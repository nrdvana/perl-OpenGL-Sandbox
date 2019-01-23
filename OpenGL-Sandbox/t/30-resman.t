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

# ResMan can be configured direct from OpenGL::Sandbox
OpenGL::Sandbox->import(-resources => { path => catdir($FindBin::Bin, 'data') });
is( $res->path, catdir($FindBin::Bin, 'data'), 'path was changed' );

$res->tex_config({
	default => '8x8',
});

my $imported_res= eval 'package Test::Ns1; use OpenGL::Sandbox q{$res}; $res';
is( $imported_res, $res, 'can import resource manager' )
	or diag $@;


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

isa_ok( $res->shader('zero.frag'), 'OpenGL::Sandbox::Shader', 'load a shader' );
isa_ok( $res->program('zero'), 'OpenGL::Sandbox::Program', 'load a shader program' );
like( $res->program('zero')->shaders->{vert}->filename, qr/zero.vert$/, 'found vert shader of prog "zero"' );
like( $res->program('zero')->shaders->{frag}->filename, qr/zero.frag$/, 'found frag shader of prog "zero"' );

done_testing;
