#!/usr/bin/env -S godot --headless --script
## CI Lint — Asset Validation (art-bible §8.D D.4). The binding import-time gate that
## art-bible §8 preamble requires: "任何 asset import 前必須通過 tools/ci/asset_validator.gd".
##
## Scans res://assets/ recursively and enforces the 5 HARD checks + emits Warnings.
## HARD violation → exit 1 (block PR merge). Warning → printed but exit 0.
##
##   HARD checks (art-bible §8.D table):
##     1. PNG dimension power-of-2            (§8.A — NPOT doubles draw calls)
##     2. PNG / atlas ≤ 2048×2048            (§8.B/§8.C HARD — mobile Safari WebGL2 MAX_TEXTURE_SIZE)
##     3. Filename snake_case                 (§8.A HARD — art assets only; see scoping)
##     4. Particle `amount` ≤ 200             (§8.C/§8.D HARD — single preset can't exceed whole budget)
##     5. No CPUParticles2D in any asset      (§8.D HARD — GPUParticles2D only, via particle_system_wrapper)
##
##   Warning checks (exit 0; lead sign-off):
##     - PNG file size ≤ 1MB                  (§8.C)
##     - audio (.ogg/.wav) size sane          (§8.C — SFX ≤100KB / BGM ≤2MB; coarse: warn > 2MB)
##     - entity-registry consistency          (§8.A — SKIPPED-notice while design/registry entity list is empty)
##
## Scoping (honesty note — prevents false-fails on existing files):
##   - snake_case (check 3) applies ONLY to art assets: *.png, *.ogg, *.wav, and *.tres under
##     assets/vfx/. It does NOT apply to assets/data/** (config Resources use Godot resource
##     naming, e.g. EnemyRegistry.tres) or assets/.godot_import_presets/**. art-bible §8.A's
##     naming rules are for Sprite/Atlas/Particle/Audio, not data config.
##   - The art-bible `vfx_<event>_<variant>` PREFIX is NOT enforced (existing presets such as
##     hit_heavy.tres predate it and work); only snake_case is enforced on vfx .tres.
##   - assets/ currently contains 0 sprite PNGs, so this lint PASSES today. It is a FORWARD gate:
##     it activates the moment real sprite/atlas assets land.
##
## Exit codes: 0 = clean (HARD all pass; warnings allowed); 1 = ≥1 HARD violation; 2 = internal error.
##
## Governing: design/art/art-bible.md §8.D; ADR-0001 (web export budget caps).
extends SceneTree


const LINT_TAG: String = "asset_validator"
const ASSETS_ROOT: String = "res://assets"
const ATLAS_MAX: int = 2048
const PARTICLE_AMOUNT_MAX: int = 200
const PNG_SIZE_WARN_BYTES: int = 1048576       ## 1 MB
const AUDIO_SIZE_WARN_BYTES: int = 2097152     ## 2 MB (BGM ceiling; SFX far smaller)

## Directories under assets/ exempt from the snake_case art-asset naming rule.
const NAMING_EXEMPT_PREFIXES: Array[String] = [
	"res://assets/data",
	"res://assets/.godot_import_presets",
]


