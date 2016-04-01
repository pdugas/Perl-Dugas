#!perl -T
# =============================================================================
# perl-Dugas - The Dugas Family of Perl Modules
# =============================================================================
# @file     t/Dugas::Util.t
# @brief    Unit-Tests
# @author   Paul Dugas <paul@dugas.cc>
# =============================================================================

use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;

plan tests => 2;

BEGIN {
    use_ok( 'Dugas::Util' ) || print "Bail out!\n";
    is(sec2dhms(1234567.8), '14 days 06:56:07.80', 'sec2dhms');
}
