?= xml_header()
<html xmlns="http://www.w3.org/1999/xhtml">
    <head>
        <meta http-equiv="Content-Type"  content="text/html; charset=UTF-8" />
        <meta http-equiv="Cache-Control" content="max-age=0" />
        <meta http-equiv="content-script-type" content="text/javascript" />
        <meta name="robots" content="noindex,nofollow" />
        <!-- <meta name="viewport" content="initial-scale=1.0, maximum-scale=1.0, user-scalable=yes" /> -->
        <title>mobirc</title>
        <script src="/static/jquery.js" type="text/javascript"></script>
        <script src="/static/jquery.form.js" type="text/javascript"></script>
        <script src="/static/jqtouch/jqtouch.min.js" type="application/x-javascript" charset="utf-8"></script>
        <link rel="stylesheet" type="text/css" media="screen" href="/static/jqtouch/jqtouch.min.css" />
        <link rel="stylesheet" type="text/css" media="screen" href="/static/jqtouch/themes/jqt/theme.min.css" />
        <link rel="stylesheet" type="text/css" media="screen" href="/static/iphone2.css" />
        <script type="text/javascript">
            $.jQTouch({
                icon: 'jqtouch.png',
                statusBar: 'black-translucent',
                preloadImages: [
                    '/static/jqtouch/themes/jqt/img/chevron.png',
                    '/static/jqtouch/themes/jqt/img/back_button_clicked.png',
                    '/static/jqtouch/themes/jqt/img/button_clicked.png'
                ]
            });

            function ts() { return (new Date()).getTime(); }
            Mobirc = {
                "updateChannelList": function () {
                    $('#contents').hide();
                    $('#menu').load(
                        docroot + 'iphone2/menu?t=' + ts(),
                        '',
                        function () {
                        }
                    );
                },
                "loadContent": function (channel) {
                    $('#contents').load(
                        docroot + 'iphone2/channel?channel=' + encodeURIComponent(channel) + '&t=' + ts(),
                        '',
                        function() {
                            $('#menu').html('');
                            $('#contents').show();
                            $('#input').ajaxForm(function () {
                                Mobirc.loadContent(channel);
                            });
                            var x = ['click', 'tap'];
                            for (i in x) {
                                $('#goMenuButton').bind(x[i], function() {
                                    Mobirc.updateChannelList();
                                    return false;
                                });
                            }
                        }
                    );
                },
                "initialize": function () {
                    var i = function (e) {
                        $('#menu .channel a').live(e, function () {
                            var elem = $(this);
                            Mobirc.loadContent(elem.text());
                            return false;
                        });
                        $('#RefreshMenu').live(e, function() {
                            Mobirc.updateChannelList();
                        });
                        $('#ClearAllUnread').live(e, function() {
                            $.post(
                                '/iphone2/clear_all_unread',
                                '',
                                function () {
                                    Mobirc.updateChannelList();
                                }
                            );
                        });
                        $('#showChannelList').live(e, function() {
                            Mobirc.updateChannelList();
                            return false;
                        });
                    };
                    i('click');
                    i('tap');
                    Mobirc.updateChannelList();
                }
            };
            $(function () {
                Mobirc.initialize();
            });
        </script>
        <style type="text/css" media="screen">
            body.fullscreen #home .info {
                display: none;
            }
        </style>
    </head>
    <body>
        <div id="menu">
            <h1>menu</h1>
            loading menu...<br />
            wait a minute...
        </div>

        <div id="contents">
        </div>

        <div id="about">
            <div class="toolbar">
                <h1>about mobirc</h1>
                <a class="button slideup" id="goMenuButton" href="#menu">Menu</a>
            </div>
            <span>mobirc version </span><span class="version"><?= $App::Mobirc::VERSION ?></span><br />
            Maintained by tokuhirom<br />
        </div>

        <?# TODO: move this part to Plugin::DocRoot ?>
        <script type="text/javascript">
            docroot='<?= docroot() ?>';
        </script>
    </body>
</html>
