package host

// TEMP(metaprogram): this entire file is interim scaffolding.
// The manifest reader, dependency graph, and topological sort are replaced by a
// compile-time generated slot array when the metaprogram lands.
// See: modulus/roadmap/Hardcoded Temporaries.md and modulus/roadmap/Module Manifest v1.md

import "base:runtime"
import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"
import core "mod:engine/core"

// _Manifest is the parsed content of a <module>.json file.
// Engine-internal only — modules never import or see this type.
@(private)
_Manifest :: struct {
	name:       string,
	version:    int,
	depends_on: []string,
	provides:   []string,
}

// _load_manifest reads <so_path_without_ext>.json and parses it.
// Returns false cleanly if the file doesn't exist — no manifest means no deps.
// TEMP(metaprogram): build-time manifest parsing eliminates all runtime file I/O here.
@(private)
_load_manifest :: proc(so_path: string) -> (m: _Manifest, ok: bool) {
	context.allocator = runtime.default_allocator()

	ext  := filepath.ext(so_path)
	base := so_path[:len(so_path) - len(ext)]

	manifest_path := strings.concatenate({base, ".json"})
	defer delete(manifest_path)

	data, read_err := os.read_entire_file_from_path(manifest_path, runtime.default_allocator())
	if read_err != os.ERROR_NONE do return {}, false
	defer delete(data)

	if err := json.unmarshal(data, &m, allocator = runtime.default_allocator()); err != nil {
		return {}, false
	}
	return m, true
}

@(private)
_free_manifest :: proc(m: ^_Manifest) {
	alloc := runtime.default_allocator()
	delete(m.name, alloc)
	for s in m.depends_on { delete(s, alloc) }
	delete(m.depends_on, alloc)
	for s in m.provides { delete(s, alloc) }
	delete(m.provides, alloc)
	m^ = {}
}

// resolve_load_order returns a new slice of paths reordered so each module loads
// after all its declared dependencies. Paths with no manifest have no deps and no
// name — they cannot be depended on by name.
// Caller must delete the returned slice with runtime.default_allocator().
// Returns nil, false if a declared dep is absent from the loaded set or a cycle exists.
// TEMP(metaprogram): eliminated entirely — slot order statically generated at build time.
resolve_load_order :: proc(paths: []string, ctx: ^core.Engine_Context) -> (result: []string, ok: bool) {
	context.allocator = runtime.default_allocator()

	n := len(paths)
	if n <= 1 {
		out := make([]string, n)
		copy(out, paths)
		return out, true
	}

	// TEMP(metaprogram): runtime manifest parsing — replaced by build-time manifest reading.
	manifests    := make([]_Manifest, n)
	has_manifest := make([]bool, n)
	defer {
		for i in 0..<n { if has_manifest[i] { _free_manifest(&manifests[i]) } }
		delete(manifests)
		delete(has_manifest)
	}

	name_to_idx := make(map[string]int)
	defer delete(name_to_idx)

	for i in 0..<n {
		m, m_ok := _load_manifest(paths[i])
		if m_ok {
			manifests[i]    = m
			has_manifest[i] = true
			if m.name != "" { name_to_idx[m.name] = i }
		}
	}

	// TEMP(metaprogram): dependency graph built at runtime — pre-computed at build time.
	in_degree := make([]int, n)
	adj       := make([][dynamic]int, n)
	defer {
		for i in 0..<n { delete(adj[i]) }
		delete(adj)
		delete(in_degree)
	}

	for i in 0..<n {
		if !has_manifest[i] do continue
		for dep_name in manifests[i].depends_on {
			dep_idx, found := name_to_idx[dep_name]
			if !found {
				core.engine_error(ctx, "manifest", fmt.tprintf(
					"'%s' depends on '%s' which is not in the loaded set",
					manifests[i].name, dep_name,
				))
				return nil, false
			}
			append(&adj[dep_idx], i)
			in_degree[i] += 1
		}
	}

	// TEMP(metaprogram): Kahn's algorithm — slot order statically determined at build time.
	queue := make([dynamic]int, 0, n)
	defer delete(queue)
	for i in 0..<n { if in_degree[i] == 0 { append(&queue, i) } }

	result_dyn := make([dynamic]string, 0, n)
	head := 0
	for head < len(queue) {
		curr := queue[head]; head += 1
		append(&result_dyn, paths[curr])
		for neighbor in adj[curr] {
			in_degree[neighbor] -= 1
			if in_degree[neighbor] == 0 { append(&queue, neighbor) }
		}
	}

	if len(result_dyn) < n {
		core.engine_error(ctx, "manifest", "dependency cycle detected — cannot determine load order")
		delete(result_dyn)
		return nil, false
	}

	return result_dyn[:], true
}
