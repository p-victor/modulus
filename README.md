# modulus

A high-performance, ultra-modular engine runtime written in Odin. The runtime is a pure loader — everything runs as a dynamically loaded module.

## Philosophy

- The runtime loads one **app module** at startup. That module owns everything: game, editor, server, tools.
- Modules are shared libraries (`.so` / `.dll`) with a defined ABI
- no engine coupling.
- Hot-reload is a first-class dev feature, stripped entirely in release builds.
- All performance-sensitive paths are compile-time gated. Release builds are uncompromising.

## Requirements

- [Odin](https://odin-lang.org/) compiler in `PATH`
- Linux (Windows cross-compilation supported, native Windows in progress)

## Build

```sh
make build        # debug build (hot-reload, logging enabled)
make release      # release build (all dev features stripped, -o:aggressive)
make rebuild      # clean + debug build
```

## Run

```sh
make run                    # run default module from build.conf
make run MODULE=my_app      # run a specific module
make run-release            # release build then run
```

## Project structure

```
engine/
  core/         ABI types, feature flags, logging interface
  host/         Module loader, runtime loop
  platform/     OS abstractions (dynamic libraries, file watcher)
modules/
  test_module/  Reference module implementation
scripts/        build.sh, run.sh, clean.sh
build.conf      Default build flags and module name
main.odin       Entry point — calls host.run()
```

## Writing a module

A module is any shared library that exports `modulus_get_module_api`:

```odin
package my_module

import core "mod:engine/core"

module_api := core.Module_API{
    name    = "my_module",
    version = 1,
    init     = proc(ctx: ^core.Engine_Context) -> bool { return true },
    update   = proc(ctx: ^core.Engine_Context, dt: f64) {},
    shutdown = proc(ctx: ^core.Engine_Context) {},
}

@(export)
modulus_get_module_api :: proc() -> ^core.Module_API {
    return &module_api
}
```

Build it as a DLL and pass the path to the runtime:

```sh
odin build modules/my_module -build-mode:dll -collection:mod=. -out:build/linux_amd64/modules/my_module.so
./build/linux_amd64/bin/modulus ./build/linux_amd64/modules/my_module.so
```

## Build flags (`build.conf`)

| Flag | Default | Effect |
|------|---------|--------|
| `MODULUS_DEBUG` | `true` | Enables verbose logging. Stripped in release. |
| `MODULUS_HOT_RELOAD` | `true` | Enables file watcher and live module reload. Stripped in release. |
| `MODULE` | `test_module` | Default module name for `make run`. |

Override per-invocation without editing the file:

```sh
MODULUS_HOT_RELOAD=false make build
make run MODULE=editor
```

Release mode forces all feature flags off regardless of `build.conf`.
