package CXGN::Biosource::Schema::BsSampleElementRelation;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';


=head1 NAME

CXGN::Biosource::Schema::BsSampleElementRelation

=head1 DESCRIPTION

biosource.bs_sample_element_relation store the associations between sample_elements, for example an est dataset and an unigene dataset can be related with a sequence assembly relation

=cut

__PACKAGE__->table("bs_sample_element_relation");

=head1 ACCESSORS

=head2 sample_element_relation_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'biosource'

=head2 sample_element_id_a

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 sample_element_id_b

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 relation_type

  data_type: 'text'
  is_nullable: 1

=head2 metadata_id

  data_type: 'bigint'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "sample_element_relation_id",
  {
    data_type         => "integer",
    default_value     => "nextval('biosource.bs_sample_element_relation_sample_element_relation_id_seq'::regclass)",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "biosource.bs_sample_element_relation_sample_element_relation_id_seq",
  },
  "sample_element_id_a",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "sample_element_id_b",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "relation_type",
  { data_type => "text", is_nullable => 1 },
  "metadata_id",
  { data_type => "bigint", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("sample_element_relation_id");

=head1 RELATIONS

=head2 sample_element_id_a

Type: belongs_to

Related object: L<CXGN::Biosource::Schema::BsSampleElement>

=cut

__PACKAGE__->belongs_to(
  "sample_element_id_a",
  "CXGN::Biosource::Schema::BsSampleElement",
  { sample_element_id => "sample_element_id_a" },
  { join_type => "LEFT", on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 sample_element_id_b

Type: belongs_to

Related object: L<CXGN::Biosource::Schema::BsSampleElement>

=cut

__PACKAGE__->belongs_to(
  "sample_element_id_b",
  "CXGN::Biosource::Schema::BsSampleElement",
  { sample_element_id => "sample_element_id_b" },
  { join_type => "LEFT", on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07000 @ 2010-06-03 08:44:10
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:AXiPl3HMiqgjo3ZKQe1aMA


__PACKAGE__->belongs_to(
    'metadata',
    'CXGN::Metadata::Schema::MdMetadata',
    {qw| foreign.metadata_id   self.metadata_id |},
);

# You can replace this text with custom content, and it will be preserved on regeneration
1;
