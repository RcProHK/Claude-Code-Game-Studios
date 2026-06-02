# Story 006: GSM state→music transition + connect_for_initial_state

> **Epic**: Audio Manager
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: M (3-4h)
> **Manifest Version**: 2026-05-29
> **Last Updated**: (set by /dev-story)

## Context

**GDD**: `design/gdd/audio-manager.md`
**Requirement**: `TR-audio-006`
*(See EPIC.md GDD Requirements table.)*

**ADR Governing Implementation**: ADR-0006 Contract 6 (`connect_for_initial_state`) — primary; Contract 4 (boot order)
**ADR Decision Summary**: 後啟動 autoload 用 `connect_for_initial_state(handler)` sentinel helper 安全訂閱當前 state（解決 boot-order race）；sentinel（`source_event="initial_state"`）派發一次；唔用 plain `.connect`（CI enforced）。

**Engine**: Godot 4.6 | **Risk**: HIGH (ADR-0006 contract surface; #4 consumes)
**Engine Notes**: GSM `state_changed(from, to, payload)` signature（from-state present，confirmed）。headless Dummy driver Tween 唔自然 advance → `bgm_changed` 必須 emit 喺 **crossfade 起 tween 之後即 emit**（唔等 complete，否則 AC phantom）。GSM injection seam **untyped** `var _gsm`（typed fails compile-time member check）。

**Control Manifest Rules (Foundation)**:
- Required: `connect_for_initial_state(_on_gsm_state_changed)`（ADR-0006 C6，CI enforced）；GSM state 名對 `game-state-machine.md` enum ground-truth
- Forbidden: plain `.connect` 落 GSM state_changed；訂閱 GSM 以外 gameplay signal
- Guardrail: Map 無 entry 嘅 state → 維持當前 BGM；sentinel → noop

---

## Acceptance Criteria

- [ ] **AC-07** GIVEN READY，WHEN GSM→BOSS_ENCOUNTER，THEN 起 crossfade 去 boss_theme + `bgm_changed(boss_theme)` emit 一次（emit 喺起 tween 之後即 emit，唔等 crossfade 完成、唔需 advance Tween）
- [ ] **AC-08** GIVEN boot，WHEN initial-state sentinel 派發，THEN 無 music change（noop）
- [ ] **AC-32** GSM reference 經 untyped injection seam（`var _gsm`）accept mock double；inject mock → emit `state_changed` → assert response
- [ ] state→track map entries：`WORKOUT_ACTIVE→{focus_low_pool,1.0}` / `BOSS_ENCOUNTER→{boss_theme,0.25}` / `REST_PERIOD→{rest_calm,1.0}`（**state 名對 GSM enum**）
- [ ] **情境 A**（⚠️ EG-3 gated）：`_on_gsm_state_changed(from=BOSS_ENCOUNTER, to=LOOT_DROP)` → 先 `LOOT_BGM_TRANSITION_SEC`(0.25s) fade boss_theme→rest_calm → 後 duck rest_calm

---

## Implementation Notes

*Derived from ADR-0006 C6/C4 + GDD Rule 6:*

- data-driven `state→track` map，每 entry `{track_id, fade_sec}`（per-state fade override，default `BGM_DEFAULT_FADE_SEC`）。**state key 必須對 GSM `GameState` enum**（`game-state-machine.md`: BOOTING/DISCONNECTED/IDLE/WORKOUT_ACTIVE/**REST_PERIOD**/COMBAT_ACTIVE/BOSS_ENCOUNTER/LOOT_DROP/SUSPENDED）。**唔好用 `REST_BETWEEN_SETS`**（Pass 6 fix — 非有效 state）。
- `bgm_changed` emit 點 = `play_bgm` 起 crossfade tween 之後、return 之前（headless Tween 唔 advance，emit-at-complete = phantom）。
- 情境 A（LOOT_DROP from BOSS）vs 情境 B（mid-fight loot，仍 BOSS_ENCOUNTER 無 transition）由 `from/to` 區分。情境 A 依賴 #15 確認 boss kill→LOOT_DROP from_state==BOSS_ENCOUNTER（**EG-3，story-level gate**）。
- Map 無 entry → 維持當前 BGM（無變、無 warning）；initial-state sentinel → noop。

---

## Out of Scope

- Story 005: `play_bgm` crossfade primitive（前置，呢度只接 GSM signal 觸發）
- Story 007: unlock 時重 query GSM current state 起 BGM（unlock flow 喺 007）
- Story 008: SUSPENDED 期間 GSM transition handling
- #15 LootDrop from-state confirm（EG-3，external）

---

## QA Test Cases

*Integration — inject mock `_gsm` double，emit signal，assert response。*

- **AC-07**: boss transition + emit timing — Given READY + `watch_signals(am)` / When mock emit `state_changed(_, BOSS_ENCOUNTER, _)` / Then `assert_signal_emitted_with_parameters(am,"bgm_changed",[&"boss_theme"])`，**唔 advance Tween / 唔 wait fade_sec**。Edge: 重複 emit BOSS_ENCOUNTER（已播）→ idempotent no re-emit。
- **AC-08**: sentinel noop — Given boot + `connect_for_initial_state` 派發 `source_event=="initial_state"` / When 派發 / Then 無 music change，無 `bgm_changed`。
- **AC-32**: mock seam — Given inject `_gsm` double / When emit `state_changed` / Then AudioManager 正確 response（驗 seam 接 mock）。
- **Map state-name**: WORKOUT_ACTIVE→focus_low_pool、BOSS_ENCOUNTER→boss_theme(fade 0.25)、REST_PERIOD→rest_calm。Edge: COMBAT_ACTIVE（無 map entry）→ 維持當前 BGM。
- **情境 A**（EG-3 gated）: Given from=BOSS_ENCOUNTER to=LOOT_DROP / Then 先 boss_theme→rest_calm fade(0.25) 後 duck rest_calm。**標 Blocked-pending-EG-3 直至 #15 confirm from-state。**

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/audio/test_gsm_music_transition.gd` — must exist and pass（⚠️ GUT 只收 `test_*.gd` prefix — [[reference_gut_filename_convention]]）
**Status**: [ ] Not yet created

> ⚠️ 情境 A sub-AC（LOOT_DROP-from-BOSS conditional fade）gated on **EG-3**（#15 LootDrop Pass 3 confirm boss kill→LOOT_DROP from_state==BOSS_ENCOUNTER）。其餘 AC（boss/rest/workout map + emit timing + sentinel）唔受 EG-3 影響，可即實作。

---

## Dependencies

- Depends on: 005 (crossfade primitive), 001 (`_gsm` seam)
- Unlocks: 007 (unlock 重 query GSM current), 008 (suspend GSM handling)
