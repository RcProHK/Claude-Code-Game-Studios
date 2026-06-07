## #22 Character Screen — timing knobs (story 004; GDD Tuning Knobs table).
##
## Registry sync: stat_tween_ms + charscreen_force_close_max_ms live in
## design/registry/entities.yaml. Safe ranges per GDD:
##   STAT_TWEEN_MS 200-400 (hard local constraint — #11 L696 band, CD C3)
##   FORCE_CLOSE_MAX_MS 0-150 (Rule 3 pinned cap)
##   SETTINGS_PERSIST_DEBOUNCE_MS 200-1000
##   LOCK_NUDGE_DURATION_MS 3000-8000 (CJK 讀速下限 ~4s)
##   ERROR_TOAST_DURATION_MS 2000-5000
##   ARIA_COALESCE_WINDOW_MS 500-2000
##
## Pinned constants (明文非 knob — GDD §Tuning Knobs):
##   - ease 曲線 cubic ease-out 零 overshoot (Pillar 1)
##   - slider keyboard step 10 pct (P-07 binding)
##   - F2 1% quantize grid (label bijectivity)
##   - F3 picker comparator 鏈 (determinism)
##
## All six knobs advance on the ONE injected clock (coordinator.advance) —
## never engine Tween / SceneTreeTimer.
extends RefCounted

const STAT_TWEEN_MS: float = 300.0
const FORCE_CLOSE_MAX_MS: float = 150.0
## Visual band consts(唔係 knob — UX spec:enter 150-200 ease-out / close 120-150 ease-in).
const OPEN_ANIM_MS: float = 180.0
const CLOSE_ANIM_MS: float = 135.0
const SETTINGS_PERSIST_DEBOUNCE_MS: float = 500.0
const LOCK_NUDGE_DURATION_MS: float = 5000.0
const ERROR_TOAST_DURATION_MS: float = 3000.0
const ARIA_COALESCE_WINDOW_MS: float = 800.0
