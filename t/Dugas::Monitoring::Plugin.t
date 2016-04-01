#!perl -T
# =============================================================================
# perl-Dugas - The Dugas Family of Perl Modules
# =============================================================================
# @file     t/Dugas::Monitoring::Plugin.t
# @brief    Unit-Tests
# @author   Paul Dugas <paul@dugas.cc>
# =============================================================================

use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;

plan tests => 1;

BEGIN {
    use_ok( 'Dugas::Monitoring::Plugin' ) || print "Bail out!\n";
}
