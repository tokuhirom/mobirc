package HTTP::Session::State::Mixin::ResponseFilter;
use strict;
use warnings;
use Exporter 'import';
our @EXPORT_OK = qw/response_filter/;

sub response_filter {
    my ($self, $session_id, $res) = @_;
    Carp::croak "missing session_id" unless $session_id;

    if (Scalar::Util::blessed $res) {
        if ($res->code == 302) {
            if (my $uri = $res->header('Location')) {
                $res->header('Location' => $self->redirect_filter($session_id, $uri));
            }
            return $res;
        } elsif ($res->content && ($res->header('Content-Type')||'text/html') =~ /html/) {
            $res->content( $self->html_filter($session_id, $res->content) );
            return $res;
        } else {
            return $res; # nop
        }
    } else {
        # psgi
        if ($res->[0] == 302) {
            my @headers = @{ $res->[1] };    # copy
            my @new_headers;
            while ( my ( $key, $val ) = splice @headers, 0, 2 ) {
                if (lc($key) eq 'location') {
                    $val = $self->redirect_filter($session_id, $val);
                }
                push @new_headers, $key, $val;
            }
            $res->[1] = \@new_headers;
            return $res;
        } elsif (my $body = $res->[2]) {
            if ( ref $body eq 'ARRAY' ) {
                # TODO: look the content-type header.
                my $content = '';
                for my $line (@$body) {
                    $content .= $line if length $line;
                }
                $res->[2] = [$self->html_filter($session_id, $content)];
                return $res;
            } else { # HTTP::Session should not process glob.
                return $res;
            }
        } else {
            return $res; # nop
        }
    }
}

1;
