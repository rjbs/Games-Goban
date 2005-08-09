use ExtUtils::MakeMaker;

WriteMakefile(
	'NAME'         => 'Games::Goban',
	'VERSION_FROM' => 'lib/Games/Goban.pm', # finds $VERSION
	'PREREQ_PM'    => { 'Games::Board::Grid' => 1.003 },
	'PREREQ_PRINT' => 1
);
