<!DOCTYPE html>
? use Text::VisualWidth::UTF8;
<html>
    <head>
        <meta http-equiv="Content-Type"  content="text/html; charset=UTF-8" />
        <meta http-equiv="Cache-Control" content="max-age=0" />
        <meta name="robots" content="noindex,nofollow" />
        <meta name="viewport" content="initial-scale=1.0, maximum-scale=1.0, user-scalable=yes" />
        <script src="/static/jquery.js" type="text/javascript"></script>
        <link rel="stylesheet" href="/static/my-site-style.css" type="text/css" />
        <title>Mobirc</title>
    </head>
    <body>
        <div id="content">
            <ol class="channels">
                <? my $i = 0; for my $channel (server->channels_sorted) { next if (!$channel->unread_lines && $i > 10); ?>
                    <li class="<?= $i % 2 ? 'even' : 'odd' ?>">
                    <a class='channel' href="/my/channel?recent_mode=on&amp;channel=<?= $channel->name_urlsafe_encoded ?>">
                        <?= Text::VisualWidth::UTF8::width($channel->name) > 23 ? decode_utf8(Text::VisualWidth::UTF8::trim($channel->name, 22)) . '…': $channel->name?>
                        <span class='unread'><?= $channel->unread_lines ?></span>
                    </a>
                </li>
                <? $i++ } ?>
            </ol>
        </div>
        <script type="text/javascript">
            var docroot = '<?= docroot() ?>';
        </script>
        <script src="/static/my-site-script.js" type="text/javascript"></script>
    </body>
</html>
