# OnboardingCoordinator (#27) — Story 001 / AC-23 / G-OB-1:
# autoload registered as TAIL (after CombatVisualFeedback #25, the impl-time current tail),
# and TERMINAL (nothing follows it except reserved #28 Telemetry, not yet written).
#
# Static read of project.godot [autoload] (ADR-0008 — project.godot is the sole ground
# truth for absolute autoload positions, F-SETUP-4). The GDD's early "after #29" wording
# was stale (B-2 fix) — the binding invariant is "after every existing coordinator", which
# this test verifies positionally rather than pinning a brittle predecessor name.
extends GutTest

const PROJECT_GODOT: String = "res://project.godot"

## Coordinators that must boot BEFORE OnboardingCoordinator (all existing tail autoloads).
const PRIOR_COORDINATORS: Array[String] = [
	"LootRevealCoordinator",
	"CharacterScreenCoordinator",
	"InventoryUICoordinator",
	"LoginShellCoordinator",
	"MirrorMomentCoordinator",
	"CombatVisualFeedback",
]

## Only these may legitimately follow #27 (reserved-Last #28 Telemetry, not yet written).
const ALLOWED_SUCCESSORS: Array[String] = [
	"Telemetry",
]


## Ordered list of autoload key names from the [autoload] section of project.godot.
func _read_autoload_order() -> Array[String]:
	var abs := ProjectSettings.globalize_path(PROJECT_GODOT)
	var file := FileAccess.open(abs, FileAccess.READ)
	assert_not_null(file, "project.godot must be readable")
	var in_section := false
	var order: Array[String] = []
	while file != null and not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line == "[autoload]":
			in_section = true
			continue
		if in_section and line.begins_with("["):
			break
		if in_section and "=" in line and not line.begins_with(";"):
			order.append(line.split("=")[0].strip_edges())
	if file != null:
		file.close()
	return order


func test_onboarding_coordinator_is_registered() -> void:
	var order := _read_autoload_order()
	assert_gt(order.find("OnboardingCoordinator"), -1,
		"AC-23/G-OB-1: OnboardingCoordinator must be a registered autoload in project.godot")


func test_onboarding_coordinator_boots_after_every_existing_coordinator() -> void:
	var order := _read_autoload_order()
	var ob_idx := order.find("OnboardingCoordinator")
	assert_gt(ob_idx, -1, "AC-23: OnboardingCoordinator must be registered")
	for name in PRIOR_COORDINATORS:
		var idx := order.find(name)
		assert_gt(idx, -1, "AC-23: prior coordinator %s must be a registered autoload" % name)
		assert_gt(ob_idx, idx,
			"AC-23/G-OB-1: OnboardingCoordinator (pos %d) must boot AFTER %s (pos %d) — tail-append" % [ob_idx, name, idx])


func test_onboarding_coordinator_is_terminal() -> void:
	# Nothing may follow #27 except reserved-Last #28 Telemetry (not yet written).
	var order := _read_autoload_order()
	var ob_idx := order.find("OnboardingCoordinator")
	assert_gt(ob_idx, -1, "AC-23: OnboardingCoordinator must be registered")
	for i in range(ob_idx + 1, order.size()):
		assert_true(order[i] in ALLOWED_SUCCESSORS,
			"AC-23/G-OB-1: OnboardingCoordinator must be TERMINAL — found unexpected successor: %s" % order[i])
