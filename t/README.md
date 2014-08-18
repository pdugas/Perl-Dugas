Perl-Dugas Unit Tests
=====================

This directory contains unit tests for the Perk-Dugas modules.  Run them with
`make test` in the top level directory.  Set TEST_VERBOSE=1 to get more detail
on the testing; i.e. `make test TEST_VERBOSE=1`.

The build and testing framework also supports collecting coverage data from 
the tests.  Use the command below.

  cover -delete && HARNESS_PERL_SWITCHES=-MDevel::Cover make test && cover

If the tests pass, the coverage results are in `cover_db/coverage.html`.
