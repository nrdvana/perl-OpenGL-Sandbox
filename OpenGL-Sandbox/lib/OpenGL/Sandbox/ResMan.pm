package OpenGL::Sandbox::ResMan;
use Moo;
use Try::Tiny;
use Carp;
use File::Spec::Functions qw/ catdir rel2abs file_name_is_absolute canonpath /;
use Log::Any '$log';
use OpenGL::Sandbox::MMap;
use OpenGL::Sandbox::Texture;
use File::Find ();
use Scalar::Util ();

# ABSTRACT: Resource manager for OpenGL prototyping
# VERSION

=head1 SYNOPSIS

  my $r= OpenGL::Sandbox::ResMan->default_instance;
  my $tex= $r->tex('foo');
  my $font= $r->font('default');

=head1 DESCRIPTION

This object caches references to various OpenGL resources like textures and fonts.
It is usually instantiated as a singleton from L</default_instance> or from
importing the C<$res> variable from L<OpenGL::Sandbox>.  It pulls resources
from a directory of your choice.  Where possible, files get memory-mapped
directly into the library that uses them, which should keep the overhead of
this library as low as possible.

Note that you need to install L<OpenGL::Sandbox::V1::FTGLFont> in order to get font support,
currently.  Other font providers might be added later.

=head1 ATTRIBUTES

=head2 resource_root_dir

The path where resources are located, adhering to the basic layout of:

  ./tex/          # textures
  ./tex/default   # file or symlink for default texture.  Required.
  ./font/         # fonts compatible with libfreetype
  ./font/default  # file or symlink for default font.  Required.
  ./shader/       # GLSL shaders with extension '.glsl', '.frag', or '.vert'

=head2 font_config

A hashref of font names which holds default L<OpenGL::Sandbox::Font|font> constructor
options.  The hash key of C<'*'> can be used to apply default values to every font.
The font named 'default' can be configured here instead of needing a file of that name in
the C<font/> directory.

Example font_config:

  {
    '*'     => { face_size => 48 }, # default settings get applied to all configs
    3d      => { face_size => 64, type => 'FTExtrudeFont' },
    default => { face_size => 32, filename => 'myfont1' }, # font named 'default'
    myfont2 => 'myfont1',  # alias
  }

=head2 tex_config

A hashref of texture names which holds default L<OpenGL::Sandbox::Texture|texture> constructor
options.  The hash key of C<'*'> can be used to apply default values to every texture.
The texture named 'default' can be configured here instead of needing a file of that name in
the C<tex/> directory.

Example tex_config:

  {
    '*'     => { wrap_s => GL_CLAMP,  wrap_t => GL_CLAMP  },
    default => { filename => 'foo.png' }, # texture named "default"
    tile1   => { wrap_s => GL_REPEAT, wrap_t => GL_REPEAT },
    blocky  => { mag_filter => GL_NEAREST },
    alias1  => 'tile1',
  }

=head2 shader_config

A hashref of shader names which holds default L<OpenGL::Sandbox::Shader|shader> constructor
options.  The hash key of C<'*'> can be used to apply default values to every shader.

Example shader_config:

  {
    '*' => { type => GL_FRAGMENT_SHADER },
    aurora => { filename => 'aurora.frag' },
    vpassthrough => { filename => 'vertex-passthrough.vert', type => GL_VERTEX_SHADER },
  }

=head2 program_config

A hashref of program (pipeline) names which holds default L<OpenGL::Sandbox::Program|program>
constructor options.  The hash key of C<'*'> can be used to apply default values to every program.

Example program_config

  {
    '*' => { shaders => { vertex => 'vpassthrough', fragment => 'aurora' } },
    'demo' => { attr => { ... }, shaders => { vertex => 'special_vshader' } },
  }

=cut

