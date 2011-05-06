package CXGN::Biosource::Schema::BsSampleElement;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';


=head1 NAME

CXGN::Biosource::Schema::BsSampleElement

=head1 DESCRIPTION

biosource.bs_sample_element store information of each elemennt of a sample. It have a organism_id column and stock_id to associate different origins, for example a tomato leaves sample can be composed by leaves of Solanum lycopersicum and Solanum pimpinellifolium.

=cut

__PACKAGE__->table("bs_sample_element");

=head1 ACCESSORS

=head2 sample_element_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'biosource'

=head2 sample_element_name

  data_type: 'varchar'
  is_nullable: 1
  size: 250

=head2 alternative_name

  data_type: 'text'
  is_nullable: 1

=head2 sample_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 description

  data_type: 'text'
  is_nullable: 1

=head2 organism_id

  data_type: 'integer'
  is_nullable: 1

=head2 stock_id

  data_type: 'integer'
  is_nullable: 1

=head2 protocol_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 metadata_id

  data_type: 'bigint'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "sample_element_id",
  {
    data_type         => "integer",
    default_value     => "nextval('biosource.bs_sample_element_sample_element_id_seq'::regclass)",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "biosource.bs_sample_element_sample_element_id_seq",
  },
  "sample_element_name",
  { data_type => "varchar", is_nullable => 1, size => 250 },
  "alternative_name",
  { data_type => "text", is_nullable => 1 },
  "sample_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "description",
  { data_type => "text", is_nullable => 1 },
  "organism_id",
  { data_type => "integer", is_nullable => 1 },
  "stock_id",
  { data_type => "integer", is_nullable => 1 },
  "protocol_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "metadata_id",
  { data_type => "bigint", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("sample_element_id");

=head1 RELATIONS

=head2 protocol

Type: belongs_to

Related object: L<CXGN::Biosource::Schema::BsProtocol>

=cut

__PACKAGE__->belongs_to(
  "protocol",
  "CXGN::Biosource::Schema::BsProtocol",
  { protocol_id => "protocol_id" },
  { join_type => "LEFT", on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 sample

Type: belongs_to

Related object: L<CXGN::Biosource::Schema::BsSample>

=cut

__PACKAGE__->belongs_to(
  "sample",
  "CXGN::Biosource::Schema::BsSample",
  { sample_id => "sample_id" },
  { join_type => "LEFT", on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 bs_sample_element_cvterms

Type: has_many

Related object: L<CXGN::Biosource::Schema::BsSampleElementCvterm>

=cut

__PACKAGE__->has_many(
  "bs_sample_element_cvterms",
  "CXGN::Biosource::Schema::BsSampleElementCvterm",
  { "foreign.sample_element_id" => "self.sample_element_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 bs_sample_element_dbxrefs

Type: has_many

Related object: L<CXGN::Biosource::Schema::BsSampleElementDbxref>

=cut

__PACKAGE__->has_many(
  "bs_sample_element_dbxrefs",
  "CXGN::Biosource::Schema::BsSampleElementDbxref",
  { "foreign.sample_element_id" => "self.sample_element_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 bs_sample_element_files

Type: has_many

Related object: L<CXGN::Biosource::Schema::BsSampleElementFile>

=cut

__PACKAGE__->has_many(
  "bs_sample_element_files",
  "CXGN::Biosource::Schema::BsSampleElementFile",
  { "foreign.sample_element_id" => "self.sample_element_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 bs_sample_element_relation_sample_element_ids_a

Type: has_many

Related object: L<CXGN::Biosource::Schema::BsSampleElementRelation>

=cut

__PACKAGE__->has_many(
  "bs_sample_element_relation_sample_element_ids_a",
  "CXGN::Biosource::Schema::BsSampleElementRelation",
  { "foreign.sample_element_id_a" => "self.sample_element_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 bs_sample_element_relation_sample_element_id_bs

Type: has_many

Related object: L<CXGN::Biosource::Schema::BsSampleElementRelation>

=cut

__PACKAGE__->has_many(
  "bs_sample_element_relation_sample_element_id_bs",
  "CXGN::Biosource::Schema::BsSampleElementRelation",
  { "foreign.sample_element_id_b" => "self.sample_element_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07000 @ 2010-06-03 08:44:10
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:QqT9f63GLT55oCff0PrR3w


__PACKAGE__->belongs_to(
    'metadata',
    'CXGN::Metadata::Schema::MdMetadata',
    {qw| foreign.metadata_id   self.metadata_id |},
);

# You can replace this text with custom content, and it will be preserved on regeneration
1;
