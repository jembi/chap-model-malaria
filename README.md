# CHAP Model: Malaria Prediction

This is a CHAP-compatible forecasting model that predicts malaria cases based on climate data. The model demonstrates CHAP integration using R, implementing a linear regression that learns from current and historical climate patterns to predict disease cases.

## Overview

This repository contains an R-based implementation that:
- Trains a linear regression model on historical climate and malaria case data
- Uses lagged effects of climate on disease transmission
- Predicts future malaria cases based on climate forecasts
- Works with a single region at a time
- Incorporates seasonal patterns when sufficient historical data is available

Note: While this model uses epidemiologically relevant time lags, it is primarily meant to demonstrate CHAP integration.

## Requirements

The project uses Docker with the `ivargr/r_inla:latest` image which contains all required R dependencies. Docker must be installed to run this model through CHAP.

## Data Format

### Training Data
The training data should be a CSV file with the following columns:
- `time_period`: Date in YYYY-MM format
- `rainfall`: Rainfall measurement
- `mean_temperature`: Average temperature
- `disease_cases`: Number of malaria cases
- `location`: Location identifier

Note: At least 4 months of historical data is required. For seasonal pattern detection, at least 13 months is recommended.

Example:
```
time_period,rainfall,mean_temperature,disease_cases,location
2024-01,14,24,130,loc1
2024-02,16,25,140,loc1
2024-03,22,26,160,loc1
```

### Future Climate Data
The future climate data for predictions should be a CSV with:
- `time_period`: Date in YYYY-MM format (must follow directly after training data)
- `rainfall`: Rainfall measurement
- `mean_temperature`: Average temperature
- `location`: Location identifier

## Usage

### Using CHAP

After installing chap-core (see [installation instructions](https://github.com/dhis2-chap/chap-core)), you can run the model through CHAP:

```bash
chap evaluate --model-name /model/path/or/url \
              --dataset-name ISIMIP_dengue_harmonized \
              --dataset-country brazil \
              --report-filename report.pdf
```

### Using MLflow Directly

The project can be run using MLflow with two main entry points:

1. Training the model:
```bash
mlflow run . -e train \
    --param-list train_data=path/to/training_data.csv \
    model=path/to/output_model.bin
```

2. Making predictions:
```bash
mlflow run . -e predict \
    --param-list model=path/to/model.bin \
    historic_data=path/to/historic_data.csv \
    future_data=path/to/future_climate.csv \
    out_file=path/to/predictions.csv
```

### Direct R Usage

You can also run the model directly in R using isolated_run.r:

```r
source("train.r")
source("predict.r")

# Train the model
train_chap("input/trainData.csv", "output/model.bin")

# Make predictions
predict_chap("output/model.bin", 
            "input/trainData.csv", 
            "input/futureClimateData.csv", 
            "output/predictions.csv")
```

## Model Details

The model implements a linear regression that:
- Uses immediate effects of rainfall (1-2 month lags)
- Incorporates longer-term temperature effects (2-3 month lags)
- Includes yearly seasonality when sufficient data is available (12-month lag)
- Handles missing values by setting them to 0
- Outputs predictions in a standardized CHAP-compatible format

The number of months predicted depends on the future climate data provided.

## Output

The predictions are saved as a CSV file with the following columns:
- `time_period`: The forecasted time period
- `rainfall`: Input rainfall value
- `mean_temperature`: Input temperature value
- `location`: Location identifier
- `sample_0`: Predicted number of malaria cases

## License

This project is licensed under the Mozilla Public License Version 2.0 - see the [LICENSE](LICENSE) file for details.


