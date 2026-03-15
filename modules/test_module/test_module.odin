package test_module

import "core:fmt"
import "core:time"
import core "mod:engine/core"

module_init :: proc(ctx: ^core.Engine_Context) -> bool {
	core.engine_log(ctx, .Info, "test_module", "init")
	return true
}

module_shutdown :: proc(ctx: ^core.Engine_Context) {
	core.engine_log(ctx, .Info, "test_module", "shutdown")
}

module_run :: proc(ctx: ^core.Engine_Context) {
	frame: u64 = 0
	tick := time.tick_now()

	for !ctx.quit^ {
		frame += 1

		now := time.tick_now()
		dt := time.duration_seconds(time.tick_diff(tick, now))
		tick = now

		core.engine_log(ctx, .Debug, "test_module", fmt.tprintf("frame=%v dt=%.4f", frame, dt))

		time.sleep(time.Second / 60)
	}
}

module_api := core.Module_API{
	name          = "test_module",
	version       = 1,
	memory_budget = 0,
	run           = module_run,
	init          = module_init,
	shutdown      = module_shutdown,
}

@(export)
modulus_get_module_api :: proc() -> ^core.Module_API {
	return &module_api
}
