#!/usr/bin/perl

=head1 NAME

 sample_dbload.pl
 A script to parse sample file and load in a database for biosource schema 
(version.0.2.).

=cut

=head1 SYPNOSIS

 sample_dbload.pl [-h] -H <dbhost> -D <dbname> -U <dbuser>
                       -u <data_loader_username>
                       -s <sample_file> [-T] [-X]

  To collect the data loaded report into a file:

 sample_dbload [-h] [-X] -D <dbname> -H <dbhost> 
               -s <sample_file> [-T] > file.log


=head1 EXAMPLE:

 perl sample_dbload.pl -H localhost -U postgres -D sandbox
                       -u aure 
                       -s solanaceae_comparisson.bs
        
    
=head2 I<Flags:>

=over

=item -s

B<data load file>               data load file in bs format (mandatory).

=item -H

B<database_host>                database host (mandatory)

=item -U

B<database_user>                database user (mandatory)

=item -D

B<database_name>                database name (mandatory)

=item -V

B<database_driver>              database driver (Pg (postgres) by default)

=item -u

B<dataloader_username>          username for the data loader (mandatory)

=item -X

B<print data load file>         print a template with examples of the 
                                data load file in bs format

=item -T

B<run as a test>                run the script as test

=item -h

B<help>                         print the help  

=back

=cut

=head1 DESCRIPTION

  This script parse the sample_dbload files and load the data into the 
 database. It will insert data into biosource schema, in the tables 
 bs_sample, bs_sample_file, bs_sample_pub, bs_sample_cvterm, 
 bs_sample_dbxref and bs_sample_relationship.

 To add relations with publications, dbxrefs or cvterms, it needs that
 exists this publication.title, dbxref.accession and cvterm.name in their
 respective tables.

  Also youb can run it with -T test mode.

  Note about -T (Test mode): You can run test mode in two ways. The first 
 using -T parameter and the second login to the database as web_usr. In this 
 mode the ids that this script will return comes from the simulation of 
 new _id_seq (get the current id_seq in an object and add using $v++). 
 
=cut

=head1 AUTHORS

  Aureliano Bombarely Gomez.
  (ab782@cornell.edu).

=cut

=head1 METHODS

sample_dbload.pl


=cut

use strict;
use warnings;

use File::Basename;
use Getopt::Std;
use Term::ReadKey;

use CXGN::Biosource::Schema;
use CXGN::Biosource::Sample;
use CXGN::Metadata::Metadbdata;

our ($opt_u, $opt_H, $opt_D, $opt_U, $opt_V, $opt_s, $opt_T, $opt_X, $opt_h);
getopts("u:H:D:U:V:s:TXh");
if (!$opt_u && !$opt_H && !$opt_D && !$opt_U && !$opt_V && !$opt_s && !$opt_T && !$opt_X && !$opt_h) {
    print "There are n\'t any tags. Print help\n\n";
    help();
} elsif ($opt_h) {
    help();
} elsif ($opt_X) {
    print_sample_template();
}

## Checking the input arguments

my $loader_username = $opt_u 
    || die("MANDATORY ARGUMENT ERROR: The -u <loader_username> argument was not supplied.\n");
my $dbname = $opt_D 
    || die("MANDATORY ARGUMENT ERROR: The -D <database_name> argument was not supplied.\n");
my $dbhost = $opt_H 
    || die("MANDATORY ARGUMENT ERROR: The -H <db_hostname> argument was not supplied.\n");
my $dbuser = $opt_U 
    || die("MANDATORY ARGUMENT ERROR: The -U <db_username> argument was not supplied.\n"); 
my $sample_file = $opt_s 
    || die("MANDATORY ARGUMENT ERROR: The -s <sample_dataload_file> argument was not supplied.\n");

my $dbdriver = $opt_V || 'Pg';

## Connecting with the database

print STDERR "\nStep 1: Connect with the database.\n";

## First, get the password as prompt

print STDERR "\n\tType password for database user=$dbuser:\n\tpswd> ";

ReadMode('noecho');
my $passw = <>;
chomp($passw);
ReadMode('normal');
print STDERR "\n\n";

## Create a new db_connection

my $schema_list = 'biosource,metadata,public';

my $schema = CXGN::Biosource::Schema->connect( "dbi:$dbdriver:database=$dbname;host=$dbhost", 
                                               $dbuser, 
                                               $passw,
                                               { AutoCommit => 0 }, 
                                               {on_connect_do => ["SET search_path TO $schema_list;"]}
                                             ); 


## Getting the last ids for the different tables to set the database sequences values in case of rollback 
## or something wrong during the test

print STDERR "\nStep 2: Get the last ids for each table.\n";

my $all_last_ids_href = $schema->get_last_id();


## Parse the sample_file and transfer the data to sample objects

