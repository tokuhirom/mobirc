package App::Mobirc::Web::Template::Wrapper;
use App::Mobirc::Web::Template;

sub wrapper {
    my ($class, $body) = @_;
    Carp::croak "missing body" unless $body;

    mt_cached(<<"...")
?= xml_header()
<html xmlns="http://www.w3.org/1999/xhtml">
    <head>
        <meta http-equiv="Content-Type"  content="text/html; charset=UTF-8" />
        <meta http-equiv="Cache-Control" content="max-age=0" />
        <meta name="robots" content="noindex,nofollow" />
        <link rel="stylesheet" href="/static/mobirc.css" type="text/css" />
        <link rel="stylesheet" href="/static/mobile.css" type="text/css" />
        <title>mobirc</title>
? if (is_iphone) {
        <meta name="viewport" content="width=device-width" />
        <meta name="viewport" content="initial-scale=1.0, user-scalable=yes" />
? }
    </head>
    <body>
        <a name="top"></a>
$body
    </body>
</html>
...
}

1;

