# Live desktop-to-Chromecast cast — research notes

Goal: extend KCast to livestream the KDE Wayland desktop to a Chromecast
device in real time (e.g. "cast my screen to the beamer/projector"),
not just cast pre-existing media files like KCast does today.

## Confirmed working

- **Record-then-cast**: Spectacle (`spectacle -R s -o <file> -n`, real
  xdg-desktop-portal ScreenCast + PipeWire) produces a valid MP4.
  `catt -d "JMGO N1S Pro 4K" cast <file>` plays it back correctly —
  visually confirmed on the real device.
- Casting a still-being-written plain MP4 fails: Chromecast shows its
  idle blue Cast-logo, never renders anything, because the MP4 `moov`
  atom genuinely doesn't exist until a clean recording stop.
- GNOME already solves the live case via `Shell.Recorder` (no portal
  needed, GNOME Shell IS the compositor) → `videorate` → `x264enc` →
  HLS. KDE/KWin has no equivalent — this is a real, confirmed KDE-Plasma
  gap, not a saturated space.
- `ffmpeg` has **no** native PipeWire capture in any officially released
  version (checked directly: `ffmpeg -filters/-devices/-h full`, no
  pipewire refs; also checked FFmpeg's own GitHub Changelog up to
  n7.1.4, zero "pipewire" mentions). The real patch is FFmpeg trac
  ticket #10742 (`pipewiregrab`), still unmerged upstream as of
  2026-08. GStreamer's `pipewiresrc` is the stable, released option.
- `x264enc` needs Packman's `gstreamer-plugins-ugly-codecs` specifically
  (openSUSE OSS's plain `gstreamer-plugins-ugly` doesn't ship the real
  libx264-linked element). `openh264enc`'s codec .so wasn't loadable.
  `vulkanh264enc` (against a Radeon RX 6650 XT / RADV NAVI23) reached
  PLAYING but SIGSEGV'd shortly after — immature Mesa RADV Vulkan Video
  encode, not pursued further.
- Must force `video/x-raw,format=I420` before `x264enc`, or it
  auto-selects `yuv444p` ("High 4:4:4 Predictive") which no consumer
  hardware decoder (incl. Chromecast) supports. `yuv420p`/"High" is the
  target, confirmed via `ffprobe`.
- Python's stdlib `mimetypes` maps `.ts` → `text/x-texmacs` (real
  collision with the TeXmacs format), not `video/mp2t` — needed a
  custom `http.server` with an `extensions_map` override
  (`hls_server.py`).
- A stray `#EXT-X-ENDLIST` tag can appear in the served playlist if
  it's read from an already-exited capture process — only test against
  a freshly-started, still-running capture.

## The actual stuck point

With every layer above verified correct (curl: correct content-types,
no ENDLIST, sliding-window live playlist; ffprobe: yuv420p/High), this
still doesn't work:

```
catt -d "JMGO N1S Pro 4K" cast --stream-type live -f http://<local-ip>:<port>/stream.m3u8
```

Chromecast briefly shows the media title, then falls back to its idle
blue Cast-logo screen. Never renders a frame.

**Ruled out for a different reason** (not a fix): wrapping the media
playlist in a hand-written HLS *master* playlist (`#EXT-X-STREAM-INF`)
makes `catt` itself fail earlier, during its own format-probing, with
"Error: No suitable format was found" — a `catt`-side failure, distinct
from the Chromecast-side title-then-idle-screen failure. Don't confuse
the two.

## Next steps (not yet tried as of 2026-08-03)

- Does the Chromecast's default media receiver actually advertise HLS
  support, or does `catt`'s generic `cast -f <url>` path target a
  receiver that expects DASH/plain-MP4/WebM instead? (pychromecast's
  `controllers.media`/`quick_play` is the place to check what
  Cast Application ID + `contentType` actually get sent in the LOAD
  message for a `.m3u8` URL.)
- Test the exact same HLS URL in a plain desktop/mobile browser FIRST —
  cheapest way to isolate "is the HLS stream itself even valid" from
  "is this a Chromecast/receiver-specific problem."
- Try `#EXT-X-PLAYLIST-TYPE:EVENT` instead of a plain sliding window.
- Chromecast-side debug logging if reachable at all.

A neutral fresh-context audit (Opus, no inherited bias toward the ideas
above) was dispatched 2026-08-03 to research `catt`/pychromecast's
actual LOAD-message construction and known Google Cast HLS receiver
quirks — check for its findings before re-deriving these from scratch
again.

## Usage

```bash
python3 portal_screencast.py /tmp/hls      # starts capture, will prompt a portal consent dialog once
python3 hls_server.py /tmp/hls 8090        # separate terminal, serves the output
catt -d "<device name>" cast --stream-type live -f http://<this-machine-ip>:8090/stream.m3u8
```
