package MooseX::Role::DBIC::Populate::ExistingAssertions;
use Moose::Role;
use namespace::autoclean -also => 'to_list';

use Carp;
use Data::Dump 'dump';

requires 'transform_for_populate';

after 'transform_for_populate' => sub {
    my ( $self, $data ) = @_;

    # resolve all the existing rows
    $self->resolve_existing( $data );
};


sub to_list($) {
    return map {
        ref && ref eq 'ARRAY' ? @$_ : $_
    } @_;
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
                            $self->_resolve_existing( $this_rs, $key, $existing, $path ),
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
    my ( $self, $this_rs, $key, $existing, $path ) = @_;

    my $rel_rs = $self->_related_resultset( $this_rs, $key );

    # recurse into this one, resolve any nested :existing
    $self->_transform_recursive( $rel_rs, $existing, $path );

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
