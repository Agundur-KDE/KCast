#!/usr/bin/env python3
"""
Cast an HLS URL to a Chromecast directly via pychromecast, bypassing catt.

catt's own content-type guessing is structurally wrong for HLS: for a
.m3u8 URL, stream_info.py's guessed_content_type() returns None (yt-dlp's
generic extractor never sets info['direct'] for m3u8 — it branches into
_extract_m3u8_formats_and_subtitles() instead), so controllers.py falls
back to content_type = kwargs.get("content_type") or "video/mp4". The
Chromecast's Default Media Receiver picks its playback engine from that
MIME string and, told "video/mp4", tries to parse the HLS text playlist
as an MP4 container — fails instantly, falls back to the idle screen.
There's no catt CLI flag to override this (checked cli.py, no
--content-type option exists).

Usage: python3 cast_hls.py "<device name>" <hls-url>
"""
import sys
import time
import logging

import pychromecast

# detailedErrorCode on a LOAD_FAILED message is only ever logged at DEBUG
# level inside pychromecast's MediaController (media.py:_process_load_failed)
# — never exposed as a status attribute — so this is the only way to see it.
logging.basicConfig(level=logging.DEBUG, format="%(name)s: %(message)s")
logging.getLogger("pychromecast").setLevel(logging.DEBUG)


def main():
    if len(sys.argv) != 3:
        print("usage: cast_hls.py <device name> <hls-url>", file=sys.stderr)
        sys.exit(1)
    device_name, url = sys.argv[1], sys.argv[2]

    chromecasts, browser = pychromecast.get_listed_chromecasts(friendly_names=[device_name])
    if not chromecasts:
        print(f"no device named {device_name!r} found", file=sys.stderr)
        sys.exit(1)
    cc = chromecasts[0]
    cc.wait()

    # Force a clean state before loading — whatever app was previously
    # active (YouTube, a leftover session, ...) stays the target of
    # media_controller otherwise, and play_media's own auto-launch
    # behavior for a DIFFERENT receiver app isn't something to rely on.
    if cc.app_id is not None:
        print(f"quitting currently active app {cc.app_id!r} first")
        cc.quit_app()
        time.sleep(2)

    mc = cc.media_controller
    mc.play_media(
        url,
        "application/x-mpegurl",
        stream_type="LIVE",
        media_info={
            "hlsSegmentFormat": "ts",
            "hlsVideoSegmentFormat": "mpeg2_ts",
        },
    )
    mc.block_until_active(timeout=10)
    print("player_state:", mc.status.player_state)
    print("idle_reason:", mc.status.idle_reason)

    # Keep polling status for a bit so we actually see whether it
    # transitions to PLAYING or bounces back to IDLE, instead of just
    # reporting whatever the very first status snapshot happened to be.
    for _ in range(15):
        time.sleep(1)
        print("status:", mc.status.player_state, "idle_reason:", mc.status.idle_reason)

    browser.stop_discovery()


if __name__ == "__main__":
    main()
