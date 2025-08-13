Name:           kcast
Version:        0.2.1
Release:        1%{?dist}
Summary:        Cast media to Chromecast from KDE Plasma (Plasmoid + C++ plugin)
License:        GPL-3.0-or-later
URL:            https://github.com/Agundur-KDE/KCast
Source0:        %{url}/archive/refs/tags/v%{version}.tar.gz#/KCast-%{version}.tar.gz

# --- Build requirements (C++/CMake + Qt6 + KF6/Plasma 6)
BuildRequires:  cmake
BuildRequires:  gcc-c++
BuildRequires:  extra-cmake-modules
BuildRequires:  qt6-qtbase-devel
BuildRequires:  qt6-qtdeclarative-devel
BuildRequires:  kf6-kcoreaddons-devel
BuildRequires:  kf6-kconfig-devel
BuildRequires:  kf6-ki18n-devel
BuildRequires:  kf6-kpackage-devel
BuildRequires:  kf6-plasma-framework-devel
# ggf. weitere KF6/Qt6 - je nach deinem CMakeLists.txt (z.B. kf6-kwindowsystem-devel, qt6-qttools-devel)

# --- Runtime
Requires:       catt
Requires:       plasma-workspace >= 6
# ggf. weitere Laufzeitabhängigkeiten, z. B. qt6-qtdeclarative, kf6-ki18n, kf6-kpackage (werden oft automatisch aufgelöst)

%description
KCast is a KDE Plasma 6 applet (plasmoid) with a C++ plugin to cast local/remote media
to Google Chromecast devices using the `catt` CLI.

%prep
%autosetup -n KCast-%{version}

%build
%cmake -B build -S . \
      -DCMAKE_BUILD_TYPE=RelWithDebInfo \
      -DCMAKE_INSTALL_PREFIX=%{_prefix} \
      -DKDE_INSTALL_USE_QT_SYS_PATHS=ON
%cmake_build -C build

%install
%cmake_install -C build

# Falls dein CMake schon korrekt in die richtigen Pfade installiert, brauchst du unten nichts mehr.
# Für Plasma 6 erwartet Fedora:
#   Plasmoid:   %{_datadir}/plasma/plasmoids/de.agundur.kcast/
#   Plugins:    %{_libdir}/qt6/qml/  ODER %{_libdir}/qt6/plugins/ (abhängig von deinem Projekt)

%files
%license LICENSE*
%doc README*
%{_datadir}/plasma/plasmoids/de.agundur.kcast/
# Plugin-Pfade anpassen:
%{_libdir}/qt6/qml/de/agundur/kcast*/**
# oder falls als Plugin installiert:
# %{_libdir}/qt6/plugins/de/agundur/kcast*/**

%changelog
* Wed Aug 13 2025 You <you@example.com> - 2.0.0-1
- Initial Fedora/Copr build
