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

sub is_bet_low {
    return shift->hi_or_lo() eq 'l';
}

sub is_bet_high {
    return shift->hi_or_lo() eq 'h';
}

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

sub calc_odds {
    my ( $self ) = @_;

}

no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);

1;

__END__

