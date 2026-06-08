## BannerStack — #24 ErrorBannerLayer sub-controller (story 003 scaffold → story 010 core).
##
## Driving GDD: design/gdd/login-gymsys-connection-ui.md Rules 5/6/7/8.
## Owner: LoginShellCoordinator (#24) — a coordinator-owned CHILD NODE under the
## ALWAYS ErrorBannerLayer (111), NOT a second autoload (Rule 1).
##
## Why a separate file (AC-01 / AC-35a): the banner-static-discipline grep (AC-35a —
## the banner has zero animation / zero audio / zero pulse) needs an unambiguous scope.
## This file deliberately contains NO AnimationPlayer / AudioStreamPlayer / pulse
## (Rule 8 — enforced by the AC-35b scene-tree assertion); the legitimate animated shell
## cross-fade lives in shell_transitions.gd, never here.
##
## STORY 010 SCOPE: the 4-system error consumer (Rule 5 — #3/#8/#11/#12, zero
## silent-swallow), source-first severity dispatch (Rule 6 + error_severity_map.tres,
## UNMAPPED default-deny), and the deterministic total-order main-slot comparator
## (severity, arrival_sequence) — `sort_custom` is 4.6-unstable and StringName sorts by
## pointer, so the slot is chosen by a monotonic int counter + String-ified compares
## (reference_stringname_sort). Dedupe / "+N" collapse / DISCONNECTED priority /
## two-layer independence = story 011.
extends Node

const ESM := preload("res://src/ui/login_shell/error_severity_map.gd")

## Monotonic arrival counter — the deterministic same-severity tie-break (Rule 7).
var _arrival_sequence: int = 0
## Banner entries: {source, error_code, key, severity, arrival_sequence, dedupe_key}.
var _entries: Array = []
## Severity authority (default = script defaults; coordinator injects the .tres instance).
var _severity_map = ESM.new()


## Inject the data-driven .tres-loaded ErrorSeverityMap (coordinator does this at boot).
func set_severity_map(map) -> void:
	if map != null:
		_severity_map = map


## Connection-status dedupe key (story 011 — single DISCONNECTED status banner).
const DISCONNECTED_DEDUPE_KEY: String = "STATUS|DISCONNECTED"


## The 4-system error consumer entry point (Rule 5 — every error edge terminates in a
## visible entry; zero silent-swallow). Classifies SOURCE-FIRST, enqueues, returns the
## severity. error_code is ignored for #8/#11/#12 (source → FEATURE_DEGRADED). DEDUPE
## (story 011 / AC-34): a re-fire of the same (source, error_code, key) does NOT add a
## second entry — it refreshes the existing entry's timestamp + TTL window (so「+N」is
## not inflated). `now_ms` is the injected arrival clock (banner t_banner_start for F2).
func dispatch_error(source: int, error_code: StringName, key: Variant, now_ms: int = 0) -> int:
	var dkey: String = _dedupe_key(source, error_code, key)
	var existing: Dictionary = _find_by_dedupe(dkey)
	if not existing.is_empty():
		existing["timestamp_ms"] = now_ms
		existing["t_banner_start_ms"] = now_ms  # re-fire refreshes the TTL window
		return existing["severity"]
	var severity: int = _severity_map.classify_source_first(source, error_code)
	_arrival_sequence += 1
	_entries.append({
		"source": source,
		"error_code": error_code,
		"key": key,
		"severity": severity,
		"arrival_sequence": _arrival_sequence,
		"dedupe_key": dkey,
		"timestamp_ms": now_ms,
		"t_banner_start_ms": now_ms,
	})
	return severity


## Set / clear the DISCONNECTED connection-status banner (story 011 / AC-33). It ranks
## above every error class (Rule 7 ladder). A single status banner — re-asserting while
## active just refreshes its timestamp; clearing removes it so the next-highest error
## rises back into the main slot (EC-B4).
func set_disconnected_status(active: bool, now_ms: int = 0) -> void:
	var existing: Dictionary = _find_by_dedupe(DISCONNECTED_DEDUPE_KEY)
	if active:
		if existing.is_empty():
			_arrival_sequence += 1
			_entries.append({
				"source": -1,
				"error_code": &"",
				"key": null,
				"severity": ESM.Severity.DISCONNECTED,
				"arrival_sequence": _arrival_sequence,
				"dedupe_key": DISCONNECTED_DEDUPE_KEY,
				"timestamp_ms": now_ms,
				"t_banner_start_ms": now_ms,
			})
		else:
			existing["timestamp_ms"] = now_ms
	elif not existing.is_empty():
		_entries.erase(existing)


## Find an entry by dedupe_key (returns the live dict by reference, or {} if absent).
## Dictionaries in a Godot Array are reference-shared, so mutating the result mutates
## the stored entry.
func _find_by_dedupe(dkey: String) -> Dictionary:
	for e: Dictionary in _entries:
		if e["dedupe_key"] == dkey:
			return e
	return {}


## Dedupe key = (signal_source, error_code, key/id). StringName → String BEFORE any
## compare (reference_stringname_sort: a StringName array sorts by pointer, not text;
## a String-keyed identity is stable and text-correct). Story 011 uses this for dedupe.
func _dedupe_key(source: int, error_code: StringName, key: Variant) -> String:
	var key_str: String = "" if key == null else String(key)
	return "%d|%s|%s" % [source, String(error_code), key_str]


## The banner occupying the single visible slot (max_visible = 1, Rule 7): the entry
## outranking all others by (priority_weight desc, arrival_sequence asc). {} if empty.
func main_slot() -> Dictionary:
	if _entries.is_empty():
		return {}
	var best: Dictionary = _entries[0]
	for e: Dictionary in _entries:
		if _outranks(e, best):
			best = e
	return best


## Total order: higher severity weight wins; ties broken by EARLIER arrival (the
## first-arrived same-severity banner holds the slot — deterministic across runs).
func _outranks(a: Dictionary, b: Dictionary) -> bool:
	var wa: int = ESM.priority_weight(a["severity"])
	var wb: int = ESM.priority_weight(b["severity"])
	if wa != wb:
		return wa > wb
	return a["arrival_sequence"] < b["arrival_sequence"]


## "+N" overflow count (everything not in the main slot). Full collapse/dedupe = story 011.
func overflow_count() -> int:
	return maxi(0, _entries.size() - 1)


func entries() -> Array:
	return _entries


func count() -> int:
	return _entries.size()


func clear() -> void:
	_entries.clear()
