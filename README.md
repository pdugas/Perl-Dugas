perl-Dugas
==========
**perl-Dugas** is a family of Perl modules that I pull into various projects as
needed.  It's my personal bag of tools that I've put together over the
years where I needed something that wasn't provided by stock Perl or another
module (without dependency issues).  I typically just pull the `lib/`
subdirectory (or parts of it) into other projects with `svn:externals` or a
submodule in Git.  I've included CPAN packaing support if you are looking to
build installation packages instead.

The following Perl modules are included:

* **Dugas::App** - Simple program options framework.
* **Dugas::LiveStatus** - Wrapper for the [LiveStatus] [LiveStatus URL] API.
* **Dugas::Logger** - Simple diagnostic logging framework.
* **Dugas::Maximo** - Wrapper for the [Maximo REST] [Maximo REST URL] API.
* **Dugas::Monitoring** - Nagios deployment paths and such.  (Should move to Dugas::Monitoring::Util.)
* **Dugas::Monitoring::Plugin** - Custom version of [Monitoring::Plugin] [Monitoring::Plugin URL]
* **Dugas::Util** - Catch-all for anything that didn't fit elsewhere.

[LiveStatus URL]: https://mathias-kettner.de/checkmk_livestatus.html
[Maximo REST URL]: http://www-01.ibm.com/support/knowledgecenter/SSLKT6_7.5.0.5/com.ibm.mif.doc/gp_intfrmwk/rest_api/c_rest_overview.html?lang=en
[Monitoring::Plugin URL]: http://search.cpan.org/dist/Monitoring-Plugin/lib/Monitoring/Plugin.pm

CONTENTS
--------
This is the top-level directory of the perl-Dugas package.  It contains the
following files and subdirectories:

* `bin/` - Example programs
* `etc/` - Example configs
* `img/` - Sample images
* `lib/` - The Perl source code
* `t/` - Unit tests
* `Changes` - Project release history
* `LICENSE` - License details
* `Makefile.PL` - Bootstrap script for the build syste,
* `MANIFEST` - List of files included in the package
* `MANIFEST.SKIP` - List of files exceluded from the package
* `README.md` - This file

INSTALLATION
------------
To install this module, run the following commands:

    perl Makefile.PL
    make

Run the unit tests with

    make test

or

    make test TEST_VERBOSE=1

then

    make install

PACKAGING
---------
Building an RPM package is a matter of the following on a RedHat/CentOS machine.

    # yum install -y rpm-build redhat-rpm-config rpmdevtools yum-utils
    # rpmdev-setuptree
    # wget https://raw.githubusercontent.com/pdugas/perl-Dugas/0.2/perl-Dugas.spec
    # spectool -g -R perl-Dugas.spec
    # yum-builddep -y perl-Dugas.spec
    # rpmbuild -ba perl-Dugas.spec

TODO
----
* Unit tests provide minimal coverage.  Need to expand them.
* Clean out `Dugas.pm` now that we typically install via RPM.

SUPPORT & DOCUMENTATION
-----------------------
The project page at http://github.com/pdugas/perl-Dugas/ should be used to
ask questions or provide feedback.  After installing, you can find
documentation for this module with the perldoc command.

    perldoc Dugas

If you don't install the package in the standard location, you should
still be able to get the documentation by pointing `perldoc` directly
to one of the `[module].pm` files.

    perldoc ./lib/Dugas/Dugas.pm

LICENSE & COPYRIGHT
-------------------
Copyright (C) 2013-2016 Paul Dugas

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation; either version 2 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program; if not, write to the Free Software Foundation, Inc., 51 Franklin
Street, Fifth Floor, Boston, MA 02110-1301 USA.

Paul Dugas may be contacted at the addresses below:

    Paul Dugas                   paul@dugas.cc
    522 Black Canyon Park        http://paul.dugas.cc/
    Canton, GA 30114 USA

