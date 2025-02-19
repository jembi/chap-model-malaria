# Use Ubuntu as the base image
FROM ubuntu:latest

# Install system dependencies and R
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    software-properties-common && \
    add-apt-repository -y "ppa:marutter/rrutter4.0" && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    r-base \
    r-cran-plumber \
    r-cran-jsonlite \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /app

# Copy all files
COPY . .

# Expose the port that the API will run on
EXPOSE 8000

# Print installed packages and then run the server
CMD ["Rscript", "-e", "installed.packages()[,1]; setwd('api'); source('start_server.r')"] 