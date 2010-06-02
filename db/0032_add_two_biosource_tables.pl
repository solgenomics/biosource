#!/usr/bin/env perl


=head1 NAME

 0032_add_two_biosource_tables.pl

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

 Create two new tables in the biosource schema:

 + bs_sample_element_file, a table to link files with sample_elements
 + bs_sample_element_relation, a table to detail the relation between 
   different samples, for example:

   sample1_element1 = tomato young root mRNA
   sample1_element2 = tomato old root mRNA
   sample1 = tomato root mRNA
   
   sample2_element1 = tomato young root EST dataset
   sample2_element2 = tomato old root EST dataset

   sample2 = tomato root EST dataset 

   sample3_element1 = tomato unigene build # root
   sample3 = tomato unigene build

  
   so you can relate sample1_element1 and sample1_element2 with
   the relation 'biological source' and sample2_element1 and sample2_element2
   with sample3_element1 as 'sequence source'. The protocol_id associated to each
   sample_element explains the process of the relation.


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

my $patch_name = '0032_add_two_biosource_tables.pl';
my $patch_descr = 'This script create two new tables in the biosource schema to link sample_element between them and associate files to this sample_elements';

print STDERR "\n+--------------------------------------------------------------------------------------------------+\n";
print STDERR "Executing the patch:\n   $patch_name.\n\nDescription:\n  $patch_descr.\n\nExecuted by:\n  $opt_p.";
print STDERR "\n+--------------------------------------------------------------------------------------------------+\n\n";

## And the requeriments if you want not use all
##
my @previous_requested_patches = (   ## ADD HERE
    '0029_biosource_schema.pl'
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

CREATE TABLE biosource.bs_sample_element_file (sample_element_file_id SERIAL PRIMARY KEY, sample_element_id int REFERENCES biosource.bs_sample_element (sample_element_id), file_id int REFERENCES metadata.md_files (file_id), metadata_id bigint REFERENCES metadata.md_metadata (metadata_id));
CREATE INDEX sample_element_file_id_index ON biosource.bs_sample_element_file (sample_element_file_id);
GRANT SELECT ON biosource.bs_sample_element_file TO web_usr;
GRANT SELECT ON biosource.bs_sample_element_file_sample_element_file_id_seq TO web_usr;
COMMENT ON TABLE biosource.bs_sample_element_file IS 'biosource.bs_sample_element_file store the associations between the sample_elements and files.';

CREATE TABLE biosource.bs_sample_element_relation (sample_element_relation_id SERIAL PRIMARY KEY, sample_element_id_A int REFERENCES biosource.bs_sample_element (sample_element_id), sample_element_id_B int REFERENCES biosource.bs_sample_element (sample_element_id), relation_type text, metadata_id bigint REFERENCES metadata.md_metadata (metadata_id));
CREATE INDEX sample_element_relation_id_index ON biosource.bs_sample_element_relation (sample_element_relation_id);
GRANT SELECT ON biosource.bs_sample_element_relation TO web_usr;
GRANT SELECT ON biosource.bs_sample_element_relation_sample_element_relation_id_seq TO web_usr;
COMMENT ON TABLE biosource.bs_sample_element_relation IS 'biosource.bs_sample_element_relation store the associations between sample_elements, for example an est dataset and an unigene dataset can be related with a sequence assembly relation';


EOSQL

## Now it will add this new patch information to the md_version table.  It did the dbversion object before and
## set the patch_name and the patch_description, so it only need to store it.
   

$dbversion->store($metadata);

$dbh->commit;

__END__

