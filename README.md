# Measure — English and Hebrew

The book uses [babelquarto](https://docs.ropensci.org/babelquarto/) to build both
languages with an English / עברית menu linking corresponding chapters.

## TL;DR

For previewing run 
python3 scripts/preview.py

For rendering html run
Rscript scripts/render.R

## Setup

Install Quarto, R, and Python 3, then run this command from the repository root:

```sh
Rscript scripts/setup.R
```

R dependencies are installed in the ignored `.R-library/` directory. The Python
preview server uses only the standard library; no Python packages are needed.

The TikZ figures also require a TeX installation with `pdflatex`, `standalone`,
and TikZ, plus `pdftocairo` on your PATH. The installed extension is enabled by
`filters: [tikz]`, with `tikz.svg-engine: pdftocairo` in `_quarto.yml`.

## Preview both languages

Use this instead of `quarto preview` or VS Code's Quarto Preview button:

```sh
python3 scripts/preview.py
```

Run it from the repository root and leave the terminal running while you edit.
It builds both editions once, opens the browser, and watches for saved changes.

- English: http://localhost:8001/en/
- Hebrew: http://localhost:8001/he/
- The root URL redirects to `/en/`; both language editions have their own prefix.
- The **Aא** language button links directly to the matching translated page.

Save a source file and wait for `Preview updated. Watching for saves…` in the
terminal. The browser refreshes automatically, retaining the current page and
restoring its scroll position. Press **Ctrl+C in the terminal running the preview**
to stop it. Restart with the same command.

### What gets rebuilt?

| Saved change | Preview behavior |
| --- | --- |
| Chapter text or a TikZ drawing, e.g. `basic_concepts/area-and-volume.en.qmd` | Renders only that English chapter and updates its search entries. |
| Hebrew chapter text, e.g. `basic_concepts/area-and-volume.he.qmd` | Renders only that Hebrew chapter and updates its search entries. |
| Chapter headings, front matter, or detected labels | Rebuilds both editions to update navigation and references. |
| Shared configuration, styles, includes, fonts, images, or extension files | Rebuilds both editions. |
| Added or deleted source files | Rebuilds both editions; update `book.chapters` when changing the book structure. |

The preview uses `scripts/preview-render.R` and Quarto's native single-file
renderer inside persistent projects for each language. These retain Quarto's
search and cross-reference caches between saves. The generated projects and
served files live in the ignored `.quarto/bilingual-preview/` directory; edit
the original source files, not these generated copies. Previewing does not
overwrite `docs/` or publish the website.

### Options and troubleshooting

Choose another port:

```sh
python3 scripts/preview.py --port 8002
```

Start without opening a browser automatically:

```sh
python3 scripts/preview.py --no-browser
```

- **Address already in use:** another process is using that port. Stop the old
  preview with Ctrl+C in its terminal, or use `--port 8002`. Closing the browser
  does not stop the server.
- **Build error after saving:** the previous successful preview stays visible.
  Read the terminal error, fix the source, and save again. If the initial build
  fails, fix it and rerun the preview command.
- **Python watcher changed:** stop and restart the preview after editing
  `scripts/preview.py`; a running Python process does not reload its own code.
- **VS Code shows an older file with an unsaved-change dot:** external edits
  are on disk while the editor retains your unsaved buffer. Save before asking
  someone else to edit. To load the disk version, use **File: Revert File** only
  after preserving any unsaved edits you want to keep.

### One-time builds

| Command | Result |
| --- | --- |
| `python3 scripts/preview.py` | Live bilingual preview with automatic rebuilds and browser refresh. |
| `Rscript scripts/render.R --local` | One-time babelquarto build into `docs/` with local language links; no server or watching. |
| `Rscript scripts/render.R` | One-time babelquarto build into `docs/` with publishing URLs; no deployment. |

If you specifically want to inspect the one-time local build, serve it separately
with `python3 -m http.server 8000 --directory docs`, then open http://localhost:8000/.
That static server does not rebuild sources or refresh the browser automatically.

## Build for publishing

```sh
Rscript scripts/render.R
```

This builds the website into `docs/`, using `book.site-url` from `_quarto.yml`
for language links. The initial URL is `https://yairmau.github.io/measure/`;
change it if the book is hosted elsewhere. Publish the entire `docs/` directory,
including `en/` and `he/`. The root page redirects to `en/`. This script does not publish anything.

The renderer builds in a temporary directory before copying successful output
into `docs/`. It renders HTML only; existing PDF configuration is retained.

## Editing translations

- English: `index.en.qmd`, `intro.en.qmd`, `basic_concepts/area-and-volume.en.qmd`,
  `basic_concepts/concentration.en.qmd`, `basic_concepts/density.en.qmd`.
- Hebrew: `index.he.qmd`, `intro.he.qmd`, `basic_concepts/area-and-volume.he.qmd`,
  `basic_concepts/concentration.he.qmd`, `basic_concepts/density.he.qmd`.
- The last three chapters belong to the `basic concepts` / `מושגי יסוד` part,
  configured with `part`, `part-he`, and nested `chapters` in `_quarto.yml`.
- Shared styling: `custom.scss`; Hebrew adjustments: `hebrew.css`.
- Hebrew language: `babelquarto` configuration in `_quarto.yml`; direction:
  `dir: rtl` in each Hebrew chapter's front matter.

For a new chapter, add its `.en.qmd` filename to `book.chapters` and create the
matching translation by replacing `.en.qmd` with `.he.qmd`. English pages use
URLs such as `/en/intro.en.html`; Hebrew pages use `/he/intro.he.html`.
Keep equation and figure identifiers consistent
between translations, and include `dir: rtl` in each Hebrew file's YAML header.
Use chapter front matter for Hebrew settings: a language profile currently makes
babelquarto's translated chapter list merge with the English list in this setup.
Translations are maintained separately, not synchronized
automatically. The initial Hebrew text is a draft for editorial review.
