package AceyDeucey::Hand;

use namespace::autoclean;

use v5.10;
use feature 'unicode_strings';

use Carp;
use List::Util qw(min max);
use Moose;
use MooseX::NonMoose;
use Games::Cards;
use IO::Prompter;
extends 'Games::Cards::Hand';

around new => sub {
    my $orig = shift;
    my $self = shift;

    return $self->$orig(@_, 'Hand');
};

sub spread {
   my ( $self ) = @_;

   my @cards = @{ $self->cards() };

   return abs($cards[0]->value() - $cards[1]->value());
}

sub is_pair {
    return shift->spread() == 0;
}

sub is_consecutive {
    return shift->spread() == 1;
}

sub is_pair_aces {
    my ( $self ) = @_;

    my @cards = @{ $self->cards() };

    return ( $cards[0]->name() eq 'A' and $cards[1]->name() eq 'A' );
}

sub ace_first {
    return shift->cards->[0]->name() eq 'A';
}

sub acey_deucey {
    my ( $self ) = @_;

    my @cards = @{ $self->cards() };

    return ( $cards[0]->name() eq 'A' and $cards[1]->name() eq '2' );
}

sub set_ace_high {
    my ( $self, $high ) = @_;

    $self->cards->[0]->name() eq 'A' or
        carp "1st card is not an Ace!\n";

    ## Games::Cards::Card::value() is not a mutator, so must
    ## re-set the card value directly:
    return $self->cards()->[0]->{value} = $high ? 14 : 1;
}

sub is_ace_high {
    my ( $self ) = @_;

    $self->cards->[0]->name() eq 'A' or
        carp "1st card is not an Ace!\n";

    return $self->cards()->[0]->value() == 14;
}

sub compute_result {
    my ( $self, $pair_hi_or_lo ) = @_;

    my $loss_factor = 0;

    my ( $first_val, $second_val, $third_val ) =
        map { $_->value() } @{ $self->cards() };

    ## Check for post hits first:
    if ( $third_val == $first_val or $third_val == $second_val ) {
        ## 3rd card hit a post
        ## - if hand is a run, penalty = doubled
        ## - if hand is a pair, penalty = tripled
        ## - if post hit is an ace, penalty = quadrupled
        if ( $third_val == 1 and ( $self->is_pair() or $self->acey_deucey() ) ) {
            say '3rd card hit an ACE post - bet is quadrupled!';
            $loss_factor = 4;
        }
        elsif ( $self->is_pair() ) {
            say '3rd card hit a pair post - bet is tripled!';
            $loss_factor = 3;
        }
        else {
            say '3rd card hit a post - bet is doubled!';
            $loss_factor = 2;
        }
    }
    ## pairs & consecutives: check whether hi or lo was called:
    elsif ( $self->is_consecutive() or $self->is_pair() ) {
        if ( $pair_hi_or_lo eq 'h' ) {
            if ( $third_val > $first_val and $third_val > $second_val ) {
                ## winner!
                say "winner - 3rd card is highest!";
                ;
            }
            else {
                ## loser!
                say "loser - 3rd card is lowest!";
                $loss_factor = 1;
            }
        }
        elsif ( $pair_hi_or_lo eq 'l' ) {
            if ( $third_val < $first_val and $third_val < $second_val ) {
                ## winner!
                say "winner - 3rd card is lowest!";
                ;
            }
            else {
                ## loser!
                $loss_factor = 1;
                say "loser - 3rd card is highest!";
            }
        }
        else {
            confess "compute_result() invalid pair_hi_or_low value '$pair_hi_or_lo'\n";
        }
    }
    ## 'standard' hand check:
    else {
        if ( $third_val < max($first_val, $second_val) and
             $third_val > min($first_val, $second_val) ) {
             # winner!
             say "winner - 3rd card is between posts!";
        }
        else {
             # loser!
             say "loser - 3rd card is outside posts!";
             $loss_factor = 1;
        }
    }

    return $loss_factor;
}

no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);

1;

__END__

