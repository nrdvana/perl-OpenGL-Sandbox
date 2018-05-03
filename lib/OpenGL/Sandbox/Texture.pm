package OpenGL::Sandbox::Texture;
use Moo;
use Carp;
use Try::Tiny;
use OpenGL ();
use OpenGL::Sandbox::MMap;

has tx_id     => ( is => 'lazy' );
has width     => ( is => 'rwp' );
has height    => ( is => 'rwp' );
has mipmaps   => ( is => 'rwp' );
has has_alpha => ( is => 'rwp' );

sub load {
	my ($self, $fname)= @_;
	my ($extension)= ($fname =~ /\.(\w+)$/)
		or croak "No file extension: \"$fname\"";
	my $loader= "load_$extension";
	$self->can($loader)
		or croak "Can't load file of type $extension";
	$self->$loader($fname);
	return $self;
}

sub load_rgb {
	my ($self, $fname)= @_;
	my $mmap= OpenGL::Sandbox::MMap->new($fname);
	$self->_load_rgb_square($mmap);
	return $self;
}
*load_rgba= *load_rgb;

# Pull in the C file and make sure it has all the C libs available
use Inline
	C => do { my $x= __FILE__; $x =~ s|\.pm|\.c|; Cwd::abs_path($x) },
	INC => '-I'.do{ my $x= __FILE__; $x =~ s|/[^/]+$|/|; Cwd::abs_path($x) }.' -I/usr/include/ffmpeg',
	LIBS => '-lGL -lswscale -X11',
	CCFLAGSEX => '-Wall -g3 -Os';

1;
