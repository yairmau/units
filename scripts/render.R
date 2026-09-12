# Run from the repository root; --local makes language links work on localhost.
if (!file.exists("_quarto.yml")) stop("Run this script from the repository root.")
if (dir.exists(".R-library")) {
  .libPaths(c(normalizePath(".R-library"), .libPaths()))
}
if (!requireNamespace("babelquarto", quietly = TRUE)) {
  stop("Install dependencies first: Rscript scripts/setup.R")
}
args <- commandArgs(trailingOnly = TRUE)
if (any(!args %in% "--local")) stop("Usage: Rscript scripts/render.R [--local]")

# babelquarto deletes its output directory: build in isolation before copying
# completed files into the tracked docs directory.
stage <- tempfile("units-bilingual-")
dir.create(stage)
sources <- list.files(all.files = TRUE, no.. = TRUE)
sources <- setdiff(sources, c(".git", ".quarto", ".R-library", "docs", "_book"))
for (source in sources) {
  if (dir.exists(source)) {
    fs::dir_copy(source, file.path(stage, source))
  } else {
    fs::file_copy(source, file.path(stage, source))
  }
}
config_path <- file.path(stage, "_quarto.yml")
config <- yaml::read_yaml(config_path)
# This command builds the website; retain the source project's PDF settings.
config$format <- list(html = config$format$html)
yaml::write_yaml(config, config_path, handlers = list(
  logical = function(x) structure(ifelse(x, "true", "false"), class = "verbatim")
))
site_url <- if ("--local" %in% args) "" else config$book[["site-url"]]
babelquarto::render_book(project_path = stage, site_url = site_url, preview = FALSE)
output <- file.path(stage, "docs")
writeLines(paste0(
  '<!doctype html><html lang="he" dir="rtl"><head><meta charset="utf-8">',
  '<meta http-equiv="refresh" content="0; url=index.he.html">',
  '<title>יחידות</title></head><body><a href="index.he.html">דף הבית</a>',
  '</body></html>'
), file.path(output, "he", "index.html"))
files <- list.files(output, recursive = TRUE, all.files = TRUE, no.. = TRUE)
targets <- file.path("docs", files)
fs::dir_create(unique(dirname(targets)))
fs::file_copy(file.path(output, files), targets, overwrite = TRUE)
message("Built English and Hebrew editions in docs/.")
