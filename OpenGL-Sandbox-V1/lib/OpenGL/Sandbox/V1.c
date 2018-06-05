#include <GL/gl.h>

void _local_gl(SV *code) {
	GLint orig_depth, depth;
	glGetIntegerv(GL_MODELVIEW_STACK_DEPTH, &orig_depth);
	glPushAttrib(GL_ALL_ATTRIB_BITS);
	glPushMatrix();
	call_sv(code, G_ARRAY|G_EVAL);
	glPopMatrix();
	glPopAttrib();
	glGetIntegerv(GL_MODELVIEW_STACK_DEPTH, &depth);
	if (depth > orig_depth) {
		warn("cleaning up matrix stack: depth=%d, orig=%d", depth, orig_depth);
		while (depth-- > orig_depth)
			glPopMatrix();
	}
	if (SvTRUE(ERRSV)) croak(NULL);
}

void _local_matrix(SV *code) {
	GLint orig_depth, depth;
	glGetIntegerv(GL_MODELVIEW_STACK_DEPTH, &orig_depth);
	glPushMatrix();
	call_sv(code, G_ARRAY|G_EVAL);
	glPopMatrix();
	glGetIntegerv(GL_MODELVIEW_STACK_DEPTH, &depth);
	if (depth > orig_depth) {
		warn("cleaning up matrix stack: depth=%d, orig=%d", depth, orig_depth);
		while (depth-- > orig_depth)
			glPopMatrix();
	}
	if (SvTRUE(ERRSV)) croak(NULL);
}

void scale(double scale_x, ...) {
	double scale_y, scale_z;
	Inline_Stack_Vars;
	if (Inline_Stack_Items > 1) {
		scale_y= SvNV(Inline_Stack_Item(1));
		scale_z= (Inline_Stack_Items > 2)? SvNV(Inline_Stack_Item(2)) : 1;
		if (Inline_Stack_Items > 3) warn("extra arguments to scale");
	}
	else {
		scale_y= scale_z= scale_x;
	}
	glScaled(scale_x, scale_y, scale_z);
	Inline_Stack_Void;
}

void trans(double x, double y, ...) {
	Inline_Stack_Vars;
	double z= (Inline_Stack_Items > 2)? SvNV(Inline_Stack_Item(2)) : 0;
	if (Inline_Stack_Items > 3) warn("extra arguments to scale");
	glTranslated(x, y, z);
	Inline_Stack_Void;
}

void trans_scale(double x, double y, double z, double sx, ...) {
	double scale_y, scale_z;
	Inline_Stack_Vars;
	glTranslated(x, y, z);
	if (Inline_Stack_Items > 4) {
		scale_y= SvNV(Inline_Stack_Item(4));
		scale_z= (Inline_Stack_Items > 5)? SvNV(Inline_Stack_Item(5)) : 1;
		if (Inline_Stack_Items > 6) warn("extra arguments to trans_scale");
	}
	else {
		scale_y= scale_z= scale_x;
	}
	glScaled(scale_x, scale_y, scale_z);
	Inline_Stack_Void;
}

void rotate(SV *arg0, double arg1, ...) {
	const char *arg0s;
	Inline_Stack_Vars;
	if (Inline_Stack_Items == 4) {
		glRotated(SvNV(arg0), arg1, SvNV(Inline_Stack_Item(2)), SvNV(Inline_Stack_Item(3)));
	}
	else if (Inline_Stack_Items == 2 && SvPOK(arg0)) {
		arg0s= SvPVX(arg0);
		switch(arg0s[0]) {
		case 'x': if (arg0s[1] == '\0') glRotated(arg1, 1.0, 0.0, 0.0); else
		case 'y': if (arg0s[1] == '\0') glRotated(arg1, 0.0, 1.0, 0.0); else
		case 'z': if (arg0s[1] == '\0') glRotated(arg1, 0.0, 0.0, 1.0); else
		default: warn("wrong arguments to rotate");
		}
	}
	else warn("wrong arguments to rotate");
	Inline_Stack_Void;
}

void mirror(const char* axis) {
	while (*axis) {
		switch(*axis++) {
		case 'x': glScaled(-1.0, 0.0, 0.0);
		case 'y': glScaled(0.0, -1.0, 0.0);
		case 'z': glScaled(0.0, 0.0, -1.0);
		default: warn("wrong arguments to mirror");
		}
	}
}

void _quads(SV *code) {
	glBegin(GL_QUADS);
	call_sv(code, G_ARRAY|G_EVAL);
	glEnd();
	if (SvTRUE(ERRSV)) croak(NULL);
}

void _quad_strip(SV *code) {
	glBegin(GL_QUAD_STRIP);
	call_sv(code, G_ARRAY|G_EVAL);
	glEnd();
	if (SvTRUE(ERRSV)) croak(NULL);
}

void _triangles(SV* code) {
	glBegin(GL_TRIANGLES);
	call_sv(code, G_ARRAY|G_EVAL);
	glEnd();
	if (SvTRUE(ERRSV)) croak(NULL);
}

