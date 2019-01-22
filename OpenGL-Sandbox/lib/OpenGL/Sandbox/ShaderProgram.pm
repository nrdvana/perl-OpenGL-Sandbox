package OpenGL::Sandbox::ShaderProgram;
use Moo;
use Carp;
use Try::Tiny;
use OpenGL::Sandbox::MMap;
our @ISA= 'OpenGL::Sandbox::ShaderProgram::Trampoline';

sub choose_implementation {
	my $jump_to_method= shift;
	@ISA= ();
	eval { extends 'OpenGL::Sandbox::ShaderProgram::V4'; 1; }
	or croak "Your OpenGL does not support version-4 shaders\n".$@;
	return shift->$jump_to_method(@_) if $jump_to_method;
	return 1;
}

sub OpenGL::Sandbox::ShaderProgram::Trampoline::_build_id { choose_implementation('_build_id', @_) }
sub OpenGL::Sandbox::ShaderProgram::Trampoline::_load     { choose_implementation('_load', @_) }

# ABSTRACT: Wrapper object for OpenGL shader program pipeline
# VERSION

=head1 DESCRIPTION

OpenGL Shader get assembled into a pipeline.  In older versions of OpenGL, there was only one
program composed of a vertex shader and fragment shader, and attacking one of those shaders was
global.  In newer OpenGL, you may assemble multiple programs and switch between them.

This class tries to support both APIs, by holding a set of shaders which you can then "activate".
On newer OpenGL, this calls C<glUseProgram>.  On older OpenGL, this changes the global vertex
and fragment shaders to the ones referenced by this object.

=head1 ATTRIBUTES

=head2 id

The OpenGL integer 'name' of this program.  On older OpenGL with the global program, this will
always be C<undef>.  On newer OpenGL, this should always return a value because accessing it
will call C<glCreateProgram>.

=over

=item has_id

True if the id attribute has been lazy-loaded already.

=back

=head2 name

A friendly name for the program (as used by the L<OpenGL::Sandbox::ResMan|Resource Manager>).

=head2 linked

Boolean; whether the program is ready to run.  This is always 'true' for older global-program
OpenGL.

=head2 shaders

A hashref of shaders, each of which will be attached to the program when it is activated.
The keys of the hashref are up to you, and simply to help diagnostics or merging shader
configurations together with defaults.

=head2 shader_list

A convenient accessor for listing out the values of the L</shader> hash.

=cut

has name       => ( is => 'rw' );
has id         => ( is => 'lazy' );
has shaders    => ( is => 'rw' );
sub shader_list { values %{ shift->shaders } }

has compiled         => ( is => 'rw' );
has _attribute_cache => ( is => 'rw' );
has _uniform_cache   => ( is => 'rw' );

=head1 METHODS

=head2 activate

  $program->activate;

Begin using this program as the active GL pipeline.

Returns C<$self> for convenient chaining.

=cut

sub activate {
	my $self= shift;
	$self->_activate;
	$self;
}

=head2 compile

For implementations where it matters, this attaches the shaders and links the program.
If it fails, this throws an exception.  For OpenGL 4 implementation, this only happens
once, and any changes to L</shaders> afterward are ignored.

Returns C<$self> for convenient chaining.

=cut

sub compile {
	my $self= shift;
	$self->_compile unless $self->compiled;
	$self->compiled(1);
	$self;
}

=head2 attr_by_name

Return the attribute ID of the given name, for the assembled program.

=head2 uniform_by_name

Return the uniform ID of the given name, for the assembled program.

=head2 set_uniform

  $prog->set_uniform( $name, \@values );
  $prog->set_uniform( $name, $opengl_array );

Set the value of a uniform.  This attempts to guess at the size/geometry of the uniform based
on the number or type of values given.

=cut

sub attr_by_name {
	my ($self, $name)= @_;
	$self->_attribute_cache->{$name} //= $self->_attr_by_name($name);
}

sub uniform_by_name {
	my ($self, $name)= @_;
	$self->_uniform_cache->{$name} //= $self->_uniform_by_name($name);
}

1;
