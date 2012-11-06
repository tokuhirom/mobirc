package App::Mobirc::Plugin::ExpireHeader;
use strict;
use warnings;
use App::Mobirc::Plugin;
use App::Mobirc::Util;
use App::Mobirc::Web::Handler;
use Encode;
use Params::Validate ':all';
use App::Mobirc::Validator;
use HTML::TreeBuilder::XPath;
use DateTime;
use DateTime::Format::HTTP;

my $time = time;

hook request_filter => sub {
    my ($self, $global_context, $req) = validate_hook('request_filter', @_);

    my $path = $req->uri->path;
    if ($path =~ m{^/static/\d+-(.+)$}) {
        $path = "/static/$1";
    }

    $req->uri->path($path);
};


hook response_filter => sub {
    my ($self, $global_context, $res) = validate_hook('response_filter', @_);

    my $req = App::Mobirc::Web::Handler->web_context->req;
    my $path = $req->uri->path;
    if ($path =~ m{^/static/}) {
        my $etag =  "'$time'";
        $res->header("Cache-Control" => "public; max-age=315360000; s-maxage=315360000");
        $res->header(Expires => DateTime::Format::HTTP->format_datetime(DateTime->now->add(years => 10)));
        $res->header(ETag => $etag);

        if (($req->header('If-None-Match') || "") eq $etag) {
            $res->status(304);
            $res->body("");
        }
    }
};

hook html_filter => sub {
    my ($self, $global_context, $req, $content) = validate_hook('html_filter', @_);
    DEBUG "CONTENT IS UTF* : " . Encode::is_utf8($content);

    my $tree = HTML::TreeBuilder::XPath->new;
    $tree->parse_content($content);

    for my $elem ($tree->findnodes('//link')) {
        my $path = $elem->attr('href');
        $path =~ s{/static/(.+)}{/static/$time-$1};
        $elem->attr(href => $path);
    }
    for my $elem ($tree->findnodes('//script')) {
        if (my $path = $elem->attr('src')) {
            $path =~ s{/static/(.+)}{/static/$time-$1};
            $elem->attr(src => $path);
        }
    }

    my $html = $tree->as_HTML(q[<>&"'{}]);
    $tree = $tree->delete;

    return ($req, decode_utf8($html));
};

1;
