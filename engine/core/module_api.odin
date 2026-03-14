package core

Engine_Context :: struct {
	frame_index: u64,
	log:         Log_Proc,
}

Module_Init_Proc     :: #type proc(ctx: ^Engine_Context) -> bool
Module_Shutdown_Proc :: #type proc(ctx: ^Engine_Context)
Module_Update_Proc   :: #type proc(ctx: ^Engine_Context, dt: f64)

Module_API :: struct {
	name:     cstring,
	version:  u32,
	init:     Module_Init_Proc,
	shutdown: Module_Shutdown_Proc,
	update:   Module_Update_Proc,
}

Get_Module_API_Proc :: #type proc() -> ^Module_API