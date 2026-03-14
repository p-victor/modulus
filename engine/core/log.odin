package core

import "core:fmt"

// Defaults to true. Pass -define:MODULUS_DEBUG=false to strip all logging in release.
MODULUS_DEBUG :: #config(MODULUS_DEBUG, true)

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

Logger :: struct {
	min_level: Log_Level,
	color:     bool,
}

make_logger :: proc(min_level := Log_Level.Debug, color := true) -> Logger {
	return Logger{min_level = min_level, color = color}
}

@(private)
_level_str := [Log_Level]string{
	.Debug = "DEBUG",
	.Info  = "INFO ",
	.Warn  = "WARN ",
	.Error = "ERROR",
}

@(private)
_level_color := [Log_Level]string{
	.Debug = "\x1b[36m",
	.Info  = "\x1b[37m",
	.Warn  = "\x1b[33m",
	.Error = "\x1b[31m",
}

RESET :: "\x1b[0m"

logger_log :: proc(l: ^Logger, level: Log_Level, tag: string, msg: string) {
	if level < l.min_level do return

	if l.color {
		fmt.printf("%s[%s]%s [%s] %s\n", _level_color[level], _level_str[level], RESET, tag, msg)
	} else {
		fmt.printf("[%s] [%s] %s\n", _level_str[level], tag, msg)
	}
}
