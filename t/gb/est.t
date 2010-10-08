#!/usr/bin/perl

=head1 NAME

  est.t
  A piece of code to test the CXGN::Biosource::GB::Est module

=cut

=head1 SYNOPSIS

 perl est.t

 prove est.t

=head1 DESCRIPTION

 This script check 133 variables to test the right operation of the 
 CXGN::Biosource::Protocol module.


=cut

=head1 AUTHORS

 Aureliano Bombarely Gomez
 (ab782@cornell.edu)

=cut


use strict;
use warnings;

use Data::Dumper;
use Test::More tests => 28;
use Test::Exception;


BEGIN {
    use_ok('CXGN::Biosource::GB::Est');              ## TEST1
}


#######################################
## FIRST TEST BLOCK: Basic functions ##
#######################################

## Define different test datasets:

my $right_set_href = {
    'dbEST Id'    => '69328768',
    'EST name'    => 'AB553315',
    'GenBank Acc' => 'AB553315',
    'GenBank gi'  => '293631861',
};

my $right_add_href = {
    'Organism'    => 'Petunia axillaris subsp. axillaris',
    'Subspecies'  => 'axillaris',
    'Tissue type' => 'pollen',
};

my $expected_href1 = {
    'dbEST Id'    => '69328768',
    'EST name'    => 'AB553315',
    'GenBank Acc' => 'AB553315',
    'GenBank gi'  => '293631861',
    'Organism'    => 'Petunia axillaris subsp. axillaris',
    'Subspecies'  => 'axillaris',
    'Tissue type' => 'pollen',
};

my $right_edit_href = {
    'EST name'    => 'AB553319',
    'GenBank Acc' => 'AB553319',
};

my $expected_href2 = {
    'dbEST Id'    => '69328768',
    'EST name'    => 'AB553319',
    'GenBank Acc' => 'AB553319',
    'GenBank gi'  => '293631861',
    'Organism'    => 'Petunia axillaris subsp. axillaris',
    'Subspecies'  => 'axillaris',
    'Tissue type' => 'pollen',
};

my $wrong_href_key = {
    'dbEST Id'    => '69328768',
    'EST name'    => 'AB553315',
    'GenBank Acc' => 'AB553315',
    'fake_key'    => '293631861',
};

my $wrong_href1 = ['fake_href'];
my $wrong_href2 = 'fake_href';


## New without data

my $gb_est1 = CXGN::Biosource::GB::Est->new();

$gb_est1->set_data($right_set_href);
my %data = $gb_est1->get_data();

foreach my $key (keys %data) {
    is( $data{$key}, 
	$right_set_href->{$key}, 
	"TESTING BASIC SET/GET FUNCTIONS: checking $key key."
	)
	or diag("Looks like this test failed");
}

$gb_est1->add_data($right_add_href);
my %data1 = $gb_est1->get_data();

foreach my $key1 (keys %data1) {
    is( $data1{$key1}, 
	$expected_href1->{$key1}, 
	"TESTING BASIC ADD FUNCTIONS: checking $key1 key.")
	or diag("Looks like this test failed");
}

$gb_est1->add_data($right_edit_href);
my %data2 = $gb_est1->get_data();

foreach my $key2 (keys %data2) {
    is( $data2{$key2}, 
	$expected_href2->{$key2}, 
	"TESTING BASIC ADD FUNCTIONS, editing data: checking $key2 key.")
	or diag("Looks like this test failed");
}

## Testing picking a concrete data

my $gb_accession = $gb_est1->get_data('GenBank Acc');
is( $gb_accession, 
    $expected_href2->{'GenBank Acc'}, 
    "TESTING BASIC GET FUNCTION, picking a single data, checking 'GenBank Acc'.")
    or diag("Looks like this test failed");
    
## Testing croaks

throws_ok { CXGN::Biosource::GB::Est->new($wrong_href1) } qr/ARGUMENT ERROR: Argument used/, 
    'TESTING DIE ERROR when argument supplied to new() function is not a hash reference 1';

throws_ok { CXGN::Biosource::GB::Est->new($wrong_href2) } qr/ARGUMENT ERROR: Argument used/, 
    'TESTING DIE ERROR when argument supplied to new() function is not a hash reference 2';

throws_ok { $gb_est1->set_data($wrong_href1) } qr/ARGUMENT ERROR: Argument used/, 
    'TESTING DIE ERROR when argument supplied to set_data() function is not a hash reference 1';

throws_ok { $gb_est1->set_data($wrong_href2) } qr/ARGUMENT ERROR: Argument used/, 
    'TESTING DIE ERROR when argument supplied to set_data() function is not a hash reference 2';

throws_ok { $gb_est1->set_data($wrong_href_key) } qr/ARGUMENT ERROR: Key=fake_key used in /, 
    'TESTING DIE ERROR when argument supplied to set_data() function has not a valid key';

throws_ok { $gb_est1->add_data($wrong_href1) } qr/ARGUMENT ERROR: Argument used/, 
    'TESTING DIE ERROR when argument supplied to add_data() function is not a hash reference 1';

throws_ok { $gb_est1->add_data($wrong_href2) } qr/ARGUMENT ERROR: Argument used/, 
    'TESTING DIE ERROR when argument supplied to add_data() function is not a hash reference 2';

throws_ok { $gb_est1->add_data($wrong_href_key) } qr/ARGUMENT ERROR: Key=fake_key used in /, 
    'TESTING DIE ERROR when argument supplied to add_data() function has not a valid key';



####
1; #
####