print STDERR "\nStep 3: Open and parse the sample file.\n";

open my $ifh, '<', $sample_file || die("Sorry, but I can not open the input file: $sample_file.\n");

my $l = 0;

## The input file can store more than one sample. Multiple samples will be stored as a hash
## with keys=sample_name and values=sample object

my %samples;

## Each data field will be defined by $data_type variable, also will be define $sample_name and $sample_element_name.

my ($dt, $sample_name, $object_sample_name, $subject_sample_name, $db_id);
my (%relationship);

while(<$ifh>) {
		
    $l++; ## Line counter

    ## It will do not read any line that start with #
    unless ($_ =~ m/^#/) {
	
	## First define the data_type
	
	if ($_ =~ m/\*DATA_TYPE:\s+\[(\w+)\]/) {
	    $dt = $1;
	}
	elsif ($_ =~ m/\/\//) {
	    if ($dt eq 'relationship') {
		my $relationship_data_href = $relationship{$object_sample_name.'+'.$subject_sample_name};
		if (defined $relationship_data_href) {
		    if ($sample_name eq $object_sample_name) {
			if ($relationship_data_href->{'parent_match'} == 0) {
			    $samples{$sample_name}->add_parent_relationship({ subject_id => $subject_sample_name,
									      type_id    => $relationship_data_href->{'type_id'}, 
									      value      => $relationship_data_href->{'value'},
									      rank       => $relationship_data_href->{'rank'}
									    });
			}
		    }
		    elsif ($sample_name eq $subject_sample_name) {
			if ($relationship_data_href->{'children_match'} == 0) {
			    $samples{$sample_name}->add_children_relationship({ object_id => $object_sample_name,
								  	        type_id   => $relationship_data_href->{'type_id'}, 
									        value     => $relationship_data_href->{'value'},
									        rank      => $relationship_data_href->{'rank'}
									     });
			}
		    }
		
		}
	    }
	    $dt = '';
	    $sample_name = '';
	    $object_sample_name = '';
	    $subject_sample_name = '';
	    $db_id = '';
	    %relationship = ();
	}
	
	my $sample_list = join(',', keys %samples);

	## Parse sample and set the data in an object

	if (defined $dt) {
	    if ($dt eq 'sample') {
		if ($_ =~ m/\*SAMPLE_NAME:\s+\[(.+?)\]/) {
		    $sample_name = $1 ||
			die("MANDATORY DATA ERROR (line $l): None sample_name data was detailed.\n");
		    
		    my $sample_obj;
		    my ($sample_row) = $schema->resultset('BsSample')
			                      ->search({ sample_name => $sample_name});
		    if (defined $sample_row) {
			$sample_obj = CXGN::Biosource::Sample->new_by_name($schema, $sample_name);
		    }
		    else {
			$sample_obj = CXGN::Biosource::Sample->new($schema);
			$sample_obj->set_sample_name($sample_name);
		    }
		    
		    $samples{$sample_name} = $sample_obj;
		}
		elsif ($_ =~ m/\*ALTERNATIVE_NAME:\s+\[(.+?)\]/) {
		    my $alt_name = $1; ## It can be null.

		    $samples{$sample_name}->set_alternative_name($alt_name);
		}
		elsif ($_ =~ m/\*SAMPLE_TYPE_NAME:\s+\[(.+?)\]/) {
		    my $sample_type = $1 ||
			die("MANDATORY DATA ERROR (line $l): None sample_type_name data was detailed in sample section.\n");
		    
		    ## It can not set the type name because it uses a cvterm_id for types. So, it will check if exists a cvterm
		    ## with this name. Biosource schema contains chado so it only needs to do a simple search

		    my ($cvterm_row) = $schema->resultset('Cv::Cvterm')
			                      ->search({ name => $sample_type });

		    unless (defined $cvterm_row) {
			die("MANDATORY DATA ERROR (line $l): Sample_type_name does not exist as name in cvterm table.\n");
		    }

		    $samples{$sample_name}->set_type_id($cvterm_row->get_column('cvterm_id'));
		}
		elsif ($_ =~ m/\*SAMPLE_DESCRIPTION:\s+\[(.+?)\]/ ) {
		    my $sample_description = $1;
		    
		    if (defined $sample_description) {
			$samples{$sample_name}->set_description($sample_description);
		    }
		}
		elsif ($_ =~ m/\*ORGANISM_NAME:\s+\[(.+?)\]/ ) {
		    my $organism_name = $1;  ## It can be null
		    
		    if (defined $organism_name) {
			$samples{$sample_name}->set_organism_by_species($organism_name);
		    }
		}
		elsif ($_ =~ m/\*STOCK_NAME:\s+\[(.+?)\]/ ) {

		    ## FOR NOW IT WILL IGNORE STOCK_NAME
		    ## my $stock_name = $1;  ## It can be null
		    
		    ## if (defined $stock_name) {

			## First check into the chado tables if exists the stock name, and then 
			## take the stock_id

		    ##	my ($stock_row) = $schema->resultset('Stock::Stock')
		    ##	                         ->search({ name => $stock_name });

		    ##	unless (defined $stock_row) {
		    ##	    die("MANDATORY DATA ERROR (line $l): Stock_name does not exist as name in stock table.\n");
		    ##	}
		    ##	else {
		    ##	    $samples{$sample_name}->set_stock_id($stock_row->get_column('stock_id'));
		    ##	}
		    ## }
		}
		elsif ($_ =~ m/\*PROTOCOL_NAME:\s+\[(.+?)\]/ ) {
		    my $protocol_name = $1;  ## It can be null
		    
		    if (defined $protocol_name) {
			$samples{$sample_name}->set_protocol_by_name($protocol_name);
		    }
		}
		elsif ($_ =~ m/\*CONTACT_NAME:\s+\[(.+?)\]/ ) {
		    my $contact_name = $1;
		    
		    if (defined $contact_name) {
			
			## If contact name has comma (,) the format will be $last_name and $first name, if it have an space will be
			## first_name and last_name. This will use a simple SQL search but should be replaced by a DBIx.
			
			my ($first_name, $last_name);
			if ($contact_name =~ m/,/) {
			    my @user = split(/,/, $contact_name);
			    $user[1] =~ s/^\s+//;
			    $user[1] =~ s/\s+$//;
			    $user[0] =~ s/^\s+//;
			    $user[0] =~ s/\s+$//;
			    $first_name = "'%" . $user[1] . "%'";
			    $last_name = "'%" . $user[0] . "%'";
			}
			else {
			    my @user = split(/ /, $contact_name);
			    $first_name = shift(@user);
			    $last_name = join(' ', @user);
			    
			}
			
			my $query = "SELECT sp_person_id FROM sgn_people.sp_person WHERE first_name ILIKE $first_name AND last_name ILIKE $last_name";
			my $sth = $schema->storage()
                                         ->dbh()
                                         ->prepare($query);
			$sth->execute();
			my ($sp_person_id) = $sth->fetchrow_array();
			
			if (defined $sp_person_id) {
			    $samples{$sample_name}->set_contact_id($sp_person_id);
			}
			else {
			    warn("OPTIONAL DATA WARNING (line $l): Contact_name=$contact_name (first_name=$first_name and last_name=$last_name) do not exists db.\n");
			}
		    }
		}
	    }
	    elsif ($dt eq 'pub') {
		if ($_ =~ m/\*SAMPLE_NAME:\s+\[(.+?)\]/) {
		    $sample_name = $1 ||
			die("MANDATORY DATA ERROR (line $l): None sample_name data was detailed in pub section.\n");
		    unless (defined $samples{$sample_name}) {		
			die("MANDATORY DATA ERROR (line $l): None sample_name data match with currente sample_list ($sample_list).\n");
		    }
		}
		elsif ($_ =~ m/\*TITLE:\s+\[(.+?)\]/) {
		    my $title = $1 ||
			die("MANDATORY DATA ERROR (line $l): None title data was detailed in pub section.\n");
		    
		    my $match;
		    my @pub_list = $samples{$sample_name}->get_publication_list('title');
		    foreach my $pub (@pub_list) {
			
			my $formated_title = $title;
			$formated_title =~ s/ //g;
			$formated_title =~ s/\.//g;
			$formated_title =~ s/-//g;
			$formated_title =~ s/_//g;

			my $formated_pub = $pub;
			$formated_pub =~ s/ //g;
			$formated_pub =~ s/\.//g;
			$formated_pub =~ s/-//g;
			$formated_pub =~ s/_//g;

			if ($formated_title =~ m/$formated_pub/i) {
			    $match = $pub;
			}
		    }

		    unless (defined $match) {
			$samples{$sample_name}->add_publication( { title => $title } );
		    }
		    else {
			warn("\nThe pub=$title match with a previous publication\n\t($match).\n\tIt will not be added.\n");
		    }
		}
	    }
	    elsif ($dt eq 'cvterm') {
		if ($_ =~ m/\*SAMPLE_NAME:\s+\[(.+?)\]/) {
		    $sample_name = $1 ||
			die("MANDATORY DATA ERROR (line $l): None sample_name data was detailed in cvterm section.\n");
		    unless (defined $samples{$sample_name}) {		
			die("MANDATORY DATA ERROR (line $l): None sample_name data match with current sample_list ($sample_list).\n");
		    }
		}
		elsif ($_ =~ m/\*CVTERM:\s+\[(.+?)\]/) {
		    my $cvterm = $1 ||
			die("MANDATORY DATA ERROR (line $l): None cvterm data was detailed in element_cvterm section.\n");
		    
		    my ($cvterm_row) = $schema->resultset('Cv::Cvterm')
			                      ->search( { name => $cvterm } );

		    if (defined $cvterm_row) {
			my $cvterm_id = $cvterm_row->get_column('cvterm_id');
			    
			my @curr_cvterm_ids = $samples{$sample_name}->get_cvterm_list();
			    
			my $cvtermmatch = 0;
			foreach my $prev_cvterm_id (@curr_cvterm_ids) {
			    if ($cvterm_id == $prev_cvterm_id) {
				$cvtermmatch = 1;
			    }
			}
			if ($cvtermmatch == 0) {
			    $samples{$sample_name}->add_cvterm($cvterm_id);
			}
			else {
			    warn("\nSKIP WARNING: cvterm=$cvterm exists associated to sample_name:$sample_name.\n");
			}		    
		    }
		    else {
			warn("MANDATORY DATA ERROR (line $l): Cvterm=$cvterm do not exists in db.\n");
		    }
		} 
	    }
	    elsif ($dt eq 'dbxref') {
		if ($_ =~ m/\*SAMPLE_NAME:\s+\[(.+?)\]/) {
		    $sample_name = $1 ||
			die("MANDATORY DATA ERROR (line $l): None sample_name data was detailed in dbxref section.\n");
		    unless (defined $samples{$sample_name}) {		
			die("MANDATORY DATA ERROR (line $l): None sample_name data match with current sample_list ($sample_list).\n");
		    }
		}
		elsif ($_ =~ m/\*DBNAME:\s+\[(.+?)\]/) {
		    my $dbname = $1 ||
			die("MANDATORY DATA ERROR (line $l): None dbname data was detailed in element_dbxref section.\n");
		    
		    my ($db_row) = $schema->resultset('General::Db')
                	                  ->search( { name => $dbname } );

		    if (defined $db_row) {
			$db_id = $db_row->get_column('db_id');
		    }
		    else {
			die("MADATORY DATA ERROR (line $l): Dbname=$dbname do not exists in db.\n");
		    }
		} 
		elsif ($_ =~ m/\*ACCESSIONS:\s+\[(.+?)\]/) {
		    my $accessions = $1 ||
			die("MANDATORY DATA ERROR (line $l): None accessions data was detailed in element_dbxref section.\n");
		
		    my @accessions = split(/,/, $accessions);
	    
		    foreach my $acc (@accessions) {		    
			my ($dbxref_row) = $schema->resultset('General::Dbxref')
                		                  ->search( 
			                                    { 
					    		      accession => $acc,
							      db_id     => $db_id,
							    }  
					                  );

			if (defined $dbxref_row) {
			    my $dbxref_id = $dbxref_row->get_column('dbxref_id');

			    my @curr_dbxref_ids = $samples{$sample_name}->get_dbxref_list();
			    
			    my $dbxrefmatch = 0;
			    foreach my $prev_dbxref_id (@curr_dbxref_ids) {
				if ($dbxref_id == $prev_dbxref_id) {
				    $dbxrefmatch = 1;
				}
			    }
			    if ($dbxrefmatch == 0) {
				$samples{$sample_name}->add_dbxref($dbxref_id );
			    }
			    else {
				warn("\nSKIP WARNING: Dbxref-access=$acc exist associated to sample_name:$sample_name.\n");
			    }
			}
			else {
			    die("MADATORY DATA ERROR (line $l): Dbxref=$dbname do not exists in db.\n");
			}
		    } 
		}
	    }
	    elsif ($dt eq 'file') {
		if ($_ =~ m/\*SAMPLE_NAME:\s+\[(.+?)\]/) {
		    $sample_name = $1 ||
			die("MANDATORY DATA ERROR (line $l): None sample_name data was detailed in file section.\n");
		    unless (defined $samples{$sample_name}) {		
			die("MANDATORY DATA ERROR (line $l): None sample_name data match with current sample_list ($sample_list).\n");
		    }
		}
		elsif ($_ =~ m/\*FILENAME:\s+\[(.+?)\]/) {
		    my $filename = $1 ||
			die("MANDATORY DATA ERROR (line $l): None filename data was detailed in file section.\n");
		    
		    my $basename = File::Basename->basename($filename);
		    my $dirname = File::Basename->dirname($filename);

		    my ($file_row) = $schema->resultset('MdFiles')
			                      ->search( { basename => $basename, dirname => $dirname } );

		    if (defined $file_row) {
			my $file_id = $file_row->get_column('file_id');
			    
			my @curr_file_ids = $samples{$sample_name}->get_file_list();
			    
			my $filematch = 0;
			foreach my $prev_file_id (@curr_file_ids) {
			    if ($file_id == $prev_file_id) {
				$filematch = 1;
			    }
			}
			if ($filematch == 0) {
			    $samples{$sample_name}->add_file($file_id);
			}
			else {
			    warn("\nSKIP WARNING: file=$filename exists associated to sample $samples{$sample_name}->get_sample_name().\n");
			}		    
		    }
		    else {
			warn("MANDATORY DATA ERROR (line $l): File=$filename do not exists in db.\n");
		    }
		} 
	    }
	    elsif ($dt eq 'relationship') {
		if ($_ =~ m/\*OBJECT_SAMPLE_NAME:\s+\[(.+?)\]/) {
		    $object_sample_name = $1 ||
			die("MANDATORY DATA ERROR (line $l): None object_sample_name data was detailed in relationship section.\n");
		}
		if ($_ =~ m/\*SUBJECT_SAMPLE_NAME:\s+\[(.+?)\]/) {
		    $subject_sample_name = $1 ||
			die("MANDATORY DATA ERROR (line $l): None object_sample_name data was detailed in relationship section.\n");
		}
		if ($_ =~ m/\*RELATIONSHIP_TYPE:\s+\[(.+?)\]/) {
		    my $relationship_type = $1 ||
			die("MANDATORY DATA ERROR (line $l): None relationship_type data was detailed in relationship section.\n");

		    ## Now it will check if exists the relationship type as cvterm

		    my ($rel_cvterm_row) = $schema->resultset('Cv::Cvterm')
			                          ->search({ name => $relationship_type });

		    unless (defined $rel_cvterm_row) {
			die("MANDATORY DATA ERROR (line $l): Relationship_table does not exist as name in cvterm table.\n");
		    }
		    else {
			$relationship{$object_sample_name . '+' . $subject_sample_name}->{'type_id'} = $rel_cvterm_row->get_column('cvterm_id');
		    }
		}
		if ($_ =~ m/\*RANK:\s+\[(.+?)\]/) {
		    my $rank = $1 ||
			die("MANDATORY DATA ERROR (line $l): None rank data was detailed in relationship section.\n");
		    $relationship{$object_sample_name . '+' . $subject_sample_name}->{'rank'} = $rank;
		}
		if ($_ =~ m/\*NOTES:\s+\[(.+?)\]/) {
		    my $notes = $1 ||
			die("MANDATORY DATA ERROR (line $l): None rank data was detailed in relationship section.\n");
		    $relationship{$object_sample_name . '+' . $subject_sample_name}->{'value'} = $notes;
		}
		

		if (defined $object_sample_name && defined $subject_sample_name) {

		    ## now it will create a hash to store the data parsed with key = $object_sample_name .'+'. $subject_sample_name

		    $relationship{$object_sample_name . '+' . $subject_sample_name} = { 'object' => $object_sample_name, 'subject' => $subject_sample_name };

		    if (defined $samples{$object_sample_name}) {
		    
			## first take the parents relationships and check if exists the relation

			my @parents_samples = $samples{$object_sample_name}->get_parents_relationship();
		    
			my $parent_match = 0;
			foreach my $p_sample (@parents_samples) {
			    if ($p_sample->get_sample_name() eq $subject_sample_name ) {
				$parent_match = 1;
			    }
			}
			$relationship{$object_sample_name . '+' . $subject_sample_name}->{'parent_match'} = $parent_match;
		    }
		    elsif (defined $samples{$subject_sample_name}) {
			
			## first take the children relationships and check if exists the relation

			my @children_samples = $samples{$sample_name}->get_children_relationship();
		    
			my $children_match = 0;
			foreach my $c_sample (@children_samples) {
			    if ($c_sample->get_sample_name() eq $object_sample_name ) {
				$children_match = 1;
			    }
			}
			$relationship{$object_sample_name . '+' . $subject_sample_name}->{'children_match'} = $children_match;
		    }
		    else {
			die("MANDATORY DATA ERROR (line $l): None sample_name data (object or subject) match with current sample_list ($sample_list).\n");
		    }
		}

		## It will add these data to the sample object in the begining in the parsing, before the read of the // sign
	    }
	}
    }
}

