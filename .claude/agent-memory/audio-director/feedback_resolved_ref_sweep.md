---
name: resolved-ref-sweep
description: review #20-style GDD 時,Open-Question 改 RESOLVED 後須核對全部引用點(Dependencies 表 / BLOCKED section / QA flag sprint-gate list)有冇殘留 stale「sprint 前須確認」
metadata:
  type: feedback
---

review multi-revision GDD(如 #20 Gym-Mode HUD)時,當一個 Open Question 喺主 entry 改為 ✅ RESOLVED,**必須**同時核對所有引用該 Q 嘅位置係咪都 sweep 乾淨。

**Why**:#20 R6 B8 將 Q-OQ13 主 entry 改「RESOLVED,無需 co-design」,但 (a) Dependencies 表 #4 行仍 `⚠️ Q-OQ13 co-design`、(b) BLOCKED section 仍「sprint 前須 #4 確認 voice reservation」、(c) QA flag 仍將 Q-OQ13 列入 6-dep sprint re-check gate。一個 question 唔可同時係「RESOLVED 無需 co-design」又係「sprint 前須確認 co-design」。呢個 stale-ref 會令 `/story-readiness` 卡喺 phantom gate = 真阻礙入 sprint = BLOCKING。同 R3/R4 反覆出現嘅「改主文冇 sweep 引用」係同一類 recurring process defect。

**How to apply**:任何「某 Q 改 RESOLVED / 某 dep 不再阻塞」嘅修訂,grep 該 Q-ID / dep 名全文,逐一核對:① Dependencies 表行嘅 ⚠️/✅ 標記;② BLOCKED section 條目(對齊已 RESOLVED 嘅 Q 嘅刪節線處理,如 Q-OQ11);③ QA flag 嘅 sprint-gate count + list。任何仍要求「sprint 前須確認」= stale = RECOMMENDED 起跳,若入 readiness gate list 則 BLOCKING。對照組:同份 GDD 對 Q-OQ11 已做正確 sweep(刪節線 + QA flag「移出 gate list」)可做 template。

關聯 [[audio-manager-priority-steal]]、[[gym-mode-hud-audio-scope]]。
