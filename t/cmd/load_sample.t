use strict;
use warnings;
use Test::More;

use Config::General;
use Data::Dump 'dump';
use IO::String;

use Test::Exception;

my $loader = test_loader->new;

TEST_INPUT( $loader );

$loader->biosource_schema->txn_do(sub {
  TEST_LOAD( $loader );
  $loader->biosource_schema->txn_rollback;
});

done_testing;
exit;

#################

sub TEST_INPUT {
    my $loader = shift;

    my @test_inputs = ( <<EOC,
<foo>
  bar baz
</foo>
  <zoz>
    zee 1
  </zoz>
-
<zoom>
  zang 42
</zoom>
-
EOC
                        <<EOC,
foo bar

------
baz boo




EOC
                        );

    $loader->input_handles( _test_open( @test_inputs ));
    my @chunks;
    while(my $d = $loader->next_data ) {
        push @chunks, $d;
    }
    is_deeply( \@chunks, [
        { foo => { bar => "baz" }, zoz => { zee => 1 } },
        { zoom => { zang => 42 } },
        { foo => "bar" },
        { baz => "boo" },
      ], 'got right chunks' )
         or diag dump \@chunks;
}
sub _test_open {
    [ map { my $s = $_; IO::String->new( \$s ) } @_ ]
}

sub TEST_LOAD {
    my $loader = shift;

    my %data = load_test_set('one');

    $loader->transform_for_populate( \%data );

    is_numeric( $data{BsSample}{organism_id}, "inflated organism_id" )
       or diag explain \%data;
    is_numeric( $data{BsSample}{type}{cv_id}, "inflated cv_id" )
       or diag explain $data{type};
    is( $data{BsSample}{type}{name}, 'made_up_type', 'sample_type transformation worked' );

    %data = load_test_set('one');
    is( scalar( keys %data ), 1, 'loaded test set again' );

    lives_ok {
        $loader->load( { load_test_set('one') } );
    } 'load did not die';

    # check the stuff that was loaded
    my $sample_rs = $loader->biosource_schema->resultset('BsSample')
                           ->search( { sample_name => $data{sample}{sample_name} });
    is( $sample_rs->count, 1, 'inserted a sample' );
    my $sample = $sample_rs->single;
    can_ok( $sample, 'sample_name' );

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
      species       Solanum pennellii
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
   <bs_sample_pubs>
     <pub>
        title New test pub!
        uniquename Fogbattesttest
        <type :existing>
          name "journal"
        </type>
     </pub>
   </bs_sample_pubs>

  <dbxref>
    <db :existing>
      name   PO
    </db>
    accession 0000282
  </dbxref>

  <dbxref>
    <db>
       name  SRA
    </db>
    accession  SRX011590
  </dbxref>

  <file>
     dirname  /transcriptome/Solanum_pennellii/Solpe454_001
     basename FAN5VQW01.sff
  </file>
  <file>
     dirname  /transcriptome/Solanum_pennellii/Solpe454_001
     basename FAN5VQW02.sff
  </file>
  <file>
     dirname  /transcriptome/Solanum_pennellii/Solpe454_001
     basename Solpe454_001_in.454.fasta
  </file>
  <file>
     dirname  /transcriptome/Solanum_pennellii/Solpe454_001
     basename Solpe454_001_in.454.fasta.qual
  </file>

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
       protocol_name  ice skating
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
    with 'CXGN::Biosource::Cmd::Role::DataStreamer';

}
