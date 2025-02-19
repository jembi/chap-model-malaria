library(plumber)
pr <- plumb("api.r")
pr$run(host="0.0.0.0", port=8000) 