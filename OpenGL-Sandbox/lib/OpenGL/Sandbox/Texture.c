#include <GL/gl.h>
#include <libavutil/avutil.h>
#include <libavutil/pixfmt.h>
#include <libswscale/swscale.h>
#include "OpenGL_Sandbox.h"

/* This gets called by Moo */
int _build_tx_id(HV *self) {
	GLuint tx_id;
	glGenTextures(1, &tx_id);
	return tx_id;
}
/* This is our shortcut to bypass Moo from C.  The more correct thing to do would be set up a call
 * stack and call $self->_build_tx_id in case someone overrode it in a subclass. */
int _lazy_build_tx_id(HV *self) {
	SV **field_p= hv_fetch(self, "tx_id", 5, 1);
	GLuint tx_id;
	if (!field_p || !*field_p)
		croak("Can't store results in supplied hash");
	if (SvIOK(*field_p)) {
		tx_id= SvIV(*field_p);
	} else {
		tx_id= _build_tx_id(self);
		sv_setiv(*field_p, tx_id);
	}
	return tx_id;
}

void DESTROY(HV *self) {
	GLuint tx_id;
	SV **field= hv_fetch(self, "tx_id", 5, 0);
	if (field && *field && SvIOK(*field)) {
		tx_id= SvIV(*field);
		if (tx_id)
			glDeleteTextures(1, &tx_id);
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

/* Reading from perl hashes is annoying.  This simplified function only returns
 * non-NULL if the key existed and the value was defined.
 */
SV *_fetch_if_defined(HV *self, const char *field, int len) {
	SV **field_p= hv_fetch(self, field, len, 0);
	return (field_p && *field_p && SvOK(*field_p)) ? *field_p : NULL;
}

void _load_rgb_square(HV *self, SV *mmap, int is_bgr) {
	SV *sv;
	void *data= SCALAR_REF_DATA_OR_CROAK(mmap);
	const char *ver;
	int major, minor;
	SV *mipmap_p= _fetch_if_defined(self, "mipmap", 6);
	SV *wrap_s_p= _fetch_if_defined(self, "wrap_s", 6);
	SV *wrap_t_p= _fetch_if_defined(self, "wrap_t", 6);
	SV *min_filter_p= _fetch_if_defined(self, "min_filter", 10);
	SV *mag_filter_p= _fetch_if_defined(self, "mag_filter", 10);
	int len= SCALAR_REF_LEN(mmap);
	int has_alpha= 0;
	int dim= _dimension_from_filesize(len, &has_alpha);
	int gl_fmt= is_bgr? ( has_alpha? GL_BGRA : GL_BGR )
	                  : ( has_alpha? GL_RGBA : GL_RGB );
	int gl_internal_fmt= has_alpha? GL_RGBA : GL_RGB;
	
	/* use mipmaps if the user set it to true, or if the min_filter uses a mipmap,
	   and default in absence of any user prefs is true. */
	int with_mipmaps= mipmap_p? SvTRUE(mipmap_p)
		: !min_filter_p? 1
		: SvIV(min_filter_p) == GL_NEAREST || SvIV(min_filter_p) == GL_LINEAR ? 0
		: 1;
	
	ver= (const char *) glGetString(GL_VERSION);
	if (!ver) croak("Can't get GL_VERSION");
	
	/* Bind texture */
	glBindTexture(GL_TEXTURE_2D, _lazy_build_tx_id(self));
	
	if (with_mipmaps) {
		/* Mipmap strategy depends on version of GL.
		   Supposedly this GetString is more compatible than GetInteger(GL_VERSION_MAJOR)
		*/
		sscanf(ver, "%d.%d", &major, &minor);
		if (major < 3) {
			glTexParameteri(GL_TEXTURE_2D, GL_GENERATE_MIPMAP, GL_TRUE);
			if (mag_filter_p)
				glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, SvIV(mag_filter_p));
			if (min_filter_p)
				glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, SvIV(min_filter_p));
		}
	} else {
		warn("without mipmaps");
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

SV* _rescale_to_pow2_square(int width, int height, int has_alpha, int want_bgr, SV *sref) {
	struct SwsContext *sws= NULL;
	SV *ret= NULL;
	void *data= SCALAR_REF_DATA_OR_CROAK(sref);
	int len= SCALAR_REF_LEN(sref);
	int px_size= has_alpha? 4 : 3;
	int dim= _round_up_pow2(width > height? width : height);
	const uint8_t *src_planes[4]= { data,0,0,0 };
	int src_stride[4]= { width*px_size,0,0,0 };
	uint8_t *dst_planes[4]= { 0,0,0,0 };
	int dst_stride[4]= { dim*px_size,0,0,0 };
	
	if (width * height * px_size != len)
		croak("Size of scalar ref disagrees with rectangle dimensions: %d * %d * %d != %d",
			width, height, px_size, len);
	
	/* rescale to square */
	sws= sws_getCachedContext(sws, width, height, has_alpha? PIX_FMT_RGBA : PIX_FMT_RGB24,
		dim, dim, want_bgr? (has_alpha? PIX_FMT_BGRA : PIX_FMT_BGR24) : (has_alpha? PIX_FMT_RGBA : PIX_FMT_RGB24),
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

void _bind_tx(HV *self, ...) {
	int target= GL_TEXTURE_2D;
	Inline_Stack_Vars;
	if (Inline_Stack_Items > 1)
		target= SvIV(Inline_Stack_Item(1));
	glBindTexture(_lazy_build_tx_id(self), target);
	Inline_Stack_Void;
}

void _render(HV *self, ...) {
	SV *value, *w_sv= NULL, *h_sv= NULL, *def_w, *def_h;
	double x= 0, y= 0, z= 0, s= 0, t= 0, s_rep= 1, t_rep= 1;
	double w, h, scale= 1;
	int i, center= 0;
	const char *key;
	
	Inline_Stack_Vars;
	if (!(Inline_Stack_Items & 1))
		/* stack items includes $self, so an actual odd number is a logical even number */
		croak("Odd number of parameters passed to ->render");

	for (i= 1; i < Inline_Stack_Items-1; i+= 2) {
		key= SvPV_nolen(Inline_Stack_Item(i));
		value= Inline_Stack_Item(i+1);
		if (!SvOK(value)) continue; /* ignore anything that isn't defined */
		switch (*key) {
		case 'x': if (!key[1]) x= SvNV(value);
			else
		case 'y': if (!key[1]) y= SvNV(value);
			else
		case 'z': if (!key[1]) z= SvNV(value);
			else
		case 'w': if (!key[1]) w_sv= value;
			else
		case 'h': if (!key[1]) h_sv= value;
			else
		case 't': if (!key[1]) t= SvNV(value);
			else if (strcmp("t_rep", key) == 0) t_rep= SvNV(value);
			else
		case 's': if (!key[1]) s= SvNV(value);
			else if (strcmp("s_rep", key) == 0) s_rep= SvNV(value);
			else if (strcmp("scale", key) == 0) scale= SvNV(value);
			else
		case 'c': if (strcmp("center", key) == 0) center= SvTRUE(value);
			else
		default:
			croak("Invalid key '%s' in call to render()", key);
		}
	}
	/* width and height default to the src_width and src_height, or width, height.
	 * but, if one one dimension given, then use those defaults as an aspect ratio to calculate the other */
	if (w_sv && h_sv) {
		w= SvNV(w_sv);
		h= SvNV(h_sv);
	}
	else {
		def_w= _fetch_if_defined(self, "src_width", 9);
		if (!def_w) def_w= _fetch_if_defined(self, "width", 5);
		if (!def_w) croak("No width defined on texture");
		def_h= _fetch_if_defined(self, "src_height", 10);
		if (!def_h) def_h= _fetch_if_defined(self, "height", 6);
		if (!def_h) croak("No height defined on texture");
		/* depending which we have, multiply by aspect ratio to calculate the other */
		if (w_sv) {
			w= SvNV(w_sv);
			h= w * SvNV(def_h) / SvNV(def_w);
		}
		else if (h_sv) {
			h= SvNV(h_sv);
			w= h * SvNV(def_w) / SvNV(def_h);
		}
		else {
			w= SvNV(def_w);
			h= SvNV(def_h);
		}
	}
	/* If scaled, adjust w,h */
	w *= scale;
	h *= scale;
	/* If centered, then adjust the x and y */
	if (center) {
		x -= w * .5;
		y -= h * .5;
	}
	//printf("Rendering texture: x=%.5f y=%.5f w=%.5f h=%.5f s=%.5f t=%.5f s_rep=%.5f t_rep=%.5f\n",
	//	x, y, w, h, s, t, s_rep, t_rep);
	
	/* TODO: If texture is NonPowerOfTwo, then multiply the s_rep and t_rep values. */
	glBegin(GL_QUADS);
	glTexCoord2d(s, t);
	glVertex2d(x, y);
	glTexCoord2d(s+s_rep, t);
	glVertex2d(x+w, y);
	glTexCoord2d(s+s_rep, t+t_rep);
	glVertex2d(x+w, y+h);
	glTexCoord2d(s, t+t_rep);
	glVertex2d(x, y+h);
	glEnd();
	Inline_Stack_Void;
}
