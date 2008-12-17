package App::Mobirc::Web::Template::IRCMessage;
use App::Mobirc::Web::Template;
use Params::Validate ':all';
use HTML::Entities qw/encode_entities/;
use App::Mobirc::Util qw/irc_nick/;

sub render_irc_message {
    my ($self, $message, ) = validate_pos(@_, OBJECT, { isa => 'App::Mobirc::Model::Message' });

    # i want to strip spaces. cellphone hates spaces.
    my $html = _irc_message($message);
    $html =~ s/^\s+//smg;
    $html =~ s/\n//g;
    $html;
}

sub _irc_message {
    my $message = shift;

    return join('', do {
        my @res;
        push @res, _time($message->time);
        if (my $who = $message->who) {
            push @res, _who($who);
        }
        push @res, _body($message);
        @res;
    });
}

# render time likes: 12:25
sub _time {
    my $time = shift;
    die "missing time" unless $time;

    mt_cached(<<'...', $time);
? my ( $sec, $min, $hour ) = localtime(shift);
<span class="time">
    <span class="hour"><?= sprintf "%02d", $hour ?></span>
    <span class="colon">:</span>
    <span class="minute"><?= sprintf "%02d", $min ?></span>
</span>
...
}

sub _who {
    my $who = shift;

    my $who_class = ( $who eq irc_nick() ) ?  'nick_myself' : 'nick_normal';
    sprintf(q{<span class="%s">(%s)</span>}, $who_class, encode_entities($who));
}

sub _body {
    my $message = shift;

    my $body = sub {
        my $body = $message->body;
        $body = encode_entities($body, q{<>&"'});
        ($body, ) = App::Mobirc->context->run_hook_filter('message_body_filter', $body);
        $body || '';
    }->();

    sprintf(q{<span class="%s">%s</span>}, encode_entities($message->class), $body);
}

1;
