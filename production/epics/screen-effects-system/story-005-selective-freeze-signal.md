# Story 005: Selective Freeze + PROCESS_MODE_ALWAYS + hit_pause_started Signal

> **Epic**: Screen Effects System
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-01

## Context

**GDD**: `design/gdd/screen-effects-system.md`
**Requirement**: `TR-screen-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001 (Web Export Budget Caps, **Accepted-structural 2026-05-30**) primary; ADR-0006 Contract 4 secondary
**ADR Decision Summary**: Hit pause = selective freeze via `get_tree().paused = true`，**唔用** `Engine.time_scale`（會凍 autoload delta timer）。所有 autoload `_ready` 設 `PROCESS_MODE_ALWAYS` → hit pause 期間繼續 tick（GymSys polling 唔 missed，GSM 唔 desync）。emit `hit_pause_started(duration_ms: int)` signal 畀 #4 AudioManager（AudioServer 唔聽 SceneTree.paused）。

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: GUT headless 跑真 SceneTree — `get_tree().paused` flag real 可讀。但無 deterministic frame loop → pause timer decrement 用手動 `_sut._process(delta)` 驅動。**`get_tree().paused` 必須喺 `after_each` restore false**，否則污染後續 test。`hit_pause_started` + `paused=true` 必須 synchronous（同 frame，no call_deferred）。

**Control Manifest Rules (this layer — Foundation)**:
- Required: selective freeze via `get_tree().paused`；ScreenEffects `PROCESS_MODE_ALWAYS`
- Forbidden: `Engine.time_scale` mutation（CI enforced）
- Guardrail: autoload 層 hit pause 期間繼續 tick（Falsifiable Test #3）

---

## Acceptance Criteria

*From GDD Section H, scoped to this story:*

- [ ] **AC-12** [Falsifiable #3] — `hit_pause(0.12)` → `get_tree().paused=true`；ScreenEffects（PROCESS_MODE_ALWAYS）繼續 tick（pause timer decrement）；PAUSABLE gameplay node freeze；timer drain 後 `get_tree().paused=false`。
- [ ] **AC-13** — HitPaused → Active：`get_tree().paused=false` within 1 frame；`hit_pause_started` signal **唔** re-emit on exit。
- [ ] **AC-25** — entering HitPaused：`hit_pause_started(duration_ms: int)` emit 同 frame 同步於 `get_tree().paused=true`（no 1-frame lag）；`duration_ms ≤ 120`。

---

## Implementation Notes

*Derived from ADR-0001 + GDD Rules 10 / Interaction #6:*

- `hit_pause(d)` 成功 → enter HitPaused：set `get_tree().paused = true`（synchronous，no call_deferred）；`hit_pause_started.emit(int(round(_pause_remaining_sec * 1000)))` 同 frame；`_state = HitPaused`。
- ScreenEffects `_ready`：`process_mode = PROCESS_MODE_ALWAYS`（自己 hit pause 期間繼續 tick）。其他 autoload 各自 `_ready` 設 ALWAYS（FR-3，drift CI = Story 011/AC-29）。
- `_process(delta)` 喺 HitPaused：`_pause_remaining_sec -= delta`；`<= 0` → `_exit_hit_paused`（`get_tree().paused = false`，`_state = Active`，**唔** re-emit signal）。
- signal payload `duration_ms` int（per Q-F1 default）≤ 120（Rule 2 ceiling clamp guaranteed）。
- `signal hit_pause_started(duration_ms: int)`。

---

## Out of Scope

*Handled by neighbouring stories:*

- Story 004: `_pause_remaining_sec` formula（呢度用 formula 結果驅動 freeze）
- Story 007: Suspended override（force release paused）+ bfcache
- Story 002: shake decay（HitPaused 期間凍結 — cross-ref Rule 4，呢度只驗 pause path）

---

## QA Test Cases

> **Precondition seams**: `_clock` injectable（控制 delta）；`_pause_remaining_sec`/`process_mode`/`_state` readable；`watch_signals(_sut)`。**CRITICAL**: `after_each` 強制 `get_tree().paused=false`（即使 test 中途 assert paused），否則毒害成個 run。Headless 真 SceneTree → paused flag real；timer decrement 用手動 `_sut._process(delta)`。

- **AC-12**: selective freeze + always-tick + auto-resume
  - Given: SUT ACTIVE；`PROCESS_MODE_ALWAYS`；`_clock` 控制 delta；`_pause_remaining_sec=0`
  - When: `hit_pause(0.12)` → `get_tree().paused==true` AND `_sut.process_mode == Node.PROCESS_MODE_ALWAYS`
  - When2: 手動 8× `_sut._process(0.015)`（sum 0.12s）— SUT 即使 paused 都 decrement（證 ALWAYS）
  - Then2: `get_tree().paused==false`；`assert_almost_eq(_pause_remaining_sec, 0.0, 0.001)`
  - Edge: 加一個 PROCESS_MODE_PAUSABLE dummy counter node 入 tree，assert 其 `_process` 喺 paused 期間 **冇** run（證 selective）。Headless: 手動 tick 唔靠真 frame；after_each restore paused。

- **AC-13**: exit no re-emit
  - Given: SUT HitPaused（paused=true，`_pause_remaining_sec≈0.001`）；`watch_signals(_sut)`
  - When: `_sut._process(0.002)`（drain → Active）
  - Then: `get_tree().paused==false`；`assert_signal_not_emitted(_sut, "hit_pause_started")`（signal 只 enter 時 fire）
  - Edge: exit path 唔 call enter handler。

- **AC-25**: synchronous signal + duration_ms
  - Given: SUT ACTIVE；`watch_signals(_sut)`；`_pause_remaining_sec=0`
  - When: `hit_pause(0.12)`
  - Then: `assert_signal_emitted(_sut, "hit_pause_started")`；`params = get_signal_parameters(_sut, "hit_pause_started", 0)`；`typeof(params[0]) == TYPE_INT`；`params[0] <= 120`；`get_tree().paused==true`（同 call 同步，no await）
  - Edge: `hit_pause(0.06)` → `duration_ms == 60`（sec→ms ×1000 int-cast）。**若 implementation 用 call_deferred set paused → AC fail by contract**（必須 inline）。

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/screen_effects/test_screen_effects_freeze.gd` — must exist and pass（AC-12, AC-13, AC-25）

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 004（`_pause_remaining_sec` formula）
- Unlocks: Story 007（Suspended releases freeze）；#4 AudioManager（hit_pause_started subscriber，pending GDD）
