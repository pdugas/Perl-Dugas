# =============================================================================
# Perl-Dugas - The Dugas Family of Perl Modules
# =============================================================================
# @file     lib/Dugas/Nagios/Plugin.pm
# @brief    Custom version of the standard Nagios::Plugin with our additions.
# @author   Paul Dugas <paul@dugas.cc>
# =============================================================================

package Dugas::Nagios::Plugin;

use 5.006;
use strict;
use warnings FATAL => 'all';
use parent 'Nagios::Plugin';
use Config::IniFiles;
use Net::SNMP;
use Net::OpenSSH;
use Dugas;
use Dugas::Logger;
use Dugas::Nagios;

=head1 NAME

Dugas::Nagios::Plugin - Framework for Nagios Plugins

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

    use Dugas::Nagios::Plugin;

    my $plugin = new Dugas::Nagios::Plugin();
    $plugin->add_arg(
        spec => 'foo|f',
        help => "-f, --foo\n"."   Enable foo",
    );
    $plugin->getopts;

    $plugin->info("Doing stuff");

    $plugin->nagios_exit( OK, "All good" );

=head1 EXPORT

The constants exported by B<Nagios::Plugin> (i.e. OK, WARNING, CRITICAL, etc.)
are similarly exported by default here.  

=cut

use Exporter;
our @EXPORT = qw(OK WARNING CRITICAL UNKNOWN DEPENDENT);
our @EXPORT_OK = qw();

use constant OK         => Nagios::Plugin::OK;
use constant WARNING    => Nagios::Plugin::WARNING;
use constant CRITICAL   => Nagios::Plugin::CRITICAL;
use constant UNKNOWN    => Nagios::Plugin::UNKNOWN;
use constant DEPENDENT  => Nagios::Plugin::DEPENDENT;

=head1 CONSTRUCTOR

=head2 B<new( OPTIONS )>

Returns a new B<Dugas::Nagios::Plugin> object.  B<OPTIONS> are
C<key=E<gt>value> pairs that would normally be used to construct a
B<Nagios::Plugin> object.  Additional options are listed below.

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
B<--prev-perfdata> and B<--prev-checktime> program options.

=item B<snmp =E<gt> BOOL>

If the B<BOOL> value is TRUE, the plugin will be configured to use SNMP.  This
adds a number of command-line options as well as the I<snmp_get()> and
I<snmp_get_table()> methods.  See the L<SNMP METHODS> section below.

=item B<ssh =E<gt> BOOL>

If the B<BOOL> value is TRUE, the plugin will be configured to use SSH adding
a number of program options and the I<ssh()> method.

=back 

=cut

sub new {
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
  $opts{extra} .= <<ENDEXTRA;

Please submit defect reports or feature requests to the project at
http://github.com/pdugas/Perl-Dugas/.
ENDEXTRA
  $opts{usage} = "Usage: %s [-v] [--config CONFIG] [--log LOG] [-H HOST]\n"
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
    fatal("Can't use both \"snmp\" and \"ssh\" parameters in constructor.")
      if exists $opts{ssh};
    $snmp = $opts{snmp};
    delete $opts{snmp};
    if ($snmp) {
      $opts{usage} .= <<ENDUSAGE;
       [-C community] [-p port] [-1|2|2c|3] [-L seclevel] [-U secname] 
       [-a authproto] [-A authpass] [-x privproto] [-X privpass]
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
       [-u username] [-p password] [-k keypath]
ENDUSAGE
    }
  }

  # Save the "config" setting and don't pass it to the base class.
  my $config = $opts{config} || $FindBin::Bin.'/../etc/nagios.conf';
  delete $opts{config};

  # Construct Nagios::Plugin baseclass
  my $self = $class->SUPER::new(%opts);

  # Save these
  $self->{local} = $local;
  $self->{prev} = $prev;
  $self->{snmp} = $snmp;
  $self->{ssh} = $ssh;

  # Setup config
  my $DEFAULT_INI = <<END_DEFAULT_INI;
