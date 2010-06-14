?= xml_header()
<html xmlns="http://www.w3.org/1999/xhtml">
    <head>
        <meta http-equiv="Content-Type"  content="text/html; charset=UTF-8" />
        <meta http-equiv="Cache-Control" content="max-age=0" />
        <meta http-equiv="content-script-type" content="text/javascript" />
        <meta name="robots" content="noindex,nofollow" />
        <meta name="viewport" content="initial-scale=1.0, maximum-scale=1.0, user-scalable=yes" />
        <link rel="stylesheet" href="/static/pc.css" type="text/css" />
        <link rel="stylesheet" href="/static/mobirc.css" type="text/css" />
        <title>mobirc</title>
        <link type="text/css" href="/static/css/ui-lightness/jquery-ui-1.8.2.custom.css" rel="stylesheet" />
        <script type="text/javascript" src="/static/js/jquery-1.4.2.min.js"></script>
        <script type="text/javascript" src="/static/js/jquery-ui-1.8.2.custom.min.js"></script>
        <script src="/static/mobirc.js" type="text/javascript"></script>
? if (is_iphone) {
        <meta name="viewport" content="width=device-width" />
        <meta name="viewport" content="initial-scale=1.0, user-scalable=yes" />
? }
    </head>
    <body>
        <div id="body">
            <div id="main">
                <div id="contents"></div>
                <div id="menu"></div>
            </div>
            <div id="footer">
                <form onsubmit="send_message(); return false;">
                    <input type="text" id="msg" name="msg" size="30" />
                    <input type="button" value="send" onclick="send_message()" />
                </form>
                <div><span>mobirc - </span><span class="version"><?= $App::Mobirc::VERSION ?></span></div>
            </div>
        </div>

?       # TODO: move this part to Plugin::DocRoot
        <script lang="javascript">
            docroot='<?= docroot() ?>';
        </script>
    </body>
</html>
