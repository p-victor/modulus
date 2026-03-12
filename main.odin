package main

import "core:fmt"
import core "mod:engine/core"
import host "mod:engine/host"
import platform "mod:engine/platform"

default_log :: proc(msg: cstring) {
	fmt.printf("[modulus] %s\n", msg)
}

main :: proc() {
	ctx := core.Engine_Context{
		frame_index = 0,
		log = default_log,
	}

	module_path: cstring
	when ODIN_OS == .Linux {
		module_path = "./build/linux_amd64/modules/test_module.so"
	} else when ODIN_OS == .Windows {
		module_path = "./build/windows_amd64/modules/test_module.dll"
	} else {
		default_log("unsupported platform")
		return
	}

	mods := host.discover_modules(module_dir)
    host.load_modules(mods, &ctx)

    for {
        host.update_modules(mods, &ctx, dt)
    }

	ctx.log("starting modulus")

	for {
		ctx.frame_index += 1

		if host.reload_module(&mod, &ctx) {
			mod.api.update(&ctx, 1.0 / 60.0)
		} else {
			ctx.log("reload failed")
		}

		platform.sleep_ms(1000)
	}
}