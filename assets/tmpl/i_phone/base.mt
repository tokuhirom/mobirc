?= xml_header()
<html xmlns="http://www.w3.org/1999/xhtml">
    <head>
        <meta http-equiv="Content-Type"  content="text/html; charset=UTF-8" />
        <meta http-equiv="Cache-Control" content="max-age=0" />
        <meta http-equiv="content-script-type" content="text/javascript" />
        <meta name="robots" content="noindex,nofollow" />
        <meta name="viewport" content="initial-scale=1.0, maximum-scale=1.0, user-scalable=yes" />
        <link rel="stylesheet" href="/static/mobirc.css" type="text/css" />
        <link rel="stylesheet" href="/static/iphone.css" type="text/css" />
        <title>mobirc</title>
        <script src="/static/jquery.js" type="text/javascript"></script>
        <script src="/static/iphone.js" type="text/javascript"></script>
    </head>
    <body>
        <div id="body">
            <div id="main">
                <div id="menu"></div>
                <form onsubmit="return false">
                    <textarea id="msg" name="msg" onfocus="clearInterval(load_menu_timer);clearInterval(load_url_timer);" onblur="lmt();lut();"></textarea>
                    <input type="button" value="send" onclick="send_message()" />
                </form>
                <div id="contents"></div>
            </div>
            <div id="footer">
                <div><span>mobirc - </span><span class="version"><?= $App::Mobirc::VERSION ?></span></div>
            </div>
        </div>

        <?# TODO: move this part to Plugin::DocRoot ?>
        <script type="text/javascript">
            docroot='<?= docroot() ?>';
        </script>
    </body>
</html>
