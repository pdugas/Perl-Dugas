# =============================================================================
# Perl-Dugas - The Dugas Family of Perl Modules
# =============================================================================
# @file     lib/Dugas/Logger.pm
# @brief    Dugas::Logger Perl Module
# @author   Paul Dugas <paul@dugas.cc>
# =============================================================================

package Dugas::Logger;

use 5.006;
use strict;
use warnings FATAL => 'all';
use POSIX qw(strftime);
use Carp qw(confess);
use Data::Dumper; $Data::Dumper::Sortkeys = 1;

=head1 NAME

Dugas::Logger - A Simple Diagnostic Logging Framework

=head1 VERSION

Version 0.1

=cut

our $VERSION = '0.1';

=head1 SYNOPSIS

  use Dugas::Logger;

  info('Doing stuff...');
  dump('foo', $foo);
  fatal('Argh!');

=head1 EXPORT

The logging subroutines (fatal(), error(), warn(), etc.) are exported by
default.  The rest of the subroutines should be fully qualified in order to use
them.

=cut

require Exporter;
our @ISA         = qw(Exporter);
our @EXPORT      = qw(fatal error warn notice info debug trace dump hexdump);
our @EXPORT_OK   = ();

=head1 LOGGING LEVELS

Messages logged using the B<Dugas::Logger> module are assigned a severity level
and are filtered at runtime by a threshold.  The B<level()> subroutine is used
to get and set the threshold.  Messages logged at a level above the current
threshold are ignored.  The default level is I<WARN> so I<FATAL>, I<ERROR>, and
I<WARN> messages are logged and the others are not.  The logging levels are
listed below.

=over

=item FATAL

These are messages logged as the program is terminating abnormally.

=item ERROR

This are used to report errors encountered performing the action the user
requested.  

=item WARN

Warnings are logged to report potential trouble performing the action the
user requests.  Retries should be logged as warnings.  

=item NOTICE

Notices are logged to report normal but significant conditions like detailed
progress, use of default values, etc.

=item INFO

Information messages are logged to report progress performing a user requested
action.

=item DEBUG

Debug messsages should be used to provide details useful for developers and 
others troubeshooting the software.

=item DATA

The DATA level is used by the B<dump()> and B<hexdump()> subroutines when
logging detailed data.

=item TRACE

Trace messages are used to record entry and exit from soubroutines for use by
developers in troubeshooting the overall flow of the software.

=back


=head1 CONSTANTS

A set of contants for the levels is available if needed.  They're named
I<LOG_LEVEL> where I<LEVEL> is replaced by the level names above; i.e.
I<LOG_ERROR>, I<LOG_DATA>, etc.

=over

=item LOG_FATAL

=item LOG_ERROR

=item LOG_WARN

=item LOG_NOTICE

=item LOG_INFO

=item LOG_DEBUG

=item LOG_DATA

=item LOG_TRACE

=back

=cut

use constant LOG_FATAL  => 0; # critical conditions
use constant LOG_ERROR  => 1; # error conditions
use constant LOG_WARN   => 2; # warning conditions
use constant LOG_NOTICE => 3; # normal but significant condition
use constant LOG_INFO   => 4; # informational / progress
use constant LOG_DEBUG  => 5; # debug-level messages
use constant LOG_DATA   => 6; # data dumps
use constant LOG_TRACE  => 7; # program flow messages

use constant TIMESTAMP_FORMAT => '%Y-%m-%d %H:%M:%S'; # sortable!

# Globals
my $lvl = $ENV{DUGAS_LOGGER_VERBOSE} || LOG_WARN;  # Current threshold
my $log = undef; # Filehandle for output file; undef if not open

=head1 UTILITY SUBROUTINES

=head2 Dugas::Logger::open ( FILENAME )

Open a file to record logged output.  Messages will be appeanded to the file.

=cut

sub open {
  my $filename = shift or confess "Missing FILENAME parameter";
  Dugas::Logger::close() if $log;
  open($log, '>>', $filename) or fatal("open(>> $filename) failed; $!");
}

=head2 Dugas::Logger::close ( )

Close the output log file if it's open.

=cut

sub close {
  if ($log) {
    close($log);
    undef $log;
  }
}

=head2 Dugas::Logger::level ( [LEVEL] )

Set the logging level (threshold) and return the new level.  Omit the parameter
to get the current level without changing it.  The default level is I<WARN>.

=cut

sub level
{
  my $newLvl = shift;
  $lvl = $newLvl || $lvl;
  return $lvl;
}

=head1 LOGGING SUBROUTINES

The routines listed below are used to log diagnostic messages and data.  Most
of them (dump() and hexdump() excluded) take a printf()-style I<FORMAT> string
as their first paramter.  This may be followed by additional parameters which
will be passed to sprintf() to produce the actual message.

