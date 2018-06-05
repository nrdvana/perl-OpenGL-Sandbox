package OpenGL::Sandbox::V1::DisplayList;

use strict;
use warnings;
use overload '""' => sub { ${ shift() } };
use OpenGL ();
use OpenGL::Sandbox::V1;

# ABSTRACT: Wrapper class for display lists

=head1 ATTRIBUTES

=head2 id

Return the ID number of the display list.  This remains undef until compiled.

=cut

sub id { ${$_[0]} }

=head1 METHODS

=head2 new

Constructor.  Takes no arguments.  The returned class is a blessed scalar ref, so not very
extensible, but very lightweight.  This does not allocate a list id until you compile the list.
The destructor will delete the list if one was allocated.

=cut

sub new {
	my $class= shift;
	my $id;
	bless \$id, $class;
}

=head2 compile

  $list->compile(sub { ... });

Compile a display list from the OpenGL commands executed within the given coderef.  To compile
and execute simultaneously, just use L</call>.

=head2 call

  $list->call;
  $list->call(sub { ... });

Call the display list, or if it hasn't been allocated yet, compile the sub first.

=cut

*compile= *OpenGL::Sandbox::V1::_displaylist_compile;

*call= *OpenGL::Sandbox::V1::_displaylist_call;

sub DESTROY {
	my $self= shift;
	OpenGL::glDeleteLists($$self, 1)
		if defined $$self;
}

1;
