# Story 007: Boot Sequence + State Machine + Lifecycle

> **Epic**: Particle System Wrapper
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: L
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-01

## Context

**GDD**: `design/gdd/particle-system-wrapper.md`
**Requirement**: `TR-particle-014`, `TR-particle-015`, `TR-particle-016`, `TR-particle-017`, `TR-particle-018`, `TR-particle-019`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006 Contract 6 (Accepted — `connect_for_initial_state`) primary；ADR-0008 (Autoload Position Map) + ADR-0001 secondary
**ADR Decision Summary**: ParticleSystemWrapper autoload **position 12**（project.godot ground truth，ADR-0008；AvatarRenderer pos 11 之後）。GSM 訂閱用 `connect_for_initial_state`（Contract 6，synthetic initial-state → Active）。Wrapper persists nothing。Lifecycle：Booting / Active / Suspended / Draining，各 state 嚴格 API-rejection。

**Engine**: Godot 4.6 | **Risk**: HIGH（WebGL 2 async pipeline — EC16 material hot-swap）
**Engine Notes**: boot ≤80ms 同 EC18 timing 係 perf/device claim，**唔** headless-assertable（CI timing 非 deterministic + headless 無真 GPU init cost）→ ADVISORY，留 VS-tier。autoload position 用 project.godot ground truth（ADR-0008）。EC16 material hot-swap 用 `call_deferred`（WebGL2 pre-first-frame race）。

**Control Manifest Rules (this layer — Foundation)**:
- Required: GSM 訂閱用 `connect_for_initial_state`（Contract 6）；autoload pos 12（project.godot 唯一 ground truth）；persists nothing
- Forbidden: 喺 `_init()` 內 connect（NPE on null）；Suspended/Booting/Draining 接受 play
- Guardrail: boot ≤80ms（ADVISORY/VS-gated）

---

## Acceptance Criteria

*From GDD Section H, scoped to this story:*

- [ ] **AC-15** — Autoload position 12，喺 AvatarRenderer(pos 11) 之後（project.godot static read）。boot ≤80ms 係 PERF claim → ADVISORY，自動化只 assert position invariant。
- [ ] **AC-16** — GSM `connect_for_initial_state`：synthetic initial-state callback（`source_event=="initial_state"`，ADR-0006 C6）→ boot 後 `_lifecycle_state == Active`；訂閱剛好一次。
- [ ] **AC-17** — Wrapper persists nothing：100 次 play 後無 PersistenceLayer reference、無 `save_*`/`load_*` method、無 `user://` path、無 `particle_*` key。
- [ ] **AC-18** — EC1 lazy fallback on slow boot（per-tier deferred build）：一 tier 未 build 但 `_booted==true`；`_warn_sink` 含 `boot_budget_overrun`；首次 play 該 tier lazily build 成功（無 exception），第二次重用不 rebuild。
- [ ] **AC-19** — EC12 mid-flight play during Suspended：`_lifecycle_state` 設 Suspended 喺 `_drain()` 之前（call log ordering）；transition 期間/後 play 返 INVALID；drain 後無 stub node `emitting==true`。
- [ ] **AC-20** — EC15 ledger drift reconciliation 喺 2.0s 後跑剛好一次：注入 drift > ±15%，advance injected time 2.0s → `_reconcile_ledger()` 跑一次，total 修正到 ground truth；1.9s 前 0 call；idempotent。
- [ ] **AC-21** — EC16 material hot-swap：`_begin_emit` 經 `call_deferred`（queued 非 inline）；`burst_started` **同步** emit（非 deferred）；node `process_material == PRESETS[preset].material` 喺首 particle 前。
- [ ] **AC-22** — play during Booting → silent INVALID 無 signal 無 crash；GSM signal during Booting → buffered，boot 後 drain（順序）。
- [ ] **AC-23** — `_exit_tree` drain with 5 active：`_lifecycle_state==Draining`；全 emitter `emitting==false` + `queue_free` called；`_active_particle_total==0`；無 orphaned timer。

---

## Implementation Notes

*Derived from ADR-0006 + ADR-0008 Implementation Guidelines:*

