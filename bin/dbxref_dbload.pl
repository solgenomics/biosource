#!/usr/bin/perl

=head1 NAME

 dbxref_dbload.pl
 A script to load dbxref into the chado table db and dbxref 
(version.0.1.).

=cut

=head1 SYPNOSIS

 dbxref_dbload.pl [-h] -H <dbhost> -D <dbname> -U <dbuser>
                       -r <dbxref_file> -n <db_name_for_xref> 
                       [-T]

  To collect the data loaded report into a file:

 dbxref_dbload [-h] [-X] -D <dbname> -H <dbhost> 
               -r <dbxref_file> [-T] > file.log


=head1 EXAMPLE:

 perl dbxref_dbload.pl -H localhost -U postgres -D sandbox
                       -r dbxref_for_sample1
                       -n GEO
        
    
=head2 I<Flags:>

=over

=item -r

B<dbxref_file>                  dbxref file with 3 columns (accession, version and description) (mandatory).

=item -n

B<xdb_name>                     external db name (it should be into the db, in db table)  (mandatory).

=item -H

B<database_host>                database host (mandatory)

=item -U

B<database_user>                database user (mandatory)

=item -D

B<database_name>                database name (mandatory)

=item -V

B<database_driver>              database driver (Pg (postgres) by default)

=item -T

B<run as a test>                run the script as test

=item -h

B<help>                         print the help  

=back

=cut

=head1 DESCRIPTION

  This script parse a dbxref file and load the dbxref data into the
  dbxref table (accession, version and description).

  Note: If the external database name (GenBank for example) is not in
        the db table, the load will fail.
 
=cut

=head1 AUTHORS

  Aureliano Bombarely Gomez.
  (ab782@cornell.edu).

=cut

=head1 METHODS

dbxref_dbload.pl


=cut

use strict;
use warnings;

use File::Basename;
use Getopt::Std;
use Term::ReadKey;

use Bio::Chado::Schema;

our ($opt_n, $opt_H, $opt_D, $opt_U, $opt_V, $opt_r, $opt_T, $opt_h);
getopts("n:H:D:U:V:r:Th");
if (!$opt_n && !$opt_H && !$opt_D && !$opt_U && !$opt_V && !$opt_r && !$opt_T && !$opt_h) {
    print "There are n\'t any tags. Print help\n\n";
    help();
} elsif ($opt_h) {
    help();
}

## Checking the input arguments

my $xdb_name = $opt_n 
    || die("MANDATORY ARGUMENT ERROR: The -n <external_db_name> argument was not supplied.\n");
my $dbname = $opt_D 
    || die("MANDATORY ARGUMENT ERROR: The -D <database_name> argument was not supplied.\n");
my $dbhost = $opt_H 
    || die("MANDATORY ARGUMENT ERROR: The -H <db_hostname> argument was not supplied.\n");
my $dbuser = $opt_U 
    || die("MANDATORY ARGUMENT ERROR: The -U <db_username> argument was not supplied.\n"); 
my $dbxref_file = $opt_r 
    || die("MANDATORY ARGUMENT ERROR: The -r <dbxref_file> argument was not supplied.\n");

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

my $schema_list = 'public';

my $schema = Bio::Chado::Schema->connect( "dbi:$dbdriver:database=$dbname;host=$dbhost", 
                                               $dbuser, 
                                               $passw,
                                               { AutoCommit => 0 }, 
                                               {on_connect_do => ["SET search_path TO $schema_list;"]}
                                             ); 


## Getting the last ids for the different tables to set the database sequences values in case of rollback 
## or something wrong during the test

print STDERR "\nStep 2: Checking external db name.\n";

my $db_id;
my ($db_row) = $schema->resultset('General::Db')
                      ->search({ name => $xdb_name });

unless (defined $db_row) {
    die("\nDATABASE ARGUMENT ERROR: $xdb_name does not exist into the chado table db.\n\tPlease check alternatives or insert it before run this script.\n\n");
}
else {
    $db_id = $db_row->get_column('db_id');
    print STDERR "\n\tDb_id=$db_id for external db name=$xdb_name\n";
}


## Parse the dbxref_file and transfer the data
## It will store them into a hash to check if there are duplications and also to check the
## number of columns (it could use COPY but in that case it ir more difficult to check things)

## First, get the last dbxref_id to set the sequences if rollback action is taken

