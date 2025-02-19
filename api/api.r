library(plumber)
library(jsonlite)

# Source the required files with correct paths
source("../train.r")
source("../predict.r")

#* @apiTitle CHAP Disease Prediction API
#* @apiDescription API for training models and making disease predictions based on climate data

#* @filter cors
function(req, res) {
  res$setHeader("Access-Control-Allow-Origin", "*")
  res$setHeader("Access-Control-Allow-Methods", "POST")
  res$setHeader("Access-Control-Allow-Headers", "Content-Type")
  plumber::forward()
}

#* Train a new model using historical data
#* @param training_data Data frame containing historical data with columns: time_period, rainfall, mean_temperature, disease_cases (minimum 4 months of data required)
#* @post /train
#* @serializer json
function(req) {
  tryCatch({
    print("Starting training...")
    input_data <- fromJSON(req$postBody)
    print("Input data parsed:")
    print(str(input_data))
    
    # Validate required columns
    required_cols <- c("time_period", "rainfall", "mean_temperature", "disease_cases")
    missing_cols <- setdiff(required_cols, names(input_data$training_data))
    if (length(missing_cols) > 0) {
      stop(paste("Missing required columns:", paste(missing_cols, collapse = ", ")))
    }
    
    # Validate minimum data length
    if (length(input_data$training_data$time_period) < 4) {
      stop("Training data must contain at least 4 months of data (for lag features)")
    }
    
    # Validate data types and check for NAs
    training_data <- input_data$training_data
    if (any(is.na(training_data$rainfall))) stop("Rainfall contains NA values")
    if (any(is.na(training_data$mean_temperature))) stop("Mean temperature contains NA values")
    if (any(is.na(training_data$disease_cases))) stop("Disease cases contains NA values")
    
    # Create temporary file for training data
    temp_csv <- tempfile(fileext = ".csv")
    print(paste("Temporary file created:", temp_csv))
    
    # Write the input data to a temporary CSV
    write.csv(training_data, temp_csv, row.names = FALSE)
    print("Data written to temp file")
    print("Training data preview:")
    print(head(training_data))
    
    # Ensure output directory exists
    dir.create("../output", showWarnings = FALSE)
    
    # Train the model using fixed output path
    model_path <- "../output/model.bin"
    print(paste("Training model, will save to:", model_path))
    train_chap(temp_csv, model_path)
    
    # Clean up temporary file
    unlink(temp_csv)
    
    # Return success response
    list(
      status = "success",
      message = "Model trained successfully",
      model_path = model_path
    )
  }, error = function(e) {
    print(paste("Error occurred:", e))
    list(
      status = "error",
      message = as.character(e)
    )
  })
}

#* Make predictions using the trained model
#* @param historic_data Data frame with historical data (12+ months recommended for better predictions)
#* @param future_data Data frame with future climate data
#* @post /predict
#* @serializer json
function(req) {
  tryCatch({
    print("Starting prediction...")
    input_data <- fromJSON(req$postBody)
    print("Input data parsed")
    print(str(input_data))
    
    # Create temporary files for processing
    temp_historic <- tempfile(fileext = ".csv")
    temp_future <- tempfile(fileext = ".csv")
    temp_predictions <- tempfile(fileext = ".csv")
    print(paste("Temp files created:", temp_historic, temp_future, temp_predictions))
    
    # Prepare historic data with required columns
    historic_data <- input_data$historic_data
    historic_data$cases_lag12 <- NA  # Add the column even if we don't have the data
    
    # Write input data to temporary CSV files
    write.csv(historic_data, temp_historic, row.names = FALSE)
    write.csv(input_data$future_data, temp_future, row.names = FALSE)
    print("Data written to temp files")
    
    # Use hardcoded model path
    model_path <- "../output/model.bin"
    if (!file.exists(model_path)) {
      stop("No trained model found. Please train a model first.")
    }
    
    predict_chap(model_path, temp_historic, temp_future, temp_predictions)
    
    # Read predictions
    predictions <- read.csv(temp_predictions)
    
    # Clean up temporary files
    unlink(temp_historic)
    unlink(temp_future)
    unlink(temp_predictions)
    
    # Return predictions data directly
    list(
      status = "success",
      predictions = predictions$sample_0  # Just return the predictions array
    )
  }, error = function(e) {
    print(paste("Error occurred:", e))
    list(
      status = "error",
      message = as.character(e)
    )
  })
} 