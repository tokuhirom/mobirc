package App::Mobirc::Web::Template::Parts;
use App::Mobirc::Web::Template;

sub keyword_line {
    my ($class, $row) = @_;
    render_irc_message($row)->as_string . mt_cached(<<'...', $row->channel);
? my $channel = $row->channel
(
    <a href="/mobile/channel?channel=<?= $channel->name_urlsafe_encoded ?>">
        <?= $channel->name ?>
    </a>
)
<br />
...
}

1;