my $last_dbxref_id = 0;
my ($last_dbxref_row) = $schema->resultset('General::Dbxref')
                               ->search(undef, { order_by => { -desc => 'dbxref_id'}, rows => 1 } );

if (defined $last_dbxref_row) {
    $last_dbxref_id = $last_dbxref_row->get_column('dbxref_id');
}

print STDERR "\n\tLast dbxref_id=$last_dbxref_id\n";

print STDERR "\nStep 3: Open and parse the dbxref file.\n";

my %dbxref;
my %dbxref_vers;
my %dbxref_desc;

open my $ifh, '<', $dbxref_file || die("Sorry, but I can not open the input file: $dbxref_file.\n");

my $l = 0;

while(<$ifh>) {
		
    $l++; ## Line counter

    ## It will do not read any line that start with #
    unless ($_ =~ m/^#/) {
	chomp($_);
	my @data = split(/\t/, $_);
	
	## First check the number of columns
	
	my $col_n = scalar(@data);
	unless ($col_n == 3) {
	    print STDERR "\n\tWARNING: line $l has $col_n columns. It should have 3. SKIPPING LINE $l.\n\n";
	}
	else {
	    
	   my $accession = $data[0];
	   
	   unless (defined $accession) {
	       print STDERR "\n\tWARNING: line $l has not any accession. SKIPPING LINE $l.\n\n";
	   }
	   else {
	       if (exists $dbxref{$accession}) {
		   my $old_line = $dbxref{$accession};
		   print STDERR "\n\tWARNING: The accession $accession in the line $l is duplicated (it was parsed in the line $old_line). SKIPPING LINE $l.\n\n";
	       }
	       else {
		   $dbxref{$accession} = $l;
		   if (defined $data[1]) {
		       $dbxref_vers{$accession} = $data[1];
		   }
		   if (defined $data[2]) {
		       $dbxref_desc{$accession} = $data[2];
		   }
	       }
	   }
	}
    }
}
print STDERR "\n\n";

my $dbxref_parsed = scalar( keys %dbxref );

print STDERR "\n\t$dbxref_parsed dbxref have been parser from the file:$dbxref_file\n";


## The file should be parsed.
## Test mode, run as evaluation of the code

print STDERR "\nStep 4: Store (or store simulation for Test mode) the dbxref data into the database.\n";

my $dbxref_rows_href;

if ($opt_T) {
    print STDERR "\nRunning the TEST MODE.\n\n";
    eval {

	$dbxref_rows_href = insert_dbxref_rows(\%dbxref, \%dbxref_vers, \%dbxref_desc);
	print STDERR "\n\n";
    };

    ## Print errors if something was wrong during the test

    if ($@) {
	print STDERR "\nTEST ERRORS:\n\n$@\n";
    }

    ## Finally, rollback, because it is a test and set the sequence values

    $schema->txn_rollback;
    if ($last_dbxref_id > 0) {
	  
	$schema->storage()->dbh()->do("SELECT setval ('dbxref_dbxref_id_seq', $last_dbxref_id, true)");
    } 
    else {
	  
	## If there aren't any value (the table is empty, it set to 1, false)
	  
	$schema->storage()->dbh()->do("SELECT setval ('dbxref_dbxref_id_seq', 1, false)");
    }
    
} 
else {
    print STDERR "\nRunning the NORMAL MODE.\n\n";

    ## TRUE RUN

    $dbxref_rows_href = insert_dbxref_rows(\%dbxref, \%dbxref_vers, \%dbxref_desc);
    print STDERR "\n\n";    
   
    ## Finally, commit or rollback option
    
    commit_prompt($schema, $last_dbxref_id);
}

print STDERR "\nStep 5: Print the rows inserted.\n";

my $outfile = 'dbxref_dbload.report.txt';
open my $out, '>', $outfile;

