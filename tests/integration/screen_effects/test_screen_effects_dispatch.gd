# ScreenEffects — Story 006: dispatch table + burst_started auto-reaction.
#
# Coverage:
#   AC-14 — burst_started(PARRY) → _apply_shake(0.6,0.08) AND hit_pause(0.06) (Falsifiable #1).
#   AC-15 — 5 no-op presets (HIT_LIGHT/STATUS_*/LOOT_BURST) → no shake/pause/log; missed count steady.
#   AC-23 — handler returns + await-free (_emit_depth back to 0). Timing is ADVISORY/perf-gated.
#
# PresetId comes from the real ParticleSystemWrapper autoload script (preload) — never a
# hardcoded int (ADR-0007 enum declaration order is load-bearing).
extends GutTest

const SE := preload("res://src/autoload/screen_effects.gd")
const PSW := preload("res://src/autoload/particle_system_wrapper.gd")

var _sut


func before_each() -> void:
	_sut = SE.new()
	add_child_autofree(_sut)
	await get_tree().process_frame
	_sut._lifecycle_state = SE.LifecycleState.ACTIVE


func after_each() -> void:
	if get_tree().paused:
		get_tree().paused = false


# ---------------------------------------------------------------------------
# AC-14 — PARRY fires both shake + pause
# ---------------------------------------------------------------------------

func test_parry_dispatch_fires_shake_and_pause() -> void:
	_sut._motion_intensity = 1.0
	_sut._trauma = 0.0
	_sut._pause_remaining_sec = 0.0
	_sut._on_burst_started(PSW.PresetId.PARRY, Vector2(100, 50))
	assert_almost_eq(_sut._trauma, 0.6, 0.0001, "AC-14: _DISPATCH[PARRY].shake intensity = 0.6")
	assert_almost_eq(_sut._pause_remaining_sec, 0.06, 0.0001, "AC-14: _DISPATCH[PARRY].pause = 0.06")


# ---------------------------------------------------------------------------
# AC-15 — no-op presets silent
# ---------------------------------------------------------------------------

func test_noop_presets_produce_no_effect() -> void:
	_sut._trauma = 0.0
	_sut._pause_remaining_sec = 0.0
	var baseline: int = _sut._dispatch_missed_count
	var noop := [
		PSW.PresetId.HIT_LIGHT, PSW.PresetId.STATUS_BURN, PSW.PresetId.STATUS_FREEZE,
		PSW.PresetId.STATUS_STUN, PSW.PresetId.LOOT_BURST,
	]
	for preset in noop:
		_sut._on_burst_started(preset, Vector2.ZERO)
	assert_eq(_sut._trauma, 0.0, "AC-15: no-op presets add no trauma")
	assert_eq(_sut._pause_remaining_sec, 0.0, "AC-15: no-op presets add no pause")
	assert_eq(_sut._dispatch_missed_count, baseline,
		"AC-15: known no-op presets are intentional table entries — NOT counted as misses")


# ---------------------------------------------------------------------------
# AC-23 — handler structural / await-free
# ---------------------------------------------------------------------------

func test_handler_returns_and_unwinds_emit_depth() -> void:
	_sut._on_burst_started(PSW.PresetId.PARRY, Vector2.ZERO)
	assert_eq(_sut._emit_depth, 0, "AC-23: handler completed + unwound (no pending await)")


func test_handler_source_is_await_free() -> void:
	# Static await-free guarantee (BLOCKING-assertable part of AC-23; timing is ADVISORY).
	var src := FileAccess.open(ProjectSettings.globalize_path("res://src/autoload/screen_effects.gd"), FileAccess.READ)
	assert_not_null(src)
	var text := src.get_as_text() if src != null else ""
	if src != null:
		src.close()
	# Crude scope: ensure no `await` appears inside the _on_burst_started body.
	var start := text.find("func _on_burst_started")
	assert_gt(start, -1, "handler exists")
	var next := text.find("\nfunc ", start + 1)
	var body := text.substr(start, (next - start) if next > -1 else text.length() - start)
	assert_false("await" in body, "AC-23: _on_burst_started must be await-free")
