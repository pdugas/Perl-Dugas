#!perl -T
# -----------------------------------------------------------------------------
# perl-Dugas - The Dugas Enterprises Perl Modules
# Copyright (C) 2013-2016 by Paul Dugas and Dugas Enterprises, LLC
# -----------------------------------------------------------------------------

use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;
use FindBin;

plan tests => 7;

use_ok('Dugas::Maximo') || print "Bail out!\n";

SKIP: {

  my $CONF = "$FindBin::RealBin/../etc/maximo.conf";
  if ($CONF =~ /^(.*)$/) { $CONF = $1; } # untaint

  skip 'Please create etc/maximo.conf for credentials.', 6 
    unless -r $CONF;

  # simple no-dependency way to get credentials.  not terribly pretty.
  { package MAXIMO; do($CONF); }

  my $mx = new Dugas::Maximo(host => $MAXIMO::MAXIMO{host},
                              user => $MAXIMO::MAXIMO{user},
                              pass => $MAXIMO::MAXIMO{pass});
  ok($mx, 'ctor')
    or diag explain $mx;

  # load the first two person OSs
  my @person = $mx->get('os', 'mxperson', _maxItems => 2);
  ok(@person, 'get(OS, PMXPERSON)')
    or diag explain @person;

  # load the first two asset MBOs
  my @assets = $mx->get('mbo', 'asset', _maxItems => 2);
  ok(@assets, 'get(MBO, ASSET)')
    or diag explain @assets;

  # load the first two location MBOs
  my @locs = $mx->get('MBO', 'LOCATIONS', _maxItems => 2);
  ok(@locs, 'get(MBO, LOCATIONS)')
    or diag explain @locs;

  # reload the first one by ID
  my $loc = $mx->get('mbo', 'locations', $locs[0]{LOCATIONSID});
  ok($loc, 'get(MBO, LOCATIONS, ID)')
    or diag explain $loc;

  # reload the first one again using get1()
  $loc = $mx->get1('mbo', 'locations', LOCATIONSID => $locs[0]{LOCATIONSID});
  ok($loc, 'get(MBO, LOCATIONS, LOCATIONSID=>...)')
    or diag explain $loc;

  # create and SR
  my $sr = $mx->post('mbo', 'sr', 
                     LOCATION                    => $locs[1]{LOCATIONSID},
                     ORGID                       => $locs[1]{ORGID},
                     SITEID                      => $locs[1]{SITEID},
                     SRSOURCE                    => 'NAGIOS',
                     DESCRIPTION                 => 'TESTING',
                     DESCRIPTION_LONGDESCRIPTION => '<i>Please Ignore.</i>');
  ok($sr, 'post(MBO, SR, LOCATION=>...)')
    or diag explain $sr;
}

# -----------------------------------------------------------------------------
# vim: set et sw=4 ts=4 :
