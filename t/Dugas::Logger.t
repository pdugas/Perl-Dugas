#!perl -T
# =============================================================================
# Perl-Dugas - The Dugas Family of Perl Modules
# =============================================================================
# @file     t/Dugas::Logger.t
# @brief    Unit-Tests
# @author   Paul Dugas <paul@dugas.cc>
# =============================================================================

use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;

plan tests => 3;

BEGIN {
    use_ok('Dugas::Logger') || print "Bail out!\n";

    is(Dugas::Logger::level(), Dugas::Logger::LOG_WARN(),
       'default level is WARN');

    Dugas::Logger::level(Dugas::Logger::LOG_DEBUG());
    is(Dugas::Logger::level(), Dugas::Logger::LOG_DEBUG(),
       'default level now DEBUG');
}
