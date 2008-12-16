package App::Mobirc::Web::Template::Parts;
use strict;
use warnings;
use base qw(Template::Declare);
use Template::Declare::Tags;
use App::Mobirc::Web::Template;

sub keyword_line {
    my ($class, $row) = @_;
    App::Mobirc::Web::View->show('irc_message', $row) . mt_cached(<<'...', $row->channel);
? my $channel = $row->channel
(
    <a href="/mobile/channel?channel=<?= $channel->name_urlsafe_encoded ?>">
        <?= $channel->name ?>
    </a>
)
<br />
...
}

template 'keyword_line' => sub {
    my ($self, $row) = @_;
    outs_raw($self->keyword_line($row));
};

template 'parts/version_info' => sub {
    div {
        class is 'VersionInfo';
        span { 'mobirc - ' };
        span {
            class is 'version';
            $App::Mobirc::VERSION;
        }
    }
};

1;