has resource_root_dir => ( is => 'rw', default => sub { '.' } );
has font_config       => ( is => 'rw', default => sub { +{} } );
has tex_config        => ( is => 'rw', default => sub { +{} } );
has shader_config     => ( is => 'rw', default => sub { +{} } );
has program_config    => ( is => 'rw', default => sub { +{} } );
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
has _font_dir_cache    => ( is => 'lazy', clearer => 1 );
has _texture_cache     => ( is => 'ro', default => sub { +{} } );
has _texture_dir_cache => ( is => 'lazy', clearer => 1 );
has _shader_dir_cache  => ( is => 'lazy', clearer => 1 );
has _shader_cache      => ( is => 'ro', default => sub { +{} } );
has _program_cache     => ( is => 'ro', default => sub { +{} } );

sub _build__texture_dir_cache {
	$_[0]->_cache_directory(catdir($_[0]->resource_root_dir, 'tex'), $_[0]->tex_fmt_priority)
}
sub _build__font_dir_cache {
	$_[0]->_cache_directory(catdir($_[0]->resource_root_dir, 'font'));
}
sub _build__shader_dir_cache {
	$_[0]->_cache_directory(catdir($_[0]->resource_root_dir, 'shader'));
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
END { $_default_instance->clear_cache if $_default_instance }

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
	eval 'require OpenGL::Sandbox::V1::FTGLFont'
		or croak "Font support requires module L<OpenGL::Sandbox::V1::FTGLFont>, and OpenGL 1.x";
	no warnings 'redefine';
	*load_font= *_load_font;
	goto $_[0]->can('load_font');
}
sub _load_font {
	my ($self, $name, %options)= @_;
	$self->_font_cache->{$name} ||= do {
		$log->debug("loading font $name");
		my $name_cfg= $self->font_config->{$name} // {};
		# Check for alias
		ref $name_cfg
			or return $self->load_font($name_cfg);
		# Merge options, configured options, and configured defaults
		my $default_cfg= $self->font_config->{'*'} // {};
		%options= ( filename => $name, %$default_cfg, %$name_cfg, %options );
		my $font_data= $self->load_fontdata($options{filename});
		OpenGL::Sandbox::V1::FTGLFont->new(data => $font_data, %options);
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

sub load_texture {
	my ($self, $name, %options)= @_;
	my $tex;
	return $tex if $tex= $self->_texture_cache->{$name};
	
	$log->debug("loading texture $name");

	my $name_cfg= $self->tex_config->{$name} // {};
	# Check for alias
	ref $name_cfg
		or return $self->load_texture($name_cfg);

	# Merge options, configured options, and configured defaults
	my $default_cfg= $self->tex_config->{'*'} // {};
	%options= ( filename => $name, %$default_cfg, %$name_cfg, %options );
	
	my $info= $self->_texture_dir_cache->{$options{filename}}
		or croak "No such texture '$options{filename}'";
	$tex= OpenGL::Sandbox::Texture->new(%options, filename => $info->[1]);
	$self->_texture_cache->{$name}= $tex;
	return $tex;
}

=head2 shader

  my $shader= $res->shader( $name );
  my $shader= $res->load_shader( $name, %options );

Returns a named shader.  A C<$name> ending with C<.frag> or C<.vert> will imply the relevant
GL shader type, unless you specifically passed it in C<%options> or configured it in
L</shader_config>.  Every call after the first uses the cached shader object, and C<%options>
are ignored.

Shader objects will always be returned, but using them will throw exceptions if the
OpenGL context can't support them.

=cut

sub shader {
	# Loading Shader might die on old OpenGL, so use a trampoline before accessing for first time.
	require OpenGL::Sandbox::Shader;
	no warnings 'redefine';
	*shader= *_load_shader;
	*load_shader= *_load_shader;
	shift->_load_shader(@_);
}
*load_shader= *shader;
sub _load_shader {
	my ($self, $name, %options)= @_;
	return $self->_shader_cache->{$name} //= do {
		$log->debug("loading shader $name");
		my $name_cfg= $self->shader_config->{$name} // {};
		# Check for alias
		!ref $name_cfg? $self->_load_shader($name_cfg)
		: do {
			# Merge options, configured options, and configured defaults
			my $default_cfg= $self->shader_config->{'*'} // {};
			%options= ( filename => $name, %$default_cfg, %$name_cfg, %options );
			my $info= $self->_shader_dir_cache->{$options{filename}}
				or croak "No such shader '$options{filename}'";
			OpenGL::Sandbox::Shader->new(%options, filename => $info->[1]);
		}
	};
}

=head2 program

  my $prog= $res->program( $name );

Return a named shader program.  The settings come from L</program_config>, but if that
does not specify C<shaders>, this will look through the C<< shaders/ >> directory for every
shader that begins with this name.  For example, if the directory contains:

   shaders/foo.vert
   shaders/foo.frag

Then this will augment the configuration with

   shaders => { vert => 'foo.vert', frag => 'foo.frag' }

Shader objects will always be returned, but using them will throw exceptions if the
OpenGL context can't support them.

=cut

sub program {
	require OpenGL::Sandbox::Program;
	no warnings 'redefine';
	*program= *_load_program;
	shift->_load_program(@_);
}
sub _load_program {
	my ($self, $name, %options)= @_;
	return $self->_program_cache->{$name} //= do {
		$log->debug("loading shader program (pipeline) $name");
		my $name_cfg= $self->program_config->{$name} // {};
		# Check for alias
		!ref $name_cfg? $self->_load_program($name_cfg)
		: do {
			# Merge options, configured options, and configured defaults
			my $default_cfg= $self->program_config->{'*'} // {};
			# Find shaders with same base name as this program, unless they were
			# specifically given by %options or %$name_cfg
			my %shaders= $options{shaders}? %{$options{shaders}}
				: $name_cfg->{shaders}? %{$name_cfg->{shaders}}
				# If shaders "foo.frag" and "foo.vert" exist, then this
				# will generate { frag => "foo.frag", vert => "foo.vert" }
				: map { $_ =~ /^\Q$name\E\.(\w+)$/? ($1 => $_) : () }
					keys %{ $self->_shader_dir_cache };
			# But still merge in any of the defaults if they weren't overridden
			%shaders= (%{$default_cfg->{shaders}}, %shaders)
				if $default_cfg->{shaders};
			# Now, translate the shader names into shader objects
			$_= $self->load_shader($_)
				for values %shaders;
			OpenGL::Sandbox::Program->new(
				%$default_cfg, %$name_cfg, %options, shaders => \%shaders
			);
		}
	};
}

