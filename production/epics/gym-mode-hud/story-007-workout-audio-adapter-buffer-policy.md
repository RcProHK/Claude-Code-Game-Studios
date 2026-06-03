# Story 007: WorkoutAudioAdapter + GSM-state gate + buffer policy + stagger

> **Epic**: Gym-Mode HUD (#20)
> **Status**: Ready (部分 AC BLOCKED — 見 Dependencies)
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: L (4h)
> **Manifest Version**: 2026-05-29
> **Last Updated**: (set by /dev-story)

## Context

**GDD**: `design/gdd/gym-mode-hud.md` (CR-9 audio consumer, CR-10 buffer, CR-11 stagger, EC-A1/A3/A4, EC-S4/S4-LOOT/S4-SUSPENDED/S4-IDLE, Q-OQ1 stub)
**Requirement**: GDD AC-CR-9 / AC-CR-10 / AC-CR-11 / AC-EC-A1/A4 / AC-EC-S4* (no TR-ID — cite GDD AC-ID)

**ADR Governing Implementation**: ADR-0002 GymSys Integration (primary) · ADR-0009 (payload, secondary)
**ADR Decision Summary**: `set_logged` raw signal 只觸發 SFX 絕不驅動計數/視覺;#20 攞唔到 #9 per-set verdict → audio gate 只能 GSM-state-level;明文接受 residual false-positive(audio = enhancement)。

**Engine**: Godot 4.6 (Web Export, Compatibility) | **Risk**: MEDIUM (transport VS-gated)
**Engine Notes**: priority 讀 **#4 `SfxCatalog.tres`** data field(`@export var sfx_catalog` DI seam,可注入 fake catalog);**非** `get_event_priority()` phantom API;`AudioManager.play_sfx(event_id)` stateless,stagger delay 100% 喺 #20 側(`ITimerService` DI seam,非 SceneTreeTimer wall-clock)。

**Control Manifest Rules**:
- Required: GSM-state-level gate `∈{WORKOUT_ACTIVE,REST_PERIOD,COMBAT_ACTIVE,BOSS_ENCOUNTER}`;buffer mid/high low-drop;config-const cap
- Forbidden: raw set_logged 驅動計數/視覺;主動 voice-budgeting(Q-OQ13 explicit-accept);hardcode priority 表
- Guardrail: `pending_buffer_cap=12` FIFO;`flush_stagger_ms=40` anti-voice-steal

---

## Acceptance Criteria

- [ ] **AC-CR-10**:audio LOCKED + 注入 `SfxCatalog.tres`(或 fake),`pending_buffer_cap+2` mid/high event → `_pending` size ≤ `pending_buffer_cap`(讀 const,FIFO drop oldest);low priority(讀 catalog)唔入 buffer(drop);`audio_unlocked` 後 flush 至空。
- [ ] **AC-EC-A1**:全程 LOCKED 從未 tap,20 個 `set_logged` 再 `_exit_tree` → `_pending` 全程 ≤12、永不 flush、`_exit_tree` 後清空(無 dangling `play_sfx`)。
- [ ] **AC-EC-A4**:deferred `streak_chime` timer(100ms)未 fire 就 `_exit_tree`/Suspended → guard(in-tree && 非 Suspended)不滿足則 drop(call count==0)。
- [ ] **AC-EC-S4 / S4-LOOT / S4-SUSPENDED / S4-IDLE(deny-side spy)**:DISCONNECTED/LOOT_DROP/SUSPENDED/IDLE 期 `set_logged` 到 → SFX 唔 trigger(spy call count==0);resume WORKOUT_ACTIVE + set_logged → 正常 trigger(gate pass)。
- [ ] **AC-CR-9** *(BLOCKED #2-GDD / #8)*:unlock 後 `set_logged` → `play_sfx(event_id)` 一次(spy count==1)。
- [ ] **AC-CR-11** *(BLOCKED #8)*:`set_complete`×`streak_chime` 同幀 → 先 `play_sfx(set_complete)`、streak_chime 經 `ITimerService` delay,斷言排程 delay==`set_streak_chime_stagger_ms`(讀 const,fake timer 即時 advance)。
- [ ] **AC-EC-S6(fallback #8)**:#8 streak 未 expose,`set_complete` 到 → 即播無 stagger(CR-11 邏輯休眠),唔因等唔存在 chime 而 defer。

---

## Implementation Notes

- `WorkoutAudioAdapter` = dedicated child node,訂 `#2.set_logged`(**只此 path 食 raw**)+ `audio_unlocked` +(co-design)#8 `streak_chime`。
- gate:`GSM.get_current_state() ∈ {WORKOUT_ACTIVE,REST_PERIOD,COMBAT_ACTIVE,BOSS_ENCOUNTER}` 先觸發;**audio gate 有意唔做 generational guard**(enhancement,接受 mid-transition stale read 漏/多一聲;explicit asymmetry vs 視覺 reconcile SM-C)。
- buffer:LOCKED 時 mid/high → FIFO `_pending`(cap);low 直接 drop;`audio_unlocked` flush priority-desc + `flush_stagger_ms`。
- **Q-OQ1 兩分支 consumer stub**:(A correlation-key)`_pending_set_complete: Dictionary(key→ts)` key-match stagger;(B same-frame)同幀並存判定。co-design 落實邊條,另一 stub 移除。fallback(兩條未落)= AC-EC-S6。
- `SfxCatalog` DI:`@export var sfx_catalog: SfxCatalog = preload("res://.../SfxCatalog.tres")`,test 傳 fake。

---

## Out of Scope

- Story 005:#9-validated count/visual path(本 story raw set_logged 只 audio)。
- EC-A6 / Q-OQ13:explicit-accept,無 testable AC(設計接受 contention cost)。

---

## QA Test Cases

- **AC-CR-10**:Given LOCKED + fake catalog;When cap+2 mid/high;Then `_pending`≤cap(FIFO);low → drop;unlock → flush 空;Edge: flush 內 self-steal(>8 voice)可接受。
- **AC-EC-A1**:Given 全程 LOCKED;When 20 set_logged + `_exit_tree`;Then ≤12 全程、清空、無 dangling。
- **AC-EC-S4×4**:Given DISCONNECTED/LOOT/SUSPENDED/IDLE;When set_logged;Then spy count==0;resume WORKOUT → count==1。
- **AC-CR-11**(BLOCKED #8):Given same-frame set_complete×streak_chime + fake ITimerService;Then set_complete first、streak delay==const;**唔 await wall-clock**。
- **AC-EC-S6**(fallback):Given #8 未 expose;Then set_complete 即播無 stagger。

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/gym_mode_hud/test_workout_audio_adapter.gd` — must exist and pass (deny-side spy + buffer policy self-contained; AC-CR-9/11 gated)
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 006 (unlock + flush ready) · Story 001 (GSM state) · #4 Audio (merged, `SfxCatalog.tres` + `play_sfx`)
- **BLOCKED (partial)**:
  - **AC-CR-9** — #2 GDD 須補列 #20 為 `set_logged` subscriber (Q-OQ5);整合測前置
  - **AC-CR-11** — #8 streak signal expose + correlation key (Q-OQ1, Prov-3)
  - Fallback **AC-EC-S6** self-contained 可過 → buffer policy + deny-side spy 部分**唔 blocked**,先做
- Unlocks: —
