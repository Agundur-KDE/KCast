Name:           kcast
Version:        0.2.6
Release:        1%{?dist}
URL:            https://github.com/Agundur-KDE/KCast
Summary:        Cast media to Chromecast from KDE Plasma (Plasmoid + C++ plugin)
License:        GPL-3.0-or-later
Source0:        %{url}/archive/refs/tags/v%{version}.tar.gz#/KCast-%{version}.tar.gz

BuildRequires:  cmake
BuildRequires:  gcc-c++
BuildRequires:  extra-cmake-modules
BuildRequires:  qt6-qtbase-devel
BuildRequires:  qt6-qtdeclarative-devel
BuildRequires:  qt6-qttools-devel
BuildRequires:  kf6-ki18n-devel

Requires:       catt
Requires:       plasma-workspace >= 6

%description
KCast is a KDE Plasma 6 applet (plasmoid) with a C++ plugin to cast local/remote media
to Google Chromecast devices using the `catt` CLI.

%prep
%autosetup -n KCast-%{version}

%build
%cmake -S . \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DKDE_INSTALL_USE_QT_SYS_PATHS=ON \
  -DKDE_INSTALL_QMLDIR=%{_qt6_qmldir} \
  -DKDE_INSTALL_PLUGINDIR=%{_qt6_plugindir}
%cmake_build

%install
%cmake_install
%find_lang plasma_applet_de.agundur.kcast

%files -f plasma_applet_de.agundur.kcast.lang
%license LICENSE
%doc README.md
%{_datadir}/plasma/plasmoids/de.agundur.kcast/
%{_libdir}/qt6/qml/de/agundur/kcast/
%dir %{_datadir}/kio
%dir %{_datadir}/kio/servicemenus
%{_datadir}/kio/servicemenus/kcast_stream.desktop

%changelog
* Mon Jun 22 2026 Alec <info@agundur.de> - 0.2.6-1
- Add Catalan localization
* Sun Jun 21 2026 Alec <info@agundur.de> - 0.2.5-1
- Remember volume per device, fix default device always shown, clean button state machine
* Wed Aug 13 2025 Alec <info@agundur.de> - 0.2.1-1
- Initial Fedora/Copr build
