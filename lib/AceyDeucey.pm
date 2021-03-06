package AceyDeucey;

use strictures 2;

use namespace::autoclean;

use v5.10;
use feature 'unicode_strings';

use Carp;
use Moose;
use Games::Cards;
use IO::Prompter [ -style => [ 'bold', 'yellow' ] ];
use Scalar::Util qw(looks_like_number);
use Term::ANSIColor;

use AceyDeucey::Hand;
=pod

=head1 NAME

AceyDeucey -- Perl module to play & control a game of 'acey deucey'

=head1 SYNOPSIS

use AceyDeucey;

my $args = {
    stake => 100,
    pot   => 200,
    hints => 0,
    decks => 2
};

AceyDeucey->new($args)->play();

=head1 DESCRIPTION

This module is used to instantiate and play a version of the card game
'acey deucey'.  It expects that your terminal is capable of rendering
UTF-8 as it uses the card-suit glyphs when displaying cards.  It also
helps if your terminal honours the ANSI colour settings too.

=head1 METHODS

Pretty much everything aside from the constructor, C<new()>, and C<play()>,
should be considered as I<private> methods. Methods not documented here
(particularly those named with a leading underscore) are B<definitely>
private (and unlikely to be useful anwyay).

=over

=item new

Construct a new instance of the game.  Accepts a hash or hashref with
the following parameters:

=over

=item stake

starting stake for the game. Optional, but if not supplied will prompt
for a value to be entered (otherwise, what's the point of playing if
there's nothing to bet with?)

=item pot

starting pot for the game (optional).

=item decks

optionally nominate the number of times through the deck you would like
to play.  Default is 1 when not provided.

=item hints

optional - any true value will allow you to request hints (in the form
of the win/loss odds) for the current hand during the course of play.

=back

=item game

Attribute: the Games::Cards::Game object for this game.
Never actually set explicitly - a default object is constructed when the
game commences.

=cut
has game => (
    is       => 'ro',
    isa      => 'Games::Cards::Game',
    default  => sub { Games::Cards::Game->new(); },
    required => 1,
);
=pod

=item hints

Attribute: boolean.  Set by C<--hints|-H> command line option.
When true, allows player to request hints to be displayed when
placing a bet.  Causes the win/lose odds for the current hand to
be calculated and displayed.

=cut
has hints => (
    is      => 'rw',
    default => 0,
);
=pod

=item quit

Attribute: set internally when the player elects to terminate the game.

=cut
has quit => (
    is      => 'rw',
    default => 0,
);
=pod

=item num_decks

Attribute: the number of decks to be played through.  Set by the
C<--decks> command line option.  Defaults to 1.

=cut
has num_decks => (
    traits  => ['Counter'],
    is      => 'rw',
    isa     => 'Num',
    default => 1,
    handles => {
        dec_num_decks   => 'dec',
        inc_num_decks   => 'inc',      # ) not used, just defined for completeness
        reset_num_decks => 'reset',    # )   "  "
    },
);
=pod

=item deck

Attribute: the internal C<Games::Cards::Deck> object from which hands
are dealt.

=cut
has deck => (
    is      => 'rw',
    isa     => 'Games::Cards::Deck',
    lazy    => 1,
    default => sub { shift->new_deck(); },
);
=pod

=item hand

Attribute: the internal C<AceyDeucey::Hand> object for the current hand
in play.

=cut
has hand => (
    is      => 'rw',
    isa     => 'AceyDeucey::Hand',
    lazy    => 1,
    default => sub { shift->new_hand(); },
);
=pod

=item pot

Attribute: returns the current value of the pot.  This is a counter - do
not use this to set the value.  Instead, see C<add_to_pot()>,
C<take_from_pot()> and C<reset_pot()>.

=cut
has pot => (
    traits  => ['Counter'],
    is      => 'rw',
    isa     => 'Num',
    default => 0,
    handles => {
        add_to_pot    => 'inc',
        take_from_pot => 'dec',
        reset_pot     => 'reset',
    },
);
=pod

=item stake

Attribute: returns the current value of the player's stake.
This is a counter - do not use this to set the value.  Instead, see
C<add_to_stake()>, C<take_from_stake()> and C<reset_stake()>.

=cut
has stake => (
    traits  => ['Counter'],
    is      => 'rw',
    isa     => 'Num',
    default => 0,
    handles => {
        add_to_stake    => 'inc',
        take_from_stake => 'dec',
        reset_stake     => 'reset',
    },
);
=pod

=item stats

Attribute: returns a hashref of the current game's statistics. Refer
C<emit_stats()> for a pretty-printed version.

=cut
has stats => (
    is      => 'rw',
    isa     => 'HashRef',
    lazy    => 1,
    default => sub { shift->_init_stats(); },
);

around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;

    if ( @_ % 2 and !ref $_[0] ) {
        confess
          "$class->new() got odd number of arguments (expected hash or hashref)\n";
    }

    my $args = ref $_[0] ? shift : {@_};

    map { $args->{$_} ||= 0 } (qw( pot stake ));

    return $class->$orig($args);
};

