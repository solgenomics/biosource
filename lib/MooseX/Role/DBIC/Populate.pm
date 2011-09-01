=head1 NAME

MooseX::Role::DBIC::Populate - make your class a loader for a DBIC schema

=head1 SYNOPSIS

  package MyClass;
  use Moose;

  has 'schema' => ( isa => 'DBIx::Class::Schema' );

  with 'MooseX::Role::DBIC::Populate';

  # now your class has a load() method that takes a hashref of data
  # and feeds it to the schema's populate() method

=head1 DESCRIPTION

This base role by itself does little more than provide a C<<load>>
method that feeds its argument to the schema's populate method.

However, if provides several stub methods that other roles can use as
hooks for extending this, using Moose method modifiers.

=cut

package MooseX::Role::DBIC::Populate;
use Moose::Role;
use namespace::autoclean -also => 'to_list';

use Carp;
use Data::Dump 'dump';
use Storable 'dclone';

requires 'schema';

sub to_list($) {
    return map {
        ref && ref eq 'ARRAY' ? @$_ : $_
    } @_;
}

=head1 METHODS

=head2 load( $file_data )

Call the schema's populate() method on each entry in the passed
hashref.  For example, if passed:

  {  Artist => [ { name => 'Jimmy' }, { name => 'Tom' } ],
     Album  => { title => 'Swell Songs' },
  }

It will call C<< populate() >> on the schema once for C<<Artist>>, and
once for C<<Album>>.  See the populate() documentation in
L<DBIx::Class::Schema>.

=cut

sub load {
    my ( $self, $file_data ) = @_;

    # make a deep copy of the data
    $file_data = dclone( $file_data );

    $self->transform_for_populate( $file_data );

    for my $source ( keys %$file_data ) {
        $self->schema->populate( $source, [ to_list $file_data->{$source} ] );
    }
}

=head1 EXTENSION METHODS

These methods are empty, meant to be extended by other roles using
method modifiers.

=head2 transform_for_populate

Run on the passed data before running populate.

=cut

# just a hook to hang things off of
sub transform_for_populate {}

=head1 EXTENSIONS

L<MooseX::Role::DBIC::Populate::ExistingAssertions>,
L<MooseX::Role::DBIC::Populate::MapKeys>

=cut

1;
