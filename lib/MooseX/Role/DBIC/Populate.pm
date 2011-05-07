package MooseX::Role::DBIC::Populate;
use Moose::Role;
use namespace::autoclean -also => 'to_list';

use Carp;
use Data::Dump 'dump';
use Storable 'dclone';

requires 'schema', 'key_map';

sub to_list($) {
    return map {
        ref && ref eq 'ARRAY' ? @$_ : $_
    } @_;
}

sub load {
    my ( $self, $file_data ) = @_;

    # make a deep copy of the data
    $file_data = dclone( $file_data );

    $self->transform_for_populate( $file_data );

    for my $source ( keys %$file_data ) {
        $self->schema->populate( $source, [ to_list $file_data->{$source} ] );
    }
}

# just a hook to hang things off of
sub transform_for_populate {}

1;
