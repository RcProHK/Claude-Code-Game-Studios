# Entity Inventory — Mirror Hero MVP (v0.1)

> **Created**: 2026-06-12 (Production Sprint 1 — AD-PHASE-GATE condition C-AD-1)
> **Purpose**: Master per-entity art-asset list that reconciles the scattered tier/family counts
> in art-bible §3.A / §5.A / §5.B against the §8.C HARD sprite budgets — the safety net AD-PHASE-GATE
> flagged as missing. Author real sprites against THIS list, not ad-hoc per-sprite decisions.
> **Sources**: art-bible §5 (Character Design) + §6.D (Quiet Grove props) + §8.C (budgets); avatar-renderer.md
> (#26 G-AR-5); enemy-director.md (§Wave Archetype Spec); boss-system.md (§MVP scope).
> **Status**: Authoritative scope list. Per-asset `.tres` region defs + `.license.md` authored at production time.

## §8.C Budget reconciliation (the reason this file exists)

| §8.C sub-cap | Limit | This inventory's on-screen worst case | Status |
|--------------|-------|----------------------------------------|--------|
| Entities (player + enemies) on screen | ≤40 sprites | 1 player + ≤8 concurrent mobs (§5.D LOD cap) + ≤1 boss = **≤10** | ✅ far under |
| Projectiles + ability VFX sprites | ≤20 | 3 class signature VFX (mostly particle `.tres`, not sprites) | ✅ |
| Tilemap visible chunks | ≤60 | Quiet Grove single-zone side-scroller | ✅ |
| HUD elements | ≤15 | see #20 Gym-Mode HUD spec | ✅ |
| Misc (props, effects) | ≤15 | ≤5 Quiet Grove props (§6.C sparse: 0-2 per 64×64) | ✅ |
| **Atlas memory per scene** | **≤64 MB VRAM (HARD)** | TBD at atlas-pack time — **track when real sheets land** | ⏳ |
| Animation frames per animation | ≤16 (HARD) | avatar skill 6-8f, walk 4f, idle 2f (§5.D) | ✅ by spec |

> The HARD cap that needs live tracking is **atlas VRAM ≤64MB**. `tools/ci/asset_validator.gd` enforces
> per-PNG ≤2048×2048 + PO2; the cross-scene VRAM sum must be checked at atlas-pack time (TexturePacker step).

---

## 1. Player Avatar (entity: `hero`)

Single player entity, **9 visual states** = 3 evolution tiers × 3 class postures. Class shown via
skill-family color accent + weapon pose (NOT separate body) per §5.A; tier shown via silhouette ratio.

| Axis | Values | Source |
|------|--------|--------|
| Evolution tier | T1 (egg-down 2.5:1) / T2 (hourglass 3:1) / T3 (triangle-up 3.5:1) | art-bible §5.A |
| Class posture | STRIKE / CONTROL / MOBILITY | #26 (3 postures), §5.D keyframe rule |
| Base size | 32×32 px (LPC base) | §8.B |

**Animation set per state** (§5.D): idle 2f · walk/run 4f · skill 6-8f (+ 1 signature hold frame, §5.D P4 rule).
**Authoritative asset count (#26 G-AR-5)**: **36 animation sheets + 12 hero stills**.
**Naming**: `hero_<state>_<dir>.png` / atlas `hero_<tier>_<class>_sheet.png` + `.tres`.
**Placeholder in repo**: `assets/art/avatar/placeholder_avatar.tres` + `emergency_avatar.tres` (replace at sign-off, Line C / #26 G-AR-5).

---

## 2. Enemies (3 archetypes × 2 combat tiers)

Data-driven via `assets/data/EnemyRegistry.tres` (strike_pool / control_pool / mobility_pool).
Each archetype has a 3-value stat curve (regular/mini/final), but visually MVP authors **regular + mini-boss**
sprites per archetype (final tier = boss, see §3). FR-1 (enemy-director): each archetype needs strong
silhouette/palette/movement differentiation (≥60% blind-classify) + `primary_outline_color` field.

| Archetype | Day | Silhouette (§5.B) | Palette anchor | Movement timing |
|-----------|-----|-------------------|----------------|-----------------|
| **STRIKE_MOB** (Push, 橫矩形) | push | 2:1 flat, armor ≥60% | `world_bark #5C4A36` + `world_ash` hi | 4f, hold ≥3f (weighty) |
| **CONTROL_MOB** (Pull, 倒V) | pull | 1:2 tall, hook/chain/tentacle | `world_slate #4A5A66` + cool 10% | 4f, hold 1f (jerky) |
| **MOBILITY_MOB** (Leg, 倒梯形) | leg | 1.5:1, lower-body ≥60% | `world_moss #3E5B3A` + warm `#B86040` 10% | 4f anticip2+explosive1+recover1 |

**Per archetype**: regular (1× scale, accent 5%) + mini-boss (1.4× scale, +1 break feature, accent 15% + dirty-particle aura) per §5.B visual hierarchy.
**Count**: 3 archetypes × 2 (regular + mini) = **6 enemy sprite sets**.
**Naming**: `<archetype>_<state>_<dir>.png`, e.g. `strike_mob_walk_east.png`.

---

## 3. Bosses

**MVP scope (boss-system.md §MVP)**: **1 final boss** + **3 mini-boss archetype templates** (the mini tier of §2, shared).

| Boss | Visual | Asset strategy |
|------|--------|----------------|
| **Final boss** (×1) | Player mirror, 2.2× scale, reuses player `char_linen` base but S pushed 60-70% (over-saturated warning), particles ×3 (§5.B / §4.E) — serves **Pillar 5** | **Reuses avatar T3 base** + palette override + scale; minimal net-new sprite. Final Boss Kill Portrait = pixel-illustrated frame (§7.A, appears once). |
| **Mini-bosses** (×3) | = §2 mini-boss tier of each archetype | Already counted in §2 (no extra). |

> Pillar 4 boss-level expression honestly **deferred post-MVP** (1 final boss template only — boss-system.md §Pillar 4 Scope Honesty Note).

---

## 4. NPC / Non-combat — **0 (intentional MVP cut)**

§5.C: **0 NPC sprites / 0 NPC animations** for v0.1. Reserved rule for v0.2+ (egg-down 2.5:1, S<15%, no accent, no dirty-particle, 4:1 head-to-body).

---

## 5. Environment — Quiet Grove zone (§6.D)

Sparse (§6.C: 0-2 props per 64×64). "Worn Wilderness", 30% manmade / 70% organic.

| Prop | Layer | Notes |
|------|-------|-------|
| Weathered stone platform tiles | foreground | 16×16, angular, high-detail top band (§6.B) |
| Broken pillar (人造遺跡) | midground | "曾有英雄到過" hook, ≤15% contrast (§6.C) |
| Moss / shrub cluster (organic) | mid/background | unified growth direction, ambient |
| Cliff / background wall | background | low-density solid + organic break |

**Forbidden (§6.D)**: signage, readable text, enemy corpses, explicit gym props (dumbbell/weight-plate shapes). **Est. ≤5 prop sprites.**
**Tile size**: 16×16 (§8.B). **Naming**: `grove_<prop>.png`.

---

## 6. Ability VFX sprites (§8.C ≤20)

Mostly particle `.tres` (in `assets/vfx/presets/`, GPUParticles2D via `particle_system_wrapper`), not sprites:

| Class | Signature (§5.D) | VFX |
|-------|-------------------|-----|
| STRIKE | weapon apex, red radial burst | `hit_heavy.tres` / `hit_light.tres` |
| CONTROL | arms spread, purple ring expand | `status_*.tres` |
| MOBILITY | airborne trajectory, blue trail | `parry.tres` + trail |
| Loot (Pillar 3) | — | `loot_burst.tres` / `loot_rare_burst.tres` |
| Death | — | `death.tres` (+ CONTROL sticky-AOE residue, cosmetic) |

All present as `.tres` today. No net-new sprite sheets unless a class adds a frame-based VFX.

---

## Production order (gated on Line E tooling — now done)

1. ✅ `pixel_art.tres` import preset + `asset_validator.gd` (Line E — done 2026-06-12)
2. Author **avatar T1 STRIKE** first (most-seen entity, validates the whole pipeline end-to-end)
3. Then 3 regular enemy archetypes (unblocks first vertical-slice visuals)
4. Then mini-bosses + final boss (reuse avatar base)
5. Then Quiet Grove props
6. Promote `asset_validator.gd` entity-registry check from SKIPPED → HARD once `entities.yaml` `entities:` is populated from this list
