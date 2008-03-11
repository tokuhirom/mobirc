use strict;
use warnings;
use utf8;
use App::Mobirc::Plugin::DocRoot;
use Encode;
use Test::Base;

filters {
    input => [qw/convert/],
};

sub convert {
    my $src = shift;
    ok Encode::is_utf8($src);
    my $dst = App::Mobirc::Plugin::DocRoot::_html_filter_docroot(undef, $src, {root => '/foo/'});
    ok Encode::is_utf8($dst);
    $dst;
}

__END__

===
--- input
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html>
<head><meta http-equiv="Content-Type" content="text/html; charset=UTF-8" /></head>
<body><a href="/">top</a></body>
</html>
--- expected
<?xml version="1.0" encoding="UTF-8"?><html>
<head><meta http-equiv="Content-Type" content="text/html; charset=UTF-8"></head>
<body><a href="/foo/">top</a></body>
</html>

===
--- input
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN" "http://www.w3.org/TR/REC-html40/loose.dtd">
<html>
<head><meta http-equiv="Content-Type" content="text/html; charset=UTF-8" /></head>
<body><script src="/mobirc.js"></script></body>
</html>
--- expected
<?xml version="1.0" encoding="UTF-8"?><html>
<head><meta http-equiv="Content-Type" content="text/html; charset=UTF-8"></head>
<body><script src="/foo/mobirc.js"></script></body>
</html>

===
--- input
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN" "http://www.w3.org/TR/REC-html40/loose.dtd">
<html>
<head><meta http-equiv="Content-Type" content="text/html; charset=UTF-8" /></head>
<body><link rel="stylesheet" href="/style.css" type="text/css"></body>
</html>
--- expected
<?xml version="1.0" encoding="UTF-8"?><html>
<head><meta http-equiv="Content-Type" content="text/html; charset=UTF-8"></head>
<body><link rel="stylesheet" href="/foo/style.css" type="text/css"></body>
</html>

===
--- input
<?xml version="1.0" encoding="UTF-8"?>
<html lang="ja" xml:lang="ja" xmlns="http://www.w3.org/1999/xhtml">
<head>
<title>foobar</title>
<body></body>
</html>
--- expected
<?xml version="1.0" encoding="UTF-8"?><html lang="ja" xml:lang="ja" xmlns="http://www.w3.org/1999/xhtml">
<head><title>foobar</title></head>
<body></body>
</html>
