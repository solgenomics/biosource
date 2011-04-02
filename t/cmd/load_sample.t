use strict;
use warnings;
use Test::More;


use Config::General;
use IO::String;

my $loader = test_loader->new;
$loader->biosource_schema->txn_do(sub {
  ALL_TESTS( $loader );
  $loader->biosource_schema->txn_rollback;
});

done_testing;
exit;

#################

sub ALL_TESTS {
    my $loader = shift;

    my %data = Config::General->new( -String => <<EOC )->getall;
<sample>

   sample_name        LA0716 Total Trichomes
   alternative_name   Solpe454_001
   sample_type_name   454 sequences
   organism_name      Solanum pennellii
   <stock>
       name         LA0716
   </stock>
   <protocol>
       name      454 sequencing
   </protocol>
   <contact>
       name       Robert Buels
   </contact>
   <publication>
      title   Studies of a biochemical factory: tomato trichome deep expressed sequence tag sequencing and proteomics.
   </publication>

   description Total RNA was extracted from total trichomes isolated from leaf tissue of Solanum pennellii LA0716 plants and used directly for cDNA synthesis using the Clontech SMART cDNA synthesis kit with slight modification to kit protocols. Reverse transcription of RNA was performed using a modified primer with sequence: 5'-TAGAGGCCGAGGCGGCCGACATGTTTTGTTTTTTTTTCTTTTTTTTTTVN-3'. Size selected SfiI digested cDNA was submitted for sequencing by the Michigan State University sequencing facility according to the standard Roche 454 GS-FLX protocol.

</sample>
EOC

    diag explain \%data;

    $loader->load( \%data );

}

#################

BEGIN {
    package test_loader;
    use Moose;
    with 'CXGN::Biosource::Cmd::Role::SampleLoader';

    use CXGN::Biosource::Schema;

    sub biosource_schema {
        CXGN::Biosource::Schema->connect(
            $ENV{BIOSOURCE_TEST_DBDSN},
            $ENV{BIOSOURCE_TEST_DBUSER},
            $ENV{BIOSOURCE_TEST_DBPASS},
            { on_connect_do => 'set search_path = biosource,metadata,public' },
            );
    }

}
