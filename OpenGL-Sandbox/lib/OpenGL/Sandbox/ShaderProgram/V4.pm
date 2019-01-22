package OpenGL::Sandbox::ShaderProgram::V4;
use Moo;
use Carp;
use OpenGL::Sandbox qw(
	warn_gl_errors
	glCreateProgram glDeleteProgram glAttachShader glDetachShader glLinkProgram glUseProgram 
	glGetAttribLocation glGetActiveUniform_c glGetUniformLocation_c
	glUniform4fv_c
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
	$self->clear_uniform_meta;
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
	$self->_assemble unless $self->assembled;
	my $id= glGetAttribLocation($self->id, $name);
	return $id < 0? undef : $id;
}

sub _uniform_by_name {
	my ($self, $name)= @_;
	$self->_assemble unless $self->assembled;
	my $id= glGetUniformLocation_c($self->id, $name);
	return $id < 0? undef : $id;
}

sub get_active_uniforms {
	my $self= shift;
	$self->_assemble unless $self->assembled;
	my $count= glGetProgramiv_p($self->id, GL_ACTIVE_UNIFORMS);
	return map {
		# Names are maximum 16 chars:
		my ($length, $size, $type);
		xs_buffer(my $name, 16);
		glGetActiveUniform_c($self->id, $_, 16, iv_ptr($length, 8), iv_ptr($size, 8), iv_ptr($type, 8), $name);
		$length= unpack 'I', $length;
		$size= unpack 'I', $size;
		$type= unpack 'I', $type;
		+{ name => substr($name, 0, $length), size => $size, type => $type }
	} 0 .. $count-1;
}

my %uniform_type_to_name= (
	GL_FLOAT, 'float',
	GL_FLOAT_VEC2, 'vec2',
	GL_FLOAT_VEC3, 'vec3',
	GL_FLOAT_VEC4, 'vec4',
	GL_INT, 'int',
	GL_INT_VEC2, 'ivec2',
	GL_INT_VEC3, 'ivec3',
	GL_INT_VEC4, 'ivec4',
	GL_UNSIGNED_INT, 'unsigned_int',
	GL_UNSIGNED_INT_VEC2, 'uvec2',
	GL_UNSIGNED_INT_VEC3, 'uvec3',
	GL_UNSIGNED_INT_VEC4, 'uvec4',
	GL_FLOAT_MAT2, 'mat2',
	GL_FLOAT_MAT3, 'mat3',
	GL_FLOAT_MAT4, 'mat4',
	GL_FLOAT_MAT2x3, 'mat2x3',
	GL_FLOAT_MAT2x4, 'mat2x4',
	GL_FLOAT_MAT3x2, 'mat3x2',
	GL_FLOAT_MAT3x4, 'mat3x4',
	GL_FLOAT_MAT4x2, 'mat4x2',
	GL_FLOAT_MAT4x3, 'mat4x3',
);
has uniform_meta => ( is => 'lazy', predicate => 1, clearer => 1 );
sub _build_uniform_meta {
	+{ map {
		$_->{setter}= '_set_uniform_'.$uniform_type_to_name{$_->{type}};
		($_->{name} => $_)
	   } shift->get_active_uniforms }
}

sub set_uniform {
	my ($self, $name)= (shift, shift);
	$self->_assemble unless $self->assembled;
	my $u= $self->uniform_meta->{$name} or croak "No such uniform '$name'";
	my $m= $u->{setter} or croak "Don't know how to set uniforms of type $u->{type}";
	my $loc= $self->uniform_by_name($name);
	$loc >= 0 or croak "No location for uniform '$name'";
	$self->$m($loc, @_);
}

sub _set_uniform_vec4 {
	my ($self, $loc)= (shift, shift);
	my $buf= @_ == 4? pack('f*', @_)
		: @_ == 1 && ref $_[0] eq 'ARRAY'? pack('f*', @{$_[0]})
		: @_ == 1 && ref($_[0])->can('ptr')? $_[0]
		: croak "Invalid arguments for vec4";
	gUniform4fv_c($loc, 1, ref $buf? $buf->ptr : iv_ptr($buf));
}

sub _set_uniform_mat4 {
	my ($self, $loc)= (shift, shift);
	my $buf= @_ == 16? pack('f*', @_)
		: @_ == 1 && ref $_[0] eq 'ARRAY'? pack('f*', @{$_[0]})
		: @_ == 1 && ref($_[0])->can('ptr')? $_[0]
		: croak "Invalid arguments for mat4";
	glUniform4fv_c($loc, 4, ref $buf? $buf->ptr : iv_ptr($buf));
}

1;
