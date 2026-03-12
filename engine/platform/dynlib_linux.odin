package platform

import "core:c"
import "core:fmt"

foreign import libc "system:c"
foreign import dl   "system:dl"

foreign libc {
	usleep :: proc(usec: c.uint) -> c.int ---
}

foreign dl {
	dlopen  :: proc(filename: cstring, flags: c.int) -> rawptr ---
	dlsym   :: proc(handle: rawptr, symbol: cstring) -> rawptr ---
	dlclose :: proc(handle: rawptr) -> c.int ---
	dlerror :: proc() -> cstring ---
}

RTLD_LOCAL :: 0
RTLD_NOW   :: 2

load_library :: proc(path: cstring) -> (Library, bool) {
	lib := dlopen(path, RTLD_NOW | RTLD_LOCAL)
	if lib == nil {
		err := dlerror()
		if err != nil {
			fmt.printf("[platform/linux] dlopen failed: %s\n", err)
		} else {
			fmt.println("[platform/linux] dlopen failed: unknown error")
		}
		return Library{}, false
	}

	return Library{handle = lib}, true
}

unload_library :: proc(lib: ^Library) {
	if lib.handle == nil {
		return
	}

	_ = dlclose(lib.handle)
	lib.handle = nil
}

load_symbol :: proc(lib: Library, name: cstring) -> rawptr {
	if lib.handle == nil {
		return nil
	}

	sym := dlsym(lib.handle, name)
	if sym == nil {
		err := dlerror()
		if err != nil {
			fmt.printf("[platform/linux] dlsym failed: %s\n", err)
		} else {
			fmt.println("[platform/linux] dlsym failed: unknown error")
		}
	}

	return sym
}

sleep_ms :: proc(ms: u32) {
	_ = usleep(c.uint(ms * 1000))
}

shared_lib_extension :: proc() -> cstring {
	return ".so"
}