# -----------------------------------------------------------------------------
# perl-Dugas - The Dugas Enterprises Perl Modules
# Copyright (C) 2013-2016 by Paul Dugas and Dugas Enterprises, LLC
# -----------------------------------------------------------------------------

package Dugas::Monitoring::Plugin;

use 5.006;
use strict;
use warnings FATAL => 'all';
use parent 'Monitoring::Plugin';

use Carp;
use Config::IniFiles;
use Dugas::Logger;
use Dugas::Monitoring;
use Dugas::Util;
use FindBin;
use JSON;
use LWP::Simple;
use Monitoring::Plugin::Performance use_die => 1;
use Net::OpenSSH;
use Params::Validate qw(:all);
use Pod::Usage;
use SNMP;
use URI;

=head1 NAME

Dugas::Monitoring::Plugin - Framework for Nagios Plugins

=head1 VERSION

Version 0.1

=cut

our $VERSION = '0.1';

=head1 SYNOPSIS

    use Dugas::Monitoring::Plugin;

    my $plugin = new Dugas::Monitoring::Plugin();
    $plugin->add_arg(
        spec => 'foo|f',
        help => "-f, --foo\n".
                "   Enable foo",
    );
    $plugin->getopts;

    $plugin->info("Doing stuff");

    $plugin->plugin_exit(OK, "All good");

=head1 EXPORT

The constants exported by B<Monitoring::Plugin> (i.e. OK, WARNING, CRITICAL,
etc.) are similarly exported by default.  The C<:STATUS> tag can be used to
import them as a set.  The C<:all> tag imports everything.

=cut

use Exporter;
our @EXPORT = qw(OK WARNING CRITICAL UNKNOWN DEPENDENT);
our @EXPORT_OK = qw();
our %EXPORT_TAGS = (
    STATUS => [qw(OK WARNING CRITICAL UNKNOWN DEPENDENT)],
    all    => [@EXPORT, @EXPORT_OK],
);

use constant OK         => Monitoring::Plugin::OK;
use constant WARNING    => Monitoring::Plugin::WARNING;
use constant CRITICAL   => Monitoring::Plugin::CRITICAL;
use constant UNKNOWN    => Monitoring::Plugin::UNKNOWN;
use constant DEPENDENT  => Monitoring::Plugin::DEPENDENT;

use constant QUERY_HOST    => 'localhost';
use constant QUERY_BASE    => '/nagios/cgi-bin';
use constant QUERY_OBJECT  => '/objectjson.cgi';
use constant QUERY_STATUS  => '/statusjson.cgi';
use constant QUERY_ARCHIVE => '/archivejson.cgi';

=head1 CONSTRUCTOR

=head2 B<new( OPTIONS )>

Returns a new B<Dugas::Monitoring::Plugin> object.  B<OPTIONS> are
C<key=E<gt>value> pairs that would normally be used to construct a
B<Monitoring::Plugin> object.  Additional options are listed below.

=over

=item B<config =E<gt> FILENAME>

Specifies a runtime configuration file to be loaded very early in the setup
process.  See the L<CONFIGURATION> section below.  If not specified, the
constructor will look for L<etc/nagios.conf>.  No warning is given if this
file cannot be read.

=item B<local =E<gt> BOOL>

If the B<BOOL> value is TRUE, the plugin will not have a B<--hostname> option
and instead expect to be checking a "local" service.

=item B<prev =E<gt> BOOL>

If the B<BOOL> value is TRUE, the plugin will expect to get the PERFDATA 
output and timestamp from a prior run of the plugin.  This adds the 
B<--prevperfdata> program option.

=item B<snmp =E<gt> BOOL>

If the B<BOOL> value is TRUE, the plugin will be configured to use SNMP.  This
adds a number of command-line options as well as the I<snmpget()> and
I<snmpget_table()> methods.  See the L<SNMP METHODS> section below.

=item B<ssh =E<gt> BOOL>

If the B<BOOL> value is TRUE, the plugin will be configured to use SSH adding
a number of program options and the I<ssh()> method.

=back 

=cut

