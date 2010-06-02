#!/usr/bin/env perl


=head1 NAME

 0029_biosource_schema.pl

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

 BIOSOURCE SCHEMA or SAMPLE + PROTOCOL tables
 biosource schema are tables that store information about every sample in five
 different tables: 
    + biosource.bs_sample, 
    + biosource.bs_sample_pub,
    + biosource.bs_sample_element, 
    + biosource.bs_sample_element_dbxref (to store GO terms...)
    + biosource.bs_sample_element_cvterm (to store tags like normalized, 
      substraction-sustracted pairs for sample_elements, 
      contaminated-contamination groups...)

  Sample should store from libraries (type: mRNA library) to proteins 
  (type: protein_fraction). It can store a protocol_group_id, so it is possible
  store from the growth conditions (protocol_type: plant growth conditions) to 
  mRNA extactions.

  Also they store information about how this samples were processed using the protocol 
  tables. There are six protocol tables:

    + biosource.bs_protocol,
    + biosource.bs_protocol_pub,
    + biosource.bs_tool,
    + biosource.bs_tool_pub,
    + biosource.bs_protocol_step
    + biosource.bs_protocol_step_dbxref   

 Biosource tables will have the prefix bs_

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

my $patch_name = '0029_biosource_schema.pl';
my $patch_descr = 'This script create the biosource schema and the sample (5) and protocol (6) tables associated to it. Also grant select to web_usr and add a comment.';

print STDERR "\n+--------------------------------------------------------------------------------------------------+\n";
print STDERR "Executing the patch:\n   $patch_name.\n\nDescription:\n  $patch_descr.\n\nExecuted by:\n  $opt_p.";
print STDERR "\n+--------------------------------------------------------------------------------------------------+\n\n";

