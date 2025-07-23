
<div align="center">

<img src="/package/contents/icons/Logo.png" width="80" alt="KCast Logo" /> 
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

<noscript><a href="https://liberapay.com/Agundur/donate"><img alt="Donate using Liberapay" src="https://liberapay.com/assets/widgets/donate.svg"></a></noscript>
</a></div>


## Description
**KCast** **Version:** 0.2.0 is a KDE Plasma 6 widget that lets you cast video files or youtube URLs to a  Chromecast devices in your local network.
It supports device discovery, local media playback via an embedded HTTP server, and drag-and-drop integration with browsers and file managers like Dolphin.

**Caution!** starting with version 0.0.2 we need [catt](https://github.com/skorokithakis/catt) installed.

## 🏠 Homepage

📦 [https://github.com/Agundur-KDE/KCast](https://github.com/Agundur-KDE/KCast)

## 📦 Features

- 📡 **Chromecast discovery** using Avahi (mDNS)
- ▶️ **Media playback controls**: Play, Pause, Resume, Stop
- 📂 **Support for local media files** via built-in HTTP server
- 🧲 **Drag & Drop** from Firefox, Chrome, or Dolphin


## Visuals
![KCast Plasmoid](KCast2.png)
![KCast Plasmoid config](KCast_ready.png)


## Installation

**system wide installation**

mkdir build && cd build

cmake ..

make

make install (as root) 


## 🛠️ Installing KCast via the openSUSE Build Service Repository

[![build result](https://build.opensuse.org/projects/home:Agundur/packages/kcast/badge.svg?type=default)](https://build.opensuse.org/package/show/home:Agundur/kcast)

For openSUSE Tumbleweed (and compatible systems):

```bash
# Add the repository
sudo zypper ar -f https://download.opensuse.org/repositories/home:/Agundur/openSUSE_Tumbleweed/home:Agundur.repo

# Automatically import GPG key (required once)
sudo zypper --gpg-auto-import-keys ref

# Refresh repository metadata
sudo zypper ref

# Install KCast
sudo zypper in kcast
```

## KCast Runtime Installer

This archive contains everything needed to install the **KCast Plasmoid** and its corresponding **QML plugin** on a KDE Plasma system.

# 📦 Content

The package [kcast-installer-package.tar.gz](https://github.com/Agundur-KDE/KCast/blob/0bf6487cc080849a661de4ef5ee7049a539cf03b/kcast-installer-package.tar.gz) includes:

- `kcast-runtime.tar.gz`: Contains the compiled `.so`, `qmldir`, and QML files
- `installer.sh`: Installs everything into the appropriate user directories

# ✅ Requirements

- KDE Plasma 6.x
- Qt 6.x runtime
- Tar, Bash, and basic command-line tools

> 📝 Needs testing on Fedora Silverblue, Bazzite

# 🚀 Installation

```bash
tar xzf kcast-installer-package.tar.gz

./installer.sh

```


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



## Tested Hardware

KCast has been tested successfully with the 

🛒[JMGO N1S Pro 4K Triple Laser Projector](https://amzn.to/43SSX1U) (Affiliate link).

This projector supports high-quality Chromecast streaming and works reliably with KCast.
Using this link helps support the development of KCast at no additional cost to you.

🛒[Samsung HW-Q935GD 9.1.4-Kanal Q-Soundbar](https://amzn.to/4enDRX7) (Affiliate link).


## Support



- Open an issue in git ...

[KCast Issues](https://github.com/Agundur-KDE/KCast/issues)


## Roadmap

- Add config options like default devie
- Try add youtube support


## Contributing
accepting contributions ...

[KCast](hhttps://github.com/Agundur-KDE/KCast)


## Authors and acknowledgment
Alec

## License
GPL


## Project status
active
