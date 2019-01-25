package OpenGL::Sandbox::VertexArray;
use Moo 2;
use Try::Tiny;
use Carp;
use OpenGL::Sandbox qw( glGetString GL_VERSION GL_TRUE GL_FALSE GL_CURRENT_PROGRAM GL_ARRAY_BUFFER
	glGetAttribLocation_c glEnableVertexAttribArray glVertexAttribPointer_c );
BEGIN {
	# Attempt OpenGL 3 imports
	try { OpenGL::Sandbox->import(qw( glBindVertexArray GL_ARRAY_BUFFER_BINDING )) };
	# Attempt OpenGL 4.3 imports
	try { OpenGL::Sandbox->import(qw( glVertexAttribFormat glVertexAttribBinding )) };
}

# ABSTRACT: Object that encapsulates the mapping from buffer to vertex shader
# VERSION

=head DESCRIPTION

Vertex Arrays can be hard to grasp, since their implementation has changed in each major
version of OpenGL, but I found a very nice write-up in the accepted answer of:

L<https://stackoverflow.com/questions/21652546/what-is-the-role-of-glbindvertexarrays-vs-glbindbuffer-and-what-is-their-relatio>

In short, there needs to be something to indicate which bytes of the buffer map to which
vertex attributes as used in the shader.  The shader can declare anything attributes it wants,
and the buffer(s) need to contain matching arrangement of data.  This configuration
is called a "VertexArray" (who names these things??)

The oldest versions of OpenGL require this information to be applied on each buffer change.
The newer versions can cache the configuration in an Object, and the newest versions of OpenGL
can set it up without mucking around with global state.

This object attempts to represent the configuration in a version-neutral manner.  There are two
phases: L</construct> and L</apply>.  On old OpenGL, C<construct> does nothing, since there is
no way to cache the results, and C<apply> does all the work.  On new OpenGL (3.0 and up) the
C<construct> step creates a cached VertexArray, and C<apply> binds it.  All you need to do is
call C<apply> and it will C<construct> if needed.

=head1 ATTRIBUTES

=head2 attributes

This is a hashref of the metadata for each attribute.  You can specify it without knowing the
index of an array, and that will be filled in later when it is applied to a program.

Each attribute is a hashref of:

  {
    name       => $text,   # should match the named attribute of the Program
    index      => $n,      # vertex attribute index; use undef to lookup by name
    buffer     => $buffer, # buffer this attribute comes from. Leave undef to use current buffer.
                           # This can also be a buffer ID integer.
    size       => $n,      # number of components per vertex attribute
    type       => $type,   # GL_FLOAT, GL_INT, etc.
    normalized => $bool,   # perl boolean, whether to remap ints to float [0..1)
    stride     => $ofs,    # number of bytes between stored attributes, or 0 for "tightly packed"
    pointer    => $ofs,    # byte offset into $buffer of first element, defaults to 0
  }
    
=head2 id

For OpenGL 3.0+, this will be allocated upon demand.  For earlier OpenGL, this remains undef.

=head2 buffer

You can specify a buffer on each attribute, or specify it in the call to C<apply>, or you can
supply a default buffer here that will be used for all the attributes.  If given a hashref,
it will be inflated to a buffer object.  If you give an integer, it will be used directly.

This is most useful for the following:

  my $vao= $res->new_vao({
    buffer => { data => pack('f*', @coordinates) },
    attributes => {
      position => { size => 3, type => GL_FLOAT, stride => 32 },
      normal   => { size => 3, type => GL_FLOAT, stride => 32 },
      texcoord => { size => 2, type => GL_FLOAT, stride => 32 },
    }
  });

=cut

has attributes  => ( is => 'rw', default => sub { +{} } );
has id          => ( is => 'lazy', predicate => 1 );
has constructed => ( is => 'rw' );
has buffer      => ( is => 'rw', coerce => sub { ref $_[0] eq 'HASH'? OpenGL::Sandbox::Buffer->new($_[0]) : $_[0] } );

sub _build_id {
	my $id= try { OpenGL::Sandbox::gen_vertex_arrays(1) };
	return $id; # if it's undef, then we don't need it.
}

sub DESTROY {
	OpenGL::Sandbox::delete_vertex_arrays(delete $_[0]{id})
		if $_[0]->has_id && $_[0]->id;
}

sub _choose_implementation {
	my $self= shift;
	my ($gl_maj, $gl_min)= split /[. ]/, glGetString(GL_VERSION);
	my $subclass= $gl_maj < 3? 'V2' : $gl_maj < 4 || $gl_min < 3? 'V3' : 'V4_3';
	bless $self, ref($self).'::'.$subclass;
}
@OpenGL::Sandbox::VertexArray::V2::ISA= ( __PACKAGE__ );
@OpenGL::Sandbox::VertexArray::V3::ISA= ( __PACKAGE__ );
@OpenGL::Sandbox::VertexArray::V4_3::ISA= ( __PACKAGE__ );

