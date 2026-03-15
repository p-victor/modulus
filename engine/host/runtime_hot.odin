package host

import "core:mem"
import "core:thread"
import "core:time"
import core "mod:engine/core"
import platform "mod:engine/platform"

// _run_hot only exists when MODULUS_HOT_RELOAD=true.
// It does not appear in release binaries at all.
when core.MODULUS_HOT_RELOAD {

@(private) _reload_flag:         bool = false
@(private) _watcher_should_stop: bool = false

// _watcher_proc runs on a background thread while the module's run proc is blocking.
// Polls the file watcher every 100ms. When the .so changes, signals the module to stop
// by setting quit = true, then sets _reload_flag so the engine knows to reload rather
// than exit.
// NOTE: write to _running from this thread is a benign race on x86 (single-byte store).
//       Acceptable for this debug-only path.
@(private)
_watcher_proc :: proc(data: rawptr) {
	w := (^platform.File_Watcher)(data)
	for !_watcher_should_stop {
		if platform.poll_changed(w) {
			_reload_flag = true
			_running = false
			return
		}
		time.sleep(100 * time.Millisecond)
	}
}

_run_hot :: proc() {
	_logger = core.make_logger()
	context.logger = _logger.impl

	module_path, ok := _resolve_module_path()
	if !ok do return

	ctx := _make_ctx()

	watcher, watching := platform.watch_file(module_path)
	defer platform.destroy_watcher(&watcher)

	_setup_signals()

	core.engine_log(&ctx, .Info, "engine", "starting modulus (hot)")
	if watching {
		core.engine_log(&ctx, .Info, "engine", "watching for hot-reload")
	}

	mod := Loaded_Module{original_path = module_path}

	for {
		_reload_flag = false

		if !load_module(&mod, &ctx) {
			core.engine_error(&ctx, "engine", "module load failed")
			break
		}

		context.allocator = mem.arena_allocator(&mod.arena)

		// Background thread watches for .so changes while module's run proc blocks.
		watcher_thread: ^thread.Thread
		if watching {
			_watcher_should_stop = false
			watcher_thread = thread.create_and_start_with_data(&watcher, _watcher_proc)
		}

		if mod.api.run != nil {
			mod.api.run(&ctx)
		}

		// Signal watcher thread to stop and wait for it before unloading.
		if watcher_thread != nil {
			_watcher_should_stop = true
			thread.join(watcher_thread)
			thread.destroy(watcher_thread)
		}

		unload_module(&mod, &ctx)

		if !_reload_flag {
			break // quit signal (SIGINT), not a reload
		}

		// Reload: reset running flag and loop.
		_running = true
		core.engine_log(&ctx, .Info, "engine", "module changed, reloading")
	}

	core.engine_log(&ctx, .Info, "engine", "shutting down")
}

} // when core.MODULUS_HOT_RELOAD
