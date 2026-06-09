extends GutTest
## Story 019 — a11y (announce_aria politeness) + AC-UX layout assertions.
##
## Covers:
##   AC-UX-2 — R-Default banner height/rect (clamp(round(0.10×H),44,72), bottom-anchored full-width)
##   AC-UX-3 — R-Glyph (yield) rect top-right + zero overlap with #20 Z5 REST panel
##   AC-UX-5 — entry card three-state alpha (1.0 / 0.55 / hidden)
##   AC-UX-8 — touch-target floors (≥44px / ≥48px entry card)
##   AC-UX-9 — cross-fade ≤ SHELL_FADE_SEC (0.25s)
##   announce_aria — error=assertive / banner=polite via PlatformDetect seam; no focus steal
##   color independence — distinct non-color glyph per severity class
##
## Spec: design/ux/login-gymsys-connection-ui.md (Banner Region Pixel Pin + AC-UX + a11y).

const ACUXLayout := preload("res://src/ui/login_shell/acux_layout.gd")
const ESM := preload("res://src/ui/login_shell/error_severity_map.gd")
const ShellFormulas := preload("res://src/ui/login_shell/shell_formulas.gd")
const CoordinatorScript := preload("res://src/autoload/login_shell_coordinator.gd")
const GSMScript := preload("res://src/autoload/game_state_machine.gd")
const FADE: float = CoordinatorScript.SHELL_FADE_MS

const G_IDLE := GSMScript.GameState.IDLE
const G_WORKOUT := GSMScript.GameState.WORKOUT_ACTIVE


class MockGsm:
	extends Node
	signal state_changed(from_state, to_state, payload)
	var current_state: int = 2
	func get_current_state() -> int: return current_state
	func connect_for_initial_state(callable: Callable) -> void:
		state_changed.connect(callable)
		callable.call(current_state, current_state, null)


class MockScreen:
	extends Node
	var can_open_value: bool = true
	func can_open() -> bool: return can_open_value


## Records every announce_aria call so the politeness routing is observable.
class MockPlatform:
	extends Node
	var calls: Array[Dictionary] = []
	func announce_aria(text: String, assertive: bool = true) -> void:
		calls.append({"text": text, "assertive": assertive})


var _cs: MockScreen
var _inv: MockScreen
var _platform: MockPlatform


func _make(gsm_state: int) -> Node:
	var gsm := MockGsm.new()
	gsm.current_state = gsm_state
	_cs = MockScreen.new()
	_inv = MockScreen.new()
	_platform = MockPlatform.new()
	add_child_autofree(gsm)
	add_child_autofree(_cs)
	add_child_autofree(_inv)
	add_child_autofree(_platform)
	var c: Node = CoordinatorScript.new()
	c._gsm = gsm
	c._character_screen = _cs
	c._inventory_ui = _inv
	c._platform = _platform
	add_child_autofree(c)
	for _i in range(8):
		c.advance(FADE)
	return c


# ---- AC-UX-2: banner region height/rect ----

func test_acux2_banner_height_640_is_64() -> void:
	# round(0.10 * 640) = 64; within [44, 72] → 64.
	assert_eq(ACUXLayout.banner_default_height(640), 64, "AC-UX-2: 640H → 64px")


func test_acux2_banner_height_560_is_56() -> void:
	assert_eq(ACUXLayout.banner_default_height(560), 56, "AC-UX-2: 560H → 56px")


func test_acux2_banner_height_tall_clamps_to_72() -> void:
	# round(0.10 * 900) = 90 → clamps to the 72 peripheral ceiling.
	assert_eq(ACUXLayout.banner_default_height(900), 72, "AC-UX-2: tall viewport → 72px ceiling")


func test_acux2_small_viewport_44px_floor_wins() -> void:
	# H=400 landscape: round(40)=40 < 44 → the hard a11y touch floor wins (accepts >10%).
	assert_eq(ACUXLayout.banner_default_height(400), 44, "AC-UX-2: 0.10×H<44 → 44px floor wins")


func test_acux2_banner_rect_bottom_anchored_full_width() -> void:
	var r: Rect2 = ACUXLayout.banner_default_rect(360, 640)
	assert_eq(r.position.x, 16.0, "full-width left inset 16")
	assert_eq(r.size.x, 328.0, "full-width = W − 2×16")
	# bottom edge = viewport bottom − 16 safe inset.
	assert_eq(r.position.y + r.size.y, 624.0, "bottom-anchored at H−16")
	assert_eq(r.size.y, 64.0, "height matches AC-UX-2 formula")


