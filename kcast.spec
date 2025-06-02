Name:           kcast
Version:        0.2.0
Release:        1%{?dist}
Summary:        KCast Version: 0.2.0 is a KDE Plasma 6 widget that lets you cast video files or youtube URLs to a  Chromecast devices in your local network. It supports device discovery, local media playback via an embedded HTTP server, and drag-and-drop integration with browsers and file managers like Dolphin.

License:        GPL-3.0-or-later
URL:            https://www.opencode.net/agundur/kcast
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  cmake
BuildRequires:  gcc-c++
BuildRequires:  extra-cmake-modules
BuildRequires:  kf6-rpm-macros
BuildRequires:  qt6-qtbase-devel
BuildRequires:  qt6-qtdeclarative-devel
BuildRequires:  plasma6-framework-devel

Requires:       plasma6-workspace

%description
KCast Version: 0.2.0 is a KDE Plasma 6 widget that lets you cast video files or youtube URLs to a  Chromecast devices in your local network

%prep
%autosetup -n %{name}-%{version}

%build
%cmake_kf6
%cmake_build

%install
%cmake_install

%files
%license LICENSE
%doc README.md
%{_kf6_qmldir}/de/agundur/kcast/
%{_kf6_datadir}/plasma/plasmoids/de.agundur.kcast/

%changelog
Mon Jun 02 2025 Alec <scholz@agundur.de> - 0.2.0
