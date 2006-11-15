use Test::More tests => 1;

use strict;

use Games::Goban;
my $board = new Games::Goban ( 
	size => 19,
	game => "go",
	white => "Seigen, Go",
	black => "Minoru, Kitani",
#	referee => \&Games::Goban::Rules::Go,
);

$board->move("pd"); $board->move("dd");
$board->as_sgf;

ok(1)
