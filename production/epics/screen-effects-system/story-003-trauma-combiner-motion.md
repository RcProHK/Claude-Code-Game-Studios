# Story 003: Trauma Combiner + Motion Intensity Composition + Hierarchy Invariant

> **Epic**: Screen Effects System
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-01

## Context

**GDD**: `design/gdd/screen-effects-system.md`
**Requirement**: `TR-screen-003`, `TR-screen-011`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001 (Web Export Budget Caps, **Accepted-structural 2026-05-30**)
**ADR Decision Summary**: Trauma combiner = additive with hard clamp：`trauma_new = min(1.0, trauma_old + raw × motion_intensity)`；`decay_rate_new = max(old, 1.0/max(MIN_SHAKE_DURATION, d))`（monotonic non-decreasing）。motion_intensity input-side multiply（`=0.0` → 完全短路，hit_pause 不受影響）。Pillar 3 hierarchy gap：`max_amplitude(PARRY) ≥ 2 × max_amplitude(HIT_HEAVY)`。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: 8 concurrent HIT_HEAVY additive = 3.2 → clamp 1.0 → offset `pow(1.0,2)×4.0×noise = 4px max`（never exceeds budget）。`MIN_SHAKE_DURATION=0.01` 防 division-by-zero。

**Control Manifest Rules (this layer — Foundation)**:
- Required: motion_intensity input-side composition；trauma hard-clamp [0,1]
- Forbidden: output-side motion multiply（decay curve 對唔上 raw trauma）
- Guardrail: trauma ≤ 1.0 → offset ≤ MAX_OFFSET_PX（peripheral receivability + vestibular safety）

---

## Acceptance Criteria

*From GDD Section H, scoped to this story:*

- [ ] **AC-06** — `trauma=0.4` + `shake(0.4, 0.12)` → `min(1.0, 0.4+0.4)=0.8`；decay_rate stays `max(12.5, 8.33)=12.5`（monotonic）。
- [ ] **AC-07** [Falsifiable #4] — 8 × `shake(0.4, 0.12)` same frame → `trauma = min(1.0, 3.2) = 1.0`；shader offset 絕對唔超 `MAX_OFFSET_PX(4.0)`。
- [ ] **AC-08** [Falsifiable #2] — `_motion_intensity=0.0` → shake：trauma += 0（no accrual）+ uniform `Vector2.ZERO` latch-clear；BUT `hit_pause(d)` 照常 fire（time perturbation ≠ vestibular）。
- [ ] **AC-26** — `max_amplitude(PARRY)=pow(0.6,2)×4.0=1.44px ≥ 2 × max_amplitude(HIT_HEAVY)=pow(0.4,2)×4.0=0.64px → 1.28px`（AC-D6 hierarchy gap）；`LOOT_RARE_BURST raw²(0.04) > TRAUMA_EPSILON(0.01)`。

---

## Implementation Notes

*Derived from ADR-0001 + GDD Rules 5/7 / Formula 2 / AC-D6:*

- Combiner（喺 `_apply_shake` 內）：`var effective := intensity * _motion_intensity`（Rule 7 input-side）；`_trauma = min(1.0, _trauma + effective)`；`_decay_rate = max(_decay_rate, 1.0 / max(MIN_SHAKE_DURATION, duration))`（monotonic）。
- `motion_intensity == 0.0` → effective = 0 → trauma += 0；latch-clear uniform `Vector2.ZERO`（reset `_trauma_just_zeroed`）。**hit_pause 唔乘 motion_intensity**（Rule 7 + Section B Test #2 — 分開 path）。
- 新 shake 過 epsilon → reset `_trauma_just_zeroed = false`（re-arm Story 002 one-shot）。
- AC-26：純 formula invariant（`raw² × MAX_OFFSET_PX`）— GDD Formula 5 table source of truth（HIT_HEAVY 0.64 / PARRY 1.44，自洽：1.44 ≥ 2×0.64=1.28 ✓）。**Note**: qa-lead 一度 flag「discrepancy」實為誤讀 shorthand — formula 自洽，無需 reconcile GDD。

---

## Out of Scope

*Handled by neighbouring stories:*

- Story 002: per-frame decay + offset write（呢度只 accrue/combine）
- Story 004: hit_pause formula（AC-08 只驗 hit_pause **照 fire**，唔驗 max-remaining）
- Story 009: SettingsManager-driven motion propagation（呢度用 direct member）

---

## QA Test Cases

> **Precondition seams**: `_trauma`/`_decay_rate`/`_motion_intensity`/`_pause_remaining_sec` test-readable；spy `_shader_sink`；`SE.MAX_OFFSET_PX`/`SE.TRAUMA_EPSILON` constants。AC-26 純算術（no SUT tick / no GPU — 最 deterministic）。

- **AC-06**: additive combiner + monotonic decay_rate
  - Given: SUT ACTIVE；`_trauma=0.4`；`_decay_rate=12.5`；`_motion_intensity=1.0`
  - When: `shake(0.4, 0.12)`
  - Then: `assert_almost_eq(_trauma, 0.8, 0.0001)`；`assert_almost_eq(_decay_rate, 12.5, 0.0001)`（max(12.5, 8.33)）
  - Edge: 若新 shake decay_rate 更高 → decay_rate 升（測埋呢個方向）

- **AC-07**: 8× saturate + budget cap
  - Given: SUT ACTIVE；`_trauma=0`；motion=1.0；spy
  - When: 8× `shake(0.4, 0.12)`（同 frame，無 _process between）
  - Then: `assert_almost_eq(_trauma, 1.0, 0.0001)`（saturate，唔係 3.2）
  - When2: `_sut._process(1.0/60.0)` → `abs(spy.last_value.x) <= 4.0+ε` AND `.y <= 4.0+ε`
  - Edge: worst-case noise ±1 @ trauma 1.0 → |offset|=4.0 exactly（cap，equality OK，never exceed）

- **AC-08**: motion=0 shake bypass, hit_pause alive
  - Given: SUT ACTIVE；`_motion_intensity=0.0`；`_trauma=0`；`_pause_remaining_sec=0`；spy
  - When: `shake(0.6, 0.08)` → `_trauma==0` AND `spy.last_value==Vector2.ZERO`
  - When2: `hit_pause(0.06)` → `assert_almost_eq(_pause_remaining_sec, 0.06, 0.0001)`（pause 唔受 motion gate）
  - Edge: key decoupling — shared guard 唔可短路 hit_pause

- **AC-26**: hierarchy gap（pure arithmetic）
  - When: `amp_parry = pow(0.6,2)*4.0` (=1.44)；`amp_heavy = pow(0.4,2)*4.0` (=0.64)
  - Then: `assert_gte(amp_parry, 2.0*amp_heavy)`（1.44 ≥ 1.28 ✓）；`assert_gt(pow(0.2,2), SE.TRAUMA_EPSILON)`（0.04 > 0.01）
  - Edge: 無 SUT tick / 無 GPU — 純算術，最安全 test。

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/screen_effects/test_screen_effects_combiner.gd` — must exist and pass（AC-06, 07, 08, 26）

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001（`_apply_shake` funnel）、Story 002（decay/offset 用 combined trauma）
- Unlocks: Story 006（dispatch feeds combiner）、Story 009（motion propagation）
