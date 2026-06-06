# Loot Drop Modal (#21)

> **Status**: Designed(pending fresh-session `/design-review`)
> **Author**: frank + design-system pipeline(full review mode — creative-director / game-designer / ux-designer / godot-specialist / systems-designer / art-director / qa-lead 七 specialist 諮詢)
> **Creative Director Review (CD-GDD-ALIGN)**: REVISED 2026-06-06 — verdict CONCERNS(C-1 folded RARE+ grid identity + C-2 overflow commit point,doc-only)→ 全部 inline 修正;5 個申報 tension 位全 ACCEPT;validation criteria:AC-80/82 sign-off + `stash_exit_count(tier)` EPIC+ 空房率 + FT-3 skip rate
> **Last Updated**: 2026-06-06
> **Implements Pillar**: Pillar 3 (DNF 式爆裝刺激 — signature ritual) · Pillar 2 constraint · Pillar 1 (FR-1 breakdown) · Pillar 5 (LEGENDARY 截圖)
> **Layer / Tier**: Presentation / Pre-MVP
> **Depends On**: #15 LootDrop (Approved, shipped) · #5 Particle (Approved, shipped) · #17 Equipment (Approved, shipped) · #1 GSM · #4 Audio · #6 ScreenEffects · #7 Camera · #33 AttentionBudget · soft: #20 HUD

## Overview

#21 Loot Drop Modal 係 Mirror Hero 嘅 **Pillar 3 signature presentation surface** — 一個 ceremonial reveal modal,負責將 #15 LootDropSystem 產生嘅每件 FULL_CEREMONY loot 兌現成「值得截圖」嘅 dopamine moment。玩家唔需要操作呢個系統:佢喺 GSM `LOOT_DROP` state(natural pause — boss 死/workout 完成)自動開 ceremony,執行 #15 已 spec 嘅 per-rarity ladder(hold/time-stop/camera focal/shake/saturation/particle/fanfare 七軌 orchestration),然後等玩家**單一 tap dismiss** — 呢下 tap 係 ceremony 期間唯一合法輸入(GSM AC-11b「modal is the input, not the surroundings」)。Dismiss 即觸發 reveal-ack handoff:#15 advance queue、#17 `receive_loot()` 入庫 + auto-equip-if-better。#21 同時 own MICRO_ACK 0.15s toast(cap-pressure degrade)同 Disabled banner 呢兩個輕量 surface。冇咗 #21,loot 只係 silent data row — 正正係 Pillar 3 禁止嘅「不知不覺發生」;MVP hypothesis(「爆裝感覺值得做返第二日」)成敗直接繫於本系統。實作上 #21 係 thin orchestration consumer:rarity 計算/ceremony 決策(FULL/MICRO_ACK)全由 #15 own,ADR-0005 嘅 75/25 公式喺 RARE+ breakdown bar 可視化(binding),#21 只 own choreography sequencing + modal UI 本身。

## Player Fantasy

> **Framing**: Direct — 玩家直接感受;#21 係成個 game 嘅 dopamine 兌現窗口。
> **CD framing 裁決(2026-06-06)**:「閃光燈定格」(The Flashbulb);「唯一證人」聲線吸收入 EPIC/LEGENDARY caption variant。

**Anchor**:「**一下閃光,將你成個 set 定格落一件裝備度。**」

#15 已經答咗「loot 係乜」— body work 嘅憑證;#21 答嘅係「**收到憑證嗰一刻係咩感覺**」:俾閃光燈拍低嘅瞬間。閃光燈嘅亮度同佢嘅短促係同一樣嘢 — 愈短愈亮。呢個唔係對 Pillar 2 嘅妥協,係 framing 自己嘅美學邏輯:ceremony ≤1.2s(#15 attention ceiling)因為快門本來就係一瞬。

