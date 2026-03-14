package host

import "core:fmt"
import "core:os"
import posix "core:sys/posix"
import "core:time"
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

// _make_ctx constructs the Engine_Context wired to the package-level logger.
@(private)
_make_ctx :: proc() -> core.Engine_Context {
	return core.Engine_Context{
		frame_index = 0,
		log         = proc(level: core.Log_Level, tag: string, msg: string) {
			core.logger_log(&_logger, level, tag, msg)
		},
	}
}

// _resolve_module_path returns the module path from the CLI arg.
// The runtime has no default — the caller (run script / user) is always responsible for providing one.
@(private)
_resolve_module_path :: proc() -> (path: string, ok: bool) {
	if len(os.args) > 1 {
		return os.args[1], true
	}

	fmt.eprintln("usage: modulus <module_path>")
	return "", false
}

// _setup_signals registers the SIGINT handler for graceful shutdown.
@(private)
_setup_signals :: proc() {
	action := posix.sigaction_t{}
	action.sa_handler = _sigint_handler
	posix.sigaction(posix.Signal.SIGINT, &action, nil)
}

// _run_cold is the release loop — no watcher, no reload, nothing but the frame.
@(private)
_run_cold :: proc() {
	_logger = core.make_logger()
	context.logger = _logger.impl // set once — logger_log reads context.logger without reassigning it

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

	_setup_signals()

	FRAME_DURATION :: time.Second / 60
	tick := time.tick_now()

	for _running {
		ctx.frame_index += 1

		now := time.tick_now()
		dt := time.duration_seconds(time.tick_diff(tick, now))
		tick = now

		if mod.api != nil {
			mod.api.update(&ctx, dt)
		}

		elapsed := time.tick_diff(tick, time.tick_now())
		remaining := FRAME_DURATION - elapsed
		if remaining > 0 {
			time.sleep(remaining)
		}
	}

	core.engine_log(&ctx, .Info, "engine", "shutting down")
}
