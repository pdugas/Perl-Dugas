# -----------------------------------------------------------------------------
# perl-Dugas - The Dugas Enterprises Perl Modules
# Copyright (C) 2013-2016 by Paul Dugas and Dugas Enterprises, LLC
# -----------------------------------------------------------------------------

package Dugas::Maximo;

use 5.006;
use strict;
use warnings FATAL => 'all';

use Carp;
use Dugas::Logger;
use HTTP::Request::Common qw(GET POST DELETE);
use LWP;
use MIME::Base64 qw(encode_base64);
use Params::Validate qw(:all);
use XML::Simple;

=head1 NAME

Dugas::Maximo - Wrapper Class for the Maximo REST API

=head1 VERSION

Version 0.2

=cut

our $VERSION = '0.2';

=head1 SYNOPSIS

    use Dugas::Maximo;

    my $mx = new Dugas::Maximo(host => 'maxmio.example.com',
                               user => 'jdoe', pass => 'secret');

    my @assets = $mx->get('MBO', 'ASSET', LOCATION => '1234');

=head1 CONSTRUCTOR

=head2 new ( OPTIONS )

Returns a new instance of the B<Dugas::Maximo> class.  The constructor accepts
the following parameters.

=over

=item host =E<gt> (HOSTHAME|ADDRESS)

Specify the hostname or IP address for the Maximo host.  Required.

=item user =E<gt> USERNAME

Specify the username to use.  This account needs to have sufficient access for
the MX objects the script is trying to use.

=item pass =E<gt> PASSWORD

Specify the password to use.

=back

=cut

sub new
{
    my $class = shift;

    my $self = validate( @_, {
        host => { type      => SCALAR,
                  callbacks => { defined => sub { defined shift() }, },
                  required  => 1 },
        user => { type      => SCALAR,
                  callbacks => { defined => sub { shift() }, },
                  required  => 1 },
        pass => { type      => SCALAR,
                  callbacks => { defined => sub { defined shift() }, },
                  required  => 1 },
    });

    bless $self, $class;

    $self->{lwp} = LWP::UserAgent->new(agent => $class);
    $self->{maxauth} = encode_base64($self->{user}.':'.$self->{pass}, '');
    #dump('maxauth', $self->{maxauth});

    return $self;
}

=head1 METHODS

=head2 get ( CLASS, TYPE [, KEY => VALUE ...] )

Query Maximo objects.  Returns an array of hashes, one for each matching MX
object, or an empty array in the case where no matches were found.  The
I<CLASS> parameter should be either C<MBO> for Maximo Business Objects or C<OS>
for Object Structures.  The I<TYPE> parameter should be the MX object type to
query; i.e. C<LOCATIONS> for locations, C<ASSET> for assets, etc.

Any number of I<KEY> => I<VALUE> pairs may be provided as additional
parameters.  This will used as query parameters for the HTTP GET request.

Refer to the Maximo's REST API documentation for specifics on the I<TYPE> and
I<KEY> => I<VALUE> parameters.

=head2 get ( CLASS, TYPE, ID [, KEY => VALUE ...] )

Query Maximo for a single object by I<ID>.  Returns a single object as a hash
reference or C<undef> if no match was found.  The I<ID> parameter should be the
key field of the MX object; i.e. the I<LOCATIONSID> field for location objects
or the I<ASSETUID> field for an asset.

=cut

