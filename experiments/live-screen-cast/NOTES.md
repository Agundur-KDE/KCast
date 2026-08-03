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

## Update 2026-08-03, later same day: video works, audio doesn't

Video-only (no audio branch) casts cleanly: correct 4K image, no
macroblocking, live and smooth. Root causes found and fixed along the
way:

- **catt's own content-type guessing is wrong for HLS** (falls back to
  `video/mp4`) — bypassed entirely with a direct `pychromecast`
  script, `cast_hls.py`, that sets `content_type` explicitly.
- **Missing CORS + Range support** in `hls_server.py` — Google Cast
  requires them; curl-based checks never caught it (curl sends no
  Origin header). Also: `socketserver.TCPServer` (unlike
  `http.server.HTTPServer`) doesn't set `allow_reuse_address`, so
  restarting the server right after a Chromecast session leaves it
  unable to rebind for ~60s (TIME_WAIT) — fixed with a
  `ReusableTCPServer` subclass.
- **A completely audio-less stream is silently rejected** by the
  Default Media Receiver (title flashes, falls back to idle) — fixed
  first with a silent AAC placeholder track, later with real desktop
  audio (see below).
- **4K needs real bitrate**: 4000 kbit/s produced visible macroblocking;
  18000 kbit/s + `speed-preset=veryfast` (still `tune=zerolatency`)
  fixed it.
- **Capture is 60fps, not 30** (confirmed via `ffprobe`) — `key-int-max`
  should match the segment `target-duration` in frames for clean,
  evenly-sized segments (ragged 0.98/0.23/0.83s splits appeared with a
  mismatched GOP).
- Screen vs. window selection is just the portal's `types` bitmask
  (1=MONITOR, 2=WINDOW) in `SelectSources` — was hardcoded to
  monitor-only, now `3` so the consent dialog offers both.
- `hlssink2`'s `target-duration` is an **unsigned integer** property —
  `0.5` is rejected outright, not silently truncated.

**Real desktop audio (not just a silent placeholder) is still broken.**
Added a second `pipewiresrc` targeting the default sink's monitor
(`pactl get-default-sink` + `.monitor`, via `target-object=`, no portal
involved — portal ScreenCast is video-only). Confirmed the *capture
mechanism itself* works: an isolated `pipewiresrc → wavenc → filesink`
test with the same target while YouTube was actively playing (verified
un-paused via `pactl list sink-inputs`, `Corked: no`) measured
mean -45dB / max -34dB — real signal. But inside the combined
video+audio `gst-launch` pipeline, the same live moment measures
mean -62dB / max -52dB (near-silence) via `ffprobe`+`ffmpeg
volumedetect` on the actual served segments — and on the real device,
audibly silent even at a receiver volume so loud it's "Ohren fliegen
weg" (ears blown off) on this hardware at 50% (normal KCast usage is
~5%). Ruled out as an explanation: receiver volume (tested at both 11%
default and 50%), paused source (checked `Corked` state directly),
wrong sink target (confirmed via `pactl list sink-inputs` that Firefox's
YouTube stream really is on the sink we target). The video branch
appearing choppy ("Häppchen dann Pause") also only started once the
second live `pipewiresrc` was added — was fine, smooth, with only the
silent-placeholder `audiotestsrc` audio branch.

**Working hypothesis**: two concurrent `pipewiresrc` GStreamer elements
in one process don't coexist cleanly on this GStreamer/PipeWire plugin
version — likely a shared mainloop/thread contention between the two
independent PipeWire client connections (one via the portal-provided
fd, one via a plain default-socket connection), causing both dropped/
attenuated audio buffers AND video stutter once both are live at once.
Tried and ruled out as the cause: `leaky=downstream,max-size-buffers=2`
queues before the muxer pads (too small — starved `fdkaacenc`'s
1024-sample frame accumulation, made audio *worse*, not the root
cause) — replaced with plain default-sized `queue` elements, stutter
and quiet-audio persisted regardless.

## Next steps (not yet tried)

- Split video capture and audio capture into **two separate OS
  processes**, each with its own independent PipeWire connection, and
  mux their output downstream (e.g. each writes to a named pipe /
  local socket, a third process or `hlssink2` instance consumes both)
  — tests directly whether same-process dual-`pipewiresrc` contention
  is really the cause.
- If that fixes it: look into whether GStreamer's pipewiresrc supports
  distinct `client-name`s or explicit separate `pw_context`s that would
  let both streams coexist in one process after all (cheaper than two
  processes, if it works).
- Once audio really works: re-test the tightened HLS window
  (`target-duration=1`, `playlist-length=3`) for further latency gains
  — this was working well on the video-only smooth test, no reason to
  revisit unless the two-process split changes buffering behavior.

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
