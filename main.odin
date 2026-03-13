package main

import "core:fmt"
import posix "core:sys/posix"
import "core:time"
import core "mod:engine/core"
import host "mod:engine/host"

running: bool = true

sigint_handler :: proc "c" (sig: posix.Signal) {
	running = false
}

default_log :: proc(msg: string) {
	fmt.printf("[modulus] %s\n", msg)
}

main :: proc() {
	ctx := core.Engine_Context{
		frame_index = 0,
		log         = default_log,
	}

	module_path: string
	when ODIN_OS == .Linux {
		module_path = "./build/linux_amd64/modules/test_module.so"
	} else when ODIN_OS == .Windows {
		module_path = "./build/windows_amd64/modules/test_module.dll"
	} else {
		default_log("unsupported platform")
		return
	}

	mod := host.Loaded_Module{
		original_path = module_path,
	}

	ctx.log("starting modulus")

	if !host.load_module(&mod, &ctx) {
		ctx.log("initial module load failed")
		return
	}

	defer host.unload_module(&mod, &ctx)

	action := posix.sigaction_t{}
	action.sa_handler = sigint_handler

	posix.sigaction(posix.Signal.SIGINT, &action, nil)

	for running {
		ctx.frame_index += 1

		if mod.api != nil {
			mod.api.update(&ctx, 1.0 / 60.0)
		}

		time.sleep(time.Second)
	}
}