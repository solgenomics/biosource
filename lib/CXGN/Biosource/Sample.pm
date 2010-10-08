
package CXGN::Biosource::Sample;

use strict;
use warnings;

use base qw | CXGN::DB::Object |;
use Bio::Chado::Schema;
use CXGN::Biosource::Schema;
use CXGN::Biosource::Protocol;
use CXGN::Metadata::Metadbdata;

use Carp qw| croak cluck |;


###############
### PERLDOC ###
###############

=head1 NAME

CXGN::Biosource::Sample
a class to manipulate a sample data from the biosource schema.

=cut

our $VERSION = '0.02';
$VERSION = eval $VERSION;

=head1 SYNOPSIS

  use CXGN::Biosource::Sample;

  ## Constructor

  my $sample = CXGN::Biosource::Sample->new($schema, $sample_id);

  ## Basic Accessors

  my $sample_name = $sample->get_sample_name();
  $sample->set_sample_type($new_type);

  ## Extended accessors

  $sample->add_publication($pub_id);
  $sample->add_dbxref($dbxref_id);
  $sample->add_cvterm($cvterm_id);
  $sample->add_file($file_id);

  my @pub_list = $sample->get_publication_list();
  my @dbxref_list = $sample->get_dbxref_list();
  my @cvterm_list = $sample->get_cvterm_list();
  my @file_list = $sample->get_file_list();

  ## Add relation between two samples

  $sample->add_children_relationship(
                             {
                               object_sample_id  => $sample_id,
                               type_id           => $cvterm_id,
                               value             => $note_text,
                               rank              => $rank,
                             }
                           );

  $sample->add_parent_relationship(
                             {
                               subject_sample_id => $sample_id,
                               type_id           => $cvterm_id,
                               value             => $note_text,
                               rank              => $rank,
                             }
                           );

  my %related_samples = $sample->get_relationship();
  my @children_samples = $sample->get_children_relationship();
  my @parents_samples = $sample->get_parents_relationship();


  ## Store function

  $sample->store($metadbdata);

  ## Obsolete functions

  unless ($sample->is_obsolete() ) {
    print STDERR "$sample_name is obsolete\n";
  }
 


=head1 DESCRIPTION

 This object manage the protocol information of the database
 from the tables:
  
   + biosource.bs_sample
   + biosource.bs_sample_pub
   + biosource.bs_sample_dbxref
   + biosource.bs_sample_cvterm
   + biosource.bs_sample_file
   + biosource.bs_sample_relationship

 This data is stored inside this object as dbic rows objects with the 
 following structure:

  %Sample_Object = ( 
    
       bs_sample_row    => BsSample_row, 
                     
       bs_samplepub_row => [ @BsSamplePub_rows ], 
 
       bs_samplecvterm_row => [ @BsSampleCvterm_rows ], 

       bs_sampledbxref_row => [ @BsSampleDbxref_rows ], 

       bs_samplefile_row => [ @BsSampleFile_rows ], 

       bs_samplechildrenrelationship_row => [ @BsSampleRelationship_rows ], 
    
       bs_sampleparentrelationship_row => [ @BsSampleRelationship_rows ], 
    
  );


=head1 AUTHOR

Aureliano Bombarely <ab782@cornell.edu>


=head1 CLASS METHODS

The following class methods are implemented:

=cut 



############################
### GENERAL CONSTRUCTORS ###
############################

=head2 constructor new

  Usage: my $sample = CXGN::Biosource::Sample->new($schema, $sample_id);

  Desc: Create a new Sample object

  Ret: a CXGN::Biosource::Sample object

  Args: a $schema a schema object, preferentially created using:
        CXGN::Biosource::Schema->connect(
                   sub{ CXGN::DB::Connection->new()->get_actual_dbh()}, 
                   %other_parameters );
        A $sample_id, a scalar.
        If $sample_id is omitted, an empty sample object is created.

  Side_Effects: accesses the database, check if exists the database columns that
                 this object use.  die if the id is not an integer.

  Example: my $sample = CXGN::Biosource::Sample->new($schema, $sample_id);

=cut

sub new {
    my $class = shift;
    my $schema = shift || 
	croak("PARAMETER ERROR: None schema object was supplied to the $class->new() function.\n");
    my $id = shift;

    ### First, bless the class to create the object and set the schema into de object 
    ### (set_schema comes from CXGN::DB::Object).

    my $self = $class->SUPER::new($schema);
    $self->set_schema($schema);                                   

    ### Second, check that ID is an integer. If it is right go and get all the data for 
    ### this row in the database and after that get the data for dbipath. 
    ### If don't find any, create an empty oject.
    ### If it is not an integer, die

    my $sample;
    my @sample_pubs = (); 
    my @sample_dbxrefs = ();
    my @sample_cvterms = ();
    my @sample_files = ();
    my @sample_children_relationship = ();
    my @sample_parents_relationship = ();

    if (defined $id) {
	unless ($id =~ m/^\d+$/) {  ## The id can be only an integer... so it is better if we detect this fail before.
            
	    croak("\nDATA TYPE ERROR: The sample_id ($id) for $class->new() IS NOT AN INTEGER.\n\n");
	}

	## Get the bs_sample_row object using a search based in the sample_id 

	($sample) = $schema->resultset('BsSample')
   	                   ->search( { sample_id => $id } );
	
	## Search sample_pub associations (bs_sample_pub_row objects) based in the sample_id

	@sample_pubs = $schema->resultset('BsSamplePub')
	                      ->search( { sample_id => $id } );

	## Search sample_dbxref associations (bs_sample_dbxref_row objects) based in the sample_id

	@sample_dbxrefs = $schema->resultset('BsSampleDbxref')
	                         ->search( { sample_id => $id } );
       
	## Search sample_cvterm associations (bs_sample_cvterm_row objects) based in the sample_id

	@sample_cvterms = $schema->resultset('BsSampleCvterm')
	                         ->search( { sample_id => $id } );

	## Search sample_cvterm associations (bs_sample_file_row objects) based in the sample_id

	@sample_files = $schema->resultset('BsSampleFile')
	                         ->search( { sample_id => $id } );

	## Search sample_relationship associations (bs_sample_relationship_row objects) based in the sample_id

	@sample_children_relationship = $schema->resultset('BsSampleRelationship')
	                                       ->search( { subject_id => $id } );

	@sample_parents_relationship = $schema->resultset('BsSampleRelationship')
	                                      ->search( { object_id => $id } );

	unless (defined $sample) {  ## If dbiref_id don't exists into the  db, it will warning with cluck and create an empty object
                
	    cluck("\nDATABASE WARNING: Sample_id ($id) for $class->new() DON'T EXISTS INTO THE DB.\nIt'll be created an empty obj.\n" );
	    
	    $sample = $schema->resultset('BsSample')
		             ->new({});
	}
    } 
    else {
	$sample = $schema->resultset('BsSample')
	                 ->new({});                              ### Create an empty object;
    }

    ## Finally it will load the dbiref_row and dbipath_row into the object.
    $self->set_bssample_row($sample);
    $self->set_bssamplepub_rows(\@sample_pubs);
    $self->set_bssampledbxref_rows(\@sample_dbxrefs);
    $self->set_bssamplecvterm_rows(\@sample_cvterms);   
    $self->set_bssamplefile_rows(\@sample_files);  
    $self->set_bssamplechildrenrelationship_rows(\@sample_children_relationship);  
    $self->set_bssampleparentsrelationship_rows(\@sample_parents_relationship); 

    return $self;
}

=head2 constructor new_by_name

  Usage: my $sample = CXGN::Biosource::Sample->new_by_name($schema, $sample_name);
 
  Desc: Create a new Sample object using sample_name
 
  Ret: a CXGN::Biosource::Sample object
 
  Args: a $schema a schema object, preferentially created using:
        CXGN::Biosource::Schema->connect(
                   sub{ CXGN::DB::Connection->new()->get_actual_dbh()}, 
                   %other_parameters );
        a $sample_name, a scalar
 
  Side_Effects: accesses the database,
                return a warning if the protocol name do not exists into the db
 
  Example: my $sample = CXGN::Biosource::Sample->new_by_name( $schema, $name);

=cut

sub new_by_name {
    my $class = shift;
    my $schema = shift || 
	croak("PARAMETER ERROR: None schema object was supplied to the $class->new_by_name() function.\n");
    my $name = shift;

    ### It will search the protocol_id for this name and it will get the protocol_id for that using the new
    ### method to create a new object. If the name don't exists into the database it will create a empty object and
    ### it will set the protocol_name for it
  
    my $sample;

    if (defined $name) {
	my ($sample_row) = $schema->resultset('BsSample')
	                          ->search({ sample_name => $name });

	unless (defined $sample_row) {                

	    cluck("\nDATABASE WARNING: sample_name ($name) for $class->new() DON'T EXISTS INTO THE DB.\n" );
	    
	    ## If do not exists any sample with this sample name, it will return a warning and it will create an empty
            ## object with the sample name set in it.

	    $sample = $class->new($schema);
	    $sample->set_sample_name($name);
	}
	else {
	    $sample = $class->new( $schema, $sample_row->get_column('sample_id') ); ## if exists it will take the sample_id to create
                                                                                    ## the object with the new constructor
	}
    } 
    else {
	$sample = $class->new($schema);                              ### Create an empty object;
    }
   
    return $sample;
}


##################################
### DBIX::CLASS ROWS ACCESSORS ###
##################################

=head2 accessors get_bssample_row, set_bssample_row

  Usage: my $bssample_row = $self->get_bssample_row();
         $self->set_bssample_row($bssample_row_object);

  Desc: Get or set a bssample row object into a sample object
 
  Ret:   Get => $bssample_row_object, a row object 
                (CXGN::Biosource::Schema::BsSample).
         Set => none
 
  Args:  Get => none
         Set => $bssample_row_object, a row object 
                (CXGN::Biosource::Schema::BsSample).
 
  Side_Effects: With set check if the argument is a row object. If fail, dies.
 
  Example: my $bssample_row = $self->get_bssample_row();
           $self->set_bssample_row($bssample_row);

=cut

sub get_bssample_row {
  my $self = shift;
 
  return $self->{bssample_row}; 
}

sub set_bssample_row {
  my $self = shift;
  my $bssample_row = shift 
      || croak("FUNCTION PARAMETER ERROR: None bssample_row object was supplied for $self->set_bsprotocol_row function.\n");
 
  if (ref($bssample_row) ne 'CXGN::Biosource::Schema::BsSample') {
      croak("SET ARGUMENT ERROR: $bssample_row isn't a bssample_row obj. (CXGN::Biosource::Schema::BsSample).\n");
  }
  $self->{bssample_row} = $bssample_row;
}



=head2 accessors get_bssamplepub_rows, set_bssamplepub_rows

  Usage: my @bssamplepub_rows = $self->get_bssamplepub_rows();
         $self->set_bssamplepub_rows(\@bssamplepub_rows);

  Desc: Get or set a list of bssamplepub rows object into a sample object
 
  Ret:   Get => @bssamplepub_row_object, a list of row objects 
                (CXGN::Biosource::Schema::BsSamplePub).
         Set => none
 
  Args:  Get => none
         Set => @bssamplepub_row_object, an array ref of row objects 
                (CXGN::Biosource::Schema::BsSamplePub).
 
  Side_Effects: With set check if the argument is a row object. If fail, dies.
 
  Example: my @bssamplepub_rows = $self->get_bssamplepub_rows();
           $self->set_bssamplepub_rows(\@bssamplepub_rows);

=cut

sub get_bssamplepub_rows {
  my $self = shift;
 
  return @{$self->{bssamplepub_rows}}; 
}

sub set_bssamplepub_rows {
  my $self = shift;
  my $bssamplepub_row_aref = shift 
      || croak("FUNCTION PARAMETER ERROR: None bssamplepub_row array ref was supplied for set_bssamplepub_rows function.\n");
 
  if (ref($bssamplepub_row_aref) ne 'ARRAY') {
      croak("SET ARGUMENT ERROR: $bssamplepub_row_aref isn't an array reference.\n");
  }
  else {
      foreach my $bssamplepub_row (@{$bssamplepub_row_aref}) {  
          if (ref($bssamplepub_row) ne 'CXGN::Biosource::Schema::BsSamplePub') {
              croak("SET ARGUMENT ERROR: $bssamplepub_row isn't a bssamplepub_row obj. (CXGN::Biosource::Schema::BsSamplePub).\n");
          }
      }
  }
  $self->{bssamplepub_rows} = $bssamplepub_row_aref;
}


=head2 accessors get_bssampledbxref_rows, set_bssampledbxref_rows

  Usage: my @bssampledbxref_rows = $self->get_bssampledbxref_rows();
         $self->set_bssampledbxref_rows(\@bssampledbxref_rows);

  Desc: Get or set a list of bssampledbxref rows object into a sample object
 
  Ret:   Get => @bssampledbxref_row_object, a list of row objects 
                (CXGN::Biosource::Schema::BsSampleDbxref).
         Set => none
 
  Args:  Get => none
         Set => @bssampledbxref_row_object, an array ref of row objects 
                (CXGN::Biosource::Schema::BsSampleDbxref).
 
  Side_Effects: With set check if the argument is a row object. If fail, dies.
 
  Example: my @bssampledbxref_rows = $self->get_bssampledbxref_rows();
           $self->set_bssampledbxref_rows(\@bssampledbxref_rows);

=cut

sub get_bssampledbxref_rows {
  my $self = shift;
 
  return @{$self->{bssampledbxref_rows}}; 
}

sub set_bssampledbxref_rows {
  my $self = shift;
  my $bssampledbxref_row_aref = shift 
      || croak("FUNCTION PARAMETER ERROR: None bssampledbxref_row array ref was supplied for set_bssampledbxref_rows function.\n");
 
  if (ref($bssampledbxref_row_aref) ne 'ARRAY') {
      croak("SET ARGUMENT ERROR: $bssampledbxref_row_aref isn't an array reference.\n");
  }
  else {
      foreach my $bssampledbxref_row (@{$bssampledbxref_row_aref}) {  
          if (ref($bssampledbxref_row) ne 'CXGN::Biosource::Schema::BsSampleDbxref') {
              croak("SET ARGUMENT ERROR: $bssampledbxref_row isn't a bssampledbxref_row obj. (CXGN::Biosource::Schema::BsSampleDbxref).\n");
          }
      }
  }
  $self->{bssampledbxref_rows} = $bssampledbxref_row_aref;
}


=head2 accessors get_bssamplecvterm_rows, set_bssamplecvterm_rows

  Usage: my @bssamplecvterm_rows = $self->get_bssamplecvterm_rows();
         $self->set_bssamplecvterm_rows(\@bssamplecvterm_rows);

  Desc: Get or set a list of bssamplecvterm rows object into a sample object
 
  Ret:   Get => @bssamplecvterm_row_object, a list of row objects 
                (CXGN::Biosource::Schema::BsSampleCvterm).
         Set => none
 
  Args:  Get => none
         Set => @bssamplecvterm_row_object, an array ref of row objects 
                (CXGN::Biosource::Schema::BsSampleCvterm).
 
  Side_Effects: With set check if the argument is a row object. If fail, dies.
 
  Example: my @bssamplecvterm_rows = $self->get_bssamplecvterm_rows();
           $self->set_bssamplecvterm_rows(\@bssamplecvterm_rows);

=cut

sub get_bssamplecvterm_rows {
  my $self = shift;
 
  return @{$self->{bssamplecvterm_rows}}; 
}

sub set_bssamplecvterm_rows {
  my $self = shift;
  my $bssamplecvterm_row_aref = shift 
      || croak("FUNCTION PARAMETER ERROR: None bssamplecvterm_row array ref was supplied for set_bssamplecvterm_rows function.\n");
 
  if (ref($bssamplecvterm_row_aref) ne 'ARRAY') {
      croak("SET ARGUMENT ERROR: $bssamplecvterm_row_aref isn't an array reference.\n");
  }
  else {
      foreach my $bssamplecvterm_row (@{$bssamplecvterm_row_aref}) {  
          if (ref($bssamplecvterm_row) ne 'CXGN::Biosource::Schema::BsSampleCvterm') {
              croak("SET ARGUMENT ERROR: $bssamplecvterm_row isn't a bssamplecvterm_row obj. (CXGN::Biosource::Schema::BsSampleCvterm).\n");
          }
      }
  }
  $self->{bssamplecvterm_rows} = $bssamplecvterm_row_aref;
}


