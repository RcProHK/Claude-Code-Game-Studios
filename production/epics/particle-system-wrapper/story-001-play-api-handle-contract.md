# Story 001: play() API + ParticleHandle Contract

> **Epic**: Particle System Wrapper
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-01

## Context

**GDD**: `design/gdd/particle-system-wrapper.md`
**Requirement**: `TR-particle-001`, `TR-particle-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001 (Web Export Budget Caps, **Accepted-structural 2026-05-30** — particle-cap/preset architecture structural; CPU budget *numbers* Provisional) primary; ADR-0006 Contract 6 secondary
**ADR Decision Summary**: ParticleSystemWrapper 係所有 GPU particle 嘅唯一 gateway。`play(preset_id, position, caller_mult, count) → ParticleHandle` 係單一入口，sync return（無 `await`）。直接 `GPUParticles2D` 初始化被 CI lint 禁止。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `ParticleHandle` 用 RefCounted + generation counter 防 stale handle（pool slot 重用後舊 handle `alive()` 必須 false）。`play()` 必須真正 sync return（assert 返回值係 `ParticleHandle` 而非 `GDScriptFunctionState`）。

**Control Manifest Rules (this layer — Foundation)**:
- Required: 所有 particle emission 過 `ParticleSystemWrapper.play()`；單一 gateway
- Forbidden: 直接 `GPUParticles2D` instantiation outside `src/autoload/particle_system_wrapper.gd`（CI: `tools/ci/check_particle_callers.gd`）
- Guardrail: `play()` O(1) acquire（唔可以 iterate 成個 pool）

---

## Acceptance Criteria

*From GDD Section H, scoped to this story:*

- [ ] **AC-01** — `play(preset_id, position, caller_mult)` 喺 Active state 返回一個 valid live `ParticleHandle`：`handle.alive() == true`、`_generation > 0`、`_pool_index >= 0`、`preset_id` 對應；返回值係 sync `ParticleHandle`（NOT coroutine）；O(1) acquire（無 full-pool iterate）。
- [ ] **AC-02** — Argument validation：NaN/INF position → `ParticleHandle.INVALID`（`alive()==false`）且**唔** emit `burst_started`；`caller_mult` clamp 到 `[0.1, 1.5]`（GDD Rule 1）；`caller_mult < 0.1` short-circuit INVALID 無 signal；clamp 命中時 `push_warning`（經 injectable `_warn_sink` seam）。

> **ADVISORY（perf-gated）**：AC-01 嘅「`play()` < 1ms」wall-clock 子句唔喺 headless 驗證（test-standards: no time-dependent assertions）。改 assert 結構 proxy（無 `await` + O(1) acquire）。實際 timing 留 VS-tier profiling。

---

## Implementation Notes

*Derived from ADR-0001 Implementation Guidelines:*

- `ParticleHandle extends RefCounted`，欄位 `_pool_index: int`（-1 = INVALID/PENDING sentinel）、`_generation: int`、`preset_id: int`；`alive()` 比較 handle `_generation` 同 slot 當前 generation。
- `ParticleHandle.INVALID` 係 static const sentinel：`_pool_index == -1`、`alive() == false`。
- `play()` 步驟：validate args → acquire free slot（O(1) free-list pop）→ set handle generation → 返回 handle。Validation fail 喺 acquire 之前 short-circuit（無 signal、無 slot 消耗）。
- `caller_mult` clamp `[0.1, 1.5]`（注意：tr-registry TR-particle-002 寫 `[0.5, 2.0]` 係舊文字；GDD Rule 1 authoritative = `[0.1, 1.5]` — 跟 GDD，review 時喺 registry flag）。
- Warning 經 `var _warn_sink := Callable()` seam（default = `push_warning`），令 test 可注入 recording sink。
- NaN/INF *multiplier*（非 position）行為 GDD Rule 1 未明示 → 跟 qa-lead 建議：non-finite multiplier 當 `< 0.1` short-circuit → INVALID。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: object pool 結構 + tier selection（呢個 story 假設 free-list 已存在）
- Story 003: Formula 1 final_count 計算 + CPU ledger（呢個 story 只 clamp caller_mult，唔計 final count）
- Story 006: `burst_started` emit ordering 細節 + re-entry guard
- Story 007: boot sequence / lifecycle state（呢個 story 假設 Active）

---

## QA Test Cases

*Written by qa-lead at story creation. Implement against these — do not invent new cases.*

- **AC-01**: `play()` in Active returns valid live handle
  - Given: SUT booted（`_lifecycle_state == Active`），pool free-list 非空，GPU node stubbed
  - When: `handle = play(PresetId.HIT_LIGHT, Vector2(100,100), 1.0)`
  - Then: `handle.alive() == true` AND `_generation > 0` AND `_pool_index >= 0` AND `preset_id == HIT_LIGHT` AND `handle != ParticleHandle.INVALID`
  - Edge cases: 返回值係 `ParticleHandle` 非 coroutine；generation monotonicity（同一重用 slot 第二個 handle generation 更大，第一個 `alive()==false`）；`INVALID.alive()==false` 且 `_pool_index==-1`

- **AC-02**: argument validation — NaN position rejected, multiplier clamped
  - Given: SUT Active；`watch_signals(_sut)`
  - When: `play(HIT_LIGHT, Vector2(NAN,100), 1.0)`
  - Then: `== INVALID` AND `assert_signal_not_emitted(burst_started)`
  - And When: `play(HIT_LIGHT, Vector2(50,50), 9999.0)` → `alive()==true` AND composed caller_mult == 1.5（clamp）→ HIT_LIGHT desktop 8×1.5=12（assert ledger/stub amount-target == 12）AND warning fired（`_warn_sink`）
  - Edge cases: `Vector2(INF,0)` / `Vector2(0,-INF)` → INVALID 無 signal；`mult < 0.1`（0.05）short-circuit INVALID 無 signal；`mult == 0.1` 同 `== 1.5` 邊界接受無 warning；`mult == NaN` → INVALID

> **Mock note**: `push_warning` 唔可以直接 intercept — route 經 injectable `_warn_sink` seam。GPU emit 全 stub no-op（`_StubParticleNode`，記低 `restart()`/`emitting`/`amount` setter call）。Pool factory 必須有 untyped injection seam（[[reference_gdscript_di_seam]]）。

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/particle/test_play_api_contract.gd` — must exist and pass（AC-01 + AC-02，每個 AC ≥1 test function）

