Name: paketname
Version: 1.0
Release: 1%{?dist}
Summary: Kurze Beschreibung des Pakets

License: GPL
Source0: %{name}-%{version}.tar.gz

BuildRequires: gcc
Requires: ...

%description
  Eine ausführlichere Beschreibung des Pakets.

%prep
  %setup -q

%build
  %configure
  make %{?dist:_dist}

%install
  rm -rf %{build_root}
  make install DESTDIR=%{build_root}

%files
  %dir %{_bindir}
  %{_bindir}/%{name}
  %doc %{docroot}/...