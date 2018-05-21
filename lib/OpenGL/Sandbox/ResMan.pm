package OpenGL::Sandbox::ResMan;

use Moo;
use Try::Tiny;
use Carp;
use File::Spec::Functions qw/ catdir rel2abs file_name_is_absolute canonpath /;
use Log::Any '$log';
use OpenGL::Sandbox::MMap;
use OpenGL::Sandbox::Font;
use OpenGL::Sandbox::Texture;
use JSON::MaybeXS ();
use File::Find ();
use Scalar::Util ();

# ABSTRACT: Resource manager for OpenGL prototyping

=head1 SYNOPSIS

  my $r= OpenGL::Sandbox::ResMan->default_instance;
  my $tex= $r->tex('foo');
  my $font= $r->font('default');

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

  ./tex/          # textures
  ./tex/default   # file or symlink for default texture.  Required.
  ./font/         # fonts compatible with libfreetype
  ./font/default  # file or symlink for default font.  Required.

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

has resource_root_dir => ( is => 'rw', default => sub { '.' } );
has font_config       => ( is => 'rw', default => sub { +{} } );
has tex_config        => ( is => 'rw', default => sub { +{} } );
has tex_fmt_priority  => ( is => 'rw', lazy => 1, builder => 1 );
has tex_default_fmt   => ( is => 'rw', lazy => 1, builder => 1 );

sub _build_tex_fmt_priority {
	my $self= shift;
	# TODO: consult OpenGL to find out which format is preferred.
	return { bgr => 1, rgb => 2, png => 50 };
}

sub _build_tex_default_fmt {
	my $self= shift;
	my $pri= $self->tex_fmt_priority;
	# Select the lowest value from the keys of the format priority map
	my $first;
	for (keys %{$self->tex_fmt_priority}) {
		$first= $_ if !defined $first || $pri->{$first} > $pri->{$_};
	}
	return $first // 'bgr';
}

has _fontdata_cache    => ( is => 'ro', default => sub { +{} } );
has _font_cache        => ( is => 'ro', default => sub { +{} } );
has _font_dir_cache    => ( is => 'lazy' );
has _texture_cache     => ( is => 'ro', default => sub { +{} } );
has _texture_dir_cache => ( is => 'lazy' );

sub _build__texture_dir_cache {
	$_[0]->_cache_directory(catdir($_[0]->resource_root_dir, 'tex'), $_[0]->tex_fmt_priority)
}
sub _build__font_dir_cache {
	$_[0]->_cache_directory(catdir($_[0]->resource_root_dir, 'font'));
}

sub clear_cache {
	my $self= shift;
	$self->_clear_texture_cache;
	$self->_clear_texture_dir_cache;
	$self->_clear_font_cache;
	$self->_clear_fontdata_cache;
	$self->_clear_font_dir_cache;
}

=head1 METHODS

=head2 new

Standard Moo constructor.  Also validates the resource directory by loading
"font/default", which must exist (either a file or symlink)

=head2 default_instance

Return a default instance which uses the current directory as "resource_root_dir".

=cut

our $_default_instance;
sub default_instance {
	$_default_instance ||= __PACKAGE__->new();
}

sub BUILD {
	my $self= shift;
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
	$self->_font_cache->{$name} ||=
		( try { $self->load_font($name) }
		  catch { chomp(my $err= "Font '$name': $_"); $log->error($err); undef; }
		)
		|| $self->_font_cache->{default}
		|| $self->load_font('default');
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
		my $fname= delete $options{file};
		my $font_data= $self->load_fontdata($fname);
		OpenGL::Sandbox::Font->new(data => $font_data, %options);
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
	my $info= $self->_font_dir_cache->{$name}
		or croak "No such font file '$name'";
	# $info is pair if [$inode_key, $real_path].  Check if inode is already mapped.
	unless ($mmap= $self->_fontdata_cache->{$info->[0]}) {
		# If it wasn't, map it and also weaken the reference
		$mmap= OpenGL::Sandbox::MMap->new($info->[1]);
		Scalar::Util::weaken( $self->_fontdata_cache->{$info->[0]}= $mmap );
	}
	# Then cache that reference for this name, but also a weak reference.
	# (the font objects will hold strong references to the data)
	Scalar::Util::weaken( $self->_fontdata_cache->{$name}= $mmap );
	return $mmap;
}

