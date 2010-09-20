
#!/usr/bin/perl
=head1 NAME

 protocol_dbload.pl
 A script to parse protocol file and load in a database for biosource schema (version.0.1.).

=cut

=head1 SYPNOSIS

 protocol_dbload.pl [-h] -U <load_username> -H <dbhost> -D <dbname> -U <dbuser> [-V <dbdriver>]
                         -p <protocol_file> [-T] [-X]

  To collect the data loaded report into a file:

 protocol_dbload [-h] [-X] -D <dbname> -H <dbhost> -U <dbuser> -p <protocol_file> [-T] > file.log


=head1 EXAMPLE:

 perl protocol_dbload.pl -u aure -H localhost -D sandbox -p RNA_extraction_protocol.bs
        
    
=head2 I<Flags:>

=over

=item -p

B<data load file>               data load file in bs format (mandatory).

=item -H

B<database_host>                database host (mandatory if you want check the relations in the database)

=item -U

B<database_user>                database user (mandatory)

=item -D

B<database_name>                database name (mandatory if you want check the relations in the database)

=item -V

B<database_driver>              database driver (Pg (postgres) by default)

=item -X

B<print data load file>         print a template with examples of the data load file in sedm format

=item -T

B<run as a test>                run the script as test

=item -h

B<help>                         print the help  

=back

=cut

=head1 DESCRIPTION

    This script parse the protocol dbload files and load the data into the database. Also youb can run it with -T test mode.

    Note about -T (Test mode): You can run test mode in two ways. The first using -T parameter and the second login to
                               the database as web_usr. In this mode the ids that this script will return comes from
                               the simulation of new _id_seq (get the current id_seq in an object and add using $v++). 
 
=cut

=head1 AUTHORS

  Aureliano Bombarely Gomez.
  (ab782@cornell.edu).

=cut

=head1 METHODS

protocol_dbload.pl


=cut

use strict;
use warnings;

use File::Basename;
use Getopt::Std;
use Term::ReadKey;

use CXGN::Biosource::Schema;
use CXGN::Biosource::Protocol;
use CXGN::DB::InsertDBH;
use CXGN::Metadata::Metadbdata;

our ($opt_u, $opt_H, $opt_D, $opt_U, $opt_V, $opt_p, $opt_T, $opt_X, $opt_h);
getopts("u:H:D:U:V:p:TXh");
if (!$opt_u && !$opt_H && !$opt_D && !$opt_U && !$opt_V && !$opt_p && !$opt_T && !$opt_X && !$opt_h) {
    print "There are n\'t any tags. Print help\n\n";
    help();
} elsif ($opt_h) {
    help();
} elsif ($opt_X) {
    print_protocol_template();
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
my $protocol_file = $opt_p 
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
					       { 
						   on_connect_do => ["SET search_path TO $schema_list;"]
					       },
                                             );
$schema->txn_begin;


## Getting the last ids for the different tables to set the database sequences values in case of rollback 
## or something wrong during the test

print STDERR "\nStep 2: Get the last ids for each table.\n";

my $last_ids_href = $schema->get_last_id();
my %last_ids = %{$last_ids_href};


## Parse the sample_file and transfer the data to sample objects

print STDERR "\nStep 3: Open and parse the sample file.\n";

open my $ifh, '<', $protocol_file || die("Sorry, but I can not open the input file: $protocol_file.\n");

my $l = 0;

## The input file can store more than one sample. Multiple samples will be stored as a hash
## with keys=sample_name and values=sample object

my %protocols;

## Each data field will be defined by $data_type variable, also will be define $sample_name and $sample_element_name.

