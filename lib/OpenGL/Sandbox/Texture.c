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
/* This is our shortcut to bypass Moo from C */
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

void _load_rgb_square(HV *self, SV *mmap) {
	SV *sv;
	void *data= SCALAR_REF_DATA_OR_CROAK(mmap);
	int len= SCALAR_REF_LEN(mmap);
	int has_alpha= 0;
	int dim= _dimension_from_filesize(len, &has_alpha);
	int gl_fmt= has_alpha? GL_RGBA : GL_RGB;
	
	/* Bind texture, and load image data */
	glBindTexture(GL_TEXTURE_2D, _lazy_build_tx_id(self));
	glTexImage2D(GL_TEXTURE_2D, 0, gl_fmt, dim, dim, 0, gl_fmt, GL_UNSIGNED_BYTE, data);

	/* update attributes */
	if (!hv_store(self, "width",  5, sv=newSViv(dim), 0)) goto store_fail;
	if (!hv_store(self, "height", 6, sv=newSViv(dim), 0)) goto store_fail;
	if (!hv_store(self, "has_alpha", 9, sv=newSViv(has_alpha? 1 : 0), 0)) goto store_fail;
	return;
store_fail:
	if (sv) sv_2mortal(sv);
	croak("Can't store results in supplied hash");
}

void _load_rgb_rect_rescale(HV *self, int width, int height, int has_alpha, SV *mmap) {
	struct SwsContext *sws= NULL;
	SV *sv= NULL;
	void *data= SCALAR_REF_DATA_OR_CROAK(mmap);
	int len= SCALAR_REF_LEN(mmap);
	int gl_fmt= has_alpha? GL_RGBA : GL_RGB;
	int px_size= has_alpha? 4 : 3;
	int dim;
	const uint8_t *src_planes[4]= { data,0,0,0 };
	int src_stride[4]= { width*px_size,0,0,0 };
	uint8_t *dst_planes[4]= { 0,0,0,0 };
	int dst_stride[4]= { 0,0,0,0 };
	
	if (width * height * px_size != len)
		croak("Size of scalar ref disagrees with rectangle dimensions: %d * %d * %d != %d",
			width, height, px_size, len);
	
	/* calculate next power of two */
	dim= (width > height? width : height) - 1;
	dim |= dim >> 16;
	dim |= dim >> 8;
	dim |= dim >> 4;
	dim |= dim >> 2;
	dim |= dim >> 1;
	dim++;
	dst_stride[0]= dim * px_size;
	
	/* rescale to square */
	sws= sws_getCachedContext(sws, width, height, has_alpha? PIX_FMT_RGBA : PIX_FMT_RGB24,
		dim, dim, has_alpha? PIX_FMT_RGBA : PIX_FMT_RGB24,
		SWS_BICUBIC, NULL, NULL, NULL);
	if (!sws)
		croak("can't initialize resize context");
	Newx(dst_planes[0], dim*dim*px_size, uint8_t); // allocate dest buffer
	SAVEFREEPV(dst_planes[0]); /* auto mem cleanup */
	sws_scale(sws, src_planes, src_stride, 0, height, dst_planes, dst_stride);
	sws_freeContext(sws);
	
	/* Bind texture, and load image data */
	glBindTexture(GL_TEXTURE_2D, _lazy_build_tx_id(self));
	glTexImage2D(GL_TEXTURE_2D, 0, gl_fmt, dim, dim, 0, gl_fmt, GL_UNSIGNED_BYTE, dst_planes[0]);

	/* update attributes */
	if (!hv_store(self, "width",  5, sv=newSViv(dim), 0)) goto store_fail;
	if (!hv_store(self, "height", 6, sv=newSViv(dim), 0)) goto store_fail;
	if (!hv_store(self, "has_alpha", 9, sv=newSViv(has_alpha? 1 : 0), 0)) goto store_fail;
	return;
store_fail:
	if (sv) sv_2mortal(sv);
	croak("Can't store results in supplied hash");
}
