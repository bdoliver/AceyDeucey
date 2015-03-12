#!/usr/bin/env perl

use strict;
use warnings;

use FindBin;
use Test::Most;

use lib "$FindBin::Bin/../lib";

use AceyDeucey;


my $game = AceyDeucey->new({stake => 200 });
ok($game, q{generated new game});

subtest 'hi_lo' => sub {
    my $master_hand = _generate_master_hand($game);

    ok($master_hand->hi_or_lo('l')
        => q{set bet low}
    );

    ok($master_hand->is_bet_low(), "bet is low");

    ok($master_hand->hi_or_lo('h')
        => q{set bet high}
    );

    ok($master_hand->is_bet_high(), "bet is high");

};

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

subtest 'compute_result()' => sub {
    subtest 'standard spread - low card first' => sub {
        my $master_hand = _generate_master_hand($game);

        my @hands = (
            { cards  => [ qw(4H 10C 8S) ],
              result => { win => 1,
                          msg => 'Winner! 3rd card is between posts!',
                        },
              msg    => 'winner',
            },
            {
              cards  => [ qw(5H 8C 10D) ],
              result => { loss => 1,
                          msg  => 'Loser! 3rd card is outside posts!',
                        },
              msg    => 'loser',
            },
            {
              cards  => [ qw(6D JC JS) ],
              result => { loss => 2,
                          msg  => 'Loser! 3rd card hit a post - bet is doubled!',
                        },
              msg    => 'loser - hit post (hi card)',
            },
            {
              cards  => [ qw(2C 9H 2D) ],
              result => { loss => 2,
                          msg  => 'Loser! 3rd card hit a post - bet is doubled!',
                        },
              msg    => 'loser - hit post (lo card)',
            },
        );

        for my $hand ( @hands ) {
            my $test_hand = $game->new_hand();
            map { $master_hand->give_a_card($test_hand, $_) } @{ $hand->{cards} };

            is_deeply($test_hand->compute_result(), $hand->{result},
                => $hand->{msg}
            );
        }
    };
    subtest 'standard spread - high card first' => sub {
        my $master_hand = _generate_master_hand($game);

        my @hands = (
            { cards  => [ qw(10C 4H 8S) ],
              result => { win => 1,
                          msg => 'Winner! 3rd card is between posts!',
                        },
              msg    => 'winner',
            },
            {
              cards  => [ qw(8C 5H 10D) ],
              result => { loss => 1,
                          msg  => 'Loser! 3rd card is outside posts!',
                        },
              msg    => 'loser',
            },
            {
              cards  => [ qw(JS 6D JC) ],
              result => { loss => 2,
                          msg  => 'Loser! 3rd card hit a post - bet is doubled!',
                        },
              msg    => 'loser - hit post (hi card)',
            },
            {
              cards  => [ qw(9H 2D 2C) ],
              result => { loss => 2,
                          msg  => 'Loser! 3rd card hit a post - bet is doubled!',
                        },
              msg    => 'loser - hit post (lo card)',
            },
        );

        for my $hand ( @hands ) {
            my $test_hand = $game->new_hand();
            map { $master_hand->give_a_card($test_hand, $_) } @{ $hand->{cards} };

            is_deeply($test_hand->compute_result(), $hand->{result},
                => $hand->{msg}
            );
        }
    };

    subtest 'post hits' => sub {
        my $master_hand = _generate_master_hand($game);

        my @hands = (
            { cards  => [ qw(5C 9S 9H) ],
              result => { loss => 2,
                          msg  => 'Loser! 3rd card hit a post - bet is doubled!',
                        },
              msg    => 'hit standard post (low card first)',
            },
            { cards  => [ qw(KS 10S 10D) ],
              result => { loss => 2,
                          msg  => 'Loser! 3rd card hit a post - bet is doubled!',
                        },
              msg    => 'hit standard post (high card first)',
            },
            {
              cards  => [ qw(4C 5D 5H) ],
              result => { loss => 2,
                          msg  => 'Loser! 3rd card hit a post - bet is doubled!',
                        },
              msg    => 'seqn post hit (low card first)',
            },
            {
              cards  => [ qw(8C 7D 8H) ],
              result => { loss => 2,
                          msg  => 'Loser! 3rd card hit a post - bet is doubled!',
                        },
              msg    => 'seqn post hit (high card first)',
            },
            {
              cards  => [ qw(3C 3D 3H) ],
              result => { loss => 3,
                          msg  => 'Loser! 3rd card hit a pair post - bet is tripled!',
                        },
              msg    => 'pair post hit',
            },
            {
              cards  => [ qw(AH AD AC) ],
              result => { loss => 4,
                          msg  => 'Loser! 3rd card hit an ACE post - bet is quadrupled!',
                        },
              msg    => 'ace pair post hit',
            },
            {
              cards  => [ qw(AS 2D 2C) ],
              result => { loss => 4,
                          msg  => 'Loser! 3rd card hit an acey-deucey post - bet is quadrupled!',
                        },
              msg    => 'acey-deucey post hit',
            },
        );

        for my $hand ( @hands ) {
            my $test_hand = $game->new_hand();
            map { $master_hand->give_a_card($test_hand, $_) } @{ $hand->{cards} };

            is_deeply($test_hand->compute_result(), $hand->{result},
                => $hand->{msg}
            );
        }
    };

    subtest 'dealt pair - bet next is higher' => sub {
        my $master_hand = _generate_master_hand($game);

        my @hands = (
            { cards  => [ qw(10C 10D KS) ],
              hi_lo  => 'h',
              result => { win => 1,
                          msg => 'Winner! 3rd card is highest!',
                        },
              msg    => 'winner',
            },
            {
              cards  => [ qw(9C 9H 5D) ],
              hi_lo  => 'h',
              result => { loss => 1,
                          msg  => 'Loser! 3rd card is lowest!',
                        },
              msg    => 'loser',
            },
        );

        for my $hand ( @hands ) {
            my $test_hand = $game->new_hand();
            map { $master_hand->give_a_card($test_hand, $_) } @{ $hand->{cards} };

            $test_hand->hi_or_lo($hand->{hi_lo});

            is_deeply($test_hand->compute_result(), $hand->{result},
                => $hand->{msg}
            );
        }
    };

    subtest 'dealt pair - bet next is lower' => sub {
        my $master_hand = _generate_master_hand($game);

        my @hands = (
            { cards  => [ qw(10C 10D KS) ],
              hi_lo  => 'l',
              result => { loss => 1,
                          msg  => 'Loser! 3rd card is highest!',
                        },
              msg    => 'loser',
            },
            {
              cards  => [ qw(9C 9H 5D) ],
              hi_lo  => 'l',
              result => { win => 1,
                          msg => 'Winner! 3rd card is lowest!',
                        },
              msg    => 'winner',
            },
        );

        for my $hand ( @hands ) {
            my $test_hand = $game->new_hand();
            map { $master_hand->give_a_card($test_hand, $_) } @{ $hand->{cards} };

            $test_hand->hi_or_lo($hand->{hi_lo});

            is_deeply($test_hand->compute_result(), $hand->{result}
                => $hand->{msg}
            );
        }
    };

    subtest 'dealt consecutive - bet next is higher' => sub {
        my $master_hand = _generate_master_hand($game);

        my @hands = (
            { cards  => [ qw(10C JD KS) ],
              hi_lo  => 'h',
              result => { win => 1,
                          msg => 'Winner! 3rd card is highest!',
                        },
              msg    => 'winner',
            },
            {
              cards  => [ qw(8C 9H 5D) ],
              hi_lo  => 'h',
              result => { loss => 1,
                          msg  => 'Loser! 3rd card is lowest!',
                        },
              msg    => 'loser',
            },
        );

        for my $hand ( @hands ) {
            my $test_hand = $game->new_hand();
            map { $master_hand->give_a_card($test_hand, $_) } @{ $hand->{cards} };

            $test_hand->hi_or_lo($hand->{hi_lo});

            is_deeply($test_hand->compute_result(), $hand->{result}
                => $hand->{msg}
            );
        }
    };

    subtest 'dealt consecutive - bet next is lower' => sub {
        my $master_hand = _generate_master_hand($game);

        my @hands = (
            { cards  => [ qw(10C JD KS) ],
              hi_lo  => 'l',
              result => { loss => 1,
                          msg  => 'Loser! 3rd card is highest!',
                        },
              msg    => 'loser',
            },
            {
              cards  => [ qw(8C 9H 5D) ],
              hi_lo  => 'l',
              result => { win => 1,
                          msg => 'Winner! 3rd card is lowest!',
                        },
              msg    => 'winner',
            },
        );

        for my $hand ( @hands ) {
            my $test_hand = $game->new_hand();
            map { $master_hand->give_a_card($test_hand, $_) } @{ $hand->{cards} };

            $test_hand->hi_or_lo($hand->{hi_lo});

            is_deeply($test_hand->compute_result(), $hand->{result}
                => $hand->{msg}
            );
        }
    };
};

