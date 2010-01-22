use t::Utils;
use utf8;
use App::Mobirc;
use Encode;
use Test::Base;

my $global_context = global_context();
$global_context->load_plugin( {module => 'DocRoot', config => {root => '/foo/'}} );

filters {
    input    => [qw/convert strip_spaces/],
    expected => [qw/strip_spaces/],
};

sub convert {
    my $html = shift;
    ok Encode::is_utf8($html);
    test_he_filter {
        my $req = shift;
        ($req, $html, ) = global_context->run_hook_filter( 'html_filter', $req, $html );
    };
    ok Encode::is_utf8($html);
    $html;
}

sub strip_spaces {
    s/\n\s*//g;
    s/\n//g;
}

run_is input => 'expected';

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
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html>
    <head>
        <meta content="text/html; charset=UTF-8" http-equiv="Content-Type" />
    </head>
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
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN" "http://www.w3.org/TR/REC-html40/loose.dtd">
<html>
    <head>
        <meta content="text/html; charset=UTF-8" http-equiv="Content-Type" />
    </head>
    <body>
        <script src="/foo/mobirc.js"></script>
    </body>
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
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN" "http://www.w3.org/TR/REC-html40/loose.dtd">
<html>
    <head>
        <meta content="text/html; charset=UTF-8" http-equiv="Content-Type" />
        <link href="/foo/style.css" rel="stylesheet" type="text/css" />
    </head>
    <body>
    </body>
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
<html lang="ja" xml:lang="ja" xmlns="http://www.w3.org/1999/xhtml">
    <head>
        <title>foobar</title>
    </head>
    <body>
    </body>
</html>
