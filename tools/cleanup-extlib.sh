#!/bin/sh
rm -rf extlib/man/

# remove HTML::Parser, Digest::SHA1
rm -rf \
  extlib/lib/perl5/*/Digest/SHA1.pm \
  extlib/lib/perl5/*/HTML/Entities.pm \
  extlib/lib/perl5/*/HTML/Filter.pm \
  extlib/lib/perl5/*/HTML/HeadParser.pm \
  extlib/lib/perl5/*/HTML/LinkExtor.pm \
  extlib/lib/perl5/*/HTML/Parser.pm \
  extlib/lib/perl5/*/HTML/PullParser.pm \
  extlib/lib/perl5/*/HTML/TokeParser.pm \
  extlib/lib/perl5/*/auto/Digest/SHA1/SHA1.so \
  extlib/lib/perl5/*/auto/HTML/Parser/Parser.so
