---
name: loot-modal-ux-positions
description: "#21 Loot Drop Modal — UX consultation positions (2026-06-06) + adversarial /ux-review 結果 (同日): 6 BLOCKING (GSM Decision #1/#3 contract rows 全漏 / exit affordance vs input policy / stream cadence vs 自家 flash rule / CJK font 斷裂)"
metadata:
  type: project
---

**#21 Loot Drop Modal UX 建議已交付 (2026-06-06)** — 主 session 起草 GDD Detailed Design + UI Requirements 用。立場(future /ux-review 要保持一致):

1. **No timed auto-dismiss** — P-05 嘅 5s auto-dismiss 應撤(OQ-P3 本身已 mark provisional pending #15)。tap-only dismiss + GSM ≥15s force-close 做 safety valve。理由:懲罰攰嘅玩家、破壞快門 fantasy、SR announcement RARE+ 讀完要 >5s。**interaction-patterns.md L175/L186 要跟住 update**。
2. **Two-stage tap**:ceremony 行緊時 tap = fast-complete(snap 終態,sting 照播完——sting 係 colorblind rarity backup channel 唔可以 cut);終態 tap = dismiss。兩段之間 ~250ms lockout 防 mash-through。
3. **Commit-at-tap pending semantics**(建議,#15 contract 待 game-designer 確認):tap = 快門 = claim;force-close 冇 tap 過 → 留 Pending → catch-up 重 reveal。
4. **FR-2 100ms binding 對象 = tier-colored burst onset only**,唔係 modal/text。
5. **Per-tier timing budget table 要有 sum ≤1200ms AC** — LEGENDARY 0.8 hold + 0.4 time-stop 已經 = 1.2s,entry 必須 overlap 唔可以 additive。
6. **Breakdown bar「workout 段視覺大過 RNG 段」係 claim-without-verifiable-target**(同 [[gym-mode-hud-ux-review]] pattern)— 修法:text % label + min-delta px floor,唔好依賴 pixel discrimination。
7. **#20 handshake:兩邊聽 GSM 就夠**,唔加 direct notify;exit 序 = exit anim(≤200ms)完先 signal GSM。#21 own 全屏 tap scrim(#20 AC-CR-5 已 early-return)。
8. **Catch-up = contact-sheet framing**:COMMON/UNCOMMON 自動 stream(免 tap),RARE+ 留尾 ascending(peak-end),summary grid 收尾;隨時 exit,per-item commit,剩低留 pending。
9. **micro_ack「0.15s toast」ambiguity flagged** — 0.15s 係 sub-readable;應係 entry duration,visible ≥1.5s。
10. **Error path:never show-then-revoke** — item identity 顯示 gate 喺 durable local commit 後;Private Mode banner 入 shared top banner stack(同 #20 silent-mode banner 要 priority table)。

**How to apply**: /ux-review loot-drop-modal 時逐項核對 GDD 有冇兌現;特別係 #5/#6 嘅 verifiable numeric target 有冇真係落咗(唔信帳面 ✅)。

---

**Adversarial /ux-review 完成 (2026-06-06,fresh session)** — 上述 10 項 consultation positions 全部兌現 ✓(逐項核過)。但搵到 6 BLOCKING 漏網(authoring 時七 specialist 都冇人 grep GSM downstream contract row):

1. **GSM game-state-machine.md L375 #21 contract row 係 review loot 類 GDD 嘅必查點** — 四項 binding 要求 (a)deferred_reveal (b)未開封 inventory-tap entry (c)BossPayload INTERRUPTED_WITH_CREDIT fast-victory variant (d)rest_ended force-close 保留 `loot_reveal_pending=true` 重試。#21 只兌現 (a);(b)(c) 零 mention,(d) 同 Rule 7「唔做 re-reveal」+ Rule 8 stash-exit 直接矛盾且無 GSM erratum。GSM L128「每個 RestPeriod 只 drain ONE」都同 intra-queue drain-all 衝突。
2. **新 pattern 確認:「自家 a11y rule vs 自家 formula 內部矛盾」** — §C flash ≤3/s vs F3 stream cadence 6.67 beats/s;同款係 CJK copy vs latin-only font 指派(Zpix 12px 喺 accessibility-requirements L87 但 #21 零引用 → H1 11px < body 12px hierarchy inversion)。Review 時要攞 GDD 自己嘅 constraint 互相對撞。
3. **Shipped-code claim 照舊要 grep**:G-LM-6「現時 STUB」係 phantom(platform_detect.gd 零 announce_aria);gym_mode_hud.gd:364 banner tap ALWAYS honored — 「#21 唯一 tap consumer」claim 有 z-order 例外。
4. 「稍後再拆」corner affordance vs AC-11 per-stage 全屏 scrim input policy 衝突 + mid-ceremony exit commit 語意 undefined — never-trap affordance 自己冇 input-policy 行。
5. Catch-up worst-case T_machine 14.3s + taps ≈19s > MIN_REVEAL_WINDOW 15s → peak-end ordering 令最高 tier 最大機率被 force-close cut(best-for-last 反噬)。
