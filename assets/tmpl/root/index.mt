? wrap {

<h1>mobirc</h1>
<div class="TopMenu">
    <ul>
        <? for (qw/mobile ajax mobile-ajax iphone/) { ?>
            <li><a href="/<?= $_ ?>/"><?= $_ ?></a></li>
        <? } ?>
    </ul>
    <form method="post" action="/account/logout">
        <input type="submit" value="logout" />
    </form>
</div>
<hr />
<div class="footer">
    <a href="http://coderepos.org/share/wiki/mobirc">mobirc</a>
</div>

? };
