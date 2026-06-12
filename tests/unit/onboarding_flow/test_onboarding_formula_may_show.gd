extends GutTest
## Story 005: OnboardingFormulas.may_show (Formula 1 coach-mark display gate) — all four
## terms + workout-critical defer (AC-10, Pillar 2 命脈) + the coordinator's WORKOUT_CRITICAL
## membership which is GSM-only (B-1 guard: WORKOUT_ACTIVE/REST_PERIOD/LOOT_DROP, NOT the #9
## WorkoutPhase.SET_ACTIVE token). See design/gdd/onboarding-flow.md Formula 1.

const F := preload("res://src/core/onboarding_formulas.gd")
const CoordScript := preload("res://src/autoload/onboarding_coordinator.gd")


# --- Pure may_show terms ------------------------------------------------------

func test_all_terms_satisfied_shows() -> void:
	assert_true(F.may_show(F.STATE_COACHING, false, false, false),
		"COACHING + not latched + not critical + no other coach-mark → may_show true")


func test_dormant_state_never_shows() -> void:
	assert_false(F.may_show(F.STATE_DORMANT, false, false, false),
		"DORMANT → never show")


func test_latched_step_never_shows() -> void:
	assert_false(F.may_show(F.STATE_COACHING, true, false, false),
		"step already latched → never re-show (恰好一次)")


func test_workout_critical_never_shows() -> void:
	# AC-10 / EC-04 — Pillar 2 命脈: any workout-critical state defers the coach-mark.
	assert_false(F.may_show(F.STATE_COACHING, false, true, false),
		"AC-10: workout-critical → may_show false (coach-mark NEVER mid-set)")


func test_other_coachmark_visible_never_shows() -> void:
	assert_false(F.may_show(F.STATE_COACHING, false, false, true),
		"single-slot discipline: another coach-mark visible → defer")


# --- Coordinator WORKOUT_CRITICAL membership (B-1 — GSM-only, no SET_ACTIVE) ----

class FakeGSM:
	extends RefCounted
	enum GameState {BOOTING, DISCONNECTED, IDLE, WORKOUT_ACTIVE, REST_PERIOD, COMBAT_ACTIVE, BOSS_ENCOUNTER, LOOT_DROP, SUSPENDED}
	var state: int = GameState.IDLE
	func get_current_state() -> int:
		return state


## Build a coordinator with only the GSM seam set, NO _ready (we test the pure membership
## helper directly — no boot, no subscriptions). autofree handles the orphan Node.
func _coord_with_gsm(gsm) -> Node:
	var c = CoordScript.new()
	c._gsm = gsm
	autofree(c)
	return c


func test_three_gsm_states_are_workout_critical() -> void:
	var gsm := FakeGSM.new()
	var c := _coord_with_gsm(gsm)
	for s in [FakeGSM.GameState.WORKOUT_ACTIVE, FakeGSM.GameState.REST_PERIOD, FakeGSM.GameState.LOOT_DROP]:
		gsm.state = s
		assert_true(c._is_workout_critical(),
			"B-1: GSM GameState %d must be workout-critical (coach-mark defers)" % s)


func test_idle_is_not_workout_critical() -> void:
	var gsm := FakeGSM.new()
	var c := _coord_with_gsm(gsm)
	gsm.state = FakeGSM.GameState.IDLE
	assert_false(c._is_workout_critical(), "IDLE is a safe display window")
	gsm.state = FakeGSM.GameState.COMBAT_ACTIVE
	assert_false(c._is_workout_critical(), "COMBAT_ACTIVE is NOT in the WORKOUT_CRITICAL set (B-1 exact)")
