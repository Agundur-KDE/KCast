#!/usr/bin/env python3

import dbus
import dbus.service
import dbus.mainloop.glib
from gi.repository import GLib
import pychromecast


class KCastService(dbus.service.Object):
    def __init__(self, bus, path="/org/kcast/Player"):
        super().__init__(bus, path)
        self.chromecasts = []
        self.selected_index = 0

    @dbus.service.method("org.kcast.Player",
                    in_signature='', out_signature='a(ss)')
    def listDevices(self):
        self.chromecasts, _ = pychromecast.get_chromecasts()
        return [(cast.name, "") for cast in self.chromecasts]


    @dbus.service.method("org.kcast.Player", in_signature='i')
    def setSelectedDeviceIndex(self, index):
        self.selected_index = index
        print(f"✅ Gerät ausgewählt: {self.chromecasts[index].name}")

    @dbus.service.method("org.kcast.Player", in_signature='s')
    def play(self, url):
        cast = self.chromecasts[self.selected_index]
        cast.wait()
        mc = cast.media_controller
        mc.play_media(url, "video/mp4")
        mc.block_until_active()
        mc.play()
        print("▶️ Wiedergabe gestartet.")

    @dbus.service.method("org.kcast.Player")
    def pause(self):
        self.chromecasts[self.selected_index].media_controller.pause()

    @dbus.service.method("org.kcast.Player")
    def stop(self):
        self.chromecasts[self.selected_index].media_controller.stop()


def main():
    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    session_bus = dbus.SessionBus()
    if session_bus.name_has_owner("org.kcast.Controller"):
        print("🔁 D-Bus bereits aktiv")
        sys.exit(0)

    name = dbus.service.BusName("org.kcast.Controller", session_bus)
    service = KCastService(session_bus)
    print("READY")
    GLib.MainLoop().run()


if __name__ == "__main__":
    main()
