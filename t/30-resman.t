#! /usr/bin/env perl
use strict;
use warnings;
use FindBin;
use File::Spec::Functions 'catdir';
use Test::More;
use Log::Any::Adapter 'TAP';
use X11::GLX::DWIM;

use_ok( 'OpenGL::Sandbox::ResMan' ) or BAIL_OUT;

my $glx= X11::GLX::DWIM->new(window => 1);
note 'GL Version '.$glx->glx_version;
$glx->target($glx->create_render_pixmap({ width => 100, height => 100 }));

my $res= OpenGL::Sandbox::ResMan->default_instance;
$res->resource_root_dir(catdir($FindBin::Bin, 'data'));

isa_ok( $res->font('default'), 'OpenGL::Sandbox::Font', 'load default font'  );
is( $res->font('Empty')->data, $res->font('default')->data, 'Empty is default' );
is( $res->font('Empty')->ascender, 0, 'look up ascender' );

is( $res->tex_default_fmt, 'bgr', 'default pixel format' );

isa_ok( $res->tex('default'), 'OpenGL::Sandbox::Texture', 'load default tex' );
is( $res->tex('8x8'), $res->tex('default'), '8x8 is default' );
is( $res->tex('8x8')->width, 8, 'width=8' );

done_testing;
