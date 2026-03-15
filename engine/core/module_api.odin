package core

// Engine_Context is the minimal handle the engine passes to modules.
// It carries only what the engine itself provides — logging and a quit signal.
// Everything else (timing, frame counters, input) belongs in the module or an addon.
Engine_Context :: struct {
	log:  Log_Proc,
	quit: ^bool, // engine sets true to request a clean stop (SIGINT or hot-reload)
}

Module_Run_Proc      :: #type proc(ctx: ^Engine_Context)
Module_Init_Proc     :: #type proc(ctx: ^Engine_Context) -> bool
Module_Shutdown_Proc :: #type proc(ctx: ^Engine_Context)

// Module_API is the contract between the engine and a module.
// run owns the application loop entirely — frame rate, sleep, event model, all of it.
// init/shutdown are optional lifecycle hooks called before/after run.
// nil run = one-shot module (init executes, then immediately shutdown).
Module_API :: struct {
	name:          cstring,
	version:       u32,
	memory_budget: uint,             // persistent arena size in bytes; 0 = engine default
	run:           Module_Run_Proc,  // nil = one-shot
	init:          Module_Init_Proc, // nil = no init
	shutdown:      Module_Shutdown_Proc, // nil = no cleanup
}

Get_Module_API_Proc :: #type proc() -> ^Module_API
