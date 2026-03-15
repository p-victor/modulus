package host

import "core:fmt"
import "core:mem"
import "core:os"
import posix "core:sys/posix"
import core "mod:engine/core"

@(private) _running: bool = true

// Package-level so the Engine_Context log proc (which cannot close over locals) can reference it.
@(private) _logger: core.Logger

@(private)
_sigint_handler :: proc "c" (sig: posix.Signal) {
	_running = false
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
		quit = &_running,
	}
}

// _resolve_module_path returns the module path from the CLI arg.
@(private)
_resolve_module_path :: proc() -> (path: string, ok: bool) {
	if len(os.args) > 1 {
		return os.args[1], true
	}
	fmt.eprintln("usage: modulus <module_path>")
	return "", false
}

// _setup_signals registers a default SIGINT handler that sets quit = true.
// Modules may install their own handler inside run() to override this.
@(private)
_setup_signals :: proc() {
	action := posix.sigaction_t{}
	action.sa_handler = _sigint_handler
	posix.sigaction(posix.Signal.SIGINT, &action, nil)
}

// _run_cold is the release path — loads the module, calls run, unloads.
// No frame loop, no watcher, no reload. The module owns all of that.
@(private)
_run_cold :: proc() {
	_logger = core.make_logger()
	context.logger = _logger.impl

	ctx := _make_ctx()

	module_path, ok := _resolve_module_path()
	if !ok do return

	mod := Loaded_Module{original_path = module_path}

	core.engine_log(&ctx, .Info, "engine", "starting modulus")

	if !load_module(&mod, &ctx) {
		core.engine_error(&ctx, "engine", "initial module load failed")
		return
	}

	defer unload_module(&mod, &ctx)

	context.allocator = mem.arena_allocator(&mod.arena)

	_setup_signals()

	if mod.api.run != nil {
		mod.api.run(&ctx)
	}

	core.engine_log(&ctx, .Info, "engine", "shutting down")
}
