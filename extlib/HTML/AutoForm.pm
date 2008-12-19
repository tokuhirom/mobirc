package HTML::AutoForm;

use strict;
use warnings;
use utf8;
use Scalar::Util;

use Class::Accessor::Lite;
use HTML::AutoForm::Error;
use HTML::AutoForm::Field;
use HTML::AutoForm::Field::AnyText;
use HTML::AutoForm::Field::InputCheckable;
use HTML::AutoForm::Field::InputSet;
use HTML::AutoForm::Field::Checkbox;
use HTML::AutoForm::Field::Hidden;
use HTML::AutoForm::Field::Radio;
use HTML::AutoForm::Field::Option;
use HTML::AutoForm::Field::Password;
use HTML::AutoForm::Field::Select;
use HTML::AutoForm::Field::Text;
use HTML::AutoForm::Field::Textarea;

our $VERSION;
our %Defaults;
our %Lang_Defaults;
our $DEFAULT_LANG;
our $CLASS_PREFIX;

BEGIN {
    $VERSION = '0.01';
    %Defaults = (
        action       => undef,
        csrf_keyname => '__autoform_csrf_key',
        fields       => undef, # need to be copied
        secure       => 1,
        reset_label  => undef,
    );
    %Lang_Defaults = (
        en => {
            submit_label => 'Submit Form',
            error_prefix => '',
        },
        ja => {
            submit_label => 'フォームを投稿',
            error_prefix => '※',
        },
    );
    Class::Accessor::Lite->mk_accessors(
        keys %Defaults,
        keys %{$Lang_Defaults{en}},
    );
    $DEFAULT_LANG = 'en';
    $CLASS_PREFIX = 'autoform';
};

sub new {
    my $klass = shift;
    my %args = @_ == 1 ? %{$_[0]} : @_;
    my $fields = delete $args{fields} || [];
    for my $n qw(action) {
        die 'mandatory attribute "' . $n . '" is missing'
            unless defined $args{$n};
    }
    my $self = bless {
        %{$Lang_Defaults{$DEFAULT_LANG}},
        %Defaults,
        %args,
        fields => [], # filled afterwards
    }, $klass;
    die 'fields should be supplied in: tag => attributes style'
        unless @$fields % 2 == 0;
    for (my $i = 0; $i < @$fields; $i += 2) {
        my $name = $fields->[$i];
        my $opts = $fields->[$i + 1];
        die 'field type is missing or invalid'
            unless $opts->{type} =~ /^(text|hidden|password|radio|select|checkbox|textarea)$/;
        my $field_klass = 'HTML::AutoForm::Field::' . ucfirst $opts->{type};
        push @{$self->{fields}}, $field_klass->new(
            %$opts,
            name => $name,
        );
    }
    $self;
}

sub field {
    my ($self, $n) = @_;
    for my $f (@{$self->{fields}}) {
        return $f
            if $f->name eq $n;
    }
    return;
}

# the default renderer
sub render {
    my ($self, $query, $csrf_token) = @_;
    
    my $do_validate = $query->request_method eq 'POST'
            || (! $self->secure && %{$query->Vars});
    
    my $html = join(
        '',
        '<form action="',
        _escape_html($self->action),
        '"',
        ($self->secure ? ' method="POST"' : ''),
        '>',
        '<table class="',
        $CLASS_PREFIX,
        '_table">',
        (map {
            sub {
                my $field = shift;
                my @values = $query->param($_->name);
                if ($field->type eq 'hidden') {
                    return $_->render(\@values);
                }
                my @r = (
                    '<tr><th>',
                    _escape_html($field->label),
                    '</th><td>',
                    $field->render(\@values),
                );
                if ($do_validate) {
                    print STDERR "validating: ", $field->name, "\n";
                    if (my $err = $field->validate($query)) {
                        push(
                            @r,
                            '<div class="',
                            $CLASS_PREFIX,
                            '_error">',
                            _escape_html($self->error_prefix . $err->message),
                            '</div>',
                        );
                    }
                }
                push @r, '</td></tr>';
                @r;
            }->($_)
        } @{$self->{fields}}),
        $self->secure ? (
            '<input type="hidden" name="',
            _escape_html($self->csrf_keyname),
            '" value="',
            # TODO: use a different id
            _escape_html($csrf_token),
            '" />',
        ) : (),
        $self->submit_label || $self->reset_label ? (
            '<tr><th></th><td>',
            $self->submit_label ? (
                '<input class="',
                $CLASS_PREFIX,
                '_field_submit" type="submit" value="',
                _escape_html($self->submit_label),
                '" />',
            ) : (),
            $self->reset_label ? (
                '<input class="',
                $CLASS_PREFIX,
                '_field_reset" type="reset" value="',
                _escape_html($self->reset_label),
                '" />',
            ) : (),
            '</td></tr>',
        ) : (),
        '</table></form>',
    );
    $html;
}

