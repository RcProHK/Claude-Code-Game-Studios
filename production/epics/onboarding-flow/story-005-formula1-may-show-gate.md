# Story 005: Formula 1 may_show gate(workout-critical defer,all-GSM)

> **Epic**: Onboarding Flow(#27)
> **Status**: Complete
> **Layer**: Polish / Presentation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-12

## Context

**GDD**: `design/gdd/onboarding-flow.md`(Formula 1 / Rule 4 / AC-10 / EC-04 — **Pillar 2 命脈**)
**Requirement**: TR-onboarding-??? (direct GDD trace)

**ADR Governing Implementation**: ADR: N/A — pure gate function（ADR-0006 GSM state read 為 input,但 gate 本身無架構 pattern）
**ADR Decision Summary**: —

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: WORKOUT_CRITICAL = {`WORKOUT_ACTIVE`, `REST_PERIOD`, `LOOT_DROP`} **全部 #1 GSM `GameState`**（B-1 fix — grep game_state_machine.gd:80-90;`SET_ACTIVE` 係 #9 `WorkoutPhase` **唔係** GSM,**勿用**）。single-enum membership,零 cross-enum。

**Control Manifest Rules(this layer)**:
- Required: gate 為 pure func;GSM state 作參數傳入(唔 read singleton)
- Forbidden: 用 `GameState.SET_ACTIVE`(唔存在 — compile error;B-1)；coach-mark mid-set 顯示
- Guardrail: WORKOUT_CRITICAL 全程 `false`(Pillar 2 命脈 — coach-mark 永不 mid-set)

---

## Acceptance Criteria

- [ ] **AC-10**（must-not-regress）— GIVEN 任何 pending coach-mark,WHEN GSM ∈ {`WORKOUT_ACTIVE`, `REST_PERIOD`, `LOOT_DROP`}（全 #1 GSM `GameState`）,THEN `may_show==false`、coach-mark **唔顯示**（defer,保持 pending）。
- [ ] Formula 1:`may_show(step) = (fsm_state != DORMANT) AND (latch[step]==false) AND (gsm_state ∉ WORKOUT_CRITICAL) AND (no_other_coachmark_visible)`。
- [ ] WORKOUT_CRITICAL constant = 純 #1 GSM GameState 集合（B-1 — single-enum）。
- [ ] **EC-04** — coach-mark pending 時 GSM 入 workout-critical → `may_show=false` defer,state 清返先顯示;**永不 mid-set 出現**。

---

## Implementation Notes

*Formula 1(GDD):*
- `src/core/onboarding_formulas.gd` static `may_show(fsm_state, latch_done, gsm_state, other_visible) -> bool`。
- **WORKOUT_CRITICAL = [GameState.WORKOUT_ACTIVE, GameState.REST_PERIOD, GameState.LOOT_DROP]**（B-1 命脈 — 全 GSM,grep game_state_machine.gd:84/85/88 verified;**唔可**用 `SET_ACTIVE`,該 token 屬 #9 WorkoutPhase ordinal 2,GSM 冇）。
- **Falsifiable**:grep coach-mark show path 必先 check `may_show`;WORKOUT_CRITICAL 全程 false（單一 membership test）。
- `#9 WorkoutPhase.SET_ACTIVE` finer mid-set 精度 **deferred**（epic-time 若要可 subscribe #9 `phase_changed`;MVP GSM `WORKOUT_ACTIVE` 粗粒已足夠保守）。

---

## Out of Scope

- Story 006: auto-dismiss timer（Formula 2 — 唔同 formula）。
- Story 011: defer 機制 + stale-latch（呢個 story 只 gate func;defer loop + max_defer 喺 011）。

---

## QA Test Cases

**AC-10 / EC-04(workout-critical defer)**:
- Given: fsm=COACHING, latch_done=false, other_visible=false
- When: gsm_state = WORKOUT_ACTIVE（或 REST_PERIOD 或 LOOT_DROP）
- Then: `may_show == false`
- Edge cases: 三個 critical state 各驗 false;gsm=IDLE → true

**Formula 1 全 term**:
- Given: 各 term 單獨翻轉
- When: `may_show(...)`
- Then: fsm==DORMANT → false;latch_done==true → false;other_visible==true → false;全 satisfy + gsm=IDLE → true
- Edge cases: 確認 WORKOUT_CRITICAL 用 GameState 常數（compile 唔到 SET_ACTIVE → 即 B-1 regression）

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/onboarding_flow/test_onboarding_formula_may_show.gd`（全 term + 3 critical state defer + B-1 GSM-only guard）
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002（scaffold — FSM enum）
- Unlocks: Story 011（defer loop 用 may_show）