sub get
{
    my $self  = shift or confess('Missing SELF parameter');
    my $class = shift or confess('Missing CLASS parameter');
    my $type  = shift or confess('Missing TYPE parameter');

    # An odd number of remaining parameters means the first is the ID.
    my $id = (@_ % 2 == 1 ? shift : undef);

    # Build the URI
    my $uri = 'https://'.$self->{host}.'/maxrest/rest/'.lc($class).'/'.uc($type);
    $uri .= '/'.$id if defined $id;
    #debug("URL is $uri");
    $uri = URI->new($uri);
    $uri->query_form(@_); # remaining parameters become query parameters

    # Build the request.
        my $req = GET($uri, MAXAUTH => $self->{maxauth});
    #dump('REQUEST', $req);

    # Issue the request.
    my $res = $self->{lwp}->request($req);
    #dump('RESPONSE', $res);
    unless ($res->is_success) {
        error("get($class, $type) failed; ".$res->status_line) ;
        return undef;
    }

# Parse the XML.
    my $xml = XMLin($res->content(), KeepRoot => 1);
#dump('XML', $xml);

    if (keys %$xml != 1) {
        error("Didn't get just a single root node in XML response");
        return undef;
    }
    my $root = (keys %$xml)[0];
    #debug("Root in XML response is $root.");

    # If the root node in the XML is FOOMboSet and there is a FOO child node
    # under there then we're to return the contents of that child.  This is
    # what we see when querying FOO MBOs.  Replace FOO here with LOCATIONS,
    # ASSET, SR, WORKORDER, etc.
    if ($root =~ /^(.*)MboSet$/) {
        my $root_type = $1;
        warn("Got $root_type MBO set instead of $type?")
            unless (uc($root_type) eq uc($type));
        if (exists $xml->{$root}{$root_type}) {
            #debug("Found $root_type under $root root so returning that.");
            if (ref($xml->{$root}{$root_type}) eq 'ARRAY') {
                return @{$xml->{$root}{$root_type}};
            } else {
                return [ $xml->{$root}{$root_type} ];
            }
        } else {
            return [];
        }
    }

    # Querying object structures returns a different XML structure.  We get a
    # root node named something like QueryFOOResponse with a FOOSet child and
    # then an child under there that's named depending on the base MBO the OS is
    # built from.  That node is the one we want to return. Trouble is, we don't
    # really know what that type will be.  For now, we'll look for the value that
    # isn't a scalar and return that.
    if ($root =~ /^Query(.*)Response$/) {
        my $root_type = $1;
        warn("Got $root_type query response instead of $type?") 
            unless (uc($root_type) eq uc($type));
        if (!exists $xml->{$root}{$root_type.'Set'}) {
            error("Didn't find ${root_type}Set under $root?");
            return undef;
        }
        foreach (keys %{$xml->{$root}{$root_type.'Set'}}) {
            if (ref $xml->{$root}{$root_type.'Set'}{$_} eq 'HASH') {
                #debug("Returning the $_ HASH node.");
                return [ $xml->{$root}{$root_type.'Set'}{$_} ];
            }
            if (ref $xml->{$root}{$root_type.'Set'}{$_} eq 'ARRAY') {
                #debug("Returning the $_ ARRAY node.");
                return @{$xml->{$root}{$root_type.'Set'}{$_}};
            }
        }
        return [];
    }

    error("Didn't understand the XML response.");
    return undef;
}

=head2 get1 ( CLASS, TYPE [, KEY => VALUE ...] )

Query Maximo for a single object.  Returns a hash reference or C<undef> if no
match was found.  The parameters are the same as for the get() method.

=cut

sub get1
{
    my $self = shift or confess('Missing SELF parameter');
    my $ret = $self->get(@_);
    return undef unless $ret && scalar @$ret;
    croak("get1(".join(',', @_).") returned more than one object.")
        if scalar @$ret > 1;
    return $ret->[0];
}

=head2 get_mbo ( TYPE [, KEY => VALUE ...] )

Query Maximo MBOs (MX business objects).
Shorthand for B<get('MBO', TYPE, ...)>.

=head2 get_mbo ( TYPE, ID [, KEY => VALUE ...] )

Query a single MBOs (MX business objects).
Shorthand for B<get('MBO', TYPE, ID, ...)>.

=cut

sub get_mbo
{
    my $self = shift or confess('Missing SELF parameter');
    return $self->get('MBO', @_);
}

=head2 get1_mbo ( TYPE [, KEY => VALUE ...] )

Query a single MBOs (MX business objects).
Shorthand for B<get('MBO', TYPE, ...)>.

=cut

sub get1_mbo
{
    my $self = shift or confess('Missing SELF parameter');
    return $self->get1('MBO', @_);
}

=head2 get_os ( TYPE [, KEY => VALUE ...] )

Query Maximo Object Structures.
Shorthand for B<get('OS', TYPE, ...)>.

=head2 get_os ( TYPE, ID [, KEY => VALUE ...] )

Query a single OS.
Shorthand for B<get('OS', TYPE, ID, ...)>.

=cut

sub get_os
{
    my $self = shift or confess('Missing SELF parameter');
    return $self->get('OS', @_);
}

=head2 get1_os ( TYPE [, KEY => VALUE ...] )

Query a single OS.
Shorthand for B<get1('OS', TYPE, ...)>.

=cut

sub get1_os
{
    my $self = shift or confess('Missing SELF parameter');
    return $self->get1('OS', @_);
}

=head2 post ( CLASS, TYPE [, KEY => VALUE ...] )

Create a new Maxmio object.  Use the I<KEY> => I<VALUE> parameters to provide
the field values.  The return value is a hash reference representing the new
object or C<undef> if there was an error.

=cut