## The file should be parsed.
## Test mode, run as evaluation of the code

print STDERR "\nStep 4: Store (or store simulation for Test mode) the sample data into the database.\n";

if ($opt_T) {
    print STDERR "\nRunning the TEST MODE.\n\n";
    eval {

	## First, creation of a metadata object

	my $metadbdata = CXGN::Metadata::Metadbdata->new($schema, $loader_username);
	$metadbdata->store();
	
	## Second, store the sample objects

	foreach my $samplename (sort keys %samples) {
	    $samples{$samplename}->store($metadbdata);
	}

	## Third, print the sample data stored

	print STDERR "\nStep 5: Print data loaded log.\n";
	print STDOUT "\nDATA NOT STORED in TEST MODE: \n";

	foreach my $samplename (sort keys %samples) {
	    my $t_sample_id = $samples{$samplename}->get_sample_id() || 'undef';
	    my $t_sample_name = $samples{$samplename}->get_sample_name() || 'undef';
	    my $t_sample_alt = $samples{$samplename}->get_alternative_name() || 'undef';
	    my $t_sample_type = $samples{$samplename}->get_type_id() || 'undef';
	    my $t_description =  $samples{$samplename}->get_description() || 'undef';
	    my $t_contact_id = $samples{$samplename}->get_contact_id() || 'undef';
	    my $t_organism_id = $samples{$samplename}->get_organism_id() || 'undef';
	     my $t_stock_id = $samples{$samplename}->get_stock_id() || 'undef';
	    print STDOUT "+ SAMPLE_DATA:\n\tsample_id =\t$t_sample_id\n";
	    print STDOUT "\tsample_name =\t$t_sample_name\n";
	    print STDOUT "\talternative_name =\t$t_sample_alt\n";
	    print STDOUT "\tsample_type_id =\t$t_sample_type\n";
	    print STDOUT "\tdescription =\t$t_description\n";
	    print STDOUT "\tcontact_id =\t$t_contact_id\n";
	    print STDOUT "\torganism_id =\t$t_organism_id\n";
	    print STDOUT "\tstock_id =\t$t_stock_id\n";
	
	    print STDOUT "  * Associated publications:\n";
	    my @pub_title_list = $samples{$samplename}->get_publication_list('title');
	    foreach my $pub (@pub_title_list) {
		print STDOUT "\t\tpub_title: $pub\n";
	    }

	    print STDOUT "  * Associated dbxrefs:\n";
	    my @dbxref_accessions = $samples{$samplename}->get_dbxref_list('accession');
	    foreach my $dbxref (@dbxref_accessions) {
		print STDOUT "\t\tdbxref_accession: $dbxref\n";
	    }

	    print STDOUT "  * Associated cvterms:\n";
	    my @cvterm_names = $samples{$samplename}->get_cvterm_list('name');
	    foreach my $cvterm (@cvterm_names) {
		print STDOUT "\t\tcvterm_name: $cvterm\n";
	    }

	    print STDOUT "  * Associated files:\n";
	    my @file_list = $samples{$samplename}->get_file_list();
	    foreach my $file (@file_list) {
		print STDOUT "\t\tfilename: $file\n";
	    }

	    print STDOUT "  * Associated relationship:\n";
	    my %related_samples = $samples{$samplename}->get_relationship();
	    foreach my $type (keys %related_samples) {
		my @sample_reltype = @{$related_samples{$type}};
		
		foreach my $sampleobj (@sample_reltype) {
		    my $sname = $sampleobj->get_sample_name();
		    print STDOUT "relation type: $type ($sname)";
		}
	    }


	    print STDOUT "\n";
	}
    };

    ## Print errors if something was wrong during the test

    if ($@) {
	print STDERR "\nTEST ERRORS:\n\n$@\n";
    }

    ## Finally, rollback, because it is a test and set the sequence values

    $schema->set_sqlseq($all_last_ids_href);
    $schema->txn_rollback;

} 
else {
    print STDERR "\nRunning the NORMAL MODE.\n\n";

    ## TRUE RUN
    ## First, creation of a metadata object
    
    my $metadbdata = CXGN::Metadata::Metadbdata->new($schema, $loader_username);
    $metadbdata->store();
    
    ## Second, store the sample objects
    
    foreach my $samplename (sort keys %samples) {
	$samples{$samplename}->store($metadbdata);
    }

    print STDERR "\nStep 5: Print the data loaded log.\n";
    print STDOUT "\nDATA PROCESSED TO BE STORED: \n";

    foreach my $samplename (sort keys %samples) {
	 my $t_sample_id = $samples{$samplename}->get_sample_id() || 'undef';
	 my $t_sample_name = $samples{$samplename}->get_sample_name() || 'undef';
	 my $t_sample_alt = $samples{$samplename}->get_alternative_name() || 'undef';
	 my $t_sample_type = $samples{$samplename}->get_type_id() || 'undef';
	 my $t_description =  $samples{$samplename}->get_description() || 'undef';
	 my $t_contact_id = $samples{$samplename}->get_contact_id() || 'undef';
	 my $t_organism_id = $samples{$samplename}->get_organism_id() || 'undef';
	 my $t_stock_id = $samples{$samplename}->get_stock_id() || 'undef';
	 print STDOUT "+ SAMPLE_DATA:\n\tsample_id =\t$t_sample_id\n";
	 print STDOUT "\tsample_name =\t$t_sample_name\n";
	 print STDOUT "\talternative_name =\t$t_sample_alt\n";
	 print STDOUT "\tsample_type_id =\t$t_sample_type\n";
	 print STDOUT "\tdescription =\t$t_description\n";
	 print STDOUT "\tcontact_id =\t$t_contact_id\n";
	 print STDOUT "\torganism_id =\t$t_organism_id\n";
	 print STDOUT "\tstock_id =\t$t_stock_id\n";
	
	 print STDOUT "  * Associated publications:\n";
	 my @pub_title_list = $samples{$samplename}->get_publication_list('title');
	 foreach my $pub (@pub_title_list) {
	     print STDOUT "\t\tpub_title: $pub\n";
	 }
	 
	 print STDOUT "  * Associated dbxrefs:\n";
	 my @dbxref_accessions = $samples{$samplename}->get_dbxref_list('accession');
	 foreach my $dbxref (@dbxref_accessions) {
	     print STDOUT "\t\tdbxref_accession: $dbxref\n";
	 }
	 
	 print STDOUT "  * Associated cvterms:\n";
	 my @cvterm_names = $samples{$samplename}->get_cvterm_list('name');
	 foreach my $cvterm (@cvterm_names) {
	     print STDOUT "\t\tcvterm_name: $cvterm\n";
	 }

	 print STDOUT "  * Associated files:\n";
	 my @file_list = $samples{$samplename}->get_file_list();
	 foreach my $file (@file_list) {
	     print STDOUT "\t\tfilename: $file\n";
	 }

	 print STDOUT "  * Associated relationship:\n";
	 my %related_samples = $samples{$samplename}->get_relationship();
	 foreach my $type (keys %related_samples) {
	     my @sample_reltype = @{$related_samples{$type}};
		
	     foreach my $sampleobj (@sample_reltype) {
		 my $sname = $sampleobj->get_sample_name();
		 print STDOUT "relation type: $type ($sname)";
	     }
	 }
	
	print STDOUT "\n";	
    }
   
    ## Finally, commit or rollback option
    
    commit_prompt($schema, $all_last_ids_href);
}


