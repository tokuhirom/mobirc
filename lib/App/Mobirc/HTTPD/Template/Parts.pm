package App::Mobirc::HTTPD::Template::Parts;
use strict;
use warnings;
use base qw(Template::Declare);
use Template::Declare::Tags;
use Params::Validate ':all';
use List::Util qw/first/;
use HTML::Entities qw/encode_entities/;
use URI::Escape qw/uri_escape/;

template 'keyword_line' => sub {
    my ($self, $row, $irc_nick) = @_;
    show 'irc_message', $row, $irc_nick;
    outs '(';
        a { attr { 'href' => sprintf('/channels/%s', uri_escape( $row->channel->name)) }
            $row->channel->name
        };
    outs ')';
    br { };
};

1;
