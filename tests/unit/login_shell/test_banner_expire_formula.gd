extends GutTest
## Story 007 — Formula 2 Banner Auto-Expire (strict-< boundary). Covers
## AC-19 / AC-19b / AC-20.
##
## GDD: Formula 2. banner_visible = (now - start) < ttl [STRICT <]. Persistent
## classes (ttl <= 0 sentinel) never auto-expire. Injected clock (now_ms).

const F := preload("res://src/ui/login_shell/shell_formulas.gd")

func _ms(seconds: float) -> int:
	return int(seconds * 1000.0)


# --- AC-19: TRANSIENT/notice visible then expires ---

func test_ac19_visible_before_ttl() -> void:
	# drain ✓ @ t_b=200, TTL=2.0; t=201.5 → 1.5 < 2.0 → visible.
	assert_true(F.banner_visible(_ms(201.5), _ms(200), 2.0), "AC-19: visible at t=201.5")


func test_ac19_gone_after_ttl() -> void:
	# t=202.1 → 2.1 < 2.0 false → gone.
	assert_false(F.banner_visible(_ms(202.1), _ms(200), 2.0), "AC-19: gone at t=202.1")


# --- AC-19b: strict-< boundary ---

func test_ac19b_exact_boundary_is_not_visible() -> void:
	# t=202.0 exact → 2.0 < 2.0 false (STRICT <).
	assert_false(F.banner_visible(_ms(202.0), _ms(200), 2.0), "AC-19b: exact boundary NOT visible (strict <)")


func test_ac19b_one_ms_before_boundary_visible() -> void:
	assert_true(F.banner_visible(_ms(200) + 1999, _ms(200), 2.0), "1ms before boundary still visible")


# --- AC-20: TRANSIENT expires but persistent class is unaffected ---

func test_ac20_transient_expires_after_5s() -> void:
	# NOT_READY TRANSIENT TTL=5.0, t past 5s → gone.
	assert_false(F.banner_visible(_ms(206.0), _ms(200), 5.0), "AC-20: TRANSIENT expires past TTL")


func test_ac20_persistent_class_never_expires() -> void:
	# ONGOING (READ_ONLY_FILESYSTEM) = persistent sentinel ttl <= 0 → always visible,
	# even far past any TRANSIENT TTL (F2 does not govern persistent classes).
	assert_true(F.banner_visible(_ms(9999.0), _ms(200), F.PERSISTENT_TTL_SENTINEL),
		"AC-20: ONGOING/WIPE/FEATURE_DEGRADED persistent — not affected by F2")
	assert_true(F.banner_visible(_ms(9999.0), _ms(200), -1.0), "negative ttl also persistent")


# --- Per-banner timer: independent start times ---

func test_per_banner_timers_are_independent() -> void:
	# Two TRANSIENT banners with different start times expire independently.
	assert_true(F.banner_visible(_ms(203.0), _ms(202), 2.0), "banner B (start 202) still visible at 203")
	assert_false(F.banner_visible(_ms(203.0), _ms(200), 2.0), "banner A (start 200) already expired at 203")
