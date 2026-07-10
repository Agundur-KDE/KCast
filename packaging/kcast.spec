Name:           kcast
Version:        0.2.14
Release:        1%{?dist}
URL:            https://github.com/Agundur-KDE/KCast
Summary:        Cast media to Chromecast from KDE Plasma (Plasmoid + C++ plugin)
License:        GPL-3.0-or-later
Source0: _service

BuildRequires:  cmake
BuildRequires:  gcc-c++
BuildRequires:  extra-cmake-modules
BuildRequires:  qt6-base-devel
BuildRequires:  qt6-declarative-devel
BuildRequires:  qt6-tools-devel
BuildRequires:  kf6-ki18n-devel

Requires:       catt
Requires:       plasma6-workspace

%description
KCast is a KDE Plasma 6 applet (plasmoid) with a C++ plugin to cast local/remote media
to Google Chromecast devices using the `catt` CLI.

%prep

rm -rf ./*

shopt -s nullglob
picked=""
for d in %{_sourcedir}/kcast-* %{_sourcedir}/KCast-* %{_sourcedir}/kcast ; do
  if [ -d "$d" ] && [ -f "$d/CMakeLists.txt" ]; then
    picked="$d"
    break
  fi
done

if [ -n "$picked" ]; then
  cp -a "$picked"/. .
else
  for f in %{_sourcedir}/* ; do
    base="$(basename "$f")"
    case "$base" in
      *.spec|*.dsc|*.changes|*.obsinfo|_service|service_attic|screenshot|*.patch)
        continue ;;
    esac
    cp -a "$f" .
  done
fi

%build
%cmake \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DKDE_INSTALL_USE_QT_SYS_PATHS=ON \
  -DKDE_INSTALL_QMLDIR=%{_qt6_qmldir} \
  -DKDE_INSTALL_PLUGINDIR=%{_qt6_plugindir}
%cmake_build

%install
%cmake_install
%files
%license LICENSE
%doc README.md
%{_datadir}/plasma/plasmoids/de.agundur.kcast/
%dir %{_qt6_qmldir}/de
%dir %{_qt6_qmldir}/de/agundur
%{_qt6_qmldir}/de/agundur/kcast/
%dir %{_datadir}/kio
%dir %{_datadir}/kio/servicemenus
%{_datadir}/kio/servicemenus/kcast_stream.desktop
%{_datadir}/locale/*/LC_MESSAGES/plasma_applet_*.agundur.kcast.mo

%changelog
* Fri Jul 10 2026 Alec <info@agundur.de> - 0.2.14-1
- Fixed "KCastBridge is not a type" applet load failure: main.qml uses
  KCastBridge directly in compactRepresentation but never imported
  de.agundur.kcast — dropped during a refactor over a year ago (commit
  e32116f, "about to rebuild") and never caught because a stale local
  dev copy in ~/.local/share/plasma/plasmoids/ kept shadowing the real
  installed file on this machine the whole time.

* Fri Jul 10 2026 Alec <info@agundur.de> - 0.2.13-1
- Fixed unresolvable zypper dependency: "Requires: plasma-workspace >= 6"
  doesn't exist as a package name on openSUSE — that distro's package is
  called plasma6-workspace (matching kfritz's spec). Every zypper install
  was failing with "nichts stellt 'plasma-workspace >= 6' bereit".

* Thu Jul 09 2026 Alec <info@agundur.de> - 0.2.12-1
- Fixed rpmlint "directories not owned by a package" for the QML install
  path: added dir ownership markers for the qmldir parent directories
  and switched to the qt6 qmldir macro (was a hardcoded libdir path).

* Thu Jul 09 2026 Alec <info@agundur.de> - 0.2.11-1
- Fixed %changelog itself: the v0.2.9 entry had a line starting with
  "%prep" (mid-sentence, after indentation) — rpm's section-boundary
  scanner mistook it for an actual %prep section marker even inside
  %changelog body text, and everything from there through the next few
  entries got swallowed into %files as bogus "file" tokens ("File must
  begin with '/'" for every word). Reworded. Verified this time with
  `rpmspec --parse` locally before pushing, not just eyeballing it.

* Thu Jul 09 2026 Alec <info@agundur.de> - 0.2.10-1
- Fixed %build: openSUSE's %cmake macro already does mkdir+cd build and
  passes the correct source dir implicitly — the spec's own extra
  "-S ." got appended after it and pointed cmake at the build/
  directory itself instead of the project root ("does not appear to
  contain CMakeLists.txt"). Removed, matching kfritz/KClaude's %build.

* Thu Jul 09 2026 Alec <info@agundur.de> - 0.2.9-1
- Fixed source unpacking: still used the old tar_scm-era Source0
  pattern (fixed GitHub-release tarball URL/name), incompatible with
  obs_scm — v0.2.8's build failed because rpmbuild looked for a
  tarball name that obs_scm never produces. Now Source0: _service plus
  the same source-directory auto-detection already proven working on
  kfritz/KClaude.

* Thu Jul 09 2026 Alec <info@agundur.de> - 0.2.8-1
- Fixed BuildRequires: qt6-qtbase-devel etc. are Fedora package names,
  don't exist on openSUSE (qt6-base-devel etc.) — v0.2.7's OBS build
  was unresolvable on both architectures because of this

* Thu Jul 09 2026 Alec <info@agundur.de> - 0.2.7-1
- Fixed install(DIRECTORY package/...) shipping raw C++ source/CMakeLists
  as installed plasmoid data
- Fixed panel-icon scroll-to-change-volume (referenced a QML id that
  doesn't exist in that scope, threw a ReferenceError every time)
- Fixed dead cursor styling and a non-existent scanDevicesWithCatt()
  call in Settings' device search button
- Fixed the bridge's mediaUrl going stale after a drag-and-drop or
  file-picker selection
- Removed dead/never-installed log message handler
- README: fixed a broken link, several typos, stale version banners,
  removed expired Amazon affiliate links, corrected the local-file
  firewall port range (45000-47000, not 8000)
- Added an OBS RPM build pipeline (previously .deb only)

* Mon Jun 22 2026 Alec <info@agundur.de> - 0.2.6-1
- Add Catalan localization
* Sun Jun 21 2026 Alec <info@agundur.de> - 0.2.5-1
- Remember volume per device, fix default device always shown, clean button state machine
* Wed Aug 13 2025 Alec <info@agundur.de> - 0.2.1-1
- Initial Fedora/Copr build
