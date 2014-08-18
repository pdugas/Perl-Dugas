#!perl -T
# =============================================================================
# Perl-Dugas - The Dugas Family of Perl Modules
# =============================================================================
# @file     t/Dugas.t
# @brief    Unit-Tests
# @author   Paul Dugas <paul@dugas.cc>
# =============================================================================

use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;

plan tests => 2;

BEGIN {
    use_ok( 'Dugas' ) || print "Bail out!\n";
    is(Dugas::sec2dhms(1234567.8), '14 days 06:56:07.80', 'sec2dhms');
}
