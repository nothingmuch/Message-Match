package Message::Match::Inbox;
use Moose;

use Message::Match::Util;

use MooseX::Types::Moose qw(ArrayRef);

use namespace::autoclean;

has _buffer => (
    traits => [qw(Array)],
    isa => ArrayRef,
    is  => "ro",
    default => sub { [] },
    handles => {
        push => "push",
    },
);

sub peek {
    my ( $self, $filter ) = @_;

    for ( @{ $self->_buffer } ) {
        return $_ if $_ ~~ $filter;
    }
}

sub match {
    my ( $self, $filter ) = @_;

    $filter ||= sub { 1 };

    Message::Match::Util::splice_first($self->_buffer, $filter);
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__;

__END__


# ex: set sw=4 et:
