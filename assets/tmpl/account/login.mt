? wrap {

<h1 class="title"><img src="/static/logo.gif" alt="mobirc" /></h1>

<? for my $key (qw/password/) {       ?>
<?    if (param("invalid_${key}")) { ?>
        <div style='color: red'>invalid <?= $key ?></div>
<?    }                                             ?>
<? }                                                ?>

<form action="/account/login_password" method="post">
    <input type='password' name='password' /><br />
    <input type='submit'   value='login' />
    <input type='hidden'   name='return' value='<?= param('return') || '' ?>' />
</form>

? }
