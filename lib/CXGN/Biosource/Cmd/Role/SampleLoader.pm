package CXGN::Biosource::Cmd::Role::SampleLoader;
use Moose::Role;
use namespace::autoclean;

requires 'biosource_schema';

sub validate {
    my ( $self, $file, $file_data ) = @_;

}

sub load {
    my ( $self, $file_data ) = @_;

    $self->load_sample( $file_data->{sample} );
}

####### helpers #########

sub load_sample {
    my ( $self, $sample_data ) = @_;
    my %data = %$sample_data;

    my $sample = $self->biosource_schema->resultset('BsSample')
         ->find_or_create({ sample_name => delete $data{sample_name} });

    for (keys %data) {
        if( my $h = $self->can("handle_$_") ) {
            $self->$h( $sample, \%data, $_ );
        }
    }

    $sample->update( \%data );
}

sub handle_publication {
    my ( $self, $sample, $data, $key ) = @_;
    my $pubs = delete $data->{$key};
    $pubs = [ $pubs ] unless ref $pubs eq 'ARRAY';

    for my $pub (@$pubs) {
        next if $sample->search_related('bs_sample_pubs')
                       ->search_related('pub', $pub )
                       ->count;

        my $pub = $self->biosource_schema->resultset('Pub::Pub')
                       ->find_or_create( $pub );
        $sample->create_related('bs_sample_pubs', { pub => $pub });
    }

}


1;