=head2 help

  Usage: help()
  Desc: print help of this script
  Ret: none
  Args: none
  Side_Effects: exit of the script
  Example: if (!@ARGV) {
               help();
           }

=cut

sub help {
  print STDERR <<EOF;
  $0: 

    Description: 

       This script parse the sample_dbload files and load the data into the 
     database. It will insert data into biosource schema, in the tables 
     bs_sample, bs_sample_file, bs_sample_pub, bs_sample_cvterm, 
     bs_sample_dbxref and bs_sample_relationship.

       To add relations with publications, dbxrefs or cvterms, it needs that
     exists this publication.title, dbxref.accession and cvterm.name in their
     respective tables.

       Also youb can run it with -T test mode.

       Note about -T (Test mode): You can run test mode in two ways. The first 
     using -T parameter and the second login to the database as web_usr. In this 
     mode the ids that this script will return comes from the simulation of 
     new _id_seq (get the current id_seq in an object). 

    Usage: 
       sample_dbload [-h] [-X] -u <loadername> -D <dbname> -H <dbhost> -U <dbuser> 
                     -V <dbdriver> -s <sample_file> [-T]

      To collect the data loaded report into a file:

       sample_dbload [-h] [-X] -D <dbname> -H <dbhost> -s <sample_file> [-T] 
                               > file.log

    Example: 
      perl sample_dbload.pl -u aure -H localhost -D sandbox -s solanaceae.bs

    Flags:
      -u loader username      loader username (mandatory)
      -H database hostname    database hostname for example localhost (mandatory)
      -D database name        database name for example (mandatory)
      -U database username    database username with insert priviledges over biosource schema (mandatory)
      -V database driver      database driver for DBI (Pg for postgres by default)
      -s sample file          data load file input file (mandatory)
      -T run as test          run this script as a test
      -X create dataload file create a template for a data load file (follow the instructions to fill it)
      -h this help

EOF
exit (1);
}


