package Message::Match::Blocking;
use Moose;

use MooseX::Types::Moose qw(CodeRef);

use Message::Match::Inbox;

use namespace::autoclean;

has read => (
    isa => CodeRef,
    is  => "ro",
    required => 1,
);

has _inbox => (
    isa => "Message::Match::Inbox",
    is  => "ro",
    default => sub { Message::Match::Inbox->new },
    handles => [qw(match peek push)],
);

sub receive {
    my ( $self, $filter ) = @_;

    $filter ||= sub { 1 };

    loop: {
        if ( defined( my $message = $self->_inbox->match($filter) ) ) {
            return $message;
        } else {
            my $message = $self->get_next();

            if ( $message ~~ $filter ) {
                return $message;
            } else {
                $self->push( $message );
                redo loop;
            }
        }
    }
}

sub get_next {
    my $self = shift;
    $self->read->();
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__;

__END__


# ex: set sw=4 et:
