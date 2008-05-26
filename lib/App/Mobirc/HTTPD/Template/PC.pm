package App::Mobirc::HTTPD::Template::PC;
use strict;
use warnings;
use base qw(Template::Declare);
use Template::Declare::Tags;
use Params::Validate ':all';
use HTML::Entities qw/encode_entities/;

template 'pc_menu' => sub {
    my ($self, $server, $keyword_recent_num) = validate_pos(@_, OBJECT, { isa => 'App::Mobirc::Model::Server' }, SCALAR);

    div {
        if ($keyword_recent_num > 0) {
            div { attr { class => 'keyword_recent_notice' }
                a { attr { href => '#' }
                    "Keyword($keyword_recent_num)"
                }
            };
        }

        for my $channel ( $server->channels ) {
            my $class = $channel->unread_lines ? 'unread channel' : 'channel';
            div { attr { class => $class }
                a { attr { 'href' => '#' }
                    $channel->name
                }
            }
        }
    };
};

1;