[snmp]
  community=public
  protocol=1
  port=161
  seclevel=noAuthNoPriv
  secname=
  authproto=MD5
  authpassword=
  privproto=DES
  privpassword=
[ssh]
  username=
  password=
  keypath=
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

  # Add the PREVIOUS arguments
  #   - Using -P and -T after seeing a handful of existing plugins us it.
  if ($prev) {
    $self->add_arg(spec     => 'prev-perfdata|P=s',
                   help     => "-P, --prev-perfdata=PERFDATA\n".
                               "   Previous PERFDATA from Nagios, ".
                               "i.e. \$SERVICEPERFDATA\$",
                   default  => undef);
    $self->add_arg(spec     => 'prev-checktime|T=s',
                   help     => "-T, --prev-checktime=TIMESTAMP\n".
                               "   Previous check time from Nagios, ".
                               "i.e. \$LASTSERVICECHECK\$",
                   default  => undef);
  }

  # Add the SNMP arguments
  if ($snmp) {
    $self->add_arg(spec     => 'community|c=s',
                   help     => "-c, --community=STRING\n".
                               "   SNMP v1 or v2c community (default: ".
                               $self->conf('snmp','community').")",
                   default  => $self->conf('snmp','community'));
    $self->add_arg(spec     => 'snmpport|p=i',
                   help     => "-p, --snmpport=INTEGER\n".
                               "   SNMP port number (default: ".
                               $self->conf('snmp','port').")",
                   default  => $self->conf('snmp','port'));
    $self->add_arg(spec     => 'protocol=s',
                   help     => "--protocol=[1|2|2c|3]\n".
                               "   SNMP protocol version (default: 1)");
    $self->add_arg(spec     => '1',
                   help     => "-1\n".
                               "   Use SNMPv1 (default)");
    $self->add_arg(spec     => '2c|2C|2',
                   help     => "-2\n".
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
    $self->add_arg(spec     => 'secname|u=s',
                   help     => "-u, --secname=USERNAME\n".
                               "   SNMPv3 username (default: ".
                               $self->conf('snmp','secname').")",
                   default  => $self->conf('snmp','secname'));
    $self->add_arg(spec     => 'authproto|a=s',
                   help     => "-a, --authproto=[MD5|SHA]\n".
                               "   SNMPv3 authentication protocol (default: ".
                               $self->conf('snmp','authproto').")",
                   default  => $self->conf('snmp','authproto'));
    $self->add_arg(spec     => 'authpassword|A=s',
                   help     => "-A, --authpassword=PASSWORD\n".
                               "   SNMPv3 authentication password (default: ".
                               $self->conf('snmp','authpassword').")",
                   default  => $self->conf('snmp','authpassword'));
    $self->add_arg(spec     => 'privproto|x=s',
                   help     => "-x, --privproto=[DES|AES]\n".
                               "   SNMPv3 privacy protocol (default: ".
                               $self->conf('snmp','privproto').")",
                   default  => $self->conf('snmp','privproto'));
    $self->add_arg(spec     => 'privpassword|X=s',
                   help     => "-X, --privpassword=PASSWORD\n".
                               "   SNMPv3 privacy password (default: ".
                               $self->conf('snmp','privpassword').")",
                   default  => $self->conf('snmp','privpassword'));
  }

  # Add the SSH arguments
  if ($ssh) {
    $self->add_arg(spec     => 'username|u=s',
                   help     => "-u, --username=STRING\n".
                               "   SSH username (default: ".
                               $self->conf('ssh','username').")",
                   default  => $self->conf('ssh','username'));
    $self->add_arg(spec     => 'password|p=s',
                   help     => "-p, --password=STRING\n".
                               "   SSH password",
                   default  => $self->conf('ssh','password'));
    $self->add_arg(spec     => 'keypath|k=s',
                   help     => "-k, --keypath=FILENAME\n".
                               "   SSH private key file (default: ".
                               $self->conf('ssh','keypath').")",
                   default  => $self->conf('ssh','keypath'));
  }

  # Done
  return $self;
}

