package CXGN::Biosource::Schema::BsSampleDbxref;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';


=head1 NAME

CXGN::Biosource::Schema::BsSampleDbxref

=head1 DESCRIPTION

biosource.bs_sample_dbxref is a linker table to associate controlled vocabullary as Plant Ontology to each element of a sample

=cut

__PACKAGE__->table("bs_sample_dbxref");

=head1 ACCESSORS

=head2 sample_dbxref_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'biosource'

=head2 sample_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 dbxref_id

  data_type: 'bigint'
  is_nullable: 1

=head2 metadata_id

  data_type: 'bigint'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "sample_dbxref_id",
  {
    data_type         => "integer",
    default_value     => "nextval('biosource.bs_sample_dbxref_sample_dbxref_id_seq'::regclass)",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "biosource.bs_sample_dbxref_sample_dbxref_id_seq",
  },
  "sample_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "dbxref_id",
  { data_type => "bigint", is_nullable => 1 },
  "metadata_id",
  { data_type => "bigint", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("sample_dbxref_id");

=head1 RELATIONS

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


# Created by DBIx::Class::Schema::Loader v0.07000 @ 2010-06-03 08:44:10
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:uuTrARXnNU8OCdGSbmcCsg

__PACKAGE__->belongs_to(
    'dbxref',
    'Bio::Chado::Schema::Result::General::Dbxref',
    { 'dbxref_id' => 'dbxref_id' },
    );


__PACKAGE__->belongs_to(
    'metadata',
    'CXGN::Metadata::Schema::MdMetadata',
    {qw| foreign.metadata_id   self.metadata_id |},
);

# You can replace this text with custom content, and it will be preserved on regeneration
1;
