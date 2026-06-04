## Integration test — GymModeHud Story 006: silent-mode banner + audio-buffer gate + Formula 3
##
## Coverage:
##   AC-CR-6 — banner shows when audio locked + non-booting; hidden when unlocked (desktop)
##   AC-CR-7 — banner tap → unlock → dismiss flag; resume re-lock → never re-appears this session
##   AC-F3   — banner pulse alpha: t=0.5→0.8, t=1.5→0.7, period=0→no NaN, clamp ≤1.0, large t in range
##   AC-U-4  — focus_mode == FOCUS_NONE; reduce_motion → pulse amp 0
##   AC-EC-S5 — banner tap honored without #33 (unlock gesture never gated)
extends GutTest

const SUT := preload("res://src/ui/gym_mode_hud/gym_mode_hud.gd")


class _StubAudio:
	extends RefCounted
	signal audio_unlocked
	var _unlocked: bool = false
	func is_audio_unlocked() -> bool:
		return _unlocked
	func _do_unlock() -> void:  # canonical banner-tap unlock path (#4 L215)
		if _unlocked:
			return
		_unlocked = true
		audio_unlocked.emit()


func _make_sut(audio_unlocked: bool = false) -> SUT:
	var sut: SUT = SUT.new()
	var audio := _StubAudio.new()
	audio._unlocked = audio_unlocked
	sut._audio_manager = audio
	add_child_autofree(sut)
	# Leave BOOTING — banner only overlays non-Booting/non-Suspended states.
	sut._hud_state = sut._HudState.ACTIVE if audio_unlocked else sut._HudState.BANNER_GATE
	return sut


# ── AC-CR-6: banner visibility ──

func test_banner_shows_when_locked_and_not_booting() -> void:
	var sut := _make_sut(false)
	assert_true(sut.should_show_banner(),
		"AC-CR-6: banner shows when audio locked + non-booting")


func test_banner_hidden_when_unlocked_desktop() -> void:
	var sut := _make_sut(true)  # desktop: unlocked from boot
	assert_false(sut.should_show_banner(),
		"AC-CR-6/EC-S8: banner never appears when audio already unlocked (desktop)")


func test_banner_hidden_in_booting() -> void:
	var sut := _make_sut(false)
	sut._hud_state = sut._HudState.BOOTING
	assert_false(sut.should_show_banner(),
		"AC-CR-6: banner does not render during BOOTING")


func test_banner_hidden_in_suspended() -> void:
	var sut := _make_sut(false)
	sut._hud_state = sut._HudState.SUSPENDED
	assert_false(sut.should_show_banner(),
		"AC-CR-6: banner does not render during SUSPENDED")


# ── AC-CR-7: tap → dismiss → never re-appears ──

func test_banner_tap_unlocks_and_dismisses() -> void:
	var sut := _make_sut(false)
	sut._on_banner_tapped()
	assert_true(sut._banner_dismissed_this_session,
		"AC-CR-7: banner tap → unlock → dismissed flag set")
	assert_false(sut.should_show_banner(),
		"AC-CR-7: dismissed banner no longer shows")


func test_banner_never_reappears_after_relock() -> void:
	var sut := _make_sut(false)
	sut._on_banner_tapped()  # unlock + dismiss
	var audio := sut._audio_manager as _StubAudio
	audio._unlocked = false  # simulate a resume that re-locked audio
	assert_false(sut.should_show_banner(),
		"AC-CR-7: once dismissed this session, banner never re-appears even if re-locked")


# ── AC-F3: banner pulse alpha (pure static) ──

func test_f3_peak_at_half_period() -> void:
	assert_almost_eq(SUT.compute_banner_alpha(0.7, 0.1, 0.5, 2.0), 0.8, 0.001,
		"AC-F3: t=0.5 (quarter-period) → peak 0.8")


func test_f3_trough_at_three_quarter() -> void:
	assert_almost_eq(SUT.compute_banner_alpha(0.7, 0.1, 1.5, 2.0), 0.7, 0.001,
		"AC-F3: t=1.5 → trough 0.7")


func test_f3_period_zero_no_nan_livelock() -> void:
	var r: float = SUT.compute_banner_alpha(0.7, 0.1, 1.0, 0.0)
	assert_false(is_nan(r),
		"AC-F3/F3-A: pulse_period=0 → P=max(0,0.5)=0.5, no NaN (no livelock)")


func test_f3_clamps_to_one() -> void:
	# base 0.95 + amp 0.15 peak = 1.10 → clamp 1.0
	assert_lte(SUT.compute_banner_alpha(0.95, 0.15, 0.5, 2.0), 1.0,
		"AC-F3/F3-B: peak above 1.0 clamps to 1.0")


func test_f3_large_t_stays_in_range() -> void:
	# fmod keeps long-session t bounded → alpha within [base, base+amp]
	var r: float = SUT.compute_banner_alpha(0.7, 0.1, 3600.5, 2.0)
	assert_between(r, 0.7, 0.8001,
		"AC-F3: large t (3600.5s) fmod keeps alpha in [base, base+amp]")


# ── AC-U-4: focus mode + reduce_motion ──

func test_banner_focus_mode_is_focus_none() -> void:
	var sut := _make_sut(false)
	assert_eq(sut.get_banner_focus_mode(), 0,
		"AC-U-4: banner focus_mode == FOCUS_NONE (0) — one-tap, no hover/focus ring")


func test_reduce_motion_zeroes_pulse_amp() -> void:
	var sut := _make_sut(false)
	sut._reduce_motion = true
	assert_eq(sut.get_banner_pulse_amp(), 0.0,
		"AC-U-4: reduce_motion → banner pulse amp 0 (static)")
	sut._reduce_motion = false
	assert_almost_eq(sut.get_banner_pulse_amp(), 0.1, 0.0001,
		"AC-U-4: motion on → banner pulse amp restored")


# ── AC-EC-S5: banner tap honored without #33 ──

func test_banner_tap_honored_without_input_policy() -> void:
	var sut := _make_sut(false)
	# No #33 IInputPolicy wired — banner unlock tap must still be honored (never gated).
	sut._on_banner_tapped()
	var audio := sut._audio_manager as _StubAudio
	assert_true(audio.is_audio_unlocked(),
		"AC-EC-S5: banner tap unlocks even with no #33 is_input_permitted (gesture never gated)")
