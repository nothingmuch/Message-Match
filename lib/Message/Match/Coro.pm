package Message::Match::Coro;
use Moose;

use Coro;

use Message::Match::Inbox;

use namespace::autoclean;

extends qw(Message::Match::Blocking);

has '+read' => ( required => 0 );

has _inbox => (
    isa => "Message::Match::Inbox",
    is  => "ro",
    default => sub { Message::Match::Inbox->new },
    handles => [qw(match peek)],
);

has _waiting => (
    isa => "Bool",
    is  => "rw",
);

has _channel => (
    isa => "Coro::Channel",
    is  => "ro",
    default => sub { Coro::Channel->new(1) },
);

sub push {
    my ( $self, $message ) = @_;

    if ( $self->_waiting ) {
        $self->_channel->put($message);
    } else {
        $self->_inbox->push($message);
    }
}

sub get_next {
    my $self = shift;

    $self->_waiting(1);
    my $message = $self->_channel->get;
    $self->_waiting(0);

    return $message;
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__;

__END__


# ex: set sw=4 et:
