# -----------------------------------------------------------------------------
# perl-Dugas - The Dugas Enterprises Perl Modules
# Copyright (C) 2013-2016 by Paul Dugas and Dugas Enterprises, LLC
# -----------------------------------------------------------------------------

package Dugas::CoreTecAPI;

use 5.006;
use strict;
use warnings FATAL => 'all';

=head1 NAME

Dugas::CoreTecAPI - CoreTec API Wrapper class

=head1 VERSION

Version 0.1

=cut

our $VERSION   = '0.1';
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

Setup.

  use Dugas::CoreTecAPI;

  my $coretec = new Dugas::CoreTecAPI( host => $hostname, port => 5000);
  
Control.

  $coretec->reset();
  $coretec->stop();
  $coretec->start();

Query.

  my $version = $coretec->version();
  my $uptime = $coretec->video_uptime();
  my $name = $coretec->device_name();

Set.

  $coretec->device_name('CAM-1234');

=cut

use Carp qw(confess);
use Params::Validate qw(:all);
use Dugas::Logger;
use IO::Socket::INET;

use constant PKT_SYNC1   => 0xDEADBEAD;
use constant PKT_SYNC2   => 0xFEEDBEEF;
use constant PKT_VERSION => 0xBEEF0002;

use constant DEFAULT_PORT    => 5000;
use constant DEFAULT_TIMEOUT => 5;

use constant CMD_RESET                      => 0;
use constant CMD_PLAY                       => 1;
use constant CMD_STOP                       => 2;
use constant CMD_PAUSE                      => 3;
use constant CMD_RESUME                     => 4;
use constant CMD_LOAD_DEFAULTS              => 5;
use constant CMD_LOAD_CONFIG                => 6;
use constant CMD_SAVE_CONFIG                => 7;
use constant CMD_LOAD_PRESET                => 8;
use constant CMD_VIDEO_RES                  => 9;
use constant CMD_VIDEO_STD                  => 10;
use constant CMD_AUDIO_ENABLE               => 11;
use constant CMD_NOISE_FILTER               => 12;
use constant CMD_MUX_TYPE                   => 13;
use constant CMD_ENABLE_VBR                 => 14;
use constant CMD_AUDIO_BITRATE              => 15;
use constant CMD_MUX_BITRATE                => 16;
use constant CMD_CBR_MAX_VBR                => 17;
use constant CMD_SET_VBR                    => 18;
use constant CMD_SET_QUALITY_CONF           => 19;
use constant CMD_GET_QUALITY_CONFIG         => 20;
use constant CMD_COMMIT                     => 21;
use constant CMD_VIDEO_DATAGRAM_IP          => 22;
use constant CMD_VIDEO_DATAGRAM_PORT        => 23;
use constant CMD_SUBCHANNEL                 => 24;
use constant CMD_ACQUIRE_SUBCHANNEL         => 25;
use constant CMD_CONTRAST                   => 26;
use constant CMD_TINT                       => 27;
use constant CMD_SATURATION                 => 28;
use constant CMD_BRIGHTNESS                 => 29;
use constant CMD_QUERY                      => 30;
use constant CMD_DEVICE_NAME                => 31;
use constant CMD_REBOOT                     => 32;
use constant CMD_DEVICE_IP                  => 33;
use constant CMD_COMMAND_PORT               => 34;
use constant CMD_STREAM_CHANGE              => 35;
use constant CMD_WATCHDOG_ENABLE            => 36;
use constant CMD_VLC_ERROR_RESET_TIME       => 37;
use constant CMD_VLC_ERROR_RESET_COUNT      => 38;
use constant CMD_SUBCHANNEL_BAUD_RATE       => 39;
use constant CMD_INVALID_QUERY              => 40;
use constant CMD_PACKETIZED_ENABLE          => 41;
use constant CMD_DEVICE_SUBNET_MASK         => 42;
use constant CMD_GATEWAYS                   => 43;
use constant CMD_DHCP_ENABLE                => 44;
use constant CMD_ACTIVE_DISCOVERY_ENABLE    => 45;
use constant CMD_SAP_ENABLE                 => 46;
use constant CMD_SET_BITRATE                => 47;
use constant CMD_FLASH_UPDATE               => 48;
use constant CMD_DHCP                       => 49;
use constant CMD_MAC                        => 50;
use constant CMD_DNS_IP                     => 51;
use constant CMD_UPDATE_SERVER_IP           => 52;
use constant CMD_UPDATE_SERVER_NAME         => 53;
use constant CMD_FULL_DUPLEX                => 54;
use constant CMD_CAMERA_TYPE                => 55;
use constant CMD_AUTO_REBOOT                => 56;
use constant CMD_AUTO_RESTART               => 57;
use constant CMD_CAMERA_ID                  => 58;
use constant CMD_FRAME_RATE                 => 59;
use constant CMD_CODEC_SELECT               => 60;
                                             # 61 skipped
