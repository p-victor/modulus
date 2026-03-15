#+build linux
package platform

import "core:path/filepath"
import "core:sys/linux"

// watch_file begins watching path for write events.
// Watches the parent directory rather than the file inode so that both
// in-place writes (CLOSE_WRITE) and linker-style temp+rename (MOVED_TO)
// are detected. The target basename is stored so poll_changed only fires
// for the file we care about.
watch_file :: proc(path: string) -> (File_Watcher, bool) {
	fd, err := linux.inotify_init1({.NONBLOCK})
	if err != .NONE {
		return {}, false
	}

	dir := filepath.dir(path)
	dir_buf: [512]byte
	copy(dir_buf[:], dir)
	dir_buf[len(dir)] = 0

	wd, err2 := linux.inotify_add_watch(fd, cstring(raw_data(dir_buf[:])), {.CLOSE_WRITE, .MOVED_TO})
	if err2 != .NONE {
		linux.close(fd)
		return {}, false
	}

	w := File_Watcher{fd = int(fd), wd = int(wd), valid = true}
	base := filepath.base(path)
	w.nlen = min(len(base), 255)
	copy(w.name[:], base[:w.nlen])

	return w, true
}

// poll_changed returns true if the watched file was written since the last call.
// Non-blocking: returns immediately with false when nothing has changed.
// Drains all pending events so the next call starts clean.
poll_changed :: proc(w: ^File_Watcher) -> bool {
	if !w.valid do return false

	buf: [4096]u8
	n, err := linux.read(linux.Fd(w.fd), buf[:])
	if err == .EAGAIN || n <= 0 {
		return false
	}

	found := false
	event_size := size_of(linux.Inotify_Event)
	i := 0
	for i + event_size <= int(n) {
		ev := (^linux.Inotify_Event)(raw_data(buf[i:]))
		if ev.len > 0 && int(ev.len) > w.nlen {
			name := raw_data(buf[i + event_size:])
			match := true
			for j in 0..<w.nlen {
				if name[j] != w.name[j] {
					match = false
					break
				}
			}
			if match && name[w.nlen] == 0 {
				found = true
			}
		}
		i += event_size + int(ev.len)
	}

	// Drain any remaining events.
	for {
		_, err2 := linux.read(linux.Fd(w.fd), buf[:])
		if err2 == .EAGAIN do break
	}

	return found
}

destroy_watcher :: proc(w: ^File_Watcher) {
	if !w.valid do return
	linux.close(linux.Fd(w.fd))
	w.valid = false
}
