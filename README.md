# CHAP Model: Malaria Prediction

This is a CHAP-compatible forecasting model that predicts malaria cases based on climate data. The model demonstrates a minimalist example of CHAP integration using R, implementing a simple linear regression that learns from rainfall and temperature to predict disease cases in the same month.

## Overview

This repository contains a basic R-based implementation that:
- Trains a linear regression model on historical climate and malaria case data
- Predicts future malaria cases based on climate forecasts
- Works with a single region at a time
- Does not consider previous disease or climate data (no lag effects)

Note: This model is primarily meant to demonstrate CHAP integration rather than provide accurate epidemiological predictions.

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

Example:
```
time_period,rainfall,mean_temperature,disease_cases,location
2023-05,10,30,200,loc1
2023-06,2,30,100,loc1
2023-06,1,35,100,loc1
```

### Future Climate Data
The future climate data for predictions should be a CSV with:
- `time_period`: Date in YYYY-MM format
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

The model implements a simple linear regression that:
- Uses rainfall and temperature as predictors
- Predicts disease cases for the same month (no time lag)
- Handles missing values by setting them to 0
- Outputs predictions in a standardized CHAP-compatible format

## Output

The predictions are saved as a CSV file with the following columns:
- `time_period`: The forecasted time period
- `rainfall`: Input rainfall value
- `mean_temperature`: Input temperature value
- `location`: Location identifier
- `sample_0`: Predicted number of malaria cases

## License

This project is licensed under the Mozilla Public License Version 2.0 - see the [LICENSE](LICENSE) file for details.


