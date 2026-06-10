class_name MirrorMomentConfig
extends Resource
## Data-driven tuning knobs for #29 Mirror Moment (CR-M1 / CI-MM-3).
##
## `mirror_moment_coordinator.gd` reads every cadence / threshold knob from a loaded
## instance of this resource — it holds ZERO cadence literals itself (CI-MM-3). The
## CELEBRATION_BURST_PRESET is the #5 PresetId enum *int* (kept data-driven so the
## B-1 LOOT-preset constraint is a config fact, not a hardcoded .gd literal).
## See design/gdd/mirror-moment.md Tuning Knobs.

## Weekly ceremony cadence window (seconds). DESIGN-FROZEN == #26 MILESTONE_CADENCE_SECONDS
## (CI-MM-3 parity assert). 604800 = 7 days.
@export var cadence_seconds: int = 604800
## Enable the REFLECTION light ceremony on micro-only weeks (守 Pillar 5 weekly cadence).
@export var weekly_reflection_enabled: bool = true
## stable-IDLE confirmation delay before presenting (EC-MM-14 transient-IDLE flicker guard).
@export var present_delay_frames: int = 6
## EVOLUTION celebration burst intensity passed to #5.play() multiplier.
@export var celebration_particle_multiplier: float = 1.0
## Auto-dismiss seconds (0 = manual dismiss only, MVP default).
@export var auto_dismiss_seconds: int = 0
## Emit a "未練" nudge on zero-change weeks (MVP MUST be false — Pillar 2 honesty).
@export var no_change_nudge_enabled: bool = false
## bfcache/SUSPENDED resume continue-window (ms). == #26 BFCACHE_CONTINUE_THRESHOLD_MS (parity).
@export var bfcache_continue_threshold_ms: int = 30000
## share-card framing. MVP = "viewport" (full clean screenshot); "9:16"/"1:1" → v0.2.
@export var share_card_aspect: String = "viewport"
## #5 PresetId int for the EVOLUTION celebration burst. B-1 HARD: MUST be a LOOT preset
## (LOOT_BURST=4 / LOOT_RARE_BURST=5) — only LOOT presets reach #5 LARGE tier and reparent
## onto CelebrationVFXLayer 110 (above the modal backdrop). Any non-LOOT preset renders on
## the world ParticleLayer (z≤7), hidden under the backdrop.
@export var celebration_burst_preset: int = 5

## Drift detector — bump on any knob change (mirrors #26 config_version_hash convention).
@export var version_hash: String = "v1-2026-06-10"

## The two #5 LOOT preset enum ints that reach LARGE tier → CelebrationVFXLayer 110 (B-1).
const LOOT_PRESET_INTS := [4, 5]  # PresetId.LOOT_BURST / PresetId.LOOT_RARE_BURST

## Load-time validation. Returns "" when valid, else a diagnostic string. Called at boot
## (EC-BOOT surrounds this); a non-empty result is a hard config error.
func validate() -> String:
	if cadence_seconds <= 0:
		return "cadence_seconds must be > 0, got %d" % cadence_seconds
	if bfcache_continue_threshold_ms <= 0:
		return "bfcache_continue_threshold_ms must be > 0, got %d" % bfcache_continue_threshold_ms
	if present_delay_frames < 0 or present_delay_frames > 30:
		return "present_delay_frames out of [0,30], got %d" % present_delay_frames
	if celebration_particle_multiplier < 0.5 or celebration_particle_multiplier > 2.0:
		return "celebration_particle_multiplier out of [0.5,2.0], got %f" % celebration_particle_multiplier
	if auto_dismiss_seconds < 0 or auto_dismiss_seconds > 30:
		return "auto_dismiss_seconds out of [0,30], got %d" % auto_dismiss_seconds
	# B-1 HARD: burst preset must be a LOOT preset so it lands on CelebrationVFXLayer 110.
	if not LOOT_PRESET_INTS.has(celebration_burst_preset):
		return "celebration_burst_preset must be a #5 LOOT preset int %s (B-1), got %d" % [str(LOOT_PRESET_INTS), celebration_burst_preset]
	return ""
