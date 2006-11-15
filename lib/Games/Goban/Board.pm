use strict;
use warnings;

package Games::Goban::Board;
use base qw(Games::Board::Grid);

=head1 NAME

Games::Goban::Board -- a go board built from Games::Board

=head1 VERSION

  $Id$

=cut

our $VERSION = '1.100';

=head1 SYNOPSIS

  use Games::Goban::Board;

  my $board = Games::Goban::Board->new(size => 19);

  # etc

This class exists is primarily for use (for now) by Games::Goban, which
currently implements its own board, badly.

=head1 DESCRIPTION

This module provides a class for representing a go board and pieces.

=cut

=head1 METHODS

The methods of this class are not substantially changed from those of
Games::Board.  Space id's are more go-like.  New pieces are blessed into the
class Games::Goban::Piece, which provides a few historical methods for
Games::Goban's consumption.

=cut

my $origin = ord('a');

sub piececlass { 'Games::Goban::Piece' }

sub new {
  my ($self, %opts) = @_;

  my $board = $self->SUPER::new(%opts);
  $board->{skip_i} = defined $opts{skip_i} ? $opts{skip_i} : 0;

  $board;
}

sub index2id {
  my ($self, $loc) = @_;

  my $id = chr($origin + $loc->[0]) . chr($origin + $loc->[1]);

  $id =~ tr/[i-s]/[j-t]/ if $self->{skip_i};

  $id;
}

sub id2index {
  my ($self, $id) = @_;

  $id =~ tr/[j-t]/[i-s]/ if $self->{skip_i};

  my @loc = split //, $id;

  $_ = ord($_) - $origin for @loc;
  \@loc;
}

package Games::Goban::Piece;
use base qw(Games::Board::Piece);

my $next_id = 0;

sub new {
  my ($class, %args) = @_;

  $args{id} ||= ++$next_id;

  my $self = $class->SUPER::new(%args);

  $self->{color} = $args{color};
  $self->{notes} = $args{notes};
  $self->{move}  = $args{move};

  bless $self => $class;
}

sub notes    { (shift)->{notes} }
sub position { (shift)->current_space_id }

sub moved_on { (shift)->{move} }

sub color  { my $self = shift; $self->{color} }
sub colour { my $self = shift; $self->{color} }

=head1 AUTHOR

Ricardo SIGNES E<lt>rjbs@cpan.orgE<gt>

=head1 COPYRIGHT

Copyright 2004 by Ricardo Signes E<lt>rjbs@cpan.orgE<gt>

This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut

1;