sub new
{
    my $class = shift;

    my %opts = @_;

    # Add/cleanup options
    $opts{license} = sprintf('Copyright (C) 2013-%d Paul Dugas.  '.
                             'All rights reserved.', 1900+(localtime)[5])
        unless $opts{license};
    $opts{version} = $VERSION
        unless $opts{version};
    $opts{extra} = ""
        unless $opts{extra};
    $opts{usage} = "Usage: %s [-v] [-C config] [-L log] [-H hostname]\n"
        unless $opts{usage};

    # The "local" parameter indicates no --hostname option
    my $local;
    if (exists $opts{'local'}) {
        $local = $opts{'local'};
        delete $opts{'local'};
    }

    # The "prev" parameter indicates we should setup handling previous PERFDATA.
    my $prev;
    if (exists $opts{prev}) {
        $prev = $opts{prev};
        delete $opts{prev};
        if ($prev) {
            $opts{usage} .= <<ENDUSAGE;
       [-P <previous perf data from Nagios, i.e. \$SERVICEPERFDATA\$>] 
       [-T <previous time from Nagios, i.e. \$LASTSERVICECHECK\$>]
ENDUSAGE
        }
    }

    # The "snmp" parameter indicates we should setup for SNMP.
    my $snmp;
    if (exists $opts{snmp}) {
        $snmp = $opts{snmp};
        delete $opts{snmp};
        if ($snmp) {
            $opts{usage} .= <<ENDUSAGE;
       [-c snmp_community] [--snmpport port] 
       [--protocol version|-1|-2|-2c|-3] 
       [-l seclevel] [-u secname] 
       [-a authproto] [-A authpasswd] 
       [-x privproto] [-x privpasswd]
ENDUSAGE
        }
    }

    # The "ssh" parameter indicates we should setup for SSH.
    my $ssh;
    if (exists $opts{ssh}) {
        $ssh = $opts{ssh};
        delete $opts{ssh};
        if ($ssh) {
            $opts{usage} .= <<ENDUSAGE;
       [--sshport port] [-u username] [-p password] 
       [-k keypath] [-K keyphrase]
ENDUSAGE
        }
    }

    # Save the "config" setting and don't pass it to the base class.
    my $config = $opts{config} || $FindBin::Bin.'/../etc/nagios.conf';
    delete $opts{config};

    # Construct Monitoring::Plugin baseclass
    my $self = $class->SUPER::new(%opts);

    # Save these
    $self->{local} = $local;
    $self->{prev} = $prev;
    $self->{snmp} = $snmp;
    $self->{ssh} = $ssh;

    # Long-Output starts undefined
    $self->{output} = undef;

    # Setup config
    my $DEFAULT_INI = <<END_DEFAULT_INI;
[snmp]
    community=public
    protocol=1
    port=161
    seclevel=noAuthNoPriv
    secname=
    authproto=MD5
    authpass=
    privproto=DES
    privpass=
[ssh]
    port=22
    username=
    password=
    keypath=
    keyphrase=
END_DEFAULT_INI
    $self->{ini} = Config::IniFiles->new( -file => \$DEFAULT_INI );
    if ($config && -r $config) {
        $self->{ini} = Config::IniFiles->new( -file => $config,
                -import => $self->{ini},
                -fallback => 'GLOBAL',
                -nocase => 1,
                -allowempty => 1 );
        die("Failed to load $config; ".
                join(' ', @Config::IniFiles::errors)) unless $self->{ini};
    }

    # Add the standard arguments
    $self->add_arg(spec     => 'manual|manpage|man',
                   help     => "--man, --manpage, --manual\n".
                               "   Display the manpage");
    $self->add_arg(spec     => 'config|C=s',
                   help     => "-C, --config=STRING\n".
                               "   Runtime config file");
    $self->add_arg(spec     => 'log|L=s',
                   help     => "-L, --log=FILENAME\n".
                               "   Log file");
    $self->add_arg(spec     => 'hostname|H=s',
                   help     => "-H, --hostname=STRING\n".
                               "   Hostname or IP address")
        unless $local;

    # Done
    return $self;
}

=head1 METHODS

=head2 getopts()

We override the B<Monitoring::Plugin>'s getopts() routine to add some additional
logic to loading and validating program options.

=cut

