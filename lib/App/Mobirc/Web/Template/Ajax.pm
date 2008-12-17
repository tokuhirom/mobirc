package App::Mobirc::Web::Template::Ajax;
use App::Mobirc::Web::Template;
use Params::Validate ':all';
use App::Mobirc;

sub base {
    my $self = shift;

    mt_cached(<<'...');
<?= xml_header() ?>
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
        <script src="/static/jquery.js" type="text/javascript"></script>
        <script src="/static/mobirc.js" type="text/javascript"></script>
? if (is_iphone) {
        <meta name="viewport" content="width=device-width" />
        <meta name="viewport" content="initial-scale=1.0, user-scalable=yes" />
? }
    </head>
    <body>
        <div id="body">
            <div id="main">
                <div id="menu"></div>
                <div id="contents"></div>
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
...
}

sub menu {
    my $class = shift;

    mt_cached(<<'...');
<div>
    <?= include('Ajax', '_keyword_channel') ?>
    <?= include('Ajax', '_channel_list') ?>
</div>
...
}

sub _keyword_channel {
    my $class = shift;

    mt_cached(<<'...');
? my $keyword_recent_num = server->keyword_channel->unread_lines;
? if ($keyword_recent_num > 0) {
    <div class="keyword_recent_notice">
        <a href="#">Keyword(<?= $keyword_recent_num ?>)</a>
    </div>
? }
...
}

sub _channel_list {
    my $class = shift;

    mt_cached(<<'...');
? for my $channel ( server()->channels ) {
?     my $class = $channel->unread_lines ? 'unread channel' : 'channel';
      <div class="<?= $class ?>">
        <a href="#"><?= $channel->name ?></a>
      </div>
? }
...
}

sub keyword {
    mt_cached(<<'...');
<div>
?   for my $row ( server->keyword_channel->message_log ) {
        <?= include('Parts', 'keyword_line', $row) ?>
?   }
</div>
...
}

sub channel {
    my ($class, $channel) = @_;
    mt_cached(<<'...', $channel);
? my $channel = shift;
<div>
?   for my $message ($channel->message_log) {
        <?= render_irc_message($message) ?>
        <br />
?   }
</div>
...
}

1;