=head2 

=head2 clear_cache

Call this method to remove all current references to any resource.  If this was the last
reference to those resources, it will also garbage collect any OpenGL resources that had been
allocated.  The next access to any font or texture will re-load the resource from disk.

=cut

sub clear_cache {
	my $self= shift;
	%{ $self->_texture_cache }= ();
	$self->_clear_texture_dir_cache;
	%{ $self->_font_cache }= ();
	%{ $self->_fontdata_cache }= ();
	$self->_clear_font_dir_cache;
	%{ $self->_program_cache }= ();
	%{ $self->_shader_cache }= ();
	$self->_clear_shader_dir_cache;
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
		# (but the whole filename always becomes a key in the hash as well)
		(my $short_name= $rel_name) =~ s/\.\w+$//;
		# If there is a conflict for the short key...
		if ($names{$short_name}) {
			# If extension priority available, use that.  Else first in wins.
			if (!$extension_priority) {
				$short_name= $rel_name;
			} else {
				my ($this_ext)= ($full_path =~ /\.(\w+)$/);
				my ($prev_ext)= ($names{$short_name}[1] =~ /\.(\w+)$/);
				($extension_priority->{$this_ext//''}//999) < ($extension_priority->{$prev_ext//''}//999)
					or ($short_name= $rel_name);
			}
		}
		# Stat, for device/inode.  But if stat fails, warn and skip it.
		if (my ($dev, $inode)= stat $full_path) {
			$names{$rel_name}= $names{$short_name}= [ "($dev,$inode)", $full_path ];
		}
		else {
			$log->warn("Can't stat $full_path: $!");
		}
	}}, $path);
	\%names;
}

1;
