#+build windows
package platform

// Windows file watching stubs — not yet implemented.
// Future: use ReadDirectoryChangesW or FindFirstChangeNotification.

watch_file :: proc(path: string) -> (File_Watcher, bool) {
	return {}, false
}

poll_changed :: proc(w: ^File_Watcher) -> bool {
	return false
}

destroy_watcher :: proc(w: ^File_Watcher) {
}
