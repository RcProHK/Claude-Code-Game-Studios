# Telemetry (#28) — Story 001 / G-TEL-1 / AC-1 (autoload Last):
# the Telemetry autoload is registered as the TERMINAL tail of the [autoload] section
# (after OnboardingCoordinator #27, the impl-time prior tail), and NOTHING follows it.
#
# Static read of project.godot [autoload] (ADR-0008 — project.godot is the sole ground
# truth for absolute autoload positions, F-SETUP-4). #28 is reserved "Last" precisely so
# it observes a fully-booted tree; it is order-resilient (connect_for_initial_state
# back-fills #1 GSM current_state), so booting Last drops zero runtime-emitted signal.
#
# This pins the canonical-map invariant positionally ("after every prior tail autoload"
# + "nothing follows") rather than a brittle single predecessor name, mirroring the #27
# test_onboarding_autoload_position.gd precedent. If a future autoload is ever appended,
# Telemetry must be pushed below it (terminal observer is always last) — this test then
# fails loudly, which is the intended tripwire.
extends GutTest

const PROJECT_GODOT: String = "res://project.godot"
const SUBJECT: String = "Telemetry"
const SUBJECT_PATH: String = "*res://src/autoload/telemetry.gd"

## Autoloads that must boot BEFORE Telemetry (every prior tail autoload, #27 included).
const PRIOR_AUTOLOADS: Array[String] = [
	"LootRevealCoordinator",
	"CharacterScreenCoordinator",
	"InventoryUICoordinator",
	"LoginShellCoordinator",
	"MirrorMomentCoordinator",
	"CombatVisualFeedback",
	"OnboardingCoordinator",
]


## Ordered list of "key=value" entries from the [autoload] section of project.godot.
## Returns [[key, value], ...] preserving listing order.
func _read_autoload_entries() -> Array:
	var abs := ProjectSettings.globalize_path(PROJECT_GODOT)
	var file := FileAccess.open(abs, FileAccess.READ)
	assert_not_null(file, "project.godot must be readable")
	var in_section := false
	var entries: Array = []
	while file != null and not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line == "[autoload]":
			in_section = true
			continue
		if in_section and line.begins_with("["):
			break
		if in_section and "=" in line and not line.begins_with(";"):
			var key := line.split("=")[0].strip_edges()
			var value := line.substr(line.find("=") + 1).strip_edges().trim_prefix("\"").trim_suffix("\"")
			entries.append([key, value])
	if file != null:
		file.close()
	return entries


func _keys_in_order() -> Array[String]:
	var keys: Array[String] = []
	for entry in _read_autoload_entries():
		keys.append(entry[0])
	return keys


func test_telemetry_is_registered() -> void:
	var keys := _keys_in_order()
	assert_gt(keys.find(SUBJECT), -1,
		"G-TEL-1/AC-1: Telemetry must be a registered autoload in project.godot")


func test_telemetry_path_points_at_autoload_script() -> void:
	var entries := _read_autoload_entries()
	var found := false
	for entry in entries:
		if entry[0] == SUBJECT:
			found = true
			assert_eq(entry[1], SUBJECT_PATH,
				"G-TEL-1/AC-1: Telemetry must point at %s" % SUBJECT_PATH)
	assert_true(found, "G-TEL-1/AC-1: Telemetry entry must exist")


func test_telemetry_boots_after_every_prior_tail_autoload() -> void:
	var keys := _keys_in_order()
	var tel_idx := keys.find(SUBJECT)
	assert_gt(tel_idx, -1, "G-TEL-1/AC-1: Telemetry must be registered")
	for name in PRIOR_AUTOLOADS:
		var idx := keys.find(name)
		assert_gt(idx, -1, "G-TEL-1: prior autoload %s must be a registered autoload" % name)
		assert_gt(tel_idx, idx,
			"G-TEL-1/AC-1: Telemetry (pos %d) must boot AFTER %s (pos %d) — reserved Last" % [tel_idx, name, idx])


func test_telemetry_is_terminal() -> void:
	# Nothing may follow #28 Telemetry — it is the canonical "Last" slot.
	var keys := _keys_in_order()
	var tel_idx := keys.find(SUBJECT)
	assert_gt(tel_idx, -1, "G-TEL-1/AC-1: Telemetry must be registered")
	assert_eq(tel_idx, keys.size() - 1,
		"G-TEL-1/AC-1: Telemetry must be TERMINAL (last entry) — found successor(s): %s"
			% str(keys.slice(tel_idx + 1)))