**Player moment**(anchor 場景):rest period,攰住、流緊汗、攞部機上嚟望 → time-stop = 快門凍結世界 → 件裝備以明信片 composition 喺 frame 入面(#15 LEGENDARY orbit drift 係呢個 metaphor 嘅字面實現)→ tap dismiss = 撳快門、將張相袋落袋。Tap 嘅 fantasy 意義係「**收藏**」,唔係「關 popup」。

**Tone / micro-copy 指引**(modal 全部文字跟呢套):

- 相片 caption 語氣 — present tense、**零正向運氣歸因**(禁「好彩/lucky」;否定式歸因如「RNG 唔夠 0.25」係 P1-reinforcing,**准** — CD N-1 precision)、一眼吸收(攰到爆嘅人唔閱讀,只 glance)
- 數字行先:「Stamped by 180kg × 5」(#15 CD Framing A downstream 指示字面兌現)
- EPIC/LEGENDARY caption variant 可用證人聲線(第二人稱、訓練拍檔 hype):「呢件,RNG 唔夠 0.25 — 係你嘅身體 unlock 嘅。」(#15 FR-1 emotional microcopy 同源)

**Reference 對位**:

- 攞 **DNF** 嘅 unapologetic 全屏感官爆發(粒子 3×、fanfare、screen-claiming flash);改:DNF euphoria 係低 drop-rate 嘅運氣驗證,我哋將同一套感官語言重新指向 **effort 驗證** — 閃光嘅 subject 係你嘅 workout data,唔係件 item
- 攞 **Diablo** legendary beam 嘅「光 = 承諾」anticipation gap(見到光、未知係乜嗰半秒 = burst→reveal 嘅 100ms→hold 結構);改:唔做 loot flood — 一 event 一件,每件保留全儀式重量

**Pillar 對齊**:

- **Pillar 3**(primary):design test「爆裝畫面值唔值得 cap 圖?」— flashbulb framing 令 modal 本身就係為俾人影相而 compose 嘅一格;FT-1 screenshot test 嘅 framing-level 兌現
- **Pillar 2**:短促係 form 唔係 constraint(上述);reveal 只發生喺 natural pause,mid-set 由 #15 Pending pool 兜住
- **Pillar 1**:相上蓋印 = 收據字面形態,「Stamped by」唔係比喻係描述;RARE+ breakdown bar(75/25)係張相嘅 EXIF — 證明邊部分係身體
- **Pillar 5**:LEGENDARY 明信片 composition 直接服務 Mirror Moment 截圖文化

## Detailed Design

> **Specialist 裁決記錄(2026-06-06 full review)**:game-designer + ux-designer + godot-specialist 並行諮詢;全部裁決已 synthesis 落 rules。唯一分歧(handoff 時機)CD-level blend:`receive_loot()` @ S3 + `modal_dismissed` @ dismiss,唔做 re-reveal(理由見 Rule 7)。

### Core Rules

1. **身份同 surfaces** — `LootRevealCoordinator`(autoload,thin Node)own 三個 presentation surface:(a) **Full reveal modal**(Pillar 3 主儀式);(b) **micro-ack toast**(cap-pressure degrade acknowledgment);(c) **Banner stack**(Private Mode disabled banner 等 shared banner region)。Coordinator 喺 `_ready` instantiate 並持有 `ModalLayer`(CanvasLayer)同 `CelebrationVFXLayer`(CanvasLayer),係 >100 層嘅 single owner(layer 數值 ground truth 屬 ADR-0001 revision — **G-LM-1**)。

2. **Reveal trigger 三層分工(ownership split)** — 避免 double-gating 同 gate 真空:
   - **GSM own「幾時」**:Rule 13 reveal gating 已 shipped(`LOOT_REVEAL_SAFE_STATES` + `gsm.loot_reveal_pending`)。#21 開 modal 嘅**唯一** trigger = `state_changed → LOOT_DROP`(boot path 必須用 `connect_for_initial_state` — ADR-0006 Contract 6,兜住 `force_reveal_on_next_session` 場景 boot 時 GSM 已喺 LOOT_DROP)。
   - **#15 own「咩內容」**:pending queue 係 source of truth;#21 經 `get_pending_drops()` / `get_drop(drop_id)` pull。
   - **#21 own「點呈現」**:choreography sequencing、drain pacing、全部 presentation 調用。
   - `loot_dropped` signal 降級為 **doorbell/prep 用途**(texture pre-warm 確認、pending badge 更新):收到時如 modal 唔 active 且 GSM 喺 LOOT_DROP → drain head;否則 no-op(件嘢喺 #15 queue,下個 drain step 自然攞到)。**`loot_dropped` 唔係「即開 modal」指令** — mid-set drop 嘅 deferral 由 GSM Rule 13 處理,#21 唔自建 wait queue。

3. **Reveal pipeline 五段(S0–S4)** — 每段有明確 content 狀態 + input policy:

   | 段 | 時間(自 reveal 開始) | 內容狀態 | Input policy |
   |---|---|---|---|
   | **S0 Burst** | T+0 → ≤100ms onset | tier-colored particle burst(#5 `play(LOOT_BURST/LOOT_RARE_BURST, item_world_pos)`)+ flash frame。**FR-2 100ms hard binding 嘅對象只係 S0** — rarity 喺 ~100ms 已 pre-attentively 可讀(burst 帶 tier color) | 唔收 tap |
   | **S1 Entry** | ~150ms → ~450ms | modal scale 0.8→1.0(elastic-light overshoot);**scale-in 完成嗰 frame 6 個 content slot 必須全部 final** — 唔准 staggered text pop-in(攰人 glance 可 land 喺任何時刻,stagger 製造「我 miss 咗嘢」uncertainty) | 唔收 tap |
   | **S2 Ceremony** | per-tier(#15 ladder:hold 0.2–0.8s + time-stop 0–0.4s) | content 已 final;ceremony VFX 行緊(freeze/shake/saturation/focal) | tap = **fast-complete**(Rule 5) |
   | **S3 Steady** | ceremony 完 → tap 為止 | 靜態 dismissable 終態;ScreenReader announcement 喺呢度 fire(一次);`receive_loot()` handoff 喺呢度 fire(Rule 7) | tap = dismiss |
   | **S4 Exit** | tap → ≤200ms | 快門定格 → shrink/fade;**exit anim 完成先通知 GSM transition**(terminal dismiss 時) | 唔收 tap;對 GSM force-close idempotent |

   Entry 同 hold **必須 overlap 計時,唔可以 additive**(否則 LEGENDARY 超 1.2s attention ceiling — 見 Formulas F1 timeline budget)。

4. **Ceremony ladder 執行** — per-tier 數值(hold / time-stop / camera / shake / saturation / particle preset / duck)**全部由 #15 Visual Spec Table own**,#21 唔 re-derive、唔另印數。#21 own 嘅係 orchestration 調用序:S0 particle burst(frame 0,FR-2)→ camera focal(RARE+:`Camera.request_focal(item_world_pos, 0.6, 1.4)`,必須 GSM==LOOT_DROP 之後 — #7 Rule 4)→ time-stop(`ScreenEffects.ceremony_freeze(duration)` — **G-LM-3**)→ shake + saturation(#6)→ fanfare(audio 觸發 ownership 見 Interactions #4 row)。`focal_completed` signal 用嚟 chain LEGENDARY orbit drift 開始點(#7 contract)。

5. **Dismiss policy:tap-only + two-stage tap** —
   - **無 timed auto-dismiss**(P-05 嘅 5s auto-dismiss 撤銷 — **G-LM-7** P-05 更新):auto-dismiss 唯一「炒」嘅人就係望得最慢嗰個(loss-aversion sting 打擊 Pillar 3);「tap = 撳快門」fantasy 要求 dismiss 必須係玩家嘅 act;RARE+ SR announcement 讀出可能 >5s。「Never traps」由 system 層兜:GSM ≥`MIN_REVEAL_WINDOW`(15s)後外部 transition 可以 force-close(Rule 8 stash-exit),#15 Pending pool 保證零 loss。
   - **Two-stage**:S2 tap = fast-complete(content snap 到 S3 終態、`ceremony_freeze` 即時 release、particle fast-decay 0.2s 唔 hard-cut、**audio sting 照播完唔 cut** — sting 係 colorblind 玩家嘅 rarity backup channel,#15 §D);S3 tap = dismiss。兩 stage 之間 `DISMISS_DEBOUNCE_SEC`(0.25s)input lockout — 攰手 mash 兩下唔會連 skip 帶 dismiss 盲拆。
   - **Tap surface = 全屏 scrim**,≥48dp CTA 只係 labelled affordance(「tap 收藏」)— Fitts's law + 汗手,唔要求瞄準。LOOT_DROP 期間 #20 已 early-return tap(#20 AC-CR-5),#21 係唯一 tap consumer。
   - Dismiss tap 行 **#33 exempt handler pattern**(唔經 `is_input_permitted()` — #33 EC-15 / GSM AC-11b「modal is the input, not the surroundings」)。

6. **Queue drain:pull model + intra/terminal split** —
   - Dismiss → emit `modal_dismissed(transition_id)` → #15 handler **以 transition_id dequeue**(唔係 strict head-pop — catch-up 模式 #21 可重排 reveal 順序,見 Rule 10;handler spec 屬 **G-LM-4** #15 reverse-wire story)→ #21 query `get_pending_drops()`。
   - **Intra-queue dismiss**(queue 非空):advance 下一件,**GSM 唔郁**(唔 exit/re-enter LOOT_DROP N 次);前後件之間 `INTER_REVEAL_GAP_SEC`(0.3s)gap。
   - **Terminal dismiss**(queue 清空):S4 exit anim 完成 → 通知 GSM 離開 LOOT_DROP。
   - **One-modal-at-a-time**:reveal 行緊時新 `loot_dropped` 嚟 → no-op(doorbell 語意,Rule 2)— 唔開第二個 modal。

7. **Handoff 時機(雙軌)** —
   - **Functional banking**:`InventorySystem.receive_loot(drop)` 喺 **S3 到達時** call(唔係 tap 時)。#21 係 shipped `receive_loot()` 嘅唯一 caller(現時零 caller — epic wire)。咁樣 tap 純粹係 ceremonial(收相),玩家永遠唔 tap 都唔丟 item,「trap」嘅 functional stakes 清零;#17 duplicate no-op + batch debounce(#17 EC-22/AC-29)兜底。
   - **Queue dequeue**:`modal_dismissed` 喺 tap dismiss / stash-exit 時 emit(Rule 6/8)。
   - **唔做 re-reveal**:`MIN_REVEAL_WINDOW`(15s)≫ ceremony 全長(≤~1.9s 連 entry/exit),S3 必然先於任何外部 force-close 到達 —「moment 未送達就被斬」場景結構上唔存在;re-reveal 已 banked item = 假快門(anti-flashbulb)。
   - Catch-up batch 跟 #17 batch 尾 debounce 語意(逐件 `receive_loot`,#17 aggregate/push/persist 各一次)。

8. **Stash-exit(GSM force-transition while modal open)** — 玩家唔望 mon、新 set 開始等外部 transition(≥15s 後)發生:modal 行 ≤0.3s「stash」收埋動畫(無需 input)→ emit `modal_dismissed`(auto-collect — item 已喺 S3 banked)→ 將被 stash 嘅 drop 加入 deferred-ack 計數,**下次進入 safe state 出 aggregated ack toast**(「+N 已收藏」,micro-ack surface 重用)。S4 dismiss path 對 force-close **idempotent**(force-close 落喺 exit anim 中途唔 double-emit)。

9. **micro_ack toast spec** — `loot_micro_ack(drop_id)` 觸發:
   - 位置:screen edge(同 #20 layout 協調,permanent corner 區附近),**永不佔 center stage**(中央係 sacred reveal space)。
   - 內容:item icon + rarity-tint flash,**無文字**(sub-second 讀唔到字);0.15s = **entrance beat**(對齊 catch-up burst cadence),total visible ~1.2s 連 fade(對齊 attention ceiling)。「0.15s toast」嘅 #15 doc comment 以此解讀 — 0.15s total = subliminal,acknowledge 唔到嘢,違 micro_ack 嘅 Pillar 1 存在意義(multi-effort 應被 acknowledge)。
   - **Non-interactive**(唔可 tap):tappable 要過 #33 exempt handler,複雜度換邊際價值近零;item 已 grant,inventory 見得返。
   - **Modal active 時 defer + aggregate**:dismiss 後 flush 成單一 aggregated toast(「+N」),唔 serial 逐個出(LEGENDARY focal lock 期間角落彈 toast = attention competitor)。連續多個 micro_ack 同理 aggregate。
   - **Safe-state gate(F4 flush gate — #15 L1081 對齊)**:`loot_micro_ack` 通常喺 mid-workout cap-hit 觸發,而 #15 UI Requirements 明文「workout 進行中唔顯示任何 toast/overlay」— 所以 toast **永不喺 non-safe state 顯示**:hold + aggregate,下次 GSM safe-state entry(REST_PERIOD / IDLE)先 flush。Acknowledgment 喺 natural pause 兌現,Pillar 1(multi-effort 被認可)同 Pillar 2(mid-set 零干擾)同時保全。

10. **Catch-up mode(contact-sheet model)** — `get_pending_drops()` ≥ `CATCH_UP_THRESHOLD`(5,#15 Formula 6)→ summary banner「您有 N 個未拆 loot」+ 主 CTA「tap to reveal all」:
    - **Banner 可 defer**:dismiss banner = 留 Pending 下次再嚟,唔係 forced flow(玩家可能趕住走)。
    - **Sub-RARE 自動 stream,零 tap**:0.15s/件 burst 流水過(aggregated particle effect,唔逐件 full burst — #5 EC-18 caller dedup 責任)。
    - **RARE+ 留最尾,ascending rarity,各自 full ceremony + tap**(peak-end rule:sequence 以最好嗰件收尾)。
    - **收尾 summary grid**:全部 N 件 rarity-sorted 一屏(「相辦/contact sheet」)— closure + screenshot-worthy(FT-1 對齊)。
    - **中途可退出**(Pillar 2 never-trap):常駐「稍後再拆」affordance(角落,≥48dp);**per-item commit** — 每件 reveal 完即時 `modal_dismissed` + banked,退出時剩低嘅原封留 Pending,banner 下次以更新咗嘅 N 重現,零懲罰。

11. **Rollback 處理(`loot_rollback`)** —
    - Reveal 行緊(S0–S3)收到 rollback:≤1 frame cancel、**必須 restore timescale**、無 terminal frame、無 toast、**唔 emit `modal_dismissed`**(#15 rollback path 自己處理 queue,emit 會 double-advance)。
    - Queued 未 reveal 嘅 rollback:pull model 下零動作(#15 自己出 queue,下次 query 見唔到)。
    - **Timescale guaranteed-restore invariant(INV-M1)**:所有 cancel path(fast-complete / rollback / stash-exit)共用單一 freeze-release 出口 — time-stop dangling = 全 game 凍結,係 #21 最高危 failure mode。
    - **永不 show-then-revoke**:S0 burst 係 non-committal(「有嘢嚟緊」嘅閃光,未 promise 具體 item);S1 content 填充 gate 喺 #15 optimistic persist 嘅 local commit 窗口之後 — 玩家見到嘅失敗形態永遠係 deferral(「Loot 已記低,稍後再拆」),唔係 revocation(見到件 EPIC 然後收返 = Pillar 1 attribution trust 最大破壞)。

12. **Disabled banner + banner stack** — `loot_disabled(reason)` → banner stack 顯示 #15 own 嘅 copy(「Private Mode:Loot 暫停掉落…」)。Modal active 時收到 → 現行 ceremony 行完,banner 喺 dismiss 後先出(唔 mid-ceremony 蓋 banner 偷走 euphoria);同時收到 rollback → rollback 優先。Banner stack:top edge full-width、safe-area 下方、**同 #20 banner 共用單一 stack region,同屏最多一條,priority:`private_mode` > 其他(audio silent-mode 等)**;絕不侵 #20 L1 anchor zone;`role=status` announce 一次。

13. **Empty-queue LOOT_DROP entry**(rollback race:入咗 LOOT_DROP 但 `get_pending_drops()` 空)→ #21 即 emit terminal dismiss 等 GSM 推進 — 否則 stuck state。

14. **玩家唔可以做嘅嘢**(constraints):mid-ceremony 唔可以 dismiss(只可 fast-complete — 保證 terminal frame 永遠被見到,reveal 唔 missable);唔可以 re-open 已 dismiss 嘅 reveal(dismiss-peek pattern 唔存在 — #5 EC-18 嘅 dedup 場景以唔提供 re-peek 直接消滅);唔可以喺 modal 開住時操作周邊(#33 ceremony lock);唔可以 skip audio sting(rarity backup channel)。

15. **Telemetry hooks(#28 未 build,signal 口要留)**:`ceremony_skip_attempted(tier)`、`time_to_dismiss_ms`、`stash_exit_count(tier)`(CD N-2:Rule 7「唔做 re-reveal」裁決嘅 empirical 前提係「EPIC+ 送入空房係罕見事件」— 要 by-tier 量得到,rate 唔低就重審)、`catchup_abandoned(remaining)` — FT-3 skip test 同 reveal engagement 嘅量度口。

### States and Transitions

`LootRevealCoordinator` 嘅 modal FSM(toast 同 banner 係 parallel surfaces,唔入 FSM):

| State | 意義 | Entry | Exit |
|---|---|---|---|
| `HIDDEN` | modal 唔 visible(pre-warmed,`visible=false`) | boot / S4 完成 | GSM → LOOT_DROP 且 queue 非空 |
| `ENTRY` | S0 burst + S1 scale-in | reveal 開始 | S1 完成(content final)→ CEREMONY |
| `CEREMONY` | S2 per-tier ladder 行緊 | ENTRY 完 | ladder 完 → STEADY;tap → fast-complete → STEADY;rollback → HIDDEN(cancel path) |
| `STEADY` | S3 dismissable 終態(SR announce + `receive_loot` 喺 entry 時 fire) | CEREMONY 完 | tap dismiss / stash-exit → EXITING |
| `EXITING` | S4 exit anim | dismiss | anim 完:queue 非空 → (gap 0.3s) ENTRY;queue 空 → HIDDEN + 通知 GSM |
| `CATCHUP_PROMPT` | summary banner 顯示中 | GSM → LOOT_DROP 且 pending ≥ CATCH_UP_THRESHOLD | tap reveal-all → ENTRY(stream mode);defer → HIDDEN + 通知 GSM |
| `CATCHUP_GRID` | 收尾 contact-sheet grid | stream 完 | tap / 外部 transition → HIDDEN |

每個 cancel/exit path 經單一 freeze-release 出口(INV-M1)。

### Interactions with Other Systems

| 系統 | 方向 | Interface owner | Contract |
|---|---|---|---|
| **#15 LootDrop** | #15 → #21 signal;#21 → #15 emit-back + pull | #15 | subscribe `loot_dropped`(doorbell)/ `loot_micro_ack` / `loot_rollback` / `loot_disabled`;pull `get_pending_drops()` / `get_drop(drop_id)`;emit `modal_dismissed(transition_id)` → #15 以 transition_id dequeue(**G-LM-4**:#15 加 handler,reverse-wire story,#18 先例) |
| **#1 GSM** | #1 → #21(state);#21 → #1(terminal dismiss) | #1 | `connect_for_initial_state(state_changed)`;開 modal 唯一 trigger = → LOOT_DROP;terminal dismiss 通知 exit(機制對齊 shipped exit path — **G-flag-3**);Rule 13 safe states + `MIN_REVEAL_WINDOW` 係 #1 own |
| **#17 Equipment** | #21 → #17 call | #17 | `receive_loot(drop)` @ S3(唯一 caller;duplicate no-op + batch debounce #17 兜) |
| **#5 Particle** | #21 → #5 call | #5 | `play(LOOT_BURST / LOOT_RARE_BURST, item_world_pos)` per #15 tier mapping;catch-up stream 用 aggregated effect(EC-18 caller dedup);**G-LM-2**:LOOT pool nodes reparent 入 CelebrationVFXLayer + `PROCESS_MODE_ALWAYS`(現時 INHERIT — tree paused 時 burst 會 freeze,違 ladder「particle 繼續」;且 layer 0 會被 saturation 降格,違 art bible「爆裝特效全飽和」) |
| **#6 ScreenEffects** | #21 → #6 call | #6 | shake + saturation tween(現有 API);**G-LM-3**:新 `ceremony_freeze(duration)` primitive(ceiling 0.4s,同 hit_pause 共用 freeze ledger,繼承 #6 Suspended/focus-resume 安全網)— #21 唔自己掂 `get_tree().paused` |
| **#7 Camera** | #21 → #7 call + signal | #7 | RARE+ `request_focal(item_world_pos, 0.6, 1.4)`(GSM==LOOT_DROP 後先 call — #7 Rule 4);subscribe `focal_completed` chain orbit drift |
| **#4 Audio** | trigger 見 note | #4 | `loot_fanfare_{tier}`(STEREO high duck)觸發時機 = **S0 reveal onset**(LEGENDARY pre-roll 對齊 0.1s pre-shake);#4 catalog source 列 #15 — **觸發 caller 歸屬喺 G-LM-4 story 一併釘實**(reveal-time 觸發要 reveal-side 知識,catalog 行歸屬以 shipped wiring 為準);`ui_back`/`ui_error` 屬 #21 可用(low/mono);micro_ack sting 降一 tier(#15 spec) |
| **#33 AttentionBudget** | #21 reads pattern | #33 | dismiss tap 用 exempt handler(唔經 `is_input_permitted()` — #33 EC-15);周邊 lock 係 #33/#20 行為,#21 零依賴 |
| **#20 HUD** | 無 direct contract | GSM-mediated | **唔加 direct notify** — 兩邊聽 GSM(雙真相源 + ordering coupling 風險);入場 skew 係 feature(HUD dim 先、burst 後 = 影相前調光 anticipation beat);exit 序 pin:S4 anim 完 → GSM transition → #20 un-dim(答 #20 Q-OQ6);banner stack 共用 contract 見 Rule 12 |
| **PlatformDetect** | #21 → call | PlatformDetect | `announce_aria(text)` gateway(**G-LM-6**:現時 STUB,epic story 實現;boot 時 inject hidden `aria-live` div — live region 必須 first announcement 前已存在於 DOM) |
| **#3 Persistence** | 無 | — | #21 **stateless presentation** — 零 persistence 寫入;reveal pending 係 #15(`loot.pending.*`)+ GSM(`gsm.loot_reveal_pending`)own |
| **#19 Zone** | 無(explicit non-goal) | — | Zone unlock ceremony = non-item reward,P-05「When NOT to Use」明文排除;#19 `drain_ceremony_queue()` 嘅 aggregated reveal 屬 post-workout summary surface(#20/#29),唔係 #21 |

## Formulas

> **Authoritative scope**:rarity 計算(`loot_rarity_score` / `workout_score` / `rng_roll` / tier thresholds)全部 ADR-0005 + #15 own — #21 唔 re-derive。本節只定義 **#21-owned presentation formulas**:timeline budget、breakdown bar 幾何、catch-up 時長、toast aggregation、fast-complete、stash budget。
> **Grep-verified 發現(systems-designer 2026-06-06)**:① #6 `MAX_PAUSE_SEC=0.12`(`screen_effects.gd:55`)會 clamp 死 RARE/EPIC/LEGENDARY time-stop — `ceremony_freeze` 必須係 #6 新 API entry point,有**自己嘅 `CEREMONY_FREEZE_MAX_SEC=0.4`**,共用 ledger 但唔受 `MAX_PAUSE_SEC` 管(hit pause 0.12 ceiling 理由係「無 visual anchor 嘅 freeze 似 hang」;ceremony 期間 modal layer ALWAYS + burst 動畫做 anchor)→ G-LM-3 amendment spec。② `ReceiveResult` 五值 enum 證實(`equipment_enums.gd:56-62`),`FAILED_ROLLBACK` 真假 ambiguous(re-entrant defer path 都 return 佢 — `inventory_system.gd:161-163`)。③ Camera Rule 5 re-entry = silent DROP(`camera_controller.gd:99`)。

### F1 — `blocking_attention_timeline`(per-tier 時間預算)

**結構(satisfiability 嘅唯一解,寫死防止將來被「優化」成 additive)**:S2 內 time-stop 同 hold **sequential**(S2a freeze-impact → S2b hold — match #15 L1059 additive arithmetic);**S1 entry 同成個 S2 concurrent**(三 track 同時由 T=0 起跑)。S1 如 additive,LEGENDARY = 450+400+800 = 1650ms > ceiling — overlap 係必要條件。T=0 = S0 burst onset;FR-2 嘅 trigger→S0 ≤100ms latency 唔計入 budget。

`T_block(tier) = max(D_entry(tier), D_timestop(tier) + D_hold(tier))`

**Constraint C1**:`D_entry(tier) ≤ D_timestop(tier) + D_hold(tier)` ∀ tier(成立時 `T_block = D_timestop + D_hold`,同 #15 一致)
**Hard assert**:`T_block(tier) ≤ ATTENTION_CEILING_MS` ∀ tier — **CI/data-load assert,唔用 runtime clamp**(clamp 靜默壓扁 ladder);ceiling 必須係 `≤`(LEGENDARY equality touch — `<` 即不可達 binding,satisfiability 教訓)

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| entry 時長 | D_entry | float ms | 150–450(per-tier knob,#21 own) | S1 scale-in |
| time-stop 窗 | D_timestop | float ms | 0–400(**#15 ladder locked**) | S2a freeze |
| hold 窗 | D_hold | float ms | 200–800(**#15 ladder locked**) | S2b hold |
| attention ceiling | ATTENTION_CEILING_MS | int ms | 1200(locked,#15 Pillar 2) | blocking 上限 |

**Per-tier timeline(sum column = T_block):**
| Tier | D_entry | S2a timestop | S2b hold | **T_block** | ≤1200 | C1 |
|---|---|---|---|---|---|---|
| COMMON | 150 | 0 | 200 | **200** | ✓ | ✓ |
| UNCOMMON | 200 | 0 | 350 | **350** | ✓ | ✓ |
| RARE | 300 | 150 | 500 | **650** | ✓ | ✓ |
| EPIC | 380 | 300 | 650 | **950** | ✓ | ✓ |
| LEGENDARY | 450 | 400 | 800 | **1200** | ✓(equality) | ✓ |

**Output Range:** [200, 1200] ms。S4 exit(≤200ms)+ `INTER_REVEAL_GAP_SEC` 唔計入 budget;saturation 2.0s recovery 屬 non-blocking ambient(#15 已定)。
**Example(LEGENDARY):** T=0 burst + entry 開始 + `ceremony_freeze(0.4)`;T=400ms freeze-release(INV-M1 單一出口);T=450ms content final;T=1200ms 入 S3。
**motion_reduction variant:** D_timestop=0 全 tier ⇒ `T_block = max(D_entry, D_hold)` = 200/350/500/650/**800** ms — ladder 單調性保留。

### F2 — `breakdown_bar_geometry`(RARE+ 75/25 可視化,ADR-0005 binding)

Normalize 分母 = `loot_rarity_score`(兩段恆等填滿 bar):

```
contrib_w = 0.75 × workout_score          contrib_r = 0.25 × rng_roll
frac_w = contrib_w / score                frac_r = 1 − frac_w
px_w = round(frac_w × W_bar)              px_r = W_bar − px_w
pct_w = round_half_up(frac_w × 100)       pct_r = 100 − pct_w     ← 保證 sum=100
Floor clause: if (px_w − px_r) < BREAKDOWN_MIN_DELTA_PX → px_w = ceil((W_bar+MIN_DELTA)/2)(corrupt-input 防線)
Display gate: W_bar < W_BAR_MIN → stacked text-only variant(% label mandatory,無 info loss)
```

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| workout/rng 原值 | workout_score, rng_roll | float | [0,1](clamp on read) | ADR-0005 |
| rarity score | score | float | [0.55, 1](RARE+ 先有 bar) | tier threshold RARE=0.55 |
| bar 寬 | W_bar | int px | ≥ W_BAR_MIN(120) | 標稱寬 |
| 最少凸出 | BREAKDOWN_MIN_DELTA_PX | int | 8(UX locked) | workout 段 ≥ RNG 段 + 8px |

**Output Range:** px_w ∈ [0, W_bar],pct ∈ [1,99] sum=100。
**Worst-case 驗證(RARE 下界):** score=0.55、rng_roll=1.0(contrib_r=0.25)⇒ workout_score=0.40(contrib_w=0.30)⇒ **54.5% / 45.5%**;@W_bar=160 → 87px/73px,delta=14px ≥ 8 ✓。8px 臨界寬 = 88px ⇒ **W_BAR_MIN=120 下 floor clause 對 legal input provably 永不觸發**(CI 改 assert「legal grid 下 naive rendering ≥8px」)。
**免費 invariant(INV-M2,Pillar 1 bar-level 體現):** RARE+ ⇒ workout 段**嚴格大過** RNG 段(0.75ws < 0.25rr ⇒ score ≤ 0.50 < 0.55 — 數學上排除)。
**Example:** score=0.55, ws=0.40, rr=1.0, W_bar=160 →「汗水 55% / 運氣 45%」87px/73px。

### F3 — `catchup_duration`(總時長 + second-level compression)

```
T_machine = T_banner_beat + min(N_sub, MAX_STREAM_BEATS) × C_stream
          + Σ_{i ∈ top-K(RARE+)} (G_gap + T_block(tier_i)) + T_grid
K = min(|RARE+|, K_CEREMONY_MAX);溢出件直入 contact-sheet grid
Ceremony 揀選:tier 降序 top-K(同 tier 內 chronological);reveal 順序照舊 ascending
RARE+ 溢出 identity 保證(CD-GDD-ALIGN C-1):ceremony-overflow 嘅 RARE+ 件必須喺 grid 以
  獨立 cell 顯示(icon + rarity text label 齊,P-06 list-display rule);「+N」badge 只准
  aggregate sub-RARE / MAX_STREAM_BEATS 溢出件 — RARE+ 永不 collapse 入數字(P3「不知不覺發生」禁令)
Overflow commit point(CD-GDD-ALIGN C-2):ceremony-overflow 件喺 grid entry 時 batch commit
  (逐件 receive_loot + modal_dismissed,#17 batch debounce 語意 — 同 Rule 7 catch-up 條款一致)
```

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| sub-RARE 件數 | N_sub | int | ≥0 | pending 低 tier |
| stream cadence | C_stream | float s | 0.15(#15 locked) | 每件 beat |
| stream cap | MAX_STREAM_BEATS | int | 40 | 溢出折入 grid |
| ceremony cap | K_CEREMONY_MAX | int | 5 | full ceremony 上限 |
| gap | G_gap | float s | 0.3 | INTER_REVEAL_GAP_SEC |
| grid entry | T_grid | float s | 0.5 | contact-sheet 入場 |

**Output Range:** `T_machine ∈ [0.8, 14.3]s`(provable bound:0.3 + 40×0.15 + 5×(0.3+1.2) + 0.5 = 14.3s — cap 本身 enforce bound,唔使 runtime time-projection)。T_machine **唔計 player tap**(RARE+ tap-paced)。
**Example(30 件 boot force-reveal:14C+10U+4R+1E+1L;qa-lead gap-fix 2026-06-06 — RARE+ 共 6 件 > K=5,cap 觸發):** ceremony 揀選 top-5 tier 降序 = L+E+3R,**第 4 件 R 折入 grid(獨立 cell + rarity label,non-ceremony — C-1)**;stream 24×0.15=3.6s;ceremonies 3×0.95+1.25+1.5=5.6s;grid 0.5;banner 0.3 → **T_machine = 10.0s**,+5 taps ≈12.5s perceived。120 件 sub-RARE → stream cap 6.0s,80 件折入 grid「+80」(sub-RARE 先准 collapse)。
(注意:registry `lootdrop_pending_hard_cap_days=30` 係 **days** 唔係件數 — 唔好混淆。)

### F4 — `toast_aggregation`(micro_ack / deferred-ack)

```
N_agg=1 → icon + tier tint(無文字);≥2 → icon + 「×N」badge;>99 → 「×99+」;tint = 最高 tier
Merge(toast visible 時新 ack):N_agg += 1;remaining := max(remaining, MERGE_MIN_REMAIN)
Instance hard cap:TOAST_MAX_LIFETIME — 到 cap 即 fade,carryover 開新 toast
Flush gate(qa-lead gap-fix + art-director conflict 統一解 2026-06-06):
  flush 條件 = modal 完全 close(S4 / stash-exit / catch-up exit)後 FLUSH_DELAY **且 GSM ∈ LOOT_REVEAL_SAFE_STATES 對應嘅 player-attention-safe 集(IDLE / REST_PERIOD / DISCONNECTED)**
  GSM 唔喺 safe state(stash-exit 場景 / mid-workout micro_ack)→ hold + 繼續 aggregate,下次 safe-state entry 先 flush
  ⇒ 同時滿足 #15 L1081「workout 進行中零 toast/overlay」+ Rule 8「下次 safe state 出 ack」,#15 零 erratum
Instance 時間結構:entry(TOAST_ENTRY_SEC)→ visible plateau(TOAST_VISIBLE_SEC)→ fade-out(TOAST_FADE_SEC)
```

**Variables:** `TOAST_ENTRY_SEC=0.15` / `TOAST_VISIBLE_SEC=1.2`(plateau,唔包 entry/fade)· `TOAST_FADE_SEC=0.15` · `MERGE_MIN_REMAIN=0.6` · `TOAST_MAX_LIFETIME=3.0` · `FLUSH_DELAY=0.1` · N_disp ∈ 1–99+
**Output Range:** toast instance 壽命 ∈ [1.2, 3.0]s。
**Example:** modal 期間 3 ack → defer;terminal dismiss 後 0.1s 出最高-tier-tint「×3」toast。

### F5 — `fast_complete_snap`(two-stage tap 嘅 stage-1)

```
Tap 有效窗:t_tap ∈ [D_entry, T_block) ⇒ fast-complete;t_tap < D_entry 一律 ignore(content 未 final + 兜 tap-through)
Snap:freeze 即 frame release(INV-M1);in-flight tween snap-to-final over SNAP_SEC(0.1s — 唔用 0-frame,0-frame 只留俾 rollback)
S3 entry @ t_tap + SNAP_SEC;min-readable:DISMISS_DEBOUNCE_SEC(0.25s)內 dismiss tap ignore
T_block_fast = t_tap + SNAP_SEC ∈ [D_entry + 100, T_block)
```

**Example(LEGENDARY):** tap@500ms → S3@600ms、最早 dismiss@850ms — 慳 600ms,tap-spam 跳唔過 0.25s readable window。

### F6 — `stash_exit_budget`

`T_stash = freeze_release(同 frame)+ T_collapse(0.2s)+ jitter margin(0.1s ≈ 6 frames@60fps)≤ 0.3s ✓`;release 必須 **idempotent**(#6 Suspended override 可能已 release — EC-M1)。

## Edge Cases

> Rules 已 cover:rollback mid-ceremony / queued rollback / empty-queue entry(Rule 13)/ banner 同 modal 並存(Rule 12)/ force-close idempotent(Rule 8)。以下係 systems-designer formula+rule space sweep(EC-M1–M20),全部 grep-verified against shipped code。

- **EC-M1 — bfcache/suspend 喺 S2 time-stop 中途**:**If** GSM 喺 S2a freeze 內轉 SUSPENDED:#6 Suspended override(`screen_effects.gd:362`)自己 hard-cancel freeze 還原 timescale;#21 行 INV-M1 出口但 **release 必須 idempotent**(ledger 已被 #6 清 → no-op)。Resume 跟 #15 threshold:delta ≤30s(`BFCACHE_CONTINUE_THRESHOLD_MS`)→ **直接重入 S3**(content 已 final,**嚴禁 re-issue `ceremony_freeze`**);>30s → defer,drop 回 pending 計入 catch-up。**Freeze 狀態永不 survive suspend boundary。**
- **EC-M2 — `ceremony_freeze` 被 reject(#6 BOOTING/SUSPENDED 唔 serviceable)**:**If** call 被拒(`screen_effects.gd:344-346` pattern):ceremony **降級照行** — 無 time-stop,用 F1 motion_reduction variant timeline,telemetry `loot_reveal.freeze_rejected`。Reveal 係 Pillar 3 hard guarantee,time-stop 係 garnish。
- **EC-M3 — freeze ledger contention**:**If** call 時已有 active freeze(理論上 safe states 排除 combat,defensive):max-remaining semantics(#6 Story 004 同款)— 延長至 max(remaining, requested);INV-M1 只清自己 entry。
- **EC-M4 — motion_reduction × ladder**:**If** on:D_timestop=0 全 tier(F1 variant);**完全唔 call `request_focal`**(#15 §D camera 改 fade-in vignette — EC-M9 整類消失);shake 0;particle ×0.5;hold / dismiss / queue 行為不變。
- **EC-M5 — unknown rarity_tier string**:**If** `rarity_tier` 唔喺 enum:`RarityTier.get(s, COMMON)` coercion — **同 #17 一模一樣**(`inventory_system.gd:180`),保證 modal 顯示 tier == inventory 入庫 tier。COMMON ceremony、無 breakdown bar、telemetry `loot_reveal.unknown_tier`;coerce 喺 ladder lookup **之前**。
- **EC-M6 — `get_drop()` 回 null(dangling drop_id)**:**If** null:skip 該件 — CRITICAL telemetry `loot_reveal.dangling_drop`,唔開 modal、唔 call `receive_loot`,`INTER_REVEAL_GAP` 後 advance;如係 terminal item → 行 terminal dismiss 出口。Placeholder modal = fabrication,禁止。
- **EC-M7 — GSM force-close 落 catch-up stream / grid**:**If** stream 中:**commit point = beat 起始 frame**(beat 顯示同時 `receive_loot` fire)— 已 commit 唔 re-reveal,in-flight 未到 commit point → 留 pending;其餘留 pending 下次 catch-up。**If** grid 中:grid 係 post-commit summary → 直接 stash-exit,零 data 影響。
- **EC-M8 — 新 drop / micro_ack 嚟喺 catch-up 中途(phase-gated append)**:**If** 新 drop:只可加入**未完**phase — sub-RARE → append stream 尾(受 `MAX_STREAM_BEATS` cap);RARE+ → 插入 ascending 序(受 `K_CEREMONY_MAX` cap);phase 已過 → 留 pending,exit 時 F4 flush。**Phase 唔回頭 = catch-up 保證 terminate。**
- **EC-M9 — 連續兩件 LEGENDARY/EPIC(focal 重入)**:**If** reveal i 嘅 focal 仲 active(0.8s lock + 0.5s `FOCAL_EXIT_DURATION` tween)而 i+1 `request_focal`:#7 Rule 5 silent DROP(`camera_controller.gd:99`)→ 第二件無聲冇 ritual。**Resolution:queue advance gate 喺 `focal_completed`** — `gap = max(INTER_REVEAL_GAP_SEC, focal 剩餘)`;**watchdog 1.5s**(冇 signal → 照 advance、無 focal、telemetry `loot_reveal.focal_watchdog` — 防 #7 bug 鎖死 queue)。
- **EC-M10 — DISCONNECTED state reveal**:**If** 喺 DISCONNECTED(safe state 之一)觸發:**UX 同 connected 完全一樣,零特殊處理** — `receive_loot()` 純 local(grep 證實無 HTTP);backend sync 係 #15/ADR-0003 reconciliation own。唔顯示 sync spinner / badge — Pillar 2 唔輸出 infra 焦慮。
- **EC-M11 — mid-modal safe→safe 轉換(如 DISCONNECTED→IDLE reconnect)**:**If** 發生:**繼續,唔 force-close** — safe set 只喺 entry 檢查;只有轉出 safe set 先觸發 stash-exit。
- **EC-M12 — viewport resize / 手機轉向 mid-modal**:**If** resize:anchor/container 一 frame re-layout;breakdown bar 用新 W_bar 重行 F2(< W_BAR_MIN → stacked text-only variant);timer 全部 time-based 不受影響;particle 唔 replay;focal clamp #7 Story 008 已兜。
- **EC-M13 — boot force-reveal × catch-up threshold 同時觸發**:**If** 同時成立:**單一 entry point** — boot 讀一次 queue depth,exclusive branch(0 件 → 唔入;1–4 → sequential;≥5 → catch-up);force-transition 只決定**幾時**入 LOOT_DROP,flow 由 queue depth 單獨決定。Assert:banner 同 sequential queue 永不同時啟動。
- **EC-M14 — S3 `receive_loot()` 五個 `ReceiveResult` variant**(`equipment_enums.gd:56-62`):
  - **`OK`**:正常。
  - **`FAILED_ROLLBACK`**:**零 user-visible 動作,照常 dismiss** + CRITICAL telemetry `loot_reveal.receive_failed`。理由:(a) 真 failure 時 #15 recovery boot-drain 保證 eventual grant;(b) re-entrant defer path 都 return 呢個值(`inventory_system.gd:161-163`)— 真假分唔到,出 error UI 會對 defer path 假報警。
  - **`QUEUED_SUSPENDED`**:suspend × S3 同 frame race — 當 success(durably parked,resume FIFO drain),行 stash-exit。
  - **`DUPLICATE_NOOP`**:replay — 當 success,telemetry counter,**唔出第二個 micro_ack**。
  - **`CONVERTED_DUPE`**:正常 dismiss,S4 後出 **shard-icon micro_ack**(icon + tint 無 count — toast spec 本身無文字,return 冇 payload)。誠實閉環。
- **EC-M15 — breakdown 數據 corrupt**:**If** ws/rr 出 [0,1]:clamp 先入 F2。**If** `|0.75ws+0.25rr − score| > 0.001` 或 score 同 tier threshold 矛盾:**信 #15 tier,隱藏 bar**,telemetry `loot_reveal.breakdown_mismatch` — bar 同 tier 矛盾比冇 bar 更傷 Pillar 1 claim。
- **EC-M16 — rollback 打中 catch-up in-flight beat**:**If** 目標係當前 stream beat:≤1 frame cancel 該 beat、跳下一 beat、aggregate count −1;已過 commit point → 屬 #17/#15 post-grant rollback path;未 stream → 既有 queued-rollback rule(Rule 11)。
- **EC-M17 — toast visible 時 modal 開**:**If** 有 active toast:即時 fade(0.1s),N_agg fold 返入 deferred aggregate,modal close 後重新 flush。**Count 唔可以蒸發。**
- **EC-M18 — catch-up banner deferred 期間 pending 增長**:**If** 再有 drop:banner count **in-place 更新**,無 re-trigger animation。
- **EC-M19 — tap-through(觸發 drop 嗰下 gameplay tap 漏入 modal)**:F5 已兜 — `t_tap < D_entry` 一律 ignore(D_entry ≥ 150ms ≥ tap-through 窗),一條規則兩用。
- **EC-M20 — S4 exit 中途新 drop 到**:pull model — S4 完成 + GAP 後先 pull,**永不 mid-exit 重入**;terminal 判定喺 gap 結束時重新評估(有新件 → 唔 exit GSM,繼續 reveal)。

## Dependencies

### Upstream(#21 依賴)

| 系統 | Nature | 點解 | Degrade path |
|------|--------|------|--------------|
| **#15 LootDrop** | **Hard** | 內容 source of truth(signals + pull API);冇 #15 無嘢 reveal | 無 — 但 `loot_disabled` 有 banner path |
| **#1 GSM** | **Hard** | `LOOT_DROP` state 係唯一開 modal trigger;Rule 13 safe-state gating | 無 |
| **#5 Particle** | **Hard**(P3:modal 開但無 burst = ritual 不完整,#5 自己都咁標) | S0 burst = FR-2 100ms 承擔者 + tier color pre-attentive 通道 | 無(#5 pool 缺位 = AC fail) |
| **#6 ScreenEffects** | **Hard** | `ceremony_freeze` / shake / saturation 三軌 | EC-M2:freeze reject → 降級照行 |
| **#17 Equipment** | **Hard** | `receive_loot()` @ S3 — 冇佢 loot 唔入庫 | #17 duplicate/suspend variants 兜(EC-M14) |
| **#7 Camera** | Hard(contract)/ graceful-degrade(runtime) | RARE+ focal + `focal_completed` chain | EC-M9 watchdog:1.5s 冇 signal 照 advance |
| **#4 Audio** | **Hard**(P3 唯一 audio peak + colorblind rarity backup channel) | `loot_fanfare_{tier}` @ S0;micro_ack sting 降一 tier | 無(silent reveal = a11y 通道斷) |
| **#33 AttentionBudget** | Soft | exempt handler pattern 引用;#21 唔 query predicate | #33 缺位 tap 照收 |
| **#20 HUD** | Soft(GSM-mediated,零 direct contract) | defer/un-dim 同步靠 GSM state | #20 缺位無影響 |
| **PlatformDetect** | Hard(web)/ no-op(native) | `announce_aria()` a11y gateway(#15 approved 約束) | G-LM-6 未落地 → AC gated |
| **#3 Persistence** | **無依賴** | #21 stateless presentation,零寫入 | — |

### Downstream(依賴 #21)

| 系統 | 期望 |
|------|------|
| **#15** | `modal_dismissed(transition_id)` emit-back(advance queue)— G-LM-4 |
| **#17** | reveal handoff 時序(S3 = #17 GDD 嘅「reveal handoff」語意載體) |
| **#28 Telemetry** | Rule 15 telemetry hooks(skip / time-to-dismiss / stash / catchup-abandon + EC error events) |
| **#26 AvatarRenderer** | 無 API 依賴;P3 約束「avatar effects 永遠係 #21 嘅 supporting cast」(#26 GDD 已載) |
| **#22 / #23** | P-06 rarity 語言共用(pattern 級,非 API) |

### Cross-system gates(G-LM-1..7 — epic 執行)

| Gate | 內容 | 對象 |
|------|------|------|
| **G-LM-1** | ADR-0001 revision:topology 加 `CelebrationVFXLayer`(110, ALWAYS, follow_viewport)+ `ModalLayer`(120, ALWAYS);註明 >100 = BackBufferCopy capture 外(saturation/shake immune);cite L109 HUD knob 先例 | ADR-0001 |
| **G-LM-2** | #5 amendment:LOOT preset pool nodes reparent 入 CelebrationVFXLayer + per-slot `PROCESS_MODE_ALWAYS`(現時 INHERIT + layer 0 — freeze 時 burst 凍結 + 被 saturation 降格雙 bug) | #5 + `particle_system_wrapper.gd` |
| **G-LM-3** | #6 amendment:新 `ceremony_freeze(duration)` API — **自己嘅 `CEREMONY_FREEZE_MAX_SEC=0.4` ceiling,唔受 `MAX_PAUSE_SEC=0.12` 管**;共用 freeze ledger(max-remaining)+ 繼承 Suspended/focus-resume 安全網 | #6 + `screen_effects.gd` |
| **G-LM-4** | #15 reverse-wire story:`modal_dismissed(transition_id)` handler(**以 transition_id dequeue**,唔係 head-pop — catch-up 重排相容);順帶釘實 `loot_fanfare_*` 觸發 caller 歸屬(reveal-onset 時機) | #15 + `loot_drop_system.gd` |
| **G-LM-5** | ADR-0008 insertion:`LootRevealCoordinator` tail append 喺 ZoneSystem 後(#28 keep last);predecessor constraints:`{#15, #1(C6), #33, Camera, ScreenEffects, Particle, Audio, PlatformDetect} ≺ #21` | ADR-0008 + `project.godot` |
| **G-LM-6** | `platform_detect.gd` STUB → 實現 `announce_aria(text)` gateway(boot 時 inject hidden `aria-live` div — live region 必須 first announcement 前存在於 DOM) | platform_detect story |
| **G-LM-7** | `interaction-patterns.md` 更新:P-05 撤 5s auto-dismiss + ladder 數值 sync #15 + OQ-P3 close;P-06 hex 確認(ux-designer 已認領) | design/ux |

### Epic 驗證 flags(G-flag-1..3 — 裁決成立嘅 shipped-code 前提,story-readiness 時 grep)

1. **G-flag-1**:player tap dismiss 唔受 `MIN_REVEAL_WINDOW`(15s)阻 — dismiss 係 completion 唔係 interruption(GSM AC-11b 字面支持,要 code 證實)
2. **G-flag-2**:`_check_pending_loot_reveal()` 嘅 outcome 機制(transition 入 LOOT_DROP 定 emit signal)— #21 binding 對返 shipped 機制
3. **G-flag-3**:GSM LOOT_DROP exit path(terminal dismiss 點觸發 transition)+ **intra-queue 唔 exit 嘅語意確認**(AC-11b 寫於單 drop 情境;multi-item「tap dismiss → exit」由 terminal dismiss 承擔 — 如 GSM 語意唔容許,escalate CD)

### Bidirectional sync flags(寫 #21 後回填上游)

- **#15 GDD erratum note(non-blocking)**:`#21.cancel_reveal()` call 方向已被 shipped `loot_rollback` signal 取代;Visual Spec Table hex 同 P-06/art bible 衝突(見 Visual/Audio section);micro_ack「0.15s toast」釐清為 entry beat
- **#5 GDD**:Section C #21 interaction contract + EC-18 嘅 [PROVISIONAL] 標記可 actualize(#21 答案:無 re-peek pattern,dedup by design;tier→preset mapping 確認 white/green/blue→LOOT_BURST、purple/orange→LOOT_RARE_BURST);Q-V4 部分閉 | **#7 GDD**:downstream #21 row actualize(API 零 change;watchdog 係 #21-side)
- **#20 GDD**:Q-OQ6 可 close(exit 序 + banner stack priority + 唔加 direct notify — 本 GDD Rule 12 / Interactions #20 row)
- **#4 GDD**:fanfare trigger 歸屬釘實後 catalog source 行 sync(G-LM-4 連帶)
- **systems-index**:#21 row 更新 + 依賴實況(5, 15, 17 → 加 1/4/6/7/33 context)

## Tuning Knobs

> **唔係 #21 own 嘅(cite only,唔重印)**:hold / time-stop ladder(#15)、`ATTENTION_CEILING_MS=1200`(#15 Pillar 2)、`C_stream=0.15`(#15 Formula 6)、`CATCH_UP_THRESHOLD=5`(#15)、`ceremony_cap=6`(#15 Rule 6 — 注意同 `K_CEREMONY_MAX` 唔同層:前者係 per-workout emit cap,後者係 catch-up reveal cap)、`CEREMONY_FREEZE_MAX_SEC=0.4`(#6 amendment own,G-LM-3)、`MIN_REVEAL_WINDOW_SECONDS=15`(#1 GSM)。

### #21-owned knobs

| Knob | Default | Safe range | 效果 / 出界後果 |
|------|---------|-----------|----------------|
| `D_ENTRY_MS`(per-tier:C/U/R/E/L) | 150/200/300/380/450 | 每 tier 受 **C1 約束**:`D_entry ≤ D_timestop + D_hold` | 太低:entry 似 pop 冇 anticipation;太高:違 C1 → CI assert fail(F1) |
| `SNAP_SEC` | 0.1 | 0.05–0.2 | fast-complete tween snap 時長。太低:似 glitch;太高:skip 唔似 skip |
| `DISMISS_DEBOUNCE_SEC` | 0.25 | 0.15–0.4 | two-stage tap lockout。太低:mash 盲拆(terminal frame 冇人見);太高:dismiss 似 input lag |
| `INTER_REVEAL_GAP_SEC` | 0.3 | 0.2–0.8 | queue 件距。**互動**:EC-M9 實際 gap = `max(呢個, focal 剩餘)` — 調低唔會快過 focal |
| `STASH_COLLAPSE_SEC` | 0.2 | 0.1–0.25 | stash-exit 收埋 anim。上限受 F6 budget(總 ≤0.3s)綁 |
| `EXIT_ANIM_SEC` | 0.2 | 0.1–0.2 | S4 exit。太高:terminal dismiss 拖慢 GSM transition(#20 un-dim 等緊) |
| `TOAST_ENTRY_SEC` | 0.15 | locked(對齊 stream cadence) | micro_ack entrance beat |
| `TOAST_VISIBLE_SEC` | 1.2 | 0.8–2.0 | toast plateau 可見時長(唔包 entry/fade)。太低:subliminal 違 Pillar 1 acknowledge;太高:常駐 UI 違 Pillar 2 |
| `TOAST_FADE_SEC` | 0.15 | 0.1–0.3 | toast fade-out 時長(EC-M17 interrupt fade 用 0.1s 獨立值) |
| `MERGE_MIN_REMAIN_SEC` | 0.6 | 0.3–1.0 | toast merge 最少剩餘 |
| `TOAST_MAX_LIFETIME_SEC` | 3.0 | 2.0–5.0 | 防 ack stream 釘死 toast |
| `FLUSH_DELAY_SEC` | 0.1 | 0–0.3 | modal close 後 deferred-ack flush 延遲 |
| `MAX_STREAM_BEATS` | 40 | 20–80 | catch-up stream cap。**互動**:同 `K_CEREMONY_MAX` 一齊 enforce F3 provable bound(default 組合 = 14.3s) |
| `K_CEREMONY_MAX` | 5 | 3–8 | catch-up full ceremony cap。太低:RARE+ 折入 grid 冇 ceremony(P3 損);太高:catch-up 變 chore(P2 損) |
| `W_BAR_MIN` | 120 | 88–160 | breakdown bar 最少寬。**88px = 8px delta 臨界**(F2)— 低過 88 floor clause 開始觸發 |
| `BREAKDOWN_MIN_DELTA_PX` | 8 | locked(UX) | workout 段最少凸出(corrupt-input 防線) |
| `FOCAL_WATCHDOG_SEC` | 1.5 | 1.0–2.5 | EC-M9 watchdog。太低:正常 focal 被誤殺;太高:#7 bug 時 queue 卡耐 |

### Knob 互動 matrix(重點)

- `D_ENTRY_MS` ↑ 任一 tier 超 C1 → F1 CI assert fail(**設計上唔俾 runtime clamp**)
- `MAX_STREAM_BEATS` × `K_CEREMONY_MAX` × `INTER_REVEAL_GAP_SEC` 三個共同決定 F3 bound — 改任何一個要重行 F3 worst-case
- `TOAST_VISIBLE_SEC` < `MERGE_MIN_REMAIN_SEC` 係 invalid 組合(merge 反而延長壽命)— data-load assert
- `EXIT_ANIM_SEC` + `INTER_REVEAL_GAP_SEC` 决定 intra-queue 件距 perceived 節奏;兩個都調高會令 3 件 queue 嘅總 perceived time 超 catch-up threshold 嘅體感 — 留意 F3 worked example 重算

## Visual/Audio Requirements

> art-director 諮詢(2026-06-06 full review,grep-verified against art bible)。Per-tier ceremony 數值(hold/time-stop/camera/shake/duck)#15 own;本節係 #21 嘅 presentation 增量。

### A. Rarity hex 裁決(cross-doc conflict 收線)

**Canonical = art bible §4.B / P-06 套**:COMMON `#FFFFFF` / UNCOMMON `#6FB87A` / RARE `#4D8FD6` / EPIC `#9B5FCC` / LEGENDARY `#FF8C42`。證據:art bible §4.B L265-268 + L276(「Legendary 用橙 #FF8C42 而唔係紅」)+ accessibility-requirements + art-style-mockup 四源一致;`#FF8C42` 係刻意校過嘅 protanopia-safe 橙(vs damage red `#D94B3E` 有專門 risk-pair 分析);`#6FB87A` 同 heal green 係 deliberate shared semantic token。#15 Visual Spec Table(L1031-1034)嗰套(`#4CAF50`/`#2196F3`/`#9C27B0`/`#FF9800`)係 Material Design 樣板色孤例 → **#15 erratum(doc-only;grep 證實 src/ + assets/ 兩套 hex 零出現,無 code impact)**。通則:**色彩語言 = art bible own;timing 數值 = system GDD own** — P-05 嘅 hold/slowmo drift 反方向同理(#15 wins,G-LM-7)。

### B. Modal 視覺(dirty frame × Flashbulb)

- **Frame = 相框,唔係 UI box**:dirty pixel frame(art bible §7.A「破爛布旗/鐵鏽金屬條」)reframe 做「沖晒出嚟嗰張相嘅相框」;irregular silhouette(chip/scratch/fray),**禁止 clean rectangle**。
- **Per-tier frame ornament escalation**(P-06 ornament density 具體化,satellite count 對齊 P-06):COMMON bare → UNCOMMON 四角 rivet → RARE 頂嵌 1 satellite orb + edge chip 提亮 → EPIC 2 satellites + 薄 etching 環 → LEGENDARY 光柱 backing(由下而上)+ frame 邊緣 emit particle + full vignette。
- **內容 hierarchy(單一焦點,§3.D)**:item icon 128×128 render 係唯一 hero;name H1(m6x11 11px)、rarity label(7px + orb)、breakdown bar 全部 subordinate。**Breakdown bar 用 `ui_amber_primary #F2A93B`(workout 段,progress semantic)vs `ui_ink_hi #4A5260`(rng 段)— 唔准用 rarity 色**(防 bar 同 tier identity 撞 channel)。
- **S4「快門定格」exit 視覺語言**:tap → ① 1-2 frame `#FFFFFF` flash 限 modal 局部(pure white reserved for loot,§4.D 合法用途)→ ② 內容凍結成「flat snapshot」1 frame → ③ snapshot shrink + fade ≤200ms 飛向 stash anchor。Ease-in,**無 bounce**(§7.D Snap+Settle)。
- Bg `ui_ink_bg #1A1D24` 92% opacity + 8% modal-local blur;16px grid 對齊(§7.A);S1 elastic-light overshoot ~1.03×(非 bounce)。

### C. S0 burst + photosensitivity 安全(WCAG 2.3.1,web game)

- **S0 burst = localized radial**(loot 原點,CelebrationVFXLayer),**frame 0 即帶 tier color**;「HDR 感」用 additive blend(§4.E 實作 note),唔係真 saturation >1.0。
- 任何 flash event ≤3 次/秒;每 reveal 只准一個 transient(無 strobe loop);flash 面積 ≤25% viewport(burst 同 S4 快門 flash 都係局部);世界 −60% 係 saturation 變化非 luminance flash(安全),**禁止**同步全屏 luminance swing;LEGENDARY 光柱 ≥0.3s rise(漸現非瞬閃);reduced motion 時 flash 收到單 1 frame。

### D. Contact-sheet grid(catch-up 收尾)

- 「菲林相辦」metaphor:每 cell = mini snapshot(icon + 簡化 dirty frame 9-slice,corner accent 色 + **rarity text label 相鄰** — P-06 list-display rule);**hero cell**:最高 tier 佔 2×2(單一焦點);header strip film-edge 風 session/date stamp — 成個 grid 係一張「今日戰利品明信片」(Pillar 5)。
- **RARE+ identity 保證(C-1)**:ceremony-overflow RARE+ 件必須有獨立 cell(icon + label);「+N」collapse 只准 sub-RARE / stream 溢出件。
- 入場:**禁止 per-cell stagger** — 一次過 left-to-right「exposure sweep」≤0.4s(flash 掃過曬相,Flashbulb 一致)。
- **Grid 模式零 celebration particle**(particle = 明度尺;ceremony 已喺 per-item reveal 用咗)。

### E. micro_ack toast + stash-exit 視覺

- **Toast**:icon 16×16 solid silhouette + tier tint + 1px hard shadow;**frameless 無 backplate**(§7.A);entry ease-out cubic;hold 固定唔隨 tier 升級(toast 唔可以變 attention escalator);event-driven only 無 idle motion;**零 particle**。Tier tint 係 enhancement-only — rarity 嘅 canonical multi-channel 傳達發生喺 modal/grid(deliberate,§4.B「color 唔係 primary signaling」過關)。
- **Stash-exit**:icon scale-down ease-in 飛向**固定 stash anchor**(screen corner 恆定位 = spatial memory;位置同 #20 layout zones + #22/#23 inventory 入口協調);tier 色短 trail 壓縮 ≤0.3s(收納唔係慶祝 — 唔用 P-06 celebration trail 時長);無 bounce。

### F. Art bible principles 應用

| Principle | #21 應用 |
|---|---|
| Silhouette First | item icon 8×8 squint test;frame irregular silhouette;每屏單一焦點(modal=item,grid=hero cell) |
| Particle Budget Rule | 3× combat 係 loot ceiling(LEGENDARY LOOT_RARE_BURST 3×,ADR-0001 cap + mobile ×0.5);toast/grid/stash 一律低/零 particle 保 ceremony 對比 |
| Layer Discipline | modal 喺 ModalLayer >100 全飽和 + shake/saturation immune;burst 喺 CelebrationVFXLayer;world −60% 行 #6 shader uniform path |

**#21 特有 constraints**:pure white `#FFFFFF` 只准 loot burst / S0 / S4 flash(§4.D);rarity ladder 永不用紅(§4.B);S4/grid sweep 都計入 perceived ceremony 預算;全 UI 16px grid + pixel font(m6x11/m5x7);desaturated screenshot QA protocol(§4.C — loot modal 係 critical scene)。

### G. Audio 增量(→ audio-director / #4 bank 協調;ceremony 本體 #15+#4 已 cover,唔重複)

| Cue | Spec 方向 | Note |
|---|---|---|
| `sfx_loot_shutter_dismiss` | 快門 click ≤0.3s,**單一共用唔分 tier**(rarity 已由 sting 傳達) | S4 核心,Flashbulb fantasy 錨點 |
| `sfx_loot_contactsheet_enter` | exposure sweep whoosh ≤0.6s | 配 grid 入場 |
| Grid hero-cell sting | **reuse** #15 最高 tier sting,**全 grid 只播 1 次**(max tier),禁止 N 件疊 N sting | mixing rule forward constraint |
| `sfx_loot_stash_put` | 軟 foley ≤0.2s 或 silent | 低優先 |
| Toast tick | ≤0.15s;safe-state-gated 下只喺 natural pause 出現,跟 #4 silent-mode soft-gate | — |

**CI note**:#15 嘅 `check_loot_audio_bank.gd` 只 enumerate per-tier sting — 以上新 entry 唔喺 lint scope;#21 epic 要決定擴 lint 定 manual checklist(forward #4)。

### H. Asset Spec Flag(#21 增量;#15 嘅 5×atlas / 5×sting / 1×shader / 5×badge 唔重複)

| Asset | 用途 | Naming |
|---|---|---|
| modal dirty frame 9-slice base ×1 | B | `ui_frame_loot_base_128.png` |
| per-tier ornament overlay ×4(COMMON bare) | B | `ui_frame_ornament_[tier]_small.png` |
| grid cell mini-frame 9-slice ×1 | D | `ui_cell_contactsheet_default_64.png` |
| film-edge header strip ×1 | D | `ui_strip_filmedge_header_large.png` |

**刻意零新增(reuse 明文)**:S4 快門 flash = shader/ColorRect;stash trail = reuse #15 per-tier particle atlas;toast = frameless 無 backplate。淨增 7 個細 sprite。

📌 **Asset Spec** — Visual/Audio requirements 已定義。Art bible 已 approved,run `/asset-spec system:loot-drop-modal` 產生 per-asset visual descriptions、dimensions、generation prompts。

## UI Requirements

### A. Surfaces

1. **Full reveal modal**(primary)— GSM LOOT_DROP 唯一觸發;one-modal-at-a-time。
2. **micro_ack / deferred-ack toast** — safe-state-gated(F4 flush gate),mid-workout 永不顯示(#15 L1081 對齊)。
3. **Banner stack** — top edge full-width、safe-area 下方;同 #20 banner 共用單一 stack region,同屏最多 1 條,priority `private_mode` > audio silent-mode;絕不侵 #20 L1 anchor zone;`role=status` announce 一次。
4. **Catch-up banner + contact-sheet grid**(Rule 10)。

### B. Content slots(modal — #15 forward contract 兌現,7 項 enumeration)

| # | Slot | Spec |
|---|------|------|
| 1 | Rarity badge | P-06 三重編碼(色 + 形 + text label);貼喺 icon 上方同一 foveal cluster(~2° 視角一個 fixation 食晒 rarity+identity,慳一次 saccade) |
| 2 | Item icon | 64×64 @2× render(128×128),唯一 hero |
| 3 | Item name | H1 m6x11 11px,`ui_text_primary` |
| 4 | Source attribution | 三 variant:「來自 boss 擊殺」/「來自健身完成」/「來自 mini-boss 擊殺」+ provenance 數字行先(「Stamped by 180kg × 5」) |
| 5 | Breakdown bar(RARE+ only) | F2 幾何;`ui_amber_primary` vs `ui_ink_hi`;**段上 text % label 必須**(「汗水 X% / 運氣 Y%」— claim 唔依賴 pixel discrimination);COMMON/UNCOMMON 唔顯示 |
| 6 | Dismiss CTA | label「tap 收藏」;CTA visual ≥48dp 但 **tap surface = 全屏 scrim**(Fitts + 汗手) |
| 7 | ScreenReader announcement | `"[Rarity] loot: [Item Name],來自 [source]. [Workout X%, RNG Y%]"`(RARE+ 先讀 breakdown);S3 fire 一次,`aria-live=assertive`,timing 唔受 motion_reduction 影響 |

(P-05 嘅 stat-delta ticker slot **MVP 唔做** — 依賴 #17 equip-result payload 未有 API;見 Open Questions OQ-1 + G-LM-7 P-05 更新。)

### C. Glance hierarchy(疲勞場景優先序)

**Rarity → Item icon → Item name → Source → Breakdown** — 攰人第一個問題係「使唔使理?」:rarity 行三條時間線(burst 色 ~100ms → frame edge tint → badge),未讀字已知值唔值得睇真;icon 先過 name(picture superiority — 疲勞下讀 11px bitmap text 成本高);**單欄、單一 top→bottom 閱讀軸**,冇 side-by-side;attribution 係 Pillar 1 meaning layer 但係第二 fixation 嘅嘢。

### D. Input

- Two-stage tap(Rule 5);S0/S1/S4 一律 ignore tap(兜 tap-through — F5);#33 exempt handler;4.6 dual-focus 注意 — tap 直接食 `gui_input`/`pressed`,**唔依賴 focus state**(`grab_focus()` 4.6 只影響 keyboard)。
- Catch-up「稍後再拆」affordance:角落、≥48dp、常駐(Pillar 2 never-trap)。

### E. Accessibility

- **motion_reduction matrix**(#15 §D + #21 增量):saturation drop / time-stop / shake 全 off;hold 保留;particle ×0.5;camera focal → fade-in vignette(`request_focal` 零 call — EC-M4);**S1 entry 改 150ms fade(無 scale 無 overshoot)— #15 §D 冇 cover entry,#21 增量**;two-stage tap 行為不變;flash 收單 1 frame。
- Color NOT sole indicator:tier = 色 + badge shape + hold 時長 + sting character(skip 唔 cut sting — Rule 5);toast tint enhancement-only。
- ARIA live region 經 `platform_detect.announce_aria()`(G-LM-6);region boot 時 inject(first announcement 前必須存在於 DOM);banner `role=status` polite,reveal announcement assertive。
- 全部 user-facing string 行 `tr()`(i18n);micro-copy tone 跟 Player Fantasy 指引(present tense、零運氣動詞、數字行先)。
- Photosensitivity 規則見 Visual/Audio §C。

📌 **UX Flag — Loot Drop Modal**:本系統有完整 UI requirements。Phase 4(Pre-Production)run `/ux-design loot-drop-modal` 產生 per-screen UX spec **先寫 epics**;stories 引用 `design/ux/loot-drop-modal.md`,唔直接 cite GDD。P-05/P-06 更新(G-LM-7)由 ux-designer 認領。

## Acceptance Criteria

> **Test evidence 分流**(#20 先例):Logic/Integration = **BLOCKING**(headless GUT);Visual/Feel/UI = **ADVISORY**(screenshot/playtest + lead sign-off — 唔 pre-mergeable,唔做 merge gate)。依賴未落地 gate 嘅 AC 標 **[gated G-x]**(story-readiness 時 grep gate 狀態解封;全部 gated AC 有 #21-side 可先行斷言或 fake seam)。Evidence:unit = `tests/unit/loot_reveal/`、integration = `tests/integration/loot_reveal/`、manual = `production/qa/evidence/loot-drop-modal/`。
> **FR-2 100ms 拆法(明文,防 epic 誤寫 BLOCKING perf test)**:headless 量唔到 wall-clock → 拆做 structural same-frame call-order(AC-8 BLOCKING)+ 真 browser frame capture(AC-9 ADVISORY)。
> **EC-M3 ownership note**:freeze ledger max-remaining 語意由 G-LM-3 #6 amendment own — 主測試落 #6 story,AC-54 只係 #21-side integration smoke(防雙邊 own 同一斷言 drift)。

### A. Invariants

- **AC-1**(INV-M1,×4 parametrized):GIVEN 任一 tier reveal 喺 S2a freeze active(fake #6 seam),WHEN 行 4 個 cancel path 之一(fast-complete / `loot_rollback` / stash-exit / EC-M1 Suspended),THEN freeze entry release **exactly once** 且 4 path 經同一 release 出口(spy 單一 call-site)。*Logic · BLOCKING*
- **AC-2**(INV-M1 idempotent):GIVEN ledger entry 已被 #6 Suspended override 清走,WHEN cancel path 再 release,THEN no-op 無 error 無 double-decrement。*Logic · BLOCKING*
- **AC-3**(INV-M2 邊界 sweep):GIVEN (ws,rr) ∈ [0,1]² 令 score ≥ 0.55(必含 score=0.55/rr=1.0 worst case),WHEN F2 計 px,THEN `px_w > px_r` 嚴格成立且 naive delta ≥8px @ W_bar ≥120。*Logic · BLOCKING*

### B. Core Rules

- **AC-4**(Rule 1):coordinator `_ready` 後持有 ModalLayer + CelebrationVFXLayer 且係唯一 instantiator;layer 數值 == ADR-0001 pinned。*Logic · BLOCKING(layer 數值斷言 [gated G-LM-1])*
- **AC-5**(Rule 2 唯一 trigger):GIVEN fake GSM `state_changed`→LOOT_DROP 且 queue 非空 THEN modal 開;其他 state 轉換或單獨 `loot_dropped`(GSM 非 LOOT_DROP)THEN 唔開。*Logic · BLOCKING*
- **AC-6**(Rule 2 boot):GIVEN boot 時 GSM 已喺 LOOT_DROP(force-reveal),WHEN `connect_for_initial_state` 接線,THEN 即收 sentinel 並開 modal。*Logic · BLOCKING*
- **AC-7**(doorbell no-op):GIVEN modal active,WHEN 新 `loot_dropped`,THEN 零 modal 動作(無第二 modal / FSM 重入)。*Logic · BLOCKING*
- **AC-8**(FR-2 structural):GIVEN reveal 開始,THEN #5 `play()` 喺 reveal-start **同一 call stack 同步**發出(無 await/timer 先行)且 preset per tier 正確(C/U/R→LOOT_BURST;E/L→LOOT_RARE_BURST)。*Logic · BLOCKING*
- **AC-9**(FR-2 wall-clock):真 web build frame capture,trigger→burst onset ≤100ms(6 frames@60fps)。*Visual/perf · manual · ADVISORY*
- **AC-10**(S1 content all-final):scale-in 完成 frame,全部 content slot(UI Requirements §B 7 項)== final fixture 且零 active content tween。*Logic · BLOCKING*
- **AC-11**(per-stage input,×5):tap 喺 S0(t<D_entry)/S1/S4 一律 ignore;S2 → fast-complete;S3 → dismiss(S0/S1 ignore 兼兜 tap-through EC-M19)。*Logic · BLOCKING*
- **AC-12**(Rule 4 調用序):LEGENDARY reveal(fake spies),調用序 = burst(frame 0)→ `request_focal`(GSM==LOOT_DROP 後)→ `ceremony_freeze`(duration 由 #15 ladder config 讀,非 hardcode)→ shake/saturation → fanfare。*Logic · BLOCKING(freeze API shape [gated G-LM-3])*
- **AC-13**(focal RARE+ only):COMMON/UNCOMMON 零 `request_focal`;RARE+ call 一次 `(item_world_pos, 0.6, 1.4)`。*Logic · BLOCKING*
- **AC-14**(無 auto-dismiss):S3 無 input,fake clock 推 60s,modal 仍 open、無 scheduled dismiss timer。*Logic · BLOCKING*
- **AC-15**(debounce):S2 tap fast-complete @t;第二 tap @t+0.2s(<`DISMISS_DEBOUNCE_SEC`,讀 config)ignore;第三 tap @t+0.3s dismiss。*Logic · BLOCKING*
- **AC-16**(fast-complete 副作用):S2 tap → content snap over `SNAP_SEC`、freeze 即 frame release、particle fast-decay call(非 hard-cut)、audio sting **零** stop/cut call(negative spy)。*Logic · BLOCKING*
- **AC-17**(#33 exempt):GIVEN `is_input_permitted()==false`,WHEN dismiss tap,THEN tap 照被消費且 #21 全程零 call 該 predicate(negative spy)。*Logic · BLOCKING*
- **AC-18**(intra-queue):queue 2 件,第 1 件 dismiss → `modal_dismissed(transition_id)` 正確、GSM exit 通知**零 call**、gap 後第 2 件 ENTRY。*Logic · BLOCKING*
- **AC-19**(terminal 順序):queue 剩 1 件 dismiss → S4 anim **完成先** call GSM 通知,anim 中途零 GSM call。*Logic · BLOCKING([gated G-flag-3] 真 exit 機制)*
- **AC-20**(receive_loot @ S3 exactly-once):S3 到達(未 tap)→ call exactly once;tap 後無第二次;永不 tap + stash-exit → 已 banked。*Logic · BLOCKING*
- **AC-21**(唯一 caller):CI grep `src/`,`receive_loot(` caller 只有 #21 coordinator 一個 call site。*Static/CI · BLOCKING*
- **AC-22**(stash-exit flow):modal S3 open,GSM 外部 force-transition → stash anim ≤0.3s(無 input)→ emit `modal_dismissed` → deferred-ack +1 → **下次 safe-state entry**(F4 flush gate)出 aggregated「+N」toast。*Logic · BLOCKING*
- **AC-23**(S4 idempotent):S4 行緊時 force-close 落中途 → `modal_dismissed` emit count == 1。*Logic · BLOCKING*
- **AC-24**(toast 結構):`loot_micro_ack` 到、modal 唔 active 且 GSM 喺 safe state → toast anchor 喺 edge container(parent assert)、icon + tier tint、**零 text node**、entry == `TOAST_ENTRY_SEC`、無 input handler。*Logic · BLOCKING*
- **AC-25**(defer + aggregate):modal active 時 3 個 `loot_micro_ack` → 零 toast 即出;close 後 `FLUSH_DELAY`(且 safe state)出**單一**「×3」toast,tint == 最高 tier。*Logic · BLOCKING*
- **AC-26**(threshold boundary):pending==4 → sequential;pending==5(==`CATCH_UP_THRESHOLD`,讀 #15 const)→ CATCHUP_PROMPT。*Logic · BLOCKING*
- **AC-27**(banner defer 零動作):CATCHUP_PROMPT defer → HIDDEN + 通知 GSM、pending 不變、`receive_loot` 零 call。*Logic · BLOCKING*
- **AC-28**(catch-up 結構):F3 fixture(14C+10U+4R+1E+1L)reveal-all → sub-RARE 24 件 `C_stream` cadence 零 tap stream(#5 aggregated,call 數 << 24);RARE+ 揀 tier-降序 top-K=5(L+E+3R)full ceremony(reveal 順序 ascending);**第 4 件 R 喺 grid 有 own cell(node assert:icon + rarity label;「+N」badge 唔適用於 RARE+ — C-1)**;overflow 件喺 grid entry batch commit(C-2)。*Logic · BLOCKING*
- **AC-29**(mid-exit 零懲罰):catch-up 行到第 k 件完,tap「稍後再拆」→ 已 reveal k 件各自已 emit `modal_dismissed` + banked;剩 N−k 件原封 pending,banner 下次以 N−k 重現。*Logic · BLOCKING(#15 dequeue side [gated G-LM-4])*
- **AC-30**(rollback mid-reveal,×4):S0–S3 任一段收 `loot_rollback`(該 drop_id)→ ≤1 frame cancel、timescale restored、無 terminal frame、無 toast、`modal_dismissed` count == 0。*Logic · BLOCKING*
- **AC-31**(queued rollback):rollback 目標係未 reveal queued drop → #21 零動作。*Logic · BLOCKING*
- **AC-32**(content source = committed store):signal payload 同 `get_drop()` 餵唔同值 → 顯示 == `get_drop()`;fill 時 null → EC-M6 skip,**永不** render placeholder。*Logic · BLOCKING*
- **AC-33**(banner deferral + priority):modal active 時 `loot_disabled` → banner dismiss 後先出;同時收 rollback → rollback 先;stack 同屏最多 1 條且 `private_mode` > audio silent-mode。*Logic · BLOCKING*
- **AC-34**(empty-queue entry):GSM→LOOT_DROP 但 queue 空 → 即 emit terminal dismiss、modal 唔開、GSM 唔 stuck。*Logic · BLOCKING*
- **AC-35**(Rule 14 mapping):① mid-ceremony 唔可 dismiss → AC-11;② 無 re-peek → AC-31/71;③ 周邊 lock 零依賴 → AC-17;④ sting 唔可 skip → AC-16。*(mapping,無獨立 evidence)*
- **AC-36**(telemetry hooks):4 情境各觸發一次 → `ceremony_skip_attempted(tier)` / `time_to_dismiss_ms` / `stash_exit_count` / `catchup_abandoned(remaining)` 各 emit 一次正確 payload(local signal;#28 sink 唔需存在)。*Logic · BLOCKING*
- **AC-37**(FSM 完整性):table-driven 行 7-state 每條 edge → transition 按表;表外 → assert/no-op 唔靜默跳。*Logic · BLOCKING*

### C. Formulas

- **AC-38**(F1 table + equality 可達):default config,T_block == 200/350/650/950/**1200** 全 pass;ceiling assert 係 `≤`(LEGENDARY equality 必須 pass)。*Logic · BLOCKING*
- **AC-39**(F1 C1 data-load assert):注入違 C1 config(LEGENDARY D_entry=1300)→ validation **fail** 且**冇** runtime clamp。*Logic · BLOCKING*
- **AC-40**(F1 非 additive):LEGENDARY fake clock,S1 同 S2a 喺 T=0 同時起跑,實測 T_block == 1200ms 非 1650ms。*Logic · BLOCKING*
- **AC-41**(F1 motion_reduction):on → T_block == 200/350/500/650/800、D_timestop==0、單調性保留。*Logic · BLOCKING*
- **AC-42**(F2 identities):(0.55, 0.40, 1.0, W=160) → px 87/73、pct 55/45、sum==100;legal sweep:`px_w+px_r==W_bar`、pct∈[1,99]、sum==100 恆成立。*Logic · BLOCKING*
- **AC-43**(F2 floor unreachable):legal grid(RARE+、W≥120)naive delta ≥8px 恆成立;corrupt input 先觸發 floor clause。*Logic · BLOCKING*
- **AC-44**(F2 display gate):W_bar < `W_BAR_MIN` → stacked text-only、% label 雙邊、零 info loss。*Logic · BLOCKING*
- **AC-45**(bar RARE+ only):COMMON/UNCOMMON → breakdown bar node 不可見/不存在。*Logic · BLOCKING*
- **AC-46**(F3 bound + caps):worst-case(>40 sub-RARE、>5 RARE+)→ T_machine ≤14.3s;120 sub-RARE → 40 beats(6.0s)+ 80 折 grid。*Logic · BLOCKING*
- **AC-47**(F3 regression):30 件 fixture → T_machine == **10.0s**(修正後 example:L+E+3R ceremony、1R 折 grid)。*Logic · BLOCKING*
- **AC-48**(F4 display):N_agg == 1/2/150 → icon+tint 無字 /「×2」/「×99+」,tint == 最高 tier。*Logic · BLOCKING*
- **AC-49**(F4 merge + 守恆):toast 剩 0.3s 新 ack → remaining := 0.6(`MERGE_MIN_REMAIN`)、N_agg+1;連續 stream → 壽命 ≤`TOAST_MAX_LIFETIME` 到 cap fade + carryover,**total count 守恆**。*Logic · BLOCKING*
- **AC-50**(F5):tap @t<D_entry ignore;@t∈[D_entry,T_block) → S3 @t+`SNAP_SEC`(tween 非 0-frame)、最早 dismiss @t+SNAP+debounce。*Logic · BLOCKING*
- **AC-51**(F6):stash-exit → freeze release 同 frame + collapse ≤0.2s + 總 ≤0.3s,release idempotent。*Logic · BLOCKING*

### D. Edge Cases

- **AC-52**(EC-M1):S2a freeze 中 SUSPENDED(fake #6 已自清)→ resume ≤30s 直接重入 S3、`ceremony_freeze` spy count **不增**、release no-op;>30s → defer 回 pending 計入 catch-up。*Logic · BLOCKING*
- **AC-53**(EC-M2):fake #6 reject freeze → ceremony 照行 motion_reduction variant、完整到 S3、telemetry `freeze_rejected`。*Logic · BLOCKING*
- **AC-54**(EC-M3 smoke):已有 active freeze 時 `ceremony_freeze` → max-remaining、release 只清自己 entry。*Integration smoke · BLOCKING [gated G-LM-3];主測落 #6 story*
- **AC-55**(EC-M4 matrix):motion_reduction on → `request_focal` **零 call 全 tier**、shake 0、particle ×0.5、hold/dismiss/queue 同 off 一致。*Logic · BLOCKING*
- **AC-56**(EC-M5 coercion 同源):`rarity_tier="MYTHIC"` → `RarityTier.get(s, COMMON)` 喺 ladder lookup 前、COMMON ceremony、無 bar、telemetry;cross-check 同 fixture 餵 real #17 → 入庫 tier == 顯示 tier。*Logic + Integration · BLOCKING*
- **AC-57**(EC-M6):`get_drop()` null → skip(無 modal / receive_loot)、CRITICAL telemetry、gap 後 advance;terminal 件 → terminal dismiss 出口。*Logic · BLOCKING*
- **AC-58**(EC-M7 commit point):stream beat in-flight 未到 commit point 時 force-close → 留 pending;已 commit 唔 re-reveal;grid 中 → stash-exit 零 data 影響。*Logic · BLOCKING*
- **AC-59**(EC-M8 phase-gate + termination):stream 中新 drop → append 規則按 phase;持續注入 → catch-up 仍 terminate(收斂 assert)。*Logic · BLOCKING*
- **AC-60**(EC-M9 focal gate + watchdog):連續 2 件 EPIC+ → advance 等 `focal_completed`、gap == max(gap, focal 剩餘);fake #7 永不 emit → `FOCAL_WATCHDOG_SEC` 後照 advance、無 focal、telemetry。*Logic · BLOCKING*
- **AC-61**(EC-M10):DISCONNECTED reveal 同 connected 完全一致:無 spinner/sync badge node、receive_loot 照 call。*Logic · BLOCKING*
- **AC-62**(EC-M11):safe→safe(DISCONNECTED→IDLE)繼續無 stash-exit;→ 非 safe 先觸發。*Logic · BLOCKING*
- **AC-63**(EC-M12):resize 令 W_bar 100 → 一 frame re-layout、stacked variant、timer 唔 reset、particle 唔 replay。*Logic · BLOCKING*
- **AC-64**(EC-M13 exclusive):boot force-reveal + depth 0/3/7 → 唔入 / sequential / catch-up;assert banner 同 sequential **永不同時**。*Logic · BLOCKING*
- **AC-65**(EC-M14 ×5):S3 `receive_loot` 回 OK / FAILED_ROLLBACK / QUEUED_SUSPENDED / DUPLICATE_NOOP / CONVERTED_DUPE → 正常 / **零 user-visible delta**+照 dismiss+CRITICAL telemetry / 當 success+stash-exit / success+無第二 micro_ack / 正常+S4 後 shard-icon micro_ack。*Integration(real #17 enum)· BLOCKING*
- **AC-66**(EC-M15):ws=1.4 → clamp 先入 F2;identity 違反 >0.001 或 score-tier 矛盾 → 信 #15 tier、隱藏 bar、telemetry。*Logic · BLOCKING*
- **AC-67**(EC-M16):rollback == 當前 stream beat(未 commit)→ ≤1 frame cancel、跳下一 beat、aggregate −1;已 commit → 零動作。*Logic · BLOCKING*
- **AC-68**(EC-M17 守恆):active toast N=2 時 modal 開 → 0.1s fade、count fold 入 deferred、close 後 flush 包齊 — **總數守恆 assert**。*Logic · BLOCKING*
- **AC-69**(EC-M18):banner deferred N=5 時新 drop → count→6 in-place、零新 entrance tween。*Logic · BLOCKING*
- **AC-70**(EC-M20):terminal S4 行緊時新 drop → 永不 mid-exit 重入;gap 後重評 terminal → 有新件唔 exit GSM 繼續。*Logic · BLOCKING*

### E. Cross-system Integration(非 isolation)

- **AC-71**(#15 round-trip):real #15+#21,`loot_dropped`→reveal→dismiss→`modal_dismissed(transition_id)` → #15 以 transition_id dequeue(非 head-pop)、下次 query 唔見該件。*Integration · BLOCKING [gated G-LM-4]*
- **AC-72**(#17 full handoff):real #17,full reveal → S3 → inventory 含 item、auto-equip 唔被阻;catch-up N 件 → 逐件 call 但 #17 aggregate/push/persist **各一次**(batch debounce)。*Integration · BLOCKING(即時可執行)*
- **AC-73**(GSM full loop):real GSM,entry→reveal→terminal dismiss → GSM 離開 LOOT_DROP;intra-queue 期間 state **全程不變**。*Integration · BLOCKING [gated G-flag-2/3]*
- **AC-74**(G-flag-1):reveal 開咗 2s(<15s)player tap dismiss → 即生效(dismiss = completion 非 interruption)。*Integration · BLOCKING [gated G-flag-1]*
- **AC-75**(#5 freeze-immune):freeze active(tree paused)→ LOOT pool nodes parent == CelebrationVFXLayer 且 `PROCESS_MODE_ALWAYS`(property assert)。*Integration · BLOCKING [gated G-LM-1+2]*
- **AC-76**(#4 fanfare):reveal onset → `play_sfx(loot_fanfare_{tier})` @ S0(LEGENDARY pre-roll 對齊 0.1s pre-shake);micro_ack sting 降一 tier。*Integration · BLOCKING [gated G-LM-4]*
- **AC-77**(ARIA once-only):S3 entry → `announce_aria` exactly once(tier + item);fast-complete 入 S3 唔 double-announce。*Logic · BLOCKING [gated G-LM-6];真 browser SR = manual ADVISORY*
- **AC-78**(#20 banner stack):real #20 audio banner 顯示中,`loot_disabled` 到 → 同屏一條、private_mode 取代(priority 表)。*Integration · BLOCKING*
- **AC-79**(G-LM-5 boot order):`project.godot` — coordinator 位於 predecessor set 全部之後、ZoneSystem 後 tail(#28 keep last)。*Static/CI · BLOCKING [gated G-LM-5]*

### F. Visual / UI(ADVISORY — headless 驗唔到)

- **AC-80**:LEGENDARY terminal frame 截圖 — 明信片 composition、「值唔值得 cap 圖」lead sign-off(Pillar 3 design test)。*Visual/Feel · ADVISORY*
- **AC-81**:micro-copy walkthrough — present tense、零**正向**運氣歸因(否定式如「RNG 唔夠 0.25」准 — N-1)、「Stamped by [weight]×[reps]」數字行先;EPIC/LEGENDARY 證人聲線合 tone。*UI · ADVISORY*
- **AC-82**:catch-up grid 截圖 — rarity-sorted 一屏、hero cell、screenshot-worthy(FT-1)。*Visual · ADVISORY*
- **AC-83**:S1 entry 錄影 — elastic-light 唔似 pop、肉眼無 staggered pop-in(structural 半邊 AC-10)。*Visual/Feel · ADVISORY*
- **AC-84**:breakdown bar 截圖(標準 + 窄屏 stacked)— 兩段對比可讀、% label 清晰、resize 唔破版。*Visual · ADVISORY*
- **AC-85**:LEGENDARY focal lock 期間錄影 — 角落零 toast(defer 兌現)。*Visual · ADVISORY(logic 半邊 AC-25)*
- **AC-86**:stash anim 錄影 — 讀成「袋低咗」唔似 crash。*Visual/Feel · ADVISORY*
- **AC-87**:world saturation 期間 burst 截圖 — burst 全飽和(>100 layer immune)。*Visual · ADVISORY [gated G-LM-1/2]*

### Test distribution

| 類別 | 數量 | Gate |
|---|---|---|
| Unit Logic(headless GUT) | 66 | BLOCKING |
| Integration | 9 | BLOCKING(7 gated) |
| Static / CI lint | 2(AC-21/79) | BLOCKING |
| Manual | 9(AC-9 + F 組 8) | ADVISORY |
| Mapping | 1(AC-35) | — |
| **總計** | **87** | |

**Coverage 自檢**:Core Rules 1–15 全 ≥1 AC ✓;F1–F6 全 ≥1 ✓;EC-M1–M20 全 cover(M19 fold 入 AC-11/50)✓;FSM ✓;INV-M1/M2 first-class ✓;cross-system 9 條非 isolation ✓。
**Gated 分佈**:G-LM-1(AC-4 部分/75/87)、G-LM-3(AC-12 部分/54)、G-LM-4(AC-29 部分/71/76)、G-LM-5(AC-79)、G-LM-6(AC-77)、G-flag-1(AC-74)、G-flag-2/3(AC-19 部分/73)— 12 條,全有先行斷言。

## Open Questions

| ID | Question | Owner | Target |
|----|----------|-------|--------|
| **OQ-1** | Stat-delta ticker slot(P-05 殘餘):modal 顯示 equip 前後 stat 變化需要 #17 equip-result payload API(`receive_loot` 回 enum 冇 stats)— MVP 唔做;#22 Character Screen 設計時一併裁(modal 加 slot vs 留俾 #22) | #22 GDD authoring | #22 design 時 |
| **OQ-2** | Rule 15 telemetry payload type(signal args vs metric struct)— `time_to_dismiss_ms` 等 4 hook 嘅 envelope 格式 | #28 Telemetry GDD | #28 design 時 |
| **OQ-3** | Contact-sheet grid 嘅 PWA share button 整合(#15 Pillar 5 提過 LEGENDARY「PWA share button 截圖」)— share API 經 platform seam 定 MVP 只靠 OS 截圖 | #27 Onboarding / PWA 層 | v0.2 |
| **OQ-4** | 新 audio cue(shutter / contactsheet / stash / toast tick)入唔入 `check_loot_audio_bank.gd` lint scope(#15 lint 只 enumerate per-tier sting) | #21 epic + #4 | epic 時 |
| **OQ-5** | G-flag-1/2/3 grep 結果(15s window vs player dismiss / `_check_pending_loot_reveal` 機制 / LOOT_DROP exit path + intra-queue 語意)— 任一同設計唔對齊 → escalate CD | #21 epic story-readiness | epic 開波時 |
