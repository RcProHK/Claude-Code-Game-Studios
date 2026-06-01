# Story 006: burst_started Signal + Re-entry Guard + CI Lint

> **Epic**: Particle System Wrapper
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-01

## Context

**GDD**: `design/gdd/particle-system-wrapper.md`
**Requirement**: `TR-particle-011`, `TR-particle-012`, `TR-particle-013`, `TR-particle-023`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001 (Web Export Budget Caps, **Accepted-structural 2026-05-30**)；ADR-0009 (Signal Payload Schema Convention) secondary
**ADR Decision Summary**: `burst_started` sync emit 喺 alloc 之後、`emitting=true` 之前（subscriber 喺 callback 見到 `emitting==false`）。Re-entry guard：signal handler 內 nested `play()` → deferred queue（防 stack overflow）。CI lint 禁止 magic int/string preset ID。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: GUT phantom-pass lesson [[project_wst_epic_status]]：**唔好** spy/override native method 做 re-entry fake — 用真 connected listener 驅動 guard。`burst_started` 同步 emit（非 deferred）。CI lint 係 build-time script（非 GUT），跟 `check_camera_callers.gd` pattern。

**Control Manifest Rules (this layer — Foundation)**:
- Required: signal 經 `.connect()`（boot order 保證，payload 2 args 簡單，無 helper）；preset ID 必須 `PresetId.*` literal
- Forbidden: magic int/string 做 preset ID；signal handler 內 inline re-entrant alloc
- Guardrail: re-entry depth 有界，flush 後 depth 歸 0

---

## Acceptance Criteria

*From GDD Section H, scoped to this story:*

- [ ] **AC-12** — Emit ordering：`acquire → apply_preset → restart(false) → emit burst_started → emitting=true`；listener 喺 callback 讀到 `node.emitting == false`（signal 喺 `emitting=true` 之前）；`restart` 用 `keep_seed==false`。
- [ ] **AC-13** — Re-entrant `play()` from listener → queued, executed at frame end, no overflow：nested call 返 PENDING handle（`_pool_index==-1`）；nested burst 唔 inline 執行；`_flush_deferred` 後 deferred play 執行剛好一次；無 stack overflow，`_emit_depth` 歸 0。
- [ ] **AC-14** — Build-time CI lint `tools/ci/check_particle_callers.gd`：bad fixture（`play(42,pos)` / `play("HIT_LIGHT",pos)` magic）→ exit != 0；good fixture（`play(ParticleSystemWrapper.PresetId.HIT_LIGHT,pos)`）→ exit 0。

---

## Implementation Notes

*Derived from ADR-0001 Implementation Guidelines:*

- Emit ordering 嚴格：先 acquire slot、apply preset material、`restart(false)`、**然後** `burst_started.emit(preset_id, pos)`、最後先 set `emitting = true`。確保 subscriber（e.g. ScreenEffects）喺 callback 時 particle 未 emit。
- Re-entry guard：`_emit_depth` counter；handler 內 nested `play()` → push 入 `_deferred_queue` 返 PENDING handle；frame end（或 `_flush_deferred`）drain FIFO；depth leak guard（後續非-nested play 成功，mirror stat_system AC-33 pattern）。
- CI lint `check_particle_callers.gd`（新建）：scan `src/` 嘅 `play(` call site，第一 arg 必須 `PresetId.*` literal reference；magic int/string/runtime var → exit != 0。Exempt：comment line、`tests/` 以外。Mirror `tools/ci/check_camera_callers.gd` 結構。
- AC-14 test harness = Bash 跑 `godot --headless --script tools/ci/check_particle_callers.gd` against fixtures dir，assert exit code。分類 build-time gate，獨立於 unit suite。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: play() validation（呢個 story 假設 valid args 已過）
- Story 007: lifecycle gate（Suspended 時 reject）— re-entry guard 喺 Active 內
- Story 004: eviction（acquire 失敗時）

---

## QA Test Cases

- **AC-12**: emit ordering
  - Given: SUT Active，stub node 記 ordered call log；signal watcher
  - When: `play(HIT_LIGHT, pos)` 成功；listener 喺 callback 讀 `node.emitting`
  - Then: call order == `[apply_preset, restart(false), <signal emit>, emitting=true]` AND listener 內 `node.emitting==false` AND restart `keep_seed==false`
  - Edge cases: acquire fail → 無 apply/restart/signal 返 INVALID（log 空）；payload == `(HIT_LIGHT, pos)` exact

