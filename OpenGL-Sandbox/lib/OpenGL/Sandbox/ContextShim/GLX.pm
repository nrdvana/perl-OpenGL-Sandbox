package OpenGL::Sandbox::ContextShim::GLX;

use parent 'X11::GLX::DWIM';
use OpenGL::Sandbox 'glGetString', 'GL_VERSION';

# ABSTRACT: Subclass of X11::GLX::DWIM to meet contract of OpenGL::Sandbox::make_context

sub new {
	my $class= shift;
	my %opts= ref $_[0] eq 'HASH'? %{$_[0]} : @_;
	my $visible= $opts{visible} // 1;
	my $glx= $class->SUPER::new();
	# Target is lazy.  Make sure GL context fully initialized before return.
	if ($visible) {
		$glx->target({ window => {
			x => $opts{x} // 0,
			y => $opts{y} // 0,
			width => $opts{width} // 400,
			height => $opts{height} // 400
		}});
	} else {
		$glx->target({ pixmap => {
			width => $opts{width} // 256,
			height => $opts{height} // 256
		}});
	}
	return $glx;
}

sub context_info {
	my $self= shift;
	sprintf("X11::GLX::DWIM %s, target '%s', GLX Version %s, OpenGL version %s\n",
		$self->SUPER::VERSION, $self->target, $self->glx_version, glGetString(GL_VERSION));
}

1;

=head1 DESCRIPTION

This class is loaded automatically if needed by L<OpenGL::Sandbox/make_context>.

It provides

=over 14

=item new

Accepting all the options of make_context

=item context_info

=back

It also a subclass of X11::GLX::DWIM so you can call those methods on it too.

=cut