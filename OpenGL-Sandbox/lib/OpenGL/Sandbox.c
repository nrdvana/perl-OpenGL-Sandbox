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

/* These are wrappers around various OpenGL functions that don't have a nice and/or consistent
 * wrapper between OpenGL and OpenGL::Modern
 */

int gen_textures(int count) {
	GLuint tx_id;
	glGenTextures(count, &tx_id);
	return tx_id;
}

void delete_texture(unsigned tx_id) {
	glDeleteTextures(1, &tx_id);
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

extern void glGenerateMipmap(int);

void _texture_load_rgb_square(HV *self, SV *mmap, int is_bgr) {
	SV *sv;
	void *data= SCALAR_REF_DATA(mmap);
	int len= SCALAR_REF_LEN(mmap);
	const char *ver;
	int major, minor;
	SV *tx_id_p=  _fetch_if_defined(self, "tx_id", 5);
	SV *mipmap_p= _fetch_if_defined(self, "mipmap", 6);
	SV *wrap_s_p= _fetch_if_defined(self, "wrap_s", 6);
	SV *wrap_t_p= _fetch_if_defined(self, "wrap_t", 6);
	SV *min_filter_p= _fetch_if_defined(self, "min_filter", 10);
	SV *mag_filter_p= _fetch_if_defined(self, "mag_filter", 10);
	int has_alpha= 0;
	int dim= _dimension_from_filesize(len, &has_alpha);
	int gl_fmt= is_bgr? ( has_alpha? GL_BGRA : GL_BGR )
	                  : ( has_alpha? GL_RGBA : GL_RGB );
	int gl_internal_fmt= has_alpha? GL_RGBA : GL_RGB;
	
	if (!tx_id_p) croak("tx_id must be initialized first");
	
	/* use mipmaps if the user set it to true, or if the min_filter uses a mipmap,
	   and default in absence of any user prefs is true. */
	int with_mipmaps= mipmap_p? SvTRUE(mipmap_p)
		: !min_filter_p? 1
		: SvIV(min_filter_p) == GL_NEAREST || SvIV(min_filter_p) == GL_LINEAR ? 0
		: 1;
	
	if (!data || !len)
		croak("Expected non-empty scalar-ref pixel buffer");
	
	/* Ensure the OpenGL context is initialized */
	//call_pv("OpenGL::Sandbox::_ensure_context", G_VOID | G_NOARGS | G_EVAL);
	//if (SvTRUE(ERRSV))
	//	croak(NULL);
	
	/* Mipmap strategy depends on version of GL.
	   Supposedly this GetString is more compatible than GetInteger(GL_VERSION_MAJOR)
	*/
	ver= (const char *) glGetString(GL_VERSION);
	if (!ver || sscanf(ver, "%d.%d", &major, &minor) != 2)
		croak("Can't get GL_VERSION");
	
	/* Bind texture */
	glBindTexture(GL_TEXTURE_2D, SvIV(tx_id_p));
	
	if (with_mipmaps) {
		if (major < 3) {
			glTexParameteri(GL_TEXTURE_2D, GL_GENERATE_MIPMAP, GL_TRUE);
			if (mag_filter_p)
				glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, SvIV(mag_filter_p));
			if (min_filter_p)
				glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, SvIV(min_filter_p));
		}
	} else {
		if (mag_filter_p)
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, SvIV(mag_filter_p));
		/* this one needs overridden even if user didn't request it, because default uses mipmaps */
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, min_filter_p? SvIV(min_filter_p) : GL_LINEAR);
		/* and inform opengl that this is the only mipmap level */
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_BASE_LEVEL, 0);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAX_LEVEL, 0);
	}
	glTexImage2D(GL_TEXTURE_2D, 0, gl_internal_fmt, dim, dim, 0, gl_fmt, GL_UNSIGNED_BYTE, data);
	if (with_mipmaps && major >= 3) {
		/* glEnable(GL_TEXTURE_2D); /* correct bug in ATI, accoridng to Khronos FAQ */
		glGenerateMipmap(GL_TEXTURE_2D);
		/* examples show setting these after mipmap generation.  Does it matter? */
		if (mag_filter_p)
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, SvIV(mag_filter_p));
		if (min_filter_p)
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, SvIV(min_filter_p));
	}
	if (wrap_s_p)
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, SvIV(wrap_s_p));
	if (wrap_t_p)
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, SvIV(wrap_t_p));

	/* update attributes */
	if (!hv_store(self, "width",     5, sv=newSViv(dim), 0)
	 || !hv_store(self, "height",    6, sv=newSViv(dim), 0)
	 || !hv_store(self, "pow2_size", 9, sv=newSViv(dim), 0)
	 || !hv_store(self, "has_alpha", 9, sv=newSViv(has_alpha? 1 : 0), 0)
	) {
		if (sv) sv_2mortal(sv);
		croak("Can't store results in supplied hash");
	}
	return;
}

