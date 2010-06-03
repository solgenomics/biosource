package CXGN::Biosource::Schema::BsSampleCvterm;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';


=head1 NAME

CXGN::Biosource::Schema::BsSampleCvterm

=head1 DESCRIPTION

biosource.bs_sample_cvterm is a linker table to associate tags to the samples as Normalized, Sustracted...

=cut

__PACKAGE__->table("bs_sample_cvterm");

=head1 ACCESSORS

=head2 sample_cvterm_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'biosource'

=head2 sample_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 cvterm_id

  data_type: 'integer'
  is_nullable: 1

=head2 metadata_id

  data_type: 'bigint'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "sample_cvterm_id",
  {
    data_type         => "integer",
    default_value     => "nextval('biosource.bs_sample_cvterm_sample_cvterm_id_seq'::regclass)",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "biosource",
  },
  "sample_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "cvterm_id",
  { data_type => "integer", is_nullable => 1 },
  "metadata_id",
  { data_type => "bigint", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("sample_cvterm_id");

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
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:zd56IZ4rxNCERY4el35Y/A


# You can replace this text with custom content, and it will be preserved on regeneration
1;
