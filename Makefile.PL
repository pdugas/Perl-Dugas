# -----------------------------------------------------------------------------
# perl-Dugas - The Dugas Enterprises Perl Modules
# Copyright (C) 2013-2016 by Paul Dugas and Dugas Enterprises, LLC
# -----------------------------------------------------------------------------

use 5.006;
use strict;
use warnings FATAL => 'all';
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME               => 'Dugas',
    AUTHOR             => q{Paul Dugas <paul@dugas.cc>},
    VERSION_FROM       => 'lib/Dugas.pm',
    ABSTRACT_FROM      => 'lib/Dugas.pm',
    LICENSE            => 'gpl_2',
    PL_FILES           => {},
    MIN_PERL_VERSION   => 5.006,
    CONFIGURE_REQUIRES => { 
                            'ExtUtils::MakeMaker' => 0, 
                          },
    BUILD_REQUIRES     => {
                            'Test::More' => 0,
                          },
    PREREQ_PM          => {
                            #'ABC'              => 1.6,
                            #'Foo::Bar::Module' => 5.0401,
                          },
    dist               => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean              => { FILES => 'Dugas-*' },
);

# -----------------------------------------------------------------------------
# vim: set et sw=4 ts=4 :
