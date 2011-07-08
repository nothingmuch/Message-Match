#!/usr/bin/perl

use strict;
use warnings;

use 5.010;

use Test::More;
use Try::Tiny;

BEGIN {
    try {
        require Smart::Match; Smart::Match->VERSION(0.004);
        require Smart::Match::Bind;
    } catch { plan 'skip_all' => "Smart::Match 0.004 and Smart::Match::Bind required" };
}

use Coro;
use Coro::Timer qw(sleep);
use List::Util qw(shuffle);

my ($set,$cleared) = ( 0, 0 );

our $cede_at_start = 0;

{
    package MockActor;
    use Moose;

    use Coro;
    use Smart::Match qw(:all);
    use Smart::Match::Bind qw(:all);

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

        cede if $::cede_at_start;
        
        while ( 1 ) {
            if ( $self->has_friend ) {
                $self->talk_with_friend;
            } else {
                $self->wait_for_friend;
            }
        }
    }

    sub wait_for_friend {
        my $self = shift;

        given ( $self->receive(sub_hash({ type => qr(exit|make_friend|friended) })) ) {
            when ($_ ~~ sub_hash({ type => "exit" })) { Coro::terminate() };
            when ($_ ~~ binding(sub_hash({
                type => "make_friend",
                friend => let(my $friend, true()),
            }))) {
                $self->establish_friendship($friend);
            };
            when ($_ ~~ binding(sub_hash({
                type => "friended",
                friend => let(my $friend, true()),
            }))) {
                $self->respond_to_friendship($friend);
            };
            default { ::fail("oh noes" ); Coro::terminate() };
        }
    }

    sub establish_friendship {
        my ( $self, $friend ) = @_;

        $self->set_friend($friend);
        $friend->message({ type => "friended", friend => $self });
    }

    sub respond_to_friendship {
        my ( $self, $friend ) = @_;

        $self->set_friend($friend);
        $friend->message({ type => "chat", friend => $self, i => 1 });
    }

    sub talk_with_friend {
        my $self = shift;

        given ( $self->receive(sub_hash({ type => qr(exit|breakup|chat) })) ) {
            when ($_ ~~ sub_hash({ type => "exit" })) { Coro::terminate() };
            when ($_ ~~ sub_hash({ type => "breakup" })) { $self->clear_friend };
            when ($_ ~~ binding(sub_hash({
                type => "chat",
                friend => let(my $friend, true()),
                i      => let(my $i, qr/\d+/),
            }))) {
                ::fail("not talking with friend") if refaddr($friend) != refaddr($self->friend);

                if ( $i < 2 + rand(10) ) {
                    $self->friend->message({ type => "chat", friend => $self, i => $i + 1 });
                } else {
                    $self->friend->message({ type => "breakup", friend => $self });
                    $self->clear_friend;
                }
            }
            default { ::fail("oh noes ". Dumper($_) ); Coro::terminate() }; use Data::Dumper;
        }
    }
}


alarm 2;

my @actors;
sub wait_for_silence {
    cede while grep { $_->messages->size or $_->has_friend } @actors;
}

for $cede_at_start ( 0, 1 ) {

    my ( $a1, $a2, $a3 ) = @actors = map { my $_ = MockActor->new; $_ } 1 .. 3;

    $_->start for @actors;

    $set = 0;
    $cleared = 0;

    $a1->message({ type => "make_friend", friend => $a2 });

    wait_for_silence();

    is( $set, 2 );
    is( $cleared, 2 );


    $set = 0;
    $cleared = 0;



    $a1->message({ type => "make_friend", friend => $a2 });
    $a1->message({ type => "make_friend", friend => $a3 });
    $a1->message({ type => "make_friend", friend => $a2 });

    wait_for_silence();

    is( $set, 6 );
    is( $cleared, 6 );

    $_->message({ type => "exit" }) for @actors;

    wait_for_silence();
}

done_testing;

# ex: set sw=4 et:

