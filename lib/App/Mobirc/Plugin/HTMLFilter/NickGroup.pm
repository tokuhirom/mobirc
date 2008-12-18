package App::Mobirc::Plugin::HTMLFilter::NickGroup;
use strict;
use App::Mobirc::Plugin;
use List::Util qw/first/;
use Encode;
use App::Mobirc::Validator;
use HTML::TreeBuilder::XPath;

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

    my $tree = HTML::TreeBuilder::XPath->new;
    $tree->parse_content($html);

    for my $elem ($tree->findnodes(q{//span[@class='nick_normal']})) {
        if (my $who = $elem->findvalue('./text()')) {
            $who =~ s!^\((.+)\)$!$1!; # (who) => who

            if (my $new_class = $self->_class($who)) {
                $elem->attr(class => $new_class);
            }
        }
    }

    $html = $tree->as_HTML();

    $tree = $tree->delete; # cleanup

    return ($req, decode_utf8($html));
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

