package POEx::Role::PSGIServer::ProxyWriter;

#ABSTRACT: Provides a push writer for PSGI applications to use
use MooseX::Declare;

class POEx::Role::PSGIServer::ProxyWriter {
    use MooseX::Types::Moose(':all');
    use POEx::Types::PSGIServer(':all');

=attribute_public server_context

    is: ro, isa: PSGIServerContext, required: 1

This is the server context from POEx::Role::PSGIServer. It is needed to determine the semantics of the current request

=cut

    has server_context => (
        is => 'ro',
        isa => PSGIServerContext,
        required => 1
    );

=attribute_public proxied

    is: ro, isa: Object, weak_ref: 1, required: 1

This is the actual object that consumes POEx::Role::PSGIServer. It is weakened to make sure it is properly collected when the connection closes

=cut

    has proxied => (
        is => 'ro',
        isa => Object,
        weak_ref => 1,
        required => 1,
    );

=method_public write

    ($data)

write proxies to the weakened PSGIServer consumer object passing along the L</server_context>

=cut

    method write($data) {
        $self->proxied->write($self->server_context, $data);
    }

=method_public close

close is proxied to the weakened PSGIServer consumer passing along L</server_context>

=cut

    method close() {
        $self->proxied->close($self->server_context);
    }

=method_public poll_cb

    (CodeRef $coderef)

poll_cb is provided to complete the interface. The first argument to $coderef will be $self

=cut

    method poll_cb(CodeRef $coderef) {
        my $on_flush = sub { $self->$coderef() };
        my $id = $self->server_context->{wheel}->ID;
        $self->proxied->set_wheel_flusher($id => $on_flush);
        $on_flush->();
    }
}
1;
__END__
