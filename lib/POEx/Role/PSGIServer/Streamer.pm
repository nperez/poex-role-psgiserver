package POEx::Role::PSGIServer::Streamer;

# Provides streaming filehandle PSGI implementation
use MooseX::Declare;

class POEx::Role::PSGIServer::Streamer
{
    use POE::Filter::Map;
    use POE::Filter::Stream;
    use MooseX::Types::Moose(':all');

    has chunked => ( is => 'ro', isa => Bool, default => 0 );
    has closed_chunk => ( is => 'rw', isa => Bool, default => 0 );

    with 'POEx::Role::Streaming';

    method _build_filter
    {
        if($self->chunked)
        {
            POE::Filter::Map->new
            (
                Get => sub { $_ },
                Put => sub
                { 
                    my $data = shift;
                    my $len = sprintf "%X", do { use bytes; length($data) };
                    return "$len\r\n$data\r\n";
                }
            );
        }
        else
        {
            return POE::Filter::Stream->new();
        }
    }

    around done_writing
    {
        if($self->chunked && !$self->closed_chunk)
        {
            $self->closed_chunk(1);
            $self->put("0\r\n\r\n");
            return;
        }

        $self->$orig;
    }
}

1;
__END__