sub getopts
{
    my $self = shift;

    if ($self->{prev}) {
        $self->add_arg(spec     => 'prevperfdata|prev|P=s',
                       help     => "-P, --prev, --prevperfdata=PERFDATA\n".
                                   "   Previous PERFDATA from Nagios, ".
                                   "i.e. \$SERVICEPERFDATA\$",
                       default  => '');
    }

    if ($self->{snmp}) {
        $self->add_arg(spec     => 'community|c=s',
                       help     => "-c, --community=STRING\n".
                                   "   SNMP v1 or v2c community (default: ".
                                   $self->conf('snmp','community').")",
                       default  => $self->conf('snmp','community'));
        $self->add_arg(spec     => 'snmpport=s',
                       help     => "--snmpport=INTEGER\n".
                                   "   SNMP port number (default: ".
                                   $self->conf('snmp','port').")",
                       default  => $self->conf('snmp','port'));
        $self->add_arg(spec     => 'protocol|snmpver=s',
                       help     => "--protocol=[1|2|2c|3]\n".
                                   "   SNMP protocol version (default: 1)");
        $self->add_arg(spec     => '1',
                       help     => "-1\n".
                                   "   Use SNMPv1 (default)");
        $self->add_arg(spec     => '2c|2C|2',
                       help     => "-2, -2c\n".
                                   "   Use SNMPv2c");
        $self->add_arg(spec     => '3',
                       help     => "-3\n".
                                   "   Use SNMPv3");
        $self->add_arg(spec     => 'seclevel|l=s',
                       help     => "-l, --seclevel=".
                                   "[noAuthNoPriv|authNoPriv|authPriv]\n".
                                   "   SNMPv3 securityLevel (default: ".
                                   $self->conf('snmp','seclevel').")",
                       default  => $self->conf('snmp','seclevel'));
        $self->add_arg(spec     => 'secname|snmpuser|u=s',
                       help     => "-u, --snmpuser, --secname=USERNAME\n".
                                   "   SNMPv3 username (default: ".
                                   $self->conf('snmp','secname').")",
                       default  => $self->conf('snmp','secname'));
        $self->add_arg(spec     => 'authproto|a=s',
                       help     => "-a, --authproto=[MD5|SHA]\n".
                                   "   SNMPv3 authentication protocol (default: ".
                                   $self->conf('snmp','authproto').")",
                       default  => $self->conf('snmp','authproto'));
        $self->add_arg(spec     => 'authpass|A=s',
                       help     => "-A, --authpass=PASSWORD\n".
                                   "   SNMPv3 authentication password (default: ".
                                   $self->conf('snmp','authpass').")",
                       default  => $self->conf('snmp','authpass'));
        $self->add_arg(spec     => 'privproto|x=s',
                       help     => "-x, --privproto=[DES|AES]\n".
                                   "   SNMPv3 privacy protocol (default: ".
                                   $self->conf('snmp','privproto').")",
                       default  => $self->conf('snmp','privproto'));
        $self->add_arg(spec     => 'privpass|X=s',
                       help     => "-X, --privpass=PASSWORD\n".
                                   "   SNMPv3 privacy password (default: ".
                                   $self->conf('snmp','privpass').")",
                       default  => $self->conf('snmp','privpass'));
    }

    if ($self->{ssh}) {
        $self->add_arg(spec     => 'sshuser=s',
                       help     => "--sshuser=STRING\n".
                                   "   SSH username (default: ".
                                   ($self->conf('ssh','username')||$ENV{USER}).")",
                       default  => $self->conf('ssh','username')||$ENV{USER});
        $self->add_arg(spec     => 'sshport=s',
                       help     => "--sshport=INT\n".
                                   "   SSH port (default: ".
                                   $self->conf('ssh','port').")",
                       default  => $self->conf('ssh','port'));
        $self->add_arg(spec     => 'sshpass=s',
                       help     => "-sshpass=STRING\n".
                                   "   SSH password",
                       default  => $self->conf('ssh','password'));
        $self->add_arg(spec     => 'sshkeypath|keypath=s',
                       help     => "--keypath=FILENAME\n".
                                   "   SSH private key file (default: ".
                                   $self->conf('ssh','keypath').")",
                       default  => $self->conf('ssh','keypath'));
        $self->add_arg(spec     => 'sshkeyphrase|keyphrase=s',
                       help     => "--keyphrase=PASSPHRASE\n".
                                   "   Passphrase to unlock the key (default: ".
                                   $self->conf('ssh','keyphrase').")",
                       default  => $self->conf('ssh','keyphrase'));
    }

    $self->SUPER::getopts();

    pod2usage(-exitval => 0, -verbose => 2)
        if ($self->opts->manual);

    $self->nagios_die("Missing --hostname option")
        if (!$self->{local} && !defined $self->opts->hostname);

    if ($self->opts->config) {
        die("Can't find or read ".$self->opts->config)
            unless -r $self->opts->config;
        $self->{ini} = Config::IniFiles->new( -file => $self->opts->config,
                -import => $self->{ini},
                -fallback => 'GLOBAL',
                -nocase => 1,
                -allowempty => 1 );
        die("Failed to load ".$self->opts->config."; ".
                join(' ', @Config::IniFiles::errors)) unless $self->{ini};
    }

    my $lvl = Dugas::Logger::level();
    $lvl += $self->opts->verbose || $self->conf('logger', 'verbose', 0);
    Dugas::Logger::level($lvl);

    if ($self->{snmp}) {
        $self->{proto} = undef;
        if (defined $self->opts->protocol) {
            if ($self->opts->protocol =~ /^\s*1\s*$/) {
                $self->{proto} = 1;
            } elsif ($self->opts->protocol =~ /^\s*2c?\s*$/i) {
                $self->{proto} = 2;
            } elsif ($self->opts->protocol =~ /^\s*3\s*$/i) {
                $self->{proto} = 3;
            }
        }
        if (defined $self->opts->{'1'}) {
            fatal("Please use --protocol or -1|-2|-2c|-3 to set SNMP version. ".
                  "Not both.") if defined $self->{proto};
            $self->{proto} = 1;
        }
        if (defined $self->opts->{'2'}) {
            fatal("Please use --protocol or -1|-2|-2c|-3 to set SNMP version. ".
                  "Not both.") if defined $self->{proto};
            $self->{proto} = 2;
        }
        if (defined $self->opts->{'2c'}) {
            fatal("Please use --protocol or -1|-2|-2c|-3 to set SNMP version. ".
                  "Not both.") if defined $self->{proto};
            $self->{proto} = 2;
        }
        if (defined $self->opts->{'3'}) {
            fatal("Please use --protocol or -1|-2|-2c|-3 to set SNMP version. ".
                  "Not both.") if defined $self->{proto};
            $self->{proto} = 3;
        }
        $self->{proto} = 1 unless $self->{proto};
    }

    if (my $log = $self->opts->log || $self->conf('logger', 'logfile')) {
        $log =~ s/%s/$FindBin::Script/;
        $log =~ s/%d/getpid()/e;
        Dugas::Logger::open($log);
    }
}

