"""Watch and preview the bilingual book using only Python's standard library."""

import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from io import BytesIO
import json
import os
from pathlib import Path
import subprocess
import threading
import time
from urllib.parse import urlsplit
import uuid
import webbrowser


ROOT = Path(__file__).resolve().parents[1]
IGNORED = {"docs", "_book", ".quarto", ".git", ".R-library", "__pycache__"}
EXTENSIONS = {
    ".qmd", ".md", ".yml", ".yaml", ".scss", ".css", ".html", ".js",
    ".r", ".py", ".lua", ".tex", ".bib", ".theme", ".png", ".jpg", ".jpeg",
    ".svg", ".gif", ".webp", ".pdf", ".csv", ".json", ".woff", ".woff2", ".ttf",
}


def snapshot():
    files = {}
    for directory, folders, names in os.walk(ROOT):
        folders[:] = [name for name in folders if name not in IGNORED and not name.startswith(".")]
        for name in names:
            path = Path(directory) / name
            if path.suffix.lower() not in EXTENSIONS or name.startswith("."):
                continue
            try:
                stat = path.stat()
                files[str(path)] = (stat.st_mtime_ns, stat.st_size)
            except FileNotFoundError:
                pass  # Editors may replace a file while saving it.
    return files


def render(changed=None):
    arguments = ["--init"] if changed is None else sorted(changed)
    try:
        result = subprocess.run(["Rscript", "scripts/preview-render.R", *arguments], cwd=ROOT)
    except FileNotFoundError:
        print("Rscript not found. Install R and run Rscript scripts/setup.R.", flush=True)
        return False
    if result.returncode:
        print("Build failed; keeping the previous preview. Save a correction to retry.", flush=True)
        return False
    return True


class PreviewHandler(SimpleHTTPRequestHandler):
    def log_message(self, format, *args):
        pass

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def send_head(self):
        if urlsplit(self.path).path == "/__preview_version":
            data = json.dumps(self.server.version).encode()
            content_type = "application/json"
        else:
            path = Path(self.translate_path(self.path))
            if path.is_dir():
                path = path / "index.html"
            if path.suffix != ".html" or not path.is_file():
                return super().send_head()
            script = """<script>
(() => {
  const version = VERSION;
  const key = 'units-preview-scroll:' + location.pathname;
  const saved = sessionStorage.getItem(key);
  if (saved !== null) {
    sessionStorage.removeItem(key);
    addEventListener('load', () => {
      const restore = () => scrollTo(0, Number(saved));
      restore();
      // Quarto's collapsing header can shift the layout after the first scroll.
      setTimeout(restore, 300);
    }, {once: true});
  }
  setInterval(async () => {
    try {
      const response = await fetch('/__preview_version', {cache: 'no-store'});
      if (response.ok && await response.json() !== version) {
        sessionStorage.setItem(key, String(scrollY));
        location.reload();
      }
    } catch (_) {} // Keep the page usable while the server restarts.
  }, 750);
})();
</script>""".replace("VERSION", json.dumps(self.server.version))
            data = path.read_bytes().replace(b"</body>", script.encode() + b"</body>")
            content_type = "text/html; charset=utf-8"
        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        return BytesIO(data)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=8001)
    parser.add_argument("--no-browser", action="store_true")
    args = parser.parse_args()
    handler = partial(PreviewHandler, directory=str(ROOT / ".quarto/bilingual-preview/site"))
    try:
        server = ThreadingHTTPServer(("127.0.0.1", args.port), handler)
    except OSError as error:
        parser.exit(1, f"Cannot start preview: {error}. Try --port with another port.\n")
    server.version = uuid.uuid4().hex
    serving = False
    try:
        previous = snapshot()
        if not render():
            return 1
        threading.Thread(target=server.serve_forever, daemon=True).start()
        serving = True
        url = f"http://localhost:{args.port}/en/"
        print(f"Preview: {url}\nWatching for saves. Press Ctrl+C to stop.", flush=True)
        if not args.no_browser:
            webbrowser.open(url)
        dirty = set()
        while True:
            time.sleep(0.5)
            current = snapshot()
            if current == previous:
                continue
            # Wait for a save burst to settle, and never run overlapping builds.
            time.sleep(0.4)
            current = snapshot()
            dirty.update(str(Path(path).relative_to(ROOT)) for path in previous.keys() | current.keys()
                         if previous.get(path) != current.get(path))
            previous = current
            if render(dirty):
                dirty.clear()
                server.version = uuid.uuid4().hex
                print("Preview updated. Watching for saves…", flush=True)
    except KeyboardInterrupt:
        print("\nPreview stopped.")
    finally:
        if serving:
            server.shutdown()
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