use constant CMD_SET_VIDEO_MODE             => 62;
use constant CMD_NUMDEVICES                 => 63;
use constant CMD_VIDEO_INPUT                => 64;
use constant CMD_CODEC_ENABLE               => 65;
use constant CMD_NETWORK_DUPLEX             => 66;
use constant CMD_NETWORK_SPEED              => 67;
use constant CMD_PASSWORD                   => 68;
use constant CMD_CLIENT_AUTH_SET            => 69;
use constant CMD_AUTH_CHECK                 => 70;
use constant CMD_AUTH_REMOVE                => 71;
use constant CMD_PRINT                      => 72;
use constant CMD_ENCODER_STATUS             => 73;
use constant CMD_ENCODER_GROUP_LEN          => 74;
use constant CMD_ENCODER_REF_DISTANCE       => 75;
use constant CMD_ENCODER_JVM                => 76;
use constant CMD_SAP_AUTHOR                 => 77;
use constant CMD_SAP_KEYWORD                => 78;
use constant CMD_SAP_COPYRIGHT              => 79;
use constant CMD_SAP_NAME                   => 80;
use constant CMD_SAP_INFO                   => 81;
use constant CMD_FTP_PERIOD                 => 82;
use constant CMD_FTP_PORT                   => 83;
use constant CMD_FTP_SERVER                 => 84;
use constant CMD_FTP_LOGIN                  => 85;
use constant CMD_FTP_PASSWORD               => 86;
use constant CMD_FTP_DISCOVERY              => 87;
use constant CMD_FTP_FILE_NAME              => 88;
use constant CMD_CHECK_VIDEO_STATUS         => 89;
use constant CMD_SEND_DATE_TIME             => 90;
use constant CMD_SEND_CLOSED_CAPTION        => 91;
use constant CMD_CLOSED_CAPTION_STRING      => 92;
use constant CMD_DISCOVERY_IP               => 93;
use constant CMD_DISCOVERY_PORT             => 94;
use constant CMD_DEVICE_TYPE                => 95;
use constant CMD_SAP_IP                     => 96;
use constant CMD_SAP_PORT                   => 97;
use constant CMD_SAP_INTERVAL               => 98;
use constant CMD_DEVICE_VERSION             => 99;
use constant CMD_OSD_TEXT                   => 100;
use constant CMD_OSD_POSITION_X             => 101;
use constant CMD_OSD_POSITION_Y             => 102;
use constant CMD_OSD_JUSTIFY                => 103;
use constant CMD_OSD_COLOR                  => 104;
use constant CMD_OSD_TEXT_BACK_COLOR        => 105;
use constant CMD_OSD_PALETTE                => 106;
use constant CMD_OSD_CLEAR                  => 107;
use constant CMD_OSD_SELECT                 => 108;
use constant CMD_OSD_UPDATE                 => 109;
use constant CMD_OSD_ENABLE                 => 110;
use constant CMD_SNMP_RW_COMMUNITY          => 115;
use constant CMD_SNMP_RO_COMMUNITY          => 116;
use constant CMD_SNMP_TRAP_MANAGER          => 117;
                                             # 118 skipped
                                             # 119 skipped
use constant CMD_DEVICE_PASSWORD            => 120;
use constant CMD_DEVICE_DATE                => 121;
use constant CMD_DEVICE_TIME                => 122;
use constant CMD_DISPLAY_SPEED              => 123;
use constant CMD_DISPLAY_ENABLE             => 124;
use constant CMD_DEFAULT                    => 125;
use constant CMD_CPU_LOAD                   => 126;
use constant CMD_CROP_TOP                   => 127;
use constant CMD_CROP_BOTTOM                => 128;
use constant CMD_BUFFER_LOW                 => 129;
use constant CMD_BUFFER_HIGH                => 130;
use constant CMD_FTP_SERVER_IP              => 131;
                                             # 132-147 skipped
