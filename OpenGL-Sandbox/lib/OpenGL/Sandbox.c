/* Util holds everthing that should not be published into the package by Inline */
#include "Sandbox-util.c"

/* These are wrappers around various OpenGL functions that don't have a nice and/or consistent
 * wrapper between OpenGL and OpenGL::Modern
 */

int _gl_get_integer(int id) {
	GLint i;
	glGetIntegerv(id, &i);
	return i;
}

void gen_textures(int count) {
	Inline_Stack_Vars;
	GLuint static_buf[16], *buf, i;

	if (count < sizeof(static_buf)/sizeof(GLuint))
		buf= static_buf;
	else {
		Newx(buf, count, GLuint);
		SAVEFREEPV(buf); /* perl frees it for us */
	}
	glGenTextures(count, buf);
	EXTEND(SP, count);
	Inline_Stack_Reset;
	for (i= 0; i < count; i++)
		Inline_Stack_Push(newSViv(buf[i]));
	Inline_Stack_Done;
	Inline_Stack_Return(count);
}

void delete_textures(SV *first, ...) {
	Inline_Stack_Vars;
	GLuint static_buf[16], *buf;
	int dest_i, i, n= sizeof(static_buf)/sizeof(GLuint);
	buf= static_buf;
	
	/* first pass, try static buffer */
	for (i= 0, dest_i= 0; i < Inline_Stack_Items; i++)
		_recursive_pack(buf, &dest_i, n, GL_UNSIGNED_INT, Inline_Stack_Item(i));
	n= dest_i;
	/* If too many, second pass with dynamic buffer */
	if (n > sizeof(static_buf)/sizeof(GLuint)) {
		Newx(buf, n, GLuint);
		SAVEFREEPV(buf); /* perl frees it for us */
		for (i= 0, dest_i= 0; i < Inline_Stack_Items; i++)
			_recursive_pack(buf, &dest_i, n, GL_UNSIGNED_INT, Inline_Stack_Item(i));
	}

	glDeleteTextures(n, buf);
	Inline_Stack_Void;
}

#ifdef GL_VERSION_2_0

void gen_buffers(int count) {
	Inline_Stack_Vars;
	GLuint static_buf[16], *buf, i;

	if (count < sizeof(static_buf)/sizeof(GLuint))
		buf= static_buf;
	else {
		Newx(buf, count, GLuint);
		SAVEFREEPV(buf); /* perl frees it for us */
	}
	glGenBuffers(count, buf);
	EXTEND(SP, count);
	Inline_Stack_Reset;
	for (i= 0; i < count; i++)
		Inline_Stack_Push(newSViv(buf[i]));
	Inline_Stack_Done;
	Inline_Stack_Return(count);
}

void delete_buffers(unsigned buf_id) {
	Inline_Stack_Vars;
	GLuint static_buf[16], *buf;
	int dest_i, i, n= sizeof(static_buf)/sizeof(GLuint);
	buf= static_buf;
	/* first pass, try static buffer */
	for (i= 0, dest_i= 0; i < Inline_Stack_Items; i++)
		_recursive_pack(buf, &dest_i, n, GL_UNSIGNED_INT, Inline_Stack_Item(i));
	n= dest_i;
	/* If too many, second pass with dynamic buffer */
	if (n > sizeof(static_buf)/sizeof(GLuint)) {
		Newx(buf, n, GLuint);
		SAVEFREEPV(buf); /* perl frees it for us */
		for (i= 0, dest_i= 0; i < Inline_Stack_Items; i++)
			_recursive_pack(buf, &dest_i, n, GL_UNSIGNED_INT, Inline_Stack_Item(i));
	}

	glDeleteBuffers(n, buf);
	Inline_Stack_Void;
}

#endif
#ifdef GL_VERSION_3_0
void gen_vertex_arrays(int count) {
	Inline_Stack_Vars;
	GLuint static_buf[16], *buf, i;

	if (count < sizeof(static_buf)/sizeof(GLuint))
		buf= static_buf;
	else {
		Newx(buf, count, GLuint);
		SAVEFREEPV(buf); /* perl frees it for us */
	}
	glGenVertexArrays(count, buf);
	EXTEND(SP, count);
	Inline_Stack_Reset;
	for (i= 0; i < count; i++)
		Inline_Stack_Push(newSViv(buf[i]));
	Inline_Stack_Done;
	Inline_Stack_Return(count);
}

