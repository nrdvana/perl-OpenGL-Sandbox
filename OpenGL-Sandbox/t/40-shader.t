#! /usr/bin/env perl
use strict;
use warnings;
use FindBin;
use Try::Tiny;
use Test::More;
use lib "$FindBin::Bin/lib";
use Log::Any::Adapter 'TAP';
use OpenGL::Sandbox qw/ make_context get_gl_errors /;
use OpenGL::Sandbox::Shader;
use OpenGL::Sandbox::ShaderProgram;

plan skip_all => "Can't create an OpenGL context: $@"
	unless eval { make_context(); 1 };

plan skip_all => "No support for modern shaders in this OpenGL context: $@"
	unless eval { OpenGL::Sandbox::Shader::choose_implementation }
		and eval { OpenGL::Sandbox::ShaderProgram::choose_implementation };

my $simple_vertex_shader= <<END;
attribute vec4 pos;
uniform   mat4 mat;
void main() {
    gl_Position = mat * pos;
}
END

my $simple_fragment_shader= <<END;
void main() {
	gl_FragColor = vec4(0,1,0,0);
}
END

subtest vertex_shader => \&test_vertex_shader;
sub test_vertex_shader {
	my $vs= new_ok( 'OpenGL::Sandbox::Shader', [ filename => 'demo.vert', source => $simple_vertex_shader ] );
	ok( eval { $vs->load; 1 }, 'compiled vertex shader' )
		or diag $@;
	done_testing;
}

subtest shader_program => \&test_shader_program;
sub test_shader_program {
	my $prog= new_ok( 'OpenGL::Sandbox::ShaderProgram', [ name => 'Test' ], shaders => {} );
	$prog->{shaders}{vertex}= OpenGL::Sandbox::Shader->new(filename => 'demo.vert', source => $simple_vertex_shader);
	$prog->{shaders}{fragment}= OpenGL::Sandbox::Shader->new(filename => 'demo.frag', source => $simple_fragment_shader);
	ok( eval { $prog->compile; 1 }, 'compiled GL shader pipeline' )
		or diag $@;
	done_testing;
}

done_testing;
