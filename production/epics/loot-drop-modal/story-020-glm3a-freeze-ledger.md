# Story 020: G-LM-3a — #6 freeze 記帳 scalar→ledger refactor + behaviour-parity

> **Epic**: Loot Drop Modal (#21)
> **Status**: Ready
> **Layer**: Presentation(epic)/ 改動喺 Foundation #6
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/loot-drop-modal.md`(G-LM-3 ②⑥ + Formulas grep 發現 ①④)
**ADR**: ADR-0001(#6 HIGH rendering domain — shake/pause 系統)
**Engine**: Godot 4.6 | **Risk**: **HIGH regression**(改 shipped #6 核心記帳 — producer 點名全 epic 最高 regression risk)

**Control Manifest Rules**:
- Required:**behaviour-parity 先行 — #6 existing tests 零變紅係本 story 驗證準則(producer binding)**
- Forbidden:改 `MAX_PAUSE_SEC=0.12` 語意(hit pause ceiling 唔郁)

## Acceptance Criteria(G-LM-3 ②⑥ — #6-side)

- [ ] **② scalar→ledger 重構**:shipped 單一 scalar `_pause_remaining_sec`(`screen_effects.gd:111`)→ per-entry ledger;每 entry 有 handle;「只清自己 entry」語意成立(真 ledger 先有意義)
- [ ] **max-remaining merge**:多 entry 並存 → 實際 freeze 時長 = max(remaining);entry 移除唔影響其他 entry
- [ ] **⑥ `hit_pause` ledger 隔離**:stray `hit_pause` 唔可以截斷 ceremony freeze(各自 entry,互不干涉)
- [ ] **Behaviour-parity(BLOCKING 驗證準則)**:重構後 **#6 existing test suite 全 green 零變紅**(hit pause / slow-mo / Suspended override 行為 byte-level 一致)
- [ ] **Combined CI gate green**

## Implementation Notes

- 本 story **唔加新 API** — 純內部記帳重構 + parity;新 API(ceremony_freeze / release / saturation)係 021。
- Suspended override(`screen_effects.gd:362`)hard-cancel 行為保持 — override 清 ledger 全部 entries + 還原 timescale。
- 寫 parity tests 先(snapshot 現行為)再 refactor — verification-driven。

## Out of Scope

- `ceremony_freeze` / `release(handle)` / saturation API(021);#21-side INV-M1(007)。

## QA Test Cases

G-LM-3 ②⑥ gate text 係 spec;parity = #6 existing suite(`tests/unit/screen_effects/`)零 diff;新 ledger unit tests:multi-entry max-remaining / per-entry removal / hit_pause 隔離。

## Test Evidence

**Required**: `tests/unit/screen_effects/test_freeze_ledger.gd` + existing suite 零變紅證明(CI run)
**Status**: [ ] Not yet created

## Dependencies

- Depends on: None(parallel wave — CD 順序 G-LM-4 後)
- Unlocks: 021
