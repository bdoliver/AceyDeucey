package AceyDeucey::Hand;

use strictures 2;

use namespace::autoclean;

use v5.10;
use feature 'unicode_strings';

use Carp;
use Games::Cards;
use List::Util qw(min max);
use Moose;
use Moose::Util::TypeConstraints;
use MooseX::NonMoose;
use Term::ANSIColor;

extends 'Games::Cards::Hand';
=pod

=head1 NAME

AceyDeucey::Hand -- module to represent a hand 'acey deucey'

=head1 SYNOPSIS

use Games::Cards;
use AceyDeucey::Hand;

my $hand = AceyDeucey::Hand->new(Games::Cards->new());

=head1 DESCRIPTION

This module is a subclass of C<Games::Cards::Hand>, with additional
methods required to support a hand of acey-deucey.

=head1 METHODS

In general, all methods except the constructor should be considered
private as the object instance itself is private to an instance of
C<AceyDeucey>.

=over

=item hi_or_lo

In the event that posts are either a pair, or consecutive (ie. the spread
is <= 1), the player must indicate whether the next card will be higher or
lower than the posts.  This method is called with 'h' when the bet is high,
or 'l' when the bet is low.

=cut
subtype 'HiLo'
    => as 'Str'
    => where { $_ =~ qr{[hHlL]} }
    => message { qq{ hi_or_lo() got '$_' (expected 'h' or 'l')} };

has hi_or_lo => (
    is      => 'rw',
    isa     => 'HiLo',
);

around new => sub {
    my $orig = shift;
    my $self = shift;

    return $self->$orig(@_, 'Hand');
};
=pod

=item spread

The numeric difference between the two post cards. Face cards J/Q/K
are treated as 11/12/13 respectively.  If the first (left) post card
is an Ace, the player has the option of choosing whether it is high
(14) or low (1).  In all other cases, Aces are low.

=cut
sub spread {
   my ( $self ) = @_;

   my @cards = @{ $self->cards() };

   return abs($cards[0]->value() - $cards[1]->value());
}
=pod

=item is_pair

Returns true if the post cards are a matched pair.

=cut
sub is_pair {
    return shift->spread() == 0;
}
=pod

=item is_consecutive

Returns true if the post cards are numerically consecutive (regardless
of suit). ie. their spread is 1.

=cut
sub is_consecutive {
    return shift->spread() == 1;
}
=pod

=item is_pair_aces

Returns true if the post cards are a pair of aces.

=cut
sub is_pair_aces {
    my ( $self ) = @_;

    my @cards = @{ $self->cards() };

    return ( $cards[0]->name() eq 'A' and $cards[1]->name() eq 'A' );
}
=pod

=item ace_first

Returns true if the first (left) post is an Ace.

=cut
sub ace_first {
    return shift->cards->[0]->name() eq 'A';
}
=pod

=item acey_deucey

Returns true if the post cards are Ace+Two (regardless of suit).

=cut
sub acey_deucey {
    my ( $self ) = @_;

    my @cards = @{ $self->cards() };

    return ( $cards[0]->name() eq 'A' and $cards[1]->name() eq '2' );
}
=pod

=item set_ace_high

Mutator used when the player elects to call the a left Ace post card
as high.

=cut
sub set_ace_high {
    my ( $self, $high ) = @_;

    $self->cards->[0]->name() eq 'A' or
        carp "1st card is not an Ace!\n";

    ## Games::Cards::Card::value() is not a mutator, so must
    ## re-set the card value directly:
    return $self->cards()->[0]->{value} = $high ? 14 : 1;
}
=pod

=item is_ace_high

Returns true if the left post card is an Ace which has been flagged as
high.

=cut
sub is_ace_high {
    my ( $self ) = @_;

    $self->cards->[0]->name() eq 'A' or
        carp "1st card is not an Ace!\n";

    return $self->cards()->[0]->value() == 14;
}
=pod

=item is_bet_low

Returns true if the player is betting the next card will be lower
than the posts.

=cut
sub is_bet_low {
    return shift->hi_or_lo() eq 'l';
}
=pod

=item is_bet_high

Returns true if the player is betting the next card will be higher
than the posts.

=cut
sub is_bet_high {
    return shift->hi_or_lo() eq 'h';
}
=pod

=item as_string

Prints the string representation of the current hand. NB: expects that
the terminal supports UTF-8 as it uses the card-suit UTF-8 code points.
If the terminal also supports ANSI colour escape sequences, the cards
will also be rendered in their appropriate colour.

=cut
sub as_string {
    my ( $self ) = @_;

    my $hand_str = colored ['black on_white'], ' Hand: ';

    ## we want to print the 3rd card between the 1st & 2nd
    ## (because those are the posts)
    for my $idx ( 0, 2, 1, ) {
           my $card = $self->cards()->[$idx];
           $hand_str .= colored ( ($card->is_face_up() and $card->suit() =~ qr{[DH]})
                                  ? ['red on_white']
                                  : ['black on_white'],
                                  $card->print('utf8'));
    }

    return $hand_str;
}
=pod

=item compute_result

Determines whether the hand is won or lost.  Returns a hashref with the
result:

