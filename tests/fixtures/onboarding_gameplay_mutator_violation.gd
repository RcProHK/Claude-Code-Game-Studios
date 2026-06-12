extends Node
## FIXTURE (NOT production) — a deliberately-violating onboarding-style file used by
## tests/static/test_onboarding_ci_lint.gd to prove check_onboarding_no_gameplay_mutator.gd
## actually catches a gameplay mutator. This file must NEVER be referenced by real code and
## lives outside the lint's scan scope (it scans src/autoload + src/ui/onboarding only).

var _persistence = null
var _loot = null


func _bad_writes() -> void:
	# VIOLATION 1 — persistence write to a gameplay namespace (only onboarding.* is legal).
	_persistence.write("loot.first_item", true)
	# VIOLATION 2 — #15 daily-claim (onboarding must never claim the daily token).
	_loot.claim_daily()
	# VIOLATION 3 — a #11/#12 gameplay mutator call.
	_loot.unlock_ability(&"strike_basic")
