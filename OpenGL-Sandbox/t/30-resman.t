#! /usr/bin/env perl
use strict;
use warnings;
use FindBin;
use File::Spec::Functions 'catdir';
use Test::More;
use Log::Any::Adapter 'TAP';
use OpenGL::Sandbox qw/ make_context get_gl_errors /;
use OpenGL::Sandbox::ResMan;

my $ctx= eval { make_context(visible => 0) };
plan skip_all => "Can't create an OpenGL context: $@"
	unless $ctx;

my $res= OpenGL::Sandbox::ResMan->default_instance;
$res->resource_root_dir(catdir($FindBin::Bin, 'data'));
$res->tex_config({
	default => '8x8',
});

# Can't run font tests without a separate font module
#$res->font_config({
#	default => 'squada',
#	squada  => { filename => 'SquadaOne-Regular', face_size => 32 },
#});
# isa_ok( $res->font('default'), 'OpenGL::Sandbox::Font', 'load default font'  );
# is( $res->font('squada')->data, $res->font('default')->data, 'Empty is default' );
# is( $res->font('default')->ascender, 28, 'look up ascender' );

is( $res->tex_default_fmt, 'bgr', 'default pixel format' );

isa_ok( $res->tex('default'), 'OpenGL::Sandbox::Texture', 'load default tex' );
is( $res->tex('8x8'), $res->tex('default'), '8x8 is default' );
$res->tex('8x8')->load;
is( $res->tex('8x8')->width, 8, 'width=8' );

done_testing;
