#!/usr/bin/env Rscript

required_packages <- c(
  "tidyverse",
  "ggplot2",
  "lubridate",
  "jsonlite",
  "httr2",
  "scales",
  "ragg",
  "systemfonts"
)

repositories <- getOption("repos")
if (is.null(repositories) || identical(unname(repositories[["CRAN"]]), "@CRAN@")) {
  options(repos = c(CRAN = "https://cloud.r-project.org"))
}

missing_packages <- setdiff(required_packages, rownames(installed.packages()))
if (length(missing_packages)) {
  install.packages(missing_packages)
} else {
  cat("All required R packages are already installed.\n")
}
