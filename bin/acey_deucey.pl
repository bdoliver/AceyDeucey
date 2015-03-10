#!/usr/bin/env perl

use strictures 2;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Getopt::Long;
use Pod::Usage;

use AceyDeucey;

binmode( STDOUT, ":encoding(UTF-8)" );

my ( $stake, $decks, $hints, $help, $man );

GetOptions(
    # "hints"  => \$hints, # may use this to display odds with each hand
    "stake=i" => \$stake,
    "decks=i" => \$decks,
    "help|?"  => \$help,
    "man"     => \$man,
) or pod2usage(2);

pod2usage(1) if $help;
pod2usage( -verbose => 2 ) if $man;

AceyDeucey->new( stake => $stake, decks => $decks )->play();

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
    }    # end sub Games::Cards::Card::suit

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

    }    # end sub Card::print
}

__END__
=head1 NAME

acey_deucey.pl - Play a game of "Acey / Deucey"

[Note: this game expects your terminal to be capable of rendering UTF8]

=head2 OPTIONS

=over

=item --pot NNN

Starting size of the pot. Optional: if not set, you will be prompted.

=item --stake NNN

Starting size of your stake.  Optional: if not set, you will be prompted.

=item --decks NNN

Number of decks to play through (default is 1).

This limits the length of a game.  A deck with be played through at least
once.  This option may be used to set the length of the game by nominating
how many times the deck will be played through. Of course, you may choose
to quit at any time during the game.

=back

