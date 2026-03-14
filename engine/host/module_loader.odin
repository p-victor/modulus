package host

import core "mod:engine/core"
import platform "mod:engine/platform"

Loaded_Module :: struct {
	original_path: string,
	lib:           platform.Library,
	api:           ^core.Module_API,
}

unload_module :: proc(m: ^Loaded_Module, ctx: ^core.Engine_Context) {
	if m.api != nil {
		m.api.shutdown(ctx)
		m.api = nil
	}

	platform.unload_library(&m.lib)
}

load_module :: proc(m: ^Loaded_Module, ctx: ^core.Engine_Context) -> bool {
	lib, ok := platform.load_library(m.original_path)
	if !ok {
		core.engine_error(ctx, "engine", "load_library failed")
		core.engine_error(ctx, "engine", platform.last_error())
		return false
	}

	symbol, found := platform.load_symbol(lib, "modulus_get_module_api")
	if !found {
		platform.unload_library(&lib)
		core.engine_error(ctx, "engine", "load_symbol failed")
		core.engine_error(ctx, "engine", platform.last_error())
		return false
	}

	get_api := cast(core.Get_Module_API_Proc)symbol
	api := get_api()
	if api == nil {
		platform.unload_library(&lib)
		core.engine_error(ctx, "engine", "module API was nil")
		return false
	}

	m.lib = lib
	m.api = api

	if !m.api.init(ctx) {
		unload_module(m, ctx)
		core.engine_error(ctx, "engine", "module init failed")
		return false
	}

	return true
}

reload_module :: proc(m: ^Loaded_Module, ctx: ^core.Engine_Context) -> bool {
	unload_module(m, ctx)
	return load_module(m, ctx)
}
