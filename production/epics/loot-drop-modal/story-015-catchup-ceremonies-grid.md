# Story 015: Catch-up ceremonies + grid + commit 語意 + EC-M7/M16 + C-1/C-2

> **Epic**: Loot Drop Modal (#21)
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/loot-drop-modal.md`(Rule 10 / Rule 7 catch-up batch / EC-M7 / EC-M16 / F3 C-1 C-2)+ UX spec(grid §D)
**ADR**: ADR-0005(C-1 RARE+ identity — P3「不知不覺發生」禁令延伸)
**Engine**: Godot 4.6 | **Risk**: MEDIUM(batch seam call shape gated G-LM-10 — fake seam 先行)

**Control Manifest Rules**:
- Required:stream beats display-only;commit point = stream-end / force-close / exit(單一 frame batch)
- Forbidden:per-beat commit(40 件 40 次 full persist);RARE+ collapse 入「+N」(C-1)

## Acceptance Criteria

- [ ] **AC-28(#21-side 半)**(catch-up 結構,F3 fixture):reveal-all → sub-RARE 24 件 `C_stream` cadence 零 tap stream(#5 aggregated,call 數 << 24;stream 期間 `loot_fanfare_*` count == 0 — D4 negative spy;**aggregated cue exactly-once + 單一 duck handle [gated G-LM-8]**);RARE+ top-K=5 tier 降序揀、ascending reveal;第 4 件 R 喺 grid 有 own cell(icon + rarity label;「+N」唔適用 RARE+ — C-1);overflow 件 grid entry frame batch commit(C-2);stream beats stream-end 嗰 frame 連發 `receive_loot` + **batch seam 包裹**(call-frame spy:同一 frame + begin/end 各一次 — **[seam call gated G-LM-10,fake seam 先]**;persist count 屬 AC-72)
- [ ] **AC-29(#21-side 半)**(mid-exit 零懲罰):ceremonies 行到第 k 件完,tap「稍後再拆」→ 已 commit 件各自已 emit `modal_dismissed` + banked;剩餘原封 pending,banner 下次以更新 N 重現(**[#15 dequeue 半邊 gated G-LM-4]**)
- [ ] **AC-58(#21-side 半)**(EC-M7 commit point):force-close 落 CATCHUP_PROMPT → 零 commit 全留 pending;落 stream 中 → 嗰刻 batch commit 已 display beats(單 frame 連發 + seam 包裹 **[gated G-LM-10]**),in-flight 未 display 留 pending,已 commit 唔 re-reveal;落 grid 中 → 收埋零 data 影響
- [ ] **AC-67**(EC-M16):rollback == 當前 stream beat(未 commit)→ ≤1 frame cancel、跳下一 beat、aggregate −1、該件唔入 batch commit;已 commit → 零動作

## Implementation Notes

- Stream beat 視覺 = luminance-stable(icon slide + tier tint,零 flash transient;flash 只准 stream 頭尾各一)— 027 AC-88 視覺半邊。
- 「稍後再拆」= 獨立 Control 喺 scrim z-order 之上,input 優先;ceremony S2 行緊時 tap = 當前件 fast-complete → S3 commit → stash,剩餘留 Pending。
- Grid:rarity-sorted 一屏、hero cell 2×2、exposure sweep ≤0.4s 禁 per-cell stagger、零 celebration particle;CATCHUP_GRID 係 post-commit summary。
- EC-M7 全 phase terminal emit(除 pre-S3 ceremony cancel — 唔 emit,GSM retry 接手)。
- RARE+ ceremonies 照 INV-M3 per-item S3 commit(≤K=5 有界)。

## Out of Scope

- Batch seam 本體(024);#15 dequeue / `loot_confirmed`(018);F3 數學(014);grid 截圖 evidence(027 AC-82)。

## QA Test Cases

GDD AC-28/29/58/67 GWT(qa-plan-import-equivalent);AC-28 用 F3 30 件 fixture golden;gated 半邊用 fake seam 先斷 #21-side call shape。

## Test Evidence

**Required**: `tests/unit/loot_reveal/test_catchup_commit.gd`
**Status**: [ ] Not yet created

## Dependencies

- Depends on: 011、012、014
- Unlocks: 026
