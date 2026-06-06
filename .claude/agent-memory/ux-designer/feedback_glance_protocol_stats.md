---
name: gym-mode-hud-ac-v1-stats
description: Glance-test pass criteria — Wilson CI lower-bound gate with small N is mathematically infeasible; check feasibility before binding
metadata:
  type: feedback
---

設計 peripheral glance-test(或任何 pass/fail playtest gate)時,binding pass condition 用「95% Wilson CI 下界 ≥ X%」+ 小 N 之前,**必先算 sample size 可行性**。

**Why**: #20 Gym-Mode HUD AC-V-1 寫「N≥12 且 Wilson CI 下界 ≥80%」,但 n=12 點估 80% → Wilson 下界僅 ≈0.52;要下界 ≥0.80 需 n≈45-50 + 點估 ≥90%。呢個令 binding entry gate 喺 stated minimum N 下**永遠 fail**,會永久卡死 epic。係 R5 嘅 over-correction(R2 原本「點估≥80% N≥8」合理,R4→R5 越收越緊冇人計數)。

**How to apply**: indie solo dev scope 下,glance-test 多數招唔到 45+ tester。揀其一:(a) pass = 點估 ≥X% + 報 CI 作參考(唔將 CI 下界做 hard gate);(b) 降下界閾值(fantasy 嘅 "80% status" 係 design target 唔一定要做 statistical floor);(c) 若堅持 CI 下界,N 要寫實際所需 sample size 並承認 scope。永遠唔好將「minimum N」同「CI 下界閾值」並列而唔驗交互可行性。相關: [[gym-mode-hud-ux-review]]。
