package test_module

import "core:fmt"
import core "mod:engine/core"

module_init :: proc(ctx: ^core.Engine_Context) -> bool {
	ctx.log("test_module.init")
	return true
}

module_shutdown :: proc(ctx: ^core.Engine_Context) {
	ctx.log("test_module.shutdown")
}

module_update :: proc(ctx: ^core.Engine_Context, dt: f64) {
	fmt.printf("test_module.update | frame=%v | dt=%v\n", ctx.frame_index, dt)
}

module_api := core.Module_API{
	name     = "test_module",
	version  = 1,
	init     = module_init,
	shutdown = module_shutdown,
	update   = module_update,
}

@(export)
modulus_get_module_api :: proc() -> ^core.Module_API {
	return &module_api
}