void _triangle_fan(SV *code) {
	glBegin(GL_TRIANGLE_FAN);
	call_sv(code, G_ARRAY|G_EVAL);
	glEnd();
	if (SvTRUE(ERRSV)) croak(NULL);
}

void _triangle_strip(SV *code) {
	glBegin(GL_TRIANGLE_STRIP);
	call_sv(code, G_ARRAY|G_EVAL);
	glEnd();
	if (SvTRUE(ERRSV)) croak(NULL);
}

void _lines(SV *code) {
	glPushAttrib(GL_CURRENT_BIT | GL_ENABLE_BIT);
	glDisable(GL_TEXTURE_2D);
	glBegin(GL_LINES);
	call_sv(code, G_ARRAY|G_EVAL);
	glEnd();
	glPopAttrib();
	if (SvTRUE(ERRSV)) croak(NULL);
}

void _line_strip(SV *code) {
	glPushAttrib(GL_CURRENT_BIT | GL_ENABLE_BIT);
	glDisable(GL_TEXTURE_2D);
	glBegin(GL_LINE_STRIP);
	call_sv(code, G_ARRAY|G_EVAL);
	glEnd();
	glPopAttrib();
	if (SvTRUE(ERRSV)) croak(NULL);
}

void plot_xy(SV *begin_mode, ...) {
	Inline_Stack_Vars;
	int i, n= Inline_Stack_Items;
	if ((n-1) & 1) warn("Odd number of arguments to plot_xy");
	if (SvOK(begin_mode)) glBegin(SvIV(begin_mode));
	for (i= 1; i+2 <= n; i+= 2) {
		glVertex2d(SvNV(Inline_Stack_Item(i)), SvNV(Inline_Stack_Item(i+1)));
	}
	if (SvOK(begin_mode)) glEnd();
	Inline_Stack_Void;
}

void plot_xyz(SV *begin_mode, ...) {
	Inline_Stack_Vars;
	int i, n= Inline_Stack_Items;
	if ((n-1) % 3) warn("Non-multiple-of-3 arguments to plot_xyz");
	if (SvOK(begin_mode)) glBegin(SvIV(begin_mode));
	for (i= 1; i+3 <= n; i+= 3) {
		glVertex3d(SvNV(Inline_Stack_Item(i)), SvNV(Inline_Stack_Item(i+1)), SvNV(Inline_Stack_Item(i+2)));
	}
	if (SvOK(begin_mode)) glEnd();
	Inline_Stack_Void;
}

void plot_st_xy(SV *begin_mode, ...) {
	Inline_Stack_Vars;
	int i, n= Inline_Stack_Items;
	if ((n-1) & 3) warn("Non-multiple-of-4 arguments to plot_st_xy");
	if (SvOK(begin_mode)) glBegin(SvIV(begin_mode));
	for (i= 1; i+4 <= n; i+= 4) {
		glTexCoord2d(SvNV(Inline_Stack_Item(i)), SvNV(Inline_Stack_Item(i+1)));
		glVertex2d(SvNV(Inline_Stack_Item(i+2)), SvNV(Inline_Stack_Item(i+3)));
	}
	if (SvOK(begin_mode)) glEnd();
	Inline_Stack_Void;
}

void plot_st_xyz(SV *begin_mode, ...) {
	Inline_Stack_Vars;
	int i, n= Inline_Stack_Items;
	if ((n-1) % 5) warn("Non-multiple-of-5 arguments to plot_st_xyz");
	if (SvOK(begin_mode)) glBegin(SvIV(begin_mode));
	for (i= 1; i+5 <= n; i+= 5) {
		glTexCoord2d(SvNV(Inline_Stack_Item(i)), SvNV(Inline_Stack_Item(i+1)));
		glVertex3d(SvNV(Inline_Stack_Item(i+2)), SvNV(Inline_Stack_Item(i+3)), SvNV(Inline_Stack_Item(i+4)));
	}
	if (SvOK(begin_mode)) glEnd();
	Inline_Stack_Void;
}

void plot_norm_st_xyz(SV *begin_mode, ...) {
	Inline_Stack_Vars;
	int i, n= Inline_Stack_Items;
	if ((n-1) & 7) warn("Non-multiple-of-8 arguments to plot_norm_st_xyz");
	if (SvOK(begin_mode)) glBegin(SvIV(begin_mode));
	for (i= 1; i+8 <= n; i+= 8) {
		glNormal3d(SvNV(Inline_Stack_Item(i)), SvNV(Inline_Stack_Item(i+1)), SvNV(Inline_Stack_Item(i+2)));
		glTexCoord2d(SvNV(Inline_Stack_Item(i+3)), SvNV(Inline_Stack_Item(i+4)));
		glVertex3d(SvNV(Inline_Stack_Item(i+5)), SvNV(Inline_Stack_Item(i+6)), SvNV(Inline_Stack_Item(i+7)));
	}
	if (SvOK(begin_mode)) glEnd();
	Inline_Stack_Void;
}

