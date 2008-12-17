use t::Utils;
use Test::More tests => 2;
use App::Mobirc::ConfigLoader;
use FindBin;
use File::Spec;
use YAML;

main();

sub check {
    my $stuff = shift;

    eval {
        App::Mobirc::ConfigLoader->load($stuff);
    };
    my $err = $@ || '';
    is $err, '', "loading success";
}

sub slurp {
    my $fname = shift;

    open my $fh, q{<}, $fname or die $!;
    my $dat = join '', <$fh>;
    close $fh;

    return $dat;
}

sub main {
    my $config_fname = File::Spec->catfile($FindBin::Bin, '..', 'config.yaml.sample');

    check($config_fname);

    # also tests comment.
    my $src = slurp($config_fname);
    $src =~ s/# //g;
    check(YAML::Load($src));
}

