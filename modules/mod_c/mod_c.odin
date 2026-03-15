package mod_c

import core "mod:engine/core"

module_init :: proc(ctx: ^core.Engine_Context) -> bool {
	core.engine_log(ctx, .Info, "mod_c", "init")
	return true
}

module_shutdown :: proc(ctx: ^core.Engine_Context) {
	core.engine_log(ctx, .Info, "mod_c", "shutdown")
}

module_pre_reload :: proc(ctx: ^core.Engine_Context) {
	core.engine_log(ctx, .Info, "mod_c", "pre_reload")
}

module_post_reload :: proc(ctx: ^core.Engine_Context) {
	core.engine_log(ctx, .Info, "mod_c", "post_reload")
}

module_api := core.Module_API{
	name          = "mod_c",
	version       = 1,
	init          = module_init,
	shutdown      = module_shutdown,
	on_pre_reload  = module_pre_reload,
	on_post_reload = module_post_reload,
}

@(export)
modulus_get_module_api :: proc() -> ^core.Module_API {
	return &module_api
}
