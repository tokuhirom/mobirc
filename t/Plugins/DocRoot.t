use strict;
use warnings;
use App::Mobirc::Plugin::DocRoot;
use Test::Base;

filters {
    input => [qw/convert/],
};

sub convert {
    App::Mobirc::Plugin::DocRoot::_html_filter_docroot(undef, $_[0], {root => '/foo/'});
}

__END__

===
--- input
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN" "http://www.w3.org/TR/REC-html40/loose.dtd">
<html><body><a href="/">top</a></body></html>
--- expected
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN" "http://www.w3.org/TR/REC-html40/loose.dtd">
<html><body><a href="/foo/">top</a></body></html>

===
--- input
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN" "http://www.w3.org/TR/REC-html40/loose.dtd">
<html><body><script src="/mobirc.js"></script></body></html>
--- expected
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN" "http://www.w3.org/TR/REC-html40/loose.dtd">
<html><body><script src="/foo/mobirc.js"></script></body></html>

===
--- input
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN" "http://www.w3.org/TR/REC-html40/loose.dtd">
<html><body><link rel="stylesheet" href="/style.css" type="text/css"></body></html>
--- expected
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN" "http://www.w3.org/TR/REC-html40/loose.dtd">
<html><body><link rel="stylesheet" href="/foo/style.css" type="text/css"></body></html>
