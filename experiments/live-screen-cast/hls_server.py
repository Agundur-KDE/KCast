#!/usr/bin/env python3
"""
Minimal HTTP server for the HLS output directory, with correct MIME types.

Needed because Python's stdlib `mimetypes` module maps the `.ts` extension
to `text/x-texmacs` (a real, bizarre collision with the TeXmacs file
format) instead of `video/mp2t` — every segment would look like an
invalid file type to a Chromecast without this override. Confirmed via
curl last session that this fix alone was sufficient to get correct
content-types end to end.
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
        super().end_headers()


if __name__ == "__main__":
    with socketserver.TCPServer(("0.0.0.0", PORT), HLSHandler) as httpd:
        print(f"serving {DIRECTORY} on 0.0.0.0:{PORT}")
        httpd.serve_forever()