=head1 PROGRAM OPTIONS

The B<Monitoring::Plugin> baseclass provides the standard B<--verbose>,
B<--version>, B<--help>, etc. command-line options.  This class adds the
following:

=over

=item B<-C | --config FILENAME>

Specify a runtime configuration file to load.  This is loaded in addition to
the default file specified with the "config" constructor parameter.  See the
L<CONFIGURATION> section below.

=item B<-L | --log FILENAME>

Specify a log file to append diagnostic logger message to.

=item B<-H | --hostname HOSTNAME|ADDRESS>

Specify the hostname or IP address of the device to check.

=item B<-c | --community COMMUNITY> (SNMP only)

Specify the SNMP community string to use.  Only available if the "snmp" 
constructor parameter was given.  Defaults to the "community" value in the
[snmp] section of the configuration file.

=item B<--snmpport PORT> (SNMP only)

Specify the SNMP port number to use.  Only available if the "snmp" 
constructor parameter was given.  Defaults to the "port" value in the
[snmp] section of the configuration file.

=item B<--protocol [1|2|2c|3]> or B<-1|-2|-2c|-3> (SNMP only)

Specify the SNMP protocol version to use.  Only available if the "snmp" 
constructor parameter was given.  Defaults to the "protocol" value in the
[snmp] section of the configuration file.

=item B<-l | --seclevel [noAuthNoPriv|authNoPriv|authPriv]> (SNMP only)

Specify the SNMPv3 security level to use.  Only available if the "snmp" 
constructor parameter was given.  Defaults to the "seclevel" value in the
[snmp] section of the configuration file.

