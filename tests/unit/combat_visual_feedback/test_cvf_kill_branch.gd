extends GutTest
## Story 006: CombatVisualFeedback (#25) kill branch — R-9/R-10 + critical-kill carve-out.
## AC-08 / AC-09 / AC-10 / AC-30 (MUST-NOT-REGRESS) + EC-05/06.
##
## Kill outcomes go through _route_kill: ALWAYS a kill-confirm number; flash + pause ONLY
## for OVERKILL or KILLED+CRITICAL (招牌「一刀劈死」). #25 NEVER play(DEATH) (= #14) and
## NEVER direct-shakes (#14 DEATH already auto-shakes 0.3). FakeParticles records every
## play() so we can assert zero DEATH preset; FakeScreenFx records shake to prove R-13.

const CvfScript := preload("res://src/autoload/combat_visual_feedback.gd")
const PSW := preload("res://src/autoload/particle_system_wrapper.gd")


# --- Fakes --------------------------------------------------------------------

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
	var plays: Array = []
	func play(preset_id: int, position: Vector2, multiplier: float = 1.0):
		plays.append({"preset": preset_id, "pos": position, "mult": multiplier})
		return null


class FakeScreenFx:
	extends RefCounted
	var pauses: Array = []
	var shakes: Array = []
	func hit_pause(duration: float) -> void:
		pauses.append(duration)
	func shake(trauma: float, _max_offset: float = 0.0) -> void:
		shakes.append(trauma)


# --- Helpers ------------------------------------------------------------------

func _make(overlay_enabled: bool = true) -> Node:
	var c = CvfScript.new()
	c._enemy_director = FakeEnemyDirector.new()
	c._gsm = FakeGSM.new()
	c._particles = FakeParticles.new()
	c._screen_fx = FakeScreenFx.new()
	c._avatar = RefCounted.new()
	add_child_autofree(c)
	c.set_process(false)
	c._overlay_enabled = overlay_enabled
	return c


func _kill(tier: int, outcome: int):
	var p := CombatResolver.HitResolvedPayload.new()
	p.damage_tier = tier
	p.outcome = outcome
	p.is_kill = true
	return p


func _assert_no_death_no_shake(c: Node, ctx: String) -> void:
	# #14 owns enemy death VFX + DEATH auto-shake. #25 must emit neither.
	assert_eq(c._particles.plays.size(), 0, "%s: #25 never play() on kill (#14 owns death VFX)" % ctx)
	assert_eq(c._screen_fx.shakes.size(), 0, "%s/R-13: #25 never direct-shakes on kill" % ctx)


# --- Tests --------------------------------------------------------------------

## AC-08: KILLED + tier < CRITICAL → kill number only (no pause, no flash, no death/shake).
func test_killed_below_critical_number_only() -> void:
	var c := _make()
	c._on_hit_resolved(_kill(CombatResolver.DamageTier.MEDIUM, CombatResolver.HitOutcome.KILLED))
	assert_eq(c._numbers_spawned, 1, "AC-08: one kill-confirm number")
	assert_eq(c._screen_fx.pauses.size(), 0, "AC-08: no hit_pause for sub-CRITICAL kill")
	assert_eq(c._overlay_state, c.OverlayState.IDLE, "AC-08: no flash for sub-CRITICAL kill")
	_assert_no_death_no_shake(c, "AC-08")


## AC-30 (MUST-NOT-REGRESS): KILLED + CRITICAL tier → 招牌 carve-out: flash + hit_pause(0.080).
func test_critical_kill_carveout_flashes_and_pauses() -> void:
	var c := _make(true)
	c._on_hit_resolved(_kill(CombatResolver.DamageTier.CRITICAL, CombatResolver.HitOutcome.KILLED))
	assert_eq(c._numbers_spawned, 1, "AC-30: kill-confirm number")
	assert_almost_eq(c._screen_fx.pauses[0], 0.080, 0.0001, "AC-30: critical-kill carve-out pause 0.080")
	assert_eq(c._overlay_state, c.OverlayState.FLASHING, "AC-30: critical-kill carve-out flashes")
	_assert_no_death_no_shake(c, "AC-30")


## AC-30 degrade path: same carve-out, overlay unratified → no flash, pause 0.100.
func test_critical_kill_carveout_degrade() -> void:
	var c := _make(false)
	c._on_hit_resolved(_kill(CombatResolver.DamageTier.CRITICAL, CombatResolver.HitOutcome.KILLED))
	assert_almost_eq(c._screen_fx.pauses[0], 0.100, 0.0001, "AC-30 degrade: pause 0.100")
	assert_eq(c._overlay_state, c.OverlayState.IDLE, "AC-30 degrade: no flash")


## AC-09: OVERKILL → flash + hit_pause(0.080) + number; no death/shake.
func test_overkill_flashes_and_pauses() -> void:
	var c := _make(true)
	c._on_hit_resolved(_kill(CombatResolver.DamageTier.HEAVY, CombatResolver.HitOutcome.OVERKILL))
	assert_eq(c._numbers_spawned, 1, "AC-09: overkill-confirm number")
	assert_almost_eq(c._screen_fx.pauses[0], 0.080, 0.0001, "AC-09: OVERKILL pause 0.080")
	assert_eq(c._overlay_state, c.OverlayState.FLASHING, "AC-09: OVERKILL flashes")
	_assert_no_death_no_shake(c, "AC-09")


## AC-10: KILLED + HEAVY tier → kill branch ONLY (outcome-first gate; no HEAVY 65ms double).
func test_killed_heavy_takes_kill_branch_no_heavy_double() -> void:
	var c := _make()
	c._on_hit_resolved(_kill(CombatResolver.DamageTier.HEAVY, CombatResolver.HitOutcome.KILLED))
	assert_eq(c._numbers_spawned, 1, "AC-10: kill number")
	assert_eq(c._screen_fx.pauses.size(), 0, "AC-10: no hit_pause — KILLED+HEAVY does NOT take the HEAVY tier branch")
	assert_eq(c._overlay_state, c.OverlayState.IDLE, "AC-10: no flash")
	_assert_no_death_no_shake(c, "AC-10")


## EC-06: KILLED + NEGLIGIBLE → still a kill number (kill is never silent, unlike a NEGLIGIBLE hit).
func test_ec06_killed_negligible_still_spawns_number() -> void:
	var c := _make()
	c._on_hit_resolved(_kill(CombatResolver.DamageTier.NEGLIGIBLE, CombatResolver.HitOutcome.KILLED))
	assert_eq(c._numbers_spawned, 1, "EC-06: KILLED+NEGLIGIBLE still spawns a kill number (not silent)")
	assert_eq(c._screen_fx.pauses.size(), 0, "EC-06: but no pause (sub-CRITICAL kill)")


## EC-05: outcome gate overrides tier — a CRITICAL-tier KILLED does NOT also run the
## non-kill CRITICAL tier branch (no double number, no double pause).
func test_ec05_no_double_handling_on_critical_kill() -> void:
	var c := _make(true)
	c._on_hit_resolved(_kill(CombatResolver.DamageTier.CRITICAL, CombatResolver.HitOutcome.KILLED))
	assert_eq(c._numbers_spawned, 1, "EC-05: exactly one number (kill branch, not also tier branch)")
	assert_eq(c._screen_fx.pauses.size(), 1, "EC-05: exactly one pause (no double)")
