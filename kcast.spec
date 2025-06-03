%ifarch aarch64
%undefine source_date_epoch_from_changelog
%endif


Name:           kcast
Version:        0.2.0
Release:        1%{?dist}
Summary:        KCast Version: 0.2.0 is a KDE Plasma 6 widget that lets you cast video files or youtube URLs to a  Chromecast devices in your local network. It supports device discovery, local media playback via an embedded HTTP server, and drag-and-drop integration with browsers and file managers like Dolphin.

License:        GPL-3.0-or-later
URL:            https://www.opencode.net/agundur/kcast
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  cmake
BuildRequires:  gcc-c++


%if 0%{?fedora}
BuildRequires: qt6-qtbase-devel
BuildRequires: qt6-qtdeclarative-devel
BuildRequires: qt6-qtquickcontrols2-devel
BuildRequires: qt6-qttools-devel
BuildRequires: fedora-logos
BuildRequires: OpenCL-ICD-Loader
BuildRequires: pinentry-qt
BuildRequires: wget1-wget
BuildRequires: extra-cmake-modules
%else
BuildRequires: qt6-base-devel
BuildRequires: qt6-declarative-devel
BuildRequires: kf6-extra-cmake-modules
BuildRequires: qt6-tools-devel
%endif

BuildRequires:  kf6-kcoreaddons-devel
BuildRequires:  kf6-kpackage-devel
BuildRequires:  kf6-ki18n-devel
BuildRequires: cmake(KF6Config)
BuildRequires: cmake(KF6KCMUtils)
BuildRequires: cmake(KF6Notifications)
BuildRequires: cmake(KF6NotifyConfig)
BuildRequires: cmake(KF6GlobalAccel)
BuildRequires: cmake(KF6GuiAddons)
BuildRequires: cmake(KF6WidgetsAddons)
BuildRequires: cmake(KF6IconThemes)
BuildRequires: cmake(KF6Codecs)
BuildRequires: cmake(KF6XmlGui)
BuildRequires:  pkgconfig(libbrotlidec)
BuildRequires:  pkgconfig(libcurl)
BuildRequires:  pkgconfig(libffi)
BuildRequires:  pkgconfig(libsystemd)
BuildRequires:  pkgconfig(libnghttp2)
BuildRequires:  pkgconfig(libidn2)
BuildRequires:  pkgconfig(libpsl)
BuildRequires:  pkgconfig(libssh)


Requires:       plasma6-workspace

%description
KCast Version: 0.2.0 is a KDE Plasma 6 widget that lets you cast video files or youtube URLs to a  Chromecast devices in your local network

%prep
%autosetup -n %{name}-%{version}

%build
%cmake package
%cmake_build

%install
%cmake_install

%files
# %license LICENSE
%doc README.md
# /usr/lib64/qt6/qml/de/agundur/kcast/
# /usr/share/plasma/plasmoids/de.agundur.kcast/
%dir %{_qt6_qmldir}/de
%dir %{_qt6_qmldir}/de/agundur
%{_qt6_qmldir}/de/agundur/kcast/
%dir %{_datadir}/plasma/plasmoids/de.agundur.kcast
%dir %{_datadir}/plasma/plasmoids/de.agundur.kcast/contents
%dir %{_datadir}/plasma/plasmoids/de.agundur.kcast/contents/ui
%{_datadir}/plasma/plasmoids/de.agundur.kcast/metadata.json
%{_datadir}/plasma/plasmoids/de.agundur.kcast/contents/ui/main.qml
%{_datadir}/plasma/plasmoids/de.agundur.kcast/CMakeLists.txt
%{_datadir}/plasma/plasmoids/de.agundur.kcast/plugin/CMakeLists.txt
%{_datadir}/plasma/plasmoids/de.agundur.kcast/plugin/kcastinterface.cpp
%{_datadir}/plasma/plasmoids/de.agundur.kcast/plugin/kcastinterface.h
%dir %{_datadir}/plasma/plasmoids/de.agundur.kcast/plugin

%changelog * Mon Jun 02 2025 Alec <scholz@agundur.de> - 0.2.0
