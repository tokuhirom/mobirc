package App::Mobirc::Web::C::Account;
use App::Mobirc::Web::C;
use App::Mobirc::Util;
use Encode;

sub dispatch_login {
    if (config->{global}->{nopassword}) {
        session->set('authorized', 1);
        return redirect(param('return') || '/');
    }
    render();
}

sub post_dispatch_login_password {
    die "missing password in config.global.password" unless config->{global}->{password};
    if (my $pw = param('password')) {
        if ($pw eq config->{global}->{password}) {
            session->set('authorized', 1);
            redirect(param('return') || '/');
        } else {
            redirect('/account/login?invalid_password=1');
        }
    } else {
        redirect('/account/login');
    }
}

sub post_dispatch_login_mobileid {
    die "missing password in config.global.mobileid" unless config->{global}->{mobileid};
    my $ma = mobile_attribute;
    if ($ma->can('user_id') && (my $user_id = $ma->user_id)) {
        if ($user_id eq config->{global}->{mobileid}) {
            if ($ma->isa_cidr(req->address)) {
                session->set('authorized', 1);
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
    session->expire();

    return redirect('/account/login');
}

1;
