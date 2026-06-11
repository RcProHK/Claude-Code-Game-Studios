extends GutTest
## Story 007: CombatVisualFeedback (#25) R-12 dual-axis decoupling. AC-12 + EC-13/14.
##
## Two independent "critical" axes:
##   - number STYLE keyed on is_crit (crit roll)        → CRIT (warm bounce) vs PLAIN (white)
##   - screen-FEEL (pause + flash) keyed on damage_tier → CRITICAL tier flashes + 80ms
## The legal cross combinations (EC-13/14) must each route correctly and independently.

const CvfScript := preload("res://src/autoload/combat_visual_feedback.gd")


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
	func play(_preset_id: int, _position: Vector2, _multiplier: float = 1.0):
		return null


class FakeScreenFx:
	extends RefCounted
	var pauses: Array = []
	func hit_pause(duration: float) -> void:
		pauses.append(duration)


# --- Helpers ------------------------------------------------------------------

func _make() -> Node:
	var c = CvfScript.new()
	c._enemy_director = FakeEnemyDirector.new()
	c._gsm = FakeGSM.new()
	c._particles = FakeParticles.new()
	c._screen_fx = FakeScreenFx.new()
	c._avatar = RefCounted.new()
	add_child_autofree(c)
	c.set_process(false)
	c._overlay_enabled = true  # ratified — exercise the real flash path
	return c


func _hit(tier: int, crit: bool):
	var p := CombatResolver.HitResolvedPayload.new()
	p.damage_tier = tier
	p.outcome = CombatResolver.HitOutcome.CRITICAL_HIT if crit else CombatResolver.HitOutcome.NORMAL_HIT
	p.is_crit = crit
	p.damage_dealt = 50
	return p


# --- Tests --------------------------------------------------------------------

## AC-12 / EC-13: crit roll on a HEAVY-tier hit → CRIT number style BUT only HEAVY
## screen-feel (65ms, NO flash). The warm number must not drag the screen-feel up.
func test_crit_roll_heavy_tier_warm_number_but_heavy_feel() -> void:
	var c := _make()
	c._on_hit_resolved(_hit(CombatResolver.DamageTier.HEAVY, true))
	assert_eq(c._last_number_style, c.NumberStyle.CRIT, "EC-13: is_crit=true → CRIT number style")
	assert_eq(c._overlay_state, c.OverlayState.IDLE, "EC-13: HEAVY tier → NO flash (screen-feel keyed on tier)")
	assert_almost_eq(c._screen_fx.pauses[0], 0.065, 0.0001, "EC-13: HEAVY screen-feel = 65ms (not 80)")


## AC-12 / EC-14: non-crit CRITICAL-tier hit → PLAIN number BUT full CRITICAL screen-feel
## (flash + 80ms). The plain number must not drag the screen-feel down.
func test_noncrit_critical_tier_plain_number_but_critical_feel() -> void:
	var c := _make()
	c._on_hit_resolved(_hit(CombatResolver.DamageTier.CRITICAL, false))
	assert_eq(c._last_number_style, c.NumberStyle.PLAIN, "EC-14: is_crit=false → PLAIN number style")
	assert_eq(c._overlay_state, c.OverlayState.FLASHING, "EC-14: CRITICAL tier → flash (screen-feel keyed on tier)")
	assert_almost_eq(c._screen_fx.pauses[0], 0.080, 0.0001, "EC-14: CRITICAL screen-feel = 80ms")


## Style axis is purely is_crit: a plain LIGHT hit → PLAIN; a crit LIGHT is unreachable
## (#13 crit-override forces is_crit → tier ≥ HEAVY) but the style mapping itself is total.
func test_number_style_is_pure_is_crit() -> void:
	var c := _make()
	c._on_hit_resolved(_hit(CombatResolver.DamageTier.LIGHT, false))
	assert_eq(c._last_number_style, c.NumberStyle.PLAIN, "LIGHT non-crit → PLAIN number")
