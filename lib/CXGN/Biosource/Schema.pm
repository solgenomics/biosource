
package CXGN::Biosource::Schema;

use strict;
use warnings;
use Carp;

use Module::Find;
use Bio::Chado::Schema;
use base 'DBIx::Class::Schema';


###############
### PERLDOC ###
###############

=head1 NAME

CXGN::Biosource::Schema
a DBIx::Class::Schema object to manipulate the biosource schema.

=cut

our $VERSION = '0.01';
$VERSION = eval $VERSION;

=head1 SYNOPSIS

 my $schema_list = 'biosource,metadata,public';

 my $schema = CXGN::Biosource::Schema->connect( sub { $dbh },
                                          { on_connect_do => ["SET search_path TO $schema_list"] }, );

 ## Using DBICFactory (it is deprecated):

 my @schema_list = split(/,/, $schema_list);
 my $schema = CXGN::DB::DBICFactory->open_schema( 'CXGN::Biosource::Schema', search_path => \@schema_list, );


=head1 DESCRIPTION

 This class create a new DBIx::Class::Schema object and load the dependencies of other schema classes as
 metadata, or chado.

 It need set_path to be able to use all of them.

 Also load the relations between schemas.

=head1 AUTHOR

Aureliano Bombarely <ab782@cornell.edu>


=head1 CLASS METHODS

The following class methods are implemented:

=cut



### The biosource schema use chado and metadata schemas, so it will load this classes

## Load our own classes
__PACKAGE__->load_classes;

## Load Metadata also
__PACKAGE__->load_classes({
    'CXGN::Metadata::Schema' => [ _find_classes('CXGN::Metadata::Schema') ],
});

## Load Bio::Chado::Schema a little differently, depending on its version
if(    !defined $Bio::Chado::Schema::VERSION #< undef implies dev checkout
    || $Bio::Chado::Schema::VERSION >= 0.08
  ) {

    __PACKAGE__->load_namespaces(
        result_namespace    => '+Bio::Chado::Schema::Result',
        resultset_namespace => '+Bio::Chado::Schema::ResultSet',
      );
} else {
    __PACKAGE__->load_classes({
        'Bio::Chado::Schema' => [ _find_classes( 'Bio::Chado::Schema' ) ],
      });
}
# check that we successfully loaded BCS
eval{ __PACKAGE__->source('Organism::Organism') } or die 'Failed to load Bio::Chado::Schema classes';

sub _find_classes {
    my $ns = shift;
    my @classes = findallmod $ns;
    s/^${ns}::// for @classes;
    return @classes;
}


=head2 get_last_id (deprecated)

  Usage: my %last_ids = $schema->get_last_id();
         my $last_table_id = $schema->get_last_id($sqlseq_name);

  Desc: Get all the last ids and store then in an hash reference for a specified schema

  Ret: $all_last_ids_href, a hash reference with keys = SQL_sequence_name and value = last_value

  Args: $schema, a CXGN::Biosource::Schema object
        $sqlseq_name, a scalar, name of the sql sequence (default value)

  Side Effects: If the seq name don't have the schema name (schema.sequence_seq) is ignored

  Example: my %last_ids = $schema->get_last_id();
           my $last_table_id = $schema->get_last_id($sqlseq_name);

=cut

sub get_last_id {
    my $schema = shift || die("None argument was supplied to the subroutine get_all_last_ids()");
    my %last_ids;
    my @source_names = $schema->sources();

    warn("WARNING: $schema->get_last_id() is a deprecated method. Use get_nextval().\n");

    foreach my $source_name (sort @source_names) {

        my $source = $schema->source($source_name);
	my $table_name = $schema->class($source_name)->table();

	if ( $schema->exists_dbtable($table_name) ) {

	    my ($primary_key_col) = $source->primary_columns();

	    my $primary_key_col_info;
	    my $primary_key_col_info_href = $source->column_info($primary_key_col);
	    if (exists $primary_key_col_info_href->{'default_value'}) {
		$primary_key_col_info = $primary_key_col_info_href->{'default_value'};
	    }
	    elsif (exists $primary_key_col_info_href->{'sequence'}) {
		$primary_key_col_info = $primary_key_col_info_href->{'sequence'};
	    }

	    my $last_value = $schema->resultset($source_name)
                                    ->get_column($primary_key_col)
                                    ->max();
	    my $seq_name;

	    if (defined $primary_key_col_info) {
		if (exists $primary_key_col_info_href->{'default_value'}) {
		    if ($primary_key_col_info =~ m/\'(.*?_seq)\'/) {
			$seq_name = $1;
		    }
		}
		elsif (exists $primary_key_col_info_href->{'sequence'}) {
		    if ($primary_key_col_info =~ m/(.*?_seq)/) {
			$seq_name = $1;
		    }
		}
	    }
	    else {
		print STDERR "The source:$source_name ($source) with primary_key_col:$primary_key_col hasn't any primary_key_col_info.\n";
	    }

	    if (defined $seq_name) {
		$last_ids{$seq_name} = $last_value || 0;
	    }
	}
    }
    return \%last_ids;
}

=head2 set_sqlseq (deprecated)

  Usage: $schema->set_sqlseq($seqvalues_href);

  Desc: set the sequence values to the values specified in the $seqvalues_href

  Ret: none

  Args: $schema, a schema object
        $seqvalues_href, a hash reference with keys=sequence_name and value=value to set
        $on_message, enable the message option

  Side Effects: If value to set is undef set value to the first seq

  Example: $schema->set_sqlseq($seqvalues_href, 1);

=cut