sub _init_stats {
    my ($self) = @_;

    return $self->stats(
        {
            decks         => $self->num_decks(),    # not sure about this
            games         => 0,
            won           => 0,
            lost          => 0,
            folded        => 0,
            initial_stake => $self->stake(),
        }
    );
} ## end sub _init_stats

sub BUILD {
    my $self = shift;

    if ( ! $self->stake() ) {
        my $val = prompt "Enter your starting stake: ", -integer => 'positive nonzero';

        ## ... because prompt() returns a Contextual::Return::Value object!
        $self->stake( $val * 1 );
    }

    $self->_msg( {msg => 'Your starting stake:', amt => $self->stake()} );

    if ( $self->pot() ) {
        $self->_msg( {msg => 'The starting pot is:', amt => $self->pot()} );
    }

    $self->_init_stats();

    return 1;
} ## end sub BUILD
=pod

=item new_deck

Method: generates a new deck from which cards will be dealt.  This is
called automatically during play when there are insufficient cards left
and C<num_decks()> is greater than 1.

=cut
sub new_deck {
    my ($self) = @_;

    my $deck = Games::Cards::Deck->new( $self->game(), 'Deck' );

    $deck->shuffle();

    return $self->deck($deck);
} ## end sub new_deck
=pod

=item new_hand

Method: creates a new hand ready for dealing.

=cut
sub new_hand {
    my ($self) = @_;

    $self->hand( AceyDeucey::Hand->new( $self->game() ) );
} ## end sub new_hand

sub _do_hints {
    my ($self) = @_;

    my $hints = $self->hand->calculate_odds();

    $self->_msg({
        msg => sprintf('Odds of winning this hand   : %2s%%',
                       $hints->{win}),
    }) if $hints->{win};

    if ( $hints->{loss} ) {
        $self->_msg({
            msg => sprintf('Odds of being outside posts : %2s%%',
                           $hints->{loss}->{outside_spread}),
        }) if $hints->{loss}->{outside_spread};

        $self->_msg({
            msg => sprintf('Odds of hitting a post      : %2s%%',
                           $hints->{loss}->{post_hit}),
        }) if $hints->{loss}->{post_hit};
    }
}

sub _msg {
    my ( $self, $args ) = @_;

    my $msg  = $args->{msg};
    my $amt  = $args->{amt};
    my $err  = $args->{err};

    ( $msg or $err )
      or confess "Internal err: _msg() requires param 'msg' or 'err'\n";

    if ( $err ) {
        say colored ['bold red'], "\t $err ";
        return 1;
    }

    my $fmt  = '%-25s';
       $fmt .= ' $%10.02f' if defined $amt;
    say sprintf( $fmt, $msg, $amt );

    return 1;
} ## end sub _msg

sub _tell_pot {
    my ( $self ) = @_;
    $self->_msg({msg => 'The pot is now: ',
                 amt => $self->pot()});
}
sub _tell_stake {
    my ( $self ) = @_;
    $self->_msg({msg => 'Your stake is now: ',
                 amt => $self->stake()});
}

after 'add_to_pot'      => sub { shift->_tell_pot(); };
after 'take_from_pot'   => sub { shift->_tell_pot(); };
after 'add_to_stake'    => sub { shift->_tell_stake(); };
after 'take_from_stake' => sub { shift->_tell_stake(); };

# can't call 'reset' with an arg so do it this way:
around 'reset_pot' => sub {
    my ( $orig, $self, $value ) = @_;

    $value
      or confess "reset_pot() requires new starting pot value!\n";

    print "Resetting pot. ";
    $self->$orig();

    $self->add_to_pot($value);

    return 1;
};

