#!/usr/bin/env perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";

use AceyDeucey;

use IO::Capture::Stdout;
use Test::Most;

my $capture = IO::Capture::Stdout->new();
$capture->start();
my $game = AceyDeucey->new({ pot => 300, stake => 200 });
$capture->stop();
ok($game, q{generated new game});

subtest 'spread()' => sub {
    my $master_hand = _generate_master_hand($game);

    for my $pairs (
        [ 'AD', 'AC',  0 ],
        [ '2D', '7C',  5 ],
        [ 'AH', 'QS', 11 ],
        [ 'AS', 'KD',  1 ], ## This will be an ace-high test.
    ) {
        my $test_hand = $game->new_hand();

        ok($master_hand->give_a_card($test_hand, $pairs->[0])
            => qq{gave test hand $pairs->[0]}
        );
        ok($master_hand->give_a_card($test_hand, $pairs->[1])
            => qq{gave test hand $pairs->[1]}
        );

        if ( $pairs->[0] eq 'AS' ) {
            ok($test_hand->cards->[0]->{value} = '14'
                => q{set 'AS' as 'high'}
            );
        }

        ok($test_hand->spread() == $pairs->[2]
            => qq{spread is $pairs->[2]}
        );
    }
};

subtest 'is_pair()' => sub {
    my $master_hand = _generate_master_hand($game);

    for my $pairs (
        [ '2C', '2D',  1 ],
        [ '5H', '9C',  0 ],
    ) {
        my $test_hand = $game->new_hand();

        ok($master_hand->give_a_card($test_hand, $pairs->[0])
            => qq{gave test hand $pairs->[0]}
        );
        ok($master_hand->give_a_card($test_hand, $pairs->[1])
            => qq{gave test hand $pairs->[1]}
        );

        ok($test_hand->is_pair() == $pairs->[2],
            => q{is_pair() }.($pairs->[2] ? 'yes' : 'no')
        );
    }
};

subtest 'is_consecutive()' => sub {
    my $master_hand = _generate_master_hand($game);

    for my $pairs (
        [ '2C', '3D',  1 ],
        [ '4C', '3S',  1 ], # order shouldn't matter
        [ '5H', '9C',  0 ],
    ) {
        my $test_hand = $game->new_hand();

        ok($master_hand->give_a_card($test_hand, $pairs->[0])
            => qq{gave test hand $pairs->[0]}
        );
        ok($master_hand->give_a_card($test_hand, $pairs->[1])
            => qq{gave test hand $pairs->[1]}
        );

        ok($test_hand->is_consecutive() == $pairs->[2],
            => q{is_consecutive() }.($pairs->[2] ? 'yes' : 'no')
        );
    }
};

subtest 'is_pair_aces()' => sub {
    my $master_hand = _generate_master_hand($game);

    for my $pairs (
        [ 'AC', 'AD',  1 ],
        [ '2C', '3S',  0 ],
        [ 'KC', 'QC',  0 ],
    ) {
        my $test_hand = $game->new_hand();

        ok($master_hand->give_a_card($test_hand, $pairs->[0])
            => qq{gave test hand $pairs->[0]}
        );
        ok($master_hand->give_a_card($test_hand, $pairs->[1])
            => qq{gave test hand $pairs->[1]}
        );

        ok($test_hand->is_pair_aces() == $pairs->[2],
            => q{is_pair_aces() }.($pairs->[2] ? 'yes' : 'no')
        );
    }
};

subtest 'ace_first()' => sub {
    my $master_hand = _generate_master_hand($game);

    for my $pairs (
        [ 'AC', 'AD',  1 ],
        [ '5C', 'AS',  0 ],
    ) {
        my $test_hand = $game->new_hand();

        ok($master_hand->give_a_card($test_hand, $pairs->[0])
            => qq{gave test hand $pairs->[0]}
        );
        ok($master_hand->give_a_card($test_hand, $pairs->[1])
            => qq{gave test hand $pairs->[1]}
        );

        ok($test_hand->ace_first() == $pairs->[2],
            => q{ace_first() }.($pairs->[2] ? 'yes' : 'no')
        );
    }
};

