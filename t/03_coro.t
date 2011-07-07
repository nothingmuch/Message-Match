#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use Try::Tiny;
use Coro;
use Coro::Timer qw(sleep);

use ok 'Message::Match::Coro';

{
    my $channel = Message::Match::Coro->new;

    async {
        for ( 1 .. 3 ) {
            sleep(0.05);
            $channel->push("foo");
        }
    };

    async {
        sleep(0.03);
        $channel->push("bar");
    };

    async {
        for ( 1 .. 12 ) {
            sleep(0.02);
            $channel->push("baz");
        }

        $channel->push("done");
    };

    ok( not($channel->peek(qr/./)), "nothing inside" );

    is_deeply( $channel->receive(qr/ba./), "baz", "baz" );
    is_deeply( $channel->receive(qr/ba./), "bar", "bar" );
    is_deeply( $channel->receive(qr/./), "baz", "baz" );
    is_deeply( $channel->receive(qr/./), "foo", "baz" );
    is_deeply( $channel->receive(qr/foo/), "foo", "foo" );
    is_deeply( $channel->receive(qr/./), "baz", "baz" );
    is_deeply( $channel->receive("baz"), "baz", "baz" );
    is_deeply( $channel->receive("baz"), "baz", "baz" );
    is_deeply( $channel->receive("baz"), "baz", "baz" );
    is_deeply( $channel->receive("baz"), "baz", "baz" );
    is_deeply( $channel->receive("baz"), "baz", "baz" );
    is_deeply( $channel->receive("baz"), "baz", "baz" );
    is_deeply( $channel->receive("baz"), "baz", "baz" );
    is_deeply( $channel->receive(qr/./), "foo", "foo" );

    ok( not($channel->peek(qr/./)), "nothing inside" );

    sleep(0.04);

    ok( $channel->peek("baz"), "more baz inside" );

    try {
        local $SIG{ALRM} = sub { die "timeout" };
        alarm 1;
        pass("more data") until $channel->receive eq "done";
        alarm 0;
    } catch {
        fail("timeout");
    };
}
    

done_testing;

# ex: set sw=4 et:

