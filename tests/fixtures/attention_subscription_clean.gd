# Fixture — legal subscription forms that check_attention_subscription.gd must NOT flag.
# NOT production code; consumed by test_attention_subscription_ci_lint.gd only.
#   - #1 state_changed via connect_for_initial_state (ADR-0006 Contract 6) — the
#     `state_changed.connect_for_initial_state(`-style helper form has `connect`
#     followed by `_`, never `(`, so the ban regex does NOT match it.
#   - #9 phase_changed via plain .connect — anchored on `state_changed`, the ban
#     regex does NOT match `phase_changed.connect(` (WST 2-arg, legal plain form).
#   - A commented-out plain state_changed.connect must NOT false-positive.
extends Node


func _good_boot() -> void:
	# Route 1: GSM via the sanctioned helper (NO plain state_changed.connect).
	GameStateMachine.connect_for_initial_state(_on_gsm_state_changed)
	# Route 2: WST phase_changed via plain .connect — legal (anchored regex skips it).
	WorkoutStateTracker.phase_changed.connect(_on_wst_phase_changed)


func _commented_bans_ignored() -> void:
	# GameStateMachine.state_changed.connect(_on_gsm_state_changed)  ← commented, must NOT match
	pass


func _on_gsm_state_changed(_from: int, _to: int, _payload) -> void:
	pass


func _on_wst_phase_changed(_from: int, _to: int) -> void:
	pass
