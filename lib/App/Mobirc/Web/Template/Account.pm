package App::Mobirc::Web::Template::Account;
use App::Mobirc::Web::Template;

sub login {
    mt_cached(<<'...');
? require_wrap()

<? for my $key (qw/password cidr mobileid/) {       ?>
<?    if (param("invalid_${key}")) { ?>
        <div style='color: red'>invalid <?= $key ?></div>
<?    }                                             ?>
<? }                                                ?>

<h1>login with mobile id</h1>
<form action="/account/login_mobileid?guid=ON" method="post">
    <input type="submit" value="login" />
</form>

<h1>login with password</h1>
<form action="/account/login_password" method="post">
    <input type='password' name='password' />
    <input type='submit'   value='login' />
</form>
...
}

1;

