extends GutTest
## Story 015: OnboardingConfig — the shipped .tres loads + validates, the 6 knobs carry the
## GDD defaults, integer-ms discipline holds, and the knob-interaction invariant
## (coach_auto_dismiss_sec ≪ coach_max_defer_sec) is enforced. See onboarding-flow.md Tuning Knobs.

const ConfigScript := preload("res://src/data/onboarding_config.gd")
const CONFIG_PATH := "res://assets/data/onboarding_config.tres"


func test_shipped_config_loads_and_validates() -> void:
	var cfg = load(CONFIG_PATH) as OnboardingConfig
	assert_not_null(cfg, "onboarding_config.tres must load as OnboardingConfig")
	assert_eq(cfg.validate(), "", "shipped config must be valid")


func test_six_knobs_carry_gdd_defaults() -> void:
	var cfg = load(CONFIG_PATH) as OnboardingConfig
	assert_almost_eq(cfg.coach_auto_dismiss_sec, 6.0, 0.001, "coach_auto_dismiss_sec default 6.0")
	assert_almost_eq(cfg.coach_max_defer_sec, 120.0, 0.001, "coach_max_defer_sec default 120.0")
	assert_almost_eq(cfg.coach_fade_sec, 0.25, 0.001, "coach_fade_sec default 0.25")
	assert_almost_eq(cfg.preview_duration_sec, 24.0, 0.001, "preview_duration_sec default 24.0")
	assert_true(cfg.preview_enabled, "preview_enabled default true")
	assert_true(cfg.coach_marks_enabled, "coach_marks_enabled default true")


func test_integer_ms_conversion() -> void:
	# Knob is float-sec; the coordinator converts to int ms once at load (Formula 2 discipline).
	var cfg = load(CONFIG_PATH) as OnboardingConfig
	assert_eq(int(cfg.coach_auto_dismiss_sec * 1000.0), 6000, "6.0s → 6000ms")
	assert_eq(int(cfg.coach_max_defer_sec * 1000.0), 120000, "120.0s → 120000ms")


func test_validate_rejects_dismiss_not_less_than_defer() -> void:
	# Knob-interaction invariant: auto-dismiss (single-card lifetime) must be ≪ max-defer.
	var cfg := ConfigScript.new()
	cfg.coach_auto_dismiss_sec = 12.0
	cfg.coach_max_defer_sec = 12.0  # equal → invalid (must be <)
	assert_ne(cfg.validate(), "", "validate must reject coach_auto_dismiss_sec >= coach_max_defer_sec")


func test_validate_rejects_out_of_range_knob() -> void:
	var cfg := ConfigScript.new()
	cfg.coach_fade_sec = 2.0  # out of [0.0, 0.6]
	assert_ne(cfg.validate(), "", "validate must reject out-of-range coach_fade_sec")
