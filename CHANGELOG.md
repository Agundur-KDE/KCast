# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.4.0] – 2026-08-30

### Added

- Manual device entry in the cast target picker: the device field now
  accepts a typed name or IP as a fallback for when `catt scan` doesn't
  find a reachable device (a known `catt` discovery issue, see #23/#24).

## [0.3.1] – 2026-07-30

### Fix

- Drag-and-drop in the full representation didn't work at all: the DropArea
  had no z-index, so it sat behind the playlist/URL field and never
  received drags over any visible control.
- Dropped URLs are QUrl objects, not strings — a follow-up TypeError once
  the drop actually landed, crashing silently (journal-only, not shown in
  the UI).

---

## [0.3.0] – 2025-08-20

### Added

- A new Volume-Slider and volume adjustment with mouse wheel
- Dolphin servicemenu for mediafiles "Play with KCast"


## Fix

- chromecast discovery would time out with a lot of chromecast devices
- small bugfixes

---

## [0.2.1] – 2025-07-25

### Added

🇩🇪 German
🇳🇱 Dutch (thanks to Vistaus Heimen Stoffels!)
🇫🇷 French
🇪🇸 Spanish
🇷🇺 Russian

---

## [0.2.0] – 2025-07-23

### Added

+- A new "Open" button for media files to allow quick playback selection.
- A "Network" configuration section with support for setting a default Chromecast device.
- Internationalization (i18n) support with proper file structure.
- German translation added as the first supported language alongside English (default).

---

## [0.1.0] – 2025-06-26

### Initial Release
- First public release of the Plasmoid, including basic Chromecast device detection and media casting via `catt`.
