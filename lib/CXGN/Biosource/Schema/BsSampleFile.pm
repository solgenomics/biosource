package CXGN::Biosource::Schema::BsSampleFile;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';


=head1 NAME

CXGN::Biosource::Schema::BsSampleFile

=head1 DESCRIPTION

biosource.bs_sample_file store the associations between the sample and files.

=cut

__PACKAGE__->table("bs_sample_file");

=head1 ACCESSORS

=head2 sample_file_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'biosource'

=head2 sample_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 file_id

  data_type: 'integer'
  is_nullable: 1

=head2 metadata_id

  data_type: 'bigint'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "sample_file_id",
  {
    data_type         => "integer",
    default_value     => "nextval('biosource.bs_sample_file_sample_file_id_seq'::regclass)",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "biosource.bs_sample_file_sample_file_id_seq",
  },
  "sample_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "file_id",
  { data_type => "integer", is_nullable => 1 },
  "metadata_id",
  { data_type => "bigint", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("sample_file_id");

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
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Y6uZB3sju8BSyC9P+cy5kQ


# You can replace this text with custom content, and it will be preserved on regeneration
1;
