# Story 008: F2 breakdown bar + INV-M2 + EC-M15 corrupt + EC-M12 resize

> **Epic**: Loot Drop Modal (#21)
> **Status**: ✅ Complete(2026-06-07 — AC-3/42/43/44/45/63/66;GUT 68/68;combined 1998/1997/0 fail;commit 75ff5a0;ws/rr/score 載體 = pinned item_metadata keys,G-LM-4a(017)grant 時持久化 — **新發現 gap fold 入 017 scope**)
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-07

## Context

**GDD**: `design/gdd/loot-drop-modal.md`(F2 / EC-M15 / EC-M12)+ UX spec §B slot 5(CJK font 指派)
**ADR**: **ADR-0005**(primary — 75/25 binding 可視化;rarity 計算 #15 own,#21 唔 re-derive)
**Engine**: Godot 4.6 | **Risk**: LOW

**Control Manifest Rules**:
- Required:formula evaluation order 釘死(clamp → gate → 幾何);% label mandatory
- Forbidden:rarity 色用喺 bar(`ui_amber_primary` vs `ui_ink_hi` — UX locked)

## Acceptance Criteria

- [ ] **AC-3**(INV-M2 邊界 sweep):(ws,rr) ∈ [0,1]² 令 score ≥ 0.55(必含 0.55/rr=1.0 worst case)→ `px_w > px_r` 嚴格成立且 naive delta ≥8px @ W_bar ≥120
- [ ] **AC-42**(identities + honest endpoints):(0.55, 0.40, 1.0, W=160) → px 87/73、pct 55/45、sum==100;legal sweep `px_w+px_r==W_bar` 恆成立;兩 contrib >0 ⇒ pct∈[1,99];(0.6, 0.8, 0.0) → 100/0(rr 真零誠實);(ws=1.0, rr=0.01) → 99/1(clamp)
- [ ] **AC-43**(floor unreachable,parameterize on `W_BAR_MIN` knob):legal grid naive delta ≥8px 恆成立(knob ≥88);corrupt input 先觸發 floor clause
- [ ] **AC-44**(display gate):W_bar < `W_BAR_MIN` → stacked text-only、% label 雙邊、零 info loss
- [ ] **AC-45**:COMMON/UNCOMMON → breakdown bar node 不可見/不存在
- [ ] **AC-63**(EC-M12):resize 令 W_bar 100 → 一 frame re-layout、stacked variant、timer 唔 reset、particle 唔 replay
- [ ] **AC-66**(EC-M15):ws=1.4 → clamp 先入 F2;identity 違反 >0.001 或 score-tier 矛盾 → 信 #15 tier、隱藏 bar、telemetry `breakdown_mismatch`

## Implementation Notes

- Evaluation order binding:① clamp-on-read ② EC-M15 gate(corrupt → 隱藏 bar,唔入幾何)③ 幾何。
- Honest-endpoint clamp 後**重 derive px_w**(`px_r = max(px_r,1); px_w = W_bar − px_r`)維持 sum invariant(Pass 2 閉合)。
- `pct_r = 100 − pct_w` 保證 sum=100;round_half_up。
- Layout(CJK fit):bar 段內純數字 label(m6x11);「汗水 / 運氣」legend 獨立行(Zpix 12px)— UX spec locked。

## Out of Scope

- Modal content slot 填充流程(006/010);visual 截圖 evidence(027 AC-84)。

## QA Test Cases

GDD AC-3/42/43/44/45/63/66 GWT + pinned vectors(qa-plan-import-equivalent;worst-case 87/73@160 golden)。

## Test Evidence

**Required**: `tests/unit/loot_reveal/test_f2_breakdown_bar.gd`
**Status**: [ ] Not yet created

## Dependencies

- Depends on: 002
- Unlocks: 027(AC-84 visual variant)