## And the requeriments if you want not use all
##
my @previous_requested_patches = (   ## ADD HERE
    
    '0022_metadata_schema.pl'
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

CREATE SCHEMA biosource;
GRANT USAGE ON SCHEMA biosource TO web_usr;

COMMENT ON SCHEMA biosource IS 'Biosource schema are composed by tables that store data about biological source of the data or other schemas as transcript or expression. It is a combination of the biological origin (samples) and how it was processed (protocol). See specific table comment for more information. The table prefix used is "bs_"';


CREATE TABLE biosource.bs_protocol (protocol_id SERIAL PRIMARY KEY, protocol_name varchar(250), protocol_type varchar(250), description text, metadata_id bigint REFERENCES metadata.md_metadata (metadata_id));
CREATE INDEX protocol_id_index ON biosource.bs_protocol (protocol_id);
GRANT SELECT ON biosource.bs_protocol TO web_usr;
GRANT SELECT ON biosource.bs_protocol_protocol_id_seq TO web_usr;
COMMENT ON TABLE biosource.bs_protocol IS 'biosource.bs_protocol store general information about how something was processed. mRNA extraction is a protocol, but also can be a protocol sequence_assembly or plant growth';


CREATE TABLE biosource.bs_protocol_pub (protocol_pub_id SERIAL PRIMARY KEY, protocol_id int REFERENCES biosource.bs_protocol (protocol_id), pub_id int REFERENCES public.pub (pub_id), metadata_id bigint REFERENCES metadata.md_metadata (metadata_id));
CREATE INDEX protocol_pub_id_index ON biosource.bs_protocol_pub (protocol_pub_id);
GRANT SELECT ON biosource.bs_protocol_pub TO web_usr;
GRANT SELECT ON biosource.bs_protocol_pub_protocol_pub_id_seq TO web_usr;
COMMENT ON TABLE biosource.bs_protocol_pub IS 'biosource.bs_protocol_pub is a linker table to associate publications to some protocols';


CREATE TABLE biosource.bs_tool (tool_id SERIAL PRIMARY KEY, tool_name varchar(250), tool_version varchar(10), tool_type varchar(250), tool_description text, tool_weblink text, file_id int REFERENCES metadata.md_files (file_id), metadata_id bigint REFERENCES metadata.md_metadata (metadata_id));
CREATE INDEX tool_id_index ON biosource.bs_tool (tool_id);
GRANT SELECT ON biosource.bs_tool TO web_usr;
GRANT SELECT ON biosource.bs_tool_tool_id_seq TO web_usr;
COMMENT ON TABLE biosource.bs_tool IS 'biosource.bs_tool stores information about the tools used during the execution of some protocols. Example of tools are vectors, mRNA purification kits, software, soils. They can have links to web_pages or/and files.';


CREATE TABLE biosource.bs_tool_pub (tool_pub_id SERIAL PRIMARY KEY, tool_id int REFERENCES biosource.bs_tool (tool_id), pub_id int REFERENCES public.pub (pub_id), metadata_id bigint REFERENCES metadata.md_metadata (metadata_id));
CREATE INDEX tool_pub_id_index ON biosource.bs_tool_pub (tool_pub_id);
GRANT SELECT ON biosource.bs_tool_pub TO web_usr;
GRANT SELECT ON biosource.bs_tool_pub_tool_pub_id_seq TO web_usr;
COMMENT ON TABLE biosource.bs_tool_pub IS 'biosource.bs_tool_pub is a linker table to associate publications to some tools';


CREATE TABLE biosource.bs_protocol_step (protocol_step_id SERIAL PRIMARY KEY, protocol_id int REFERENCES biosource.bs_protocol (protocol_id), step int, action text, execution text, tool_id int REFERENCES biosource.bs_tool (tool_id), begin_date timestamp, end_date timestamp, location text, metadata_id bigint REFERENCES metadata.md_metadata (metadata_id));
CREATE INDEX protocol_step_id_index ON biosource.bs_protocol_step (protocol_step_id);
GRANT SELECT ON biosource.bs_protocol_step TO web_usr;
GRANT SELECT ON biosource.bs_protocol_step_protocol_step_id_Seq TO web_usr;
COMMENT ON TABLE biosource.bs_protocol_step IS 'biosource.bs_protocol_step store data for each step or stage in a protocol. They are order by the secuencially by step column. Execution describe the action produced during the step, for example plant growth at 24C, blastall -p blastx, ligation... begin_date, end_date and location generally will be used for plant field growth conditions.';


CREATE TABLE biosource.bs_protocol_step_dbxref (protocol_step_dbxref_id SERIAL PRIMARY KEY, protocol_step_id int REFERENCES biosource.bs_protocol_step (protocol_step_id), dbxref_id int REFERENCES public.dbxref (dbxref_id), metadata_id bigint REFERENCES metadata.md_metadata (metadata_id));
CREATE INDEX protocol_step_dbxref_id_index ON biosource.bs_protocol_step_dbxref (protocol_step_dbxref_id);
GRANT SELECT ON biosource.bs_protocol_step_dbxref TO web_usr;
GRANT SELECT ON biosource.bs_protocol_step_dbxref_protocol_step_dbxref_id_seq TO web_usr;  
COMMENT ON TABLE biosource.bs_protocol_step_dbxref IS 'biosource.bs_protocol_step_dbxref is a loker table designed to store controlled vocabulary terms associated to some protocol steps';


CREATE TABLE biosource.bs_sample (sample_id SERIAL PRIMARY KEY, sample_name varchar(250), sample_type varchar(250), description text, contact_id int REFERENCES sgn_people.sp_person (sp_person_id), metadata_id bigint REFERENCES metadata.md_metadata (metadata_id));
CREATE INDEX sample_id_index ON biosource.bs_sample (sample_id);
GRANT SELECT ON biosource.bs_sample TO web_usr;
GRANT SELECT ON biosource.bs_sample_sample_id_seq TO web_usr;
COMMENT ON TABLE biosource.bs_sample IS 'biosource.bs_sample store information about the origin of a biological sample. It can be composed by different elements, for example tomato fruit sample can be a mix of fruits in different stages. Each stage will be a sample_element. Sample also can have associated a sp_person_id in terms of contact.';


CREATE TABLE biosource.bs_sample_pub (sample_pub_id SERIAL PRIMARY KEY, sample_id int REFERENCES biosource.bs_sample (sample_id), pub_id int REFERENCES public.pub (pub_id), metadata_id bigint REFERENCES metadata.md_metadata (metadata_id));
CREATE INDEX sample_pub_id_index ON biosource.bs_sample_pub (sample_pub_id);
GRANT SELECT ON biosource.bs_sample_pub TO web_usr;
GRANT SELECT ON biosource.bs_sample_pub_sample_pub_id_seq TO web_usr;
COMMENT ON TABLE biosource.bs_sample_pub IS 'bisource.bs_sample_pub is a linker table to associate publications to a sample.';

CREATE TABLE biosource.bs_sample_element (sample_element_id SERIAL PRIMARY KEY, sample_element_name varchar(250), alternative_name text, sample_id int REFERENCES biosource.bs_sample (sample_id), description text, organism_id int REFERENCES public.organism (organism_id), stock_id int, protocol_id int REFERENCES biosource.bs_protocol (protocol_id), metadata_id bigint REFERENCES metadata.md_metadata (metadata_id));
CREATE INDEX sample_element_id_index ON biosource.bs_sample_element (sample_element_id);
GRANT SELECT ON biosource.bs_sample_element TO web_usr;
GRANT SELECT ON biosource.bs_sample_element_sample_element_id_seq TO web_usr;
COMMENT ON TABLE biosource.bs_sample_element IS 'biosource.bs_sample_element store information of each elemennt of a sample. It have a organism_id column and stock_id to associate different origins, for example a tomato leaves sample can be composed by leaves of Solanum lycopersicum and Solanum pimpinellifolium.';

CREATE TABLE biosource.bs_sample_element_cvterm (sample_element_cvterm_id SERIAL PRIMARY KEY, sample_element_id int REFERENCES biosource.bs_sample_element (sample_element_id), cvterm_id int REFERENCES public.cvterm (cvterm_id), metadata_id bigint REFERENCES metadata.md_metadata (metadata_id));
CREATE INDEX sample_element_cvterm_id_index ON biosource.bs_sample_element_cvterm (sample_element_cvterm_id);
GRANT SELECT ON biosource.bs_sample_element_cvterm TO web_usr;
GRANT select ON biosource.bs_sample_element_cvterm_sample_element_cvterm_id_seq TO web_usr;
COMMENT ON TABLE biosource.bs_sample_element_cvterm IS 'biosource.bs_sample_cvterm is a linker table to associate tags to the samples as Normalized, Sustracted...';

CREATE TABLE biosource.bs_sample_element_dbxref (sample_element_dbxref_id SERIAL PRIMARY KEY, sample_element_id int REFERENCES biosource.bs_sample_element (sample_element_id), dbxref_id bigint REFERENCES public.dbxref (dbxref_id), metadata_id bigint REFERENCES metadata.md_metadata (metadata_id));
CREATE INDEX sample_element_dbxref_id_index ON biosource.bs_sample_element_dbxref (sample_element_dbxref_id);
GRANT SELECT ON biosource.bs_sample_element_dbxref TO web_usr;
GRANT select ON biosource.bs_sample_element_dbxref_sample_element_dbxref_id_seq TO web_usr;
COMMENT ON TABLE biosource.bs_sample_element_dbxref IS 'biosource.bs_sample_element_dbxref is a linker table to associate controlled vocabullary as Plant Ontology to each element of a sample';


EOSQL

## Now it will add this new patch information to the md_version table.  It did the dbversion object before and
## set the patch_name and the patch_description, so it only need to store it.
   

$dbversion->store($metadata);

$dbh->commit;

__END__

