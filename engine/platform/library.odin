package platform

import "core:dynlib"

Library :: struct {
	impl:  dynlib.Library,
	valid: bool,
}

load_library :: proc(path: string) -> (Library, bool) {
	lib, ok := dynlib.load_library(path)
	if !ok {
		return Library{}, false
	}

	return Library{
		impl  = lib,
		valid = true,
	}, true
}

load_symbol :: proc(lib: Library, name: string) -> (rawptr, bool) {
	if !lib.valid {
		return nil, false
	}

	return dynlib.symbol_address(lib.impl, name)
}

unload_library :: proc(lib: ^Library) {
	if !lib.valid {
		return
	}

	dynlib.unload_library(lib.impl)
	lib.impl = dynlib.Library{}
	lib.valid = false
}

last_error :: proc() -> string {
	return dynlib.last_error()
}

shared_lib_extension :: proc() -> string {
	return "." + dynlib.LIBRARY_FILE_EXTENSION
}

library_is_valid :: proc(lib: Library) -> bool {
	return lib.valid
}