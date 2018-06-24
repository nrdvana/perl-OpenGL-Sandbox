#! /usr/bin/env perl
use strict;
use warnings;
use FindBin;
use File::Spec::Functions 'catdir';
use Time::HiRes 'sleep';
use Test::More;
use Try::Tiny;
use Log::Any::Adapter 'TAP';
use OpenGL::Sandbox qw/ make_context get_gl_errors GL_TRIANGLES /;
use OpenGL::Sandbox::V1 qw/ compile_list cylinder sphere disk partial_disk /;

my $c= try { make_context; }
	or plan skip_all => "Can't test without context";

# No way to verify... just call methods and verify no GL errors.
sub assert_noerror {
	my ($code, $name)= @_;
	local $@;
	if (eval { $code->(); 1; }) {
		is_deeply( [get_gl_errors], [], $name);
	} else {
		fail($name);
		diag $@;
	}
}

assert_noerror sub { cylinder(1,2,3,4,5); }, 'cylinder';
assert_noerror sub { sphere(1,2,3); }, 'sphere';
assert_noerror sub { disk(2,1,3,4); }, 'disk';
assert_noerror sub { partial_disk(2,1,3,4,5,6); }, 'partial_disk';

done_testing;