sub validate {
    my ($self, $query, $check_csrf_callback) = @_;
    
    for my $f (@{$self->{fields}}) {
        if (my $error = $f->validate($query)) {
            return;
        } elsif (my $h = $f->custom) {
            if (my $error = $h->($f, $query)) {
                return;
            }
        }
    }
    if ($self->secure) {
        my $ok;
        if (my $csrf_value = $query->param($self->csrf_keyname)) {
            if ($check_csrf_callback->($csrf_value)) {
                $ok = 1;
            }
        }
        return
            unless $ok;
    }
    1;
}

sub _build_element {
    my ($tag, $base, $extra, $omit, $append) = @_;
    my %attr = (
        (map {
            ($_ => $base->{$_})
        } grep {
            ! exists $omit->{$_} && ! /^(allow_multiple|label|required|xhtml_compat)$/
        } keys %$base),
        %$extra,
    );
    my $is_xhtml = $base->{xhtml_compat};
    my $html = join(
        '',
        '<' . $tag,
        (map {
            $is_xhtml || $_ ne $attr{$_} ||
            ! /^(?:(?:check|disable|select)ed|readonly)$/
                ? ' ' . $_ . '="' . _escape_html($attr{$_}) . '"'
                : ' ' . $_;
        } sort grep {
            defined $attr{$_}
        } keys %attr),
        defined $append ? ('>', $append, '</', $tag, '>') : ($is_xhtml ? ' />' : '>'),
    );
    $html;
}

sub _escape_html {
    my $str = shift;
    $str =~ s/&/&amp;/g;
    $str =~ s/>/&gt;/g;
    $str =~ s/</&lt;/g;
    $str =~ s/"/&quot;/g;
    $str =~ s/'/&#39;/g;
    $str;
}

1;

__END__

=head1 NAME

HTML::AutoForm - a standalone HTML form validator and renderer

=head1 SYNOPSIS

 # build form object
 my $form = HTML::AutoForm->new(
     fields => [
         username  => {
             type       => 'text',
             required   => 1,
             min_length => 6,
             max_length => 8,
             regexp     => qr/^[0-9a-z_]+$/,
         },
 ...
     ],
 );

 # validate form
 my $ok = $form->validate(
     $query,                # any object that support $query->param('name')
     sub { ... },           # callback to check if csrf token is valid
 );

 # render form
 $html .= $form->render(
     $query,
     $csrf_token,
 );

=head1 DESCRIPTION

HTML::AutoForm is a simple form validator and renderer.

=head1 CONSTRUCTOR

The new function takes following arguments.

=head2 action

action attribute of form tag (mandatory)

=head2 secure

whether or not to limit form submission to POST method, and to perform CSRF protection (default: 1)

=head2 fields

an array of fields in name => attr form.  Following attributes are accepted.

type - type of the field (mandatory, accepted types are: text, hidden, password, radio, select, checkbox, textarea)

required - whether or not user selection (or input) to the field is mandatory.  For fields that support multiple selection (like checkbox), set a numeral to require certain number of items to be selected.  Or set an arrayref to specify the range of number of choices.

min_length - minimum length of value (for editable fields)

max_length - maximum length of value (for editable fields)

regexp     - regular expression used for validation (for editable fields)

custom     - custom validation rule (set as subref, for editable fields)

label      - label of the field (default is ucfirst(name))

options    - an arrayref of value => attributes (for checkbox, radio, select types)

Other attributes are treated as ordinal HTML attributes.

=head1 METHODS

=head2 action

action attribute of form tag

=head2 csrf_keyname

set parameter name used for CSRF protection (default: '__autoform_csrf_key')

=head2 field($field_name)

accessor for field object by name

=head2 fields

accessor for field object array

=head2 render($query [, $csrf_token])

default HTML renderer

=head2 secure

whether or not to protect the form againts CSRF attacks

=head2 validate($query [, csrf_token_validator ])

query validator

=head1 AUTHOR

Kazuho Oku E<lt>kazuhooku !@#$%^&* gmail.comE<gt>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut
