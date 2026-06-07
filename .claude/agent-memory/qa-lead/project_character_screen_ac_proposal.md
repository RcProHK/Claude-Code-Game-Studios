---
name: character-screen-ac-proposal
description: "#22 Character Screen AC 提案 (2026-06-07): 45 條 (38B/6A/1GATED) + 6 flags — FLAG-1 affordance/subscription 矛盾, FLAG-3 HIT_HEAVY preview API 不存在"
metadata:
  type: project
---

# #22 Character Screen — AC 提案 (2026-06-07)

qa-lead 為 #22 GDD(AC section 當時未寫)提案咗 45 條 AC:38 BLOCKING(9 Logic unit + 29 Integration)/ 6 ADVISORY(manual)/ 1 RATIFICATION-GATED(ADR-0001 perf)。

**Why:** #22 GDD Detailed Design / Formulas / Edge Cases 已寫好,AC section 仍 [To be designed] — 提案供 design 寫 AC section 用。

**How to apply:** #22 GDD AC section 寫完後做 QA pass 時,對返呢 6 個 flag 有冇裁決:

1. **FLAG-1(矛盾)**:Rule 8 CLOSED 零-subscription invariant vs States table 入口 affordance 跟 GSM 顯示/隱藏 — affordance owner 要 pin 做 host shell(screen node 以外)
2. **FLAG-2**:Rule 1「隱藏 / disabled」二選一未 pin
3. **FLAG-3(HIGH)**:EC-24 HIT_HEAVY preview **冇 shipped API** — #6 public 只有 `shake(intensity,duration)` L282,HIT_HEAVY params 係 internal table L194;需 #6 additive preview API(併 G-CS-4)否則 #22 要 hardcode magic numbers
4. **FLAG-4**:Rule 30/EC-26 per-frame coalesce locus(#22 定 #6)未 pin — 提案假設 #22-side
5. **FLAG-5(nit)**:F1 arrow operand「v_display_at_retarget」vs「interpolated 值」— roundi monotonic ⇒ sign 一致,非 bug,但 golden vector 要 pin operand
6. **FLAG-6**:browser back 唔 intercept = absence claim,headless 唔可測 → manual ADVISORY

其他 key 結構:
- G-CS-1 gated ACs:open sync read + picker source(`get_loadout`/`get_items_for_slot` 未落地前跑唔到)
- Rule 29 boot self-read 係 #6/#7 嘅 G-CS-2/G-CS-4 story AC,**唔屬 #22 epic**
- 最關鍵 seam = injected time source(F1 tween manual stepper,唔用 engine Tween wall clock)— 冇佢 Group B/D 全 flaky
- ARIA seam 已 shipped:`platform_detect.announce_aria` L32(#21 story-025)
- Test files:tests/unit/character_screen/{test_char_screen_format,test_stat_tween,test_picker_sort}.gd + tests/integration/character_screen/test_charscreen_{lifecycle,binding,commands,settings,aria}.gd

相關:[[loot-drop-modal-qa-review]](#21 同 pattern 嘅 presentation-tier QA)
