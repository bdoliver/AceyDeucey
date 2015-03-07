#!/usr/bin/env perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Getopt::Long;
use Pod::Usage;

use AceyDeucey;

binmode(STDOUT, ":utf8");


my ($pot, $stake, $hints, $help, $man);

GetOptions(
#    "hints"     => \$hints,
    "stake=i"   => \$stake,
    "pot=i"     => \$pot,
    "help|?"    => \$help,
    "man"       => \$man,
) or pod2usage(2);

pod2usage(1) if $help;
pod2usage(-verbose => 2) if $man;

if ( $stake ) {
    $pot or die "--pot is required with --stake\n";
}

AceyDeucey->new(pot => $pot, stake => $stake)->play();

__END__
=head1 NAME

acey_deucey.pl - Play a game of "Acey / Deucey"

=head2 OPTIONS

=over

=item --pot NNN

Starting size of the pot. Optional: if not set, you will be prompted.

=item --stake NNN

Starting size of your stake.  Optional: if not set, you will be prompted.