=item B<-u | --secname USERNAME> (SNMP only)

Specify the SNMPv3 username to use.  Only available if the "snmp" 
constructor parameter was given.  Defaults to the "secname" value in the
[snmp] section of the configuration file.

=item B<-a | --authproto [MD5|SHA]> (SNMP only)

Specify the SNMPv3 authentication protocol to use.  Only available if the
"snmp" constructor parameter was given.  Defaults to the "authproto" value in
the [snmp] section of the configuration file.

=item B<-A | --authpass PASSWORD> (SNMP only)

Specify the SNMPv3 authentication password to use.  Only available if the
"snmp" constructor parameter was given.  Defaults to the "authpass" value
in the [snmp] section of the configuration file.

=item B<-x | --privproto [DES|AES]> (SNMP only)

Specify the SNMPv3 privacy protocol to use.  Only available if the
"snmp" constructor parameter was given.  Defaults to the "privproto" value
in the [snmp] section of the configuration file.

=item B<-X | --privpass PASSWORD> (SNMP only)

Specify the SNMPv3 privacy password to use.  Only available if the
"snmp" constructor parameter was given.  Defaults to the "privpass" value
in the [snmp] section of the configuration file.

=item B<-P | --prevperfdata PERFDATA> (PREV only)

Provide the PERFDATA output from a previous check.  Only available if the
"prev" constructor parameter was given.  This is typically used with a Nagios
command definition that includes C<-P $SERVICEPERFDATA$>.

=back

=head1 RUNTIME CONFIGURATION

The constructor accepts a C<config =E<gt> FILENAME> option that specifies a 
default file to be loaded early in the setup process.  The B<--config>
command-line parameter many be used to specify another file to be loaded in
addition to the default.  Either should point to an INI-style runtime
configuration file.  If no config files are provided, the
defaults are as follows:

    [logger]
      logfile=

    [snmp]
      community=public
      protocol=1
      port=161
      seclevel=noAuthNoPriv
      secname=
      authproto=MD5
      authpass=
      privproto=DES
      privpass=

=head2 conf( SECTION, KEY, [ DEFAULT ] )

Returns the value of the B<KEY> in the B<SECTION> of the config file or the
B<DEFAULT> value if the key or section don't exist.

=cut

sub conf
{
    my $self    = shift or confess("Missing SELF parameter");
    my $section = shift or confess("Missing SECTION parameter");
    my $key     = shift or confess("Missing KEY parameter");
    my $default = shift;

    return $self->{ini}->val($section, $key, $default);
}

=head1 BASECLASS METHODS

The following B<Monitoring::Plugin> methods are being extended.

=head2 plugin_exit( CODE, MESSAGE, [LONG_TEXT] )

We've extended the baseclass version to add the lines from C<add_output()>.

=cut

sub plugin_exit
{
    my $self = shift or confess('Missing SELF parameter');
    my $code = shift; $code = uc($code) unless $code =~ /^\d+$/;
    my $msg  = shift;
    my $long = shift;

    $msg .= "\n".join("\n", @{$self->{output}}) if $self->{output};
    $msg .= "\n".$long                          if $long;

    return $self->SUPER::plugin_exit($code, $msg);
}

=head2 check_messages( [OPTIONS] )

We add join=>', ' and join_all=>' and ' as default OPTIONs.  See
L<Monitoring::Plugin::Functions> for details on the available OPTIONs.

=cut

sub check_messages
{
    my $self = shift or confess('Missing SELF parameter');
    my $opts = {@_};

    $opts->{join}     = ', '    unless exists $opts->{join};
    $opts->{join_all} = ' and ' unless exists $opts->{join_all};

    return $self->SUPER::check_messages( %{$opts} );
}

=head1 LONG-OUTPUT SUPPORT

Support for adding the I<LONG TEXT> lines described in the plugin API at
http://assets.nagios.com/downloads/nagioscore/docs/nagioscore/4/en/pluginapi.html

=head2 add_output( LONG_TEXT, [LONG_TEXT, ...] )

Add one or more I<LONG_TEXT> lines to the plugin output.

=cut

sub add_output
{
    my $self = shift or confess('Missing SELF parameter');
    return unless scalar(@_);
    $self->{output} = [] unless $self->{output};
    push @{$self->{output}}, @_;
}

