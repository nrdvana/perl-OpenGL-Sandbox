package OpenGL::Sandbox::Texture;
use Moo;
use Carp;
use Try::Tiny;
use OpenGL ();
use OpenGL::Sandbox::MMap;

=head1 ATTRIBUTES

=head2 tx_id

Lazy-built OpenGL texture ID (integer)

=head2 width

Width of texture, in texels

=head2 height

Height of texture, in texels.  Currently will always equal width.

=head2 has_alpha

Boolean of whether the texture contains an alpha channel.

=head2 mipmap

Boolean, whether texture has (or should have) mipmaps generated for it.
When loading any "simple" image format, this setting controls whether
mipmaps will be automatically generated.

=cut

has tx_id      => ( is => 'lazy' );
has width      => ( is => 'rwp' );
has height     => ( is => 'rwp' );
has has_alpha  => ( is => 'rwp' );
has mipmap     => ( is => 'rwp' );
has min_filter => ( is => 'rwp' );
has mag_filter => ( is => 'rwp' );
has wrap_s     => ( is => 'rwp' );
has wrap_t     => ( is => 'rwp' );

=head1 METHODS

=head2 load

  $tex->load($fname);

Load image data from a file into OpenGL, and auto-detect the type based on file name.

Each file extension is handed off to a matching "load_${ext}" method. 

=cut

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

=head2 load_rgb

Load image data from a file which is nothing more than raw RGB or RGBA pixels
in a power-of-two dimension suitable for directly loading into OpenGL.  The
dimensions and presence of alpha channel are derived mathematically from the
file size.  The data is directly mmap'd so no copying is performed before
handing the pointer to OpenGL.

=head2 load_bgr

Same as rgb, except the source data has the red and blue bytes swapped.

=cut

sub load_rgb {
	my ($self, $fname)= @_;
	my $mmap= OpenGL::Sandbox::MMap->new($fname);
	$self->_load_rgb_square($mmap, 0);
	return $self;
}
sub load_bgr {
	my ($self, $fname)= @_;
	my $mmap= OpenGL::Sandbox::MMap->new($fname);
	$self->_load_rgb_square($mmap, 1);
	return $self;
}

=head2 load_png

Load image data from a PNG file.  The file is read and decoded, and if it is a
square power of two dimension, it is loaded directly.  If it is rectangular, it
gets stretched out to the next power of two square, using libswscale.

This library currently has no provision for the OpenGL "rectangular texture"
extension that allows for actual rectangular images and positive integer texture
coordinates.

=cut

sub load_png {
	my ($self, $fname)= @_;
	my $use_bgr= 1; # TODO: check OpenGL for optimal format
	$self->_load_rgb_square(_load_png_data_and_rescale($fname, $use_bgr), $use_bgr);
	return $self;
}

sub _load_png_data_and_rescale {
	my ($fname, $use_bgr)= @_;
	require Image::PNG::Libpng;
	
	# Load PNG format, or die
	open my $fh, '<:raw', $fname or croak "open($fname): $!";
	my $png= Image::PNG::Libpng::create_read_struct();
	$png->init_io($fh);
	$png->read_png(Image::PNG::Const::PNG_TRANSFORM_EXPAND());
	close $fh or croak "close($fname): $!";
	
	# Verify it's an encoding that we can use
	my $header= $png->get_IHDR;
	my ($width, $height, $color, $bit_depth)= @{$header}{'width','height','color_type','bit_depth'};
	my $has_alpha= $color eq Image::PNG::Const::PNG_COLOR_TYPE_RGB()? 0
		: $color eq Image::PNG::Const::PNG_COLOR_TYPE_RGB_ALPHA()? 1
		: croak "$fname must be encoded as RGB or RGBA";
	$bit_depth == 8
		or croak "$fname must be encoded with 8-bit color channels";
	
	# Get the row data and scale it to a square if needed
	my $dataref= \join('', @{ $png->get_rows });
	length($$dataref) == ($has_alpha? 4 : 3) * $width * $height
		or croak sprintf "$fname does not contain the expected number of data bytes (%d != %d * %d * %d)",
			length($$dataref), $has_alpha? 4:3, $width, $height;
	$dataref= _rescale_to_pow2_square($width, $height, $has_alpha, $use_bgr? 1 : 0, $dataref)
		unless $width == $height && $width == _round_up_pow2($width);
	return $dataref;
}

=head2 bind

  $tex->bind( $target=GL_TEXTURE_2D )

Make this image the current texture for OpenGL's C<$target>, with the default
of GL_TEXTURE_2D.

=cut

*bind= *_bind_tx; # in C, conflicts with sockets function, so have to rename from perl

=head1 CLASS FUNCTIONS

=head2 convert_png

  convert_png("foo.png", "foo.rgb");

Read a .png file and write an .rgb file.  The .png will be scaled to a square
power of 2 if it is not already.  The pixel format of the PNG must be RGB or RGBA.

=cut

sub convert_png {
	my ($src, $dst)= @_;
	my $use_bgr= $dst =~ /bgr$/? 1 : 0;
	my $dataref= _load_png_data_and_rescale($src, $use_bgr);
	open my $dst_fh, '>', $dst or croak "open($dst): $!";
	binmode $dst_fh;
	print $dst_fh $$dataref;
	close $dst_fh or croak "close($dst): $!";
}

# Pull in the C file and make sure it has all the C libs available
use Inline
	C => do { my $x= __FILE__; $x =~ s|\.pm|\.c|; Cwd::abs_path($x) },
	INC => '-I'.do{ my $x= __FILE__; $x =~ s|/[^/]+$|/|; Cwd::abs_path($x) }.' -I/usr/include/ffmpeg',
	LIBS => '-lGL -lswscale -X11',
	CCFLAGSEX => '-Wall -g3 -Os';

1;
