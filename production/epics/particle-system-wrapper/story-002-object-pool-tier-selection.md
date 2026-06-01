# Story 002: Object Pool + Tier Selection + No-Realloc

> **Epic**: Particle System Wrapper
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-01

## Context

**GDD**: `design/gdd/particle-system-wrapper.md`
**Requirement**: `TR-particle-003`, `TR-particle-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001 (Web Export Budget Caps, **Accepted-structural 2026-05-30**)
**ADR Decision Summary**: 固定 16-node pool（SMALL 8 / MEDIUM 6 / LARGE 2），每 tier `amount` buffer 喺 boot set 一次（SMALL 32 / MEDIUM 96 / LARGE 256），runtime **永不** realloc。Tier 由 final_count band 選擇。

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: `GPUParticles2D.amount` 改值會觸發 GPU buffer 重建（昂貴）— 所以 boot 設定後 runtime 唔可以再改。LOOT preset 永遠走 LARGE tier（loot 視覺特權）。

**Control Manifest Rules (this layer — Foundation)**:
- Required: pool nodes 喺 `_ready()` 一次性建立
- Forbidden: runtime `amount` reassignment（每 node 一世只 set 一次）
- Guardrail: 16 nodes total，無動態 grow

---

## Acceptance Criteria

*From GDD Section H, scoped to this story:*

- [ ] **AC-03** — Boot 後 pool 組成固定：total 16 nodes，SMALL=8 / MEDIUM=6 / LARGE=2；`PRESETS.size() == 9`；SMALL node `amount`==32、MEDIUM==96、LARGE==256；每 tier `amount` 喺 boot 只 set 一次。
- [ ] **AC-04** — Tier selection 按 final_count band：`[1..32]`→SMALL、`[33..96]`→MEDIUM、`[97..256]`→LARGE；LOOT_BURST/LOOT_RARE_BURST 永遠→LARGE（無視 final_count）；20 次混合 `play()` 後每個 node 嘅 `amount`-setter call count 仍 == 1（永不 reassign post-boot）。

---

## Implementation Notes

*Derived from ADR-0001 Implementation Guidelines:*

- Pool 用 typed array per tier 或單一 array + tier metadata。Free-list per tier（O(1) acquire/release）。
- `_select_tier(preset_id, final_count) → String`：先 check LOOT short-circuit（`preset_id in [LOOT_BURST, LOOT_RARE_BURST]` → "LARGE"），再 band 判斷。
- Boundary：32→SMALL、33→MEDIUM、96→MEDIUM、97→LARGE、256→LARGE。
- 防禦：`final_count <= 0` 唔應到達（Formula 1 upstream clamp ≥1）；若到達 route SMALL 不 crash。
- Stub node factory 必須係 injection seam（untyped），令 test 換入記低 `amount`-setter call count 嘅 `_StubParticleNode`。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: `play()` API surface + handle（呢個 story 提供 free-list 畀 001 acquire）
- Story 003: final_count 計算（呢個 story 接收 final_count 做 input，唔計）
- Story 004: LRU eviction（pool 滿時點處理）
- Story 008: preset .tres material 內容

---

## QA Test Cases

- **AC-03**: pool composition fixed at boot
  - Given: SUT `_ready()` 完成（stubbed node factory）
  - When: 檢查 boot 後 pool
  - Then: total==16 AND SMALL==8/MEDIUM==6/LARGE==2 AND `PRESETS.size()==9` AND SMALL.amount==32/MEDIUM==96/LARGE==256
  - Edge cases: 每 tier amount set 剛好一次；PRESETS keys 剛好係 9 個 PresetId（set equality，無多無少）

- **AC-04**: tier selection by band；amount never reassigned post-boot
  - Given: SUT booted；每 stub node 記 amount-setter call count，baseline==1
  - When: `_select_tier(preset, final_count)` 跨 band
  - Then: `[1..32]`→SMALL、`[33..96]`→MEDIUM、`[97..256]`→LARGE
  - And: 20 次混合 play 後每個 node amount-setter count == 1
  - Edge cases: boundary 32→SMALL/33→MEDIUM/96→MEDIUM/97→LARGE/256→LARGE；LOOT_BURST/LOOT_RARE_BURST 永遠 LARGE；final_count 0/負 防禦 route SMALL 不 crash

> **Stub note**: amount-setter spy 係 AC-04 嘅 load-bearing 機制 — pool nodes 必須係 stub type 先數到 setter invocation。確認 factory injection seam 存在。

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/particle/test_pool_tier_selection.gd` — must exist and pass（AC-03 + AC-04）

**Status**: [x] Created; GUT 9/9 PASS（particle dir 19/19 with Story 001）+ combined 1113/1114（1 pending = pre-existing AC-37；0 fail）— Godot 4.6.3, 2026-06-01

---

## Dependencies

- Depends on: Story 001（ParticleHandle + play() surface）
- Unlocks: Story 003（ledger）、Story 004（LRU eviction）

---

## Completion Notes

**Completed**: 2026-06-01
**Criteria**: 2/2（AC-03 pool 16 nodes SMALL8/MED6/LARGE2 + PRESET_TABLE 9 keys + amount 32/96/256 set-once；AC-04 tier band selection + LOOT 永遠 LARGE + amount 永不 reassign + 0/負 defensive + >256 warn）
**Implementation**: 重構 `particle_system_wrapper.gd` flat pool → tiered：
- 新 consts：TIER_SMALL/MEDIUM/LARGE、POOL_SIZE_* (8/6/2)、AMOUNT_BUFFER_* (32/96/256)。
- `PRESET_TABLE` const Dict（9 PresetId → {base_count}）— Rule 1 membership oracle + Rule 7 base；Story 008 enrich material/lifetime/z_index。
- `PoolSlot` 加 `tier` field；`_free` Array[int] → Dictionary（per-tier free lists，by-reference mutate）。
- `_build_tier()` 設 `node.amount` 一次 at boot（Rule 5 no realloc）。
- `_select_tier(preset_id, final_count)`（LOOT short-circuit LARGE → band → >256 warn fallback）。
- `_acquire_slot(tier)` / `_reclaim_stopped_slots(tier)` tier-aware。
- `play()` preset validation 改 `PRESET_TABLE.has`；加 final_count(base)+tier selection（Story 003 換全 Formula 1）。
**Key discoveries**:
1. HIT_LIGHT base 8 → SMALL tier（8 nodes）— Story 001 reuse test 原本 loop POOL_SIZE(16) 會超 SMALL 容量；改成「fill until reject」tier-agnostic。
2. autoload pool 16 GPUParticles2D 喺 headless shutdown 用 `queue_free` 會 leak CanvasItem RID（deferred 唔 flush）→ `_exit_tree` 改 `free()` 同步釋放，particle-only run 0 orphans 確認清咗。
3. Combined run 殘留 7 CanvasItem orphans 係其他 test dir 既有（particle-only = 0 證明非本 epic 引入）。
**Deviations**: `_exit_tree` free() + minimal `_lifecycle_state` 仍屬 Story 001/007 scaffold（已標 ownership）。`final_count = base_count` 係 Story 003 Formula 1 嘅 placeholder（tier 選擇用 base，caller mult 已 record 待 003 compose）。
**Test Evidence**: `tests/unit/particle/test_pool_tier_selection.gd`（9 test functions）
**Code Review**: Pending（lean mode — 後續 batch review）
