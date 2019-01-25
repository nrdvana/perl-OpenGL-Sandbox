#! /usr/bin/env perl
use strict;
use warnings;
use Log::Any::Adapter 'Daemontools', -init => { env => 1 };
use Time::HiRes 'time';
use OpenGL::Sandbox qw( :all GL_FLOAT GL_TRIANGLES glDrawArrays );
use OpenGL::Sandbox -resources => {
  path => './t/data',
  program_config => {
    demo => { shaders => { vert => 'xy_screen.vert' } },
  },
  vertex_array_config => {
    unit_quad => {
      buffer => {
        data => pack('f*',
          # two triangles covering entire screen
          -1.0, -1.0,   1.0, -1.0,    -1.0,  1.0,
           1.0, -1.0,   1.0,  1.0,    -1.0,  1.0
        )
      },
      attributes => { pos => { size => 2, type => GL_FLOAT } }
    },
  },
};
make_context;
new_program('demo', shaders => { frag => $ARGV[0] })->activate
	->set_uniform("iResolution", 640, 480, 1.0);
vao('unit_quad')->apply;
my $started= time;
while (1) {
  program('demo')->set_uniform("iGlobalTime", time - $started);
  glDrawArrays( GL_TRIANGLES, 0, 6 );
  next_frame;
}