=head2 accessors get_bssamplefile_rows, set_bssamplefile_rows

  Usage: my @bssamplefile_rows = $self->get_bssamplefile_rows();
         $self->set_bssamplefile_rows(\@bssamplefile_rows);

  Desc: Get or set a list of bssamplefile rows object into a sample object
 
  Ret:   Get => @bssamplefile_row_object, a list of row objects 
                (CXGN::Biosource::Schema::BsSampleFile).
         Set => none
 
  Args:  Get => none
         Set => @bssamplefile_row_object, an array ref of row objects 
                (CXGN::Biosource::Schema::BsSampleFile).
 
  Side_Effects: With set check if the argument is a row object. If fail, dies.
 
  Example: my @bssamplefile_rows = $self->get_bssamplefile_rows();
           $self->set_bssamplefile_rows(\@bssamplefile_rows);

=cut

sub get_bssamplefile_rows {
  my $self = shift;
 
  return @{$self->{bssamplefile_rows}}; 
}

sub set_bssamplefile_rows {
  my $self = shift;
  my $bssamplefile_row_aref = shift 
      || croak("FUNCTION PARAMETER ERROR: None bssamplefile_row array ref was supplied for set_bssamplefile_rows function.\n");
 
  if (ref($bssamplefile_row_aref) ne 'ARRAY') {
      croak("SET ARGUMENT ERROR: $bssamplefile_row_aref isn't an array reference.\n");
  }
  else {
      foreach my $bssamplefile_row (@{$bssamplefile_row_aref}) {  
          if (ref($bssamplefile_row) ne 'CXGN::Biosource::Schema::BsSampleFile') {
              croak("SET ARGUMENT ERROR: $bssamplefile_row isn't a bssamplefile_row obj. (CXGN::Biosource::Schema::BsSampleFile).\n");
          }
      }
  }
  $self->{bssamplefile_rows} = $bssamplefile_row_aref;
}


=head2 accessors get_bssamplechildrenrelationship_rows, set_bssamplechildrenrelationship_rows

  Usage: my @bssamplerelationship_rows = $self->get_bssamplechildrenrelationship_rows();
         $self->set_bssamplechildrenrelationship_rows(\@bssamplechildrenrelationship_rows);

  Desc: Get or set a list of bssamplerelation rows object into a sample object, where
        subject_id is or will be sample_id
 
  Ret:   Get => @bssamplerelationship_row_object, a list of row objects 
                (CXGN::Biosource::Schema::BsSampleRelationship).
         Set => none
 
  Args:  Get => none
         Set => @bssamplerelationship_row_object, an array ref of row objects 
                (CXGN::Biosource::Schema::BsSampleRelationship).
 
  Side_Effects: With set check if the argument is a row object. If fail, dies.
                Also will check if the subject_id in the row is the same than the
                sample_id from the sample object. If both are defined and are different
                it will die.
 
  Example: my @bssamplerelationship_rows = $self->get_bssamplechildrenrelationship_rows();
           $self->set_bssamplechildrenrelationship_rows(\@bssamplechildrenrelationship_rows);

=cut

sub get_bssamplechildrenrelationship_rows {
  my $self = shift;
 
  return @{$self->{bssamplechildrenrelationship_rows}}; 
}

sub set_bssamplechildrenrelationship_rows {
  my $self = shift;
  my $bssamplerelationship_row_aref = shift 
      || croak("FUNCTION PARAMETER ERROR: None bssamplerelationship_row array ref was supplied for set_bssamplechildrenrelation_rows function.\n");
 
  if (ref($bssamplerelationship_row_aref) ne 'ARRAY') {
      croak("SET ARGUMENT ERROR: $bssamplerelationship_row_aref isn't an array reference.\n");
  }
  else {
      foreach my $bssamplerelationship_row (@{$bssamplerelationship_row_aref}) {  
          if (ref($bssamplerelationship_row) ne 'CXGN::Biosource::Schema::BsSampleRelationship') {
              croak("SET ARGUMENT ERROR: $bssamplerelationship_row isn't a bssamplerelationship_row obj. (CXGN::Biosource::Schema::BsSampleRelationship).\n");
          }

	  ## Also it will check the the subject_id in the $bssamplerelationship_row is sample_id or null

	  my $sample_id = $self->get_sample_id();
	  my $subject_id = $bssamplerelationship_row->get_column('subject_id');

	  if (defined $sample_id && defined $subject_id) {
	      if ($sample_id != $subject_id) {
		  croak("SET ARGUMENT ERROR: row:$bssamplerelationship_row can not be set as children relationship because row subject_id is different from object sample_id.\n");
	      }
	  }
      }
  }
  $self->{bssamplechildrenrelationship_rows} = $bssamplerelationship_row_aref;
}



=head2 accessors get_bssampleparentsrelationship_rows, set_bssampleparentsrelationship_rows

  Usage: my @bssamplerelationship_rows = $self->get_bssampleparentsrelationship_rows();
         $self->set_bssampleparentsrelationship_rows(\@bssampleparentsrelationship_rows);

  Desc: Get or set a list of bssamplerelationship rows object into a sample object, where
        object_id is or will be sample_id
 
  Ret:   Get => @bssamplerelationship_row_object, a list of row objects 
                (CXGN::Biosource::Schema::BsSampleRelationship).
         Set => none
 
  Args:  Get => none
         Set => @bssamplerelationship_row_object, an array ref of row objects 
                (CXGN::Biosource::Schema::BsSampleRelationship).
 
  Side_Effects: With set check if the argument is a row object. If fail, dies.
                Also will check if the object_id in the row is the same than the
                sample_id from the sample object. If both are defined and are different
                it will die.
 
  Example: my @bssamplerelationship_rows = $self->get_bssampleparentsrelationship_rows();
           $self->set_bssampleparentsrelationship_rows(\@bssampleparentrelationship_rows);

=cut

sub get_bssampleparentsrelationship_rows {
  my $self = shift;
 
  return @{$self->{bssampleparentsrelationship_rows}}; 
}

sub set_bssampleparentsrelationship_rows {
  my $self = shift;
  my $bssamplerelationship_row_aref = shift 
      || croak("FUNCTION PARAMETER ERROR: None bssamplerelationship_row array ref was supplied for set_bssampleparentsrelation_rows function.\n");
 
  if (ref($bssamplerelationship_row_aref) ne 'ARRAY') {
      croak("SET ARGUMENT ERROR: $bssamplerelationship_row_aref isn't an array reference.\n");
  }
  else {
      foreach my $bssamplerelationship_row (@{$bssamplerelationship_row_aref}) {  
          if (ref($bssamplerelationship_row) ne 'CXGN::Biosource::Schema::BsSampleRelationship') {
              croak("SET ARGUMENT ERROR: $bssamplerelationship_row isn't a bssamplerelationship_row obj. (CXGN::Biosource::Schema::BsSampleRelationship).\n");
          }

	  ## Also it will check the the subject_id in the $bssamplerelationship_row is sample_id or null

	  my $sample_id = $self->get_sample_id();
	  my $object_id = $bssamplerelationship_row->get_column('object_id');

	  if (defined $sample_id && defined $object_id) {
	      if ($sample_id != $object_id) {
		  croak("SET ARGUMENT ERROR: row:$bssamplerelationship_row can not be set as parent relationship because row object_id is different from object sample_id.\n");
	      }
	  }
      }
  }
  $self->{bssampleparentsrelationship_rows} = $bssamplerelationship_row_aref;
}




#################################
### DATA ACCESSORS FOR SAMPLE ###
#################################

=head2 get_sample_id, force_set_sample_id
  
  Usage: my $sample_id = $sample->get_sample_id();
         $sample->force_set_sample_id($sample_id);

  Desc: get or set a sample_id in a sample object. 
        set method should be USED WITH PRECAUTION
        If you want set a sample_id that do not exists into the database you 
        should consider that when you store this object you CAN STORE a 
        sample_id that do not follow the biosource.bs_sample_sample_id_seq

  Ret:  get=> $sample_id, a scalar.
        set=> none

  Args: get=> none
        set=> $sample_id, a scalar (constraint: it must be an integer)

  Side_Effects: none

  Example: my $sample_id = $sample->get_sample_id(); 

=cut

sub get_sample_id {
  my $self = shift;
  return $self->get_bssample_row->get_column('sample_id');
}

sub force_set_sample_id {
  my $self = shift;
  my $data = shift ||
      croak("FUNCTION PARAMETER ERROR: None sample_id was supplied for force_set_sample_id function");

  unless ($data =~ m/^\d+$/) {
      croak("DATA TYPE ERROR: The sample_id ($data) for $self->force_set_sample_id() ISN'T AN INTEGER.\n");
  }

  $self->get_bssample_row()
       ->set_column( sample_id => $data );
 
}

=head2 accessors get_sample_name, set_sample_name

  Usage: my $sample_name = $sample->get_sample_name();
         $sample->set_sample_name($sample_name);

  Desc: Get or set the sample_name from sample object. 

  Ret:  get=> $sample_name, a scalar
        set=> none

  Args: get=> none
        set=> $sample_name, a scalar

  Side_Effects: none

  Example: my $sample_name = $sample->get_sample_name();
           $sample->set_sample_name($new_name);
=cut

sub get_sample_name {
  my $self = shift;
  return $self->get_bssample_row->get_column('sample_name'); 
}

sub set_sample_name {
  my $self = shift;
  my $data = shift 
      || croak("FUNCTION PARAMETER ERROR: None data was supplied for $self->set_sample_name function.\n"); 

  $self->get_bssample_row()
       ->set_column( sample_name => $data );
}


=head2 accessors get_alternative_name, set_alternative_name

  Usage: my $alternative_name = $sample->get_alternative_name();
         $sample->set_alternative_name($alternative_name);

  Desc: Get or set the alternative_name from a sample object 

  Ret:  get=> $alternative_name, a scalar
        set=> none

  Args: get=> none
        set=> $alternative_name, a scalar

  Side_Effects: none

  Example: my $alternative_name = $sample->get_alternative_name();
           $sample->set_alternative_name($alternative_name);
=cut

sub get_alternative_name {
  my $self = shift;
  return $self->get_bssample_row->get_column('alternative_name'); 
}

sub set_alternative_name {
  my $self = shift;
  my $data = shift;

  $self->get_bssample_row()
       ->set_column( alternative_name => $data );
}

=head2 accessors get_type_id, set_type_id

  Usage: my $cvterm_id = $sample->get_type_id();
         $sample->set_type_id($cvterm_id);
 
  Desc: Get or set type_id from a sample object. 
 
  Ret:  get=> $type_id, a scalar
        set=> none
 
  Args: get=> none
        set=> $type_id, a scalar
 
  Side_Effects: die if the argument supplied is not an integer
 
  Example: my $cvterm_id = $sample->get_type_id();

=cut

sub get_type_id {
  my $self = shift;
  return $self->get_bssample_row->get_column('type_id'); 
}

sub set_type_id {
  my $self = shift;
  my $data = shift 
      || croak("FUNCTION PARAMETER ERROR: None data was supplied for $self->set_type_id function.\n");

  unless ($data =~ m/^\d+$/) {
      croak("DATA TYPE ERROR: The type_id ($data) for $self->set_type_id() ISN'T AN INTEGER.\n");
  }

  $self->get_bssample_row()
       ->set_column( type_id => $data );
}

=head2 accessors get_description, set_description

  Usage: my $description = $sample->get_description();
         $sample->set_description($description);

  Desc: Get or set the description from a sample object 

  Ret:  get=> $description, a scalar
        set=> none

  Args: get=> none
        set=> $description, a scalar

  Side_Effects: none

  Example: my $description = $sample->get_description();
           $sample->set_description($description);
=cut

sub get_description {
  my $self = shift;
  return $self->get_bssample_row->get_column('description'); 
}

sub set_description {
  my $self = shift;
  my $data = shift;

  $self->get_bssample_row()
       ->set_column( description => $data );
}

=head2 get_contact_id, set_contact_id
  
  Usage: my $contact_id = $sample->get_contact_id();
         $sample->set_contact_id($contact_id);

  Desc: get or set a contact_id in a sample object. 

  Ret:  get=> $contact_id, a scalar.
        set=> none

  Args: get=> none
        set=> $contact_id, a scalar (constraint: it must be an integer)

  Side_Effects: die if the argument supplied is not an integer

  Example: my $contact_id = $sample->get_contact_id(); 

=cut

sub get_contact_id {
  my $self = shift;
  return $self->get_bssample_row->get_column('contact_id');
}

sub set_contact_id {
  my $self = shift;
  my $data = shift;

  unless ($data =~ m/^\d+$/) {
      croak("DATA TYPE ERROR: The contact_id ($data) for $self->set_contact_id() ISN'T AN INTEGER.\n");
  }

  $self->get_bssample_row()
       ->set_column( contact_id => $data );
 
}

=head2 get_contact_by_username, set_contact_by_username
  
  Usage: my $contact_username = $sample->get_contact_by_username();
         $sample->set_contact_by_username($contact_username);

  Desc: get or set a contact_id in a sample object using username 

  Ret:  get=> $contact_username, a scalar.
        set=> none

  Args: get=> none
        set=> $contact_username, a scalar (constraint: it must be an integer)

  Side_Effects: die if the argument supplied is not an integer

  Example: my $contact = $sample->get_contact_by_username(); 

=cut

sub get_contact_by_username {
  my $self = shift;

  my $contact_id = $self->get_bssample_row
                        ->get_column('contact_id');

  if (defined $contact_id) {

      ## This is a temp simple SQL query. It should be replaced by DBIx::Class search when the person module will be developed 

      my $query = "SELECT username FROM sgn_people.sp_person WHERE sp_person_id = ?";
      my ($username) = $self->get_schema()
	                    ->storage()
			    ->dbh()
			    ->selectrow_array($query, undef, $contact_id);

      unless (defined $username) {
	  croak("DATABASE INTEGRITY ERROR: sp_person_id=$contact_id defined in biosource.bs_sample don't exists in sp_person table.\n");
      }
      else {
	  return $username
      }
  } 
}

sub set_contact_by_username {
  my $self = shift;
  my $data = shift ||
      croak("SET ARGUMENT ERROR: None argument was supplied to the $self->set_contact_by_username function.\n");
  
  my $query = "SELECT sp_person_id FROM sgn_people.sp_person WHERE username = ?";
  my ($contact_id) = $self->get_schema()
                          ->storage()
			  ->dbh()
			  ->selectrow_array($query, undef, $data);
  
  unless (defined $contact_id) {
      croak("DATABASE COHERENCE ERROR: username=$data supplied to function set_contact_by_username don't exists in sp_person table.\n");
  }
  else {
      $self->get_bssample_row()
	   ->set_column( contact_id => $contact_id );
  }
 
}

=head2 get_organism_id, set_organism_id
  
  Usage: my $organism_id = $sample->get_organism_id();
         $sample->set_organism_id($organism_id);

  Desc: get or set a organism_id in a sample object. 

  Ret:  get=> $organism_id, a scalar.
        set=> none

  Args: get=> none
        set=> $organism_id, a scalar (constraint: it must be an integer)

  Side_Effects: die if the argument supplied is not an integer

  Example: my $organism_id = $sample->get_organism_id(); 

=cut

sub get_organism_id {
  my $self = shift;
  return $self->get_bssample_row->get_column('organism_id');
}

sub set_organism_id {
  my $self = shift;
  my $data = shift;

  ## Organism_id should be able to be null to delete organism associations from some samples

  unless (defined $data && $data =~ m/^\d+$/) {
      croak("DATA TYPE ERROR: The organism_id ($data) for $self->set_organism_id() ISN'T AN INTEGER.\n");
  }

  $self->get_bssample_row()
       ->set_column( organism_id => $data );
 
}

