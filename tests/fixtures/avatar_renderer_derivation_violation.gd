# CI fixture (NOT a test — no `test_` prefix, so GUT never collects it). Exercises
# tools/ci/check_avatar_renderer_derivation.gd (CI-1 / AC-23): a `_visual_state` field
# write OUTSIDE `_derive_state_from_canonical()` is a single-writer violation, while writes
# inside it and `==` comparisons anywhere are clean.
extends Node

var _visual_state = null
var _current_anim := &"IDLE"


func _derive_state_from_canonical(_t: int) -> void:
	# ALLOWED: the single fabrication boundary is the only permitted writer.
	_visual_state.evolution_tier = 1
	_visual_state.animation_state = _current_anim


func _on_some_handler() -> void:
	# VIOLATION: a handler must never write a _visual_state field directly (CI-1 / AC-23).
	_visual_state.animation_state = &"COMBAT"


func _compare_only() -> void:
	# CLEAN: `==` is a comparison, not an assignment — must NOT be flagged.
	if _visual_state.animation_state == &"IDLE":
		pass
