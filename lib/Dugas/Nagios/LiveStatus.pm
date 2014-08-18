# =============================================================================
# Perl-Dugas - The Dugas Family of Perl Modules
# =============================================================================
# @file     lib/Dugas/Nagios/LiveStatus.pm
# @brief    Wrapper class for the check_mk LiveStatus API
# @author   Paul Dugas <paul@dugas.cc>
# =============================================================================

package Dugas::Nagios::LiveStatus;

use 5.006;
use strict;
use warnings FATAL => 'all';
use Carp;
use Encode;
use JSON qw(decode_json);
use Params::Validate qw(:all);
use IO::Socket::UNIX;

=head1 NAME

Dugas::Nagios::LiveStatus - Wrapper class for the LiveStatus API

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

    use Dugas::Nagios::LiveStatus;

    my $live = new Dugas::Nagios::LiveStatus(
        socket => '/var/spool/nagios/live'
    );
    my @hosts = $live->get("GET hosts");

=head1 CONSTANTS

=over

=item DEFAULT_SOCKET

The default path to the local I<LiveStatus> socket, F</var/spool/nagios/live>.

=item DEFAULT_PORT

The default TCP port to be used when connecting to a remote I<LiveStatus>
instance.

=back

=cut

use constant DEFAULT_SOCKET => '/var/spool/nagios/live';
use constant DEFAULT_PORT   => 6557;

=head1 CONSTRUCTOR

Each form of the constructor returns a B<Dugas::LiveStatus> object.  

=head2 new ( )

The default constructor returns a B<Dugas::LiveStatus> object setup to use the
default UNIX-domain I<check_mk> I<LiveStatus> socket, I<DEFAULT_SOCKET>.

=head2 new ( PATH )

Constructs a B<Dugas::LiveStatus> object setup to use the specified
path for the UNIX-domain I<check_mk> I<LiveStatus>. socket.

=head2 new ( OPTIONS )

Constructs a B<Dugas::LiveStatus> object setup based on the specified key/value
options.  Options listed below are supported.

=over

=item socket => PATH

Path to the UNIX-domain check_mk LiveStatus socket.  Defaults to
I<DEFAULT_SOCKET>.

=item host => [HOSTNAME|IP]

Hostname or IP address for the remote I<LiveStatus> instance to connect to.  

=item port => PORT

TCP port number to use when connecting to a remote I<LiveStatus> insteance.
Defaults to I<DEFAULT_PORT>.

=back

=cut

sub new
{
  my $class = shift;
  unshift(@_, 'socket') if @_ == 1;
  my $self = validate( @_, { socket => 0, host => 0, port => 0 } );
  $self->{socket} = DEFAULT_SOCKET unless $self->{socket};
  $self->{port} = DEFAULT_PORT unless $self->{port};
  bless $self, $class;

  my $sock;
  if ($self->{host}) {
    $sock = IO::Socket::INET->new(PeerAddr => $self->{host},
      PeerPort => $self->{port},
      Proto    => 'tcp');
    croak("Failed to open ".$self->{host}.":".$self->{port}."; ".$!)
    unless (defined $sock and $sock->connected());
  } else {
    $sock = IO::Socket::UNIX->new(Peer=>$self->{socket}, Type=>SOCK_STREAM);
    croak("Failed to open ".$self->{socket}."; ".$!)
    unless (defined $sock and $sock->connected());
  }
  $self->{sock} = $sock;

  return $self;
}

=head1 METHODS

Instances of the B<Dugas::LiveStatus> class support the following methods.

=head2 get ( QUERY )

Send a GET query. Returns results as an array (one element for each returned
record) of hashes (record fields as keys). The I<QUERY> parameter should
contain the leading I<GET> command.

    for ($live->get("GET hosts")) {
        print $_->{name}, "\n";
    }

Include query options as needed.

    @contact_names = $live->get("GET contacts\n".
                                "Columns: name alias");

    @crit_svcs = $live->get("GET services\n".
                            "Filter: state = 2");

=cut

sub get {
  my $self  = shift or confess("Misssing SELF parameter");
  my $query = shift or confess("Misssing QUERY parameter");

  croak("Socket isn't open!")
    unless (defined $self->{sock} and $self->{sock}->connected());

  $query .= "\n".
            "OutputFormat: json\n".
            "KeepAlive: on\n".
            "ResponseHeader: fixed16\n".
            "Localtime: ".time()."\n".
            "\n";

  print {$self->{sock}} encode('utf-8' => $query)
    or croak("Failed to send query; $!");

  my $head;
  $self->{sock}->read($head, 16)
    or croak("Failed to read head; $!");
  croak("Invalid header; '$head'")
    unless 16 == length($head) and $head =~ /^\s*(\d+)\s+(\d+)\s*$/;
  my ($err, $len) = ($1, $2);

  my $body = '';
  if ($len > 0) {
    $self->{sock}->read($body, $len)
      or croak("Failed to read body; $!");
  }

  croak("LiveStatus error $err; $body")
    unless $err == 200;

  my $data = decode_json($body);

  my @ret = ();
  for my $r (1..$#{$data}) {
    for (0..$#{@{$data}[0]}) {
      $ret[$r-1]{@{@{$data}[0]}[$_]} = @{@{$data}[$r]}[$_];
    }
  }

  return @ret;
}

=head2 get1 ( QUERY )

Shorthand for get() when only a single record is expected in the response.
Returns a hash reference for the record or UNDEF if no record found.

    $host = $live->get1("GET hosts\n".
                        "Filter: name = WWW");

=cut

sub get1 {
  my $self  = shift or confess("Misssing SELF parameter");
  my $query = shift or confess("Misssing QUERY parameter");

  return ($self->get($query."\nLimit: 1"))[0];
}

=head2 get_host( HOSTNAME )

Shorthand for get1() to retrieve one host record by name.

    $host = $live->get_host("WWW");

=cut

sub get_host {
  my $self = shift or confess("Misssing SELF parameter");
  my $host = shift or confess("Misssing HOST parameter");

  return ($self->get1("GET hosts\nFilter: name = $host"))[0];
}

=head2 get_service( HOSTNAME, SERVICE_DESCRIPTION )

Shorthand for B<get1()> to retrieve one service record by host name and service
description.

    $svc = $live->getService("WWW", "HTTP");

=cut

sub get_service {
  my $self    = shift or confess("Misssing SELF parameter");
  my $host    = shift or confess("Misssing HOST parameter");
  my $service = shift or confess("Misssing SERVICE parameter");

  return ($self->get1("GET services\n".
                      "Filter: host_name = $host\n".
                      "Filter: description = $service"))[0];
}

=head1 SEE ALSO

See the LiveStatus page at L<http://mathias-kettner.de/checkmk_livestatus.html>
for information about installing the extension and the query syntax.

=head1 AUTHOR

Paul Dugas, <paul@dugas.cc>

=head1 BUGS

Please report any bugs or feature requests using the project page at
L<http://github.com/pdugas/Perl-Dugas>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Dugas::LiveStatus

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

1; # End of Dugas::LiveStatus

# =============================================================================
# vim: set et sw=2 ts=2 :
