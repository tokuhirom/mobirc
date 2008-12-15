package App::Mobirc::Web::Template::Root;
use App::Mobirc::Web::Template;

sub index {
    my $class = shift;

    mt_cached_with_wrap(<<'...');
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
...
}

1;
