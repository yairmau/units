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
config <- yaml::read_yaml(config_path, handlers = list(seq = as.list))
# babelquarto requires unsuffixed main-language sources. Normalize only the
# temporary copy, then restore explicit English filenames in the HTML output.
english_sources <- list.files(stage, pattern = "\\.en\\.qmd$", recursive = TRUE, full.names = TRUE)
for (file in english_sources) fs::file_move(file, sub("\\.en\\.qmd$", ".qmd", file))
normalize_english <- function(value) {
  if (is.list(value)) return(lapply(value, normalize_english))
  if (is.character(value)) return(gsub("\\.en\\.qmd", ".qmd", value))
  value
}
config <- normalize_english(config)
for (file in list.files(stage, pattern = "\\.qmd$", recursive = TRUE, full.names = TRUE)) {
  text <- readLines(file, warn = FALSE)
  writeLines(gsub("\\.en\\.qmd", ".qmd", text), file)
}
# This command builds the website; retain the source project's PDF settings.
config$format <- list(html = config$format$html)
yaml::write_yaml(config, config_path, handlers = list(
  logical = function(x) structure(ifelse(x, "true", "false"), class = "verbatim")
))
site_url <- if ("--local" %in% args) "" else config$book[["site-url"]]
babelquarto::render_book(project_path = stage, site_url = site_url, preview = FALSE)
output <- file.path(stage, "docs")
# With one alternative language, make the switch a normal link to that page.
for (page in list.files(output, pattern = "\\.html$", recursive = TRUE, full.names = TRUE)) {
  document <- xml2::read_html(page)
  button <- xml2::xml_find_first(document, "//*[@id='languages-button']")
  menu <- xml2::xml_find_first(document, "//*[@id='languages-links']")
  alternatives <- xml2::xml_find_all(menu, ".//a[@href]")
  if (!inherits(button, "xml_missing") && length(alternatives) == 1L) {
    alternative <- alternatives[[1]]
    xml2::xml_set_name(button, "a")
    xml2::xml_set_attr(button, "href", xml2::xml_attr(alternative, "href"))
    xml2::xml_set_attr(button, "hreflang", sub(
      "^language-link-", "", xml2::xml_attr(alternative, "id")
    ))
    xml2::xml_set_attr(button, "class", "btn btn-primary babelquarto-languages-button")
    attributes <- xml2::xml_attrs(button)
    xml2::xml_attrs(button) <- attributes[
      !names(attributes) %in% c("type", "data-bs-toggle", "aria-expanded")
    ]
    xml2::xml_remove(menu)
    xml2::write_html(document, page)
  }
}
writeLines(paste0(
  '<!doctype html><html lang="he" dir="rtl"><head><meta charset="utf-8">',
  '<meta http-equiv="refresh" content="0; url=index.he.html">',
  '<title>יחידות</title></head><body><a href="index.he.html">דף הבית</a>',
  '</body></html>'
), file.path(output, "he", "index.html"))

# babelquarto places its main language at the root. Give English its own
# directory, preserving relative links by moving its assets alongside it.
fs::dir_create(file.path(output, "en"))
entries <- setdiff(list.files(output, all.files = TRUE, no.. = TRUE),
                   c("en", "he", "sitemap.xml", "robots.txt", "CNAME", ".nojekyll"))
for (entry in entries) fs::file_move(file.path(output, entry), file.path(output, "en", entry))

base_url <- sub("/+$", "", site_url)
english_filename <- function(url) {
  sub("(?<!\\.en)(?<!\\.he)\\.html(?=$|[?#])", ".en.html", url, perl = TRUE)
}
prefix_english <- function(url) {
  prefix <- paste0(base_url, "/")
  if (is.na(url) || !startsWith(url, prefix) || startsWith(url, "//")) return(url)
  relative <- sub("^/+", "", substring(url, nchar(prefix) + 1L))
  if (grepl("^he(/|$)|^(sitemap\\.xml|robots\\.txt)$", relative)) return(paste0(prefix, relative))
  if (grepl("^en(/|$)", relative)) return(english_filename(paste0(prefix, relative)))
  english_filename(paste0(prefix, "en/", relative))
}
for (page in list.files(output, pattern = "\\.html$", recursive = TRUE, full.names = TRUE)) {
  document <- xml2::read_html(page)
  # Includes language links, canonical/alternate URLs, and social metadata.
  for (attribute in c("href", "src", "content", "data-quarto-source-url")) {
    nodes <- xml2::xml_find_all(document, paste0("//*[@", attribute, "]"))
    for (node in nodes) {
      value <- xml2::xml_attr(node, attribute)
      rewritten <- prefix_english(value)
      if (startsWith(page, file.path(output, "en", "")) &&
          !grepl("^[a-zA-Z][a-zA-Z0-9+.-]*:|^//|^/", value)) {
        rewritten <- english_filename(rewritten)
      }
      repo <- config$book[["repo-url"]]
      if (!is.null(repo) && startsWith(value, repo) && grepl("/en/", page, fixed = TRUE)) {
        rewritten <- sub("(?<!\\.he)(?<!\\.en)\\.qmd$", ".en.qmd", rewritten, perl = TRUE)
      }
      xml2::xml_set_attr(node, attribute, rewritten)
    }
  }
  xml2::write_html(document, page)
}
for (page in list.files(file.path(output, "en"), pattern = "\\.html$", recursive = TRUE, full.names = TRUE)) {
  fs::file_move(page, english_filename(page))
}
search_path <- file.path(output, "en", "search.json")
if (file.exists(search_path)) {
  search <- jsonlite::read_json(search_path, simplifyVector = FALSE)
  for (i in seq_along(search)) search[[i]]$href <- english_filename(search[[i]]$href)
  jsonlite::write_json(search, search_path, auto_unbox = TRUE, pretty = TRUE)
}
writeLines('<!doctype html><meta charset="utf-8"><meta http-equiv="refresh" content="0; url=index.en.html"><a href="index.en.html">English</a>', file.path(output, "en", "index.html"))
sitemap <- file.path(output, "sitemap.xml")
if (file.exists(sitemap)) {
  document <- xml2::read_xml(sitemap)
  for (node in xml2::xml_find_all(document, "//*[local-name()='loc']")) {
    xml2::xml_text(node) <- prefix_english(xml2::xml_text(node))
  }
  for (node in xml2::xml_find_all(document, "//*[@href]")) {
    xml2::xml_set_attr(node, "href", prefix_english(xml2::xml_attr(node, "href")))
  }
  xml2::write_xml(document, sitemap)
}
writeLines('<!doctype html><html lang="en"><meta charset="utf-8"><meta http-equiv="refresh" content="0; url=en/"><title>Choose a language</title><a href="en/">English</a> · <a href="he/">עברית</a></html>', file.path(output, "index.html"))
files <- list.files(output, recursive = TRUE, all.files = TRUE, no.. = TRUE)
targets <- file.path("docs", files)
fs::dir_create(unique(dirname(targets)))
fs::file_copy(file.path(output, files), targets, overwrite = TRUE)
# Retire obsolete HTML filenames after the new build succeeds.
old_pages <- list.files("docs", pattern = "\\.html$", recursive = TRUE)
old_pages <- setdiff(old_pages, files[grepl("\\.html$", files)])
if (length(old_pages)) unlink(file.path("docs", old_pages))
message("Built English and Hebrew editions in docs/.")
