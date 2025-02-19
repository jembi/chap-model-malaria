library(plumber)
pr <- plumb("api.r")
pr$run(port=8000) 