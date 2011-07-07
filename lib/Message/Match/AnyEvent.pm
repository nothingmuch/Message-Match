package Message::Match::AnyEvent; # Control::AnyEvent
use Moose;

use AnyEvent;
use Scalar::Util qw(reftype);

use Message::Match::Inbox;
use Message::Match::Util;

sub _invoke;

use namespace::clean;

has _inbox => (
    isa => "Message::Match::Inbox",
    is  => "ro",
    default => sub { Message::Match::Inbox->new },
    handles => [qw(match peek)],
);

has _filters => (
    traits => [qw(Array)],
    isa => "ArrayRef",
    is  => "ro",
    default => sub { [] },
    handles => {
        _get_filters => "get",
        _push_filter => "push",
    },
);

sub _invoke ($$) {
    my ( $cb, $message ) = @_;

    if ( reftype($cb) eq 'CODE' and not blessed($cb) ) {
        $message->$cb;
    } else {
        $cb->send($message);
    }

    return $cb;
}

sub push {
    my ( $self, $message ) = @_;

    if ( my $matching_filter = Message::Match::Util::splice_first(
        $self->_filters,
        sub {
            my $filter = $_->{filter};
            return $message ~~ $filter;
        },
    ) ) {
        _invoke($matching_filter->{cb}, $message);
    } else {
        $self->_inbox->push($message);
    }
}

sub push_cb {
    my $self = shift;

    return sub { $self->push(@_) };
}

sub receive_cv {
    my ( $self, $filter, $cb ) = @_;

    $filter ||= sub { 1 };

    $cb ||= AE::cv();

    if ( defined( my $message = $self->_inbox->match($filter) ) ) {
        _invoke($cb, $message);
    } else {
        $self->wait($filter, $cb);
    }

    return $cb;
}

sub receive {
    my ( $self, @args ) = @_;

    return $self->receive_cv(@args)->recv;
}

sub wait {
    my ( $self, $filter, $cb ) = @_;
    
    my $cv ||= AE::cv();

    $self->_push_filter({ filter => $filter, cb => $cb });
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__;

__END__


# ex: set sw=4 et:
