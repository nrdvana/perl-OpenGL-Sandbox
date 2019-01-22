package OpenGL::Sandbox::Shader;
use Moo;
use Carp;
use Try::Tiny;
use OpenGL::Sandbox::MMap;
our @ISA= 'OpenGL::Sandbox::Shader::Trampoline';

sub choose_implementation {
	my $jump_to_method= shift;
	@ISA= ();
	eval { extends 'OpenGL::Sandbox::Shader::V4'; 1; }
	or croak "Your OpenGL does not support version-4 shaders\n".$@;
	return shift->$jump_to_method(@_) if $jump_to_method;
	return 1;
}

sub OpenGL::Sandbox::Shader::Trampoline::_build_id { choose_implementation('_build_id', @_) }
sub OpenGL::Sandbox::Shader::Trampoline::_load     { choose_implementation('_load', @_) }

# ABSTRACT: Wrapper object for OpenGL shader
# VERSION

=head1 DESCRIPTION

OpenGL Shaders allow custom code to be loaded onto the graphics hardware and run in parallel
and asynchronous to the host application.

Each shader has an ID, and once compiled (or loaded as pre-compiled binaries) they can be
attached to Programs and used as a rendering pipeline.  This class wraps a single shader ID,
providing methods to conveniently load, compile, attach, detach, and destroy the associated
shader within OpenGL.

Note that this implementation currently requires at least OpenGL version (TODO), or it will throw
an exception as soon as you try to use the shaders.

=head1 ATTRIBUTES

=head2 filename

Path from which shader code will be loaded.  If not set, the shader will not load anything
automatically.

=head2 source

Optional - supply source code directly rather than loading from L</filename>.

=head2 type

Type of shader, i.e. C<GL_FRAGMENT_SHADER>, C<GL_VERTEX_SHADER>, ...

If you don't set this before lazy-building L</shader_id>, it will attempt to guess from the
C<filename>, and if it can't guess it will throw an exception.

=head2 loader

A method name or coderef of your choice for lazy-loading (and compiling) the code.
If not set, the loader is determined from the L</filename> and if that is not set, nothing
loaded on creation of the L<shader_id>.

Gets executed as C<< $shader->$loader($filename) >>.

=head2 loaded

Boolean; whether the shader is loaded and compiled, via this API.
(it won't know about changes you make via your own OpenGL calls)

=head2 id

The OpenGL integer "name" of this shader.  This is a lazy-built attribute, and will call
glCreateShader the first time you access it.  Use C<has_id> to find out whether this has
happened yet.

=over

=item has_id

True if the id attribute is defined.

=back

=cut

has filename   => ( is => 'rw' );
has source     => ( is => 'rw' );
has loader     => ( is => 'rw' );
has loaded     => ( is => 'rw' );
has type       => ( is => 'rw' );
has id         => ( is => 'lazy', predicate => 1 );

=head1 METHODS

=head2 load

  $shader->load;

Load shader source code from a file into OpenGL.  This does not happen when the
object is first constructed, in case the OpenGL context hasn't been initialized yet.
It automatically happens when you use a program pipeline that is attached to the shader.

Calls C<< $self->loader->($self, $self->filename) >>.  L</shader_id> will be a valid texture
id after this (assuming the loader doesn't die).  The default loader also compiles the shader,
and throws an exception if compilation fails.

Returns C<$self> for convenient chaining.

=cut

sub load {
	my ($self, $fname)= @_;
	$fname //= $self->filename;
	my $loader= $self->loader // '_load';
	$self->$loader($fname);
	$self;
}

1;