my $m = 0;
foreach my $dbxref_accession (sort keys %{$dbxref_rows_href}) {
    my $row = $dbxref_rows_href->{$dbxref_accession};
    my %data = $row->get_columns();
    my @columns = ('dbxref_id', 'db_id', 'accession', 'version', 'description');

    if ($m == 0) {
	my $col_list = join("\t", @columns);
	print $out "#$col_list\n";
    }
    
    my @data_list;
    foreach my $col (@columns) {
	push @data_list, $data{$col};
    }
    my $data_print = join("\t", @data_list);
    print $out "$data_print\n";
    
    $m++;
}
print STDERR "\n\n";

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

       This script parse a dbxref file and load the dbxref data into the
       dbxref table (accession, version and description).

    Note: 
       
       If the external database name (GenBank for example) is not in
       the db table, the load will fail.

    Usage: 
      
      dbxref_dbload.pl [-h] -H <dbhost> -D <dbname> -U <dbuser>
                       -r <dbxref_file> -n <db_name_for_xref> 
                       [-T]

    Example: 
      
      perl dbxref_dbload.pl -H localhost -U postgres -D sandbox
                       -r dbxref_for_sample1
                       -n GEO

    Flags:
      
      -r <dbxref_file>           dbxref file with 3 columns (accession, version and description) (mandatory).
      -n <xdb_name>              external db name (it should be into the db, in db table)  (mandatory).
      -H <database_host>         database host (mandatory)
      -U <database_user>         database user (mandatory)
      -D <database_name>         database name (mandatory)
      -V <database_driver>       database driver (Pg (postgres) by default)
      -T <run_as_a_test>         run the script as test
      -h <help>                  print the help  


EOF
exit (1);
}


################################
### GENERAL DATABASE METHODS ###
################################

=head2 commit_prompt

 Usage: commit_prompt($schema, $dbxref_last_id, $prompt_message, $after_message);
 Desc: ask if you want commit or rollback the changes in the database. If the answer (STDIN) is yes, commit the changes.
 Ret: none
 Args: $dbh (database conection object), $prompt_message and $after_message are object to print a message during prompt
       and after the answer. $initials_tableseq_href is an hash reference with keys=name of the sequence of a concrete
       table and values=current value before the process. It will be used if the option choosed is rollback.
 Side_Effects: print message
 Example: commit_prompt($schema, $dbxref_last_id);

=cut

sub commit_prompt {
  my ($schema, $dbxref_last_id, $prompt_message, $after_message) = @_;
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
      $schema->txn_rollback;
      
      if ($last_dbxref_id > 0) {
	  
	  $schema->storage()->dbh()->do("SELECT setval ('dbxref_dbxref_id_seq', $last_dbxref_id, true)");
      } 
      else {
	  
	  ## If there aren't any value (the table is empty, it set to 1, false)
	  
	  $schema->storage()->dbh()->do("SELECT setval ('dbxref_dbxref_id_seq', 1, false)");
      }

      print STDERR "done.\n\n";
  }
}



=head2 insert_dbxref_rows

 Usage: my $inserted_rows_href = insert_dbxref_rows($dbxref_href, $dbxref_version_href, $dbxref_description_href)
 Desc: Insert into the database the specified dbxref
 Ret: A hash reference with keys=accession and value=dbxref row object
 Args: $dbxref_href, a hash reference with keys=accession and value=line
       $dbxref_version_href, a hash reference with keys=accession and value=version
       $dbxref_description_href, a hash reference with keys=accession and value=description
 Side_Effects: Die if the dbxref hash refererence is not supplied
               Print status
 Example: my $inserted_rows_href = insert_dbxref_rows($dbxref_href, $dbxref_version_href, $dbxref_description_href)

=cut

sub insert_dbxref_rows {
  my $dbxref_href = shift ||
      die("\nERROR: dbxref hash reference was not supplied to insert_dbxref_rows function.\n ");
  my $dbxref_vers_href = shift;
  my $dbxref_desc_href = shift;

  my %dbxref = %{$dbxref_href};

  my %dbxref_row;

  foreach my $dbxref_acc (sort keys %dbxref) {
      my %data = ( 'accession' => $dbxref_acc, 'db_id' => $db_id );
      
      if (exists $dbxref_vers_href->{$dbxref_acc}) {
	  $data{'version'} = $dbxref_vers_href->{$dbxref_acc};
      }
      if (exists $dbxref_desc_href->{$dbxref_acc}) {
	  $data{'description'} = $dbxref_desc_href->{$dbxref_acc}; 
      }
      
      my $new_row = $schema->resultset('General::Dbxref')
	  ->find_or_create(\%data);
      
      $dbxref_row{$dbxref_acc}= $new_row;

      my $new_dbxref_id = $new_row->get_column('dbxref_id');
      print STDERR "\tAccession $dbxref_acc was inserted (dbxref_id=$new_dbxref_id)\r";
  }
  return \%dbxref_row;
}



####
1;##
####