# ---- AC-UX-3: yield glyph rect + zero overlap with Z5 REST panel ----

func test_acux3_glyph_rect_top_right_16x16() -> void:
	var g: Rect2 = ACUXLayout.glyph_rect(360)
	assert_eq(g.position, Vector2(328.0, 16.0), "R-Glyph at x=W−32, y=16")
	assert_eq(g.size, Vector2(16.0, 16.0), "R-Glyph is 16×16")


func test_acux3_glyph_disjoint_from_rest_panel() -> void:
	# Z5 REST panel = bottom slide-up (representative bottom-half rect). The top-right
	# glyph must have ZERO tap-target overlap with it.
	var glyph: Rect2 = ACUXLayout.glyph_rect(360)
	var z5_rest_panel := Rect2(0.0, 420.0, 360.0, 220.0)  # bottom slide-up
	assert_true(ACUXLayout.rects_disjoint(glyph, z5_rest_panel), "AC-UX-3: R-Glyph ∩ Z5 == ∅")


func test_acux3_rects_disjoint_detects_overlap() -> void:
	# Sanity: an overlapping pair is NOT disjoint (the predicate is not vacuously true).
	var a := Rect2(0.0, 0.0, 100.0, 100.0)
	var b := Rect2(50.0, 50.0, 100.0, 100.0)
	assert_false(ACUXLayout.rects_disjoint(a, b), "overlapping rects → not disjoint")


# ---- AC-UX-5: entry card three-state alpha ----

func test_acux5_entry_enabled_alpha_1() -> void:
	var c := _make(G_IDLE)
	assert_true(c.is_entry_visible(), "entry visible in SHELL_IDLE")
	assert_eq(c.get_entry_card_alpha(&"character_screen"), 1.0, "AC-UX-5: enabled → a=1.0")


func test_acux5_can_open_false_race_alpha_055() -> void:
	var c := _make(G_IDLE)
	_inv.can_open_value = false
	assert_eq(c.get_entry_card_alpha(&"inventory"), 0.55, "AC-UX-5: can_open false race → 0.55 (still tappable)")


func test_acux5_workout_hides_entry() -> void:
	var c := _make(G_WORKOUT)
	assert_false(c.is_entry_visible(), "AC-UX-5: workout state → entry hidden (not rendered)")


# ---- AC-UX-8: touch-target floors ----

func test_acux8_touch_floor_constants() -> void:
	assert_eq(ACUXLayout.MIN_TOUCH_PX, 44, "AC-UX-8: interactive ≥44px")
	assert_eq(ACUXLayout.MIN_ENTRY_CARD_PX, 48, "AC-UX-8: entry card ≥48px")


func test_acux8_meets_touch_floor() -> void:
	assert_true(ACUXLayout.meets_touch_floor(44), "44px meets the interactive floor")
	assert_false(ACUXLayout.meets_touch_floor(43), "43px fails the interactive floor")
	assert_true(ACUXLayout.meets_touch_floor(48, true), "48px meets the entry-card floor")
	assert_false(ACUXLayout.meets_touch_floor(44, true), "44px fails the ≥48px entry-card floor")


# ---- AC-UX-9: cross-fade budget ----

func test_acux9_fade_within_budget() -> void:
	assert_true(ACUXLayout.fade_within_budget(ShellFormulas.SHELL_FADE_SEC), "AC-UX-9: default fade within budget")
	assert_true(ShellFormulas.SHELL_FADE_SEC <= 0.25, "AC-UX-9: SHELL_FADE_SEC ≤ 0.25s")
	assert_false(ACUXLayout.fade_within_budget(0.26), "0.26s exceeds the budget")


# ---- announce_aria: error=assertive / banner=polite ----

func test_announce_inline_error_is_assertive() -> void:
	var c := _make(G_IDLE)
	c._aria_log.clear()
	_platform.calls.clear()
	c._claim_pending = true
	c.notify_claim_result(&"invalid_credentials")
	assert_eq(c.get_aria_log().size(), 1, "one announcement on claim deny")
	assert_eq(c.get_aria_log()[0]["politeness"], "assertive", "inline error → assertive")
	assert_eq(_platform.calls.size(), 1, "routed through PlatformDetect seam")
	assert_true(_platform.calls[0]["assertive"], "seam called with assertive=true")


