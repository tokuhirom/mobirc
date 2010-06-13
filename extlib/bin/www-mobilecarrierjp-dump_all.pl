use strict;
use warnings;
use YAML;
use FindBin;
use File::Spec;
use lib File::Spec->catfile($FindBin::Bin, '..', 'lib');
use Module::Pluggable::Object;

my $pluggable = Module::Pluggable::Object->new(
    'require' => 'yes',
    'search_path' => ['WWW::MobileCarrierJP'],
);

my $datdir = File::Spec->catfile($FindBin::Bin, '..', 'dat');
mkdir $datdir;
for my $module ($pluggable->plugins()) {
    next if $module eq 'WWW::MobileCarrierJP::Declare';

    my $fname = $module;
    $fname =~ s/^WWW::MobileCarrierJP:://;
    $fname =~ s/::/-/g;
    $fname = lc $fname;
    YAML::DumpFile(
        File::Spec->catfile($datdir, "$fname.yaml"),
        $module->scrape(),
    );
}