=head2 fatal ( FORMAT [,PARAMS] )

Logs a FATAL message and exits.  This should be used to report faults that
cannot be worked around or retried.

=cut

sub fatal { _logger('FATAL', @_); exit(1); }

=head2 error ( FORMAT [, PARAMS] )

Logs an ERROR message and returns.  This should be used to report any failure
the prevented the program from performing a user-requested action.

=cut

sub error { _logger('ERROR', @_); }

=head2 warn ( FORMA [, PARAMS] )

Logs a WARN message and returns.  These should be used to report when some
action was taken to work around a fault of some kind.

=cut

sub warn { _logger('WARN', @_) if $lvl >= LOG_WARN; }

=head2 notice ( FORMAT [, PARAMS] )

Logs a NOTICE message and returns.  These should be used to report when some
minor information an administration may want to look into.  These do not 
indicate any inability to perform the desired action.

=cut

sub notice { _logger('NOTICE', @_) if $lvl >= LOG_NOTICE; }

=head2 info ( FORMAT [, PARAMS] )

Logs an INFO message and returns.  These should be used to report progress in
performin a user-request action.

=cut

sub info { _logger('INFO', @_) if $lvl >= LOG_INFO; }

=head2 debug ( FORMAT [, PARAMS] )

Logs a DEBUG message and returns.  These should be used to report information
used to troubleshoot issues.

=cut

sub debug { _logger('DEBUG', @_) if $lvl >= LOG_DEBUG; }

=head2 trace ( FORMAT [, PARAMS] )

Logs a TRACE message and returns.  These should be used to report entry and
exit if subroutines.

=cut

sub trace($;@) { _logger('TRACE', @_) if $lvl >= LOG_DEBUG; }

=head2 dump ( NAME, VALUE )

Dumps the given VALUE to the log as a DATA message.  Uses B<Data::Dumper>.

=cut

sub dump 
{
  return unless $lvl >= LOG_DATA;
  my $key = shift or confess('Missing NAME parameter');
  my $val = shift;
  Dugas::Logger::warn("Ignoring extra parameters; @_") if @_;
  _logger('DATA', Data::Dumper->Dump([$val],[$key]));
}

=head2 hexdump ( NAME, VALUE )

Dumps the given VALUE in binary format to the log as a DATA message.

=cut

sub hexdump 
{
  return unless $lvl >= LOG_DATA;
  my $name  = shift or confess('Missing NAME parameter');
  my $value = shift or confess('Missing VALUE parameter');
  Dugas::Logger::warn("Ignoring extra parameters; @_") if @_;
  my ($pos, @bytes, $fmt, $msg) = (0, undef, undef, '');
  foreach my $data (unpack("a16"x(length($value)/16)."a*", $value)) {
    my $len = length($data);
    if ($len == 16) {
      @bytes = unpack('N4', $data);
      $fmt="  0x%08x (%05d)   %08x %08x %08x %08x   %s\n";
    } else {
      @bytes = unpack('C*', $data);
      $_ = sprintf "%2.2x", $_ for @bytes;
      push(@bytes, '  ') while $len++ < 16;
      $fmt="  0x%08x (%05d)   %s%s%s%s %s%s%s%s %s%s%s%s %s%s%s%s   %s\n";
    }
    $data =~ tr/\0-\37\177-\377/./;
    $msg .= sprintf($fmt,$pos,$pos,@bytes,$data);
    $pos += 16;
  }
  _logger('DATA', "\$$name = \n$msg");
}

=head2 Dugas::Logger::_logger ( LEVEL, FORMAT [, PARAMS] )

This is the routine that actually logs the message.  It's not usually used
directly.  Consider it private and subject to change.

=cut

sub _logger
{
  my $level  = shift or confess('Missing LEVEL parameter');
  my $format = shift or confess('Missing FORMAT parameter');
  chomp $format; chomp $format;
  if (@_) { $format = sprintf("$format", map {defined $_ ? $_ : 'UNDEF'} @_); }
  $format = '['.$level.'] '.$format."\n";
  print(STDERR $format);
  print({$log} strftime(TIMESTAMP_FORMAT, localtime()), $format)
    if defined $log;
}

=head1 ENVIRONMENT VARIABLES

The default logging level may be overridden by setting the
C<DUGAS_LOGGER_VERBOSE> environment variable to the desired integer value.

=head1 SEE ALSO

B<Dugas::App> - Configures B<Dugas::Logger> using standard program options.

=head1 AUTHOR

Paul Dugas, <paul@dugas.cc>

=head1 BUGS

Please report any bugs or feature requests using the project page at
L<http://github.com/pdugas/Perl-Dugas>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Dugas::Logger

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

1; # End of Dugas::Logger
