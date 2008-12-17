?= xml_header();
<html xmlns="http://www.w3.org/1999/xhtml">
    <head>
        <meta http-equiv="Content-Type"  content="text/html; charset=UTF-8" />
        <meta http-equiv="Cache-Control" content="max-age=0" />
        <meta http-equiv="content-script-type" content="text/javascript" />
        <meta name="robots" content="noindex,nofollow" />
        <link rel="stylesheet" href="/static/mobirc.css" type="text/css" />
        <link rel="stylesheet" href="/static/mobile-ajax.css" type="text/css" />
        <title>mobirc</title>
        <meta name="viewport" content="initial-scale=1.0, maximum-scale=1.0, user-scalable=yes" />
        <style type="text/css">
            <?= encoded_string(load_assets('static', 'mobile-ajax.css')) ?>
        </style>
    </head>
    <body>
        <textarea id="stylesheet" style="display: none"><?= encoded_string(load_assets('static', 'mobile-ajax.css')) ?></textarea>
        <h1><select id="channel" onchange="Mobirc.onChangeChannel();">
? for my $channel ( server->channels ) {
            <option value="<?= $channel->name ?>"><?= $channel->name ?></option>
? }
        </select></h1>

        <div id="channel-iframe-container" class="iframe-container">&nbsp;</div>

        <form onsubmit="return Mobirc.onSubmit()" action="/mobile-ajax/channel" method="post">
            <input type="text" id="msg" name="msg" <?= is_iphone() ? 'size="30"' : '' ?> />
            <input type="submit" accesskey="1" value="OK[1]" />
        </form>

        <div id="recentlog-iframe-container" class="iframe-container">&nbsp;</div>

        <p style="border-top: 1px solid black">
            # <a href="/mobile/topics" accesskey="#">topics</a>
            |
            * <a href="/mobile/topics" accesskey="*">keyword</a>
        </p>

        <div class="VersionInfo">
            mobirc - <span class="version"><?= $App::Mobirc::VERSION ?></span>
        </div>

        <div id="jsonp-container">&nbsp;</div>
        <div id="submit-iframe-container" style="_isplay: none">&nbsp;</div>

?       # TODO: move this part to Plugin::DocRoot
        <script type="text/javascript">
            ___docroot = '<?= docroot() ?>';
        </script>

        <script type="text/javascript">
            <?= encoded_string(load_assets('static', 'mobile-ajax.js')) ?>
        </script>
