package CXGN::Biosource::Schema::BsProtocolStep;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';


=head1 NAME

CXGN::Biosource::Schema::BsProtocolStep

=head1 DESCRIPTION

biosource.bs_protocol_step store data for each step or stage in a protocol. They are order by the secuencially by step column. Execution describe the action produced during the step, for example plant growth at 24C, blastall -p blastx, ligation... begin_date, end_date and location generally will be used for plant field growth conditions.

=cut

__PACKAGE__->table("bs_protocol_step");

=head1 ACCESSORS

=head2 protocol_step_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'biosource'

=head2 protocol_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 step

  data_type: 'integer'
  is_nullable: 1

=head2 action

  data_type: 'text'
  is_nullable: 1

=head2 execution

  data_type: 'text'
  is_nullable: 1

=head2 tool_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 begin_date

  data_type: 'timestamp'
  is_nullable: 1

=head2 end_date

  data_type: 'timestamp'
  is_nullable: 1

=head2 location

  data_type: 'text'
  is_nullable: 1

=head2 metadata_id

  data_type: 'bigint'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "protocol_step_id",
  {
    data_type         => "integer",
    default_value     => "nextval('biosource.bs_protocol_step_protocol_step_id_seq'::regclass)",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "biosource.bs_protocol_step_protocol_step_id_seq",
  },
  "protocol_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "step",
  { data_type => "integer", is_nullable => 1 },
  "action",
  { data_type => "text", is_nullable => 1 },
  "execution",
  { data_type => "text", is_nullable => 1 },
  "tool_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "begin_date",
  { data_type => "timestamp", is_nullable => 1 },
  "end_date",
  { data_type => "timestamp", is_nullable => 1 },
  "location",
  { data_type => "text", is_nullable => 1 },
  "metadata_id",
  { data_type => "bigint", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("protocol_step_id");

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

=head2 bs_protocol_step_dbxrefs

Type: has_many

Related object: L<CXGN::Biosource::Schema::BsProtocolStepDbxref>

=cut

__PACKAGE__->has_many(
  "bs_protocol_step_dbxrefs",
  "CXGN::Biosource::Schema::BsProtocolStepDbxref",
  { "foreign.protocol_step_id" => "self.protocol_step_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07000 @ 2010-06-03 08:44:10
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Eo14DzLYVIwcjwZp96WR5g


__PACKAGE__->belongs_to(
    'metadata',
    'CXGN::Metadata::Schema::MdMetadata',
    {qw| foreign.metadata_id   self.metadata_id |},
);

# You can replace this text with custom content, and it will be preserved on regeneration
1;
