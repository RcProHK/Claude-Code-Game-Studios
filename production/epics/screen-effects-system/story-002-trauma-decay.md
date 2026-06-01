# Story 002: Trauma² Decay + noise_sample + Epsilon Short-circuit

> **Epic**: Screen Effects System
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-01

## Context

**GDD**: `design/gdd/screen-effects-system.md`
**Requirement**: `TR-screen-002`, `TR-screen-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001 (Web Export Budget Caps, **Accepted-structural 2026-05-30**)
**ADR Decision Summary**: 震動透過 shader uniform `u_shake_offset`（NOT `Camera2D.offset`）。Trauma² decay（Yoshi/Vlachos GDC pattern）每 frame：`offset = pow(trauma,2) × MAX_OFFSET_PX × noise; trauma -= decay_rate × delta`。`trauma < TRAUMA_EPSILON` short-circuit（zero per-frame cost when idle）。

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: shader uniform 經 `_shader_sink` injectable seam（唔可 override native `RenderingServer.global_shader_parameter_set` — phantom-pass guard）。`noise_sample(t) = Vector2(sin(t×137), sin(t×211))` — deterministic，seed time **必須 injectable/accumulated**（`_shake_time += delta` 由 0 起），唔可用 wall-clock，否則 test 無法 reproduce。

**Control Manifest Rules (this layer — Foundation)**:
- Required: 震動 via shader uniform `u_shake_offset`（routed through ScreenEffects）
- Forbidden: `Camera2D.offset` mutation；Perlin noise（mobile WebGL2 dependent texture read 貴）
- Guardrail: trauma < epsilon → zero per-frame cost（FR-1 budget protection）

---

## Acceptance Criteria

*From GDD Section H, scoped to this story:*

- [ ] **AC-05** — `trauma=0.6`、1 frame（delta=1/60）、decay_rate=12.5 → `trauma = max(0, 0.6 - 12.5/60) ≈ 0.391`；`offset.x = pow(0.391,2) × MAX_OFFSET_PX(4.0) × noise.x`（Formula 1）。
- [ ] **AC-09** — `trauma < TRAUMA_EPSILON(0.01)` → skip Formula 1 evaluation；one-shot clear shader uniform 到 `Vector2.ZERO`（`_trauma_just_zeroed` latch；之後 idle frame 唔再 write）。

---

## Implementation Notes

*Derived from ADR-0001 + GDD Rule 4 / Formula 1+4:*

- `_process(delta)`：`delta = min(delta, MAX_FRAME_DELTA)`（bfcache clamp，Story 007）；Suspended/HitPaused early-return（Story 005/007）；`_motion_intensity==0` short-circuit（Story 003）。
- Trauma decay：`_trauma = max(0.0, _trauma - _decay_rate * delta)`；`offset = pow(_trauma,2) * MAX_OFFSET_PX * _noise_sample(_shake_time)`；`_shader_sink.call("u_shake_offset", offset)`。
- `_noise_sample(t)`: `Vector2(sin(t*137.0), sin(t*211.0))`（cheap deterministic hash，NOT Perlin）。`_shake_time` accumulate（`+= delta`）— injectable/deterministic seed。
- Epsilon short-circuit：`trauma < TRAUMA_EPSILON` → skip evaluation；若 `_trauma_just_zeroed` 未 set → one-shot `_shader_sink.call("u_shake_offset", Vector2.ZERO)` + set latch true（之後 idle 唔再 write）。新 shake 過 epsilon → reset latch false（Story 003 combiner）。
- 邊界：`trauma == TRAUMA_EPSILON` → NOT below → Formula 1 仍 evaluate（boundary 係 `<` 唔係 `≤`）。

---

## Out of Scope

*Handled by neighbouring stories:*

- Story 003: trauma accrual / combiner / motion composition（呢度只 decay 既有 trauma）
- Story 005: HitPaused freeze（decay 凍結）
- Story 007: bfcache delta clamp + Suspended reset（呢度假設 Active）

---

## QA Test Cases

> **Precondition seams**: `_shader_sink` spy（record last_value + **call_count** — 證 one-shot）；`_shake_time` deterministic seed（confirm seed source 唔係 wall-clock 先 implement）；`_trauma`/`_decay_rate`/`_trauma_just_zeroed` test-readable；`SE.TRAUMA_EPSILON`/`SE.MAX_OFFSET_PX` constants（唔 inline magic）。Headless 無 frame loop → 手動 call `_sut._process(delta)`。

- **AC-05**: Trauma² decay one frame
  - Given: SUT ACTIVE；`_trauma=0.6`；`_decay_rate=12.5`；spy sink；`_noise_sample` deterministic
  - When: `_sut._process(1.0/60.0)`（手動 tick）
  - Then: `expected = max(0, 0.6 - 12.5/60) ≈ 0.39167`；`assert_almost_eq(_trauma, expected, 0.0005)`；`n = Vector2(sin(SEED*137), sin(SEED*211))`；`expected_x = pow(expected,2)*4.0*n.x`；`assert_almost_eq(spy.last_value.x, expected_x, 0.001)`
  - Edge: decay clamp at 0（never negative）。**Headless flag**: noise seed 必須 deterministic/injectable，否則 assertion break — confirm seed source before implementing。

- **AC-09**: epsilon short-circuit + one-shot clear
  - Given: SUT ACTIVE；`_trauma=0.005`（< epsilon）；`_trauma_just_zeroed=false`；spy
  - When: `_sut._process(1.0/60.0)`
  - Then: `_trauma < SE.TRAUMA_EPSILON`；`spy.last_value == Vector2.ZERO`（one-shot write）；`_trauma_just_zeroed == true`
  - When2: 第二次 tick（trauma 仍 < epsilon）
  - Then2: `spy.call_count_since_marker == 0`（latched — 唔再 write）
  - Edge: `trauma == TRAUMA_EPSILON` → 仍 evaluate（boundary `<`）；新 shake 過 epsilon → reset latch。Headless: spy 要 count writes 證 one-shot。

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/screen_effects/test_screen_effects_decay.gd` — must exist and pass（AC-05, AC-09）

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001（API surface + `_shader_sink` seam）
- Unlocks: Story 003（combiner feeds decay）、Story 005（HitPaused freezes decay）