=head1 SNMP SUPPORT

The following methods and constants for use when the C<snmp> parameter was
passed to the constructor.

=head2 snmp()

Returns an B<SNMP::Session> object configured using the program options provided
and runtime configuration.  

=cut

sub snmp
{
    my $self = shift or confess('Missing SELF parameter');
    if ($self->{snmp}) {
        $self->{snmpSession} = SNMP::Session->new($self->snmp_opts())
            unless $self->{snmpSession};
    } else {
        error("Plugin not configured for SNMP!");
    }
    return $self->{snmpSession};
}

=head2 snmp_opts()

Returns a hashref for initializing an L<SNMP::Session> object.

=cut

sub snmp_opts
{
    my $self = shift or confess('Missing SELF parameter');

    my %opts;

    unless ($self->{snmp}) {
        error("Plugin not configured for SNMP!");
        return %opts;
    }

    my $dest = $self->opts->hostname;
    if ($self->opts->snmpport =~ /^((tcp|udp):)?(.*)$/i) { 
        $dest = ($1//'')."$dest:$3"; 
    }

    %opts = (
        DestHost    => $dest,
        Version     => $self->{proto},
        Timeout     => $self->opts->timeout * 1000000, # micro-seconds
        RetryNoSuch => 1,
        Community   => $self->opts->community,
        SecLevel    => $self->opts->seclevel,
        SecName     => $self->opts->secname,
        AuthProto   => $self->opts->authproto,
        AuthPass    => $self->opts->authpass,
        PrivProto   => $self->opts->privproto,
        PrivPass    => $self->opts->privpass,
        UseEnums    => 1,
    );

    $opts{community} = $self->opts->community
        if ($self->opts->community && $self->{proto} != 3);

    if ($self->{proto} == 3) {

        fatal("Both --seclevel and --secname required for SNMPv3")
            unless ($self->opts->seclevel && $self->opts->secname);

        $opts{username} = $self->opts->secname;

        fatal("Invalid --seclevel value; \"$self->opts->seclevel\"")
            unless ($self->opts->seclevel =~ /^(no)?auth(no)?priv$/i);
        my ($auth, $priv) = (!$1, !$2);

        if ($auth) {
            fatal("Invalid --authproto value; \"$self->opts->authproto\"")
                unless ($self->opts->authproto =~ /^(MD5|SHA)$/i);
            $opts{authprotocol} = $self->opts->authproto;

            fatal("Missing --authpass")
                unless (defined $self->opts->authpass);
            if ($self->opts->authpass =~ /^0x/) {
                $opts{authkey} = $self->opts->authpass;
            } else {
                $opts{authpass} = $self->opts->authpass;
            }
        }

        if ($priv) {
            fatal("Invalid --privproto value; \"$self->opts->privproto\"")
                unless ($self->opts->privproto =~ /^(DES|AES)$/i);
            $opts{privprotocol} = $self->opts->privproto;

            fatal("Missing --privpass")
                unless (defined $self->opts->privpass);
            if ($self->opts->privpass =~ /^0x/) {
                $opts{privkey} = $self->opts->privpass;
            } else {
                $opts{privpass} = $self->opts->privpass;
            }
        }

    }

    return %opts;
}

=head1 SSH SUPPORT

The following methods are enabled if the C<ssh> parameter was passed to the
constructor.

=head2 ssh()

Returns a B<Net::OpenSSH> object configured using the program options provided
and runtime configuration.

=cut

sub ssh
{
    my $self = shift or confess('Missing SELF parameter');

    unless ($self->{ssh}) {
        error("Plugin not configured for SSH!");
        return undef;
    }

    unless ($self->{openssh}) {
        my %opts = ();
        $opts{port}       = $self->opts->sshport
            if length $self->opts->sshport;
        $opts{user}       = $self->opts->sshuser
            if length $self->opts->sshuser;
        $opts{password}   = $self->opts->sshpass
            if length $self->opts->sshpass;
        $opts{key_path}   = $self->opts->sshkeypath
            if length $self->opts->sshkeypath;
        $opts{passphrase} = $self->opts->sshkeyphrase
            if length $self->opts->sshkeyphrase;
        $opts{batch_mode} = 1; # don't prompt for passwords, just fail
            my $ssh = new Net::OpenSSH($self->opts->hostname, %opts);
        if ($ssh->error) {
            $self->{openssh_error} = $ssh->error;
            return undef;
        }
        $self->{openssh} = $ssh;
        undef $self->{openssh_error};
    }
    return $self->{openssh};
}

=head2 ssh_error()

Returns the C<Net::OpenSSH::error> value from the last call to C<ssh()>.

=cut

sub ssh_error
{
    my $self = shift or confess('Missing SELF parameter');
    return $self->{openssh_error};
}

=head2 ssh_system()

Shorthand for the system() method on the B<Net::OpenSSH> object returned by the
ssh() method.

=cut

sub ssh_system
{
    my $self = shift or confess("Missing SELF parameter");
    return $self->ssh()->system(@_);
}

=head2 ssh_capture()

Shorthand for the capture() method on the B<Net::OpenSSH> object returned by
the ssh() method.

=cut

sub ssh_capture
{
    my $self = shift or confess("Missing SELF parameter");
    return $self->ssh()->capture(@_);
}

=head2 ssh_pipe()

Shorthand for the pipe() method on the B<Net::OpenSSH> object returned by the
ssh() method.

=cut

sub ssh_pipe
{
    my $self = shift or confess("Missing SELF parameter");
    return $self->ssh()->pipe_in(@_);
}

=head1 PREVIOUS PERFDATA

The following methods provide access to performance data from the previous run
of the plugin.  These are only avialble if the C<prev> parameter was passed
to the constructor.  They rely on the C<--prevperfdata> parameter being
provided on the command line.  Typically, we create a command object in the
monitoring system like below when deltas are to be reported.  The performance
data from the previous time the service was checked will be available then.

    define command {
        command_name eg-check-foo
        command_line $USER1$/eg/check-foo -H $HOSTADDRESS --prev '$SERVICEPERFDATA$'
    }

=head2 prev()

Returns a reference to a hash that contains the parsed previous performance 
data.  There will be a key matching each entry in the perfdata and the values
will be B<Monitoring::Plugin::Performance> objects.

=cut

sub prev
{
    my $self = shift or confess('Missing SELF parameter');

    unless ($self->{prev}) {
        error("Plugin not configured for PREV!");
        return undef;
    }

    $self->{prevData} = _parse_perfdata($self->opts->prevperfdata)
        unless exists $self->{prevData};

    return $self->{prevData};
}

=head1 JSON QUERY METHODS

Nagios-4.0.7 and beyond provides a JSON Query integration API.  The methods
below provide an interface to these queries.  See C</nagios/jsonquery.html> on
your Nagios server for details.

The C<OPTIONS> passed to these C<query_*> methods are passed along as HTTP
query parameters verbatem with the exception of the options below which are
used to build the URL and are not passwd as query parameters.

=over

=item B<host =E<gt> HOSTNAME|IPADDRESS>

Specify the hostname or IP address of the Nagios server.  Defaults to
C<localhost>.

=item B<user =E<gt> USERNAME>

Specify the username to connect with.  Not defined by default.

=item B<pass =E<gt> PASSWORD>

Specify the password to connect with.  Not defined by default.  Only used if
C<user> is specified.

=item B<base =E<gt> URI>

Specify the base URI to connect to.  Defaults to C</nagios/cgi-bin>.

=back

=head2 $hostlist = query_hostlist( OPTIONS )

Returns a hashref representing the results of an Object JSON CGI 'hostlist'
query.  Returns C<undef> if the request fails.

=cut

sub query_hostlist
{
    my $self = shift or confess('Missing SELF parameter');
    return $self->_query(type=>QUERY_OBJECT, query=>'hostlist', @_);
}

=head2 $status = query_status_host( HOST, OPTIONS )

Returns a hashref representing the results of an Status JSON CGI 'host'
query.  Returns C<undef> if the request fails.

=cut

sub query_status_host
{
    my $self = shift or confess('Missing SELF parameter');
    my $host = shift or confess('Missing HOST parameter');
    return $self->_query(type=>QUERY_STATUS, query=>'host', hostname=>$host, 
                         @_);
}

=head2 $status = query_status_service( HOST, SERVICE, OPTIONS )

Returns a hashref representing the results of an Status JSON CGI 'service'
query.  Returns C<undef> if the request fails.

=cut

sub query_status_service
{
    my $self    = shift or confess('Missing SELF parameter');
    my $host    = shift or confess('Missing HOST parameter');
    my $service = shift or confess('Missing SERVICE parameter');
    return $self->_query(type=>QUERY_STATUS, query=>'service', hostname=>$host,
                         servicedescription=>$service, @_);
}

# Internal utility to perform a Nagios JSON Query
sub _query
{
    my $self = shift or confess('Missing SELF parameter');
    my %opts = ( formatoptions=>'enumerate', @_ );

    my $host = $opts{host} // QUERY_HOST; delete $opts{host};
    my $base = $opts{base} // QUERY_BASE; delete $opts{base};
    my $user = $opts{user};               delete $opts{host};
    my $pass = $opts{pass};               delete $opts{host};
    my $type = $opts{type};               delete $opts{type};

    confess('Missing TYPE parameter') unless $type;

    my $url = 'http://'.$host.$base.$type;
    $url = URI->new($url);
    $url->query_form(%opts);
    my $ua  = LWP::UserAgent->new;
    my $req = HTTP::Request->new(GET => $url);
    $req->authorization_basic($user||'', $pass||'') if ($user || $pass);

    my $res = $ua->request($req);
    if ($res->is_error) {
        error("Query failed; ", $res->status_line);
        return undef;
    }

    my $ret = decode_json $res->content;
    unless (defined $ret &&
            exists $ret->{result}{type_code} && 
            $ret->{result}{type_code} == 0) {
        error("Query failed; ".$ret->{result}{message});
        return undef;
    }

    return $ret;
}

=head1 OTHER METHODS

A handful of other methods that don't go elsewhere...

=head2 get_http( URI )

Returns the content of an HTTP request to the given URI on the host.

=cut

sub get_http
{
    my $self = shift or confess('Missing SELF parameter');
    my $uri  = shift or confess('Missing URI parameter');
    my $opts = validate(@_, {
        user => { type=>SCALAR,
                  default=>(UNIVERSAL::can($self->opts, "user")
                            ? $self->opts->user : undef) },
        pass => { type=>SCALAR,
                  default=>(UNIVERSAL::can($self->opts, "pass")
                            ? $self->opts->pass : undef) },
        port => { type=>SCALAR,
                  default=>(UNIVERSAL::can($self->opts, "port")
                            ? $self->opts->port : undef)},
    });

    $self->plugin_exit(UNKNOWN,
                       "The get_http() method is only ".
                       "supported when --hostname is set.")
        unless !$self->{local} && $self->opts->hostname;

    my $url = 'http://'.$self->opts->hostname;
    $url .= ':'.$opts->{port} if $opts->{port};
    $url .= $uri;

    my $ua  = LWP::UserAgent->new;
    my $req = HTTP::Request->new(GET => $url);

    $req->authorization_basic($opts->{user}||'', $opts->{pass}||'')
        if ($opts->{user} || $opts->{pass});

    my $res = $ua->request($req);
    return undef if $res->is_error;
    return $res->content;
}

# Internal utility for parsing perfdata strings into a hash of 
# Monitoring::Plugin::Performance objects indexes by label.
sub _parse_perfdata
{
  my $perfdata = shift || '';
  my $ret = {};
  foreach (Monitoring::Plugin::Performance->parse_perfstring($perfdata))
    { $ret->{$_->label} = $_; }
  return $ret;
}

sub _sort_keys
{
  my (@oids, @others);
  foreach (keys %{$_[0]}) {
    if (/^(\.\d+)+$/) { push @oids, $_; } else { push @others, $_; }
  }
  return [ Net::SNMP::oid_lex_sort(@oids), sort @others ];
}

=head1 SEE ALSO

B<Monitoring::Plugin>, B<Dugas::Logger>

=head1 AUTHOR

Paul Dugas, <paul@dugas.cc>

=head1 BUGS

Please report any bugs or feature requests using the project page at
L<http://github.com/pdugas/perl-Dugas>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Dugas::Monitoring::Plugin

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

1; # End of Dugas::Monitoring::Plugin

# -----------------------------------------------------------------------------
# vim: set et ts=4 sw=4 :
