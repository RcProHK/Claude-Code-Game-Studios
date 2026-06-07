# PlatformDetect — Autoload position 3
#
# Status: PARTIAL — announce_aria gateway live (#21 G-LM-6, story 025);
#   mobile/desktop tier detection still pending (ADR-0001).
# Governing ADR: ADR-0001 Web Export Budget Caps (mobile vs desktop GPU/CPU tier detection)
# Forbidden Pattern Gateway: ALL `JavaScriptBridge.eval()` calls MUST route through this autoload.
#   CI lint: tools/ci/check_platform_detect_callers.gd
extends Node

## #21 G-LM-6 — DOM aria-live region id. Injected at BOOT (the live region must
## exist in the DOM before its first announcement or screen readers ignore it).
const ARIA_LIVE_DIV_ID: String = "godot-aria-live"

## Headless/test-observable announcement log (the web DOM write is invisible to
## GUT; native builds are a logged no-op — a11y announcements are web-only).
var _aria_announcements: Array[String] = []

## Whether the DOM live region was injected (web export only).
var _aria_region_injected: bool = false


func _ready() -> void:
	_inject_aria_live_region()


## #21 G-LM-6 — screen-reader announcement gateway (sole JavaScriptBridge
## caller — forbidden-pattern discipline). aria-live=assertive: the reveal
## announcement preempts; banners use their own role=status (polite) markup.
## Native/headless: append-log no-op.
##
## Usage: PlatformDetect.announce_aria("EPIC loot: Iron Blade,來自 boss 擊殺.")
func announce_aria(text: String) -> void:
	_aria_announcements.append(text)
	if not _aria_region_injected:
		return
	# textContent via JSON-escaped string — no HTML injection surface.
	JavaScriptBridge.eval(
		"var n=document.getElementById(%s); if(n){n.textContent=%s;}" % [
			JSON.stringify(ARIA_LIVE_DIV_ID), JSON.stringify(text),
		], true)


func get_aria_announcements() -> Array[String]:
	return _aria_announcements


## Boot-time injection — hidden assertive live region appended to <body>.
## VS-tier spike note (story 025): Godot 4.5+ ships AccessKit for native
## platforms; its web-export coverage is UNVERIFIED headless — the real-browser
## pass (AC-77 manual half, story 027) must check for double-announcement and,
## if the engine exposes its own tree, this DOM region becomes the single
## source (engine-side announcements off).
func _inject_aria_live_region() -> void:
	if not OS.has_feature("web"):
		return  # native/headless — gateway logs only
	JavaScriptBridge.eval(
		"if(!document.getElementById(%s)){" % JSON.stringify(ARIA_LIVE_DIV_ID) +
		"var d=document.createElement('div');" +
		"d.id=%s;" % JSON.stringify(ARIA_LIVE_DIV_ID) +
		"d.setAttribute('aria-live','assertive');" +
		"d.setAttribute('role','status');" +
		"d.style.cssText='position:absolute;width:1px;height:1px;overflow:hidden;clip:rect(0 0 0 0);';" +
		"document.body.appendChild(d);}", true)
	_aria_region_injected = true