=head2 get_organism_by_species, set_organism_by_species
  
  Usage: my $species = $sample->get_organism_by_species();
         $sample->set_organism_by_species($species);

  Desc: get or set a organism_id in a sample object using species 

  Ret:  get=> $species, a scalar.
        set=> none

  Args: get=> none
        set=> $species, a scalar

  Side_Effects: die if the argument supplied is not into the db

  Example: my $species = $sample->get_organism_by_species();
           $sample->set_organism_by_species('Solanum lycopersicum');

=cut

sub get_organism_by_species {
  my $self = shift;

  my $organism_id = $self->get_bssample_row
                         ->get_column('organism_id');

  my $species;
  if (defined $organism_id) {

      my ($organism_row) = $self->get_schema()
	                        ->resultset('Organism::Organism')
			        ->search({ organism_id => $organism_id });

      if (defined $organism_row) {
	  $species = $organism_row->get_column('species');
      }
  
      unless (defined $species) {
	  croak("DATABASE INTEGRITY ERROR: organism_id=$organism_id defined in biosource.bs_sample don't exists in organism table.\n");
      }
  } 
  return $species;
}

sub set_organism_by_species {
  my $self = shift;
  my $data = shift ||
      croak("SET ARGUMENT ERROR: None argument was supplied to the $self->set_organism_by_species function.\n");
  
  my ($organism_row) = $self->get_schema()
	                        ->resultset('Organism::Organism')
			        ->search({ species => $data });

  if (defined $organism_row) {
      my $organism_id = $organism_row->get_column('organism_id');
      $self->get_bssample_row()
	   ->set_column( organism_id => $organism_id );
  }
  else {
      croak("DATABASE COHERENCE ERROR: species=$data supplied to function set_organism_by_species don't exists in organism table.\n");
  }
}

=head2 accessors get_stock_id, set_stock_id

  Usage: my $stock_id = $sample->get_stock_id();
         $sample->set_stock_id($stock_id);
 
  Desc: Get or set stock_id from a sample object. 
 
  Ret:  get=> $stock_id, a scalar
        set=> none
 
  Args: get=> none
        set=> $stock_id, a scalar
 
  Side_Effects: die if the argument supplied is not an integer
 
  Example: my $stock_id = $sample->get_stock_id();

=cut

sub get_stock_id {
  my $self = shift;
  return $self->get_bssample_row->get_column('stock_id'); 
}

sub set_stock_id {
  my $self = shift;
  my $data = shift 
      || croak("FUNCTION PARAMETER ERROR: None data was supplied for $self->set_stock_id function.\n");

  unless ($data =~ m/^\d+$/) {
      croak("DATA TYPE ERROR: The stock_id ($data) for $self->set_stock_id() ISN'T AN INTEGER.\n");
  }

  $self->get_bssample_row()
       ->set_column( stock_id => $data );
}

=head2 accessors get_protocol_id, set_protocol_id

  Usage: my $protocol_id = $sample->get_protocol_id();
         $sample->set_protocol_id($protocol_id);
 
  Desc: Get or set protocol_id from a sample object. 
 
  Ret:  get=> $protocol_id, a scalar
        set=> none
 
  Args: get=> none
        set=> $protocol_id, a scalar
 
  Side_Effects: die if the argument supplied is not an integer
 
  Example: my $protocol_id = $sample->get_protocol_id();

=cut

sub get_protocol_id {
  my $self = shift;
  return $self->get_bssample_row->get_column('protocol_id'); 
}

sub set_protocol_id {
  my $self = shift;
  my $data = shift 
      || croak("FUNCTION PARAMETER ERROR: None data was supplied for $self->set_protocol_id function.\n");

  unless ($data =~ m/^\d+$/) {
      croak("DATA TYPE ERROR: The protocol_id ($data) for $self->set_protocol_id() ISN'T AN INTEGER.\n");
  }

  $self->get_bssample_row()
       ->set_column( protocol_id => $data );
}

=head2 get_protocol_by_name, set_protocol_by_name
  
  Usage: my $protocol = $sample->get_protocol_by_name();
         $sample->set_protocol_by_name($name);

  Desc: get or set a protocol_id in a sample object using name 

  Ret:  get=> $name, a scalar.
        set=> none

  Args: get=> none
        set=> $name, a scalar

  Side_Effects: die if the argument supplied is not into the db

  Example: my $name = $sample->get_protocol_by_name();
           $sample->set_protocol_by_name('Fruit mRNA extraction');

=cut

sub get_protocol_by_name {
  my $self = shift;

  my $protocol_id = $self->get_bssample_row
                         ->get_column('protocol_id');

  my $name;
  if (defined $protocol_id) {

      my ($protocol_row) = $self->get_schema()
	                        ->resultset('BsProtocol')
			        ->search({ protocol_id => $protocol_id });

      if (defined $protocol_row) {
	  $name = $protocol_row->get_column('protocol_name');
      }
  
      unless (defined $name) {
	  croak("DATABASE INTEGRITY ERROR: protocol_id=$protocol_id defined in biosource.bs_sample don't exists in bs_protocol table.\n");
      }
  } 
  return $name;
}

sub set_protocol_by_name {
  my $self = shift;
  my $data = shift ||
      croak("SET ARGUMENT ERROR: None argument was supplied to the $self->set_protocol_by_name function.\n");
  
  my ($protocol_row) = $self->get_schema()
	                     ->resultset('BsProtocol')
			     ->search({ protocol_name => $data });

  if (defined $protocol_row) {
      my $protocol_id = $protocol_row->get_column('protocol_id');
      $self->get_bssample_row()
	   ->set_column( protocol_id => $protocol_id );
  }
  else {
      croak("DATABASE COHERENCE ERROR: protocol_name=$data supplied to function set_protocol_by_name don't exists in protocol table.\n");
  }
}




######################################
### DATA ACCESSORS FOR SAMPLE PUBS ###
######################################

=head2 add_publication

  Usage: $sample->add_publication($pub_id);

  Desc: Add a publication to the pub_ids associated to sample object
        using different arguments as pub_id, title or dbxref_accession 

  Ret:  None

  Args: $pub_id, a publication id. 
        To use with $pub_id: 
          $sample->add_publication($pub_id);
        To use with $pub_title
          $sample->add_publication({ title => $pub_title } );
        To use with pubmed accession
          $sample->add_publication({ dbxref_accession => $accesssion});
          
  Side_Effects: die if the parameter is not an object

  Example: $sample->add_publication($pub_id);

=cut

sub add_publication {
    my $self = shift;
    my $pub = shift ||
        croak("FUNCTION PARAMETER ERROR: None pub was supplied for $self->add_publication function.\n");

    my $pub_id;
    if ($pub =~ m/^\d+$/) {
        $pub_id = $pub;
    }
    elsif (ref($pub) eq 'HASH') {
        my $pub_row; 
        if (exists $pub->{'title'}) {
	    my $title = $pub->{'title'};
            ($pub_row) = $self->get_schema()
                              ->resultset('Pub::Pub')
                              ->search( {title => { 'ilike', '%'.$title.'%' } });
        }
        elsif (exists $pub->{'dbxref_accession'}) {
                ($pub_row) = $self->get_schema()
                              ->resultset('Pub::Pub')
                              ->search( 
                                        { 'dbxref.accession' => $pub->{'dbxref_accession'} }, 
                                        { join => { 'pub_dbxrefs' => 'dbxref' } }, 
                                      );
            
        }
        
        unless (defined $pub_row) {
            croak("DATABASE ARGUMENT ERROR: Publication data used as argument for $self->add_publication function don't exists in DB.\n");
        }
        $pub_id = $pub_row->get_column('pub_id');
        
    }
    else {
        croak("SET ARGUMENT ERROR: Publication ($pub) isn't a pub_id, or hash with title or dbxref_accession keys.\n");
    }
    my $samplepub_row = $self->get_schema()
                             ->resultset('BsSamplePub')
                             ->new({ pub_id => $pub_id});
    
    if (defined $self->get_sample_id() ) {
        $samplepub_row->set_column( sample_id => $self->get_sample_id() );
    }

    my @samplepub_rows = $self->get_bssamplepub_rows();
    push @samplepub_rows, $samplepub_row;
    $self->set_bssamplepub_rows(\@samplepub_rows);
}

=head2 get_publication_list

  Usage: my @pub_list = $sample->get_publication_list();

  Desc: Get a list of publications associated to this sample

  Ret: An array of pub_ids by default, but can be titles
       or accessions using an argument

  Args: None or a column to get.

  Side_Effects: die if the parameter is not an object

  Example: my @pub_id_list = $sample->get_publication_list();
           my @pub_title_list = $sample->get_publication_list('title');
           my @pub_title_accs = $sample->get_publication_list('dbxref.accession');


=cut

sub get_publication_list {
    my $self = shift;
    my $field = shift;

    my @pub_list = ();

    my @samplepub_rows = $self->get_bssamplepub_rows();
    foreach my $samplepub_row (@samplepub_rows) {
        my $pub_id = $samplepub_row->get_column('pub_id');
        my ($pub_row) = $self->get_schema()
                             ->resultset('Pub::Pub')
                             ->search(
                                       { 'me.pub_id' => $pub_id },
                                       {
                                         '+select' => ['dbxref.accession'],
                                         '+as'     => ['accession'],
                                         join => { 'pub_dbxrefs' => 'dbxref' },
                                       }
                                     );

        if (defined $field) {
            push @pub_list, $pub_row->get_column($field);
        }
        else {
            push @pub_list, $pub_row->get_column('pub_id');
        }
    }
    
    return @pub_list;                  
}


########################################
### DATA ACCESSORS FOR SAMPLE DBXREF ###
########################################

=head2 add_dbxref

  Usage: $sample->add_dbxref($dbxref_id);

  Desc: Add a dbxref to the dbxref_ids associated to sample object
        using different arguments as dbxref_id or accession 

  Ret:  None

  Args: $dbxref_id, a dbxref id. 
        To use with $dbxref_id: 
          $sample->add_dbxref($dbxref_id);
        To use with accession
          $sample->add_dbxref({ accession => $accesssion});
          
  Side_Effects: die if the parameter is not an object

  Example: $sample->add_dbxref($dbxref_id);

=cut

sub add_dbxref {
    my $self = shift;
    my $dbxref = shift ||
        croak("FUNCTION PARAMETER ERROR: None dbxref was supplied for $self->add_dbxref function.\n");

    my $dbxref_id;
    if ($dbxref =~ m/^\d+$/) {
        $dbxref_id = $dbxref;
    }
    elsif (ref($dbxref) eq 'HASH') {
        my $dbxref_row; 
        
        if (exists $dbxref->{'accession'}) {
                ($dbxref_row) = $self->get_schema()
                                     ->resultset('General::Dbxref')
                                     ->search( 
                                               { 'accession' => $dbxref->{'accession'} }, 
                                             );
            
        }
        
        unless (defined $dbxref_row) {
            croak("DATABASE ARGUMENT ERROR: Dbxref data used as argument for $self->add_dbxref function don't exists in DB.\n");
        }
        $dbxref_id = $dbxref_row->get_column('dbxref_id');
        
    }
    else {
        croak("SET ARGUMENT ERROR: Dbxref ($dbxref) isn't a dbxref_id, or hash with accession keys.\n");
    }
    my $sampledbxref_row = $self->get_schema()
                                ->resultset('BsSampleDbxref')
                                ->new({ dbxref_id => $dbxref_id});
    
    if (defined $self->get_sample_id() ) {
        $sampledbxref_row->set_column( sample_id => $self->get_sample_id() );
    }

    my @sampledbxref_rows = $self->get_bssampledbxref_rows();
    push @sampledbxref_rows, $sampledbxref_row;
    $self->set_bssampledbxref_rows(\@sampledbxref_rows);
}

=head2 get_dbxref_list

  Usage: my @dbxref_list = $sample->get_dbxref_list();

  Desc: Get a list of dbxrefs associated to this sample

  Ret: An array of dbxrefs_ids by default, but can be accessions 
       using an argument

  Args: None or a column to get.

  Side_Effects: die if the parameter is not an object

  Example: my @dbxref_id_list = $sample->get_dbxref_list();
           my @dbxref_accessions = $sample->get_dbxref_list('accession');


=cut

sub get_dbxref_list {
    my $self = shift;
    my $field = shift;

    my @dbxref_list = ();

    my @sampledbxref_rows = $self->get_bssampledbxref_rows();
    foreach my $sampledbxref_row (@sampledbxref_rows) {
        my $dbxref_id = $sampledbxref_row->get_column('dbxref_id');
        my ($dbxref_row) = $self->get_schema()
                                ->resultset('General::Dbxref')
                                ->search(
                                          { 'dbxref_id' => $dbxref_id },
                                        );

        if (defined $field) {
            push @dbxref_list, $dbxref_row->get_column($field);
        }
        else {
            push @dbxref_list, $dbxref_row->get_column('dbxref_id');
        }
    }
    
    return @dbxref_list;                  
}


########################################
### DATA ACCESSORS FOR SAMPLE CVTERM ###
########################################

=head2 add_cvterm

  Usage: $sample->add_cvterm($cvterm_id);

  Desc: Add a cvterm to the cvterm_ids associated to sample object
        using different arguments as cvterm_id or name 

  Ret:  None

  Args: $cvterm_id, a cvterm id. 
        To use with $cvterm_id: 
          $sample->add_cvterm($cvterm_id);
        To use with name
          $sample->add_cvterm({ name => $name});
          
  Side_Effects: die if the parameter is not an object

  Example: $sample->add_cvterm($cvterm_id);
           $sample->add_cvterm({ name => 'normalized' })

=cut

sub add_cvterm {
    my $self = shift;
    my $cvterm = shift ||
        croak("FUNCTION PARAMETER ERROR: None cvterm was supplied for $self->add_cvterm function.\n");

    my $cvterm_id;
    if ($cvterm =~ m/^\d+$/) {
        $cvterm_id = $cvterm;
    }
    elsif (ref($cvterm) eq 'HASH') {
        my $cvterm_row; 
        
        if (exists $cvterm->{'name'}) {
                ($cvterm_row) = $self->get_schema()
                                     ->resultset('Cv::Cvterm')
                                     ->search( 
                                               { 'name' => $cvterm->{'name'} }, 
                                             );
            
        }
        
        unless (defined $cvterm_row) {
            croak("DATABASE ARGUMENT ERROR: Cvterm data used as argument for $self->add_cvterm function don't exists in DB.\n");
        }
        $cvterm_id = $cvterm_row->get_column('cvterm_id');
        
    }
    else {
        croak("SET ARGUMENT ERROR: Cvterm ($cvterm) isn't a cvterm_id, or hash with accession keys.\n");
    }
    my $samplecvterm_row = $self->get_schema()
                                ->resultset('BsSampleCvterm')
                                ->new({ cvterm_id => $cvterm_id});
    
    if (defined $self->get_sample_id() ) {
        $samplecvterm_row->set_column( sample_id => $self->get_sample_id() );
    }

    my @samplecvterm_rows = $self->get_bssamplecvterm_rows();
    push @samplecvterm_rows, $samplecvterm_row;
    $self->set_bssamplecvterm_rows(\@samplecvterm_rows);
}

=head2 get_cvterm_list

  Usage: my @cvterm_list = $sample->get_cvterm_list();

  Desc: Get a list of cvterms associated to this sample

  Ret: An array of cvterms_ids by default, but can be names 
       using an argument

  Args: None or a column to get.

  Side_Effects: die if the parameter is not an object

  Example: my @cvterm_id_list = $sample->get_cvterm_list();
           my @cvterm_names = $sample->get_cvterm_list('name');


=cut