=head1 METHODS

=head2 getopts ( )

We override the B<Nagios::Plugin>'s getopts() routine to add some additional
logic to loading and validating program options.

=cut

sub getopts {
  my $self = shift;
  $self->SUPER::getopts();

  # Load CONFIG.
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

  # Setup logger.
  my $lvl = Dugas::Logger::level();
  $lvl += $self->opts->verbose || $self->conf('logger', 'verbose', 0);
  Dugas::Logger::level($lvl);

  if ($self->{snmp}) {
    # Check PROTOCOL.
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
      fatal("Please use either --protocol or -1|-2|-2c|-3 to set SNMP version.")
        if defined $self->{proto};
      $self->{proto} = 1;
    }
    if (defined $self->opts->{'2c'}) {
      fatal("Please use either --protocol or -1|-2|-2c|-3 to set SNMP version.")
        if defined $self->{proto};
      $self->{proto} = 2;
    }
    if (defined $self->opts->{'3'}) {
      fatal("Please use either --protocol or -1|-2|-2c|-3 to set SNMP version.")
        if defined $self->{proto};
      $self->{proto} = 3;
    }
    $self->{proto} = 1 unless $self->{proto};
  }

  # Setup logfile.
  if (my $log = $self->opts->log || $self->conf('logger', 'logfile')) {
    $log =~ s/%s/$FindBin::Script/;
    $log =~ s/%d/getpid()/e;
    debug("Opening $log for logging.");
    Dugas::Logger::open($log);
  }
}

=head1 PROGRAM OPTIONS

The B<Nagios::Plugin> baseclass provides the standard B<--verbose>,
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

=item B<-p | --snmpport PORT> (SNMP only)

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

=item B<-A | --authpassword PASSWORD> (SNMP only)

Specify the SNMPv3 authentication password to use.  Only available if the
"snmp" constructor parameter was given.  Defaults to the "authpassword" value
in the [snmp] section of the configuration file.

=item B<-x | --privproto [DES|AES]> (SNMP only)

Specify the SNMPv3 privacy protocol to use.  Only available if the
"snmp" constructor parameter was given.  Defaults to the "privproto" value
in the [snmp] section of the configuration file.

=item B<-X | --privpassword PASSWORD> (SNMP only)

Specify the SNMPv3 privacy password to use.  Only available if the
"snmp" constructor parameter was given.  Defaults to the "privpassword" value
in the [snmp] section of the configuration file.

=item B<-P | --prev-perfdata PERFDATA> (PREV only)

Provide the PERFDATA output from a previous check.  Only available if the
"prev" constructor parameter was given.  This is typically used with a Nagios
command definition that includes C<-P $SERVICEPERFDATA$>.

=item B<-T | --prev-checktime TIMESTAMP> (PREV only)

Provide the timestamp of the previous check.  Only available if the "prev"
constructor parameter was given.  This is typically used with a Nagios command
definition that includes C<-T $LASTSERVICECHECK$>.

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
      authpassword=
      privproto=DES
      privpassword=

=head2 conf( SECTION, KEY, [ DEFAULT ] )

Returns the value of the B<KEY> in the B<SECTION> of the config file or the
B<DEFAULT> value if the key or section don't exist.

=cut

sub conf {
  my $self    = shift or confess("Missing SELF parameter");
  my $section = shift or confess("Missing SECTION parameter");
  my $key     = shift or confess("Missing KEY parameter");
  my $default = shift;

  return $self->{ini}->val($section, $key, $default);
}

=head1 SNMP METHODS

The following methods are enabled if the C<snmp> parameter was passed to the
constructor.

=head2 snmp ( )

Returns a B<Net::SNMP> session object configured using the program options
provided and runtime configuration.

=cut

