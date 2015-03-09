#!/usr/bin/env perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Getopt::Long;
use Pod::Usage;

use AceyDeucey;

binmode(STDOUT, ":utf8");


my ($pot, $stake, $decks, $hints, $help, $man);

GetOptions(
#    "hints"     => \$hints, # may use this to display odds with each hand
    "stake=i"   => \$stake,
    "pot=i"     => \$pot,
    "decks=i"   => \$decks,
    "help|?"    => \$help,
    "man"       => \$man,
) or pod2usage(2);

pod2usage(1) if $help;
pod2usage(-verbose => 2) if $man;

if ( $stake ) {
    $pot or die "--pot is required with --stake\n";
}

AceyDeucey->new(pot => $pot, stake => $stake, decks => $decks)->play();

__END__
=head1 NAME

acey_deucey.pl - Play a game of "Acey / Deucey"

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

