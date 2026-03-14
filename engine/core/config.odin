package core

// ----------------------------------------------------------------------------
// Compile-time feature flags
//
// Defaults here represent the dev/debug experience.
// Pass -define:FLAG=false to override, or let build.sh manage it via build.conf.
//
// NOTE: This file is an interim solution. These flags should eventually be
// driven by the module manifest system and metaprogram. See Obsidian:
//   modulus/roadmap/Build Config and Metaprogram.md
// ----------------------------------------------------------------------------

// Controls verbose debug/info logging. Stripped entirely in release.
// engine_log calls compile to nothing when false.
MODULUS_DEBUG :: #config(MODULUS_DEBUG, true)

// Controls hot-reload: file watcher, module reload on change.
// Stripped entirely in release — no watcher, no reload overhead.
MODULUS_HOT_RELOAD :: #config(MODULUS_HOT_RELOAD, true)
