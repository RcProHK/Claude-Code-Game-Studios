class_name AvatarEvolutionSnapshot
extends Resource
## The #29 Mirror Moment ceremony seam (ADR-0010 / CR-11).
##
## A read-only, self-contained snapshot #29 composes the weekly ceremony portrait
## from. #26 PRODUCES it (`get_evolution_snapshot()`); #29 RENDERS from it. #26
## itself renders NO ceremony (CR-17 / AC-30). All 8 fields are read from #26's
## already-derived visible state — #26 derives nothing new when producing this.

## Current evolution_tier (0..3).
@export var tier: int = 0
## {&"STRIKE", &"CONTROL", &"MOBILITY"}.
@export var class_posture: StringName = &"STRIKE"
## res:// to the current (posture,tier) SpriteFrames — the "after" sprite.
@export var sprite_frames_resource_path: String = ""
## The still "mirror" pose frame index within that SpriteFrames (#29 composes around it).
@export var hero_pose_frame: int = 0
## Last-ceremonied tier (for #29 ghost / "before"). Collapse handled by #26 (CR-M5).
@export var prior_tier: int = 0
## res:// to the prior (posture,tier) SpriteFrames — the "before" ghost. "" = first-ever.
@export var prior_sprite_frames_resource_path: String = ""
## {stat_total, ability_count, max_class_depth, achieved_at_unix} — narrative "成因" (FC-2 frozen).
@export var source_metrics: Dictionary = {}
@export var snapshot_taken_unix: int = 0
