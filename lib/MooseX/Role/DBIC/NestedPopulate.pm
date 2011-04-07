package MooseX::Role::DBIC::NestedPopulate;
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

sub load {
    my ( $self, $file_data ) = @_;

    # make a deep copy of the data
    $file_data = dclone( $file_data );


    $file_data = $self->transform_for_populate( $file_data );
    for my $source ( keys %$file_data ) {
        $self->schema->populate( $source, [ to_list $file_data->{$source} ] );
    }
}

####### helpers #########

sub transform_for_populate {
    my ( $self, $data ) = @_;

    # map all the keys
    $self->map_all_keys( $data );

    # resolve all the existing rows
    $self->resolve_existing( $data );
}

sub map_all_keys {
    my ( $self, $data ) = @_;
    $self->_map_keys_recurse( $data );
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

sub resolve_existing {
    my ( $self, $data ) = @_;

    for my $d ( to_list $data ) {
        for my $k ( keys %$d ) {
            my $rs = $self->schema->resultset( $k );
            $self->_transform_recursive( $rs, $d->{$k}, [ $k ] );
        }
    }
    return $data;
}

sub _transform_recursive {
    my ( $self, $this_rs, $d, $path ) = @_;
    for my $data ( to_list $d ) {
      KEY:
        for my $key (keys %$data) {
            if( ref $data->{$key} ) { # we have some kind of nesting

                # resolve any :existing relations
                for my $item ( to_list $data->{$key} ) {
                    ref $item eq 'HASH' or die "parse error";
                    if( my $existing = delete $item->{':existing'} ) {

                        # convert find the existing item and merge its
                        # IDs into the top-level hash
                        delete $data->{$key};

                        %$data = (
                            %$data,
                            $self->_resolve_existing( $this_rs, $key, $existing ),
                        );

                        next KEY;
                    }
                }

                # recurse into the nested relation
                my $rs = $self->_related_resultset( $this_rs, $key );
                $self->_transform_recursive( $rs, $data->{$key}, [ @$path, $key ] );
            }
        }
    }
}

# this returns the *full* resultset of the related table, whereas
# dbic's restricts it with a join
sub _related_resultset {
    my ( $self, $rs, $relname ) = @_;

    my $rsrc = $rs->result_source;
    my $rel_info = $rsrc->relationship_info( $relname )
       or croak $rsrc->source_name." has no relationship '$relname'\n";
    my $related_source = $rs->result_source->related_source($relname);

    return $rsrc->schema->resultset( $related_source->source_name );
}

sub _resolve_existing {
    my ( $self, $this_rs, $key, $existing ) = @_;

    my $rel_rs = $self->_related_resultset( $this_rs, $key );

    ref $existing eq 'ARRAY'
        and croak "cannot link to multiple existing $key rows\n";

    my $existing_rs = $rel_rs->search( $existing );
    my $existing_obj = $existing_rs->next
        or croak "existing $key not found with ".dump( $existing );
    $existing_rs->next
        and croak "multiple existing $key rows found with ".dump( $existing );

    my $rsrc = $this_rs->result_source;
    my $rel_info = $rsrc->relationship_info( $key )
       or croak $rsrc->source_name." has no relationship '$key'\n";

    my %data;
    while( my ( $foreign_col, $self_col ) = each %{$rel_info->{cond}} ) {
        s/^(foreign|self)\.// for $foreign_col, $self_col;
        $data{$self_col} = $existing_obj->get_column($foreign_col);
    }

    return %data;
}


1;
