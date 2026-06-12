# Story 015: Registry knobs + 2 新 UX pattern + UX advisory carry

> **Epic**: Onboarding Flow(#27)
> **Status**: Complete
> **Layer**: Polish / Presentation
> **Type**: Config/Data
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-12

## Context

**GDD**: `design/gdd/onboarding-flow.md`(Tuning Knobs;6 knob)
**UX**: `design/ux/onboarding-flow.md`（5 ADVISORY + 2 新 pattern flagged）
**Requirement**: TR-onboarding-??? (direct GDD trace)

**ADR Governing Implementation**: ADR: N/A — data-driven config + doc（knob 全 onboarding-internal,無 cross-system entity/formula 要 registry;UX pattern library doc）
**ADR Decision Summary**: —

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: knob 全 onboarding-internal（`onboarding.*` namespace,無 cross-system 要 entities.yaml 註冊 — design-review 已確認）;config `.tres` data-driven（gameplay value 唔 hardcode）。

**Control Manifest Rules(this layer)**:
- Required: knob data-driven config（唔 hardcode）;integer-ms 紀律（float sec → int ms 載入時）
- Forbidden: knob hardcode 入 formula
- Guardrail: `coach_auto_dismiss_sec` ≪ `coach_max_defer_sec`（唔同軸）

---

## Acceptance Criteria

- [ ] 6 knob 落 config（`coach_auto_dismiss_sec` 6.0 / `coach_max_defer_sec` 120.0 / `coach_fade_sec` 0.25 / `preview_duration_sec` 24.0 / `preview_enabled` true / `coach_marks_enabled` true）;safe range + integer-ms 載入。
- [ ] **2 新 UX pattern 入庫** → `design/ux/interaction-patterns.md`:`coach-mark`（peripheral dismissible in-context hint;鏡 P-17 restraint;teaching 非 error）+ `preview-watermark`（非綁定試演標示）。catalog index 加對應編號 + 完整 pattern entry。
- [ ] **5 UX advisory carry 落實**(UX spec 補):header `Platform Target` field + appear-latency AC + resolution/aspect-ratio AC + preview-loading state 明寫 + keyboard focus order 明寫。
- [ ] knob 互動 doc:`coach_auto_dismiss_sec ≪ coach_max_defer_sec`;`preview_enabled=false` → `preview_duration_sec` 無關;`coach_marks_enabled=false` → 全 coach-* knob 無關。

---

## Implementation Notes

*data-driven config + doc:*

- `src/data/onboarding_config.gd`（class_name + register）+ `assets/data/onboarding_config.tres`（6 knob）。formula 載入時 `int(sec*1000)`（integer-ms 紀律）。
- **interaction-patterns.md** catalog 加 2 row（P-20 coach-mark / P-21 preview-watermark 或對應下一編號 — grep 現有最大編號 P-19）+ 2 完整 pattern entry（Category/Used In/Description/Specification/When-to-Use/When-NOT/Accessibility;coach-mark 明確同 P-17 區隔 teaching-vs-error）。
- **UX spec advisory 補**(`design/ux/onboarding-flow.md` Edit):header 加 `Platform Target`;AC 加 appear-latency（「非-critical window 後 ≤1 frame fade-in 啟動」）+ resolution（「peripheral anchor 16:9/4:3/portrait 唔遮中央互動」）;States 加 preview-loading row;Interaction Map 補 keyboard focus order（Tab/Esc 落點）。

---

## Out of Scope

- Story 005/006: formula 用 knob（呢度定義 knob）。
- Story 016: playtest（呢度 doc/config）。

---

## QA Test Cases

**Knob config**:
- Setup: load `onboarding_config.tres`
- Verify: 6 knob 在 + safe range + `int(sec*1000)` 載入
- Pass condition: `coach_auto_dismiss_sec(6.0) → 6000ms`;互動約束 doc 在

**Pattern library**:
- Setup: 讀 `interaction-patterns.md`
- Verify: coach-mark + preview-watermark 2 entry 完整;catalog index 同步;coach-mark vs P-17 區隔明寫
- Pass condition: 2 pattern Defined 狀態

**UX advisory carry**:
- Setup: 讀更新後 `design/ux/onboarding-flow.md`
- Verify: header Platform Target + appear-latency AC + resolution AC + preview-loading state + keyboard focus 全補
- Pass condition: 5 advisory 全落地

---

## Test Evidence

**Story Type**: Config/Data
**Required evidence**: smoke check（`production/qa/smoke-*.md` — config load + pattern doc + UX advisory）
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 005/006（formula 用 knob）+ Story 013/014（pattern 行為 ground truth）
- Unlocks: None
