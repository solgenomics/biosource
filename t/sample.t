#!/usr/bin/perl

=head1 NAME

  sample.t
  A piece of code to test the CXGN::Biosource::Sample module

=cut

=head1 SYNOPSIS

 perl sample.t

 Note: To run the complete test the database connection should be done as 
       postgres user 
 (web_usr have not privileges to insert new data into the sed tables)  

 prove sample.t

 this test needs some environment variables:

   export BIOSOURCE_TEST_METALOADER= 'metaloader user'
   export BIOSOURCE_TEST_DBDSN= 'database dsn as: dbi:DriverName:database=database_name;host=hostname;port=port'
   export BIOSOURCE_TEST_DBUSER= 'database user with insert permissions'
   export BIOSOURCE_TEST_DBPASS= 'database password'

 also is recommendable set the reset dbseq after run the script
    export RESET_DBSEQ=1

 if it is not set, after one run all the test that depends of a primary id
 (as metadata_id) will fail because it is calculated based in the last
 primary id and not in the current sequence for this primary id


=head1 DESCRIPTION

 This script check 216 variables to test the right operation of the 
 CXGN::Biosource::Sample module:

  - from   1 to   4  - Module use;
  - from   5 to  14 - BASIC SET/GET FUNCTIONS
  - from  15 to  35 - TESTING DIE ERROR for new() and set/get basic functions
  - from  36 to  43 - TESTING STORE_SAMPLE FUNCTIONS
  - from  44 to  46 - TESTING GET_METADATA FUNCTION
  - from  47 to  48 - TESTING DIE ERROR for store_sample()
  - from  49 to  53 - TESTING SAMPLE OBSOLETE FUNCTIONs
  - from  54 to  56 - TESTING DIE ERROR for sample obsolete functions
  - from  57 to  60 - TESTING STORE_SAMPLE
  - from  61        - TESTING NEW_BY_NAME
  - from  62 to  85 - TESTING associate publications functions
  - from  86 to 107 - TESTING associate dbxref functions
  - from 108 to 129 - TESTING associate cvterm functions
  - from 130 to 152 - TESTING associate file functions
  - from 153 to 214 - TESTING associate sample relationship functions
  - from 215 to 224 - TESTING general store function
  - from 225 to 226 - TESTING other functions

=cut

=head1 AUTHORS

 Aureliano Bombarely Gomez
 (ab782@cornell.edu)

=cut

use strict;
use warnings;

use Test::More;
use Test::Exception;

use CXGN::DB::Connection;


## The tests still need search_path

my @schema_list = ('biosource', 'metadata', 'public');
my $schema_list = join(',', @schema_list);
my $set_path = "SET search_path TO $schema_list";

## First check env. variables and connection

BEGIN {

    ## Env. variables have been changed to use biosource specific ones

    my @env_variables = qw/BIOSOURCE_TEST_METALOADER BIOSOURCE_TEST_DBDSN BIOSOURCE_TEST_DBUSER BIOSOURCE_TEST_DBPASS/;

    ## RESET_DBSEQ is an optional env. variable, it doesn't need to check it

    for my $env (@env_variables) {
        unless (defined $ENV{$env}) {
            plan skip_all => "Environment variable $env not set, aborting";
        }
    }

    eval { 
        CXGN::DB::Connection->new( 
                                   $ENV{BIOSOURCE_TEST_DBDSN}, 
                                   $ENV{BIOSOURCE_TEST_DBUSER}, 
                                   $ENV{BIOSOURCE_TEST_DBPASS}, 
                                   {on_connect_do => $set_path}
                                 ); 
    };

    if ($@ =~ m/DBI connect/) {

        plan skip_all => "Could not connect to database";
    }

    plan tests => 226;
}

BEGIN {
    use_ok('CXGN::Biosource::Schema');
    use_ok('CXGN::Biosource::Sample');
    use_ok('CXGN::Biosource::Protocol');
    use_ok('CXGN::Metadata::Metadbdata');
}


#if we cannot load the CXGN::Metadata::Schema module, no point in continuing
CXGN::Biosource::Schema->can('connect')
    or BAIL_OUT('could not load the CXGN::Biosource::Schema module');
CXGN::Metadata::Schema->can('connect')
    or BAIL_OUT('could not load the CXGN::Metadata::Schema module');
Bio::Chado::Schema->can('connect')
    or BAIL_OUT('could not load the Bio::Chado::Schema module');

## Prespecified variable

my $metadata_creation_user = $ENV{BIOSOURCE_TEST_METALOADER};

## The biosource schema contain all the metadata classes so don't need to create another Metadata schema
## CXGN::DB::DBICFactory is obsolete, it has been replaced by CXGN::Biosource::Schema

my $schema = CXGN::Biosource::Schema->connect( $ENV{BIOSOURCE_TEST_DBDSN}, 
                                               $ENV{BIOSOURCE_TEST_DBUSER}, 
                                               $ENV{BIOSOURCE_TEST_DBPASS}, 
                                               {on_connect_do => $set_path});

$schema->txn_begin();

## Get the last values
my %last_ids = %{$schema->get_last_id()};

my $last_metadata_id = $last_ids{'metadata.md_metadata_metadata_id_seq'};
my $last_sample_id = $last_ids{'biosource.bs_sample_sample_id_seq'};
my $last_cvterm_id = $last_ids{'cvterm_cvterm_id_seq'};
my $last_organism_id = $last_ids{'organism_organism_id_seq'};
my $last_protocol_id = $last_ids{'biosource.bs_protocol_protocol_id_seq'};

## Create a empty metadata object to use in the database store functions
my $metadbdata = CXGN::Metadata::Metadbdata->new($schema, $metadata_creation_user);
my $creation_date = $metadbdata->get_object_creation_date();
my $creation_user_id = $metadbdata->get_object_creation_user_by_id();

#######################################
## FIRST TEST BLOCK: Basic functions ##
#######################################

## (TEST FROM 5 to 13)
## This is the first group of tests, to check if an empty object can store and after can return the data
## Create a new empty object; 

my $sample = CXGN::Biosource::Sample->new($schema, undef); 

## Load of the eight different parameters for an empty object using a hash with keys=root name for tha function and
 ## values=value to test

my %test_values_for_empty_object=( sample_id        => $last_sample_id+1,
				   sample_name      => 'sample test',
				   alternative_name => 'another name',
				   type_id          => $last_cvterm_id || 1,
				   description      => 'this is a test',
				   organism_id      => $last_organism_id || 1,
				   stock_id         => 1,
				   protocol_id      => $last_protocol_id || 1,
				   contact_id       => $creation_user_id,
                                  );

## Load the data in the empty object
my @function_keys = sort keys %test_values_for_empty_object;
foreach my $rootfunction (@function_keys) {
    my $setfunction = 'set_' . $rootfunction;
    if ($rootfunction eq 'sample_id') {
	$setfunction = 'force_set_' . $rootfunction;
    } 
    $sample->$setfunction($test_values_for_empty_object{$rootfunction});
}
## Get the data from the object and store in two hashes. The first %getdata with keys=root_function_name and 
 ## value=value_get_from_object and the second, %testname with keys=root_function_name and values=name for the test.

my (%getdata, %testnames);
foreach my $rootfunction (@function_keys) {
    my $getfunction = 'get_'.$rootfunction;
    my $data = $sample->$getfunction();
    $getdata{$rootfunction} = $data;
    my $testname = 'BASIC SET/GET FUNCTION for ' . $rootfunction.' test';
    $testnames{$rootfunction} = $testname;
}

## And now run the test for each function and value

foreach my $rootfunction (@function_keys) {
    is($getdata{$rootfunction}, $test_values_for_empty_object{$rootfunction}, $testnames{$rootfunction}) 
	or diag "Looks like this failed.";
}

## Test the set_contact_by_username (TEST 14)

$sample->set_contact_by_username($metadata_creation_user);
my $contact = $sample->get_contact_by_username();
is($sample->get_contact_by_username(), $metadata_creation_user, "BASIC SET/GET FUNCTION for contact_by_username, checking username")
    or diag "Looks like this failed";

## It will check set_organism_by_species and set_protocol_by_name after insert 
## into the database this data

## Testing the die results (TEST 15 to 35)

throws_ok { CXGN::Biosource::Sample->new() } qr/PARAMETER ERROR: None schema/, 
    'TESTING DIE ERROR when none schema is supplied to new() function';

throws_ok { CXGN::Biosource::Sample->new($schema, 'no integer')} qr/DATA TYPE ERROR/, 
    'TESTING DIE ERROR when a non integer is used to create a protocol object with new() function';

throws_ok { CXGN::Biosource::Sample->new($schema)->set_bssample_row() } qr/PARAMETER ERROR: None bssample_row/, 
    'TESTING DIE ERROR when none schema is supplied to set_bssample_row() function';

throws_ok { CXGN::Biosource::Sample->new($schema)->set_bssample_row($schema) } qr/SET ARGUMENT ERROR:/, 
    'TESTING DIE ERROR when argument supplied to set_bssample_row() is not a CXGN::Biosource::Schema::BsSample row object';

throws_ok { CXGN::Biosource::Sample->new($schema)->force_set_sample_id() } qr/PARAMETER ERROR: None sample_id/, 
    'TESTING DIE ERROR when none sample_id is supplied to set_force_sample_id() function';

throws_ok { CXGN::Biosource::Sample->new($schema)->force_set_sample_id('non integer') } qr/DATA TYPE ERROR:/, 
    'TESTING DIE ERROR when argument supplied to set_force_sample_id() is not an integer';

throws_ok { CXGN::Biosource::Sample->new($schema)->set_sample_name() } qr/PARAMETER ERROR: None data/, 
    'TESTING DIE ERROR when none data is supplied to set_sample_name() function';

throws_ok { CXGN::Biosource::Sample->new($schema)->set_type_id() } qr/PARAMETER ERROR: None data/, 
    'TESTING DIE ERROR when none data is supplied to set_type_id() function';

throws_ok { CXGN::Biosource::Sample->new($schema)->set_type_id('non integer') } qr/DATA TYPE ERROR:/, 
    'TESTING DIE ERROR when argument supplied to set_type_id() is not an integer';

throws_ok { CXGN::Biosource::Sample->new($schema)->set_contact_id('non integer') } qr/DATA TYPE ERROR:/, 
    'TESTING DIE ERROR when argument supplied to set_contact_id() is not an integer';

throws_ok { CXGN::Biosource::Sample->new($schema)->set_contact_by_username() } qr/SET ARGUMENT ERROR: None argument/, 
    'TESTING DIE ERROR when none argument is supplied to set_contact_by_username()';

throws_ok { CXGN::Biosource::Sample->new($schema)->set_contact_by_username('non existing user: None') } qr/DATABASE COHERENCE ERROR:/, 
    'TESTING DIE ERROR when username supplied to set_contact_by_username() do not exists into the database';

throws_ok { CXGN::Biosource::Sample->new($schema)->set_organism_id('non integer') } qr/DATA TYPE ERROR:/, 
    'TESTING DIE ERROR when argument supplied to set_organism_id() is not an integer';

throws_ok { CXGN::Biosource::Sample->new($schema)->set_organism_by_species() } qr/SET ARGUMENT ERROR: None argument/, 
    'TESTING DIE ERROR when none argument is supplied to set_organism_by_species()';

