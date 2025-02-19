options(warn=1)

train_chap <- function(csv_fn, model_fn) {
  df <- read.csv(csv_fn)
  
  # Calculate mean before creating lag features
  training_mean <- mean(df$disease_cases, na.rm = TRUE)
  print(paste("Training data mean:", round(training_mean, 2), "cases"))
  
  # Create focused lag features
  # Rainfall: 1-2 month lags (immediate effects)
  df$rainfall_lag1 <- c(NA, df$rainfall[-nrow(df)])
  df$rainfall_lag2 <- c(NA, NA, df$rainfall[-nrow(df):-(nrow(df)-1)])
  
  # Temperature: 2-3 month lags (longer-term effects)
  df$temp_lag2 <- c(NA, NA, df$mean_temperature[-nrow(df):-(nrow(df)-1)])
  df$temp_lag3 <- c(NA, NA, NA, df$mean_temperature[-nrow(df):-(nrow(df)-2)])
  
  # Optional 12-month lag for disease cases if enough data
  if(nrow(df) >= 13) {
    df$cases_lag12 <- c(rep(NA, 12), df$disease_cases[-nrow(df):-(nrow(df)-11)])
    use_yearly_lag <- TRUE
    print("Using seasonal patterns (13+ months of data)")
  } else {
    use_yearly_lag <- FALSE
    print("Using recent trends only (4-12 months of data)")
  }
  
  # Remove rows with NA due to lagging
  df <- df[4:nrow(df),]
  
  df$disease_cases[is.na(df$disease_cases)] <- 0
  
  # Train model with appropriate formula
  if(use_yearly_lag) {
    model <- lm(disease_cases ~ rainfall + mean_temperature + 
                rainfall_lag1 + rainfall_lag2 +
                temp_lag2 + temp_lag3 +
                cases_lag12, data = df)
  } else {
    model <- lm(disease_cases ~ rainfall + mean_temperature + 
                rainfall_lag1 + rainfall_lag2 +
                temp_lag2 + temp_lag3, data = df)
  }
  
  print("Model trained successfully")
  
  # Save model along with metadata
  model_info <- list(
    model = model,
    use_yearly_lag = use_yearly_lag,
    training_mean = training_mean
  )
  
  saveRDS(model_info, file=model_fn)
}

args <- commandArgs(trailingOnly = TRUE)

if (length(args) == 2) {
  csv_fn <- args[1]
  model_fn <- args[2]
  
  train_chap(csv_fn, model_fn)
}# else {
#  stop("Usage: Rscript train.R <csv_fn> <model_fn>")
#}