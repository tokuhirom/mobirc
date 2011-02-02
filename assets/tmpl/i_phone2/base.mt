<!doctype html>
<html>
    <head>
        <meta charset="utf-8">
        <meta http-equiv="Cache-Control" content="max-age=0" />
        <meta http-equiv="content-script-type" content="text/javascript" />
        <meta name="robots" content="noindex,nofollow" />
        <meta name="viewport" content="initial-scale=1.0, maximum-scale=1.0, user-scalable=yes" />
        <title>mobirc</title>
        <link rel="stylesheet" href="/static/jquery.mobile-1.0a1.min.css" />
        <link rel="stylesheet" href="/static/iphon2.css" />
        <script src="/static/jquery-1.5.min.js" type="text/javascript"></script>
        <script src="/static/jquery.mobile-1.0a2.min.js" type="application/x-javascript" charset="utf-8"></script>
        <script src="/static/iphone2.js" type="application/x-javascript" charset="utf-8"></script>
    </head>
    <body>
        <!-- This view only supports latest webkit, especially iPhone -->

        <div data-role="page" id="index">
            <div data-role="header">
                <h1>Menu</h1>
                <a href="#about" class="ui-btn-right ui-btn ui-btn-icon-right ui-btn-corner-all ui-shadow ui-btn-down-b ui-btn-up-b" data-theme="b"><span class="ui-btn-inner ui-btn-corner-all"><span class="ui-btn-text">about</span></span></a>
            </div>
            <div data-role="content">
                <a id="RefreshChannelListButton" href="#" data-role="button" data-icon="refresh" data-inline="true">refresh</a>
                <a href="#" data-role="button" data-icon="delete" data-inline="true">clear</a>
                <ul data-role="listview" data-inset="true" data-theme="c" data-dividertheme="b" id="ChannelList">
                    <li data-role="list-divider">Channels</li> 
                    <!-- channel list here -->
                </ul> 
            </div>
        </div>

        <div data-role="page" id="about">
            <div data-role="header">
                <h1>about mobirc</h1>
            </div>
            <div data-role="content">
                <span>mobirc version </span><span class="version"><?= $App::Mobirc::VERSION ?></span><br />
                Maintained by tokuhirom<br />
            </div>
        </div>

        <div data-role="page" id="channel">
            <div data-role="header">
                <h1 id="ChannelName" class="ChannelName">channel name here</h1>
            </div>
            <div data-role="content">
                <form action="<?= docroot() ?>api/send_msg" method="post" id="ChannelForm">
                    <input type="hidden" name="channel" value="" id="ChannelNameHidden" />
                    <input type="text" name="msg" data-inline="true" />
                    <input data-role="button" type="submit" value="post" data-inline="true" />
                </form>
                <div id="channel_log">&nbsp;</div>
            </div>
        </div>

        <script type="text/html" id="tmpl_channel_log">
            <div class="message <%= class %> <%= is_new ? 'new' : '' %>">
                <span class="time"><%= hour  %>:<%= minute %></span>

                <% if (who) { %>
                    <span class="who <%= who_class %>">
                    <%= who %>
                    </span>
                <% } %>

                <span class="body">
                    <%= html_body %>
                </span>
            </div>
        </script>

        <?# TODO: move this part to Plugin::DocRoot ?>
        <script type="text/javascript">
            docroot='<?= docroot() ?>';
        </script>
    </body>
</html>