void delete_vertex_arrays(unsigned buf_id) {
	Inline_Stack_Vars;
	GLuint static_buf[16], *buf;
	int dest_i, i, n= sizeof(static_buf)/sizeof(GLuint);
	buf= static_buf;
	/* first pass, try static buffer */
	for (i= 0, dest_i= 0; i < Inline_Stack_Items; i++)
		_recursive_pack(buf, &dest_i, n, GL_UNSIGNED_INT, Inline_Stack_Item(i));
	n= dest_i;
	/* If too many, second pass with dynamic buffer */
	if (n > sizeof(static_buf)/sizeof(GLuint)) {
		Newx(buf, n, GLuint);
		SAVEFREEPV(buf); /* perl frees it for us */
		for (i= 0, dest_i= 0; i < Inline_Stack_Items; i++)
			_recursive_pack(buf, &dest_i, n, GL_UNSIGNED_INT, Inline_Stack_Item(i));
	}

	glDeleteVertexArrays(n, buf);
	Inline_Stack_Void;
}
#endif

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

int _round_up_pow2(long dim) {
	--dim;
	dim |= dim >> 32;
	dim |= dim >> 16;
	dim |= dim >> 8;
	dim |= dim >> 4;
	dim |= dim >> 2;
	dim |= dim >> 1;
	return ++dim;
}

/* for diagnosing changes to memory-mapped scalar refs */
int _get_scalarref_pv(SV *) {
	return (int) SCALAR_REF_DATA(sref);
}

