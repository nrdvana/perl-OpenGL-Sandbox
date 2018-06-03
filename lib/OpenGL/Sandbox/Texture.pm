package OpenGL::Sandbox::Texture;
use Moo;
use Carp;
use Try::Tiny;
use OpenGL ();
use OpenGL::Sandbox::MMap;

=head1 ATTRIBUTES

=head2 filename

Path from which image data will be loaded.  If not set, the texture will not have any default
image data loaded.

=head2 loader

A method name or coderef of your choice for lazy-loading the image data.  If not set, the
loader is determined from the L</filename> and if that is not set, nothing gets loaded on
creation of the texture id L<tx_id>.

Gets executed as C<< $tex->$loader($filename) >>.

=head2 loaded

Boolean; whether any image data has been loaded yet.  This is not automatically aware of data
you load yourself via calls to glTexImage or glTexSubImage.

=head2 src_width

Original width of the texture before it might have been rescaled to a square power of two.

=head2 src_height

Original height of the texture before it might have been rescaled to a square power of two.

=head2 tx_id

Lazy-built OpenGL texture ID (integer).  Triggers L</load> if image is not yet loaded.

=head2 width

Width of texture, in texels.

=head2 height

Height of texture, in texels.  Currently will always equal width.

=head2 pow2_size

If texture is loaded as a square power-of-two (currently all are) then this returns the
dimension of the texture.  This can differ from width/height in the event that you configured
those with the logical dimensions of the image.  If texture was loaded as a rectangular texture,
this is undef.

=head2 has_alpha

Boolean of whether the texture contains an alpha channel.

=head2 mipmap

Boolean, whether texture has (or should have) mipmaps generated for it.
When loading any "simple" image format, this setting controls whether
mipmaps will be automatically generated.

=cut

has filename   => ( is => 'rw' );
has loader     => ( is => 'rw' );
has loaded     => ( is => 'rw' );
has src_width  => ( is => 'rw' );
has src_height => ( is => 'rw' );
has tx_id      => ( is => 'rw', lazy => 1, builder => 1 );
has width      => ( is => 'rwp' );
has height     => ( is => 'rwp' );
has pow2_size  => ( is => 'rw' );
has has_alpha  => ( is => 'rwp' );
has mipmap     => ( is => 'rwp' );
has min_filter => ( is => 'rwp' );
has mag_filter => ( is => 'rwp' );
has wrap_s     => ( is => 'rwp' );
has wrap_t     => ( is => 'rwp' );

=head1 METHODS

=head2 bind

  $tex->bind( $target=GL_TEXTURE_2D )

Make this image the current texture for OpenGL's C<$target>, with the default of
C<GL_TEXTURE_2D>.  If L</tx_id> does not exist yet, it gets created.  If this texture has
a L</loader> or L</filename> defined and has not yet been L</loaded>, this automatically
calls L</load>.

Returns C<$self> for convenient chaining.

=cut

sub bind {
	my ($self, $target)= @_;
	OpenGL::glBindTexture($self->tx_id, $target // OpenGL::GL_TEXTURE_2D);
	if (!$self->loaded && (defined $self->loader || defined $self->filename)) {
		$self->load;
	}
	$self;
}

=head2 load

  $tex->load;

Load image data from a file into OpenGL.  This does not happen when the object is first
constructed, in case the OpenGL context hasn't been initialized yet.  It automatically happens
when L</bind> is called for the first time.

Calls C<< $self->loader->($self, $self->filename) >>.  L</tx_id> will be a valid texture id
after this (assuming the loader doesn't die).

Returns C<$self> for convenient chaining.

=cut

sub load {
	my ($self, $fname)= @_;
	$fname //= $self->filename;
	my $loader= $self->loader // do {
		my ($extension)= ($fname =~ /\.(\w+)$/)
			or croak "No file extension: \"$fname\"";
		my $method= "load_$extension";
		$self->can($method)
			or croak "Can't load file of type $extension";
	};
	$self->$loader($fname);
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
	$self->loaded(1);
	return $self;
}
sub load_bgr {
	my ($self, $fname)= @_;
	my $mmap= OpenGL::Sandbox::MMap->new($fname);
	$self->_load_rgb_square($mmap, 1);
	$self->loaded(1);
	return $self;
}

=head2 load_png

Load image data from a PNG file.  The file is read and decoded, and if it is a
square power of two dimension, it is loaded directly.  If it is rectangular, it
gets stretched out to the next power of two square, using libswscale.

This library currently has no provision for the OpenGL "rectangular texture"
extension that allows for actual rectangular images and positive integer texture
coordinates.  That could be a useful addition.

=cut

sub load_png {
	my ($self, $fname)= @_;
	my $use_bgr= 1; # TODO: check OpenGL for optimal format
	my ($imgref, $w, $h)= _load_png_data_and_rescale($fname, $use_bgr);
	$self->_load_rgb_square($imgref, $use_bgr);
	$self->src_width($w);
	$self->src_height($h);
	$self->loaded(1);
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
	return $dataref, $width, $height;
}

=head2 TODO: load_ktx

OpenGL has its own image file format designed to directly handle all the various things you
might want to load into a texture.  Integrating libktx is on my list.

=head2 render

  $tex->render( %args );
  # keys %args= x, y, w, h, scale, center

Render the texture as a plain rectangle with optional coordinate/size modifications.
Implies a call to C</bind> which might also trigger L</load>.

=over

=item x, y

Use specified origin point. Defaults to (0,0) otherwise.

=item w, h

Use specified with and/or height.  Defaults to pixel dimensions of the source image, unless
only one is specified then it calculates the other using the aspect ratio.  If source
dimensions are not set, it uses the actual texture dimensions.

=item scale

Multiply coordinates by this number.

=item center

Center the image on the origin, instead of using it as the corner

=back

=cut

sub render {
	my $self= shift;
	my %args= @_ == 1? @{ $_[0] } : @_;
	$self->_render(@args{qw/ x y w h scale center /});
}

=head2 render_xywh

  $tex->render_xywh( $x, $y, $w, $h );

Slightly more efficient way to call C<< $tex->render( x => $x, y => $y, w => $w, h => $h ); >>.
Any argument may be undefined to use the defaults.

=cut

sub render_xywh {
	my ($self, $x, $y, $w, $h)= @_;
	$self->_render($x, $y, $w, $h, undef, undef);
}

=head1 CLASS FUNCTIONS

=head2 convert_png

  convert_png("foo.png", "foo.rgb");

Read a C<.png> file and write an C<.rgb> (or C<.bgr>) file.  The C<.png> will be scaled to a
square power of 2 if it is not already.  The pixel format of the PNG must be C<RGB> or C<RGBA>.
This does not require an OpenGL context.

=cut

sub convert_png {
	my ($src, $dst)= @_;
	my $use_bgr= $dst =~ /\.bgr$/? 1 : 0;
	my ($dataref)= _load_png_data_and_rescale($src, $use_bgr);
	open my $dst_fh, '>', $dst or croak "open($dst): $!";
	binmode $dst_fh;
	print $dst_fh $$dataref;
	close $dst_fh or croak "close($dst): $!";
}

# Pull in the C file and make sure it has all the C libs available
use Inline
	C => do { my $x= __FILE__; $x =~ s|\.pm|\.c|; Cwd::abs_path($x) },
	INC => '-I'.do{ my $x= __FILE__; $x =~ s|/[^/]+$|/|; Cwd::abs_path($x) }.' -I/usr/include/ffmpeg',
	LIBS => '-lGL -lswscale',
	CCFLAGSEX => '-Wall -g3 -Os';

1;
