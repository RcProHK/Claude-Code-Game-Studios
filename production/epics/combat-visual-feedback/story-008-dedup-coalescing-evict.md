# Story 008: R-14 dedup + R-15 coalescing (F3) + enemy_killed evict + FakeClock

> **Epic**: Combat Visual Feedback(#25)
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-11

## Context

**GDD**: `design/gdd/combat-visual-feedback.md`(R-14/R-15 + Formula 3 + EC-03/07/17)
**Requirement**: `TR-cvf-008`

**ADR Governing Implementation**: ADR-0009: Signal Payload Schema(primary)
**ADR Decision Summary**: `hit_resolved` = single source of visual feedback;`enemy_killed` = non-visual cleanup hook(evict per-target state)。dedup 用 `transition_id`+`target_id`。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: F3 用 monotonic ms → **injectable FakeClock**(`_now_ms()` DI seam,唔直接 `Time.get_ticks_msec()` — 否則 AC-14 flaky);`_last_particle_ms` Dictionary int-clean sentinel(`not has()` 而非 -INF float)。

**Control Manifest Rules (Presentation)**:
- Required: coalescing 只 gate `#25` 自己 `play()`;number/pause/overlay 唔受 gate
- Forbidden: 直接 `Time.get_ticks_msec()`(用 injectable clock)
- Guardrail: `_last_particle_ms` dict 唔隨死敵無限增長(enemy_killed evict)

---

## Acceptance Criteria

*From GDD R-14/R-15 + Formula 3:*

- [x] **AC-13**:hit_resolved{KILLED, tid=X, target=7} + enemy_killed{tid=X, enemy_instance_id=7} → number 恰好 1 次(test_dedup_kill_plus_enemy_killed)。⚠️ **grep erratum**:enemy_killed 真 field = `enemy_instance_id`(非 `target_id`),但 == hit_resolved.target_id(皆 enemy instance_id)
- [x] **AC-14**:同 target 兩 hit < COALESCE(FakeClock t=0/120)→ `play`==1 + number==2;t=210 第三 → `play`==2(test_coalesce_suppresses_second_particle_not_number)
- [x] **AC-31(F3 leak guard)**:target=7 在 `_last_particle_ms` → `enemy_killed{enemy_instance_id=7}` → `has(7)==false` AND `_seen` 清 `z|7`(test_enemy_killed_evicts_per_target_state)
- [x] **EC-03**:coalesce 窗口內 → particle suppress + number 照彈(AC-14 number==2 覆蓋)
- [x] **Formula 3**:first hit(`not has()` int-clean sentinel)永遠 emit(test_first_hit_always_emits_particle);knob 200ms(test_coalesce_knob_is_200ms)。**injectable `_now_ms()` DI seam**(FakeClock,唔直接 Time.get_ticks_msec)

---

## Implementation Notes

*Derived from ADR-0009:*

- F3 `should_emit_particle(target_id, now_ms)`:`if not _last_particle_ms.has(target_id) or now_ms - _last_particle_ms[target_id] >= COALESCE_MS: record + return true; else false`。
- dedup:`_seen` set keyed `(transition_id, target_id)`;`hit_resolved` 處理前 check;`enemy_killed` 只 evict(唔彈 visual)。
- `enemy_killed(target_id)` → `_last_particle_ms.erase(target_id)` + `_seen` 清該 target(防 gym-session 30-60min 死敵累積 leak)。
- **injectable clock**:`_now_ms()` 經 DI seam(FakeClock 注入);test 可控 monotonic 時間。

---

## Out of Scope

- Story 009: number pool(本 story 只 gate count)
- Story 012: Suspended clear（coalescing/dedup 全清留 lifecycle story）

---

## QA Test Cases

- **AC-13**: dedup
  - Given: `hit_resolved{KILLED, tid=X, target=7}` + `enemy_killed{tid=X, target=7}`
  - When: 兩者 process
  - Then: number 彈 1 次
- **AC-14**: coalescing(FakeClock)
  - Given: target=A,FakeClock t=0 hit,t=120 hit,COALESCE=200
  - When: route
  - Then: `play`==1（第二 coalesce）+ number==2
  - Edge cases: t=210 第三 hit → `play`==2（窗口外）
- **AC-31**: evict
  - Given: target=7 in `_last_particle_ms`
  - When: `enemy_killed{target=7}`
  - Then: `has(7)==false`
  - Edge cases: first-hit(無 entry)→ emit true（int-clean sentinel)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/combat_visual_feedback/test_cvf_coalesce_dedup.gd`(AC-13/14/31 + EC-03 + F3 first-hit;FakeClock inject)
**Status**: [x] Created + green 2026-06-11 — `test_cvf_coalesce_dedup.gd` 5/5(dedup + coalesce + first-hit + evict + knob);cvf suite 33/33。`_seen`/`_last_particle_ms` 重命名（scaffold `_dedup`/`_coalesce`）+ `_should_emit_particle`(F3)+ `_evict_seen_for_target` + `_now_ms`(clock seam)

---

## Dependencies

- Depends on: Story 004(routing)、Story 003(clock seam scaffold)
- Unlocks: Story 012(Suspended clear)
