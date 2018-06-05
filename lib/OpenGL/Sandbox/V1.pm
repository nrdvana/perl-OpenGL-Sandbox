package OpenGL::Sandbox::V1;
use strict;
use warnings;
use Carp;
use parent 'Exporter';
use Try::Tiny;
use Math::Trig;

use Inline
	C => do { my $x= __FILE__; $x =~ s|\.pm|\.c|; Cwd::abs_path($x) },
	LIBS => '-lGL',
	CCFLAGSEX => '-Wall -g3 -Os';

=head1 EXPORTABLE FUNCTIONS

=head2 MATRIX FUNCTIONS

=head3 load_identity

Alias for glLoadIdentity

=head3 local_matrix

  local_matrix { ... };

Wrap a block of code with glPushmatrix/glPopMatrix.  This wrapper also checks the matrix stack
depth before and after the call, warns if they don't match, and performs any missing
glPopMatrix calls.

=cut

sub local_matrix(&) { goto &_local_matrix }
*load_identity= *OpenGL::glLoadIdentity;

=head3 scale

  scale $xyz;
  scale $x, $y; # z=1
  scale $x, $y, $z;

Scale all axes (one argument), the x and y axes (2 arguments), or a normal call to glScale
(3 arguments).

=head3 trans

  trans $x, $y;
  trans $x, $y, $z;

Translate along x,y or x,y,z axes.  Calls either glTranslate2f or glTranslate3f.

=head3 trans_scale

  trans_scale $x, $y, $x, $s;       # scale each by $s
  trans_scale $x, $y, $x, $sx, $sy; # $sz=1
  trans_scale $x, $y, $x, $sx, $sy, $sz;

Combination of glTranslate, then glScale.

=head3 rotate

  rotate $degrees, $x, $y, $z;
  rotate x => $degrees;
  rotate y => $degrees;
  rotate z => $degrees;

Normal call to glRotated, or x/y/z notation to rotate around that axis.

=head3 mirror

  mirror 'x';  # glScale(-1, 0, 0)
  mirror 'y';  # glScale(0, -1, 0)
  mirror 'xyz'; # glScale(-1, -1, -1)

Use glScale to invert one more more axes.

=head3 local_gl

  local_gl { ... };

Like local_matrix, but also calls glPushAttrib/glPopAttrib.
This is expensive, and should probably only be used for debugging.

=cut

sub local_gl(&) { goto &_local_gl }

=head2 GEOMETRY PLOTTING

=head3 lines

  lines { ... };  # wraps code with glBegin(GL_LINES); ... glEnd();

=head3 line_strip

  line_strip { ... };  # wraps code with glBegin(GL_LINE_STRIP); ... glEnd();

=head3 quads

  quads { ... };  # wraps code with glBegin(GL_QUADS); ... glEnd();

=head3 quad_strip

  quad_strip { ... }; # wraps code with glBegin(GL_QUAD_STRIP); ... glEnd();

=head3 triangles

  triangles { ... }; # wraps code with glBegin(GL_TRIANGLES); ... glEnd();

=head3 triangle_strip

  triangle_strip { ... }; # wraps code with glBegin(GL_TRIANGLE_STRIP); ... glEnd();

=head3 triangle_fan

  triangle_fan { ... }; # wraps code with glBegin(GL_TRIANGLE_FAN); ... glEnd();

=cut

sub lines(&) { goto &_lines }
sub line_strip(&) { goto &_line_strip }
sub quads(&) { goto &_quads }
sub quad_strip(&) { goto &_quad_strip }
sub triangles(&) { goto &_triangles }
sub triangle_strip(&) { goto &_triangle_strip }
sub triangle_fan(&) { goto &_triangle_fan }

=head3 plot_xy

  plot_xy(
     $geom_mode,  # optional, i.e. GL_TRIANGLES or undef
     $x0, $y0,  # Shortcut for many glVertex2d calls
     $x1, $y1,
     ...
     $xN, $yN,
  );

If C<$geom_mode> is not undef or zero, this makes a call to C<glBegin> and C<glEnd> around the
calls to C<glVertex2d>.

=head3 plot_xyz

  plot_xyz(
     $geom_mode,
     $x0, $y0, $z0,
     $x1, $y1, $z1,
     ...
     $xN, $yN, $zN,
  );

Like above, but call C<glVertex3d>.

=head3 plot_st_xy

  plot_st_xy(
     $geom_mode,
     $s0, $t0,  $x0, $y0,
     $s1, $t1,  $x1, $y1,
     ...
     $sN, $tN,  $xN, $yN,
  );

Like above, but calls both C<glTexCoord2d> and C<glVertex2d>.

=head3 plot_st_xyz

  plot_st_xyz(
     $geom_mode,
     $s0, $t0,   $x0, $y0, $z0,
     $s1, $t1,   $x1, $y1, $z1,
     ...
     $sN, $tN,   $xN, $yN, $zN,
  );

Like above, but call both C<glTexCoord2d> and C<glVertex3d>.

=head3 plot_norm_st_xyz

  plot_norm_st_xyz(
     $geom_mode,
     $nx0, $ny0, $nz0,   $s0, $t0,   $x0, $y0, $z0,
     $nx0, $ny0, $nz0,   $s1, $t1,   $x1, $y1, $z1,
     ...
     $nx0, $ny0, $nz0,   $sN, $tN,   $xN, $yN, $zN,
  );

Like above, but calls each of C<glNormal3d>, C<glTexCoord2d>, C<glVertex3d>.