use constant CMD_VIDEO_UPTIME               => 148;
                                             # 149-199 skipped
use constant CMD_SUBCHANNEL_SELECT          => 200;
use constant CMD_SUBCHANNEL_ENABLE          => 201;
use constant CMD_SUBCHANNEL_BAUD            => 202;
use constant CMD_SUBCHANNEL_PORT            => 203;
use constant CMD_SUBCHANNEL_IP              => 204;
use constant CMD_SUBCHANNEL_PARITY          => 205;
use constant CMD_SUBCHANNEL_STOP_BITS       => 205;
use constant CMD_SUBCHANNEL_RS422           => 207;
use constant CMD_SUBCHANNEL_TCP             => 208;
use constant CMD_SUBCHANNEL_SERVER          => 209;
use constant CMD_SUBCHANNEL_EIGHT_BIT       => 210;
use constant CMD_SUBCHANNEL_TX_LEVEL        => 211;
use constant CMD_SUBCHANNEL_IDLE_TIME       => 212;
use constant CMD_SUBCHANNEL_CONNECT_TIMEOUT => 213;
use constant CMD_SUBCHANNEL_A               => 214;
use constant CMD_SUBCHANNEL_B               => 215;
use constant CMD_NUM_SUBCHANNES             => 216;

=head1 CONSTRUCTOR

=head2 Dugas::CoreTecAPI::new( OPTIONS )

=head2 new Dugas::CoreTecAPI( OPTIONS )

Returns a new B<Dugas::CoreTecAPI> object.  Use the following options to
configure it.

=over

=item timeout => SECS

Specify the timeout (in seconds) for connect and read operations.  Defaults to
B<Dugas::CoreTecAPI::DEFAULT_PORT>.

=back

=cut

sub new
{
    my $class = shift or confess('Missing CLASS parameter');

    my $obj = validate( @_, {
                              timeout => { type    => SCALAR,
                                           default => DEFAULT_TIMEOUT },
                            });

    bless $obj, $class;

    return $obj;
}

=head1 METHODS

=head2 open HOST

=head2 open HOST, PORT

Open a connection to the CoreTec device using the hostname or IP address in
I<HOST>.  Connects via TCP to port I<PORT> or I<DEFAULT_PORT> if omitted.

Returns true on success or C<undef> otherwise.

=cut

sub open {
    my $self = shift or confess('Missing SELF parameter');
    my $host = shift or confess('Missing HOST parameter');
    my $port = shift || DEFAULT_PORT;
    carp("Ignoring extra parameters") if @_;

    my $sock = new IO::Socket::INET(PeerHost => $host,
                                    PeerPort => $port,
                                    Timeout  => $self->{timeout},,
                                    Proto    => 'tcp');
    unless ($sock) {
        error("CoreTecAPI connect failed; $@");
        return undef;
    }

    $self->{sock} = $sock;
    return 1;
}

=head2 close

Close the connection if it's open.

=cut

sub close {
    my $self = shift or confess('Missing SELF parameter');
    carp("Ignoring extra parameters") if @_;

    if ($self->is_open()) {
        $self->{sock}->close();
        undef $self->{sock};
    }
}

=head2 is_open

Returns true of the connection to the CoreTec device is open.

=cut

sub is_open {
    my $self = shift or confess('Missing SELF parameter');
    carp("Ignoring extra parameters") if @_;

    return (exists $self->{sock} && defined $self->{sock});
}

=head2 reset

Perfrom a reset of the encode/decode operation.

=cut

sub reset {
    my $self = shift or confess('Missing SELF parameter');
    carp("Ignoring extra parameters") if @_;
    croak("Not connected") unless $self->is_open();
    $self->_cmd(CMD_RESET);
}

=head2 play

Start the encode/decode operation.

=cut

sub play {
    my $self = shift or confess('Missing SELF parameter');
    carp("Ignoring extra parameters") if @_;
    croak("Not connected") unless $self->is_open();
    $self->_cmd(CMD_PLAY);
}

=head2 stop

Stop the encode/decode operation.

=cut

