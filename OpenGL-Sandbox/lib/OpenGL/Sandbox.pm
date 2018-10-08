package OpenGL::Sandbox;

use v5.14; # I can aim for older upon request.  Not expecting any requests though.
use strict;
use warnings;
use Try::Tiny;
use Exporter;
use Carp;
use Log::Any '$log';
use Module::Runtime 'require_module';
use Scalar::Util 'weaken';
# Choose OpenGL::Modern if available, else fall back to OpenGL.
# But use the one configured in the environment.  But yet don't blindly
# load modules from environment either.
our $OpenGLModule;
BEGIN {
	$OpenGLModule //= do {
		my $fromenv= $ENV{OPENGL_SANDBOX_OPENGLMODULE} // '';
		# Don't blindly require module from environment...
		# Any other value, and the user must require it themself (such as perl -M)
		eval "require $fromenv" if $fromenv eq 'OpenGL' || $fromenv eq 'OpenGL::Modern';
		$fromenv? $fromenv
		: eval 'require OpenGL::Modern; 1'? 'OpenGL::Modern'
		: eval 'require OpenGL; 1'? 'OpenGL'
		: croak "Can't load either OpenGL::Modern or OpenGL.  Please install one.";
	};
	
	# If this succeeds, assume it is safe to eval this package name later
	$OpenGLModule->import(qw/
		glGetString glGetError
		GL_VERSION
	/);
}
require constant;
require OpenGL::Sandbox::ResMan;

# ABSTRACT: Rapid-prototyping utilities for OpenGL

=head1 EXPORTS

=head2 GL_$CONSTANT, gl$Function

This module can export OpenGL constants and functions, selecting them out of either L<OpenGL> or
L<OpenGL::Modern>.   When exported by name, constants will be exported as true perl constants.
However, the full selection of GL constants and functions is *not* available directly from this
module's namespace.  i.e. C<< OpenGL::Sandbox::GL_TRUE() >> does not work.

=head2 $res

Returns a default global instance of the L<resource manager|OpenGL::Sandbox::ResMan>
with C<resource_root_dir> pointing to the current directory.

=head2 tex

Shortcut for C<< OpenGL::Sandbox::ResMan->default_instance->tex >>

=head2 font

Shortcut for C<< OpenGL::Sandbox::ResMan->default_instance->font >>

Note that you need to install L<OpenGL::Sandbox::V1::FTGLFont> in order to get font support,
currently.  Other font providers might be added later.

=cut

sub tex  { OpenGL::Sandbox::ResMan->default_instance->tex(@_) }
sub font { OpenGL::Sandbox::ResMan->default_instance->font(@_) }

=head2 :V1:all

Exports ':all' from L<OpenGL::Sandbox::V1> (which must be installed separately).
This module contains many "sugar" functions to make the GL 1.x API more friendly.

C<:V2:all>, C<:V3:all>, etc will likewise import everything from packages named
C<OpenGL::SandBox::V$_> which do not currently exist, but could be authored
in the future.

=cut

our @EXPORT_OK= qw( font tex make_context current_context
	get_gl_errors log_gl_errors warn_gl_errors
	glGetString glGetError GL_VERSION );
our %EXPORT_TAGS= ( all => \@EXPORT_OK );

sub import {
	my $caller= caller;
	my $class= $_[0];
	my @gl_const;
	my @gl_fn;
	for (reverse 1..$#_) {
		my $arg= $_[$_];
		if ($arg eq '$res') {
			my $res= OpenGL::Sandbox::ResMan->default_instance;
			no strict 'refs';
			*{$caller.'::res'}= \$res;
			splice(@_, $_, 1);
		}
		elsif ($arg =~ /^:V(\d)(:.*)?$/) {
			my $mod= "OpenGL::Sandbox::V$1";
			my $imports= $2;
			$imports =~ s/:/ :/g;
			eval "package $caller; use $mod qw/ $imports /; 1"
				or croak "Can't load $mod (note that this must be installed separately)\n  $@";
			splice(@_, $_, 1);
		}
		elsif ($arg =~ /^GL_/) {
			push @gl_const, $arg;
			splice(@_, $_, 1);
		}
		elsif ($arg =~ /^gl[a-zA-Z]/) {
			# Let local methods in this package override external ones
			unless ($class->can($arg)) {
				push @gl_fn, $arg;
				splice(@_, $_, 1);
			}
		}
	}
	$class->_import_gl_constants_into($caller, @gl_const) if @gl_const;
	$class->_import_gl_functions_into($caller, @gl_fn) if @gl_fn;
	# Let the real Exporter module handle anything remaining in @_
	goto \&Exporter::import;
}

