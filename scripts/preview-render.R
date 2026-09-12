# Persistent native Quarto projects for incremental bilingual preview.
# Publishing continues to use render.R and babelquarto.
root <- normalizePath(".")
.libPaths(c(normalizePath(".R-library"), .libPaths()))
args <- commandArgs(trailingOnly = TRUE)
cache <- file.path(root, ".quarto", "bilingual-preview")
site <- file.path(cache, "site")
manifest_path <- file.path(cache, "manifest.rds")
config <- yaml::read_yaml("_quarto.yml", handlers = list(seq = as.list))
languages <- c(config$babelquarto$mainlanguage, unlist(config$babelquarto$languages))
if (length(languages) != 2L) stop("Incremental preview currently supports two languages.")

translate_chapters <- function(value, language) {
  if (is.list(value)) {
    for (i in seq_along(value)) {
      key <- names(value)[i]
      if (is.null(key) || is.na(key) || key %in% c("chapters", "file")) {
        value[[i]] <- translate_chapters(value[[i]], language)
      } else if (key == "part" && !is.null(value[[paste0("part-", language)]])) {
        value[[i]] <- value[[paste0("part-", language)]]
      }
    }
    return(value)
  }
  if (is.character(value) && language != languages[[1]]) {
    return(sub("\\.en\\.qmd$", paste0(".", language, ".qmd"), value))
  }
  value
}

outline <- function(path) {
  lines <- readLines(path, warn = FALSE)
  header <- character()
  if (length(lines) && lines[[1]] == "---") {
    end <- which(lines[-1] %in% c("---", "..."))[1] + 1L
    if (!is.na(end)) header <- lines[seq_len(end)]
  }
  # Rebuild shared navigation/cross-references when document structure changes.
  c(header, grep("^#{1,6} |\\{#[^}]+\\}|^ *#\\| *label:", lines, value = TRUE))
}

full <- "--init" %in% args || !file.exists(manifest_path) || !file.exists(file.path(site, "en", "index.en.html"))
manifest <- if (!full) readRDS(manifest_path) else NULL
changed <- setdiff(args, "--init")
if (!full) {
  full <- any(!changed %in% names(manifest$pages)) || any(!file.exists(changed))
  if (!full) full <- any(vapply(changed, function(file) {
    !identical(outline(file), manifest$outlines[[file]])
  }, logical(1)))
}

if (full) {
  message("Shared settings or chapter structure: building both editions.")
  if (file.exists(manifest_path)) unlink(manifest_path)
  manifest <- list(pages = list(), outlines = list())
  for (language in languages) {
    project <- file.path(cache, language)
    # These directories contain generated copies only; preserve the served site
    # until both language builds have succeeded.
    if (dir.exists(project)) unlink(project, recursive = TRUE)
    dir.create(project, recursive = TRUE)
    sources <- setdiff(list.files(all.files = TRUE, no.. = TRUE),
                      c(".git", ".quarto", ".R-library", "docs", "_book"))
    for (source in sources) {
      if (dir.exists(source)) fs::dir_copy(source, file.path(project, source))
      else fs::file_copy(source, file.path(project, source))
    }
    localized <- config
    localized$lang <- language
    localized$project[["output-dir"]] <- "docs"
    localized$format <- list(html = config$format$html)
    localized$book[["site-url"]] <- NULL
    localized$book$chapters <- translate_chapters(config$book$chapters, language)
    if (!is.null(config$book$appendices)) {
      localized$book$appendices <- translate_chapters(config$book$appendices, language)
    }
    for (field in c("title", "subtitle", "description", "abstract", "author")) {
      translation <- config[[paste0(field, "-", language)]]
      if (!is.null(translation)) localized$book[[field]] <- translation
    }
    yaml::write_yaml(localized, file.path(project, "_quarto.yml"), handlers = list(
      logical = function(x) structure(ifelse(x, "true", "false"), class = "verbatim")
    ))
    chapters <- unlist(c(localized$book$chapters, localized$book$appendices))
    chapters <- unname(chapters[grepl("\\.qmd$", chapters)])
    if (any(!file.exists(chapters))) stop("Missing translated chapters: ", paste(chapters[!file.exists(chapters)], collapse = ", "))
    for (file in chapters) {
      manifest$pages[[file]] <- language
      manifest$outlines[[file]] <- outline(file)
    }
  }
}

