# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.4.3] – 2026-08-31

### Fix

- Panel/taskbar icon disappeared again after the 0.4.2 packaging fix
  (#26) — the 0.4.1 fix relied on registering the icon in the system
  icon theme via CMake, which only works for RPM/deb installs; a plain
  `.plasmoid` install (KDE Store, `kpackagetool6 -i`) never touches the
  system icon theme, so the panel icon rendered blank/generic there.
  Switched to KPackage's package-relative icon notation
  (`/icons/<file>`), which works regardless of install method.
  Two follow-on fixes found while testing this: `Kirigami.Icon` doesn't
  resolve that package-relative notation itself (only some Plasma-native
  surfaces do — resolved manually via `Qt.resolvedUrl()`), and
  `Kirigami.Icon`'s automatic monochrome-icon heuristic misjudged the
  multi-color logo and rendered it as a solid-color mask — switched to a
  plain `Image` element instead. Also fixed the wrong icon asset being
  referenced (a solid-black, unused SVG instead of the real PNG).
  Removes the now-unnecessary system-icon-theme install from CMake/spec.

## [0.4.2] – 2026-08-30

### Fix

- v0.4.1's OBS/RPM build failed silently on the release side (new icon
  file not listed in the RPM spec's %files), and `build-deb` had been
  uploading a stale-versioned .deb (still 0.3.1-1, from an outdated
  debian/changelog) under that release without erroring. Both fixed;
  no functional changes over 0.4.1.

## [0.4.1] – 2026-08-30

### Fix

- Manual device entry (0.4.0) didn't actually work: the config page's
  editable field never marked the config as changed, so Apply/OK
  silently did nothing. Typing a device also didn't show up in an
  already-open widget popup, since the popup's internal `defaultDevice`
  had permanently lost its live binding to the config the first time a
  device was ever selected.
- The panel/taskbar icon showed a generic placeholder ("beamer") icon
  instead of the actual KCast logo — the bundled logo was never
  registered in the system icon theme.

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
