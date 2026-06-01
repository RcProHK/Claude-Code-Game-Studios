# ParticleSystemWrapper — Story 005: mobile UA detection (boot-cached, conservative).
#
# Coverage:
#   AC-11 — classify_ua() table + conservative default (FR-3) + boot-cache immutability
#           (provider read once, never re-read on play) + debug-only override.
#
# classify_ua() is a pure static func — the UA table is tested with no JSBridge (which
# is null in headless). The wrapper never calls JavaScriptBridge.eval directly (ADR-0001
# forbids it outside platform_detect.gd); UA comes from the injectable _ua_provider seam.
#
# SPEC NOTE: the GDD Rule 10 code block (authoritative) returns false for an
# unrecognised *valid* string (its final `return false`) — so windows/linux AND an
# unknown/empty string classify as DESKTOP. Only null / non-String classify as MOBILE
# (FR-3). The Rule 10 *table* loosely says "fallthrough → MOBILE", which contradicts the
# code for the unknown-valid-string case. We implement the locked code and flag the
# tension for the designer (see story Completion Notes).
extends GutTest

const PSW := preload("res://src/autoload/particle_system_wrapper.gd")


class _StubNode:
	extends Node
	var emitting: bool = false
	var amount: int = 0
	func restart(_keep_seed: bool = false) -> void:
		pass


## Build a SUT with an injected UA provider. _ready() runs synchronously on add_child,
## caching _is_mobile from the provider.
func _make_sut(provider: Callable) -> Object:
	var sut = PSW.new()
	sut._node_factory = func() -> Node: return _StubNode.new()
	sut._ua_provider = provider
	add_child_autofree(sut)
	return sut


# ---------------------------------------------------------------------------
# AC-11 — classify_ua() table (pure static)
# ---------------------------------------------------------------------------

func test_classify_ua_ios_devices_are_mobile() -> void:
	assert_true(PSW.classify_ua("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0)", 5), "iPhone → MOBILE")
	assert_true(PSW.classify_ua("iPod touch", 5), "iPod → MOBILE")
	assert_true(PSW.classify_ua("Mozilla/5.0 (iPad; CPU OS 12_0)", 5), "iPad (legacy) → MOBILE")


func test_classify_ua_ipad_as_mac_is_mobile() -> void:
	assert_true(PSW.classify_ua("Mozilla/5.0 (Macintosh; Intel Mac OS X)", 5),
		"AC-11: Macintosh + maxTouchPoints>1 (iPadOS 13+) → MOBILE")


func test_classify_ua_real_mac_is_desktop() -> void:
	assert_false(PSW.classify_ua("Mozilla/5.0 (Macintosh; Intel Mac OS X)", 0),
		"AC-11: Macintosh + maxTouchPoints==0 (real Mac) → DESKTOP")


func test_classify_ua_android_variants_are_mobile() -> void:
	assert_true(PSW.classify_ua("Mozilla/5.0 (Linux; Android 13; Pixel) Mobile", 5), "Android phone → MOBILE")
	assert_true(PSW.classify_ua("Mozilla/5.0 (Linux; Android 13; Tablet)", 5),
		"AC-11: Android tablet (no 'mobile') → MOBILE (conservative fallthrough on 'android')")


func test_classify_ua_desktop_os_are_desktop() -> void:
	assert_false(PSW.classify_ua("Mozilla/5.0 (Windows NT 10.0; Win64)", 0), "Windows → DESKTOP")
	assert_false(PSW.classify_ua("Mozilla/5.0 (X11; Linux x86_64)", 0), "Linux → DESKTOP")


func test_classify_ua_null_and_nonstring_are_conservative_mobile() -> void:
	assert_true(PSW.classify_ua(null, 0), "AC-11: null UA → MOBILE (FR-3 conservative)")
	assert_true(PSW.classify_ua(12345, 0), "AC-11: non-String UA → MOBILE (FR-3 conservative)")


func test_classify_ua_unknown_valid_string_is_desktop_per_locked_code() -> void:
	# GDD Rule 10 code block's final `return false`: an unrecognised *valid* string
	# (incl. empty) is DESKTOP. (Table's loose "fallthrough → MOBILE" applies to
	# null/non-String only — flagged in Completion Notes.)
	assert_false(PSW.classify_ua("", 0), "AC-11: empty string → DESKTOP (locked code)")
	assert_false(PSW.classify_ua("SomeUnknownBrowser/1.0", 0), "AC-11: unknown valid UA → DESKTOP (locked code)")


# ---------------------------------------------------------------------------
# AC-11 — boot-cache immutability
# ---------------------------------------------------------------------------

func test_ua_provider_read_once_at_boot_and_cached() -> void:
	var count := {"n": 0}
	var sut = _make_sut(func() -> Variant:
		count["n"] += 1
		return {"ua": "iPhone", "max_touch": 5})
	assert_true(sut._is_mobile, "AC-11: iPhone UA boot-cached → mobile")
	assert_eq(count["n"], 1, "AC-11: provider read exactly once at boot")
	# Swap to a desktop provider, then play repeatedly — cache must NOT be re-read.
	sut._ua_provider = func() -> Variant:
		count["n"] += 1
		return {"ua": "Windows NT", "max_touch": 0}
	for i in 5:
		sut.play(PSW.PresetId.HIT_LIGHT, Vector2(i, i), 1.0)
	assert_true(sut._is_mobile, "AC-11: _is_mobile stays the boot-cached value")
	assert_eq(count["n"], 1, "AC-11: provider NOT re-read on play() (cached at boot)")


func test_provider_returning_null_is_conservative_mobile() -> void:
	var sut = _make_sut(func() -> Variant: return null)
	assert_true(sut._is_mobile, "AC-11: provider returning null → MOBILE (FR-3 conservative)")


# ---------------------------------------------------------------------------
# AC-11 — debug-only override
# ---------------------------------------------------------------------------

func test_set_mobile_override_honored_in_debug_only() -> void:
	var sut = _make_sut(func() -> Variant: return {"ua": "Windows NT", "max_touch": 0})
	assert_false(sut._is_mobile, "desktop UA → not mobile before override")
	sut.set_mobile_override(true)
	if OS.is_debug_build():
		assert_true(sut._is_mobile, "AC-11: debug build honors set_mobile_override(true)")
	else:
		assert_false(sut._is_mobile, "AC-11: production build — override is a no-op")
