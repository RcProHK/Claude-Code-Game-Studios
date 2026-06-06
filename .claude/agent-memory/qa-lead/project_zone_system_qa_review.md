---
name: zone-system-qa-review
description: "#19 Zone System GDD QA review — Pass 2 (2026-06-06) verdict PASS: 10 PASS/2 WEAK/0 FAIL, 0 phantom, exit bar 12/12 substance-met; 5 ADVISORY items for epic; Pass 1 history below"
metadata:
  type: project
---

#19 zone-system.md QA review 歷史(qa-lead)。

**Pass 2(2026-06-06,fresh verification re-review)**: **PASS — 0 BLOCKING**
- **F/GAP 全清**:phantom workout_id grep 0(8/8 全 `_forwarded`,signature 對 workout_state_tracker.gd:69 verbatim);AC-07 validate_registry form;AC-09 三件套((c) static gate 現時 green — enemy_director.gd 零 zone ref);GAP-1 persist-fail Rule 5 binding + AC-10 two-phase;seam 4 類齊;GAP-8 moot(P2 刪 kind)。
- **AC-02/03/05 BLOCKED-ON 判斷:唔需要** — 軸重裁後 #8/#18 dep 消失,source = shipped #9 signal + injected registry seam,unit-level 自足。剩番 BLOCKED-ON ×2(#29/#20 ceremony consumer)正確。
- **12-AC verdict**:10 PASS / 2 WEAK(AC-04 corruption vector 單一;AC-12 sweep≺connect order 喺 synchronous `_ready` 內 unobservable — 改 functional asserts)/ 0 FAIL。零 self-referencing orphan。
- **Cite 全 grep-verified(0 phantom)**:WST:69 / loot_drop:582 / persistence_layer:291-294(`zone.` 未入 list = G-Z-3 一致)/ enemy_director:506-508 / #8 L46 + Rule 7(L289-293 write-success-then-emit + rollback verbatim)/ #17 L66 UTC pin / EG-4 file 存在 / #18 ×3 sync 實證(L129/L131/L352/L286)/ EC-8 premise(WST L57 SUSPENDED drop)。
- **5 ADVISORY(epic 時收)**:N-1 `zone.unlocked` telemetry 零 AC assert(4 events 得 3 — 併入 AC-02 一行);N-2 EC-5 trigger 喺 WORKOUT_COUNT-only 軸下不可達(unlock 只喺 completion event / boot sweep — 都唔係 mid-workout;defensive spec OK,加一句 note);N-3 Rule 4「load path assert」字眼有 raw-assert 實裝風險(#18 AC-20 同款)+ load 時冇 prior state 可比 — 改 validation+telemetry 或 runtime mutation guard;N-4 drain 後 persist 未 pin(crash-after-drain → re-show,安全方向但應 pin 一句;MVP queue 空,v0.2-facing);N-5 AC-07/09/11/12 GWT form nits(substance 全 testable)。
- Exit bar 12/12 substance-met(item 11 form partial — 見 N-5)。

**Why:** Pass 1 → Pass 2 嘅 fix 全部 grep-verifiable 兌現,zero new phantom(對比 #20 R7 phantom-hell — 呢次 revision discipline 正確)。
**How to apply:** epic 開波時:(1) 5 ADVISORY 做 story-level 收尾(N-1/N-2/N-5 一版 minor polish 即可);(2) Formula note 嘅 #2 cursor ordering assumption(單 slot dedup 夠)要對返 ADR-0002;(3) G-Z-1 ADR-0008 amendment 同 G-PR-3 一齊做;(4) G-Z-3 namespace 一行係 epic story。同 [[pr-detection-qa-review]] / [[equipment-inventory-qa-review]] 同 pipeline。

---

**Pass 1(2026-06-06,adversarial AC review)**: **MAJOR REVISION**(已全清,留底)
- AC verdict:1 PASS(AC-08)/ 3 WEAK(AC-01/03/04)/ 5 FAIL(AC-02/05/06/07/09)。
- 1 phantom field:`workout_completed(workout_id)` 全 doc — shipped 係 `workout_completed_forwarded(completed_at, transition_id)`。
- AC-07 raw assert GUT-untestable;AC-02/03/05 GATED 缺失(舊軸 dep);AC-09 同 G-Z-2 自相矛盾。
- 8 gaps:GAP-1 persist-fail / GAP-2 EC-5 / GAP-3 telemetry / GAP-4 boot states / GAP-5 EC-1 reconcile phantom / GAP-6 seam 章缺失 / GAP-7 讀面 API / GAP-8 PR_MILESTONE。
