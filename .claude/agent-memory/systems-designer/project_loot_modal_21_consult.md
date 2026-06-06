---
name: loot-modal-21-consult
description: "#21 Loot Reveal Modal formulas+EC consult 2026-06-06 — ceremony_freeze 0.4 vs MAX_PAUSE_SEC 0.12 衝突; FAILED_ROLLBACK ambiguity; F1 overlap model"
metadata:
  type: project
---

#21 Loot Reveal Modal consult (2026-06-06) — 提交咗 F1-F6 formulas + EC-M1..M20 sweep 俾主 session 起草 GDD。

**Why:** #21 GDD Section C 已 lock,主 session 需要 Formulas + Edge Cases 內容。

**How to apply:** #21 GDD review pass 時對返以下 ground truth + 檢查兩個 upstream flag 有冇落實。

Key grep-verified facts:
- **🔴 ceremony_freeze 衝突**: screen_effects.gd:55 `MAX_PAUSE_SEC=0.12` 會 clamp 晒 RARE+ time-stop (0.15/0.3/0.4)。ceremony_freeze 必須係 #6 新 API + 自己 ceiling `CEREMONY_FREEZE_MAX_SEC=0.4` 共用 ledger;rationale = modal layer ALWAYS 有 visual anchor。要 #6-scoped story,唔係已有 API。
- **🟡 FAILED_ROLLBACK ambiguity**: inventory_system.gd:161-163 re-entrancy defer path return FAILED_ROLLBACK 但下 frame 真 grant — caller 分唔到真假 failure → #21 對 FAILED_ROLLBACK 只可 telemetry,零 user-visible 反應。
- **F1 結構解**: S2 內 time-stop→hold sequential (match #15 L1059 additive 0.4+0.8=1.2s),S1 entry 同 S2 全程 concurrent;T_block = max(D_entry, D_ts+D_hold);LEGENDARY = 1200ms **equality** — ceiling 必須 `<=` 唔係 `<`(satisfiability)。提議 D_entry ladder 150/200/300/380/450。
- **F2 proof**: RARE+ ⇒ workout 段嚴格 > RNG 段 (0.75ws<0.25rr ⇒ score<0.50<0.55);worst case score=0.55/rr=1.0 → 54.5%/45.5%,8px floor 臨界 W_bar=88px → W_BAR_MIN=120 下 floor provably dead (CI assert 形式,runtime clause 留 corrupt-input 防線)。
- **F3 bound**: MAX_STREAM_BEATS=40 + K_CEREMONY_MAX=5 ⇒ T_machine ≤ 14.3s provable,唔使 runtime time-projection。registry `lootdrop_pending_hard_cap_days=30` 係 **days 唔係件數** (entities.yaml:1104-1116)。
- ReceiveResult = {FAILED_ROLLBACK=0,OK=1,QUEUED_SUSPENDED=2,DUPLICATE_NOOP=3,CONVERTED_DUPE=4} (equipment_enums.gd:56)。CONVERTED_DUPE → S4 後 shard-icon micro_ack (無 count — return 冇 payload)。
- receive_loot 純 local 無 HTTP (inventory_system.gd:152) → DISCONNECTED reveal UX 同 connected 一樣;sync = #15/ADR-0003 (entities.yaml:812 Formula 5)。
- CameraController Rule 5 = strict re-entry silent DROP (camera_controller.gd:99) → 連續 LEGENDARY 要 gate queue advance 喺 focal_completed (line 59) + 1.5s watchdog;FOCAL_EXIT_DURATION=0.5。
- unknown rarity coercion 必須同 #17 一致: RarityTier.get(s, COMMON) (inventory_system.gd:180)。
- LOOT_REVEAL_SAFE_STATES = [IDLE, REST_PERIOD, DISCONNECTED] (game_state_machine.gd:441);safe→safe mid-modal 唔 force-close。
- #6 Suspended override (screen_effects.gd:362) 自己 hard-cancel freeze → #21 release 必須 idempotent;resume 永不 re-issue ceremony_freeze。

Registry 候選 (待 user approve): CEREMONY_FREEZE_MAX_SEC / D_entry ladder / MAX_STREAM_BEATS / K_CEREMONY_MAX / BREAKDOWN_MIN_DELTA_PX=8 / W_BAR_MIN=120。
