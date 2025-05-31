
<div align="center">
  <h1>KCast</h1> <p><strong>Version: 0.2.0</strong></p>
  <a href="https://kde.org/de/">
  <img src="https://img.shields.io/badge/KDE_Plasma-6.1+-blue?style=flat&logo=kde" alt="KCast">
</a>
 <a href="https://www.gnu.org/licenses/gpl-3.0.html">
  <img src="https://img.shields.io/badge/License-GPLv3-blue.svg" alt="License: GPLv3">
</a>
  <a href="https://paypal.me/agundur">
  <img src="https://img.shields.io/badge/donate-PayPal-%2337a556" alt="PayPal">
</a>
  </a>
  <a href="https://store.kde.org/p/2290729">
  <img src="https://img.shields.io/badge/KDE%20Plasma-1D99F3?logo=kdeplasma&logoColor=fff" alt="kdeplasma">
</a></div>



## Description
**KCast** **Version:** 0.2.0 is a KDE Plasma 6 widget that lets you cast video files or youtube URLs to a  Chromecast devices in your local network.
It supports device discovery, local media playback via an embedded HTTP server, and drag-and-drop integration with browsers and file managers like Dolphin.

**Caution!** starting with version 0.2.0 we need [catt](https://github.com/skorokithakis/catt) installed.


## 📦 Features

- 📡 **Chromecast discovery** using Avahi (mDNS)
- ▶️ **Media playback controls**: Play, Pause, Resume, Stop
- 📂 **Support for local media files** via built-in HTTP server
- 🧲 **Drag & Drop** from Firefox, Chrome, or Dolphin


## Visuals
![KCast Plasmoid](KCast.png)
![KCast Plasmoid config](KCast_ready.png)


## Installation


mkdir build && cd build

cmake ..

make

make install (as root)


or

download kcast-complete.tar.gz

$ sudo tar -xf kcast-complete.tar.gz -C /

## 🧠 Dependencies

To run KCast successfully, the following software must be installed:

### Required

KCast is based on:

- [catt](https://github.com/skorokithakis/catt)

  $ pipx install catt

- [Python 3](https://www.python.org/)

- Avahi Daemon – for local network device discovery (mDNS) (systemctl status avahi-daemon)



Networking & Firewall:


- Your PC and the Chromecast must be on the same LAN

- mDNS must be allowed through the firewall

- The internal HTTP server uses TCP port 8000 to serve local files

To allow via firewalld:
_______________________

- sudo firewall-cmd --permanent --add-service=mdns
- sudo firewall-cmd --permanent --add-port=8009/tcp
- sudo firewall-cmd --reload

- For the casting of local files to work you need to allow in the port range 45000-47000 over tcp.

## Usage

- Switch on a chromecast enabled device in your locale network.
- drop a video file from Dolphin and/or Web-Browser on it an hit "play"

## Support

- tail -f ~/.local/share/kcast.log

- Open an issue in git ...

[KCast Issues](https://www.opencode.net/agundur/kcast/-/issues)


## Roadmap

- Add config options like default devie
- Try add youtube support


## Contributing
accepting contributions ...

[KCast](https://www.opencode.net/agundur/kcast)


## Authors and acknowledgment
Alec

## License
GPL


## Project status
active
