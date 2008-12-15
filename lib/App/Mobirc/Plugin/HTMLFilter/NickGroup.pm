package App::Mobirc::Plugin::HTMLFilter::NickGroup;
use strict;
use App::Mobirc::Plugin;
use List::Util qw/first/;
use XML::LibXML;
use Encode;
use App::Mobirc::Validator;

has 'map' => (
    is       => 'ro',
    isa      => 'HashRef',
    required => 1,
);

# nick -> who_class ("nick_" + groupname)
has class_for => (
    is => 'ro',
    isa => 'HashRef',
    lazy => 1,
    default => sub {
        my $self = shift;
        my %groups = %{ $self->map };
        my %class_for;
        while ( my ( $group, $nicks ) = each %groups ) {
            for my $nick ( @{$nicks} ) {
                push @{ $class_for{$nick} }, "nick_" . $group;
            }
        }
        \%class_for;
    },
);

hook 'html_filter' => sub {
    my ($self, $global_context, $req, $html) = validate_hook('html_filter', @_);

    my $doc = eval { XML::LibXML->new->parse_html_string($html); };
    if ($@) {
        warn $@;
        return ($req, $html);
    }

    for my $elem ($doc->findnodes(q{//span[@class='nick_normal']})) {
        if (my $who = $elem->findvalue('./text()')) {
            $who =~ s!^\((.+)\)$!$1!; # (who) => who

            if (my $new_class = $self->_class($who)) {
                $elem->setAttribute(class => $new_class);
            }
        }
    }

    $html = $doc->toStringHTML();
    $html =~ s{<!DOCTYPE[^>]*>\s*}{};
    $html =~ s{(<a[^>]+)/>}{$1></a>}gi;
    return ($req, decode($doc->encoding || "UTF-8", $html));
};

sub _class {
    my ($self, $nick) = @_;

    if ($nick = first { $nick =~ /^$_/i } keys %{ $self->class_for }) {
        return join ' ', @{ $self->class_for->{$nick} };
    } else {
        return;
    }
}

1;

=head1 AUTHOR

id:hirose31 & id:tokuhirom

