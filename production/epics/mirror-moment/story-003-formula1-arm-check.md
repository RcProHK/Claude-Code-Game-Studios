# Story 003: Formula 1 — ceremony_arm_check (cadence + change + once-per-window)

> **Epic**: Mirror Moment System (#29)
> **Status**: Ready
> **Layer**: Polish
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/mirror-moment.md` Formula 1 / CR-M1 / EC-MM-5/6
**Requirement**: AC-01 / AC-02(GDD 直接 trace)
**ADR Governing Implementation**: N/A — pure formula(cadence gate logic);secondary ADR-0003(read latch)
**ADR Decision Summary**: N/A pure deterministic gate;cadence wall-clock(`TimeProvider.now_unix()`,server-time-sanity-checked)。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `TimeProvider.now_unix()`(wall-clock,server-time-sanity per #17 Rule 4 / #2);**唔用 persisted monotonic anchor**(跨 WASM reload 歸零 poison drift)。`MIRROR_CADENCE_SECONDS` from `.tres`(CI-MM-3)。

**Control Manifest Rules (Polish layer)**:
- Required: cadence wall-clock + server-time sanity;`cadence_open` 單一真相源(`presented_this_window = not cadence_open`)
- Forbidden: hardcoded cadence literal(`.tres` only,CI-MM-3);persisted monotonic anchor
- Guardrail: epoch-zero 繼承 #26 gate（唔重複）

---

## Acceptance Criteria

- [ ] **AC-01**: `last_ceremony_unix=300000` + `now=1000000`(Δ=700000 > 604800)+ `pending=true` → GSM 入 IDLE → `should_arm==true` → ARMED → 呈現一次慶典
- [ ] **AC-02**: 同一 cadence window 內已呈現過(`now-last < 604800`)→ 玩家再開 game 入 IDLE 兼 `pending`/`week_had_change` 仍 true → **唔再呈現**(`should_arm==false`)
- [ ] Formula 1:`should_arm = cadence_open ∧ has_change ∧ not presented_this_window`;`cadence_open = (now-last_ceremony) >= MIRROR_CADENCE_SECONDS`;`has_change = pending_evolution_ceremony ∨ week_had_change`;`presented_this_window = not cadence_open`(同一變數)
- [ ] EC-MM-5:cadence window 邊界喺 ARMED 期間跨過 → 不影響(has_change 仍 true,present gate 一過即呈現)
- [ ] EC-MM-6:clock skew / server-time sanity fail(偏差 > `CLOCK_SANITY_TOLERANCE_SEC`)→ 寧可唔 arm(grace),下次 boot server sync 後再試
- [ ] epoch-zero 註記:fresh account `last_ceremony_unix==0` → cadence_open 恆 true,但 has_change 要求收過 #26 signal(#26 自己 gate first-boot)→ #29 唔重複 gate

---

## Implementation Notes

*Derived from Formula 1 + CR-M1:*

- `cadence_open` 同 `presented_this_window` 係同一比較互補 — 實作共用一個 `cadence_open` 變數(single source of truth)。
- wall-clock `TimeProvider.now_unix()` + server-time sanity(EC-MM-6 grace:寧遲一次慶典,唔假慶典)。
- epoch-zero:#29 唔自己 gate first-boot(繼承 #26 Formula 3 epoch-zero guard + 48h grace)— `has_change` 要求收過 #26 signal 已足夠。
- 純函數 deterministic;injected `TimeProvider` test seam。

---

## Out of Scope

- Story 004:content selection(Formula 2 — 本 story 只 arm gate)
- Story 005:non-workout present gate(CR-M3,本 story 只 cadence/change arm)

---

## QA Test Cases

- **AC-01/02**: arm gate
  - Given: golden table(700000/true/false→true;700000/false/true→true;700000/false/false→false;300000/true/true→false)
  - When: Formula 1
  - Then: should_arm 對表
  - Edge cases: epoch-zero(last==0)依賴 has_change;EC-MM-5 window 跨過唔取消
- **EC-MM-6**: clock sanity
  - Given: server-time 偏差 > tolerance
  - When: arm check
  - Then: 唔 arm(grace);下次 sync 再試

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/mirror_moment/formula1_arm_check_test.gd` — injected TimeProvider;golden table;deterministic
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002(FSM + latch state)
- Unlocks: Story 005(arm → present gate)