my ($dt, $protocol_name, $protocol_step, $db_id);

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
	    $protocol_name = '';
	    $protocol_step = '';
	    $db_id = '';
	}
	
	my $protocol_list = join(',', keys %protocols);

	## Parse sample and set the data in an object

	if (defined $dt) {
	    if ($dt eq 'protocol') {
		if ($_ =~ m/\*PROTOCOL_NAME:\s+\[(.+)\]/) {
		    $protocol_name = $1 ||
			die("MANDATORY DATA ERROR (line $l): None sample_name data was detailed.\n");
		    
		    my $protocol_obj;
		    my ($protocol_row) = $schema->resultset('BsProtocol')
			                        ->search({ protocol_name => $protocol_name});
		    if (defined $protocol_row) {
			$protocol_obj = CXGN::Biosource::Protocol->new_by_name($schema, $protocol_name);
		    }
		    else {
			$protocol_obj = CXGN::Biosource::Protocol->new($schema);
			$protocol_obj->set_protocol_name($protocol_name);
		    }
		    
		    $protocols{$protocol_name} = $protocol_obj;
		}
		elsif ($_ =~ m/\*PROTOCOL_TYPE:\s+\[(.+)\]/) {
		    my $protocol_type = $1 ||
			die("MANDATORY DATA ERROR (line $l): None protocol_type data was detailed in protocol section.\n");
		    
		    $protocols{$protocol_name}->set_protocol_type($protocol_type);
		}
		elsif ($_ =~ m/\*PROTOCOL_DESCRIPTION:\s+\[(.+)\]/ ) {
		    my $protocol_description = $1;
		    
		    if (defined $protocol_description) {
			$protocols{$protocol_name}->set_description($protocol_description);
		    }
		}
	    }
	    elsif ($dt eq 'pub') {
		if ($_ =~ m/\*PROTOCOL_NAME:\s+\[(.+)\]/) {
		    $protocol_name = $1 ||
			die("MANDATORY DATA ERROR (line $l): None protocol_name data was detailed in pub section.\n");
		    unless (defined $protocols{$protocol_name}) {		
			die("MANDATORY DATA ERROR (line $l): None protocol_name data match with curr. protocol_list ($protocol_list).\n");
		    }
		}
		elsif ($_ =~ m/\*TITLE:\s+\[(.+)\]/) {
		    my $title = $1 ||
			die("MANDATORY DATA ERROR (line $l): None title data was detailed in pub section.\n");
		    
		    my $match;
		    my @pub_list = $protocols{$protocol_name}->get_publication_list('title');
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
			$protocols{$protocol_name}->add_publication( { title => $title } );
		    }
		    else {
			warn("\nThe pub=$title match with a previous publication\n\t($match).\n\tIt will not be added.\n");
		    }
		}
	    }
	    elsif ($dt eq 'protocol_step') {
		if ($_ =~ m/\*PROTOCOL_NAME:\s+\[(.+)\]/) {
		    $protocol_name = $1 ||
			die("MANDATORY DATA ERROR (line $l): None protocol_name data was detailed in protocol_element section.\n");
		    unless (defined $protocols{$protocol_name}) {		
			die("MANDATORY DATA ERROR (line $l): None protocol_name data match with curr. protocol list ($protocol_list).\n");
		    }
		}
		elsif ($_ =~ m/\*STEP:\s+\[(.+)\]/) {
		    $protocol_step = $1 ||
			die("MANDATORY DATA ERROR (line $l): None step data was detailed in protocol_step section.\n");
		    
		    my %protocol_steps = $protocols{$protocol_name}->get_protocol_steps();

		    if (defined $protocol_steps{$protocol_step}) {
			warn("\nSKIP WARNING: Step:$protocol_step exists associated to protocol=$protocol_name.\n");
		    }
		    else {
			$protocols{$protocol_name}->add_protocol_step( { step => $protocol_step } );
		    }
		}
		elsif ($_ =~ m/\*ACTION:\s+\[(.+)\]/) {
		    my $action = $1;
		    
		    if (defined $action) {
			$protocols{$protocol_name}->edit_protocol_step(
			                                                $protocol_step, 
			                                                { action => $action }
			                                              );
		    }
		}
		elsif ($_ =~ m/\*EXECUTION:\s+\[(.+)\]/) {
		    my $execution = $1;
		    
		    if (defined $execution) {
			$protocols{$protocol_name}->edit_protocol_step(
			                                                $protocol_step, 
			                                                { execution => $execution }
			                                              );
		    }
		}
		elsif ($_ =~ m/\*TOOL_NAME:\s+\[(.+)\]/) {
		    my $tool_name = $1;
		    if (defined $tool_name) {
			$protocols{$protocol_name}->edit_protocol_step(
			                                                $protocol_step, 
				      		   		        { tool_name => $tool_name }
                                                                      );
		    }
		}
		elsif ($_ =~ m/\*BEGIN_DATE:\s+\[(.+)\]/) {
		    my $begin_date = $1;
		    
		    if (defined $begin_date) {
			$protocols{$protocol_name}->edit_protocol_step(
			                                                $protocol_step, 
				 				        { begin_date => $begin_date }
                                                                      );
		    }
		}
		elsif ($_ =~ m/\*END_DATE:\s+\[(.+)\]/) {
		    my $end_date = $1;
		    
		    if (defined $end_date) {
			$protocols{$protocol_name}->edit_protocol_step(
			                                                $protocol_step, 
				 				        { end_date => $end_date }
                                                                      );
		    }
		}
		elsif ($_ =~ m/\*LOCATION:\s+\[(.+)\]/) {
		    my $location = $1;
		    
		    if (defined $location) {
			$protocols{$protocol_name}->edit_protocol_step(
			                                                $protocol_step, 
				   				        { location => $location }
			                                              );
		    }
		}
	    }
	    elsif ($dt eq 'step_dbxref') {
		if ($_ =~ m/\*PROTOCOL_NAME:\s+\[(.+)\]/) {
		    $protocol_name = $1 ||
			die("MANDATORY DATA ERROR (line $l): None protocol_name data was detailed in element_dbxref section.\n");
		    unless (defined $protocols{$protocol_name}) {		
			die("MANDATORY DATA ERROR (line $l): None protocol_name data match with curr. protocol_list ($protocol_list).\n");
		    }
		}
		elsif ($_ =~ m/\*STEP:\s+\[(.+)\]/) {
		    $protocol_step = $1 ||
			die("MANDATORY DATA ERROR (line $l): None step data was detailed in element_dbxref section.\n");
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

			    my %protocolstep_dbxref = $protocols{$protocol_name}->get_dbxref_from_protocol_steps();
			    
			    my $dbxrefmatch = 0;
			    my $dbxref_aref = $protocolstep_dbxref{$protocol_step};

			    if (defined $dbxref_aref) {
				my @dbxref_ids = @{ $dbxref_aref };
				foreach my $prev_dbxref_id (@dbxref_ids) {
				    if ($dbxref_id == $prev_dbxref_id) {
					$dbxrefmatch = 1;
				    }
				}
			    }
			    if ($dbxrefmatch == 0) {
				$protocols{$protocol_name}->add_dbxref_to_protocol_step( $protocol_step, 
							 			         $dbxref_id );
			    }
			    else {
				warn("\nSKIP WARNING: Dbxref-access=$acc exist associated to element_name:$protocol_step.\n");
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

print STDERR "\nStep 4: Store (or store simulation for Test mode) the protocol data into the database.\n";

if ($opt_T) {
    print STDERR "\nRunning the TEST MODE.\n\n";
    eval {

	## First, creation of a metadata object

	my $metadbdata = CXGN::Metadata::Metadbdata->new($schema, $loader_username);
	$metadbdata->store();
	
	## Second, store the sample objects

	foreach my $protocolname (sort keys %protocols) {
	    $protocols{$protocolname}->store($metadbdata);
	}

	## Third, print the sample data stored

	print STDERR "\nStep 5: Print data loaded log.\n";
	print STDOUT "\nDATA NOT STORED in TEST MODE: \n";

	foreach my $protocolname (sort keys %protocols) {
	    my $t_protocol_id = $protocols{$protocolname}->get_protocol_id() || 'undef';
	    my $t_protocol_name = $protocols{$protocolname}->get_protocol_name() || 'undef';
	    my $t_protocol_type = $protocols{$protocolname}->get_protocol_type() || 'undef';
	    my $t_description =  $protocols{$protocolname}->get_description() || 'undef';
	    print STDOUT "+ PROTOCOL_DATA:\n\tprotocol_id =\t$t_protocol_id\n";
	    print STDOUT "\tprotocol_name =\t$t_protocol_name\n";
	    print STDOUT "\tprotocol_type =\t$t_protocol_type\n";
	    print STDOUT "\tdescription =\t$t_description\n";
	
	    print STDOUT "  * Associated publications:\n";
	    my @pub_title_list = $protocols{$protocolname}->get_publication_list('title');
	    foreach my $pub (@pub_title_list) {
		print STDOUT "\t\tpub_title: $pub\n";
	    }

	    print STDOUT "\n";
	    print STDOUT "  * Associated protocol steps:\n";
	    my %prot_steps = $protocols{$protocolname}->get_protocol_steps();
	    my %prot_steps_dbxref_p = $protocols{$protocolname}->get_dbxref_from_protocol_steps();
	    
	    foreach my $protocol_el (sort keys %prot_steps) {
		my %element_data = %{ $prot_steps{$protocol_el}};
		print STDOUT "\n";
		foreach my $column (sort keys %element_data) {
		    my $data = $element_data{$column} || 'undef';
		    print STDOUT "\t\t$column:\t$data\n";
		}
	    
		my $dbxref_aref_p = $prot_steps_dbxref_p{$protocol_el};
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

    my ($rows3) = $schema->storage()
	   	        ->dbh()
		        ->selectrow_array("SHOW search_path");

    $schema->set_sqlseq(\%last_ids);

} else {
    print STDERR "\nRunning the NORMAL MODE.\n\n";

    ## TRUE RUN
    ## First, creation of a metadata object
    
    my $metadbdata = CXGN::Metadata::Metadbdata->new($schema, $loader_username);
    $metadbdata->store();
    
    ## Second, store the sample objects
    
    foreach my $protocolname (sort keys %protocols) {
	$protocols{$protocolname}->store($metadbdata);
    }

    print STDERR "\nStep 5: Print the data loaded log.\n";
    print STDOUT "\nDATA PROCESSED TO BE STORED: \n";

    foreach my $protocolname (sort keys %protocols) {
	my $t_protocol_id = $protocols{$protocolname}->get_protocol_id() || 'undef';
	my $t_protocol_name = $protocols{$protocolname}->get_protocol_name() || 'undef';
	my $t_protocol_type = $protocols{$protocolname}->get_protocol_type() || 'undef';
	my $t_description =  $protocols{$protocolname}->get_description() || 'undef';
	print STDOUT "+ PROTOCOL_DATA:\n\tprotocol_id =\t$t_protocol_id\n";
	print STDOUT "\tprotocol_name =\t$t_protocol_name\n";
	print STDOUT "\tprotocol_type =\t$t_protocol_type\n";
	print STDOUT "\tdescription =\t$t_description\n";
	
	print STDOUT "  * Associated publications:\n";
	my @pub_title_list = $protocols{$protocolname}->get_publication_list('title');
	foreach my $pub (@pub_title_list) {
	    print STDOUT "\t\tpub_title: $pub\n";
	}
	
	print STDOUT "\n";
	print STDOUT "  * Associated protocol steps:\n";
	my %prot_steps = $protocols{$protocolname}->get_protocol_steps();
	my %prot_steps_dbxref_p = $protocols{$protocolname}->get_dbxref_from_protocol_steps();
	
	foreach my $protocol_el (sort keys %prot_steps) {
	    my %element_data = %{ $prot_steps{$protocol_el}};
	    print STDOUT "\n";
	    foreach my $column (sort keys %element_data) {
		my $data = $element_data{$column} || 'undef';
		print STDOUT "\t\t$column:\t$data\n";
	    }
	    
	    my $dbxref_aref_p = $prot_steps_dbxref_p{$protocol_el};
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
    
    commit_prompt($schema, \%last_ids);
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
       protocol_dbload [-h] [-X] -u <loader> -D <dbname> -H <dbhost> -U <dbuser> [-V <dbdriver>] -p <protocol_file> [-T]

      To collect the data loaded report into a file:

       protocol_dbload [-h] [-X] -u <loader> -D <dbname> -H <dbhost> -p <protocol_file> [-T] > file.log

    Example: 
      perl protocol_dbload.pl -u aure -H localhost -D sandbox -p protocol_file.bs


    Flags:
      -u loader username      loader username (mandatory)
      -H database hostname    for example localhost or db.sgn.cornell.edu (mandatory for check domains in the database)
      -D database name        sandbox or cxgn etc (mandatory for check domains in the database)
      -U database username    database username (mandatory)
      -V database driver      driver for database connection (Pg by default)
      -p protocol file        data load file input file (mandatory)
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



=head2 print_protocol_template

  Usage: print_protocol_template()
  Desc: print a protocol_template file
  Ret: none
  Args: none
  Side_Effects: create a file and exit of the script
  Example:

=cut

sub print_protocol_template {
    my $dir = `pwd`;
    chomp($dir);
    my $template_protocol_file = $dir . '/protocol_load_file.bs';
    open my $TFH, '>', $template_protocol_file || die("Sorry, I can not open the file: $template_protocol_file.\n");

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
#               Note1: Time format should be YEAR-MONTH-DAY HOUR:MIN:SEC (example: 2001-10-10 10:00::08)
#
# NOTE FOR DATABASE CURATORS: To load all this data into the database, use the sedm_sources_dbload.pl script
#


#####################################################################################
# PROTOCOL_DATA #####################################################################
# FIELD	#		# DATA #	# DATA_STRINGENCY #	# EXAMPLE_AND_NOTES #
#####################################################################################

## To add a new protocol (MANDATORY):

*DATA_TYPE:		[]		#mandatory,single	example:[protocol]
*PROTOCOL_NAME:		[]		#mandatory,single	example:[Tomato plant growth]
*PROTOCOL_TYPE:         []              #mandatory,single       example:[plant growth]
*PROTOCOL_DESCRIPTION: 	[]		#optional,single	example:[The plants were...]
//

## To associate a publication to an existing protocol:

*DATA_TYPE:             []              #mandatory              example:[pub]
*PROTOCOL_NAME:		[]		#mandatory,single,fl	example:[Tomato plant growth]
*TITLE:                 []              #mandatory              example:[Solanaceae comparissons]
//

## To add a protocol_element to an existing protocol:

*DATA_TYPE:             []              #mandatory,single       example:[protocol_step]
*PROTOCOL_NAME:		[]		#mandatory,single	example:[Tomato plant growth]
*STEP:                  []              #mandatory,single       example:[1]
*ACTION:                []              #optional,single  	example:[Sterilize seeds]
*EXECUTION:             []              #optional,single	example:[200 seeds were sterilized with 5% bleach solution]
*TOOL_NAME:             []              #optional,single        example:[]
*BEGIN_DATE:            []              #optional,single,note1  example:[2001-01-01]
*END_DATE:              []              #optional,single,note1  example:[2001-01-02]
*LOCATION:              []              #optional,single        example:[Example Lab, Cornell University, NY, USA]
//

## To associate ontologies as dbxrefs (to store more than one dbxref with different dbname can be used more entries)

*DATA_TYPE:	        []              #mandatory,single	example:[step_dbxref]
*PROTOCOL_NAME:         []              #mandatory,single       example:[Tomato plant growth]
*STEP:                  []              #mandatory,single       example:[1]
*DBNAME:                []              #mandatory,single       example:[ENVO]
*ACCESSIONS:		[]		#mandatory,multiple     example:[00000117]
//';

    print $TFH "$info";
    print STDERR "...done (printed protocol_load_file with the name: $template_protocol_file)\n\n";
    exit (1);
}




####
1;##
####