SV* _img_rescale_to_pow2_square(int width, int height, int has_alpha, int want_bgr, SV *sref) {
	struct SwsContext *sws= NULL;
	SV *ret= NULL;
	void *data= SCALAR_REF_DATA(sref);
	int len= SCALAR_REF_LEN(sref);
	int px_size= has_alpha? 4 : 3;
	int dim= _round_up_pow2(width > height? width : height);
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

const char * gl_error_name(int code) {
	switch (code) {
	case GL_INVALID_ENUM:      return "GL_INVALID_ENUM";
	case GL_INVALID_VALUE:     return "GL_INVALID_VALUE";
	case GL_INVALID_OPERATION: return "GL_INVALID_OPERATION";
	case GL_OUT_OF_MEMORY:     return "GL_OUT_OF_MEMORY";
	#ifdef GL_INVALID_FRAMEBUFFER_OPERATION
	case GL_INVALID_FRAMEBUFFER_OPERATION: return "GL_INVALID_FRAMEBUFFER_OPERATION";
	#endif
	#ifdef GL_STACK_OVERFLOW
	case GL_STACK_OVERFLOW:    return "GL_STACK_OVERFLOW";
	#endif
	#ifdef GL_STACK_UNDERFLOW
	case GL_STACK_UNDERFLOW:   return "GL_STACK_UNDERFLOW";
	#endif
	#ifdef GL_TABLE_TOO_LARGE
	case GL_TABLE_TOO_LARGE:   return "GL_TABLE_TOO_LARGE";
	#endif
	default:                   return NULL;
	}
}

/* Wrappers for various shader-related functions, requiring at least GL 2.0 */
#ifdef GL_VERSION_2_0

void load_buffer_data(int target, SV *size_sv, SV *data_sv, SV *usage_sv) {
	int usage= usage_sv && SvOK(usage_sv)? SvIV(usage_sv) : GL_STATIC_DRAW;
	unsigned long size, data_size= 0;
	char *data= NULL;
	_get_buffer_from_sv(data_sv, &data, &data_size);
	size= (size_sv && SvOK(size_sv))? SvUV(size_sv) : data_size;
	if (data_size < size) croak("Data not long enough (%d bytes, you requested %d)", data_size, size);
	glBufferData(target, size, data, usage);
}

void load_buffer_sub_data(int target, long offset, SV *size_sv, SV *data_sv, SV *data_offset_sv) {
	unsigned long size, data_size= 0, data_offset;
	char *data= NULL;
	_get_buffer_from_sv(data_sv, &data, &data_size);
	if (data_offset_sv && SvOK(data_offset_sv)) {
		data_offset= SvUV(data_offset_sv);
		if (data_offset > data_size) croak("Invalid data offset (%d exceeds data length %d)", data_offset, data_size);
		data += data_offset;
		data_size -= data_offset;
	}
	size= (size_sv && SvOK(size_sv))? SvUV(size_sv) : data_size;
	if (data_size < size) croak("Data not long enough (%d bytes, you requested %d)", data_size, size);
	glBufferSubData(target, offset, size, data);
}

SV *mmap_buffer(int buffer_id, SV *buffer_target, SV *access_sv, SV *offset_sv, SV *length_sv) {
	int gl_maj= 0, gl_min= 0;
	int access= 0, access_r= 0, access_w= 0, mode;
	GLint actual_size, target;
	unsigned len, offset, length;
	const char* access_pv;
	void *addr;
	
	/* OpenGL 2.0 only has MapBuffer, 3.0 has MapBufferRange (needed for access flags)
	 * and OpenGL 4.5 has MapNamedBufferRange needed to avoid binding the buffer first
	 */
	glGetIntegerv(GL_MAJOR_VERSION, &gl_maj);
	glGetIntegerv(GL_MINOR_VERSION, &gl_min);
	
	/* 'access' can be given as a symbolic string, or as an integer.  If omitted, assume "r+".
	 * OpenGL < 3.0 won't even have the constants available for GL_MAP_*, so the symbolic
	 * constants allow generic access to the API without worrying about that.
	 */
	if (!SvOK(access_sv)) {
		access_r= 1;
		access_w= 1;
		#ifdef GL_VERSION_3_0
		access= GL_MAP_READ_BIT | GL_MAP_WRITE_BIT;
		#endif
	}
	#ifdef GL_VERSION_3_0
	else if (sv_contains_integer(access_sv)) {
		access= SvIV(access_sv);
		access_r= (access & GL_MAP_READ_BIT)? 1 : 0;
		access_w= (access & GL_MAP_WRITE_BIT)? 1 : 0;
	}
	#endif
	else {
		access_pv= SvPV(access_sv, len);
		if (len < 1) croak("Invalid symbolic access notation \"\"");
		while (*access_pv) {
			switch (*access_pv++) {
			case '+': access_r= 1, access_w= 1; break;
			case 'r': access_r= 1; break;
			case 'w': access_w= 1; break;
			default: croak "Invalid symbolic access notation '%s' in '%s'", access_pv[-1], SvPV_nolen(access_sv));
		}
		#ifdef GL_VERSION_3_0
		access= (access_r? GL_MAP_READ_BIT : 0) | (access_w? GL_MAP_WRITE_BIT : 0);
		#endif
	}
	
	offset= SvOK(offset_sv)? SvUV(offset) : 0;
	length= SvOK(length_sv)? SvUV(length) : 0;

	/* OpenGL 4.5 can look up size and map buffer without binding first */
	#ifdef GL_VERSION_4_5
	if (gl_maj >= 4 && gl_min >= 5) {
		glGetNamedBufferParameteriv(target, GL_BUFFER_SIZE, &actual_size);
		if (offset > actual_size) croak("Offset %d exceeds actual buffer size %d", offset, actual_size);
		if (offset+length > actual_size) croak("Length %d exceeds actual buffer size %d", length, actual_size);
		if (!length) length= actual_size - offset;
		if (!(addr= glMapNamedBufferRange(buffer_id, offset, length, access)))
			croak("glMapNamedBufferRange failed");
	}
	else {
	#endif
		if (!SvOK(target_sv)) croak("Require GL buffer target on OpenGL < 4.5");
		target= SvIV(target_sv);
		glBindBuffer(target, buffer_id);
		glGetBufferParameteriv(target, GL_BUFFER_SIZE, &actual_size);
		if (offset > actual_size) croak("Offset %d exceeds actual buffer size %d", offset, actual_size);
		if (offset+length > actual_size) croak("Length %d exceeds actual buffer size %d", length, actual_size);
		if (!length) length= actual_size - offset;
		/* OpenGL 3.0 is required for BufferRange, else fall back to mapping whole thing. */
		#ifdef GL_VERSION_3_0
		if (gl_maj >= 3) {
			if (!(addr= glMapBufferRange(target, offset, length, access)))
				croak("glMapBufferRange failed");
		}
		else
		#else
		{
			mode= access_r && access_w? GL_READ_WRITE
				  : access_r? GL_READ_ONLY
				  : access_w? GL_WRITE_ONLY
				  : croak("Must specify read or write access");
			if (!(addr= glMapBuffer(target, mode)))
				croak("glMapBuffer failed");
			/* OpenGL mapped all of it, but we can just pretend we did a sub-range */
			addr= (void*) (((char*) addr) + offset);
		}
		#endif
	#ifdef GL_VERSION_4_5
	}
	#endif

	/* at this point, have buffer mapped and know length */
	create_sv_view_of_data(addr, length, );
}

int unmap_buffer(int buffer_id, SV *buffer_target, SV *memmap) {
}

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
	#if 0
	//#ifdef GL_VERSION_4_1
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
	int type= 0, component_type, size= 0, loc= 0, components= 0, buf_req= 0, i, cur_prog, arg_i, arg_lim, dest_i;
	unsigned long buf_size;
	char static_buf[ 8 * 16 ], *buf= NULL;
	AV *info= NULL;
	
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
	#if 0
	//#ifdef GL_VERSION_4_1
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

	/* If there is only one argument, and it is a ref, and not an arrayref (those get handled below)
	 * then try using it as a data buffer of some kind.
	 */
	if (Inline_Stack_Items == 4) {
		s= Inline_Stack_Item(3);
		if (SvROK(s) && SvTYPE(SvRV(s)) != SVt_PVAV) {
			_get_buffer_from_sv(s, &buf, &buf_size);
			if (!buf || !buf_size)
				croak("Don't know how to extract values/buffer from %s", SvPV_nolen(s));
			if (buf_size < buf_req)
				croak("Uniform %s is type %s, requiring packed data of at least %d bytes (got %d)", name, get_glsl_type_name(type), buf_req, buf_size);
		}
	}
	/* If not given a packed buffer, recursively iterate the arguments and pack it into one of our own */
	if (!buf) {
		if (buf_req <= sizeof(static_buf))
			buf= static_buf; /* use stack buffer if large enough */
		else {
			Newx(buf, buf_req, char);
			SAVEFREEPV(buf); /* perl frees it for us */
		}
		dest_i= 0;
		for (arg_i= 3, arg_lim= Inline_Stack_Items; arg_i < arg_lim; ++arg_i)
			_recursive_pack(buf, &dest_i, components*size, component_type, Inline_Stack_Item(arg_i));
		if (dest_i != components*size)
			croak("Uniform %s is type %s, requiring %d values (got %d)", name, get_glsl_type_name(type), components*size, dest_i);
	}

	/* Finally, call glUniform depending on the type */
	#if 0
	//#ifdef GL_VERSION_4_1
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
	#if 0
	//#ifdef GL_VERSION_4_1
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
	#if 0
	//#ifdef GL_VERSION_4_1
	} else {
		switch (type) {
		case GL_INT:      case GL_BOOL:      glProgramUniform1iv(program, loc, size, (GLint*) buf); break;
		case GL_INT_VEC2: case GL_BOOL_VEC2: glProgramUniform2iv(program, loc, size, (GLint*) buf); break;
		case GL_INT_VEC3: case GL_BOOL_VEC3: glProgramUniform3iv(program, loc, size, (GLint*) buf); break;
		case GL_INT_VEC4: case GL_BOOL_VEC4: glProgramUniform4iv(program, loc, size, (GLint*) buf); break;
		case GL_UNSIGNED_INT:      glProgramUniform1uiv(program, loc, size, (GLuint*) buf); break;
		case GL_UNSIGNED_INT_VEC2: glProgramUniform2uiv(program, loc, size, (GLuint*) buf); break;
		case GL_UNSIGNED_INT_VEC3: glProgramUniform3uiv(program, loc, size, (GLuint*) buf); break;
		case GL_UNSIGNED_INT_VEC4: glProgramUniform4uiv(program, loc, size, (GLuint*) buf); break;
		case GL_FLOAT:         glProgramUniform1fv(program, loc, size, (GLfloat*) buf); break;
		case GL_FLOAT_VEC2:    glProgramUniform2fv(program, loc, size, (GLfloat*) buf); break;
		case GL_FLOAT_VEC3:    glProgramUniform3fv(program, loc, size, (GLfloat*) buf); break;
		case GL_FLOAT_VEC4:    glProgramUniform4fv(program, loc, size, (GLfloat*) buf); break;
		case GL_FLOAT_MAT2:    glProgramUniformMatrix2fv(program, loc, size, 0, (GLfloat*) buf); break;
		case GL_FLOAT_MAT3:    glProgramUniformMatrix3fv(program, loc, size, 0, (GLfloat*) buf); break;
		case GL_FLOAT_MAT4:    glProgramUniformMatrix4fv(program, loc, size, 0, (GLfloat*) buf); break;
		case GL_FLOAT_MAT2x3:  glProgramUniformMatrix2x3fv(program, loc, size, 0, (GLfloat*) buf); break;
		case GL_FLOAT_MAT3x2:  glProgramUniformMatrix3x2fv(program, loc, size, 0, (GLfloat*) buf); break;
		case GL_FLOAT_MAT2x4:  glProgramUniformMatrix2x4fv(program, loc, size, 0, (GLfloat*) buf); break;
		case GL_FLOAT_MAT4x2:  glProgramUniformMatrix4x2fv(program, loc, size, 0, (GLfloat*) buf); break;
		case GL_FLOAT_MAT3x4:  glProgramUniformMatrix3x4fv(program, loc, size, 0, (GLfloat*) buf); break;
		case GL_FLOAT_MAT4x3:  glProgramUniformMatrix4x3fv(program, loc, size, 0, (GLfloat*) buf); break;
		case GL_DOUBLE:        glProgramUniform1dv(program, loc, size, (GLdouble*) buf); break;
		case GL_DOUBLE_VEC2:   glProgramUniform2dv(program, loc, size, (GLdouble*) buf); break;
		case GL_DOUBLE_VEC3:   glProgramUniform3dv(program, loc, size, (GLdouble*) buf); break;
		case GL_DOUBLE_VEC4:   glProgramUniform4dv(program, loc, size, (GLdouble*) buf); break;
		case GL_DOUBLE_MAT2:   glProgramUniformMatrix2dv(program, loc, size, 0, (GLdouble*) buf); break;
		case GL_DOUBLE_MAT3:   glProgramUniformMatrix3dv(program, loc, size, 0, (GLdouble*) buf); break;
		case GL_DOUBLE_MAT4:   glProgramUniformMatrix4dv(program, loc, size, 0, (GLdouble*) buf); break;
		case GL_DOUBLE_MAT2x3: glProgramUniformMatrix2x3dv(program, loc, size, 0, (GLdouble*) buf); break;
		case GL_DOUBLE_MAT3x2: glProgramUniformMatrix3x2dv(program, loc, size, 0, (GLdouble*) buf); break;
		case GL_DOUBLE_MAT2x4: glProgramUniformMatrix2x4dv(program, loc, size, 0, (GLdouble*) buf); break;
		case GL_DOUBLE_MAT4x2: glProgramUniformMatrix4x2dv(program, loc, size, 0, (GLdouble*) buf); break;
		case GL_DOUBLE_MAT3x4: glProgramUniformMatrix3x4dv(program, loc, size, 0, (GLdouble*) buf); break;
		case GL_DOUBLE_MAT4x3: glProgramUniformMatrix4x3dv(program, loc, size, 0, (GLdouble*) buf); break;
		default: croak("Unimplemented type %d for uniform %s", type, name);
		}
	}
	#endif
	Inline_Stack_Void;
}

#endif
/* end version guard for shaders */
