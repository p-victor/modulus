package host

import "core:mem"
import "base:runtime"
import core "mod:engine/core"
import platform "mod:engine/platform"

// TEMP(metaprogram): slot count derived from manifest at compile time.
MAX_MODULES :: 64

// TEMP(metaprogram): modules declare memory_budget in manifest; validated and wired at compile time.
@(private) DEFAULT_MODULE_ARENA_SIZE :: 4 * mem.Megabyte

Loaded_Module :: struct {
	original_path: string,
	lib:           platform.Library,
	api:           ^core.Module_API,
	arena:         mem.Arena,
}

unload_module :: proc(m: ^Loaded_Module, ctx: ^core.Engine_Context) {
	if m.api != nil {
		if m.api.shutdown != nil {
			m.api.shutdown(ctx)
		}
		m.api = nil
	}

	platform.unload_library(&m.lib)

	// Free arena backing memory. Must use the heap explicitly — same reason
	// as the alloc: context.allocator points to this arena, not the heap.
	delete(m.arena.data, runtime.default_allocator())
	m.arena = {}
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

	// Create the module's persistent arena. Sized by the module's declared
	// budget, falling back to the engine default.
	// Must use the heap explicitly — context.allocator may already point to
	// a dead arena from a previous load (e.g. during hot-reload).
	budget := api.memory_budget if api.memory_budget > 0 else DEFAULT_MODULE_ARENA_SIZE
	m.arena.data = make([]byte, budget, runtime.default_allocator())

	// Set context.allocator to the arena so that init (and all callees) use it.
	context.allocator = mem.arena_allocator(&m.arena)

	if m.api.init != nil && !m.api.init(ctx) {
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