=over

=item Winning Hand:

    { win => 1,
      msg => string,
    }

=item Losing Hand:

    { loss => 1-4,  ## the loss factor
      msg => string,
    }

=back

The loss factor is used to determine how much the player loses.
Certain losing combinations incur additional penalties - this
value is the multiplier for those and will be in the range 1 - 4
(inclusive).

=cut
sub compute_result {
    my ( $self ) = @_;

    my $result = {};

    my ( $first_val, $second_val, $third_val ) =
        map { $_->value() } @{ $self->cards() };

    ## Check for post hits first:
    if ( $third_val == $first_val or $third_val == $second_val ) {
        ## 3rd card hit a post
        ## - if hand is a run, penalty = doubled
        ## - if hand is a pair, penalty = tripled
        ## - if post hit is an ace, penalty = quadrupled
        if ( $third_val == 1 and ( $self->is_pair() or $self->acey_deucey() ) ) {
            $result->{msg}  = 'Loser! 3rd card hit an ACE post - bet is quadrupled!';
            $result->{loss} = 4;
        }
        elsif ( $third_val == 2 and $self->acey_deucey() ) {
            $result->{msg}  = 'Loser! 3rd card hit an acey-deucey post - bet is quadrupled!';
            $result->{loss} = 4;
        }
        elsif ( $self->is_pair() ) {
            $result->{msg}  = 'Loser! 3rd card hit a pair post - bet is tripled!';
            $result->{loss} = 3;
        }
        else {
            $result->{msg}  = 'Loser! 3rd card hit a post - bet is doubled!';
            $result->{loss} = 2;
        }
    }
    ## pairs & consecutives: check whether hi or lo was called:
    elsif ( $self->is_consecutive() or $self->is_pair() ) {
        if ( $self->is_bet_high() ) {
            if ( $third_val > $first_val and $third_val > $second_val ) {
                ## winner!
                $result->{msg} = 'Winner! 3rd card is highest!';
                $result->{win} = 1;
            }
            else {
                ## loser!
                $result->{msg}  = 'Loser! 3rd card is lowest!';
                $result->{loss} = 1;
            }
        }
        else {
            if ( $third_val < $first_val and $third_val < $second_val ) {
                ## winner!
                $result->{msg} = 'Winner! 3rd card is lowest!';
                $result->{win} = 1;
            }
            else {
                ## loser!
                $result->{msg}  = 'Loser! 3rd card is highest!';
                $result->{loss} = 1;
            }
        }
    }
    ## 'standard' hand check:
    else {
        if ( $third_val < max($first_val, $second_val) and
             $third_val > min($first_val, $second_val) ) {
             # winner!
             $result->{msg} = 'Winner! 3rd card is between posts!';
             $result->{win} = 1;
        }
        else {
             # loser!
             $result->{msg}  = 'Loser! 3rd card is outside posts!';
             $result->{loss} = 1;
        }
    }

    return $result;
}
=pod

=item calculate_odds

Determines the odds of whether the current hand can be won or lost.
This method will only ever be called if the game was started with the
C<--hints> option.  The player may then enter B<h> while placing a bet
to get the hints (odds) for the current hand.

=cut
sub calculate_odds {
    my ( $self ) = @_;

    my $odds = {};

    my ( $post1, $post2 ) = map { $_->value() } (@{ $self->cards() })[0,1];

    ## Win odds:
    ##  - normal spread
    if ( $self->spread() > 1 ) {
        $odds->{win} = ( abs($post1 - $post2) - 1 ) * 4 / 50 * 100;
    }
    ##  - must be pair or consecutive, so bet will be either high or low
    elsif ( $self->is_bet_high() ) {
        $odds->{win} = ( 13 - max($post1,$post2) ) * 4 / 50 * 100;
    }
    elsif ( $self->is_bet_low() ) {
        $odds->{win} = ( min($post1,$post2) - 1 ) * 4 / 50 * 100;
    }

    ## Loss odds:
    if ( $self->spread() > 1 ) {
        my $outside_hi = ( 13 - max($post1,$post2) ) * 4 / 50 * 100;
        my $outside_lo = ( min($post1,$post2) - 1 ) * 4 / 50 * 100;
        $odds->{loss}->{outside_spread} = $outside_hi + $outside_lo;
    }

    if ( $self->is_pair() ) {
        # pair post hit (ie. matching pair remaining in deck)
        $odds->{loss}->{post_hit} = 2 / 50 * 100;
    }
    else {
        # non-pair post hit (ie. 3 of each post remaining in deck)
        $odds->{loss}->{post_hit} = (3 + 3) / 50 * 100;
    }

    # If hi or lo was bet (because pair or consecutive cards),
    # then show loss odds:
    if ( $self->hi_or_lo() ) {
        if ( $self->is_bet_high() ) {
            $odds->{loss}->{card_lo} = ( min($post1,$post2) - 1 ) * 4 / 50 * 100;
        }
        else {
            $odds->{loss}->{card_hi} = ( 13 - max($post1,$post2) ) * 4 / 50 * 100;
        }
    }

    return $odds;
}
=pod

=back

=cut
no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);

1;

__END__

