# Story 018: G-IU-3 doc errata cluster(六件)+ manual evidence protocol

> **Epic**: Inventory UI (#23)
> **Status**: Complete
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

- [x] **(a)** #4 catalog 來源 column:reuse 行加 #23(ui_sheet_* / ui_salvage_execute / ui_lock_* / ui_error / ui_charscreen_open/close;**`ui_back` 唔加** — 明文唔用注記)
- [x] **(b)** 備註更新:`ui_salvage_execute`「transaction stamp,count-invariant(1..120 件同一響)」;`ui_charscreen_*`「ledger-surface 開合 family cue(#22+#23 共用;名係 historical)」+ chaining craft constraint(close+open back-to-back ~300ms)
- [x] **(c)** #23 voice pool 包絡行(IDLE/DISCONNECTED only / low mono / 同時 ≤2-3 — 零新 entry)
- [x] **(d)** interaction-patterns.md:P-13/15/16 Used-by 加 #23 + 變體註記(P-13 list 變體 / P-15 BULK 加重版 + fixed-footer / P-16 BULK_SELECT+MAKE_ROOM)+ P-14 加 #23(make-room hint)
- [x] **(e)** #17 code「bulk-salvage shortcut」superseded note(已兌現 Rule 11 (a) — story 009)
- [x] **(f)** #17 `set_lock` doc comment「immune to every salvage path」over-claim 收窄(MANUAL + BULK only — sweep/evict 唔理 lock)
- [x] Manual evidence protocol:`production/qa/evidence/inventory-ui/README.md`(AC-30 CJK walkthrough / AC-31 SR + touch + dead-gap + focus-driven / AC-32 visual 名單[零 cascade / 零 countdown / badge 文法 / greyscale / claim-silent 體感記錄];AC-33 RATIFICATION-GATED 記錄行 + sign-off 表)
- [x] **(g) 追加**(story 001 deferred advisory):ADR-0001 insertion 令行號移位 — #23 GDD G-IU-2 row「L112/L127」→「L117/L132」+ #22 GDD Rule 34 / G-CS-7 row「L107+L122」→「L117+L132」erratum

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
**Status**: [x] Created — 七件 grep 全驗(a×4 / b×1 / c×1 / d×4 / e×1 / f×1 / g×3)+ README 存在三 AC 章節齊;combined gate CLEAN 2370/2369/0 fail(comment-only 零變紅;2026-06-08)

## Completion Notes

**Completed**: 2026-06-08
**Criteria**: 7/7 passing(原六件 + (g) 追加 — story 001 deferred line-cite erratum 喺度收回)
**Deviations**: None
**Test Evidence**: doc-diff greps 全 pass + combined gate 零變紅;manual evidence 收集本身 = EXTERNAL(protocol 交付 = story 完成,#21/#22 先例)
**Code Review**: Complete — degraded inline APPROVED(spawn block 持續;(e)(f) 純 comment 零行為)

## Dependencies

- Depends on: Story 015(map 落地先寫 (a)(b) 終稿)
- Unlocks: epic 收線