**Status**: [x] Created; GUT 10/10 PASS（particle dir）+ combined 1104/1105（唯一 pending = pre-existing AC-37 WST ADR-gated；0 fail）— Godot 4.6.3, 2026-06-01

---

## Dependencies

- Depends on: None（foundational — 第一個 particle story）
- Unlocks: Story 002（pool）、Story 003（ledger/formula）、Story 006（signal）

---

## Completion Notes

**Completed**: 2026-06-01
**Criteria**: 2/2（AC-01 play() live handle + sync + generation monotonicity + INVALID sentinel；AC-02 NaN/INF position reject + multiplier clamp [0.1,1.5] + <0.1 short-circuit + NaN reject + boundary no-warn）
**Implementation**:
- `src/core/particle_handle.gd` — new `class_name ParticleHandle extends RefCounted`：`static var INVALID`（非 const — RefCounted 唔係 constant expr）、`_slot` 反向引用（untyped seam）、`alive()` 比較 slot.generation == snapshot、`position()`、`stop()`。
- `src/autoload/particle_system_wrapper.gd` — Story 001 實作：`PresetId` enum（9 GDD-locked）、`LifecycleState` enum（minimal，Story 007 expand）、`play()`（state gate + Rule 1 三段 validation + acquire + minimal emit）、`PoolSlot` inner class、flat 16-node pool（Story 002 re-segment tiers）、`_node_factory`/`_warn_sink` DI seam、`_acquire_slot`/`_reclaim_stopped_slots`（generation bump on acquire）、minimal `_exit_tree` cleanup。
**Key discoveries**:
1. 新 `class_name` 要 `godot --headless --import` 刷新 global class cache，否則 GUT parse 「Could not find type ParticleHandle」。
2. `INVALID` 必須 `static var`（`const := ParticleHandle.new()` 非法 — .new() 唔係 constant expression）。
3. Generation-reuse 語義要耗盡 pool 先迫到 same-slot reuse（free-list LIFO；reclaim 只喺 free 空時觸發）— test 改為 exhaust→stop→replay。
4. Autoload 起 16 真 GPUParticles2D 會喺 headless shutdown leak CanvasItem RID → 加 minimal `_exit_tree` queue_free（Story 007 AC-23 owns 完整 Draining drain）。
**Deviations**: minimal `_lifecycle_state`（BOOTING→ACTIVE）+ minimal `_exit_tree` 屬 Story 007 範疇嘅 scaffold — 為 play() 可用 + 唔留 leak 落 main；Story 007 會 expand 成完整 GSM-gated state machine。已喺 code comment 標明 Story 007 ownership。
**Test Evidence**: `tests/unit/particle/test_play_api_contract.gd`（10 test functions）
**Code Review**: Pending（lean mode — 後續 batch review）
