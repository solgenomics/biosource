package CXGN::Biosource::Schema::BsSampleElementDbxref;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';


=head1 NAME

CXGN::Biosource::Schema::BsSampleElementDbxref

=head1 DESCRIPTION

biosource.bs_sample_element_dbxref is a linker table to associate controlled vocabullary as Plant Ontology to each element of a sample

=cut

__PACKAGE__->table("bs_sample_element_dbxref");

=head1 ACCESSORS

=head2 sample_element_dbxref_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'biosource'

=head2 sample_element_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 dbxref_id

  data_type: 'bigint'
  is_nullable: 1

=head2 metadata_id

  data_type: 'bigint'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "sample_element_dbxref_id",
  {
    data_type         => "integer",
    default_value     => "nextval('biosource.bs_sample_element_dbxref_sample_element_dbxref_id_seq'::regclass)",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "biosource.bs_sample_element_dbxref_sample_element_dbxref_id_seq",
  },
  "sample_element_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "dbxref_id",
  { data_type => "bigint", is_nullable => 1 },
  "metadata_id",
  { data_type => "bigint", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("sample_element_dbxref_id");

=head1 RELATIONS

=head2 sample_element

Type: belongs_to

Related object: L<CXGN::Biosource::Schema::BsSampleElement>

=cut

__PACKAGE__->belongs_to(
  "sample_element",
  "CXGN::Biosource::Schema::BsSampleElement",
  { sample_element_id => "sample_element_id" },
  { join_type => "LEFT", on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07000 @ 2010-06-03 08:44:10
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:HfXtJHVpKVnqf7BYIDlaXA


# You can replace this text with custom content, and it will be preserved on regeneration
1;