=head2 DISPLAY LISTS

=head3 displaylist

  my $list= compile_list { ... };

Constructs a displaylist by compiling the code in the block.

=head3 dlist_compile

  call_list($list, sub { ... });

If the variable C<$list> contains a compiled displaylist, this calls that list.  Else it
creates a new list, assigns it to the variable C<$list>, and compiles the contents of the
coderef.  This is a convenient way of compiling some code on the first pass and then calling
it every iteration after that.

=cut

sub compile_list(&) { DisplayList->new->compile(shift); }

*call_list= *_displaylist_call;

=head2 COLORS

=head3 setcolor

  setcolor($r, $g, $b);
  setcolor($r, $g, $b, $a);
  setcolor(\@rgb);
  setcolor(\@rgba);
  setcolor('#RRGGBB');
  setcolor('#RRGGBBAA');

Various ways to specify a color for glSetColor4f.  If Alpha component is missing, it defaults to 1.0

=head3 extract_color

  my ($r, $g, $b, $a)= extract_color('#RRGGBBAA');

Convenience method that always returns 4 components of a color, given a variety of formats.

=head3 color_mult

  my ($r, $g, $b, $a)= color_mult( \@color1, \@color2 )

Multiply each component of color1 by that component of color2.

=cut

sub draw_axes {
	my ($scale, $units, $color)= @_;
	OpenGL::glPushAttrib(OpenGL::GL_CURRENT_BIT | OpenGL::GL_ENABLE_BIT);
	OpenGL::glDisable(OpenGL::GL_TEXTURE_2D);
	$scale //= 1;
	$units //= 100;
	my $err= 1;
	eval {
		lines {
			setcolor(color_mult($color, [1,1,1,0.5])) if defined $color;
			for (my $x= -$units; $x <= $units; $x++) {
				ploy_xy undef,
					$x*$scale,  $units*$scale,
					$x*$scale, -$units*$scale;
			}
			for (my $y= -$units; $y <= $units; $y++) {
				plot_xy undef,
					$units*$scale, $y*$scale,
					-$units*$scale, $y*$scale;
			}
		};
		quads {
			my $thick= $scale*0.05;
			setcolor($color) if defined $color;
			plot_xy undef,
				-$thick, -$units*$scale,
				-$thick,  $units*$scale,
				 $thick,  $units*$scale,
				 $thick, -$units*$scale,
				-$units*$scale, -$thick,
				 $units*$scale, -$thick,
				 $units*$scale,  $thick,
				-$units*$scale,  $thick;
		};
		$err= 0;
	};
	OpenGL::glPopAttrib();
	$log->error($@) if $err;
}

sub draw_unit_cube {
	my ($scale)= @_;
	OpenGL::glPushAttrib(OpenGL::GL_CURRENT_BIT | OpenGL::GL_ENABLE_BIT);
	OpenGL::glDisable(OpenGL::GL_TEXTURE_2D);
	$scale //= 1;
	my $err= 1;
	eval {
		lines sub {
			for my $x (0, 1) {
				for my $y (0, 1) {
					OpenGL::glColor3d(.25 + $x*.75, .25 + $y*.75, .25);
					OpenGL::glVertex3d(-1+$x*2, -1+$y*2, -1);
					OpenGL::glColor3d(.25 + $x*.75, .25 + $y*.75, 1);
					OpenGL::glVertex3d(-1+$x*2, -1+$y*2,  1);
				}
			}
			for my $x (0, 1) {
				for my $z (0, 1) {
					OpenGL::glColor3d(.25 + $x*.75, .25, .25 + $z*.75);
					OpenGL::glVertex3d(-1+$x*2, -1, -1+$z*2);
					OpenGL::glColor3d(.25 + $x*.75, 1, .25 + $z*.75);
					OpenGL::glVertex3d(-1+$x*2, 1, -1+$z*2);
				}
			}
			for my $z (0, 1) {
				for my $y (0, 1) {
					OpenGL::glColor3d(.25, .25 + $y*.75, .25 + $z*.75);
					OpenGL::glVertex3d(-1, -1+$y*2, -1+$z*2);
					OpenGL::glColor3d(1, .25 + $y*.75, .25 + $z*.75);
					OpenGL::glVertex3d(1, -1+$y*2, -1+$z*2);
				}
			}
		};
		$err= 0;
	};
	OpenGL::glPopAttrib();
	$log->error($@) if $err;
}

sub draw_crossbox {
	my ($min_x, $min_y, $w, $h)= @_ == 1? $_[0]->xywh : @_;
	my ($max_x, $max_y)= ($min_x + $w, $min_y + $h);
	glPushAttrib(GL_CURRENT_BIT | GL_ENABLE_BIT);
	glDisable(GL_TEXTURE_2D);
	setcolor(.5,1,.5,.5);
	line_strip {
		plot_v2
			$min_x, $min_y,
			$min_x, $max_y,
			$max_x, $max_y,
			$max_x, $min_y,
			$min_x, $min_y;
	};
	# Cross hairs of origin
	setcolor(1,.5,.5,.5);
	lines {
		plot_v2
			$min_x, 0,  $max_x, 0,
			0, $min_y,  0, $max_y;
	};
	# Diagonals from origin to corners
	setcolor(.7,.4,.4,.4);
	lines {
		plot_v2
			$min_x, $min_y,  0,0,
			$max_x, $max_y,  0,0,
			$min_x, $max_y,  0,0,
			$max_x, $min_y,  0,0;
	};
	glPopAttrib();
}

1;
