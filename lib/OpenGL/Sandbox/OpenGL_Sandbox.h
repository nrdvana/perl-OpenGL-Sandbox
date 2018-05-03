#ifndef OpenGL_Sandbox_H
#define OpenGL_Sandbox_H

#define IS_SCALAR_REF(s) (SvROK(s) && SvPOK(SvRV(s)))
#define SCALAR_REF_DATA(obj) (IS_SCALAR_REF(obj)? (void*)SvPVX(SvRV(obj)) : (void*)0)
#define SCALAR_REF_DATA_OR_CROAK(obj) (IS_SCALAR_REF(obj)? (void*)SvPVX(SvRV(obj)) : (croak("Expected scalar ref"), (void*)0))
#define SCALAR_REF_LEN(obj) (IS_SCALAR_REF(obj)? SvCUR(SvRV(obj)) : 0)

#endif