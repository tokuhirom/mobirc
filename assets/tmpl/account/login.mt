? wrap {

<? for my $key (qw/password/) {       ?>
<?    if (param("invalid_${key}")) { ?>
        <div style='color: red'>invalid <?= $key ?></div>
<?    }                                             ?>
<? }                                                ?>

<h1>login</h1>
<form action="/account/login_password" method="post">
    <input type='password' name='password' />
    <input type='submit'   value='login' />
    <input type='hidden'   name='return' value='<?= param('return') ?>' />
</form>

? }
