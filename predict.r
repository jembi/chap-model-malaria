options(warn=1)

predict_chap <- function(model_fn, historic_data_fn, future_climatedata_fn, predictions_fn) {
  # Load data
  future_df <- read.csv(future_climatedata_fn)
  historic_df <- read.csv(historic_data_fn)
  model_info <- readRDS(model_fn)
  model <- model_info$model  # Extract model from model_info
  use_yearly_lag <- model_info$use_yearly_lag  # Get lag info
  
  print(paste("Model uses yearly lag:", use_yearly_lag))
  
  # Initialize prediction dataframe
  pred_df <- future_df[order(future_df$time_period),]
  pred_df$sample_0 <- NA_real_
  
  # Get historical data for lags
  hist_rainfall <- tail(historic_df$rainfall, 3)
  hist_temp <- tail(historic_df$mean_temperature, 3)
  hist_cases <- if(use_yearly_lag && nrow(historic_df) >= 12) tail(historic_df$disease_cases, 12) else NULL
  
  # Make predictions for future months
  for(i in 1:nrow(pred_df)) {
    # Prepare features for current prediction
    features <- data.frame(
      rainfall = pred_df$rainfall[i],
      mean_temperature = pred_df$mean_temperature[i],
      rainfall_lag1 = if(i == 1) hist_rainfall[3] else pred_df$rainfall[i-1],
      rainfall_lag2 = if(i == 1) hist_rainfall[2] else if(i == 2) hist_rainfall[3] else pred_df$rainfall[i-2],
      temp_lag2 = if(i == 1) hist_temp[2] else if(i == 2) hist_temp[3] else pred_df$mean_temperature[i-2],
      temp_lag3 = if(i == 1) hist_temp[1] else if(i == 2) hist_temp[2] else if(i == 3) hist_temp[3] else pred_df$mean_temperature[i-3]
    )
    
    # Add 12-month lag if model was trained with it
    if(use_yearly_lag) {
      features$cases_lag12 <- if(!is.null(hist_cases) && i <= length(hist_cases)) {
        hist_cases[i]
      } else if(i > 12 && !is.na(pred_df$sample_0[i-12])) {
        pred_df$sample_0[i-12]
      } else {
        mean(historic_df$disease_cases)  # Use mean of historic cases instead of 0
      }
    }
    
    # Make prediction
    tryCatch({
      pred_df$sample_0[i] <- predict(model, newdata = features)
    }, error = function(e) {
      print(paste("Error in prediction:", e))
    })
  }
  
  # Apply scaling based on historical data
  historic_mean <- mean(historic_df$disease_cases, na.rm = TRUE)
  training_mean <- model_info$training_mean
  scale_factor <- historic_mean / training_mean
  
  print("Scaling predictions:")
  print(paste("- Historic mean:", round(historic_mean, 2)))
  print(paste("- Training mean:", round(training_mean, 2)))
  print(paste("- Scale factor:", round(scale_factor, 2)))
  
  pred_df$sample_0 <- pred_df$sample_0 * scale_factor
  
  # Save predictions
  write.csv(pred_df, predictions_fn, row.names = FALSE)
  
  print(paste("\nPredictions for", nrow(pred_df), "months:", 
              paste(round(pred_df$sample_0, 2), collapse = ", ")))
}

args <- commandArgs(trailingOnly = TRUE)

if (length(args) == 4) {
  model_fn <- args[1]
  historic_data_fn <- args[2]
  future_climatedata_fn <- args[3]
  predictions_fn <- args[4]
  
  predict_chap(model_fn, historic_data_fn, future_climatedata_fn, predictions_fn)
}# else {
#  stop("Usage: Rscript predict.R <model_fn> <historic_data_fn> <future_climatedata_fn> <predictions_fn>")
#}