sub stop {
    my $self = shift or confess('Missing SELF parameter');
    carp("Ignoring extra parameters") if @_;
    croak("Not connected") unless $self->is_open();
    $self->_cmd(CMD_STOP);
}

=head2 version

Returns the formware version.

=cut

sub version {
    my $self = shift or confess('Missing SELF parameter');
    carp("Ignoring extra parameters") if @_;
    croak("Not connected") unless $self->is_open();
    return $self->get(CMD_DEVICE_VERSION);
}

=head2 video_status

Returns the video input status for an encoder.

=cut

sub video_status {
    my $self = shift or confess('Missing SELF parameter');
    croak("Ignoring extra parameters") if @_;
    return unpack('V', $self->get(CMD_CHECK_VIDEO_STATUS));
}

=head2 video_uptime

Returns the video stream uptime (on seconds) for a decoder.

=cut

sub video_uptime {
    my $self = shift or confess('Missing SELF parameter');
    carp("Ignoring extra parameters") if @_;
    croak("Ignoring extra parameters") if @_;
    return unpack('V', $self->get(CMD_VIDEO_UPTIME));
}

=head2 name

=head2 name NAME

Get/set the device name.

=cut

sub name {
    my $self = shift or confess('Missing SELF parameter');
    my $name = shift;
    carp("Ignoring extra parameters") if @_;
    croak("Ignoring extra parameters") if @_;

    if (defined $name) {
        $self->set(CMD_DEVICE_NAME, $name);
    } else {
        return $self->get(CMD_DEVICE_NAME);
    }
}

=head2 set COMMAND

=head2 set COMMAND, DATA

Send the I<COMMAND>, with I<DATA> if specified.  Returns true on success and
C<undef> otherwise.

=cut

sub set {
    my $self = shift or confess('Missing SELF parameter');
    my $cmd  = shift or confess('Missing COMMAND parameter');
    my $data  = shift or confess('Missing COMMAND parameter');
    carp("Ignoring extra parameters") if @_;
    croak("Ignoring extra parameters") if @_;

    my $pkt = pack('VVVVVa', PKT_SYNC1, PKT_SYNC2, PKT_VERSION, $cmd, 
                   ($data ? length($data) : 0),
                   ($data ? $data : ''));
    hexdump('set', $pkt);

    unless ($self->{sock}->send($pkt) == length($pkt)) {
        error("send() failed; $!");
        return undef;
    }

    return 1;
}

=head2 get COMMAND

Send a I<CMD_QUERY> for the I<COMMAND> value and wait for the response.
Returns the raw data from the response.

=cut

sub get {
    my $self = shift or confess('Missing SELF parameter');
    my $get  = shift or confess('Missing COMMAND parameter');
    carp("Ignoring extra parameters") if @_;
    croak("Ignoring extra parameters") if @_;

    unless ($self->set(CMD_QUERY, pack('v', $get))) {
        error("set(CMD_QUERY) failed; $!");
        return undef;
    }

    my $pkt;
    unless (defined $self->{sock}->recv($pkt, 20)) {
        error("recv(head) failed; $!");
        return undef;
    }
    hexdump('get_head', $pkt);
    unless (length($pkt) == 20) {
        error("recv(head) got %d instead of 20", length($pkt));
        return undef;
    }

    my ($sync1, $sync2, $ver, $got, $len) = unpack('VVVVV', $pkt);
    unless (PKT_SYNC1 == $sync1 && PKT_SYNC2 == $sync2 && PKT_VERSION == $ver) {
        error("Invalid packet header");
        return undef;
    }

    if ($len) {
        $self->{sock}->recv($pkt, $len);
        hexdump('data', $pkt);
        unless (length($pkt) == $len) {
            error("recv(data) got %d instead of %d", length($pkt), $len);
            return undef;
        }
    } else {
        $pkt = undef;
    }

    unless ($got == $got) {
        error("Got %d instead of %d", $got, $get);
        return undef;
    }

    return $pkt;
}

=head1 AUTHOR

Paul Dugas, <paul@dugas.cc>

=head1 BUGS

Please report any bugs or feature requests using the project page at
L<http://github.com/pdugas/perl-Dugas>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Dugas::CoreTecAPI

=head1 ACKNOWLEDGEMENTS

(none)

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

1; # End of Dugas::App

# -----------------------------------------------------------------------------
# vim: set et sw=4 ts=4 :
