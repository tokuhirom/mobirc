package HTTP::MobileAttribute::Agent::Base;
use strict;
use warnings;
require Class::Component;
use Carp;

sub import {
    my $pkg = caller(0);

    no strict 'refs';

    *{"$pkg\::mk_accessors"} = \&mk_accessors;
    *{"$pkg\::no_match"}     = \&_no_match;
    *{"$pkg\::user_agent"}   = sub { $_[0]->request->get('User-Agent') };
    *{"$pkg\::class_component_load_plugin_resolver"} = sub { "HTTP::MobileAttribute::Plugin::$_[1]" };
    $pkg->mk_accessors(qw/request carrier_longname/);

    unless ($pkg->isa('Class::Component')) {
        unshift @{"$pkg\::ISA"}, 'Class::Component';
    }
    Class::Component::Implement->init($pkg);

    $pkg->load_components(qw/DisableDynamicPlugin Autocall::InjectMethod AutoloadPlugin/);
}

sub _no_match {
    my $self = shift;

    if ($^W) {
        carp(
            $self->user_agent,
            ": no match. Might be new variants. ",
            "please contact the author of HTTP::MobileAgent!"
        );
    }
}

sub mk_accessors {
    my ($class, @methods) = @_;

    no strict 'refs';
    for my $method (@methods) {
        *{"${class}::${method}"} = sub { $_[0]->{$method} };
    }
}

1;
__END__

=encoding utf-8

=head1 NAME

HTTP::MobileAttribute::Agent::Base - Agent の Abstract ベースクラス

=head1 DESCRIPTION

HTTP::MobileAttribute::Agent::* の抽象基底クラスです。

HTTP::MobileAttribute::Agent::* は、UserAgent を parse し、その属性をアクセサとして提供します。
UserAgent からとれる以上の情報は提供しないところがミソです。

=head1 AUTHOR

Tokuhiro Matsuno

=head1 SEE ALSO

L<HTTP::MobileAttribute>

