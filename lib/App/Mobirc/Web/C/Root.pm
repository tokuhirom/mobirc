package App::Mobirc::Web::C::Root;
use App::Mobirc::Web::C;
use Encode;
use MIME::Base64::URLSafe qw(urlsafe_b64encode);

sub dispatch_index {
    if (param('auto')) {
        my $ma = App::Mobirc::Web::Handler->web_context->mobile_attribute;
        my $ua = req->headers->header('User-Agent');
        if ($ma->is_docomo || $ma->is_ezweb || $ma->is_softbank) {
            redirect('/mobile/channel?channel=' . encode_urlsafe_encoded(param('channel')));
        } elsif ($ua =~ /iPhone/) {
            redirect('/iphone/channel?channel=' . encode_urlsafe_encoded(param('channel')));
        } elsif ($ua =~ /Android/) {
            redirect('/android/channel?channel=' . encode_urlsafe_encoded(param('channel')));
        } else {
            redirect('/mobile/channel?channel=' . encode_urlsafe_encoded(param('channel')));
        }
    } else {
        render();
    }
}

sub encode_urlsafe_encoded {
    my $channel_name = shift;
    urlsafe_b64encode(encode_utf8 $channel_name);
}

1;
