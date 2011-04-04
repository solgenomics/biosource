package FixSamplePubConstraint;
use Moose;

extends 'CXGN::Metadata::Dbpatch';

sub description { 'fix the foreign key constraint on the bs_sample_pub table to cascade when a sample is deleted' }

sub patch {
    my $self = shift;
    $self->dbh->{RaiseError} = 1;
    $self->dbh->do(<<'');
alter table biosource.bs_sample_pub drop CONSTRAINT bs_sample_pub_sample_id_fkey;
alter table biosource.bs_sample_pub add constraint bs_sample_pub_sample_id_fkey  FOREIGN KEY (sample_id) REFERENCES biosource.bs_sample(sample_id) on delete cascade;


    print "done.\n";
}

1;
