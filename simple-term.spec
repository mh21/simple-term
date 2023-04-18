Name: simple-term
Version: 1.0.0
Release: %autorelease
Summary: Simple vte-based terminal

License: GPL-3.0-or-later
URL: https://github.com/mh21/simple-term

Source0: https://github.com/mh21/simple-term/archive/refs/tags/v%{version}.tar.gz

BuildRequires: gnome-common
BuildRequires: vala
BuildRequires: gtk4-devel
BuildRequires: vte291-gtk4-devel

%description
Simple vte-based terminal

%prep
%autosetup
./autogen.sh

%build
%configure
%make_build

%install
%make_install

%files
%license LICENSE
%doc README.md LICENSE
%{_bindir}/simple-term

%changelog
* Tue Apr 18 2023 Michael Hofmann <mh21@mh21.de> - 1.0.0-1
- initial packaging
