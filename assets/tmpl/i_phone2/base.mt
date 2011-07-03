?= xml_header()
<html xmlns="http://www.w3.org/1999/xhtml">
    <head>
        <meta http-equiv="Content-Type"  content="text/html; charset=UTF-8" />
        <meta http-equiv="Cache-Control" content="max-age=0" />
        <meta http-equiv="content-script-type" content="text/javascript" />
        <meta name="robots" content="noindex,nofollow" />
        <meta name="viewport" content="initial-scale=1.0, maximum-scale=1.0, user-scalable=no" />
        <title>mobirc</title>
        <script src="/static/js/jquery-1.6.1.min.js" type="text/javascript"></script>
        <link rel="stylesheet" type="text/css" media="screen" href="/static/jqtouch/jqtouch.min.css" />
        <link rel="stylesheet" type="text/css" media="screen" href="/static/jqtouch/themes/jqt/theme.css" />
        <link rel="stylesheet" type="text/css" media="screen" href="/static/iphone2.css" />
        <script src="/static/jquery.form.js" type="text/javascript" charset="utf-8"></script>
        <script src="/static/js/jquery.tmpl.min.js" type="text/javascript" charset="utf-8"></script>
        <script src="/static/iphone2.js" type="text/javascript" charset="utf-8"></script>
        <style type="text/css" media="screen">
            body.fullscreen #home .info {
                display: none;
            }
        </style>
    </head>
    <body>
        <div id="menu">
            <div class="toolbar">
                <h1>mobirc</h1>
                <a class="button slideup" href="#about">About</a>
            </div>
            <div>
                <div id="MiscMenuContainer">
                    <input type="button" id="RefreshMenu" value="refresh" />
                    <input type="button" id="ClearAllUnread" value="clear all unread" />
                </div>
                <div id="ChannelList">
                    Now Loading...
                </div>
            </div>
        </div>

        <script id="ChannelListTmpl" type="jquery/template">
            <ul>
                {{each channels}}
                <li class="arrow channel">
                    <a href="#">{{html $value.name }}</a>
                    {{if $value.unread_lines}}
                        <small class="counter">${$value.unread_lines}</small>
                    {{/if}}
                </li>
                {{/each}}
            </ul>
        </script>

        <div id="contents">
        </div>

        <div id="about" style="display:none">
            <div class="toolbar">
                <h1>about mobirc</h1>
                <a class="button slideup" href="#menu">Menu</a>
            </div>
            <span>mobirc version </span><span class="version"><?= $App::Mobirc::VERSION ?></span><br />
            Maintained by tokuhirom<br />
        </div>

        <div style="display:none" id="loading">
            <img class="ui-icon-loading" src="/static/ajax-loader.png" width="40" height="40" />
        </div>

        <?# TODO: move this part to Plugin::DocRoot ?>
        <script type="text/javascript">
            docroot='<?= docroot() ?>';
        </script>
    </body>
</html>
