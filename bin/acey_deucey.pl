#!/usr/bin/env perl

use strictures 2;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Getopt::Long;
use Pod::Usage;

use AceyDeucey;

binmode( STDOUT, ":encoding(UTF-8)" );

my ( $stake, $pot, $decks, $hints );

GetOptions(
    "pot=i"   => \$pot,
    "stake=i" => \$stake,
    "decks=i" => \$decks,
    "hints|H" => \$hints,
    "help|?"  => sub { pod2usage( -verbose => 1 ) },
    "man"     => sub { pod2usage( -verbose => 2 ) },
) or pod2usage(2);

AceyDeucey->new(
    { stake => $stake,
      pot   => $pot,
      decks => $decks,
      hints => $hints },
)->play();

exit(0);

### =================================================================
### Monkey-patch Games::Cards::Card to add UTF-8 output
{
    no warnings qw(redefine);

    package Games::Cards::Card;

    sub suit {
        my $suit   = shift->{"suit"};
        my $length = shift;
        my %utf8   = (
            "Diamonds" => "\N{U+2666}",
            "Hearts"   => "\N{U+2665}",
            "Spades"   => "\N{U+2660}",
            "Clubs"    => "\N{U+2663}",
        );

        my $long = $length && $length eq "long";
        my $utf8 = $length && $length eq "utf8";
        return $long ? $suit : $utf8 ? $utf8{$suit} : uc( substr( $suit, 0, 1 ) );
    }   # end sub Games::Cards::Card::suit

    sub print {
        my $card   = shift;
        my $length = shift;
        my $long   = $length && $length eq "long";
        my $utf8   = $length && $length eq "utf8";
        my ( $name, $suit ) = ( $card->name($length), $card->suit($length) );
        my $face_up = $card->{"face_up"};

        $long
          ? (
              $face_up
            ? $name . " of " . $suit
            : "(Face down card)"
          )
          : (    # long
            $face_up ? sprintf( "%3s ", $name . $suit )
                     : ( $utf8  ? " \N{U+263B} "  # 'A' = light smiley face
                                : "*** " )        # 'B' = dark smiley face
          );

    }   # end sub Card::print
}

__END__
=head1 NAME

acey_deucey.pl - Play a game of "Acey / Deucey"

=head1 SYNOPSIS

acey_deucey.pl [--stake N] [--decks N] [--help|--man]

[Note: this game expects your terminal to be capable of rendering UTF8]

=head1 OPTIONS

=over

=item --stake NNN

Starting size of your stake.  Optional: if not set, you will be prompted.

=item --pot NNN

Optionally nominate a starting pot for the game (in which case, your aim
is to eventually win the contents of the pot).

=item --decks NNN

Number of decks to play through (default is 1).

This limits the length of a game.  A deck with be played through at least
once.  This option may be used to set the length of the game by nominating
how many times the deck will be played through. Of course, you may choose
to quit at any time during the game.  eg. C<--decks 2> means one re-shuffle
during the game; the deck is played through twice.

=item --hints

Optionally allow hints (in the form of messages regarding the odds of
various things) to be displayed.

=item --help

Brief help about command line options.

=item --man

Display the complete manpage / perldoc for the game.

=back

=head1 DESCRIPTION

=head2 Card Order

=over

=item

Aces are always low (but see below for the one exception).

=item

Face cards, J/Q/K are treated as 11/12/13 respectively.

=back

=head2 Rules



=over

=item 1

Ante-up: enter the amount you wish to contribute to the pot.  This is
your "buy-in" for the hand.  If you want to terminate the game, enter
an ante of zero.  You will then be prompted to confirm you want to quit
the game.

=item 2

Three cards are dealt, the middle card being face-down. Your aim is to bet
whether the face-down card will be between the other two cards (which are
referred to as "posts").  There are a few additional things to consider:

=over

=item

If the posts are a pair or are consecutive (order does not matter), you
have the option to call whether the face-down card is High or Low (ie.
lower than the lowest of the posts, or higher than the highest of the
posts).

=item

If the first card (left post) is an Ace, you have the option to call
whether the Ace should be treated as high or low. An Ace on the right
post is always low.

=item

Be careful if the posts are an Ace pair, or Acey-Deucey (ie. Ace+Two of
any suit). Special penalties apply if you "lose" the hand (see Win / Lose
below).

=back

=item 3

Place your bet: enter the amount you wish to bet for this hand. If you
think the chances of winning the hand are not good, you may bet zero -
in which case you only lose your ante.  You may bet up to the value of
your remaining stake or the pot, whichever is the lower.  As a convenience,
you may enter C<p> to bet the pot.

=item 4

The middle card is flipped over, and the result displayed with your win
or loss adjusting both your stake and the pot as appropriate.

=item 5

Deal again? (y/n) - the default is 'y' to deal another hand (just press
enter). Or enter 'n' if you want to leave the game.  If your stake has
dropped to zero (or less) you have automatically lost and the game ends.

=back

When the game is over, a summary of statistics will be displayed for your
information: your starting and ending stake, and the amount you "won";
and a count of the number of games played, won and lost.

=head2 Win / Lose

=over

=item B<Wins>

If the 3rd card falls between the posts, or if you correctly bet that it
is higher or lower than the posts (for pair or consecutive posts), you
win your bet amount from the pot.

=item B<Losses>

If the 3rd card falls outside the posts, or your bet that it will be
higher or lower than the posts fails, you lose the amount of your bet.
It is deducted from your stake and paid into the pot.

=item B<Penalties>

There are some special situations which will alter how much you lose when
the 3rd card C<hits> (i.e. matches in value) a post card:

=over

=item

If the 3rd card hits an Ace post (ie. the 3rd card is also an Ace), you
will lose B<four> times your bet to the pot.

e.g. If the posts are B<AH> B<2H> (an acey-deucey), or B<AD> B<AC> and
the 3rd card is B<AS>, you will lose ( bet amount x 4 ).

=item

If the 3rd card is a 2 and the posts are acey-deucey, you will lose
B<four> times your bet to the pot.

e.g. If the posts are B<AH> B<2H> (an acey-deucey) and the 3rd card is
B<2D>, you will lose ( bet amount x 4 ).

=item

If the 3rd card hits any other pair post, you will lose B<three> times
your bet to the pot.

e.g. If the posts are B<5D> B<5H> and the 3rd card is 5C, you lose
( bet amount x 3 ).

=item

If the 3rd card hits any other post card, you lose double your bet.

e.g. If the posts are B<7C> B<JD> and the 3rd card is B<7H>, you lose
(bet amount x 2 ).

=back

So be very mindful of the chances of hitting a post, particularly an
ace post, if you decide to bet the pot.

=back

=head1 AUTHOR

Brendon Oliver <brendon.oliver@gmail.com>

Last updated: 2015/03/10
