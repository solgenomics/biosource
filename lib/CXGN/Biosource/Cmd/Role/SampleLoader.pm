package CXGN::Biosource::Cmd::Role::SampleLoader;
use Moose::Role;
use namespace::autoclean;

use Carp;
use Data::Dump 'dump';
use Storable 'dclone';

requires 'biosource_schema';

with 'MooseX::Role::DBIC::NestedPopulate';

sub schema { shift->biosource_schema( @_ ) }

sub key_map {
    return { sample => 'BsSample' }
}

sub validate {
    my ( $self, $file, $file_data ) = @_;
}

# implement some convenient biosource-specific shortcuts in the loading syntax
before 'transform_for_populate' => sub {
    my ( $self, $data ) = @_;

    # for each data item
    for my $d ( ref $data eq 'ARRAY' ? @$data : $data ) {

        # support a <sample_type> shortcut that automatically uses
        # existing sample_type CV and a null database for the dbxref
        if( my $type = delete $d->{sample}{sample_type} ) {
            $d->{sample}{type} =
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
            if( my $existing = delete $type->{':existing'} ) {
                $d->{sample}{type} = { ':existing' => $d->{sample}{type} };
            }
        }



    }

};


1;

