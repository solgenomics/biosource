#!/usr/bin/env perl


=head1 NAME

 0049_update_biosource_v.0.02_TobEA_migration.pl

=head1 SYNOPSIS

  this_script.pl [options]

  Options:

    -D <dbname> (mandatory)
      dbname to load into

    -H <dbhost> (mandatory)
      dbhost to load into

    -p <script_executor_user> (mandatory)
      username to run the script

    -F force to run this script and don't stop it by 
       missing previous db_patches

  Note: If the first time that you run this script, obviously
        you have not any previous dbversion row in the md_dbversion
        table, so you need to force the execution of this script 
        using -F

=head1 DESCRIPTION

 Update the biosource v0.01 to v0.02 for the TobEA data

 The update of the version 0.01 to 0.02 will be done in three steps 
 and three patches:

 1) update_biosource_v.0.02_creation.pl, 
    where it will create the new tables

 2) update_biosource_v.0.02_TobEA_migration.pl, 
    where it will migrate the TobEA data if it exists in the db.

 3) update_biosource_v.0.02_cleaning.pl
    where it will remove the old tables like sample_elements from
    the schema

 This will create an overlaping region between the patches 1 and 3
 where will possible the use of the two versions of the biosource 
 code.

=head1 AUTHOR

Aureliano Bombarely,
ab782@cornell.edu

=head1 COPYRIGHT & LICENSE

Copyright 2009 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


use strict;
use warnings;

use Pod::Usage;
use Getopt::Std;
use CXGN::DB::InsertDBH;
use CXGN::Metadata::Dbversion;   ### Module to interact with the metadata.md_dbversion table


## Declaration of the parameters used to run the script

our ($opt_H, $opt_D, $opt_p, $opt_F, $opt_h);
getopts("H:D:p:Fh");

## If is used -h <help> or none parameters is detailed print pod

if (!$opt_H && !$opt_D && !$opt_p && !$opt_F && !$opt_h) {
    print STDERR "There are n\'t any tags. Print help\n\n";
    pod2usage(1);
} 
elsif ($opt_h) {
    pod2usage(1);
} 


## Declaration of the name of the script and the description

my $patch_name = '0049_update_biosource_v.0.02_TobEA_migration.pl';
my $patch_descr = 'This script update the biosource schema to version 0.02 (part 2 of 3), migration the samples of the TobEA dataset.';

print STDERR "\n+--------------------------------------------------------------------------------------------------+\n";
print STDERR "Executing the patch:\n   $patch_name.\n\nDescription:\n  $patch_descr.\n\nExecuted by:\n  $opt_p.";
print STDERR "\n+--------------------------------------------------------------------------------------------------+\n\n";

## And the requeriments if you want not use all
##
my @previous_requested_patches = (   ## ADD HERE
    '0029_biosource_schema.pl',
    '0032_add_two_biosource_tables.pl',
    '0048_update_biosource_v.0.02_creation.pl',
); 

## Specify the mandatory parameters

if (!$opt_H || !$opt_D) {
    print STDERR "\nMANDATORY PARAMETER ERROR: -D <db_name> or/and -H <db_host> parameters has not been specified for $patch_name.\n";
} 

if (!$opt_p) {
    print STDERR "\nMANDATORY PARAMETER ERROR: -p <script_executor_user> parameter has not been specified for $patch_name.\n";
}

## Create the $schema object for the db_version object
## This should be replace for CXGN::DB::DBICFactory as soon as it can use CXGN::DB::InsertDBH

my $dbh =  CXGN::DB::InsertDBH->new(
                                     { 
					 dbname => $opt_D, 
					 dbhost => $opt_H 
				     }
                                   )->get_actual_dbh();

print STDERR "\nCreating the Metadata Schema object.\n";

my $metadata_schema = CXGN::Metadata::Schema->connect(   
                                                       sub { $dbh },
                                                      { on_connect_do => ['SET search_path TO metadata;'] },
                                                      );

print STDERR "\nChecking if this db_patch was executed before or if have been executed the previous db_patches.\n";

### Now it will check if you have runned this patch or the previous patches

my $dbversion = CXGN::Metadata::Dbversion->new($metadata_schema)
                                         ->complete_checking( { 
					                         patch_name  => $patch_name,
							         patch_descr => $patch_descr, 
							         prepatch_req => \@previous_requested_patches,
							         force => $opt_F 
							      } 
                                                             );


