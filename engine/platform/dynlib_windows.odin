package platform

foreign import kernel32 "system:kernel32.lib"

foreign kernel32 {
	LoadLibraryA   :: proc(file_name: cstring) -> rawptr ---
	FreeLibrary    :: proc(module: rawptr) -> i32 ---
	GetProcAddress :: proc(module: rawptr, proc_name: cstring) -> rawptr ---
	Sleep          :: proc(milliseconds: u32) ---
}

load_library :: proc(path: cstring) -> (Library, bool) {
	lib := LoadLibraryA(path)
	if lib == nil {
		return Library{}, false
	}
	return Library{handle = lib}, true
}

unload_library :: proc(lib: ^Library) {
	if lib.handle == nil {
		return
	}

	_ = FreeLibrary(lib.handle)
	lib.handle = nil
}

load_symbol :: proc(lib: Library, name: cstring) -> rawptr {
	if lib.handle == nil {
		return nil
	}
	return GetProcAddress(lib.handle, name)
}

sleep_ms :: proc(ms: u32) {
	Sleep(ms)
}

shared_lib_extension :: proc() -> cstring {
	return ".dll"
}