package main

import "core:fmt"
import posix "core:sys/posix"
import "core:time"
import core "mod:engine/core"
import host "mod:engine/host"

running: bool = true

// Package-level logger so the log proc (which can't close over locals) can reference it.
engine_logger: core.Logger

sigint_handler :: proc "c" (sig: posix.Signal) {
	running = false
}

run :: proc() {
	ctx := core.Engine_Context{
		frame_index = 0,
		log         = proc(level: core.Log_Level, tag: string, msg: string) {
			core.logger_log(&engine_logger, level, tag, msg)
		},
	}

	module_path: string
	when ODIN_OS == .Linux {
		module_path = "./build/linux_amd64/modules/test_module.so"
	} else when ODIN_OS == .Windows {
		module_path = "./build/windows_amd64/modules/test_module.dll"
	} else {
		fmt.println("unsupported platform")
		return
	}

	mod := host.Loaded_Module{original_path = module_path}

	core.engine_log(&ctx, .Info, "engine", "starting modulus")

	if !host.load_module(&mod, &ctx) {
		core.engine_error(&ctx, "engine", "initial module load failed")
		return
	}

	defer host.unload_module(&mod, &ctx)

	action := posix.sigaction_t{}
	action.sa_handler = sigint_handler
	posix.sigaction(posix.Signal.SIGINT, &action, nil)

	FRAME_DURATION :: time.Second / 60

	tick := time.tick_now()

	for running {
		ctx.frame_index += 1

		now := time.tick_now()
		dt := time.duration_seconds(time.tick_diff(tick, now))
		tick = now

		if mod.api != nil {
			mod.api.update(&ctx, dt)
		}

		elapsed := time.tick_diff(tick, time.tick_now())
		remaining := FRAME_DURATION - elapsed
		if remaining > 0 {
			time.sleep(remaining)
		}
	}

	core.engine_log(&ctx, .Info, "engine", "shutting down")
}

main :: proc() {
	engine_logger = core.make_logger()
	run()
}
