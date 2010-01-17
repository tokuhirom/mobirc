#!/usr/bin/perl

package HTTP::Engine::Role::RequestBuilder::HTTPBody;
use Any::Moose '::Role';

with qw(
    HTTP::Engine::Role::RequestBuilder::ReadBody
);
use HTTP::Body;
use HTTP::Engine::Request::Upload;

# tempolary file path for upload file.
has upload_tmp => (
    is => 'rw',
);

has chunk_size => (
    is      => 'ro',
    isa     => 'Int',
    default => 4096,
);

sub _build_http_body {
    my ( $self, $req ) = @_;

    $self->_read_to_end($req->_read_state);

    return delete $req->_read_state->{data}{http_body};
}

sub _build_raw_body {
    my ( $self, $req ) = @_;

    $self->_read_to_end($req->_read_state);

    return delete $req->_read_state->{data}{raw_body};
}


sub _build_read_state {
    my($self, $req) = @_;

    my $length = $req->content_length || 0;
    my $type   = $req->header('Content-Type');

    my $body = HTTP::Body->new($type, $length);
    $body->tmpdir( $self->upload_tmp) if $self->upload_tmp;

    return $self->_read_init({
        input_handle   => $req->_connection->{input_handle},
        content_length => $length,
        read_position  => 0,
        data => {
            raw_body      => "",
            http_body     => $body,
        },
    });
}

sub _handle_read_chunk {
    my ( $self, $state, $chunk ) = @_;

    my $d = $state->{data};

    $d->{raw_body} .= $chunk;
    $d->{http_body}->add($chunk);
}

sub _prepare_uploads  {
    my($self, $req) = @_;

    my $uploads = $req->http_body->upload;
    my %uploads;
    for my $name (keys %{ $uploads }) {
        my $files = $uploads->{$name};
        $files = ref $files eq 'ARRAY' ? $files : [$files];

        my @uploads;
        for my $upload (@{ $files }) {
            my $headers = HTTP::Headers::Fast->new( %{ $upload->{headers} } );
            push(
                @uploads,
                HTTP::Engine::Request::Upload->new(
                    headers  => $headers,
                    tempname => $upload->{tempname},
                    size     => $upload->{size},
                    filename => $upload->{filename},
                )
            );
        }
        $uploads{$name} = @uploads > 1 ? \@uploads : $uploads[0];

        # support access to the filename as a normal param
        my @filenames = map { $_->{filename} } @uploads;
        $req->parameters->{$name} =  @filenames > 1 ? \@filenames : $filenames[0];
    }
    return \%uploads;
}

1;

