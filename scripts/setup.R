# Run from the repository root: Rscript scripts/setup.R
dir.create(".R-library", showWarnings = FALSE)
.libPaths(c(normalizePath(".R-library"), .libPaths()))
options(repos = c(
  ropensci = "https://ropensci.r-universe.dev",
  CRAN = "https://cloud.r-project.org"
))
install.packages("babelquarto")
if (!requireNamespace("babelquarto", quietly = TRUE)) {
  stop("babelquarto installation failed.")
}
