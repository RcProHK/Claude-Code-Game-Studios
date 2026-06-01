# Story 006: Dispatch Table + burst_started Auto-Reaction

> **Epic**: Screen Effects System
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-01

## Context

**GDD**: `design/gdd/screen-effects-system.md`
**Requirement**: `TR-screen-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001 (Web Export Budget Caps, **Accepted-structural 2026-05-30**)
**ADR Decision Summary**: ScreenEffects 訂閱 `ParticleSystemWrapper.burst_started(preset_id, position)` → static const `_DISPATCH` Dictionary lookup auto-react。4 active：HIT_HEAVY {0.4/0.12, pause 0}、PARRY {0.6/0.08, pause 0.06}、DEATH {0.3/0.18, pause 0}、LOOT_RARE_BURST {0.2/0.15, pause 0}。5 no-op（HIT_LIGHT / STATUS_BURN / STATUS_FREEZE / STATUS_STUN / LOOT_BURST）— sensation hierarchy 嚴肅 noise floor。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `_DISPATCH` keys 用 `ParticleSystemWrapper.PresetId.*`（real enum：PARRY=2、LOOT_BURST=4、LOOT_RARE_BURST=5）— 唔可 hardcode int（ADR-0007 enum declaration order load-bearing）。direct `.connect()`（autoload pos 12 < 14 boot order 保證，per Q-V6 resolution）。

**Control Manifest Rules (this layer — Foundation)**:
- Required: `_DISPATCH` static const Dictionary；keys ⊆ PresetId enum（CI drift check）
- Forbidden: match-expression dispatch（data-driven 失效）；shake for no-op presets
- Guardrail: dispatch O(1) lookup；handler await-free

---

## Acceptance Criteria

*From GDD Section H, scoped to this story:*

- [ ] **AC-14** [Falsifiable #1] — `burst_started(PresetId.PARRY, pos)` → `_on_burst_started` → `_apply_shake(0.6, 0.08)` AND `hit_pause(0.06)`（兩者都要，per `_DISPATCH[PARRY]`）。
- [ ] **AC-15** — `burst_started(HIT_LIGHT|STATUS_BURN|STATUS_FREEZE|STATUS_STUN|LOOT_BURST, pos)` → NO shake, NO pause, NO log；`_dispatch_missed_count` 不變（known no-op，唔係 unknown）。
- [ ] **AC-23** — handler returns（structural）；dispatch O(1)；無 await（`_emit_depth` 歸 0）。timing claim ADVISORY/perf-gated（Story 011）。

---

## Implementation Notes

*Derived from ADR-0001 + GDD Rule 9 / Interaction #1+4:*

- `_ready`：`ParticleSystemWrapper.burst_started.connect(_on_burst_started)`（direct connect，Q-V6 RECOMMENDED；EC-13 graceful degradation 若 #5 absent — call_deferred retry，可留 Story 007/觀察）。
- `_DISPATCH` static const Dictionary：**包含全 9 presets** — 4 active（shake+optional pause）+ 5 explicit no-op entry（區分 known-no-op vs unknown）。
- `_on_burst_started(preset_id, position)`：lookup `_DISPATCH`；有 active entry → `_apply_shake(intensity, duration)` +（pause>0 → `hit_pause(pause)`）；no-op entry → silent skip（唔 increment counter）；unknown（唔喺 table）→ `_dispatch_missed_count += 1`（EC-14 telemetry，no warning）。
- `position` arg received but unused（`# position reserved for future positional shake`）。
- handler await-free（AC-23 structural）。

---

## Out of Scope

*Handled by neighbouring stories:*

- Story 003: `_apply_shake` combiner（dispatch 只 call funnel）
- Story 005: hit_pause freeze（dispatch call hit_pause，freeze 行為喺 005）
- Story 008: `_DISPATCH` keys ⊆ PresetId CI drift check（lint）

---

## QA Test Cases

> **Precondition seams**: `const PSW := preload("res://src/autoload/particle_system_wrapper.gd")` 攞真 PresetId enum（唔 hardcode int）；`_trauma`/`_pause_remaining_sec`/`_dispatch_missed_count`/`_emit_depth` readable。

- **AC-14**: PARRY dispatch fires both
  - Given: SUT ACTIVE；motion=1.0；`_trauma=0`；`_pause_remaining_sec=0`
  - When: `_sut._on_burst_started(PSW.PresetId.PARRY, Vector2(100,50))`
  - Then: `assert_almost_eq(_trauma, 0.6, 0.0001)`；`assert_almost_eq(_pause_remaining_sec, 0.06, 0.0001)`
  - Edge: Falsifiable #1 — 兩個 effect 都驗（只 fire 一個 = fail）。Headless: 用 preload PresetId 唔 hardcode 2。

- **AC-15**: 5 no-op presets silent
  - Given: SUT ACTIVE；`_trauma=0`；`_pause_remaining_sec=0`；baseline `_dispatch_missed_count`
  - When: 對 HIT_LIGHT/STATUS_BURN/STATUS_FREEZE/STATUS_STUN/LOOT_BURST 各 call `_on_burst_started`
  - Then: `_trauma==0`；`_pause_remaining_sec==0`；`_dispatch_missed_count==baseline`（known no-op 唔 increment）
  - Edge: known no-op（table 有 explicit no-op entry）vs unmapped（counter++）係兩回事。確認 table 含全 9 presets。LOOT_BURST=4 唔好同 LOOT_RARE_BURST=5 撈亂。

- **AC-23**: handler structural / await-free
  - Given: SUT ACTIVE
  - When: `_sut._on_burst_started(PSW.PresetId.PARRY, pos)`
  - Then: `_emit_depth==0`（completed + unwound，無 pending await）
  - Edge: static RegEx scan `_on_burst_started` 內無 `await`（0 matches）。**唔 assert wall-clock timing**（ADVISORY/perf-gated，Story 011）。

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/screen_effects/test_screen_effects_dispatch.gd` — must exist and pass（AC-14, 15, 23）

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 003（`_apply_shake`）、Story 005（hit_pause）、**#5 ParticleSystemWrapper (Complete ✅ — burst_started signal + PresetId enum)**
- Unlocks: Story 008（CI drift check `_DISPATCH` ⊆ PresetId）
