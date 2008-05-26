package App::Mobirc::HTTPD::Controller;
use strict;
use warnings;

use Carp;
use CGI;
use URI;
use Encode;
use Template;
use Path::Class;
use URI::Escape;
use HTTP::Response;
use HTML::Entities;
use Scalar::Util qw/blessed/;
use List::Util qw/first/;
use Template::Provider::Encoding;
use Encode::JP::Mobile 0.24;

use App::Mobirc;
use App::Mobirc::Util;
use App::Mobirc::HTTPD::View;

sub call {
    my ($class, $method, @args) = @_;
    DEBUG "CALL METHOD $method with @args";
    $class->$method(@args);
}

sub server () { App::Mobirc->context->server } ## no critic.

# this module contains MVC's C.

sub dispatch_index {
    my ($class, $c) = @_;

    if ($c->{mobile_agent}->is_non_mobile) {
        return render_td(
            $c,
            'pc_top' => (
                $c->{mobile_agent},
                ($c->{config}->{httpd}->{root} || '/'),
            )
        );
    }

    my $server = server;

    my $channels = [
        reverse
          map {
              $_->[0];
          }
          sort {
              $a->[1] <=> $b->[1] ||
              $a->[2] <=> $b->[2]
          }
          map {
              my $unl  = $_->unread_lines ? 1 : 0;
              my $buf  = $_->message_log || [];
              my $last =
                (grep {
                    $_->{class} eq "public" ||
                    $_->{class} eq "notice"
                } @{ $buf })[-1] || {};
              my $time = ($last->{time} || 0);
              [$_, $unl, $time];
          }
          $server->channels
    ];

    my $keyword_recent_num = $server->get_channel(U '*keyword*')->unread_lines;

    return render(
        $c,
        'index' => {
            exists_recent_entries => (
                grep( $_->unread_lines, $server->channels )
                ? true
                : false
            ),
            keyword_recent_num => $keyword_recent_num,
            channels => $channels,
        }
    );
}

# recent messages on every channel
sub dispatch_recent {
    my ($class, $c) = @_;

    my @target_channels;
    my $log_counter = 0;
    my $has_next_page = false;

    my @unread_channels =
      grep { $_->unread_lines }
      $c->{global_context}->channels;

    DEBUG "SCALAR " . scalar @unread_channels;

    for my $channel (@unread_channels) {
        push @target_channels, $channel;
        $log_counter += scalar @{ $channel->recent_log };

        if ($log_counter >= $c->{config}->{httpd}->{recent_log_per_page}) {
            $has_next_page = true; # FIXME: BUGGY
            last;
        }
    }

    my $out = render(
        $c,
        'recent' => {
            target_channels => \@target_channels,
            has_next_page   => $has_next_page,
        },
    );

    # reset counter.
    for my $channel ( @target_channels ) {
        $channel->clear_unread;
    }

    return $out;
}

sub dispatch_clear_all_unread {
    my ($class, $c) = @_;

    for my $channel ($c->{global_context}->channels) {
        $channel->clear_unread;
    }

    my $response = HTTP::Response->new(302);
    my $root = $c->{config}->{httpd}->{root};

    # SHOULD USE http://example.com/ INSTEAD OF http://example.com:portnumber/
    # because au phone returns '400 Bad Request' when redrirect to http://example.com:portnumber/
    $response->push_header(
        'Location' => (
                'http://'
              . ($c->{config}->{httpd}->{host} || $c->{req}->header('Host'))
              . $root
        )
    );

    return $response;
}

# topic on every channel
sub dispatch_topics {
    my ($class, $c) = @_;

    render_td(
        $c => (
            'topics', $c->{mobile_agent}, App::Mobirc->context->server
        )
    );
}

sub post_dispatch_show_channel {
    my ( $class, $c, $recent_mode, $channel) = @_;

    $channel = decode('utf8', $channel); # maybe $channel is not flagged utf8.

    my $r       = CGI->new( $c->{req}->content );
    my $message = $r->param('msg');
    $message = decode( $c->{mobile_agent}->encoding, $message );

    DEBUG "POST MESSAGE $message";

    $c->{global_context}->get_channel($channel)->post_command($message);

    my $irc_incode = $c->{irc_incode};

    my $response = HTTP::Response->new(302);
    my $root = $c->{config}->{httpd}->{root};
    $root =~ s!/$!!;
    my $path = $c->{req}->uri;
    $path =~ s/#/%23/;

    # SHOULD USE http://example.com/ INSTEAD OF http://example.com:portnumber/
    # because au phone returns '400 Bad Request' when redrirect to http://example.com:portnumber/
    $response->push_header(
        'Location' => (
                'http://'
              . ($c->{config}->{httpd}->{host} || $c->{req}->header('Host'))
              . $root
              . $path
              . '?time='
              . time
        )
    );
    return $response;
}

