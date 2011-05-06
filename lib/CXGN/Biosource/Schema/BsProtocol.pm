package CXGN::Biosource::Schema::BsProtocol;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';


=head1 NAME

CXGN::Biosource::Schema::BsProtocol

=head1 DESCRIPTION

biosource.bs_protocol store general information about how something was processed. mRNA extraction is a protocol, but also can be a protocol sequence_assembly or plant growth

=cut

__PACKAGE__->table("bs_protocol");

=head1 ACCESSORS

=head2 protocol_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'biosource'

=head2 protocol_name

  data_type: 'varchar'
  is_nullable: 1
  size: 250

=head2 protocol_type

  data_type: 'varchar'
  is_nullable: 1
  size: 250

=head2 description

  data_type: 'text'
  is_nullable: 1

=head2 metadata_id

  data_type: 'bigint'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "protocol_id",
  {
    data_type         => "integer",
    default_value     => "nextval('biosource.bs_protocol_protocol_id_seq'::regclass)",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "biosource.bs_protocol_protocol_id_seq",
  },
  "protocol_name",
  { data_type => "varchar", is_nullable => 1, size => 250 },
  "protocol_type",
  { data_type => "varchar", is_nullable => 1, size => 250 },
  "description",
  { data_type => "text", is_nullable => 1 },
  "metadata_id",
  { data_type => "bigint", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("protocol_id");

=head1 RELATIONS

=head2 bs_protocol_pubs

Type: has_many

Related object: L<CXGN::Biosource::Schema::BsProtocolPub>

=cut

__PACKAGE__->has_many(
  "bs_protocol_pubs",
  "CXGN::Biosource::Schema::BsProtocolPub",
  { "foreign.protocol_id" => "self.protocol_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 bs_protocol_steps

Type: has_many

Related object: L<CXGN::Biosource::Schema::BsProtocolStep>

=cut

__PACKAGE__->has_many(
  "bs_protocol_steps",
  "CXGN::Biosource::Schema::BsProtocolStep",
  { "foreign.protocol_id" => "self.protocol_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 bs_samples

Type: has_many

Related object: L<CXGN::Biosource::Schema::BsSample>

=cut

__PACKAGE__->has_many(
  "bs_samples",
  "CXGN::Biosource::Schema::BsSample",
  { "foreign.protocol_id" => "self.protocol_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 bs_sample_elements

Type: has_many

Related object: L<CXGN::Biosource::Schema::BsSampleElement>

=cut

__PACKAGE__->has_many(
  "bs_sample_elements",
  "CXGN::Biosource::Schema::BsSampleElement",
  { "foreign.protocol_id" => "self.protocol_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07000 @ 2010-06-03 08:44:10
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:0oesosJwIP+DOTqEPvUrqg


__PACKAGE__->belongs_to(
    'metadata',
    'CXGN::Metadata::Schema::MdMetadata',
    {qw| foreign.metadata_id   self.metadata_id |},
);

# You can replace this text with custom content, and it will be preserved on regeneration
1;
