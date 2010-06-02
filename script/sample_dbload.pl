
#!/usr/bin/perl
=head1 NAME

 sample_dbload.pl
 A script to parse sample file and load in a database for biosource schema (version.0.1.).

=cut

=head1 SYPNOSIS

 sample_dbload.pl [-h] -U <load_username> -H <dbhost> -D <dbname> -s <sample_file> [-T] [-X]

  To collect the data loaded report into a file:

 sample_dbload [-h] [-X] -D <dbname> -H <dbhost> -s <sample_file> [-T] > file.log


=head1 EXAMPLE:

 perl sample_dbload.pl -u aure -H localhost -D sandbox -s solanaceae_comparisson.bs
        
    
=head2 I<Flags:>

=over

=item -s

B<data load file>               data load file in bs format (mandatory).

=item -H

B<database_host>                database host (mandatory if you want check the relations in the database)

=item -D

B<database_name>                database name (mandatory if you want check the relations in the database)

=item -X

B<print data load file>         print a template with examples of the data load file in bs format

=item -T

B<run as a test>                run the script as test

=item -h

B<help>                         print the help  

=back

=cut

=head1 DESCRIPTION

    This script parse the sample_dbload files and load the data into the database. Also youb can run it with -T test mode.

    Note about -T (Test mode): You can run test mode in two ways. The first using -T parameter and the second login to
                               the database as web_usr. In this mode the ids that this script will return comes from
                               the simulation of new _id_seq (get the current id_seq in an object and add using $v++). 
 
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
use CXGN::Biosource::Schema;
use CXGN::Biosource::Sample;
use CXGN::DB::InsertDBH;
use CXGN::Metadata::Metadbdata;

our ($opt_u, $opt_H, $opt_D, $opt_s, $opt_T, $opt_X, $opt_h);
getopts("u:H:D:s:TXh");
if (!$opt_u && !$opt_H && !$opt_D && !$opt_s && !$opt_T && !$opt_X && !$opt_h) {
    print "There are n\'t any tags. Print help\n\n";
    help();
} elsif ($opt_h) {
    help();
} elsif ($opt_X) {
    print_sample_template();
}

## Checking the input arguments

my $loader_username = $opt_u || die("MANDATORY ARGUMENT ERROR: The -u <loader_username> argument was not supplied.\n");
my $dbname = $opt_D || die("MANDATORY ARGUMENT ERROR: The -D <database_name> argument was not supplied.\n");
my $dbhost = $opt_H || die("MANDATORY ARGUMENT ERROR: The -H <db_hostname> argument was not supplied.\n"); 
my $sample_file = $opt_s || die("MANDATORY ARGUMENT ERROR: The -s <sample_dataload_file> argument was not supplied.\n");

## Connecting with the database

my $dbh =  CXGN::DB::InsertDBH->new({ dbname => $dbname, dbhost => $dbhost })->get_actual_dbh();

## The triggers need to set the search path to tsearch2 in the version of psql 8.1
my $psqlv = `psql --version`;
chomp($psqlv);

my $schema_list = 'biosource,metadata,public';
if ($psqlv =~ /8\.1/) {
    $schema_list .= ',tsearch2';
}

print STDERR "\nStep 1: Connect with the database.\n";

my $schema = CXGN::Biosource::Schema->connect( sub { $dbh },
                                         { on_connect_do => ["SET search_path TO $schema_list;"] },
                                        );

## Getting the last ids for the different tables to set the database sequences values in case of rollback 
## or something wrong during the test

print STDERR "\nStep 2: Get the last ids for each table.\n";

my $all_last_ids_href = $schema->get_all_last_ids();


## Parse the sample_file and transfer the data to sample objects

print STDERR "\nStep 3: Open and parse the sample file.\n";

open my $ifh, '<', $sample_file || die("Sorry, but I can not open the input file: $sample_file.\n");

my $l = 0;

## The input file can store more than one sample. Multiple samples will be stored as a hash
## with keys=sample_name and values=sample object

my %samples;

## Each data field will be defined by $data_type variable, also will be define $sample_name and $sample_element_name.

my ($dt, $sample_name, $sample_element_name, $db_id);

