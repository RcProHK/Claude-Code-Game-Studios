extends Node
## FIXTURE (NOT production) — a deliberately-violating telemetry-style file used by
## tests/static/test_telemetry_ci_lint.gd to prove check_telemetry_no_pii.gd actually
## catches raw body data in a payload. NEVER referenced by real code; lives outside the
## lint's scan scope (it scans src/autoload/telemetry.gd + src/telemetry/* only).

var payload: Dictionary = {}


func _bad_payload(weight: float) -> void:
	# VIOLATION 1 — raw absolute weight as a quoted dict key.
	payload["weight_kg"] = 100
	# VIOLATION 2 — absolute 1RM as a quoted dict key.
	payload["one_rep_max"] = 150
	# VIOLATION 3 — bodyweight as a bare assigned field.
	var bodyweight := weight
	payload["bw"] = bodyweight


func _legal_payload() -> void:
	# ALLOWLIST — normalized / de-identified values (must NOT be flagged).
	payload["pr_magnitude"] = 1.2
	payload["rarity_tier"] = "EPIC"
	payload["completed_exercises_count"] = 8
	payload["damage_dealt"] = 50  # in-game damage, NOT a body metric
