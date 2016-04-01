# =============================================================================
# Dugas-Perl - The Dugas Family of Perl Modules
# =============================================================================
# @file     lib/Dugas/Monitoring.pm
# @brief    Perl module for our Nagios utilities.
# @author   Paul Dugas <paul@dugas.cc>
# =============================================================================

package Dugas::Monitoring;

use 5.006;
use strict;
use warnings FATAL => 'all';
use Cwd;
use Carp;
use File::Spec;
use Dugas::Logger;
use Params::Validate qw(:all);

=head1 NAME

Dugas::Monitoring - Nagios setup information.

=head1 VERSION

Version 0.1

=cut

our $VERSION = '0.1';

=head1 SYNOPSIS

    use Dugas::Monitoring;

    print Dugas::Monitoring::BASEDIR, "\n";
    ...

=head1 DESCRIPTION

The B<Dugas::Monitoring> module provides a handful of routines we use for our
Nagios installations - mostly, paths and other static stuff.

=cut

# This will be the top-level directory where we expect to find the bin/, etc/,
# lib/, and etc/nagios.d/ subdirectories.
my $basedir;

# Handle parameters passed when the module is use'd.
sub import
{
  my $name = shift; # module name.  ignored

  # $dir will be our initial, two levels up from where this file lives.
  my ($vol, $dir, $file) = File::Spec->splitpath(__FILE__);
  $dir = Cwd::realpath(File::Spec->catdir($dir, (File::Spec->updir()) x 2));

  # Process parameters.
  my $opts = validate(@_, {BASEDIR => {type => SCALAR, default => $dir}});
  $basedir = $opts->{BASEDIR};

  # Warn if BASEDIR doesn't seem right.
  if (-d $basedir) {
    note("Nagios BASEDIR ($basedir) may not be correct.")
      unless (-d BINDIR() && -d ETCDIR() && -d LIBDIR());
  } else {
    note("Nagios BASEDIR ($basedir) doesn't exist.")
  }
} # import()

=head1 CONSTANTS

=head2 B<BASEDIR>

Returns the full path for the top-level directory for the Nagios setup.  We
expect this folder to contain nagios.conf, bin/, etc/, and lib/.  By default,
this will be two levels up from the Monitoring.pm Perl module itself since we
typically deploy things that way.

The B<BASEDIR> value can be overridden when use'ing the module like so:

  use Dugas::Monitoring( BASEDIR => '/opt/nagios' );

=cut

sub BASEDIR { return $basedir; }

=head2 B<BINDIR>

Returns the full path for the C<bin/> subdirectory under B<BASEDIR>.

=cut

sub BINDIR { return BASEDIR().'/bin'; }

=head2 B<ETCDIR>

Returns the full path for the C<etc/> subdirectory under B<BASEDIR>.

=cut

sub ETCDIR { return BASEDIR().'/etc'; }

=head2 B<LIBDIR>

Returns the full path for the C<lib/> subdirectory under B<BASEDIR>.

=cut

sub LIBDIR { return BASEDIR().'/lib'; }

=head2 B<NAGDIR>

Returns the full path for the main C<etc/nagios.d/> subdirectory under
B<BASEDIR>.

=cut

sub NAGDIR { return ETCDIR().'/nagios.d'; }

=head2 B<NAGCFG>

Returns the full path for the main C<etc/nagios.cfg> file under B<BASEDIR>.

=cut

sub NAGCFG { return ETCDIR().'/nagios.cfg'; }

=head1 SUBROUTINES

=head2 host_state_name ( STATE )

Returns the string name for a given host I<STATE>.

=cut

sub host_state_name {
  my $state = shift;
  croak("Missing STATE parameter")
      unless defined $state;

  if ($state == 0)  { return 'UP'; }
  if ($state == 1)  { return 'DOWN'; }
  if ($state == 2)  { return 'UNREACHABLE'; }

  croak("Invalid STATE paremeter value; $state");
}

=head2 service_state_name ( STATE )

Returns the string name for a given service I<STATE>.

=cut

sub service_state_name {
  my $state = shift;
  croak("Missing STATE parameter")
      unless defined $state;

  if ($state == 0)  { return 'OK'; }
  if ($state == 1)  { return 'WARNING'; }
  if ($state == 2)  { return 'CRITICAL'; }
  if ($state == 3)  { return 'UNKNOWN'; }

  croak("Invalid STATE parameter value; $state");
}

=head2 state_type_name ( TYPE )

Returns the string name for a given state B<TYPE>.

=cut

sub state_type_name {
  my $type = shift;
  croak("Missing TYPE parameter")
      unless defined $type;

  if ($type == 0)  { return 'SOFT'; }
  if ($type == 1)  { return 'HARD'; }

  croak("Invalid TYPE parameter value; $type");
}

=head1 SEE ALSO

B<Dugas::Monitoring::Plugin>

=head1 AUTHOR

Paul Dugas, <paul@dugas.cc>

=head1 BUGS

Please report any bugs or feature requests using the project page at
L<http://github.com/pdugas/Perl-Dugas>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Dugas::Monitoring

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2013-2016 Paul Dugas

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation; either version 2 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program; if not, write to the Free Software Foundation, Inc., 51 Franklin
Street, Fifth Floor, Boston, MA 02110-1301 USA.

Paul Dugas may be contacted at the addresses below:

    Paul Dugas                   paul@dugas.cc
    522 Black Canyon Park        http://paul.dugas.cc/
    Canton, GA 30114 USA

=cut

1; # End of Dugas::Nagios

# =============================================================================
# vim: set et ts=4 sw=4 :
