package CXGN::Biosource::Cmd::Role::SampleLoader;
use Moose::Role;
use namespace::autoclean -also => 'to_list';

use Storable 'dclone';

requires 'biosource_schema';

with qw(
           MooseX::Role::DBIC::Populate
           MooseX::Role::DBIC::Populate::MapKeys
           MooseX::Role::DBIC::Populate::ExistingAssertions
       );

sub schema { shift->biosource_schema( @_ ) }

sub key_map {
    return {qw{
       /sample               BsSample
       /protocol             BsProtocol
       /sample_relationship  BsSampleRelationship
    }};
}

sub validate {
    my ( $self, $file, $file_data ) = @_;
}

sub to_list($) {
    my ( $data ) = @_;
    return ref $data eq 'ARRAY' ? @$data : $data
}

# implement some convenient biosource-specific shortcuts in the loading syntax
before 'resolve_existing' => sub {
    my ( $self, $data ) = @_;

    # for each data item
    for my $d ( to_list $data ) {
        if( $d->{BsSample} ) {
            for my $sample ( to_list $d->{BsSample} ) {
                $self->_munge_sample( $sample );
            }
        }
    }
};

sub _munge_sample {
    my ( $self, $d ) = @_;
    # support a <sample_type> shortcut that automatically uses
    # existing sample_type CV and a null database for the dbxref
    if ( my $type = delete $d->{sample_type} ) {
        $d->{type} =
            {
        name   => $type->{name} || $type->{':existing'}{name},
        cv     => {
            ':existing' => { name => 'sample_type' }
            },
        dbxref => {
            db        => { ':existing' => { name => 'null' } },
            accession => $type->{name} || $type->{':existing'}{name},
        },
    };
        # need to patch it up a bit if it's an existing sample type
        if ( my $existing = delete $type->{':existing'} ) {
            $d->{type} = { ':existing' => $d->{type} };
        }
    }

    # clean up the description a bit
    $d->{description} =~ s/\s+/ /g;

    # support a <files> section in a <sample> that makes it easier
    # to insert bs_sample_files
    $self->_xform_many_to_many( $d, 'file' => ( 'bs_sample_files' => 'file' ) );

    # support a dbxref section
    $self->_xform_many_to_many( $d, 'dbxref' => ( 'bs_sample_dbxrefs' => 'dbxref' ) );

    # support a pub section
    $self->_xform_many_to_many( $d, 'pub' => ( 'bs_sample_pubs' => 'pub' ) );
}

sub _xform_many_to_many {
    my ( $self, $d, $section, $rel, $frel ) = @_;

    if( my $mm_data = delete $d->{$section} ) {
        $d->{$rel} = [ to_list ( $d->{$rel} || [] ),
                       map {
                           { $frel => $_ },
                       } to_list $mm_data
                     ];
    }
}

1;