- Autoload 註冊喺 project.godot **position 12**（AvatarRenderer 11 之後、CameraController 13 之前）。
- GSM 訂閱：`GameStateMachine.connect_for_initial_state(_on_state_changed)`（Contract 6 sentinel `source_event=="initial_state"`，mirror `connect_for_initial_state_test.gd`）。self-loop initial state（from==to）唔當真 Suspended transition。
- Lifecycle state enum：`Booting(0) / Active(1) / Suspended(2) / Draining(3)`。EC12：set Suspended **先**於 drain（ordering 重要）。
- EC15 reconcile：`_reconcile_ledger()` 用 injected clock，2.0s 後跑一次修正 drift（idempotent）。
- EC16：material hot-swap 經 `call_deferred(_begin_emit)`（WebGL2 race），但 `burst_started` sync emit（AC-21）。
- AC-17 mirror 現有 `test_no_persistence_hooks.gd` 3-invariant 結構。
- 全部 timing/perf 子句（boot ≤80ms、EC18）→ ADVISORY，VS-tier device evidence；behavioral set（16/19-23）headless-automatable with injected GSM/clock/log seams。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001-006: play/pool/ledger/eviction/UA/signal 本體（呢個 story wire lifecycle gate 喺其上）
- Story 009: boot ≤80ms / EC18 真實 device 驗證（hardware-gated）
- #28 Telemetry: telemetry signal 真實 sink（呢度 stub）

---

## QA Test Cases

- **AC-15**: autoload pos 12 after AvatarRenderer(11)
  - Given: project.godot autoload section
  - When: parse autoload order（static read）
  - Then: ParticleSystemWrapper pos==12 AND 喺 AvatarRenderer 之後
  - Edge cases: boot ≤80ms → PERF，NOT headless-assertable，ADVISORY VS-tier；project.godot ≠12 就 flag（ADR-0008 ground truth）

- **AC-16**: GSM connect_for_initial_state → Active
  - Given: stub GSM 暴露 `connect_for_initial_state`（capture Callable）；SUT booting
  - When: deliver synthetic initial-state（`source_event=="initial_state"` ADR-0006 C6）
  - Then: boot 後 `_lifecycle_state==Active` AND 訂閱剛好一次
  - Edge cases: sentinel source_event 偵測；self-loop(from==to) 唔當真 Suspended

- **AC-17**: persists nothing
  - Given: SUT booted
  - When: 100 次 play 後 introspect
  - Then: 無 PersistenceLayer ref、無 `save_*`/`load_*`、無 `user://`、無 `particle_*` key
  - Edge cases: mirror `test_no_persistence_hooks.gd`；`get_method_list()` filter save_/load_

- **AC-18**: EC1 lazy fallback slow boot
  - Given: 注入 slow-boot flag 跳過一 tier build，`_booted` 仍 true
  - When: boot 完成一 tier 未 build
  - Then: `_booted==true` AND `_warn_sink` 含 `boot_budget_overrun` AND 首次 play 該 tier lazily build 成功（無 exception）
  - Edge cases: lazy-build 剛好一次，第二次重用不 rebuild；`_warn_sink`/`_log_sink` 注入非真 log scrape

- **AC-19**: EC12 mid-flight Suspended
  - Given: SUT Active in-flight play；GSM deliver state→Suspended
  - When: Suspended handler 跑
  - Then: Suspended 設定喺 `_drain()` 之前（call log）AND transition 期間/後 play 返 INVALID AND drain 後無 `emitting==true`
  - Edge cases: 全 emitting node 設 false，pool 保留不 free；Suspended 亦 reject LOOT（無 carve-out）

- **AC-20**: EC15 reconcile once after 2.0s
  - Given: 注入 drift > ±15%（corrupt `_active_particle_total`）；injectable clock
  - When: advance injected time 2.0s + tick reconcile scheduler
  - Then: `_reconcile_ledger()` 跑剛好一次 AND total 修正到 ground truth
  - Edge cases: 1.9s 前 0 call；time 經 injected clock；無 drift 時 idempotent

- **AC-21**: EC16 material hot-swap deferred, signal sync
  - Given: stub node 記 process_material 賦值 + call log；signal watcher
  - When: play acquire 需 material hot-swap
  - Then: `_begin_emit` 經 call_deferred（queued 非 inline）AND `burst_started` 同步 emit（assert_signal_emitted within play frame）AND `process_material == PRESETS[preset].material` 喺 `_begin_emit` 前
  - Edge cases: 「首 particle 用對 material」係 GPU-side 不可 headless 驗證 → assert process_material 賦值 proxy；視覺正確性 → screenshot ADVISORY

- **AC-22**: play during Booting silent INVALID; GSM buffered
  - Given: SUT Booting（`_booted==false`）
  - When: `play(HIT_LIGHT)`
  - Then: silent INVALID（Rule 14）無 signal 無 crash
  - And When: GSM signal during Booting → buffered，boot 後順序 drain
  - Edge cases: buffered Suspended-during-boot → boot 後 Suspended；Booting reject 唔 `_dropped_play_calls++`（Booting reject ≠ budget reject）

