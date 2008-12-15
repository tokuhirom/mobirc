package App::Mobirc::Web::C::Account;
use Mouse;
use App::Mobirc::Web::C;
use App::Mobirc::Util;
use Encode;

sub dispatch_login {
    my ($class, $req) = @_;

    render_td(
        $req,
        'Account', 'login' => (
            mobile_agent => $req->mobile_agent,
            req => $req,
        )
    );
}

sub post_dispatch_login_password {
    my ($class, $req, $args) = @_;
    my $conf = App::Mobirc->context->config;
    die "missing password in config.global.password" unless $conf->{global}->{password};
    if (my $pw = $req->params->{password}) {
        if ($pw eq $conf->{global}->{password}) {
            $args->{session}->set('authorized', 1);
            redirect('/');
        } else {
            redirect('/account/login?invalid_password=1');
        }
    } else {
        redirect('/account/login');
    }
}

sub post_dispatch_login_mobileid {
    my ($class, $req, $args) = @_;
    my $conf = App::Mobirc->context->config;
    die "missing password in config.global.mobileid" unless $conf->{global}->{mobileid};
    my $ma = HTTP::MobileAttribute->new($req->headers);
    if ($ma->can('user_id') && (my $user_id = $ma->user_id)) {
        if ($user_id eq $conf->{global}->{mobileid}) {
            if ($ma->isa_cidr($req->address)) {
                $args->{session}->set('authorized', 1);
                return redirect('/');
            } else {
                return redirect('/account/login?invalid_cidr=1');
            }
        } else {
            return redirect('/account/login?invalid_mobileid=1');
        }
    } else {
        return redirect('/account/login');
    }
}

sub post_dispatch_logout {
    my ($class, $req, $args) = @_;
    $args->{session}->expire();

    return redirect('/account/login');
}

1;
