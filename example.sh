#!/usr/local/bin/Rscript

# generate dataset with certain seed
set.seed(1)
data <- dyntoy::generate_dataset(
  id = "specific_example/scoup",
  num_cells = 49,
  num_features = 51,
  model = "bifurcating",
  normalise = FALSE
)

# add method specific args (if needed)
data$parameters <- list()

data$seed <- 1L

# write example dataset to file
file <- commandArgs(trailingOnly = TRUE)[[1]]
dynutils::write_h5(data, file)
