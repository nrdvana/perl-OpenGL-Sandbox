package OpenGL::Sandbox::ResMan;
use strict;
use warnings;
use Try::Tiny;
use Carp;
use OpenGL::Sandbox::MMap;

# ABSTRACT: Resource manager for OpenGL prototyping

=head1 SYNOPSIS

  use OpenGL::Sandbox '$res';
  my $img= $res->img('foo');
  my $tex= $img->texture;
  my $font= $res->font('default');

=head1 DESCRIPTION

This object holds references to each image and font that you load.
It is usually instantiated as a singleton from L</default_instance> or from
importing the C<$res> variable from L<OpenGL::Sandbox>.  It pulls resources
from a directory of your choice.  Where possible, files get memory-mapped
directly into the library that uses them, which should keep the overhead of
this library as low as possible.

=head1 ATTRIBUTES

=head2 resource_root_dir

The path where resources are located, adhering to the basic layout of:

  ./img/          # image files, i.e. PNG, GIF, BMP etc.
  ./tex/          # pre-processed textures in GL "mmap-compatible" format
  ./tex/default   # file or symlink for default texture.  Required.
  ./font/         # fonts compatible with libfreetype
  ./font/default  # file or symlink for default font.  Required.

files in the ./img directory can be loaded directly to textures, or you can
call L</make_tex> to pre-process it to the ./tex directory.

=head2 font_config

A hashref of font names which holds default constructor options.  By default,
fonts are loaded as texture-fonts, rendered at 24px.  For larger resolutions,
or to render the font in 3D or other modes, you can set options here so that
they get loaded on demand.

=head2 tex_config

A hashref of texture names which holds default texture constructor options.
By default, textures are loaded as a single square power-of-two (stretching
a rectangular image as needed) with no mip-mapping.  These options can specify
that mipmap levels should be generated, or enable non-power-of-two mode.

=cut

has resource_root_dir => ( is => 'ro', default => sub { '.' } );
has font_config       => ( is => 'rw', default => sub { +{} } );
has tex_config        => ( is => 'rw', default => sub { +{} } );

has _fontdata_cache   => ( is => 'ro', default => sub { {} } );
has _font_cache       => ( is => 'ro', default => sub { {} } );
has _tex_cache        => ( is => 'ro', default => sub { {} } );

=head1 METHODS

=head2 new

Standard Moo constructor.  Also validates the resource directory by loading
"font/default", which must exist (either a file or symlink)

=head2 default_instance

Return a default instance which uses the current directory as "resource_root_dir".

=cut

our $_default_instance;
sub default_instance {
	$_default_instance ||= __PACKAGE__->new(resource_root_dir => '.');
}

sub BUILD {
	my $self= shift;
	$self->load_fontdata('default');
	$self->load_texture('default');
	$log->debug("OpenGL::Sandbox::ResMan loaded");
}

=head2 release_gl

Free all OpenGL resources currently referenced by the texture and image cache.

=cut

sub release_gl {
	my $self= shift;
	$_->release_gl for values %{$self->_font_cache};
	%{$self->_tex_cache}= ();
}

=head2 font

  $font= $res->font( $name );

Retrieve a named font, loading it if needed.  See L</load_font>.

If the font cannot be loaded, this logs a warning and returns the 'default'
font rather than throwing an exception or returning undef.

=cut

sub font {
	my ($self, $name)= @_;
	$self->_font_cache->{$name}
		or try { $self->load_font($name, $resolution) }
		   catch { chomp(my $err= "Font '$name': $_"); $log->error($err); undef; }
		or $self->_font_cache->{default};
}

=head2 load_font

  $font= $res->load_font( $name, %config );

Load a font by name.  By default, a font file of the same name is loaded as a
TextureFont and rendered at 24px.  If multiple named fonts reference the same
file (including hardlink checks), it will only be mapped into memory once.

Any configuration options specified here are combined with any defaults
specified in L</font_config>.

If the font can't be loaded, this throws an exception.  If the named font has
already been loaded, this will return the existing font, even if the options
have changed.

=cut

sub load_font {
	my ($self, $name, %options)= @_;
	$self->_font_cache->{$name} ||= do {
		$log->debug("loading font $name");
		my $defaults= $self->font_config->{$name} || {};
		%options= ( file => $name, %$defaults, %options );
		my $font_data= $self->load_fontdata($options{file});
		OpenGL::Sandbox::TextureFont->new(data => $font_data, %options);
	};
}

=head2 load_fontdata

  $mmap= $res->load_fontdata( $name );

Memory-map the given font file.  Dies if the font doesn't exist.
A memory-mapped font file can be shared between all the renderings
at different resolutions.

=cut

sub load_fontdata {
	my ($self, $name)= @_;
	my $mmap;
	return $mmap if $mmap= $self->_fontdata_cache->{$name};
	
	$log->debug("loading fontdata $name");
	my $fname= File::Spec->rel2abs( $name, $self->resource_root_dir.'/font' );
	# resolve filename to device and inode ID, which might already be mapped
	my ($dev, $ino)= stat $fname
		or croak "No such font file '$name'";
	unless ($mmap= $self->_fontdata_cache->{"~$dev,$ino"}) {
		# If it wasn't, map it and also weaken the reference
		$mmap= OpenGL::Sandbox::MMap->new($fname);
		weaken( $self->_fontdata_cache->{"~$dev,$ino"}= $mmap );
	}
	# Then cache that reference for this name, but also a weak reference
	weaken( $self->_fontdata_cache->{$name}= $mmap );
	return $mmap;
}

=head2 tex

  my $tex= $res->tex( $name );

Load a texture by name, or return the 'default' texture if it doesn't exist.

=cut

sub tex {
	my ($self, $name)= @_;
	$self->_texture_cache->{$name}
		or try { $self->load_texture($name) }
		   catch { chomp(my $err= "Image '$name': $_"); $log->error($err); undef; }
		or $self->_texture_cache->{default};
}

=head2 load_texture

  my $tex= $res->load_texture( $name, %options )

Load a texture by name.  It searches for known file extensions in the C<$resource_dir/tex/>
directory and can resolve symlinks so it only loads a texture once even if it
has multiple names.

If a new texture object is created, it is initialized with C<%options>.

Dies if no matching file can be found, or if it wasn't able to process it.

=cut

sub load_texture {
	my ($self, $name, %options)= @_;
	my $tex;
	return $tex if $tex= $self->_texture_cache->{$name};
	
	$log->debug("loading texture $name");
	my ($fname)= grep { -e $_ } map {
			File::Spec->rel2abs( $name.$_, $self->resource_root_dir.'/tex' )
		} qw( .rgb .rgba .png ), '';
	$fname or croak "No such texture '$name'";
	my ($dev, $ino)= stat $fname
		or croak "stat($fname): $!";
	return $tex if $tex= $self->_texture_cache->{"~$dev,$ino"};
	
	$tex= OpenGL::Sandbox::Texture->new(\%options)->load($fname);
	$self->_texture_cache->{"~$dev,$ino"}= $tex;
	$self->_texture_cache->{$name}= $tex;
	return $tex;
}

1;
