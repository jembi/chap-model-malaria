# CHAP Model: Malaria Prediction

This is a CHAP-compatible forecasting model that predicts malaria cases based on climate data. The model demonstrates CHAP integration using R, implementing a linear regression that learns from current and historical climate patterns to predict disease cases.

## Overview

This repository contains an R-based implementation that:
- Trains a linear regression model on historical climate and malaria case data
- Uses lagged effects of climate on disease transmission
- Predicts future malaria cases based on climate forecasts
- Incorporates seasonal patterns when sufficient historical data is available

Note: While this model uses epidemiologically relevant time lags, it is primarily meant to demonstrate CHAP integration.

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

## Usage Methods

### 1. Command Line Usage

#### Requirements
The project uses Docker with the `ivargr/r_inla:latest` image which contains all required R dependencies. Docker must be installed to run this model through CHAP.

#### Direct R Usage
You can run the model directly in R using [isolated_run.r](isolated_run.r):
```bash
Rscript isolated_run.r
```

#### Using CHAP
After installing chap-core (see [installation instructions](https://github.com/dhis2-chap/chap-core)):
```bash
chap evaluate --model-name /model/path/or/url \
              --dataset-name ISIMIP_dengue_harmonized \
              --dataset-country brazil \
              --report-filename report.pdf
```

#### Using MLflow
The project can be run using MLflow:
```bash
# Training
mlflow run . -e train \
    --param-list train_data=path/to/training_data.csv \
    model=path/to/output_model.bin

# Predictions
mlflow run . -e predict \
    --param-list model=path/to/model.bin \
    historic_data=path/to/historic_data.csv \
    future_data=path/to/future_climate.csv \
    out_file=path/to/predictions.csv
```

### 2. REST API Usage

#### Requirements
Additional R packages are required for the API:
```bash
# Install system dependencies (Ubuntu/Debian)
sudo apt-get install r-cran-plumber r-cran-jsonlite

# Or install R packages directly
Rscript -e 'install.packages(c("plumber", "jsonlite"))'
```

#### Starting the API Server
```bash
cd api
Rscript start_server.r
```
The server will run on http://localhost:8000

#### API Endpoints

##### Train Model
`POST /train`

Trains a new model using historical data. Requires at least 4 months of data.

Request body:
```json
{
  "training_data": {
    "time_period": ["2022-01", "2022-02", "2022-03", "2022-04"],
    "rainfall": [100, 120, 110, 90],
    "mean_temperature": [25, 26, 27, 28],
    "disease_cases": [10, 12, 15, 14]
  }
}
```

##### Make Predictions
`POST /predict`

Makes predictions using the trained model. 12+ months of historical data recommended.

Request body:
```json
{
  "historic_data": {
    "time_period": ["2022-01", "2022-02", "2022-03", "2022-04"],
    "rainfall": [100, 120, 110, 90],
    "mean_temperature": [25, 26, 27, 28],
    "disease_cases": [10, 12, 15, 14]
  },
  "future_data": {
    "time_period": ["2022-05", "2022-06"],
    "rainfall": [95, 105],
    "mean_temperature": [29, 30]
  }
}
```

#### API Error Handling
Errors are returned in the format:
```json
{
  "status": "error",
  "message": "Error description here"
}
```

Common API errors:
- Missing required columns in data
- Not enough historical data (minimum 4 months required)
- No trained model found
- NA/null values in the input data

## Model Details

The model implements a linear regression that:
- Uses immediate effects of rainfall (1-2 month lags)
- Incorporates longer-term temperature effects (2-3 month lags)
- Includes yearly seasonality when sufficient data is available (12-month lag)
- Handles missing values by setting them to 0
- Outputs predictions in a standardized CHAP-compatible format

## Project Structure
```
.
├── api/                # REST API implementation
│   ├── api.r          # API endpoint definitions
│   └── start_server.r # Server startup script
├── train.r            # Model training implementation
├── predict.r          # Prediction implementation
├── isolated_run.r     # Example direct usage
└── output/            # Directory for trained models
    └── model.bin      # Trained model file (created after training)
```

## License

This project is licensed under the Mozilla Public License Version 2.0 - see the [LICENSE](LICENSE) file for details.


