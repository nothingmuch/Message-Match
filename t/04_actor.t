#!/usr/bin/perl

use strict;
use warnings;

use 5.010;

use Test::More;

use Coro;
use Coro::Timer qw(sleep);

my ($set,$cleared) = ( 0, 0 );

{
    package MockActor;
    use Moose;

    use Scalar::Util qw(refaddr);

    with qw(Message::Match::Actor::Coro);

    use overload '""' => sub { shift->name };

    my $i;
    has name => (
        isa => "Str",
        is  => "ro",
        default => sub { ++$i },
    );

    has friend => (
        isa => __PACKAGE__,
        is  => "ro",
        writer => "set_friend",
        predicate => "has_friend",
        clearer => "clear_friend",
    );

    after clear_friend => sub { $cleared++ };
    after set_friend => sub { $set++ };

    sub run {
        my $self = shift;

        while ( 1 ) {
            Coro::cede();
            unless ( $self->has_friend ) {
                given ( $self->receive([ qr/exit|make_friend|friended/, sub { 1 } ]) ) {
                    when ([ "exit", sub { 1 } ]) { Coro::terminate() };
                    when ([ "make_friend", sub { 1 } ]) {
                        my $friend = $_->[1];
                        $self->set_friend($friend);
                        $friend->message([ friended => $self ]);
                    };
                    when ([ "friended", sub { 1 } ]) {
                        my $friend = $_->[1];
                        $self->set_friend($friend);
                        $friend->message([ chat => [ $self, 1 ] ]);
                    };
                    default { ::fail("oh noes" ); Coro::terminate() };
                }
            } else {
                given ( $self->receive([ qr/breakup|exit|chat/, sub { 1 } ]) ) {
                    when ([ "exit", sub { 1 } ]) { Coro::terminate() };
                    when ([ "breakup", sub { 1 } ]) { $self->clear_friend };
                    when ([ "chat", sub { 1 } ]) {
                        my ( $friend, $i ) = @{ $_->[1] };
                        ::fail("not talking with friend") if refaddr($friend) != refaddr($self->friend);
                        if ( $i < 3 ) {
                            $self->friend->message([ chat => [ $self, $i + 1 ] ]);
                        } else {
                            $self->friend->message([ "breakup", $self ]);
                            $self->clear_friend;
                        }
                    }
                    default { fail("oh noes" ); Coro::terminate() };
                }
            }
        }
    }
}

my ( $a1, $a2, $a3 ) = map { my $_ = MockActor->new; $_->start; $_ } 1 .. 3;

$a1->message([ make_friend => $a2 ]);

cede until $set and not grep { $_->has_friend } $a2, $a2, $a3;

is( $cleared, 2 );


$set = 0;
$cleared = 0;




$a1->message([ make_friend => $a2 ]);
$a1->message([ make_friend => $a3 ]);

cede until $set == 4 and not grep { $_->has_friend } $a1, $a2, $a3;

is( $cleared, 4 );


$set = 0;
$cleared = 0;



$a1->message([ make_friend => $a2 ]);
$a2->message([ make_friend => $a3 ]);
$a3->message([ make_friend => $a1 ]);
$a3->message([ make_friend => $a2 ]);

cede until $set == 8 and not grep { $_->has_friend } $a1, $a2, $a3;

is( $cleared, 8 );


$_->message([ exit => 1 ]) for $a1, $a2, $a3;

done_testing;

# ex: set sw=4 et:

