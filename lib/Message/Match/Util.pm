package Message::Match::Util;

use 5.010;

use strict;
use warnings;

use namespace::autoclean;

sub splice_first {
    my ( $array, $filter ) = @_;

    my @buffer = @$array;

    my @checked;
    my $matched;

    outer: while ( @buffer ) {
        for ( shift @buffer ) {
            if ( $_ ~~ $filter ) {
                $matched = $_;
                last outer;
            } else {
                push @checked, $_;
            }
        }
    }

    @$array = ( @checked, @buffer );

    return $matched;
}

__PACKAGE__;

__END__


# ex: set sw=4 et:
