package OpenGL::Sandbox;
use strict;
use warnings;
use Try::Tiny;
use Carp;

# ABSTRACT: Rapid-prototyping utilities for OpenGL

=head1 EXPORTS

=head2 $res

Returns a global instance of the resource manager with resource_root_dir
pointing to the current directory.

=head2 :v1

Exports the OpenGL API 1.x functions and constants, and also convenient aliases
and helper functions from L<OpenGL::Sandbox::V1> (which must be installed
separately).

=cut

sub import {
	my $caller= caller;
	my $class= shift;
	while (defined(my $arg=shift)) {
		if ($arg eq '$res') {
			no strict 'refs';
			my $res= __PACKAGE__->default_instance;
			*{$caller.'::res'}= \$res;
		}
		elsif ($arg eq 'v1') {
			eval "package $caller; use OpenGL::Sandbox::V1 ':all'"
				or croak "Can't load OpenGL::Sandbox::V1 (note that this must be installed separately)\n  $@";
		}
		else {
			croak "'$arg' is not exported by ".__PACKAGE__."\n";
	}
}

1;
