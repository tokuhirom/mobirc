package HTTP::Engine::Types::Core;
use Any::Moose;
use Any::Moose (
    'X::Types' => [-declare => [qw/Interface Uri Header Handler/]],
);

use URI;
use URI::WithBase;
use URI::QueryParam;
use HTTP::Headers::Fast;

do {
    role_type Interface, { role => "HTTP::Engine::Role::Interface" };

    coerce Interface, from 'HashRef' => via {
        my $module  = $_->{module};
        my $plugins = $_->{plugins} || [];
        my $args    = $_->{args};
        $args->{request_handler} = $_->{request_handler};

        if ( $module !~ s{^\+}{} ) {
            $module = join( '::', "HTTP", "Engine", "Interface", $module );
        }

        Any::Moose::load_class($module);

        return $module->new(%$args);
    };
};

do {
    class_type Uri, { class => "URI::WithBase" };

    coerce Uri, from 'Str' => via {

        # generate base uri
        my $uri  = URI->new($_);
        my $base = $uri->path;
        $base =~ s{^/+}{};
        $uri->path($base);
        $base .= '/' unless $base =~ /\/$/;
        $uri->query(undef);
        $uri->path($base);
        URI::WithBase->new( $_, $uri );
    };
};

do {
    subtype Header,
        as 'Object',
        where { $_->isa('HTTP::Headers::Fast') || $_->isa('HTTP::Headers') };

    coerce Header,
        from 'ArrayRef' => via { HTTP::Headers::Fast->new( @{$_} ) },
        from 'HashRef'  => via { HTTP::Headers::Fast->new( %{$_} ) };
};

do {
    subtype Handler, as 'CodeRef';
    coerce Handler, from 'Str' => via { \&{$_} };
};

1;

__END__

=head1 NAME

HTTP::Engine::Types::Core - Core HTTP::Engine Types

=head1 SYNOPSIS

  use Any::Moose;
  use HTTP::Engine::Types::Core qw( Interface );

  has 'interface' => (
    isa    => Interface,
    coerce => 1
  );

=head1 DESCRIPTION

HTTP::Engine::Types::Core defines the main subtypes used in HTTP::Engine

=head1 AUTHORS

Kazuhiro Osawa and HTTP::Engine Authors.

=head1 SEE ALSO

L<HTTP::Engine>, L<MouseX::Types>, L<MooseX::Types>

=cut
