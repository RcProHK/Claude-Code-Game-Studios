# Story 017: G-IU-5 shards thousands-separator shared formatter(#22 churn 管控)

> **Epic**: Inventory UI (#23)
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/inventory-ui.md` — Formulas 表 shards row(D6)+ G-IU-5 row + UX spec UXQ-6
**Requirement**: direct GDD trace(D6 — 全 game 統一)

**ADR Governing Implementation**: N/A — display formatter,冇架構 pattern
**ADR Decision Summary**: —

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: 千位逗號 lossless(「禁 K/M」原意 = 禁 lossy abbreviation);int64 安全

**Control Manifest Rules**: **#22-side 限一行 + AC literal 同步;單一 story 收口;禁順手 refactor**(PR-EPIC binding directive ⑤)

---

## Acceptance Criteria

- [x] Shared formatter(locus 裁:**#17-side static `InventorySystem.format_shards`** — #22 零新 preload[global class_name],真・一行 churn;doc comment「#22/#23 shared contract」)+ unit golden(0 / 999 / 1000 / 1400 / 1234567 / 負數)
- [x] #23 全部 shards 顯示位(header counter / BULK select rows + confirm header `yield_display` / 單件+bulk toast)行 formatter(006/011/012 placeholder 收口;TODO 剷走)
- [x] **#22-side 一行 churn**:`get_forge_shards_display` `str()` → formatter;#23 browse test literal「1400」→「1,400」同步(#22 suite 無 display-string literal — grep 確認);**#22 suite 重跑零變紅**
- [x] Doc errata:#17 comment 擴「#22/#23 shared contract」;#22 GDD「verbatim 禁 K/M」行 + #22 ux spec「無千分位」×2 行 erratum(UXQ-6;superseded 注記)

## Implementation Notes

- 禁順手 refactor #22 其他嘢 — diff 應該係 formatter file + #22 一行 + AC literal + 三處 doc

## Out of Scope

- 任何 #22 其他 display 邏輯

## QA Test Cases

- **Golden**: Given int 系列,When format,Then 千位逗號 binary-exact;negative/0 邊界
- **Parity**: Given #22 suite,When 重跑,Then 零變紅(AC literal 已同步)

## Test Evidence

**Story Type**: Integration
**Required evidence**: formatter unit + #22 suite 重跑 + combined CI gate
**Status**: [x] Created — `tests/unit/inventory_ui/test_shards_formatter.gd` 3 tests(goldens + 負數 + 雙 coordinator locus assert);combined gate CLEAN 2370/2369/0 fail(2026-06-08)

## Completion Notes

**Completed**: 2026-06-08
**Criteria**: 4/4 passing
**Deviations**: None — diff 範圍照 directive ⑤:formatter(#17 static)+ #22 一行 + #23 收口位 + 三處 doc + tests;零順手 refactor
**Test Evidence**: 3 unit tests + browse literal 同步 + #22 suite 零變紅(combined gate)
**Code Review**: Complete — degraded inline APPROVED / ADEQUATE(spawn block 持續)

## Dependencies

- Depends on: Story 006(consume 位存在)
- Unlocks: AC-21 golden 文字 final