around 'reset_stake' => sub {
    my ( $orig, $self, $value ) = @_;

    $value
      or confess "reset_stake() requires new starting stake value!\n";

    print "Resetting stake. ";
    $self->$orig();

    $self->add_to_stake($value);

    return 1;
};
=pod

=item deal

Method: deals 3 cards from the deck to the hand.  The 3rd card will be
dealt face-down.

=cut
sub deal {
    my ( $self, $count ) = @_;

    $count ||= 3;

    $count and $count > 0
      or confess "deal() requires positive number of cards to be dealt!\n";

    $self->deck->give_cards( $self->hand(), $count );

    ## face-down the 'middle' card until we 'flip' it:
    ## NB: the _last_ card is rendered as the 'middle':
    $self->hand->cards->[2]->face_down();

    return 1;
} ## end sub deal
=pod

=item play

Method: runs a game of acey deucey.  This is the main I<loop> of the game.

=cut
sub play {
    my ($self) = @_;

    while ( !$self->quit() and $self->num_decks() > 0 ) {
        if ( $self->deck()->size() < 3 ) {
            ## When there's less than 3 cards remaining, we can't re-deal.
            ## If the player has elected to go through the deck more than
            ## once, re-start with a new deck.
            if ( $self->num_decks > 1 ) {
                say "Re-shuffling deck...";

                # starting over with a new deck is simpler than recovering
                # the played cards:
                $self->new_deck();
            }
            $self->dec_num_decks(1);
        }

        $self->play_hand();

        my $quit;

        if ( !$self->stake() ) {
            say "You have blown your stake! You lose!";
            last;
        }

        if ( $self->quit() ) {
            my $continue = prompt "\nDo you want to quit? (y/n) ", -yn;
            $quit = $continue eq 'y';
        }
        else {
            my $continue = prompt "\nDeal again? (y/n) ", -yn, -default => 'y';
            $quit = $continue eq 'n';

            $self->new_hand() if $continue eq 'y';
        }

        $self->quit($quit);
    }

    say 'Played through all decks - game over!' if !$self->num_decks();

    $self->emit_stats();
} ## end sub play
=pod

=item play_hand

Method: plays out a single hand of acey-deucey.  This is where the
betting takes place; stats are maintained; and where the determination
of win or lose takes place.  This is called from within the main C<play()>
loop.

=cut
sub play_hand {
    my ($self) = @_;

    my $ante = $self->ante_up();

    $ante or return $self->quit(1);

    $self->stats()->{games}++;

    $self->deal();

    my $hand = $self->hand();

    $self->_msg( { msg => "\n\t" . $hand->as_string() } );

    my ($ace_hi_or_lo);

    if ( $hand->is_pair() or $hand->is_consecutive() ) {

        # call for next card to be hi / lo
        my $hi_or_lo = prompt 'Pair or run: is next card (h)igh or (l)ow? ',
          -keyletters;
        $self->_msg(
            {
                msg => 'You bet next card will be ' . ( $hi_or_lo eq 'h' ? 'higher' : 'lower' )
            }
        );

        # gah! need to stringify the prompt result...
        $self->hand->hi_or_lo( $hi_or_lo . '' );
    }
    elsif ( $self->hand->ace_first() ) {
        if ( !$hand->acey_deucey() ) {
            $ace_hi_or_lo = prompt 'First card is Ace: (h)igh or (l)ow? ', -keyletters;
            if ( $ace_hi_or_lo eq 'h' ) {
                $self->_msg( { msg => 'First card: Ace is high' } );
                $self->hand->set_ace_high(1);
            }
            else {
                $self->_msg( { msg => 'First card: Ace is low' } );

                # ace is low by default so no need to set.
            }
        }
    }

    my $spread = $hand->spread();

    ## no need to tell the spread for pairs & consecutives:
    $self->_msg( { msg => "\nThe spread is $spread" } ) if $spread > 1;

    my $bet = $self->get_bet() or return 0;

    sleep 1;    ## artificial delay before the "flip"

    ## Flip the middle card & work out the result:
    $self->hand->cards->[2]->face_up();

    $self->_msg( { msg => "\n\t" . $hand->as_string() } );

    my $result = $hand->compute_result();

    $self->_msg(
        {
            msg => "\n\t"
              . colored(
                $result->{win}
                ? ['bold green']
                : ['bold red'],
                "$result->{msg}\n"
              )
        }
    );

    if ( $result->{win} ) {

        # winning hand => no loss factor = win the bet amt from the pot.
        $self->_msg(
            {
                msg => 'You won: ',
                amt => $bet
            }
        );
        $self->stats()->{won}++;
        $self->add_to_stake($bet);
        $self->take_from_pot($bet);
    }
    else {
        # losing => pay loss_factor x bet to pot
        $bet *= $result->{loss};
        $self->_msg(
            {
                msg => 'You lost:',
                amt => $bet
            }
        );
        $self->stats()->{lost}++;
        $self->take_from_stake($bet);
        $self->add_to_pot($bet);
    }
} ## end sub play_hand
=pod

