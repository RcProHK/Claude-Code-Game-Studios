# Story 008: Preset Library + Visual Spec .tres Assets

> **Epic**: Particle System Wrapper
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Config/Data
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-01

## Context

**GDD**: `design/gdd/particle-system-wrapper.md`
**Requirement**: `TR-particle-002`（9 named presets — data-side definition）
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001 (Web Export Budget Caps, **Accepted-structural 2026-05-30**)
**ADR Decision Summary**: 9 個命名 preset（closed library，CI-enforced）：`HIT_LIGHT / HIT_HEAVY / PARRY / DEATH / LOOT_BURST / LOOT_RARE_BURST / STATUS_BURN / STATUS_FREEZE / STATUS_STUN`。每 preset 對應一個 `ParticleProcessMaterial` .tres，定義 count / lifetime / material / z_index。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `.tres` ParticleProcessMaterial 用 Godot 4.6 import system；z_index discipline（combat=5、status=4、loot=7 — loot render 喺 combat 之上）。color ramp 跟 game-concept Color Philosophy（white→green→blue→purple→orange）。

**Control Manifest Rules (this layer — Foundation)**:
- Required: gameplay 數值 data-driven（base count / lifetime 喺 .tres，唔 hardcode）
- Forbidden: preset library 開放擴充（closed 9，CI-enforced）
- Guardrail: count range `[4, 48]`（Formula 1 base-count 表）

---

## Acceptance Criteria

*From GDD Rule 13，scoped to this story（Config/Data — smoke check 為主）:*

- [ ] **AC-S1** — 9 個 `.tres` files（`assets/vfx/presets/`）+ `PRESETS` const dict 載入無 error；`PRESETS.size()==9`；keys 剛好係 9 個 PresetId（set equality）。
- [ ] **AC-S2** — 每 entry schema 完整：`count`(int)、`lifetime`(float)、`material`(ParticleProcessMaterial)、`z_index`(int)，type 全部正確。
- [ ] **AC-S3** — Spot check：HIT_LIGHT count==8 / lifetime==0.25 / z_index==5；z_index discipline combat==5 / status==4 / loot==7；count range `[4,48]`。

---

## Implementation Notes

*Derived from ADR-0001 Implementation Guidelines:*

- 建立 9 個 `.tres` ParticleProcessMaterial assets 喺 `assets/vfx/presets/`（每 preset 一個）。
- `PRESETS` const dict（喺 wrapper 或獨立 resource）map `PresetId` → preset spec（count / lifetime / material path / z_index）。
- z_index：combat（HIT_LIGHT/HIT_HEAVY/PARRY/DEATH）=5、status（BURN/FREEZE/STUN）=4、loot（LOOT_BURST/LOOT_RARE_BURST）=7。
- color ramp 跟 game-concept Color Philosophy escalation。
- Config/Data story — 無 programmer agent，直接編輯 data 檔。Smoke check 為 evidence。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: PresetId enum 定義（呢個 story 填 .tres 內容對應 enum）
- Story 002: tier amount buffer（pool-side，非 preset-side）
- Story 009: LOOT_BURST vs LOOT_RARE_BURST peripheral distinguishability（FR-2，playtest-gated）

---

## QA Test Cases

*Config/Data story — smoke check only。Evidence: `production/qa/smoke-[date].md`.*

- **Smoke check**: Preset library loadable + schema-complete
  - Given: `assets/vfx/presets/*.tres`（9 files）+ `PRESETS` const dict
  - When: `/smoke-check` 載入每 preset
  - Then: 9 `.tres` 載入無 error（無 missing res:// path）AND `PRESETS.size()==9` AND keys==9 PresetId（set equality）AND 每 entry 有 count(int)/lifetime(float)/material(ParticleProcessMaterial)/z_index(int) 且 type 正確
  - Spot checks: HIT_LIGHT count==8/lifetime==0.25/z_index==5；z_index combat==5/status==4/loot==7；count range `[4,48]`

> ADVISORY — passing smoke check 足夠做 Done evidence。無 automated unit test required，但 schema-completeness check 平，建議加入 smoke pass。

---

## Test Evidence

**Story Type**: Config/Data
**Required evidence**:
- Smoke check pass report — `production/qa/smoke-[date].md`（preset load + schema check）
- 9 `.tres` files 存在於 `assets/vfx/presets/`

**Status**: [x] Created; smoke PASS — `production/qa/smoke-2026-06-01-particle-presets.md` + automated `tests/unit/particle/test_preset_library.gd`（6 tests）；combined 1220/1221（1 pending = pre-existing AC-37；0 fail）— Godot 4.6.3, 2026-06-01

---

## Dependencies

- Depends on: Story 001（PresetId enum）、Story 002（tier 對應 preset count）
- Unlocks: epic close-out（preset library 完整）

---

## Completion Notes

**Completed**: 2026-06-01
**Criteria**: 3/3（AC-S1 9 .tres load + PRESET_TABLE 9 keys；AC-S2 schema-complete count/lifetime/z_index/material；AC-S3 spot checks + z_index discipline + count range）
**Implementation**:
- PRESET_TABLE enrich：每 preset 加 lifetime + z_index + material_path（per GDD Visual Spec Table Rule 13）；修正 STATUS_* base_count placeholder 12 → GDD 值 4/5/6。
- `tools/asset-pipeline/generate_particle_presets.gd` — programmatic generator，由 GDD spec 建 9 個 ParticleProcessMaterial（color_ramp GradientTexture1D + emission_shape + spread + velocity + gravity + damping），`ResourceSaver.save` → `assets/vfx/presets/*.tres`。
- `_swap_material` (Story 007 EC16 stub) wired：load .tres + set `process_material` / `lifetime` / `z_index` on real GPUParticles2D（stub-guarded → headless GPU-free）。
- Smoke evidence：`production/qa/smoke-2026-06-01-particle-presets.md` + automated schema test。
**Key decisions / deviations**:
1. **`.tres` programmatically generated（非手寫）** — 由 generator script 從 single GDD spec 建，避免手寫 ParticleProcessMaterial .tres 格式錯 + 保證可重生。滿足 AC-S1「9 .tres load」字面 + spirit（data-driven）。
2. **Particle texture deferred**：係 GPUParticles2D node property + 未產出 art dependency（spark_sharp.png 等）→ 留 null，material texture-agnostic。
3. **scale_curve deferred**：GDD per-preset scale-over-lifetime curve（CurveTexture）用 material default 近似，full curve 留 art polish follow-up。
4. **STATUS base_count 修正** 12→4/5/6 唔影響任何現有 test（無 test assert STATUS count）。
**Test Evidence**: `tests/unit/particle/test_preset_library.gd`（6）+ smoke doc + 9 `.tres` + generator
**Code Review**: Pending（lean mode — 後續 batch review）
