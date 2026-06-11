extends GutTest
## Story 009: CombatVisualFeedback (#25) damage-number pool render (R-19, AC-19).
## Verifies the pre-instantiated Label pool, oldest-recycle when full (latest-wins),
## Formula 1 rise/fade via _process, and release-on-expiry. No runtime alloc.

const CvfScript := preload("res://src/autoload/combat_visual_feedback.gd")
const F := preload("res://src/core/combat_visual_feedback_formulas.gd")


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


func _make() -> Node:
	var c = CvfScript.new()
	c._enemy_director = FakeEnemyDirector.new()
	c._gsm = FakeGSM.new()
	c._particles = FakeParticles.new()
	c._screen_fx = FakeScreenFx.new()
	c._avatar = RefCounted.new()
	add_child_autofree(c)
	c.set_process(false)
	return c


func _light(tid: String, target: int):
	var p := CombatResolver.HitResolvedPayload.new()
	p.damage_tier = CombatResolver.DamageTier.LIGHT
	p.outcome = CombatResolver.HitOutcome.NORMAL_HIT
	p.transition_id = tid
	p.target_id = target
	p.damage_dealt = target  # distinct text per number
	return p


# --- Tests --------------------------------------------------------------------

func test_pool_pre_instantiated_at_boot() -> void:
	var c := _make()
	assert_eq(c._number_pool.size(), F.MAX_CONCURRENT_DAMAGE_NUMBERS,
		"R-19: Label pool pre-instantiated to MAX_CONCURRENT (12) at boot")
	assert_not_null(c._number_layer, "CombatNumberLayer host created")
	assert_eq(c._number_layer.layer, c.NUMBER_LAYER, "host at NUMBER_LAYER sort order")


## AC-19: pool full → oldest-recycle (latest-wins). Active never exceeds the cap.
func test_pool_oldest_recycle_when_full() -> void:
	var c := _make()
	for i in range(13):
		c._on_hit_resolved(_light("t%d" % i, i + 1))
	assert_eq(c._active_numbers.size(), F.MAX_CONCURRENT_DAMAGE_NUMBERS,
		"AC-19: 13 spawns into a 12 pool → active capped at 12 (oldest recycled)")
	# Latest-wins: the newest number (value 13) is visible.
	var newest: Dictionary = c._active_numbers[c._active_numbers.size() - 1]
	var lbl: Label = newest["label"]
	assert_true(lbl.visible, "AC-19: newest number is visible")
	assert_eq(lbl.text, "13", "AC-19: newest number shows the latest hit")


## Formula 1 applied by _process; expired numbers release back to the pool.
## _process clamps each frame to MAX_FRAME_DELTA (0.1) — so we advance in 0.1 steps.
func test_process_ticks_rise_fade_and_releases() -> void:
	var c := _make()
	c._on_hit_resolved(_light("a", 7))
	assert_eq(c._active_numbers.size(), 1, "one active number")
	var lbl: Label = c._active_numbers[0]["label"]
	var base: Vector2 = c._active_numbers[0]["base"]

	for _i in range(4):
		c._process(0.1)  # → t=0.4 mid-life (each frame clamps to MAX_FRAME_DELTA)
	assert_almost_eq(lbl.position.y, base.y - 30.0, 0.001, "Formula 1: y rises ~30px at t=0.4")
	assert_almost_eq(lbl.modulate.a, 1.0, 0.001, "Formula 1: still opaque at fade-start")

	for _i in range(5):
		c._process(0.1)  # → t≈0.9 > LIFETIME 0.8 (margin past the fp boundary) → release
	assert_eq(c._active_numbers.size(), 0, "expired number released back to pool")
	assert_false(lbl.visible, "released label hidden")


## Suspended force-releases all active numbers (States table; bfcache wiring story 012).
func test_suspended_releases_all_numbers() -> void:
	var c := _make()
	c._on_hit_resolved(_light("a", 1))
	c._on_hit_resolved(_light("b", 2))
	assert_eq(c._active_numbers.size(), 2, "two active before suspend")
	c._enter_suspended()
	assert_eq(c._active_numbers.size(), 0, "Suspended force-releases all numbers")