################################
### GENERAL DATABASE METHODS ###
################################

=head2 commit_prompt

 Usage: commit_prompt($schema, $set_tableseq_href, $prompt_message, $after_message);
 Desc: ask if you want commit or rollback the changes in the database. If the answer (STDIN) is yes, commit the changes.
 Ret: none
 Args: $dbh (database conection object), $prompt_message and $after_message are object to print a message during prompt
       and after the answer. $initials_tableseq_href is an hash reference with keys=name of the sequence of a concrete
       table and values=current value before the process. It will be used if the option choosed is rollback.
 Side_Effects: print message
 Example: commit_prompt($schema, $initials_table_seq_href);

=cut

sub commit_prompt {
  my ($schema, $seqvalues_href, $prompt_message, $after_message) = @_;
  unless ($prompt_message) {
    $prompt_message = "Commit?\n(yes|no, default no)> ";
  }
  print STDERR $prompt_message;

  ## Ask the question... commit or rollback

  if (<STDIN> =~ m/^y(es)/i) {

      ## If is yes... commit

      print STDERR "Committing...\n\n";
      $schema->txn_commit;
      print "okay.\n";
      if ($after_message) {
	  print STDERR $after_message;
      }
  } else {
      
      ## If it is no, rollback and set the database sequences values to the initial values

      print STDERR "Rolling back...\n\n";
      $schema->set_sqlseq($seqvalues_href);
      $schema->txn_rollback;
      print STDERR "done.\n\n";
  }
}