while(<$ifh>) {
		
    $l++; ## Line counter

    ## It will do not read any line that start with #
    unless ($_ =~ m/^#/) {
	
	## First define the data_type
	
	if ($_ =~ m/\*DATA_TYPE:\s+\[(\w+)\]/) {
	    $dt = $1;
	}
	elsif ($_ =~ m/\/\//) {
	    $dt = '';
	    $sample_name = '';
	    $sample_element_name = '';
	    $db_id = '';
	}
	
	my $sample_list = join(',', keys %samples);

	## Parse sample and set the data in an object

	if (defined $dt) {
	    if ($dt eq 'sample') {
		if ($_ =~ m/\*SAMPLE_NAME:\s+\[(.+)\]/) {
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
		elsif ($_ =~ m/\*SAMPLE_TYPE:\s+\[(.+)\]/) {
		    my $sample_type = $1 ||
			die("MANDATORY DATA ERROR (line $l): None sample_type data was detailed in sample section.\n");
		    
		    $samples{$sample_name}->set_sample_type($sample_type);
		}
		elsif ($_ =~ m/\*SAMPLE_DESCRIPTION:\s+\[(.+)\]/ ) {
		    my $sample_description = $1;
		    
		    if (defined $sample_description) {
			$samples{$sample_name}->set_description($sample_description);
		    }
		}
		elsif ($_ =~ m/\*CONTACT_NAME:\s+\[(.+)\]/ ) {
		    my $contact_name = $1;
		    
		    if (defined $contact_name) {
			
			## If contact name has comma (,) the format will be $last_name and $first name, if it have an space will be
			## first_name and last_name. This will use a simple SQL search but should be replaced by a DBIx.
			
			my ($first_name, $last_name);
			if ($contact_name =~ m/,/) {
			    my @user = split(/,/, $contact_name);
			    $first_name = "'%" . $user[1] . "%'";
			    $last_name = "'%" . $user[0] . "%'";
			}
			else {
			    my @user = split(/ /, $contact_name);
			    $first_name = shift(@user);
			    $last_name = join(' ', @user);
			    
			}
			
			my $query = "SELECT sp_person_id FROM sgn_people.sp_person WHERE first_name ILIKE ? AND last_name ILIKE ?";
			my $sth = $dbh->prepare($query);
			$sth->execute($first_name, $last_name);
			my ($sp_person_id) = $sth->fetchrow_array();
			
			if (defined $sp_person_id) {
			    $samples{$sample_name}->set_contact_id($sp_person_id);
			}
			else {
			    warn("OPTIONAL DATA WARNING (line $l): Contact_name=$contact_name do not exists db.\n");
			}
		    }
		}
	    }
	    elsif ($dt eq 'pub') {
		if ($_ =~ m/\*SAMPLE_NAME:\s+\[(.+)\]/) {
		    $sample_name = $1 ||
			die("MANDATORY DATA ERROR (line $l): None sample_name data was detailed in pub section.\n");
		    unless (defined $samples{$sample_name}) {		
			die("MANDATORY DATA ERROR (line $l): None sample_name data match with currente sample_list ($sample_list).\n");
		    }
		}
		elsif ($_ =~ m/\*TITLE:\s+\[(.+)\]/) {
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
	    elsif ($dt eq 'sample_element') {
		if ($_ =~ m/\*SAMPLE_NAME:\s+\[(.+)\]/) {
		    $sample_name = $1 ||
			die("MANDATORY DATA ERROR (line $l): None sample_name data was detailed in sample_element section.\n");
		    unless (defined $samples{$sample_name}) {		
			die("MANDATORY DATA ERROR (line $l): None sample_name data match with currente sample_list ($sample_list).\n");
		    }
		}
		elsif ($_ =~ m/\*SAMPLE_ELEMENT_NAME:\s+\[(.+)\]/) {
		    $sample_element_name = $1 ||
			die("MANDATORY DATA ERROR (line $l): None sample_element_name data was detailed in sample_element section.\n");
		    
		    my %sample_elements = $samples{$sample_name}->get_sample_elements();

		    if (defined $sample_elements{$sample_element_name}) {
			warn("\nSKIP WARNING: Sample_element:$sample_element_name exists associated to sample=$sample_name.\n");
		    }
		    else {
			$samples{$sample_name}->add_sample_element( { sample_element_name => $sample_element_name } );
		    }
		}
		elsif ($_ =~ m/\*ALTERNATIVE_NAME:\s+\[(.+)\]/) {
		    my $alt_name = $1;
		    
		    if (defined $alt_name) {
			$samples{$sample_name}->edit_sample_element(
			                                             $sample_element_name, 
			                                             { alternative_name => $alt_name }
			                                           );
		    }
		}
		elsif ($_ =~ m/\*SAMPLE_ELEMENT_DESCR:\s+\[(.+)\]/) {
		    my $element_descript = $1;
		    
		    if (defined $element_descript) {
			$samples{$sample_name}->edit_sample_element(
			                                             $sample_element_name, 
			                                             { description => $element_descript }
			                                           );
		    }
		}
		elsif ($_ =~ m/\*ORGANISM_NAME:\s+\[(.+)\]/) {
		    my $organism_name = $1;
		    if (defined $organism_name) {
			$samples{$sample_name}->edit_sample_element(
			                                             $sample_element_name, 
				      		   		     { organism_name => $organism_name }
                                                                   );
		    }
		}
		elsif ($_ =~ m/\*STOCK_NAME:\s+\[(.+)\]/) {
		    my $stock_name = $1;
		    
		    if (defined $stock_name) {
			$samples{$sample_name}->edit_sample_element(
			                                             $sample_element_name, 
				 				     { stock_name => $stock_name }
                                                                   );
		    }
		}
		elsif ($_ =~ m/\*PROTOCOL_NAME:\s+\[(.+)\]/) {
		    my $alt_name = $1;
		    
		    if (defined $alt_name) {
			$samples{$sample_name}->edit_sample_element(
			                                             $sample_element_name, 
				   				     { alternative_name => $alt_name }
			                                           );
		    }
		}
	    }
	    elsif ($dt eq 'element_cvterm') {
		if ($_ =~ m/\*SAMPLE_NAME:\s+\[(.+)\]/) {
		    $sample_name = $1 ||
			die("MANDATORY DATA ERROR (line $l): None sample_name data was detailed in element_cvterm section.\n");
		    unless (defined $samples{$sample_name}) {		
			die("MANDATORY DATA ERROR (line $l): None sample_name data match with currente sample_list ($sample_list).\n");
		    }
		}
		elsif ($_ =~ m/\*SAMPLE_ELEMENT_NAME:\s+\[(.+)\]/) {
		    $sample_element_name = $1 ||
			die("MANDATORY DATA ERROR (line $l): None sample_element_name data was detailed in element_cvterm section.\n");
		}
		elsif ($_ =~ m/\*CVTERM:\s+\[(.+)\]/) {
		    my $cvterm = $1 ||
			die("MANDATORY DATA ERROR (line $l): None cvterm data was detailed in element_cvterm section.\n");
		    
		    my ($cvterm_row) = $schema->resultset('Cv::Cvterm')
			                      ->search( { name => $cvterm } );

		    if (defined $cvterm_row) {
			my $cvterm_id = $cvterm_row->get_column('cvterm_id');
			    
			my %samplelements_cvterm = $samples{$sample_name}->get_cvterm_from_sample_elements();
			    
			my $cvtermmatch = 0;
			my $cvterm_aref = $samplelements_cvterm{$sample_element_name};
			
			if (defined $cvterm_aref) {
			    my @cvterm_ids = @{ $cvterm_aref };
			    foreach my $prev_cvterm_id (@cvterm_ids) {
				if ($cvterm_id == $prev_cvterm_id) {
				    $cvtermmatch = 1;
				}
			    }
			}
			if ($cvtermmatch == 0) {
			    $samples{$sample_name}->add_cvterm_to_sample_element( $sample_element_name, 
										  $cvterm_id );
			}
			else {
			    warn("\nSKIP WARNING: cvterm=$cvterm exists associated to element_name:$sample_element_name.\n");
			}		    
		    }
		    else {
			warn("MANDATORY DATA ERROR (line $l): Cvterm=$cvterm do not exists in db.\n");
		    }
		} 
	    }
	    elsif ($dt eq 'element_dbxref') {
		if ($_ =~ m/\*SAMPLE_NAME:\s+\[(.+)\]/) {
		    $sample_name = $1 ||
			die("MANDATORY DATA ERROR (line $l): None sample_name data was detailed in element_dbxref section.\n");
		    unless (defined $samples{$sample_name}) {		
			die("MANDATORY DATA ERROR (line $l): None sample_name data match with currente sample_list ($sample_list).\n");
		    }
		}
		elsif ($_ =~ m/\*SAMPLE_ELEMENT_NAME:\s+\[(.+)\]/) {
		    $sample_element_name = $1 ||
			die("MANDATORY DATA ERROR (line $l): None sample_element_name data was detailed in element_dbxref section.\n");
		}
		elsif ($_ =~ m/\*DBNAME:\s+\[(.+)\]/) {
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
		elsif ($_ =~ m/\*ACCESSIONS:\s+\[(.+)\]/) {
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

			    my %samplelements_dbxref = $samples{$sample_name}->get_dbxref_from_sample_elements();
			    
			    my $dbxrefmatch = 0;
			    my $dbxref_aref = $samplelements_dbxref{$sample_element_name};

			    if (defined $dbxref_aref) {
				my @dbxref_ids = @{ $dbxref_aref };
				foreach my $prev_dbxref_id (@dbxref_ids) {
				    if ($dbxref_id == $prev_dbxref_id) {
					$dbxrefmatch = 1;
				    }
				}
			    }
			    if ($dbxrefmatch == 0) {
				$samples{$sample_name}->add_dbxref_to_sample_element( $sample_element_name, 
										      $dbxref_id );
			    }
			    else {
				warn("\nSKIP WARNING: Dbxref-access=$acc exist associated to element_name:$sample_element_name.\n");
			    }
			}
			else {
			    die("MADATORY DATA ERROR (line $l): Dbxref=$dbname do not exists in db.\n");
			}
		    } 
		}
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
	    my $t_sample_type = $samples{$samplename}->get_sample_type() || 'undef';
	    my $t_description =  $samples{$samplename}->get_description() || 'undef';
	    my $t_contact_id = $samples{$samplename}->get_contact_id() || 'undef';
	    print STDOUT "+ SAMPLE_DATA:\n\tsample_id =\t$t_sample_id\n";
	    print STDOUT "\tsample_name =\t$t_sample_name\n";
	    print STDOUT "\tsample_type =\t$t_sample_type\n";
	    print STDOUT "\tdescription =\t$t_description\n";
	    print STDOUT "\tcontact_id =\t$t_contact_id\n\n";
	
	    print STDOUT "  * Associated publications:\n";
	    my @pub_title_list = $samples{$samplename}->get_publication_list('title');
	    foreach my $pub (@pub_title_list) {
		print STDOUT "\t\tpub_title: $pub\n";
	    }

	    print STDOUT "\n";
	    print STDOUT "  * Associated sample_elements:\n";
	    my %sample_elements = $samples{$samplename}->get_sample_elements();
	    my %samplelementscvterm_p = $samples{$samplename}->get_cvterm_from_sample_elements();
	    my %samplelementsdbxref_p = $samples{$samplename}->get_dbxref_from_sample_elements();
	    
	    foreach my $sample_el (sort keys %sample_elements) {
		my %element_data = %{ $sample_elements{$sample_el}};
		print STDOUT "\n";
		foreach my $column (sort keys %element_data) {
		    my $data = $element_data{$column} || 'undef';
		    print STDOUT "\t\t$column:\t$data\n";
		}
	    
		my $cvterm_aref_p = $samplelementscvterm_p{$sample_el};
		my $cvterm_list = 'undef';
		if (defined $cvterm_aref_p) {
		    my @sample_el_cvterms = @{ $cvterm_aref_p };
		    my $cvterm_list = join(',', @sample_el_cvterms);
		    print STDOUT "\t\tcvterm_id_list:\t$cvterm_list\n";
		}
	    
		my $dbxref_aref_p = $samplelementsdbxref_p{$sample_el};
		my $dbxref_list = 'undef';
		if (defined $dbxref_aref_p) {
		    my @sample_el_dbxrefs = @{ $dbxref_aref_p };
		    my $dbxref_list = join(',', @sample_el_dbxrefs);
		    print STDOUT "\t\tdbxref_id_list:\t$dbxref_list\n";
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

    $schema->txn_rollback;
    $schema->set_sqlseq_values_to_original_state($all_last_ids_href);

} else {
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
	my $t_sample_type = $samples{$samplename}->get_sample_type() || 'undef';
	my $t_description =  $samples{$samplename}->get_description() || 'undef';
	my $t_contact_id = $samples{$samplename}->get_contact_id() || 'undef';
	print STDOUT "+ SAMPLE_DATA:\n\tsample_id =\t$t_sample_id\n";
	print STDOUT "\tsample_name =\t$t_sample_name\n";
	print STDOUT "\tsample_type =\t$t_sample_type\n";
	print STDOUT "\tdescription =\t$t_description\n";
	print STDOUT "\tcontact_id =\t$t_contact_id\n\n";
	
	print STDOUT "  * Associated publications:\n";
	my @pub_title_list = $samples{$samplename}->get_publication_list('title');
	foreach my $pub (@pub_title_list) {
	    print STDOUT "\t\tpub_title: $pub\n";
	}

	print STDOUT "\n";
	print STDOUT "  * Associated sample_elements:\n";
	my %sample_elements = $samples{$samplename}->get_sample_elements();
	my %samplelementscvterm_p = $samples{$samplename}->get_cvterm_from_sample_elements();
	my %samplelementsdbxref_p = $samples{$samplename}->get_dbxref_from_sample_elements();
	
	foreach my $sample_el (sort keys %sample_elements) {
	    my %element_data = %{ $sample_elements{$sample_el}};
	    print STDOUT "\n";
	    foreach my $column (sort keys %element_data) {
		my $data = $element_data{$column} || 'undef';
		print STDOUT "\t\t$column:\t$data\n";
	    }
	    
	    my $cvterm_aref_p = $samplelementscvterm_p{$sample_el};
	    my $cvterm_list = 'undef';
	    if (defined $cvterm_aref_p) {
		my @sample_el_cvterms = @{ $cvterm_aref_p };
		my $cvterm_list = join(',', @sample_el_cvterms);
		print STDOUT "\t\tcvterm_id_list:\t$cvterm_list\n";
	    }
	    
	    my $dbxref_aref_p = $samplelementsdbxref_p{$sample_el};
	    my $dbxref_list = 'undef';
	    if (defined $dbxref_aref_p) {
		my @sample_el_dbxrefs = @{ $dbxref_aref_p };
		my $dbxref_list = join(',', @sample_el_dbxrefs);
		print STDOUT "\t\tdbxref_id_list:\t$dbxref_list\n";
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
      This script load data for samples

      In a .bs format (text format with fields delimited by [] ). To print a template file use the -X option and fill following the
      instructions. The load data file can have one or more of these data types.

    
    Usage: 
       sample_dbload [-h] [-X] -D <dbname> -H <dbhost> -s <sample_file> [-T]

      To collect the data loaded report into a file:

       sample_dbload [-h] [-X] -D <dbname> -H <dbhost> -s <sample_file> [-T] > file.log

    Example: 
      perl sample_dbload.pl -u aure -H localhost -D sandbox -s solanaceae_comparisson.bs


    Flags:
      -u loader username      loader username (mandatory)
      -H database hostname    for example localhost or db.sgn.cornell.edu (mandatory for check domains in the database)
      -D database name        sandbox or cxgn etc (mandatory for check domains in the database)
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
      $schema->set_sqlseq_values_to_original_state($seqvalues_href);
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
*SAMPLE_NAME:		[]		#mandatory,single,fl	example:[Tomato fruits treated with SA]
*SAMPLE_TYPE:           []              #mandatory,single,f1    example:[one colour microarray target]
*SAMPLE_DESCRIPTION: 	[]		#optional,single	example:[1mM salicylic acid were applied to...]
*CONTACT_NAME:          []              #optional,single        example:[Bombarely, Aureliano]
//

## To associate a publication to an existing sample:

*DATA_TYPE:             []              #mandatory              example:[pub]
*SAMPLE_NAME:		[]		#mandatory,single,fl	example:[Tomato fruits treated with SA]
*TITLE:                 []              #mandatory              example:[The example of the pub]
//

## To add a sample_element to an existing sample:

*DATA_TYPE:             []              #mandatory,single       example:[sample_element]
*SAMPLE_NAME:		[]		#mandatory,single,fl	example:[Tomato fruits treated with SA]
*SAMPLE_ELEMENT_NAME:   []              #mandatory,single       example:[Sl_RF_SAt001]
*ALTERNATIVE_NAME:      []              #optional,single  	example:[S.lycopersicum red fruit treated with SA]
*SAMPLE_ELEMENT_DESCR:  []              #optional,single	example:[One of the three element samples...]
*ORGANISM_NAME:         []              #optional,single        example:[Solanum lycopersicum]
*STOCK_NAME:            []              #optional,single        example:[Microtom]
*PROTOCOL_NAME:         []              #optional,single        example:[mRNA extraction]
//
  
## To associate tags as cvterms (terms suggested: Normalized, Sustracted...)

*DATA_TYPE:	        []              #mandatory,single	example:[cvterm]
*SAMPLE_ELEMENT_NAME:   []              #mandatory,single       example:[Sl_RF_SAt001]
*CVTERM:		[]		#mandatory,multiple     example:[Normalized,Sustracted]
//

## To associate ontologies as dbxrefs (to store more than one dbxref with different dbname can be used more entries)

*DATA_TYPE:	        []              #mandatory,single	example:[dbxref]
*SAMPLE_ELEMENT_NAME:   []              #mandatory,single       example:[Sl_RF_SAt001]
*DBNAME:                []              #mandatory,single       example:[PO]
*ACCESSIONS:		[]		#mandatory,multiple     example:[0000077,0002003]
//';

    print $TFH "$info";
    print STDERR "...done (printed sample_file with the name: $template_sample_file)\n\n";
    exit (1);
}




####
1;##
####