func test_announce_banner_status_is_polite() -> void:
	var c := _make(G_IDLE)
	c._aria_log.clear()
	_platform.calls.clear()
	c._on_persistence_error("QUOTA_EXHAUSTED", "streak.x")
	assert_eq(c.get_aria_log()[-1]["politeness"], "polite", "peripheral banner → polite")
	assert_eq(_platform.calls[-1]["assertive"], false, "seam called with assertive=false")


func test_feature_degraded_error_is_polite() -> void:
	var c := _make(G_IDLE)
	c._aria_log.clear()
	c._on_streak_error("PERSIST_LAYER_FAIL", "streak.streak_count")
	assert_eq(c.get_aria_log()[-1]["politeness"], "polite", "FEATURE_DEGRADED save banner → polite")


func test_rate_limited_inline_is_assertive() -> void:
	var c := _make(G_IDLE)
	c._aria_log.clear()
	c._claim_pending = true
	c.notify_claim_result(&"rate_limited", 30)
	assert_eq(c.get_aria_log()[-1]["politeness"], "assertive", "rate-limit inline → assertive")


func test_banner_does_not_steal_form_focus() -> void:
	var c := _make(G_IDLE)
	assert_false(c.banner_grabs_focus(), "banner appearing never grabs form focus (UX L493)")


func test_platform_seam_optional_no_crash() -> void:
	# announce must be a no-op (log only) when no platform seam is injected.
	var c := _make(G_IDLE)
	c._platform = null
	c._aria_log.clear()
	c.announce_banner_status("test")
	assert_eq(c.get_aria_log().size(), 1, "logged locally even with no platform seam")


# ---- real PlatformDetect seam: politeness lanes recorded (headless = log only) ----

const PlatformDetectScript := preload("res://src/autoload/platform_detect.gd")

func test_platform_announce_records_politeness() -> void:
	var p: Node = PlatformDetectScript.new()
	add_child_autofree(p)  # _ready() injects nothing headless (OS web feature absent)
	p.announce_aria("err", true)
	p.announce_aria("banner", false)
	assert_eq(p.get_aria_politeness(), ["assertive", "polite"], "politeness log mirrors calls")
	assert_eq(p.get_aria_announcements(), ["err", "banner"], "text log preserved")


func test_platform_announce_default_is_assertive() -> void:
	# Back-compat: existing #21/#22/#23 single-arg callers default to assertive.
	var p: Node = PlatformDetectScript.new()
	add_child_autofree(p)
	p.announce_aria("legacy single-arg")
	assert_eq(p.get_aria_politeness(), ["assertive"], "single-arg call defaults to assertive")


# ---- color independence ----

func test_color_independence_distinct_glyphs() -> void:
	var warning := ESM.severity_glyph(ESM.Severity.ONGOING)
	var slash := ESM.severity_glyph(ESM.Severity.DISCONNECTED)
	var check := ESM.severity_glyph(ESM.Severity.NOTIFICATION)
	var info := ESM.severity_glyph(ESM.Severity.TRANSIENT)
	assert_eq(warning, &"warning", "error class → ⚠ warning")
	assert_eq(slash, &"slash", "DISCONNECTED → ⃠ slash")
	assert_eq(check, &"check", "NOTIFICATION done → ✓ check")
	assert_eq(info, &"info", "TRANSIENT → ⓘ info")
	# 4 distinct non-color signals.
	var distinct := {warning: true, slash: true, check: true, info: true}
	assert_eq(distinct.size(), 4, "4 distinct non-color glyphs")


func test_every_severity_has_nonempty_glyph() -> void:
	for sev in [
		ESM.Severity.TRANSIENT, ESM.Severity.FEATURE_DEGRADED, ESM.Severity.WIPE,
		ESM.Severity.ONGOING, ESM.Severity.UNMAPPED, ESM.Severity.DISCONNECTED,
		ESM.Severity.NOTIFICATION,
	]:
		assert_ne(ESM.severity_glyph(sev), &"", "every severity resolves to a non-color glyph")
