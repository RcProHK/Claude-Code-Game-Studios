# PlatformDetect — Autoload position 3
#
# Status: PARTIAL — announce_aria gateway live (#21 G-LM-6, story 025);
#   mobile/desktop tier detection still pending (ADR-0001).
# Governing ADR: ADR-0001 Web Export Budget Caps (mobile vs desktop GPU/CPU tier detection)
# Forbidden Pattern Gateway: ALL `JavaScriptBridge.eval()` calls MUST route through this autoload.
#   CI lint: tools/ci/check_platform_detect_callers.gd
extends Node

## #21 G-LM-6 — DOM aria-live region ids. Injected at BOOT (the live region must
## exist in the DOM before its first announcement or screen readers ignore it).
## Two regions (#24 G-LS-6 / AC-UX a11y, story 019): an ASSERTIVE region (errors,
## loot reveal — preempts) and a POLITE region (peripheral banner status — does NOT
## interrupt). Toggling aria-live on a single region is unreliable across SRs, so
## each politeness gets its own dedicated region.
const ARIA_LIVE_DIV_ID: String = "godot-aria-live"
const ARIA_LIVE_POLITE_DIV_ID: String = "godot-aria-live-polite"

## Headless/test-observable announcement log (the web DOM write is invisible to
## GUT; native builds are a logged no-op — a11y announcements are web-only).
var _aria_announcements: Array[String] = []
## Parallel politeness log (same index as _aria_announcements): "assertive" | "polite".
var _aria_politeness: Array[String] = []

## Whether the DOM live regions were injected (web export only).
var _aria_region_injected: bool = false


func _ready() -> void:
	_inject_aria_live_regions()


## #21 G-LM-6 / #24 story 019 — screen-reader announcement gateway (sole
## JavaScriptBridge caller — forbidden-pattern discipline). `assertive` (default,
## back-compat with #21/#22/#23 single-arg callers) preempts the SR; `assertive=false`
## routes to the polite region (banner status — peripheral, non-interrupting).
## Native/headless: append-log no-op.
##
## Usage: PlatformDetect.announce_aria("EPIC loot: Iron Blade.")            # assertive
##        PlatformDetect.announce_aria("連線已恢復.", false)                 # polite
func announce_aria(text: String, assertive: bool = true) -> void:
	_aria_announcements.append(text)
	_aria_politeness.append("assertive" if assertive else "polite")
	if not _aria_region_injected:
		return
	var div_id: String = ARIA_LIVE_DIV_ID if assertive else ARIA_LIVE_POLITE_DIV_ID
	# textContent via JSON-escaped string — no HTML injection surface.
	JavaScriptBridge.eval(
		"var n=document.getElementById(%s); if(n){n.textContent=%s;}" % [
			JSON.stringify(div_id), JSON.stringify(text),
		], true)


func get_aria_announcements() -> Array[String]:
	return _aria_announcements


## Politeness of each announcement (same index as get_aria_announcements()).
## "assertive" | "polite". Test surface for the #24 error-vs-banner routing contract.
func get_aria_politeness() -> Array[String]:
	return _aria_politeness


## Boot-time injection — two hidden live regions appended to <body>.
## VS-tier spike note (story 025): Godot 4.5+ ships AccessKit for native
## platforms; its web-export coverage is UNVERIFIED headless — the real-browser
## pass (AC-77 manual half, story 027) must check for double-announcement and,
## if the engine exposes its own tree, these DOM regions become the single
## source (engine-side announcements off).
func _inject_aria_live_regions() -> void:
	if not OS.has_feature("web"):
		return  # native/headless — gateway logs only
	_inject_one_region(ARIA_LIVE_DIV_ID, "assertive")
	_inject_one_region(ARIA_LIVE_POLITE_DIV_ID, "polite")
	_aria_region_injected = true


func _inject_one_region(div_id: String, politeness: String) -> void:
	JavaScriptBridge.eval(
		"if(!document.getElementById(%s)){" % JSON.stringify(div_id) +
		"var d=document.createElement('div');" +
		"d.id=%s;" % JSON.stringify(div_id) +
		"d.setAttribute('aria-live',%s);" % JSON.stringify(politeness) +
		"d.setAttribute('role','status');" +
		"d.style.cssText='position:absolute;width:1px;height:1px;overflow:hidden;clip:rect(0 0 0 0);';" +
		"document.body.appendChild(d);}", true)
