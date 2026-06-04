# Story 003: Tween circuit-breaker + handle-map (spike-grounded)

> **Epic**: Gym-Mode HUD (#20)
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: M (3-4h)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-04

## Context

**GDD**: `design/gdd/gym-mode-hud.md` (EC-F4 / EC-R2 / EC-R6 / AC-EC-F4b / AC-CR-2 zero-floor)
**Requirement**: GDD AC-EC-F4b / AC-EC-F4 / AC-EC-R2 (no TR-ID — cite GDD AC-ID)
**Reference impl**: `prototypes/tween-spike/SPIKE-FINDINGS.md`(authoritative — R8 反向 author 嘅 spec;`HudTweenManager` inner class)。Spike 12/12 pass(Godot 4.6.3 + GUT 9.6.0)。

**ADR Governing Implementation**: ADR-0001 Web Export Budget Caps (primary)
**ADR Decision Summary**: tween burst cap(`max_concurrent_tweens`)+ allocation 峰值控制防 mobile Safari WASM GC stutter。

**Engine**: Godot 4.6 (Web Export, Compatibility) | **Risk**: HIGH
**Engine Notes (spike-verified runtime behavior)**:
- **A1/B2**: `kill()` **唔 emit `finished`** → kill path 必須有獨立 erase code path
- **A2**: 自然完成 emit `finished` **剛好一次** → lifecycle ③ 只行自然路徑
- **A3**: `kill()` 後 `is_valid()==false`(但不足以區分新舊 → 仍需 identity `==` 比對)
- **A4**: `finished`(0-arg)+ `.bind(stat_id, tween)` → callback 正確收 `(stat_id, src_tween)` 2 param

**Control Manifest Rules**:
- Required: config-const;test-readable seam(同 AC-CR-2 `_active_tween_count` 同級)
- Forbidden: 餵 NaN/INF 入 Tween(永不 settle livelock);blind `--`(無配對 created tween)
- Guardrail: circuit-breaker `max_tween_restart_count` 保證有限次內必 settle

---

## Acceptance Criteria

- [ ] **AC-EC-F4b(spike-grounded)**:
  - **(1) snap-index off-by-one**:create(第 1 個 event)唔算 restart;注入第 **`max_tween_restart_count + 1`** 個連續 same-stat_id event 嗰刻即時讀 → bar value == latest target(instant snap)且 `_restart_count[stat_id]==0`。
  - **(2) snap-path counter 歸零**:snap 後 `_active_tween_count==0`(snap = `_kill`(--)+`set_immediate`(唔++));`_active_tween_count==_active_tweens.size()` invariant 維持。
  - **(3) empty/stale-handle no-op**:stale `_on_tween_finished(stat_id, stale_tween)` 到達 → identity guard `_active_tweens.get(stat_id)!=src_tween` 提早 return,counter 不變、新 entry 不被誤刪。
  - **(4) reset-then-resume**:用 logical-epoch seam(非 `await` frame)——snap 後 fake-complete `_on_tween_finished(stat_id, current_tween)` → `_restart_count==0` → 新 `stat_changed` → 正常重啟 tween(count 遞增非瞬 snap)。
- [ ] **AC-EC-F4**:NaN/INF guard → fallback 上一 confirmed、唔 redraw、log 一次、唔餵 Tween;boot-time first NaN → 0.0。
- [ ] **AC-EC-R2**:同 stat_id tween 未完又新 event → kill 舊、由當前 interpolated 值 restart(無回跳/無疊);先 kill(--)後 create(++)峰值不超 cap;reduce_motion 直接 snap。
- [ ] **AC-CR-2 zero-floor**:`reduce_motion==true`(F2 instant set 從未 ++)連續 snap/kill → `_active_tween_count` 永遠 ≥ 0(`max(count-1,0)` + handle-tracking)。
- [ ] **EC-R6**:◐ deep-dim element 收 stat_changed → `set()` 更新值 skip tween(唔 ++);升 emphasis 時一次性 snap reconcile。

---

## Implementation Notes

*Reference SPIKE-FINDINGS.md `HudTweenManager` —— 唔直接搬 prototype code,rewrite 到 production 標準。*
- `_active_tweens: Dictionary(stat_id:StringName → live Tween)`;invariant `_active_tween_count == _active_tweens.size()`(consider derive `_active_tween_count` 直接 = `.size()` 消雙真相源)。
- `_kill(stat_id)`:`if t and t.is_valid(): t.kill()` → `if _active_tweens.has(stat_id): _active_tweens.erase(stat_id); _active_tween_count = maxi(count-1,0)`。EC-R2/EC-F5 kill 一律行此獨立 erase,**絕不靠 `_on_tween_finished`**(kill 唔 emit finished)。
- kill-restart branch atomic ordering:**第一步 `_restart_count[stat_id]+=1` → 即 compare cap(`>= max_tween_restart_count` → snap+reset 0+return)→ 否則 `_kill`→`_create`**。create(首 event,無 entry)行 else 唔 ++。
- 2-param seam:`tween.finished.connect(_on_tween_finished.bind(stat_id, t))`;`_on_tween_finished(stat_id, src_tween)` 內 identity guard → erase + `maxi(count-1,0)` + `_restart_count[stat_id]=0`(lifecycle ③)。
- `_get_restart_count_for_test(stat_id)->int` public getter(test inspect)。
- `stat_changed`→tween/snap handler 用 **plain `.connect()` synchronous**(非 `CONNECT_DEFERRED`);`call_deferred` 只限 EC-R4。

---

## Out of Scope

- Story 002:basic tween create + F1/F2(本 story 加 circuit-breaker 層)。
- Story 008:◐ alpha 數值(本 story EC-R6 只 skip-tween 邏輯,唔定 alpha)。

---

## QA Test Cases

- **AC-EC-F4b(1)**:Given `max_tween_restart_count=5`;When 注入 6 個連續 same-stat_id `stat_changed`;Then 第 6 個 event 嗰刻 value==latest target(snap)且 `_get_restart_count_for_test==0`;Edge: naive 無-breaker impl 喺第 6 個仍 in-flight 中間值 → fail(分辨力)。
- **AC-EC-F4b(3)**:Given snap 已 erase entry;When call `_on_tween_finished(stat_id, stale_tween)`;Then counter 不變(identity guard return);Edge: 新 tween B 存在時 stale A finished → B entry 不被刪。
- **AC-EC-F4b(4)**:Given snap 後;When fake-complete `_on_tween_finished(stat_id, cur)` → 再注入新 stat_changed;Then `_restart_count==0` 後 `_active_tween_count` 遞增(正常 tween,非 snap);**零 frame-timing 依賴**。
- **AC-EC-R2**:Given EXP tween t=0.15;When 新 stat_changed(EXP);Then 由當前 interpolated restart(無回跳);kill-restart 期間 `_active_tween_count ≤ max_concurrent_tweens`。
- **AC-CR-2 zero-floor**:Given reduce_motion==true;When 連續 snap/kill;Then count 永 ≥0。
- **EC-R6**:Given element emphasis==◐;When stat_changed 到;Then value set 但 `_active_tween_count` 不 ++(skip tween)。

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/gym_mode_hud/test_tween_circuit_breaker.gd` — must exist and pass (mirror spike 12 assertions where applicable)
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (tween core + `_active_tween_count` seam)
- Unlocks: Story 008 (◐ emphasis 用 EC-R6 skip-tween)

---

## Completion Notes
**Completed**: 2026-06-04
**Criteria**: 5/5 passing (AC-EC-F4b 1-4 / AC-EC-F4 guard / AC-EC-R2 / AC-CR-2 zero-floor / EC-R6)
**Deviations**: None. `_active_tween_count` 改為 derived getter (= `_active_tweens.size()`)，消雙真相源（systems-designer ADVISORY），spike invariant 由構造成立。Story 002 tween core 重構入 generic `_request_stat_tween`（EXP 為首個 caller，Story 004 加 HP）。
**Test Evidence**: Logic — `tests/unit/gym_mode_hud/test_tween_circuit_breaker.gd` (10 test functions mirror spike PART B B2-B6 + resume + reduce_motion + EC-R6, 10/10 pass). Full combined gate green: 1438 pass / 0 fail / 1 pre-existing pending.
**Code Review**: Complete — APPROVED (rewrite 到 production 標準，唔搬 prototype；kill 獨立 erase / restart++先於cap / snap@MAX+1 / 2-param identity guard 全對 SPIKE-FINDINGS.md)
**Files**: `src/ui/gym_mode_hud/gym_mode_hud.gd` (refactored — handle-map circuit breaker), `tests/unit/gym_mode_hud/test_tween_circuit_breaker.gd` (created)
