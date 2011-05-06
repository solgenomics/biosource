package CXGN::Biosource::Schema::BsTool;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';


=head1 NAME

CXGN::Biosource::Schema::BsTool

=head1 DESCRIPTION

biosource.bs_tool stores information about the tools used during the execution of some protocols. Example of tools are vectors, mRNA purification kits, software, soils. They can have links to web_pages or/and files.

=cut

__PACKAGE__->table("bs_tool");

=head1 ACCESSORS

=head2 tool_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'biosource'

=head2 tool_name

  data_type: 'varchar'
  is_nullable: 1
  size: 250

=head2 tool_version

  data_type: 'varchar'
  is_nullable: 1
  size: 10

=head2 tool_type

  data_type: 'varchar'
  is_nullable: 1
  size: 250

=head2 tool_description

  data_type: 'text'
  is_nullable: 1

=head2 tool_weblink

  data_type: 'text'
  is_nullable: 1

=head2 file_id

  data_type: 'integer'
  is_nullable: 1

=head2 metadata_id

  data_type: 'bigint'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "tool_id",
  {
    data_type         => "integer",
    default_value     => "nextval('biosource.bs_tool_tool_id_seq'::regclass)",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "biosource.bs_tool_tool_id_seq",
  },
  "tool_name",
  { data_type => "varchar", is_nullable => 1, size => 250 },
  "tool_version",
  { data_type => "varchar", is_nullable => 1, size => 10 },
  "tool_type",
  { data_type => "varchar", is_nullable => 1, size => 250 },
  "tool_description",
  { data_type => "text", is_nullable => 1 },
  "tool_weblink",
  { data_type => "text", is_nullable => 1 },
  "file_id",
  { data_type => "integer", is_nullable => 1 },
  "metadata_id",
  { data_type => "bigint", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("tool_id");

=head1 RELATIONS

=head2 bs_protocol_steps

Type: has_many

Related object: L<CXGN::Biosource::Schema::BsProtocolStep>

=cut

__PACKAGE__->has_many(
  "bs_protocol_steps",
  "CXGN::Biosource::Schema::BsProtocolStep",
  { "foreign.tool_id" => "self.tool_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 bs_tool_pubs

Type: has_many

Related object: L<CXGN::Biosource::Schema::BsToolPub>

=cut

__PACKAGE__->has_many(
  "bs_tool_pubs",
  "CXGN::Biosource::Schema::BsToolPub",
  { "foreign.tool_id" => "self.tool_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07000 @ 2010-06-03 08:44:10
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:aohxpyj2D7n4qDaJsexppw


__PACKAGE__->belongs_to(
    'metadata',
    'CXGN::Metadata::Schema::MdMetadata',
    {qw| foreign.metadata_id   self.metadata_id |},
);

# You can replace this text with custom content, and it will be preserved on regeneration
1;
