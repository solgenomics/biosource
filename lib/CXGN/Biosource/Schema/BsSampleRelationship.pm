package CXGN::Biosource::Schema::BsSampleRelationship;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';


=head1 NAME

CXGN::Biosource::Schema::BsSampleRelationship

=head1 DESCRIPTION

biosource.bs_sample_relationship store the associations between sample, for example an est dataset and an unigene dataset can be related with a sequence assembly relation

=cut

__PACKAGE__->table("bs_sample_relationship");

=head1 ACCESSORS

=head2 sample_relationship_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'biosource'

=head2 subject_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 object_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 type_id

  data_type: 'integer'
  is_nullable: 1

=head2 value

  data_type: 'text'
  is_nullable: 1

=head2 rank

  data_type: 'integer'
  is_nullable: 1

=head2 metadata_id

  data_type: 'bigint'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "sample_relationship_id",
  {
    data_type         => "integer",
    default_value     => "nextval('biosource.bs_sample_relationship_sample_relationship_id_seq'::regclass)",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "biosource.bs_sample_relationship_sample_relationship_id_seq",
  },
  "subject_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "object_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "type_id",
  { data_type => "integer", is_nullable => 1 },
  "value",
  { data_type => "text", is_nullable => 1 },
  "rank",
  { data_type => "integer", is_nullable => 1 },
  "metadata_id",
  { data_type => "bigint", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("sample_relationship_id");

=head1 RELATIONS

=head2 subject

Type: belongs_to

Related object: L<CXGN::Biosource::Schema::BsSample>

=cut

__PACKAGE__->belongs_to(
  "subject",
  "CXGN::Biosource::Schema::BsSample",
  { sample_id => "subject_id" },
  { join_type => "LEFT", on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 object

Type: belongs_to

Related object: L<CXGN::Biosource::Schema::BsSample>

=cut

__PACKAGE__->belongs_to(
  "object",
  "CXGN::Biosource::Schema::BsSample",
  { sample_id => "object_id" },
  { join_type => "LEFT", on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07000 @ 2010-06-03 08:44:10
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:6+N63MCuKU9+SVk9yhYSWA

__PACKAGE__->belongs_to(
    'type',
    'Bio::Chado::Schema::Result::Cv::Cvterm',
    { 'foreign.cvterm_id' => 'self.type_id' },
    );

__PACKAGE__->belongs_to(
    'metadata',
    'CXGN::Metadata::Schema::MdMetadata',
    {qw| foreign.metadata_id   self.metadata_id |},
);

# You can replace this text with custom content, and it will be preserved on regeneration
1;
