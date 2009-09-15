<!DOCTYPE html>
? use Text::VisualWidth::UTF8;
<html>
    <head>
        <meta http-equiv="Content-Type"  content="text/html; charset=UTF-8" />
        <meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate" />
        <meta http-equiv="Pragma" content="no-cache" />

        <meta name="robots" content="noindex,nofollow" />
        <meta name="viewport" content="initial-scale=1.0, maximum-scale=1.0, user-scalable=no" />
        <script src="/static/jquery.js" type="text/javascript"></script>
        <link rel="stylesheet" href="/static/android.css" type="text/css" />
        <title>Mobirc</title>
    </head>
    <body>
        <div id="content">
            <ol class="channels">
                <? my $favorites = ' ' . join(' ', split /\s*,\s*/, lc config->{global}->{favorites}) . ' '; ?>
                <? my $channels  = [ sort { -($favorites =~ quotemeta(lc $a->name)) <=> -($favorites =~ quotemeta(lc $b->name)) } server->channels_sorted ];

                <? my $i = 0; for my $channel (@$channels) { next if (!$channel->name || !param('all') && !$channel->unread_lines && $i > 10); ?>
                <li class="<?= $i % 2 ? 'even' : 'odd' ?>">
                    <a class='channel' href="/android/channel?channel=<?= $channel->name_urlsafe_encoded ?>">
                        <?= Text::VisualWidth::UTF8::width($channel->name) > 23 ? decode_utf8(Text::VisualWidth::UTF8::trim($channel->name, 22)) . '…': $channel->name?>
                        <span class='unread'><?= $channel->unread_lines ?></span>
                    </a>
                </li>
                <? $i++ } ?>

                <? if (!param('all')) { ?>
                <li class="<?= $i++ % 2 ? 'even' : 'odd' ?>">
                    <a class='channel' href="/android/?all=1">
                        More…
                    </a>
                </li>
                <? } else { ?>
                <li class="<?= $i++ % 2 ? 'even' : 'odd' ?>">
                    <a class='channel' href="/android/clear_all_unread">
                        Clear All Unread
                    </a>
                </li>
                <? } ?>

                <li class="<?= $i++ % 2 ? 'even' : 'odd' ?>">
                    <a class='channel' href="/android/">
                        Reload
                    </a>
                </li>
            </ol>
        </div>
        <script type="text/javascript">
            var docroot = '<?= docroot() ?>';
        </script>
        <script src="/static/android.js" type="text/javascript"></script>
    </body>
</html>
