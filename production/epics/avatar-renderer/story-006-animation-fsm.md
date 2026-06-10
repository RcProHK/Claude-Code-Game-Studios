# Story 006: Animation FSM (IDLE/COMBAT/CAST) GSM-driven

> **Epic**: Avatar Renderer (#26)
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/avatar-renderer.md` CR-2 / States table / EC-ANIM-3/4 / EC-SIG-5 / EC-XSYS-2
**Requirement**: AC-06(GDD 直接 trace)
**ADR Governing Implementation**: ADR-0006 State Machine Contract(primary)
**ADR Decision Summary**: GSM transition atomicity;state membership read via `get_current_state()`。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `AnimatedSprite2D` + `SpriteFrames` hand-rolled FSM — **NO `AnimationPlayer`**(CI-6/AC-28)。`GSM.state_changed(from,to,payload)`;`get_current_state()->GameState`(`game_state_machine.gd:241`)。`COMBAT_TICK` 唔存在 — 用 Option C(`state_changed` to ∈ {COMBAT_ACTIVE, BOSS_ENCOUNTER})。

**Control Manifest Rules (Presentation layer)**:
- Required: 3-state FSM mutually exclusive;boss 共用 combat anim(CR-1/Option C)
- Forbidden: `AnimationPlayer`;mid-combat sprite swap(defer to next IDLE)
- Guardrail: idle→combat/cast instant cut ≤1 frame(0.3s readability)

---

## Acceptance Criteria

- [ ] **AC-06**: GSM `state_changed(IDLE, COMBAT_ACTIVE, p)`(同 `(_, BOSS_ENCOUNTER, p)`)→ anim IDLE→COMBAT ≤1 frame;`(COMBAT_ACTIVE, IDLE, _)` → COMBAT→IDLE ≤1 frame
- [ ] CR-2 Option C 三 source:(a) to∈{COMBAT_ACTIVE,BOSS_ENCOUNTER}→COMBAT;(b) `ability_cast(caster==player)`→CAST(story 007 timing);(c) from∈{COMBAT_ACTIVE,BOSS_ENCOUNTER}, to∉{…}→IDLE
- [ ] EC-ANIM-3:GSM exit combat mid-cast → cast MUST complete(atomicity),post-finish transition to GSM-derived state
- [ ] EC-ANIM-4:`AnimatedSprite2D` frame desync(stuck)→ force IDLE anim + clear cast queue + log `animation_desync_recovery`
- [ ] EC-SIG-5:GSM state 不在 known enum → ignore,retain previous anim,log `unknown_gsm_state` once/session
- [ ] EC-XSYS-2:GSM signal storm(>10/100ms)→ 16ms debounce GSM-derived transition(只最終 state per window);cast NOT debounced(atomicity)

---

## Implementation Notes

*Derived from CR-2 + States table:*

- hand-rolled FSM(IDLE/COMBAT/CAST);`AnimatedSprite2D.play(anim_name)` 切換;**零 `AnimationPlayer`**。
- COMBAT 內 `#11.stat_changed` 接受但 defer sprite swap 到 next IDLE(mid-combat flicker guard — States COMBAT row)。
- debounce(`GSM_SIGNAL_DEBOUNCE_MS`=16)只 apply GSM-derived anim transition;cast(story 007)atomicity,唔 debounce。
- SUSPENDED transition 由 story 010 處理(本 story 只 IDLE⇄COMBAT⇄CAST entry/exit)。

---

## Out of Scope

- Story 007:cast timing / hard window / queue 細節(本 story 只 CAST entry/exit edge)
- Story 010:SUSPENDED handling
- Story 008:posture sprite swap timing

---

## QA Test Cases

- **AC-06**: combat anim cut
  - Given: anim IDLE
  - When: `state_changed(IDLE, COMBAT_ACTIVE, p)` / `(_, BOSS_ENCOUNTER, p)`
  - Then: COMBAT ≤1 frame;reverse → IDLE ≤1 frame
  - Edge cases: boss 共用 combat anim(無單獨 boss anim)
- **EC-ANIM-3**: cast atomicity on combat exit
  - Given: mid-cast,GSM exits combat
  - When: cast in progress
  - Then: cast completes,then transition to GSM-derived state
- **EC-XSYS-2**: storm debounce
  - Given: 11 state_changed in 100ms
  - When: process
  - Then: 只最終 state apply(16ms debounce);cast 不受 debounce

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/avatar_renderer/animation_fsm_test.gd` — must pass;FSM transition table-driven;GSM signal injected(mock GSM emit)
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002(pipeline + GSM subscription)
- Unlocks: Story 007(cast timing builds on CAST state)
