? wrap {

<h1 class="title"><img src="/static/logo.gif" alt="mobirc" width="164" height="51" /></h1>

<div class="TopMenu">
    <ul>
        <? for (qw/mobile ajax iphone iphone2/) { ?>
            <li><a href="/<?= $_ ?>/"><?= $_ ?></a></li>
        <? } ?>
    </ul>
    <form method="post" action="/account/logout">
        <input type="submit" value="logout" />
    </form>
</div>
<hr />

? };