throws_ok { CXGN::Biosource::Sample->new($schema)->set_organism_by_species('non existing species: None') } qr/DATABASE COHERENCE ERROR:/, 
    'TESTING DIE ERROR when spcies supplied to set_organism_by_species() do not exists into the database';

throws_ok { CXGN::Biosource::Sample->new($schema)->set_stock_id() } qr/PARAMETER ERROR: None data/, 
    'TESTING DIE ERROR when none data is supplied to set_stock_id() function';

throws_ok { CXGN::Biosource::Sample->new($schema)->set_stock_id('non integer') } qr/DATA TYPE ERROR:/, 
    'TESTING DIE ERROR when argument supplied to set_stock_id() is not an integer';

throws_ok { CXGN::Biosource::Sample->new($schema)->set_protocol_id() } qr/PARAMETER ERROR: None data/, 
    'TESTING DIE ERROR when none data is supplied to set_protocol_id() function';

throws_ok { CXGN::Biosource::Sample->new($schema)->set_protocol_id('non integer') } qr/DATA TYPE ERROR:/, 
    'TESTING DIE ERROR when argument supplied to set_protocol_id() is not an integer';

throws_ok { CXGN::Biosource::Sample->new($schema)->set_protocol_by_name() } qr/SET ARGUMENT ERROR: None argument/, 
    'TESTING DIE ERROR when none argument is supplied to set_protocol_by_name()';

throws_ok { CXGN::Biosource::Sample->new($schema)->set_protocol_by_name('non existing protocol: None') } qr/DATABASE COHERENCE ERROR:/, 
    'TESTING DIE ERROR when spcies supplied to set_protocol_by_name() do not exists into the database';


#######################################################
### SECOND TEST BLOCK:  Store and Obsolete Functions ##
#######################################################

