extends GutTest
## Story 006 — Formula 1 Rate-Limited Countdown. Covers AC-16 / AC-17 / AC-18 +
## display format + retry_after<=0 immediate re-enable.
##
## GDD: design/gdd/login-gymsys-connection-ui.md Formula 1. Pure logic, injected
## clock (now_ms) — never Time.get_ticks_msec() (AC-51).

const F := preload("res://src/ui/login_shell/shell_formulas.gd")

## AC examples are in seconds; the formula takes integer-ms (intro discipline).
func _ms(seconds: float) -> int:
	return int(seconds * 1000.0)


# --- AC-16: countdown value ---

func test_ac16_countdown_value_at_t115() -> void:
	# retry_after=30, t_start=100s, now=115s → 30 - 15 = 15.
	assert_eq(F.display_seconds(30, _ms(100), _ms(115)), 15, "AC-16: display_seconds == 15")


func test_ac16_ceil_partial_second_rounds_up() -> void:
	# t=129.5 → remaining 0.5s → ceil → 1.
	assert_eq(F.display_seconds(30, _ms(100), _ms(129.5)), 1, "ceil(0.5s) → 1")
	# t=129.999 → remaining 1ms → ceil → 1.
	assert_eq(F.display_seconds(30, _ms(100), _ms(129.999)), 1, "ceil(1ms) → 1")


# --- AC-17: re-enable boundary ---

func test_ac17_reenable_at_exact_boundary() -> void:
	# t=130 exact → remaining 0 → display 0 + submit enabled.
	assert_eq(F.display_seconds(30, _ms(100), _ms(130)), 0, "AC-17: display_seconds == 0 at t=130")
	assert_true(F.submit_enabled(30, _ms(100), _ms(130)), "AC-17: submit_enabled == true")


func test_ac17_still_disabled_just_before_boundary() -> void:
	assert_false(F.submit_enabled(30, _ms(100), _ms(129.9)), "still disabled at t=129.9")


# --- AC-18: retry_after == 0 (and negative / absent) → immediate re-enable, no copy ---

func test_ac18_retry_after_zero_immediate_reenable() -> void:
	assert_eq(F.display_seconds(0, _ms(100), _ms(100)), 0, "AC-18: retry_after==0 → 0")
	assert_true(F.submit_enabled(0, _ms(100), _ms(100)), "AC-18: immediate re-enable")


func test_ac18_retry_after_negative_treated_as_zero() -> void:
	assert_eq(F.display_seconds(-5, _ms(100), _ms(100)), 0, "negative retry_after → 0 (N1)")


# --- Display format: inline vs m:ss ---

func test_format_inline_under_100() -> void:
	assert_eq(F.format_countdown(15), "等 15 秒再試", "N≤99 inline")
	assert_eq(F.format_countdown(99), "等 99 秒再試", "N=99 inline boundary")


func test_format_mss_at_and_above_100() -> void:
	assert_eq(F.format_countdown(100), "等 1:40 再試", "N=100 → m:ss")
	assert_eq(F.format_countdown(3600), "等 60:00 再試", "r=3600 upper bound → 60:00")


func test_format_mss_zero_pads_seconds() -> void:
	# 125s → 2:05 (ss zero-padded).
	assert_eq(F.format_countdown(125), "等 2:05 再試", "ss zero-padded")
