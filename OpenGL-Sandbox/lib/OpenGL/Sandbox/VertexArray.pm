package OpenGL::Sandbox::VertexArray;
use Moo 2;
use Try::Tiny;
use Carp;
use OpenGL::Sandbox qw( glGetString GL_VERSION GL_TRUE GL_FALSE GL_CURRENT_PROGRAM GL_ARRAY_BUFFER
	glGetAttribLocation_c glEnableVertexAttribArray glVertexAttribPointer_c );
# Attempt OpenGL 3 imports
try { OpenGL::Sandbox->import(qw( glBindVertexArray )) };
# Attempt OpenGL 4.3 imports
try { OpenGL::Sandbox->import(qw( glVertexAttribFormat glVertexAttribBinding )) };

# ABSTRACT: Object that encapsulates the mapping from buffer to vertex shader

=head DESCRIPTION

Vertex Arrays can be hard to grasp, since their implementation has changed in each major
version of OpenGL, but I found a very nice write-up in the accepted answer of:

L<https://stackoverflow.com/questions/21652546/what-is-the-role-of-glbindvertexarrays-vs-glbindbuffer-and-what-is-their-relatio>

In short, there needs to be something to indicate which bytes of the buffer map to which
vertex attributes as used in the shader.  The shader can declare anything it wants, and the
buffer can contain any record-size of data needed to pair with the shader.  This mapping is
called a "VertexArray" (who names these things??)

The oldest versions of OpenGL require this information to be applied on each buffer change.
The newer versions can cache that data in a virtual "Object", and the newest versions of OpenGL
can even link it together in a persistent manner.

This object attempts to represent one in a version-neutral manner.  Call L</apply> to make this
mapping "happen", however that needs to happen for the current GL context.  (or, at least this
is the goal of the object.  I haven't actually tested against each of the older versions of
OpenGL)

=head1 ATTRIBUTES

=head2 attributes

This is a hashref of the metadata for each attribute.  You can specify it without knowing the
index of an array, and that will be filled in later when it is applied to a program.

Each attribute is a hashref of:

  {
    name       => $text, # should match the named attribute of the Program
    index      => $n,    # vertex attribute index; discovered automatically during ->apply
    size       => $n,    # number of components per vertex attribute
    type       => $type, # GL_FLOAT, GL_INT, etc.
    normalized => $bool, # perl boolean
    stride     => $ofs,  # number of bytes between stored attributes, or 0 for "tightly packed"
    pointer    => $ofs,  # 
  }
    
=head2 id

For OpenGL 3.0+, this will be allocated upon demand.  For earlier OpenGL, this remains undef.

=cut

has attributes => ( is => 'rw', default => sub { +{} } );
has id         => ( is => 'lazy' );
sub _build_id {
	my $id= try { OpenGL::Sandbox::gen_vertex_arrays(1) };
	return $id; # if it's undef, then we don't need it.
}

=head1 METHODS

=head2 apply

  $vertex_array->apply($program, $buffer);

Make the configuration of this vertex array active.

=cut

sub apply {
	my ($self, $program, $buffer)= @_;
	my ($gl_maj, $gl_min)= split /[. ]/, glGetString(GL_VERSION);
	$program //= glGetInteger(GL_CURRENT_PROGRAM);
	if ($gl_maj >= 4 && $gl_min >= 3) {
		my $vao_id= $self->id || croak("Can't allocate Vertex Array Object ID?");
		glBindVertexArray($vao_id);
		# TODO: for 4.5 and up, can build the state once and then ->apply only needs
		#  to glBindVertexArray($vao_id) and then return.
		for my $aname (keys %{ $self->attributes }) {
			my $attr= $self->attributes->{$aname};
			my $attr_index= $attr->{index}
				// (ref $program? $program->attr_by_name($aname) : glGetAttribLocation_c($program, $aname));
			next unless defined $attr_index && $attr_index > 0;
			glEnableVertexAttribArray($attr_index);
			glVertexAttribFormat($attr_index, $attr->{size}, $attr->{type}, $attr->{normalized}? GL_TRUE:GL_FALSE, $attr->{stride}//0);
			glVertexAttribBinding($attr_index, 0);
		}
	}
	elsif ($gl_maj >= 2) {
		if ($gl_maj >= 3) {
			my $vao_id= $self->id || croak("Can't allocate Vertex Array Object ID?");
			glBindVertexArray($vao_id);
		}
		defined $buffer or die "Must pass buffer ID for OpenGL < 4";
		glBindBuffer(GL_ARRAY_BUFFER, ref $buffer? $buffer->id : $buffer);
		for my $aname (keys %{ $self->attributes }) {
			my $attr= $self->attributes->{$aname};
			my $attr_index= $attr->{index}
				// (ref $program? $program->attr_by_name($aname) : glGetAttribLocation_c($program, $aname));
			next unless defined $attr_index && $attr_index > 0;
			glVertexAttribPointer_c( $attr_index, $attr->{size}, $attr->{type}, $attr->{normalized}? GL_TRUE:GL_FALSE, $attr->{stride}//0, $attr->{pointer}//0 );
			glEnableVertexAttribArray( $attr_index );
		}
	}
	else {
		croak "No support for VertexArray prior to OpenGL 2.0";
	}
}

1;
