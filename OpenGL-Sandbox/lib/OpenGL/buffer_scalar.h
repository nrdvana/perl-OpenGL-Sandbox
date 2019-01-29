#define BUFFER_SCALAR_READONLY 1
#define BUFFER_SCALAR_UTF8 2
typedef intptr_t buffer_scalar_callback_data[8];
typedef void (*buffer_scalar_free_fn)(SV *var, void *address, size_t length, buffer_scalar_callback_data callback_data);
extern SV* buffer_scalar_wrap(SV *target, void *address, size_t length, int flags,
	buffer_scalar_callback_data callback_data, buffer_scalar_free_fn destructor);
extern SV* buffer_scalar_unwrap(SV *target);
extern int buffer_scalar_iswrapped(SV *target);
