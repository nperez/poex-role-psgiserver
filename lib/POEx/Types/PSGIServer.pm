package POEx::Types::PSGIServer;
use warnings;
use strict;

use MooseX::Types -declare => 
[qw/
    PSGIServerContext
    PSGIResponse
    PSGIBody
    HTTPRequest
    HTTPCode
/];

use MooseX::Types::Moose(':all');
use MooseX::Types::Structured(':all');
use POEx::Types(':all');
use HTTP::Reqest;
use HTTP::Status;
use Plack::Util;
use Scalar::Util;

subtype PSGIServerContext,
    as Dict
    [
        request => HTTPRequest,
        wheel => Wheel,
        version => Str,
        protocol => Str, 
        connection => Str,
        keep_alive => Bool,
        chunked => Optional[Maybe[Bool]],
        explicit_length => Optional[Maybe[Bool]],
    ];

subtype HTTPRequest,
    as class_type('HTTP::Request');

subtype HTTPCode,
    as Int,
    where 
    {
        HTTP::Status::is_info($_) 
        || HTTP::Status::is_success($_)
        || HTTP::Status::is_redirect($_)
        || HTTP::Status::is_error($_)
    };

subtype PSGIBody,
    as Ref,
    where
    {
        Plack::Util::is_real_fh($_)
        || (Scalar::Util::blessed($_) && ($_->can('getline') && $_->can('close'))
    };

subtype PSGIResponse,
    as Tuple
    [
        HTTPCode,
        ArrayRef,
        PSGIBody
    ];
1;
__END__
