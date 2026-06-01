# Story 008: Boot Sequence + Autoload Pos 14 + CI Lint + Persistence Ban

> **Epic**: Screen Effects System
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-01

## Context

**GDD**: `design/gdd/screen-effects-system.md`
**Requirement**: `TR-screen-009`, `TR-screen-013`, `TR-screen-014`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001 (Web Export Budget Caps, **Accepted-structural 2026-05-30**) primary; ADR-0006 Contract 6 secondary
**ADR Decision Summary**: ScreenEffects autoload **position 14**（project.godot ground truth，ADR-0008；after ParticleSystemWrapper pos 12）。GSM 訂閱 `connect_for_initial_state`（ADR-0006 Contract 6，NO .bind）。震動 via shader uniform `u_shake_offset`（NOT `Camera2D.offset`）— CI lint `check_screen_effects_callers.gd` enforce。Persists nothing（Rule 16）。

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: CI lint test 用 inline RegEx + comment-skip + violation/clean/real-source 三段式（mirror `test_particle_ci_lint.gd` — lint script `quit()` 拆 GUT tree，唔 spawn subprocess）。**Owner-vs-caller scoping**：`screen_effects.gd` 本身合法 set `get_tree().paused` + `u_shake_offset`（佢係 owner）；ban 係針對其他 file — test pattern 要對齊 `check_screen_effects_callers.gd` 嘅 partition。autoload pos test = static read project.godot。

**Control Manifest Rules (this layer — Foundation)**:
- Required: autoload pos 14（project.godot 唯一 ground truth，ADR-0008）；`connect_for_initial_state`；persists nothing
- Forbidden: `Camera2D.offset` / `Engine.time_scale` / `get_tree().paused` / `u_shake_offset` write outside `screen_effects.gd`（CI enforced）；`.bind()` on connect_for_initial_state
- Guardrail: zero persistence reference

---

## Acceptance Criteria

*From GDD Section H, scoped to this story:*

- [ ] **AC-21** [Falsifiable #6] — `check_screen_effects_callers.gd`：其他 file 含 `Camera2D.*.offset=` / `Engine.time_scale=` / `get_tree().paused=` / `global_shader_parameter_set("u_shake_offset"` → build fail（exit 1）；`screen_effects.gd`（owner）合法用 paused/uniform 唔 flag。
- [ ] **AC-22** — Persistence ban：new session boot → `_trauma=0`、`_motion_intensity=1.0`（EC-15 default）、`_pause_remaining_sec=0`；無 `PersistenceLayer` reference、無 `save_*`/`load_*` method、無 `user://` path。
- [ ] **AC（boot）** — autoload pos 14（after ParticleSystemWrapper pos 12，static read）；`connect_for_initial_state` called exactly once at `_ready`。

---

## Implementation Notes

*Derived from ADR-0001 + ADR-0006 + GDD Rules 13/15/16:*

- 註冊 ScreenEffects autoload @ project.godot **pos 14**（ScreenEffects 已喺 project.godot pos 14 — 確認唔好移）。
- `_ready`：`process_mode = PROCESS_MODE_ALWAYS`；register global shader uniform；`GameStateMachine.connect_for_initial_state(_on_gsm_state_changed)`（NO .bind）；`_state = Active`。
- 新 CI lint `tools/ci/check_screen_effects_callers.gd`（mirror `check_particle_callers.gd` structure）：scan `src/` outside `screen_effects.gd`（owner exempt）+ `tests/` + `tools/debug/`；forbidden patterns（4 條 regex）→ exit 1。**Owner partition**：`get_tree().paused=` + `u_shake_offset` write 喺 owner 合法；`Camera2D.offset` + `Engine.time_scale` 喺 owner 都唔應出現（owner 用 paused，唔用 time_scale）。
- Persistence ban：ScreenEffects 無 `_persistence` member、無 save/load method、無 `user://`。`_motion_intensity` default 1.0（EC-15；SettingsManager setter override — Story 009）。
- 注意：`_DISPATCH` keys ⊆ PresetId enum drift check 可加入呢個 lint OR Story 011（FR-3 EXPECTED_AUTOLOADS）— 呢度做 caller ban + autoload pos。

---

## Out of Scope

*Handled by neighbouring stories:*

- Story 007: `_on_gsm_state_changed` handler 行為（呢度只 wire subscription）
- Story 011: FR-3 EXPECTED_AUTOLOADS whitelist drift（PROCESS_MODE_ALWAYS CI）— RATIFICATION-GATED
- Story 009: SettingsManager setter override default

---

## QA Test Cases

> **Precondition seams**: CI lint test = inline RegEx（const FORBIDDEN pattern 對齊 lint script）+ comment-skip + violation/clean/real-source 三段（mirror `test_particle_ci_lint.gd`）。autoload pos = static read project.godot（mirror `test_particle_autoload_position.gd`）。`_gsm` stub w/ `connect_for_initial_state` spy counter。

- **AC-21**: CI lint（fixtures + real source）
  - Fixtures: `tests/fixtures/screen_effects_violation.gd`（含全 4 banned form：`camera.offset=`、`Engine.time_scale=`、`get_tree().paused=`、`global_shader_parameter_set("u_shake_offset"`）；`tests/fixtures/screen_effects_clean.gd`（legal only + commented banned line）
  - Then: violation fixture matches==4；clean fixture matches==0；real source `screen_effects.gd` — **owner-scoped**：assert 無 `Camera2D.offset` / `Engine.time_scale`（owner 都唔應有）；paused/uniform 喺 owner 合法（pattern 對齊 lint 嘅 owner-vs-caller partition）
  - Edge: comment-skip（commented banned line 唔 match）。inline RegEx no subprocess。**FLAG**: 對齊 `check_screen_effects_callers.gd` 嘅 owner-file vs caller-file partition 先寫 test。

- **AC-22**: persistence ban + boot defaults
  - Given: brand-new `_sut`（fresh new()）
  - Then: `_trauma==0`；`assert_almost_eq(_motion_intensity, 1.0, 0.0001)`（EC-15）；`_pause_remaining_sec==0`
  - Static scans（RegEx real source）: `PersistenceLayer` matches==0；`func\s+(save|load)_` matches==0；`user://` matches==0
  - Edge: EC-15 default 確認 1.0。static scan 同 CI-lint pattern。

- **AC（boot）**: autoload pos 14 + connect once
  - Static: project.godot [autoload] → `se_idx+1==14` AND `se_idx > psw_idx`（ScreenEffects after ParticleSystemWrapper pos 12）
  - Given: `_sut` w/ stub `_gsm`（connect_for_initial_state spy counter）
  - When: trigger `_ready` boot path
  - Then: `stub.connect_for_initial_state_call_count == 1`（ADR-0006 C6 exactly once）

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/static/test_screen_effects_ci_lint.gd`（AC-21）+ `tests/static/test_screen_effects_autoload_position.gd`（boot pos + connect）+ `tests/unit/screen_effects/test_screen_effects_persistence_ban.gd`（AC-22）
- `tools/ci/check_screen_effects_callers.gd` — new CI lint script
- `tests/fixtures/screen_effects_{violation,clean}.gd`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001-007（boot wires the full surface）、**#1 GameStateMachine (Complete — connect_for_initial_state)**、**#5 ParticleSystemWrapper (Complete — pos 12 precedes pos 14)**
- Unlocks: epic close-out；Story 011（FR-3 autoload drift extends this lint）
