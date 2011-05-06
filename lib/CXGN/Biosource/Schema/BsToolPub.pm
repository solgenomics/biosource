package CXGN::Biosource::Schema::BsToolPub;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';


=head1 NAME

CXGN::Biosource::Schema::BsToolPub

=head1 DESCRIPTION

biosource.bs_tool_pub is a linker table to associate publications to some tools

=cut

__PACKAGE__->table("bs_tool_pub");

=head1 ACCESSORS

=head2 tool_pub_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'biosource'

=head2 tool_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 pub_id

  data_type: 'integer'
  is_nullable: 1

=head2 metadata_id

  data_type: 'bigint'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "tool_pub_id",
  {
    data_type         => "integer",
    default_value     => "nextval('biosource.bs_tool_pub_tool_pub_id_seq'::regclass)",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "biosource.bs_tool_pub_tool_pub_id_seq",
  },
  "tool_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "pub_id",
  { data_type => "integer", is_nullable => 1 },
  "metadata_id",
  { data_type => "bigint", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("tool_pub_id");

=head1 RELATIONS

=head2 tool

Type: belongs_to

Related object: L<CXGN::Biosource::Schema::BsTool>

=cut

__PACKAGE__->belongs_to(
  "tool",
  "CXGN::Biosource::Schema::BsTool",
  { tool_id => "tool_id" },
  { join_type => "LEFT", on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07000 @ 2010-06-03 08:44:10
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:nkrPs3q1Fyd7gecFl0hHVA


__PACKAGE__->belongs_to(
    'metadata',
    'CXGN::Metadata::Schema::MdMetadata',
    {qw| foreign.metadata_id   self.metadata_id |},
);

# You can replace this text with custom content, and it will be preserved on regeneration
1;