=head2 tex

  my $tex= $res->tex( $name );

Load a texture by name, or return the 'default' texture if it doesn't exist.

=cut

sub tex {
	my ($self, $name)= @_;
	$self->_texture_cache->{$name} ||=
		( try { $self->load_texture($name) }
		  catch { chomp(my $err= "Image '$name': $_"); $log->error($err); undef; }
		)
		|| $self->_texture_cache->{default}
		|| $self->load_texture('default');
}

=head2 load_texture

  my $tex= $res->load_texture( $name )

Load a texture by name.  It first checks for a file of no extension, which may
be an image file, cached texture file, or symlink/hardlink to another file.
Failing that, it checks for a file of that name with any file extension, and
attempts to load them in whatever order they were returned.

Dies if no matching file can be found, or if it wasn't able to process any match.

=cut

my $json; 
sub _options_to_key { ($json //= JSON::MaybeXS->new->canonical)->encode(shift) }
sub load_texture {
	my ($self, $name, %options)= @_;
	my $tex;
	return $tex if $tex= $self->_texture_cache->{$name};
	
	$log->debug("loading texture $name");
	
	# Merge options, configured options, and configured defaults
	my $default_cfg= $self->tex_config->{'*'} || {};
	my $name_cfg= $self->tex_config->{$name} || {};
	%options= ( file => $name, %$default_cfg, %$name_cfg, %options );
	my $fname= delete $options{file};
	my $opt_key= _options_to_key(\%options);
	
	my $info= $self->_texture_dir_cache->{$fname}
		or croak "No such texture '$name'";
	# $info is pair if [$inode_key, $real_path].  Check if inode is already loaded
	# with these same options.
	unless ($tex= $self->_texture_cache->{$info->[0] . $opt_key}) {
		$tex= OpenGL::Sandbox::Texture->new(\%options)->load($info->[1]);
		$self->_texture_cache->{$info->[0] . $opt_key}= $tex;
	}
	$self->_texture_cache->{$name}= $tex;
	return $tex;
}

sub _cache_directory {
	my ($self, $path, $extension_priority)= @_;
	my %names;
	File::Find::find({ no_chdir => 1, wanted => sub {
		return if -d $_; # ignore directories
		my $full_path= $File::Find::name;
		(my $rel_name= substr($full_path, length($File::Find::dir))) =~ s,^[\\/],,;
		# If it's a symlink, get the real filename
		if (-l $full_path) {
			$full_path= readlink $full_path;
			$full_path= canonpath(catdir($File::Find::dir, $full_path))
				unless file_name_is_absolute($full_path);
		}
		# Decide on the friendly name which becomes the key in the hash
		(my $key= $rel_name) =~ s/\.\w+$//;
		# If there is a conflict for the key, resolve with the extension priority (low wins)
		# or else a key of literally $_ takes priority
		if ($names{$key}) {
			if (!$extension_priority) {
				return unless $rel_name eq $key;
			} else {
				my ($this_ext)= ($full_path =~ /\.(\w+)$/);
				my ($prev_ext)= ($names{$key}[1] =~ /\.(\w+)$/);
				($extension_priority->{$this_ext//''}//999) < ($extension_priority->{$prev_ext//''}//999)
					or return;
			}
		}
		# Stat, for device/inode.  But if stat fails, warn and skip it.
		if (my ($dev, $inode)= stat $full_path) {
			$names{$rel_name}= $names{$key}= [ "($dev,$inode)", $full_path ];
		}
		else {
			$log->warn("Can't stat $full_path: $!");
		}
	}}, $path);
	\%names;
}

1;
