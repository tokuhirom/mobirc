package HTTP::Session::State::Cookie;
use HTTP::Session::State::Base;
use Carp ();
use Scalar::Util ();

our $COOKIE_CLASS = 'CGI::Cookie';

__PACKAGE__->mk_ro_accessors(qw/name path domain expires/);

{
    my $required = 0;
    sub _cookie_class {
        my $class = shift;
        unless ($required) {
            (my $klass = $COOKIE_CLASS) =~ s!::!/!g;
            $klass .= ".pm";
            require $klass;
            $required++;
        }
        return $COOKIE_CLASS
    }
}

sub new {
    my $class = shift;
    my %args = ref($_[0]) ? %{$_[0]} : @_;
    # set default values
    $args{name} ||= 'http_session_sid';
    $args{path} ||= '/';
    bless {%args}, $class;
}

sub get_session_id {
    my ($self, $req) = @_;

    my $cookie_header = $ENV{HTTP_COOKIE} || (Scalar::Util::blessed($req) ? $req->header('Cookie') : $req->{HTTP_COOKIE});
    return unless $cookie_header;

    my %jar    = _cookie_class()->parse($cookie_header);
    my $cookie = $jar{$self->name};
    return $cookie ? $cookie->value : undef;
}

sub response_filter {
    my ($self, $session_id, $res) = @_;
    Carp::croak "missing session_id" unless $session_id;

    $self->header_filter($session_id, $res);
}

sub header_filter {
    my ($self, $session_id, $res) = @_;
    Carp::croak "missing session_id" unless $session_id;

    my $cookie = _cookie_class()->new(
        sub {
            my %options = (
                -name   => $self->name,
                -value  => $session_id,
                -path   => $self->path,
            );
            $options{'-domain'} = $self->domain if $self->domain;
            $options{'-expires'} = $self->expires if $self->expires;
            %options;
        }->()
    );
    if (Scalar::Util::blessed($res)) {
        $res->header( 'Set-Cookie' => $cookie->as_string );
        $res;
    } else {
        push @{$res->[1]}, 'Set-Cookie' => $cookie->as_string;
        $res;
    }
}

1;
__END__

=head1 NAME

HTTP::Session::State::Cookie - Maintain session IDs using cookies

=head1 SYNOPSIS

    HTTP::Session->new(
        state => HTTP::Session::State::Cookie->new(
            name   => 'foo_sid',
            path   => '/my/',
            domain => 'example.com,
        ),
        store => ...,
        request => ...,
    );

=head1 DESCRIPTION

Maintain session IDs using cookies

=head1 CONFIGURATION

=over 4

=item name

cookie name.

    default: http_session_sid

=item path

path.

    default: /

=item domain

    default: undef

=item expires

expire date.e.g. "+3M".
see also L<CGI::Cookie>.

    default: undef

=back

=head1 METHODS

=over 4

=item header_filter($res)

header filter

=item get_session_id

=item response_filter

for internal use only

=back

=head1 HOW TO USE YOUR OWN CGI::Simple::Cookie?

    use HTTP::Session::State::Cookie;
    BEGIN {
    $HTTP::Session::State::Cookie::COOKIE_CLASS = 'CGI/Simple/Cookie.pm';
    }

=head1 SEE ALSO

L<HTTP::Session>, L<CGI::Cookie>, L<CGI::Simple::Cookie>

