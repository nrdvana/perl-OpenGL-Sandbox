#! /usr/bin/env perl
use strict;
use warnings;
use FindBin;
use Test::More;

use_ok( 'OpenGL::Sandbox::Texture' ) or BAIL_OUT;

# Create tmp dir for this script
my $tmp= $FindBin::Bin;
$tmp =~ s,$,/tmp/$FindBin::Script/, or die "can't calc temp dir";
$tmp =~ s,\.t/,/,;
-d $tmp || mkdir $tmp or die "Can't create dir $tmp";

for my $dim (1, 2, 4, 16, 32, 64, 128) {
	subtest "dim=$dim" => sub {
		for my $alpha (0, 1) {
			# Write out RGBA texture
			my $fname= "$tmp/$dim.".($alpha? 'rgba':'rgb');
			open my $img1, '>', $fname or die "open($fname): $!";
			print $img1 chr(0x7F) x ($dim * $dim * ($alpha?4:3)) or die "print: $!";
			close $img1 or die "close: $!";
			# Load it as a texture
			my $tx= OpenGL::Sandbox::Texture->new->load($fname);
			is( $tx->width, $dim, "width=$dim" );
			is( $tx->height, $dim, "height=$dim" );
			is( $tx->mipmaps, undef, "no mipmaps" );
			is( !!$tx->has_alpha, !!$alpha, "has_alpha=$alpha" );
		}
	};
}

done_testing;