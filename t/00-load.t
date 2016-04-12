#!perl -T
# -----------------------------------------------------------------------------
# perl-Dugas - The Dugas Enterprises Perl Modules
# Copyright (C) 2013-2016 by Paul Dugas and Dugas Enterprises, LLC
# -----------------------------------------------------------------------------

use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;

plan tests => 7;

BEGIN {
    use_ok( 'Dugas' )                         || print "Bail out!\n";
    use_ok( 'Dugas::App' )                    || print "Bail out!\n";
    use_ok( 'Dugas::Logger' )                 || print "Bail out!\n";
    use_ok( 'Dugas::Maximo' )                 || print "Bail out!\n";
    use_ok( 'Dugas::Monitoring' )             || print "Bail out!\n";
    use_ok( 'Dugas::Monitoring::LiveStatus' ) || print "Bail out!\n";
    use_ok( 'Dugas::Monitoring::Plugin' )     || print "Bail out!\n";
}

diag( "Testing Dugas $Dugas::VERSION, Perl $], $^X" );

# -----------------------------------------------------------------------------
# vim: set et sw=4 ts=4 :