### CREATE AN METADATA OBJECT and a new metadata_id in the database for this data

my $metadata = CXGN::Metadata::Metadbdata->new($metadata_schema, $opt_p);

### Get a new metadata_id (if you are using store function you only need to supply $metadbdata object)

my $metadata_id = $metadata->store()
                           ->get_metadata_id();

### Now you can insert the data using different options:
##
##  1- By sql queryes using $dbh->do(<<EOSQL); and detailing in the tag the queries
##
##  2- Using objects with the store function
##
##  3- Using DBIx::Class first level objects
##

## In this case we will use the SQL tag

print STDERR "\nExecuting the SQL commands.\n";

$dbh->do(<<EOSQL);

-------------------------
-- biosource.bs_sample --
-------------------------

-- Correct the sample_id=95 adding contact;
UPDATE biosource.bs_sample SET contact_id=(SELECT contact_id FROM biosource.bs_sample WHERE sample_id=1) WHERE sample_id=95; 

-- Add the organism_id
UPDATE biosource.bs_sample SET organism_id=(SELECT organism_id FROM public.organism WHERE species='Nicotiana tabacum');

--------------------------------------
-- biosource.bs_sample_relationship --
--------------------------------------

-- There are not any bs_sample_element_relation to migrate to this table.
-- There are one sample and sample_element to migrate to this table with sample_id=101

INSERT INTO biosource.bs_sample (sample_name, description, organism_id, metadata_id) (SELECT sample_element_name, description, organism_id, metadata_id FROM biosource.bs_sample_element WHERE sample_id=101);
UPDATE biosource.bs_sample SET contact_id=(SELECT contact_id FROM biosource.bs_sample WHERE sample_id=1) WHERE sample_id>101;

-- Now it will add the relation between these sample elements and the sample 101

-- First, add dbxref

INSERT INTO public.dbxref (accession, description, db_id) VALUES ('sample_relationship', 'dbxref for a local cvterm used in biosource', (SELECT db_id FROM public.db WHERE name='null')); 
INSERT INTO public.cv (name, definition) VALUES ('sample_relationship', 'term created to define the relation between different samples in the biosource.bs_sample table');
INSERT INTO public.cvterm (name, definition, is_relationshiptype, cv_id, dbxref_id) VALUES ('sequence_dataset_composed_by', 'sample relationship predicate', 1, (SELECT cv_id FROM public.cv WHERE name='sample_relationship'), (SELECT dbxref_id FROM public.dbxref WHERE accession='sample_relationship'));

INSERT INTO biosource.bs_sample_relationship (subject_id) SELECT sample_id FROM biosource.bs_sample WHERE sample_id>101;

UPDATE biosource.bs_sample_relationship SET metadata_id=(SELECT metadata_id FROM biosource.bs_sample WHERE sample_id=1), object_id=101, type_id=(SELECT cvterm_id FROM public.cvterm WHERE name='sequence_dataset_composed_by'), rank=0, value='seuence dataset composition' WHERE subject_id > 101;

------------------------------
-- biosource.bs_sample_file --
------------------------------

--Nothing to migrate

--------------------------------
-- biosource.bs_sample_cvterm --
--------------------------------

-- Nothing to migrate

--------------------------------
-- biosource.bs_sample_dbxref --
--------------------------------

-- Now it will need to move the dbxref for the GO terms associated with each sample_element
-- The relation is: sample_element_id => dbxref_id to sample_id => dbxref_id
-- First we will copy the data into temp table, add the sample_id and copy back to sample_dbxref

INSERT INTO biosource.bs_sample_dbxref (sample_id, dbxref_id, metadata_id) SELECT biosource.bs_sample_element.sample_id, biosource.bs_sample_element_dbxref.dbxref_id, biosource.bs_sample_element_dbxref.metadata_id FROM biosource.bs_sample_element_dbxref JOIN biosource.bs_sample_element USING(sample_element_id) ORDER BY sample_element_id;


EOSQL

## Now it will add this new patch information to the md_version table.  It did the dbversion object before and
## set the patch_name and the patch_description, so it only need to store it.
   

$dbversion->store($metadata);

$dbh->commit;

__END__