void _setcolor(SV *thing, ...) {
	Inline_Stack_Vars;
	unsigned c;
	if (Inline_Stack_Items == 4) {
		glColor4d(SvNV(thing), SvNV(Inline_Stack_Item(1)), SvNV(Inline_Stack_Item(2)), SvNV(Inline_Stack_Item(3)));
	}
	else if (Inline_Stack_Items == 3) {
		glColor4d(SvNV(thing), SvNV(Inline_Stack_Item(1)), SvNV(Inline_Stack_Item(2)), 1);
	}
	else if (Inline_Stack_Items == 1) {
		c= SvUV(thing);
		glColor4ub((GLbyte)(c>>24), (GLbyte)(c>>16), (GLbyte)(c>>8), (GLbyte)c);
	}
	else warn("wrong arguments");
	Inline_Stack_Void;
}

SV * _displaylist_compile(SV *self, SV *code) {
	int list_id;
	if (SvROK(self) && SvIOK(SvRV(self)))
		list_id= SvIV(SvRV(self));
	else {
		list_id= glGenLists(1);
		if (sv_derived_from(self, "OpenGL::Sandbox::V1::DisplayList"))
			sv_setiv(SvRV(self), list_id);
		else
			/* force self to become a blessed Displaylist, in style of open(my $x) forcing $x to become a filehandle */
			sv_setref_iv(self, "OpenGL::Sandbox::V1::DisplayList", list_id);
	}
	
	glNewList(list_id, GL_COMPILE);
	call_sv(code, G_ARRAY|G_EVAL);
	glEndList();
	if (SvTRUE(ERRSV)) croak(NULL);
	return self;
}

void _displaylist_call(SV *self, ...) {
	Inline_Stack_Vars;
	SV *code;
	if (SvROK(self) && SvIOK(SvRV(self)))
		glCallList(SvIV(SvRV(self)));
	else if (Inline_Stack_Items > 1 && SvOK(code= Inline_Stack_Item(1))) {
		list_id= glGenLists(1);
		if (sv_derived_from(self, "OpenGL::Sandbox::V1::DisplayList"))
			sv_setiv(SvRV(self), list_id);
		else
			/* force self to become a blessed Displaylist, in style of open(my $x) forcing $x to become a filehandle */
			sv_setref_iv(self, "OpenGL::Sandbox::V1::DisplayList", list_id);
		
		glNewList(list_id, GL_COMPILE_AND_EXECUTE);
		call_sv(code, G_ARRAY|G_EVAL);
		glEndList();
		if (SvTRUE(ERRSV)) croak(NULL);
	}
	else warn("Calling un-initialized display list");
	Inline_Stack_Reset;
	Inline_Stack_Push(self);
	Inline_Stack_Done;
}

static void _parse_color(SV *c, float *rgba);

void setcolor(SV *c0) {
	GLfloat components[4];
	if (Inline_Stack_Vars == 1)
		parse_color(c0, components);
	else if (Inline_Stack_Vars == 3) {
		for (i= 0; i < 3; i++)
			components[i]= SvNV(Inline_Stack_Item(i));
		components[i]= 1.0;
	}
	else if (Inline_Stack_Vars == 4) {
		for (i= 0; i < 4; i++)
			components[i]= SvNV(Inline_Stack_Item(i));
	}
	else croak("Expected 1, 3, or 4 arguments to setcolor");
	glColor4fv(components);
}

void extract_color(SV *c) {
	Inline_Stack_Vars;
	float components[4];
	int i;
	parse_color(c, components);
	Inline_Stack_Reset;
	for (i=0; i < 4; i++)
		Inline_Stack_Push(sv_2mortal(newSVnv(components[i])));
	Inline_Stack_Done;
}

void color_mult(SV *c0, SV *c1) {
	Inline_Stack_Vars;
	float components[8];
	int i;
	parse_color(c0, components);
	parse_color(c1, components+4);
	Inline_Stack_Reset;
	for (i=0; i < 4; i++)
		Inline_Stack_Push(sv_2mortal(newSVnv(components[i] * components[i+4])));
	Inline_Stack_Done;
}

static void parse_color(SV *c, float *rgba) {
	SV **field_p;
	int i, n;
	unsigned hex_rgba[4];
	if (!SvOK(c)) {
		*rgba[0]= *rgba[1]= *rgba[2]= 0;
		*rgba[3]= 1;
	}
	else if (SvROK(c) && SvTYPE(c) == SVt_PVAV) {
		for (i=0; i < 4; i++) {
			field_p= av_fetch((SV*) SvRV(c), i, 0);
			rgba[i]= (field_p && *field_p && SvOK(*field_p))? SvNV(*field_p) : 0;
		}
	}
	else {
		n= sscanf(SvPV(c), "#%2x%2x%2x%2x", hex_rgba+0, hex_rgba+1, hex_rgba+2, hex_rgba+3);
		if (n < 3) croak("Not a valid color: %s", SvPV(c));
		if (n < 4) ad= 0xFF;
		for (i=0; i < 4; i++)
			rgba[i]= hex_rgba[i] / 255.0;
	}
}
