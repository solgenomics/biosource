package MooseX::Role::DBIC::NestedPopulate;
use Moose::Role;
use namespace::autoclean;

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

    return
         $map->{ join '/', @path }
      || $map->{ $path[-1] }
      || $path[-1];
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

sub map_keys {
    my ( $self, $data ) = @_;
    # map key names
    for my $key (keys %$data) {
        my $new_key = $self->map_key( $key );
        unless( $new_key eq $key ) {
            $data->{$new_key} = delete $data->{$key};
            $key = $new_key;
        }
    }
}

sub transform_for_populate {
    my ( $self, $data ) = @_;
    for my $d ( to_list $data ) {
        $self->map_keys( $data );

        for my $k ( keys %$d ) {
            my $rs = $self->schema->resultset( $k );
            $self->_transform_recursive( $rs, $d->{$k} );
        }
    }
    return $data;
}

sub _transform_recursive {
    my ( $self, $this_rs, $d ) = @_;
    for my $data ( to_list $d ) {
        $self->map_keys( $data );
      KEY:
        for my $key (keys %$data) {
            if( ref $data->{$key} ) { # we have some kind of nesting

                # resolve any :existing relations
                for my $item ( to_list $data->{$key} ) {
                    ref $item eq 'HASH' or die "parse error";
                    if( my $existing = delete $item->{':existing'} ) {
                        # convert the item to ID cols
                        #warn "got existing $key\n";

                        delete $data->{$key};

                        # merge the proper relations
                        %$data = (
                            %$data,
                            $self->_resolve_existing( $this_rs, $key, $existing ),
                        );

                        next KEY;
                    }
                }

                # recurse into the nested relation
                my $rs = $self->_related_resultset( $this_rs, $key );
                $self->_transform_recursive( $rs, $data->{$key} );
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

    my $existing_obj = $rel_rs->find( $existing )
        or croak "existing $key not found with ".dump( $existing );

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