int round_up_pow2(long dim) {
	--dim;
	dim |= dim >> 32;
	dim |= dim >> 16;
	dim |= dim >> 8;
	dim |= dim >> 4;
	dim |= dim >> 2;
	dim |= dim >> 1;
	return ++dim;
}

SV* _img_rescale_to_pow2_square(int width, int height, int has_alpha, int want_bgr, SV *sref) {
	struct SwsContext *sws= NULL;
	SV *ret= NULL;
	void *data= SCALAR_REF_DATA(sref);
	int len= SCALAR_REF_LEN(sref);
	int px_size= has_alpha? 4 : 3;
	int dim= round_up_pow2(width > height? width : height);
	const uint8_t *src_planes[4]= { data,0,0,0 };
	int src_stride[4]= { width*px_size,0,0,0 };
	uint8_t *dst_planes[4]= { 0,0,0,0 };
	int dst_stride[4]= { dim*px_size,0,0,0 };
	
	if (!data || !len)
		croak("Expected non-empty scalar-ref pixel buffer");
	if (width * height * px_size != len)
		croak("Size of scalar ref disagrees with rectangle dimensions: %d * %d * %d != %d",
			width, height, px_size, len);
	
	/* rescale to square */
	sws= sws_getCachedContext(sws, width, height, has_alpha? AV_PIX_FMT_RGBA : AV_PIX_FMT_RGB24,
		dim, dim, want_bgr? (has_alpha? AV_PIX_FMT_BGRA : AV_PIX_FMT_BGR24) : (has_alpha? AV_PIX_FMT_RGBA : AV_PIX_FMT_RGB24),
		SWS_BICUBIC, NULL, NULL, NULL);
	if (!sws)
		croak("can't initialize resize context");
	
	/* allocate a "mortal" scalar into which we write the new image */
	ret= sv_2mortal(newSV(dim*dim*px_size));
	sv_setpvn(ret, "", 0);
	SvGROW(ret, dim*dim*px_size);
	SvCUR_set(ret, dim*dim*px_size);
	dst_planes[0]= (uint8_t*) SvPVX(ret);
	
	/* perform the rescale */
	sws_scale(sws, src_planes, src_stride, 0, height, dst_planes, dst_stride);
	sws_freeContext(sws);
	
	/* return a ref to the scalar, to avoid making a copy */
	return newRV_inc(ret);
}

void _img_rgb_to_bgr(SV *sref, int has_alpha) {
	char *p= SCALAR_REF_DATA(sref), *last, c;
	int px_size= has_alpha? 4 : 3;
	int len= SCALAR_REF_LEN(sref);
	if (!p || len < px_size) croak("Expected non-empty scalar-ref pixel buffer");
	last= p + len - px_size;
	while (p <= last) {
		c= p[0]; p[0]= p[2]; p[2]= c;
		p+= px_size;
	}
}

/* Wrappers for various shader-related functions, requiring at least GL 2.0 */
#ifdef GL_VERSION_2_0

