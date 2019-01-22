package OpenGL::Sandbox::Shader::V4;
use Carp;
use OpenGL::Sandbox qw(
	warn_gl_errors
	glCreateShader glDeleteShader glCompileShader
	GL_FRAGMENT_SHADER GL_VERTEX_SHADER GL_COMPILE_STATUS GL_FALSE
);
use OpenGL::Modern::Helpers qw( glShaderSource_p glGetShaderiv_p glGetShaderInfoLog_p );

sub _build_id {
	my $self= shift;
	my $type= defined $self->type? $self->type
		: $self->filename =~ /\.frag$/i? GL_FRAGMENT_SHADER
		: $self->filename =~ /\.vert$/i? GL_VERTEX_SHADER
		: croak "No shader type specified, and don't recognize file extension";
	my $id= glCreateShader($type);
	warn_gl_errors and croak "glCreateShader failed";
	$self->type($type);
	$id;
}

sub _load {
	my ($self, $fname)= @_;
	my $id= $self->id;
	# TODO: check for binary pre-compiled shaders
	my $source= $self->source // do { ${OpenGL::Sandbox::MMap->new($fname)} };
	glShaderSource_p($id, $source);
	warn_gl_errors and croak("glShaderSource failed (for $fname)");
	glCompileShader($id);
	warn_gl_errors and croak("glCompileShader failed (for $fname)");
	if (glGetShaderiv_p($id, GL_COMPILE_STATUS) == GL_FALSE) {
		my $log= glGetShaderInfoLog_p($id);
		croak "Error in shader: $log";
    }
	$self->loaded(1);
}

sub _destroy {
	my $self= shift;
	glDeleteShader($self->shader_id) if $self->has_shader_id;
	delete $self->{shader_id};
}

1;