sub get_cvterm_list {
    my $self = shift;
    my $field = shift;

    my @cvterm_list = ();

    my @samplecvterm_rows = $self->get_bssamplecvterm_rows();
    foreach my $samplecvterm_row (@samplecvterm_rows) {
        my $cvterm_id = $samplecvterm_row->get_column('cvterm_id');
        my ($cvterm_row) = $self->get_schema()
                                ->resultset('Cv::Cvterm')
                                ->search(
                                          { 'cvterm_id' => $cvterm_id },
                                        );

        if (defined $field) {
            push @cvterm_list, $cvterm_row->get_column($field);
        }
        else {
            push @cvterm_list, $cvterm_row->get_column('cvterm_id');
        }
    }
    
    return @cvterm_list;                  
}


######################################
### DATA ACCESSORS FOR SAMPLE FILE ###
######################################

=head2 add_file

  Usage: $sample->add_file($file_id);

  Desc: Add a file to the file_ids associated to sample object
        using different arguments as file_id or filename+dirname 

  Ret:  None

  Args: $file_id, a file id. 
        To use with $file_id: 
          $sample->add_file($file_id);
        To use with basename+dirname
          $sample->add_file({ basename => $filename, dirname => $dirname });
          
  Side_Effects: die if the parameter is not an object

  Example: $sample->add_file($file_id);

=cut

sub add_file {
    my $self = shift;
    my $file = shift ||
        croak("FUNCTION PARAMETER ERROR: None file was supplied for $self->add_file function.\n");

    my $file_id;
    if ($file =~ m/^\d+$/) {
        $file_id = $file;
    }
    elsif (ref($file) eq 'HASH') {
        my $file_row; 
        
        if (exists $file->{'basename'} && exists $file->{'dirname'}) {
                ($file_row) = $self->get_schema()
                                   ->resultset('MdFiles')
                                   ->search( 
                                               { 
						   'basename' => $file->{'basename'},
						   'dirname'  => $file->{'dirname'}
					       }, 
                                           );
            
        }
        
        unless (defined $file_row) {
            croak("DATABASE ARGUMENT ERROR: File data used as argument for $self->add_file function don't exists in DB.\n");
        }
        $file_id = $file_row->get_column('file_id');
        
    }
    else {
        croak("SET ARGUMENT ERROR: File ($file) isn't a file_id, or hash with accession keys.\n");
    }
    my $samplefile_row = $self->get_schema()
                               ->resultset('BsSampleFile')
                               ->new({ file_id => $file_id});
    
    if (defined $self->get_sample_id() ) {
        $samplefile_row->set_column( sample_id => $self->get_sample_id() );
    }

    my @samplefile_rows = $self->get_bssamplefile_rows();
    push @samplefile_rows, $samplefile_row;
    $self->set_bssamplefile_rows(\@samplefile_rows);
}

=head2 get_file_list

  Usage: my @file_list = $sample->get_file_list();

  Desc: Get a list of files associated to this sample

  Ret: An array of file_ids by default, but can be filenames 
       using an argument

  Args: None or a column to get.

  Side_Effects: die if the parameter is not an object

  Example: my @file_id_list = $sample->get_file_list();
           my @filenames = $sample->get_file_list('basename');


=cut

sub get_file_list {
    my $self = shift;
    my $field = shift;

    my @file_list = ();

    my @samplefile_rows = $self->get_bssamplefile_rows();
    foreach my $samplefile_row (@samplefile_rows) {
        my $file_id = $samplefile_row->get_column('file_id');
        my ($file_row) = $self->get_schema()
                              ->resultset('MdFiles')
                              ->search(
                                        { 'file_id' => $file_id },
                                      );

        if (defined $field) {
            push @file_list, $file_row->get_column($field);
        }
        else {
            push @file_list, $file_row->get_column('file_id');
        }
    }
    
    return @file_list;                  
}

##############################################
### DATA ACCESSORS FOR SAMPLE RELATIONSHIP ###
##############################################

=head2 add_child_relationship

  Usage: $sample->add_child_relationship( $hash_ref );

  Desc: Add a child relationship to a sample (sample object
        will be subject_sample).

  Ret:  None

  Args: $hash_reference argument with the following keys:
         object_id  => $sample_id,
         type_id    => $cvterm_id,
         value      => $note_text,
         rank       => $rank,
          
  Side_Effects: die if the parameter is not an object

  Example: $sample->add_child_relationship(
                             {
                               object_id  => $sample_id,
                               type_id    => $cvterm_id,
                               value      => $note_text,
                               rank       => $rank,
                             }
                           );

=cut

sub add_child_relationship {
    my $self = shift;
    my $hashref = shift ||
        croak("FUNCTION PARAMETER ERROR: None hash reference was supplied for $self->add_children_relationship function.\n");

    if (ref($hashref) eq 'HASH') {
        
	## First check the arguments.

	if (exists $hashref->{'object_id'} && $hashref->{'object_id'} =~ m/^\d+$/) {

	    ## Check if exists a sample_id = object_sample_id

	    my ($sample_row) = $self->get_schema()
                                    ->resultset('BsSample')
                                    ->search( { 'sample_id' => $hashref->{'object_id'} } );
	    
	    unless (defined $sample_row) {
		croak("DATABASE ARGUMENT ERROR: object_id=$hashref->{'object_id'} does not exists into bs_sample table in the database.\n");
	    }
	}
	else {
	    croak("DATABASE ARGUMENT ERROR: hash reference argument have not object_id key or it is not an integer.\n");
	}
	
	if (exists $hashref->{'type_id'} && $hashref->{'type_id'} =~ m/^\d+$/) {

	    ## Check if exists a cvterm_id = type_id

	    my ($cvterm_row) = $self->get_schema()
                                     ->resultset('Cv::Cvterm')
                                     ->search( { 'cvterm_id' => $hashref->{'type_id'} } ); 
	    
	    unless (defined $cvterm_row) {
		croak("DATABASE ARGUMENT ERROR: type_id=$hashref->{'type_id'} does not exists into cvterm table in the database.\n");
	    }
	}
	else {
	    croak("DATABASE ARGUMENT ERROR: hash reference argument have not type_id key or it is not an integer.\n");
	}

	unless (exists $hashref->{'rank'}) {

	   croak("DATABASE ARGUMENT ERROR: hash reference argument have not rank key.\n");
	}
	unless ($hashref->{'rank'} =~ m/^\d+$/) {

	    croak("DATABASE ARGUMENT ERROR: hash reference argument is not an integer.\n");
	}
    }
    else {
	croak("SET ARGUMENT ERROR: The argument ($hashref) isn't a hash reference.\n");
    }

    my $samplerelationship_row = $self->get_schema()
                                       ->resultset('BsSampleRelationship')
                                       ->new($hashref);
	
    if (defined $self->get_sample_id() ) {
	$samplerelationship_row->set_column( subject_id => $self->get_sample_id() );
    }
	
    my @samplechildren_rs_rows = $self->get_bssamplechildrenrelationship_rows();
    push @samplechildren_rs_rows, $samplerelationship_row;
    $self->set_bssamplechildrenrelationship_rows(\@samplechildren_rs_rows);
}


=head2 add_parent_relationship

  Usage: $sample->add_parent_relationship( $hash_ref );

  Desc: Add a parent relationship to a sample (sample object
        will be object_sample_id).

  Ret:  None

  Args: $hash_reference argument with the following keys:
         subject_id => $sample_id,
         type_id    => $cvterm_id,
         value      => $note_text,
         rank       => $rank,
          
  Side_Effects: die if the parameter is not an object

  Example: $sample->add_parent_relationship(
                             {
                               subject_id => $sample_id,
                               type_id    => $cvterm_id,
                               value      => $note_text,
                               rank       => $rank,
                             }
                           );

=cut

sub add_parent_relationship {
    my $self = shift;
    my $hashref = shift ||
        croak("FUNCTION PARAMETER ERROR: None hash reference was supplied for $self->add_parent_relationship function.\n");

    if (ref($hashref) eq 'HASH') {
        
	## First check the arguments.

	if (exists $hashref->{'subject_id'} && $hashref->{'subject_id'} =~ m/^\d+$/) {

	    ## Check if exists a sample_id = subject_id

	    my ($sample_row) = $self->get_schema()
                                    ->resultset('BsSample')
                                    ->search( { 'sample_id' => $hashref->{'subject_id'} } );
	    
	    unless (defined $sample_row) {
		croak("DATABASE ARGUMENT ERROR: subject_id=$hashref->{'subject_id'} does not exists into bs_sample table in the database.\n");
	    }
	}
	else {
	    croak("DATABASE ARGUMENT ERROR: hash reference argument have not subject_id key or it is not an integer.\n");
	}
	
	if (exists $hashref->{'type_id'} && $hashref->{'type_id'} =~ m/^\d+$/) {

	    ## Check if exists a cvterm_id = type_id

	    my ($cvterm_row) = $self->get_schema()
                                     ->resultset('Cv::Cvterm')
                                     ->search( { 'cvterm_id' => $hashref->{'type_id'} } ); 
	    
	    unless (defined $cvterm_row) {
		croak("DATABASE ARGUMENT ERROR: type_id=$hashref->{'type_id'} does not exists into cvterm table in the database.\n");
	    }
	}
	else {
	    croak("DATABASE ARGUMENT ERROR: hash reference argument have not type_id key or it is not an integer.\n");
	}

	unless (exists $hashref->{'rank'}) {

	   croak("DATABASE ARGUMENT ERROR: hash reference argument have not rank key.\n");
	}
	unless ($hashref->{'rank'} =~ m/^\d+$/) {

	    croak("DATABASE ARGUMENT ERROR: hash reference argument is not an integer.\n");
	}
    }
    else {
	croak("SET ARGUMENT ERROR: The argument ($hashref) isn't a hash reference.\n");
    }

    my $samplerelationship_row = $self->get_schema()
                                       ->resultset('BsSampleRelationship')
                                       ->new($hashref);
	
    if (defined $self->get_sample_id() ) {
	$samplerelationship_row->set_column( object_id => $self->get_sample_id() );
    }
	
    my @sampleparent_rs_rows = $self->get_bssampleparentsrelationship_rows();
    push @sampleparent_rs_rows, $samplerelationship_row;
    $self->set_bssampleparentsrelationship_rows(\@sampleparent_rs_rows);
}

=head2 get_children_relationship

  Usage: @children_samples = $sample->get_children_relationship();

  Desc: Get a list of CXGN::Biosource::Sample objects with the
        associated as children with the target Sample object

  Ret:  An array of CXGN::Biosource::Sample objects

  Args: None
          
  Side_Effects: None

  Example: my @children_samples = $sample->get_children_relationship();

=cut

sub get_children_relationship {
    my $self = shift;

    my @children = ();

    my @samplerelationship_rows = $self->get_bssamplechildrenrelationship_rows();
    foreach my $sample_rs_row (@samplerelationship_rows) {
        my $children_id = $sample_rs_row->get_column('object_id');
       
	my $children_sample = __PACKAGE__->new($self->get_schema(), $children_id);

	push @children, $children_sample;
    }
    return @children;                  
}


=head2 get_parents_relationship

  Usage: @parents_samples = $sample->get_parents_relationship();

  Desc: Get a list of CXGN::Biosource::Sample objects with the
        associated as parents with the target Sample object

  Ret:  An array of CXGN::Biosource::Sample objects

  Args: None
          
  Side_Effects: None

  Example: my @parents_samples = $sample->get_parents_relationship();

=cut

sub get_parents_relationship {
    my $self = shift;

    my @parents = ();

    my @samplerelationship_rows = $self->get_bssampleparentsrelationship_rows();
    foreach my $sample_rs_row (@samplerelationship_rows) {
        my $parent_id = $sample_rs_row->get_column('subject_id');
       
	my $parent_sample = __PACKAGE__->new($self->get_schema(), $parent_id);

	push @parents, $parent_sample;
    }
    return @parents;                  
}

=head2 get_brothers_relationship

  Usage: @brothers_samples = $sample->get_brothers_relationship();

  Desc: Get a list of CXGN::Biosource::Sample objects with the
        same parents than the sample

  Ret:  An array of CXGN::Biosource::Sample objects

  Args: None
          
  Side_Effects: None

  Example: my @brothers_samples = $sample->get_brothers_relationship();

=cut

sub get_brothers_relationship {
    my $self = shift;

    my @brothers = ();

    ## It will take the list of parent_ids, to compare with the list of the
    ## children's parent ids. If it is the same, it will be pushed into the
    ## brothers array.
    
    my @parents_id_list = ();
    my @parents_list = $self->get_parents_relationship();
    foreach my $parent (@parents_list) {

	my $parent_id = $parent->get_sample_id();
	push @parents_id_list, $parent_id;
    }
    

    foreach my $parent_c (@parents_list) {
        my @children_list = $parent_c->get_children_relationship();
       
	foreach my $child (@children_list) {
	    
	    ## Also, it should not add itself

	    if ($child->get_sample_id() != $self->get_sample_id() ) {

		my @child_parents_id_list = ();
		my @child_parents_list = $child->get_parents_relationship();
		foreach my $child_parent (@child_parents_list) {

		    my $child_parent_id = $child_parent->get_sample_id();
		    push @child_parents_id_list, $child_parent_id;
		}

		my $parents_ids = join(',', sort {$a <=> $b} @parents_id_list);
		my $child_parents_ids = join(',', sort {$a <=> $b} @child_parents_id_list);
	    
		if ($child_parents_ids eq $parents_ids) {
		    push @brothers, $child;
		}
	    }
	}
    }
    return @brothers;                  
}


=head2 get_relationship

  Usage: %related_samples = $sample->get_relationship();

  Desc: Get a hash of CXGN::Biosource::Sample objects related with
        the sample object

  Ret:  A hash with keys  = children OR parents
                    value = array reference of 
                            CXGN::Biosource::Sample objects

  Args: None
          
  Side_Effects: None

  Example: my %related_samples = $sample->get_relationship();

=cut

sub get_relationship {
    my $self = shift;

    my @parents_samples = $self->get_parents_relationship();
    my @children_samples = $self->get_children_relationship();
    my @brothers_samples = $self->get_brothers_relationship();
    
    my %relationship = (
	                 parents  => \@parents_samples,
	                 children => \@children_samples,
	                 brothers => \@brothers_samples,
	               );

    return %relationship;                  
}


#####################################
### METADBDATA ASSOCIATED METHODS ###
#####################################

=head2 accessors get_sample_metadbdata

  Usage: my $metadbdata = $sample->get_sample_metadbdata();

  Desc: Get metadata object associated to sample data (see CXGN::Metadata::Metadbdata). 

  Ret:  A metadbdata object (CXGN::Metadata::Metadbdata)

  Args: Optional, a metadbdata object to transfer metadata creation variables

  Side_Effects: none

  Example: my $metadbdata = $sample->get_sample_metadbdata();
           my $metadbdata = $sample->get_sample_metadbdata($metadbdata);

=cut

sub get_sample_metadbdata {
  my $self = shift;
  my $metadata_obj_base = shift;
  
  my $metadbdata; 
  my $metadata_id = $self->get_bssample_row
                         ->get_column('metadata_id');

  if (defined $metadata_id) {
      $metadbdata = CXGN::Metadata::Metadbdata->new($self->get_schema(), undef, $metadata_id);
      if (defined $metadata_obj_base) {

	  ## This will transfer the creation data from the base object to the new one
	  $metadbdata->set_object_creation_date($metadata_obj_base->get_object_creation_date());
	  $metadbdata->set_object_creation_user($metadata_obj_base->get_object_creation_user());
      }	  
  } 
  else {
      my $sample_id = $self->get_sample_id();
      croak("DATABASE INTEGRITY ERROR: The metadata_id for the sample_id=$sample_id is undefined.\n");
  }
  
  return $metadbdata;
}

