package CXGN::Biosource::Cmd::Command::load_sample;
sub abstract { 'load bs_sample data' }

use Moose;
use namespace::autoclean;

use Config::General;

extends 'MooseX::App::Cmd::Command';

my %getopt_configuration =  (
        ( map {
            ( "biosource_$_" => [ traits => ['NoGetopt']] )
          } qw( schema attrs schema_options )
        ),
        biosource_dsn => [
            traits      => ['Getopt'],
            cmd_aliases => 'd',
            ],
        biosource_user => [
            traits      => ['Getopt'],
            cmd_aliases => 'u',
            ],
        biosource_password => [
            traits      => ['Getopt'],
            cmd_aliases => 'p',
            ],
        biosource_class => [
            default => 'CXGN::Biosource::Schema',
            ],
);

with 'MooseX::Role::DBIC' => {
    schema_name => 'biosource',
    accessor_options => \%getopt_configuration,
};

# the actual loading functionality is in here
with 'CXGN::Biosource::Cmd::Role::SampleLoader';

sub execute {
    my ( $self, $opt, @data_files ) = @_;

    my @data =
        map {
            my $file = $_;
            my %data = Config::General->new( $file )->getall;
            $self->validate( $file, \%data );
            \%data
        }
        @data_files;

    $self->biosource_schema->txn_do( sub {
        for my $file_data ( @data ) {
            $self->load( $file_data );
        }
    });
}


1;
