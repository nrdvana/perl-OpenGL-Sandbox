#include <GL/gl.h>
#include <GL/glext.h>
#include <libavutil/avutil.h>
#include <libavutil/pixfmt.h>
#include <libswscale/swscale.h>
#if LIBAVUTIL_VERSION_MAJOR < 54
#define AV_PIX_FMT_RGBA PIX_FMT_RGBA
#define AV_PIX_FMT_RGB24 PIX_FMT_RGB24
#define AV_PIX_FMT_BGRA PIX_FMT_BGRA
#define AV_PIX_FMT_BGR24 PIX_FMT_BGR24
#endif

/* Don't want to get into the whole GLEW stuff, but these don't seem to be in gl.h...
 * Shouldn't hurt to include them as long as all access is guarded by #ifdef GL_VERSION_
 */
extern void glGenerateMipmap(int);
extern void glGenBuffers( GLsizei n, GLuint * buffers);
extern void glDeleteBuffers( GLsizei n, const GLuint * buffers);
extern void glBufferData( GLenum target, GLsizeiptr size, const GLvoid * data, GLenum usage);
extern void glBufferSubData( GLenum target, GLintptr offset, GLsizeiptr size, const GLvoid * data);
extern void glGetProgramiv( GLuint program, GLenum pname, GLint *params);
extern GLint glGetUniformLocation( GLuint program, const GLchar *name);
extern void glGetActiveUniform( GLuint program, GLuint index, GLsizei bufSize, GLsizei *length, GLint *size, GLenum *type, GLchar *name);
extern void glUniform1fv( GLint location, GLsizei count, const GLfloat *value);
extern void glUniform2fv( GLint location, GLsizei count, const GLfloat *value);
extern void glUniform3fv( GLint location, GLsizei count, const GLfloat *value);
extern void glUniform4fv( GLint location, GLsizei count, const GLfloat *value);
extern void glUniform1iv( GLint location, GLsizei count, const GLint *value);
extern void glUniform2iv( GLint location, GLsizei count, const GLint *value);
extern void glUniform3iv( GLint location, GLsizei count, const GLint *value);
extern void glUniform4iv( GLint location, GLsizei count, const GLint *value);
extern void glUniform1uiv( GLint location, GLsizei count, const GLuint *value);
extern void glUniform2uiv( GLint location, GLsizei count, const GLuint *value);
extern void glUniform3uiv( GLint location, GLsizei count, const GLuint *value);
extern void glUniform4uiv( GLint location, GLsizei count, const GLuint *value);
extern void glUniformMatrix2fv( GLint location, GLsizei count, GLboolean transpose, const GLfloat *value);
extern void glUniformMatrix3fv( GLint location, GLsizei count, GLboolean transpose, const GLfloat *value);
extern void glUniformMatrix4fv( GLint location, GLsizei count, GLboolean transpose, const GLfloat *value);
extern void glUniformMatrix2x3fv( GLint location, GLsizei count, GLboolean transpose, const GLfloat *value);
extern void glUniformMatrix3x2fv( GLint location, GLsizei count, GLboolean transpose, const GLfloat *value);
extern void glUniformMatrix2x4fv( GLint location, GLsizei count, GLboolean transpose, const GLfloat *value);
extern void glUniformMatrix4x2fv( GLint location, GLsizei count, GLboolean transpose, const GLfloat *value);
extern void glUniformMatrix3x4fv( GLint location, GLsizei count, GLboolean transpose, const GLfloat *value);
extern void glUniformMatrix4x3fv( GLint location, GLsizei count, GLboolean transpose, const GLfloat *value);
#if 0
//#ifdef GL_VERSION_4_1
extern void glUniform1dv( GLint location, GLsizei count, const GLdouble *value);
extern void glUniform2dv( GLint location, GLsizei count, const GLdouble *value);
extern void glUniform3dv( GLint location, GLsizei count, const GLdouble *value);
extern void glUniform4dv( GLint location, GLsizei count, const GLdouble *value);
extern void glUniformMatrix2dv( GLint location, GLsizei count, GLboolean transpose, const GLdouble *value);
extern void glUniformMatrix3dv( GLint location, GLsizei count, GLboolean transpose, const GLdouble *value);
extern void glUniformMatrix4dv( GLint location, GLsizei count, GLboolean transpose, const GLdouble *value);
extern void glUniformMatrix2x3dv( GLint location, GLsizei count, GLboolean transpose, const GLdouble *value);
extern void glUniformMatrix3x2dv( GLint location, GLsizei count, GLboolean transpose, const GLdouble *value);
extern void glUniformMatrix2x4dv( GLint location, GLsizei count, GLboolean transpose, const GLdouble *value);
extern void glUniformMatrix4x2dv( GLint location, GLsizei count, GLboolean transpose, const GLdouble *value);
extern void glUniformMatrix3x4dv( GLint location, GLsizei count, GLboolean transpose, const GLdouble *value);
extern void glUniformMatrix4x3dv( GLint location, GLsizei count, GLboolean transpose, const GLdouble *value);
extern void glProgramUniform1fv( GLuint program, GLint location, GLsizei count, const GLfloat *value);
extern void glProgramUniform2fv( GLuint program, GLint location, GLsizei count, const GLfloat *value);
extern void glProgramUniform3fv( GLuint program, GLint location, GLsizei count, const GLfloat *value);
extern void glProgramUniform4fv( GLuint program, GLint location, GLsizei count, const GLfloat *value);
extern void glProgramUniform1iv( GLuint program, GLint location, GLsizei count, const GLint *value);
extern void glProgramUniform2iv( GLuint program, GLint location, GLsizei count, const GLint *value);
extern void glProgramUniform3iv( GLuint program, GLint location, GLsizei count, const GLint *value);
extern void glProgramUniform4iv( GLuint program, GLint location, GLsizei count, const GLint *value);
extern void glProgramUniform1uiv( GLuint program, GLint location, GLsizei count, const GLuint *value);
extern void glProgramUniform2uiv( GLuint program, GLint location, GLsizei count, const GLuint *value);
extern void glProgramUniform3uiv( GLuint program, GLint location, GLsizei count, const GLuint *value);
extern void glProgramUniform4uiv( GLuint program, GLint location, GLsizei count, const GLuint *value);
extern void glProgramUniformMatrix2fv( GLuint program, GLint location, GLsizei count, GLboolean transpose, const GLfloat *value);
extern void glProgramUniformMatrix3fv( GLuint program, GLint location, GLsizei count, GLboolean transpose, const GLfloat *value);
extern void glProgramUniformMatrix4fv( GLuint program, GLint location, GLsizei count, GLboolean transpose, const GLfloat *value);
extern void glProgramUniformMatrix2x3fv( GLuint program, GLint location, GLsizei count, GLboolean transpose, const GLfloat *value);
extern void glProgramUniformMatrix3x2fv( GLuint program, GLint location, GLsizei count, GLboolean transpose, const GLfloat *value);
extern void glProgramUniformMatrix2x4fv( GLuint program, GLint location, GLsizei count, GLboolean transpose, const GLfloat *value);
extern void glProgramUniformMatrix4x2fv( GLuint program, GLint location, GLsizei count, GLboolean transpose, const GLfloat *value);
extern void glProgramUniformMatrix3x4fv( GLuint program, GLint location, GLsizei count, GLboolean transpose, const GLfloat *value);
extern void glProgramUniformMatrix4x3fv( GLuint program, GLint location, GLsizei count, GLboolean transpose, const GLfloat *value);
extern void glProgramUniform1dv( GLuint program, GLint location, GLsizei count, const GLdouble *value);
extern void glProgramUniform2dv( GLuint program, GLint location, GLsizei count, const GLdouble *value);
extern void glProgramUniform3dv( GLuint program, GLint location, GLsizei count, const GLdouble *value);
extern void glProgramUniform4dv( GLuint program, GLint location, GLsizei count, const GLdouble *value);
extern void glProgramUniformMatrix2dv( GLuint program, GLint location, GLsizei count, GLboolean transpose, const GLdouble *value);
extern void glProgramUniformMatrix3dv( GLuint program, GLint location, GLsizei count, GLboolean transpose, const GLdouble *value);
extern void glProgramUniformMatrix4dv( GLuint program, GLint location, GLsizei count, GLboolean transpose, const GLdouble *value);
extern void glProgramUniformMatrix2x3dv( GLuint program, GLint location, GLsizei count, GLboolean transpose, const GLdouble *value);
extern void glProgramUniformMatrix3x2dv( GLuint program, GLint location, GLsizei count, GLboolean transpose, const GLdouble *value);
extern void glProgramUniformMatrix2x4dv( GLuint program, GLint location, GLsizei count, GLboolean transpose, const GLdouble *value);
extern void glProgramUniformMatrix4x2dv( GLuint program, GLint location, GLsizei count, GLboolean transpose, const GLdouble *value);
extern void glProgramUniformMatrix3x4dv( GLuint program, GLint location, GLsizei count, GLboolean transpose, const GLdouble *value);
extern void glProgramUniformMatrix4x3dv( GLuint program, GLint location, GLsizei count, GLboolean transpose, const GLdouble *value);
#endif

