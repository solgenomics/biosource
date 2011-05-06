package CXGN::Biosource::Schema::BsProtocolPub;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';


=head1 NAME

CXGN::Biosource::Schema::BsProtocolPub

=head1 DESCRIPTION

biosource.bs_protocol_pub is a linker table to associate publications to some protocols

=cut

__PACKAGE__->table("bs_protocol_pub");

=head1 ACCESSORS

=head2 protocol_pub_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'biosource'

=head2 protocol_id

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
  "protocol_pub_id",
  {
    data_type         => "integer",
    default_value     => "nextval('biosource.bs_protocol_pub_protocol_pub_id_seq'::regclass)",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "biosource.bs_protocol_pub_protocol_pub_id_seq",
  },
  "protocol_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "pub_id",
  { data_type => "integer", is_nullable => 1 },
  "metadata_id",
  { data_type => "bigint", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("protocol_pub_id");

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


# Created by DBIx::Class::Schema::Loader v0.07000 @ 2010-06-03 08:44:10
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:JkAEt244XRrh4Awk5mrD8g


__PACKAGE__->belongs_to(
    'metadata',
    'CXGN::Metadata::Schema::MdMetadata',
    {qw| foreign.metadata_id   self.metadata_id |},
);

# You can replace this text with custom content, and it will be preserved on regeneration
1;
