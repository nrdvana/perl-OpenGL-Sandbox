package OpenGL::Sandbox;

use 5.14; # I can aim for older upon request.  Not expecting any requests though.
use strict;
use warnings;
use Try::Tiny;
use Exporter;
use Carp;
require OpenGL::Sandbox::ResMan;

# ABSTRACT: Rapid-prototyping utilities for OpenGL

=head1 EXPORTS

=head2 $res

Returns a default global instance of the L<resource manager|OpenGL::Sandbox::ResMan>
with C<resource_root_dir> pointing to the current directory.

=head2 tex

Shortcut for C<< OpenGL::Sandbox::ResMan->default_instance->tex >>

=head2 font

Shortcut for C<< OpenGL::Sandbox::ResMan->default_instance->font >>

Note that you need to install L<OpenGL::Sandbox::V1::FTGLFont> in order to get font support,
currently.  Other font providers might be added later.

=head2 :1.x

Exports everything from L<OpenGL::Sandbox::V1> (which must be installed separately).
This module contains many "sugar" functions to make the GL 1.x API more friendly.

C<:2.x>, C<:3.x>, etc will likewise import everything from packages named
C<OpenGL::SandBox::$_> (which do not currently exist, but could be authored
in the future)

=cut

our @EXPORT_OK= qw( font tex );
our %EXPORT_TAGS= ( all => \@EXPORT_OK );

sub import {
	my $caller= caller;
	my @normal;
	for (reverse 1..$#_) {
		my $arg= $_[$_];
		if ($arg eq '$res') {
			my $res= OpenGL::Sandbox::ResMan->default_instance;
			no strict 'refs';
			*{$caller.'::res'}= \$res;
			splice(@_, $_, 1);
		}
		elsif ($arg =~ /^:(\d).x$/) {
			my $mod= "OpenGL::Sandbox::V$1";
			eval "package $caller; use $mod ':all'; 1"
				or croak "Can't load $mod (note that this must be installed separately)\n  $@";
			splice(@_, $_, 1);
		}
	}
	goto \&Exporter::import;
}

sub tex  { OpenGL::Sandbox::ResMan->default_instance->tex(@_) }
sub font { OpenGL::Sandbox::ResMan->default_instance->font(@_) }

1;