const char* get_glsl_type_name(int type) {
	switch (type) {
	case GL_BOOL:              return "bool";
	case GL_BOOL_VEC2:         return "bvec2";
	case GL_BOOL_VEC3:         return "bvec3";
	case GL_BOOL_VEC4:         return "bvec4";
	case GL_INT:               return "int";
	case GL_INT_VEC2:          return "ivec2";
	case GL_INT_VEC3:          return "ivec3";
	case GL_INT_VEC4:          return "ivec4";
	case GL_UNSIGNED_INT:      return "unsigned int";
	#ifdef GL_VERSION_2_1
	case GL_UNSIGNED_INT_VEC2: return "uvec2";
	case GL_UNSIGNED_INT_VEC3: return "uvec3";
	case GL_UNSIGNED_INT_VEC4: return "uvec4";
	#endif
	case GL_FLOAT:             return "float";
	case GL_FLOAT_VEC2:        return "vec2";
	case GL_FLOAT_VEC3:        return "vec3";
	case GL_FLOAT_VEC4:        return "vec4";
	case GL_FLOAT_MAT2:        return "mat2";
	case GL_FLOAT_MAT3:        return "mat3";
	case GL_FLOAT_MAT4:        return "mat4";
	case GL_FLOAT_MAT2x3:      return "mat2x3";
	case GL_FLOAT_MAT2x4:      return "mat2x4";
	case GL_FLOAT_MAT3x2:      return "mat3x2";
	case GL_FLOAT_MAT3x4:      return "mat3x4";
	case GL_FLOAT_MAT4x2:      return "mat4x2";
	case GL_FLOAT_MAT4x3:      return "mat4x3";
	case GL_DOUBLE:            return "double";
	#ifdef GL_VERSION_4_1
	case GL_DOUBLE_VEC2:       return "dvec2";
	case GL_DOUBLE_VEC3:       return "dvec3";
	case GL_DOUBLE_VEC4:       return "dvec4";
	case GL_DOUBLE_MAT2:       return "dmat2";
	case GL_DOUBLE_MAT3:       return "dmat3";
	case GL_DOUBLE_MAT4:       return "dmat4";
	case GL_DOUBLE_MAT2x3:     return "dmat2x3";
	case GL_DOUBLE_MAT3x2:     return "dmat3x2";
	case GL_DOUBLE_MAT2x4:     return "dmat2x4";
	case GL_DOUBLE_MAT4x2:     return "dmat4x2";
	case GL_DOUBLE_MAT3x4:     return "dmat3x4";
	case GL_DOUBLE_MAT4x3:     return "dmat4x3";
	#endif
	default: return NULL;
	}
}

SV * get_program_uniforms(unsigned program) {
	GLsizei namelen;
	GLint size, loc, active_uniforms= 0, i;
	GLenum type;
	char namebuf[32];
	HV *result; AV *item;
	result= (HV*) sv_2mortal((SV*) newHV());
	glGetProgramiv(program, GL_ACTIVE_UNIFORMS, &active_uniforms);
	for (i= 0; i < active_uniforms; i++) {
		namelen= 0;
		glGetActiveUniform(program, i, sizeof(namebuf)-1, &namelen, &size, &type, namebuf);
		if (namelen > 0 && namelen < sizeof(namebuf)) {
			namebuf[namelen]= '\0';
			loc= glGetUniformLocation(program, namebuf);
			item= (AV*) sv_2mortal((SV*) newAV());
			av_extend(item, 3);
			av_push(item, newSVpvn(namebuf, namelen));
			av_push(item, newSViv(loc));
			av_push(item, newSViv(type));
			av_push(item, newSViv(size));
			if (!hv_store(result, namebuf, namelen, newRV_inc((SV*)item), 0)) croak("hv_store failed");
		}
    }
	return newRV_inc((SV*) result);
}

