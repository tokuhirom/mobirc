package App::Mobirc::Web::C::Initialize;
use App::Mobirc::Web::C;
use App::Mobirc::Util;
use HTML::AutoForm;

{
    my $form = HTML::AutoForm->new(
        action => '/setup/basic',
        fields => [
            password => {
                type     => 'password',
                required => 1,
            },
            keywords => {
                type    => 'text',
            },
            stopwords => {
                type    => 'text',
            },
        ]
    );
    sub dispatch_basic {
        render_td( $form );
    }
    sub post_dispatch_basic {
        if ($form->validate(req, sub { 1 })) {
            for my $field (@{ $form->fields }) {
                my $key = $field->name;
                global_context->config->{global}->{$key} = param($key);
            }
            redirect('/');
        } else {
            render_td($form);
        }
    }
}

1;
