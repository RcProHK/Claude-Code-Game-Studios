extends GutTest
## Story 005: CombatVisualFeedback (#25) HEAVY/CRITICAL routing + Formula 4 hit_pause +
## R-13 double-shake guard. AC-06 / AC-07a / AC-07b / AC-22.
##
## FakeScreenFx records BOTH hit_pause and shake — the shake-recorder proves #25 never
## direct-shakes (R-13). Formula 4 is exercised as a pure static function (AC-22).

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
	var shakes: Array = []  ## records direct shake calls — must stay EMPTY (R-13)
	func hit_pause(duration: float) -> void:
		pauses.append(duration)
	func shake(trauma: float, _max_offset: float = 0.0) -> void:
		shakes.append(trauma)


# --- Helpers ------------------------------------------------------------------

func _make(overlay_enabled: bool = false) -> Node:
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


func _hit(tier: int, outcome: int, crit: bool = false):
	var p := CombatResolver.HitResolvedPayload.new()
	p.damage_tier = tier
	p.outcome = outcome
	p.is_crit = crit
	p.damage_dealt = 50
	return p


# --- Routing tests ------------------------------------------------------------

## AC-06: HEAVY non-kill → HIT_HEAVY + hit_pause(0.065) + ZERO direct shake.
func test_heavy_plays_pause_and_never_direct_shakes() -> void:
	var c := _make()
	c._on_hit_resolved(_hit(CombatResolver.DamageTier.HEAVY, CombatResolver.HitOutcome.NORMAL_HIT))
	assert_eq(c._particles.plays.size(), 1, "AC-06: one particle")
	assert_eq(c._particles.plays[0]["preset"], PSW.PresetId.HIT_HEAVY, "AC-06: HIT_HEAVY")
	assert_eq(c._screen_fx.pauses.size(), 1, "AC-06: one hit_pause")
	assert_almost_eq(c._screen_fx.pauses[0], 0.065, 0.0001, "AC-06: HEAVY pause 0.065")
	assert_eq(c._screen_fx.shakes.size(), 0, "AC-06/R-13: #25 never direct-calls shake")


## AC-07a: CRITICAL + overlay ratified → HIT_HEAVY + hit_pause(0.080) + overlay FLASHING.
func test_critical_ratified_flashes_and_pauses_080() -> void:
	var c := _make(true)
	c._on_hit_resolved(_hit(CombatResolver.DamageTier.CRITICAL, CombatResolver.HitOutcome.CRITICAL_HIT, true))
	assert_eq(c._particles.plays[0]["preset"], PSW.PresetId.HIT_HEAVY, "AC-07a: HIT_HEAVY (shared)")
	assert_almost_eq(c._screen_fx.pauses[0], 0.080, 0.0001, "AC-07a: CRITICAL pause 0.080 (ratified)")
	assert_eq(c._overlay_state, c.OverlayState.FLASHING, "AC-07a: overlay enters FLASHING")
	assert_eq(c._screen_fx.shakes.size(), 0, "AC-07a/R-13: no direct shake")


## AC-07b: CRITICAL + overlay NOT ratified → degrade: hit_pause(0.100), no flash, number still spawns.
func test_critical_degrade_no_flash_pause_100() -> void:
	var c := _make(false)
	c._on_hit_resolved(_hit(CombatResolver.DamageTier.CRITICAL, CombatResolver.HitOutcome.CRITICAL_HIT, true))
	assert_eq(c._particles.plays[0]["preset"], PSW.PresetId.HIT_HEAVY, "AC-07b: HIT_HEAVY")
	assert_almost_eq(c._screen_fx.pauses[0], 0.100, 0.0001, "AC-07b: degrade pause 0.100")
	assert_eq(c._overlay_state, c.OverlayState.IDLE, "AC-07b: overlay stays IDLE (no flash)")
	assert_eq(c._numbers_spawned, 1, "AC-07b: damage number still spawns")


# --- Formula 4 pure-function tests (AC-22) ------------------------------------

func test_f4_heavy_returns_065() -> void:
	assert_almost_eq(
		CombatVisualFeedbackFormulas.hit_pause_sec(CombatResolver.HitOutcome.NORMAL_HIT, CombatResolver.DamageTier.HEAVY),
		0.065, 0.0001, "AC-22: (NORMAL,HEAVY) → 0.065")


func test_f4_critical_returns_080_ratified() -> void:
	assert_almost_eq(
		CombatVisualFeedbackFormulas.hit_pause_sec(CombatResolver.HitOutcome.CRITICAL_HIT, CombatResolver.DamageTier.CRITICAL),
		0.080, 0.0001, "AC-22: (CRITICAL_HIT,CRITICAL) → 0.080 (default ratified)")


func test_f4_lower_tiers_return_zero() -> void:
	for tier in [CombatResolver.DamageTier.MEDIUM, CombatResolver.DamageTier.LIGHT, CombatResolver.DamageTier.NEGLIGIBLE]:
		assert_almost_eq(
			CombatVisualFeedbackFormulas.hit_pause_sec(CombatResolver.HitOutcome.NORMAL_HIT, tier),
			0.0, 0.0001, "AC-22: lower tier %d → 0.0" % tier)


func test_f4_critical_degrade_returns_100() -> void:
	assert_almost_eq(
		CombatVisualFeedbackFormulas.hit_pause_sec(CombatResolver.HitOutcome.CRITICAL_HIT, CombatResolver.DamageTier.CRITICAL, false),
		0.100, 0.0001, "AC-22/EC-20: CRITICAL degrade → 0.100")
