package OpenGL::Sandbox;

use v5.14; # I can aim for older upon request.  Not expecting any requests though.
use strict;
use warnings;
use Try::Tiny;
use Exporter;
use Carp;
use Log::Any '$log';
# Choose OpenGL::Modern if available, else fall back to OpenGL.
our $OpenGLModule;
BEGIN {
	$OpenGLModule= eval 'require OpenGL::Modern; 1'? 'OpenGL::Modern'
		: eval 'require OpenGL; 1'? 'OpenGL'
		: croak "Can't load either OpenGL::Modern or OpenGL.  Please install one.";
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

This module can export OpenGL constants and functions, selecting them out of either OpenGL or
OpenGL::Modern.   When exported by name, constants will be exported as true perl constants.
However, the full selection of GL constants and functions is *not* available directly from this
module's namespace.  i.e. OpenGL::Sandbox::GL_TRUE() does not work.

=head2 $res

Returns a default global instance of the L<resource manager|OpenGL::Sandbox::ResMan>
with C<resource_root_dir> pointing to the current directory.

=head2 tex

Shortcut for C<< OpenGL::Sandbox::ResMan->default_instance->tex >>

=head2 font

Shortcut for C<< OpenGL::Sandbox::ResMan->default_instance->font >>

Note that you need to install L<OpenGL::Sandbox::V1::FTGLFont> in order to get font support,
currently.  Other font providers might be added later.

=head2 :1.x

Exports everything from L<OpenGL::Sandbox::V1> (which must be installed separately).
This module contains many "sugar" functions to make the GL 1.x API more friendly.

C<:2.x>, C<:3.x>, etc will likewise import everything from packages named
C<OpenGL::SandBox::$_> (which do not currently exist, but could be authored
in the future)

=head2 make_context

Pick the lightest smallest module that can get a window set up for rendering.
This tries: L<X11::GLX>, L<OpenGL::GLFW>, and L<SDLx::App> in that order.
It assumes you don't have any desire to receive user input and just want to render some stuff.
If you do actually have a preference, you should just invoke that package yourself.

Always returns an object whose scope controls the lifecycle of the window, and that object
always has a C<swap_buffers> method.

=head2 get_gl_errors

Returns the symbolic names of any pending OpenGL errors, as a list.

=cut

our @EXPORT_OK= qw( font tex make_context get_gl_errors );
our %EXPORT_TAGS= ( all => \@EXPORT_OK );

sub import {
	my $caller= caller;
	my @normal;
	for (reverse 1..$#_) {
		my $arg= $_[$_];
		if ($arg eq '$res') {
			my $res= OpenGL::Sandbox::ResMan->default_instance;
			no strict 'refs';
			*{$caller.'::res'}= \$res;
			splice(@_, $_, 1);
		}
		elsif ($arg =~ /^:(\d).x$/) {
			my $mod= "OpenGL::Sandbox::V$1";
			eval "package $caller; use $mod ':all'; 1"
				or croak "Can't load $mod (note that this must be installed separately)\n  $@";
			splice(@_, $_, 1);
		}
		elsif ($arg =~ /^GL_/) {
			my $const= __PACKAGE__->can($arg) // do {
				my $value= $OpenGLModule->$arg;
				constant->import($arg => $value);
				__PACKAGE__->can($arg);
			};
			no strict 'refs';
			*{ $caller . '::' . $arg }= $const;
			splice(@_, $_, 1);
		}
		elsif ($arg =~ /^gl[a-zA-Z]/) {
			no strict 'refs';
			*{ $caller . '::' . $arg }= $OpenGLModule->can($arg) // die "No $arg in $OpenGLModule";
			splice(@_, $_, 1);
		}
	}
	goto \&Exporter::import;
}

sub tex  { OpenGL::Sandbox::ResMan->default_instance->tex(@_) }
sub font { OpenGL::Sandbox::ResMan->default_instance->font(@_) }

sub make_context {
	my (%opts)= @_;
	# Try X11 first, because lightest weight
	if (eval 'require X11::GLX::DWIM; 1') {
		my $glx= X11::GLX::DWIM->new();
		my $visible= $opts{visible} // 1;
		if ($visible) {
			$glx->target({ window => { width => $opts{width} // 400, height => $opts{height} // 400 }});
		} else {
			$glx->target({ pixmap => { width => $opts{width} // 256, height => $opts{height} // 256 }});
		}
		$log->infof("Loaded X11::GLX::DWIM %s, target '%s', GLX Version %s, OpenGL version %s\n",
			$glx->VERSION, $visible? 'window':'pixmap', $glx->glx_version, glGetString(GL_VERSION));
		return $glx;
	}
	# TODO: Else try GLFW
	# Else try SDL
	elsif (eval 'require SDLx::App; 1') {
		my $sdl= SDLx::App->new(
			title  => $opts{title} // 'OpenGL',
			width  => $opts{width} // 400,
			height => $opts{height} // 400,
			depth  => 32,
			opengl => 1,
		);
		$log->infof("Loaded SDLx::App %s, OpenGL version %s\n", $sdl->VERSION, glGetString(GL_VERSION));
		return $sdl;
	}
	else {
		die "Tests require one of X11::GLX or SDL to be installed.";
	}
}

our %_gl_err_msg;
BEGIN {
	%_gl_err_msg= map { eval { $OpenGLModule->can($_)->() => $_ } } qw(
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

1;
