? my ($channel, $channel_page_option) = @_
<html>
    <head>
        <meta http-equiv="Content-Type"  content="text/html; charset=UTF-8" />
        <meta http-equiv="Cache-Control" content="max-age=0" />
        <meta name="robots" content="noindex,nofollow" />
        <meta name="viewport" content="initial-scale=1.0, maximum-scale=1.0, user-scalable=no" />
        <script src="/static/jquery.js" type="text/javascript"></script>
        <!--
        <script type="text/javascript" src="http://s.hatena.ne.jp/js/HatenaStar.js"></script>
        -->
        <script type="text/javascript" src="http://cho45.stfuawsc.com/jsdeferred/jsdeferred.mini.js"></script>
        <script type="text/javascript" src="/static/HatenaStar4Android.js"></script>

        <script type="text/javascript">
        // <![CDATA[
            Hatena.Star.SiteConfig = {
              entryNodes: {
                'div.message': {
                    uri       : 'a.uri',
                    title     : 'div.body',
                    container : 'span.who'
                }
              }
            };
        // ]]>
        </script>
        
        <link rel="stylesheet" href="/static/android.css" type="text/css" />
        <title><?= $channel->name ?></title>
    </head>
    <body>
        <div id="content">
            <? my $message     = param('msg') || ''; ?>
            <? my $page        = param('page') || 1; ?>

            <form action='/android/channel?channel=<?= $channel->name_urlsafe_encoded?>' method='post' id="input">
                <div class="input">
                    <input value="<?= $message ?>" type="text" name="msg" size="10" class="text" />
                </div>
            </form>

            <? my $recent_mode = param('recent_mode'); ?>
            <? if ($channel) { ?>
            <?    if (@{$channel->message_log}) { ?>
            <?       my $meth = $recent_mode ? 'recent_log' : 'message_log'; ?>
            <?       my $log  = [ reverse $channel->$meth  ] ?>
            <?       my $i = 0; for my $message (splice @$log, ($page - 1) * 10, 10) { ?>
            <div class="message <?= $message->class ?>">
                <span class="time">
                    <? if (my ($id) = $message->body =~ m{\[([a-z]+)\]}) { ?>
                    <select class="operations">
                        <option selected="selected" value="">♥♣</option>
                        <option value="/me fav <?= $id ?>">fav</option>
                    </select>
                    <? } ?>

                    <?= sprintf "%02d:%02d", $message->hour, $message->minute ?></span>
                </span>

                <? if ($message->who) { ?>
                <span class="who <?= $message->who_class ?>" onclick="document.getElementById('foo').click()">
                    <?= $message->who ?>

                    <? if ($message->{metadata} && $message->{metadata}->{uri}) { ?>
                        <a href="<?= $message->{metadata}->{uri} ?>" class="uri">URI</a>
                    <? } ?>

                </span>
                <? } ?>

                <div class="body">
                    <?= encoded_string($message->html_body) ?>
                </div>
            </div>
            <?       $i++ } ?>
            <?       if ($recent_mode) { ?>
            <div class="more">
                <a href="/android/channel?channel=<?= $channel->name_urlsafe_encoded ?>">More…</a>
            </div>
            <?       } else { ?>
            <div class="<?= $i++ % 2 ? 'even' : 'odd' ?>">
                <a class='channel' href="/android/channel?channel=<?= $channel->name_urlsafe_encoded ?>;page=<?= $page + 1 ?>">
                    More…
                </a>
            </div>
            <?       } ?>
            <?    } else { ?>
            <p>No message here.</p>
            <?    } ?>
            <? } else { ?>
            <p>No such channel.</p>
            <? } ?>
        </div>
        <script type="text/javascript">
            var docroot = '<?= docroot() ?>';
        </script>
        <script src="/static/android.js" type="text/javascript"></script>
    </body>
</html>