### Use of store functions.

 eval {

     ## Before evaluate this function it should create a protocol, 
     ## organism and cvterm (as sample type)
     
     ## PREREQ ORGANISM
     
     my $organism_row = $schema->resultset('Organism::Organism')
	                       ->new(
	                              {
					  abbreviation => 'G.species',
					  genus        => 'Genus',
					  species      => 'Genus species',
					  common_name  => 'Organism test',
					  comment      => 'testing species',
                                      }
			            )
			       ->insert()
			       ->discard_changes();
     
     my $organism_id = $organism_row->get_column('organism_id');

     ## PREREQ PROTOCOL

     my $protocol = CXGN::Biosource::Protocol->new($schema);
     $protocol->set_protocol_name('protocol test');
     $protocol->set_protocol_type('test');
     $protocol->set_description('This is a test too');
     $protocol->store($metadbdata);

     my $protocol_id = $protocol->get_protocol_id();

     ## PREREQ CVTERM TYPE (it will need db, dbxref, cv and cvterm)

      my $new_db_id0 = $schema->resultset('General::Db')
                              ->new( 
                                    { 
                                      name        => 'dbtesting for sample type',
                                      description => 'this is a test for add a sample type',
                                      urlprefix   => 'http//.',
                                      url         => 'www.testingdb.com'
                                    }
                                  )
                              ->insert()
                              ->discard_changes()
                              ->get_column('db_id');

     my $new_dbxref_id0 = $schema->resultset('General::Dbxref')
                                 ->new( 
                                         { 
                                           db_id       => $new_db_id0,
                                           accession   => 'TESTDBXREF-SAMPLE_TYPE',
                                           version     => '1',
                                           description => 'this is a test for add a sample type',
                                         }
                                       )
                                  ->insert()
                                  ->discard_changes()
                                  ->get_column('dbxref_id');

     my $another_dbxref_id0 = $schema->resultset('General::Dbxref')
                                 ->new( 
                                         { 
                                           db_id       => $new_db_id0,
                                           accession   => 'TESTDBXREF-SAMPLE_TYPE 2',
                                           version     => '1',
                                           description => 'this is a test for add a sample type',
                                         }
                                       )
                                  ->insert()
                                  ->discard_changes()
                                  ->get_column('dbxref_id');


     my $new_cv_id0 = $schema->resultset('Cv::Cv')
                             ->new( 
                                    { 
                                       name       => 'sample types cv', 
                                       definition => 'this is a test for add sample types',
                                    }
                                  )
                             ->insert()
                             ->discard_changes()
                             ->get_column('cv_id');

     my $new_type_id0 = $schema->resultset('Cv::Cvterm')
                                 ->new( 
                                    { 
                                       cv_id      => $new_cv_id0,
                                       name       => 'sample type cvterm 1',
                                       definition => 'this is a test for add sample types',
                                       dbxref_id  => $new_dbxref_id0,
                                    }
                                  )
                             ->insert()
                             ->discard_changes()
                             ->get_column('cvterm_id');

     my $new_type_id1 = $schema->resultset('Cv::Cvterm')
                                 ->new( 
                                    { 
                                       cv_id      => $new_cv_id0,
                                       name       => 'sample type cvterm 2',
                                       definition => 'this is another test for add sample types',
                                       dbxref_id  => $another_dbxref_id0,
                                    }
                                  )
                             ->insert()
                             ->discard_changes()
                             ->get_column('cvterm_id');

     my $sample2 = CXGN::Biosource::Sample->new($schema);
     $sample2->set_sample_name('sample_test');
     $sample2->set_alternative_name('alternative sample test');
     $sample2->set_type_id($new_type_id0);
     $sample2->set_description('This is a description test');
     $sample2->set_contact_by_username($metadata_creation_user);
     $sample2->set_organism_by_species('Genus species');
     $sample2->set_stock_id(1);
     $sample2->set_protocol_by_name('protocol test');

     $sample2->store_sample($metadbdata);

     my $curr_metadata_id = $metadbdata->get_metadata_id();
     

     ## Testing the protocol_id and protocol_name for the new object stored (TEST 36 to 43)

     is($sample2->get_sample_id(), $last_sample_id+1, "TESTING STORE_SAMPLE FUNCTION, checking the sample_id")
	 or diag "Looks like this failed";
     is($sample2->get_sample_name(), 'sample_test', "TESTING STORE_SAMPLE FUNCTION, checking the sample_name")
	 or diag "Looks like this failed";
     is($sample2->get_type_id(), $last_cvterm_id+1, "TESTING STORE_SAMPLE FUNCTION, checking the type_id")
	 or diag "Looks like this failed";
     is($sample2->get_description(), 'This is a description test', "TESTING STORE_SAMPLE FUNCTION, checking description")
	 or diag "Looks like this failed";
     is($sample2->get_contact_by_username(), $metadata_creation_user, "TESTING STORE_SAMPLE FUNCTION, checking contact by username")
	 or diag "Looks like this failed";
     is($sample2->get_organism_by_species(), 'Genus species', "TESTING STORE_SAMPLE FUNCTION, checking organism by species")
	 or diag "Looks like this failed";
     is($sample2->get_stock_id(), 1, "TESTING STORE_SAMPLE FUNCTION, checking the stock_id")
	 or diag "Looks like this failed";
     is($sample2->get_protocol_by_name(), $protocol->get_protocol_name(), "TESTING STORE_SAMPLE FUNCTION, checking protocol by name")
	 or diag "Looks like this failed";

     ## Testing the get_medatata function (TEST 44 to 46)

     my $obj_metadbdata = $sample2->get_sample_metadbdata();
     is($obj_metadbdata->get_metadata_id(), $last_metadata_id+1, "TESTING GET_METADATA FUNCTION, checking the metadata_id")
 	or diag "Looks like this failed";
     is($obj_metadbdata->get_create_date(), $creation_date, "TESTING GET_METADATA FUNCTION, checking create_date")
 	or diag "Looks like this failed";
     is($obj_metadbdata->get_create_person_id_by_username, $metadata_creation_user, 
	"TESING GET_METADATA FUNCTION, checking create_person by username")
 	or diag "Looks like this failed";
    
     ## Testing die for store function (TEST 47 and 48)

     throws_ok { $sample2->store_sample() } qr/STORE ERROR: None metadbdata/, 
     'TESTING DIE ERROR when none metadbdata object is supplied to store_sample() function';

     throws_ok { $sample2->store_sample($schema) } qr/STORE ERROR: Metadbdata supplied/, 
     'TESTING DIE ERROR when argument supplied to store_sample() is not a CXGN::Metadata::Metadbdata object';

     ## Testing if it is obsolete (TEST 49)

     is($sample2->is_sample_obsolete(), 0, "TESTING IS_SAMPLE_OBSOLETE FUNCTION, checking boolean")
 	or diag "Looks like this failed";

     ## Testing obsolete (TEST 50 to 53) 

     $sample2->obsolete_sample($metadbdata, 'testing obsolete');
    
     is($sample2->is_sample_obsolete(), 1, "TESTING SAMPLE_OBSOLETE FUNCTION, checking boolean after obsolete the sample")
 	or diag "Looks like this failed";

     is($sample2->get_sample_metadbdata()->get_metadata_id, $last_metadata_id+2, "TESTING SAMPLE_OBSOLETE, checking metadata_id")
 	or diag "Looks like this failed";

     $sample2->obsolete_sample($metadbdata, 'testing obsolete', 'REVERT');
    
     is($sample2->is_sample_obsolete(), 0, "TESTING REVERT SAMPLE_OBSOLETE FUNCTION, checking boolean after revert obsolete")
 	or diag "Looks like this failed";

     is($sample2->get_sample_metadbdata()->get_metadata_id, $last_metadata_id+3, "TESTING REVERT SAMPLE_OBSOLETE, for metadata_id")
 	or diag "Looks like this failed";

     ## Testing die for obsolete function (TEST 54 to 56)

     throws_ok { $sample2->obsolete_sample() } qr/OBSOLETE ERROR: None metadbdata/, 
     'TESTING DIE ERROR when none metadbdata object is supplied to obsolete_sample() function';

     throws_ok { $sample2->obsolete_sample($schema) } qr/OBSOLETE ERROR: Metadbdata/, 
     'TESTING DIE ERROR when argument supplied to obsolete_sample() is not a CXGN::Metadata::Metadbdata object';

     throws_ok { $sample2->obsolete_sample($metadbdata) } qr/OBSOLETE ERROR: None obsolete note/, 
     'TESTING DIE ERROR when none obsolete note is supplied to obsolete_sample() function';
    
     ## Testing store for modifications (TEST 57 to 60)

     $sample2->set_description('This is another test');
     $sample2->store_sample($metadbdata);

     is($sample2->get_sample_id(), $last_sample_id+1, "TESTING STORE_SAMPLE for modifications, checking the sample_id")
 	or diag "Looks like this failed";
     is($sample2->get_sample_name(), 'sample_test', "TESTING STORE_SAMPLE for modifications, checking the sample_name")
 	or diag "Looks like this failed";
     is($sample2->get_description(), 'This is another test', "TESTING STORE_SAMPLE for modifications, checking description")
 	or diag "Looks like this failed";

     my $obj_metadbdata2 = $sample2->get_sample_metadbdata();
     is($obj_metadbdata2->get_metadata_id(), $last_metadata_id+4, "TESTING STORE_SAMPLE for modifications, checking new metadata_id")
 	or diag "Looks like this failed";
    

     ## Testing new by name (TEST 61)

     my $sample3 = CXGN::Biosource::Sample->new_by_name($schema, 'sample_test');
     is($sample3->get_sample_id(), $last_sample_id+1, "TESTING NEW_BY_NAME, checking sample_id")
 	or diag "Looks like this failed";


     #######################################
     ## THIRD BLOCK: Sample_Pub functions ##
     #######################################

     ## Testing of the publication

     ## Testing the die when the wrong for the row accessions get/set_bssamplepub_rows (TEST 62 to 64)
    
     throws_ok { $sample3->set_bssamplepub_rows() } qr/FUNCTION PARAMETER ERROR: None bssamplepub_row/, 
     'TESTING DIE ERROR when none data is supplied to set_bssamplepub_rows() function';

     throws_ok { $sample3->set_bssamplepub_rows('this is not an integer') } qr/SET ARGUMENT ERROR:/, 
     'TESTING DIE ERROR when data type supplied to set_bssamplepub_rows() function is not an array reference';

     throws_ok { $sample3->set_bssamplepub_rows([$schema, $schema]) } qr/SET ARGUMENT ERROR:/, 
     'TESTING DIE ERROR when the elements of the array reference supplied to set_bssamplepub_rows() function are not row objects';


     ## First, it need to add all the rows that the chado schema use for a publication
 
     my $new_db_id = $schema->resultset('General::Db')
                             ->new( 
                                    { 
                                      name        => 'dbtesting',
                                      description => 'this is a test for add a tool-pub relation',
                                      urlprefix   => 'http//.',
                                      url         => 'www.testingdb.com'
                                    }
                                  )
                              ->insert()
                              ->discard_changes()
                              ->get_column('db_id');

     my $new_dbxref_id1 = $schema->resultset('General::Dbxref')
                                 ->new( 
                                         { 
                                           db_id       => $new_db_id,
                                           accession   => 'TESTDBACC01',
                                           version     => '1',
                                           description => 'this is a test for add a tool-pub relation',
                                         }
                                       )
                                  ->insert()
                                  ->discard_changes()
                                  ->get_column('dbxref_id');

     my $new_dbxref_id2 = $schema->resultset('General::Dbxref')
                                 ->new( 
                                         { 
                                           db_id       => $new_db_id,
                                           accession   => 'TESTDBACC02',
                                           version     => '1',
                                           description => 'this is a test for add a tool-pub relation',
                                         }
                                       )
                                  ->insert()
                                  ->discard_changes()
                                  ->get_column('dbxref_id');

     my $new_cv_id = $schema->resultset('Cv::Cv')
                             ->new( 
                                    { 
                                       name       => 'testingcv', 
                                       definition => 'this is a test for add a tool-pub relation',
                                    }
                                  )
                             ->insert()
                             ->discard_changes()
                             ->get_column('cv_id');

      my $new_cvterm_id1 = $schema->resultset('Cv::Cvterm')
                                 ->new( 
                                    { 
                                       cv_id      => $new_cv_id,
                                       name       => 'testingcvterm1',
                                       definition => 'this is a test for add tool-pub relation',
                                       dbxref_id  => $new_dbxref_id1,
                                    }
                                  )
                             ->insert()
                             ->discard_changes()
                             ->get_column('cvterm_id');

     my $new_cvterm_id2 = $schema->resultset('Cv::Cvterm')
                                 ->new( 
                                    { 
                                       cv_id      => $new_cv_id,
                                       name       => 'testingcvterm2',
                                       definition => 'this is a test for add tool-pub relation',
                                       dbxref_id  => $new_dbxref_id2,
                                    }
                                  )
                             ->insert()
                             ->discard_changes()
                             ->get_column('cvterm_id');

      my $new_pub_id1 = $schema->resultset('Pub::Pub')
                               ->new( 
                                     { 
                                          title          => 'testingtitle1',
                                          uniquename     => '00000:testingtitle1',   
                                          type_id        => $new_cvterm_id1,
                                      }
                                    )
                               ->insert()
                               ->discard_changes()
                               ->get_column('pub_id');

     my $new_pub_id2 = $schema->resultset('Pub::Pub')
                               ->new( 
                                       { 
                                         title          => 'testingtitle2',
                                         uniquename     => '00000:testingtitle2',   
                                         type_id        => $new_cvterm_id1,
                                       }
                                     )
                               ->insert()
                               ->discard_changes()
                               ->get_column('pub_id');

      my $new_pub_id3 = $schema->resultset('Pub::Pub')
                                ->new( 
                                       { 
                                         title          => 'testingtitle3',
                                         uniquename     => '00000:testingtitle3',   
                                         type_id        => $new_cvterm_id1,
                                       }
                                     )
                                ->insert()
                                ->discard_changes()
                                ->get_column('pub_id');

      my @pub_list = ($new_pub_id1, $new_pub_id2, $new_pub_id3);
 
      my $new_pub_dbxref = $schema->resultset('Pub::PubDbxref')
                                  ->new( 
                                          { 
                                            pub_id    => $new_pub_id3,
                                            dbxref_id => $new_dbxref_id1,   
                                          }
                                        )
                                  ->insert();

     ## TEST DIE for add_publication, TEST 65 and 67

     throws_ok { $sample3->add_publication() } qr/FUNCTION PARAMETER ERROR: None pub/, 
     'TESTING DIE ERROR when none data is supplied to add_publication() function';

     throws_ok { $sample3->add_publication('this is not an integer') } qr/SET ARGUMENT ERROR: Publication/, 
     'TESTING DIE ERROR when data supplied to add_publication() function is not an integer';

     throws_ok { $sample3->add_publication({ title => 'fake that does not exist' }) } qr/DATABASE ARGUMENT ERROR: Publication data/, 
     'TESTING DIE ERROR when data supplied to add_publication() function does not exists into the database';

     ## TEST 68 AND 69

     $sample3->add_publication($new_pub_id1);
     $sample3->add_publication({ title => 'testingtitle2' });
     $sample3->add_publication({ dbxref_accession => 'TESTDBACC01' });

     my @pub_id_list = $sample3->get_publication_list();
     my $expected_pub_id_list = join(',', sort {$a <=> $b} @pub_list);
     my $obtained_pub_id_list = join(',', sort {$a <=> $b} @pub_id_list);

     is($obtained_pub_id_list, $expected_pub_id_list, 'TESTING ADD_PUBLICATION and GET_PUBLICATION_LIST, checking pub_id list')
          or diag "Looks like this failed";

     my @pub_title_list = $sample3->get_publication_list('title');
     my $expected_pub_title_list = 'testingtitle1,testingtitle2,testingtitle3';
     my $obtained_pub_title_list = join(',', sort @pub_title_list);
    
     is($obtained_pub_title_list, $expected_pub_title_list, 'TESTING GET_PUBLICATION_LIST TITLE, checking pub_title list')
          or diag "Looks like this failed";


     ## Only the third pub has associated a dbxref_id (the rest will be undef) (TEST 70)
     my @pub_accession_list = $sample3->get_publication_list('accession');
     my $expected_pub_accession_list = 'TESTDBACC01';
     my $obtained_pub_accession_list = $pub_accession_list[2];   
    
     is($obtained_pub_accession_list, $expected_pub_accession_list, 'TESTING GET_PUBLICATION_LIST ACCESSION, checking pub_accession list')
 	or diag "Looks like this failed";


     ## Store functions (TEST 71)

     $sample3->store_pub_associations($metadbdata);
     
     my $sample4 = CXGN::Biosource::Sample->new($schema, $sample3->get_sample_id() );
     
     my @pub_id_list2 = $sample4->get_publication_list();
     my $expected_pub_id_list2 = join(',', sort {$a <=> $b} @pub_list);
     my $obtained_pub_id_list2 = join(',', sort {$a <=> $b} @pub_id_list2);
    
     is($obtained_pub_id_list2, $expected_pub_id_list2, 'TESTING STORE PUB ASSOCIATIONS, checking pub_id list')
	 or diag "Looks like this failed";
    
     ## Testing die for store function (TEST 72 AND 73)
    
     throws_ok { $sample4->store_pub_associations() } qr/STORE ERROR: None metadbdata/, 
     'TESTING DIE ERROR when none metadbdata object is supplied to store_pub_associations() function';
    
     throws_ok { $sample4->store_pub_associations($schema) } qr/STORE ERROR: Metadbdata supplied/, 
     'TESTING DIE ERROR when argument supplied to store_pub_associations() is not a CXGN::Metadata::Metadbdata object';

     ## Testing obsolete functions (TEST 74 to 77)
     
     my $n = 0;
     foreach my $pub_assoc (@pub_id_list2) {
          $n++;
          is($sample4->is_sample_pub_obsolete($pub_assoc), 0, 
 	    "TESTING GET_SAMPLE_PUB_METADATA AND IS_SAMPLE_PUB_OBSOLETE, checking boolean ($n)")
              or diag "Looks like this failed";
     }

     my %samplepub_md1 = $sample4->get_sample_pub_metadbdata();
     is($samplepub_md1{$pub_id_list[1]}->get_metadata_id, $last_metadata_id+1, "TESTING GET_SAMPLE_PUB_METADATA, checking metadata_id")
	 or diag "Looks like this failed";

     ## TEST 78 TO 81

     $sample4->obsolete_pub_association($metadbdata, 'obsolete test', $pub_id_list[1]);
     is($sample4->is_sample_pub_obsolete($pub_id_list[1]), 1, "TESTING OBSOLETE PUB ASSOCIATIONS, checking boolean") 
          or diag "Looks like this failed";

     my %samplepub_md2 = $sample4->get_sample_pub_metadbdata();
     is($samplepub_md2{$pub_id_list[1]}->get_metadata_id, $last_metadata_id+5, "TESTING OBSOLETE PUB FUNCTION, checking new metadata_id")
	 or diag "Looks like this failed";

     $sample4->obsolete_pub_association($metadbdata, 'obsolete test', $pub_id_list[1], 'REVERT');
     is($sample4->is_sample_pub_obsolete($pub_id_list[1]), 0, "TESTING OBSOLETE PUB ASSOCIATIONS REVERT, checking boolean") 
          or diag "Looks like this failed";

     my %samplepub_md2o = $sample4->get_sample_pub_metadbdata();
     my $samplepub_metadata_id2 = $samplepub_md2o{$pub_id_list[1]}->get_metadata_id();
     is($samplepub_metadata_id2, $last_metadata_id+6, "TESTING OBSOLETE PUB FUNCTION REVERT, checking new metadata_id")
	 or diag "Looks like this failed";

     ## Checking the errors for obsolete_pub_asociation (TEST 82 TO 85)
    
     throws_ok { $sample4->obsolete_pub_association() } qr/OBSOLETE ERROR: None metadbdata/, 
     'TESTING DIE ERROR when none metadbdata object is supplied to obsolete_pub_association() function';

     throws_ok { $sample4->obsolete_pub_association($schema) } qr/OBSOLETE ERROR: Metadbdata/, 
     'TESTING DIE ERROR when argument supplied to obsolete_pub_association() is not a CXGN::Metadata::Metadbdata object';
    
     throws_ok { $sample4->obsolete_pub_association($metadbdata) } qr/OBSOLETE ERROR: None obsolete note/, 
     'TESTING DIE ERROR when none obsolete note is supplied to obsolete_pub_association() function';
    
     throws_ok { $sample4->obsolete_pub_association($metadbdata, 'test note') } qr/OBSOLETE ERROR: None pub_id/, 
     'TESTING DIE ERROR when none pub_id is supplied to obsolete_pub_association() function';

    
     ##########################################
     ## FORTH BLOCK: Sample_Dbxref functions ##
     ##########################################

     ## Testing of the dbxref

     ## Testing the die when the wrong for the row accessions get/set_bssamplepub_rows (TEST 86 to 88)
    
     throws_ok { $sample4->set_bssampledbxref_rows() } qr/FUNCTION PARAMETER ERROR: None bssampledbxref_row/, 
     'TESTING DIE ERROR when none data is supplied to set_bssampledbxref_rows() function';

     throws_ok { $sample4->set_bssampledbxref_rows('this is not an integer') } qr/SET ARGUMENT ERROR:/, 
     'TESTING DIE ERROR when data type supplied to set_bssampledbxref_rows() function is not an array reference';

     throws_ok { $sample4->set_bssampledbxref_rows([$schema, $schema]) } qr/SET ARGUMENT ERROR:/, 
     'TESTING DIE ERROR when the elements of the array reference supplied to set_bssampledbxref_rows() function are not row objects';
    
     ## First insert two new dbxrefs
 
     my $db_id1 = $schema->resultset('General::Db')
                             ->new( 
                                    { 
                                      name        => 'dbxref-dbtesting',
                                      description => 'this is a test for add a tool-pub relation',
                                      urlprefix   => 'http//.',
                                      url         => 'www.testingdb.com'
                                    }
                                  )
                              ->insert()
                              ->discard_changes()
                              ->get_column('db_id');

     my $dbxref_id1_1 = $schema->resultset('General::Dbxref')
                                 ->new( 
                                         { 
                                           db_id       => $db_id1,
                                           accession   => 'TEST_ACCESSION-DBXREF1',
                                           version     => '1',
                                           description => 'this is a test for add a dbxref relation',
                                         }
                                       )
                                  ->insert()
                                  ->discard_changes()
                                  ->get_column('dbxref_id');

     my $dbxref_id1_2 = $schema->resultset('General::Dbxref')
                                 ->new( 
                                         { 
                                           db_id       => $db_id1,
                                           accession   => 'TEST_ACCESSION-DBXREF2',
                                           version     => '1',
                                           description => 'this is a test for add a dbxref relation',
                                         }
                                       )
                                  ->insert()
                                  ->discard_changes()
                                  ->get_column('dbxref_id');

     my @exp_dbxref_id_list = ($dbxref_id1_1, $dbxref_id1_2);
     my @exp_dbxref_acc_list = ('TEST_ACCESSION-DBXREF1', 'TEST_ACCESSION-DBXREF2');
     
     ## Testing die with add function, TEST 89 to 91
     
     throws_ok { $sample4->add_dbxref() } qr/FUNCTION PARAMETER ERROR: None dbxref/, 
     'TESTING DIE ERROR when none data is supplied to add_dbxref() function';

     throws_ok { $sample4->add_dbxref('this is not an integer') } qr/SET ARGUMENT ERROR: Dbxref/, 
     'TESTING DIE ERROR when data supplied to add_dbxref() function is not an integer';

     throws_ok { $sample4->add_dbxref({ accession => 'fake that does not exist' }) } qr/DATABASE ARGUMENT ERROR: Dbxref/, 
     'TESTING DIE ERROR when data supplied to add_dbxref() function does not exists into the database';

     ## Testing add and get functions TEST 92 AND 93

     $sample4->add_dbxref($dbxref_id1_1);
     $sample4->add_dbxref({ accession => 'TEST_ACCESSION-DBXREF2' });

     my @dbxref_id_list = $sample4->get_dbxref_list();
     my $expected_dbxref_id_list = join(',', sort {$a <=> $b} @exp_dbxref_id_list);
     my $obtained_dbxref_id_list = join(',', sort {$a <=> $b} @dbxref_id_list);

     is($obtained_dbxref_id_list, $expected_dbxref_id_list, 'TESTING ADD_DBXREF and GET_DBXREF_LIST, checking dbxref_id list')
          or diag "Looks like this failed";

     my @dbxref_accession_list = $sample4->get_dbxref_list('accession');
     my $expected_dbxref_acc_list = join(',', sort @exp_dbxref_acc_list);
     my $obtained_dbxref_acc_list = join(',', sort @dbxref_accession_list);
    
     is($obtained_dbxref_acc_list, $expected_dbxref_acc_list, 'TESTING GET_DBXREF_LIST ACCESSION, checking dbxref accession list')
          or diag "Looks like this failed";
     
     ## Store functions (TEST 94)

     $sample4->store_dbxref_associations($metadbdata);
     
     my $sample5 = CXGN::Biosource::Sample->new($schema, $sample4->get_sample_id() );
     
     my @dbxref_id_list2 = $sample4->get_dbxref_list();
     my $expected_dbxref_id_list2 = join(',', sort {$a <=> $b} @exp_dbxref_id_list);
     my $obtained_dbxref_id_list2 = join(',', sort {$a <=> $b} @dbxref_id_list2);
    
     is($obtained_dbxref_id_list2, $expected_dbxref_id_list2, 'TESTING STORE DBXREF ASSOCIATIONS, checking dbxref_id list')
	 or diag "Looks like this failed";
    
     ## Testing die for store function (TEST 95 AND 96)
    
     throws_ok { $sample5->store_dbxref_associations() } qr/STORE ERROR: None metadbdata/, 
     'TESTING DIE ERROR when none metadbdata object is supplied to store_dbxref_associations() function';
    
     throws_ok { $sample5->store_dbxref_associations($schema) } qr/STORE ERROR: Metadbdata supplied/, 
     'TESTING DIE ERROR when argument supplied to store_dbxref_associations() is not a CXGN::Metadata::Metadbdata object';

     ## Testing obsolete functions (TEST 97 to 99)
     
     my $m = 0;
     foreach my $dbxref_assoc (@dbxref_id_list2) {
          $m++;
          is($sample5->is_sample_dbxref_obsolete($dbxref_assoc), 0, 
 	    "TESTING GET_SAMPLE_DBXREF_METADATA AND IS_SAMPLE_DBXREF_OBSOLETE, checking boolean ($m)")
              or diag "Looks like this failed";
     }

     my %sampledbxref_md1 = $sample5->get_sample_dbxref_metadbdata();
     is($sampledbxref_md1{$dbxref_id_list[1]}->get_metadata_id, $last_metadata_id+1, "TESTING GET_SAMPLE_DBXREF_METADATA, checking metadata_id")
	 or diag "Looks like this failed";

     ## TEST 100 TO 103

     $sample5->obsolete_dbxref_association($metadbdata, 'obsolete test for dbxref', $dbxref_id_list[1]);
     is($sample5->is_sample_dbxref_obsolete($dbxref_id_list[1]), 1, "TESTING OBSOLETE DBXREF ASSOCIATIONS, checking boolean") 
          or diag "Looks like this failed";

     my %sampledbxref_md2 = $sample5->get_sample_dbxref_metadbdata();
     is($sampledbxref_md2{$dbxref_id_list[1]}->get_metadata_id, $last_metadata_id+7, "TESTING OBSOLETE DBXREF FUNCTION, checking new metadata_id")
	 or diag "Looks like this failed";

     $sample5->obsolete_dbxref_association($metadbdata, 'obsolete test for dbxref', $dbxref_id_list[1], 'REVERT');
     is($sample5->is_sample_dbxref_obsolete($dbxref_id_list[1]), 0, "TESTING OBSOLETE DBXREF ASSOCIATIONS REVERT, checking boolean") 
          or diag "Looks like this failed";

     my %sampledbxref_md2o = $sample5->get_sample_dbxref_metadbdata();
     my $sampledbxref_metadata_id2 = $sampledbxref_md2o{$dbxref_id_list[1]}->get_metadata_id();
     is($sampledbxref_metadata_id2, $last_metadata_id+8, "TESTING OBSOLETE DBXREF FUNCTION REVERT, checking new metadata_id")
	 or diag "Looks like this failed";

     ## Checking the errors for obsolete_pub_asociation (TEST 104 TO 107)
    
     throws_ok { $sample5->obsolete_dbxref_association() } qr/OBSOLETE ERROR: None metadbdata/, 
     'TESTING DIE ERROR when none metadbdata object is supplied to obsolete_dbxref_association() function';

     throws_ok { $sample5->obsolete_dbxref_association($schema) } qr/OBSOLETE ERROR: Metadbdata/, 
     'TESTING DIE ERROR when argument supplied to obsolete_dbxref_association() is not a CXGN::Metadata::Metadbdata object';
    
     throws_ok { $sample5->obsolete_dbxref_association($metadbdata) } qr/OBSOLETE ERROR: None obsolete note/, 
     'TESTING DIE ERROR when none obsolete note is supplied to obsolete_dbxref_association() function';
    
     throws_ok { $sample5->obsolete_dbxref_association($metadbdata, 'test note') } qr/OBSOLETE ERROR: None dbxref_id/, 
     'TESTING DIE ERROR when none dbxref_id is supplied to obsolete_dbxref_association() function';


     ##########################################
     ## FIFTH BLOCK: Sample_Cvterm functions ##
     ##########################################

     ## Testing of the cvterm associations

     ## Testing the die when the wrong for the row accessions get/set_bssamplepub_rows (TEST 108 to 110)
    
     throws_ok { $sample5->set_bssamplecvterm_rows() } qr/FUNCTION PARAMETER ERROR: None bssamplecvterm_row/, 
     'TESTING DIE ERROR when none data is supplied to set_bssamplecvterm_rows() function';

     throws_ok { $sample5->set_bssamplecvterm_rows('this is not an integer') } qr/SET ARGUMENT ERROR:/, 
     'TESTING DIE ERROR when data type supplied to set_bssamplecvterm_rows() function is not an array reference';

     throws_ok { $sample5->set_bssamplecvterm_rows([$schema, $schema]) } qr/SET ARGUMENT ERROR:/, 
     'TESTING DIE ERROR when the elements of the array reference supplied to set_bssamplecvterm_rows() function are not row objects';
    
     ## First insert two new dbxrefs
 
     my $db_id2 = $schema->resultset('General::Db')
                             ->new( 
                                    { 
                                      name        => 'cvterm-dbtesting',
                                      description => 'this is a test for add a tool-pub relation',
                                      urlprefix   => 'http//.',
                                      url         => 'www.testingdb.com'
                                    }
                                  )
                              ->insert()
                              ->discard_changes()
                              ->get_column('db_id');

     my $dbxref_id2_1 = $schema->resultset('General::Dbxref')
                                 ->new( 
                                         { 
                                           db_id       => $db_id2,
                                           accession   => 'TEST_ACCESSION-CVTERM1',
                                           version     => '1',
                                           description => 'this is a test for add a cvterm relation',
                                         }
                                       )
                                  ->insert()
                                  ->discard_changes()
                                  ->get_column('dbxref_id');

     my $dbxref_id2_2 = $schema->resultset('General::Dbxref')
                                 ->new( 
                                         { 
                                           db_id       => $db_id1,
                                           accession   => 'TEST_ACCESSION-CVTERM2',
                                           version     => '1',
                                           description => 'this is a test for add a cvterm relation',
                                         }
                                       )
                                  ->insert()
                                  ->discard_changes()
                                  ->get_column('dbxref_id');

     my $cv_id1 = $schema->resultset('Cv::Cv')
                          ->new( 
                                 { 
				   name       => 'testingcv1', 
				   definition => 'this is a test for add a cvterm relation',
                                 }
                               )
                          ->insert()
                          ->discard_changes()
                          ->get_column('cv_id');

      my $cvterm_id1_1 = $schema->resultset('Cv::Cvterm')
                                ->new( 
                                    { 
                                       cv_id      => $cv_id1,
                                       name       => 'testing-cvterm1',
                                       definition => 'this is a test for add cvterm relation',
                                       dbxref_id  => $dbxref_id2_1,
                                    }
                                  )
                             ->insert()
                             ->discard_changes()
                             ->get_column('cvterm_id');

     my $cvterm_id1_2 = $schema->resultset('Cv::Cvterm')
	                       ->new( 
                                      { 
                                        cv_id      => $cv_id1,
                                        name       => 'testing-cvterm2',
                                        definition => 'this is a test for add cvterm relation',
                                        dbxref_id  => $dbxref_id2_2,
                                      }
                                    )
                               ->insert()
                               ->discard_changes()
                               ->get_column('cvterm_id');

     my @exp_cvterm_id_list = ($cvterm_id1_1, $cvterm_id1_2);
     my @exp_cvterm_name_list = ('testing-cvterm1', 'testing-cvterm2');
     
     ## Testing die with add function, TEST 111 to 113
     
     throws_ok { $sample5->add_cvterm() } qr/FUNCTION PARAMETER ERROR: None cvterm/, 
     'TESTING DIE ERROR when none data is supplied to add_cvterm() function';

     throws_ok { $sample5->add_cvterm('this is not an integer') } qr/SET ARGUMENT ERROR: Cvterm/, 
     'TESTING DIE ERROR when data supplied to add_cvterm() function is not an integer';

     throws_ok { $sample5->add_cvterm({ accession => 'fake that does not exist' }) } qr/DATABASE ARGUMENT ERROR: Cvterm/, 
     'TESTING DIE ERROR when data supplied to add_cvterm() function does not exists into the database';

     ## Testing add and get functions TEST 114 AND 115

     $sample5->add_cvterm($cvterm_id1_1);
     $sample5->add_cvterm({ name => 'testing-cvterm2' });

     my @cvterm_id_list = $sample5->get_cvterm_list();
     my $expected_cvterm_id_list = join(',', sort {$a <=> $b} @exp_cvterm_id_list);
     my $obtained_cvterm_id_list = join(',', sort {$a <=> $b} @cvterm_id_list);

     is($obtained_cvterm_id_list, $expected_cvterm_id_list, 'TESTING ADD_CVTERM and GET_CVTERM_LIST, checking cvterm_id list')
          or diag "Looks like this failed";

     my @cvterm_name_list = $sample5->get_cvterm_list('name');
     my $expected_cvterm_name_list = join(',', sort @exp_cvterm_name_list);
     my $obtained_cvterm_name_list = join(',', sort @cvterm_name_list);
    
     is($obtained_cvterm_name_list, $expected_cvterm_name_list, 'TESTING GET_CVTERM_LIST ACCESSION, checking cvterm accession list')
          or diag "Looks like this failed";
     
     ## Store functions (TEST 116)

     $sample5->store_cvterm_associations($metadbdata);
     
     my $sample6 = CXGN::Biosource::Sample->new($schema, $sample5->get_sample_id() );
     
     my @cvterm_id_list2 = $sample6->get_cvterm_list();
     my $expected_cvterm_id_list2 = join(',', sort {$a <=> $b} @exp_cvterm_id_list);
     my $obtained_cvterm_id_list2 = join(',', sort {$a <=> $b} @cvterm_id_list2);
    
     is($obtained_cvterm_id_list2, $expected_cvterm_id_list2, 'TESTING STORE CVTERM ASSOCIATIONS, checking cvterm_id list')
	 or diag "Looks like this failed";
    
     ## Testing die for store function (TEST 117 AND 118)
    
     throws_ok { $sample6->store_cvterm_associations() } qr/STORE ERROR: None metadbdata/, 
     'TESTING DIE ERROR when none metadbdata object is supplied to store_cvterm_associations() function';
    
     throws_ok { $sample6->store_cvterm_associations($schema) } qr/STORE ERROR: Metadbdata supplied/, 
     'TESTING DIE ERROR when argument supplied to store_cvterm_associations() is not a CXGN::Metadata::Metadbdata object';

     ## Testing obsolete functions (TEST 119 to 121)
     
     my $o = 0;
     foreach my $cvterm_assoc (@cvterm_id_list2) {
          $o++;
          is($sample6->is_sample_cvterm_obsolete($cvterm_assoc), 0, 
 	    "TESTING GET_SAMPLE_CVTERM_METADATA AND IS_SAMPLE_CVTERM_OBSOLETE, checking boolean ($o)")
              or diag "Looks like this failed";
     }

     my %samplecvterm_md1 = $sample6->get_sample_cvterm_metadbdata();
     is($samplecvterm_md1{$cvterm_id_list[1]}->get_metadata_id, $last_metadata_id+1, "TESTING GET_SAMPLE_CVTERM_METADATA, checking metadata_id")
	 or diag "Looks like this failed";

     ## TEST 122 TO 125

     $sample6->obsolete_cvterm_association($metadbdata, 'obsolete test for cvterm', $cvterm_id_list2[1]);
     is($sample6->is_sample_cvterm_obsolete($cvterm_id_list2[1]), 1, "TESTING OBSOLETE CVTERM ASSOCIATIONS, checking boolean") 
          or diag "Looks like this failed";

     my %samplecvterm_md2 = $sample6->get_sample_cvterm_metadbdata();
     is($samplecvterm_md2{$cvterm_id_list2[1]}->get_metadata_id(), $last_metadata_id+9, "TESTING OBSOLETE CVTERM FUNCTION, checking new metadata_id")
	 or diag "Looks like this failed";

     $sample6->obsolete_cvterm_association($metadbdata, 'obsolete test for cvterm', $cvterm_id_list2[1], 'REVERT');
     is($sample6->is_sample_cvterm_obsolete($cvterm_id_list2[1]), 0, "TESTING OBSOLETE CVTERM ASSOCIATIONS REVERT, checking boolean") 
          or diag "Looks like this failed";

     my %samplecvterm_md2o = $sample6->get_sample_cvterm_metadbdata();
     my $samplecvterm_metadata_id2 = $samplecvterm_md2o{$cvterm_id_list2[1]}->get_metadata_id();
     is($samplecvterm_metadata_id2, $last_metadata_id+10, "TESTING OBSOLETE CVTERM FUNCTION REVERT, checking new metadata_id")
	 or diag "Looks like this failed";

     ## Checking the errors for obsolete_pub_asociation (TEST 126 TO 129)
    
     throws_ok { $sample6->obsolete_cvterm_association() } qr/OBSOLETE ERROR: None metadbdata/, 
     'TESTING DIE ERROR when none metadbdata object is supplied to obsolete_cvterm_association() function';

     throws_ok { $sample6->obsolete_cvterm_association($schema) } qr/OBSOLETE ERROR: Metadbdata/, 
     'TESTING DIE ERROR when argument supplied to obsolete_cvterm_association() is not a CXGN::Metadata::Metadbdata object';
    
     throws_ok { $sample6->obsolete_cvterm_association($metadbdata) } qr/OBSOLETE ERROR: None obsolete note/, 
     'TESTING DIE ERROR when none obsolete note is supplied to obsolete_cvterm_association() function';
    
     throws_ok { $sample6->obsolete_cvterm_association($metadbdata, 'test note') } qr/OBSOLETE ERROR: None cvterm_id/, 
     'TESTING DIE ERROR when none cvterm_id is supplied to obsolete_cvterm_association() function';

     ###########################################
     ## SIXTH BLOCK: Associated File Function ##
     ###########################################

     ## Testing the functions to associate a file to a sample

     ## Testing the die when the wrong for the row accessions get/set_bssamplefile_rows (TEST 130 to 132)
    
     throws_ok { $sample6->set_bssamplefile_rows() } qr/FUNCTION PARAMETER ERROR: None bssamplefile_row/, 
     'TESTING DIE ERROR when none data is supplied to set_bssamplefile_rows() function';

     throws_ok { $sample6->set_bssamplefile_rows('this is not an integer') } qr/SET ARGUMENT ERROR:/, 
     'TESTING DIE ERROR when data type supplied to set_bssamplefile_rows() function is not an array reference';

     throws_ok { $sample6->set_bssamplefile_rows([$schema, $schema]) } qr/SET ARGUMENT ERROR:/, 
     'TESTING DIE ERROR when the elements of the array reference supplied to set_bssamplefile_rows() function are not row objects';

     ## It will add three different files into the metadata.md_files tables before continue testing

     my %fileids = ();
     my @file_names = ('test1.txt', 'test2.txt', 'test3.txt');
     
     foreach my $filename (@file_names) {

	 my $file_row = $schema->resultset('MdFiles')->new( 
	                                                    { 
                                                              basename    => $filename, 
                                                              dirname     => '/dir/test/', 
                                                              filetype    => 'text', 
                                                              metadata_id => $curr_metadata_id
                                                            }
	                                                  );
	 my $file_id = $file_row->insert()
	                        ->discard_changes()
			        ->get_column('file_id');
	
	 $fileids{$filename} = $file_id;
     }
   
     ## Testing die with add function, TEST 133 to 135
     
     throws_ok { $sample6->add_file() } qr/FUNCTION PARAMETER ERROR: None file/, 
     'TESTING DIE ERROR when none data is supplied to add_file() function';

     throws_ok { $sample6->add_file('this is not an integer') } qr/SET ARGUMENT ERROR: File/, 
     'TESTING DIE ERROR when data supplied to add_file() function is not an integer or a hash';

     throws_ok { $sample6->add_file({ basename => 'fake that does not exist' }) } qr/DATABASE ARGUMENT ERROR: File/, 
     'TESTING DIE ERROR when data supplied to add does not exists into the database';

     ## Testing add and get functions TEST 136 AND 137

     $sample6->add_file($fileids{'test1.txt'});
     $sample6->add_file($fileids{'test2.txt'});
     $sample6->add_file({ basename => 'test3.txt', dirname => '/dir/test/' });
     
     my @file_id_list = $sample6->get_file_list();
     my $expected_file_id_list = join(',', sort {$a <=> $b} values %fileids);
     my $obtained_file_id_list = join(',', sort {$a <=> $b} @file_id_list);

     is($obtained_file_id_list, $expected_file_id_list, 'TESTING ADD_FILE and GET_FILE_LIST, checking file_id list')
          or diag "Looks like this failed";

     my @file_name_list = $sample6->get_file_list('basename');
     my $expected_file_name_list = join(',', sort @file_names);
     my $obtained_file_name_list = join(',', sort @file_name_list);
    
     is($obtained_file_name_list, $expected_file_name_list, 'TESTING GET_FILE_LIST ACCESSION, checking file accession list')
          or diag "Looks like this failed";
     
     ## Store functions (TEST 138)

     $sample6->store_file_associations($metadbdata);
     
     my $sample7 = CXGN::Biosource::Sample->new($schema, $sample6->get_sample_id() );
     
     my @file_id_list2 = $sample6->get_file_list();
     my $expected_file_id_list2 = join(',', sort {$a <=> $b} values %fileids);
     my $obtained_file_id_list2 = join(',', sort {$a <=> $b} @file_id_list2);
    
     is($obtained_file_id_list2, $expected_file_id_list2, 'TESTING STORE FILE ASSOCIATIONS, checking file_id list')
	 or diag "Looks like this failed";
    
     ## Testing die for store function (TEST 139 AND 140)
    
     throws_ok { $sample7->store_file_associations() } qr/STORE ERROR: None metadbdata/, 
     'TESTING DIE ERROR when none metadbdata object is supplied to store_file_associations() function';
    
     throws_ok { $sample7->store_file_associations($schema) } qr/STORE ERROR: Metadbdata supplied/, 
     'TESTING DIE ERROR when argument supplied to store_file_associations() is not a CXGN::Metadata::Metadbdata object';

     ## Testing obsolete functions (TEST 141 to 144)
     
     my $p = 0;
     foreach my $file_assoc (@file_id_list2) {
          $p++;
          is($sample7->is_sample_file_obsolete($file_assoc), 0, 
 	    "TESTING GET_SAMPLE_FILE_METADATA AND IS_SAMPLE_FILE_OBSOLETE, checking boolean ($p)")
              or diag "Looks like this failed";
     }

     my %samplefile_md1 = $sample6->get_sample_file_metadbdata();
     is($samplefile_md1{$file_id_list[1]}->get_metadata_id, $last_metadata_id+1, "TESTING GET_SAMPLE_FILE_METADATA, checking metadata_id")
	 or diag "Looks like this failed";

     ## TEST 145 TO 148

     $sample7->obsolete_file_association($metadbdata, 'obsolete test for file', $file_id_list2[1]);
     is($sample7->is_sample_file_obsolete($file_id_list2[1]), 1, "TESTING OBSOLETE FILE ASSOCIATIONS, checking boolean") 
          or diag "Looks like this failed";

     my %samplefile_md2 = $sample7->get_sample_file_metadbdata();
     is($samplefile_md2{$file_id_list2[1]}->get_metadata_id(), $last_metadata_id+11, "TESTING OBSOLETE FILE FUNCTION, checking new metadata_id")
	 or diag "Looks like this failed";

     $sample7->obsolete_file_association($metadbdata, 'obsolete test for file', $file_id_list2[1], 'REVERT');
     is($sample7->is_sample_file_obsolete($file_id_list2[1]), 0, "TESTING OBSOLETE FILE ASSOCIATIONS REVERT, checking boolean") 
          or diag "Looks like this failed";

     my %samplefile_md2o = $sample7->get_sample_file_metadbdata();
     my $samplefile_metadata_id2 = $samplefile_md2o{$file_id_list2[1]}->get_metadata_id();
     is($samplefile_metadata_id2, $last_metadata_id+12, "TESTING OBSOLETE FILE FUNCTION REVERT, checking new metadata_id")
	 or diag "Looks like this failed";

     ## Checking the errors for obsolete_pub_asociation (TEST 149 TO 152)
    
     throws_ok { $sample7->obsolete_file_association() } qr/OBSOLETE ERROR: None metadbdata/, 
     'TESTING DIE ERROR when none metadbdata object is supplied to obsolete_file_association() function';

     throws_ok { $sample7->obsolete_file_association($schema) } qr/OBSOLETE ERROR: Metadbdata/, 
     'TESTING DIE ERROR when argument supplied to obsolete_file_association() is not a CXGN::Metadata::Metadbdata object';
    
     throws_ok { $sample7->obsolete_file_association($metadbdata) } qr/OBSOLETE ERROR: None obsolete note/, 
     'TESTING DIE ERROR when none obsolete note is supplied to obsolete_file_association() function';
    
     throws_ok { $sample7->obsolete_file_association($metadbdata, 'test note') } qr/OBSOLETE ERROR: None file_id/, 
     'TESTING DIE ERROR when none file_id is supplied to obsolete_file_association() function';
	
     ########################################################
     ## SEVENTH BLOCK: Associate relationship with samples ##
     ########################################################

     ## Testing the functions to associate a relationship between samples

     ## Testing the die when the wrong for the row accessions get/set_bssamplepchildrenrelationship 
     ## and bssampleparentsrelationship_rows (TEST 153 to 158)
    
     throws_ok { $sample7->set_bssamplechildrenrelationship_rows() } qr/FUNCTION PARAMETER ERROR: None bssamplerelationship_row/, 
     'TESTING DIE ERROR when none data is supplied to set_bssamplechildrenrelationship_rows() function';

     throws_ok { $sample7->set_bssamplechildrenrelationship_rows('this is not an integer') } qr/SET ARGUMENT ERROR:/, 
     'TESTING DIE ERROR when data type supplied to set_bssamplechildrenrelationship_rows() function is not an array reference';

     throws_ok { $sample7->set_bssamplechildrenrelationship_rows([$schema, $schema]) } qr/SET ARGUMENT ERROR:/, 
     'TESTING DIE ERROR when the elements of the array reference supplied to set_bssamplechildrenrelationship_rows() function are not row objects';

     throws_ok { $sample7->set_bssampleparentsrelationship_rows() } qr/FUNCTION PARAMETER ERROR: None bssamplerelationship_row/, 
     'TESTING DIE ERROR when none data is supplied to set_bssampleparentsrelationship_rows() function';

     throws_ok { $sample7->set_bssampleparentsrelationship_rows('this is not an integer') } qr/SET ARGUMENT ERROR:/, 
     'TESTING DIE ERROR when data type supplied to set_bssampleparentsrelationship_rows() function is not an array reference';

     throws_ok { $sample7->set_bssampleparentsrelationship_rows([$schema, $schema]) } qr/SET ARGUMENT ERROR:/, 
     'TESTING DIE ERROR when the elements of the array reference supplied to set_bssampleparentsrelationship_rows() function are not row objects';

     ## It will create three different samples to relate between them. 
     ## Sample_reltest-1 will be parent of Sample_reltest-2 and Sample_reltest-3

     my %new_samples = ( 'Sample_reltest-1' => $new_type_id0, 
			 'Sample_reltest-2' => $new_type_id1, 
			 'Sample_reltest-3' => $new_type_id1 );
     my %samples_rel = ();

     foreach my $new_sample (keys %new_samples) {
	 my $sample_r = CXGN::Biosource::Sample->new($schema);
	 $sample_r->set_sample_name($new_sample);
	 $sample_r->set_type_id($new_samples{$new_sample});
	 $sample_r->set_description('This is a description test');
	 $sample_r->set_organism_by_species('Genus species');

	 $sample_r->store_sample($metadbdata);
	 $samples_rel{$new_sample} = $sample_r;
     }

     ## Check die for relationship functions, TEST 159 to 178

     throws_ok { $sample7->add_child_relationship() } qr/FUNCTION PARAMETER ERROR: None hash/, 
     'TESTING DIE ERROR when none data is supplied to add_child_relationship() function';

     throws_ok { $sample7->add_child_relationship('this is not an hash ref') } qr/SET ARGUMENT ERROR: The argument/, 
     'TESTING DIE ERROR when data supplied to add_child_relationship() function is not an hash';

     throws_ok { $sample7->add_child_relationship({ test => 'non object_id' }) } qr/DATABASE ARGUMENT ERROR: hash ref/, 
     'TESTING DIE ERROR when data supplied to add_child_relationship does not contain the key=object_id';

     throws_ok { $sample7->add_child_relationship({ object_id => 'non object_id' }) } qr/DATABASE ARGUMENT ERROR: hash ref/, 
     'TESTING DIE ERROR when hash supplied to add_child_relationship have not an integer associated with the key=obbject_id';

     throws_ok { $sample7->add_child_relationship({ object_id => $last_sample_id+100 }) } qr/DATABASE ARGUMENT ERROR: object/, 
     'TESTING DIE ERROR when object_id supplied to the function add_child_relationship() does not exists into the database';

     throws_ok { $sample7->add_child_relationship({ object_id => $sample7->get_sample_id(), test => 'non object_id' }) } qr/DATABASE ARGUMENT ERROR: hash ref/, 
     'TESTING DIE ERROR when data supplied to add_child_relationship does not contain the key=type_id';

     throws_ok { $sample7->add_child_relationship({ object_id => $sample7->get_sample_id(), type_id => 'non type_id' }) } qr/DATABASE ARGUMENT ERROR: hash ref/, 
     'TESTING DIE ERROR when hash supplied to add_child_relationship have not an integer associated with the key=type_id';

     throws_ok { $sample7->add_child_relationship({ object_id => $sample7->get_sample_id(), type_id => $last_cvterm_id+100 }) } qr/DATABASE ARGUMENT ERROR: type_id/, 
     'TESTING DIE ERROR when type_id (cvterm) supplied to the function add_child_relationship() does not exists into the database';

     throws_ok { $sample7->add_child_relationship({ object_id => $sample7->get_sample_id(), type_id => $new_type_id0 }) } qr/DATABASE ARGUMENT ERROR: hash/, 
     'TESTING DIE ERROR when data supplied to add_child_relationship does not contain the key=rank';

     throws_ok { $sample7->add_child_relationship({ object_id => $sample7->get_sample_id(), type_id => $new_type_id0, rank => 'noint' }) } qr/DATABASE ARGUMENT ERROR: hash/, 
     'TESTING DIE ERROR when rank supplied to the function add_child_relationship() is not an integer';


     throws_ok { $sample7->add_parent_relationship() } qr/FUNCTION PARAMETER ERROR: None hash/, 
     'TESTING DIE ERROR when none data is supplied to add_parents_relationship() function';

     throws_ok { $sample7->add_parent_relationship('this is not an hash ref') } qr/SET ARGUMENT ERROR: The argument/, 
     'TESTING DIE ERROR when data supplied to add_parents_relationship() function is not an hash';

     throws_ok { $sample7->add_parent_relationship({ test => 'non subject_id' }) } qr/DATABASE ARGUMENT ERROR: hash ref/, 
     'TESTING DIE ERROR when data supplied to add_parents_relationship does not contain the key=subject_id';

     throws_ok { $sample7->add_parent_relationship({ subject_id => 'non subject_id' }) } qr/DATABASE ARGUMENT ERROR: hash ref/, 
     'TESTING DIE ERROR when hash supplied to add_parents_relationship have not an integer associated with the key=subject_id';

     throws_ok { $sample7->add_parent_relationship({ subject_id => $last_sample_id+100 }) } qr/DATABASE ARGUMENT ERROR: subject/, 
     'TESTING DIE ERROR when subject_sample_id supplied to the function add_parents_relationship() does not exists into the database';

     throws_ok { $sample7->add_parent_relationship({ subject_id => $sample7->get_sample_id(), test => 'non type_id' }) } qr/DATABASE ARGUMENT ERROR: hash ref/, 
     'TESTING DIE ERROR when data supplied to add_parents_relationship does not contain the key=type_id';

     throws_ok { $sample7->add_parent_relationship({ subject_id => $sample7->get_sample_id(), type_id => 'non type_id' }) } qr/DATABASE ARGUMENT ERROR: hash ref/, 
     'TESTING DIE ERROR when hash supplied to add_parents_relationship have not an integer associated with the key=type_id';

     throws_ok { $sample7->add_parent_relationship({ subject_id => $sample7->get_sample_id(), type_id => $last_cvterm_id+100 }) } qr/DATABASE ARGUMENT ERROR: type_id/, 
     'TESTING DIE ERROR when type_id (cvterm) supplied to the function add_parents_relationship() does not exists into the database';

     throws_ok { $sample7->add_parent_relationship({ subject_id => $sample7->get_sample_id(), type_id => $new_type_id0 }) } qr/DATABASE ARGUMENT ERROR: hash/, 
     'TESTING DIE ERROR when data supplied to add_parents_relationship does not contain the key=rank';

     throws_ok { $sample7->add_parent_relationship({ subject_id => $sample7->get_sample_id(), type_id => $new_type_id0, rank => 'noint' }) } qr/DATABASE ARGUMENT ERROR: hash/, 
     'TESTING DIE ERROR when rank supplied to the function add_parents_relationship() is not an integer';

     ## Now we will test two different ways to add the same data
     ## 1) Adding the relation Sample_reltest-1 as base and Sample-reltest-2 as children
     ## 2) Adding the relation Sample_reltest-3 as base and Sample-reltest-1 as parent
     
     $samples_rel{'Sample_reltest-1'}->add_child_relationship(
	                                                          { 
								     object_id => $samples_rel{'Sample_reltest-2'}->get_sample_id(), 
								     type_id   => $new_type_id0,
								     value     => 'relationship test',
								     rank      => 1
								  }
	                                                        );

     $samples_rel{'Sample_reltest-3'}->add_parent_relationship(
	                                                          { 
								     subject_id => $samples_rel{'Sample_reltest-1'}->get_sample_id(), 
								     type_id    => $new_type_id0,
								     value      => 'relationship test',
								     rank       => 1
								  }
	                                                        );

     ## TEST 179 and 180

     ## Now it will get_children_relationship and get_parents_relations and check the results
     ## The data are not stored into the database, so the relation for independent samples 
     ## will not be added (Sample_reltest-1 will have as child Sample_reltest-2 and Sample_reltest-3
     ## will have as parent Sample_reltest-1, but the Sample_reltest-1 object will not know about that
     ## relation if it is not stored into the database and redumped.

     my @children_samples = $samples_rel{'Sample_reltest-1'}->get_children_relationship();
     
     is( $children_samples[0]->get_sample_id(), 
	 $samples_rel{'Sample_reltest-2'}->get_sample_id(), 
	 'TESTING ADD_CHILD_RELATIONSHIP and GET_CHILDREN_RELATIONSHIP, checking sample_id list (children)')
          or diag "Looks like this failed";

     my @parents_samples = $samples_rel{'Sample_reltest-3'}->get_parents_relationship();
    
     is( $parents_samples[0]->get_sample_id(), 
	 $samples_rel{'Sample_reltest-1'}->get_sample_id(), 
	 'TESTING ADD_PARENT_RELATIONSHIP and GET_PARENTS_RELATIONSHIP, checking sample_id list (parents)')
          or diag "Looks like this failed";

     ## Store functions, TEST 181 to 189

     $samples_rel{'Sample_reltest-1'}->store_children_associations($metadbdata);
     $samples_rel{'Sample_reltest-3'}->store_parents_associations($metadbdata);

     my $sample8 = CXGN::Biosource::Sample->new($schema, $samples_rel{'Sample_reltest-1'}->get_sample_id() );
     my $sample9 = CXGN::Biosource::Sample->new($schema, $samples_rel{'Sample_reltest-2'}->get_sample_id() );
     my $sample10 = CXGN::Biosource::Sample->new($schema, $samples_rel{'Sample_reltest-3'}->get_sample_id() );

     ## Now it will check the sample relations using get_relationship, it will return all the relations
     ## the relation between Sample_reltest-1 and Sample_reltest-3 was inserted using Sample_reltest-3 object
     ## but now will be recognized but all the searches of Sample_reltest-1 object

     ## Also it will check brothers (It can not be tested if the data is not stored into the database)

     my %relations_1 = $sample8->get_relationship();
     my %relations_2 = $sample9->get_relationship();
     my %relations_3 = $sample10->get_relationship();
     
     my @check_data = ( 
	                { stored_children   => $relations_1{'children'},
                          expected_children => [$samples_rel{'Sample_reltest-2'}->get_sample_id(), $samples_rel{'Sample_reltest-3'}->get_sample_id()],
			  stored_parents    => $relations_1{'parents'},
			  expected_parents  => [],
			  stored_brothers   => $relations_1{'brothers'},
			  expected_brothers => [],
			      
                        },
	                { stored_children   => $relations_2{'children'},
                          expected_children => [],
			  stored_parents    => $relations_2{'parents'},
			  expected_parents  => [$samples_rel{'Sample_reltest-1'}->get_sample_id()],
			  stored_brothers   => $relations_2{'brothers'},
			  expected_brothers => [$samples_rel{'Sample_reltest-3'}->get_sample_id()],
                        },
	                { stored_children   => $relations_3{'children'},
                          expected_children => [],
			  stored_parents    => $relations_3{'parents'},
			  expected_parents  => [$samples_rel{'Sample_reltest-1'}->get_sample_id()],
			  stored_brothers   => $relations_3{'brothers'},
			  expected_brothers => [$samples_rel{'Sample_reltest-2'}->get_sample_id()],
                        },
	              );

     my $z = 0;
     foreach my $check (@check_data) {

	 $z++;
	 my @obt_stored_children = ();
	 my @stored_children = @{$check->{'stored_children'}};
	 foreach my $stored_child (@stored_children) {
	     push @obt_stored_children, $stored_child->get_sample_id();
	 }

	 my @expected_children = @{$check->{'expected_children'}};
	 my $obtained_children = join(',', sort {$a <=> $b} @obt_stored_children);
	 my $expected_children = join(',', sort {$a <=> $b} @expected_children);

	 is( $obtained_children, $expected_children, "TESTING STORE_CHILDREN/PARENTS/BROTHERS_RELATIONSHIP and GET_RELATIONSHIP, checking sample_id list $z (children)")
	     or diag "Looks like this failed";

	 my @obt_stored_parents = ();
	 my @stored_parents = @{$check->{'stored_parents'}};
	 foreach my $stored_parent (@stored_parents) {
	     push @obt_stored_parents, $stored_parent->get_sample_id();
	 }

	 my @expected_parents = @{$check->{'expected_parents'}};
	 my $obtained_parents = join(',', sort {$a <=> $b} @obt_stored_parents);
	 my $expected_parents = join(',', sort {$a <=> $b} @expected_parents);

	 is( $obtained_parents, $expected_parents, "TESTING STORE_CHILDREN/PARENTS/BROTHERS_RELATIONSHIP and GET_RELATIONSHIP, checking sample_id list $z (parents)")
	     or diag "Looks like this failed";
	 
	 my @obt_stored_brothers = ();
	 my @stored_brothers = @{$check->{'stored_brothers'}};
	 foreach my $stored_brother (@stored_brothers) {
	     push @obt_stored_brothers, $stored_brother->get_sample_id();
	 }

	 my @expected_brothers = @{$check->{'expected_brothers'}};
	 my $obtained_brothers = join(',', sort {$a <=> $b} @obt_stored_brothers);
	 my $expected_brothers = join(',', sort {$a <=> $b} @expected_brothers);

	 is( $obtained_brothers, $expected_brothers, "TESTING STORE_CHILDREN/PARENTS/BROTHERS_RELATIONSHIP and GET_RELATIONSHIP, checking sample_id list $z (brothers)")
	     or diag "Looks like this failed";

     }
     
     ## Testing die for store function (TEST 190 to 193)
    
     throws_ok { $sample8->store_children_associations() } qr/STORE ERROR: None metadbdata/, 
     'TESTING DIE ERROR when none metadbdata object is supplied to store_children_associations() function';
    
     throws_ok { $sample8->store_children_associations($schema) } qr/STORE ERROR: Metadbdata supplied/, 
     'TESTING DIE ERROR when argument supplied to store_children_associations() is not a CXGN::Metadata::Metadbdata object';

     throws_ok { $sample8->store_parents_associations() } qr/STORE ERROR: None metadbdata/, 
     'TESTING DIE ERROR when none metadbdata object is supplied to store_parents_associations() function';
    
     throws_ok { $sample8->store_parents_associations($schema) } qr/STORE ERROR: Metadbdata supplied/, 
     'TESTING DIE ERROR when argument supplied to store_parents_associations() is not a CXGN::Metadata::Metadbdata object';

     ## Test obsolete functions (TEST 194 to 198)

     is($sample8->is_sample_children_obsolete($samples_rel{'Sample_reltest-2'}->get_sample_id()), 0, 
	"TESTING GET_SAMPLE_CHILDREN_METADATA AND IS_SAMPLE_CHILDREN_OBSOLETE, checking boolean")
	 or diag "Looks like this failed";

     is($sample9->is_sample_parents_obsolete($samples_rel{'Sample_reltest-1'}->get_sample_id()), 0, 
	"TESTING GET_SAMPLE_PARENTS_METADATA AND IS_SAMPLE_PARENTS_OBSOLETE, checking boolean")
	 or diag "Looks like this failed";
     
     my $q = 0;
     my %samplechildren_md1 = $sample8->get_sample_children_metadbdata();
     foreach my $sample_children_id (keys %samplechildren_md1) {	 
	 
	 $q++;
	 my $children_metadata = $samplechildren_md1{$sample_children_id};
	 is($children_metadata->get_metadata_id, $last_metadata_id+1, "TESTING GET_SAMPLE_CHILDREN_METADATA, checking metadata_id (children $q)")
	     or diag "Looks like this failed";
     }

     my $r = 0;
     my %sampleparents_md1 = $sample9->get_sample_parents_metadbdata();
     foreach my $sample_parents_id (keys %sampleparents_md1) {	 
	 
	 $r++;
	 my $parents_metadata = $sampleparents_md1{$sample_parents_id};
	 is($parents_metadata->get_metadata_id, $last_metadata_id+1, "TESTING GET_SAMPLE_PARENTS_METADATA, checking metadata_id (parents $r)")
	     or diag "Looks like this failed";
     }


     ## Test 199 to 206

     $sample8->obsolete_children_association($metadbdata, 'obsolete test for children', $samples_rel{'Sample_reltest-2'}->get_sample_id() );
     is($sample8->is_sample_children_obsolete($samples_rel{'Sample_reltest-2'}->get_sample_id()), 1, "TESTING OBSOLETE CHILDREN ASSOCIATIONS, checking boolean") 
          or diag "Looks like this failed";

     my %samplechildren_md2 = $sample8->get_sample_children_metadbdata();
     is($samplechildren_md2{$samples_rel{'Sample_reltest-2'}->get_sample_id()}->get_metadata_id(), $last_metadata_id+13, "TESTING OBSOLETE CHILDREN FUNCTION, checking new metadata_id")
	 or diag "Looks like this failed";

     $sample8->obsolete_children_association($metadbdata, 'obsolete test for children', $samples_rel{'Sample_reltest-2'}->get_sample_id(), 'REVERT');
     is($sample8->is_sample_children_obsolete($samples_rel{'Sample_reltest-2'}->get_sample_id()), 0, "TESTING OBSOLETE CHILDREN ASSOCIATIONS REVERT, checking boolean") 
          or diag "Looks like this failed";

     my %samplechildren_md2o = $sample8->get_sample_children_metadbdata();
     my $samplechildren_metadata_id2 = $samplechildren_md2o{$samples_rel{'Sample_reltest-2'}->get_sample_id()}->get_metadata_id();
     is($samplechildren_metadata_id2, $last_metadata_id+14, "TESTING OBSOLETE CHILDREN FUNCTION REVERT, checking new metadata_id")
	 or diag "Looks like this failed";


     $sample9->obsolete_parents_association($metadbdata, 'obsolete test for parents', $samples_rel{'Sample_reltest-1'}->get_sample_id() );
     is($sample9->is_sample_parents_obsolete($samples_rel{'Sample_reltest-1'}->get_sample_id()), 1, "TESTING OBSOLETE PARENTS ASSOCIATIONS, checking boolean") 
          or diag "Looks like this failed";

     my %sampleparents_md2 = $sample9->get_sample_parents_metadbdata();
     is($sampleparents_md2{$samples_rel{'Sample_reltest-1'}->get_sample_id()}->get_metadata_id(), $last_metadata_id+15, "TESTING OBSOLETE PARENTS FUNCTION, checking new metadata_id")
	 or diag "Looks like this failed";

     $sample9->obsolete_parents_association($metadbdata, 'obsolete test for parents', $samples_rel{'Sample_reltest-1'}->get_sample_id(), 'REVERT');
     is($sample9->is_sample_parents_obsolete($samples_rel{'Sample_reltest-1'}->get_sample_id()), 0, "TESTING OBSOLETE PARENTS ASSOCIATIONS REVERT, checking boolean") 
          or diag "Looks like this failed";

     my %sampleparents_md2o = $sample9->get_sample_parents_metadbdata();
     my $sampleparents_metadata_id2 = $sampleparents_md2o{$samples_rel{'Sample_reltest-1'}->get_sample_id()}->get_metadata_id();
     is($sampleparents_metadata_id2, $last_metadata_id+16, "TESTING OBSOLETE PARENTS FUNCTION REVERT, checking new metadata_id")
	 or diag "Looks like this failed";


     ## Checking the errors for obsolete_pub_asociation (TEST 207 TO 214)
    
     throws_ok { $sample8->obsolete_children_association() } qr/OBSOLETE ERROR: None metadbdata/, 
     'TESTING DIE ERROR when none metadbdata object is supplied to obsolete_children_association() function';

     throws_ok { $sample8->obsolete_children_association($schema) } qr/OBSOLETE ERROR: Metadbdata/, 
     'TESTING DIE ERROR when argument supplied to obsolete_children_association() is not a CXGN::Metadata::Metadbdata object';
    
     throws_ok { $sample8->obsolete_children_association($metadbdata) } qr/OBSOLETE ERROR: None obsolete note/, 
     'TESTING DIE ERROR when none obsolete note is supplied to obsolete_children_association() function';
    
     throws_ok { $sample8->obsolete_children_association($metadbdata, 'test note') } qr/OBSOLETE ERROR: None object_id/, 
     'TESTING DIE ERROR when none file_id is supplied to obsolete_children_association() function';

     
     throws_ok { $sample9->obsolete_parents_association() } qr/OBSOLETE ERROR: None metadbdata/, 
     'TESTING DIE ERROR when none metadbdata object is supplied to obsolete_parents_association() function';

     throws_ok { $sample9->obsolete_parents_association($schema) } qr/OBSOLETE ERROR: Metadbdata/, 
     'TESTING DIE ERROR when argument supplied to obsolete_parents_association() is not a CXGN::Metadata::Metadbdata object';
    
     throws_ok { $sample9->obsolete_parents_association($metadbdata) } qr/OBSOLETE ERROR: None obsolete note/, 
     'TESTING DIE ERROR when none obsolete note is supplied to obsolete_parents_association() function';
    
     throws_ok { $sample9->obsolete_parents_association($metadbdata, 'test note') } qr/OBSOLETE ERROR: None subject_id/, 
     'TESTING DIE ERROR when none file_id is supplied to obsolete_parents_association() function';

     #################################
     ## EIGHTH BLOCK: Global store  ##
     #################################

     ## Testing die for store function (TEST 215 to 216)
    
     throws_ok { $sample8->store() } qr/STORE ERROR: None metadbdata/, 
     'TESTING DIE ERROR when none metadbdata object is supplied to store() function';
    
     throws_ok { $sample8->store($schema) } qr/STORE ERROR: Metadbdata supplied/, 
     'TESTING DIE ERROR when argument supplied to store() is not a CXGN::Metadata::Metadbdata object';

     ## Now it will create a new sample and store it

     ## Basic sample

     my $g_sample = CXGN::Biosource::Sample->new($schema);
     $g_sample->set_sample_name('global sample');
     $g_sample->set_type_id($new_type_id1);
     $g_sample->set_description('This is a description test');
     $g_sample->set_organism_by_species('Genus species');

     ## Associate pub

     $g_sample->add_publication($new_pub_id2);

     ## Associate dbxref
     
     $g_sample->add_dbxref($dbxref_id1_2);

     ## Associate cvterm
     
     $g_sample->add_cvterm($cvterm_id1_2);

     ## Associate file

     $g_sample->add_file($fileids{'test2.txt'});

     ## Associate child

     $g_sample->add_child_relationship( { object_id => $samples_rel{'Sample_reltest-2'}->get_sample_id(), 
					  type_id   => $new_type_id0,
					  value     => 'relationship test',
					  rank      => 1
					} );
    
     ## Associate parent

     $g_sample->add_parent_relationship( { subject_id => $samples_rel{'Sample_reltest-1'}->get_sample_id(), 
					   type_id    => $new_type_id0,
					   value      => 'relationship test',
					   rank       => 2
					 } );

     $g_sample->store($metadbdata);

     ## Now it will check some of the data stored TEST 217 to 224

     my $gg_sample = CXGN::Biosource::Sample->new($schema, $g_sample->get_sample_id());

     is($gg_sample->get_sample_id(), $last_sample_id+5, "TESTING STORE FUNCTION, checking sample_id")
	 or diag "Looks like this failed";
     is($gg_sample->get_sample_name(), 'global sample', "TESTING STORE FUNCTION, checking sample_name")
	 or diag "Looks like this failed";

     my ($g_pub_name) = $gg_sample->get_publication_list('title');
     is($g_pub_name, 'testingtitle2', "TESTING STORE FUNCTION, checking publication title")
	 or diag "Looks like this failed";
     
     my ($g_dbxref_acc) = $gg_sample->get_dbxref_list('accession');
     is($g_dbxref_acc, 'TEST_ACCESSION-DBXREF2', "TESTING STORE FUNCTION, checking dbxref accession")
	 or diag "Looks like this failed";

     my ($g_cvterm_name) = $gg_sample->get_cvterm_list('name');
     is($g_cvterm_name, 'testing-cvterm2', "TESTING STORE FUNCTION, checking cvterm name")
	 or diag "Looks like this failed"; 

     my ($g_file_name) = $gg_sample->get_file_list('basename');
     is($g_file_name, 'test2.txt', "TESTING STORE FUNCTION, checking file basename")
	 or diag "Looks like this failed";

     my ($g_child_sample) = $gg_sample->get_children_relationship();
     is($g_child_sample->get_sample_name, 'Sample_reltest-2', "TESTING STORE FUNCTION, checking child sample_name")
	 or diag "Looks like this failed";

     my ($g_parent_sample) = $gg_sample->get_parents_relationship();
     is($g_parent_sample->get_sample_name, 'Sample_reltest-1', "TESTING STORE FUNCTION, checking parent sample_name")
	 or diag "Looks like this failed";


     #################################
     ## NINTH BLOCK: Other methods ##
     #################################

     ## It will check the data associated with dbxref stored in the test 89

     ## Before it will store cvterms associated with these dbxrefs

      my $rel_cv_id = $schema->resultset('Cv::Cv')
                          ->new( 
                                 { 
				   name       => 'testingcv_related', 
				   definition => 'this is a test for add a cvterm relation',
                                 }
                               )
                          ->insert()
                          ->discard_changes()
                          ->get_column('cv_id');

      my $rel_cvterm_id1 = $schema->resultset('Cv::Cvterm')
                                ->new( 
                                    { 
                                       cv_id      => $rel_cv_id,
                                       name       => 'testing-cvterm1_related',
                                       definition => 'this is a test for add cvterm relation',
                                       dbxref_id  => $dbxref_id1_1,
                                    }
                                  )
                             ->insert()
                             ->discard_changes()
                             ->get_column('cvterm_id');

     my $rel_cvterm_id2 = $schema->resultset('Cv::Cvterm')
	                       ->new( 
                                      { 
                                        cv_id      => $rel_cv_id,
                                        name       => 'testing-cvterm2_related',
                                        definition => 'this is a test for add cvterm relation',
                                        dbxref_id  => $dbxref_id1_2,
                                      }
                                    )
                               ->insert()
                               ->discard_changes()
                               ->get_column('cvterm_id');

     my @rel_exp_cvterm_id_list = ($rel_cvterm_id1, $rel_cvterm_id2);
     my @rel_exp_cvterm_name_list = ('testing-cvterm1_related', 'testing-cvterm2_related');

     ## Now check the function, TESTs 225 and 226

     my %dbxref_related = $sample7->get_dbxref_related('dbxref-dbtesting');

     my @accessions_dbxref_rel = ();
     my @cvterm_names_rel = ();

     my @dbxref_related_href = values %dbxref_related;
     foreach my $dbxref_href (@dbxref_related_href) {
	 push @accessions_dbxref_rel, $dbxref_href->{'dbxref.accession'};
	 push @cvterm_names_rel, $dbxref_href->{'cvterm.name'};
     }    

     my $pred_accession_list = join(',', sort @exp_dbxref_acc_list);
     my $obt_accession_list = join(',', sort @accessions_dbxref_rel);

     is($pred_accession_list, $obt_accession_list, "TESTING GET_DBXREF_RELATED FUNCTION, checking list of dbxref_accessions")
	 or diag "Looks like this failed";

     my $pred_cvterm_name_list = join(',', sort @rel_exp_cvterm_name_list);
     my $obt_cvterm_name_list = join(',', sort @cvterm_names_rel);

     is($pred_cvterm_name_list, $obt_cvterm_name_list, "TESTING GET_DBXREF_RELATED FUNCTION, checking list of cvterm_names")
	 or diag "Looks like this failed";


};  ## End of the eval function

if ($@) {
    print "\nEVAL ERROR:\n\n$@\n";
}



 ## RESTORING THE ORIGINAL STATE IN THE DATABASE
## To restore the original state in the database, rollback (it is in a transaction) and set the table_sequence values. 

$schema->txn_rollback();

## The transaction change the values in the sequence, so if we want set the original value, before the changes
 ## we have two options:
  ##     1) SELECT setval (<sequence_name>, $last_value_before_change, true); that said, ok your last true value was...
   ##    2) SELECT setval (<sequence_name>, $last_value_before_change+1, false); It is false that your last value was ... so the 
    ##      next time take the value before this.
     ##  
      ##   The option 1 leave the seq information in a original state except if there aren't any value in the seq, that it is
       ##   more as the option 2 

if ($ENV{RESET_DBSEQ}) {
    $schema->set_sqlseq(\%last_ids);
}
