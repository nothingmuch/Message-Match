package Message::Match::Actor::Coro;
use Moose::Role;

use Coro;

use Message::Match::Coro;

use namespace::autoclean;

has messages => (
    isa => "Message::Match::Coro",
    is  => "ro",
    default => sub { Message::Match::Coro->new },
    handles => {
        message => "push",
        receive => "receive",
    },
);

sub start {
    my $self = shift;

    async { $self->run }
}

requires "run";

__PACKAGE__;

__END__


# ex: set sw=4 et:
