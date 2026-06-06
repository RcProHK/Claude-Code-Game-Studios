## BossVisualResource — boss sprite + animation visual bundle (per GP-F2)
##
## Driving GDD:
##   * design/gdd/boss-system.md — Rule 1 (BossVisualResource stub schema, Q-V2)
##
## Governing ADR:
##   * ADR-0001 (Web Export Budget Caps) — silhouette / particle budget context
##
## Driving Story: production/epics/boss-system/story-001-boss-template-schema.md
## Implementing TR: TR-boss-001 (schema)
##
## GP-F2 (boss-system.md Rule 1): this lives in its OWN file. GDScript permits
## only ONE file-level `class_name` per script — declaring a second `class_name`
## inside `boss_template.gd` would be a parse error. `BossTemplate.visual_template`
## references this type, which resolves once this file registers the global class.
##
## Q-V2 (boss-system.md Section J): #16 owns this stub until #26 Avatar Renderer
## finalizes a shared visual interface. A future refactor may extract an
## `IVisualResource` (@abstract, Godot 4.5+) — tracked under BOSS-AC-followup-07.
class_name BossVisualResource extends Resource


## Base sprite atlas / texture for the boss.
@export var sprite_texture: Texture2D = null


## Uniform sprite scale. Final bosses render at 2-3× standard enemy size
## (boss-system.md Section I — 96×96 px final vs 16-32 px enemy).
@export var sprite_scale: Vector2 = Vector2.ONE


## Animation set: idle / telegraph / attack_<id> / staggered / death frames.
## BossInstance (Story 002) asserts the required animation names exist; the
## BossRegistry validation CI lint (Story 015 / followup-08) enforces it at load.
@export var anim_set: SpriteFrames = null


## Thumbnail size (px) for the silhouette identifiability test (Section I):
## scaled to this size as a pure silhouette, the class family should be
## recognisable (STRIKE / CONTROL / MOBILITY).
@export var silhouette_test_size_px: int = 32


## Rim-light colour used in the reveal-ritual saturate burst (Section I step 4).
@export var rim_light_color: Color = Color.WHITE
