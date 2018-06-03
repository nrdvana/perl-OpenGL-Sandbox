#! /usr/bin/env perl
use strict;
use warnings;
use FindBin;
use Try::Tiny;
use Test::More;
use JSON;
use X11::GLX::DWIM;
use Log::Any::Adapter 'TAP';

use_ok( 'OpenGL::Sandbox::Texture' ) or BAIL_OUT;

my $glx= X11::GLX::DWIM->new();
$glx->target({ pixmap => { width => 128, height => 128 } });
note 'GL Version '.$glx->glx_version;

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
				my $tx= OpenGL::Sandbox::Texture->new(filename => $fname)->load;
				is( $tx->width, $dim, "width=$dim" );
				is( $tx->height, $dim, "height=$dim" );
				is( $tx->pow2_size, $dim, "pow2_size=$dim" );
				ok( !$tx->mipmap, "no mipmaps" );
				is( !!$tx->has_alpha, !!$alpha, "has_alpha=$alpha" );
				is_deeply( $glx->get_gl_errors//{}, {}, 'no GL error' );
			}
		};
	}
};

subtest load_png => sub {
	my @tests= (
		[ '8x8.png', 8, 8, 8, 0, 8, 8 ],
		[ '14x7-rgba.png', 16, 16, 16, 1, 14, 7 ]
	);
	for (@tests) {
		my ($fname, $width, $height, $pow2, $has_alpha, $src_w, $src_h)= @$_;
		subtest $fname => sub {
			my $tx= OpenGL::Sandbox::Texture->new(filename => "$datadir/tex/$fname")->load;
			is( $tx->width, $width, 'width' );
			is( $tx->height, $height, 'height' );
			is( $tx->pow2_size, $pow2, 'pow2_size' );
			is( $tx->has_alpha, $has_alpha, 'alpha' );
			is( $tx->src_width, $src_w, 'src_width' );
			is( $tx->src_height, $src_h, 'src_height' );
			
			OpenGL::Sandbox::Texture::convert_png("$datadir/tex/$fname", "$tmp/$fname.rgb");
			my $tx2= OpenGL::Sandbox::Texture->new(filename => "$tmp/$fname.rgb")->load;
			is( $tx2->width, $tx->width, 'width after convert to rgb' );
			is_deeply( $glx->get_gl_errors//{}, {}, 'no GL error' );
		};
	}
};

subtest render => sub {
	my $tx1= OpenGL::Sandbox::Texture->new(filename => "$datadir/tex/8x8.png")->load;
	my $tx2= OpenGL::Sandbox::Texture->new(filename => "$datadir/tex/14x7-rgba.png")->load;
	my @tests= (
		[ ],
		[ center => 1 ],
		[ x => 1.5 ],
		[ y => 1.5 ],
		[ z => 1.5 ],
		[ w => 1, h => 1 ],
		[ w => 1 ],
		[ h => 1 ],
		[ scale => 4 ],
		[ s => .1 ],
		[ t => .1 ],
		[ s_rep => 5 ],
		[ t_rep => 5 ],
	);
	# Can't actually check result, but just check for exceptions
	for my $t (@tests) {
		is( (try{ $tx1->render(@$t); '' } catch {$_}), '', 'render sq   '.JSON->new->canonical->encode($t) );
		is( (try{ $tx2->render(@$t); '' } catch {$_}), '', 'render rect '.JSON->new->canonical->encode($t) );
	}
};

done_testing;
