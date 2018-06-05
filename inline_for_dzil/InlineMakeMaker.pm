package inc::InlineMakeMaker;
use Moose;

extends 'Dist::Zilla::Plugin::MakeMaker::Awesome';

override _build_MakeFile_PL_template => sub {
	my $tpl= shift->next::method(@_);
	$tpl =~ s/ExtUtils::MakeMaker/Inline::MakeMaker/g;
	return $tpl;
};
override register_prereqs => sub {
	$_[0]->zilla->register_prereqs(
		{ phase => 'configure' },
		'Inline::MakeMaker' => 0.45,
	);
	shift->next::method(@_);
};

__PACKAGE__->meta->make_immutable;
