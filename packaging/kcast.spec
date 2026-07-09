Name:           kcast
Version:        0.2.9
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
Requires:       plasma-workspace >= 6

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
%cmake -S . \
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
%{_libdir}/qt6/qml/de/agundur/kcast/
%dir %{_datadir}/kio
%dir %{_datadir}/kio/servicemenus
%{_datadir}/kio/servicemenus/kcast_stream.desktop
%{_datadir}/locale/*/LC_MESSAGES/plasma_applet_*.agundur.kcast.mo

%changelog
* Thu Jul 09 2026 Alec <info@agundur.de> - 0.2.9-1
- Fixed Source0/%prep: still used the old tar_scm-era pattern (fixed
  GitHub-release tarball URL/name), incompatible with obs_scm — v0.2.8's
  build failed because rpmbuild looked for a tarball name that obs_scm
  never produces. Now Source0: _service + the same directory-detection
  %prep already proven working on kfritz/KClaude.

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
