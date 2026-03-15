package mod_d

import core "mod:engine/core"

module_init :: proc(ctx: ^core.Engine_Context) -> bool {
	core.engine_log(ctx, .Info, "mod_d", "init")
	return true
}

module_shutdown :: proc(ctx: ^core.Engine_Context) {
	core.engine_log(ctx, .Info, "mod_d", "shutdown")
}

module_api := core.Module_API{
	name     = "mod_d",
	version  = 1,
	init     = module_init,
	shutdown = module_shutdown,
}

@(export)
modulus_get_module_api :: proc() -> ^core.Module_API {
	return &module_api
}
