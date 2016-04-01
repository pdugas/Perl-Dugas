Name:		perl-Dugas
Version:	0.1
Release:	1%{?dist}
Summary:	Dugas Perl Modules
Group:		Develpment/Libraries
URL:		https://github.com/pdugas/Perl-Dugas
License:	GPL
Source0:	https://github.com/pdugas/Perl-Dugas/archive/${name}-%{version}.tar.gz

BuildArch:	noarch

BuildRequires:	perl(Config::IniFiles)
BuildRequires:	perl(ExtUtils::MakeMaker)
BuildRequires:	perl(JSON)
BuildRequires:	perl(LWP)
BuildRequires:	perl(Monitoring::Plugin)
BuildRequires:	perl(Net::OpenSSH)
BuildRequires:	perl(Net::SNMP)
BuildRequires:	perl(Test::Simple)
BuildRequires:	perl(XML::Simple)

Requires:	perl(Carp)
Requires:	perl(Config::IniFiles)
Requires:	perl(JSON)
Requires:	perl(LWP)
Requires:	perl(Monitoring::Plugin)
Requires:	perl(Net::OpenSSH)
Requires:	perl(Net::SNMP)
Requires:	perl(XML::Simple)
Requires:       perl(:MODULE_COMPAT_%(eval "`%{__perl} -V:version`"; echo $version))

%description
The Dugas Perl modules are a set of utilities developed by Paul Dugas for use
on various projects.  See https://github.com/pdugas/Perl-Dugas for details.

%prep
%setup -q -n Perl-Dugas-%{version}

%build
%{__perl} Makefile.PL INSTALLDIRS=vendor NO_PACKLIST=1
make %{?_smp_mflags}

%install
make pure_install PERL_INSTALL_ROOT=$RPM_BUILD_ROOT
find $RPM_BUILD_ROOT -type f -name .packlist -exec rm {} 2>/dev/null \;
find $RPM_BUILD_ROOT -depth -type d -exec rmdir {} 2>/dev/null \;
%{_fixperms} $RPM_BUILD_ROOT/*
%{__install} -Dp -m 644 "etc/eg.conf" "%{buildroot}%{_sysconfdir}/dugas.conf"
%{__install} -d -m 755 %{buildroot}%{_datadir}/doc/%{name}-%{version}/eg/
%{__install} -m 755 "bin/eg-plugin" "%{buildroot}%{_datadir}/doc/%{name}-%{version}/eg/eg-plugin"
%{__install} -m 755 "bin/eg-app" "%{buildroot}%{_datadir}/doc/%{name}-%{version}/eg/eg-app"

%check
make test

%files
%doc README.md LICENSE
%{perl_vendorlib}/*
%{_mandir}/man3/*
%attr(644,root,root) %config(noreplace) %{_sysconfdir}/dugas.conf

%changelog
* Fri Apr  1 2016 Paul Dugas <paul@dugas.cc>
- Initial 0.1 release.
* Mon Mar 28 2016 Paul Dugas <paul@dugas.cc>
- Initial Specfile.
