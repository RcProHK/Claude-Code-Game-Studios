## ACUXLayout — #24 Story 019 layout / geometry formulas for the AC-UX assertions.
##
## Pure static functions: R-Default banner rect, R-Glyph (yield) rect, rect-disjoint
## predicate, touch-target floors, cross-fade budget. No node refs, no state — fully
## unit-testable headless (the real pixel placement happens in the story-015 login
## panel + ErrorBannerLayer scenes, which canvas/DOM make un-introspectable in GUT;
## these formulas are the measurable contract those scenes must honour).
##
## Driving spec: design/ux/login-gymsys-connection-ui.md — "Banner Region Pixel Pin"
##   (R-Default / R-Toast / R-Glyph) + AC-UX-2 / AC-UX-3 / AC-UX-8 / AC-UX-9.
## GDD: design/gdd/login-gymsys-connection-ui.md (UI Requirements + Motion Safety).
##
## NO class_name (preload-referenced) — same rationale as shell_formulas.gd /
## error_severity_map.gd (dodges global-class-cache staleness; reference_dev_environment).
extends RefCounted

const ShellFormulas := preload("res://src/ui/login_shell/shell_formulas.gd")

## Safe-zone inset (px). All shell coords inset ≥16 (UX Reference viewport §).
const SAFE_INSET_PX: int = 16

## Touch-target floors (WCAG AA / AC-UX-8). gameplay-critical interactive ≥44px;
## entry cards ≥48px (slightly larger — primary navigation affordance, UX L211/L261).
const MIN_TOUCH_PX: int = 44
const MIN_ENTRY_CARD_PX: int = 48

## R-Glyph (yield state) is a fixed 16×16 status glyph (UX L170).
const GLYPH_SIZE_PX: int = 16

## R-Default peripheral height ceiling (px) — AC-UX-2 upper clamp (Rule 7 peripheral).
const BANNER_HEIGHT_CEIL_PX: int = 72


## AC-UX-2 — R-Default banner height: clamp(round(0.10×H), 44, 72).
## The 44 floor is a HARD a11y touch requirement and wins even when it exceeds the
## 10% peripheral soft ceiling on short viewports (e.g. H<440 landscape → 44px > 10%);
## 72 is the peripheral ceiling on tall viewports. BANNER_MAX_HEIGHT_PCT is the single
## data-driven source for the 10% term.
static func banner_default_height(viewport_h: int) -> int:
	var pct: int = roundi(ShellFormulas.BANNER_MAX_HEIGHT_PCT * float(viewport_h))
	return clampi(pct, MIN_TOUCH_PX, BANNER_HEIGHT_CEIL_PX)


## AC-UX-2 — R-Default rect: full-width (±16 inset), bottom-anchored (bottom edge =
## viewport bottom − 16 safe inset).
static func banner_default_rect(viewport_w: int, viewport_h: int) -> Rect2:
	var h: int = banner_default_height(viewport_h)
	var x: float = float(SAFE_INSET_PX)
	var w: float = float(viewport_w - 2 * SAFE_INSET_PX)
	var bottom: float = float(viewport_h - SAFE_INSET_PX)
	var y: float = bottom - float(h)
	return Rect2(x, y, w, float(h))


## AC-UX-3 — R-Glyph (yield) rect: 16×16 at ErrorBannerLayer top-right,
## x∈[W−32, W−16], y∈[16, 32] (UX L170).
static func glyph_rect(viewport_w: int) -> Rect2:
	var x: float = float(viewport_w - SAFE_INSET_PX - GLYPH_SIZE_PX)  # W−32
	var y: float = float(SAFE_INSET_PX)                               # 16
	return Rect2(x, y, float(GLYPH_SIZE_PX), float(GLYPH_SIZE_PX))


## AC-UX-3 — zero tap-target overlap predicate (true == disjoint == OK). The yield
## glyph (top-right) MUST NOT intersect the #20 Z5 REST panel (bottom slide-up).
static func rects_disjoint(a: Rect2, b: Rect2) -> bool:
	return not a.intersects(b)


## AC-UX-8 — touch-target compliance (≥44px, or ≥48px for entry cards).
static func meets_touch_floor(size_px: int, is_entry_card: bool = false) -> bool:
	var floor_px: int = MIN_ENTRY_CARD_PX if is_entry_card else MIN_TOUCH_PX
	return size_px >= floor_px


## AC-UX-9 — cross-fade duration compliance (≤ SHELL_FADE_SEC 0.25s). Banner
## motion-safety (zero AnimationPlayer/tween) is enforced STATICALLY by story-016's
## lint (check_login_shell_static_discipline.gd), not at runtime here.
static func fade_within_budget(fade_sec: float) -> bool:
	return fade_sec <= ShellFormulas.SHELL_FADE_SEC
