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

sub context () { App::Mobirc->context } ## no critic
sub server  () { context->server } ## no critic.

# this module contains MVC's C.

sub dispatch_index {
    my ($class, $c) = @_;

    return render_td(
        $c,
        'mobile/top' => {
            exists_recent_entries => scalar( grep { $_->unread_lines } server->channels ),
            mobile_agent       => $c->req->mobile_agent,
            keyword_recent_num => server->keyword_channel->unread_lines(),
            channels           => scalar( server->channels_sorted ),
        }
    );
}

# recent messages on every channel
sub dispatch_recent {
    my ($class, $c) = @_;

    my @unread_channels =
      grep { $_->unread_lines }
      context->channels;

    my $out = render_td(
        $c,
        'mobile/recent' => {
            channel       => $unread_channels[0],
            has_next_page => (scalar(@unread_channels) >= 2 ? 1 : 0),
        },
    );

    # reset counter.
    if (my $channel = $unread_channels[0]) {
        $channel->clear_unread;
    }

    return $out;
}

    # SHOULD USE http://example.com/ INSTEAD OF http://example.com:portnumber/
    # because au phone returns '400 Bad Request' when redrirect to http://example.com:portnumber/
sub dispatch_clear_all_unread {
    my ($class, $c) = @_;

    for my $channel (context->channels) {
        $channel->clear_unread;
    }

    my $root = context->config->{httpd}->{root};
    $c->res->redirect($root);
}

# topic on every channel
sub dispatch_topics {
    my ($class, $c) = @_;

    render_td(
        $c => (
            'mobile/topics', $c->req->mobile_agent, App::Mobirc->context->server
        )
    );
}

sub post_dispatch_show_channel {
    my ( $class, $c, $channel) = @_;

    my $message = decode( $c->req->mobile_agent->encoding, $c->req->params->{'msg'} );

    DEBUG "POST MESSAGE $message";

    context->get_channel($channel)->post_command($message);

    my $root = context->config->{httpd}->{root};
    $root =~ s!/$!!;
    my $path = $c->req->uri->path;
    $path =~ s/#/%23/;

    $c->res->redirect( $root . $path . '?time=' . time );
}

sub dispatch_keyword {
    my ($class, $c, ) = @_;

    my $channel = server->keyword_channel;

    my $res = render_td(
        $c,
        'mobile/keyword' => (
            $c->req->mobile_agent,
            ($c->req->params->{recent_mode} ? $channel->recent_log : $channel->message_log),
            $c->{irc_nick},
        ),
    );

    $channel->clear_unread;

    return $res;
}

sub dispatch_show_channel {
    my ($class, $c, $channel_name,) = @_;

    DEBUG "show channel page: $channel_name";

    my $channel = context->get_channel($channel_name);

    my $out = render(
        $c,
        'show_channel' => {
            channel     => $channel,
            recent_mode => $c->req->params->{recent_mode},
            msg         => decode_utf8( $c->req->params->{msg} ), # XXX maybe wrong?
            channel_page_option => [
                map { $_->( $channel, $c ) } @{
                    context->get_hook_codes('channel_page_option')
                  }
            ],
        }
    );

    $channel->clear_unread;

    return $out;
}

{
    sub dispatch_ajax_base {
        my ($class, $c) = @_;

        return render_td(
            $c,
            'ajax_base' => (
                $c->req->mobile_agent,
                ($c->{config}->{httpd}->{root} || '/'),
            )
        );
    }

    sub dispatch_ajax_channel {
        my ($class, $c, $channel_name) = @_;

        my $channel = server->get_channel($channel_name);
        my $res = render_td(
            $c,
            'ajax_channel' => (
                $channel,
                $c->{irc_nick}
            )
        );
        $channel->clear_unread();
        return $res;
    }

    sub post_dispatch_ajax_channel {
        my ( $class, $c, $channel) = @_;

        my $message = $c->req->parameters->{'msg'};
        $message = decode( $c->req->mobile_agent->encoding, $message );

        DEBUG "POST MESSAGE $message";

        server->get_channel($channel)->post_command($message);

        $c->res->body('ok');
    }

    sub dispatch_ajax_menu {
        my ($class, $c ) = @_;

        render_td(
            $c,
            'ajax_menu' => (
                server,
                server->keyword_channel->unread_lines,
            )
        );
    }

    sub dispatch_ajax_keyword {
        my ($class, $c ) = @_;

        my $res = render_td(
            $c,
            'ajax_keyword' => (
                server,
                $c->{irc_nick},
            )
        );
        server->keyword_channel->clear_unread();
        $res;
    }
}

sub make_response {
    my ( $c, $out ) = @_;

    $out = _html_filter($c, $out);
    my $content = encode( $c->req->mobile_agent->encoding, $out);

    # change content type for docomo
    # FIXME: hmm... should be in the plugin?
    my $content_type = $c->{config}->{httpd}->{content_type};
    $content_type= 'application/xhtml+xml' if $c->req->mobile_agent->is_docomo;
    unless ( $content_type ) {
        if ( $c->req->mobile_agent->can_display_utf8 ) {
            $content_type = 'text/html; charset=UTF-8';
        } else {
            $content_type = 'text/html; charset=Shift_JIS';
        }
    }

    my $response = HTTP::Response->new(200);
    $response->push_header( 'Content-type' => encode('utf8', $content_type) );
    $response->push_header('Content-Length' => length($content) );

    $response->content( $content );

    for my $code (@{context->get_hook_codes('response_filter')}) {
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
        mobile_agent         => $c->req->mobile_agent,
        title                => $c->{config}->{httpd}->{title},
        version              => $App::Mobirc::VERSION,
        now                  => time(),

        %$args,
    };

    my $tmpl_dir = 'mobile';
    DEBUG "tmpl_dir: $tmpl_dir";

    my $tt = Template->new(
        LOAD_TEMPLATES => [
            Template::Provider::Encoding->new(
                ABSOLUTE => 1,
                INCLUDE_PATH => dir( context->config->{global}->{assets_dir}, 'tmpl', $tmpl_dir, )->stringify,
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

    my $file = file(context->{config}->{global}->{assets_dir},'static', $file_name);
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

    for my $code (@{context->get_hook_codes('html_filter')}) {
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
