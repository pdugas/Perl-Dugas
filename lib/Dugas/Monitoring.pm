# -----------------------------------------------------------------------------
# perl-Dugas - The Dugas Enterprises Perl Modules
# Copyright (C) 2013-2016 by Paul Dugas and Dugas Enterprises, LLC
# -----------------------------------------------------------------------------

package Dugas::Monitoring;

use 5.006;
use strict;
use warnings FATAL => 'all';

use Carp;
use Cwd;
use Dugas::Logger;
use File::Spec;
use Params::Validate qw(:all);

=head1 NAME

Dugas::Monitoring - Monitoring system setup information.

=head1 VERSION

Version 0.2

=cut

our $VERSION = '0.2';

=head1 SYNOPSIS

    use Dugas::Monitoring;

=head1 DESCRIPTION

The B<Dugas::Monitoring> module provides a handful of routines we use for our
monitoring installations.

=cut

=head1 SUBROUTINES

=head2 host_state_name ( STATE )

Returns the string name for a given host I<STATE>.

=cut

sub host_state_name
{
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

sub service_state_name
{
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

sub state_type_name
{
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
L<http://github.com/pdugas/perl-Dugas>.

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

1; # End of Dugas::Monitoring

# -----------------------------------------------------------------------------
# vim: set et sw=4 ts=4 :