/* These macros are used to access the OpenGL::Sandbox::MMap object data */
#define SCALAR_REF_DATA(obj) (SvROK(obj) && SvPOK(SvRV(obj))? (void*)SvPVX(SvRV(obj)) : (void*)0)
#define SCALAR_REF_LEN(obj)  (SvROK(obj) && SvPOK(SvRV(obj))? SvCUR(SvRV(obj)) : 0)

/* Reading from perl hashes is annoying.  This simplified function only returns
 * non-NULL if the key existed and the value was defined.
 */
SV *_fetch_if_defined(HV *self, const char *field, int len) {
	SV **field_p= hv_fetch(self, field, len, 0);
	return (field_p && *field_p && SvOK(*field_p)) ? *field_p : NULL;
}

void _get_buffer_from_sv(SV *s, char **data, unsigned long *size) {
	dSP;
	if (!s || !SvOK(s)) croak("Data is undefined");
	if (sv_isa(s, "OpenGL::Array")) {
		/* OpenGL::Array has an internal struct and the only way to correctly
		 * access its ->data field is by calling the perl method ->ptr */
		ENTER;
		SAVETMPS;
		PUSHMARK(SP);
		EXTEND(SP, 1);
		PUSHs(sv_mortalcopy(s));
		PUTBACK;
		if (call_method("ptr", G_SCALAR) != 1)
			croak("stack assertion failed");
		SPAGAIN;
		*data= (char*) POPi;
		PUTBACK;
		FREETMPS;
		LEAVE;
		
		ENTER;
		SAVETMPS;
		PUSHMARK(SP);
		EXTEND(SP, 1);
		PUSHs(sv_mortalcopy(s));
		PUTBACK;
		if (call_method("length", G_SCALAR) != 1)
			croak("stack assertion failed");
		SPAGAIN;
		*size= POPi;
		PUTBACK;
		FREETMPS;
		LEAVE;
	}
	else if (sv_isa(s, "OpenGL::Sandbox::MMap") || (SvROK(s) && SvPOK(SvRV(s)))) {
		*data= SCALAR_REF_DATA(s);
		*size= SCALAR_REF_LEN(s);
	}
	else if (SvPOK(s)) {
		*data= SvPV(s, (*size));
	}
	else
		croak("Don't know how to get data buffer from %s", SvPV_nolen(s));
}

