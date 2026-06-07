# Story 018: G-IU-3 doc errata cluster(六件)+ manual evidence protocol

> **Epic**: Inventory UI (#23)
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Config/Data
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/inventory-ui.md` — G-IU-3 row(六件)+ AC-30/31/32(ADVISORY)+ AC-33(GATED)
**Requirement**: direct GDD trace

**ADR Governing Implementation**: N/A — doc errata
**ADR Decision Summary**: —

**Engine**: Godot 4.6 | **Risk**: LOW

---

## Acceptance Criteria

- [ ] **(a)** #4 catalog 來源 column:reuse 行加 #23(ui_sheet_* / ui_salvage_execute / ui_lock_* / ui_error / ui_charscreen_open/close;**`ui_back` 唔加**)
- [ ] **(b)** 備註更新:`ui_salvage_execute`「transaction stamp,count-invariant(1..120 件同一響)」;`ui_charscreen_*`「ledger-surface 開合 family cue(#22+#23 共用;名係 historical)」+ chaining craft constraint(close+open back-to-back ~300ms)
- [ ] **(c)** #23 voice pool 包絡行(IDLE/DISCONNECTED only / low mono / 同時 ≤2-3)
- [ ] **(d)** interaction-patterns.md:P-13/15/16 Used-by 加 #23 + 變體註記(P-13 list 變體 / P-15 BULK 加重版 + fixed-footer / P-16 BULK_SELECT+MAKE_ROOM)+ P-14 加 #23(make-room hint)
- [ ] **(e)** #17 code L706-707「bulk-salvage shortcut」superseded note(已兌現 Rule 11 (a))
- [ ] **(f)** #17 `set_lock` doc comment L690-691「immune to every salvage path」over-claim 收窄(manual/bulk only — sweep/evict 唔理 lock)
- [ ] Manual evidence protocol:`production/qa/evidence/inventory-ui/README.md`(AC-30 CJK walkthrough / AC-31 SR + touch + dead-gap / AC-32 visual 名單[零 cascade / 零 countdown / badge 文法 / greyscale / claim-silent 體感記錄];AC-33 RATIFICATION-GATED 記錄行)

## Implementation Notes

- (e)(f) 係 code comment 改動但零行為變 — 跑 combined gate 確認零變紅
- #22 evidence protocol README 係格式先例

## Out of Scope

- Manual evidence 收集本身(EXTERNAL — 真機/真 SR)

## QA Test Cases

- **Doc diff**: grep 六件各自 marker;README 存在 + 三 AC 章節齊

## Test Evidence

**Story Type**: Config/Data
**Required evidence**: doc diffs + combined gate 零變紅
**Status**: [ ] Not yet created

## Dependencies

- Depends on: Story 015(map 落地先寫 (a)(b) 終稿)
- Unlocks: epic 收線
