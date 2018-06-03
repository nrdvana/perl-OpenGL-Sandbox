#! /usr/bin/env perl
use strict;
use warnings;
use FindBin;
use Test::More;
use Log::Any::Adapter 'TAP';
use File::Spec::Functions 'catdir';

use OpenGL::Sandbox qw/ $res font tex /;
$res->resource_root_dir(catdir($FindBin::Bin, 'data'));

is( $res->font('Empty'), font('Empty') );

is( $res->tex('default'), tex('default') );

done_testing;