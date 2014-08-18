#!perl -T
# =============================================================================
# Perl-Dugas - The Dugas Family of Perl Modules
# =============================================================================
# @file     t/manifest.t
# @brief    Unit-Tests
# @author   Paul Dugas <paul@dugas.cc>
# =============================================================================

use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;

unless ( $ENV{RELEASE_TESTING} ) {
    plan( skip_all => "Author tests not required for installation; set RELEASE_TESTING" );
}

my $min_tcm = 0.9;
eval "use Test::CheckManifest $min_tcm";
plan skip_all => "Test::CheckManifest $min_tcm required" if $@;

ok_manifest();