sub post
{
    my $self  = shift or confess('Missing SELF parameter');
    my $class = shift or confess('Missing CLASS parameter');
    my $type  = shift or confess('Missing TYPE parameter');

    my $id = (@_ % 2 == 1 ? shift : undef);

    my $uri = 'https://'.$self->{host}.'/maxrest/rest/'.lc($class).'/'.lc($type);
    $uri .= '/'.$id if defined $id;

    my $req = POST($uri, { @_ }, MAXAUTH => $self->{maxauth});

    my $res = $self->{lwp}->request($req);
    dump('RESPONSE', $res);
    unless ($res->is_success) {
        error("post($uri) failed; ".$res->status_line);
        return undef;
    }

    my $xml = XMLin($res->content(), KeepRoot => 1);

    if (uc($class) eq 'MBO') {
        return $xml->{uc($type)} if (exists $xml->{uc($type)});
        error("Didn't find ".uc($type)." in MBO POST response.");
        return undef;
    }

    if (uc($class) eq 'OS') {
        my $root = (keys %$xml)[0];
        if ($root ne 'Create'.uc($type).'Response' &&
                $root ne 'Sync'.uc($type).'Response') {
            error("Unexpected root ($root) in response to ".uc($type)." POST.");
            return undef;
        }
        unless (exists $xml->{$root}{uc($type).'Set'}) {
            error("Missing ".uc($type)."Set node under $root in POST response.");
            return undef;
        }
        foreach (keys %{$xml->{$root}{uc($type).'Set'}}) {
            if (ref $xml->{$root}{uc($type).'Set'}{$_} eq 'HASH') {
                return $xml->{$root}{uc($type).'Set'}{$_};
            }
        }
    }

    return undef;
}

=head2 post_mbo ( TYPE [, KEY => VALUE ...] )

Create a Maximo MBO (MX business object).
Shorthand for B<post('MBO', TYPE, ...)>.

=head2 post_mbo ( TYPE, ID [, KEY => VALUE ...] )

Update a Maximo MBO (MX business object).
Shorthand for B<post('MBO', TYPE, ID, ...)>.

=cut

sub post_mbo
{
    my $self = shift or confess('Missing SELF parameter');
    return $self->post('MBO', @_);
}

=head2 post_os ( TYPE [, KEY => VALUE ...] )

Create a Maximo OS (MX Object Structure).
Shorthand for B<post('OS', TYPE, ...)>.

=head2 post_os ( TYPE, ID [, KEY => VALUE ...] )

Update a Maximo OS (MX Object Structure).
Shorthand for B<post('OS', TYPE, ID, ...)>.

=cut

sub post_os
{
    my $self = shift or confess('Missing SELF parameter');
    return $self->post('OS', @_);
}

=head2 delete ( CLASS, TYPE, ID )

Delete a Maxmio object.  Returns 1 on success or 0 on an error.

=cut

sub delete
{
    my $self  = shift or confess('Missing SELF parameter');
    my $class = shift or confess('Missing CLASS parameter');
    my $type  = shift or confess('Missing TYPE parameter');
    my $id    = shift or confess('Missing ID parameter');

    my $uri = 'https://'.$self->{host}.'/maxrest/rest/'.
        lc($class).'/'.lc($type).'/'.$id;
    debug('URL is '.$uri);

    my $req = DELETE($uri, MAXAUTH => $self->{maxauth});
    dump('REQUEST', $req);

    my $res = $self->{lwp}->request($req);
    dump('RESPONSE', $res);
    unless ($res->is_success) {
        error("delete($class, $type, $id) failed; ".$res->status_line);
        return 0;
    }

    return 1;
}

=head2 delete_mbo ( TYPE, ID [, KEY => VALUE ...] )

Delete a Maximo MBO (MX Business Object).
Shorthand for B<delete('MBO', TYPE, ID, ...)>.

=cut

sub delete_mbo
{
    my $self = shift or confess('Missing SELF parameter');
    return $self->delete('MBO', @_);
}

=head2 delete_os ( TYPE, ID [, KEY => VALUE ...] )

Delete a Maximo OS (MX Object Structure).
Shorthand for B<delete('OS', TYPE, ID, ...)>.

=cut

sub delete_os
{
    my $self = shift or confess('Missing SELF parameter');
    return $self->delete('OS', @_);
}

=head1 AUTHOR

Paul Dugas, <paul@dugas.cc>

=head1 BUGS

Please report any bugs or feature requests using the project page at
L<http://github.com/pdugas/perl-Dugas>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Dugas::Maximo

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

1; # End of Dugas::Maximo

# -----------------------------------------------------------------------------
# vim: set et sw=4 ts=4 :
