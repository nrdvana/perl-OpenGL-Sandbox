package OpenGL::Sandbox::ContextShim::GLX;

use X11::GLX::DWIM;
use OpenGL::Sandbox 'glGetString', 'GL_VERSION';
use Scalar::Util 'weaken';

# ABSTRACT: Subclass of X11::GLX::DWIM to meet contract of OpenGL::Sandbox::make_context

our %instances;
sub new {
	my $class= shift;
	my %opts= ref $_[0] eq 'HASH'? %{$_[0]} : @_;
	my $visible= $opts{visible} // 1;
	my $glx= X11::GLX::DWIM->new();
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
	my $self= bless { glx => $glx }, $class;
	weaken($instances{$self}= $self);
	return $self;
}

END {
	delete $_->{glx} for values %instances;
}

sub glx { shift->{glx} }

sub context_info {
	my $self= shift;
	sprintf("X11::GLX::DWIM %s, target '%s', GLX Version %s, OpenGL version %s\n",
		$self->glx && $self->glx->VERSION, $self->glx && $self->glx->target,
		$self->glx && $self->glx->glx_version, glGetString(GL_VERSION));
}

sub swap_buffers {
	my $self= shift;
	$self->glx->swap_buffers if $self->glx;
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

=head1 ATTRIBUTES

=head2 glx

The L<X11::GLX::DWIM> object

=cut
