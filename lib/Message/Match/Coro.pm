package Message::Match::Coro;
use Moose;

use Coro;
use Guard;

use Message::Match::Inbox;

use namespace::autoclean;

extends qw(Message::Match::Blocking); # FIXME role!

has '+read' => ( required => 0 );

has _inbox => (
    isa => "Message::Match::Inbox",
    is  => "ro",
    default => sub { Message::Match::Inbox->new },
    handles => [qw(match peek)],
);

before match => sub {
    my $self = shift;
    $self->read_all;
};

sub read_all {
    my $self = shift;

    while ( $self->_channel->size ) {
        my $message = $self->get_next();
        $self->_inbox->push( $message );
    }
}

sub size {
    my $self = shift;
    $self->_inbox->size + $self->_channel->size;
}

has _waiting => (
    #isa => "Bool",
    is  => "rw",
);

has _channel => (
    isa => "Coro::Channel",
    is  => "ro",
    default => sub { Coro::Channel->new },
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

    scope_guard { $self->_waiting(0) };
    $self->_waiting(1);

    $self->_channel->get;
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__;

__END__


# ex: set sw=4 et:
