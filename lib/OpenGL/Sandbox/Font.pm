package OpenGL::Sandbox::Font;
use strict;
use warnings;
use Cwd;
use OpenGL::Sandbox::MMap;

use Inline CPP => do { my $x= __FILE__; $x =~ s/\.pm$/\.cpp/; $x },
	INC => '-I/usr/include/FTGL -I/usr/include/freetype2 -I'
	       .do{ my $x= __FILE__; $x =~ s|/[^/]+$||; Cwd::abs_path($x) },
	LIBS => '-lfreetype -lftgl';

push @OpenGL::Sandbox::Font::TextureFont, __PACKAGE__;

our %h_align_map= ( left => 1, center => 2, right => 3 );
our %v_align_map= ( top => 4, center => 3, base => 2, bottom => 1 );

sub render {
	my ($self, $text, %opts)= @_;
	my $h_align= $opts{h_align}? $h_align_map{$opts{h_align}}//1 : 1;
	my $v_align= $opts{v_align}? $v_align_map{$opts{v_align}}//1 : 1;
	my $monospace= $opts{monospace} // 0;
	if ($opts{x} or $opts{y} or $opts{scale} or $opts{height}) {
		my $x= $opts{x} || 0;
		my $y= $opts{y} || 0;
		my $scale= $opts{scale} // ($opts{height}? $opts{height} / $self->ascender : 1);
		$self->render_xy_scale_text($x, $y, $scale, $text, $h_align, $v_align, $monospace);
	} else {
		$self->render_text($text, $h_align, $v_align, $monospace);
	}
}

1;