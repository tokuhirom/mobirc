<!doctype html>
<html xmlns="http://www.w3.org/1999/xhtml">
    <head>
        <meta http-equiv="Content-Type"  content="text/html; charset=UTF-8" />
        <meta http-equiv="Cache-Control" content="max-age=0" />
        <meta http-equiv="content-script-type" content="text/javascript" />
        <meta name="robots" content="noindex,nofollow" />
        <meta name="viewport" content="initial-scale=1.0, maximum-scale=1.0, user-scalable=no" />
        <title>mobirc</title>
        <script src="/static/js/jquery-1.7.2.min.js" type="text/javascript"></script>
        <link rel="stylesheet" type="text/css" media="screen" href="/static/jqtouch/jqtouch.min.css" />
        <link rel="stylesheet" type="text/css" media="screen" href="/static/jqtouch/themes/jqt/theme.css" />
        <link rel="stylesheet" type="text/css" media="screen" href="/static/iphone2.css" />
        <script src="/static/iphone2.js" type="text/javascript" charset="utf-8"></script>
        <style type="text/css" media="screen">
            body.fullscreen #home .info {
                display: none;
            }
        </style>
    </head>
    <body>
        <div id="menu">
            <div>
                <?= $_[0] ?>
                <footer>
                    mobirc <?= $App::Mobirc::VERSION ?> by tokuhirom.
                </footer>
            </div>
        </div>

        <?# TODO: move this part to Plugin::DocRoot ?>
        <script type="text/javascript">
            docroot='<?= docroot() ?>';
        </script>
    </body>
</html>
