# =============================================================================
# perl-Dugas - The Dugas Family of Perl Modules
# =============================================================================
# @file     lib/Dugas/App.pm
# @brief    A simple application class handling program options and logging.
# @author   Paul Dugas <paul@dugas.cc>
# =============================================================================

package Dugas::App;

use 5.006;
use strict;
use warnings FATAL => 'all';

=head1 NAME

Dugas::App - A simple application class handling runtime configuration.

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

  use Dugas::App;

  my $app = new Dugas::App( conf => 'eg.conf',
                            opts => [ { spec=>'foo' } ] );
  
  if ($app->conf('eg', 'foo', 'foo')) { 
      ...
  }

=cut

use Carp qw(confess);
use Params::Validate qw(:all);
use POSIX qw(getpid strftime);
use Getopt::Long qw(:config no_ignore_case gnu_getopt);
use Pod::Usage;
use Dugas::Logger;
use File::Basename qw(fileparse);
use Config::IniFiles;

# This will be the top-level directory where we expect to find the etc/
#subdirectory.
my $basedir;

# Process parameters passed when the module is use'd.
sub import
{
  my $name = shift; # module name, ignored

  # $dir will be our initial BASEDIR, two levels up from where this file lives
  # since this module typically is not installed in the usual place.
  my ($vol, $dir, $file) = File::Spec->splitpath(__FILE__);
  $dir = Cwd::realpath(File::Spec->catdir($dir, (File::Spec->updir()) x 2));

  # process parameters.
  my $opts = validate(@_, {BASEDIR => {type => SCALAR, default => $dir}});
  $basedir = $opts->{BASEDIR};

  # Warn if BASEDIR doesn't seem right.
  if (-d $basedir) {
    notice("Dugas::App BASEDIR ($basedir) may not be correct.")
      unless (-d ETCDIR());
  } else {
    notice("Dugas::App BASEDIR ($basedir) doesn't exist.")
  }
}

my %DEFAULT = (
  logger => {
    logfile => undef
  }
);

=head1 CONSTANTS

The following contants are provided.

=head2 B<BASEDIR>

Returns the full path for the top-level directory under which we expect to 
find etc/ and other subdirectories.

The B<BASEDIR> value can be overridden when use'ing the module like so:

  use Dugas::App( BASEDIR => '/' );

=cut

sub BASEDIR() { return $basedir; }

=head2 B<ETCDIR>

Returns the full path for the C<etc/> subdirectory under B<BASEDIR>.  We expect
to find runtime config files here.

=cut

sub ETCDIR() { return File::Spec->catdir(BASEDIR, 'etc'); }

=head1 CONSTRUCTOR

=head2 B<$obj = new Dugas::App( OPTIONS )>

Returns a new B<Dugas::App> object.  Use the following options to configure it.

=over

=item B<version =E<gt> STRING>

Sepecify the version string used in usage and version output. Defaults to
B<Dugas::App::VERSION>.

=item B<license =E<gt> STRING>

Specify the license string used in usage and version output. Defaults to a
simple copyright statement.

=item B<conf =E<gt> FILENAME>

Specify an INI-style runtime configuration file to load. Defults to
C<dugas.conf>.

=item B<opts =E<gt> ARRAYREF>

Specify an array of hash references, one for each command-line option to add to
the stock options.  See L<PROGRAM OPTIONS>.

=item B<prefix =E<gt> SCALAR>

Specify a prefix string for environment variables.

=back

=cut

sub new
{
  my $class = shift or confess('Missing CLASS parameter');

  my ($prog, $path, $ext) = fileparse($main::0);

  my $prefix = uc($prog); $prefix =~ s/[^0-9A-Z]/_/g;

  my $obj = validate( @_, {
    version => { default => $Dugas::App::VERSION },
    license => { default => $Dugas::App::LICENSE },
    conf    => { type => SCALAR, default => 'dugas.conf' },
    opts    => { type => ARRAYREF, default => [] },
    prefix  => { type => SCALAR, default => $prefix },
  });

  bless $obj, $class;

  ($obj->{prog}, $obj->{path}, $obj->{ext}) = ($prog, $path, $ext);

  $obj->{opts} = [ @{$obj->{opts}},
    { spec    => 'usage|?' },
    { spec    => 'help|h' },
    { spec    => 'version|V' },
    { spec    => 'verbose|v+', default => 0 },
    { spec    => 'quiet|q' },
    { spec    => 'config|C=s' },
    { spec    => 'log|L=s', default => $obj->conf('logger', 'logfile') },
  ];

  $obj->{optvals} = {};

  for (@{$obj->{opts}}) {
    my $name = $_->{spec}; $name =~ s/[|=+!:].*$//;
    my $default = $_->{default};
    my $envvar = uc($obj->{prefix}.'_'.$name);
    debug("EnvVar for $name option is $envvar.");
    $default = $ENV{$envvar} if exists $ENV{$envvar};
    debug("Default for $name option is ".($default||'UNDEF').".");
    next unless defined $default;
    $obj->{optvals}{$name} = $default;
  }

  GetOptions($obj->{optvals}, map { $_->{spec} } @{$obj->{opts}})
    or pod2usage(-exitval => -1);
  dump('Dugas::App::obj', $obj);

  my $msg = sprintf("%s %s\n%s\n",
                    $obj->{prog},  $obj->{version}, $obj->{license});
  pod2usage(-msg => $msg, -exitval => 0, -verbose => 1)
    if $obj->{optvals}{usage};
  pod2usage(-exitval => 0, -verbose => 2)
    if $obj->{optvals}{help};
  if ($obj->{optvals}{version}) { print $msg; exit(0); }

  my $lvl = Dugas::Logger::level();
  $lvl += $obj->{optvals}{verbose} if $obj->{optvals}{verbose};
  $lvl = Dugas::Logger::LOG_ERROR if $obj->{optvals}{quiet};
  Dugas::Logger::level($lvl);

  $obj->{config} = {};
  if (my $filename = $obj->{optvals}{config} || $obj->{conf}) {
    $filename =~ s/%s/$obj->{prog}/;
    $filename = File::Spec->catfile(ETCDIR, $filename);
    if (-r $filename) {
      debug("Loading config from $filename.");
      tie %{$obj->{config}}, 'Config::IniFiles',
          (-file       => $filename, -fallback   => 'GLOBAL',
           -nocase     => 1,         -allowempty => 1);
      fatal("Failed to load $filename; ".
            join(' ', @Config::IniFiles::errors))
        unless $obj->{config};
    } else {
      debug("Not loading config from $filename; missing or inaccessible.");
    }
  }

  # Open the log file if indicated.
  if (my $filename = $obj->conf('logger', 'logfile', 'log')) {
    $filename =~ s/%s/$obj->{prog}/;
    $filename =~ s/%d/getpid()/e;
    debug("Opening $filename for logging.");
    Dugas::Logger::open($filename);
  }

  return $obj;
}

