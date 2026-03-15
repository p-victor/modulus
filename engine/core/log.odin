package core

import "core:log"
import "base:intrinsics"

Log_Level :: enum {
	Debug,
	Info,
	Warn,
	Error,
}

Log_Proc :: #type proc(level: Log_Level, tag: string, msg: string)

// Zero-cost in release: force-inlined and body compiled out when MODULUS_DEBUG=false.
engine_log :: #force_inline proc(ctx: ^Engine_Context, level: Log_Level, tag: string, msg: string) {
	when MODULUS_DEBUG {
		ctx.log(level, tag, msg)
	}
}

// Always present in all builds — use for genuine errors that must be visible in release.
engine_error :: #force_inline proc(ctx: ^Engine_Context, tag: string, msg: string) {
	ctx.log(.Error, tag, msg)
}

// Zero-cost in release: force-inlined and body compiled out when both flags are false.
// Active in debug (MODULUS_DEBUG) and safe (MODULUS_SAFE) builds.
// Logs the failure via engine_error then traps — debugger catches it, no stack trace noise.
engine_assert :: #force_inline proc(ctx: ^Engine_Context, cond: bool, tag: string, msg: string) {
	when MODULUS_DEBUG || MODULUS_SAFE {
		if !cond {
			engine_error(ctx, tag, msg)
			intrinsics.trap()
		}
	}
}

// Logger wraps core:log. Holds a min_level filter and the backend log.Logger.
// The backend handles formatting, color, and output — we map our levels to core:log levels.
Logger :: struct {
	min_level: Log_Level,
	impl:      log.Logger,
}

make_logger :: proc(min_level := Log_Level.Debug) -> Logger {
	// Level and terminal color only — no source location since our call site
	// is always logger_log, which is not useful location info.
	impl := log.create_console_logger(_to_core_level(min_level), {.Level, .Terminal_Color})
	return Logger{min_level = min_level, impl = impl}
}

logger_log :: proc(l: ^Logger, level: Log_Level, tag: string, msg: string) {
	if level < l.min_level do return

	switch level {
	case .Debug: log.debugf("[%s] %s", tag, msg)
	case .Info:  log.infof("[%s] %s", tag, msg)
	case .Warn:  log.warnf("[%s] %s", tag, msg)
	case .Error: log.errorf("[%s] %s", tag, msg)
	}
}

// _to_core_level maps our ABI-stable Log_Level to Odin's core:log.Level.
// These look identical now but must remain separate: Log_Level is part of the module ABI
// and will diverge (Trace, Critical, etc.). Modules must not depend on core:log directly.
@(private)
_to_core_level :: proc(level: Log_Level) -> log.Level {
	switch level {
	case .Debug: return .Debug
	case .Info:  return .Info
	case .Warn:  return .Warning
	case .Error: return .Error
	}
	return .Debug
}
