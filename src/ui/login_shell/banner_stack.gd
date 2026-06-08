## BannerStack — #24 ErrorBannerLayer sub-controller (story 003 scaffold).
##
## Driving GDD: design/gdd/login-gymsys-connection-ui.md Rules 7/8.
## Owner: LoginShellCoordinator (#24) — a coordinator-owned CHILD NODE under the
## ALWAYS ErrorBannerLayer (111), NOT a second autoload (Rule 1).
##
## Why a separate file (AC-01 / AC-35a): the banner-static-discipline grep
## (AC-35a — the banner has zero animation / zero audio / zero pulse) needs an
## unambiguous scope. Keeping the banner host in its own file lets the grep target
## banner_stack.gd precisely and never false-positive the LEGITIMATE state-transition
## cross-fade tween (that lives in shell_transitions.gd). AC-35a CI must also assert
## this file EXISTS — a missing file ≠ no-match (grepping a non-existent path is a
## phantom pass).
##
## SCAFFOLD SCOPE: holds an ordered list only. Severity classification, dedup key
## ((signal_source, error_code, key/id)), priority ordering
## (DISCONNECTED > ONGOING > WIPE > FEATURE_DEGRADED > TRANSIENT > notification),
## single-slot (max_visible = 1) collapse + "+N" counter, and the deterministic
## (severity_class, arrival_sequence) total-order comparator are ALL story 010.
## This file deliberately contains NO AnimationPlayer / AudioStreamPlayer / pulse
## (Rule 8 — enforced by the AC-35b scene-tree assertion).
extends Node

## Monotonic arrival counter (story 010 total-order tie-break — reference_stringname_sort:
## never sort StringName by pointer; tie-break uses this integer). Scaffold owns the
## field so the seam exists; ordering logic lands in story 010.
var _arrival_sequence: int = 0
## Enqueued banner records (story 010 adds severity sort + single-slot collapse).
var _banners: Array = []


## Scaffold enqueue — appends a banner record with its arrival sequence. NO severity
## sort, NO dedup (story 010). Returns the assigned arrival sequence.
func enqueue(banner: Dictionary) -> int:
	_arrival_sequence += 1
	var record: Dictionary = banner.duplicate()
	record["arrival_sequence"] = _arrival_sequence
	_banners.append(record)
	return _arrival_sequence


## Scaffold — current banner count (story 010 adds single-slot + "+N" collapse).
func count() -> int:
	return _banners.size()


## Scaffold — clears all banners.
func clear() -> void:
	_banners.clear()
