extends GutTest
## Story 014: CombatVisualFeedback (#25) G-CV-3 combat-hit cue trigger (consumer-forward).
## tier/outcome → AudioManager.play_sfx(cue); silent-mode (#4 absent) fail-soft with the
## visual fully intact. #25 only TRIGGERS — #4 owns playback + the cue catalog.

const CvfScript := preload("res://src/autoload/combat_visual_feedback.gd")


class FakeEnemyDirector:
	extends RefCounted
	signal hit_resolved(payload)
	signal enemy_killed(payload)


class FakeGSM:
	extends RefCounted
	enum GameState {BOOTING, DISCONNECTED, IDLE, WORKOUT_ACTIVE, REST_PERIOD, COMBAT_ACTIVE, BOSS_ENCOUNTER, LOOT_DROP, SUSPENDED}
	signal state_changed(from_state, to_state, payload)
	func connect_for_initial_state(c: Callable) -> void:
		state_changed.connect(c)


class FakeParticles:
	extends RefCounted
	func play(_p: int, _pos: Vector2, _m: float = 1.0):
		return null


class FakeScreenFx:
	extends RefCounted
	func hit_pause(_d: float) -> void:
		pass


class FakeAudio:
	extends RefCounted
	var cues: Array = []
	func play_sfx(event_id: StringName) -> void:
		cues.append(event_id)


var _tid := 0

func _make(audio) -> Node:
	var c = CvfScript.new()
	c._enemy_director = FakeEnemyDirector.new()
	c._gsm = FakeGSM.new()
	c._particles = FakeParticles.new()
	c._screen_fx = FakeScreenFx.new()
	c._audio = audio
	c._avatar = RefCounted.new()
	add_child_autofree(c)
	c.set_process(false)
	c._overlay_enabled = true
	return c


func _hit(tier: int, outcome: int):
	var p := CombatResolver.HitResolvedPayload.new()
	p.damage_tier = tier
	p.outcome = outcome
	p.damage_dealt = 50
	_tid += 1
	p.transition_id = "t%d" % _tid
	p.target_id = _tid
	return p


# --- Tests --------------------------------------------------------------------

func test_tier_cue_map() -> void:
	var DT := CombatResolver.DamageTier
	var HO := CombatResolver.HitOutcome
	var cases := [
		[DT.LIGHT, HO.NORMAL_HIT, "sfx_hit_light"],
		[DT.MEDIUM, HO.NORMAL_HIT, "sfx_hit_light"],
		[DT.HEAVY, HO.NORMAL_HIT, "sfx_hit_heavy"],
		[DT.CRITICAL, HO.CRITICAL_HIT, "sfx_hit_critical"],
	]
	for case in cases:
		var a := FakeAudio.new()
		var c := _make(a)
		c._on_hit_resolved(_hit(case[0], case[1]))
		assert_eq(a.cues.size(), 1, "one cue for tier %d" % case[0])
		assert_eq(String(a.cues[0]), case[2], "tier %d → %s" % [case[0], case[2]])


func test_outcome_cue_map() -> void:
	var DT := CombatResolver.DamageTier
	var HO := CombatResolver.HitOutcome
	var cases := [
		[DT.HEAVY, HO.OVERKILL, "sfx_overkill"],
		[DT.MEDIUM, HO.KILLED, "sfx_kill"],
		[DT.CRITICAL, HO.KILLED, "sfx_hit_critical"],  # critical-kill carve-out → chime
	]
	for case in cases:
		var a := FakeAudio.new()
		var c := _make(a)
		c._on_hit_resolved(_hit(case[0], case[1]))
		assert_eq(a.cues.size(), 1, "one cue for outcome case")
		assert_eq(String(a.cues[0]), case[2], "%d/%d → %s" % [case[0], case[1], case[2]])


func test_negligible_is_silent() -> void:
	var a := FakeAudio.new()
	var c := _make(a)
	c._on_hit_resolved(_hit(CombatResolver.DamageTier.NEGLIGIBLE, CombatResolver.HitOutcome.NORMAL_HIT))
	assert_eq(a.cues.size(), 0, "NEGLIGIBLE → no cue (silent floor)")


## Silent-mode (#4 absent / no play_sfx): fail-soft — no crash, the visual is complete.
func test_silent_mode_visual_intact_no_crash() -> void:
	var c := _make(RefCounted.new())  # bare object, no play_sfx → has_method guard skips
	c._on_hit_resolved(_hit(CombatResolver.DamageTier.CRITICAL, CombatResolver.HitOutcome.CRITICAL_HIT))
	# Visual still fully present without any audio:
	assert_eq(c._overlay_state, c.OverlayState.FLASHING, "silent: flash still fires")
	assert_eq(c._numbers_spawned, 1, "silent: number still spawns")
	assert_true(c._number_pool.size() > 0, "silent: pool intact (no crash)")
