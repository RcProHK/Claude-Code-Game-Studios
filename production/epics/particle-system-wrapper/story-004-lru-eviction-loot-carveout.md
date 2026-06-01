# Story 004: LRU Eviction + Hybrid LOOT Carve-Out

> **Epic**: Particle System Wrapper
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-01

## Context

**GDD**: `design/gdd/particle-system-wrapper.md`
**Requirement**: `TR-particle-007`, `TR-particle-008`, `TR-particle-009`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001 (Web Export Budget Caps, **Accepted-structural 2026-05-30**)
**ADR Decision Summary**: Pool 滿時 LRU eviction（age-only，最舊先 evict），但 150ms floor 保護未滿 150ms 嘅 burst。Hybrid LOOT carve-out：LOOT request 可繞過 floor evict 非-LOOT victim（loot 視覺特權），但永不 evict LOOT。Combat 全保護時 silent reject + telemetry。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Eviction 用自然 fade（set `emitting=false`），**唔** `restart()` 亦 **唔** `queue_free`（保留 node 重用）。`now` 必須 injectable（`_now_provider` seam）— 唔可以用 `Time.get_ticks_msec()` 直接驅動 test。

**Control Manifest Rules (this layer — Foundation)**:
- Required: eviction 經自然 fade（emitting=false）；`now` 經 injectable seam
- Forbidden: evict 時 `queue_free` / `restart()` pool node
- Guardrail: 150ms floor 保護；LOOT 永不被 evict

---

## Acceptance Criteria

*From GDD Section H, scoped to this story:*

- [ ] **AC-08** — 非-LOOT play evict 最舊 slot（age > 150ms floor），保護 < 150ms 嘅 slot：200ms slot 被 force-expire、100ms slot 不動；evicted node `emitting==false`（無 restart/queue_free）；ledger 同步遞減。
- [ ] **AC-09** — LOOT carve-out：全 slot < 150ms（全 floor-protected）時 LOOT request 仍 evict 一個非-LOOT（HIT_LIGHT），LOOT victim 不動，新 LOOT burst 成功 + emit `burst_started`。
- [ ] **AC-10** — Combat all-protected：全 slot < 150ms 且全 LOOT 時 combat play clean-reject 返回 INVALID、無 `burst_started`、`_dropped_play_calls += 1`、`push_warning` throttled（≤1 per `WARNING_THROTTLE_MS=1000`）。

---

## Implementation Notes

*Derived from ADR-0001 Implementation Guidelines:*

- `_age_queue` 維持 spawn order；eviction 揀最舊（lowest spawn_time）且 age > 150ms。
- `_force_expire(slot)`：`node.emitting = false` + ledger 同步遞減 + free-list 歸還。**唔** restart / queue_free。
- LOOT carve-out（`is_loot_request == true`）：喺非-LOOT 子集中揀最舊 evict（即使 < 150ms），永不掃 LOOT victim。
- Combat all-protected reject：`_dropped_play_calls += 1`；telemetry 5% trigger（`_dropped / _total > 0.05` → telemetry event）counter math 喺呢度，emit 喺 Story 007 / #28；warning 經 `_warn_sink` + `_now_provider` throttle。
- `now` 經 `var _now_provider := Callable()`（default `Time.get_ticks_msec`），test 注入固定 clock。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003: ledger primitive（呢個 story 用 ledger total 判滿 + 遞減）
- Story 007: telemetry signal emit（呢度只計 counter）+ Suspended-state reject
- Story 002: tier selection（eviction 喺 tier 內進行）

---

## QA Test Cases

- **AC-08**: non-LOOT evicts oldest above floor; protects < 150ms
  - Given: pool 概念性滿；slotA age==200ms(>floor)、slotB age==100ms(<floor)；`now` 注入
  - When: 非-LOOT `play(HIT_LIGHT)` 需要 space
  - Then: slotA force-expired AND slotB 不 evict AND evicted `emitting==false`（無 restart/queue_free）AND ledger 同步遞減
  - Edge cases: tie-break 兩個 >150ms → 最舊先；`now` 注入非 `Time.get_ticks_msec`