subtest 'acey_deucey()' => sub {
    my $master_hand = _generate_master_hand($game);

    for my $pairs (
        [ 'AC', '2D',  1 ],
        [ '5C', 'AS',  0 ],
    ) {
        my $test_hand = $game->new_hand();

        ok($master_hand->give_a_card($test_hand, $pairs->[0])
            => qq{gave test hand $pairs->[0]}
        );
        ok($master_hand->give_a_card($test_hand, $pairs->[1])
            => qq{gave test hand $pairs->[1]}
        );

        ok($test_hand->acey_deucey() == $pairs->[2],
            => q{acey_deucey() }.($pairs->[2] ? 'yes' : 'no')
        );
    }
};

subtest 'set_ace_high() / is_ace_high()' => sub {
    my $master_hand = _generate_master_hand($game);

    my $test_hand = $game->new_hand();

    ok($master_hand->give_a_card($test_hand, 'AC')
        => q{gave test hand 'AC'}
    );

    ok($test_hand->set_ace_high() == 1
        => q{set AC low}
    );

    ok($test_hand->is_ace_high() == 0
        => q{is_ace_high() is false}
    );

    ok($test_hand->set_ace_high(1) == 14
        => q{set AC high}
    );
    ok($test_hand->is_ace_high() == 1
        => q{is_ace_high() is true}
    );

    ok($test_hand->set_ace_high() == 1
        => q{set AC low again}
    );
    ok($test_hand->is_ace_high() == 0
        => q{is_ace_high() is false again}
    );
};

