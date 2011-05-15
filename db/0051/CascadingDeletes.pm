package CascadingDeletes;
use Moose;

extends 'CXGN::Metadata::Dbpatch';

has '+description' => ( default => <<'' );
Adds cascading deletes from bs_sample to bs_sample_pub, bs_sample_file, bs_sample_relationship.

sub patch {

    shift->dbh->do(<<EOSQL);

SET search_path=biosource,metadata,public;

ALTER TABLE bs_sample_pub
  DROP CONSTRAINT bs_sample_pub_sample_id_fkey;

ALTER TABLE bs_sample_pub
  ADD CONSTRAINT bs_sample_pub_sample_id_fkey
                 FOREIGN KEY (sample_id)
                 REFERENCES bs_sample(sample_id)
                 ON DELETE CASCADE;

ALTER TABLE bs_sample_file
  DROP CONSTRAINT bs_sample_file_sample_id_fkey;

ALTER TABLE bs_sample_file
  ADD CONSTRAINT bs_sample_file_sample_id_fkey
                 FOREIGN KEY (sample_id)
                 REFERENCES bs_sample(sample_id)
                 ON DELETE CASCADE;

ALTER TABLE bs_sample_relationship
  DROP CONSTRAINT bs_sample_relationship_subject_id_fkey,
  DROP CONSTRAINT bs_sample_relationship_object_id_fkey;

ALTER TABLE bs_sample_relationship
  ADD CONSTRAINT bs_sample_relationship_subject_id_fkey
                 FOREIGN KEY (subject_id)
                 REFERENCES bs_sample(sample_id)
                 ON DELETE CASCADE,
  ADD CONSTRAINT bs_sample_relationship_object_id_fkey
                 FOREIGN KEY (object_id)
                 REFERENCES bs_sample(sample_id)
                 ON DELETE CASCADE;
EOSQL

    print "Done.";
    return 1;
}

1;
