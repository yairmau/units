# Units — English and Hebrew

The book uses [babelquarto](https://docs.ropensci.org/babelquarto/) to build both
languages with an English / עברית menu linking corresponding chapters.

## Setup

Install Quarto and R, then run these commands from this directory:

```sh
Rscript scripts/setup.R
```

R dependencies are installed in the ignored `.R-library/` directory.

## Preview both languages

```sh
Rscript scripts/render.R --local
python3 -m http.server 8000 --directory docs
```

Open http://localhost:8000 (English) or http://localhost:8000/he/ (Hebrew).
After editing, rerun the render command and refresh the browser. Quarto's usual
Preview button does not run babelquarto's complete bilingual build.

## Build for publishing

```sh
Rscript scripts/render.R
```

This builds the website into `docs/`, using `book.site-url` from `_quarto.yml`
for language links. The initial URL is `https://yairmau.github.io/units/`;
change it if the book is hosted elsewhere. Publish the entire `docs/` directory,
including `he/`. This script does not publish anything.

The renderer builds in a temporary directory before copying successful output
into `docs/`. It renders HTML only; existing PDF configuration is retained.

## Editing translations

- English: `index.qmd`, `intro.qmd`, `basic-concepts.qmd`.
- Hebrew: `index.he.qmd`, `intro.he.qmd`, `basic-concepts.he.qmd`.
- Shared styling: `custom.scss`; Hebrew adjustments: `hebrew.css`.
- Hebrew language: `babelquarto` configuration in `_quarto.yml`; direction:
  `dir: rtl` in each Hebrew chapter's front matter.

For a new chapter, add its English filename to `book.chapters` and create the
matching `.he.qmd` translation. Keep equation and figure identifiers consistent
between translations, and include `dir: rtl` in each Hebrew file's YAML header.
Use chapter front matter for Hebrew settings: a language profile currently makes
babelquarto's translated chapter list merge with the English list in this setup.
Translations are maintained separately, not synchronized
automatically. The initial Hebrew text is a draft for editorial review.
