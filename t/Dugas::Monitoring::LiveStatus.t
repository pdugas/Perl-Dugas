#!perl -T
# -----------------------------------------------------------------------------
# perl-Dugas - The Dugas Enterprises Perl Modules
# Copyright (C) 2013-2016 by Paul Dugas and Dugas Enterprises, LLC
# -----------------------------------------------------------------------------

use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;

plan tests => 5;

sub test_livestatus {
  my $live = shift or die "Missing LIVE parameter";

  my $host = $live->get_host('LOCALHOST');
  ok($host, 'get_host(LOCALHOST)') or diag explain $host;

  my $svc = $live->get_service('LOCALHOST', 'LOAD');
  ok($svc, 'get_service(LOCALHOST, LOAD)') or diag explain $svc;
}

use_ok( 'Dugas::Monitoring::LiveStatus' ) || print "Bail out!\n";

SKIP: {
  my $live; eval { $live = new Dugas::Monitoring::LiveStatus(); };
  skip 'No LiveStatus local socket', 2 unless $live;
  test_livestatus $live;
};

SKIP: {
  my $live; eval { $live = new Dugas::Monitoring::LiveStatus(host => 'nagios'); };
  skip 'No LiveStatus host', 2 unless $live;
  test_livestatus $live;
};

# -----------------------------------------------------------------------------
# vim: set et sw=4 ts=4 :
