package mod_a

import "core:time"
import core "mod:engine/core"

module_init :: proc(ctx: ^core.Engine_Context) -> bool {
	core.engine_log(ctx, .Info, "mod_a", "init")
	return true
}

module_shutdown :: proc(ctx: ^core.Engine_Context) {
	core.engine_log(ctx, .Info, "mod_a", "shutdown")
}

module_pre_reload :: proc(ctx: ^core.Engine_Context) {
	core.engine_log(ctx, .Info, "mod_a", "pre_reload")
}

module_post_reload :: proc(ctx: ^core.Engine_Context) {
	core.engine_log(ctx, .Info, "mod_a", "post_reload")
}

module_run :: proc(ctx: ^core.Engine_Context) {
	core.engine_log(ctx, .Info, "mod_a", "run — waiting for quit or reload")
	for !ctx.quit^ {
		time.sleep(100 * time.Millisecond)
	}
}

module_api := core.Module_API{
	name          = "mod_a",
	version       = 1,
	run           = module_run,
	init          = module_init,
	shutdown      = module_shutdown,
	on_pre_reload  = module_pre_reload,
	on_post_reload = module_post_reload,
}

@(export)
modulus_get_module_api :: proc() -> ^core.Module_API {
	return &module_api
}
