package platform

// File_Watcher watches a single file for modifications.
// Handles are opaque ints so the struct compiles on all platforms.
// Platform-specific implementations provide watch_file, poll_changed, destroy_watcher.
File_Watcher :: struct {
	fd:    int, // platform watch handle (inotify fd on Linux)
	wd:    int, // watch descriptor
	valid: bool,
}
