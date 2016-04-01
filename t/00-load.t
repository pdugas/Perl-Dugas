#!perl -T
# =============================================================================
# perl-Dugas - The Dugas Family of Perl Modules
# =============================================================================
# @file     t/00-load.t
# @brief    Unit-Tests
# @author   Paul Dugas <paul@dugas.cc>
# =============================================================================

use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;

plan tests => 7;

BEGIN {
    use_ok( 'Dugas' ) || print "Bail out!\n";
    use_ok( 'Dugas::App' ) || print "Bail out!\n";
    use_ok( 'Dugas::Logger' ) || print "Bail out!\n";
    use_ok( 'Dugas::Maximo' ) || print "Bail out!\n";
    use_ok( 'Dugas::Monitoring' ) || print "Bail out!\n";
    use_ok( 'Dugas::Monitoring::LiveStatus' ) || print "Bail out!\n";
    use_ok( 'Dugas::Monitoring::Plugin' ) || print "Bail out!\n";
}

diag( "Testing Dugas $Dugas::VERSION, Perl $], $^X" );
