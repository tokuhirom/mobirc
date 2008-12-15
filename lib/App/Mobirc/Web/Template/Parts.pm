package App::Mobirc::Web::Template::Parts;
use strict;
use warnings;
use base qw(Template::Declare);
use Template::Declare::Tags;

template 'keyword_line' => sub {
    my ($self, $row, $irc_nick) = @_;
    show 'irc_message', $row, $irc_nick;
    outs '(';
        a { attr { 'href' => '/mobile/channel?channel=' . $row->channel->name_urlsafe_encoded }
            $row->channel->name
        };
    outs ')';
    br { };
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
