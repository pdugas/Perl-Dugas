#!perl -T
# -----------------------------------------------------------------------------
# perl-Dugas - The Dugas Enterprises Perl Modules
# Copyright (C) 2013-2016 by Paul Dugas and Dugas Enterprises, LLC
# -----------------------------------------------------------------------------

use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;

plan tests => 1;

BEGIN {
    use_ok('Dugas::App') || print "Bail out!\n";
}

# -----------------------------------------------------------------------------
# vim: set et sw=4 ts=4 :
