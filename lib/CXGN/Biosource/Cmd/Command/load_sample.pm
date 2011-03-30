package CXGN::Biosource::Cmd::Command::load_sample;
use Moose;

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
);

with 'MooseX::Role::DBIC' => {
    schema_name => 'biosource',
    accessor_options => \%getopt_configuration,
};



sub abstract { 'load data on bs_sample' }

sub execute {
    my ( $self, $opt, @args ) = @_;

    print "load that thing!\n";
}

1;
