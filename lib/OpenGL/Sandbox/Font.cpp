#include <ftgl.h>
#include <GL/gl.h>
#include "OpenGL_Sandbox.h"

class TextureFont: private FTTextureFont {
	SV *mmap_obj;
public:
	/* Constructor takes one parameter of type OpenGL::Sandbox::MMap,
	 * and retains a reference to it until destroyed.
	 */
	TextureFont(SV *mmap):
		mmap_obj(mmap),
		FTTextureFont((const unsigned char*)MMAP_OBJ_PTR_OR_CROAK(mmap), MMAP_OBJ_LEN(mmap))
	{
		SvREFCNT_inc_void_NN(mmap_obj);
	}
	~TextureFont() {
		SvREFCNT_dec(mmap_obj);
	}

	/* I'd prefer to export the methods of the parent class directly, but
	 * can't figure out a way to get Inline::CPP to process the classes
	 * from the FTGL heders.
	 * So, just re-publish them with perl-friendly names.
	 */
	double ascender() { return Ascender(); }
	double descender() { return Descender(); }
	double advance(const char *text) { return Advance(text, -1); }
	
	void render_text(const char *text, int h_align, int v_align, double monospace) {
		FTPoint pos(0,0);
		
		float width= (monospace != 0.0f)? monospace * strlen(text) : this->Advance(text, -1);
		if (h_align == 3)
			pos.X(-width);
		else if (h_align == 2)
			pos.X(-0.5 * width);
		
		if (v_align == 4)
			pos.Y(-Ascender());
		else if (v_align == 1)
			pos.Y(Descender());
		else if (v_align == 3)
			pos.Y(-0.5 * Ascender());
		
		if (monospace != 0.0f) {
			while (*text) {
				float charWidth= Advance(text, 1);
				float xOfs= 0.5*(monospace - charWidth);
				Render(text, 1, pos+FTPoint(xOfs,0));
				pos.X(pos.X()+monospace);
				text++;//text= utf8_nextChar(text);
			}
		}
		else {
			Render(text, -1, pos);
		}
	}
	
	void render_xy_scale_text(double x, double y, double scale, const char *text, int h_align, int v_align, double monospace) {
		glPushMatrix();
		glTranslated(x, y, 0);
		if (scale) glScaled(scale, scale, 1);
		render_text(text, h_align, v_align, monospace);
		glPopMatrix();
	}
};