sub set_sqlseq {
    my $schema = shift
	|| die("None argument was supplied to the subroutine set_sqlseq_values_to_original_state().\n");
    my $seqvalues_href = shift
	|| die("None argument was supplied to the subroutine set_sqlseq_values_to_original_state().\n");
    my $on_message = shift;  ## To enable messages

    warn("WARNING: $schema->set_sqlseq is a deprecated method. Table sequences should be set manually.\n");

    my %seqvalues = %{ $seqvalues_href };

    foreach my $sqlseq (sort keys %seqvalues) {

        my $sqlseqline = "'".$sqlseq."'";
        my $val = $seqvalues{$sqlseq};

        if ($val > 0) {

            $schema->storage()
		   ->dbh()
		   ->do("SELECT setval ($sqlseqline, $val, true)");
        }
	else {

            ## If there aren't any value (the table is empty, it set to 1, false)

            $schema->storage()->dbh()->do("SELECT setval ($sqlseqline, 1, false)");
        }
    }
    if (defined $on_message) {
	print STDERR "Setting the SQL sequences to the original values before run the script... done\n";
    }
}

=head2 exists_dbtable

  Usage: $schema->exists_dbtable($dbtablename, $dbschemaname);

  Desc: Check in exists a table in the database

  Ret: A boolean, 1 for true and 0 for false

  Args: $dbtablename and $dbschemaname. If none schename is supplied,
        it will use the schema set in search_path


  Side Effects: None

  Example: if ($schema->exists_dbtable($table)) { ## do something }

=cut

sub exists_dbtable {
    my $schema = shift;
    my $tablename = shift;
    my $schemaname = shift;

    my $dbh = $schema->storage()
	             ->dbh();

    ## First get all the path setted for this object

    my @schemalist;
    if (defined $schemaname) {
	push @schemalist, $schemaname;
    }
    else {
	my ($path) = $dbh->selectrow_array("SHOW search_path");
	@schemalist = split(/, /, $path);
    }

    my $dbtrue = 0;
    foreach my $schema_name (@schemalist) {
	my $query = "SELECT count(*) FROM pg_tables WHERE tablename = ? AND schemaname = ?";
	my ($predbtrue) = $dbh->selectrow_array($query, undef, $tablename, $schema_name);
	if ($predbtrue > $dbtrue) {
	    $dbtrue = $predbtrue;
	}
    }

    return $dbtrue;
}

##################################################
## New function to replace deprecated functions ##
##################################################

=head2 get_nextval

  Usage: my %nextval = $schema->get_nextval();

  Desc: Get all the next values from the table sequences
        and store into hash using SELECT nextval()

  Ret: %nextval, a hash with keys = SQL_sequence_name
       and value = nextval

  Args: $schema, a CXGN::GEM::Schema object

  Side Effects: If the table has not primary_key or
                default value sequence, it will be ignore.

  Example: my %nextval = $schema->get_nextval();

=cut

sub get_nextval {
    my $schema = shift
	|| die("None argument was supplied to the subroutine get_nextval()");

    my %nextval;
    my @source_names = $schema->sources();

    my $dbh = $schema->storage()
	             ->dbh();

    foreach my $source_name (sort @source_names) {

        my $source = $schema->source($source_name);
	my $table_name = $schema->class($source_name)
                                ->table();

	## To get the sequence
	## 1) Get primary key

	my $seq_name;
	my ($prikey) = $dbh->primary_key(undef, undef, $table_name);

	if (defined $prikey) {

	    ## 2) Get default for primary key

	    my $sth = $dbh->column_info( undef, undef, $table_name, $prikey);
	    my ($rel) = (@{$sth->fetchall_arrayref({})});
	    my $default_val = $rel->{'COLUMN_DEF'};

	    ## 3) Extract the seq_name

	    if ($default_val =~ m/nextval\('(.+)'::regclass\)/) {
		$seq_name = $1;
	    }
	}

	if (defined $seq_name) {
	    if ($schema->is_table($table_name)) {

                ## Get the nextval (it is not using currval, because
                ## you can not use it without use nextval before).

		my $query = "SELECT nextval('$seq_name')";
		my ($nextval) = $dbh->selectrow_array($query);

		$nextval{$table_name} = $nextval || 0;
	    }
	}

    }
    return %nextval;
}

=head2 is_table

  Usage: $schema->is_table($tablename, $schemaname);

  Desc: Return 0/1 if exists or not a table into the
        database

  Ret: 0 or 1

  Args: $schema, a CXGN::GEM::Schema object
        $tablename, name of a table
        $schemaname, name of a schema

  Side Effects: If $tablename is undef. it will return
                0.
                If $schemaname is undef. it will search
                for the tablename in all the schemas.

  Example: if ($schema->is_table('ge_experiment')) {
                  ## Do something
           }

=cut

sub is_table {
    my $schema = shift
	|| die("None argument was supplied to the subroutine is_table()");

    my $tablename = shift;
    my $schemaname = shift;

    ## Get the dbh

    my $dbh = $schema->storage()
	             ->dbh();

    ## Define the hash with the tablenames

    my %tables;

    ## Get all the tables with the tablename

    my $presence = 0;

    if (defined $tablename) {
	my $sth = $dbh->table_info('', $schemaname, $tablename, 'TABLE');
	for my $rel (@{$sth->fetchall_arrayref({})}) {

	    ## It will search based in LIKE so it need to check the right anme
	    if ($rel->{TABLE_NAME} eq $tablename) {
		$presence = 1;
	    }
	}
    }

    return $presence;
}






####
1;##
####
