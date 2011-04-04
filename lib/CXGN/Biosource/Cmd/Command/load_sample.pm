package CXGN::Biosource::Cmd::Command::load_sample;
sub abstract { 'load bs_sample data' }

use Moose;
use namespace::autoclean;

use Config::General;

extends 'MooseX::App::Cmd::Command';

my %getopt_configuration =  (
        ( map {
            ( "biosource_$_" => [ traits => ['NoGetopt']] )
          } qw( schema attrs )
        ),
        biosource_schema_options => [
            traits  => ['NoGetopt'],
            default => sub { +{ on_connect_do => 'set search_path = biosource,public' } },
            ],
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


has 'dry_run' => (
    is            => 'ro',
    isa           => 'Bool',
    traits        => ['Getopt'],
    cmd_aliases   => 'x',
    default       => 0,
    documentation => 'do not actually load, also implies --trace',
    );

has 'trace'  => (
    is            => 'ro',
    isa           => 'Bool',
    traits        => ['Getopt'],
    cmd_aliases   => 't',
    default       => sub { shift->dry_run },
    documentation => 'print SQL commands that are run',
);

has '+key_map' => (
    traits => ['NoGetopt'],
    );

sub execute {
    my ( $self, $opt, $argv ) = @_;

    my @data =
        map {
            my $file = $_;
            my %data = Config::General->new( $file )->getall;
            $self->validate( $file, \%data );
            \%data
        }
        @$argv;
    local $ENV{DBIC_TRACE} = $self->dry_run || $self->trace ? 1 : 0;

    $self->biosource_schema->txn_do( sub {
        for my $file_data ( @data ) {
            $self->load( $file_data );
        }
        if( $self->dry_run ) {
            print "dry run selected, rolling back transaction.\n";
            $self->biosource_schema->txn_rollback;
        }
    });
}


1;
