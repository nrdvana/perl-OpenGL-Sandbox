#ifndef OpenGL_Sandbox_H
#define OpenGL_Sandbox_H

#define IS_MMAP_OBJ(s) (sv_isa((s), "OpenGL::Sandbox::MMap"))
#define MMAP_OBJ_PTR(obj) (IS_MMAP_OBJ(obj)? (void*)SvPVX(SvRV(obj)) : (void*)0)
#define MMAP_OBJ_PTR_OR_CROAK(obj) (IS_MMAP_OBJ(obj)? (void*)SvPVX(SvRV(obj)) : (croak("Expected MMap object"), (void*)0))
#define MMAP_OBJ_LEN(obj) (IS_MMAP_OBJ(obj)? SvCUR(SvRV(obj)) : 0)

#endif