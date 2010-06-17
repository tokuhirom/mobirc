#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use Text::SimpleTable;
use File::Find::Rule;

plan skip_all => 'this test requires "jsl" command'
  unless `jsl` =~ /JavaScript Lint/;

my @files = File::Find::Rule->file()->name('*.js')->in('assets/static/');
plan tests => 1 * @files;

my $table = Text::SimpleTable->new( 25, 5, 5 );

for my $file (@files) {
    # 0 error(s), 6 warning(s)
    my $out = `jsl -stdin < $file`;
    if ( $out =~ /((\d+) error\(s\), (\d+) warning\(s\))/ ) {
        my ( $msg, $err, $warn ) = ( $1, $2, $3 );
        $file =~ s!htdocs/js/!!;
        $table->row( $file, $err, $warn );
        is $err, 0, $file;
    }
    else {
        ok 0;
    }
}

diag $table->draw;
