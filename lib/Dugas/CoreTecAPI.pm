# =============================================================================
# Perl-Dugas - The Dugas Family of Perl Modules
# =============================================================================
# @file     lib/Dugas/CoreTecAPI.pm
# @brief    CoreTec Communications Encoder/Decoder API Wrapper class
# @author   Paul Dugas <paul@dugas.cc>
# =============================================================================

package Dugas::CoreTecAPI;

use 5.006;
use strict;
use warnings FATAL => 'all';

=head1 NAME

Dugas::CoreTecAPI - CoreTec API Wrapper class

=head1 VERSION

Version 0.01

=cut

our $VERSION   = '0.01';
our $AUTHOR    = 'Paul Dugas';
our $COPYRIGHT = "Copyright (C) 2013-".(1900+(localtime)[5])." $AUTHOR";
our $LICENSE   = <<ENDLICENSE;

$COPYRIGHT

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
ENDLICENSE

=head1 SYNOPSIS

  use Dugas::CoreTecAPI;

  my $coretec = new Dugas::CoreTecAPI( host => $hostname, port => 5000);
  
  $coretec->play();
  $coretec->stop();
  my $version = $coretec->query(Dugas::CoreTecAPI::CMD_VERSION);

=cut

use Carp qw(confess);
use Params::Validate qw(:all);
use Dugas::Logger;
use IO::Socket::INET;

use constant DEFAULT_PORT => 5000;

=head1 CONSTANTS

=cut

=head1 CONSTRUCTOR

=head2 B<$obj = new Dugas::CoreTecAPI( PPTIONS )>

Returns a new B<Dugas::CoretecAPI> object.  Use the following options to configure it.

=over

=item B<host =E<gt> HOSTNAME|IPADDRESS>

Sepecify the hostname of the device to connect to.  Required.

=item B<port =E<gt> INTEGER>

Specify the TCP port number to connect to.  Defaults to
B<Dugas::CoretecAPI::DEFAULT_PORT>.

=back

=cut

sub new
{
  my $class = shift or confess('Missing CLASS parameter');

  my $obj = validate( @_, {
    host => { type => SCALAR },
    port => { type => SCALAR, default => $Dugas::CoreTecAPI::DEFAULT_PORT },
  });

  bless $obj, $class;

  $obj->{sock} = new IO::Socket::INET(PeerHost => $obj->{host},
                                      PeerPort => $obj->{port},
                                      Proto => 'tcp');
  confess("CoreTecAPI connection failed") unless $obj->{sock};

  return $obj;
}

=head1 METHODS

=head2 B<query( COMMAND )>

Sends a I<CMD_QUERY> command and returns the content of the response.

=cut

sub query {
  my $self = shift or confess('Missing SELF parameter');
  my $cmd  = shift or confess('Missing COMMAND parameter');

  my $ret = $obj->{optvals}{lc($opt)};

  return $ret;
}

=head1 AUTHOR

Paul Dugas, <paul at dugas.cc>

=head1 BUGS

Please report any bugs or feature requests using the project page at
L<http://github.com/pdugas/Perl-Dugas>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Dugas::App

=head1 ACKNOWLEDGEMENTS

(none)

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2013-2014 Paul Dugas

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

1; # End of Dugas::App

# =============================================================================
# vim: set et sw=2 ts=2 :
