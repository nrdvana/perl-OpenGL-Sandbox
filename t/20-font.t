#! /usr/bin/env perl
use strict;
use warnings;
use FindBin;
use Test::More;

use_ok( 'OpenGL::Sandbox::Font' ) or BAIL_OUT;

my $mmap= OpenGL::Sandbox::MMap->new("$FindBin::Bin/data/font/Empty.ttf");
my $font= new_ok( 'OpenGL::Sandbox::Font', [ data => $mmap ], '$font' );
is( $font->ascender, 0, 'font has zero dimension character' );

done_testing;