sub _import_gl_constants_into {
	my ($class, $into, @names)= @_;
	# First, import into this module, then import into caller.  This resolves an
	# inefficiency in traditional OpenGL module where it optimizes imports for
	# import speed rather than runtime speed.  We want constants to actually be
	# perl constants.
	my @need_import_const= grep !$class->can($_), @names;
	$OpenGLModule->import(@need_import_const);
	# Now for each constant we imported, undefine it then pass it to the constant module
	no strict 'refs';
	for (@need_import_const) {
		my $val= $class->can($_)->();
		undef *$_;
		constant->import($_ => $val);
	}
	# Now import them all into caller
	*{ $into . '::' . $_ }= $class->can($_) for @names;
}

sub _import_gl_functions_into {
	my ($class, $into, @names)= @_;
	eval "package $into; $OpenGLModule->import(\@names); 1" or die $@;
}

=head2 make_context

  my $context= make_context( %opts );

Pick the lightest smallest module that can get a window set up for rendering.
This tries: L<X11::GLX>, and L<SDLx::App> in that order.  You can override the detection
with environment variable C<OPENGL_SANDBOX_CONTEXT_PROVIDER>.
It assumes you don't have any desire to receive user input and just want to render some stuff.
If you do actually have a preference, you should just invoke that package yourself.

Always returns an object whose scope controls the lifecycle of the window, and that object
always has a C<swap_buffers> method.

This attempts to automatically pick up the window geometry, either from a "--geometry=" option
or from the environment variable C<OPENGL_SANDBOX_GEOMETRY>.  The Geometry value is in X11
notation of C<"${WIDTH}x${HEIGHT}+$X+$Y"> except that negative C<X>,C<Y> (from right edge) are
not supported.

Not all options have been implemented for each source, but the list of possibilities is:

=over

=item x, y, width, height

Set the placement and dimensions of the created window.

=item visible

Defaults to true, but if false, attempts to create an off-screen GL context.

=item fullscreen

Attempts to create a full-screen context.

=item noframe

Attempts to create a window without window border decorations.

=item title

Window title

=back

Note that if you're using Classic OpenGL (V1) you also need to set up the projection matrix
to something more useful than the defaults before rendering anything.
See L<OpenGL::Sandbox::V1/setup_projection>.

=cut

our %provider_aliases;
BEGIN {
	%provider_aliases= (
		'GLX'            => 'OpenGL::Sandbox::ContextShim::GLX',
		'X11::GLX'       => 'OpenGL::Sandbox::ContextShim::GLX',
		'X11::GLX::DWIM' => 'OpenGL::Sandbox::ContextShim::GLX',
		'GLFW'           => 'OpenGL::Sandbox::ContextShim::GLFW',
		'OpenGL::GLFW'   => 'OpenGL::Sandbox::ContextShim::GLFW',
		'SDL'            => 'OpenGL::Sandbox::ContextShim::SDL',
		'SDLx::App'      => 'OpenGL::Sandbox::ContextShim::SDL',
	);
}