void set_uniform(unsigned program, SV* uniform_cache, const char *name, ...) {
	Inline_Stack_Vars;
	SV **entry, *s;
	int type= 0, component_type, size= 0, loc= 0, components= 0, buf_req= 0, i, cur_prog;
	char static_buf[ 8 * 16 ], *buf;
	AV *info= NULL, *array= NULL;
	
	/* Can't call glUniform for a program that isn't the active one, unless GL > 4.1 */
	glGetIntegerv(GL_CURRENT_PROGRAM, &cur_prog);
	if (cur_prog != program) {
		#ifdef GL_VERSION_4_1
		glGetIntegerv(GL_MAJOR_VERSION, &i);
		if (i < 4)
		#endif
			croak("Can't set uniforms for program other than the current (unless GL >= 4.1)");
	}

	/* Lazy-build the uniform cache */
	if (!SvROK(uniform_cache) || !SvOK(SvRV(uniform_cache)) || SvTYPE(SvRV(uniform_cache)) != SVt_PVHV) {
		sv_setsv( uniform_cache, get_program_uniforms(program) );
	}

	/* Find uniform details by name */
	entry= hv_fetch((HV*) SvRV(uniform_cache), name, strlen(name), 0);
	if (!entry || !*entry || !SvROK(*entry))
		croak("No active uniform '%s' in program %d", name, program);
	if (SvTYPE(SvRV(*entry)) != SVt_PVAV || av_len(info= (AV*) SvRV(*entry)) < 3)
		croak("Invalid uniform info record for %s", name);

	/* Validate the uniform metadata */
	entry= av_fetch(info, 1, 0);
	if (!entry || !*entry || !SvIOK(*entry)) croak("Invalid uniform info record for %s", name);
	loc= SvIV(*entry);
	entry= av_fetch(info, 2, 0);
	if (!entry || !*entry || !SvIOK(*entry)) croak("Invalid uniform info record for %s", name);
	type= SvIV(*entry);
	entry= av_fetch(info, 3, 0);
	if (!entry || !*entry || !SvIOK(*entry)) croak("Invalid uniform info record for %s", name);
	size= SvIV(*entry);

	/* Determine how many and what type of arguments we want based on type */
	switch (type) {
	         case GL_FLOAT: components= 1;
	if (0) { case GL_FLOAT_VEC2: components= 2; }
	if (0) { case GL_FLOAT_VEC3: components= 3; }
	if (0) { case GL_FLOAT_VEC4: components= 4; }
	if (0) { case GL_FLOAT_MAT2: components= 4; }
	if (0) { case GL_FLOAT_MAT3: components= 9; }
	if (0) { case GL_FLOAT_MAT4: components= 16; }
	#ifdef GL_FLOAT_MAT2x3
	if (0) { case GL_FLOAT_MAT2x3: case GL_FLOAT_MAT3x2: components= 6; }
	if (0) { case GL_FLOAT_MAT2x4: case GL_FLOAT_MAT4x2: components= 8; }
	if (0) { case GL_FLOAT_MAT3x4: case GL_FLOAT_MAT4x3: components= 12; }
	#endif
		component_type= GL_FLOAT;
		buf_req= components * size * sizeof(GLfloat);
		break;
	         case GL_INT:      case GL_BOOL:      components= 1;
	if (0) { case GL_INT_VEC2: case GL_BOOL_VEC2: components= 2; }
	if (0) { case GL_INT_VEC3: case GL_BOOL_VEC3: components= 3; }
	if (0) { case GL_INT_VEC4: case GL_BOOL_VEC4: components= 4; }
		component_type= GL_INT;
		buf_req= components * size * sizeof(GLint);
		break;
	#ifdef GL_VERSION_2_1
	         case GL_UNSIGNED_INT: components= 1;
	if (0) { case GL_UNSIGNED_INT_VEC2: components= 2; }
	if (0) { case GL_UNSIGNED_INT_VEC3: components= 3; }
	if (0) { case GL_UNSIGNED_INT_VEC4: components= 4; }
		component_type= GL_UNSIGNED_INT;
		buf_req= components * size * sizeof(GLint);
		break;
	#endif
	#ifdef GL_VERSION_4_1
	         case GL_DOUBLE: components= 1;
	if (0) { case GL_DOUBLE_VEC2: components= 2; }
	if (0) { case GL_DOUBLE_VEC3: components= 3; }
	if (0) { case GL_DOUBLE_VEC4: components= 4; }
	if (0) { case GL_DOUBLE_MAT2: components= 4; }
	if (0) { case GL_DOUBLE_MAT3: components= 9; }
	if (0) { case GL_DOUBLE_MAT4: components= 16; }
	if (0) { case GL_DOUBLE_MAT2x3: case GL_DOUBLE_MAT3x2: components= 6; }
	if (0) { case GL_DOUBLE_MAT2x4: case GL_DOUBLE_MAT4x2: components= 8; }
	if (0) { case GL_DOUBLE_MAT3x4: case GL_DOUBLE_MAT4x3: components= 12; }
		component_type= GL_DOUBLE;
		buf_req= components * size * sizeof(GLdouble);
		break;
	#endif
	default:
		croak("Unimplemented type %d for uniform %s", type, name);
	}

	/* Check whether user gave us the right type and number of arguments */
	if (Inline_Stack_Items == 3 + components * size) {
		array= NULL;
	}
	else if (Inline_Stack_Items == 4 && SvROK(Inline_Stack_Item(3))) {
		if (sv_isa(Inline_Stack_Item(3), "OpenGL::Array")) {
			croak("OpenGL::Array objects are not yet handled");
		}
		else if (SvTYPE(SvRV(Inline_Stack_Item(3))) == SVt_PVAV) {
			array= (AV*) SvRV(Inline_Stack_Item(3));
			if (av_len(array) != components * size)
				croak("Uniform %s is type %s, requiring %d values (got %d)", name, get_glsl_type_name(type), components*size, Inline_Stack_Items-3);
		}
		else
			croak("Don't know how to extract values from %s", SvPV_nolen(Inline_Stack_Item(3)));
	}
	else {
		croak("Uniform %s is type %s, requiring %d values (got %d)", name, get_glsl_type_name(type), components*size, Inline_Stack_Items-3);
	}

	/* If not packed into an OpenGL::Array, round up the data and pack it into one of our own */
	if (buf_req <= sizeof(static_buf))
		buf= static_buf; /* use stack buffer if large enough */
	else {
		Newx(buf, buf_req, char);
		SAVEFREEPV(buf); /* perl frees it for us */
	}
	for (i= 0; i < components; i++) {
		if (array) {
			entry= av_fetch(array, i, 0);
			s= entry? *entry : NULL;
		} else {
			s= Inline_Stack_Item(3+i);
		}
		if (!s || !SvOK(s)) croak("Undef encountered in uniform values");
		switch (component_type) {
		case GL_INT:          ((GLint*)buf)[i]= SvIV(s); break;
		case GL_UNSIGNED_INT: ((GLuint*)buf)[i]= SvUV(s); break;
		case GL_FLOAT:        ((GLfloat*)buf)[i]= SvNV(s); break;
		#ifdef GL_VERSION_4_1
		case GL_DOUBLE:       ((GLdouble*)buf)[i]= SvNV(s); break;
		#endif
		default: croak("Unimplemented");
		}
	}

	/* Finally, call glUniform depending on the type */
	#ifdef GL_VERSION_4_1
	if (cur_prog == program) {
	#endif
	switch (type) {
	case GL_INT:      case GL_BOOL:      glUniform1iv(loc, size, (GLint*) buf); break;
	case GL_INT_VEC2: case GL_BOOL_VEC2: glUniform2iv(loc, size, (GLint*) buf); break;
	case GL_INT_VEC3: case GL_BOOL_VEC3: glUniform3iv(loc, size, (GLint*) buf); break;
	case GL_INT_VEC4: case GL_BOOL_VEC4: glUniform4iv(loc, size, (GLint*) buf); break;
	#ifdef GL_VERSION_2_1
	case GL_UNSIGNED_INT:      glUniform1uiv(loc, size, (GLuint*) buf); break;
	case GL_UNSIGNED_INT_VEC2: glUniform2uiv(loc, size, (GLuint*) buf); break;
	case GL_UNSIGNED_INT_VEC3: glUniform3uiv(loc, size, (GLuint*) buf); break;
	case GL_UNSIGNED_INT_VEC4: glUniform4uiv(loc, size, (GLuint*) buf); break;
	#endif
	case GL_FLOAT:        glUniform1fv(loc, size, (GLfloat*) buf); break;
	case GL_FLOAT_VEC2:   glUniform2fv(loc, size, (GLfloat*) buf); break;
	case GL_FLOAT_VEC3:   glUniform3fv(loc, size, (GLfloat*) buf); break;
	case GL_FLOAT_VEC4:   glUniform4fv(loc, size, (GLfloat*) buf); break;
	case GL_FLOAT_MAT2:   glUniformMatrix2fv(loc, size, 0, (GLfloat*) buf); break;
	case GL_FLOAT_MAT3:   glUniformMatrix3fv(loc, size, 0, (GLfloat*) buf); break;
	case GL_FLOAT_MAT4:   glUniformMatrix4fv(loc, size, 0, (GLfloat*) buf); break;
	#ifdef GL_FLOAT_MAT2x3
	case GL_FLOAT_MAT2x3: glUniformMatrix2x3fv(loc, size, 0, (GLfloat*) buf); break;
	case GL_FLOAT_MAT3x2: glUniformMatrix3x2fv(loc, size, 0, (GLfloat*) buf); break;
	case GL_FLOAT_MAT2x4: glUniformMatrix2x4fv(loc, size, 0, (GLfloat*) buf); break;
	case GL_FLOAT_MAT4x2: glUniformMatrix4x2fv(loc, size, 0, (GLfloat*) buf); break;
	case GL_FLOAT_MAT3x4: glUniformMatrix3x4fv(loc, size, 0, (GLfloat*) buf); break;
	case GL_FLOAT_MAT4x3: glUniformMatrix4x3fv(loc, size, 0, (GLfloat*) buf); break;
	#endif
	#ifdef GL_VERSION_4_1
	case GL_DOUBLE:        glUniform1dv(loc, size, (GLdouble*) buf); break;
	case GL_DOUBLE_VEC2:   glUniform2dv(loc, size, (GLdouble*) buf); break;
	case GL_DOUBLE_VEC3:   glUniform3dv(loc, size, (GLdouble*) buf); break;
	case GL_DOUBLE_VEC4:   glUniform4dv(loc, size, (GLdouble*) buf); break;
	case GL_DOUBLE_MAT2:   glUniformMatrix2dv(loc, size, 0, (GLdouble*) buf); break;
	case GL_DOUBLE_MAT3:   glUniformMatrix3dv(loc, size, 0, (GLdouble*) buf); break;
	case GL_DOUBLE_MAT4:   glUniformMatrix4dv(loc, size, 0, (GLdouble*) buf); break;
	case GL_DOUBLE_MAT2x3: glUniformMatrix2x3dv(loc, size, 0, (GLdouble*) buf); break;
	case GL_DOUBLE_MAT3x2: glUniformMatrix3x2dv(loc, size, 0, (GLdouble*) buf); break;
	case GL_DOUBLE_MAT2x4: glUniformMatrix2x4dv(loc, size, 0, (GLdouble*) buf); break;
	case GL_DOUBLE_MAT4x2: glUniformMatrix4x2dv(loc, size, 0, (GLdouble*) buf); break;
	case GL_DOUBLE_MAT3x4: glUniformMatrix3x4dv(loc, size, 0, (GLdouble*) buf); break;
	case GL_DOUBLE_MAT4x3: glUniformMatrix4x3dv(loc, size, 0, (GLdouble*) buf); break;
	#endif
	default: croak("Unimplemented type %d for uniform %s", type, name);
	}
	#ifdef GL_VERSION_4_1
	} else {
		switch (type) {
		case GL_INT:      case GL_BOOL:      glProgramUniform1iv(loc, size, (GLint*) buf); break;
		case GL_INT_VEC2: case GL_BOOL_VEC2: glProgramUniform2iv(loc, size, (GLint*) buf); break;
		case GL_INT_VEC3: case GL_BOOL_VEC3: glProgramUniform3iv(loc, size, (GLint*) buf); break;
		case GL_INT_VEC4: case GL_BOOL_VEC4: glProgramUniform4iv(loc, size, (GLint*) buf); break;
		case GL_UNSIGNED_INT:      glProgramUniform1uiv(loc, size, (GLuint*) buf); break;
		case GL_UNSIGNED_INT_VEC2: glProgramUniform2uiv(loc, size, (GLuint*) buf); break;
		case GL_UNSIGNED_INT_VEC3: glProgramUniform3uiv(loc, size, (GLuint*) buf); break;
		case GL_UNSIGNED_INT_VEC4: glProgramUniform4uiv(loc, size, (GLuint*) buf); break;
		case GL_FLOAT:         glProgramUniform1fv(loc, size, (GLfloat*) buf); break;
		case GL_FLOAT_VEC2:    glProgramUniform2fv(loc, size, (GLfloat*) buf); break;
		case GL_FLOAT_VEC3:    glProgramUniform3fv(loc, size, (GLfloat*) buf); break;
		case GL_FLOAT_VEC4:    glProgramUniform4fv(loc, size, (GLfloat*) buf); break;
		case GL_FLOAT_MAT2:    glProgramUniformMatrix2fv(loc, size, 0, (GLfloat*) buf); break;
		case GL_FLOAT_MAT3:    glProgramUniformMatrix3fv(loc, size, 0, (GLfloat*) buf); break;
		case GL_FLOAT_MAT4:    glProgramUniformMatrix4fv(loc, size, 0, (GLfloat*) buf); break;
		case GL_FLOAT_MAT2x3:  glProgramUniformMatrix2x3fv(loc, size, 0, (GLfloat*) buf); break;
		case GL_FLOAT_MAT3x2:  glProgramUniformMatrix3x2fv(loc, size, 0, (GLfloat*) buf); break;
		case GL_FLOAT_MAT2x4:  glProgramUniformMatrix2x4fv(loc, size, 0, (GLfloat*) buf); break;
		case GL_FLOAT_MAT4x2:  glProgramUniformMatrix4x2fv(loc, size, 0, (GLfloat*) buf); break;
		case GL_FLOAT_MAT3x4:  glProgramUniformMatrix3x4fv(loc, size, 0, (GLfloat*) buf); break;
		case GL_FLOAT_MAT4x3:  glProgramUniformMatrix4x3fv(loc, size, 0, (GLfloat*) buf); break;
		case GL_DOUBLE:        glProgramUniform1dv(loc, size, (GLdouble*) buf); break;
		case GL_DOUBLE_VEC2:   glProgramUniform2dv(loc, size, (GLdouble*) buf); break;
		case GL_DOUBLE_VEC3:   glProgramUniform3dv(loc, size, (GLdouble*) buf); break;
		case GL_DOUBLE_VEC4:   glProgramUniform4dv(loc, size, (GLdouble*) buf); break;
		case GL_DOUBLE_MAT2:   glProgramUniformMatrix2dv(loc, size, 0, (GLdouble*) buf); break;
		case GL_DOUBLE_MAT3:   glProgramUniformMatrix3dv(loc, size, 0, (GLdouble*) buf); break;
		case GL_DOUBLE_MAT4:   glProgramUniformMatrix4dv(loc, size, 0, (GLdouble*) buf); break;
		case GL_DOUBLE_MAT2x3: glProgramUniformMatrix2x3dv(loc, size, 0, (GLdouble*) buf); break;
		case GL_DOUBLE_MAT3x2: glProgramUniformMatrix3x2dv(loc, size, 0, (GLdouble*) buf); break;
		case GL_DOUBLE_MAT2x4: glProgramUniformMatrix2x4dv(loc, size, 0, (GLdouble*) buf); break;
		case GL_DOUBLE_MAT4x2: glProgramUniformMatrix4x2dv(loc, size, 0, (GLdouble*) buf); break;
		case GL_DOUBLE_MAT3x4: glProgramUniformMatrix3x4dv(loc, size, 0, (GLdouble*) buf); break;
		case GL_DOUBLE_MAT4x3: glProgramUniformMatrix4x3dv(loc, size, 0, (GLdouble*) buf); break;
		default: croak("Unimplemented type %d for uniform %s", type, name);
		}
	}
	#endif
	Inline_Stack_Void;
}

#endif
/* end version guard for shaders */
