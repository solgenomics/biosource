use strict;
use Module::Build;

my $build = Module::Build->new(
    dist_name          => 'Biosource',
    dist_author        => 'Sol Genomics Network',
    dist_abstract      => 'Ambikon component to manage sample & protocol data',
    license            => 'perl',
    create_makefile_pl => 'passthrough',

    # current version of our core libraries distribution
    dist_version => '0.1',

    recursive_test_files => 1,

    # and now the list of perl module dependencies

    requires => {
        'DBIx::Class'        => 0,
        'Module::Find'       => 0,
        'Bio::Chado::Schema' => 0,
    },

    build_requires => {
        'Test::More'         => 0,
        'Test::Exception'    => 0,
    },
);

$build->create_build_script;

## Finally it will print the db_patches that this module needs to run to work

my $db_patches = {
                   '0029_biosource_schema.pl'                 => 1,
		   '0032_add_two_biosource_tables.pl'         => 1,
		   '0048_update_biosource_v.0.02_creation.pl' => 1,
                 };

## For now it will print the dbpatches that this Build.PL requires

if (%{$db_patches}) {
    print "\nDB: db_patches required:\n";
    for my $dbpatch (sort keys %{$db_patches}) {
        print "\t+ $dbpatch\n";
    }
}
else {
    print "\nDB: None db_patch is required for this component.\n";
}
print "\n";

###
1;#
###
