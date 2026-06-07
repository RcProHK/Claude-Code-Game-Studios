---
name: loot-duck-spec-conflict
description: "#15 Visual Spec Table 嘅 per-tier Audio Duck 列(−3..−16dB/固定時長)同 shipped #4 duck 系統(flat −8 high + finished-release)直接衝突 — #21 Rule 4 引用咗 stale 一邊"
metadata:
  type: reference
---

Grep-verified 2026-06-06(#21 loot-drop-modal adversarial review 期間發現):

- **#15** `design/gdd/loot-drop-system.md` L1028-1034 Visual Spec Table 有 per-tier「Audio Duck」列:COMMON −3dB/0.3s → LEGENDARY **−16dB/0.8s**(固定時長語意);L1052 仲話 ceremony 後 ease-back「還原到 **0dB**」;L1054 CI lint forward 要求 verify duck dB/duration 對應呢張表。
- **Shipped #4** `design/gdd/audio-manager.md`(已 implement + merged):high priority 一律 **flat `DUCK_OFFSET_DB=−8`**(safe range **−12–0** — #15 嘅 −16 出界),release 由 **`finished` signal 驅動**(非固定時長,短 sting 用 `SHALLOW_RELEASE_SEC=0.15`),Music base 係 **−6dB 唔係 0dB**。#4 無 per-tier duck 機制(`_register_duck(offset)` 機械上支援 per-call offset,但 spec 冇 per-tier 表)。
- **#21** `design/gdd/loot-drop-modal.md` L70(Rule 4)將「duck」列入「#15 Visual Spec Table own,#21 唔 re-derive」— 即引導 implementer 去睇 stale 嗰邊。#21 L352 嘅 #15 erratum list 只 cover hex,**冇 cover duck 列**。

**How to apply**:任何 #21 epic / G-LM-4 story / #15 erratum / `check_loot_audio_bank.gd` lint 擴展 review 時,duck 真相 = shipped #4(flat −8 + finished-release);#15 duck 列同 0dB 句須入 erratum。關聯 [[audio-manager-priority-steal]]。
