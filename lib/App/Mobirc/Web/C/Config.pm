package App::Mobirc::Web::C::Config;
use App::Mobirc::Web::C;
use App::Mobirc::Util;
use HTML::AutoForm;

sub dispatch_index { render_td() }

{
    # XXX how to set a default value?
    my $form = HTML::AutoForm->new(
        action => '/config/irc',
        fields => [
            server => {
                required => 1,
                type    => 'text',
            },
            port => {
                default => 6667,
                type    => 'text',
                required => 1,
                regexp => qr/^[0-9]+$/,
            },
            nick => {
                required => 1,
                type    => 'text',
            },
            desc => {
                type    => 'text',
            },
            username => {
                required => 1,
                type    => 'text',
            },
            password => {
                required => 1,
                type    => 'password',
            },
            incode => {
                default => 'utf8',
                required => 1,
                type    => 'text',
            },
        ],
    );
    sub dispatch_irc {
        render_td($form);
    }
    sub post_dispatch_irc {
        if ($form->validate(req, sub { 1 })) {
            for my $field (@{ $form->fields }) {
                my $key = $field->name;
                global_context->config->{plugin}->{$key} = param($key);
            }
            redirect('/config/need_save');
        } else {
            render_td($form);
        }
    }
}

{
    my $form = HTML::AutoForm->new(
        action => '/config/mobileid',
        fields => [ ],
    );
    sub dispatch_mobileid {
        render_td($form);
    }
}

1;
