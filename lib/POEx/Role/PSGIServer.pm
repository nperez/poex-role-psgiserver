package POEx::Role::PSGIServer;
use MooseX::Declare;

role POEx::Role::PSGIServer
{
    use aliased 'POEx::Role::Event';
    use MooseX::Types::Moose(':all');
    use Moose::Autobox;
    use HTTP::Message::PSGI;
    use HTTP::Status qw(status_message);
    use Plack::Util;
    use POE::Filter::HTTP::Parser;
    use POE::Filter::Stream;
    use POEx::Role::PSGIServer::Types(':all');
    use POEx::Role::PSGIServer::Streamer;

    has psgi_app => (is => 'ro', isa => CodeRef, required => 1);

    after _start is Event
    {
        $self->filter(POE::Filter::HTTP::Parser->new(type => 'server'));
    }

    method write(PSGIServerContext $c, Str $data)
    {
        $c->{wheel}->put($data);
    }

    method write_chunked(PSGIServerContext $c, Str $data)
    {
        my $len = sprintf "%X", do { use bytes; length($data) };
        $self->write($c, "$len\r\n$data\r\n");
    }

    method close_chunked(PSGIServerContext $c)
    {
        $self->write($c, "0\r\n\r\n");
        $self->close_connection($c);
    }

    method close_connection(PSGIServerContext $c)
    {
        $c->{wheel}->shutdown_output();
        $self->delete_wheel((delete $c->{wheel})->ID);
    }

    method handle_socket_error(Str $action, Int $code, Str $message, WheelID $id) is Event
    {
        $self->delete_wheel($id);
    }

    method handle_listen_error(Str $action, Int $code, Str $message, WheelID $id) is Event
    {
    }

    method process_headers(PSGIServerContext $c, ArrayRef $headers)
    {
        {$headers->flatten}
            ->kv
            ->each
            (
                sub
                {   
                    $c->{keep_alive} = 0 if $_->[0] eq 'Connection' && $_->[1] eq 'close';
                    $c->{explicit_length} = 1 if $_->[0] eq 'Content-Length';
                    $c->{wheel}->put($_->[0].':'.$v."\r\n")
                }
            );
        
        $c->{chunked} = ($c->{keep_alive} && !exists($c->{explicit_length});    
    }

    method respond(PSGIServerContext $c, PSGIResponse $response) is Event
    {
        my ($code, $headers, $body) = @$response;
        
        $self->write($c, "$protocol $code ${ \status_message($code) }\r\n");
        $self->process_headers($c, $headers);

        my $no_body_allowed = ($c->{request}->method =~ /^head$/i)
            || ($code < 200)
            || ($code == 204)
            || ($code == 304);

        if ($no_body_allowed) {
            $self->write->($c, "\r\n");
            $self->close_connection($c);
            return;
        }

        $self->write->($c, "Transfer-Encoding: chunked\r\n") if $c->{chunked};
        $self->write->($c, "\r\n");

        if ($body)
        {
            if (Plack::Util::is_real_fh($body))
            {
                # destroy the old wheel, since the Streamer will build a new one
                $self->delete_wheel($c->{wheel}->ID);
                my $handle = (delete $c->{wheel})->get_intput_handle();

                POEx::Role::PSGIServer::Streamer->new
                (
                    input_handle => $body,
                    output_handle => $handle,
                    chunked => $chunked,
                );
            }
            else 
            {
                Plack::Util::foreach
                (
                    $body, 
                    (
                        $chunked 
                        ? sub { $self->write_chunked($c, $_) }
                        : sub { $self->write($c, $_) }
                    )
                );

                $chunked ? $self->close_chunked($c) : $self->close_connection($c);
            }

            return;
        }
    }

    method generate_psgi_env(PSGIServerContext $c)
    {
        return req_to_psgi
        (
            $c->{request},
            SERVER_NAME         => $self->listen_ip,
            SERVER_PORT         => $self->listen_port,
            SERVER_PROTOCOL     => $c->{protocol},
            'psgi.streaming'    => Plack::Util::TRUE,
            'psgi.nonblocking'  => Plack::Util::TRUE,
            'psgi.runonce'      => Plack::Util::FALSE,
        );
    }

    method handle_inbound_data(HTTPRequest $req, WheelID $wheel_id) is Event
    {
        my $version  = $req->header('X-HTTP-Version') || '0.9';
        my $protocol = "HTTP/$version";
        my $connection = $req->header('Connection') || '';
        my $keep_alive = $version eq '1.1' && $connection ne 'close';
        
        my $context =
        {
            request => $req,
            wheel => $self->get_wheel($wheel_id),
            version => $version,
            protocol => $connection,
            connection => $connection,
            keep_alive => $keep_alive,
        };

        my $response = Plack::Util::run_app($self->psgi_app, $self->generate_psgi_env($c));

        if (ref($response) eq 'CODE')
        {
            $response->(sub { $self->respond($context, @_) });
        }
        else
        {
            $self->yield('respond', $context, $response);
        }
    }

    with 'POEx::Role::TCPServer';
}
