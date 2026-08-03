#!/usr/bin/env python3
"""
xdg-desktop-portal ScreenCast handshake -> PipeWire fd -> gst-launch child.

Reconstructed from an earlier session (scripts lived only in /tmp/, never
committed, lost on reboot) — this is the second attempt at the same
pipeline, being committed this time regardless of whether it ends up
working, per explicit user request ("diesmal im Branch ablegen egal
welcher Stand am Schluss").

Confirmed-working facts from the last session, preserved here as comments
since they cost real debugging time to (re)discover:

- The fd from OpenPipeWireRemote is only meaningful inside the process
  that received it. Writing the raw fd number to a file and reusing it in
  a separately-launched gst-launch-1.0 process crashes PipeWire/SPA
  ("source->loop == &impl->loop' failed ... remove_from_poll()") because
  the fd number is unrelated garbage in the new process's own fd table.
  Fix: launch gst-launch-1.0 as a DIRECT CHILD of this process via
  subprocess.Popen(pass_fds=[fd]), keeping the fd valid across exec.
- x264enc needs Packman's gstreamer-plugins-ugly-codecs specifically —
  openSUSE OSS's plain gstreamer-plugins-ugly does not ship the actual
  libx264-linked encoder element.
- Force `video/x-raw,format=I420` before x264enc, or it auto-selects
  yuv444p ("High 4:4:4 Predictive") which no consumer hardware decoder
  (incl. Chromecast) supports. yuv420p/"High" profile is the target.
"""
import sys
import subprocess

import dbus
import dbus.mainloop.glib
from gi.repository import GLib

PORTAL_BUS_NAME = "org.freedesktop.portal.Desktop"
PORTAL_OBJECT_PATH = "/org/freedesktop/portal/desktop"
SCREENCAST_IFACE = "org.freedesktop.portal.ScreenCast"
REQUEST_IFACE = "org.freedesktop.portal.Request"

# ponytail: module-level counter for unique handle tokens, a real app would
# use something less collision-prone (random suffix) — fine for a one-shot
# scratch script run by a single user.
_token_counter = 0


def next_token(prefix):
    global _token_counter
    _token_counter += 1
    return f"{prefix}_{_token_counter}"


