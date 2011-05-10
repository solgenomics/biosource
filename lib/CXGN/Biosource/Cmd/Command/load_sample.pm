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
            default => sub { +{ on_connect_do => 'set search_path = biosource,metadata,public' } },
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
with 'CXGN::Biosource::Cmd::Role::SampleLoader',
     'CXGN::Biosource::Cmd::Role::DataStreamer';

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

has '+input_handles' => (
    traits => ['NoGetopt'],
  );

sub execute {
    my ( $self, $opt, $argv ) = @_;

    # validate the input if possible
    my $input_is_prevalidated = 0;
    if( @$argv ) {
        $self->input_handles( [ @$argv ] );
        while( my $data = $self->next_data ) {
            $self->validate( $data );
        }
        $input_is_prevalidated = 1;
        $self->input_handles( [ @$argv ] );
    } else {
        $self->input_handles( [ \*STDIN ] );
    }

    local $ENV{DBIC_TRACE} = $self->dry_run || $self->trace ? 1 : 0;

    # now load
    $self->biosource_schema->txn_do( sub {

        while( my $data = $self->next_data ) {
            $self->validate( $data ) unless $input_is_prevalidated;
            $self->load( $data );
        }

        if( $self->dry_run ) {
            print "\nDry run requested, rolling back transaction.\n";
            $self->biosource_schema->txn_rollback;
            print "Success.\n";
        }
    });
}

1;
