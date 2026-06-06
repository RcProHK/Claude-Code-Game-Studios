---
name: loot-modal-ux-positions
description: "#21 Loot Drop Modal UX consultation (2026-06-06) — key positions: no auto-dismiss, two-stage tap, commit-at-tap pending semantics, per-tier timing budget table, breakdown-bar verifiable-target catch"
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
