class_name AvatarVisualState
extends Resource
## #26 Avatar Renderer — derived, presentation-only visible state.
##
## Every visible field is DERIVED from canonical #11 Stat / #12 Ability / #1 GSM
## data inside `avatar_renderer.gd::_derive_state_from_canonical()` (CR-6 / INV-1).
## No external mutation path exists — `get_visual_state()` returns `.duplicate()`.
## See design/gdd/avatar-renderer.md (Story 002 / AC-02 / AC-29).

# --- Identity (derived) ---
## Evolution tier 0..3 — Formula 2 (generalist OR specialist symmetric path).
@export var evolution_tier: int = 0
## Class posture — Formula 1 argmax(STR/DEX/VIT). {&"STRIKE", &"CONTROL", &"MOBILITY"}.
@export var class_posture: StringName = &"STRIKE"
## Animation state — CR-2 FSM. {&"IDLE", &"COMBAT", &"CAST"} (SUSPENDED is engine pause).
@export var animation_state: StringName = &"IDLE"

# --- Sprite frame state ---
## res:// path to the current (posture,tier) SpriteFrames (PostureConfig LUT).
@export var sprite_frames_resource_path: String = ""
## Current AnimatedSprite2D frame index.
@export var current_frame: int = 0
## [0.0,1.0] fractional frame progress (for set_frame_and_progress restore — CR-8).
@export var frame_progress: float = 0.0

# --- Micro-evolution (shader-only delta — CR-5b) ---
## [0.0,1.0] hue rotation.
@export var micro_palette_shift: float = 0.0
## [0.0,1.0] outline brightness.
@export var micro_outline_intensity: float = 0.0

# --- Milestone tracking (source = #3 persistence, NOT pure re-derivation) ---
@export var last_emitted_tier: int = 0
## 0 = never (Formula 3 epoch-zero guard).
@export var last_milestone_emit_unix: int = 0

# --- Anti-fabrication traceability (CR-6 / INV-1 / FT-3 audit) ---
## {field_name: source_signal_name}. A visible field with no attribution fails AC-02/AC-29.
@export var derived_from: Dictionary = {}

# --- ADR-0006 Contract 2 traceability ---
## triggering GSM transition_id (0 = bootstrap / none).
@export var transition_id: int = 0
@export var schema_version: int = 1
