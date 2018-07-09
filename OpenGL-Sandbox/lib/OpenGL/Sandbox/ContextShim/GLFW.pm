package OpenGL::Sandbox::ContextShim::GLFW;

use strict;
use warnings;
use Carp;
use OpenGL::GLFW qw/ glfwInit glfwGetVersionString glfwTerminate NULL GLFW_TRUE GLFW_FALSE
	glfwGetPrimaryMonitor glfwCreateWindow glfwMakeContextCurrent glfwDestroyWindow
	glfwSwapInterval glfwSwapBuffers glfwPollEvents
	glfwWindowHint GLFW_VISIBLE GLFW_DECORATED GLFW_MAXIMIZED GLFW_DOUBLEBUFFER
	/;
use OpenGL::Sandbox qw/ glGetString GL_VERSION /;

# ABSTRACT: Context wrapper around OpenGL::GLFW API

# would use Moo, but I want to write my own constructor rather than store
# all these arguments as official attributes.
our $glfw_init;
sub new {
	my $class= shift;
	my %opts= ref $_[0] eq 'HASH'? %{$_[0]} : @_;
	($glfw_init //= glfwInit)
		or croak "GLFW Initialization Failed";
	my $self= bless {}, $class;
	
	glfwWindowHint(GLFW_VISIBLE, ($opts{visible} // 1)? GLFW_TRUE : GLFW_FALSE);
	glfwWindowHint(GLFW_DECORATED, $opts{noframe}? GLFW_FALSE : GLFW_TRUE);
	#glfwWindowHint(GLFW_MAXIMIZED, $opts{fullscreen}? GLFW_TRUE : GLFW_FALSE);
	
	my $w= glfwCreateWindow(
		$opts{width} // 640, # width
		$opts{height} // 480, # height
		$opts{title} // 'OpenGL', # title
		$opts{fullscreen}? glfwGetPrimaryMonitor() : NULL, # monitor
		NULL # share_window
	) or croak "glfwCreateWindow failed";
	$self->{window}= $w;
	
	glfwSetWindowPos($w, $opts{x}//0, $opts{y}//0)
		if $opts{x} || $opts{y};
	
	glfwMakeContextCurrent($w);
	glfwSwapInterval(1) if $opts{vsync} // 1;
	return $self;
}

sub DESTROY {
	my $self= shift;
	glfwDestroyWindow(delete $self->{window}) if defined $self->{window};
}

END { glfwTerminate if $glfw_init }

sub context_info {
	my $self= shift;
	sprintf("OpenGL::GLFW %s, glfw version %s, OpenGL version %s\n",
		OpenGL::GLFW->VERSION, glfwGetVersionString(), glGetString(GL_VERSION));
}

sub swap_buffers {
	my $self= shift;
	glfwSwapBuffers($self->{window});
	glfwPollEvents;
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

=cut
