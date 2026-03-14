#+build linux
package platform

import "core:sys/linux"

// watch_file begins watching path for close-after-write events (fires when compiler finishes writing the .so).
// Uses inotify with O_NONBLOCK so poll_changed never blocks.
watch_file :: proc(path: string) -> (File_Watcher, bool) {
	fd, err := linux.inotify_init1({.NONBLOCK})
	if err != .NONE {
		return {}, false
	}

	// inotify_add_watch requires a null-terminated path; build one on the stack.
	path_buf: [512]byte
	copy(path_buf[:], path)
	path_buf[len(path)] = 0
	cpath := cstring(raw_data(path_buf[:]))

	wd, err2 := linux.inotify_add_watch(fd, cpath, {.CLOSE_WRITE})
	if err2 != .NONE {
		linux.close(fd)
		return {}, false
	}

	return File_Watcher{fd = int(fd), wd = int(wd), valid = true}, true
}

// poll_changed returns true if the watched file was written since the last call.
// Non-blocking: returns immediately with false when nothing has changed.
// Drains all pending events so the next call starts clean.
poll_changed :: proc(w: ^File_Watcher) -> bool {
	if !w.valid do return false

	buf: [256]u8
	n, err := linux.read(linux.Fd(w.fd), buf[:])
	if err == .EAGAIN || n <= 0 {
		return false
	}

	for {
		_, err2 := linux.read(linux.Fd(w.fd), buf[:])
		if err2 == .EAGAIN do break
	}

	return true
}

destroy_watcher :: proc(w: ^File_Watcher) {
	if !w.valid do return
	linux.close(linux.Fd(w.fd))
	w.valid = false
}