=head1 METHODS

=head2 $app->opt( OPTION )

Returns the value of the named program option.  Returns the default value
(or UNDEF if no default was given) if the option was not specified.  

=cut

sub opt($$) {
  my $obj = shift or confess('Missing SELF parameter');
  my $opt = shift or confess('Missing OPT parameter');
  my $ret = $obj->{optvals}{lc($opt)};
  return $ret;
}

=head2 $app->conf( SECTION, KEY [,OPTION] )

Returns the value of a configuration file entry.  If the OPTION parameter is
set, the result from C<opt(OPTION)> is returned if it's defined.  Otherwise,
the value for the entry is returned.

=cut

sub conf($$$;$) {
  my $obj = shift or confess('Missing SELF parameter');
  my $sec = shift or confess('Missing SEC parameter');
  my $key = shift or confess('Missing KEY parameter');
  my $opt = shift;
  $sec = lc($sec);
  $key = lc($key);
  my $ret = undef;
  if ($opt && defined $obj->{optvals}{lc($opt)}) {
    $ret = $obj->{optvals}{lc($opt)};
  } elsif (exists $obj->{config}{$sec} && exists $obj->{config}{$sec}{$key}) {
    $ret = $obj->{config}{$sec}{$key};
  } elsif (exists $DEFAULT{$sec}) {
    $ret = $DEFAULT{$sec}{$key};
  }
  return $ret;
}

=head1 PROGRAM OPTIONS

The following program options are supported automatically:

=over

=item B<-? | --usage>

Displays basic usage information and exits.  Specifically, the SYNOPSYS and
OPTIONS secion of the POD documentation defined in the application script
itself are presented here.

=item B<-h | --help>

Displays the manpage and exits.  This displays the POD documentation embedded
into the application script itself.

=item B<-V | --version>

Displays the version and copyright information and exits.

=item B<-v | --verbose>

Increases the level of diagnostic logging in the B<Dugas::Logger> module.  May
be used multiple time; i.e. C<-vvv>.

=item B<-q | --quiet>

Minimizes the level of diagnostic logging.  See B<Dugas::Logger>.

=item B<-c | --config FILENAME>

Specify an INI-style configuration file to load on startup.

=item B<-l | --log FILENAME>

Specify a file where diagnostic logging output from B<Dugas::Logger> should go.

=back

Custom program options are added using the C<conf> parameter to the constructor.
The example below adds --foo and --bar options.  

  $app = new Dugas::App( opts => [
      { spec => 'foo' },
      { spec => 'bar=s', default => 'asdf' },
  ]);

The value for the C<opts> parameter is an array of hashes.  Each has represents
an additional program option and contains a C<spec> element and an optional
C<default> element.  The C<spec> element is passed to the B<Getopt::Long>
module's C<GetOptions()> routine as the option specification.

Use the C<opt()> method to retrieve the value of program options after the
program has been initialized.

Envornment variables that correspond to the option names will override the 
default values.  The command-line options still override this.  The environment
variables are named C<PREFIX_NAME> where C<PREFIX> is the program name with
non-letter or -digit characters converted to underscores and the C<NAME> is the 
option name.  i.e.  The --error option in the C<eg-app> program may be set 
using the C<EG_APP_ERROR> environment variable..

=head1 CONFIG FILE

The runtime configuration file specified with the C<--config> program option
and the C<conf> parameter to the constuctor point to an INI-style text file 
that is expected tp contain C<key=value> pairs in C<[sections]>.

  ; Comments start with a semicolon
  [logger]
    logfile=/tmp/%s-%d.log

The C<conf()> method is used to retrieve config file values.

=head1 SEE ALSO

B<Dugas::Logger> - Diagnostic Logging Framework

=head1 AUTHOR

Paul Dugas, <paul at dugas.cc>

=head1 BUGS

Please report any bugs or feature requests using the project page at
L<http://github.com/pdugas/perl-Dugas>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Dugas::App

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

# =============================================================================
# vim: set et sw=2 ts=2 :
