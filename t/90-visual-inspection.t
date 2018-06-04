#! /usr/bin/env perl
use strict;
use warnings;
use FindBin;
use File::Spec::Functions 'catdir';
use Time::HiRes 'sleep';
use Test::More;
use Log::Any::Adapter 'TAP';
use X11::GLX::DWIM;

use_ok( 'OpenGL::Sandbox::ResMan' ) or BAIL_OUT;

my $glx= X11::GLX::DWIM->new();
$glx->target({ window => { width => 256, height => 256 }}); # instantiate target
$glx->apply_gl_projection(left => -128, right => 128, top => 128, bottom => -128, ortho => 1, z => 10);
note 'GLX Version '.$glx->glx_version;

my $res= OpenGL::Sandbox::ResMan->default_instance;
$res->resource_root_dir(catdir($FindBin::Bin, 'data'));
$res->font_config({
	default => { filename => 'SquadaOne-Regular', face_size => 32 }
});
$res->tex_config({
	default => '8x8',
});

# First frame seems to get lost, unless I sleep a bit
$glx->display->flush_sync;
sleep 1;

OpenGL::glEnable(OpenGL::GL_TEXTURE_2D);
OpenGL::glEnable(OpenGL::GL_BLEND);
OpenGL::glBlendFunc(OpenGL::GL_SRC_ALPHA, OpenGL::GL_ONE);

sub show(&) {
	$glx->begin_frame;
	shift->();
	$glx->end_frame;
	$glx->display->flush_sync;
	sleep .5;
}

# Render solid blue, as a test
OpenGL::glClearColor(0,0,1,1);
show {
};
# Render texture at 0,0
OpenGL::glClearColor(0,0,0,1);
$res->tex('8x8')->wrap_s(OpenGL::GL_CLAMP);
$res->tex('8x8')->wrap_t(OpenGL::GL_CLAMP);
show {
	$res->tex('8x8')->render;
};

# Render scaled to 1/4 the window
show {
	$res->tex('8x8')->render(scale => 16);
};

# Render full-window, ignoring native texture dimensions
show {
	$res->tex('8x8')->render(w => 256, center => 1);
};

# Render repeated 9 times across the window
$res->tex('8x8')->wrap_s(OpenGL::GL_REPEAT);
$res->tex('8x8')->wrap_t(OpenGL::GL_REPEAT);
show {
	$res->tex('8x8')->render(w => 256, center => 1, s_rep => 9, t_rep => 9);
};

# Render with alpha blending, and with non-square aspect texture
OpenGL::glClearColor(0,.2,.3,1);
show {
	$res->tex('14x7-rgba')->render(w => 256, center => 1, s_rep => 9, t_rep => 9);
};

# Render with baseline at origin
show {
	$res->font('default')->render("Left Baseline");
};

# Render with baseline at origin
show {
	$res->font('default')->render("Right Baseline", xalign => 1);
};

show {
	$res->font('default')->render('Center Baseline', xalign => .5);
};
show {
	$res->font('default')->render("Top", xalign => .5, yalign => 1);
};
show {
	$res->font('default')->render("Center", xalign => .5, yalign => .5);
};
show {
	$res->font('default')->render("Bottom", xalign => .5, yalign => -1);
};
show {
	$res->font('default')->render('Width=200', width => 200, xalign => .5);
};
show {
	$res->font('default')->render('Scale 3x', xalign => .5, scale => 3);
};
show {
	$res->font('default')->render('Width=200,Height=50', width => 200, height => 50, xalign => .5);
};
show {
	$res->font('default')->render("monospaced", x => -100, monospace => 15);
};

done_testing;
