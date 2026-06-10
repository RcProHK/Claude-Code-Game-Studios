# Story 015: PostureConfig LUT + sprite resolution + EMERGENCY fallback + z-order + VRAM

> **Epic**: Avatar Renderer (#26)
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/avatar-renderer.md` PostureConfig LUT / CR-7 / CR-14 / INV-3/INV-6 / EC-ASSET-1/2
**Requirement**: AC-12 / AC-19(GDD 直接 trace)
**ADR Governing Implementation**: ADR-0001 Web Export Budget Caps(primary — CanvasLayer topology + texture budget)
**ADR Decision Summary**: CanvasLayer topology(Character 10 / Particle 20);sprite draw-call + atlas budget;texture VRAM 監控。

**Engine**: Godot 4.6 | **Risk**: HIGH(WebGL2 sprite/atlas/VRAM domain)
**Engine Notes**: texture VRAM 用 `Performance.RENDER_TEXTURE_MEM_USED`(15)/ `RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED`(3)— **NOT `MEMORY_STATIC`**(measures total heap)。web-runtime accuracy → Q-OQ-VRAM VS-tier。`AnimatedSprite2D.sprite_frames` assignment 只喺 `avatar_renderer.gd`(CI-6)。

**Control Manifest Rules (Presentation layer)**:
- Required: CanvasLayer.layer==10;avatar z_index∈[-10,10];particle Z≥20;VRAM via RENDER_TEXTURE_MEM_USED
- Forbidden: raw z_index>50;`MEMORY_STATIC` for texture budget;hardcoded fallback(EMERGENCY 係 preloaded resource 非 code-gen)
- Guardrail: INV-6 VRAM ≤600KB mobile(current+adjacent)/ ≤2.3MB desktop(all 12)

---

## Acceptance Criteria

- [ ] **AC-12**: `PostureConfig.tres` 有 12 entries(3 class × 4 tier);`_derive_sprite_frames` 對全 12 返 non-null;missing key → `EMERGENCY_AVATAR.tres` fallback
- [ ] **AC-19**: sum current+adjacent tier texture VRAM via `Performance.RENDER_TEXTURE_MEM_USED`(NOT `MEMORY_STATIC`)≤ 600KB mobile / ≤ 2.3MB desktop(desktop Vulkan measurable;web → Q-OQ-VRAM)
- [ ] CR-7 z-order:Character CanvasLayer.layer==10;avatar z_index=0 internal[-10,10];particle layer 20;NEVER raw z_index>50;effect displacement ≤4px;burst ≤2× bbox
- [ ] EC-ASSET-1(CRITICAL):`SpriteFrames` for (posture,tier) load fail → `EMERGENCY_AVATAR.tres`(preloaded T0 STRIKE idle);disable cast/combat anim;log `sprite_load_failure`;silhouette never breaks(INV-1)
- [ ] EC-ASSET-2:tier preload 超 mobile budget → lazy-load current+adjacent(T_n−1/T_n/T_n+1);discard ≤T_n−2(INV-6)

---

## Implementation Notes

*Derived from PostureConfig LUT + CR-7/CR-14:*

- `PostureConfig`(`assets/data/posture_config.tres`):key `"{CLASS}_T{tier}"` → SpriteFrames path;`_derive_sprite_frames` load;missing → EMERGENCY。
- `EMERGENCY_AVATAR.tres` always preloaded(EC-ASSET-1 fallback)。
- CanvasLayer topology setup(layer 10);particle delegated #5 layer 20。
- VRAM monitor 用 `RENDER_TEXTURE_MEM_USED`(probe-verified enum);desktop Vulkan measurable,web-runtime number 留 Q-OQ-VRAM VS-tier(唔 block code — enum 寫啱即可)。
- **G-AR-5 / asset 提示**:實際 36 sheet + 12 hero still 由 `/asset-spec` 生產;本 story 用 placeholder SpriteFrames + EMERGENCY 跑 logic(BLOCKING AC 唔等 final art)。

---

## Out of Scope

- Story 016:particle preset trigger(本 story set z-order topology,016 trigger presets)
- Story 019:silhouette playtest(本 story logic;visual fidelity 留 ADVISORY)
- `/asset-spec`:final 36 sheet 生產(G-AR-5)

---

## QA Test Cases

- **AC-12**: PostureConfig 12 + fallback
  - Given: PostureConfig.tres
  - When: `_derive_sprite_frames` 對 12 (class,tier)
  - Then: 全 non-null;missing key → EMERGENCY
  - Edge cases: EC-ASSET-1 load fail → EMERGENCY,silhouette 唔斷
- **AC-19**: VRAM budget
  - Given: current+adjacent tier loaded
  - When: `RENDER_TEXTURE_MEM_USED` sum
  - Then: ≤600KB mobile / ≤2.3MB desktop;NOT MEMORY_STATIC
  - Edge cases: EC-ASSET-2 lazy-load discard ≤T_n−2

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/avatar_renderer/sprite_resolution_test.gd` — placeholder SpriteFrames fixtures;EMERGENCY fallback case;VRAM assertion(desktop-measurable)
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002(pipeline)/ Story 004(tier→sprite)/ Story 008(posture swap gate)
- Unlocks: Story 014(snapshot sprite path)/ Story 016(particle z-order)
