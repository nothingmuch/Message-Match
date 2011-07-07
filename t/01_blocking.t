#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use ok 'Message::Match::Blocking';


{
    my $counter;
    my $receiver = Message::Match::Blocking->new( read => sub { [ timer => ++$counter ] } );

    $receiver->push({ hi => "moose" });

    is_deeply( $receiver->receive([ timer => 3 ]), [ timer => 3 ], "receive 3rd read" );

    is( $counter, 3, "counter incremented" );

    is_deeply( $receiver->receive([ timer => sub { 1 } ]), [ timer => 1 ], "receive 1st read" );

    is_deeply( $receiver->receive(sub { 1 }), { hi => "moose" }, "receive first message in queue" );

    is_deeply( $receiver->receive([ timer => sub { 1 } ]), [ timer => 2 ], "receive 2nd read" );

    is( $counter, 3, "counter not incremented" );

    is_deeply( $receiver->receive([ timer => sub { 1 } ]), [ timer => 4 ], "receive 4th read" );

    is( $counter, 4, "counter incremented" );
}

done_testing;

# ex: set sw=4 et:

