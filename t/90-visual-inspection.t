#! /usr/bin/env perl
use strict;
use warnings;
use FindBin;
use File::Spec::Functions 'catdir';
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

# First frame seems to get lost, unless I sleep a bit
sleep 1;
$glx->display->flush_sync;
$glx->begin_frame;
OpenGL::glClearColor(0,0,1,1);
OpenGL::glClear(OpenGL::GL_COLOR_BUFFER_BIT);
$glx->end_frame;
$glx->display->flush_sync;
sleep 1;

# Render texture at 0,0
OpenGL::glClearColor(0,0,0,1);
OpenGL::glEnable(OpenGL::GL_TEXTURE_2D);
#OpenGL::glBlendFunc(OpenGL::GL_SRC_ALPHA, OpenGL::GL_ONE);
$res->tex('8x8')->wrap_s(OpenGL::GL_CLAMP);
$res->tex('8x8')->wrap_t(OpenGL::GL_CLAMP);

# Render scaled to 1/4 the window
$glx->begin_frame;
$res->tex('8x8')->render(scale => 16);
$glx->end_frame;
$glx->display->flush_sync;
sleep 1;

# Render full-window, ignoring native texture dimensions
$glx->begin_frame;
$res->tex('8x8')->render(w => 256, center => 1);
$glx->end_frame;
$glx->display->flush_sync;
sleep 1;

# Render repeated 9 times across the window
$res->tex('8x8')->wrap_s(OpenGL::GL_REPEAT);
$res->tex('8x8')->wrap_t(OpenGL::GL_REPEAT);
$glx->begin_frame;
$res->tex('8x8')->render(w => 256, center => 1, s_rep => 9, t_rep => 9);
$glx->end_frame;
$glx->display->flush_sync;
sleep 1;

done_testing;