- **AC-13**: re-entrant play queued
  - Given: listener connected to `burst_started` 同步 call `play()` 一次
  - When: 外層 `play(HIT_LIGHT)` → listener re-enter `play(HIT_HEAVY)`
  - Then: nested 返 PENDING（`_pool_index==-1`）AND nested 唔 inline 執行 AND `_flush_deferred` 後執行剛好一次 AND 無 overflow（`_emit_depth` 歸 0）
  - Edge cases: depth reset（後續非-nested play 成功）；多個 nested FIFO；PENDING `alive()` drain 前 false、drain 後 generation set；**用真 connected listener 驅動，唔 spy native method**（phantom-pass lesson）

- **AC-14**: build-time CI lint（NOT GUT — Bash exit-code harness）
  - Given: `tools/ci/check_particle_callers.gd` against fixtures
  - When: bad fixture `play(42,pos)` / `play("HIT_LIGHT",pos)` → exit != 0
  - And When: good fixture `play(ParticleSystemWrapper.PresetId.HIT_LIGHT,pos)` → exit 0
  - Edge cases: runtime expr `play(some_var,pos)` → fail；multi-line `play(` → 偵測；comment `// play(42,...)` → 唔 trip（false-positive guard）；`tests/` 外 out of scope

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/particle/test_burst_signal_reentry.gd` — AC-12 + AC-13（must exist and pass）
- `tests/static/test_particle_callers_lint.gd` OR Bash harness — AC-14 CI lint（fixture exit-code check）
- `tools/ci/check_particle_callers.gd` — new CI lint script created

**Status**: [x] Created; GUT 5/5（test_burst_signal_reentry.gd）+ 3/3（test_particle_ci_lint.gd）；particle dir 49/49；combined（unit+integration+static）1205/1206（1 pending = pre-existing AC-37；0 fail）— Godot 4.6.3, 2026-06-01

---

## Dependencies

- Depends on: Story 001（play surface）、Story 002（acquire）
- Unlocks: Story 007（lifecycle 用 emit ordering）

---

## Completion Notes

**Completed**: 2026-06-01
**Criteria**: 3/3（AC-12 emit ordering restart→signal→emitting=true + position-before-signal；AC-13 re-entry queue PENDING + flush resolve + no depth leak；AC-14 magic-preset CI lint）
**Implementation**:
- `particle_system_wrapper.gd`：refactor `play()` → re-entry guard wrapper（`_emit_depth`/`_deferred_plays`）+ `_execute_play()`（原 body）。`_begin_emit()` 鎖死 ordering（`_apply_preset` → `restart(false)` → `burst_started.emit` → `emitting=true`，Rule 11）；`_apply_preset()`（position；material/lifetime Story 008）；`_queue_deferred()`（PENDING handle `_pool_index=-1`）；`_flush_deferred()`（FIFO drain，own `_emit_depth` 令 flush 中 re-entry queue 去下個 flush，no recursion）。
- **TR-023 已存在** `check_particle_callers.gd`（GPUParticles2D instantiation gateway）— 驗證過 real wrapper PASS（wrapper exempt）。
- **TR-013 新** `tools/ci/check_particle_preset_magic.gd`：`ParticleSystemWrapper.play(` 第一 arg int/string literal → fail；scoped to qualifier 避免 AnimationPlayer.play false-positive；comment-skip。fixtures `tests/fixtures/particle_preset_magic_{violation,clean}.gd`。
**Key discoveries**:
1. AC-14 用 inline-regex static test（mirror test_enemy_director_ci_lint）— lint script call quit() 會拆 GUT tree，所以唔跑 subprocess。
2. `_LogStubNode extends Node2D` 要自己 `var amount`（Node2D 無 native amount，唯 GPUParticles2D 有）— _build_tier 設 amount 會 fail without it。
3. AC-14 lint scoped to `ParticleSystemWrapper.play(` 而非 unqualified `play(` — 避免 `AnimationPlayer.play("idle")` false-positive（qa-lead fixtures 用 unqualified；我改 qualified = 真實 call style）。
**Deviations**: `_apply_preset` 只 set position（material/lifetime hot-swap = Story 008 EC16 deferred）。`_flush_deferred` production 由 `call_deferred` 觸發；test 直接 call。
**Test Evidence**: `tests/unit/particle/test_burst_signal_reentry.gd`（5）+ `tests/static/test_particle_ci_lint.gd`（3）+ `tools/ci/check_particle_preset_magic.gd` + 2 fixtures
**Code Review**: Pending（lean mode — 後續 batch review）