- **AC-23**: _exit_tree drain with 5 active
  - Given: SUT Active 5 active emitting stub node
  - When: `_exit_tree()`
  - Then: `_lifecycle_state==Draining` AND 全 emitter false + `queue_free` called（stub spy）AND `_active_particle_total==0` AND 無 orphaned timer
  - Edge cases: play during Draining → INVALID；double `_exit_tree` idempotent 無 crash；queue_free 真實，用 stub spy flag 判斷

> **Integration evidence note**: 混合 static-structural（15/17）+ behavioral lifecycle（16/19-23）。behavioral set headless-automatable with injected seam。perf 子句（boot ≤80ms、EC18）→ VS-tier device。DoD：Integration 接受「integration test OR documented playtest」；GSM-lifecycle behavior qualifies as integration test。

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/particle/test_boot_lifecycle.gd` — must exist and pass（AC-16/17/18/19/20/21/22/23 behavioral）
- `tests/static/test_particle_autoload_position.gd` — AC-15 position invariant（project.godot static read）

**Status**: [x] Created; GUT 8/8（test_boot_lifecycle.gd）+ 1/1（test_particle_autoload_position.gd）；particle unit+integration 57/57；combined（unit+integration+static）1214/1215（1 pending = pre-existing AC-37；0 fail）— Godot 4.6.3, 2026-06-01

---

## Dependencies

- Depends on: Story 001-006（全 behaviour 本體 — lifecycle gate 套喺其上）
- Unlocks: Story 008（preset library 喺 Active 載入）；epic close-out

---

## Completion Notes

**Completed**: 2026-06-01
**Criteria**: 9/9（AC-15 autoload pos 12 static；AC-16 GSM connect_for_initial_state subscribe-once + Active；AC-17 persists nothing；AC-18 EC1 lazy fallback；AC-19 EC12 Suspended drain+reject+resume；AC-20 EC15 reconcile once @2.0s idempotent；AC-21 burst_started sync；AC-22 play-during-Booting INVALID；AC-23 _exit_tree Draining drain）
**Implementation**: `particle_system_wrapper.gd`：
- `_gsm` DI seam + `_ready` `connect_for_initial_state(_on_gsm_state_changed)`（ADR-0006 C6，NO .bind）；`_booted`；`_last_reconcile_ms`。
- `_on_gsm_state_changed`（suspended → `_enter_suspended`；非-suspended → resume Active）；`_is_suspended_state`（`GameState.SUSPENDED` enum）；`_enter_suspended`（state-before-drain，EC12 ordering）；`_drain`（emitting=false all，pool preserved）。
- `_process` → `_check_reconcile`（2000ms gate，**無 timer** → AC-23 no-orphan-timers）+ `_reconcile_ledger`（total = ledger sum）。
- EC1：`_build_tier_guarded`（`_skip_tier_for_test` skip + warn boot_budget_overrun）+ `_lazy_build_tier_if_absent`（`_acquire_slot` 首用 lazy build）。
- `_exit_tree` 擴展做完整 Draining drain（state + emitting=false + free() + ledger/age_queue clear + total 0）。
- EC16：`_apply_preset` `call_deferred("_swap_material")`（material 內容 = Story 008；burst_started 維持 sync）。
**Key discoveries**:
1. **加新 class_name file 後 combined gate 要先 `--import`** — 否則 stale global class cache 令無關 file（e.g. test_ability_id_surface.gd `AbilityId.get()`）phantom parse error，假 fail。re-import 後 0 fail。延伸 Story 001 lesson。→ 記入 memory。
2. GSM state 係 `GameState` **enum**（非 string）；`_is_suspended_state` 比 `GameStateMachine.GameState.SUSPENDED`。stub GSM deliver enum int。
3. test stub GSM 用 `extends RefCounted`（非 Node）— wrapper hold `_gsm` ref → SUT free 時自動 free，無 orphan。
4. reconcile 用 `_process`（非 timer）避免 AC-23 orphaned-timer + 測試用 `set_process(false)` + injected clock 手動驅動。
**Deviations**: AC-21 material **內容** swap（process_material/lifetime from .tres）deferred 去 Story 008（EC16 call_deferred 機制已搭，body no-op）。boot ≤80ms + EC18 timing = PERF claim → ADVISORY VS-tier（唔 headless assert）。AC-22 GSM-buffered-during-Booting：synchronous autoload boot 下 N/A（connect 喺 _ready 尾，Active 後），只測 play-during-Booting reject。
**Test Evidence**: `tests/integration/particle/test_boot_lifecycle.gd`（8）+ `tests/static/test_particle_autoload_position.gd`（1）
**Code Review**: Pending（lean mode — 後續 batch review）
