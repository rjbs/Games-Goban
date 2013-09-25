use strict;
use warnings;
package Games::Goban;
# ABSTRACT: Board for playing go, renju, othello, etc.

use 5.006;
use Carp;

my $ORIGIN     = ord('a');
my $piececlass = 'Games::Goban::Piece';

our %types = (
  go      => 1,
  othello => 2,
  renju   => 4,
  gomoku  => 4,
);

our %defaults = (
  game    => 'go',
  size    => 19,
  white   => 'Miss White',
  black   => 'Mr. Black',
  skip_i  => 0,
  referee => sub { 1 }
);

=head1 SYNOPSIS

  use Games::Goban;
  my $board = new Games::Goban ( 
    size  => 19,
    game  => "go",
    white => "Seigen, Go",
    black => "Minoru, Kitani",
    referee => \&Games::Goban::Rules::Go,
  );

  $board->move("pd"); $board->move("dd");
  print $board->as_sgf;

=head1 DESCRIPTION

This is a generic module for handling goban-based board games.
Theoretically, it can be used to handle many of the other games which
can use Smart Game Format (SGF) but I want to keep it reasonably
restricted in order to keep it simple. 

=head1 METHODS

=head2 new(%options); 

Creates and initializes a new goban. The options and their legal
values (* marks defaults):

  size       Any integer between 5 and 26, default: 19
  game       *go, othello, renju, gomoku
  white      Any text, default: "Miss White"
  black      Any text, default: "Mr Black"
  skip_i     Truth value; whether 'i' should be skipped; false by default
  referee    Any subroutine, default: sub {1} # (All moves are valid) 

The referee subroutine takes a board object and a piece object, and
determines whether or not the move is legal. It also reports if the
game is won.

=cut

sub new {
  my $class = shift;
  my %opts = (%defaults, @_);

  unless (($opts{size} !~ /\D/) and ($opts{size} > 4) and ($opts{size} <= 26)) {
    croak "Illegal size $opts{size} (must be integer > 4)";
  }

  $opts{game} = lc $opts{game};
  croak "Unknown game $opts{game}" unless exists $types{ $opts{game} };

  my $board = bless {
    move        => 1,
    moves       => [],
    turn        => 'b',
    game        => $opts{game},
    size        => $opts{size},
    black       => $opts{black},
    white       => $opts{white},
    skip_i      => $opts{skip_i},
    referee     => $opts{referee},
    callbacks   => {},
    magiccookie => "a0000",
  }, $class;

  for (0 .. ($opts{size} - 1)) {
    push @{ $board->{board} }, [ (undef) x $opts{size} ];
  }
  $board->{hoshi} = $board->_calc_hoshi;

  return $board;
}

=head2 move

    $ok = $board->move($position)

Takes a move, creates a Games::Goban::Piece object, and attempts to
place it on the board, subject to the constraints of the I<referee>. 
If this is not successful, it returns C<0> and sets C<$@> to be an error
message explaining why the move could not be made. If successful,
updates the board, updates the move number and the turn, and returns
true.

=cut

sub move {
  my ($self, $move) = @_;

  my ($x, $y) = $self->_pos2grid($move, $self->skip_i);

  $self->_check_pos($move);
  my $stat = $self->{referee}->($self, $move);

  return $stat if !$stat;
  $self->{board}[$x][$y] = bless {
    colour => $self->{turn},
    move   => $self->{move},
    xy     => [ $x, $y ],
    board  => $self
    },
    "Games::Goban::Piece";
  push @{ $self->{moves} },
    {
    player => $self->{turn},
    piece  => $self->{board}[$x][$y]
    };
  $self->{move}++;
  $self->{turn} = $self->{turn} eq "b" ? "w" : "b";

  while (my ($key, $cb) = each %{ $self->{callbacks} }) { $cb->($key, $self) }

  return 1;
}

=head2 pass

This method causes the current player to pass.  At present, nothing happens for
two subsequent passes.

=cut

sub pass {
  my $self = shift;

  push @{ $self->{moves} },
    {
    player => $self->{turn},
    piece  => undef
    };
  $self->{move}++;
  $self->{turn} = $self->{turn} eq "b" ? "w" : "b";
}

=head2 get

    $move = $board->get($position)

Gets the C<Games::Goban::Piece> object at the given location, if there
is one. Locations are specified as per SGF - a 19x19 board starts from
C<aa> in the top left corner, with C<ss> in the bottom right.  (If the skip_i
option was set while creating the board, C<tt> is the bottom right and there
are no C<i> positions.  This allows for traditional notation.)

=cut

sub get {
  my ($self, $pos) = @_;
  my ($x, $y) = $self->_pos2grid($pos, $self->skip_i);
  $self->_check_grid($x, $y);

  return $self->{board}[$x][$y];
}

