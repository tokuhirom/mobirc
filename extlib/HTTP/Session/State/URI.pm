package HTTP::Session::State::URI;
use HTTP::Session::State::Base;
use HTML::StickyQuery;

__PACKAGE__->mk_ro_accessors(qw/session_id_name/);

sub new {
    my $class = shift;
    my %args = ref($_[0]) ? %{$_[0]} : @_;
    # set default values
    $args{session_id_name} ||= 'sid';
    bless {%args}, $class;
}

sub get_session_id {
    my ($self, $req) = @_;
    Carp::croak "missing req" unless $req;
    $req->param($self->session_id_name);
}

sub response_filter {
    my ($self, $session_id, $res) = @_;
    Carp::croak "missing session_id" unless $session_id;

    if ($res->code == 302) {
        if (my $uri = $res->header('Location')) {
            $res->header('Location' => $self->redirect_filter($session_id, $uri));
        }
        return $res;
    } elsif ($res->content) {
        $res->content( $self->html_filter($session_id, $res->content) );
        return $res;
    } else {
        return $res; # nop
    }
}

sub html_filter {
    my ($self, $session_id, $html) = @_;
    Carp::croak "missing session_id" unless $session_id;

    my $session_id_name = $self->session_id_name;

    $html =~ s/(<form\s*.*?>)/$1\n<input type="hidden" name="$session_id_name" value="$session_id">/isg;

    my $sticky = HTML::StickyQuery->new;
    return $sticky->sticky(
        scalarref => \$html,
        param     => { $session_id_name => $session_id },
    );
}

sub redirect_filter {
    my ( $self, $session_id, $path ) = @_;
    Carp::croak "missing session_id" unless $session_id;

    my $uri = URI->new($path);
    $uri->query_form( $uri->query_form, $self->session_id_name => $session_id );
    return $uri->as_string;
}

1;
__END__

=head1 NAME

HTTP::Session::State::URI - embed session id to uri

=head1 SYNOPSIS

    HTTP::Session->new(
        state => HTTP::Session::State::URI->new(
            session_id_name => 'foo_sid',
        ),
        store => ...,
        request => ...,
    );

=head1 DESCRIPTION

This state module embeds session id to uri.

=head1 CONFIGURATION

=over 4

=item session_id_name

You can set the session id name.

    default: sid

=back

=head1 METHODS

=over 4

=item html_filter($session_id, $html)

HTML filter

=item redirect_filter($session_id, $url)

redirect filter

=item get_session_id

=item response_filter

for internal use only

=back

=head1 WARNINGS

URI sessions are very prone to session hijacking problems.

=head1 SEE ALSO

L<HTTP::Session>

