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

1. JSON payload:
```bash
curl -X POST http://localhost:8000/train \
  -H "Content-Type: application/json" \
  -d '{
    "training_data": {
      "time_period": ["2022-01", "2022-02", "2022-03", "2022-04"],
      "rainfall": [100, 120, 110, 90],
      "mean_temperature": [25, 26, 27, 28],
      "disease_cases": [10, 12, 15, 14],
      "location": ["loc1", "loc1", "loc1", "loc1"]
    }
  }'
```

2. CSV file upload:
```bash
curl -X POST http://localhost:8000/train \
  -F "training_data=@path/to/training_data.csv"
```

##### Make Predictions
`POST /predict`

Makes predictions using the trained model. The model adapts to the amount of historical data provided:
- With 4+ months of data: Uses recent trends and weather patterns
- With 13+ months of data: Uses seasonal patterns for more accurate long-term predictions
- Location information required for each data point

1. JSON payload example:
```bash
curl -X POST http://localhost:8000/predict \
  -H "Content-Type: application/json" \
  -d '{
    "historic_data": {
      "time_period": ["2023-01", "2023-02", "2023-03", "2023-04"],
      "rainfall": [12, 15, 20, 18],
      "mean_temperature": [24, 25, 26, 27],
      "disease_cases": [120, 130, 150, 180],
      "location": ["loc1", "loc1", "loc1", "loc1"]
    },
    "future_data": {
      "time_period": ["2023-05", "2023-06"],
      "rainfall": [10, 5],
      "mean_temperature": [28, 29],
      "location": ["loc1", "loc1"]
    }
  }'
```

2. CSV file upload:
```bash
curl -X POST http://localhost:8000/predict \
  -F "historic_data=@path/to/historic_data.csv" \
  -F "future_data=@path/to/future_data.csv"
```

The CSV files should follow the same data format described in the [Data Format](#data-format) section.

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
- Location mismatch between historic and future data

## Model Details

The model implements a linear regression that:
- Uses immediate effects of rainfall (1-2 month lags)
- Incorporates longer-term temperature effects (2-3 month lags)
- Includes seasonal patterns when sufficient historical data is available
- Adapts to available data length (uses historical averages when needed)
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

## Docker Deployment

You can deploy the CHAP Model, with the API exposed, using Docker to ensure a consistent environment across different systems. This section provides instructions on how to build and run the application using Docker.

### Requirements
Ensure Docker and Docker Compose are installed on your system.

### Building and Running the Application
1. **Build the Docker Image**:
   Navigate to the project directory and run the following command to build the Docker image:
   ```bash
   docker-compose build
   ```

2. **Run the Application**:
   Start the application using Docker Compose:
   ```bash
   docker-compose up
   ```
   This command will start the application and expose it on port 8000.

3. **Access the API**:
   Once the application is running, you can access the API at `http://host-ip:8000`.

4. **Stopping the Application**:
   To stop the application, press `Ctrl+C` if running in the foreground, or use:
   ```bash
   docker-compose down
   ```

This Docker deployment option allows you to easily run the application in a containerized environment, ensuring consistency across different systems.

## License

This project is licensed under the Mozilla Public License Version 2.0 - see the [LICENSE](LICENSE) file for details.