=head2 size

    $size = $board->size

Returns the size of the goban.

=cut

sub size { $_[0]->{size} }

=head2 hoshi

  @hoshi_points = $board->hoshi

Returns a list of hoshi points.

=cut

sub hoshi {
  my $self = shift;

  map { $self->_grid2pos(@$_, $self->skip_i) } @{ $self->{hoshi} };
}

=head2 is_hoshi

  $star = $board->is_hoshi('dp')

Returns true if the named position is a hoshi (star) point.

=cut

sub is_hoshi {
  my $board = shift;
  my $point = shift;
  return 1 if grep { /^$point$/ } $board->hoshi;
}

=head2 as_sgf

    $sgf = $board->as_sgf;

Returns a representation of the board as an SGF (Smart Game Format) file.

=cut

sub as_sgf {
  my $self = shift;
  my $sgf;

  $sgf
    .= "(;GM[$types{$self->{game}}]FF[4]AP[Games::Goban]SZ[$self->{size}]PB[$self->{black}]PW[$self->{white}]\n";
  foreach (@{ $self->{moves} }) {
    $sgf .= q{;}
      . uc($_->{player}) . q<[>
      . ($_->{piece} ? $self->_grid2pos(@{ $_->{piece}->_xy }, 0) : q{}) . q<]>;
  }
  $sgf .= ")\n";

  return $sgf;
}

=head2 as_text

    print $board->as_text(coords => 1)

Returns a printable text picture of the board, similar to that printed
by C<gnugo>. Black pieces are represented by C<X>, white pieces by C<O>,
and the latest move is enclosed in parentheses. I<hoshi> points are in their
normal position for Go, and printed as an C<+>. Coordinates are not printed by
default, but can be enabled as suggested in the synopsis.

=cut

sub as_text {
  my $board = shift;
  my %opts  = @_;
  my @hoshi = $board->hoshi;
  my $text;
  for (my $y = $board->size - 1; $y >= 0; $y--) { ## no critic For
    $text .= substr($board->_grid2pos(0, $y, $board->skip_i), 1, 1) . ': '
      if $opts{coords};
    for my $x (0 .. ($board->size - 1)) {
      my $pos = $board->_grid2pos($x, $y, $board->skip_i);
      my $p = $board->get($pos);
      if (  $p
        and $p->move == $board->{move} - 1
        and $text
        and substr($text, -1, 1) ne "\n")
      {
        chop $text;
        $text .= "(";
      }
      $text .= (
        $p
        ? ($p->color eq "b" ? "X" : "O")
        : ($board->is_hoshi($pos) ? q{+} : q{.})
      ) . q{ };
      if ($p and $p->move == $board->{move} - 1) { chop $text; $text .= ")"; }
    }
    $text .= "\n";
  }
  if ($opts{coords}) {
    $text .= q{ } x 3;
    for (0 .. ($board->size - 1)) {
      $text .= substr($board->_grid2pos($_, 0, $board->skip_i), 0, 1) . q{ };
    }
    $text .= "\n";
  }
  return $text;
}

=head2 register

    my $key = $board->register(\&callback);

Register a callback to be called after every move is made. This is useful for
analysis programs which wish to maintain statistics on the board state. The
C<key> returned from this can be fed to...

=cut

sub register {
  my ($board, $cb) = @_;
  my $key = ++$board->{magiccookie};
  $board->{callbacks}{$key} = $cb;
  $board->{notes}->{$key} = {};
  return $key;
}

=head2 notes

    $board->notes($key)->{score} += 5;

C<notes> returns a hash reference which can be used by a callback to
store local state about the board. 

=cut

sub notes {
  my ($board, $key) = @_;
  return $board->{notes}->{$key};
}

=head2 hash

    $hash = $board->hash

Provides a unique hash of the board position. If the phrase "positional
superko" means anything to you, you want to use this method. If not,
move along, nothing to see here.

=cut

sub hash {
  my $board = shift;
  my $hash  = chr(0) x 91;
  my $bit   = 0;
  $board->_iterboard(
    sub {
      my $piece = shift;
      vec($hash, $bit, 2) = $piece->color eq "b" ? 1 : 2 if $piece;
      $bit += 3;
    }
  );
  return $hash;
}

=head2 skip_i

This method returns true if the 'skip_i' argument to the constructor was true
and the 'i' coordinant should be skipped.  (Note that 'i' is never skipped when
producing SGF output.)

=cut

sub skip_i { return (shift)->{skip_i} }

# This method accepts a position string and checks whether it is a valid
# position on the given board.  If it is, 1 is returned.  Otherwise, it carps
# that the position is not on the board.  It does this by calling _check_grid,
# also below.

