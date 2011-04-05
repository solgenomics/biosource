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

# block is a row
#   scalar is a column value
#   block name implies id name

sub ALL_TESTS {
    my $loader = shift;

    my %data = load_test_set('one');

    #diag explain \%data;

    $loader->transform_for_populate( \%data );

    is_numeric( $data{BsSample}{organism_id}, "inflated organism_id" )
       or diag explain \%data;
    is_numeric( $data{BsSample}{type}{cv_id}, "inflated cv_id" )
       or diag explain $data{type};

    $loader->load( { load_test_set('one') } );
}

#################

sub is_numeric {
    my ( $thing, $desc ) = @_;
    like( $thing, qr/^\d+$/, "$desc is numeric" );
}


sub load_test_set {
    my ( $name ) = @_;

    my %sets = ( one => <<EOC,
<sample>
   sample_name        Made up sample name for testing!
   alternative_name   made up alternative
   description <<EOD
      This is a big long indented description!
      Total RNA was extracted from total trichomes isolated from leaf
      tissue of Solanum pennellii LA0716 plants and used directly for
      cDNA synthesis using the Clontech SMART cDNA synthesis kit with
      slight modification to kit protocols. Reverse transcription of
      RNA was performed using a modified primer with sequence:
      5'-TAGAGGCCGAGGCGGCCGACATGTTTTGTTTTTTTTTCTTTTTTTTTTVN-3'. Size
      selected SfiI digested cDNA was submitted for sequencing by the
      Michigan State University sequencing facility according to the
      standard Roche 454 GS-FLX protocol.
      EOD

   <sample_type>
     name   made_up_type
   </sample_type>

   <organism :existing>
      species         Solanum pennellii
   </organism>
   <stock :existing>
        name         LA0716
   </stock>
   <protocol>
       protocol_name  noggin bashing
   </protocol>
   # <contact :existing>
   #     name           Robert Buels
   # </contact>

   <bs_sample_pubs>
     <pub :existing>
        title Nature and regulation of pistil-expressed genes in tomato.
        # TODO: might want to support doing something like this in the future
        # <stock_relationship_pubs>
        #   <stock_relationship>
        #      <subject :existing>
        #         name LA0716
        #      </subject>
        #      <object>
        #         name This is a test stock!
        #      </object>
        #      <type :existing>
        #         name null
        #      </type>
        #   </stock_relationship>
        # </stock_relationship_pubs>
     </pub>
   </bs_sample_pubs>
   <bs_sample_pubs>
     <pub>
        title New test pub!
        uniquename Fogbattesttest
        <type :existing>
          name "journal"
        </type>
     </pub>
   </bs_sample_pubs>
</sample>
EOC
                 two => <<EOC,
<sample>
   sample_name        LA0716 Total Trichomes
   alternative_name   Solpe454_001
   description <<EOD
      Total RNA was extracted from total trichomes isolated from leaf
      tissue of Solanum pennellii LA0716 plants and used directly for
      cDNA synthesis using the Clontech SMART cDNA synthesis kit with
      slight modification to kit protocols. Reverse transcription of
      RNA was performed using a modified primer with sequence:
      5'-TAGAGGCCGAGGCGGCCGACATGTTTTGTTTTTTTTTCTTTTTTTTTTVN-3'. Size
      selected SfiI digested cDNA was submitted for sequencing by the
      Michigan State University sequencing facility according to the
      standard Roche 454 GS-FLX protocol.
      EOD

   <type :existing>
     name   454 sequences
   </type>

   <organism :existing>
      species         Solanum pennellii
   </organism>
   <protocol :existing>
       protocol_name  noggin bashing
   </protocol>
</sample>
EOC

                 );

    return Config::General->new( -String => $sets{$name} )->getall;
}


BEGIN {
    package test_loader;
    use Moose;

    use CXGN::Biosource::Schema;

    has 'biosource_schema' => (
        is => 'ro',
        lazy_build => 1,
        );
    sub _build_biosource_schema {
        CXGN::Biosource::Schema->connect(
            $ENV{BIOSOURCE_TEST_DBDSN},
            $ENV{BIOSOURCE_TEST_DBUSER},
            $ENV{BIOSOURCE_TEST_DBPASS},
            { on_connect_do => 'set search_path = biosource,metadata,public' },
            );
    }

    with 'CXGN::Biosource::Cmd::Role::SampleLoader';

}
