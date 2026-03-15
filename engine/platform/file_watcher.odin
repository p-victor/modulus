package platform

// File_Watcher watches a single file for modifications.
// All fields are plain value types so the struct compiles on all platforms.
// Platform-specific implementations provide watch_file, poll_changed, destroy_watcher.
File_Watcher :: struct {
	fd:    int,       // platform watch handle (inotify fd on Linux)
	wd:    int,       // watch descriptor
	valid: bool,
	name:  [256]u8,  // target filename (basename only, null-terminated)
	nlen:  int,      // byte length of name, excluding null
}