=head2 print_sample_template

  Usage: print_sample_template()
  Desc: print a sample_template file
  Ret: none
  Args: none
  Side_Effects: create a file and exit of the script
  Example:

=cut

sub print_sample_template {
    my $dir = `pwd`;
    chomp($dir);
    my $template_sample_file = $dir . '/sample_load_file.bs';
    open my $TFH, '>', $template_sample_file || die("Sorry, I can not open the file: $template_sample_file.\n");

    print STDERR "PRINT SEDM DATA LOAD FILE option...\n";
    my $info = '# Notes for the Source data load to Biosource sample ()
#
#	Data stingency keys:
#
#		Load the data in a flat file with different data types. The data to load will should be between [data]. 
#		 - Mandatory => means that you should have a data in this field to load in the database.
#		 - Optional  => this field could be empty
#		 - Single    => this field can have only one data
#		 - Multiple  => this field can have more than one data separated by comma
#		 
#
# NOTE FOR DATABASE CURATORS: To load all this data into the database, use the sedm_sources_dbload.pl script
#


#####################################################################################
# SAMPLE_DATA #######################################################################
# FIELD	#		# DATA #	# DATA_STRINGENCY #	# EXAMPLE_AND_NOTES #
#####################################################################################

## To add a new sample (MANDATORY):

*DATA_TYPE:		[]		#mandatory,single	example:[sample]
*SAMPLE_NAME:		[]		#mandatory,single,f1	example:[Tomato fruits treated with SA]
*ALTERNATIVE_NAME:      []              #optional,single        example:[TomFrutSA_01]
*SAMPLE_TYPE_NAME:      []              #mandatory,single,f1    example:[one colour microarray target]
*SAMPLE_DESCRIPTION: 	[]		#optional,single	example:[1mM salicylic acid were applied to...]
*ORGANISM_NAME:         []              #optional,single        example:[Solanum lycopersicum]
*STOCK_NAME:            []              #optional,single        example:[Microtom]
*PROTOCOL_NAME:         []              #optional,single        example:[mRNA extraction]
*CONTACT_NAME:          []              #optional,single        example:[Bombarely, Aureliano]
//

## To associate a publication to an existing sample:

*DATA_TYPE:             []              #mandatory              example:[pub]
*SAMPLE_NAME:		[]		#mandatory,single,fl	example:[Tomato fruits treated with SA]
*TITLE:                 []              #mandatory              example:[The example of the pub]
//

## To associate ontologies as dbxrefs (to store more than one dbxref with different dbname can be used more entries)

*DATA_TYPE:	        []              #mandatory,single	example:[dbxref]
*SAMPLE_NAME:           []              #mandatory,single       example:[Sl_RF_SAt001]
*DBNAME:                []              #mandatory,single       example:[PO]
*ACCESSIONS:		[]		#mandatory,multiple     example:[0000077,0002003]
//
  
## To associate tags as cvterms (terms suggested: Normalized, Sustracted...)

*DATA_TYPE:	        []              #mandatory,single	example:[cvterm]
*SAMPLE_NAME:           []              #mandatory,single       example:[Sl_RF_SAt001]
*CVTERM:		[]		#mandatory,multiple     example:[Normalized,Sustracted]
//

## To associate files to a sample

*DATA_TYPE:	        []              #mandatory,single	example:[file]
*SAMPLE_NAME:           []              #mandatory,single       example:[Sl_RF_SAt001]
*FILENAME:              []              #mandatory,single       example:[/transcriptome/tomato/SlRf.fasta]
//

## To associate two samples between them

*DATA_TYPE:	        []              #mandatory,single	example:[relationship]
*OBJECT_SAMPLE_NAME:    []              #mandatory,single       example:[Sl_RF_SAt001]
*SUBJECT_SAMPLE_NAME:   []              #mandatory,single       example:[Sl_RF_SAt002]
*RELATIONSHIP_TYPE:     []              #mandatory,single       example:[mRNA extraction]
*RANK:                  []              #mandatory,single       example:[1]
*NOTES:                 []              #optional,single        example:[sample processing to extract rna]
//
          
';

    print $TFH "$info";
    print STDERR "...done (printed sample_file with the name: $template_sample_file)\n\n";
    exit (1);
}




####
1;##
####
