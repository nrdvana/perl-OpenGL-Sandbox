package OpenGL::Sandbox::MMap;
use strict;
use warnings;
use File::Map 'map_file';

# ABSTRACT: Wrapper around a memory-mapped scalar ref
# VERSION

=head1 SYNOPSIS

  my $mmap= OpenGL::Sandbox::MMap->new("Filename.ttf");

=head1 DESCRIPTION

This is a simple wrapper around File::Map to make it more convenient to open
read-only memory-mapped files, and to make sure they are distinctly held as
references and not accidentally copied into perl scalars.

=head1 ATTRIBUTES

=head2 size

Number of bytes mapped from file.  Same as C<length($$mmap)>

=head1 METHODS

=head2 new

  my $mmap= OpenGL::Sandbox::MMap->new($filename);

Return a blessed reference to a scalar which points to memory-mapped data.
C<$filename> is always opened read-only.

=cut

sub size { length(${(shift)}) }

sub new {
	my ($class, $fname)= @_;
	my $map;
	my $self= bless \$map, $class;
	map_file $map, $fname;
	$self;
}

1;
