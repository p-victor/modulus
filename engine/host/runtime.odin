package host

import "base:runtime"
import "core:fmt"
import "core:mem"
import "core:os"
import posix "core:sys/posix"
import core "mod:engine/core"

// false = keep running, true = quit. Modules loop `for !ctx.quit^`.
// SIGINT and the hot-reload watcher both set this to true to stop the module's run proc.
@(private) _should_quit: bool = false

// Package-level so the Engine_Context log proc (which cannot close over locals) can reference it.
@(private) _logger: core.Logger

@(private)
_sigint_handler :: proc "c" (sig: posix.Signal) {
	_should_quit = true
}

// Compile-time dispatch — exactly one of _run_hot / _run_cold exists in any given build.
run :: proc() {
	when core.MODULUS_HOT_RELOAD {
		_run_hot()
	} else {
		_run_cold()
	}
}

// _make_ctx constructs the Engine_Context wired to the package-level logger and quit flag.
@(private)
_make_ctx :: proc() -> core.Engine_Context {
	return core.Engine_Context{
		log  = proc(level: core.Log_Level, tag: string, msg: string) {
			core.logger_log(&_logger, level, tag, msg)
		},
		quit = &_should_quit,
	}
}

// _resolve_module_paths returns all module paths from CLI args (os.args[1:]).
// Slot 0 is the primary module (run is called on it); subsequent slots are companions.
@(private)
_resolve_module_paths :: proc() -> (paths: []string, ok: bool) {
	if len(os.args) > 1 {
		return os.args[1:], true
	}
	fmt.eprintln("usage: modulus <module_path> [module_path ...]")
	return nil, false
}

// _setup_signals registers a default SIGINT handler that sets quit = true.
// Modules may install their own handler inside run() to override this.
@(private)
_setup_signals :: proc() {
	action := posix.sigaction_t{}
	action.sa_handler = _sigint_handler
	posix.sigaction(posix.Signal.SIGINT, &action, nil)
}

// _run_cold is the release/safe path — loads all modules, calls run on slot 0, unloads all.
// No watcher, no reload. Slot 0 is the primary; companions are init/shutdown only.
@(private)
_run_cold :: proc() {
	_logger = core.make_logger()
	context.logger = _logger.impl

	ctx := _make_ctx()

	module_paths, ok := _resolve_module_paths()
	if !ok do return

	// TEMP(metaprogram): load order determined at runtime from manifests.
	// Metaprogram pre-computes this and generates a statically ordered slot array.
	ordered_paths, sort_ok := resolve_load_order(module_paths, &ctx)
	if !sort_ok do return
	defer delete(ordered_paths, runtime.default_allocator())

	module_count := min(len(ordered_paths), MAX_MODULES)

	slots: [MAX_MODULES]Loaded_Module
	for i in 0..<module_count {
		slots[i].original_path = ordered_paths[i]
	}

	core.engine_log(&ctx, .Info, "engine", "starting modulus")

	loaded_count := 0
	for i in 0..<module_count {
		if !load_module(&slots[i], &ctx) {
			core.engine_error(&ctx, "engine", fmt.tprintf("failed to load: %s", module_paths[i]))
			for j := loaded_count - 1; j >= 0; j -= 1 {
				unload_module(&slots[j], &ctx)
			}
			return
		}
		loaded_count += 1
	}

	// TEMP(design): primary should be declared in manifest ("primary": true).
	// See: modulus/roadmap/Phase 2 - Module Manifest and Registry.md
	primary := 0
	for i in 0..<loaded_count {
		if slots[i].api.run != nil { primary = i; break }
	}

	context.allocator = mem.arena_allocator(&slots[primary].arena)

	_setup_signals()

	if slots[primary].api.run != nil {
		slots[primary].api.run(&ctx)
	}

	core.engine_log(&ctx, .Info, "engine", "shutting down")

	for i := loaded_count - 1; i >= 0; i -= 1 {
		unload_module(&slots[i], &ctx)
	}
}
