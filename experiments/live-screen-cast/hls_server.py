#!/usr/bin/env python3
"""
Minimal HTTP server for the HLS output directory, with correct MIME types
and the CORS + Range support Google Cast's adaptive-streaming (Shaka
Player) path requires.

Two separate real bugs fixed here, found across two sessions:
- Python's stdlib `mimetypes` module maps the `.ts` extension to
  `text/x-texmacs` (a real, bizarre collision with the TeXmacs file
  format) instead of `video/mp2t` — every segment would look like an
  invalid file type to a Chromecast without this override.
- Google's own docs: "For adaptive media streaming, Google Cast requires
  the presence of CORS headers" (Content-Type, Accept-Encoding, Range).
  `http.server.SimpleHTTPRequestHandler` sends none of these and has no
  Range/206 support at all — curl-based checks never caught this because
  curl doesn't send an Origin header, but Shaka Player's fetch() from the
  receiver's gstatic origin does.
"""
import sys
import http.server
import socketserver

PORT = int(sys.argv[2]) if len(sys.argv) > 2 else 8090
DIRECTORY = sys.argv[1] if len(sys.argv) > 1 else "/tmp/hls"


class HLSHandler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {
        **http.server.SimpleHTTPRequestHandler.extensions_map,
        ".ts": "video/mp2t",
        ".m3u8": "application/vnd.apple.mpegurl",
    }

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)

    def end_headers(self):
        # Live playlists must never be cached — a stale .m3u8 served to
        # the Chromecast would make it request already-evicted segments.
        self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "Range, Origin, Content-Type, Accept")
        self.send_header("Access-Control-Expose-Headers", "Content-Length, Content-Range")
        self.send_header("Accept-Ranges", "bytes")
        super().end_headers()

    def do_OPTIONS(self):
        # CORS preflight — Shaka Player sends this before the real GET.
        self.send_response(204)
        self.end_headers()

    def do_GET(self):
        # ponytail: whole-file Range only (start-, no multi-range) — every
        # segment here is one short .ts file, Shaka doesn't need partial
        # mid-segment fetches for this use case, just the header to exist.
        range_header = self.headers.get("Range")
        if not range_header:
            return super().do_GET()

        path = self.translate_path(self.path)
        try:
            with open(path, "rb") as f:
                data = f.read()
        except OSError:
            self.send_error(404)
            return

        total = len(data)
        try:
            start_s, end_s = range_header.replace("bytes=", "").split("-")
            start = int(start_s) if start_s else 0
            end = int(end_s) if end_s else total - 1
        except ValueError:
            self.send_error(400)
            return

        chunk = data[start : end + 1]
        self.send_response(206)
        self.send_header("Content-Type", self.guess_type(path))
        self.send_header("Content-Range", f"bytes {start}-{end}/{total}")
        self.send_header("Content-Length", str(len(chunk)))
        self.end_headers()
        self.wfile.write(chunk)


if __name__ == "__main__":
    with socketserver.TCPServer(("0.0.0.0", PORT), HLSHandler) as httpd:
        print(f"serving {DIRECTORY} on 0.0.0.0:{PORT}")
        httpd.serve_forever()
