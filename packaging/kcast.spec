Name:           kcast
Version:        0.2.1
Release:        1%{?dist}
URL:            https://github.com/Agundur-KDE/KCast

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
BuildRequires:  libplasma-devel
BuildRequires:  kf6-kcmutils-devel
BuildRequires:  kf6-knotifications-devel
BuildRequires:  kf6-knotifyconfig-devel
BuildRequires:  kf6-kglobalaccel-devel
BuildRequires:  kf6-kguiaddons-devel
BuildRequires:  kf6-kwidgetsaddons-devel
BuildRequires:  kf6-kcodecs-devel
BuildRequires:  kf6-kiconthemes-devel
BuildRequires:  kf6-kxmlgui-devel


# --- Runtime
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

%install
%cmake_install
%find_lang plasma_applet_de.agundur.kcast

%files -f plasma_applet_de.agundur.kcast.lang
%license LICENSE*
%doc README*
%{_datadir}/plasma/plasmoids/de.agundur.kcast/

%{_libdir}/qt6/qml/de/agundur/kcast*/**


%changelog
* Wed Aug 13 2025 You <you@example.com> - 0.2.1-1
- Initial Fedora/Copr build