sub dispatch_keyword {
    my ($class, $c, $recent_mode) = @_;

    my $channel = server->get_channel(U '*keyword*');

    my $res = render_td(
        $c,
        'keyword' => (
            $c->{mobile_agent},
            ($recent_mode ? $channel->recent_log : $channel->message_log),
            $c->{irc_nick},
        ),
    );

    $channel->clear_unread;

    return $res;
}

sub dispatch_show_channel {
    my ($class, $c, $recent_mode, $channel_name, $render) = @_;

    DEBUG "show channel page: $channel_name";
    $channel_name = decode('utf8', $channel_name); # maybe $channel_name is not flagged utf8.

    my $channel = $c->{global_context}->get_channel($channel_name);

    my $out = render(
        $c,
        'show_channel' => {
            channel     => $channel,
            recent_mode => $recent_mode,
            render_ajax    => $render,
            msg         => decode(
                'utf8', +{ URI->new( $c->{req}->uri )->query_form }->{msg}
            ),
            channel_page_option => [
                map { $_->( $channel, $c ) } @{
                    $c->{global_context}->get_hook_codes('channel_page_option')
                  }
            ],
          }
    );

    $channel->clear_unread;

    return $out;
}

sub dispatch_pc_menu {
    my ($class, $c ) = @_;

    render_td(
        $c,
        'pc_menu' => (
            server,
            server->keyword_channel->unread_lines,
        )
    );
}

sub make_response {
    my ( $c, $out ) = @_;

    $out = _html_filter($c, $out);
    my $content = encode( $c->{mobile_agent}->encoding, $out);

    # change content type for docomo
    # FIXME: hmm... should be in the plugin?
    my $content_type = $c->{config}->{httpd}->{content_type};
    $content_type= 'application/xhtml+xml' if $c->{mobile_agent}->is_docomo;
    unless ( $content_type ) {
        if ( $c->{mobile_agent}->can_display_utf8 ) {
            $content_type = 'text/html; charset=UTF-8';
        } else {
            $content_type = 'text/html; charset=Shift_JIS';
        }
    }

    my $response = HTTP::Response->new(200);
    $response->push_header( 'Content-type' => encode('utf8', $content_type) );
    $response->push_header('Content-Length' => length($content) );

    $response->content( $content );

    for my $code (@{$c->{global_context}->get_hook_codes('response_filter')}) {
        $code->($c, $response);
    }

    return $response;
}

sub render {
    my ( $c, $name, $args ) = @_;

    croak "invalid args : $args" unless ref $args eq 'HASH';

    DEBUG "rendering template";

    # set default vars
    $args = {
        docroot              => $c->{config}->{httpd}->{root},
        render_line          => sub { render_line( $c, @_ ) },
        user_agent           => $c->{user_agent},
        mobile_agent         => $c->{mobile_agent},
        title                => $c->{config}->{httpd}->{title},
        version              => $App::Mobirc::VERSION,
        now                  => time(),

        %$args,
    };

    my $tmpl_dir = $c->{mobile_agent}->is_non_mobile ? 'pc' : 'mobile';
    DEBUG "tmpl_dir: $tmpl_dir";

    my $tt = Template->new(
        LOAD_TEMPLATES => [
            Template::Provider::Encoding->new(
                ABSOLUTE => 1,
                INCLUDE_PATH => dir( $c->{config}->{global}->{assets_dir}, 'tmpl', $tmpl_dir, )->stringify,
            )
        ],
    );
    $tt->process("$name.html", $args, \my $out)
        or die $tt->error;

    DEBUG "rendering done";

    return make_response($c, $out);
}

sub dispatch_static {
    my ($class, $c, $file_name, $content_type) = @_;

    my $file = file($c->{config}->{global}->{assets_dir},'static', $file_name);
    my $content = $file->slurp;

    my $response = HTTP::Response->new(200);
    $response->push_header( 'Content-type' => $content_type );
    $response->push_header('Content-Length' => length($content) );

    $response->content( $content );

    return $response;
}

sub _html_filter {
    my $c = shift;
    my $content = shift;

    for my $code (@{$c->{global_context}->get_hook_codes('html_filter')}) {
        $content = $code->($c, $content);
    }

    $content;
}

sub render_td {
    my ($c, @args) = @_;
    my $html = App::Mobirc::HTTPD::View->show(@args);
    make_response($c, $html);
}

sub render_line {
    my $c   = shift;
    my $message = shift;

    return "" unless $message;
    croak "must be object: $message" unless ref $message eq 'App::Mobirc::Model::Message';

    my $out = App::Mobirc::HTTPD::View->show('irc_message', $message, $c->{irc_nick});
    $out =~ s/^ //smg;
    $out =~ s/\n//g;
    $out;
}

1;