$capture->start(); ## because compute_result() produces messages...
subtest 'compute_result()' => sub {
    subtest 'standard spread - low card first' => sub {
        my $master_hand = _generate_master_hand($game);

        my @hands = (
            ## following hands: 1st card is low
            { cards  => [ qw(4H 10C 8S) ],
              result => 0,
              msg    => 'winner',
            },
            {
              cards  => [ qw(5H 8C 10D) ],
              result => 1,
              msg    => 'loser',
            },
            {
              cards  => [ qw(6D JS JC) ],
              result => 2,
              msg    => 'loser - hit post (hi card)',
            },
            {
              cards  => [ qw(2C 9H 2D) ],
              result => 2,
              msg    => 'loser - hit post (lo card)',
            },
            ## following hands: 2nd card low

        );

        for my $hand ( @hands ) {
            my $test_hand = $game->new_hand();
            map { $master_hand->give_a_card($test_hand, $_) } @{ $hand->{cards} };

            ok($test_hand->compute_result() == $hand->{result}
                => $hand->{msg}
            );
        }
    };
    subtest 'standard spread - high card first' => sub {
        my $master_hand = _generate_master_hand($game);

        my @hands = (
            ## following hands: 1st card is low
            { cards  => [ qw(10C 4H 8S) ],
              result => 0,
              msg    => 'winner',
            },
            {
              cards  => [ qw(8C 5H 10D) ],
              result => 1,
              msg    => 'loser',
            },
            {
              cards  => [ qw(JS 6D JC) ],
              result => 2,
              msg    => 'loser - hit post (hi card)',
            },
            {
              cards  => [ qw(9H 2C 2D) ],
              result => 2,
              msg    => 'loser - hit post (lo card)',
            },
            ## following hands: 2nd card low

        );

        for my $hand ( @hands ) {
            my $test_hand = $game->new_hand();
            map { $master_hand->give_a_card($test_hand, $_) } @{ $hand->{cards} };

            ok($test_hand->compute_result() == $hand->{result}
                => $hand->{msg}
            );
        }
    };

    subtest 'post hits' => sub {
        my $master_hand = _generate_master_hand($game);

        my @hands = (
            ## following hands: 1st card is low
            { cards  => [ qw(5C 9H 9S) ],
              result => 2,
              msg    => 'hit standard post (low card first)',
            },
            { cards  => [ qw(10S KS 10D) ],
              result => 2,
              msg    => 'hit standard post (high card first)',
            },
            {
              cards  => [ qw(4C 5H 5D) ],
              result => 2,
              msg    => 'seqn post hit (low card first)',
            },
            {
              cards  => [ qw(8C 7D 8H) ],
              result => 2,
              msg    => 'seqn post hit (high card first)',
            },
            {
              cards  => [ qw(3C 3H 3D) ],
              result => 3,
              msg    => 'pair post hit',
            },
            {
              cards  => [ qw(AH AC AD) ],
              result => 4,
              msg    => 'ace pair post hit',
            },
            ## following hands: 2nd card low

        );

        for my $hand ( @hands ) {
            my $test_hand = $game->new_hand();
            map { $master_hand->give_a_card($test_hand, $_) } @{ $hand->{cards} };

            ok($test_hand->compute_result() == $hand->{result}
                => $hand->{msg}
            );
        }
    };

    subtest 'dealt pair - bet next is higher' => sub {
        my $master_hand = _generate_master_hand($game);

        my @hands = (
            ## following hands: 1st card is low
            { cards  => [ qw(10C 10D KS) ],
              hi_lo  => 'h',
              result => 0,
              msg    => 'winner',
            },
            {
              cards  => [ qw(9C 9H 5D) ],
              hi_lo  => 'h',
              result => 1,
              msg    => 'loser',
            },
        );

        for my $hand ( @hands ) {
            my $test_hand = $game->new_hand();
            map { $master_hand->give_a_card($test_hand, $_) } @{ $hand->{cards} };

            ok($test_hand->compute_result($hand->{hi_lo}) == $hand->{result}
                => $hand->{msg}
            );
        }
    };

    subtest 'dealt pair - bet next is lower' => sub {
        my $master_hand = _generate_master_hand($game);

        my @hands = (
            ## following hands: 1st card is low
            { cards  => [ qw(10C 10D KS) ],
              hi_lo  => 'l',
              result => 1,
              msg    => 'loser',
            },
            {
              cards  => [ qw(9C 9H 5D) ],
              hi_lo  => 'l',
              result => 0,
              msg    => 'winner',
            },
        );

        for my $hand ( @hands ) {
            my $test_hand = $game->new_hand();
            map { $master_hand->give_a_card($test_hand, $_) } @{ $hand->{cards} };

            ok($test_hand->compute_result($hand->{hi_lo}) == $hand->{result}
                => $hand->{msg}
            );
        }
    };

    subtest 'dealt consecutive - bet next is higher' => sub {
        my $master_hand = _generate_master_hand($game);

        my @hands = (
            ## following hands: 1st card is low
            { cards  => [ qw(10C JD KS) ],
              hi_lo  => 'h',
              result => 0,
              msg    => 'winner',
            },
            {
              cards  => [ qw(8C 9H 5D) ],
              hi_lo  => 'h',
              result => 1,
              msg    => 'loser',
            },
        );

        for my $hand ( @hands ) {
            my $test_hand = $game->new_hand();
            map { $master_hand->give_a_card($test_hand, $_) } @{ $hand->{cards} };

            ok($test_hand->compute_result($hand->{hi_lo}) == $hand->{result}
                => $hand->{msg}
            );
        }
    };

    subtest 'dealt consecutive - bet next is lower' => sub {
        my $master_hand = _generate_master_hand($game);

        my @hands = (
            ## following hands: 1st card is low
            { cards  => [ qw(10C JD KS) ],
              hi_lo  => 'l',
              result => 1,
              msg    => 'loser',
            },
            {
              cards  => [ qw(8C 9H 5D) ],
              hi_lo  => 'l',
              result => 0,
              msg    => 'winner',
            },
        );

        for my $hand ( @hands ) {
            my $test_hand = $game->new_hand();
            map { $master_hand->give_a_card($test_hand, $_) } @{ $hand->{cards} };

            ok($test_hand->compute_result($hand->{hi_lo}) == $hand->{result}
                => $hand->{msg}
            );
        }
    };

};
$capture->stop();

## A $deck object cannot give_a_card() to put a specific card into a
## test hand.  To work around this, we deal the entire unshuffled $deck
## to a $master_hand.  We can then tell $master_hand to give specific
## cards to $test_hand in order to make the test results predictable.
sub _generate_master_hand {
    my ( $game ) = @_;

    my $deck = $game->new_deck(); # new deck is always unshuffled! :-)
    my $hand = $game->new_hand(); #

    $deck->give_cards($hand, 'all');

    return $hand;
}





done_testing();

