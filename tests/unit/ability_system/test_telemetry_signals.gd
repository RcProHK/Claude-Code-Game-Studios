# AbilitySystem — AC-20 Telemetry signal surface (Rule 16)
#
# Scope: verifies exactly 7 ability-prefixed signals are declared (the telemetry
# surface), with their canonical names, plus the separately-counted boot_completed
# lifecycle signal. Uses get_signal_list() reflection, FILTERING OUT inherited Node
# signals (e.g. ready, tree_entered, script_changed) by matching the "ability_" prefix.
#
# AC-20 counts the 7 ability_* signals:
#   ability_unlocked, ability_cast, ability_cooldown_started, ability_cooldown_ended,
#   ability_mutation_rejected, ability_cast_rejected, ability_unlock_save_failed.
# boot_completed is the 8th declared signal but is a lifecycle signal counted separately.
#
# Framework: GUT (Godot Unit Testing) v9.x
# Driving GDD: design/gdd/ability-system.md AC-20 (Rule 16); Story 002
extends GutTest


const EXPECTED_ABILITY_SIGNALS: Array[String] = [
	"ability_unlocked",
	"ability_cast",
	"ability_cooldown_started",
	"ability_cooldown_ended",
	"ability_mutation_rejected",
	"ability_cast_rejected",
	"ability_unlock_save_failed",
]


var _ability: Node = null


func before_each() -> void:
	_ability = preload("res://src/autoload/ability_system.gd").new()


func after_each() -> void:
	_ability.free()
	_ability = null


## Helper — names of all declared signals whose name begins with "ability_"
## (filters out inherited Node signals).
func _ability_signal_names() -> Array[String]:
	var names: Array[String] = []
	for s: Dictionary in _ability.get_signal_list():
		var sig_name: String = String(s.get("name", ""))
		if sig_name.begins_with("ability_"):
			names.append(sig_name)
	return names


## AC-20: exactly 7 ability_* telemetry signals, all canonical, no extras.
func test_ability_system_declares_exactly_seven_ability_signals() -> void:
	# Act
	var ability_signals: Array[String] = _ability_signal_names()

	# Assert — count is exactly 7.
	assert_eq(ability_signals.size(), 7,
		"AC-20: exactly 7 ability_* telemetry signals must be declared (got %s)" % [ability_signals])

	# Assert — each canonical signal is present.
	for sig_name: String in EXPECTED_ABILITY_SIGNALS:
		assert_true(ability_signals.has(sig_name),
			"AC-20: ability signal '%s' must be declared" % sig_name)


## AC-20: each ability signal carries the correct number of typed parameters.
func test_ability_signals_have_correct_arity() -> void:
	# Arrange — expected arg counts per the AC-20 signatures.
	const EXPECTED_ARITY: Dictionary = {
		"ability_unlocked": 2,            # (ability_id, source)
		"ability_cast": 3,                # (ability_id, caster, target)
		"ability_cooldown_started": 2,    # (ability_id, duration)
		"ability_cooldown_ended": 1,      # (ability_id)
		"ability_mutation_rejected": 3,   # (ability_id, source, reason)
		"ability_cast_rejected": 2,       # (ability_id, reason)
		"ability_unlock_save_failed": 1,  # (ability_id)
	}

	# Act + Assert
	for s: Dictionary in _ability.get_signal_list():
		var sig_name: String = String(s.get("name", ""))
		if not EXPECTED_ARITY.has(sig_name):
			continue
		var arg_count: int = (s.get("args", []) as Array).size()
		assert_eq(arg_count, EXPECTED_ARITY[sig_name],
			"AC-20: signal '%s' must declare %d params" % [sig_name, EXPECTED_ARITY[sig_name]])


## AC-20: boot_completed lifecycle signal is declared (the 8th signal, counted separately).
func test_boot_completed_signal_declared() -> void:
	# Act
	var has_boot_completed: bool = false
	for s: Dictionary in _ability.get_signal_list():
		if String(s.get("name", "")) == "boot_completed":
			has_boot_completed = true
			# Lifecycle signal carries no payload.
			assert_eq((s.get("args", []) as Array).size(), 0,
				"AC-20: boot_completed must carry no payload")
			break

	# Assert
	assert_true(has_boot_completed,
		"AC-20: boot_completed lifecycle signal must be declared (separate from the 7 ability signals)")
