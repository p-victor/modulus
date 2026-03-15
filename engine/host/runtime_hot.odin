package host

import "base:runtime"
import "core:fmt"
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

@(private)
_Watcher_Data :: struct {
	watchers: ^[MAX_MODULES]platform.File_Watcher,
	watching: ^[MAX_MODULES]bool,
	count:    int,
}

// _watcher_proc runs on a background thread while the primary module's run proc is blocking.
// Polls all active slot watchers every 100ms. When any .so changes, signals the module to
// stop and sets _reload_flag so the engine reloads all slots.
// NOTE: write to _should_quit from this thread is a benign race on x86 (single-byte store).
//       Acceptable for this debug-only path.
@(private)
_watcher_proc :: proc(data: rawptr) {
	d := (^_Watcher_Data)(data)
	for !_watcher_should_stop {
		for i in 0..<d.count {
			if d.watching[i] && platform.poll_changed(&d.watchers[i]) {
				_reload_flag = true
				_should_quit = true
				return
			}
		}
		time.sleep(100 * time.Millisecond)
	}
}

_run_hot :: proc() {
	_logger = core.make_logger()
	context.logger = _logger.impl

	module_paths, ok := _resolve_module_paths()
	if !ok do return

	ctx := _make_ctx()

	// TEMP(metaprogram): load order determined at runtime from manifests.
	// Metaprogram pre-computes this and generates a statically ordered slot array.
	ordered_paths, sort_ok := resolve_load_order(module_paths, &ctx)
	if !sort_ok do return
	defer delete(ordered_paths, runtime.default_allocator())

	module_count := min(len(ordered_paths), MAX_MODULES)

	slots:    [MAX_MODULES]Loaded_Module
	watchers: [MAX_MODULES]platform.File_Watcher
	watching: [MAX_MODULES]bool

	for i in 0..<module_count {
		slots[i].original_path = ordered_paths[i]
		watchers[i], watching[i] = platform.watch_file(ordered_paths[i])
	}
	defer {
		for i in 0..<module_count {
			platform.destroy_watcher(&watchers[i])
		}
	}

	_setup_signals()

	core.engine_log(&ctx, .Info, "engine", "starting modulus (hot)")
	for i in 0..<module_count {
		if watching[i] {
			core.engine_log(&ctx, .Info, "engine", fmt.tprintf("watching: %s", module_paths[i]))
		}
	}

	watcher_data := _Watcher_Data{
		watchers = &watchers,
		watching = &watching,
		count    = module_count,
	}

	any_watching := false
	for i in 0..<module_count {
		if watching[i] { any_watching = true; break }
	}

	is_reload := false

	for {
		_reload_flag = false

		// Load all slots. On partial failure, unload what succeeded and abort.
		loaded_count := 0
		for i in 0..<module_count {
			if !load_module(&slots[i], &ctx) {
				core.engine_error(&ctx, "engine", fmt.tprintf("failed to load: %s", module_paths[i]))
				for j := loaded_count - 1; j >= 0; j -= 1 {
					unload_module(&slots[j], &ctx)
				}
				break
			}
			loaded_count += 1
		}
		if loaded_count < module_count do break

		// TEMP(design): primary should be declared in manifest ("primary": true).
		// See: modulus/roadmap/Phase 2 - Module Manifest and Registry.md
		primary := 0
		for i in 0..<module_count {
			if slots[i].api.run != nil { primary = i; break }
		}

		context.allocator = mem.arena_allocator(&slots[primary].arena)

		if is_reload {
			for i in 0..<module_count {
				if slots[i].api.on_post_reload != nil {
					slots[i].api.on_post_reload(&ctx)
				}
			}
		}

		// Background thread watches all slots for .so changes while primary run blocks.
		watcher_thread: ^thread.Thread
		if any_watching {
			_watcher_should_stop = false
			watcher_thread = thread.create_and_start_with_data(&watcher_data, _watcher_proc)
		}

		if slots[primary].api.run != nil {
			slots[primary].api.run(&ctx)
		}

		// Signal watcher thread to stop and wait for it before unloading.
		if watcher_thread != nil {
			_watcher_should_stop = true
			thread.join(watcher_thread)
			thread.destroy(watcher_thread)
		}

		if _reload_flag {
			for i in 0..<module_count {
				if slots[i].api.on_pre_reload != nil {
					slots[i].api.on_pre_reload(&ctx)
				}
			}
		}

		// Unload all slots in reverse order.
		for i := module_count - 1; i >= 0; i -= 1 {
			unload_module(&slots[i], &ctx)
		}

		if !_reload_flag {
			break // quit signal (SIGINT), not a reload
		}

		// Reload: reset running flag and loop.
		is_reload = true
		_should_quit = false
		core.engine_log(&ctx, .Info, "engine", "module changed, reloading")
	}

	core.engine_log(&ctx, .Info, "engine", "shutting down")
}

} // when core.MODULUS_HOT_RELOAD
