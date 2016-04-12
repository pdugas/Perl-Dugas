#!perl -T
# -----------------------------------------------------------------------------
# perl-Dugas - The Dugas Enterprises Perl Modules
# Copyright (C) 2013-2016 by Paul Dugas and Dugas Enterprises, LLC
# -----------------------------------------------------------------------------

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

# -----------------------------------------------------------------------------
# vim: set et sw=4 ts=4 :
