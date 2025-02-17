options(warn=1)

predict_chap <- function(model_fn, historic_data_fn, future_climatedata_fn, predictions_fn) {
  # Load data
  future_df <- read.csv(future_climatedata_fn)
  historic_df <- read.csv(historic_data_fn)
  model <- readRDS(model_fn)
  
  # Initialize prediction dataframe
  pred_df <- future_df[order(future_df$time_period),]
  
  # Get historical data for lags
  hist_rainfall <- tail(historic_df$rainfall, 3)
  hist_temp <- tail(historic_df$mean_temperature, 3)
  hist_cases <- if(nrow(historic_df) >= 12) tail(historic_df$disease_cases, 12) else NULL
  
  # Make predictions for future months
  for(i in 1:nrow(pred_df)) {
    # Prepare features for current prediction
    features <- data.frame(
      rainfall = pred_df$rainfall[i],
      mean_temperature = pred_df$mean_temperature[i],
      rainfall_lag1 = if(i == 1) hist_rainfall[3] else pred_df$rainfall[i-1],
      rainfall_lag2 = if(i == 1) hist_rainfall[2] else if(i == 2) hist_rainfall[3] else pred_df$rainfall[i-2],
      temp_lag2 = if(i == 1) hist_rainfall[2] else if(i == 2) hist_rainfall[3] else pred_df$mean_temperature[i-2],
      temp_lag3 = if(i == 1) hist_rainfall[1] else if(i == 2) hist_rainfall[2] else if(i == 3) hist_rainfall[3] else pred_df$mean_temperature[i-3]
    )
    
    # Add 12-month lag if it was used in training
    if(!is.null(hist_cases) && "cases_lag12" %in% names(model$coefficients)) {
      features$cases_lag12 <- if(i <= length(hist_cases)) hist_cases[i] else pred_df$sample_0[i-12]
    }
    
    # Make prediction
    pred_df$sample_0[i] <- predict(model, newdata = features)
  }
  
  # Save predictions
  write.csv(pred_df, predictions_fn, row.names = FALSE)
  
  print(paste("Forecasted values for", nrow(pred_df), "months:", paste(pred_df$sample_0, collapse = ", ")))
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