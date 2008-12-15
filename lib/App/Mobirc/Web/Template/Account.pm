package App::Mobirc::Web::Template::Account;
use App::Mobirc::Web::Template;
use Params::Validate ':all';
use Text::MicroTemplate qw/build_mt/;

sub login {
    my $class = shift;
    my %args = validate(
        @_ => {
            mobile_agent => 1,
            req => 1,
        }
    );
    my $encoding = $args{mobile_agent}->can_display_utf8 ? 'UTF-8' : 'Shift_JIS';
    qq{<?xml version="1.0" encoding="$encoding" ?>} . mt_cached(<<'...', $args{req}, $encoding);
? my ($req, $encoding) = @_
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
    <head>
        <meta http-equiv="Content-Type"  content="text/html; charset=<?= $encoding ?>" />
        <meta http-equiv="Cache-Control" content="max-age=0" />
        <meta name="robots" content="noindex,nofollow" />
        <link rel="stylesheet" href="/static/mobirc.css" type="text/css" />
        <link rel="stylesheet" href="/static/mobile.css" type="text/css" />
        <title>login - mobirc</title>
    </head>
    <body>
        <? for my $key (qw/password cidr mobileid/) { ?>
        <?    if ($req->params->{"invalid_${key}"}) { ?>
                <div style='color: red'>invalid <?= $key ?></div>
        <?    }                                       ?>
        <? }                                          ?>
        <h1>login with mobile id</h1>
        <form action="/account/login_mobileid?guid=ON" method="post">
            <input type="submit" value="login" />
        </form>

        <h1>login with password</h1>
        <form action="/account/login_password" method="post">
            <input type='password' name='password' />
            <input type='submit'   value='login' />
        </form>
    </body>
</html>
...
};

1;

