## #22 F2/F4 + Format Table + font floor — unit suite (story 005; GDD AC-05/06/08/09/43a).
extends GutTest

const F := preload("res://src/ui/character_screen/char_screen_formulas.gd")


## --- AC-05: F2 quantize vectors + ingestion guard (sd B-2) ---

func test_ac05_quantize_golden_vectors() -> void:
	var cases := [
		[0.6789, 68, 0.68, "68%"],
		[0.999, 100, 1.0, "100%"],
		[-0.5, 0, 0.0, "0%"],
		[1.7, 100, 1.0, "100%"],
	]
	for c in cases:
		var q: Dictionary = F.quantize(c[0])
		assert_eq(q.pct, c[1], "pct for %s" % c[0])
		assert_almost_eq(q.store, c[2], 0.000001, "store for %s" % c[0])
		assert_eq(q.label, c[3], "label for %s" % c[0])


func test_ac05_ingestion_guard_nan_inf_string() -> void:
	for bad in [NAN, INF, -INF, "abc", null, [1, 2]]:
		var q: Dictionary = F.quantize(bad)
		assert_eq(q.pct, 100, "corrupt input → default 1.0 →「100%%」(零 trap):%s" % str(bad))
		assert_almost_eq(q.store, 1.0, 0.000001)
		assert_eq(q.label, "100%")


func test_f2_grid_bijectivity_roundtrip() -> void:
	# 101 點 grid:store → re-quantize → 同一 pct(label↔stored 一一對應)
	for pct in range(0, 101):
		var store: float = float(pct) / 100.0
		var q: Dictionary = F.quantize(store)
		assert_eq(q.pct, pct, "round-trip pct %d" % pct)


## --- AC-06: keyboard clamp 唔 wrap ---

func test_ac06_keyboard_step_clamps() -> void:
	assert_eq(F.keyboard_step(100, 1), 100, "100 撳 + → clamp no-op")
	assert_eq(F.keyboard_step(0, -1), 0, "0 撳 − → clamp no-op")
	assert_eq(F.keyboard_step(55, 1), 65)
	assert_eq(F.keyboard_step(95, 1), 100, "95+10 → clamp 100")
	assert_eq(F.keyboard_step(5, -1), 0, "5−10 → clamp 0")


## --- AC-08: F4 badge predicate vectors ---

func test_ac08_badge_vectors() -> void:
	assert_false(F.badge_visible(90.4, 90.0), "{90.4,90.0} → disp 90==90 → hidden")
	assert_true(F.badge_visible(90.6, 90.0), "{90.6,90.0} → 91>90 → visible")
	assert_eq(F.badge_text(90.6, 90.0), "+90 / +91(受真身上限約束)")
	assert_false(F.badge_visible(0.0, 0.0), "{0,0} → hidden(「+0」row 照 render 係 render 層)")
	# half-away 驗證 vector(binary-exact .5 — golden vector 紀律)
	assert_true(F.badge_visible(90.5, 89.5), "{90.5,89.5} → 91 vs 90 → visible")


## --- AC-09: Format Table golden vectors ---

func test_ac09_format_table() -> void:
	assert_eq(F.fmt_int(47.0), "47", "STR")
	assert_eq(F.fmt_int(1240.0), "1240", "max_hp")
	assert_eq(F.fmt_int(96.4), "96", "attack_power roundi")
	assert_eq(F.fmt_int(210.4), "210", "move_speed")
	assert_eq(F.fmt_pct(0.07), "7%", "crit_chance")
	assert_eq(F.fmt_pct(0.5), "50%", "crit ceiling")
	assert_eq(F.fmt_pct(0.0), "0%", "crit floor")


func test_ac09_formatter_for_routing() -> void:
	assert_eq(F.formatter_for(&"crit_chance").call(0.07), "7%")
	assert_eq(F.formatter_for(&"attack_power").call(96.4), "96")


## --- AC-43a: CJK font floor (theme guard — theme resource 落地後擴 introspect) ---

func test_ac43a_font_floor_clamp() -> void:
	assert_eq(F.CJK_FONT_FLOOR_PX, 12, "accessibility-requirements L87 floor")
	assert_eq(F.clamp_font_size(8), 12, "永不細過 floor")
	assert_eq(F.clamp_font_size(12), 12)
	assert_eq(F.clamp_font_size(14), 14, "高過 floor 不變")