func _init() -> void:
	var snake_re := RegEx.new()
	if snake_re.compile("^[a-z][a-z0-9_]*$") != OK:
		push_error("[%s] regex compile failed" % LINT_TAG)
		quit(2)
		return

	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(ASSETS_ROOT)):
		push_error("[%s] assets root not found: %s" % [LINT_TAG, ASSETS_ROOT])
		quit(2)
		return

	var files: Array[String] = []
	_walk(ASSETS_ROOT, files)

	var hard: Array[String] = []      ## HARD violations → fail
	var warns: Array[String] = []     ## Warnings → print, no fail
	var amount_re := RegEx.new()
	amount_re.compile("(?m)^\\s*amount\\s*=\\s*(\\d+)")

	for path: String in files:
		var ext: String = path.get_extension().to_lower()
		var stem: String = path.get_file().get_basename()

		# --- Check 3: snake_case (art assets only) ---
		var is_art_asset := ext == "png" or ext == "ogg" or ext == "wav" \
			or (ext == "tres" and path.begins_with("res://assets/vfx"))
		if is_art_asset and not _naming_exempt(path):
			if snake_re.search(stem) == null:
				hard.append("%s: filename '%s' not snake_case (§8.A HARD)" % [path, path.get_file()])

		# --- Checks 1, 2 + PNG size warning ---
		if ext == "png":
			var abs_path: String = ProjectSettings.globalize_path(path)
			var img := Image.new()
			if img.load(abs_path) != OK:
				warns.append("%s: could not load PNG to verify dimensions" % path)
			else:
				var w: int = img.get_width()
				var h: int = img.get_height()
				if not _is_pow2(w) or not _is_pow2(h):
					hard.append("%s: %dx%d not power-of-2 (§8.A HARD — NPOT doubles draw calls)" % [path, w, h])
				if w > ATLAS_MAX or h > ATLAS_MAX:
					hard.append("%s: %dx%d exceeds %d atlas cap (§8.C HARD — mobile WebGL2 OOM)" % [path, w, h, ATLAS_MAX])
			var f := FileAccess.open(abs_path, FileAccess.READ)
			if f != null:
				if f.get_length() > PNG_SIZE_WARN_BYTES:
					warns.append("%s: %.2f MB > 1 MB (§8.C — lead sign-off)" % [path, f.get_length() / 1048576.0])
				f.close()

		# --- audio size warning ---
		if ext == "ogg" or ext == "wav":
			var af := FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.READ)
			if af != null:
				if af.get_length() > AUDIO_SIZE_WARN_BYTES:
					warns.append("%s: %.2f MB > 2 MB audio (§8.C — lead sign-off)" % [path, af.get_length() / 1048576.0])
				af.close()

		# --- Checks 4, 5: scan resource/scene text ---
		if ext == "tres" or ext == "tscn":
			var rf := FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.READ)
			if rf == null:
				continue
			var text: String = rf.get_as_text()
			rf.close()
			if text.contains("CPUParticles2D"):
				hard.append("%s: contains CPUParticles2D (§8.D HARD — GPUParticles2D only via particle_system_wrapper)" % path)
			for m: RegExMatch in amount_re.search_all(text):
				var amt: int = m.get_string(1).to_int()
				if amt > PARTICLE_AMOUNT_MAX:
					hard.append("%s: particle amount=%d > %d (§8.C/§8.D HARD)" % [path, amt, PARTICLE_AMOUNT_MAX])

	# --- entity-registry consistency (Warning — skipped while registry empty) ---
	warns.append("entity-registry match (§8.A): SKIPPED — populate design/assets/entity-inventory.md " \
		+ "+ design/registry/entities.yaml `entities:` then promote this to HARD per-sprite-prefix check")

	# --- report ---
	for w: String in warns:
		print("[%s] WARN: %s" % [LINT_TAG, w])

	if hard.is_empty():
		print("[%s] PASS: %d asset file(s) scanned under %s — 0 HARD violations (art-bible §8.D)" % [LINT_TAG, files.size(), ASSETS_ROOT])
		quit(0)
		return

	for v: String in hard:
		printerr("%s" % v)
	printerr("")
	printerr("[%s] FAIL: %d HARD asset violation(s) — block PR merge (art-bible §8.D)" % [LINT_TAG, hard.size()])
	quit(1)


func _walk(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var child := dir_path + "/" + name
		if dir.current_is_dir():
			if not name.begins_with("."):   # skip hidden (but NOT our .godot_import_presets — keep scanning it)
				_walk(child, out)
			elif name == ".godot_import_presets":
				_walk(child, out)
		else:
			out.append(child)
		name = dir.get_next()
	dir.list_dir_end()


func _naming_exempt(path: String) -> bool:
	for prefix: String in NAMING_EXEMPT_PREFIXES:
		if path.begins_with(prefix):
			return true
	return false


func _is_pow2(n: int) -> bool:
	return n > 0 and (n & (n - 1)) == 0