our $current_context;
sub make_context {
	my (%opts)= @_;
	# Check for geometry specification on command line
	my ($geom_spec, $w,$h,$l,$t);
	for (0..$#ARGV) {
		if ($ARGV[$_] =~ /^--?geometry(?:=(.*))?/) {
			$geom_spec= $1 // $ARGV[$_+1];
			last;
		}
	}
	# Also check environment variable
	$geom_spec //= $ENV{OPENGL_SANDBOX_GEOMETRY};
	if (defined $geom_spec
		&& (($w, $h, $l, $t)= ($geom_spec =~ /^(\d+)x(\d+)([-+]\d+)?([-+]\d+)?/))
	) {
		$opts{width} //= $w;
		$opts{height} //= $h;
		$opts{x} //= $l if defined $l;
		$opts{y} //= $t if defined $t;
	}
	
	# Load user's requested provider, or auto-detect first available
	my $provider= $ENV{OPENGL_SANDBOX_CONTEXT_PROVIDER};
	$provider //=
		# Try X11 first, because lightest weight
		eval('require X11::GLX::DWIM; 1;') ? 'GLX'
		: eval('require OpenGL::GLFW; 1;') ? 'GLFW'
		: eval('require SDLx::App; 1;') ? 'SDL'
		: croak "make_context needs one of X11::GLX, OpenGL::GLFW, or SDLx::App to be installed";
	
	my $class= $provider_aliases{$provider}
		or croak "Unhandled context provider $provider";
	require_module($class);
	
	my $cx= $class->new(%opts);
	$log->infof("Loaded %s", $cx->context_info);
	weaken($current_context= $cx); 
	return $cx;
}

=head2 current_context

Returns the most recently created result of L</make_context>, assuming it hasn't been
garbage-collected.  In other words, there is a global weak-ref to the result of make_context.
If you have a simple program with only one context, this global simplifies life for you.

=cut

sub current_context { $current_context }

=head2 get_gl_errors

Returns the symbolic names of any pending OpenGL errors, as a list.

=cut

our %_gl_err_msg;
BEGIN {
	%_gl_err_msg= map { my $v= eval "$OpenGLModule->import('$_'); $_()"; defined $v? ($v => $_) : () } qw(
		GL_INVALID_ENUM
		GL_INVALID_VALUE
		GL_INVALID_OPERATION
		GL_INVALID_FRAMEBUFFER_OPERATION
		GL_OUT_OF_MEMORY
		GL_STACK_OVERFLOW
		GL_STACK_UNDERFLOW
		GL_TABLE_TOO_LARGE
	);
}

sub get_gl_errors {
	my $self= shift;
	my (@names, $e);
	push @names, $_gl_err_msg{$e} || "(unrecognized) ".$e
		while (($e= glGetError()));
	return @names;
}

sub log_gl_errors {
	my @errors= get_gl_errors;
	$log->error("GL Error Bits: ".join(', ', @errors)) if @errors;
}

sub warn_gl_errors {
	my @errors= get_gl_errors;
	warn("GL Error Bits: ".join(', ', @errors)."\n") if @errors;
}

1;

__END__

=head1 INSTALLING

Getting this module collection installed is abnormally difficult.  This is a "selfish module"
that I wrote primarily for me, but published in case it might be useful to someone else. My
other more altruistic modules aim for high compatibility, but this one just unapologetically
depends on lots of specific things.

For the core module, you need:

=over

=item *

Perl 5.14 or higher

=item *

libGL, and headers

=item *

LibAV libraries libswscale, libavutil, and headers, for the feature that automatically rescales textures

=item *

L<Image::PNG::Libpng>, for the feature that automatically loads PNG.

=item *

L<File::Map>, for efficiently memory-mapping resource files

=item *

L<Inline::C>, including a local C compiler

=back

For the "V1" module (L<OpenGL::Sandbox::V1>) you will additionally need

=over

=item *

libGLU and headers

=item *

Inline::CPP, including a local C++ compiler

=back

For the "FTGLFont" module (L<OpenGL::Sandbox::V1::FTGLFont>) you will additionally need

=over

=item *

libftgl, and libfreetype2, and headers

=back

You probably also want a module to open a GL context to see things in.  This module is aware
of L<X11::GLX> and L<SDL>, but you can use anything you like since the GL context
is global.