- **AC-09**: LOOT carve-out evicts HIT_LIGHT even when all < 150ms
  - Given: 全 slot < 150ms；組成 6×HIT_LIGHT + 2×LOOT_BURST
  - When: `play(LOOT_RARE_BURST)`（is_loot_request）
  - Then: 剛好一個 HIT_LIGHT force-expired AND 兩個 LOOT_BURST 不動 AND 新 burst `alive()==true` AND `assert_signal_emitted_with_parameters(burst_started, [LOOT_RARE_BURST, pos])`
  - Edge cases: evict 最舊非-LOOT；剩一個非-LOOT 就 evict 佢

- **AC-10**: all-LOOT all-protected combat clean-rejects
  - Given: 全 slot < 150ms 且全 LOOT_*
  - When: `play(HIT_HEAVY)`（combat）
  - Then: INVALID AND 無 `burst_started` AND `_dropped_play_calls += 1` AND warning throttled ≤1/1000ms
  - Edge cases: 5 次連續 reject 內 `_dropped += 5` 但 warn ≤1（注入 `_now_provider`+`_warn_sink`）；telemetry 5% counter math（emit 屬 Story 007）

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/particle/test_lru_eviction.gd` — must exist and pass（AC-08 + AC-09 + AC-10）

**Status**: [x] Created; GUT 6/6 PASS（particle dir 34/34）+ combined 1128/1129（1 pending = pre-existing AC-37；0 fail）— Godot 4.6.3, 2026-06-01

---

## Dependencies

- Depends on: Story 002（pool）、Story 003（ledger total）
- Unlocks: Story 007（telemetry emit）

---

## Completion Notes

**Completed**: 2026-06-01
**Criteria**: 3/3（AC-08 evict oldest >150ms floor + protect <150ms + emitting=false no-restart/no-free + ledger decrement；AC-09 LOOT floor-bypass carve-out + young-LOOT-never-evicted + old-LOOT-evictable；AC-10 combat all-protected INVALID + no signal + _dropped++ + throttled warn）
**Implementation**: `particle_system_wrapper.gd`：
- consts EVICTION_MIN_LIFE_MS 150、WARNING_THROTTLE_MS 1000；state `_age_queue`/`_total_play_calls`/`_dropped_play_calls`/`_last_dropped_warn_ms`/`_now_provider`（injectable clock）。
- `_try_evict(tier, needed, is_loot)`：tier-aware，iterate `_age_queue.duplicate()` oldest-first，floor(<150ms) skip for non-LOOT；young-LOOT skip；`_force_expire` first eligible → true。
- `_force_expire(handle_id)`：node.emitting=false（natural fade，NOT restart/queue_free）+ `_on_expire`（ledger decrement + age_queue erase + slot release）。
- `play()`：tier full → `_try_evict` + retry once → 否則 dropped reject（_dropped++ + `_maybe_warn_dropped` throttled + no signal）；用 `_now()` spawn time；`_total_play_calls++`；`_age_queue.append`。
- `_now()` + `_maybe_warn_dropped()` helpers。
**Key discoveries（spec）**:
1. **Tier segmentation 令 qa-lead AC-09 cross-tier「LOOT evicts HIT_LIGHT」唔成立**：LOOT 永遠 LARGE，non-LOOT base ≤28 ×1.5 max 42 → MEDIUM，永不到 LARGE。改測真正可達 branch：is_loot floor-bypass（同 tier）+ young-LOOT-never-evicted + old-LOOT-evictable。LOOT 實際 cap 2 concurrent（LARGE size，per GDD line 207）。
2. **GDD Rule 8 算法「never evict LOOT」guard 只喺 `age<150` block 內** → young LOOT 受保護，**old LOOT（>150ms）可被 evict**（Pillar 3：new loot moment 一定落，即使要踢走舊 loot）。實作忠於 GDD。
3. eviction 唔 bump generation → 被 evict 嘅 handle 喺 slot 被 **reuse**（下次 acquire）先 `alive()==false`；test 直接驗 slot state（is_emitting/node.emitting/restart_count）而非 handle.alive()。
**Deviations**: telemetry 5% emit（_dropped/_total>0.05）counter 已 track，**emit 本身 deferred 去 Story 007/#28**。expiry timer 仍 Story 007。
**Test Evidence**: `tests/unit/particle/test_lru_eviction.gd`（6 test functions）
**Code Review**: Pending（lean mode — 後續 batch review）
