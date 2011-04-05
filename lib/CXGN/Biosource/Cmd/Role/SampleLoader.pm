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


1;