updates <- list()
for (language in languages) {
  files <- changed[vapply(changed, function(file) identical(manifest$pages[[file]], language), logical(1))]
  if (!full && !length(files)) next
  project <- file.path(cache, language)
  output <- file.path(project, "docs")
  before <- if (dir.exists(output)) file.info(list.files(output, recursive = TRUE, full.names = TRUE)) else NULL
  if (!full) {
    for (file in files) fs::file_copy(file.path(root, file), file.path(project, file), overwrite = TRUE)
  }
  withr::with_dir(project, {
    if (full) quarto::quarto_render(output_format = "html", as_job = FALSE)
    else for (file in files) {
      message("Rendering only ", file)
      quarto::quarto_render(input = file, output_format = "html", as_job = FALSE, quiet = TRUE)
    }
  })
  candidates <- list.files(output, recursive = TRUE, full.names = TRUE)
  after <- file.info(candidates)
  updated <- if (full) candidates else candidates[
    !candidates %in% rownames(before) |
      is.na(before[candidates, "mtime"]) |
      after$mtime != before[candidates, "mtime"] |
      after$size != before[candidates, "size"]
  ]
  # Add the same direct language link used by the babelquarto publishing build.
  for (page in updated[grepl("\\.html$", updated)]) {
    document <- xml2::read_html(page)
    sidebar <- xml2::xml_find_first(document, "//*[contains(concat(' ', normalize-space(@class), ' '), ' sidebar-menu-container ')]")
    if (inherits(sidebar, "xml_missing")) next
    other <- setdiff(languages, language)
    relative <- as.character(fs::path_rel(page, output))
    target <- paste0("/", other, "/", sub(
      paste0("\\.", language, "\\.html$"), paste0(".", other, ".html"), relative
    ))
    label <- Filter(function(x) x$name == other, config$babelquarto$languagecodes)[[1]]$text
    container <- xml2::read_xml('<div id="languages-links-parent"><a id="languages-button" class="btn btn-primary babelquarto-languages-button"><i/></a></div>')
    link <- xml2::xml_find_first(container, ".//a")
    xml2::xml_set_attr(link, "href", target)
    xml2::xml_set_attr(link, "hreflang", other)
    icon <- config$babelquarto$icon
    if (is.null(icon)) icon <- "bi bi-globe2"
    xml2::xml_set_attr(xml2::xml_find_first(link, ".//i"), "class", icon)
    xml2::xml_add_child(link, "span", paste0(" ", label))
    xml2::xml_add_sibling(sidebar, container, .where = "before")
    xml2::write_html(document, page)
  }
  destination <- file.path(site, language)
  updates[[language]] <- list(from = updated, to = file.path(destination, fs::path_rel(updated, output)))
}
# Copy only changed output after every requested render succeeds.
if (full && dir.exists(site)) fs::dir_delete(site)
for (update in updates) {
  fs::dir_create(unique(dirname(update$to)))
  fs::file_copy(update$from, update$to, overwrite = TRUE)
}
if (full) writeLines('<!doctype html><meta charset="utf-8"><meta http-equiv="refresh" content="0; url=index.he.html"><a href="index.he.html">עברית</a>', file.path(site, "he", "index.html"))
if (full) writeLines('<!doctype html><meta charset="utf-8"><meta http-equiv="refresh" content="0; url=index.en.html"><a href="index.en.html">English</a>', file.path(site, "en", "index.html"))
if (full) writeLines('<!doctype html><html lang="en"><meta charset="utf-8"><meta http-equiv="refresh" content="0; url=en/"><title>Choose a language</title><a href="en/">English</a> · <a href="he/">עברית</a></html>', file.path(site, "index.html"))
saveRDS(manifest, manifest_path)
message("Preview output updated.")
