#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use ok 'Message::Match::AnyEvent';

{
    my $receiver = Message::Match::AnyEvent->new;

    my $w = AE::timer 0.01, 0, sub { $receiver->push("timer") };

    ok( not($receiver->peek(qr/timer/)), "no match for timer" );
    ok( not($receiver->match(qr/timer/)), "no match for timer" );

    for ( AE::cv() ) {
        my $w = AE::timer 0.02, 0, $_;
        $_->recv;
    }

    is( $receiver->peek(qr/timer/), "timer", "match for timer" );
    is( $receiver->match(qr/timer/), "timer", "match for timer" );
}

{
    my $receiver = Message::Match::AnyEvent->new;

    my $w = AE::timer 0.01, 0, sub { $receiver->push("timer") };

    my $cv = $receiver->receive_cv(qr/timer/);

    isa_ok($cv, "AnyEvent::CondVar");

    ok( !$cv->ready, "not yet ready" );

    is( $cv->recv, "timer", "received event" );
}

{
    my $receiver = Message::Match::AnyEvent->new;

    my $w1 = AE::timer 0.03, 0, sub { $receiver->push([ "timer" => "a" ]) };
    my $w2 = AE::timer 0.01, 0, sub { $receiver->push([ "timer" => "b" ]) };

    my $cv1 = $receiver->receive_cv([ timer => "a" ]);
    my $cv2 = $receiver->receive_cv([ timer => "b" ]);

    ok( !$_->ready, "not yet ready" ) for $cv1, $cv2;

    isa_ok($_, "AnyEvent::CondVar") for $cv1, $cv2;

    for ( AE::cv() ) {
        my $w = AE::timer 0.01, 0, $_;
        $_->recv;
    }

    ok( $cv2->ready, "cv2 ready" );
    ok( not($cv1->ready), "cv1 not yet ready" );

    for ( AE::cv() ) {
        my $w = AE::timer 0.02, 0, $_;
        $_->recv;
    }

    ok( $cv1->ready, "cv1 ready" );

    is_deeply( $cv1->recv, [ "timer" => "a" ], "received event" );
    is_deeply( $cv2->recv, [ "timer" => "b" ], "received event" );
}

{
    my $receiver = Message::Match::AnyEvent->new;

    my $w1 = AE::timer 0.02, 0, sub { $receiver->push([ "timer" => "a" ]) };
    my $w2 = AE::timer 0.01, 0, sub { $receiver->push([ "timer" => "b" ]) };

    for ( AE::cv() ) {
        my $w = AE::timer 0.03, 0, $_;
        $_->recv;
    }

    my $cv1 = $receiver->receive_cv([ timer => "a" ]);
    my $cv2 = $receiver->receive_cv([ timer => "b" ]);

    ok( $cv1->ready, "cv1 ready" );
    ok( $cv2->ready, "cv2 ready" );

    is_deeply( $cv1->recv, [ "timer" => "a" ], "received event" );
    is_deeply( $cv2->recv, [ "timer" => "b" ], "received event" );
}

{
    my $receiver = Message::Match::AnyEvent->new;

    my $counter;

    my $w;
    $w = AE::timer 0.005, 0.005, sub {
        $receiver->push([ "timer" => ++$counter ]);
        undef $w if $counter >= 4;
    };

    my $cv1 = $receiver->receive_cv([ timer => 2 ]);

    my $cv2 = AE::cv;
    $cv2 = $receiver->receive_cv([ timer => qr/\d+/ ], $cv2);

    is_deeply( $cv1->recv, [ timer => 2 ], "filter for timer 2" );
    is_deeply( $cv2->recv, [ timer => 1 ], "filter for timer 1" );

    ok( not( $receiver->peek([ timer => 1 ]) ), "no timer 1 in queue" );
    ok( not( $receiver->peek([ timer => 2 ]) ), "no timer 2 in queue" );
    ok( not( $receiver->peek([ timer => 3 ]) ), "no timer 3 in queue" );
    ok( not( $receiver->peek([ timer => 4 ]) ), "no timer 4 in queue" );

    for ( AE::cv() ) {
        my $w = AE::timer 0.02, 0, $_;
        $_->recv;
    }

    ok( $receiver->peek([ timer => 3 ]), "timer 3 in queue" );
    ok( $receiver->peek([ timer => 4 ]), "timer 4 in queue" );

    is_deeply( $receiver->receive(sub { 1 }), [ timer => 3 ], "recv any gives timer 3" );
    is_deeply( $receiver->receive(sub { 1 }), [ timer => 4 ], "recv any gives timer 4" );

    my $cv = AE::cv();
    $receiver->receive_cv(sub { 1 }, $cv);

    my $timeout = AE::timer 0.01, 0, sub { $cv->send("abort") };

    is_deeply( $cv->recv, "abort", "timed out waiting for more events" );
}


done_testing;

# ex: set sw=4 et:

