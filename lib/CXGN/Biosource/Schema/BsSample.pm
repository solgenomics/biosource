package CXGN::Biosource::Schema::BsSample;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';


=head1 NAME

CXGN::Biosource::Schema::BsSample

=head1 DESCRIPTION

biosource.bs_sample store information about the origin of a biological sample. It can be composed by different elements, for example tomato fruit sample can be a mix of fruits in different stages. Each stage will be a sample_element. Sample also can have associated a sp_person_id in terms of contact.

=cut

__PACKAGE__->table("bs_sample");

=head1 ACCESSORS

=head2 sample_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'biosource'

=head2 sample_name

  data_type: 'varchar'
  is_nullable: 1
  size: 250

=head2 sample_type

  data_type: 'varchar'
  is_nullable: 1
  size: 250

=head2 alternative_name

  data_type: 'text'
  is_nullable: 1

=head2 type_id

  data_type: 'bigint'
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

  data_type: 'bigint'
  is_foreign_key: 1
  is_nullable: 1

=head2 contact_id

  data_type: 'integer'
  is_nullable: 1

=head2 metadata_id

  data_type: 'bigint'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "sample_id",
  {
    data_type         => "integer",
    default_value     => "nextval('biosource.bs_sample_sample_id_seq'::regclass)",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "biosource.bs_sample_sample_id_seq",
  },
  "sample_name",
  { data_type => "varchar", is_nullable => 1, size => 250 },
  "sample_type",
  { data_type => "varchar", is_nullable => 1, size => 250 },
  "alternative_name",
  { data_type => "text", is_nullable => 1 },
  "type_id",
  { data_type => "bigint", is_nullable => 1 },
  "description",
  { data_type => "text", is_nullable => 1 },
  "organism_id",
  { data_type => "integer", is_nullable => 1 },
  "stock_id",
  { data_type => "integer", is_nullable => 1 },
  "protocol_id",
  { data_type => "bigint", is_foreign_key => 1, is_nullable => 1 },
  "contact_id",
  { data_type => "integer", is_nullable => 1 },
  "metadata_id",
  { data_type => "bigint", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("sample_id");

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

=head2 bs_sample_cvterms

Type: has_many

Related object: L<CXGN::Biosource::Schema::BsSampleCvterm>

=cut

__PACKAGE__->has_many(
  "bs_sample_cvterms",
  "CXGN::Biosource::Schema::BsSampleCvterm",
  { "foreign.sample_id" => "self.sample_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 bs_sample_dbxrefs

Type: has_many

Related object: L<CXGN::Biosource::Schema::BsSampleDbxref>

=cut

__PACKAGE__->has_many(
  "bs_sample_dbxrefs",
  "CXGN::Biosource::Schema::BsSampleDbxref",
  { "foreign.sample_id" => "self.sample_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 bs_sample_elements

Type: has_many

Related object: L<CXGN::Biosource::Schema::BsSampleElement>

=cut

__PACKAGE__->has_many(
  "bs_sample_elements",
  "CXGN::Biosource::Schema::BsSampleElement",
  { "foreign.sample_id" => "self.sample_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 bs_sample_files

Type: has_many

Related object: L<CXGN::Biosource::Schema::BsSampleFile>

=cut

__PACKAGE__->has_many(
  "bs_sample_files",
  "CXGN::Biosource::Schema::BsSampleFile",
  { "foreign.sample_id" => "self.sample_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 bs_sample_pubs

Type: has_many

Related object: L<CXGN::Biosource::Schema::BsSamplePub>

=cut

__PACKAGE__->has_many(
  "bs_sample_pubs",
  "CXGN::Biosource::Schema::BsSamplePub",
  { "foreign.sample_id" => "self.sample_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 bs_sample_relationship_subjects

Type: has_many

Related object: L<CXGN::Biosource::Schema::BsSampleRelationship>

=cut

__PACKAGE__->has_many(
  "bs_sample_relationship_subjects",
  "CXGN::Biosource::Schema::BsSampleRelationship",
  { "foreign.subject_id" => "self.sample_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 bs_sample_relationship_objects

Type: has_many

Related object: L<CXGN::Biosource::Schema::BsSampleRelationship>

=cut

__PACKAGE__->has_many(
  "bs_sample_relationship_objects",
  "CXGN::Biosource::Schema::BsSampleRelationship",
  { "foreign.object_id" => "self.sample_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07000 @ 2010-06-03 08:44:10
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Z8ynJHBhRUewSoAByUtx2w

__PACKAGE__->belongs_to(
    'stock',
    'Bio::Chado::Schema::Result::Stock::Stock',
    {qw| foreign.stock_id   self.stock_id |},
);

__PACKAGE__->belongs_to(
    'organism',
    'Bio::Chado::Schema::Result::Organism::Organism',
    {qw| foreign.organism_id   self.organism_id |},
);

__PACKAGE__->belongs_to(
    'type',
    'Bio::Chado::Schema::Result::Cv::Cvterm',
    {qw| foreign.cvterm_id   self.type_id |},
);

__PACKAGE__->many_to_many(
    'dbxrefs',
    'bs_sample_dbxrefs' => 'dbxref'
  );

# You can replace this text with custom content, and it will be preserved on regeneration
1;