class PortalScreenCast:
    def __init__(self, mainloop, bus):
        self.mainloop = mainloop
        self.bus = bus
        self.portal = bus.get_object(PORTAL_BUS_NAME, PORTAL_OBJECT_PATH)
        self.screencast = dbus.Interface(self.portal, SCREENCAST_IFACE)
        self.session_handle = None
        self.node_id = None
        self.pw_fd = None

    def _sender_token(self):
        # The portal's Request/Session object paths embed the CALLER's
        # unique bus name (colon stripped, dots -> underscores) — needed
        # to construct the request object path to subscribe to before
        # the method reply even arrives.
        return self.bus.get_unique_name()[1:].replace(".", "_")

    def _subscribe_request(self, handle_token, on_response):
        path = f"/org/freedesktop/portal/desktop/request/{self._sender_token()}/{handle_token}"
        self.bus.add_signal_receiver(
            on_response,
            signal_name="Response",
            dbus_interface=REQUEST_IFACE,
            path=path,
        )

    def create_session(self):
        session_token = next_token("session")
        handle_token = next_token("request")
        self._subscribe_request(handle_token, self._on_session_created)
        self.screencast.CreateSession(
            {
                "session_handle_token": session_token,
                "handle_token": handle_token,
            }
        )

    def _on_session_created(self, response, results):
        if response != 0:
            print(f"CreateSession failed, response={response}", file=sys.stderr)
            self.mainloop.quit()
            return
        self.session_handle = results["session_handle"]
        print(f"session: {self.session_handle}")
        self.select_sources()

    def select_sources(self):
        handle_token = next_token("request")
        self._subscribe_request(handle_token, self._on_sources_selected)
        self.screencast.SelectSources(
            self.session_handle,
            {
                "handle_token": handle_token,
                "types": dbus.UInt32(1),  # 1 = MONITOR (whole screen), 2 = WINDOW
                "multiple": False,
                "cursor_mode": dbus.UInt32(2),  # 2 = embedded (cursor baked into frames)
            },
        )

    def _on_sources_selected(self, response, results):
        if response != 0:
            print(f"SelectSources failed, response={response}", file=sys.stderr)
            self.mainloop.quit()
            return
        self.start()

    def start(self):
        handle_token = next_token("request")
        self._subscribe_request(handle_token, self._on_started)
        self.screencast.Start(
            self.session_handle,
            "",  # parent_window, empty = no parent
            {"handle_token": handle_token},
        )

    def _on_started(self, response, results):
        if response != 0:
            print(f"Start failed, response={response} (user likely cancelled the consent dialog)", file=sys.stderr)
            self.mainloop.quit()
            return
        streams = results["streams"]
        if not streams:
            print("Start succeeded but no streams returned", file=sys.stderr)
            self.mainloop.quit()
            return
        self.node_id, props = streams[0]
        print(f"node_id: {self.node_id}, props: {dict(props)}")
        self.open_pipewire_remote()

    def open_pipewire_remote(self):
        # Direct method call, not the Request/Response pattern — the fd
        # comes back as a UnixFd in the method reply itself.
        fd_obj = self.screencast.OpenPipeWireRemote(self.session_handle, {})
        self.pw_fd = fd_obj.take()
        print(f"pipewire fd: {self.pw_fd}")
        self.launch_gstreamer()

    def launch_gstreamer(self):
        out_dir = sys.argv[1] if len(sys.argv) > 1 else "/tmp/hls"
        import os
        os.makedirs(out_dir, exist_ok=True)
        # hlssink2 has request pads named "video"/"audio" (ANY caps) and
        # muxes to MPEG-TS + segments internally — it wants the raw
        # parsed h264 elementary stream directly, NOT an already-muxed
        # mpegtsmux output (that's what the first attempt got wrong,
        # "mpegtsmux0 konnte nicht mit hlssink2-0 verknüpft werden").
        # Explicit `sink.video` + `name=sink` because gst-launch can't
        # auto-pick between the two identically-ANY-typed request pads.
        # Added after the video-only stream reached the Chromecast
        # correctly (200 OK on playlist + segments, confirmed via the
        # server's own access log) but still failed to play — a
        # neutral audit flagged missing audio as a real, plausible
        # blocker (Cast/Shaka can be stricter about audio-less content
        # than ffplay), and it's cheap to rule out: silent AAC track,
        # not real desktop audio yet.
        pipeline = [
            "gst-launch-1.0", "-e",
            "pipewiresrc", f"fd={self.pw_fd}", f"path={self.node_id}",
            "!", "videoconvert",
            "!", "video/x-raw,format=I420",
            "!", "x264enc", "tune=zerolatency", "speed-preset=ultrafast", "bitrate=4000", "key-int-max=30",
            "!", "h264parse",
            "!", "sink.video",
            "hlssink2", "name=sink",
            f"playlist-location={out_dir}/stream.m3u8",
            f"location={out_dir}/segment%05d.ts",
            "target-duration=2",
            "max-files=6",
            "playlist-length=4",
            "audiotestsrc", "wave=silence", "is-live=true",
            "!", "audioconvert",
            "!", "audioresample",
            "!", "fdkaacenc",
            "!", "aacparse",
            "!", "sink.audio",
        ]
        print("launching:", " ".join(pipeline))
        # pass_fds keeps exactly this fd open across exec in the child —
        # everything else Python opened gets closed as usual (close_fds
        # defaults to True). This is the fix for the fd-in-separate-
        # process crash from last session.
        proc = subprocess.Popen(pipeline, pass_fds=[self.pw_fd])
        try:
            proc.wait()
        except KeyboardInterrupt:
            proc.terminate()
            proc.wait()
        self.mainloop.quit()

    def run(self):
        self.create_session()
        self.mainloop.run()


def main():
    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    bus = dbus.SessionBus()
    mainloop = GLib.MainLoop()
    portal = PortalScreenCast(mainloop, bus)
    portal.run()


if __name__ == "__main__":
    main()
