# Loot Drop Modal (#21)

> **Status**: Revised(Pass 1 fix pass 2026-06-06 — pending fresh-session `/design-review` Pass 2)
> **Author**: frank + design-system pipeline(full review mode — creative-director / game-designer / ux-designer / godot-specialist / systems-designer / art-director / qa-lead 七 specialist 諮詢)
> **Review Pass 1 (2026-06-06)**: MAJOR REVISION NEEDED(7 adversarial specialists + CD synthesis;~25 BLOCKING / 8 clusters)— 全部 inline 修正本 pass。**CD 裁決 D1-D5 binding**:D1 S3 = 唯一 commit point + pre-S3 force-close = cancel+re-reveal(推翻原 auto-collect blend)/ D2 freeze-as-hold(`ceremony_freeze` 錨 `focal_completed`,#7 零 change,orbit drift cut from MVP)/ D4 catch-up stream aggregated cue + sustained duck / D5 two-stage 保留 + F5 clamp。詳見 design/gdd/reviews/loot-drop-modal-review-log.md
> **Creative Director Review (CD-GDD-ALIGN)**: REVISED 2026-06-06 — verdict CONCERNS(C-1 folded RARE+ grid identity + C-2 overflow commit point,doc-only)→ 全部 inline 修正;5 個申報 tension 位全 ACCEPT;validation criteria:AC-80/82 sign-off + `re_reveal_count(tier)` EPIC+ 空房率 + FT-3 skip rate
> **Last Updated**: 2026-06-06
> **Implements Pillar**: Pillar 3 (DNF 式爆裝刺激 — signature ritual) · Pillar 2 constraint · Pillar 1 (FR-1 breakdown) · Pillar 5 (LEGENDARY 截圖)
> **Layer / Tier**: Presentation / Pre-MVP
> **Depends On**: #15 LootDrop (Approved, shipped) · #5 Particle (Approved, shipped) · #17 Equipment (Approved, shipped) · #1 GSM · #4 Audio · #6 ScreenEffects · #7 Camera · #33 AttentionBudget · soft: #20 HUD

## Overview

#21 Loot Drop Modal 係 Mirror Hero 嘅 **Pillar 3 signature presentation surface** — 一個 ceremonial reveal modal,負責將 #15 LootDropSystem 產生嘅每件 FULL_CEREMONY loot 兌現成「值得截圖」嘅 dopamine moment。玩家唔需要操作呢個系統:佢喺 GSM `LOOT_DROP` state(natural pause — boss 死/workout 完成)自動開 ceremony,執行 #15 已 spec 嘅 per-rarity ladder(hold/time-stop/camera focal/shake/saturation/particle/fanfare 七軌 orchestration),然後等玩家**單一 tap dismiss** — 呢下 tap 係 ceremony 期間唯一合法輸入(GSM AC-11b「modal is the input, not the surroundings」)。Banking 喺 S3 到達時發生(INV-M3:#17 `receive_loot()` 入庫 + auto-equip-if-better);dismiss 觸發 queue advance(`modal_dismissed` → #15 dequeue)。#21 同時 own MICRO_ACK 0.15s toast(cap-pressure degrade)同 Disabled banner 呢兩個輕量 surface。冇咗 #21,loot 只係 silent data row — 正正係 Pillar 3 禁止嘅「不知不覺發生」;MVP hypothesis(「爆裝感覺值得做返第二日」)成敗直接繫於本系統。實作上 #21 係 thin orchestration consumer:rarity 計算/ceremony 決策(FULL/MICRO_ACK)全由 #15 own,ADR-0005 嘅 75/25 公式喺 RARE+ breakdown bar 可視化(binding),#21 只 own choreography sequencing + modal UI 本身。

## Player Fantasy

> **Framing**: Direct — 玩家直接感受;#21 係成個 game 嘅 dopamine 兌現窗口。
> **CD framing 裁決(2026-06-06)**:「閃光燈定格」(The Flashbulb);「唯一證人」聲線吸收入 EPIC/LEGENDARY caption variant。

**Anchor**:「**一下閃光,將你成個 set 定格落一件裝備度。**」

#15 已經答咗「loot 係乜」— body work 嘅憑證;#21 答嘅係「**收到憑證嗰一刻係咩感覺**」:俾閃光燈拍低嘅瞬間。閃光燈嘅亮度同佢嘅短促係同一樣嘢 — 愈短愈亮。呢個唔係對 Pillar 2 嘅妥協,係 framing 自己嘅美學邏輯:ceremony ≤1.2s(#15 attention ceiling)因為快門本來就係一瞬。

**Player moment**(anchor 場景):rest period,攰住、流緊汗、攞部機上嚟望 → time-stop = 快門凍結世界(D2 freeze-as-hold:camera 推到 peak 嗰刻連 camera 都凍埋 — 成個世界定格喺張相度)→ 件裝備以明信片 composition 喺 frame 入面 → tap dismiss = 撳快門、將張相袋落袋。Tap 嘅 fantasy 意義係「**影低佢**」,唔係「關 popup」。(#15 LEGENDARY orbit drift cut from MVP — D2,v0.2 重訪。)

**Tone / micro-copy 指引**(modal 全部文字跟呢套):

- 相片 caption 語氣 — present tense、**零正向運氣歸因**(禁「好彩/lucky」;否定式歸因如「RNG 唔夠 0.25」係 P1-reinforcing,**准** — CD N-1 precision)、一眼吸收(攰到爆嘅人唔閱讀,只 glance)
- 數字行先:「**180kg × 5 — Stamped**」(#15 CD Framing A downstream 指示字面兌現;Pass 1 修正 — 原「Stamped by 180kg × 5」text 行先,自違本條 guideline)
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

> **Specialist 裁決記錄(2026-06-06 full review)**:game-designer + ux-designer + godot-specialist 並行諮詢;全部裁決已 synthesis 落 rules。Handoff 時機原 CD blend(auto-collect + 唔 re-reveal)**已被 Pass 1 D1 裁決推翻** — 現行:`receive_loot()` @ S3(INV-M3 唯一 commit point)+ pre-S3 force-close = cancel + re-reveal(Rule 7/8)。

### Core Rules

1. **身份同 surfaces** — `LootRevealCoordinator`(autoload,thin Node)own 三個 presentation surface:(a) **Full reveal modal**(Pillar 3 主儀式);(b) **micro-ack toast**(cap-pressure degrade acknowledgment);(c) **Banner stack**(Private Mode disabled banner 等 shared banner region)。Coordinator 喺 `_ready` instantiate 並持有 `ModalLayer`(CanvasLayer)同 `CelebrationVFXLayer`(CanvasLayer),係 >100 層嘅 single owner(layer 數值 ground truth 屬 ADR-0001 revision — **G-LM-1**)。

2. **Reveal trigger 三層分工(ownership split)** — 避免 double-gating 同 gate 真空:
   - **GSM own「幾時」**:Rule 13 reveal gating 已 shipped(`LOOT_REVEAL_SAFE_STATES` + `gsm.loot_reveal_pending`)。#21 開 modal 嘅**唯一** trigger = `state_changed → LOOT_DROP`(boot path 必須用 `connect_for_initial_state` — ADR-0006 Contract 6,兜住 `force_reveal_on_next_session` 場景 boot 時 GSM 已喺 LOOT_DROP)。
   - **#15 own「咩內容」**:**reveal queue** 係 source of truth;#21 經 `get_pending_drops()` / `get_drop(drop_id)` pull。**Grep-verified 警告(Pass 1 B 級發現)**:shipped `_pending_drops`(`loot_drop_system.gd:766-779`)係 **backend-sync-pending** 語意 — backend ACK 即 `erase(drop_id)` + `loot.pending`→`loot.committed` rename(#15 AC-34 釘死)。Story 013 backend wire 後 ACK(秒級)必然跑贏 reveal(等 safe state)→ 未 reveal drop 由 queue 蒸發。**G-LM-4 必須將 revealed-state 同 sync-state 分離**(`revealed` flag / 雙 namespace — backend ACK 永不將 unrevealed drop 移出 reveal queue;reveal dequeue 永不 skip commit rename),呢個係 G-LM-4 嘅核心 scope,唔係順帶。同時 micro_ack drops 一樣寫入 `_pending_drops`(L646)且 `LootDrop` record 冇 ceremony field — G-LM-4 須持久化 ceremony kind(FULL_CEREMONY / MICRO_ACK),`get_pending_drops()` 對 #21 reveal flow 只回 FULL_CEREMONY 件(micro_ack 件嘅 banking 行 Rule 9 路徑,唔入 reveal queue)。
   - **#21 own「點呈現」**:choreography sequencing、drain pacing、全部 presentation 調用。
   - `loot_dropped` signal 降級為 **doorbell/prep 用途**(texture pre-warm 確認、pending badge 更新):收到時如 modal 唔 active 且 GSM 喺 LOOT_DROP → drain head;否則 no-op(件嘢喺 #15 queue,下個 drain step 自然攞到)。**`loot_dropped` 唔係「即開 modal」指令** — mid-set drop 嘅 deferral 由 GSM Rule 13 處理,#21 唔自建 wait queue。

3. **Reveal pipeline 五段(S0–S4)** — 每段有明確 content 狀態 + input policy:

   | 段 | Timeline(global reveal clock,T=0 = reveal-start frame) | 內容狀態 | Input policy |
   |---|---|---|---|
   | **S0 Burst** | **frame-0 event(唔係 duration)** — trigger→T=0 latency ≤100ms 唔計入 budget | tier-colored particle burst(#5 `play(LOOT_BURST/LOOT_RARE_BURST, reveal_anchor_pos)`)+ flash frame + fanfare 同 frame。**FR-2 100ms hard binding 嘅對象只係 trigger→S0** — rarity 喺 ~100ms 已 pre-attentively 可讀(burst 帶 tier color) | 唔收 tap |
   | **S1 Entry** | [0, D_entry](per-tier 150–450ms,**同 S2 並行** — 統一 timing model) | modal scale 0.8→1.0(elastic-light overshoot);**scale-in 完成嗰 frame 視覺 content slots(§B 1-6)必須全部 final** — 唔准 staggered text pop-in(攰人 glance 可 land 喺任何時刻,stagger 製造「我 miss 咗嘢」uncertainty) | 唔收 tap(t<D_entry 兜 tap-through,F5) |
   | **S2 Ceremony** | [0, T_block]:**S2a hold/focal-push [0, D_hold] → S2b freeze @ peak [D_hold, D_hold+D_timestop]**(D2 order — 推鏡入 peak 然後快門凍結) | content 已 final(由 D_entry 起);ceremony 行緊(focal push → freeze/shake/saturation) | tap(t≥D_entry)= **fast-complete**(Rule 5) |
   | **S3 Steady** | T_block → tap 為止 | 靜態 dismissable 終態;ScreenReader announcement 喺呢度 fire(一次);`receive_loot()` + INV-M3 commit 喺呢度 fire(Rule 7);focal exit tween 喺背景 non-blocking 行完 | tap = dismiss(debounce 錨 S3 entry,F5) |
   | **S4 Exit** | tap → ≤200ms | 快門定格 → shrink/fade;**exit anim 完成先 emit terminal `modal_dismissed`**(→ #15 `loot_confirmed` → GSM,Rule 6) | 唔收 tap;對 GSM force-close idempotent |

   Entry 同 S2 **必須 overlap 計時,唔可以 additive**(否則 LEGENDARY 超 1.2s attention ceiling — 見 Formulas F1 timeline budget + FSM section 統一 timing model 表)。

4. **Ceremony ladder 執行(D2 freeze-as-hold choreography)** — per-tier 數值(hold / time-stop / camera zoom+duration / shake / saturation / particle preset)**全部由 #15 Visual Spec Table own**(#15 L1030-1034:RARE 1.02× pulse 0.3s / EPIC 1.05× focal 0.65s / LEGENDARY 1.08× focal 0.8s),#21 經 data-driven ceremony config 讀,**零 hardcode、唔另印數**。**Duck 唔喺 #15-own 清單**(Pass 1 B 級修正):duck 深度/release 係 **#4 own**(shipped flat −8dB + signal-driven release;#15 表嘅 per-tier −3..−16dB 列係 stale — #15 erratum,見 Bidirectional sync flags)。
   - **調用序**:S0 particle burst(frame 0,FR-2)+ fanfare(`play_sfx(loot_fanfare_{tier})` — **caller = #21 coordinator**,EG-1 precedent,唔再 defer)→ EPIC/LEGENDARY:`CameraController.request_focal(reveal_anchor_pos, D_hold(tier), zoom(tier))` @ T=0(必須 GSM==LOOT_DROP 之後 — #7 Rule 4;**camera push-in 就係 S2a hold 嘅字面實現** — focal entry duration == #15 hold 數值,同源)→ `focal_completed`(T≈D_hold)→ `ScreenEffects.ceremony_freeze(D_timestop)`(**G-LM-3**)— **freeze-as-hold**:#7 focal exit tween 係 pause-bound(`camera_controller.gd:355-356`),freeze 將佢凍住 → **camera 釘喺 peak zoom 成個 D_timestop = 快門凍結嘅字面實現**;freeze 自然 expiry → S3,exit tween 喺 S3 期間 non-blocking 行完。RARE:`request_focal` pulse(#15 數值)@ T=0,freeze 錨 clock T=D_hold。COMMON/UNCOMMON:無 focal、無 freeze(D_timestop=0)。Shake(#6,ALWAYS process,freeze 期間照行)+ saturation(**G-LM-3 新增 API** — shipped #6 現時零 saturation 實現,grep 全 src/ 證實;唔係「現有 API」)。
   - **LEGENDARY orbit drift:cut from MVP**(D2)— #7 冇 hold phase,orbit 需要 #7 amendment;freeze-as-hold 已兌現「定格喺 peak」嘅 fantasy 需求。#15 嘅 orbit 條款入 erratum note(v0.2 重訪)。
   - **`reveal_anchor_pos` 來源(Pass 1 B 級修正 — 原文 `item_world_pos` unsourced:`LootDrop` record 零 position field,workout-completion loot 喺 IDLE 冇 world entity)**:anchor = **avatar 位置**(#15 fantasy「avatar 手上發光」嘅字面兌現)— `get_tree().get_first_node_in_group(&"avatar_anchor")` query(forward constraint → #26 AvatarRenderer register group;#26 係 soft dep,query-only);group 缺位 fallback = camera viewport center。burst 同 focal 共用同一 anchor。

5. **Dismiss policy:tap-only + two-stage tap** —
   - **無 timed auto-dismiss**(P-05 嘅 5s auto-dismiss 撤銷 — **G-LM-7** P-05 更新):auto-dismiss 唯一「炒」嘅人就係望得最慢嗰個(loss-aversion sting 打擊 Pillar 3);「tap = 撳快門」fantasy 要求 dismiss 必須係玩家嘅 act;RARE+ SR announcement 讀出可能 >5s。「Never traps」由 system 層兜:外部 transition(`rest_ended` 等)可以 force-close modal(Rule 8),#15 Pending pool 保證零 loss。**措辭修正(Pass 1)**:`MIN_REVEAL_WINDOW`(15s)係 GSM **entry gate**(入 LOOT_DROP 前檢查 RestPeriod 剩餘時間 — GSM L123),**唔係 force-close suppression window** — `rest_ended` 係 event-driven,可以喺 ceremony 未完成(pre-S3)就 fire,呢個場景由 Rule 8 pre-S3 branch 兜(cancel + re-reveal)。
   - **Two-stage**:S2 tap = fast-complete(content snap 到 S3 終態;freeze active → 即時 release,freeze 未 issue → **唔 issue**(skip),兩種都行 INV-M1 單一出口;particle `stop()` natural fade 唔 hard-cut(#5 零新 API — 原文「fast-decay 0.2s」係 phantom primitive,撤);**audio sting 照播完,#21 零 stop/cut call** — sting 係 colorblind 玩家嘅 rarity backup channel,#15 §D。**Scope note(Pass 1)**:「唔 cut」係 #21-side 承諾;pool-pressure voice steal 由 G-LM-8 priority 指派 + Rule 10 stream aggregated cue 共同壓低,唔係 AC-16 spy 可達範圍);S3 tap = dismiss。兩 stage 之間 `DISMISS_DEBOUNCE_SEC`(0.25s)input lockout — 攰手 mash 兩下唔會連 skip 帶 dismiss 盲拆(lockout 錨點 = **S3 entry**,統一 F5/AC-15,見 F5)。**S2 fast-complete tap 同 debounce-ignored tap 一律無 audio feedback(deliberate — 嗰刻 sting 係唯一 audio 主體,加 click 會 mask tier character;ignore 係 debounce 唔係 invalid action,唔出 `ui_error`)。**
   - **Tap surface = 全屏 scrim**,≥48px CTA 只係 labelled affordance(label「**影低佢**」— 快門 framing;原「tap 收藏」會被 stash-exit auto-collect 踢爆做 fiction,Pass 1 R 級修正:tap 嘅真實效果係影相,收藏本來就自動)— Fitts's law + 汗手,唔要求瞄準。LOOT_DROP 期間 #20 已 early-return tap(#20 AC-CR-5),#21 係唯一 tap consumer。
   - Dismiss tap 行 **#33 exempt handler pattern**(唔經 `is_input_permitted()` — #33 EC-15 / GSM AC-11b「modal is the input, not the surroundings」)。

6. **Queue drain:pull model + intra/terminal split** —
   - Dismiss → emit `modal_dismissed(drop_id, terminal: bool)` → #15 handler **以 drop_id dequeue**(Pass 1 修正:queue primary key 係 drop_id — `_pending_drops` / `get_drop` / `loot_rollback` / #15 EC-29 double-dismiss guard 全部 drop_id;transition_id 喺 debug path 會碰撞。唔係 strict head-pop — catch-up 模式 #21 可重排 reveal 順序,見 Rule 10;handler spec 屬 **G-LM-4** #15 reverse-wire story)→ #21 query `get_pending_drops()`。
   - **Intra-queue dismiss**(queue 非空):advance 下一件,**GSM 唔郁**(唔 exit/re-enter LOOT_DROP N 次);前後件之間 gap = `max(INTER_REVEAL_GAP_SEC, 上件係 EPIC+ ? FOCAL_EXIT_MARGIN_SEC : 0)`(EC-M9 — 等 #7 focal exit tween 完先 request 下一個 focal)。
   - **Terminal dismiss**(queue 清空):S4 exit anim 完成 → emit `modal_dismissed(drop_id, terminal=true)` → **#15 見 queue 空 emit `loot_confirmed` → GSM 訂閱觸發 exit transition**(Pass 1 seam 方向修正:GSM AC-14 / L234 locked 機制係 #15 chain,zero-direct-call — #21 **永不**直接 call GSM;原「#21 通知 GSM」措辭撤)。
   - **GSM L128 drain cadence reconcile(Pass 1)**:GSM Decision #1 寫「每個 RestPeriod 只 drain ONE」— #21 intra-queue drain-all supersede 佢(catch-up 係 #15 Rule 15 要求;fatigue bound 由 F3 caps + per-item commit + 外部 force-close 兜)→ **GSM erratum**(見 Bidirectional sync flags),G-flag-3 scope 明文包埋 drain cadence。
   - **One-modal-at-a-time**:reveal 行緊時新 `loot_dropped` 嚟 → no-op(doorbell 語意,Rule 2)— 唔開第二個 modal。

7. **Handoff 時機(D1 commit-point invariant — INV-M3)** —
   - **INV-M3(S3 = 唯一 commit point)**:`InventorySystem.receive_loot(drop)` 喺 **S3 到達時** call(唔係 tap 時),且 **S3 係 sequential reveal 唯一嘅 banking + dequeue commit point** — S3 未到 = 件嘢未離開 #15 reveal queue(零 emit、零 bank);S3 到咗 = banked + 可 dequeue。#21 係 shipped `receive_loot()` 嘅唯一 caller(現時零 caller — epic wire;CI lint 見 AC-21 owner-exempt 條款)。咁樣 tap 純粹係 ceremonial(撳快門),玩家永遠唔 tap 都唔丟 item;#17 duplicate no-op + batch debounce(#17 EC-22/AC-29)兜底。
   - **Pre-S3 force-close = cancel + re-reveal(D1,推翻原「唔做 re-reveal」blend)**:原論證(「15s ≫ ceremony 全長,S3 必先於 force-close」)唔成立 — 15s 係 entry gate 唔係 suppression window,`rest_ended` event-driven 可以喺 S0-S2 fire。Pre-S3 force-close:cancel(行 INV-M1 出口)、**唔 emit `modal_dismissed`**、件留 #15 queue、GSM `loot_reveal_pending` 保持 true(GSM L127 retry 語意 — **同 shipped GSM contract 完全對齊**)→ 下次 safe state **re-reveal**。哲學:未撳快門 = 張相從未影過,re-reveal untapped item 係誠實;auto-collect untapped 先係假快門。**Re-reveal 只限 pre-S3(未 banked)件;已 banked(post-S3)item 永不 re-reveal**(嗰個先係 anti-flashbulb)。
   - **`FAILED_ROLLBACK` recovery chain(Pass 1 修正 — #17 EC-1 鏈唔可以斷)**:#17 EC-1 設計係 caller catch `FAILED_ROLLBACK` 後寫 `loot.pending.recovery`(#15 sole-writer namespace)。#21 係 stateless presentation 唔寫 persistence → S3 `receive_loot` 回 `FAILED_ROLLBACK` 時 #21 call **#15 `report_receive_failure(drop_id)`**(G-LM-4 新增 handler,#15 寫自己 recovery namespace)— boot-drain eventual grant 鏈保全;user-visible 行為照 EC-M14(零 delta + 照 dismiss)。
   - **Queue dequeue**:`modal_dismissed` 喺 tap dismiss / post-S3 stash-exit 時 emit(Rule 6/8);pre-S3 cancel 路徑零 emit(上文)。
   - **Catch-up batch commit point = stream-end(或 force-close 嗰刻,whichever first)**(Pass 1 修正 — 原「per-beat commit」對 shipped #17 one-frame debounce 唔可滿足:beats 隔 0.15s ≈ 9 frames → 40 件 = 40 次 full persist):stream beats 只 display 唔 commit;stream 完成(或 force-close 中斷)嗰刻,已 display 嘅 beats 喺**單一 frame 連發** `receive_loot` + `modal_dismissed` → #17 one-frame ONE_SHOT debounce 啱用,aggregate/push/persist 各一次;未 display beats 留 pending。RARE+ ceremonies 照 INV-M3 per-item S3 commit(件數 ≤ K=5,persist 次數有界)。Grid overflow 件(C-2)入 grid entry 嗰 frame 同款 batch。

8. **Force-close(GSM force-transition while modal open)— D1 pre/post-S3 split** — 玩家唔望 mon、新 set 開始等外部 transition 發生時:
   - **Pre-S3(S0-S2)**:**cancel + re-reveal path** — ≤1 frame cancel(行 INV-M1 出口,同 rollback-cancel 同 shape)、**唔 emit `modal_dismissed`**、件留 #15 queue、`loot_reveal_pending` 保持 true → 下次 safe state GSM retry re-reveal(Rule 7)。無 toast(件未 banked,冇嘢 acknowledge)。
   - **Post-S3(S3/S4)**:**stash-exit auto-collect** — modal 行 ≤0.3s「stash」收埋動畫(無需 input)→ emit `modal_dismissed`(item 已喺 S3 banked)→ 將被 stash 嘅 drop 加入 deferred-ack 計數,**下次進入 safe state 出 aggregated ack toast**(「+N 已收藏」,micro-ack surface 重用)。S4 dismiss path 對 force-close **idempotent**(force-close 落喺 exit anim 中途唔 double-emit)。
   - **SUSPENDED-triggered force-close(任何段)**:bfcache pagehide 後零 frame render — **跳過全部動畫即時行對應 branch**(pre-S3 cancel / post-S3 即 emit),唔等 anim(否則 `modal_dismissed` 延到 resume)。

9. **micro_ack:banking + toast spec** — `loot_micro_ack(drop_id)` 觸發:
   - **Banking(Pass 1 新增 — 原文「item 已 grant」係 phantom assertion:shipped 零 caller,micro_ack 件從未入過庫)**:#21 收 signal 即 `get_drop(drop_id)` → `receive_loot(drop)`(即時,mid-workout data-layer call,零 UI — #21 仍係唯一 caller)→ emit `modal_dismissed(drop_id, terminal=false)` dequeue。咁樣 micro_ack 件:(a) 真係入咗庫;(b) 唔會留喺 queue 漏入下次 catch-up 變 full ceremony(double-acknowledge / 推翻 #15 cap 決策);(c) `FAILED_ROLLBACK` 同款行 `report_receive_failure` 鏈(Rule 7)。
   - 位置:screen edge(同 #20 layout 協調,permanent corner 區附近),**永不佔 center stage**(中央係 sacred reveal space)。
   - 內容:item icon + rarity-tint flash,**無文字**(sub-second 讀唔到字);0.15s = **entrance beat**(對齊 catch-up burst cadence),total visible ~1.2s 連 fade(對齊 attention ceiling)。「0.15s toast」嘅 #15 doc comment 以此解讀 — 0.15s total = subliminal,acknowledge 唔到嘢,違 micro_ack 嘅 Pillar 1 存在意義(multi-effort 應被 acknowledge)。
   - **Non-interactive**(唔可 tap):tappable 要過 #33 exempt handler,複雜度換邊際價值近零;item 已 grant,inventory 見得返。
   - **Modal active 時 defer + aggregate**:dismiss 後 flush 成單一 aggregated toast(「+N」),唔 serial 逐個出(LEGENDARY freeze-hold 期間角落彈 toast = attention competitor)。連續多個 micro_ack 同理 aggregate。
   - **Safe-state gate(F4 flush gate — #15 L1081 對齊)**:`loot_micro_ack` 通常喺 mid-workout cap-hit 觸發,而 #15 UI Requirements 明文「workout 進行中唔顯示任何 toast/overlay」— 所以 toast **永不喺 non-safe state 顯示**:hold + aggregate,下次 GSM safe-state entry(REST_PERIOD / IDLE)先 flush。Acknowledgment 喺 natural pause 兌現,Pillar 1(multi-effort 被認可)同 Pillar 2(mid-set 零干擾)同時保全。

10. **Catch-up mode(contact-sheet model)** — `get_pending_drops()` ≥ `CATCH_UP_THRESHOLD`(5,#15 Formula 6)→ **center prompt surface**「您有 N 個未拆 loot」(Pass 1:唔用 top-edge banner — 單手 thumb-reach 最差 zone,同自己 Fitts 哲學矛盾;input 語言同 modal 一致:**全屏 tap = reveal-all,corner ≥48px = 「稍後再拆」defer**):
    - **可 defer**:defer = 留 Pending 下次再嚟,唔係 forced flow(玩家可能趕住走);terminal emit → GSM 推進(retry-suppression 見 FSM note / G-LM-4)。
    - **Sub-RARE 自動 stream,零 tap**:0.15s/件流水過(aggregated particle effect,唔逐件 full burst — #5 EC-18 caller dedup 責任)。**Stream beat 視覺 = luminance-stable(icon slide + tier tint,零 flash transient)**(Pass 1 修正 — 6.7 beats/s 配 per-beat flash 直接違自己 §C「≤3 flash/s」WCAG 2.3.1 rule;flash transient 只准 stream 頭尾各一次)。**Stream audio(D4)= 單一 aggregated cue**(≤stream 長度嘅 riser/coin-shower texture,low priority,單一 duck handle)— **禁止 per-beat fanfare**(naive 實作 = 機關槍 + Music duck 釘死 −14dB + 8-voice pool 洪水 steal 走 RARE+ sting tail);catch-up 全程落一個 sustained 淺 duck(−4dB 單 handle),per-ceremony fanfare duck 照行(#4 multiset 自然疊加),exit 時 release。
    - **RARE+ 留最尾,ascending rarity,各自 full ceremony + tap**(peak-end rule:sequence 以最好嗰件收尾)。
    - **收尾 summary grid**:全部 N 件 rarity-sorted 一屏(「相辦/contact sheet」)— closure + screenshot-worthy(FT-1 對齊)。
    - **中途可退出**(Pillar 2 never-trap):常駐「稍後再拆」affordance(角落,≥48px,**獨立 Control 喺 scrim z-order 之上,input 優先食 tap**(Pass 1 修正 — 原文冇 input policy,同「全屏 scrim」食 tap 矛盾);ceremony S2 行緊時 tap affordance = 當前件 fast-complete → S3 commit → stash 收埋,剩餘留 Pending — exit 永遠唔丟件)。**Commit 語意(對齊 Rule 7)**:RARE+ ceremonies per-item commit @ S3(INV-M3);stream beats display-only,stream-end / force-close / exit 嗰刻單一 frame batch commit 已 display 件;未 display 原封留 Pending,banner 下次以更新咗嘅 N 重現,零懲罰。
    - **15s window truncation(Pass 1 明文)**:worst-case catch-up(14.3s 機器時間 + taps)可以俾 `rest_ended` force-close 斬,而 peak-end ordering 令被斬嘅係最高 tier — **accepted limitation**:per-item/batch commit 保證零 loss,未 reveal RARE+ 原封留 Pending,下次 catch-up 以同一 peak-end 結構重現(peak 冇消失,只係延期);telemetry `catchup_truncated(remaining, reason)` 量度發生率,rate 高就重訪(縮 K / RARE+ 提前)。

11. **Rollback 處理(`loot_rollback`)** —
    - **Pre-S3(S0–S2)**收到 rollback(該 drop_id):≤1 frame cancel、**必須 restore timescale**、無 terminal frame、無 toast、**唔 emit `modal_dismissed`**(#15 rollback path 自己處理 queue,emit 會 double-advance)。
    - **S3(post-banking)收到 rollback:顯示層 no-op**(Pass 1 修正 — S3 時 `receive_loot` 已 fire、content 已被見:cancel = 字面 show-then-revoke,違自己第 4 bullet;item 已 grant,revoke 屬 #15/#17 post-grant reconciliation path,#21 唔演)— modal 照行到 dismiss,telemetry `loot_reveal.late_rollback`。同 EC-M16 stream「已過 commit point → post-grant path」同一原則。
    - **Rollback-cancel 之後必須 re-query**(Pass 1 修正 — 原 FSM「rollback → HIDDEN」會令 GSM 永久 stuck:Rule 13 只係 entry-time check,queue 空冇人 emit terminal):cancel 完成 → `get_pending_drops()`:非空 → gap 後 ENTRY 下一件;空 → emit `modal_dismissed("", terminal=true)` 行 terminal 出口(#15 emit `loot_confirmed` → GSM exit)。
    - Queued 未 reveal 嘅 rollback:pull model 下零動作(#15 自己出 queue,下次 query 見唔到)。
    - **Timescale guaranteed-restore invariant(INV-M1)**:所有 cancel path(fast-complete / rollback / pre-S3 force-close / EC-M1 Suspended)共用單一 freeze-release 出口,release **idempotent** 且「freeze 未 issue」時係 no-op — time-stop dangling = 全 game 凍結,係 #21 最高危 failure mode。
    - **永不 show-then-revoke**:S0 burst 係 non-committal(「有嘢嚟緊」嘅閃光,未 promise 具體 item);S1 content 填充 gate 喺 #15 optimistic persist 嘅 local commit 窗口之後 — 玩家見到嘅失敗形態永遠係 deferral(「Loot 已記低,稍後再拆」),唔係 revocation(見到件 EPIC 然後收返 = Pillar 1 attribution trust 最大破壞)。

12. **Disabled banner + banner stack** — `loot_disabled(reason)` → banner stack 顯示 #15 own 嘅 copy(「Private Mode:Loot 暫停掉落…」)。Modal active 時收到 → 現行 ceremony 行完,banner 喺 dismiss 後先出(唔 mid-ceremony 蓋 banner 偷走 euphoria);同時收到 rollback → rollback 優先。Banner stack:top edge full-width、**固定 top margin**(Pass 1:web export `get_display_safe_area()` 回 full canvas — iOS inset 要 JS bridge,唔依賴;固定 margin 兜)、**同 #20 banner 共用單一 stack region,同屏最多一條,priority:`private_mode` > 其他(audio silent-mode 等)**;**displacement 語意(Pass 1)**:被 displace 嘅 banner 喺高 priority banner 清走後 re-render(predicate 仍 true 就返嚟 — displacement ≠ #20 one-shot dismissal,防 audio banner 永鎖;#20-side suppress 接線屬 Q-OQ6 sync);**catch-up summary banner 唔屬 banner stack**(佢係 interactive CTA surface,行 CATCHUP_PROMPT state,center placement — 唔同 status banner 爭位);絕不侵 #20 L1 anchor zone;`role=status` announce 一次。

13. **Empty-queue LOOT_DROP entry**(rollback race:入咗 LOOT_DROP 但 `get_pending_drops()` 空)→ #21 即 emit `modal_dismissed("", terminal=true)` → #15 emit `loot_confirmed` → GSM 推進 — 否則 stuck state(seam 全行 #15 chain,Rule 6)。
13b. **GSM contract row 兌現狀態(Pass 1 — GSM L375 四項逐項收線)**:(a) `source_event = "deferred_reveal"` entry mode — Rule 2 GSM-driven trigger 已兌現 ✓;(b) inventory「未開封」item tap entry trigger — **defer v0.2**(未開封件已 auto-commit 唔喺 reveal queue,需要 #23 Inventory UI surface + 獨立 content-source 分支;MVP 30-日 hard-cap auto-commit 係極罕 path,deferred-ack 已 acknowledge)→ GSM erratum note + OQ-6;(c) `BossPayload.outcome == INTERRUPTED_WITH_CREDIT` → **fast-victory variant 兌現**:source attribution slot 用「快勝」variant copy + caption(UI Requirements §B slot 4),ceremony ladder 照 tier 不變(layout variant 唔係 ceremony variant);(d) `rest_ended` force-close 保留 `loot_reveal_pending = true` — Rule 8 pre-S3 branch 已兌現 ✓(post-S3 件已 banked,#15 dequeue 後 queue 空 → `loot_confirmed` 清 flag,語意一致)。

14. **玩家唔可以做嘅嘢**(constraints):mid-ceremony 唔可以 dismiss(只可 fast-complete — 保證 terminal frame 永遠被見到,reveal 唔 missable);唔可以 re-open 已 dismiss 嘅 reveal(dismiss-peek pattern 唔存在 — #5 EC-18 嘅 dedup 場景以唔提供 re-peek 直接消滅);唔可以喺 modal 開住時操作周邊(#33 ceremony lock);唔可以 skip audio sting(rarity backup channel)。

15. **Telemetry hooks(#28 未 build,signal 口要留)**:`ceremony_skip_attempted(tier)`、`time_to_dismiss_ms`(EPIC+ <500ms 標 `suspicious_dismiss` flag — 誤觸 dismiss = moment 蒸發嘅盲區量度)、`re_reveal_count(tier)`(pre-S3 force-close 觸發 — **CD N-2 threshold pin(Pass 1,binding-gate satisfiability 教訓)**:EPIC+ re-reveal rate >5% over 首 100 RARE+ reveals → 重開 D1 裁決)、`stash_exit_count(tier)`(post-S3)、`catchup_abandoned(remaining)`、`catchup_truncated(remaining, reason)` — FT-3 skip test 同 reveal engagement 嘅量度口。

### States and Transitions

`LootRevealCoordinator` 嘅 modal FSM(toast 同 banner 係 parallel surfaces,唔入 FSM)。**8 states + 1 explicit mode flag `in_catchup: bool`**(Pass 1 修正 — 原 7-state 表表達唔到 catch-up:stream 冇 state、EXITING→GRID edge 缺、GRID 冇 GSM notify;「stream mode」由 smuggled flag 升做 first-class)。AC-37 嘅 table-driven 斷言以 (state, in_catchup) pair 為 edge 單位:

| State | 意義 | Entry | Exit edges(全列) |
|---|---|---|---|
| `HIDDEN` | modal 唔 visible(pre-warmed,`visible=false`) | boot / terminal 出口 | GSM→LOOT_DROP:depth==0 → 即 terminal emit 留喺 HIDDEN(Rule 13);0<depth<threshold → ENTRY(in_catchup=false);depth≥threshold → CATCHUP_PROMPT |
| `ENTRY` | S0 burst + S1 scale-in | reveal 開始 | S1 完成(content final)→ CEREMONY;rollback(該 drop_id)→ cancel → re-query(Rule 11:非空 → gap 後 ENTRY;空 → terminal emit → HIDDEN);pre-S3 force-close → cancel → HIDDEN(零 emit,Rule 8) |
| `CEREMONY` | S2 ladder 行緊(hold/focal-push → freeze @ peak,D2) | ENTRY 完 | ladder 完 / tap fast-complete → STEADY;rollback → cancel → re-query 同上;pre-S3 force-close → cancel → HIDDEN(零 emit) |
| `STEADY` | S3 dismissable 終態(SR announce + `receive_loot` + INV-M3 commit 喺 entry 時 fire) | CEREMONY 完 | tap dismiss / post-S3 force-close(stash-exit)→ EXITING;rollback → **no-op 留 STEADY**(Rule 11 post-banking) |
| `EXITING` | S4 exit anim(或 stash collapse) | dismiss / stash-exit | anim 完:in_catchup 且 ceremonies 剩 → gap 後 ENTRY;in_catchup 且 ceremonies 完 → CATCHUP_GRID;!in_catchup 且 queue 非空 → gap 後 ENTRY;queue 空 → terminal emit → HIDDEN。force-close 落中途 → idempotent(唔 double-emit,Rule 8) |
| `CATCHUP_PROMPT` | summary banner 顯示中 | GSM→LOOT_DROP 且 depth ≥ threshold | tap reveal-all:sub-RARE>0 → CATCHUP_STREAM;sub-RARE==0 → ENTRY(in_catchup=true);defer / force-close → terminal emit → HIDDEN(零 commit,留 pending — EC-M7) |
| `CATCHUP_STREAM` | sub-RARE 零 tap 流水(display-only beats) | reveal-all | stream 完 → batch commit(Rule 7)→ RARE+ 有 → ENTRY(in_catchup=true);RARE+ 無 → CATCHUP_GRID;「稍後再拆」tap / force-close → batch commit 已 display 件 → terminal emit → HIDDEN |
| `CATCHUP_GRID` | 收尾 contact-sheet grid(post-commit summary + C-2 overflow batch commit @ entry) | ceremonies 完 / stream 完(零 RARE+) | tap close / 外部 transition → **terminal emit → HIDDEN**(Pass 1 修正 — 原表零 GSM notify = 全 sub-RARE case GSM deadlock) |

**Terminal emit 語意**:`modal_dismissed("", terminal=true)` → #15 handler:emit `loot_confirmed` → GSM exit(Rule 6 seam)。**Defer/exit 時 queue 仍非空嘅 retry-suppression**(同一 safe-state occupancy 唔准 banner 無限 re-trigger loop)歸 G-LM-4 釘實(shipped `_check_pending_loot_reveal()` @ gsm:446 現時零 caller — GSM-side wiring 本身屬 reverse-wire story scope)。

**統一 timing model(Pass 1 — stage table / F1 / FSM 單一讀法,防 additive 誤寫)**:
- **T=0 = reveal-start orchestration frame**(#21 開始呢件 drop 嘅 choreography 嗰 frame);trigger→T=0 嘅 latency(FR-2 ≤100ms)唔計入 budget。
- **S0 係 frame-0 event,唔係 duration**(burst + fanfare 喺 T=0 同 frame 發出)。
- **三 track 由 T=0 並行**:① S1 entry scale-in [0, D_entry];② camera focal push-in [0, D_hold](EPIC/LEG;== S2a);③ ladder window [0, T_block]。
- **S2 內部結構(D2)**:S2a = hold/focal-push [0, D_hold] → S2b = freeze @ peak [D_hold, D_hold+D_timestop]。T_block = max(D_entry, D_hold + D_timestop)。
- **FSM state ≠ timeline stage**:ENTRY/CEREMONY 係 input-policy gate(content 同 VFX 係 parallel track);`ceremony_freeze` 喺 FSM 邊個 state 發出由 timeline 決定(T=D_hold),唔係 state transition 決定。
- 全部 timer 行 global reveal clock(delta-time 累積),fake-clock test 以 T=0 frame 為錨(AC-40)。

每個 cancel/exit path 經單一 freeze-release 出口(INV-M1,idempotent + 未-issue no-op)。

### Interactions with Other Systems

| 系統 | 方向 | Interface owner | Contract |
|---|---|---|---|
| **#15 LootDrop** | #15 → #21 signal;#21 → #15 emit-back + pull + call | #15 | subscribe `loot_dropped`(doorbell)/ `loot_micro_ack` / `loot_rollback` / `loot_disabled`;pull `get_pending_drops()`(只回 FULL_CEREMONY 件,Rule 2)/ `get_drop(drop_id)`;emit `modal_dismissed(drop_id, terminal)` → #15 以 drop_id dequeue + terminal 時 emit `loot_confirmed`;call `report_receive_failure(drop_id)`(EC-1 recovery 鏈,Rule 7)(**G-LM-4** 重寫 scope:revealed/sync state 分離 + ceremony kind 持久化 + drop_id dequeue + loot_confirmed emit + recovery handler + defer retry-suppression — #15 加 handler,reverse-wire story,#18 先例) |
| **#1 GSM** | #1 → #21(state only)| #1 | `connect_for_initial_state(state_changed)`;開 modal 唯一 trigger = → LOOT_DROP;**exit 行 #15 chain(`loot_confirmed`),#21 對 GSM zero-direct-call**(GSM AC-14 — Pass 1 seam 方向修正);Rule 13 safe states + `MIN_REVEAL_WINDOW`(entry gate)係 #1 own;L375 四項 contract 兌現狀態見 Rule 13b |
| **#17 Equipment** | #21 → #17 call | #17 | `receive_loot(drop)` @ S3 / micro_ack / batch frame(唯一 caller — AC-21 owner-exempt lint;duplicate no-op + one-frame batch debounce #17 兜;`FAILED_ROLLBACK` → `report_receive_failure` 鏈,Rule 7)+ **#17 erratum**:doc comment「#15 calls this」→ #21(見 sync flags) |
| **#5 Particle** | #21 → #5 call | #5 | `play(LOOT_BURST / LOOT_RARE_BURST, reveal_anchor_pos)` per #15 tier mapping;catch-up stream 用 aggregated effect(EC-18 caller dedup);**G-LM-2**:LOOT pool nodes reparent 入 CelebrationVFXLayer + `PROCESS_MODE_ALWAYS`(現時 INHERIT — tree paused 時 burst 會 freeze,違 ladder「particle 繼續」;且 layer 0 會被 saturation 降格,違 art bible「爆裝特效全飽和」)+ **reparent 時序 = post-#21-boot handshake**(`register_celebration_layer(layer)`,idempotent — pool 喺 #5 boot 已 add_child,layer 等 #21 tail `_ready` 先存在) |
| **#6 ScreenEffects** | #21 → #6 call | #6 | shake(現有 API,ALWAYS process freeze 期間照行);**G-LM-3 重寫 scope(Pass 1)**:① 新 `ceremony_freeze(duration)` primitive(ceiling 0.4s,**唔受 `MAX_PAUSE_SEC=0.12` 管**)② **freeze 記帳由 shipped 單一 scalar(`_pause_remaining_sec`)重構成 per-entry ledger** + ③ **新 idempotent 早收 `release(handle)` API**(INV-M1 出口 — shipped 只有自然 expiry,無早收)④ **saturation API 全新**(shipped 零 saturation 實現 — grep src/ 證實,「現有 API」係 phantom;BackBufferCopy shader uniform 通路)⑤ 繼承 Suspended/focus-resume 安全網 — #21 唔自己掂 `get_tree().paused` |
| **#7 Camera** | #21 → #7 call + signal | #7 | EPIC/LEG `request_focal(reveal_anchor_pos, D_hold(tier), zoom(tier))` + RARE pulse(數值 data-driven 讀 #15 table,零 hardcode — Pass 1 修正);GSM==LOOT_DROP 後先 call(#7 Rule 4);subscribe `focal_completed` 做 freeze 錨點(D2 freeze-as-hold);**#7 API 零 change 維持成立**(D2 設計目標);orbit drift cut from MVP;連續 EPIC+ 間距 = `FOCAL_EXIT_MARGIN_SEC`(EC-M9) |
| **#4 Audio** | #21 → #4 call | #4 | **`play_sfx(loot_fanfare_{tier})` caller = #21 coordinator @ S0(Pass 1 釘死 — EG-1 precedent:data layer 唔 call play_sfx,presentation consumer own forwarding;#4 catalog source 列 #15→#21 行 erratum sync)**;LEGENDARY pre-roll 對齊 0.1s pre-shake;`ui_back` 屬 #21 可用(low/mono);**micro_ack/toast 一律配 toast tick(low/mono),fanfare 音色家族獨家保留俾 modal — #15 L204「降一 tier sting」erratum**(mid-set 無畫面 fanfare 違 Pillar 2 + aggregated 跨 tier sting 無解);新 cue catalog co-design = **G-LM-8**;AudioManager process-mode = **G-LM-9**(freeze 期間 fanfare 唔俾 engine pause) |
| **#33 AttentionBudget** | #21 reads pattern | #33 | dismiss tap 用 exempt handler(唔經 `is_input_permitted()` — #33 EC-15);周邊 lock 係 #33/#20 行為,#21 零依賴 |
| **#20 HUD** | 無 direct contract | GSM-mediated | **唔加 direct notify** — 兩邊聽 GSM(雙真相源 + ordering coupling 風險);入場 skew 係 feature(HUD dim 先、burst 後 = 影相前調光 anticipation beat);exit 序 pin:S4 anim 完 → GSM transition → #20 un-dim(答 #20 Q-OQ6);banner stack 共用 contract 見 Rule 12 |
| **PlatformDetect** | #21 → call | PlatformDetect | `announce_aria(text)` gateway(**G-LM-6**:**現時唔存在**(grep `platform_detect.gd` 零 aria match — Pass 1 措辭修正,唔係 stub),epic story 新增;boot 時 inject hidden `aria-live` div — live region 必須 first announcement 前已存在於 DOM) |
| **#26 AvatarRenderer** | #21 → group query | #21 | `reveal_anchor_pos` 來源(Rule 4):`get_first_node_in_group(&"avatar_anchor")`,fallback viewport center;**soft dep,query-only,零 API contract**;forward constraint → #26 register group(#26 GDD 已載「supporting cast」約束) |
| **#3 Persistence** | 無 | — | #21 **stateless presentation** — 零 persistence 寫入;reveal pending 係 #15(`loot.pending.*`)+ GSM(`gsm.loot_reveal_pending`)own |
| **#19 Zone** | 無(explicit non-goal) | — | Zone unlock ceremony = non-item reward,P-05「When NOT to Use」明文排除;#19 `drain_ceremony_queue()` 嘅 aggregated reveal 屬 post-workout summary surface(#20/#29),唔係 #21 |

## Formulas

> **Authoritative scope**:rarity 計算(`loot_rarity_score` / `workout_score` / `rng_roll` / tier thresholds)全部 ADR-0005 + #15 own — #21 唔 re-derive。本節只定義 **#21-owned presentation formulas**:timeline budget、breakdown bar 幾何、catch-up 時長、toast aggregation、fast-complete、stash budget。
> **Grep-verified 發現(systems-designer 2026-06-06)**:① #6 `MAX_PAUSE_SEC=0.12`(`screen_effects.gd:55`)會 clamp 死 RARE/EPIC/LEGENDARY time-stop — `ceremony_freeze` 必須係 #6 新 API entry point,有**自己嘅 `CEREMONY_FREEZE_MAX_SEC=0.4`**,共用 ledger 但唔受 `MAX_PAUSE_SEC` 管(hit pause 0.12 ceiling 理由係「無 visual anchor 嘅 freeze 似 hang」;ceremony 期間 modal layer ALWAYS + burst 動畫做 anchor)→ G-LM-3 amendment spec。② `ReceiveResult` 五值 enum 證實(`equipment_enums.gd:56-62`),`FAILED_ROLLBACK` 真假 ambiguous(re-entrant defer path 都 return 佢 — `inventory_system.gd:161-163`)。③ Camera Rule 5 re-entry = silent DROP(行為 @ `camera_controller.gd:194-198`,counter declaration @ :99 — Pass 1 cite 精確化;有 `push_warning`,唔係完全 silent,但 caller 冇 callback)。④(Pass 1 補)「共用 ledger」係 amendment 目標形態 — shipped 記帳係單一 scalar `_pause_remaining_sec`(`:111`),ledger 本身屬 G-LM-3 新建。

### F1 — `blocking_attention_timeline`(per-tier 時間預算)

**結構(satisfiability 嘅唯一解,寫死防止將來被「優化」成 additive)**:S2 內 hold 同 time-stop **sequential,順序 = S2a hold/focal-push → S2b freeze @ peak**(D2 freeze-as-hold:camera push-in 行足 D_hold 到 peak,`focal_completed` 觸發 freeze — 推鏡入 peak 然後快門凍結;總和 match #15 L1059 additive arithmetic,順序係 #21 Pass 1 裁決);**S1 entry 同成個 S2 concurrent**(三 track 同時由 T=0 起跑)。S1 如 additive,LEGENDARY = 450+400+800 = 1650ms > ceiling — overlap 係必要條件。T=0 = reveal-start frame(S0 burst 同 frame);FR-2 嘅 trigger→S0 ≤100ms latency 唔計入 budget。

`T_block(tier) = max(D_entry(tier), D_hold(tier) + D_timestop(tier))`

**Constraint C1**:`D_entry(tier) ≤ D_hold(tier) + D_timestop(tier)` ∀ tier(成立時 `T_block = D_hold + D_timestop`,同 #15 一致)
**Freeze 錨點**:EPIC/LEG = `focal_completed` signal(fallback timer T=D_hold+0.2s — #7 bug 時照 freeze,telemetry `loot_reveal.focal_anchor_fallback`);RARE/C-U = clock T=D_hold(RARE pulse 0.3s 早完,freeze 照錨 hold 結束;C/U D_timestop=0 無 freeze)。Focal entry duration 同 D_hold 同源(#15 table:EPIC 0.65s/LEG 0.8s == hold 650/800ms),budget 算術唔受 signal jitter 影響(assert 用 nominal config 數)。
**Hard assert**:`T_block(tier) ≤ ATTENTION_CEILING_MS` ∀ tier — **CI/data-load assert,唔用 runtime clamp**(clamp 靜默壓扁 ladder);ceiling 必須係 `≤`(LEGENDARY equality touch — `<` 即不可達 binding,satisfiability 教訓)

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| entry 時長 | D_entry | float ms | 150–450(per-tier knob,#21 own) | S1 scale-in |
| time-stop 窗 | D_timestop | float ms | 0–400(**#15 ladder locked**) | S2a freeze |
| hold 窗 | D_hold | float ms | 200–800(**#15 ladder locked**) | S2b hold |
| attention ceiling | ATTENTION_CEILING_MS | int ms | 1200(locked,#15 Pillar 2) | blocking 上限 |

**Per-tier timeline(sum column = T_block):**
| Tier | D_entry | S2a hold/focal | S2b timestop | **T_block** | ≤1200 | C1 |
|---|---|---|---|---|---|---|
| COMMON | 150 | 200 | 0 | **200** | ✓ | ✓ |
| UNCOMMON | 200 | 350 | 0 | **350** | ✓ | ✓ |
| RARE | 300 | 500 | 150 | **650** | ✓ | ✓ |
| EPIC | 380 | 650 | 300 | **950** | ✓ | ✓ |
| LEGENDARY | 450 | 800 | 400 | **1200** | ✓(equality) | ✓ |

**Output Range:** [200, 1200] ms。S4 exit(≤200ms)+ inter-reveal gap 唔計入 budget;saturation 2.0s recovery 屬 non-blocking ambient(#15 已定)。
**Example(LEGENDARY,D2):** T=0 burst + fanfare + entry 開始 + `request_focal(anchor, 0.8, 1.08)`(camera push-in = S2a);T=450ms content final;T=800ms `focal_completed` → `ceremony_freeze(0.4)`(camera 釘喺 peak — pause-bound exit tween 被凍);T=1200ms freeze 自然 expiry(INV-M1 單一出口)→ 入 S3,focal exit tween 喺 S3 背景行完(0.5s,non-blocking)。
**motion_reduction variant:** D_timestop=0 全 tier ⇒ `T_block = max(D_entry, D_hold)` = 200/350/500/650/**800** ms — ladder 單調性保留。

### F2 — `breakdown_bar_geometry`(RARE+ 75/25 可視化,ADR-0005 binding)

Normalize 分母 = `loot_rarity_score`(兩段恆等填滿 bar):

```
Evaluation order(Pass 1 釘死):① clamp-on-read ws/rr → [0,1] ② EC-M15 identity/tier gate(corrupt → 隱藏 bar,
  唔入幾何 — score=0 / div-by-zero 喺呢度截)③ 幾何:
contrib_w = 0.75 × workout_score          contrib_r = 0.25 × rng_roll
frac_w = contrib_w / score                frac_r = 1 − frac_w
px_w = round(frac_w × W_bar)              px_r = W_bar − px_w
pct_w = round_half_up(frac_w × 100)
Honest-endpoint clamp(Pass 1 — rr=0.01 round 到 100/0 係假 claim;rr=0 嘅 100/0 先係真):
  if contrib_r > 0: pct_w = min(pct_w, 99);  if contrib_w > 0: pct_w = max(pct_w, 1)
  px 同步:contrib_r > 0 ⇒ px_r = max(px_r, 1)
pct_r = 100 − pct_w     ← 保證 sum=100
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

**Output Range:** px_w ∈ [0, W_bar];**兩 contrib 均 >0 時 pct ∈ [1,99]**(clamp 保證);contrib 真零(rr=0 / ws=0)先准 0/100 端點 — 嗰陣「運氣 0%」係真 claim(Pass 1:ws=0.8/rr=0 → score=0.6 legal → 100/0 誠實顯示;rr=0.01 → clamp 到 99/1)。sum=100 恆成立。
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
| banner beat | T_banner_beat | float s | 0.3 | banner→stream 過場(Pass 1 補:原公式用咗但 table 冇) |
| stream cadence | C_stream | float s | 0.15(#15 locked) | 每件 beat |
| stream cap | MAX_STREAM_BEATS | int | 40 | 溢出折入 grid |
| ceremony cap | K_CEREMONY_MAX | int | 5 | full ceremony 上限 |
| gap(per-ceremony) | G_gap(i) | float s | 0.3 / 0.6 | 上一件係 EPIC+ → `FOCAL_EXIT_MARGIN_SEC`(0.6);否則 `INTER_REVEAL_GAP_SEC`(0.3)— EC-M9 |
| grid entry | T_grid | float s | 0.5 | contact-sheet 入場 |

**Output Range:** `T_machine ∈ [~1.55, 15.8]s`(provable bound:0.3 + 40×0.15 + 5×(0.6+1.2) + 0.5 = 15.8s worst-case 全 EPIC+ ceremonies — cap 本身 enforce bound,唔使 runtime time-projection;**下界修正(Pass 1)**:threshold ≥5 ⇒ 實際 min ≈ 0.3+5×0.15+0.5 = 1.55s,原 0.8 不可達)。T_machine **唔計 player tap**(RARE+ tap-paced);**EC-M9 watchdog degraded path 除外**(fake/壞 #7 下 watchdog 1.5s/件 — bound 以 #7 正常 emit `focal_completed` 為前提)。
**Example(30 件 boot force-reveal:14C+10U+4R+1E+1L — RARE+ 共 6 件 > K=5,cap 觸發):** ceremony 揀選 top-5 tier 降序 = L+E+3R,**第 4 件 R 折入 grid(獨立 cell + rarity label,non-ceremony — C-1)**;stream 24×0.15=3.6s;ceremonies(reveal ascending:R,R,R,E,L;gaps 0.3/0.3/0.3/0.3/0.6 — L 前一件 E 係 EPIC+)= 3×(0.3+0.65)+(0.3+0.95)+(0.6+1.2)= 5.9s;grid 0.5;banner 0.3 → **T_machine = 10.3s**,+5 taps ≈12.8s perceived。120 件 sub-RARE → stream cap 6.0s,80 件折入 grid「+80」(sub-RARE 先准 collapse)。
(注意:registry `lootdrop_pending_hard_cap_days=30` 係 **days** 唔係件數 — 唔好混淆。)

### F4 — `toast_aggregation`(micro_ack / deferred-ack)

```
N_agg=1 → icon + tier tint(無文字);≥2 → icon + 「×N」badge;>99 → 「×99+」;tint/icon = 最高 tier 嗰件
Merge(toast visible 時新 ack):if (TOAST_MAX_LIFETIME − elapsed) ≥ MERGE_MIN_REMAIN:
  N_agg += 1;remaining := max(remaining, MERGE_MIN_REMAIN)
else(Pass 1 — merge-vs-cap 邊界釘死,MERGE_MIN_REMAIN 嘅 acknowledge 保證唔俾 cap 靜默打破):
  該 ack 唔 merge → 直入 carryover bucket
Instance hard cap:TOAST_MAX_LIFETIME — 到 cap 即 fade;fade 完以 carryover N 開新 toast
守恆定義(AC-49 ground truth):Σ N_agg(所有 displayed instances)+ pending carryover == total acks 收到數
Flush gate(qa-lead gap-fix + art-director conflict 統一解 2026-06-06):
  flush 條件 = modal 完全 close(S4 / stash-exit / catch-up exit)後 FLUSH_DELAY **且 GSM ∈ LOOT_REVEAL_SAFE_STATES 對應嘅 player-attention-safe 集(IDLE / REST_PERIOD / DISCONNECTED)**
  GSM 唔喺 safe state(stash-exit 場景 / mid-workout micro_ack)→ hold + 繼續 aggregate,下次 safe-state entry 先 flush
  ⇒ 同時滿足 #15 L1081「workout 進行中零 toast/overlay」+ Rule 8「下次 safe state 出 ack」,#15 零 erratum
Instance 時間結構:entry(TOAST_ENTRY_SEC)→ visible plateau(TOAST_VISIBLE_SEC)→ fade-out(TOAST_FADE_SEC)
```

**Variables:** `TOAST_ENTRY_SEC=0.15` / `TOAST_VISIBLE_SEC=1.2`(plateau,唔包 entry/fade)· `TOAST_FADE_SEC=0.15` · `MERGE_MIN_REMAIN=0.6` · `TOAST_MAX_LIFETIME=3.0` · `FLUSH_DELAY=0.1` · N_disp ∈ 1–99+
**Output Range(Pass 1 修正):** toast instance 壽命 normal ∈ [1.5, 3.15]s(min = entry 0.15 + plateau 1.2 + fade 0.15;max = cap 3.0 + fade 0.15);EC-M17 interrupt fade(0.1s)例外可 <1.5s。
**Example:** modal 期間 3 ack → defer;terminal dismiss 後 0.1s(且 GSM safe state)出最高-tier-tint「×3」toast 配 toast tick(low/mono)。

### F5 — `fast_complete_snap`(two-stage tap 嘅 stage-1)

```
Tap 有效窗:t_tap ∈ [D_entry, T_block) ⇒ fast-complete;t_tap < D_entry 一律 ignore(content 未 final + 兜 tap-through)
Boundary tiebreak(Pass 1):state 以 frame 開始時評估 — tap 落喺 ladder 完成嗰 frame = fast-complete(防 fake-clock flaky)
Snap:freeze active → 即 frame release;freeze 未 issue → 唔 issue(skip)— 兩種行 INV-M1 出口;
  in-flight tween snap-to-final over SNAP_SEC(0.1s — 唔用 0-frame,0-frame 只留俾 rollback)
S3 entry(D5 clamp,Pass 1):S3_entry = min(t_tap + SNAP_SEC, T_block) — fast-complete 永不慢過 natural;
  同 frame 雙路 race(snap 完成 == ladder 完成)→ natural completion supersede,S3 side effects exactly-once
Debounce(錨點統一 = S3 entry,Pass 1 — 原 AC-15 S2-tap 錨同 F5 矛盾):S3_entry 後 DISMISS_DEBOUNCE_SEC(0.25s)內
  dismiss tap ignore(min-readable:terminal frame 至少被見 0.25s);natural 到達 S3(冇 fast-complete)零 lockout
T_block_fast = S3_entry ∈ [D_entry + SNAP_SEC, T_block]
```

**Example(LEGENDARY):** tap@500ms → S3@600ms、最早 dismiss@850ms — 慳 600ms,tap-spam 跳唔過 0.25s readable window。tap@1150ms → S3 @ min(1250, 1200) = **1200ms**(clamp — 唔會慢過 natural)。

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| tap 時刻 | t_tap | float ms | [D_entry, T_block) | 自 T=0 |
| snap 時長 | SNAP_SEC | float s | 0.05–0.2(knob) | in-flight tween snap-to-final |
| debounce | DISMISS_DEBOUNCE_SEC | float s | 0.15–0.4(knob) | S3_entry 錨 lockout |

### F6 — `stash_exit_budget`

`T_stash = freeze_release(同 frame)+ T_collapse(0.2s)+ jitter margin(0.1s ≈ 6 frames@60fps)≤ 0.3s ✓`;release 必須 **idempotent**(#6 Suspended override 可能已 release — EC-M1)。**Scope(Pass 1)**:F6 只適用 post-S3 stash-exit;pre-S3 force-close 行 ≤1 frame cancel(Rule 8),唔行 collapse anim。SUSPENDED-triggered → 跳 anim 即 emit(Rule 8)。

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| collapse 時長 | T_collapse / STASH_COLLAPSE_SEC | float s | 0.1–0.2(knob;上限受 budget 綁) | stash 收埋 anim |
| jitter margin | — | float s | 0.1(fixed) | 6 frames@60fps |
| budget 上限 | — | float s | 0.3(locked) | 外部 transition 唔等得耐 |

## Edge Cases

> Rules 已 cover:rollback mid-ceremony / queued rollback / empty-queue entry(Rule 13)/ banner 同 modal 並存(Rule 12)/ force-close idempotent(Rule 8)。以下係 systems-designer formula+rule space sweep(EC-M1–M20),全部 grep-verified against shipped code。

- **EC-M1 — bfcache/suspend 喺 S2 freeze 中途**:**If** GSM 喺 S2b freeze 內轉 SUSPENDED:#6 Suspended override(`screen_effects.gd:362`)自己 hard-cancel freeze 還原 timescale;#21 行 INV-M1 出口但 **release 必須 idempotent**(ledger 已被 #6 清 → no-op)。Resume 跟 #15 threshold:delta ≤30s(`BFCACHE_CONTINUE_THRESHOLD_MS`)→ **直接重入 S3**(content 已 final;S3 entry 照 fire receive_loot/INV-M3 commit;**嚴禁 re-issue `ceremony_freeze`**);>30s → **pre-S3 cancel 語意**(D1:未 banked、唔 emit、留 pending 計入下次 reveal/catch-up — re-reveal 誠實)。Suspend 落 S3/S4(post-banked)→ Rule 8 SUSPENDED clause(跳 anim 即 emit)。**Freeze 狀態永不 survive suspend boundary。**
- **EC-M2 — `ceremony_freeze` 被 reject(#6 BOOTING/SUSPENDED 唔 serviceable)**:**If** call 被拒(`screen_effects.gd:344-346` pattern):ceremony **降級照行** — 無 time-stop,用 F1 motion_reduction variant timeline,telemetry `loot_reveal.freeze_rejected`。Reveal 係 Pillar 3 hard guarantee,time-stop 係 garnish。
- **EC-M3 — freeze ledger contention**:**If** call 時已有 active freeze(理論上 safe states 排除 combat,defensive):max-remaining semantics(#6 Story 004 同款)— 延長至 max(remaining, requested);INV-M1 只清自己 entry。
- **EC-M4 — motion_reduction × ladder**:**If** on:D_timestop=0 全 tier(F1 variant);**完全唔 call `request_focal`**(#15 §D camera 改 fade-in vignette — EC-M9 整類消失);shake 0;particle ×0.5;hold / dismiss / queue 行為不變。
- **EC-M5 — unknown rarity_tier string**:**If** `rarity_tier` 唔喺 enum:`RarityTier.get(s, COMMON)` coercion — **同 #17 一模一樣**(`inventory_system.gd:180`),保證 modal 顯示 tier == inventory 入庫 tier。COMMON ceremony、無 breakdown bar、telemetry `loot_reveal.unknown_tier`;coerce 喺 ladder lookup **之前**。
- **EC-M6 — `get_drop()` 回 null(dangling drop_id)**:**If** null:skip 該件 — CRITICAL telemetry `loot_reveal.dangling_drop`,唔開 modal、唔 call `receive_loot`,`INTER_REVEAL_GAP` 後 advance;如係 terminal item → 行 terminal dismiss 出口。Placeholder modal = fabrication,禁止。
- **EC-M7 — GSM force-close 落 catch-up 各 phase**:**If** CATCHUP_PROMPT:banner 收埋、零 commit、全部留 pending(Pass 1 補 — 原文冇 prompt phase)。**If** stream 中:**force-close 嗰刻就係 batch commit point**(Rule 7 — 已 display beats 單一 frame 連發 commit;in-flight 未 display → 留 pending)— 已 commit 唔 re-reveal。**If** ceremony 中:per-item 語意 — pre-S3 cancel 留 pending / post-S3 stash(Rule 8)。**If** grid 中:grid 係 post-commit summary → 直接收埋,零 data 影響。全 phase:terminal emit → #15 `loot_confirmed`(除 pre-S3 ceremony cancel — 嗰下唔 emit,GSM retry 語意接手)。
- **EC-M8 — 新 drop / micro_ack 嚟喺 catch-up 中途(phase-gated append)**:**If** 新 drop:只可加入**未完**phase — sub-RARE → append stream 尾(受 `MAX_STREAM_BEATS` cap);RARE+ → 插入 ascending 序(受 `K_CEREMONY_MAX` cap;**cap 已滿 → 留 pending,唔入 grid**(Pass 1 釘:grid 係本次 session 嘅 commit summary,mid-flight 新件未 commit — 下次 catch-up 以 full ceremony 機會重現,保 C-1 identity));phase 已過 → 留 pending,exit 時 F4 flush。**Phase 唔回頭 = catch-up 保證 terminate。**
- **EC-M9 — 連續兩件 EPIC+(focal 重入)**:**If** reveal i 嘅 focal lifecycle 仲未完(**grep ground truth(Pass 1 修正):`focal_completed` 喺 entry tween 完成嗰刻 emit(`camera_controller.gd:364-376`),之後 0.5s exit tween 期間 `_lifecycle_state` 仍係 FOCAL,re-entry 照 silent DROP;「focal 剩餘」無 public API 可查 — 原「gate 喺 focal_completed」修唔到自己想修嘅 bug**)而 i+1 `request_focal` → 第二件無聲冇 ritual。**Resolution(deterministic margin,唔靠 API)**:上一件係 EPIC+ 時 inter-reveal gap = `FOCAL_EXIT_MARGIN_SEC`(0.6,knob)— timeline 推導:exit tween 喺 freeze 期間被凍,S3 entry 起計 0.5s 完;下一件 request 最早 = S3 + S4(0.2)+ gap(0.6)= S3+0.8 > S3+0.5 ✓ margin 0.3s。Knob 值約束:**必須 ≥ #7 `FOCAL_EXIT_DURATION`(0.5)− `EXIT_ANIM_SEC` + 0.1s margin**(G-flag grep #7 const 確認,值變要重驗)。**Watchdog `FOCAL_WATCHDOG_SEC`(1.5s)留做 freeze-錨 fallback**(`focal_completed` 冇 emit → T=D_hold+0.2s 照 freeze,F1;queue 永不鎖死,telemetry `loot_reveal.focal_watchdog`)。
- **EC-M10 — DISCONNECTED state reveal**:**If** 喺 DISCONNECTED(safe state 之一)觸發:**UX 同 connected 完全一樣,零特殊處理** — `receive_loot()` 純 local(grep 證實無 HTTP);backend sync 係 #15/ADR-0003 reconciliation own。唔顯示 sync spinner / badge — Pillar 2 唔輸出 infra 焦慮。
- **EC-M11 — mid-modal safe→safe 轉換(如 DISCONNECTED→IDLE reconnect)**:**If** 發生:**繼續,唔 force-close** — safe set 只喺 entry 檢查;只有轉出 safe set 先觸發 stash-exit。
- **EC-M12 — viewport resize / 手機轉向 mid-modal**:**If** resize:anchor/container 一 frame re-layout;breakdown bar 用新 W_bar 重行 F2(< W_BAR_MIN → stacked text-only variant);timer 全部 time-based 不受影響;particle 唔 replay;focal clamp #7 Story 008 已兜。
- **EC-M13 — boot force-reveal × catch-up threshold 同時觸發**:**If** 同時成立:**單一 entry point** — boot 讀一次 queue depth,exclusive branch(0 件 → 唔入;1–4 → sequential;≥5 → catch-up);force-transition 只決定**幾時**入 LOOT_DROP,flow 由 queue depth 單獨決定。Assert:banner 同 sequential queue 永不同時啟動。
- **EC-M14 — S3 `receive_loot()` 五個 `ReceiveResult` variant**(`equipment_enums.gd:56-62`):
  - **`OK`**:正常。
  - **`FAILED_ROLLBACK`**:**零 user-visible 動作,照常 dismiss** + CRITICAL telemetry `loot_reveal.receive_failed` + **call `LootDropSystem.report_receive_failure(drop_id)`(Rule 7 — #15 寫 `loot.pending.recovery`,#17 EC-1 boot-drain 鏈保全;Pass 1 修正:原文淨 telemetry 會斬斷 recovery chain → 真 hydration failure = 真 loot loss)**。理由:(a) 真 failure 時 #15 recovery boot-drain 保證 eventual grant(而家鏈真係接通);(b) re-entrant defer path 都 return 呢個值(`inventory_system.gd:161-163`)— 真假分唔到,出 error UI 會對 defer path 假報警(report 對 defer path 係 no-op class — #15 handler 自己 dedupe)。
  - **`QUEUED_SUSPENDED`**:suspend × S3 同 frame race — 當 success(durably parked,resume FIFO drain),行 stash-exit。
  - **`DUPLICATE_NOOP`**:replay — 當 success,telemetry counter,**唔出第二個 micro_ack**。
  - **`CONVERTED_DUPE`**:正常 dismiss;**shard-icon ack 入 F4 deferred aggregate**(#21 self-sourced ack — F4 計埋自家 source;intra-queue 時 GSM 仍喺 LOOT_DROP 非 safe state,實際 flush 喺 terminal + safe-state entry — Pass 1 措辭修正,原「S4 後即出」唔過 F4 gate)。誠實閉環。
- **EC-M15 — breakdown 數據 corrupt**:**If** ws/rr 出 [0,1]:clamp 先入 F2。**If** `|0.75ws+0.25rr − score| > 0.001` 或 score 同 tier threshold 矛盾:**信 #15 tier,隱藏 bar**,telemetry `loot_reveal.breakdown_mismatch` — bar 同 tier 矛盾比冇 bar 更傷 Pillar 1 claim。
- **EC-M16 — rollback 打中 catch-up stream**:**If** 目標係當前/已 display 但 batch 未 fire 嘅 beat:≤1 frame cancel 該 beat、跳下一 beat、aggregate count −1、**該件唔入 batch commit**(Rule 7 batch 語意);batch 已 fire(stream-end 後)→ 屬 #17/#15 post-grant rollback path;未 stream → 既有 queued-rollback rule(Rule 11)。
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
| **#7 Camera** | Hard(contract)/ graceful-degrade(runtime) | RARE pulse + EPIC/LEG focal;`focal_completed` = freeze 錨點(D2) | F1 fallback timer:T=D_hold+0.2s 照 freeze;EC-M9 margin + watchdog |
| **#26 AvatarRenderer** | Soft(group query,零 API) | `reveal_anchor_pos` 來源(Rule 4) | group 缺位 → viewport center fallback |
| **#4 Audio** | **Hard**(P3 唯一 audio peak + colorblind rarity backup channel) | `loot_fanfare_{tier}` @ S0(caller = #21);toast 配 tick(low/mono) | Silent-mode fallback chain:badge shape + label + hold(Visual/Audio §G) |
| **#33 AttentionBudget** | Soft | exempt handler pattern 引用;#21 唔 query predicate | #33 缺位 tap 照收 |
| **#20 HUD** | Soft(GSM-mediated,零 direct contract) | defer/un-dim 同步靠 GSM state | #20 缺位無影響 |
| **PlatformDetect** | Hard(web)/ no-op(native) | `announce_aria()` a11y gateway(#15 approved 約束) | G-LM-6 未落地 → AC gated |
| **#3 Persistence** | **無依賴** | #21 stateless presentation,零寫入 | — |

### Downstream(依賴 #21)

| 系統 | 期望 |
|------|------|
| **#15** | `modal_dismissed(drop_id, terminal)` emit-back(dequeue + terminal → `loot_confirmed`)+ `report_receive_failure` — G-LM-4 |
| **#17** | reveal handoff 時序(S3 = #17 GDD 嘅「reveal handoff」語意載體) |
| **#28 Telemetry** | Rule 15 telemetry hooks(skip / time-to-dismiss / stash / catchup-abandon + EC error events) |
| **#26 AvatarRenderer** | 無 API 依賴;P3 約束「avatar effects 永遠係 #21 嘅 supporting cast」(#26 GDD 已載) |
| **#22 / #23** | P-06 rarity 語言共用(pattern 級,非 API) |

### Cross-system gates(G-LM-1..9 — epic 執行;G-LM-3/4 Pass 1 重寫,G-LM-8/9 Pass 1 新增)

| Gate | 內容 | 對象 |
|------|------|------|
| **G-LM-1** | ADR-0001 revision:topology 加 `CelebrationVFXLayer`(110, ALWAYS, follow_viewport)+ `ModalLayer`(120, ALWAYS);註明 >100 = BackBufferCopy capture 外(saturation/shake immune);cite L109 HUD knob 先例;**Pass 1 補**:① 釘實 layer 嘅 viewport residence — `follow_viewport` 只喺同 Camera2D 同一 viewport 先有意義(world content 如最終入 SubViewport,autoload layer 掛 root viewport 嘅 anchor 映射要明文)② modal 8% local blur = 第二次 framebuffer copy(Compatibility/WebGL2)— priced 入 budget 或 opacity-only fallback | ADR-0001 |
| **G-LM-2** | #5 amendment:LOOT preset pool nodes reparent 入 CelebrationVFXLayer + per-slot `PROCESS_MODE_ALWAYS`(現時 INHERIT + layer 0 — freeze 時 burst 凍結 + 被 saturation 降格雙 bug) | #5 + `particle_system_wrapper.gd` |
| **G-LM-3** | #6 amendment(**Pass 1 重寫 — scope 遠大過原 gate text**):① 新 `ceremony_freeze(duration)` API — `CEREMONY_FREEZE_MAX_SEC=0.4` ceiling,唔受 `MAX_PAUSE_SEC=0.12` 管 ② **freeze 記帳由 shipped 單一 scalar(`_pause_remaining_sec`,`screen_effects.gd:111`)重構成 per-entry ledger**(max-remaining merge;「只清自己 entry」要真 ledger 先有意義)③ **新 idempotent 早收 `release(handle)` API**(shipped 只有自然 expiry — INV-M1 出口而家連 API 都未存在)④ **saturation API 全新**(shipped #6 零 saturation 實現;world −60% desaturation 行 shader uniform path)⑤ 繼承 Suspended/focus-resume 安全網;⑥ stray `hit_pause` 唔可以截斷 ceremony freeze(ledger 隔離) | #6 + `screen_effects.gd` |
| **G-LM-4** | #15 reverse-wire story(**Pass 1 重寫 — 核心 scope,唔係順帶**):① **revealed-state 同 sync-state 分離**(backend ACK 永不將 unrevealed drop 移出 reveal queue;reveal dequeue 永不 skip `loot.pending`→`loot.committed` rename — `loot_drop_system.gd:766-779` 雙語意拆解)② **ceremony kind 持久化**(FULL_CEREMONY/MICRO_ACK — `get_pending_drops()` 對 reveal flow 只回 FULL_CEREMONY)③ `modal_dismissed(drop_id, terminal)` handler(**以 drop_id dequeue**)④ terminal → emit `loot_confirmed`(GSM exit chain)⑤ 新 `report_receive_failure(drop_id)` handler(寫 `loot.pending.recovery` — #17 EC-1 鏈)⑥ defer/exit retry-suppression(同一 safe-state occupancy 唔 re-trigger banner;`_check_pending_loot_reveal()` @ gsm:446 現時零 caller,GSM-side wiring 同 story 一齊做)⑦ #4 catalog source 列 #15→#21 sync | #15 + `loot_drop_system.gd`(+ GSM wiring) |
| **G-LM-5** | ADR-0008 insertion:`LootRevealCoordinator` tail append 喺 ZoneSystem 後(#28 keep last);predecessor constraints:`{#15, #1(C6), #33, Camera, ScreenEffects, Particle, Audio, PlatformDetect} ≺ #21` | ADR-0008 + `project.godot` |
| **G-LM-6** | `platform_detect.gd` **新增** `announce_aria(text)` gateway(Pass 1 措辭修正:grep 零 aria match — 唔係 stub,係未存在)(boot 時 inject hidden `aria-live` div — live region 必須 first announcement 前存在於 DOM;story 先 verify 4.6 web build 有冇 native a11y tree 防 double-announcement) | platform_detect story |
| **G-LM-7** | `interaction-patterns.md` 更新:P-05 撤 5s auto-dismiss + ladder 數值 sync #15 + OQ-P3 close;P-06 hex 確認(ux-designer 已認領) | design/ux |
| **G-LM-8** | **#4 catalog co-design(Pass 1 新增)**:4 新 cue 入 catalog freeze 表 + `SfxCatalog.tres` — event_id / priority / channels 齊(建議:shutter = mid/mono/no-duck「儀式錨點唔俾 combat-class 食」;contactsheet/stash/tick = low/mono;stream aggregated cue = low/單 duck handle);voice pool concurrency 重估(catch-up 包絡);audio-director sign-off;lint scope 裁決(原 OQ-4 併入) | #4 + `SfxCatalog.tres` |
| **G-LM-9** | **#4 process-mode amendment(Pass 1 新增)**:AudioManager(或最少 SFX pool players)+ LootRevealCoordinator 本體 `PROCESS_MODE_ALWAYS` — `ceremony_freeze` 用 `get_tree().paused`,PAUSABLE audio 喺 freeze 期間 stutter(fanfare 啱起音即停 0.4s 喺 dopamine peak;AC-16 spy 結構上驗唔到 engine pause,要 property assert);註:`tools/ci/check_autoload_process_modes.gd` 未存在,whitelist lint 一併開 | #4 + `audio_manager.gd` + `project.godot` |

### Epic 驗證 flags(G-flag-1..4 — 裁決成立嘅 shipped-code 前提,story-readiness 時 grep;**Pass 1 已 grep 部分,結果如下**)

1. **G-flag-1**:player tap dismiss 唔受 `MIN_REVEAL_WINDOW`(15s)阻 — dismiss 係 completion 唔係 interruption(GSM AC-11b 字面支持,要 code 證實)— **未 grep,epic 時做**
2. **G-flag-2**:`_check_pending_loot_reveal()` 機制 — **Pass 1 grep 結果:function 存在(`game_state_machine.gd:446`)但零 caller,GSM Rule 13 wiring 未完成 → 併入 G-LM-4 story scope(連 defer retry-suppression 一齊)**
3. **G-flag-3**:GSM LOOT_DROP exit path — **Pass 1 grep 已解:locked 機制 = #15 emit `loot_confirmed` → GSM 訂閱 exit(GSM L234/L363/AC-14 zero-direct-call),#21 設計已對齊(Rule 6)**。剩餘 scope:intra-queue 唔 exit 嘅語意確認 + **drain cadence(GSM L128「只 drain ONE」erratum — Rule 6 已裁 #21 supersede,erratum 出咗先算閂)**
4. **G-flag-4(Pass 1 新增)**:#7 `FOCAL_EXIT_DURATION`(0.5)+ `_resolved_focal_duration` const 值 grep — `FOCAL_EXIT_MARGIN_SEC` knob 約束(EC-M9)依賴呢個數;#7 一改要重驗

### Bidirectional sync flags + Erratum drafts(Pass 1 — exit bar 第 5 項;upstream patch 喺 epic / 對應 gate story 執行)

**#15 GDD erratum draft(9 項)**:
1. `#21.cancel_reveal()` call 方向已被 shipped `loot_rollback` signal 取代
2. Visual Spec Table hex(L1031-1034 Material 套)→ art bible §4.B canonical(見 Visual/Audio §A)
3. micro_ack「0.15s toast」釐清為 entry beat(F4)
4. **L204「micro_ack 維持 audio sting(降一 tier)」→ 撤**:toast 一律配 toast tick(low/mono)— fanfare 音色家族獨家保留俾 modal(mid-set 無畫面 fanfare 違 Pillar 2;aggregated 跨 tier sting 無解)
5. **Visual Spec Table「Audio Duck」列 stale**:per-tier −3..−16dB 同 shipped #4 衝突(flat −8、safe range −12–0、−16 出界);L1052「還原到 0dB」錯(Music base = −6dB);duck 深度/release 係 #4 own;L1054 嘅 CI duck-verify 指示一併撤
6. **L1082 FR-2 anchor rebase**:「emit 後 100ms 內 visual onset」喺 deferred reveal 下不可滿足 → re-anchor 做「reveal-trigger 後 ≤100ms」(#21 stage table)
7. **L1102「所有 RARE+ 仍各自獨立 ceremony」**被 `K_CEREMONY_MAX=5` supersede(CD C-1 grid identity 保底)
8. **AC-18 + EC-28 catch-up 語意 stale**:「individual reveals skip in favor of single tap-to-burst」→ #21 contact-sheet model(stream + top-K ceremonies + grid)
9. **LEGENDARY orbit drift cut from MVP**(D2 — #7 冇 hold phase;freeze-as-hold 兌現「定格喺 peak」;v0.2 重訪)

**#17 GDD/code erratum draft(2 項)**:
1. `inventory_system.gd:145` doc comment +「#15 calls this after the #21 reveal handoff (modal dismissed)」+ #17 GDD reveal handoff 定義:caller = **#21 @ S3**(INV-M3,唔係 modal dismissed 時)
2. EC-1 recovery 鏈 locus:caller 唔直接寫 `loot.pending.recovery`(#21 stateless)— 經 #15 `report_receive_failure(drop_id)`(G-LM-4)

**#4 GDD erratum draft(2 項)**:
1. Catalog source 列:`loot_fanfare_*` 觸發 caller #15 → **#21 coordinator**(EG-1 precedent)
2. 新 cue entries(G-LM-8)+ AudioManager process-mode(G-LM-9)

**GSM(#1)GDD erratum draft(2 項)**:
1. **L128「每個 RestPeriod 只 drain ONE」**→ #21 Rule 6/10 supersede(intra-queue drain + catch-up;fatigue bound 由 F3 caps + per-item commit + force-close 兜)
2. **L375(b)「未開封 item tap entry」defer v0.2**(OQ-6 — 需要 #23 surface + 獨立 content-source 分支;L375 a/c/d 已兌現,見 Rule 13b)

**其他 sync**:
- **#5 GDD**:Section C #21 interaction contract + EC-18 嘅 [PROVISIONAL] 標記可 actualize(無 re-peek pattern,dedup by design;tier→preset mapping 確認 white/green/blue→LOOT_BURST、purple/orange→LOOT_RARE_BURST);Q-V4 部分閉;**G-LM-2 補 reparent 時序**:pool 喺 #5 boot add_child 到 wrapper,CelebrationVFXLayer 等 #21(tail)`_ready` 先存在 → reparent 行 post-#21-boot handshake(#5 expose `register_celebration_layer(layer)`,idempotent)
- **#7 GDD**:downstream #21 row actualize(API 零 change 維持成立 — D2;margin 係 #21-side knob)
- **#20 GDD**:Q-OQ6 可 close(exit 序 + banner stack priority + 唔加 direct notify — 本 GDD Rule 12 / Interactions #20 row)
- **#26 GDD**:forward constraint — avatar node register `avatar_anchor` group(Rule 4)
- **systems-index**:#21 row 更新 + 依賴實況(5, 15, 17 → 加 1/4/6/7/33 + soft 26 context)

## Tuning Knobs

> **唔係 #21 own 嘅(cite only,唔重印)**:hold / time-stop ladder(#15)、`ATTENTION_CEILING_MS=1200`(#15 Pillar 2)、`C_stream=0.15`(#15 Formula 6)、`CATCH_UP_THRESHOLD=5`(#15)、`ceremony_cap=6`(#15 Rule 6 — 注意同 `K_CEREMONY_MAX` 唔同層:前者係 per-workout emit cap,後者係 catch-up reveal cap)、`CEREMONY_FREEZE_MAX_SEC=0.4`(#6 amendment own,G-LM-3)、`MIN_REVEAL_WINDOW_SECONDS=15`(#1 GSM)。

### #21-owned knobs

| Knob | Default | Safe range | 效果 / 出界後果 |
|------|---------|-----------|----------------|
| `D_ENTRY_MS`(per-tier:C/U/R/E/L) | 150/200/300/380/450 | 每 tier 受 **C1 約束**:`D_entry ≤ D_timestop + D_hold` | 太低:entry 似 pop 冇 anticipation;太高:違 C1 → CI assert fail(F1) |
| `SNAP_SEC` | 0.1 | 0.05–0.2 | fast-complete tween snap 時長。太低:似 glitch;太高:skip 唔似 skip |
| `DISMISS_DEBOUNCE_SEC` | 0.25 | 0.15–0.4 | two-stage tap lockout。太低:mash 盲拆(terminal frame 冇人見);太高:dismiss 似 input lag |
| `INTER_REVEAL_GAP_SEC` | 0.3 | 0.2–0.8 | queue 件距。**互動**:上件 EPIC+ 時實際 gap = `max(呢個, FOCAL_EXIT_MARGIN_SEC)`(EC-M9) |
| `FOCAL_EXIT_MARGIN_SEC` | 0.6 | 0.6–1.0(**下限 locked:必須 ≥ #7 `FOCAL_EXIT_DURATION`(0.5)− `EXIT_ANIM_SEC` + 0.1 — G-flag-4**) | EPIC+ 後件距(deterministic margin,代替無 API 嘅「focal 剩餘」)。太低:#7 re-entry silent DROP 復發 |
| `STASH_COLLAPSE_SEC` | 0.2 | 0.1–**0.2**(Pass 1 修正 — 原上限 0.25 + jitter 0.1 = 0.35 > F6 budget 0.3,safe range 內 AC-51 會 fail) | stash-exit 收埋 anim。上限受 F6 budget(總 ≤0.3s)綁 |
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
| `FOCAL_WATCHDOG_SEC` | 1.5 | 1.0–2.5 | freeze-錨 fallback(F1:`focal_completed` 冇 emit → T=D_hold+0.2s 照 freeze)+ queue 防鎖。太低:正常 focal 被誤殺;太高:#7 bug 時 queue 卡耐 |

### Knob 互動 matrix(重點)

- `D_ENTRY_MS` ↑ 任一 tier 超 C1 → F1 CI assert fail(**設計上唔俾 runtime clamp**)
- `MAX_STREAM_BEATS` × `K_CEREMONY_MAX` × `INTER_REVEAL_GAP_SEC` × `FOCAL_EXIT_MARGIN_SEC` 共同決定 F3 bound — 改任何一個要重行 F3 worst-case
- `TOAST_VISIBLE_SEC` < `MERGE_MIN_REMAIN_SEC` 係 invalid 組合(merge 反而延長壽命)— data-load assert
- `EXIT_ANIM_SEC` + `INTER_REVEAL_GAP_SEC` 决定 intra-queue 件距 perceived 節奏;兩個都調高會令 3 件 queue 嘅總 perceived time 超 catch-up threshold 嘅體感 — 留意 F3 worked example 重算
- **Cross-reveal flash budget(Pass 1)**:`EXIT_ANIM_SEC` + `INTER_REVEAL_GAP_SEC` 調到 min(0.1+0.2)時 COMMON 連環 cycle 嘅 transient 密度(S0 burst + S4 快門 flash)可超 §C「≤3 flash/s」— data-load assert:`2 / (T_block_min + EXIT_ANIM + GAP) ≤ 3`
- `FOCAL_EXIT_MARGIN_SEC` 下限綁 #7 const(G-flag-4)— #7 調 `FOCAL_EXIT_DURATION` 要重驗

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
- **Catch-up stream(Pass 1 — 6.7 beats/s vs 上行 rule 嘅內部矛盾收線)**:stream beat = **luminance-stable**(icon slide + tier tint,**零 per-beat flash transient**);flash transient 只准 stream 開始同結束各一次。S4「1-2 frame」快門 flash 嘅實作語意 = **≥1 presented frame + time cap ~33ms**(time-based,唔係 frame count — 掉 frame 時保證有 frame 見到,30fps 機唔變長閃)。
- **Intra-queue 連環 cycle transient 密度受 knob matrix flash budget assert 綁**(見 Tuning Knobs)。

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

| Cue | Spec 方向(priority/channels 屬 G-LM-8 co-design,下列係 #21 建議) | Note |
|---|---|---|
| `sfx_loot_shutter_dismiss` | 快門 click ≤0.3s,**單一共用唔分 tier**(rarity 已由 sting 傳達);**mid/mono/no-duck**(儀式錨點唔俾 combat-class 食 — `audio_unlock_confirm` 升 mid 同構) | S4 核心,Flashbulb fantasy 錨點 |
| `sfx_loot_contactsheet_enter` | exposure sweep whoosh ≤0.6s;low/mono | 配 grid 入場 |
| Catch-up stream aggregated cue(Pass 1 新增,D4) | 單一 riser/coin-shower texture ≤stream 長度;low;**單一 duck handle 或唔 duck**;**禁止 per-beat fanfare** | Rule 10;catch-up 全程另落 −4dB sustained 淺 duck |
| Grid hero-cell sting | **條件化(Pass 1)**:只喺 hero 件未經 full ceremony 時播(全 sub-RARE catch-up);hero 件啱啱 ceremony 完 → 唔 replay(2 秒內同 peak 播兩次 = devaluation + self-overlap flam),grid 入場只用 whoosh | mixing rule forward constraint |
| `sfx_loot_stash_put` | **default silent(Pass 1)** — stash 觸發語境 = 玩家已唔望 mon、新 set 開始,出聲係 mid-set 噪音;acknowledgment 由 safe-state flush toast 承擔 | 低優先 |
| Toast tick | ≤0.15s;low/mono;safe-state-gated 下只喺 natural pause 出現,跟 #4 silent-mode soft-gate;`FLUSH_DELAY` 下限建議 0.15s(避開 #4 set_complete/streak_chime 80-120ms stagger window) | toast 一律 tick — fanfare 家族 modal 獨家(#15 L204 erratum) |

**Silent-mode(LOCKED)fallback chain(Pass 1 明文)**:#4 LOCKED 期間 `play_sfx` = drop + warn(唔 defer)— modal ceremony 喺 silent mode 下 sting channel 斷:rarity 傳達 fallback = badge shape + text label + hold 時長(P-06 三重編碼,colorblind + silent 雙重 degrade 都企得住);**首 session 首 reveal(boot force-reveal 早於首 gesture)接受首件靜音** — dismiss tap 兼任 unlock gesture,intra-queue 第二件起有聲;唔做 stale sting replay(#4 既有立場一致)。

**CI note**:新 cue catalog 登記 + lint scope 裁決全部歸 **G-LM-8**(原 OQ-4 併入)。

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
| 4 | Source attribution | 四 variant(Pass 1 +1 — GSM L375(c) 兌現):「來自 boss 擊殺」/「來自健身完成」/「來自 mini-boss 擊殺」/「**快勝**」(`BossPayload.outcome == INTERRUPTED_WITH_CREDIT` — fast-victory copy variant,ceremony ladder 照 tier 不變)+ provenance 數字行先(「180kg × 5 — Stamped」) |
| 5 | Breakdown bar(RARE+ only) | F2 幾何;`ui_amber_primary` vs `ui_ink_hi`;**% label 必須**(claim 唔依賴 pixel discrimination);**Layout(Pass 1 CJK fit 修正)**:bar 段內 label = 純數字「55%」/「45%」(數字行 m6x11,唔受 CJK 寬度綁);「汗水 / 運氣」legend 行喺 bar 上方獨立一行(Zpix 12px,自由寬度)— 原 side-by-side「汗水 55% / 運氣 45%」@Zpix ≈130px 闊過 W_BAR_MIN=120;COMMON/UNCOMMON 唔顯示 |
| 6 | Dismiss CTA | label「**影低佢**」(快門 framing — Rule 5);CTA visual ≥48px 但 **tap surface = 全屏 scrim**(Fitts + 汗手) |
| 7 | ScreenReader announcement | `"[Rarity] loot: [Item Name],來自 [source]. [Workout X%, RNG Y%]"`(RARE+ 先讀 breakdown);S3 fire 一次,`aria-live=assertive`,timing 唔受 motion_reduction 影響 |

(P-05 嘅 stat-delta ticker slot **MVP 唔做** — 依賴 #17 equip-result payload 未有 API;見 Open Questions OQ-1 + G-LM-7 P-05 更新。)

**Font 指派表(Pass 1 新增 — 原文只派 latin-only pixel font,render 唔到全 modal 嘅廣東話 copy)**:

| String 類 | Font | Size | Note |
|---|---|---|---|
| CJK strings(item name 中文 / caption / attribution / legend /「影低佢」/「稍後再拆」) | **Zpix** | **12px floor**(`accessibility-requirements.md:87` CJK body 標準) | 「一眼吸收」claim 嘅 render target;H1 hierarchy 由 position/weight 補(11px latin H1 < 12px CJK 係接受嘅 inversion) |
| Latin / 數字(「180kg × 5」/ %、×N badge / tier 英文名) | m6x11 | 11px | 原指派維持 |
| 細註(7px 級) | m5x7 | 7px | **latin/數字 only** — CJK 7px 不可讀,禁止 |

AC-84 加 CJK 截圖 variant(雙 font 混排 + 窄屏)。

### C. Glance hierarchy(疲勞場景優先序)

**Rarity → Item icon → Item name → Source → Breakdown** — 攰人第一個問題係「使唔使理?」:rarity 行三條時間線(burst 色 ~100ms → frame edge tint → badge),未讀字已知值唔值得睇真;icon 先過 name(picture superiority — 疲勞下讀 11px bitmap text 成本高);**單欄、單一 top→bottom 閱讀軸**,冇 side-by-side;attribution 係 Pillar 1 meaning layer 但係第二 fixation 嘅嘢。

### D. Input

- Two-stage tap(Rule 5);S0/S1/S4 一律 ignore tap(兜 tap-through — F5);#33 exempt handler;4.6 dual-focus 注意 — tap 直接食 `gui_input`/`pressed`,**唔依賴 focus state**(`grab_focus()` 4.6 只影響 keyboard)。
- Catch-up「稍後再拆」affordance:角落、≥48px、常駐(Pillar 2 never-trap);**獨立 Control 喺 scrim z-order 之上,input 優先**(Rule 10 — exit 語意:當前件 fast-complete → commit → 收埋,剩餘留 pending)。
- **Keyboard dismiss(Pass 1 新增 — desktop secondary platform)**:`ui_accept` == scrim tap 等價(同一 handler、同一 per-stage policy);catch-up exit 經 `ui_cancel`。Accessibility checklist「keyboard only」過關。

### E. Accessibility

- **motion_reduction matrix**(#15 §D + #21 增量):saturation drop / time-stop / shake 全 off;hold 保留;particle ×0.5;camera focal → fade-in vignette(`request_focal` 零 call — EC-M4);**S1 entry 改 150ms fade(無 scale 無 overshoot)— #15 §D 冇 cover entry,#21 增量**;two-stage tap 行為不變;flash 收單 1 frame。
- Color NOT sole indicator:tier = 色 + badge shape + hold 時長 + sting character(skip 唔 cut sting — Rule 5);toast tint enhancement-only。
- ARIA live region 經 `platform_detect.announce_aria()`(G-LM-6);region boot 時 inject(first announcement 前必須存在於 DOM);banner `role=status` polite,reveal announcement assertive。**Intra-queue 連環 reveal 用 short variant**(「[Rarity]:[Name]」— assertive 互斬下 full read 永遠讀唔完);**catch-up 收尾單一 aggregate announce**(「N 件 loot 已收,最高 [tier]」— stream 逐件零 announce,grid 一次)。
- 全部 user-facing string 行 `tr()`(i18n);micro-copy tone 跟 Player Fantasy 指引(present tense、零運氣動詞、數字行先)。
- Photosensitivity 規則見 Visual/Audio §C。

📌 **UX Flag — Loot Drop Modal**:本系統有完整 UI requirements。Phase 4(Pre-Production)run `/ux-design loot-drop-modal` 產生 per-screen UX spec **先寫 epics**;stories 引用 `design/ux/loot-drop-modal.md`,唔直接 cite GDD。P-05/P-06 更新(G-LM-7)由 ux-designer 認領。

## Acceptance Criteria

> **Test evidence 分流**(#20 先例):Logic/Integration = **BLOCKING**(headless GUT);Visual/Feel/UI = **ADVISORY**(screenshot/playtest + lead sign-off — 唔 pre-mergeable,唔做 merge gate)。依賴未落地 gate 嘅 AC 標 **[gated G-x]**(story-readiness 時 grep gate 狀態解封;全部 gated AC 有 #21-side 可先行斷言或 fake seam)。Evidence:unit = `tests/unit/loot_reveal/`、integration = `tests/integration/loot_reveal/`、manual = `production/qa/evidence/loot-drop-modal/`。
> **FR-2 100ms 拆法(明文,防 epic 誤寫 BLOCKING perf test)**:headless 量唔到 wall-clock → 拆做 structural same-frame call-order(AC-8 BLOCKING)+ 真 browser frame capture(AC-9 ADVISORY)。
> **EC-M3 ownership note**:freeze ledger max-remaining 語意由 G-LM-3 #6 amendment own — 主測試落 #6 story,AC-54 只係 #21-side integration smoke(防雙邊 own 同一斷言 drift)。

### A. Invariants

- **AC-1**(INV-M1,×4 parametrized):GIVEN 任一 tier reveal 喺 S2b freeze active(fake #6 seam;D2 下 freeze 窗 [D_hold, T_block) — production config tap@freeze 窗係可達,唔使注入特製 config),WHEN 行 4 個 cancel path 之一(fast-complete / `loot_rollback` / **pre-S3 force-close** / EC-M1 Suspended),THEN freeze entry release **exactly once** 且 4 path 經同一 release 出口(spy 單一 call-site)。*Logic · BLOCKING [release API gated G-LM-3]*
- **AC-2**(INV-M1 idempotent + 未-issue no-op):GIVEN ledger entry 已被 #6 Suspended override 清走 **或 freeze 從未 issue(tap 落 S2a)**,WHEN cancel path 行 release,THEN no-op 無 error 無 double-decrement。*Logic · BLOCKING*
- **AC-3**(INV-M2 邊界 sweep):GIVEN (ws,rr) ∈ [0,1]² 令 score ≥ 0.55(必含 score=0.55/rr=1.0 worst case),WHEN F2 計 px,THEN `px_w > px_r` 嚴格成立且 naive delta ≥8px @ W_bar ≥120。*Logic · BLOCKING*

### B. Core Rules

- **AC-4**(Rule 1):coordinator `_ready` 後持有 ModalLayer + CelebrationVFXLayer 且係唯一 instantiator;layer 數值 == ADR-0001 pinned。*Logic · BLOCKING(layer 數值斷言 [gated G-LM-1])*
- **AC-5**(Rule 2 唯一 trigger):GIVEN fake GSM `state_changed`→LOOT_DROP 且 queue 非空 THEN modal 開;其他 state 轉換或單獨 `loot_dropped`(GSM 非 LOOT_DROP)THEN 唔開。*Logic · BLOCKING*
- **AC-6**(Rule 2 boot):GIVEN boot 時 GSM 已喺 LOOT_DROP(force-reveal),WHEN `connect_for_initial_state` 接線,THEN 即收 sentinel 並開 modal。*Logic · BLOCKING*
- **AC-7**(doorbell no-op):GIVEN modal active,WHEN 新 `loot_dropped`,THEN 零 modal 動作(無第二 modal / FSM 重入)。*Logic · BLOCKING*
- **AC-8**(FR-2 structural):GIVEN reveal 開始,THEN #5 `play()` 喺 reveal-start **同一 call stack 同步**發出(無 await/timer 先行)且 preset per tier 正確(C/U/R→LOOT_BURST;E/L→LOOT_RARE_BURST)。*Logic · BLOCKING*
- **AC-9**(FR-2 wall-clock):真 web build frame capture,trigger→burst onset ≤100ms(6 frames@60fps)。*Visual/perf · manual · ADVISORY*
- **AC-10**(S1 content all-final):scale-in 完成 frame,**視覺 content slots(§B 1-6)**== final fixture 且零 active content tween(slot 7 SR announcement @ S3,唔屬 S1-final 範圍)。*Logic · BLOCKING*
- **AC-11**(per-stage input,×5):tap 喺 S0(t<D_entry)/S1/S4 一律 ignore;S2 → fast-complete;S3 → dismiss(S0/S1 ignore 兼兜 tap-through EC-M19)。*Logic · BLOCKING*
- **AC-12**(Rule 4 D2 調用序):LEGENDARY reveal(fake spies),調用序 = burst + fanfare(frame 0)→ `request_focal`(GSM==LOOT_DROP 後,T=0)→ **`focal_completed` 收到先** call `ceremony_freeze`(duration 由 #15 ladder config 讀,非 hardcode)→ shake;saturation call [gated G-LM-3 新 API]。fake #7 唔 emit `focal_completed` → fallback timer T=D_hold+0.2s 照 freeze + telemetry。*Logic · BLOCKING(freeze API shape [gated G-LM-3])*
- **AC-13**(focal per-tier config):COMMON/UNCOMMON 零 `request_focal`;RARE pulse / EPIC / LEGENDARY 各 call 一次,**args == #15 Visual Spec Table per-tier 數值(config 讀,零 hardcode literal — grep source 無 magic number)**。*Logic · BLOCKING*
- **AC-14**(無 auto-dismiss):S3 無 input,fake clock 推 60s,modal 仍 open、無 scheduled dismiss timer。*Logic · BLOCKING*
- **AC-15**(debounce,**錨點 = S3 entry** — Pass 1 統一 F5):S2 tap fast-complete @t → S3 @t+`SNAP_SEC`;第二 tap @S3+0.2s(<`DISMISS_DEBOUNCE_SEC`,讀 config)ignore;第三 tap @S3+0.3s dismiss。Natural 到達 S3(冇 fast-complete)→ 零 lockout,S3 entry 即 tap 即 dismiss。*Logic · BLOCKING*
- **AC-16**(fast-complete 副作用):S2 tap → content snap over `SNAP_SEC`、freeze active 即 frame release / 未 issue 唔 issue(spy:`ceremony_freeze` call count 不增)、particle `stop()` natural fade(非 hard-cut)、audio sting **零** stop/cut call(negative spy)、**fast-complete tap 零 audio feedback call**(negative spy — Rule 5 deliberate silence)。*Logic · BLOCKING*
- **AC-17**(#33 exempt):GIVEN `is_input_permitted()==false`,WHEN dismiss tap,THEN tap 照被消費且 #21 全程零 call 該 predicate(negative spy)。*Logic · BLOCKING*
- **AC-18**(intra-queue):queue 2 件,第 1 件 dismiss → `modal_dismissed(drop_id, terminal=false)` 正確、**全程零 GSM direct call**(negative spy)、gap 後第 2 件 ENTRY。*Logic · BLOCKING*
- **AC-19**(terminal 順序):queue 剩 1 件 dismiss → S4 anim **完成先** emit `modal_dismissed(drop_id, terminal=true)`,anim 中途零 emit;**#21 全程零 GSM direct call**(exit 經 #15 `loot_confirmed` chain — GSM AC-14)。*Logic · BLOCKING([gated G-LM-4] #15 handler emit 半邊)*
- **AC-20**(receive_loot @ S3 exactly-once):S3 到達(未 tap)→ call exactly once;tap 後無第二次;永不 tap + stash-exit → 已 banked。*Logic · BLOCKING*
- **AC-21**(唯一 caller,**owner-exempt** — Pass 1 修正,PR #12 lint 事故同 class 防禦):CI grep `src/`,`receive_loot(` caller **喺 `inventory_system.gd`(owner 內部 4 個 re-entrancy/boot-drain call sites)以外**只有 #21 coordinator 一個 call site。*Static/CI · BLOCKING*
- **AC-22**(post-S3 stash-exit flow):modal **S3** open,GSM 外部 force-transition → stash anim ≤0.3s(無 input)→ emit `modal_dismissed` → deferred-ack +1 → **下次 safe-state entry**(F4 flush gate)出 aggregated「+N」toast。*Logic · BLOCKING*
- **AC-22b**(pre-S3 force-close = cancel + re-reveal,D1 — Pass 1 新增):modal 喺 S0/S1/S2 任一段,GSM 外部 force-transition → ≤1 frame cancel、INV-M1 release、**`modal_dismissed` emit count == 0、`receive_loot` 零 call**、件留 #15 queue;下次 GSM → LOOT_DROP 該件 re-reveal(full ceremony 重行)、`re_reveal_count(tier)` telemetry +1、無 toast。*Logic · BLOCKING*
- **AC-23**(S4 idempotent):S4 行緊時 force-close 落中途 → `modal_dismissed` emit count == 1。*Logic · BLOCKING*
- **AC-24**(toast 結構):`loot_micro_ack` 到、modal 唔 active 且 GSM 喺 safe state → toast anchor 喺 edge container(parent assert)、icon + tier tint、**零 text node**、entry == `TOAST_ENTRY_SEC`、無 input handler。*Logic · BLOCKING*
- **AC-25**(defer + aggregate):modal active 時 3 個 `loot_micro_ack` → 零 toast 即出;close 後 `FLUSH_DELAY`(且 safe state)出**單一**「×3」toast,tint == 最高 tier。*Logic · BLOCKING*
- **AC-26**(threshold boundary):pending==4 → sequential;pending==5(==`CATCH_UP_THRESHOLD`,讀 #15 const)→ CATCHUP_PROMPT。*Logic · BLOCKING*
- **AC-27**(prompt defer 零動作):CATCHUP_PROMPT defer → terminal emit → HIDDEN、pending 不變、`receive_loot` 零 call、零 GSM direct call。*Logic · BLOCKING*
- **AC-28**(catch-up 結構):F3 fixture(14C+10U+4R+1E+1L)reveal-all → sub-RARE 24 件 `C_stream` cadence 零 tap stream(#5 aggregated,call 數 << 24;**stream 期間 `loot_fanfare_*` call count == 0** — D4 negative spy);RARE+ 揀 tier-降序 top-K=5(L+E+3R)full ceremony(reveal 順序 ascending);**第 4 件 R 喺 grid 有 own cell(node assert:icon + rarity label;「+N」badge 唔適用於 RARE+ — C-1)**;overflow 件喺 grid entry 嗰 frame batch commit(C-2);**stream beats 喺 stream-end 嗰 frame 單一 batch 連發 `receive_loot`(Rule 7 — #17 persist spy == 1 次)**。*Logic · BLOCKING*
- **AC-29**(mid-exit 零懲罰):catch-up ceremonies 行到第 k 件完,tap「稍後再拆」→ 已 commit 件(stream batch + k 件 ceremony)各自已 emit `modal_dismissed` + banked;剩餘原封 pending,banner 下次以更新 N 重現。*Logic · BLOCKING(#15 dequeue side [gated G-LM-4])*
- **AC-30**(rollback mid-reveal,×3 — Pass 1 改):**S0–S2** 任一段收 `loot_rollback`(該 drop_id)→ ≤1 frame cancel、timescale restored、無 terminal frame、無 toast、`modal_dismissed` count == 0、**cancel 後 re-query:queue 非空 → gap 後下一件 ENTRY;空 → terminal emit(GSM 唔 stuck)**。*Logic · BLOCKING*
- **AC-30b**(S3 rollback = 顯示層 no-op — Pass 1 新增):S3 收 `loot_rollback` → modal 照留 STEADY、可正常 dismiss、telemetry `late_rollback`、零 cancel 副作用(post-banking,Rule 11)。*Logic · BLOCKING*
- **AC-31**(queued rollback):rollback 目標係未 reveal queued drop → #21 零動作。*Logic · BLOCKING*
- **AC-32**(content source = committed store):signal payload 同 `get_drop()` 餵唔同值 → 顯示 == `get_drop()`;fill 時 null → EC-M6 skip,**永不** render placeholder。*Logic · BLOCKING*
- **AC-33**(banner deferral + priority):modal active 時 `loot_disabled` → banner dismiss 後先出;同時收 rollback → rollback 先;stack 同屏最多 1 條且 `private_mode` > audio silent-mode。*Logic · BLOCKING*
- **AC-34**(empty-queue entry):GSM→LOOT_DROP 但 queue 空 → 即 emit `modal_dismissed("", terminal=true)`、modal 唔開、GSM 唔 stuck(#15 chain)。*Logic · BLOCKING*
- **AC-34b**(micro_ack banking — Pass 1 新增):`loot_micro_ack(drop_id)` 到 → `receive_loot` exactly-once + `modal_dismissed(drop_id, false)` emit(dequeue)、零 modal/UI 動作、toast 行 F4 deferral;該件唔再出現喺 `get_pending_drops()`(唔漏入 catch-up)。*Logic · BLOCKING([gated G-LM-4] dequeue 半邊)*
- **AC-35**(Rule 14 mapping):① mid-ceremony 唔可 dismiss → AC-11;② 無 re-peek → AC-31/71;③ 周邊 lock 零依賴 → AC-17;④ sting 唔可 skip → AC-16。*(mapping,無獨立 evidence)*
- **AC-36**(telemetry hooks):4 情境各觸發一次 → `ceremony_skip_attempted(tier)` / `time_to_dismiss_ms` / `stash_exit_count` / `catchup_abandoned(remaining)` 各 emit 一次正確 payload(local signal;#28 sink 唔需存在)。*Logic · BLOCKING*
- **AC-37**(FSM 完整性):table-driven 行 **8-state × in_catchup flag** 每條 edge(包括 CATCHUP_STREAM、EXITING→CATCHUP_GRID、CATCHUP_GRID terminal emit、rollback re-query edges)→ transition 按表;表外 → assert/no-op 唔靜默跳。*Logic · BLOCKING*
- **AC-37b**(fast-victory variant — GSM L375(c),Pass 1 新增):GIVEN drop 嘅 source payload 係 `BossPayload.outcome == INTERRUPTED_WITH_CREDIT`,THEN attribution slot 用「快勝」variant(fixture string assert);ceremony ladder 照 tier 不變。*Logic · BLOCKING*
- **AC-37c**(keyboard dismiss — Pass 1 新增):`ui_accept` 喺 S2/S3 行為 == scrim tap(fast-complete/dismiss,同一 per-stage policy);S0/S1/S4 ignore;catch-up `ui_cancel` == 「稍後再拆」。*Logic · BLOCKING*

### C. Formulas

- **AC-38**(F1 table + equality 可達):default config,T_block == 200/350/650/950/**1200** 全 pass;ceiling assert 係 `≤`(LEGENDARY equality 必須 pass)。*Logic · BLOCKING*
- **AC-39**(F1 C1 data-load assert):注入違 C1 config(LEGENDARY D_entry=1300)→ validation **fail** 且**冇** runtime clamp。*Logic · BLOCKING*
- **AC-40**(F1 非 additive):LEGENDARY fake clock,S1 同 S2a 喺 T=0 同時起跑,實測 T_block == 1200ms 非 1650ms。*Logic · BLOCKING*
- **AC-41**(F1 motion_reduction):on → T_block == 200/350/500/650/800、D_timestop==0、單調性保留。*Logic · BLOCKING*
- **AC-42**(F2 identities + honest endpoints — Pass 1 改):(0.55, 0.40, 1.0, W=160) → px 87/73、pct 55/45、sum==100;legal sweep:`px_w+px_r==W_bar`、sum==100 恆成立、**兩 contrib >0 ⇒ pct∈[1,99]**(clamp);**端點 case:(0.6, 0.8, 0.0) → pct 100/0(rr 真零,誠實);(ws=1.0, rr=0.01) → pct 99/1(clamp,唔准顯示「運氣 0%」)**。*Logic · BLOCKING*
- **AC-43**(F2 floor unreachable,**domain parameterize on `W_BAR_MIN` knob** — Pass 1 改,knob tune 到 88-119 時 CI sweep 跟 knob 行):legal grid(RARE+、W≥`W_BAR_MIN`)naive delta ≥8px 恆成立(`W_BAR_MIN`≥88 先成立 — knob 下限 88 係臨界);corrupt input 先觸發 floor clause。*Logic · BLOCKING*
- **AC-44**(F2 display gate):W_bar < `W_BAR_MIN` → stacked text-only、% label 雙邊、零 info loss。*Logic · BLOCKING*
- **AC-45**(bar RARE+ only):COMMON/UNCOMMON → breakdown bar node 不可見/不存在。*Logic · BLOCKING*
- **AC-46**(F3 bound + caps):worst-case(>40 sub-RARE、>5 RARE+ 全 EPIC+)→ T_machine ≤**15.8s**(**前提:#7 正常 emit `focal_completed`;watchdog degraded path 除外** — Pass 1);120 sub-RARE → 40 beats(6.0s)+ 80 折 grid。*Logic · BLOCKING*
- **AC-47**(F3 regression):30 件 fixture → T_machine == **10.3s**(Pass 1 重算:L+E+3R ceremony、1R 折 grid、L 前 gap = `FOCAL_EXIT_MARGIN_SEC` 0.6)。*Logic · BLOCKING*
- **AC-48**(F4 display):N_agg == 1/2/150 → icon+tint 無字 /「×2」/「×99+」,tint == 最高 tier。*Logic · BLOCKING*
- **AC-49**(F4 merge + 守恆):toast 剩 0.3s(remaining-to-cap ≥ MERGE_MIN_REMAIN)新 ack → remaining := 0.6、N_agg+1;**remaining-to-cap < MERGE_MIN_REMAIN 嘅 ack → 唔 merge 直入 carryover**(Pass 1 邊界);連續 stream → 壽命 ≤`TOAST_MAX_LIFETIME` 到 cap fade + carryover 開新 toast;**守恆:Σ N_agg(displayed)+ pending carryover == total acks**(F4 定義)。*Logic · BLOCKING*
- **AC-50**(F5):tap @t<D_entry ignore;@t∈[D_entry,T_block) → S3 @**min(t+`SNAP_SEC`, T_block)**(clamp — tap@T_block−50ms 唔慢過 natural;同 frame race natural supersede,S3 副作用 exactly-once)、最早 dismiss @S3+debounce;**boundary frame tap(ladder 完成嗰 frame)= fast-complete**(tiebreak pin)。*Logic · BLOCKING*
- **AC-51**(F6,post-S3 only):stash-exit → freeze release 同 frame + collapse ≤`STASH_COLLAPSE_SEC` + 總 ≤0.3s,release idempotent;**SUSPENDED-triggered → 零 anim 即 emit**(Rule 8)。*Logic · BLOCKING*

### D. Edge Cases

- **AC-52**(EC-M1):S2b freeze 中 SUSPENDED(fake #6 已自清)→ resume ≤30s 直接重入 S3(receive_loot @ 重入嗰下 fire exactly-once)、`ceremony_freeze` spy count **不增**、release no-op;>30s → **pre-S3 cancel 語意**(唔 emit、留 pending、零 receive_loot — D1)。*Logic · BLOCKING*
- **AC-53**(EC-M2):fake #6 reject freeze → ceremony 照行 motion_reduction variant、完整到 S3、telemetry `freeze_rejected`。*Logic · BLOCKING*
- **AC-54**(EC-M3 smoke):已有 active freeze 時 `ceremony_freeze` → max-remaining、release 只清自己 entry。*Integration smoke · BLOCKING [gated G-LM-3];主測落 #6 story*
- **AC-55**(EC-M4 matrix):motion_reduction on → `request_focal` **零 call 全 tier**、shake 0、particle ×0.5、hold/dismiss/queue 同 off 一致。*Logic · BLOCKING*
- **AC-56**(EC-M5 coercion 同源):`rarity_tier="MYTHIC"` → `RarityTier.get(s, COMMON)` 喺 ladder lookup 前、COMMON ceremony、無 bar、telemetry;cross-check 同 fixture 餵 real #17 → 入庫 tier == 顯示 tier。*Logic + Integration · BLOCKING*
- **AC-57**(EC-M6):`get_drop()` null → skip(無 modal / receive_loot)、CRITICAL telemetry、gap 後 advance;terminal 件 → terminal dismiss 出口。*Logic · BLOCKING*
- **AC-58**(EC-M7 commit point):force-close 落 CATCHUP_PROMPT → 零 commit 全留 pending;落 stream 中 → **嗰刻 batch commit 已 display beats(單 frame 連發,#17 persist == 1)**,in-flight 未 display → 留 pending,已 commit 唔 re-reveal;落 grid 中 → 收埋零 data 影響。*Logic · BLOCKING*
- **AC-59**(EC-M8 phase-gate + termination):stream 中新 drop → append 規則按 phase;持續注入 → catch-up 仍 terminate(收斂 assert)。*Logic · BLOCKING*
- **AC-60**(EC-M9 margin + watchdog):連續 2 件 EPIC+ → 件距 == `max(INTER_REVEAL_GAP_SEC, FOCAL_EXIT_MARGIN_SEC)`(deterministic,零 #7 state query — negative spy);fake #7 永不 emit `focal_completed` → fallback timer T=D_hold+0.2s 照 freeze、queue 照 advance、telemetry `focal_anchor_fallback`。*Logic · BLOCKING*
- **AC-61**(EC-M10):DISCONNECTED reveal 同 connected 完全一致:無 spinner/sync badge node、receive_loot 照 call。*Logic · BLOCKING*
- **AC-62**(EC-M11):safe→safe(DISCONNECTED→IDLE)繼續無 stash-exit;→ 非 safe 先觸發。*Logic · BLOCKING*
- **AC-63**(EC-M12):resize 令 W_bar 100 → 一 frame re-layout、stacked variant、timer 唔 reset、particle 唔 replay。*Logic · BLOCKING*
- **AC-64**(EC-M13 exclusive):boot force-reveal + depth 0/3/7 → 唔入 / sequential / catch-up;assert banner 同 sequential **永不同時**。*Logic · BLOCKING*
- **AC-65**(EC-M14 ×5):S3 `receive_loot` 回 OK / FAILED_ROLLBACK / QUEUED_SUSPENDED / DUPLICATE_NOOP / CONVERTED_DUPE → 正常 / **零 user-visible delta**+照 dismiss+CRITICAL telemetry+**`report_receive_failure(drop_id)` call exactly-once**(Pass 1 — recovery 鏈)/ 當 success+stash-exit / success+無第二 micro_ack / 正常+shard ack 入 F4 deferred aggregate(flush 喺 terminal+safe state)。*Integration(real #17 enum;report handler [gated G-LM-4])· BLOCKING*
- **AC-66**(EC-M15):ws=1.4 → clamp 先入 F2;identity 違反 >0.001 或 score-tier 矛盾 → 信 #15 tier、隱藏 bar、telemetry。*Logic · BLOCKING*
- **AC-67**(EC-M16):rollback == 當前 stream beat(未 commit)→ ≤1 frame cancel、跳下一 beat、aggregate −1;已 commit → 零動作。*Logic · BLOCKING*
- **AC-68**(EC-M17 守恆):active toast N=2 時 modal 開 → 0.1s fade、count fold 入 deferred、close 後 flush 包齊 — **總數守恆 assert**。*Logic · BLOCKING*
- **AC-69**(EC-M18):banner deferred N=5 時新 drop → count→6 in-place、零新 entrance tween。*Logic · BLOCKING*
- **AC-70**(EC-M20):terminal S4 行緊時新 drop → 永不 mid-exit 重入;gap 後重評 terminal → 有新件唔 exit GSM 繼續。*Logic · BLOCKING*

### E. Cross-system Integration(非 isolation)

- **AC-71**(#15 round-trip):real #15+#21,`loot_dropped`→reveal→dismiss→`modal_dismissed(drop_id, terminal)` → #15 以 drop_id dequeue(非 head-pop)、下次 query 唔見該件;**ordering case(Pass 1 — 雙語意防回歸):backend ACK 先到、reveal 後到 → 件仍喺 reveal queue、照 reveal、dequeue 唔 skip commit rename**。*Integration · BLOCKING [gated G-LM-4]*
- **AC-72**(#17 full handoff):real #17,full reveal → S3 → inventory 含 item、auto-equip 唔被阻;catch-up:**stream batch 喺單一 frame 連發 + RARE+ 逐件 S3** → #17 aggregate/push/persist **per batch/件各一次**(one-frame ONE_SHOT debounce 語意 — Pass 1 改成 shipped #17 可滿足形式)。*Integration · BLOCKING(即時可執行)*
- **AC-73**(GSM full loop):real GSM + real #15,entry→reveal→terminal dismiss → `modal_dismissed(terminal)` → **#15 emit `loot_confirmed`** → GSM 離開 LOOT_DROP(#21 zero GSM direct call — spy);intra-queue 期間 state **全程不變**。*Integration · BLOCKING [gated G-LM-4(#15 emit 半邊)]*
- **AC-74**(G-flag-1):reveal 開咗 2s(<15s)player tap dismiss → 即生效(dismiss = completion 非 interruption)。*Integration · BLOCKING [gated G-flag-1]*
- **AC-75**(#5 freeze-immune):freeze active(tree paused)→ LOOT pool nodes parent == CelebrationVFXLayer 且 `PROCESS_MODE_ALWAYS`(property assert)。*Integration · BLOCKING [gated G-LM-1+2]*
- **AC-76**(#4 fanfare):reveal onset → **#21 coordinator** call `play_sfx(loot_fanfare_{tier})` @ S0 frame(LEGENDARY pre-roll 對齊 0.1s pre-shake);toast flush → toast tick(low/mono),**零 fanfare/sting call**(Pass 1 — #15 L204 erratum)。*Integration · BLOCKING [gated G-LM-8]*
- **AC-76b**(freeze-audio 共存 — Pass 1 新增):AudioManager(或 SFX pool players)+ LootRevealCoordinator `process_mode == PROCESS_MODE_ALWAYS`(property assert — fanfare 喺 `ceremony_freeze` 期間唔俾 engine pause;AC-16 spy 驗唔到 engine-level pause,呢條補個窿)。*Static/property · BLOCKING [gated G-LM-9]*
- **AC-77**(ARIA once-only):S3 entry → `announce_aria` exactly once(tier + item);fast-complete 入 S3 唔 double-announce。*Logic · BLOCKING [gated G-LM-6];真 browser SR = manual ADVISORY*
- **AC-78**(#20 banner stack):real #20 audio banner 顯示中,`loot_disabled` 到 → 同屏一條、private_mode 取代;private_mode banner 清走後 audio banner re-render(displacement ≠ one-shot dismissal — predicate 仍 true 就返嚟,防 audio 永鎖)。*Integration · BLOCKING [gated #20 Q-OQ6 sync — 「同屏一條」arbitration 需 #20-side suppress 接線,#20 audio banner 係 HUD 內部 predicate render]*
- **AC-79**(G-LM-5 boot order):`project.godot` — coordinator 位於 predecessor set 全部之後、ZoneSystem 後 tail(#28 keep last)。*Static/CI · BLOCKING [gated G-LM-5]*

### F. Visual / UI(ADVISORY — headless 驗唔到)

- **AC-80**:LEGENDARY terminal frame 截圖 — 明信片 composition、「值唔值得 cap 圖」lead sign-off(Pillar 3 design test)。*Visual/Feel · ADVISORY*
- **AC-81**:micro-copy walkthrough — present tense、零**正向**運氣歸因(否定式如「RNG 唔夠 0.25」准 — N-1)、「[weight]×[reps] — Stamped」數字行先;EPIC/LEGENDARY 證人聲線合 tone;CTA ==「影低佢」。*UI · ADVISORY*
- **AC-82**:catch-up grid 截圖 — rarity-sorted 一屏、hero cell、screenshot-worthy(FT-1)。*Visual · ADVISORY*
- **AC-83**:S1 entry 錄影 — elastic-light 唔似 pop、肉眼無 staggered pop-in(structural 半邊 AC-10)。*Visual/Feel · ADVISORY*
- **AC-84**:breakdown bar 截圖(標準 + 窄屏 stacked + **CJK 雙 font 混排 variant**)— 兩段對比可讀、% label 清晰、legend 行 Zpix 12px 可讀、resize 唔破版。*Visual · ADVISORY*
- **AC-85**:LEGENDARY freeze-hold 窗(focal peak)期間錄影 — 角落零 toast(defer 兌現)。*Visual · ADVISORY(logic 半邊 AC-25)*
- **AC-86**:stash anim 錄影 — 讀成「袋低咗」唔似 crash。*Visual/Feel · ADVISORY*
- **AC-87**:world saturation 期間 burst 截圖 — burst 全飽和(>100 layer immune)。*Visual · ADVISORY [gated G-LM-1/2/3]*
- **AC-88**:catch-up stream 錄影 — beats luminance-stable(零 per-beat flash),flash transient 只喺 stream 頭尾;**LEGENDARY freeze 期間 fanfare 連續播放無 stutter**(真 build 聽感 — AC-76b 嘅 perceptual 半邊)。*Visual/Audio · ADVISORY [gated G-LM-9]*

### Test distribution

| 類別 | 數量 | Gate |
|---|---|---|
| Unit Logic(headless GUT) | 71(+5 Pass 1:AC-22b/30b/34b/37b/37c) | BLOCKING |
| Integration | 9 | BLOCKING(6 gated) |
| Static / CI / property | 3(AC-21/79/76b) | BLOCKING |
| Manual | 10(AC-9 + F 組 9) | ADVISORY |
| Mapping | 1(AC-35) | — |
| **總計** | **94** | |

**Coverage 自檢**:Core Rules 1–15 + 13b 全 ≥1 AC ✓;F1–F6 全 ≥1 ✓;EC-M1–M20 全 cover(M19 fold 入 AC-11/50)✓;FSM 8-state × flag ✓(AC-37);INV-M1/M2/M3 first-class ✓(AC-1/3/20+22b);D1-D5 裁決全部有 AC 兌現 ✓(D1→AC-22b/52、D2→AC-12/60、D4→AC-28、D5→AC-50)。
**Gated 分佈(Pass 1 重數,19 條)**:G-LM-1(AC-4 部分/75/87)、G-LM-3(AC-1 release API/12 部分/54)、G-LM-4(AC-19 部分/29 部分/34b 部分/65 report/71/73)、G-LM-5(AC-79)、G-LM-6(AC-77)、G-LM-8(AC-76)、G-LM-9(AC-76b/88)、G-flag-1(AC-74)、#20 Q-OQ6(AC-78)— 全有 #21-side 先行斷言或 fake seam。

## Open Questions

| ID | Question | Owner | Target |
|----|----------|-------|--------|
| **OQ-1** | Stat-delta ticker slot(P-05 殘餘):modal 顯示 equip 前後 stat 變化需要 #17 equip-result payload API(`receive_loot` 回 enum 冇 stats)— MVP 唔做;#22 Character Screen 設計時一併裁(modal 加 slot vs 留俾 #22) | #22 GDD authoring | #22 design 時 |
| **OQ-2** | Rule 15 telemetry payload type(signal args vs metric struct)— `time_to_dismiss_ms` 等 4 hook 嘅 envelope 格式 | #28 Telemetry GDD | #28 design 時 |
| **OQ-3** | Contact-sheet grid 嘅 PWA share button 整合(#15 Pillar 5 提過 LEGENDARY「PWA share button 截圖」)— share API 經 platform seam 定 MVP 只靠 OS 截圖 | #27 Onboarding / PWA 層 | v0.2 |
| ~~OQ-4~~ | **RESOLVED Pass 1** — 併入 G-LM-8(catalog co-design 連 lint scope 一齊裁) | — | — |
| **OQ-5** | G-flag 剩餘 grep(G-flag-1 15s window vs player dismiss / G-flag-3 intra-queue 語意 / G-flag-4 #7 const)— 任一同設計唔對齊 → escalate CD。**Pass 1 已解:exit path = `loot_confirmed` chain(G-flag-3 主體)、`_check_pending_loot_reveal` 零 caller(G-flag-2 → 併入 G-LM-4)** | #21 epic story-readiness | epic 開波時 |
| **OQ-6** | GSM L375(b)「未開封」item tap entry trigger — defer v0.2(需 #23 surface + 獨立 content-source 分支;30-日 hard-cap auto-commit 件唔喺 reveal queue)— v0.2 時同 #23 一齊裁 ritual recovery 形態 | #23 GDD + GSM erratum | v0.2 |
