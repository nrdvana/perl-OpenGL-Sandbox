#! /usr/bin/env perl
use strict;
use warnings;
use FindBin;
use Test::More;
use Log::Any::Adapter 'TAP';
use File::Spec::Functions 'catdir';

use OpenGL::Sandbox qw/ $res font tex /;
$res->resource_root_dir(catdir($FindBin::Bin, 'data'));
$res->font_config({
	default => 'SquadaOne-Regular',
});
$res->tex_config({
	default => '8x8',
});

is( $res->font('SquadaOne-Regular'), font('default') );

is( $res->tex('default'), tex('8x8') );

done_testing;