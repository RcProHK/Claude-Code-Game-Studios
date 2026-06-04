# Fixture — banned GSM plain-connect that check_attention_subscription.gd MUST flag.
# NOT production code; consumed by test_attention_subscription_ci_lint.gd only.
# The plain `state_changed.connect(` form silently misses GSM's initial state
# (ADR-0006 Contract 4/6) — it must use connect_for_initial_state() instead.
extends Node


func _bad_boot() -> void:
	# VIOLATION: plain .connect on state_changed misses the initial-state delivery.
	GameStateMachine.state_changed.connect(_on_state_changed)


func _on_state_changed(_from: int, _to: int, _payload) -> void:
	pass
