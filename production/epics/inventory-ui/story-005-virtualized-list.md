# Story 005: Virtualized card list component(novel — 零先例 code)

> **Epic**: Inventory UI (#23)
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: L
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-08

## Context

**GDD**: `design/gdd/inventory-ui.md` — Rule 9(component spec 全段)+ EC-14(scroll 雙軌)
**Requirement**: direct GDD trace(AC-13)

**ADR Governing Implementation**: ADR-0001(draw-call 紀律 — virtualization 係 budget 手段)
**ADR Decision Summary**: 2D web target draw calls mobile ≤150 / desktop ≤200;120+180 全 instantiate 會爆。

**Engine**: Godot 4.6 | **Risk**: MEDIUM(novel component;Godot 零內置 virtualized Control list)
**Engine Notes**: ScrollContainer + 固定高 spacer + card pool reposition(scroll offset → index 數學);`ItemList`/`Tree` 做唔到 P-06 composite card — 唔好行嗰條路

**Control Manifest Rules (Presentation)**:
- Guardrail: 60fps;draw calls budget
- Required: 公開 API doc comments

---

## Acceptance Criteria

- [x] `src/ui/inventory_ui/virtualized_card_list.gd`:**fixed row height**(`ROW_HEIGHT_PX` const — retention/receipt note 行喺 fixed card 內預留)+ pool ≤ `ceil(viewport_h / ROW_HEIGHT_PX) + 2 × POOL_BUFFER_ROWS`(knob default 2)
- [x] **AC-13**:120 件 fixture → instantiated row nodes ≤ pool 公式(test 讀 implementation 同一常數;P-06 card node 計,chrome 唔計)
- [x] Scroll 雙軌:bulk rebuild → reset 頂;單件 mutation rebuild → **保留 offset(clamped)**
- [x] 兩 instance 可共存(INVENTORY / MAILBOX 各自 instance,同一 class — plain script,零 singleton state)
- [x] Row content 由 caller 注入(view model → card populate callback)— component 唔識 #17

## Implementation Notes

- 設計成 #24 可 reuse(generic card list,唔 hardcode #23 內容)
- List row provenance 單行 ellipsis 係 caller 責任(populate callback)— component 只保證 fixed height
- Focus-driven virtualization hook(focus 行到視窗邊 → 視窗推進)— API 預留,接線喺 015

## Out of Scope

- Story 006:#23 view model 接入;Story 015:SR focus 行為驗收

## QA Test Cases

- **AC-13**: Given 120 件,When render @ 560px viewport,Then node count ≤ 公式;Given scroll 到底,Then 同一 bound(pool 重用唔加)
- **雙軌**: Given scroll @ offset X,When 單件 remove rebuild,Then offset == X(clamped);When 120→8 bulk rebuild,Then offset == 0
- **邊界**: 0 件 / 1 件 / 件數 < pool size — 零 crash 零 ghost row

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/inventory_ui/test_invui_browse.gd`(virtualization cases)
**Status**: [x] Created — 10 tests 全 pass;combined gate CLEAN 2294/2293/0 fail(2026-06-08)

## Completion Notes

**Completed**: 2026-06-08
**Criteria**: 5/5 passing
**Deviations**: None — `ROW_HEIGHT_PX = 96.0` 由本 story pin(GDD knob 行話「UX spec 定後 test 讀同一常數」;UX spec 只 pin「fixed height」冇數值 — 96px = 3 行文字 + retention 預留 + ≥48px touch;test 讀 implementation 同一常數兌現)。`ensure_index_visible` focus hook 已預留(story 015 接線)
**Test Evidence**: 10 tests — AC-13 bound ×2(首屏 + scroll 到底唔增長)/ EC-14 雙軌 ×3(keep/reset/clamp)/ 邊界 ×3(0/1/<pool)/ populate window 連續 / focus hook 數學
**Code Review**: Complete — degraded inline APPROVED / ADEQUATE(spawn block 持續)

## Dependencies

- Depends on: Story 002(dir;可實際並行)
- Unlocks: 006(list render)
