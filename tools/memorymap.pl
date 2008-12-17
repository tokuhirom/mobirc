use strict;
use warnings;
use GTop;
use Module::Find;
use Perl6::Say;
my $gtop = GTop->new;
my @mods = findallmod 'App::Mobirc';
unshift @mods, 'App::Mobirc::Web::Handler';
unshift @mods, findallmod 'App::Mobirc::Web::C';
unshift @mods, 'App::Mobirc::Web::C';
unshift @mods, 'App::Mobirc::Web::View';
unshift @mods, findallmod 'App::Mobirc::Web::Template';
unshift @mods, 'App::Mobirc::Web::Router';
unshift @mods, 'HTML::Entities';
unshift @mods, 'JSON';
unshift @mods, 'App::Mobirc::Util';
unshift @mods, 'App::Mobirc';
unshift @mods, 'App::Mobirc::Plugin';
unshift @mods, 'HTTP::Engine::Interface::POE';
unshift @mods, 'POE::Component::Server::TCP';
unshift @mods, 'POE::Filter::HTTPD';
unshift @mods, 'IO::Scalar';
unshift @mods, 'URI::WithBase';
unshift @mods, 'HTTP::Engine::Interface';
unshift @mods, qw/
    XSLoader
    Geo::Coordinates::Converter
    URI
    Template
    Template::Declare::Tags
    Template::Declare
    String::TT
    HTTP::Body
    HTTP::Headers
    HTTP::Request
    URI::QueryParam
    HTTP::Engine::Types::Core
    HTTP::Engine::Request
    HTTP::Engine::Request::Upload
    HTTP::Engine::Response
    HTTP::Engine
/;
unshift @mods, 'File::ShareDir';
unshift @mods, 'XML::LibXML';
unshift @mods, 'Carp';
unshift @mods, 'Encode::MIME::Name';
unshift @mods, qw/HTTP::Request HTTP::Date POE URI/;
unshift @mods, qw/
    MRO::Compat
    Sub::Exporter
    POE
    Carp
    Symbol
    POSIX
    Fcntl
    Errno
    Socket
    IO::Handle
    FileHandle
    POE::Wheel
    POE::Sugar::Args
    POE::Wheel
    POE::Wheel::SocketFactory
    POE::Sugar::Args
    POE::Filter::IRCD
    POE::Wheel
    Net::DNS
    Params::Validate
    YAML
    Encode
    File::Basename
    POE::Wheel::ReadWrite
    POE::Component::IRC::Common
    POE::Component::IRC::Constants
    POE::Component::IRC::Plugin::ISupport
    POE::Component::IRC::Plugin::Whois
    POE::Component::IRC::Plugin::DCC
    POE::Component::Client::DNS
    POE::Component::Pluggable
    POE::Component::IRC
/;
# say "MODS: @mods";
say "INIT: " . $gtop->proc_mem($$)->size;
my $prev = $gtop->proc_mem($$)->size;
for my $mod (@mods) {
    if ($mod =~ s/^\.\s*//) {
        eval "$mod";
    } else {
        eval "require $mod";
    }
    die $@ if $@;
    printf "%07d, %08d  # $mod\n", $gtop->proc_mem($$)->size - $prev, $gtop->proc_mem($$)->size;
    $prev = $gtop->proc_mem($$)->size;
}

say $gtop->proc_mem($$)->size, " : Total";

