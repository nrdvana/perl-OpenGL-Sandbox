package OpenGL::Sandbox::ShaderProgram::V4;
use Moo;
use Carp;
use OpenGL::Sandbox qw(
	warn_gl_errors
	glCreateProgram glDeleteProgram glAttachShader glDetachShader glLinkProgram glUseProgram 
	glGetAttribLocation glGetUniformLocation
	GL_LINK_STATUS GL_FALSE GL_TRUE GL_CURRENT_PROGRAM
);
use OpenGL::Modern::Helpers qw( glGetIntegerv_p glGetProgramInfoLog_p glGetProgramiv_p );

has assembled => ( is => 'rw' );

sub _build_id {
	my $self= shift;
	warn_gl_errors;
	my $id= glCreateProgram();
	$id && !warn_gl_errors or croak "glCreateProgram failed";
	my $log= glGetProgramInfoLog_p($id);
	warn "Shader Program ".$self->name.": ".$log
		if $log;
	$id;
}

sub _assemble {
	my $self= shift;
	return if $self->assembled;
	my $id= $self->id;
	warn_gl_errors;
	for ($self->shader_list) {
		$_->load; # also compiles
		glAttachShader($id, $_->id);
		!warn_gl_errors
			or croak "glAttachShader failed: ".glGetProgramInfoLog_p($id);
	}
    glLinkProgram($id);
	!warn_gl_errors and glGetProgramiv_p($id, GL_LINK_STATUS) == GL_TRUE
		or croak "glLinkProgram failed: ".glGetProgramInfoLog_p($id);
}

sub _disassemble {
	my $self= shift;
	return unless $self->has_id && $self->assembled;
	glUseProgram(0) if glGetIntegerv_p(GL_CURRENT_PROGRAM, 1) == $self->id;
	$_->has_id && glDetachShader($self->id, $_->id) for @{ $self->shader_list };
	$self->assembled(0);
}

sub _activate {
	my $self= shift;
	$self->_assemble unless $self->assembled;
	glUseProgram($self->id);
}

sub DESTROY {
	my $self= shift;
	if ($self->has_id) {
		$self->_disassemble;
		glDeleteProgram(delete $self->{id});
	}
}

sub _attr_by_name {
	my ($self, $name)= @_;
	$self->_compile unless $self->compiled;
	my $id= glGetAttribLocation($self->id, $name);
	return $id < 0? undef : $id;
}

sub _uniform_by_name {
	my ($self, $name)= @_;
	$self->_compile unless $self->compiled;
	my $id= glGetUniformLocation($self->id, $name);
	return $id < 0? undef : $id;
}

1;
