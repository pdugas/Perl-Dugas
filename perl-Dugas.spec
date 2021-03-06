# -----------------------------------------------------------------------------
# perl-Dugas - The Dugas Enterprises Perl Modules
# Copyright (C) 2013-2016 by Paul Dugas and Dugas Enterprises, LLC
# -----------------------------------------------------------------------------

Name:		perl-Dugas
Version:	0.2
Release:	1%{?dist}
Summary:	Dugas Perl Modules
Group:		Develpment/Libraries
URL:		https://github.com/pdugas/perl-Dugas
License:	GPL
Source0:	https://github.com/pdugas/perl-Dugas/archive/%{version}.tar.gz

BuildArch:	noarch

BuildRequires:	perl(Config::IniFiles)
BuildRequires:	perl(ExtUtils::MakeMaker)
BuildRequires:	perl(JSON)
BuildRequires:	perl(LWP)
BuildRequires:	perl(Monitoring::Plugin)
BuildRequires:	perl(Net::OpenSSH)
BuildRequires:	perl(SNMP)
BuildRequires:	perl(Test::CheckManifest)
BuildRequires:	perl(Test::Pod)
BuildRequires:	perl(Test::Pod::Coverage)
BuildRequires:	perl(Test::Simple)
BuildRequires:	perl(XML::Simple)

Requires:	perl(Carp)
Requires:	perl(Config::IniFiles)
Requires:	perl(JSON)
Requires:	perl(LWP)
Requires:	perl(Monitoring::Plugin)
Requires:	perl(Net::OpenSSH)
Requires:	perl(SNMP)
Requires:	perl(XML::Simple)
Requires:   perl(:MODULE_COMPAT_%(eval "`%{__perl} -V:version`"; echo $version))

%description
The Dugas Perl modules are a set of utilities developed by Paul Dugas for use
on various projects.  See https://github.com/pdugas/perl-Dugas for details.

%prep
%setup -q -n perl-Dugas-%{version}

%build
%{__perl} Makefile.PL INSTALLDIRS=vendor NO_PACKLIST=1
make %{?_smp_mflags}

%install
make pure_install PERL_INSTALL_ROOT=$RPM_BUILD_ROOT
find $RPM_BUILD_ROOT -type f -name .packlist -exec rm {} 2>/dev/null \;
find $RPM_BUILD_ROOT -depth -type d -exec rmdir {} 2>/dev/null \;
%{_fixperms} $RPM_BUILD_ROOT/*
#%{__install} -Dp -m 644 "etc/dugas.conf" "%{buildroot}%{_sysconfdir}/dugas.conf"
%{__install} -d -m 755 %{buildroot}%{_datadir}/doc/%{name}-%{version}/eg/
%{__install} -m 755 "bin/eg-plugin" "%{buildroot}%{_datadir}/doc/%{name}-%{version}/eg/eg-plugin"
%{__install} -m 755 "bin/eg-app" "%{buildroot}%{_datadir}/doc/%{name}-%{version}/eg/eg-app"

%check
make RELEASE_TESTING=1 test

%files
%doc README.md LICENSE
%{perl_vendorlib}/*
%{_mandir}/man3/*
#%attr(644,root,root) %config(noreplace) %{_sysconfdir}/dugas.conf

%changelog
* Tue Apr 12 2016 Paul Dugas <paul@dugas.cc>
- Initial 0.2 release.
* Fri Apr  1 2016 Paul Dugas <paul@dugas.cc>
- Initial 0.1 release.
* Mon Mar 28 2016 Paul Dugas <paul@dugas.cc>
- Initial Specfile.

# -----------------------------------------------------------------------------
# vim: set et sw=4 ts=4 :
