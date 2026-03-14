package host

import core "mod:engine/core"
import platform "mod:engine/platform"
import "core:time"

// _run_hot only exists when MODULUS_HOT_RELOAD=true.
// It does not appear in release binaries at all.
when core.MODULUS_HOT_RELOAD {

_run_hot :: proc() {
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

	watcher, watching := platform.watch_file(module_path)
	defer platform.destroy_watcher(&watcher)
	if watching {
		core.engine_log(&ctx, .Info, "engine", "hot-reload watching module")
	}

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

		if watching && platform.poll_changed(&watcher) {
			core.engine_log(&ctx, .Info, "engine", "module changed, reloading")
			reload_module(&mod, &ctx)
		}

		elapsed := time.tick_diff(tick, time.tick_now())
		remaining := FRAME_DURATION - elapsed
		if remaining > 0 {
			time.sleep(remaining)
		}
	}

	core.engine_log(&ctx, .Info, "engine", "shutting down")
}

} // when core.MODULUS_HOT_RELOAD
