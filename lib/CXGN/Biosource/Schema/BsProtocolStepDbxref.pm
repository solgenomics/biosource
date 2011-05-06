package CXGN::Biosource::Schema::BsProtocolStepDbxref;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';


=head1 NAME

CXGN::Biosource::Schema::BsProtocolStepDbxref

=head1 DESCRIPTION

biosource.bs_protocol_step_dbxref is a loker table designed to store controlled vocabulary terms associated to some protocol steps

=cut

__PACKAGE__->table("bs_protocol_step_dbxref");

=head1 ACCESSORS

=head2 protocol_step_dbxref_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'biosource'

=head2 protocol_step_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 dbxref_id

  data_type: 'integer'
  is_nullable: 1

=head2 metadata_id

  data_type: 'bigint'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "protocol_step_dbxref_id",
  {
    data_type         => "integer",
    default_value     => "nextval('biosource.bs_protocol_step_dbxref_protocol_step_dbxref_id_seq'::regclass)",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "biosource.bs_protocol_step_dbxref_protocol_step_dbxref_id_seq",
  },
  "protocol_step_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "dbxref_id",
  { data_type => "integer", is_nullable => 1 },
  "metadata_id",
  { data_type => "bigint", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("protocol_step_dbxref_id");

=head1 RELATIONS

=head2 protocol_step

Type: belongs_to

Related object: L<CXGN::Biosource::Schema::BsProtocolStep>

=cut

__PACKAGE__->belongs_to(
  "protocol_step",
  "CXGN::Biosource::Schema::BsProtocolStep",
  { protocol_step_id => "protocol_step_id" },
  { join_type => "LEFT", on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07000 @ 2010-06-03 08:44:10
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:fQCLmqu/Hf69A2HsLq4R5A


__PACKAGE__->belongs_to(
    'metadata',
    'CXGN::Metadata::Schema::MdMetadata',
    {qw| foreign.metadata_id   self.metadata_id |},
);

# You can replace this text with custom content, and it will be preserved on regeneration
1;
