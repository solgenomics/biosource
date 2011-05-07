package MooseX::Role::DBIC::Populate::MapKeys;
use Moose::Role;
use namespace::autoclean -also => 'to_list';

requires 'transform_for_populate', 'key_map';

after 'transform_for_populate' => sub {
    my ( $self, $data ) = @_;

    # map all the keys
    $self->map_all_keys( $data );
};

sub map_all_keys {
    my ( $self, $data ) = @_;
    $self->_map_keys_recurse( $data );
}

sub to_list($) {
    return map {
        ref && ref eq 'ARRAY' ? @$_ : $_
    } @_;
}

sub _map_keys_recurse {
    my ( $self, $data, @path ) = @_;

    # map key names
    for my $d ( to_list $data ) {

        for my $key ( keys %$d ) {
            my $new_key = $self->map_key( @path, $key );
            unless( $new_key eq $key ) {
                $d->{$new_key} = delete $d->{$key};
                $key = $new_key;
            }
            if( ref $d->{$key} ) {
                $self->_map_keys_recurse( $d->{$key}, @path, $key );
            }
        }
    }
}

sub map_key {
    my ( $self, @path ) = @_;

    my $map  = $self->key_map;

    my $abs = join '', map "/$_", @path;
    #warn "mapping key $abs\n";

    return
         $map->{ $abs }       # look for abs
      || $map->{ $path[-1] }  # look for rel
      || $path[-1];           # else, no mapping
}


1;
