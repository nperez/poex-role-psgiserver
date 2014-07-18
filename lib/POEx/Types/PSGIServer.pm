package POEx::Types::PSGIServer;

#ABSTRACT: Provides type constraints for use in POEx::Role::PSGIServer
use warnings;
use strict;

use MooseX::Types -declare => [qw/
    PSGIServerContext
    PSGIResponse
    PSGIBody
    HTTPRequest
    HTTPCode
/];

use MooseX::Types::Moose(':all');
use MooseX::Types::Structured(':all');
use POEx::Types(':all');
use HTTP::Request;
use HTTP::Status;
use Plack::Util;
use Scalar::Util;

=type PSGIServerContext

PSGIServerContext is defined as a Hash with the following keys:

    request => HTTPRequest,
    wheel => Optional[Wheel],
    version => Str,
    protocol => Str, 
    connection => Str,
    keep_alive => Bool,
    chunked => Optional[Bool],
    explicit_length => Optional[Bool],

The context is passed around to identify the current connection and what it is expecting

=cut

subtype PSGIServerContext,
    as Dict [
        request => HTTPRequest,
        wheel => Optional[Wheel],
        version => Str,
        protocol => Str, 
        connection => Str,
        keep_alive => Bool,
        chunked => Optional[Maybe[Bool]],
        explicit_length => Optional[Maybe[Bool]],
    ];

=type HTTPRequest

This is a simple class_type for HTTP::Request

=cut

subtype HTTPRequest,
    as class_type('HTTP::Request');

=type HTTPCode

This constraint uses HTTP::Status to check if the Int is a valid HTTP::Status code

=cut

subtype HTTPCode,
    as Int,
    where {
        HTTP::Status::is_info($_) 
        || HTTP::Status::is_success($_)
        || HTTP::Status::is_redirect($_)
        || HTTP::Status::is_error($_)
    };

=type PSGIBody

The PSGIBody constraint covers two of the three types of body responses valid for PGSI responses: a real filehandle or a blessed reference that duck-types getline and close

=cut

subtype PSGIBody,
    as Ref,
    where {
        Plack::Util::is_real_fh($_)
        || (Scalar::Util::blessed($_) && ($_->can('getline') && $_->can('close')))
    };

=type PSGIResponse

This constraint checks responses from PSGI applications for a valid HTTPCode, an ArrayRef of headers, and the Optional PSGIBody or ArrayRef body

=cut

subtype PSGIResponse,
    as Tuple [
        HTTPCode,
        ArrayRef,
        Optional[ArrayRef|PSGIBody]
    ];
1;
__END__
