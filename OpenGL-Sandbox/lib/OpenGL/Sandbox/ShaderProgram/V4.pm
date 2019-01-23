package OpenGL::Sandbox::ShaderProgram::V4;
use Moo;
use Carp;
use OpenGL::Sandbox qw(
	warn_gl_errors
	glCreateProgram glDeleteProgram glAttachShader glDetachShader glLinkProgram glUseProgram 
	glGetAttribLocation get_program_uniforms
	GL_LINK_STATUS GL_FALSE GL_TRUE GL_CURRENT_PROGRAM GL_ACTIVE_UNIFORMS
	GL_FLOAT GL_FLOAT_VEC2 GL_FLOAT_VEC3 GL_FLOAT_VEC4
	GL_INT GL_INT_VEC2 GL_INT_VEC3 GL_INT_VEC4
	GL_UNSIGNED_INT GL_UNSIGNED_INT_VEC2 GL_UNSIGNED_INT_VEC3 GL_UNSIGNED_INT_VEC4
	GL_FLOAT_MAT2 GL_FLOAT_MAT3 GL_FLOAT_MAT4
	GL_FLOAT_MAT2x3 GL_FLOAT_MAT2x4 GL_FLOAT_MAT3x2 GL_FLOAT_MAT3x4 GL_FLOAT_MAT4x2 GL_FLOAT_MAT4x3
);
use OpenGL::Modern::Helpers qw( glGetIntegerv_p glGetProgramInfoLog_p glGetProgramiv_p xs_buffer iv_ptr );

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
	$self->assembled(1);
}

sub _disassemble {
	my $self= shift;
	return unless $self->has_id && $self->assembled;
	glUseProgram(0) if glGetIntegerv_p(GL_CURRENT_PROGRAM, 1) == $self->id;
	$_->has_id && glDetachShader($self->id, $_->id) for $self->shader_list;
	$self->clear_uniforms;
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

sub _build_uniforms {
	get_program_uniforms(shift->id);
}

sub set_uniform {
	my $self= shift;
	OpenGL::Sandbox::set_uniform($self->id, $self->uniforms, @_);
	$self;
}

1;