void _recursive_pack(void *dest, int *dest_i, int dest_lim, int component_type, SV *val) {
	int i, lim;
	SV **elem;
	AV *array;
	if (SvROK(val) && SvTYPE(SvRV(val)) == SVt_PVAV) {
		array= (AV*) SvRV(val);
		for (i= 0, lim=av_len(array)+1; i < lim; i++) {
			elem= av_fetch(array, i, 0);
			if (!elem || !*elem)
				croak("Undefined value in array");
			_recursive_pack(dest, dest_i, dest_lim, component_type, *elem);
		}
	}
	else {
		if (*dest_i < dest_lim) {
			switch (component_type) {
			case GL_INT:          ((GLint*)dest)[*dest_i]= SvIV(val); break;
			case GL_UNSIGNED_INT: ((GLuint*)dest)[*dest_i]= SvUV(val); break;
			case GL_FLOAT:        ((GLfloat*)dest)[*dest_i]= SvNV(val); break;
			#ifdef GL_VERSION_4_1
			case GL_DOUBLE:       ((GLdouble*)dest)[*dest_i]= SvNV(val); break;
			#endif
			default: croak("Unimplemented");
			}
		}
		/* increment regardless, so we can count how many extra arguments there were */
		++(*dest_i);
	}
}

/* This function operates on the idea that a power of two texture composed of
 * RGB or RGBA pixels must either be 4*4*4...*4 or 4*4*4...*3 bytes long.
 * So, it will either be a clean power of 4, or a power of 4 times 3.
 * This iteratively divides by 4, then checks to see if the result is 1 or 3.
 */
int _dimension_from_filesize(int filesize, int *has_alpha_out) {
	int dim= 1, size= filesize;
	if (size) {
		/* Count size's powers of 4, in dim */
		while ((size & 3) == 0) {
			size >>= 2;
			dim <<= 1;
		}
	}
	if (size != 1 && size != 3)
		croak("File length 0x%X is not a power of 2 quare of pixels", size);
	if (size == 1) { /* RGBA, even power of 4 bytes */
		*has_alpha_out= 1;
		return dim >> 1;
	} else { /* RGB */
		*has_alpha_out= 0;
		return dim;
	}
}
