Name: EZMonitor
Version: 0.2
Release: 1%{?dist}
Summary: EZMonitor is a KDE (Plasma 6) Plasmoid to connect to a apsystems EZ1 Microinverter and show the power each solar panel is producing.

License: GPL
Source0: %{name}-%{version}.tar.gz

BuildRequires: gcc
Requires: ...

%description
  EZMonitor is a KDE (Plasma 6) Plasmoid to connect to a apsystems EZ1 Microinverter and show the power each solar panel is producing.
  Enable the local API of your APsystems EZ1-M and add the plasmoid to your desktop and enjoy.


%build
  mkdir build && cd build
  cmake ..
  make

%install
  make install

%files
  %dir %{package}