=head2 is_sample_obsolete

  Usage: $sample->is_sample_obsolete();
  
  Desc: Get obsolete field form metadata object associated to 
        sample data (see CXGN::Metadata::Metadbdata). 
  
  Ret:  0 -> false (it is not obsolete) or 1 -> true (it is obsolete)
  
  Args: none
  
  Side_Effects: none
  
  Example: unless ($sample->is_sample_obsolete()) { ## do something }

=cut

sub is_sample_obsolete {
  my $self = shift;

  my $metadbdata = $self->get_sample_metadbdata();
  my $obsolete = $metadbdata->get_obsolete();
  
  if (defined $obsolete) {
      return $obsolete;
  } 
  else {
      return 0;
  }
}


=head2 accessors get_sample_pub_metadbdata

  Usage: my %metadbdata = $sample->get_sample_pub_metadbdata();

  Desc: Get metadata object associated to pub data 
        (see CXGN::Metadata::Metadbdata). 

  Ret:  A hash with keys=pub_id and values=metadbdata object 
        (CXGN::Metadata::Metadbdata) for pub relation

  Args: Optional, a metadbdata object to transfer metadata creation variables

  Side_Effects: none

  Example: my %metadbdata = $sample->get_sample_pub_metadbdata();
           my %metadbdata = $sample->get_sample_pub_metadbdata($metadbdata);

=cut

sub get_sample_pub_metadbdata {
  my $self = shift;
  my $metadata_obj_base = shift;
  
  my %metadbdata; 
  my @bssamplepub_rows = $self->get_bssamplepub_rows();

  foreach my $bssamplepub_row (@bssamplepub_rows) {
      my $pub_id = $bssamplepub_row->get_column('pub_id');
      my $metadata_id = $bssamplepub_row->get_column('metadata_id');

      if (defined $metadata_id) {
          my $metadbdata = CXGN::Metadata::Metadbdata->new($self->get_schema(), undef, $metadata_id);
          if (defined $metadata_obj_base) {

              ## This will transfer the creation data from the base object to the new one
              $metadbdata->set_object_creation_date($metadata_obj_base->get_object_creation_date());
              $metadbdata->set_object_creation_user($metadata_obj_base->get_object_creation_user());
          }     
          $metadbdata{$pub_id} = $metadbdata;
      } 
      else {
          my $sample_pub_id = $bssamplepub_row->get_column('sample_pub_id');
	  unless (defined $sample_pub_id) {
	      croak("OBJECT MANIPULATION ERROR: Object $self haven't any sample_pub_id associated. Probably it hasn't been stored\n");
	  }
	  else {
	      croak("DATABASE INTEGRITY ERROR: The metadata_id for the sample_pub_id=$sample_pub_id is undefined.\n");
	  }
      }
  }
  return %metadbdata;
}

=head2 is_sample_pub_obsolete

  Usage: $sample->is_sample_pub_obsolete($pub_id);
  
  Desc: Get obsolete field form metadata object associated to 
        pub data (see CXGN::Metadata::Metadbdata). 
  
  Ret:  0 -> false (it is not obsolete) or 1 -> true (it is obsolete)
  
  Args: $pub_id, a publication_id
  
  Side_Effects: none
  
  Example: unless ( $sample->is_sample_pub_obsolete($pub_id) ) { ## do something }

=cut

sub is_sample_pub_obsolete {
  my $self = shift;
  my $pub_id = shift;

  my %metadbdata = $self->get_sample_pub_metadbdata();
  my $metadbdata = $metadbdata{$pub_id};
  
  my $obsolete = 0;
  if (defined $metadbdata) {
      $obsolete = $metadbdata->get_obsolete() || 0;
  }
  return $obsolete;
}


=head2 accessors get_sample_dbxref_metadbdata

  Usage: my %metadbdata = $sample->get_sample_dbxref_metadbdata();

  Desc: Get metadata object associated to dbxref data 
        (see CXGN::Metadata::Metadbdata). 

  Ret:  A hash with keys=dbxref_id and values=metadbdata object 
        (CXGN::Metadata::Metadbdata) for pub relation

  Args: Optional, a metadbdata object to transfer metadata creation variables

  Side_Effects: none

  Example: my %metadbdata = $sample->get_sample_dbxref_metadbdata();
           my %metadbdata = $sample->get_sample_dbxref_metadbdata($metadbdata);

=cut

sub get_sample_dbxref_metadbdata {
  my $self = shift;
  my $metadata_obj_base = shift;
  
  my %metadbdata; 
  my @bssampledbxref_rows = $self->get_bssampledbxref_rows();

  foreach my $bssampledbxref_row (@bssampledbxref_rows) {
      my $dbxref_id = $bssampledbxref_row->get_column('dbxref_id');
      my $metadata_id = $bssampledbxref_row->get_column('metadata_id');

      if (defined $metadata_id) {
          my $metadbdata = CXGN::Metadata::Metadbdata->new($self->get_schema(), undef, $metadata_id);
          if (defined $metadata_obj_base) {

              ## This will transfer the creation data from the base object to the new one
              $metadbdata->set_object_creation_date($metadata_obj_base->get_object_creation_date());
              $metadbdata->set_object_creation_user($metadata_obj_base->get_object_creation_user());
          }     
          $metadbdata{$dbxref_id} = $metadbdata;
      } 
      else {
          my $sample_dbxref_id = $bssampledbxref_row->get_column('sample_dbxref_id');
	  unless (defined $sample_dbxref_id) {
	      croak("OBJECT MANIPULATION ERROR: Object $self haven't any sample_dbxref_id associated. Probably it hasn't been stored\n");
	  }
	  else {
	      croak("DATABASE INTEGRITY ERROR: The metadata_id for the sample_dbxref_id=$sample_dbxref_id is undefined.\n");
	  }
      }
  }
  return %metadbdata;
}

=head2 is_sample_dbxref_obsolete

  Usage: $sample->is_sample_dbxref_obsolete($dbxref_id);
  
  Desc: Get obsolete field form metadata object associated to 
        dbxref data (see CXGN::Metadata::Metadbdata). 
  
  Ret:  0 -> false (it is not obsolete) or 1 -> true (it is obsolete)
  
  Args: $dbxref_id, a dbxref_id
  
  Side_Effects: none
  
  Example: unless ( $sample->is_sample_dbxref_obsolete($dbxref_id) ) { ## do something }

=cut

sub is_sample_dbxref_obsolete {
  my $self = shift;
  my $dbxref_id = shift;

  my %metadbdata = $self->get_sample_dbxref_metadbdata();
  my $metadbdata = $metadbdata{$dbxref_id};
  
  my $obsolete = 0;
  if (defined $metadbdata) {
      $obsolete = $metadbdata->get_obsolete() || 0;
  }
  return $obsolete;
}


=head2 accessors get_sample_cvterm_metadbdata

  Usage: my %metadbdata = $sample->get_sample_cvterm_metadbdata();

  Desc: Get metadata object associated to cvterm data 
        (see CXGN::Metadata::Metadbdata). 

  Ret:  A hash with keys=cvterm_id and values=metadbdata object 
        (CXGN::Metadata::Metadbdata) for pub relation

  Args: Optional, a metadbdata object to transfer metadata creation variables

  Side_Effects: none

  Example: my %metadbdata = $sample->get_sample_cvterm_metadbdata();
           my %metadbdata = $sample->get_sample_cvterm_metadbdata($metadbdata);

=cut

sub get_sample_cvterm_metadbdata {
  my $self = shift;
  my $metadata_obj_base = shift;
  
  my %metadbdata; 
  my @bssamplecvterm_rows = $self->get_bssamplecvterm_rows();

  foreach my $bssamplecvterm_row (@bssamplecvterm_rows) {
      my $cvterm_id = $bssamplecvterm_row->get_column('cvterm_id');
      my $metadata_id = $bssamplecvterm_row->get_column('metadata_id');

      if (defined $metadata_id) {
          my $metadbdata = CXGN::Metadata::Metadbdata->new($self->get_schema(), undef, $metadata_id);
          if (defined $metadata_obj_base) {

              ## This will transfer the creation data from the base object to the new one
              $metadbdata->set_object_creation_date($metadata_obj_base->get_object_creation_date());
              $metadbdata->set_object_creation_user($metadata_obj_base->get_object_creation_user());
          }     
          $metadbdata{$cvterm_id} = $metadbdata;
      } 
      else {
          my $sample_cvterm_id = $bssamplecvterm_row->get_column('sample_cvterm_id');
	  unless (defined $sample_cvterm_id) {
	      croak("OBJECT MANIPULATION ERROR: Object $self haven't any sample_cvterm_id associated. Probably it hasn't been stored\n");
	  }
	  else {
	      croak("DATABASE INTEGRITY ERROR: The metadata_id for the sample_cvterm_id=$sample_cvterm_id is undefined.\n");
	  }
      }
  }
  return %metadbdata;
}

=head2 is_sample_cvterm_obsolete

  Usage: $sample->is_sample_cvterm_obsolete($cvterm_id);
  
  Desc: Get obsolete field form metadata object associated to 
        cvterm data (see CXGN::Metadata::Metadbdata). 
  
  Ret:  0 -> false (it is not obsolete) or 1 -> true (it is obsolete)
  
  Args: $cvterm_id, a cvterm_id
  
  Side_Effects: none
  
  Example: unless ( $sample->is_sample_cvterm_obsolete($cvterm_id) ) { ## do something }

=cut

sub is_sample_cvterm_obsolete {
  my $self = shift;
  my $cvterm_id = shift;

  my %metadbdata = $self->get_sample_cvterm_metadbdata();
  my $metadbdata = $metadbdata{$cvterm_id};
  
  my $obsolete = 0;
  if (defined $metadbdata) {
      $obsolete = $metadbdata->get_obsolete() || 0;
  }
  return $obsolete;
}


=head2 accessors get_sample_file_metadbdata

  Usage: my %metadbdata = $sample->get_sample_file_metadbdata();

  Desc: Get metadata object associated to file data 
        (see CXGN::Metadata::Metadbdata). 

  Ret:  A hash with keys=file_id and values=metadbdata object 
        (CXGN::Metadata::Metadbdata) for file relation

  Args: Optional, a metadbdata object to transfer metadata creation variables

  Side_Effects: none

  Example: my %metadbdata = $sample->get_sample_file_metadbdata();
           my %metadbdata = $sample->get_sample_file_metadbdata($metadbdata);

=cut

sub get_sample_file_metadbdata {
  my $self = shift;
  my $metadata_obj_base = shift;
  
  my %metadbdata; 
  my @bssamplefile_rows = $self->get_bssamplefile_rows();

  foreach my $bssamplefile_row (@bssamplefile_rows) {
      my $file_id = $bssamplefile_row->get_column('file_id');
      my $metadata_id = $bssamplefile_row->get_column('metadata_id');

      if (defined $metadata_id) {
          my $metadbdata = CXGN::Metadata::Metadbdata->new($self->get_schema(), undef, $metadata_id);
          if (defined $metadata_obj_base) {

              ## This will transfer the creation data from the base object to the new one
              $metadbdata->set_object_creation_date($metadata_obj_base->get_object_creation_date());
              $metadbdata->set_object_creation_user($metadata_obj_base->get_object_creation_user());
          }     
          $metadbdata{$file_id} = $metadbdata;
      } 
      else {
          my $sample_file_id = $bssamplefile_row->get_column('sample_file_id');
	  unless (defined $sample_file_id) {
	      croak("OBJECT MANIPULATION ERROR: Object $self haven't any sample_file_id associated. Probably it hasn't been stored\n");
	  }
	  else {
	      croak("DATABASE INTEGRITY ERROR: The metadata_id for the sample_file_id=$sample_file_id is undefined.\n");
	  }
      }
  }
  return %metadbdata;
}

=head2 is_sample_file_obsolete

  Usage: $sample->is_sample_file_obsolete($file_id);
  
  Desc: Get obsolete field form metadata object associated to 
        file data (see CXGN::Metadata::Metadbdata). 
  
  Ret:  0 -> false (it is not obsolete) or 1 -> true (it is obsolete)
  
  Args: $file_id, a file_id
  
  Side_Effects: none
  
  Example: unless ( $sample->is_sample_file_obsolete($file_id) ) { ## do something }

=cut

sub is_sample_file_obsolete {
  my $self = shift;
  my $file_id = shift;

  my %metadbdata = $self->get_sample_file_metadbdata();
  my $metadbdata = $metadbdata{$file_id};
  
  my $obsolete = 0;
  if (defined $metadbdata) {
      $obsolete = $metadbdata->get_obsolete() || 0;
  }
  return $obsolete;
}

=head2 accessors get_sample_children_metadbdata

  Usage: my %metadbdata = $sample->get_sample_children_metadbdata();

  Desc: Get metadata object associated to children relationship data 
        (see CXGN::Metadata::Metadbdata). 

  Ret:  A hash with keys=file_id and values=metadbdata object 
        (CXGN::Metadata::Metadbdata) for file relation

  Args: Optional, a metadbdata object to transfer metadata creation variables

  Side_Effects: none

  Example: my %metadbdata = $sample->get_sample_children_metadbdata();
           my %metadbdata = $sample->get_sample_children_metadbdata($metadbdata);

=cut

sub get_sample_children_metadbdata {
  my $self = shift;
  my $metadata_obj_base = shift;
  
  my %metadbdata; 
  my @bssamplechildren_rows = $self->get_bssamplechildrenrelationship_rows();

  foreach my $bssamplechildren_row (@bssamplechildren_rows) {
      my $children_id = $bssamplechildren_row->get_column('object_id');
      my $metadata_id = $bssamplechildren_row->get_column('metadata_id');

      if (defined $metadata_id) {
          my $metadbdata = CXGN::Metadata::Metadbdata->new($self->get_schema(), undef, $metadata_id);
          if (defined $metadata_obj_base) {

              ## This will transfer the creation data from the base object to the new one
              $metadbdata->set_object_creation_date($metadata_obj_base->get_object_creation_date());
              $metadbdata->set_object_creation_user($metadata_obj_base->get_object_creation_user());
          }     
          $metadbdata{$children_id} = $metadbdata;
      } 
      else {
          my $sample_relationship_id = $bssamplechildren_row->get_column('sample_relationship_id');
	  unless (defined $sample_relationship_id) {
	      croak("OBJECT MANIPULATION ERROR: Object $self haven't any sample_relationship_id associated. Probably it hasn't been stored\n");
	  }
	  else {
	      croak("DATABASE INTEGRITY ERROR: The metadata_id for the sample_relationship_id=$sample_relationship_id is undefined.\n");
	  }
      }
  }
  return %metadbdata;
}

=head2 is_sample_children_obsolete

  Usage: $sample->is_sample_children_obsolete($sample_id);
  
  Desc: Get obsolete field form metadata object associated to 
        sample relationship data (see CXGN::Metadata::Metadbdata). 
  
  Ret:  0 -> false (it is not obsolete) or 1 -> true (it is obsolete)
  
  Args: $sample_id, a sample_id
  
  Side_Effects: none
  
  Example: unless ( $sample->is_sample_children_obsolete($children_id) ) { ## do something }

=cut

sub is_sample_children_obsolete {
  my $self = shift;
  my $children_id = shift;

  my %metadbdata = $self->get_sample_children_metadbdata();
  my $metadbdata = $metadbdata{$children_id};
  
  my $obsolete = 0;
  if (defined $metadbdata) {
      $obsolete = $metadbdata->get_obsolete() || 0;
  }
  return $obsolete;
}


=head2 accessors get_sample_parents_metadbdata

  Usage: my %metadbdata = $sample->get_sample_parents_metadbdata();

  Desc: Get metadata object associated to parent relationship data 
        (see CXGN::Metadata::Metadbdata). 

  Ret:  A hash with keys=file_id and values=metadbdata object 
        (CXGN::Metadata::Metadbdata) for sample relation

  Args: Optional, a metadbdata object to transfer metadata creation variables

  Side_Effects: none

  Example: my %metadbdata = $sample->get_sample_parents_metadbdata();
           my %metadbdata = $sample->get_sample_parents_metadbdata($metadbdata);

=cut

sub get_sample_parents_metadbdata {
  my $self = shift;
  my $metadata_obj_base = shift;
  
  my %metadbdata; 
  my @bssampleparent_rows = $self->get_bssampleparentsrelationship_rows();

  foreach my $bssampleparent_row (@bssampleparent_rows) {
      my $parent_id = $bssampleparent_row->get_column('subject_id');
      my $metadata_id = $bssampleparent_row->get_column('metadata_id');

      if (defined $metadata_id) {
          my $metadbdata = CXGN::Metadata::Metadbdata->new($self->get_schema(), undef, $metadata_id);
          if (defined $metadata_obj_base) {

              ## This will transfer the creation data from the base object to the new one
              $metadbdata->set_object_creation_date($metadata_obj_base->get_object_creation_date());
              $metadbdata->set_object_creation_user($metadata_obj_base->get_object_creation_user());
          }     
          $metadbdata{$parent_id} = $metadbdata;
      } 
      else {
          my $sample_relationship_id = $bssampleparent_row->get_column('sample_relationship_id');
	  unless (defined $sample_relationship_id) {
	      croak("OBJECT MANIPULATION ERROR: Object $self haven't any sample_relationship_id associated. Probably it hasn't been stored\n");
	  }
	  else {
	      croak("DATABASE INTEGRITY ERROR: The metadata_id for the sample_relationship_id=$sample_relationship_id is undefined.\n");
	  }
      }
  }
  return %metadbdata;
}

=head2 is_sample_parents_obsolete

  Usage: $sample->is_sample_parents_obsolete($sample_id);
  
  Desc: Get obsolete field form metadata object associated to 
        sample relationship data (see CXGN::Metadata::Metadbdata). 
  
  Ret:  0 -> false (it is not obsolete) or 1 -> true (it is obsolete)
  
  Args: $sample_id, a sample_id
  
  Side_Effects: none
  
  Example: unless ( $sample->is_sample_parents_obsolete($children_id) ) { ## do something }

=cut

sub is_sample_parents_obsolete {
  my $self = shift;
  my $parent_id = shift;

  my %metadbdata = $self->get_sample_parents_metadbdata();
  my $metadbdata = $metadbdata{$parent_id};
  
  my $obsolete = 0;
  if (defined $metadbdata) {
      $obsolete = $metadbdata->get_obsolete() || 0;
  }
  return $obsolete;
}


#######################
### STORING METHODS ###
#######################


=head2 store

  Usage: my $sample = $sample->store($metadbdata);
 
  Desc: Store in the database the all sample data for the sample object
       (sample, sample_pub, sample_dbxref, sample_cvterm, sample_file, 
       sample_childrenrelationship, sample_parentrelationship rows)
       See the methods store_sample, store_pub_associations, 
       store_dbxref_associations, store_cvterm_associations, 
       store_file_associations, store_children_associations and 
       store_parents_associations.

  Ret: $sample, the sample object
 
  Args: $metadata, a metadata object (CXGN::Metadata::Metadbdata object).
 
  Side_Effects: Die if:
                1- None metadata object is supplied.
                2- The metadata supplied is not a CXGN::Metadata::Metadbdata 
                   object
 
  Example: my $sample = $sample->store($metadata);

=cut

sub store {
    my $self = shift;

    ## FIRST, check the metadata_id supplied as parameter
    my $metadata = shift  
	|| croak("STORE ERROR: None metadbdata object was supplied to $self->store().\n");
    
    unless (ref($metadata) eq 'CXGN::Metadata::Metadbdata') {
	croak("STORE ERROR: Metadbdata supplied to $self->store() is not CXGN::Metadata::Metadbdata object.\n");
    }

    ## SECOND, the store functions return the updated object, so it will chain the different store functions

    $self->store_sample($metadata)
	 ->store_pub_associations($metadata)
	 ->store_dbxref_associations($metadata)
         ->store_cvterm_associations($metadata)
	 ->store_file_associations($metadata)
	 ->store_children_associations($metadata)
	 ->store_parents_associations($metadata);

    return $self;
}



=head2 store_sample

  Usage: my $sample = $sample->store_sample($metadata);
 
  Desc: Store in the database the sample data for the sample object
       (Only the bssample row, don't store any sample_element or 
        sample_pub data)
 
  Ret: $sample, the sample object with the data updated
 
  Args: $metadata, a metadata object (CXGN::Metadata::Metadbdata object).
 
  Side_Effects: Die if:
                1- None metadata object is supplied.
                2- The metadata supplied is not a CXGN::Metadata::Metadbdata 
                   object
 
  Example: my $sample = $sample->store_sample($metadata);

=cut

sub store_sample {
    my $self = shift;

    ## FIRST, check the metadata_id supplied as parameter
    my $metadata = shift  
	|| croak("STORE ERROR: None metadbdata object was supplied to $self->store_sample().\n");
    
    unless (ref($metadata) eq 'CXGN::Metadata::Metadbdata') {
	croak("STORE ERROR: Metadbdata supplied to $self->store_sample() is not CXGN::Metadata::Metadbdata object.\n");
    }

    ## It is not necessary check the current user used to store the data because should be the same than the used 
    ## to create a metadata_id. In the medadbdata object, it is checked.

    ## SECOND, check if exists or not sample_id. 
    ##   if exists sample_id         => update
    ##   if do not exists sample_id  => insert

    my $bssample_row = $self->get_bssample_row();
    my $sample_id = $bssample_row->get_column('sample_id');

    unless (defined $sample_id) {                                   ## NEW INSERT and DISCARD CHANGES
	
	my $metadata_id = $metadata->store()
	                           ->get_metadata_id();

	$bssample_row->set_column( metadata_id => $metadata_id );   ## Set the metadata_id column
        
	$bssample_row->insert()
                     ->discard_changes();                           ## It will set the row with the updated row
	
	## Now we set the sample_id value for all the rows that depends of it as sample_pub rows

	my @bssamplepub_rows = $self->get_bssamplepub_rows();
	foreach my $bssamplepub_row (@bssamplepub_rows) {
	    $bssamplepub_row->set_column( sample_id => $bssample_row->get_column('sample_id'));
	}

	my @bssampledbxref_rows = $self->get_bssampledbxref_rows();
	foreach my $bssampledbxref_row (@bssampledbxref_rows) {
	    $bssampledbxref_row->set_column( sample_id => $bssample_row->get_column('sample_id'));
	}

	my @bssamplecvterm_rows = $self->get_bssamplecvterm_rows();
	foreach my $bssamplecvterm_row (@bssamplecvterm_rows) {
	    $bssamplecvterm_row->set_column( sample_id => $bssample_row->get_column('sample_id'));
	}

	my @bssamplefile_rows = $self->get_bssamplefile_rows();
	foreach my $bssamplefile_row (@bssamplefile_rows) {
	    $bssamplefile_row->set_column( sample_id => $bssample_row->get_column('sample_id'));
	}

	my @bssamplechildren_rows = $self->get_bssamplechildrenrelationship_rows();
	foreach my $bssamplechildren_row (@bssamplechildren_rows) {
	    $bssamplechildren_row->set_column( subject_id => $bssample_row->get_column('sample_id'));
	}

	my @bssampleparents_rows = $self->get_bssampleparentsrelationship_rows();
	foreach my $bssampleparents_row (@bssampleparents_rows) {
	    $bssampleparents_row->set_column( object_id => $bssample_row->get_column('sample_id'));
	}
                    
    } 
    else {                                                            ## UPDATE IF SOMETHING has change
	
        my @columns_changed = $bssample_row->is_changed();
	
        if (scalar(@columns_changed) > 0) {                         ## ...something has change, it will take
	   
            my @modification_note_list;                             ## the changes and the old metadata object for
	    foreach my $col_changed (@columns_changed) {            ## this dbiref and it will create a new row
		push @modification_note_list, "set value in $col_changed column";
	    }
	   
            my $modification_note = join ', ', @modification_note_list;
	   
	    my $mod_metadata_id = $self->get_sample_metadbdata($metadata)
	                               ->store({ modification_note => $modification_note })
				       ->get_metadata_id(); 

	    $bssample_row->set_column( metadata_id => $mod_metadata_id );

	    $bssample_row->update()
                         ->discard_changes();
	}
    }
    return $self;    
}


=head2 obsolete_sample

  Usage: my $sample = $sample->obsolete_sample($metadata, $note, 'REVERT');
 
  Desc: Change the status of a data to obsolete.
        If revert tag is used the obsolete status will be reverted to 0 (false)
 
  Ret: $sample, the sample object updated with the db data.
  
  Args: $metadata, a metadata object (CXGN::Metadata::Metadbdata object).
        $note, a note to explain the cause of make this data obsolete
        optional, 'REVERT'.
  
  Side_Effects: Die if:
                1- None metadata object is supplied.
                2- The metadata supplied is not a CXGN::Metadata::Metadbdata 
  
  Example: my $sample = $sample->obsolete_sample($metadata, 'change to obsolete test');

=cut

sub obsolete_sample {
    my $self = shift;

    ## FIRST, check the metadata_id supplied as parameter
   
    my $metadata = shift  
	|| croak("OBSOLETE ERROR: None metadbdata object was supplied to $self->obsolete_sample().\n");
    
    unless (ref($metadata) eq 'CXGN::Metadata::Metadbdata') {
	croak("OBSOLETE ERROR: Metadbdata object supplied to $self->obsolete_sample is not CXGN::Metadata::Metadbdata obj.\n");
    }

    my $obsolete_note = shift 
	|| croak("OBSOLETE ERROR: None obsolete note was supplied to $self->obsolete_sample().\n");

    my $revert_tag = shift;


    ## If exists the tag revert change obsolete to 0

    my $obsolete = 1;
    my $modification_note = 'change to obsolete';
    if (defined $revert_tag && $revert_tag =~ m/REVERT/i) {
	$obsolete = 0;
	$modification_note = 'revert obsolete';
    }

    ## Create a new metadata with the obsolete tag

    my $mod_metadata_id = $self->get_sample_metadbdata($metadata) 
                               ->store( { modification_note => $modification_note,
		                          obsolete          => $obsolete, 
		                          obsolete_note     => $obsolete_note } )
                               ->get_metadata_id();
     
    ## Modify the group row in the database
 
    my $bssample_row = $self->get_bssample_row();

    $bssample_row->set_column( metadata_id => $mod_metadata_id );
         
    $bssample_row->update()
	           ->discard_changes();

    return $self;
}


=head2 store_pub_associations

  Usage: my $sample = $sample->store_pub_associations($metadata);
 
  Desc: Store in the database the pub association for the sample object
 
  Ret: $sample, the sample object with the data updated
 
  Args: $metadata, a metadata object (CXGN::Metadata::Metadbdata object).
 
  Side_Effects: Die if:
                1- None metadata object is supplied.
                2- The metadata supplied is not a CXGN::Metadata::Metadbdata 
                   object
 
  Example: my $sample = $sample->store_pub_associations($metadata);

=cut

sub store_pub_associations {
    my $self = shift;

    ## FIRST, check the metadata_id supplied as parameter
    my $metadata = shift  
        || croak("STORE ERROR: None metadbdata object was supplied to $self->store_pub_associations().\n");
    
    unless (ref($metadata) eq 'CXGN::Metadata::Metadbdata') {
        croak("STORE ERROR: Metadbdata supplied to $self->store_pub_associations() is not CXGN::Metadata::Metadbdata object.\n");
    }

    ## It is not necessary check the current user used to store the data because should be the same than the used 
    ## to create a metadata_id. In the medadbdata object, it is checked.

    ## SECOND, check if exists or not sample_pub_id. 
    ##   if exists sample_pub_id         => update
    ##   if do not exists sample_pub_id  => insert

    my @bssamplepub_rows = $self->get_bssamplepub_rows();
    
    foreach my $bssamplepub_row (@bssamplepub_rows) {
        
        my $sample_pub_id = $bssamplepub_row->get_column('sample_pub_id');
	my $pub_id = $bssamplepub_row->get_column('pub_id');

        unless (defined $sample_pub_id) {                                   ## NEW INSERT and DISCARD CHANGES
        
            my $metadata_id = $metadata->store()
                                       ->get_metadata_id();

            $bssamplepub_row->set_column( metadata_id => $metadata_id );    ## Set the metadata_id column
        
            $bssamplepub_row->insert()
                            ->discard_changes();                            ## It will set the row with the updated row
                            
        } 
        else {                                                                ## UPDATE IF SOMETHING has change
        
            my @columns_changed = $bssamplepub_row->is_changed();
        
            if (scalar(@columns_changed) > 0) {                         ## ...something has change, it will take
           
                my @modification_note_list;                             ## the changes and the old metadata object for
                foreach my $col_changed (@columns_changed) {            ## this dbiref and it will create a new row
                    push @modification_note_list, "set value in $col_changed column";
                }
                
                my $modification_note = join ', ', @modification_note_list;
           
		my %aspub_metadata = $self->get_sample_pub_metadbdata($metadata);
		my $mod_metadata_id = $aspub_metadata{$pub_id}->store({ modification_note => $modification_note })
                                                              ->get_metadata_id(); 

                $bssamplepub_row->set_column( metadata_id => $mod_metadata_id );

                $bssamplepub_row->update()
                                  ->discard_changes();
            }
        }
    }
    return $self;    
}

=head2 obsolete_pub_association

  Usage: my $sample = $sample->obsolete_pub_association($metadata, $note, $pub_id, 'REVERT');
 
  Desc: Change the status of a data to obsolete.
        If revert tag is used the obsolete status will be reverted to 0 (false)
 
  Ret: $sample, the sample object updated with the db data.
  
  Args: $metadata, a metadata object (CXGN::Metadata::Metadbdata object).
        $note, a note to explain the cause of make this data obsolete
        $pub_id, a publication id associated to this sample
        optional, 'REVERT'.
  
  Side_Effects: Die if:
                1- None metadata object is supplied.
                2- The metadata supplied is not a CXGN::Metadata::Metadbdata 
  
  Example: my $sample = $sample->obsolete_pub_association($metadata, 
                                                          'change to obsolete test', 
                                                          $pub_id );

=cut

sub obsolete_pub_association {
    my $self = shift;

    ## FIRST, check the metadata_id supplied as parameter
   
    my $metadata = shift  
	|| croak("OBSOLETE ERROR: None metadbdata object was supplied to $self->obsolete_pub_association().\n");
    
    unless (ref($metadata) eq 'CXGN::Metadata::Metadbdata') {
	croak("OBSOLETE ERROR: Metadbdata object supplied to $self->obsolete_pub_association is not CXGN::Metadata::Metadbdata obj.\n");
    }

    my $obsolete_note = shift 
	|| croak("OBSOLETE ERROR: None obsolete note was supplied to $self->obsolete_pub_association().\n");

    my $pub_id = shift 
	|| croak("OBSOLETE ERROR: None pub_id was supplied to $self->obsolete_pub_association().\n");

    my $revert_tag = shift;


    ## If exists the tag revert change obsolete to 0

    my $obsolete = 1;
    my $modification_note = 'change to obsolete';
    if (defined $revert_tag && $revert_tag =~ m/REVERT/i) {
	$obsolete = 0;
	$modification_note = 'revert obsolete';
    }

    ## Create a new metadata with the obsolete tag
    
    my %aspub_metadata = $self->get_sample_pub_metadbdata($metadata);
    my $mod_metadata_id = $aspub_metadata{$pub_id}->store( { modification_note => $modification_note,
							     obsolete          => $obsolete, 
							     obsolete_note     => $obsolete_note } )
                                                  ->get_metadata_id();
     
    ## Modify the group row in the database
 
    my @bssamplepub_rows = $self->get_bssamplepub_rows();
    foreach my $bssamplepub_row (@bssamplepub_rows) {
	if ($bssamplepub_row->get_column('pub_id') == $pub_id) {

	    $bssamplepub_row->set_column( metadata_id => $mod_metadata_id );
         
	    $bssamplepub_row->update()
	                    ->discard_changes();
	}
    }
    return $self;
}

=head2 store_dbxref_associations

  Usage: my $sample = $sample->store_dbxref_associations($metadata);
 
  Desc: Store in the database the dbxref association for the sample object
 
  Ret: $sample, the sample object with the data updated
 
  Args: $metadata, a metadata object (CXGN::Metadata::Metadbdata object).
 
  Side_Effects: Die if:
                1- None metadata object is supplied.
                2- The metadata supplied is not a CXGN::Metadata::Metadbdata 
                   object
 
  Example: my $sample = $sample->store_dbxref_associations($metadata);

=cut

sub store_dbxref_associations {
    my $self = shift;

    ## FIRST, check the metadata_id supplied as parameter
    my $metadata = shift  
        || croak("STORE ERROR: None metadbdata object was supplied to $self->store_dbxref_associations().\n");
    
    unless (ref($metadata) eq 'CXGN::Metadata::Metadbdata') {
        croak("STORE ERROR: Metadbdata supplied to $self->store_dbxref_associations() is not CXGN::Metadata::Metadbdata object.\n");
    }

    ## It is not necessary check the current user used to store the data because should be the same than the used 
    ## to create a metadata_id. In the medadbdata object, it is checked.

    ## SECOND, check if exists or not sample_dbxref_id. 
    ##   if exists sample_dbxref_id         => update
    ##   if do not exists sample_dbxref_id  => insert

    my @bssampledbxref_rows = $self->get_bssampledbxref_rows();
    
    foreach my $bssampledbxref_row (@bssampledbxref_rows) {
        
        my $sample_dbxref_id = $bssampledbxref_row->get_column('sample_dbxref_id');

	## The dbxref_id is a foreign kwy into the database, so if it doesn't exists
	## the DBIx::Class object will return a db error

	my $dbxref_id = $bssampledbxref_row->get_column('dbxref_id');

        unless (defined $sample_dbxref_id) {                                   ## NEW INSERT and DISCARD CHANGES
        
            my $metadata_id = $metadata->store()
                                       ->get_metadata_id();

            $bssampledbxref_row->set_column( metadata_id => $metadata_id );    ## Set the metadata_id column
        
            $bssampledbxref_row->insert()
                               ->discard_changes();                            ## It will set the row with the updated row
                            
        } 
        else {                                                                ## UPDATE IF SOMETHING has change
        
            my @columns_changed = $bssampledbxref_row->is_changed();
        
            if (scalar(@columns_changed) > 0) {                         ## ...something has change, it will take
           
                my @modification_note_list;                             ## the changes and the old metadata object for
                foreach my $col_changed (@columns_changed) {            ## this dbiref and it will create a new row
                    push @modification_note_list, "set value in $col_changed column";
                }
                
                my $modification_note = join ', ', @modification_note_list;
           
		my %asdbxref_metadata = $self->get_sample_dbxref_metadbdata($metadata);
		my $mod_metadata_id = $asdbxref_metadata{$dbxref_id}->store({ modification_note => $modification_note })
                                                                    ->get_metadata_id(); 

                $bssampledbxref_row->set_column( metadata_id => $mod_metadata_id );

                $bssampledbxref_row->update()
                                   ->discard_changes();
            }
        }
    }
    return $self;    
}

=head2 obsolete_dbxref_association

  Usage: my $sample = $sample->obsolete_dbxref_association($metadata, $note, $dbxref_id, 'REVERT');
 
  Desc: Change the status of a data to obsolete.
        If revert tag is used the obsolete status will be reverted to 0 (false)
 
  Ret: $sample, the sample object updated with the db data.
  
  Args: $metadata, a metadata object (CXGN::Metadata::Metadbdata object).
        $note, a note to explain the cause of make this data obsolete
        $dbxref_id, a dbxref id associated to this sample
        optional, 'REVERT'.
  
  Side_Effects: Die if:
                1- None metadata object is supplied.
                2- The metadata supplied is not a CXGN::Metadata::Metadbdata 
  
  Example: my $sample = $sample->obsolete_dbxref_association($metadata, 
                                                          'change to obsolete test', 
                                                          $dbxref_id );

=cut

sub obsolete_dbxref_association {
    my $self = shift;

    ## FIRST, check the metadata_id supplied as parameter
   
    my $metadata = shift  
	|| croak("OBSOLETE ERROR: None metadbdata object was supplied to $self->obsolete_dbxref_association().\n");
    
    unless (ref($metadata) eq 'CXGN::Metadata::Metadbdata') {
	croak("OBSOLETE ERROR: Metadbdata object supplied to $self->obsolete_dbxref_association is not CXGN::Metadata::Metadbdata obj.\n");
    }

    my $obsolete_note = shift 
	|| croak("OBSOLETE ERROR: None obsolete note was supplied to $self->obsolete_dbxref_association().\n");

    my $dbxref_id = shift 
	|| croak("OBSOLETE ERROR: None dbxref_id was supplied to $self->obsolete_dbxref_association().\n");

    my $revert_tag = shift;


    ## If exists the tag revert change obsolete to 0

    my $obsolete = 1;
    my $modification_note = 'change to obsolete';
    if (defined $revert_tag && $revert_tag =~ m/REVERT/i) {
	$obsolete = 0;
	$modification_note = 'revert obsolete';
    }

    ## Create a new metadata with the obsolete tag
    
    my %asdbxref_metadata = $self->get_sample_dbxref_metadbdata($metadata);
    my $mod_metadata_id = $asdbxref_metadata{$dbxref_id}->store( { modification_note => $modification_note,
							           obsolete          => $obsolete, 
							           obsolete_note     => $obsolete_note } )
                                                        ->get_metadata_id();
     
    ## Modify the group row in the database
 
    my @bssampledbxref_rows = $self->get_bssampledbxref_rows();
    foreach my $bssampledbxref_row (@bssampledbxref_rows) {
	if ($bssampledbxref_row->get_column('dbxref_id') == $dbxref_id) {

	    $bssampledbxref_row->set_column( metadata_id => $mod_metadata_id );
         
	    $bssampledbxref_row->update()
	                       ->discard_changes();
	}
    }
    return $self;
}

=head2 store_cvterm_associations

  Usage: my $sample = $sample->store_cvterm_associations($metadata);
 
  Desc: Store in the database the cvterm association for the sample object
 
  Ret: $sample, the sample object with the data updated
 
  Args: $metadata, a metadata object (CXGN::Metadata::Metadbdata object).
 
  Side_Effects: Die if:
                1- None metadata object is supplied.
                2- The metadata supplied is not a CXGN::Metadata::Metadbdata 
                   object
 
  Example: my $sample = $sample->store_cvterm_associations($metadata);

=cut

sub store_cvterm_associations {
    my $self = shift;

    ## FIRST, check the metadata_id supplied as parameter
    my $metadata = shift  
        || croak("STORE ERROR: None metadbdata object was supplied to $self->store_cvterm_associations().\n");
    
    unless (ref($metadata) eq 'CXGN::Metadata::Metadbdata') {
        croak("STORE ERROR: Metadbdata supplied to $self->store_cvterm_associations() is not CXGN::Metadata::Metadbdata object.\n");
    }

    ## It is not necessary check the current user used to store the data because should be the same than the used 
    ## to create a metadata_id. In the medadbdata object, it is checked.

    ## SECOND, check if exists or not sample_cvterm_id. 
    ##   if exists sample_cvterm_id         => update
    ##   if do not exists sample_cvterm_id  => insert

    my @bssamplecvterm_rows = $self->get_bssamplecvterm_rows();
    
    foreach my $bssamplecvterm_row (@bssamplecvterm_rows) {
        
        my $sample_cvterm_id = $bssamplecvterm_row->get_column('sample_cvterm_id');

	## The cvterm_id is a foreign kwy into the database, so if it doesn't exists
	## the DBIx::Class object will return a db error

	my $cvterm_id = $bssamplecvterm_row->get_column('cvterm_id');

        unless (defined $sample_cvterm_id) {                                   ## NEW INSERT and DISCARD CHANGES
        
            my $metadata_id = $metadata->store()
                                       ->get_metadata_id();

            $bssamplecvterm_row->set_column( metadata_id => $metadata_id );    ## Set the metadata_id column
        
            $bssamplecvterm_row->insert()
                               ->discard_changes();                            ## It will set the row with the updated row
                            
        } 
        else {                                                                ## UPDATE IF SOMETHING has change
        
            my @columns_changed = $bssamplecvterm_row->is_changed();
        
            if (scalar(@columns_changed) > 0) {                         ## ...something has change, it will take
           
                my @modification_note_list;                             ## the changes and the old metadata object for
                foreach my $col_changed (@columns_changed) {            ## this dbiref and it will create a new row
                    push @modification_note_list, "set value in $col_changed column";
                }
                
                my $modification_note = join ', ', @modification_note_list;
           
		my %ascvterm_metadata = $self->get_sample_cvterm_metadbdata($metadata);
		my $mod_metadata_id = $ascvterm_metadata{$cvterm_id}->store({ modification_note => $modification_note })
                                                                    ->get_metadata_id(); 

                $bssamplecvterm_row->set_column( metadata_id => $mod_metadata_id );

                $bssamplecvterm_row->update()
                                   ->discard_changes();
            }
        }
    }
    return $self;    
}

=head2 obsolete_cvterm_association

  Usage: my $sample = $sample->obsolete_cvterm_association($metadata, $note, $cvterm_id, 'REVERT');
 
  Desc: Change the status of a data to obsolete.
        If revert tag is used the obsolete status will be reverted to 0 (false)
 
  Ret: $sample, the sample object updated with the db data.
  
  Args: $metadata, a metadata object (CXGN::Metadata::Metadbdata object).
        $note, a note to explain the cause of make this data obsolete
        $cvterm_id, a cvterm id associated to this sample
        optional, 'REVERT'.
  
  Side_Effects: Die if:
                1- None metadata object is supplied.
                2- The metadata supplied is not a CXGN::Metadata::Metadbdata 
  
  Example: my $sample = $sample->obsolete_cvterm_association($metadata, 
                                                          'change to obsolete test', 
                                                          $cvterm_id );

=cut

sub obsolete_cvterm_association {
    my $self = shift;

    ## FIRST, check the metadata_id supplied as parameter
   
    my $metadata = shift  
	|| croak("OBSOLETE ERROR: None metadbdata object was supplied to $self->obsolete_cvterm_association().\n");
    
    unless (ref($metadata) eq 'CXGN::Metadata::Metadbdata') {
	croak("OBSOLETE ERROR: Metadbdata object supplied to $self->obsolete_cvterm_association is not CXGN::Metadata::Metadbdata obj.\n");
    }

    my $obsolete_note = shift 
	|| croak("OBSOLETE ERROR: None obsolete note was supplied to $self->obsolete_cvterm_association().\n");

    my $cvterm_id = shift 
	|| croak("OBSOLETE ERROR: None cvterm_id was supplied to $self->obsolete_cvterm_association().\n");

    my $revert_tag = shift;


    ## If exists the tag revert change obsolete to 0

    my $obsolete = 1;
    my $modification_note = 'change to obsolete';
    if (defined $revert_tag && $revert_tag =~ m/REVERT/i) {
	$obsolete = 0;
	$modification_note = 'revert obsolete';
    }

    ## Create a new metadata with the obsolete tag
    
    my %ascvterm_metadata = $self->get_sample_cvterm_metadbdata($metadata);
    my $mod_metadata_id = $ascvterm_metadata{$cvterm_id}->store( { modification_note => $modification_note,
							           obsolete          => $obsolete, 
							           obsolete_note     => $obsolete_note } )
                                                        ->get_metadata_id();
     
    ## Modify the group row in the database
 
    my @bssamplecvterm_rows = $self->get_bssamplecvterm_rows();
    foreach my $bssamplecvterm_row (@bssamplecvterm_rows) {
	if ($bssamplecvterm_row->get_column('cvterm_id') == $cvterm_id) {

	    $bssamplecvterm_row->set_column( metadata_id => $mod_metadata_id );
         
	    $bssamplecvterm_row->update()
	                       ->discard_changes();
	}
    }
    return $self;
}

=head2 store_file_associations

  Usage: my $sample = $sample->store_file_associations($metadata);
 
  Desc: Store in the database the file association for the sample object
 
  Ret: $sample, the sample object with the data updated
 
  Args: $metadata, a metadata object (CXGN::Metadata::Metadbdata object).
 
  Side_Effects: Die if:
                1- None metadata object is supplied.
                2- The metadata supplied is not a CXGN::Metadata::Metadbdata 
                   object
 
  Example: my $sample = $sample->store_file_associations($metadata);

=cut

sub store_file_associations {
    my $self = shift;

    ## FIRST, check the metadata_id supplied as parameter
    my $metadata = shift  
        || croak("STORE ERROR: None metadbdata object was supplied to $self->store_file_associations().\n");
    
    unless (ref($metadata) eq 'CXGN::Metadata::Metadbdata') {
        croak("STORE ERROR: Metadbdata supplied to $self->store_file_associations() is not CXGN::Metadata::Metadbdata object.\n");
    }

    ## It is not necessary check the current user used to store the data because should be the same than the used 
    ## to create a metadata_id. In the medadbdata object, it is checked.

    ## SECOND, check if exists or not sample_file_id. 
    ##   if exists sample_file_id         => update
    ##   if do not exists sample_file_id  => insert

    my @bssamplefile_rows = $self->get_bssamplefile_rows();
    
    foreach my $bssamplefile_row (@bssamplefile_rows) {
        
        my $sample_file_id = $bssamplefile_row->get_column('sample_file_id');

	## The file_id is a foreign key into the database, so if it doesn't exists
	## the DBIx::Class object will return a db error

	my $file_id = $bssamplefile_row->get_column('file_id');

        unless (defined $sample_file_id) {                                   ## NEW INSERT and DISCARD CHANGES
        
            my $metadata_id = $metadata->store()
                                       ->get_metadata_id();

            $bssamplefile_row->set_column( metadata_id => $metadata_id );    ## Set the metadata_id column
        
            $bssamplefile_row->insert()
                             ->discard_changes();                            ## It will set the row with the updated row
                            
        } 
        else {                                                                ## UPDATE IF SOMETHING has change
        
            my @columns_changed = $bssamplefile_row->is_changed();
        
            if (scalar(@columns_changed) > 0) {                         ## ...something has change, it will take
           
                my @modification_note_list;                             ## the changes and the old metadata object for
                foreach my $col_changed (@columns_changed) {            ## this dbiref and it will create a new row
                    push @modification_note_list, "set value in $col_changed column";
                }
                
                my $modification_note = join ', ', @modification_note_list;
           
		my %asfile_metadata = $self->get_sample_file_metadbdata($metadata);
		my $mod_metadata_id = $asfile_metadata{$file_id}->store({ modification_note => $modification_note })
                                                                    ->get_metadata_id(); 

                $bssamplefile_row->set_column( metadata_id => $mod_metadata_id );

                $bssamplefile_row->update()
                                 ->discard_changes();
            }
        }
    }
    return $self;    
}

=head2 obsolete_file_association

  Usage: my $sample = $sample->obsolete_file_association($metadata, $note, $file_id, 'REVERT');
 
  Desc: Change the status of a data to obsolete.
        If revert tag is used the obsolete status will be reverted to 0 (false)
 
  Ret: $sample, the sample object updated with the db data.
  
  Args: $metadata, a metadata object (CXGN::Metadata::Metadbdata object).
        $note, a note to explain the cause of make this data obsolete
        $file_id, a file id associated to this sample
        optional, 'REVERT'.
  
  Side_Effects: Die if:
                1- None metadata object is supplied.
                2- The metadata supplied is not a CXGN::Metadata::Metadbdata 
  
  Example: my $sample = $sample->obsolete_file_association($metadata, 
                                                          'change to obsolete test', 
                                                          $file_id );

=cut

sub obsolete_file_association {
    my $self = shift;

    ## FIRST, check the metadata_id supplied as parameter
   
    my $metadata = shift  
	|| croak("OBSOLETE ERROR: None metadbdata object was supplied to $self->obsolete_file_association().\n");
    
    unless (ref($metadata) eq 'CXGN::Metadata::Metadbdata') {
	croak("OBSOLETE ERROR: Metadbdata object supplied to $self->obsolete_file_association is not CXGN::Metadata::Metadbdata obj.\n");
    }

    my $obsolete_note = shift 
	|| croak("OBSOLETE ERROR: None obsolete note was supplied to $self->obsolete_file_association().\n");

    my $file_id = shift 
	|| croak("OBSOLETE ERROR: None file_id was supplied to $self->obsolete_file_association().\n");

    my $revert_tag = shift;


    ## If exists the tag revert change obsolete to 0

    my $obsolete = 1;
    my $modification_note = 'change to obsolete';
    if (defined $revert_tag && $revert_tag =~ m/REVERT/i) {
	$obsolete = 0;
	$modification_note = 'revert obsolete';
    }

    ## Create a new metadata with the obsolete tag
    
    my %asfile_metadata = $self->get_sample_file_metadbdata($metadata);
    my $mod_metadata_id = $asfile_metadata{$file_id}->store( {   modification_note => $modification_note,
					      	                 obsolete          => $obsolete, 
							         obsolete_note     => $obsolete_note } )
                                                        ->get_metadata_id();
     
    ## Modify the group row in the database
 
    my @bssamplefile_rows = $self->get_bssamplefile_rows();
    foreach my $bssamplefile_row (@bssamplefile_rows) {
	if ($bssamplefile_row->get_column('file_id') == $file_id) {

	    $bssamplefile_row->set_column( metadata_id => $mod_metadata_id );
         
	    $bssamplefile_row->update()
	                     ->discard_changes();
	}
    }
    return $self;
}

=head2 store_children_associations

  Usage: my $sample = $sample->store_children_associations($metadata);
 
  Desc: Store in the database the samples children relationship association 
        for the sample object
 
  Ret: $sample, the sample object with the data updated
 
  Args: $metadata, a metadata object (CXGN::Metadata::Metadbdata object).
 
  Side_Effects: Die if:
                1- None metadata object is supplied.
                2- The metadata supplied is not a CXGN::Metadata::Metadbdata 
                   object
 
  Example: my $sample = $sample->store_children_associations($metadata);

=cut

sub store_children_associations {
    my $self = shift;

    ## FIRST, check the metadata_id supplied as parameter
    my $metadata = shift  
        || croak("STORE ERROR: None metadbdata object was supplied to $self->store_children_associations().\n");
    
    unless (ref($metadata) eq 'CXGN::Metadata::Metadbdata') {
        croak("STORE ERROR: Metadbdata supplied to $self->store_children_associations() is not CXGN::Metadata::Metadbdata object.\n");
    }

    ## It is not necessary check the current user used to store the data because should be the same than the used 
    ## to create a metadata_id. In the medadbdata object, it is checked.

    ## SECOND, check if exists or not sample_relationship_id. 
    ##   if exists sample_relationship_id         => update
    ##   if do not exists sample_relationship_id  => insert

    my @bssamplechildrenrs_rows = $self->get_bssamplechildrenrelationship_rows();
    
    foreach my $bssamplechildrenrs_row (@bssamplechildrenrs_rows) {
        
        my $sample_relationship_id = $bssamplechildrenrs_row->get_column('sample_relationship_id');

	## The sample_id is a foreign key into the database, so if it doesn't exists
	## the DBIx::Class object will return a db error

	my $children_id = $bssamplechildrenrs_row->get_column('object_id');

        unless (defined $sample_relationship_id) {                                   ## NEW INSERT and DISCARD CHANGES
        
            my $metadata_id = $metadata->store()
                                       ->get_metadata_id();

            $bssamplechildrenrs_row->set_column( metadata_id => $metadata_id );    ## Set the metadata_id column
        
            $bssamplechildrenrs_row->insert()
                                   ->discard_changes();                            ## It will set the row with the updated row
                            
        } 
        else {                                                                ## UPDATE IF SOMETHING has change
        
            my @columns_changed = $bssamplechildrenrs_row->is_changed();
        
            if (scalar(@columns_changed) > 0) {                         ## ...something has change, it will take
           
                my @modification_note_list;                             ## the changes and the old metadata object for
                foreach my $col_changed (@columns_changed) {            ## this dbiref and it will create a new row
                    push @modification_note_list, "set value in $col_changed column";
                }
                
                my $modification_note = join ', ', @modification_note_list;
           
		my %aschildren_metadata = $self->get_sample_children_metadbdata($metadata);
		my $mod_metadata_id = $aschildren_metadata{$children_id}->store({ modification_note => $modification_note })
                                                                        ->get_metadata_id(); 

                $bssamplechildrenrs_row->set_column( metadata_id => $mod_metadata_id );

                $bssamplechildrenrs_row->update()
                                       ->discard_changes();
            }
        }
    }
    return $self;    
}

=head2 obsolete_children_association

  Usage: my $sample = $sample->obsolete_children_association($metadata, $note, $children_id, 'REVERT');
 
  Desc: Change the status of a data to obsolete.
        If revert tag is used the obsolete status will be reverted to 0 (false)
 
  Ret: $sample, the sample object updated with the db data.
  
  Args: $metadata, a metadata object (CXGN::Metadata::Metadbdata object).
        $note, a note to explain the cause of make this data obsolete
        $children_id, a sample id associated to this sample as object_sample_id
        optional, 'REVERT'.
  
  Side_Effects: Die if:
                1- None metadata object is supplied.
                2- The metadata supplied is not a CXGN::Metadata::Metadbdata 
  
  Example: my $sample = $sample->obsolete_children_association($metadata, 
                                                          'change to obsolete test', 
                                                          $object_sample_id );

=cut

sub obsolete_children_association {
    my $self = shift;

    ## FIRST, check the metadata_id supplied as parameter
   
    my $metadata = shift  
	|| croak("OBSOLETE ERROR: None metadbdata object was supplied to $self->obsolete_children_association().\n");
    
    unless (ref($metadata) eq 'CXGN::Metadata::Metadbdata') {
	croak("OBSOLETE ERROR: Metadbdata object supplied to $self->obsolete_children_association is not CXGN::Metadata::Metadbdata obj.\n");
    }

    my $obsolete_note = shift 
	|| croak("OBSOLETE ERROR: None obsolete note was supplied to $self->obsolete_children_association().\n");

    my $children_id = shift 
	|| croak("OBSOLETE ERROR: None object_id was supplied to $self->obsolete_children_association().\n");

    my $revert_tag = shift;


    ## If exists the tag revert change obsolete to 0

    my $obsolete = 1;
    my $modification_note = 'change to obsolete';
    if (defined $revert_tag && $revert_tag =~ m/REVERT/i) {
	$obsolete = 0;
	$modification_note = 'revert obsolete';
    }

    ## Create a new metadata with the obsolete tag
    
    my %aschildren_metadata = $self->get_sample_children_metadbdata($metadata);
    my $mod_metadata_id = $aschildren_metadata{$children_id}->store( { modification_note => $modification_note,
				   			               obsolete          => $obsolete, 
							               obsolete_note     => $obsolete_note } )
                                                        ->get_metadata_id();
     
    ## Modify the group row in the database
 
    my @bssamplechildren_rows = $self->get_bssamplechildrenrelationship_rows();
    foreach my $bssamplechildren_row (@bssamplechildren_rows) {
	if ($bssamplechildren_row->get_column('object_id') == $children_id) {

	    $bssamplechildren_row->set_column( metadata_id => $mod_metadata_id );
         
	    $bssamplechildren_row->update()
	                         ->discard_changes();
	}
    }
    return $self;
}

=head2 store_parents_associations

  Usage: my $sample = $sample->store_parents_associations($metadata);
 
  Desc: Store in the database the samples parents relationship association 
        for the sample object
 
  Ret: $sample, the sample object with the data updated
 
  Args: $metadata, a metadata object (CXGN::Metadata::Metadbdata object).
 
  Side_Effects: Die if:
                1- None metadata object is supplied.
                2- The metadata supplied is not a CXGN::Metadata::Metadbdata 
                   object
 
  Example: my $sample = $sample->store_parents_associations($metadata);

=cut

sub store_parents_associations {
    my $self = shift;

    ## FIRST, check the metadata_id supplied as parameter
    my $metadata = shift  
        || croak("STORE ERROR: None metadbdata object was supplied to $self->store_parents_associations().\n");
    
    unless (ref($metadata) eq 'CXGN::Metadata::Metadbdata') {
        croak("STORE ERROR: Metadbdata supplied to $self->store_parents_associations() is not CXGN::Metadata::Metadbdata object.\n");
    }

    ## It is not necessary check the current user used to store the data because should be the same than the used 
    ## to create a metadata_id. In the medadbdata object, it is checked.

    ## SECOND, check if exists or not sample_relationship_id. 
    ##   if exists sample_relationship_id         => update
    ##   if do not exists sample_relationship_id  => insert

    my @bssampleparentsrs_rows = $self->get_bssampleparentsrelationship_rows();
    
    foreach my $bssampleparentsrs_row (@bssampleparentsrs_rows) {
        
        my $sample_relationship_id = $bssampleparentsrs_row->get_column('sample_relationship_id');

	## The sample_id is a foreign key into the database, so if it doesn't exists
	## the DBIx::Class object will return a db error

	my $parent_id = $bssampleparentsrs_row->get_column('subject_id');

        unless (defined $sample_relationship_id) {                                   ## NEW INSERT and DISCARD CHANGES
        
            my $metadata_id = $metadata->store()
                                       ->get_metadata_id();

            $bssampleparentsrs_row->set_column( metadata_id => $metadata_id );    ## Set the metadata_id column
        
            $bssampleparentsrs_row->insert()
                                  ->discard_changes();                            ## It will set the row with the updated row
                            
        } 
        else {                                                                ## UPDATE IF SOMETHING has change
        
            my @columns_changed = $bssampleparentsrs_row->is_changed();
        
            if (scalar(@columns_changed) > 0) {                         ## ...something has change, it will take
           
                my @modification_note_list;                             ## the changes and the old metadata object for
                foreach my $col_changed (@columns_changed) {            ## this dbiref and it will create a new row
                    push @modification_note_list, "set value in $col_changed column";
                }
                
                my $modification_note = join ', ', @modification_note_list;
           
		my %asparents_metadata = $self->get_sample_parents_metadbdata($metadata);
		my $mod_metadata_id = $asparents_metadata{$parent_id}->store({ modification_note => $modification_note })
                                                                     ->get_metadata_id(); 

                $bssampleparentsrs_row->set_column( metadata_id => $mod_metadata_id );

                $bssampleparentsrs_row->update()
                                      ->discard_changes();
            }
        }
    }
    return $self;    
}

=head2 obsolete_parents_association

  Usage: my $sample = $sample->obsolete_parents_association($metadata, $note, $parent_id, 'REVERT');
 
  Desc: Change the status of a data to obsolete.
        If revert tag is used the obsolete status will be reverted to 0 (false)
 
  Ret: $sample, the sample object updated with the db data.
  
  Args: $metadata, a metadata object (CXGN::Metadata::Metadbdata object).
        $note, a note to explain the cause of make this data obsolete
        $parent_id, a sample id associated to this sample as subject_sample_id
        optional, 'REVERT'.
  
  Side_Effects: Die if:
                1- None metadata object is supplied.
                2- The metadata supplied is not a CXGN::Metadata::Metadbdata 
  
  Example: my $sample = $sample->obsolete_parents_association($metadata, 
                                                          'change to obsolete test', 
                                                          $subject_sample_id );

=cut

sub obsolete_parents_association {
    my $self = shift;

    ## FIRST, check the metadata_id supplied as parameter
   
    my $metadata = shift  
	|| croak("OBSOLETE ERROR: None metadbdata object was supplied to $self->obsolete_parents_association().\n");
    
    unless (ref($metadata) eq 'CXGN::Metadata::Metadbdata') {
	croak("OBSOLETE ERROR: Metadbdata object supplied to $self->obsolete_parents_association is not CXGN::Metadata::Metadbdata obj.\n");
    }

    my $obsolete_note = shift 
	|| croak("OBSOLETE ERROR: None obsolete note was supplied to $self->obsolete_parents_association().\n");

    my $parents_id = shift 
	|| croak("OBSOLETE ERROR: None subject_id was supplied to $self->obsolete_parents_association().\n");

    my $revert_tag = shift;


    ## If exists the tag revert change obsolete to 0

    my $obsolete = 1;
    my $modification_note = 'change to obsolete';
    if (defined $revert_tag && $revert_tag =~ m/REVERT/i) {
	$obsolete = 0;
	$modification_note = 'revert obsolete';
    }

    ## Create a new metadata with the obsolete tag
    
    my %asparents_metadata = $self->get_sample_parents_metadbdata($metadata);
    my $mod_metadata_id = $asparents_metadata{$parents_id}->store( { modification_note => $modification_note,
				   			               obsolete          => $obsolete, 
							               obsolete_note     => $obsolete_note } )
                                                        ->get_metadata_id();
     
    ## Modify the group row in the database
 
    my @bssampleparents_rows = $self->get_bssampleparentsrelationship_rows();
    foreach my $bssampleparents_row (@bssampleparents_rows) {
	if ($bssampleparents_row->get_column('subject_id') == $parents_id) {

	    $bssampleparents_row->set_column( metadata_id => $mod_metadata_id );
         
	    $bssampleparents_row->update()
	                        ->discard_changes();
	}
    }
    return $self;
}



#####################
### Other Methods ###
#####################

=head2 get_dbxref_related

  Usage: my %dbxref_related = $sample->get_dbxref_related();
  
  Desc: Get a hash where keys=dbxref_id and values=hash ref
           
  Ret:  %dbxref_related a HASH with KEYS=dbxref_id and VALUE=HASH REF with:
                                    KEYS=type and VALUE=value
        types = (cvterm.cvterm_id, dbxref.dbxref_id, dbxref.accession, db.name, cvterm.name)
  
  Args: $dbname, if dbname is specified it will only get the dbxref associated with this dbname
  
  Side_Effects: none
  
  Example: my %dbxref_related = $sample->get_dbxref_related();
           my %dbxref_po = $sample->get_dbxref_related('PO');

=cut

sub get_dbxref_related {
    my $self = shift;
    my $dbname = shift;

    my %related_global = ();

    my @dbxref_id_list = $self->get_dbxref_list();

    foreach my $dbxref_id (@dbxref_id_list) {

	my %related = ();

	my ($dbxref_row) = $self->get_schema()
	                        ->resultset('General::Dbxref')
		                ->search( { dbxref_id => $dbxref_id } );
	     
	my %dbxref_data = $dbxref_row->get_columns();
	    
	my ($cvterm_row) = $self->get_schema
		                ->resultset('Cv::Cvterm')
		                ->search( { dbxref_id => $dbxref_id } );
	
	my ($db_row) = $self->get_schema()
                                ->resultset('General::Db')
       	                        ->search( { db_id => $dbxref_data{'db_id'} } );

	my $dbmatch = 1;
	if (defined $dbname) {
	    unless ( $db_row->get_column('name') eq $dbname ) {
		$dbmatch = 0;
	    }
	}

	if (defined $cvterm_row) {
	    my %cvterm_data = $cvterm_row->get_columns();
		     	    
	    if ($dbmatch == 1) {
		$related{'dbxref.dbxref_id'} = $dbxref_id;
		$related{'db.name'} = $db_row->get_column('name');
		$related{'db.urlprefix'} = $db_row->get_column('urlprefix');
		$related{'db.url'} = $db_row->get_column('url');
		$related{'dbxref.accession'} = $dbxref_data{'accession'};
		$related{'cvterm.name'} = $cvterm_data{'name'};
		$related{'cvterm.cvterm_id'} = $cvterm_data{'cvterm_id'};
		$related{'cvterm.cv_id'} = $cvterm_data{'cv_id'};
		$related_global{$dbxref_id} = \%related;
	    }
	}
	else {
	    if ($dbmatch == 1) {
		$related{'dbxref.dbxref_id'} = $dbxref_id;
		$related{'db.name'} = $db_row->get_column('name');
		$related{'db.urlprefix'} = $db_row->get_column('urlprefix');
		$related{'db.url'} = $db_row->get_column('url');
		$related{'dbxref.accession'} = $dbxref_data{'accession'};
		$related_global{$dbxref_id} = \%related;
	    }
	}
	
    }
    return %related_global;
}




####
1;##
####
