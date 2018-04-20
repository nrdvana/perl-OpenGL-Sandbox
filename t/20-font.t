#! /usr/bin/env perl
use strict;
use warnings;
use Test::More;

use_ok( 'OpenGL::Sandbox::Font' ) or BAIL_OUT;

chomp(my $ttf= `find /usr/share -name '*.ttf' | head -n 1`);
-f $ttf or die "Can't find a font to test with in /usr/share";
my $mmap= OpenGL::Sandbox::MMap->new($ttf);
my $font= new_ok( 'OpenGL::Sandbox::Font::TextureFont', [ $mmap ], '$font' );

done_testing;