=head1 METHODS

=head2 apply

  $vertex_array->apply($program, $buffer);

Make the configuration of this vertex array active for drawing.  This might cause a cascade of
effects, like binding buffers, loading buffers, binding the vertex array object, looking up
program attributes, and enabling and configuring the attributes.  Steps which don't need
repeated won't be.

If C<$program> is not given, the current one will be used for any attribute-index lookups.
If C<$buffer> is not given, the current GL_VERTEX_ARRAY buffer will be used (unless an
attribute configuration specifies otherwise).

=cut

sub apply {
	$_[0]->_choose_implementation;
	shift->apply(@_);
}

sub construct {
	$_[0]->_choose_implementation;
	shift->construct(@_);
}

sub _bind_buffer_unless_current {
	my ($buffer, $current)= @_;
	if (ref $buffer) {
		$buffer->bind(GL_ARRAY_BUFFER) unless $buffer->id == $current;
		return $buffer->id;
	}
	else {
		glBindBuffer(GL_ARRAY_BUFFER, $buffer) unless $buffer == $current;
		return $buffer;
	}
}

sub OpenGL::Sandbox::VertexArray::V2::apply {
	my ($self, $program, $default_buffer)= @_;
	$program //= OpenGL::Sandbox::_gl_get_integer(GL_CURRENT_PROGRAM);
	my $cur_buffer= OpenGL::Sandbox::_gl_get_integer(GL_ARRAY_BUFFER_BINDING);
	$default_buffer //= $self->buffer // $cur_buffer;
	for my $aname (keys %{ $self->attributes }) {
		my $attr= $self->attributes->{$aname};
		my $attr_index= $attr->{index}
			// (ref $program? $program->attr_by_name($aname) : glGetAttribLocation_c($program, $aname));
		if (defined $attr_index && $attr_index > 0) {
			$cur_buffer= _bind_buffer_unless_current($attr->{buffer} // $default_buffer, $cur_buffer);
			glVertexAttribPointer_c( $attr_index, $attr->{size}, $attr->{type}, $attr->{normalized}? GL_TRUE:GL_FALSE, $attr->{stride}//0, $attr->{pointer}//0 );
			glEnableVertexAttribArray( $attr_index );
		}
		else {
			carp "No such attribute '$aname'";
		}
	}
}

sub OpenGL::Sandbox::VertexArray::V2::construct {}

sub OpenGL::Sandbox::VertexArray::V3::apply {
	my ($self, $program, $default_buffer)= @_;
	$self->constructed? glBindVertexArray($self->id) : $self->construct($program, $default_buffer);
}

sub OpenGL::Sandbox::VertexArray::V3::construct {
	my ($self, $program, $default_buffer)= @_;
	my $vao_id= $self->id || croak("Can't allocate Vertex Array Object ID?");
	glBindVertexArray($vao_id);
	OpenGL::Sandbox::VertexArray::V2::apply(@_);
	$self->constructed(1);
}

sub OpenGL::Sandbox::VertexArray::V4_3::apply {
	my ($self, $program, $default_buffer)= @_;
	$self->constructed? glBindVertexArray($self->id) : $self->construct($program, $default_buffer);
}

sub OpenGL::Sandbox::VertexArray::V4_3::construct {
	my ($self, $program, $default_buffer)= @_;
	my $vao_id= $self->id || croak("Can't allocate Vertex Array Object ID?");
	glBindVertexArray($vao_id);
	$program //= OpenGL::Sandbox::_gl_get_integer(GL_CURRENT_PROGRAM);
	my $cur_buffer= OpenGL::Sandbox::_gl_get_integer(GL_ARRAY_BUFFER_BINDING);
	$default_buffer //= $cur_buffer;
	for my $aname (keys %{ $self->attributes }) {
		my $attr= $self->attributes->{$aname};
		my $attr_index= $attr->{index}
			// (ref $program? $program->attr_by_name($aname) : glGetAttribLocation_c($program, $aname));
		if (defined $attr_index && $attr_index > 0) {
			$cur_buffer= _bind_buffer_unless_current($attr->{buffer} // $default_buffer, $cur_buffer);
			glEnableVertexAttribArray($attr_index);
			glVertexAttribFormat($attr_index, $attr->{size}, $attr->{type}, $attr->{normalized}? GL_TRUE:GL_FALSE, $attr->{stride}//0);
			glVertexAttribBinding($attr_index, 0);
		}
		else {
			carp "No such attribute '$aname'";
		}
	}
	$self->constructed(1);
}

# TODO: for 4.5 and up, can construct without binding the VAO, and no need to change
# buffer binding.

1;
