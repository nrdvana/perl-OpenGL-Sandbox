package OpenGL::Sandbox::ContextShim::SDL;

use parent 'SDLx::App';
use OpenGL::Sandbox 'glGetString', 'GL_VERSION';

# ABSTRACT: Subclass of SDLx::App to meet contract of OpenGL::Sandbox::make_context

sub new {
	my $class= shift;
	my %opts= ref $_[0] eq 'HASH'? %{$_[0]} : @_;
	# TODO: Figure out best way to create invisible SDL window
	if (defined $opts{visible} && !$opts{visible}) {
		$opts{x}= -100;
		$opts{width}= $opts{height}= 1;
	}
	# This is the only option I know of for SDL to set initial window placement
	local $ENV{SDL_VIDEO_WINDOW_POS}= ($opts{x}//0).','.($opts{y}//0)
		if defined $opts{x} || defined $opts{y};
	my $flags= 0;
	$flags |= SDL::SDL_NOFRAME() if $opts{noframe};
	$flags |= SDL::SDL_FULLSCREEN() if $opts{fullscreen};
	$class->SUPER::new(
		title  => $opts{title} // 'OpenGL',
		(defined $opts{width}?  ( width  => $opts{width} ) : ()),
		(defined $opts{height}? ( height => $opts{height} ) : ()),
		($flags?                ( flags => (SDL::SDL_ANYFORMAT() | $flags) ) : ()),
		opengl => 1,
		exit_on_quit => 1,
	);
}

sub context_info {
	my $self= shift;
	sprintf("SDLx::App %s, OpenGL version %s\n", $self->SUPER::VERSION, glGetString(GL_VERSION));
}

sub swap_buffers {
	shift->sync;
}

1;

=head1 DESCRIPTION

This class is loaded automatically if needed by L<OpenGL::Sandbox/make_context>.

It provides

=over 14

=item new

Accepting all the options of make_context

=item context_info

=item swap_buffers

=back

It also a subclass of SDLx::App so you can call those methods on it too.

=cut
