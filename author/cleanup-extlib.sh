#!/bin/zsh
rm -rf extlib/man/
rm -rf extlib/**/.meta/**/install.json
rm -rf extlib/lib/perl5/x86_64-*/perllocal.pod

# remove HTML::Parser, Digest::SHA1
rm -rf
  extlib/lib/perl5/**/*.bs
rm -rf \
  extlib/lib/perl5/*/Digest/SHA1.pm \
  extlib/lib/perl5/*/auto/Digest/SHA1/SHA1.so
rm -rf \
  extlib/lib/perl5/*/HTML/Entities.pm \
  extlib/lib/perl5/*/HTML/Filter.pm \
  extlib/lib/perl5/*/HTML/HeadParser.pm \
  extlib/lib/perl5/*/HTML/LinkExtor.pm \
  extlib/lib/perl5/*/HTML/Parser.pm \
  extlib/lib/perl5/*/HTML/PullParser.pm \
  extlib/lib/perl5/*/HTML/TokeParser.pm \
  extlib/lib/perl5/*/auto/HTML/Parser/Parser.so
