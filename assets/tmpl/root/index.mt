? wrap {

<h1>mobirc</h1>
<div class="TopMenu">
    <ul>
        <? for (qw/mobile ajax mobile-ajax iphone android iphone2/) { ?>
            <li><a href="/<?= $_ ?>/"><?= $_ ?></a></li>
        <? } ?>
    </ul>
    <form method="post" action="/account/logout">
        <input type="submit" value="logout" />
    </form>
</div>
<hr />

? };