sub snmp {
  my $self = shift or confess('MISSING SELF parameter');

  unless ($self->{snmp}) {
    error("Plugin not configured for SNMP!");
    return undef;
  }

  unless ($self->{snmpSession}) {

    my %opts = (
      hostname  => $self->opts->hostname,
      port      => $self->opts->snmpport,
      version   => $self->{proto},
      translate => [ timeticks => 0 ],
    );

    $opts{community} = $self->opts->community
      if ($self->opts->community && $self->{proto} != 3);

    if ($self->{proto} == 3) {

      $self->fatal("Both --seclevel and --secname required for SNMPv3")
        unless ($self->opts->seclevel && $self->opts->secname);

      $opts{username} = $self->opts->secname;

      $self->fatal("Invalid --seclevel value; \"$self->opts->seclevel\"")
        unless ($self->opts->seclevel =~ /^(no)?auth(no)?priv$/i);
      my ($auth, $priv) = (!$1, !$2);

      if ($auth) {
        $self->fatal("Invalid --authproto value; \"$self->opts->authproto\"")
          unless ($self->opts->authproto =~ /^(MD5|SHA)$/i);
        $opts{authprotocol} = $self->opts->authproto;

        $self->fatal("Missing --authpassword")
          unless (defined $self->opts->authpassword);
        if ($self->opts->authpassword =~ /^0x/) {
          $opts{authkey} = $self->opts->authpassword;
        } else {
          $opts{authpassword} = $self->opts->authpassword;
        }
      }

      if ($priv) {
        $self->fatal("Invalid --privproto value; \"$self->opts->privproto\"")
          unless ($self->opts->privproto =~ /^(DES|AES)$/i);
        $opts{privprotocol} = $self->opts->privproto;

        $self->fatal("Missing --privpassword")
          unless (defined $self->opts->privpassword);
        if ($self->opts->privpassword =~ /^0x/) {
          $opts{privkey} = $self->opts->privpassword;
        } else {
          $opts{privpassword} = $self->opts->privpassword;
        }
      }

    } # if SNMPv3

    my ($snmp, $error) = Net::SNMP->session(%opts);
    $self->fatal("SNMP error; $error") unless (defined $snmp);
    $self->{snmpSession} = $snmp;
  }
  return $self->{snmpSession};
}

=head2 snmp_get({ NAME => OID, ... })

=head2 snmp_get( OID, ... )

SNMP GET one or more OIDs.  The first form takes a hashref of I<NAME> => I<OID>
pairs and, on success, returns a hashref with a key for each I<NAME> and
I<OID>.  The second form takes an array of I<OID>s and returns a has with
I<OID>s as keys.  The values in the return hash are the results from the SNMP
GET command.

Returns UNDEF if there is an error.

=cut

sub snmp_get {
  my $self = shift or confess("Missing SELF parameter");
  confess("Missing OID parameters") unless @_;

  my %names; # name/OID map
  if (ref $_[0] eq ref {}) { %names = %{$_[0]}; shift; }
  foreach (@_) { $names{$_} = $_; }

  my @oids = values %names;
  my $vals;
  eval {
    local $SIG{ALRM} = sub { $self->fatal('SNMP timeout'); };
    alarm $self->opts->timeout;
    $vals = $self->snmp->get_request(varbindlist => [@oids]);
    alarm 0;
  };
  $self->fatal("Eval error; $@") if ($@);
  if ($self->snmp->error_status() == 2) {
    warn($self->snmp->error().
         '; OID='.$oids[$self->snmp->error_index()-1]);
  } elsif ($self->snmp->error_status()) {
    error($self->snmp->error());
  }

  my $ret = {};
  foreach (keys %names) {
      my $oid = $names{$_};
      $ret->{$_} = $ret->{$oid} = $vals->{$oid};
  }
  return $ret;
}

=head2 snmp_get_table( TABLE_OID, [ NAMES ] )

Calls B<Net::SNMP::get_table()> with the I<TABLE_OID>.  Returns a hashref with 
the returned OIDs a keys.  The I<NAMES> parameter may be provided as a hash of
I<NAME> => I<OID> pairs in which case the returned hashref will also have
corresponding I<NAME> keys.