subtest 'Calculate odds' => sub {
    my $master_hand = _generate_master_hand($game);
        my @hands = (
            { cards  => [ qw(3C JD KS) ],
              result => { win  => 56,
                          loss => { outside_spread => 32,
                                    post_hit       => 12,
                          },
                        },
              msg    => 'odds on spread > 1',
            },
            { cards  => [ qw(3S 4D KD) ],
              hi_lo  => 'h',
              result => { win  => 72,
                          loss => { card_lo  => 16,
                                    post_hit => 12,
                          },
                        },
              msg    => 'odds on seqn, bet card is high',
           },
           { cards  => [ qw(3H 4H KC) ],
             hi_lo => 'l',
             result => { win  => 16,
                         loss => { card_hi  => 72,
                                   post_hit => 12,
                         },
                        },
              msg    => 'odds on seqn, bet card is low',
            },
            { cards  => [ qw(6S 6D AS) ],
              hi_lo  => 'h',
              result => { win  => 56,
                          loss => { card_lo  => 40,
                                    post_hit => 4,
                          },
                        },
              msg    => 'odds on pair, bet card is high',
           },
           { cards  => [ qw(7H 7D AD) ],
             hi_lo => 'l',
             result => { win  => 48,
                         loss => { card_hi  => 48,
                                   post_hit => 4,
                         },
                        },
              msg    => 'odds on pair, bet card is low',
            },
        );

        for my $hand ( @hands ) {
            my $test_hand = $game->new_hand();

            $test_hand->hi_or_lo($hand->{hi_lo}) if $hand->{hi_lo};

            map { $master_hand->give_a_card($test_hand, $_) } @{ $hand->{cards} };

            is_deeply($test_hand->calculate_odds(), $hand->{result}
                => $hand->{msg}
            );
        }

};
done_testing();

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