sub _check_pos {
  my $self = shift;
  my $pos  = shift;

  my ($x, $y) = $self->_pos2grid($pos, $self->skip_i);

  return $self->_check_grid($x, $y);
}

sub _check_grid {
  my $self = shift;
  my ($x, $y) = @_;

  return 1
    if (($x < $self->size) and ($y < $self->size));

  croak "position '"
    . $self->_grid2pos($x, $y, $self->skip_i)
    . "' not on board";
}

# This method returns a list of the hoshi points that should be found on the
# board, given its size.

sub _calc_hoshi {
  my $self = shift;
  my $size = $self->size;
  my $half = ($size - 1) / 2;

  my @hoshi = ();

  if ($size % 2) { push @hoshi, [ $half, $half ]; }  # middle center

  my $margin = ($size > 11 ? 4 : ($size > 6 ? 3 : ($size > 4 ? 2 : undef)));

  return \@hoshi unless $margin;

  push @hoshi, (
    [ $margin - 1, $margin - 1 ],                    # top left
    [ $size - $margin, $margin - 1 ],                # top right
    [ $margin - 1, $size - $margin ],                # bottom left
    [ $size - $margin, $size - $margin ]             # bottom right
  );

  if (($size % 2) && ($size > 9)) {
    push @hoshi, (
      [ $half, $margin - 1 ],                        # top center
      [ $margin - 1, $half ],                        # middle left
      [ $size - $margin, $half ],                    # middle right
      [ $half, $size - $margin ]                     # bottom center
    );
  }

  return \@hoshi;
}

# This subroutine passes every findable square on the board to the supplied
# subroutine reference.

sub _iterboard {
  my ($self, $sub) = @_;
  for my $x ('a' .. chr($self->size + ord("a") - 1)) {
    for my $y ('a' .. chr($self->size + ord("a") - 1)) {
      $sub->($self->get("$x$y"));
    }
  }

}

# This method accepts an (x,y) position, starting with (0,0) and returns the
# 'xy' text representing it.
# The third parameter, if true, indicates that 'i' should be skipped.

sub _grid2pos {
  my $self = shift;
  my ($x, $y, $skip_i) = @_;

  if ($skip_i) {
    for ($x, $y) {
      $_++ if ($_ >= 8);
    }
  }

  return chr($ORIGIN + $x) . chr($ORIGIN + $y);
}

# This method accepts an 'xy' position string and returns the (x,y) indexes
# where that position falls in the board.
# The second parameter, if true, indicates that 'i' should be skipped.

sub _pos2grid {
  my $self = shift;
  my ($pos, $skip_i) = @_;

  my ($xc, $yc) = (lc($pos) =~ /^([a-z])([a-z])$/);
  my ($x, $y);

  $x = ord($xc) - $ORIGIN;
  $x-- if ($skip_i and ($x > 8));

  $y = ord($yc) - $ORIGIN;
  $y-- if ($skip_i and ($y > 8));

  return ($x, $y);
}

package Games::Goban::Piece;

=head1 C<Games::Goban::Piece> methods

Here are the methods which can be called on a C<Games::Goban::Piece>
object, representing a piece on the board.

=cut

=head1 color

Returns "b" for a black piece and "w" for a white. C<colour> is also
provided for Anglophones.

=cut

sub color  { $_[0]->{colour} }
sub colour { $_[0]->{colour} }

=head1 notes

Similar to the C<notes> method on the board class, this provides a 
private area for callbacks to scribble on.

=cut

sub notes { $_[0]->{notes}->{ $_[1] } }

=head1 position

Returns the position of this piece, as a two-character string.
Incidentally, try to avoid taking references to C<Piece> objects, since
this stops them being destroyed in a timely fashion. Use a C<position>
and C<get> if you can get away with it, or take a weak reference if
you're worried about the piece going away or being replaced by another
one in that position.

=cut

sub position {
  my $piece = shift;

  ## no critic Private
  $piece->board->_grid2pos(@{ $piece->_xy }, $piece->board->skip_i);
}

sub _xy { $_[0]->{xy} }

=head1 move

Returns the move number on which this piece was played.

=cut

sub move { $_[0]->{move} }

=head1 board

Returns the board object whence this piece came.

=cut

sub board { $_[0]->{board} }

1;

=head1 TODO

=over

=item *

use Games::Goban::Board for game board

=item * 

add C<<$board->pass>>

=item *

possibly enable C<<$board->move('')>> to pass

=item *

produce example referee

=item *

produce sample method for removing captured stones

=back

=head1 SEE ALSO

Smart Game Format: http://www.red-bean.com/sgf/

C<Games::Go::SGF>

The US Go Association: http://www.usgo.org/