=item ante_up

Method: prompt the player to ante-up - buy into the hand before
the deal.

=cut
sub ante_up {
    my ($self) = @_;

    my $val = prompt "\nAnte-up: ", -integer => sub { $_ >= 0 };

    my $ante = $val * 1;

    $ante or return 0;    ## no ante - player probably bailing out...

    $self->_msg( { msg => "Your ante :", amt => $ante } );

    $self->take_from_stake($ante);
    $self->add_to_pot($ante);

    return $ante;
} ## end sub ante_up
=pod

=item get_bet

Method: prompt the player to place their bet for the current hand.

=cut
sub get_bet {
    my ($self) = @_;

    my $stake = $self->stake();
    my $pot   = $self->pot();
    my $bet;

    my $prompt = "\nPlace your bet (amount, 0 to fold, '(p)ot' to bet the pot";
    $prompt .= ", 'h' for hints" if $self->hints();
    $prompt .= "): ";

    BET: {

        my $val = prompt $prompt;

        if ( $val and $val =~ qr{^p(?:ot)?$}i ) {
            $bet = $self->pot();
        }
        elsif ( $val and looks_like_number($val) ) {
            $bet = $val * 1;
        }
        elsif ( $val and $self->hints() and $val =~ qr{^[hH]$} ) {
            $self->_do_hints();
            redo BET;
        }
        else {
            $val ||= '';
            say "Invalid bet '$val'";
            redo BET;
        }

        if ( $bet > $stake ) {
            $self->_msg(
                { err => sprintf( 'You cannot bet more than your stake ($%.02f)', $stake ) } );
            redo BET;
        }
        if ( $bet > $pot ) {
            $self->_msg(
                { err => sprintf( 'You cannot bet more than the pot ($%.02f)', $pot ) } );
            redo BET;
        }
    }

    if ($bet) {
        say sprintf( 'You bet : $%.02f', $bet );
    }
    else {
        $self->_msg( { err => 'You have chosen to fold.' } );
        $self->stats->{folded}++;
    }

    return $bet;
} ## end sub get_bet
=pod

=item emit_stats

Method: pretty-prints the contents of the C<stats()> hashref.
Called when the C<play()> game loop has just exited.

=cut
sub emit_stats {
    my ($self) = @_;

    my $stats = $self->stats();

    say '';
    $self->_msg(
        {
            msg => 'Your initial stake was:',
            amt => $stats->{initial_stake}
        }
    );
    $self->_msg(
        {
            msg => 'Your final stake was:',
            amt => $self->stake()
        }
    );
    my $winnings = $self->stake() - $stats->{initial_stake};

    $self->_msg(
        {
            msg => 'You ' . ( $winnings >= 0 ? 'won' : 'lost' ),
            amt => abs($winnings)
        }
    );

    say '';
    say sprintf(
        'You played %4s game%s', $stats->{games},
        ( $stats->{games} > 1 or $stats->{games} == 0 )
        ? 's'
        : ''
    );
    say sprintf(
        'You won    %4s game%s', $stats->{won},
        ( $stats->{won} > 1 or $stats->{won} == 0 )
        ? 's'
        : ''
    );
    say sprintf(
        'You lost   %4s game%s', $stats->{lost},
        ( $stats->{lost} > 1 or $stats->{lost} == 0 )
        ? 's'
        : ''
    );
    say sprintf(
        'You folded %4s game%s', $stats->{folded},
        ( $stats->{folded} > 1 or $stats->{lost} == 0 )
        ? 's'
        : ''
    ) if $stats->{folded};

    say '';
    say 'Good bye!';
} ## end sub emit_stats
=pod

=back

=cut
no Moose;
__PACKAGE__->meta->make_immutable;

1;

__END__
