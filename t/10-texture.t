#! /usr/bin/env perl
use strict;
use warnings;
use FindBin;
use Test::More;
use X11::GLX::DWIM;

use_ok( 'OpenGL::Sandbox::Texture' ) or BAIL_OUT;

my $glx= X11::GLX::DWIM->new(window => 1);
note 'GL Version '.$glx->glx_version;
$glx->target($glx->create_render_pixmap({ width => 100, height => 100 }));

# Create tmp dir for this script
my $tmp= "$FindBin::Bin/tmp/$FindBin::Script";
$tmp =~ s/\.t$// or die "can't calc temp dir";
-d $tmp || mkdir $tmp or die "Can't create dir $tmp";

my $datadir= "$FindBin::Bin/data";

subtest load_rgb => sub {
	for my $dim (1, 2, 4, 16, 32, 64, 128) {
		subtest "dim=$dim" => sub {
			for my $alpha (0, 1) {
				# Write out RGBA texture
				my $fname= "$tmp/$dim-$alpha.rgb";
				open my $img1, '>', $fname or die "open($fname): $!";
				print $img1 chr(0x7F) x ($dim * $dim * ($alpha?4:3)) or die "print: $!";
				close $img1 or die "close: $!";
				# Load it as a texture
				my $tx= OpenGL::Sandbox::Texture->new->load($fname);
				is( $tx->width, $dim, "width=$dim" );
				is( $tx->height, $dim, "height=$dim" );
				ok( !$tx->mipmap, "no mipmaps" );
				is( !!$tx->has_alpha, !!$alpha, "has_alpha=$alpha" );
				is_deeply( $glx->get_gl_errors//{}, {}, 'no GL error' );
			}
		};
	}
};

subtest load_png => sub {
	my @tests= (
		[ '8x8.png', 8, 8, 0 ],
		[ '14x7-rgba.png', 16, 16, 1 ]
	);
	for (@tests) {
		my ($fname, $width, $height, $has_alpha)= @$_;
		subtest $fname => sub {
			my $tx= OpenGL::Sandbox::Texture->new->load("$datadir/tex/$fname");
			is( $tx->width, $width, 'width' );
			is( $tx->height, $height, 'height' );
			is( $tx->has_alpha, $has_alpha, 'alpha' );
			
			OpenGL::Sandbox::Texture::convert_png("$datadir/tex/$fname", "$tmp/$fname.rgb");
			my $tx2= OpenGL::Sandbox::Texture->new->load("$tmp/$fname.rgb");
			is( $tx2->width, $tx->width, 'width after convert to rgb' );
			is_deeply( $glx->get_gl_errors//{}, {}, 'no GL error' );
		};
	}
};

done_testing;
