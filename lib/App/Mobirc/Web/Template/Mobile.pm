package App::Mobirc::Web::Template::Mobile;
use App::Mobirc::Web::Template;
use Params::Validate ':all';
use Text::MicroTemplate qw/encoded_string/;
use App::Mobirc::Pictogram qw/pictogram/;

sub topics {
    my $class = shift;
    my %args = validate(
        @_ => {
            channels     => 1,
        }
    );
    mt_cached_with_wrap(<<'...', $args{channels});
? my $channels = shift;
? for my $channel (@{$channels}) {
    <div class="OneTopic">
        <a href="/mobile/channel?channel=<?= $channel->name_urlsafe_encoded ?>"><?= $channel->name ?></a><br />
        <span><?= $channel->topic ?></span><br />
    </div>
? }
...
}

sub keyword {
    my $self = shift;
    my %args = validate(
        @_ => {
            rows         => 1,
        }
    );

    mt_cached_with_wrap(<<'...', $args{rows}, _go_to_top());
? my ($rows, $footer) = @_;
<div class="ttlLv1">keyword</div>
? for my $row (@$rows) {
    <?= encoded_string App::Mobirc::Web::Template::Parts->keyword_line( $row ) ?>
? }

<?= $footer ?>
...
}

sub top {
    my $self = shift;
    my %args = validate(
        @_ => {
            exists_recent_entries => 1,
            keyword_recent_num    => 1,
            channels              => 1,
        }
    );

    mt_cached_with_wrap(<<'...', $args{exists_recent_entries}, $args{keyword_recent_num}, $args{channels});
? my ($exists_recent_entries, $keyword_recent_num, $channels) = @_

? if ($keyword_recent_num) {
    <div class="keyword_recent_notice">
        <a href="/mobile/keyword?recent_mode=on">Keyword(<?= $keyword_recent_num ?>)</a>
    </div>
? }

? for my $channel (@$channels) {
    <?= pictogram('(^-^)') ?>
    <a href="/mobile/channel?channel=<?= $channel->name_urlsafe_encoded ?>"><?= $channel->name ?></a>
    <? if ($channel->unread_lines) { ?>
        <a href="/mobile/channel?recent_mode=on&channel=<?= $channel->name_urlsafe_encoded ?>">
            <?= $channel->unread_lines ?>
        </a>
    <? }                             ?>
    <br />
? }

<hr />

<?= pictogram('0') ?><a href="/mobile/#top" accesskey="0">refresh list</a><br />
? if ($exists_recent_entries) {
    <span>*</span><a href="/mobile/recent" accesskey="*">recent</a><br />
? }
<? # TODO: use pictogram for '#' & '*' ?>
<span>#</span><a href="/mobile/topics" accesskey="#">topics</a><br />
<span>!</span><a href="/mobile/keyword" accesskey="!">keyword</a><br />
<span><?= pictogram('9') ?></span><a href="/mobile/clear_all_unread" accesskey="9">clear_all_unread</a><br />

<hr />

App::Mobirc <?= $App::Mobirc::VERSION ?>
...
}

sub recent {
    my $class = shift;
    my %args = validate(
        @_ => {
            channels      => 1,
            has_next_page => 1,
        }
    );

    mt_cached_with_wrap(<<'...', $args{channels}, $args{has_next_page}, _go_to_top());
? my ($channels, $has_next_page, $go_to_top) = @_;
? for my $channel (@$channels) {
    <div class="ChannelHeader">
        <a class="ChannelName"><?= $channel->name ?></a>
        <a href="/mobile/channel?channel=<?= $channel->name_urlsafe_encoded ?>">more...</a>
    </div>
?    for my $message (@{$channel->recent_log}) {
        <?= render_irc_message($message) ?>
        <br />
?    }
    <hr />
? }

? if ($has_next_page) {
    <?= pictogram(6) ?><a href="/mobile/recent" accesskey="6">next</a>
? }

<hr />

<?= $go_to_top ?>
...
}

sub _go_to_top {
    my $pict = pictogram('8');
    encoded_string qq{
        <div class="GoToTop">
            $pict <a accesskey="8" href="/mobile/">ch list</a>
        </div>
    };
}

sub channel {
    my $self = shift;
    my %args = validate(
        @_ => {
            channel             => 1,
            channel_page_option => 1,
            recent_mode         => 1,
            message             => 1,
        }
    );
    my $channel = $args{channel};

    # TODO: we need include() syntax in T::MT
    mt_cached_with_wrap(<<'...', $args{channel}, $args{message}, $args{channel_page_option}, $args{recent_mode}, _go_to_top());
? my ($channel, $message, $channel_page_option, $recent_mode, $go_to_top) = @_
    <form action='/mobile/channel?channel=<?= $channel->name_urlsafe_encoded?>' method='post'>
        <input <? if ($message) { ?>value="<?= $message ?><? } ?>
               type="text" name="msg" size="10" />
        <input type="submit" accesskey="1" value="OK" />
    </form>

? for my $html (@$channel_page_option) {
    <?= $html ?>
? }

? if ($channel) {
?    if (@{$channel->message_log}) {
?       my $meth = $recent_mode ? 'recent_log' : 'message_log';
?       for my $message (reverse $channel->$meth) {
            <?= render_irc_message($message) ?>
            <br />
?       }
?       unless ($recent_mode) {
            <hr />
            <?= pictogram('5') ?><a href="/mobile/channel?channel=<?= $channel->name_urlsafe_encoded ?>" accesskey="5">more</a>
?       }
?    } else {
        <p>no message here</p>
?    }
? } else {
    <p>no such channel.</p>
? }

<hr />

<?= $go_to_top ?>
...
}

1;
