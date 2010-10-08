
package CXGN::Biosource::GB::Est;

use strict;
use warnings;


use CXGN::Biosource::Sample;

use Carp qw| croak cluck |;


###############
### PERLDOC ###
###############

=head1 NAME

CXGN::Biosource::GB::Est
a class to create an object to store GenBank Est data

=cut

our $VERSION = '0.01';
$VERSION = eval $VERSION;

=head1 SYNOPSIS

  use CXGN::Biosource::GB::Est;

  ## Constructor

  my $gb_est = CXGN::Biosource::GB::Est->new();
  my $gb_est = CXGN::Biosource::GB::Est->new({ %gb_est_data });

  ## Basic Accessors

  my %gb_data = $est_gb->get_data();
  my $est_name = $est_gb->get_data('EST name');

  ## To set the data:
  $est_gb->set_data({ 'EST name' => $est_name });
  
  ## To add a new key/value pair to the object:
  $est_gb->add_data({ 'EST name' => $est_name  })

  ## Accessor list:
  ## 'dbEST Id', 'EST name', 'GenBank Acc', 'GenBank gi',
  ## 'DNA type',
  ## 'PolyA Tail',
  ## 'sequence', 'Entry Created', 'Last Updated',
  ## 'Lib Name', 'Organism', 'Subspecies', 'Cultivar', 'Tissue type', 'Develop. stage', 'Description',
  ## 'Name', 'Institution', 'Address', 'Tel', 'Fax', 'E-mail',
  ## 'PubMed ID','Title','Authors','Citation'


=head1 DESCRIPTION

 This object manage Est data from the GenBank Est format (from dbEST database)


=head1 AUTHOR

Aureliano Bombarely <ab782@cornell.edu>


=head1 CLASS METHODS

The following class methods are implemented:

=cut 



############################
### GENERAL CONSTRUCTORS ###
############################

=head2 constructor new

  Usage: my $gb_est = CXGN::Biosource::GB::Est->new();
         my $gb_est = CXGN::Biosource::GB::Est->new({ %gb_est_data });

  Desc: Create a new GB Est object

  Ret: a CXGN::Biosource::GB::Est object

  Args: {%gb_est_data}, a hash reference with genbank data

  Side_Effects: Die if the argument used is not a hash reference

  Example: my $gb_est = CXGN::Biosource::GB::Est->new('AB553315');
           my $gb_est = CXGN::Biosource::GB::Est->new(
              {
                'Lib Name' => 'petunia pollen cDNA library', 
                'Organism' => 'Petunia axillaris subsp. axillaris'
	      }
           );

=cut

sub new {
    my $class = shift;
    my $arg_href = shift;

    my $self = bless( {}, $class );                             

    if (defined $arg_href && ref($arg_href) ne 'HASH') {
	croak("ARGUMENT ERROR: Argument used for $self->new() function is not a hash reference.\n");
    }
    else {
	$self->set_data($arg_href);
    }
    
    return $self;
}



#################
### ACCESSORS ###
#################

=head2 get_data

  Usage: my %gb_data = $est_gb->get_data();
         my $gb_field = $est_gb->get_data($field);

  Desc: Get data from the CXGN::Biosource::GB::Est object

  Ret: A hash if no argument was used
       A scalar if a scalar was used, or undef if the
       scalar do not exists inside the object
 
  Args: $field, a scalar with the field name to get the genbank est data
 
  Side_Effects: None
 
  Example: my %gb_data = $est_gb->get_data();
           my $est_name = $est_gb->get_data('EST name');

=cut

sub get_data {
  my $self = shift;
  my $field = shift;

  my %data = %{$self->{gb_data}};

  unless (defined $field) {
      return %data;
  }
  else {
      return $data{$field}; 
  }
}


=head2 set_data

  Usage: $est_gb->set_data($data_href);

  Desc: Set data from the CXGN::Biosource::GB::Est object

  Ret: None
 
  Args: $data_href, a hash reference with genbank data with
        the following keys: 'dbEST Id', 'EST name', 
        'GenBank Acc', 'GenBank gi', 'DNA type', 'PolyA Tail',
        'sequence', 'Entry Created', 'Last Updated', 'Lib Name', 
        'Organism', 'Subspecies', 'Cultivar', 'Tissue type', 
        'Develop. stage', 'Description', 'Name', 'Institution', 
        'Address', 'Tel', 'Fax', 'E-mail', 'PubMed ID', 'Title',
        'Authors' and 'Citation'
 
  Side_Effects: Die if the argument is not a hash reference 
                or the keys are not permited
 
  Example: $est_gb->set_data({ Organism => 'Solanum tuberosum'});

=cut

sub set_data {
  my $self = shift;
  my $data_href = shift;
  
  if (defined $data_href) {
      if (ref($data_href) ne 'HASH') {
	  croak("ARGUMENT ERROR: Argument used $self->set_data() is not a hash reference.\n");
      }
 
      my %permited_keys = (
	  'EST name'       => 1,
	  'dbEST Id'       => 1,
	  'GenBank Acc'    => 1, 
	  'GenBank gi'     => 1, 
	  'DNA type'       => 1, 
	  'PolyA Tail'     => 1,
	  'sequence'       => 1, 
	  'Entry Created'  => 1, 
	  'Last Updated'   => 1, 
	  'Lib Name'       => 1, 
	  'Organism'       => 1,
	  'Subspecies'     => 1,
	  'Cultivar'       => 1,
	  'Tissue type'    => 1,
	  'Develop. stage' => 1,  
	  'Description'    => 1,
	  'Name'           => 1, 
	  'Institution'    => 1, 
	  'Address'        => 1, 
	  'Tel'            => 1, 
	  'Fax'            => 1, 
	  'E-mail'         => 1,
	  'PubMed ID'      => 1, 
	  'Title'          => 1, 
	  'Authors'	   => 1,
	  'Citation'       => 1
	  );

      ## Check the permited key
  
      foreach my $key (keys %{$data_href}) {
	  unless (exists $permited_keys{$key}) {
	      croak("ARGUMENT ERROR: Key=$key used in the hash reference for the function $self->set_data() is not a valid key.\n");
	  }
      }
  }
  else {
      $data_href = {};
  }

  $self->{gb_data} = $data_href;
}


=head2 add_data

  Usage: $est_gb->add_data($hash_ref);

  Desc: Add data to the CXGN::Biosource::GB::Est object

  Ret: None

  Args: $data_href, a hash reference with genbank data with
        the following keys: 'dbEST Id', 'EST name', 
        'GenBank Acc', 'GenBank gi', 'DNA type', 'PolyA Tail',
        'sequence', 'Entry Created', 'Last Updated', 'Lib Name', 
        'Organism', 'Cultivar', 'Develop. stage', 'Description',
        'Name', 'Institution', 'Address', 'Tel', 'Fax', 'E-mail',
        'PubMed ID', 'Title', 'Authors' and 'Citation'
 
  Side_Effects: Die if the argument is not a hash reference 
                or the keys are not permited
 
  Example: $est_gb->add_data({ Organism => 'Solanum tuberosum'});

=cut

sub add_data {
     my $self = shift;
     my $data_href = shift;
  
     if (defined $data_href) {
	 if (ref($data_href) ne 'HASH') {
	     croak("ARGUMENT ERROR: Argument used $self->add_data() is not a hash reference.\n");
	 }
     }
     my $obj_data_href = $self->{gb_data};
     foreach my $key (keys %{$data_href}) {
	 $obj_data_href->{$key} = $data_href->{$key};
     }

     $self->set_data($obj_data_href);
}



####
1; #
####
