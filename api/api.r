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

# Helper function to handle input data that could be JSON or CSV
parse_input_data <- function(req, field_name) {
  print(paste("Content-Type:", req$HTTP_CONTENT_TYPE))
  print(paste("Request body type:", typeof(req$postBody)))
  
  if (req$HTTP_CONTENT_TYPE == "application/json") {
    # Parse JSON input
    input_data <- fromJSON(req$postBody)
    return(input_data[[field_name]])
  } else if (grepl("multipart/form-data", req$HTTP_CONTENT_TYPE, ignore.case = TRUE)) {
    # Handle file upload using raw body data
    if (!is.null(req$bodyRaw)) {
      # Print first few bytes of raw data
      print("Raw data preview:")
      print(rawToChar(req$bodyRaw[1:min(100, length(req$bodyRaw))]))
      
      # Try to find the boundary
      boundary <- sub(".*boundary=([^;]+).*", "\\1", req$HTTP_CONTENT_TYPE)
      print(paste("Boundary:", boundary))
      
      # Create a temporary file
      temp_file <- tempfile(fileext = ".csv")
      
      # Try to extract CSV content from multipart data
      raw_text <- rawToChar(req$bodyRaw)
      parts <- strsplit(raw_text, boundary, fixed = TRUE)[[1]]
      print(paste("Number of parts found:", length(parts)))
      
      # Look for the CSV content
      for (part in parts) {
        if (grepl(field_name, part) && grepl("text/csv", part, ignore.case = TRUE)) {
          # Extract content between headers and boundary
          content <- sub(".*\r\n\r\n(.*?)\r\n.*", "\\1", part)
          print("Found CSV content:")
          print(substr(content, 1, 100))
          writeLines(content, temp_file)
          
          # Try to read as CSV
          tryCatch({
            data <- read.csv(temp_file)
            unlink(temp_file)  # Clean up temp file
            return(data)
          }, error = function(e) {
            print(paste("CSV parsing error:", e))
            unlink(temp_file)  # Clean up temp file
            stop("Failed to parse CSV data from file upload")
          })
        }
      }
      
      print("No CSV content found in multipart data")
      stop("No CSV content found in file upload")
    }
  }
  stop(paste("No valid", field_name, "provided. Send either JSON data or CSV file."))
}

#* Train a new model using historical data
#* @param training_data Data frame containing historical data with columns: time_period, rainfall, mean_temperature, disease_cases (minimum 4 months of data required)
#* @post /train
#* @serializer json
function(req) {
  tryCatch({
    print("Starting training...")
    
    # Parse input data (either JSON or CSV)
    training_data <- parse_input_data(req, "training_data")
    print("Input data parsed:")
    print(str(training_data))
    
    # Validate required columns
    required_cols <- c("time_period", "rainfall", "mean_temperature", "disease_cases")
    missing_cols <- setdiff(required_cols, names(training_data))
    if (length(missing_cols) > 0) {
      stop(paste("Missing required columns:", paste(missing_cols, collapse = ", ")))
    }
    
    # Validate minimum data length
    if (length(training_data$time_period) < 4) {
      stop("Training data must contain at least 4 months of data (for lag features)")
    }
    
    # Validate data types and check for NAs
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
#* @param historic_data Data frame with historical data (must match training data length)
#* @param future_data Data frame with future climate data
#* @post /predict
#* @serializer json
function(req) {
  tryCatch({
    print("Starting prediction...")
    
    # Parse input data (either JSON or CSV)
    historic_data <- parse_input_data(req, "historic_data")
    future_data <- parse_input_data(req, "future_data")
    print("Input data parsed")
    print(str(historic_data))
    print(str(future_data))
    
    # Convert list to data frame if needed
    if (is.list(historic_data) && !is.data.frame(historic_data)) {
      historic_data <- as.data.frame(historic_data)
    }
    if (is.list(future_data) && !is.data.frame(future_data)) {
      future_data <- as.data.frame(future_data)
    }
    
    # Validate required fields
    if (is.null(historic_data$location)) {
      stop("Missing required field 'location' in historic_data")
    }
    if (is.null(future_data$location)) {
      stop("Missing required field 'location' in future_data")
    }
    
    # Validate location consistency
    if (length(unique(historic_data$location)) > 1) {
      stop("All historic data must be for the same location")
    }
    if (length(unique(future_data$location)) > 1) {
      stop("All future data must be for the same location")
    }
    if (unique(historic_data$location)[1] != unique(future_data$location)[1]) {
      stop("Historic and future data must be for the same location")
    }
    
    # Create temporary files for processing
    temp_historic <- tempfile(fileext = ".csv")
    temp_future <- tempfile(fileext = ".csv")
    temp_predictions <- tempfile(fileext = ".csv")
    print(paste("Temp files created:", temp_historic, temp_future, temp_predictions))
    
    # Write historic data with lag columns
    historic_df <- data.frame(
      time_period = historic_data$time_period,
      rainfall = historic_data$rainfall,
      mean_temperature = historic_data$mean_temperature,
      disease_cases = historic_data$disease_cases,
      location = historic_data$location,
      rainfall_lag1 = c(NA_real_, head(historic_data$rainfall, -1)),
      rainfall_lag2 = c(NA_real_, NA_real_, head(historic_data$rainfall, -2)),
      temp_lag2 = c(NA_real_, NA_real_, head(historic_data$mean_temperature, -2)),
      temp_lag3 = c(NA_real_, NA_real_, NA_real_, head(historic_data$mean_temperature, -3)),
      cases_lag12 = rep(NA_real_, nrow(historic_data))
    )
    
    # Write future data with lag columns
    future_df <- data.frame(
      time_period = future_data$time_period,
      rainfall = future_data$rainfall,
      mean_temperature = future_data$mean_temperature,
      location = future_data$location,
      disease_cases = rep(NA_real_, nrow(future_data)),
      rainfall_lag1 = rep(NA_real_, nrow(future_data)),
      rainfall_lag2 = rep(NA_real_, nrow(future_data)),
      temp_lag2 = rep(NA_real_, nrow(future_data)),
      temp_lag3 = rep(NA_real_, nrow(future_data)),
      cases_lag12 = rep(NA_real_, nrow(future_data))
    )
    
    # Write to CSV files
    write.csv(historic_df, temp_historic, row.names = FALSE, quote = FALSE)
    write.csv(future_df, temp_future, row.names = FALSE, quote = FALSE)
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