Returns UNDEF if there is an error.

=cut

sub snmp_get_table {
  my $self  = shift  or confess("Missing SELF parameter");
  my $table = shift  or confess("Missing TABLE_OID parameter");
  my $names = shift;

  my $ret;
  eval {
    local $SIG{ALRM} = sub { $self->fatal('SNMP timeout'); };
    alarm $self->opts->timeout;
    $ret = $self->snmp->get_table(baseoid => $table);
    alarm 0;
  };
  fatal("Eval error; $@") if ($@);
  error($self->snmp->error()) if ($self->snmp->error_status());

  if ($names && (ref $names eq ref {})) {
      my %lookup; @lookup{values %{$names}} = keys %{$names};
      foreach (keys %{$ret}) {
          fatal("huh?") unless /^(.*)\.(\d+)$/;
          if ($lookup{$1}) { $ret->{$lookup{$1}.".$2"} = $ret->{$_}; }
      }
  }

  return $ret;
}

=head1 SSH METHODS

The following methods are enabled if the C<ssh> parameter was passed to the
constructor.

=head2 ssh ( )

Returns a B<Net::OpenSSH> object configured using the program options provided
and runtime configuration.

=cut

sub ssh {
  my $self = shift or confess('MISSING SELF parameter');

  unless ($self->{ssh}) {
    error("Plugin not configured for SSH!");
    return undef;
  }

  unless ($self->{openssh}) {
    my %opts = ();
    $opts{user} = $self->opts->username if $self->opts->username;
    $opts{password} = $self->opts->password if $self->opts->password;
    $opts{key_path} = $self->opts->keypath if $self->opts->keypath;
    my $ssh = new Net::OpenSSH($self->opts->hostname, %opts);
    if ($ssh->error) {
      error("SSH to ".$self->opts->hostname." failed; ".$ssh->error);
      return undef;
    }
    $self->{openssh} = $ssh;
  }
  return $self->{openssh};
}

sub ssh_system {
  my $self = shift or confess("Missing SELF parameter");
  return $self->ssh()->system(@_);
}

sub ssh_capture {
  my $self = shift or confess("Missing SELF parameter");
  return $self->ssh()->capture(@_);
}

sub ssh_pipe {
  my $self = shift or confess("Missing SELF parameter");
  return $self->ssh()->pipe_in(@_);
}

=head1 UTILITY SUBROUTINES

The following subroutines are "static"; i.e. not methods of the class.

=head2 Dugas::Plugin::parse_perfdata ( PERFDATA )

Takes a I<PERFDATA> string output by a Nagios plugin and returns the data
broken out into a hash.  This is just converting the results of 
B<Nagios::Plugin::Perforamnce::parse_perfstring()> into a hash.

=cut

sub parse_perfdata {
  my $perfdata = shift or confess("Missing PERFDATA parameter");
  my %perf;
  foreach (Nagios::Plugin::Performance->parse_perfstring($perfdata))
    { $perf{$_->label} = $_; }
  return \%perf;
}

=head2 sortKeys( HASH )

Custom sort B<Data::Dumper::Sortkeys> routine that groups and sorts OID and
non-OID keys in a hash.  Used here so the dump() routine can dump the 
results of SNMP requests cleanly.

=cut

sub sortKeys {
  my (@oids, @others);
  foreach (keys %{$_[0]}) {
    if (/^(\.\d+)+$/) { push @oids, $_; } else { push @others, $_; }
  }
  return [ Net::SNMP::oid_lex_sort(@oids), sort @others ];
}

=head1 SEE ALSO

B<Dugas::Nagios>, B<Dugas::Logger>, B<Nagios::Plugin>, B<Net::SNMP>

=head1 AUTHOR

Paul Dugas, <paul@dugas.cc>

=head1 BUGS

Please report any bugs or feature requests using the project page at
L<http://github.com/pdugas/Perl-Dugas>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Dugas

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

1; # End of Dugas::Nagios::Plugin
