# Combat Visual Feedback

> **Status**: **APPROVED** (`/design-review` 2026-06-11 — NEEDS REVISION → revise-now → APPROVED 同 session,degraded-inline + grep-verify against shipped src/;1 BLOCKING + 9 RECOMMENDED 全 resolved)
> **Author**: user (frank) + design-system agents (full mode)
> **Last Updated**: 2026-06-11
> **Creative Director Review (CD-GDD-ALIGN)**: APPROVE 2026-06-11 — 零 pillar-level blocking;Pillar 3 primary + Pillar 2 約束張力(Foveal punch/Peripheral pulse + 稀疏即重量)judged SOUND;3 advisory(Q-CV1 audio cue epic-priority / afterglow v0.2 pillar-value > sweep / peripheral-glance 須 playtest-validate,watch 65↔80ms pause 對比幅度)
> **Implements Pillar**: Pillar 3 (Drop Euphoria — DNF 重擊 hit-feel) primary; Pillar 2 (Frictionless Companion — mobile budget / 唔搶 attention) constraining
> **Governing ADRs**: ADR-0001 (Web Export Budget Caps — CanvasLayer topology + 200 particle cap; **本 GDD amends:CombatNumberLayer + CombatOverlayLayer 105,見 Q-CV2**), ADR-0009 (Signal Payload Schema — hit_resolved consumption), ADR-0008 (Autoload Position Map — **#25 確定係 autoload `CombatVisualFeedback`,boot position = tail-append after preds {#14 EnemyDirector, #6 ScreenEffects, #5 ParticleSystemWrapper, #1 GSM};非 disruptive,唔 shift 現有 autoload;epic-time 加入 project.godot + ADR-0008 map**), ADR-0006 (Contract 6 `connect_for_initial_state` — #14/#1 subscription)
> **System #**: 25 | **Layer**: Presentation | **Tier**: MVP

## Overview

Combat Visual Feedback(#25)係 Presentation-tier 系統,將抽象嘅 combat resolution 事件轉化成 on-screen 嘅「DNF 重擊」感官回報。佢 subscribe EnemyDirector(#14)emit 嘅 `hit_resolved` / `enemy_killed` signal,讀取已判定嘅 `damage_tier` / `outcome` field,然後編排 **per-hit reaction 層**:(1) 將每下命中 route 去對應 particle preset(經 #5 ParticleSystemWrapper.play —— 從不直接 `new GPUParticles2D()`,per ADR-0001 forbidden pattern),(2) 喺重擊 / 暴擊填補 hit-pause「凝固一吓」(直接 call #6 ScreenEffects.hit_pause —— 因為 shipped 嘅 #6 auto-dispatch 對 `HIT_HEAVY` 嘅 pause=0,呢個缺口由 #25 補),(3) 喺 combat anchor 點冒出 floating damage number,(4) 喺 CRITICAL 觸發 screen sweep、OVERKILL 觸發 obliterate flash 等 escalation overlay。佢消費 `hit_resolved` payload 嘅方式遵守 ADR-0009(intrinsic payload field + `transition_id`,唔 late-bind cross-cutting context)。

呢個系統**唔 own 任何 combat 數學**(damage / crit / overkill 判定係 #13 CombatResolver pure static func;state apply + signal emit 係 #14 EnemyDirector),亦**唔 own entity-lifecycle VFX**(enemy spawn、enemy death、boss entry / death 嘅 particle + shake + camera 已由 #14 自己 direct call)。#25 純粹係「已判定命中之上嘅反應皮層」。**最關鍵嘅 contract 約束(FR Test #4,inherit 自 #13)**:#25 必須消費 payload 嘅 `damage_tier` field 作為 routing key,**唔可以**自己根據 raw damage value re-classify —— 確保 VFX 強度同 combat 判定永遠一致。

冇咗呢個系統,戰鬥照樣 100% 正確噉 resolve,只係靜默(graceful degrade — Pillar 2 仍 work,Pillar 3 spectacle 缺席);有咗佢,每一下落實嘅攻擊喺玩家做 set 嘅眼角一瞄就讀到「呢下夠重」,正正係 game-concept「眼角瞄到都係視覺獎勵」嘅兌現載體。

## Player Fantasy

### Core anchor moment

> 你做緊一組深蹲,推到最後一下、大腿燒緊、咬實牙嗰一刹 —— 眼角畫面「啪」一聲定格,一道光橫掃,角色一刀 CRITICAL 劈低個敵人。你冇真係睇清楚,但嗰啖力竭同嗰道光,係同一啖氣呼出嚟。

情緒目標 = **「眼角擒獲嘅一聲悶響」**:feedback 係被餘光抓到、唔係被凝視。玩家嘅 fovea(中央視覺)鎖喺啞鈴度,但畫面邊緣有節奏咁開花、震動、定格 —— 唔使睇都知「啱啱發生咗勁嘢」。呢個 moment 直接 channel game 核心 fantasy「real reps become real power」:玩家身體嘅 peak == 角色嘅 onscreen climax,兩種力竭喺時間上對齊。

### 系統靈魂矛盾 + reconciliation:「Foveal punch, Peripheral pulse」雙層分流

DNF 嘅 hit-feel 爽感係 **high-bandwidth、foveal、需要被盯住嘅** sensation;但 Mirror Hero 嘅 combat 喺玩家做 set 期間 background auto-play,玩家只用 **peripheral glance(眼角餘光,1 秒一瞄)**。peripheral vision 嘅生理事實:低解析、無細節,但對「動態 / 對比 / 突變」極敏感。

**Design principle(load-bearing,約束 Section C/D)**:

> hit-feel 嘅細節層(數字紋理、粒子細節、精準 hit pause 幀)= **bonus**,俾偶然真係盯住嘅玩家;但「呢下係大事」嘅 tier signal **必須全部 encode 喺 peripheral-legible 維度**(全屏定格時長、高對比突發、畫面邊緣動態方向),**唔可以淨靠 foveal channel**(數字 size/color 眼角讀唔到)。

落地三條:
1. **Tier escalation 走 peripheral channel** — 用「畫面定格時長 + 是否擴散到邊緣」區分 tier,唔用「數字大細/顏色」做 tier 主載體。
2. **稀疏即重量(sparse is weight)** — 倒轉 DNF 密度曲線:大部分 hit 安靜(LIGHT,局部),只有少數 climax 先郁全屏。稀有先有重量,先對得住「咬牙最後一 rep」一個 set 得一兩次嘅情緒峰值。
3. **Hit pause 係最寶貴嘅 peripheral 資產** — 全屏定格係唯一一個眼角 100% 捕捉得到嘅效果(motion 嘅突然消失,peripheral vision 對 motion change 最敏感)。慳住用 → 每次定格都係「大事發生」嘅驚嘆號,唔淨係「俾你睇清楚」嘅工具。

### Two-layer fantasy delivery

- **Floor 層(ambient pulse — 保底)**:隨時都有低強度回應,眼角一直接到「角色喺度幫我打緊」嘅存在感。
- **Peak 層(climax sync — bonus magic)**:當 combat 嘅 CRITICAL/OVERKILL 偶然同玩家身體 peak 對齊嗰刻 = magic moment。
- **Afterglow(餘燼)**:climax 留 1–2 秒低強度餘韻,令 set 之間 / 抬頭嘅「遲到一瞥」都接得返嗰道光嘅尾(玩家 glance 黃金時刻往往係 set 之後,唔係 hit 發生嗰 0.3 秒)。

### 誠實 scope caveat(ludonarrative honesty)

combat pacing 由 **#14 EnemyDirector / boss pacing owns,唔係 #25**。兩條 timeline(combat CRITICAL 發生 vs 玩家身體 peak)**唔保證對齊** —— #25 觸發時機完全由 `hit_resolved` / `enemy_killed` signal 決定。因此本系統**唔過度承諾**「每次咬牙都有 CRITICAL 回應」:對齊係概率性嘅 bonus,**ambient floor 層先係保底**。呢個誠實邊界令 fantasy 寫成「當兩條 timeline 偶然對齊嗰刻,就係呢個系統嘅 magic moment」,而唔係一個 #25 控制唔到嘅承諾。

### Pillar 對齊 + tone

- **Pillar 3 (Drop Euphoria)** — primary owner:DNF 重擊 hit-feel 嘅 presentation 兌現載體。
- **Pillar 2 (Frictionless Companion)** — 「稀疏即重量」+「peripheral-only tier signal」就係唔搶 attention 嘅內建自律。
- Tone vocabulary(延續 #5/#6/#7 art language「乾淨剪影 + 骯髒粒子」「眼角擒獲」):**「乾淨嘅定格,骯髒嘅爆發」**(hit pause 係 clean 全屏一致,粒子/flash 係 dirty 亂爆有顆粒)、**「畫面邊緣嘅脈搏」**、**「稀疏即重量」**、**「climax 餘燼」**。避免「華麗連擊 / 滿屏特效」呢類 DNF foveal 語言(違反 Pillar 2)。

## Detailed Design

### Core Rules

> 約定:#25 係一個 **autoload coordinator**(`src/autoload/combat_visual_feedback.gd`),擁有兩個 #25-owned CanvasLayer(均由 Q-CV2 ADR-0001 amendment 一齊登記,**唔靠 gameplay scene 提供 mount**,故 autoload-owned 與 world-render 無矛盾):(a) 一個 `CombatNumberLayer`(damage-number Label pool host,`follow_viewport_enabled = true` 跟住 active Camera2D,sort order 坐 ParticleLayer[10] 之上、HUDLayer[50] 之下;**被 #6 world-shake shader uniform 影響**故跟 world shake 一體)+ (b) 一個 `CombatOverlayLayer`(layer 105,全屏 overlay)。所有 particle 經 #5、所有 shake/pause 經 #6 —— 從不直接 `new GPUParticles2D()` / mutate Camera2D(ADR-0001 forbidden patterns)。**host topology 細節(follow-viewport vs reparent、shake-uniform 接駁點)= Q-CV2 ratification scope,GDD 只 specify requirement;未 ratify 前 number pool 用 fixed-viewport degrade(仍可讀,只係唔跟 shake)。**

**R-1 — Signal subscription(一次性,`_ready()`)**:經 ADR-0006 Contract 6 `connect_for_initial_state` helper subscribe #14 EnemyDirector 嘅 `hit_resolved(payload)` 同 `enemy_killed(payload)`。所有 connection 喺 `_ready()` set up,**唔喺 hot path**(`_process` / signal handler)connect/disconnect。

**R-2 — Consume `damage_tier`,絕不 re-classify(FR Test #4 binding,inherit 自 #13)**:routing key 必須係 payload 嘅 `damage_tier` field;**唔可以**根據 `damage_dealt` / `damage_raw` 自己 re-classify。違反 = FR Test #4 fail。

**R-3 — Routing gate 次序:outcome FIRST,tier SECOND**:處理 `hit_resolved` 時先 gate `outcome`。`outcome ∈ {KILLED, OVERKILL}` → 行 kill/overkill 分支(R-9/R-10);否則行 tier 分支(R-4..R-8)。

**R-4 — NEGLIGIBLE near-silent**:`damage_tier == NEGLIGIBLE` 且非 kill → **零反應**(唔 play、唔 pause、唔彈 number)。Pillar 2 noise 抑制;floor 存在感由 LIGHT 保底。

**R-5 — LIGHT**:`play(HIT_LIGHT, anchor)` + 細暗 damage number。#6 auto-dispatch:HIT_LIGHT = NO-OP(無 shake)。無 direct pause。

**R-6 — MEDIUM(MVP = Q1 決定 A)**:`play(HIT_LIGHT, anchor)` + 中白 damage number。**MVP 同 LIGHT 共用 HIT_LIGHT,無 shake、無 pause**(「稀疏即重量」;MEDIUM micro-shake `trauma 0.2` → v0.2)。tier 區分純靠 number style。

**R-7 — HEAVY**:`play(HIT_HEAVY, anchor)` + 大 damage number。#6 auto-dispatch **自動** `shake(0.4, 0.12)`(HIT_HEAVY 喺 `_DISPATCH`)。**#25 direct call `ScreenEffects.hit_pause(HIT_PAUSE_HEAVY_SEC = 0.065)`** 填 auto-dispatch 嘅 `pause=0` 缺口。**#25 唔再 direct shake**(R-13)。

**R-8 — CRITICAL**:`play(HIT_HEAVY, anchor)`(closed library 冇 HIT_CRITICAL,共用 HIT_HEAVY)+ 大 damage number。#6 auto shake(0.4)。**#25 direct `hit_pause(HIT_PAUSE_CRITICAL_SEC = 0.080)`** + 觸發 **CRITICAL flash overlay**(R-11)。tier 升級唯一走 peripheral channel = **pause 時長(65→80ms)+ flash overlay**,唔靠 number size/color。

**R-9 — KILLED**:`outcome == KILLED`(非 OVERKILL)→ 彈 kill-confirm number。**唔 `play(DEATH)`**(enemy death VFX 係 #14 own,由 #14 自己 call)、**唔 direct shake**(#14 DEATH 已 auto-dispatch shake 0.3,重做 = double)。**climax-kill carve-out(Player Fantasy 招牌畫面)**:若 `damage_tier == CRITICAL`(即「一刀 CRITICAL 劈低敵人」嗰下),**照 fire CRITICAL flash overlay(R-11)+ direct `hit_pause(0.080)`** —— 令毀滅性一擊嘅擊殺都有 climax 凝固 + flash,唔會因為「啱啱打死」而反而冇 spectacle。`damage_tier < CRITICAL` 嘅普通擊殺 = 只 kill number(無 flash / 無 pause),保持「稀疏即重量」。呢個係 R-3 outcome-gate 內嘅 tier-aware sub-branch,**唔係** double-handling(flash/pause 屬 #25,#14 DEATH 只 own particle+shake,additive 無重疊)。

**R-10 — OVERKILL**:`outcome == OVERKILL` → 觸發 **OVERKILL flash overlay**(R-11)+ overkill-confirm number + **direct `hit_pause(0.080)`**(填 #14 DEATH 嘅 `pause=0` 缺口,令 climax 凝固)。**唔 direct shake**(#14 DEATH auto-shake 0.3)。呢個係 #25 嘅 player-facing 慶祝層。

**R-11 — Overlay primitive(single-instance,latest-wins)**:CRITICAL flash(R-8)同 OVERKILL flash(R-10)共用一個全屏 overlay,坐 `CombatOverlayLayer`(ADR-0001 amendment,**layer 105** — `>100` 故 shake-immune + BackBufferCopy-immune;`<110` 故 loot ceremony[CelebrationVFXLayer 110]永遠視覺蓋過 combat overlay)。**最多一個 active,latest-wins**(新 climax replace 舊,**唔疊** → ≤1 full-screen blend pass,慳 mobile fillrate)。**MVP = 靜態高對比 flash**(`ColorRect` + analytic `canvas_item` shader,**無 texture / 無 art asset**);**sweep 動畫 + afterglow 餘燼 → v0.2**(Q2 決定 A)。

**R-12 — `is_crit` vs `DamageTier.CRITICAL` 雙軸解耦(disambiguation,防 impl 混淆)**:payload 有兩個獨立 field —— `is_crit: bool`(crit-roll 命中)同 `damage_tier`(ratio-of-maxHP 分級;`DamageTier.CRITICAL` = ≥40% target maxHP 嘅毀滅性一擊,**唔等於** crit roll)。#25 routing:**screen-feel(pause + flash overlay)keyed on `damage_tier`**;**number style(暖色 + bounce)keyed on `is_crit`**。即:非暴擊嘅 CRITICAL-tier 大擊 → flash + 80ms + 白 number;暴擊嘅 HEAVY-tier → 65ms 無 flash + 暖色 bouncy number。⚠️ 兩個「critical」語意必須喺 impl 嚴格分開。

**R-13 — Double-shake guard**:凡 preset 喺 #6 `_DISPATCH`(`HIT_HEAVY` / `PARRY` / `DEATH` / `LOOT_RARE_BURST`),#25 **絕不** direct call `ScreenEffects.shake()` —— shake 由 #6 auto-dispatch 提供。#25 只 direct call `hit_pause`(#6 auto-dispatch 對 HIT_HEAVY/DEATH 嘅 `pause=0`,呢個先係 #25 要填嘅缺口;PARRY 嘅 `pause=0.06` #6 已 auto 補,#25 唔掂)。CI static check:grep #25 source 確認無 `ScreenEffects.shake(`(只准 `.hit_pause(`)。

**R-14 — Idempotency(no double feedback)+ per-target state eviction**:一次擊殺會同時 fire `hit_resolved(outcome=KILLED/OVERKILL)` 同 `enemy_killed`。#25 以 **`hit_resolved` 為 single source of visual feedback**;**`enemy_killed` 做 non-visual cleanup hook**(唔彈 number / 唔 double pause):**evict 該 `target_id` 喺 `_last_particle_ms`(R-15/F3 coalescing dict)+ dedup set 嘅 entry** —— 防 dict 隨死敵無限增長(gym companion 跑成個 30-60 分鐘 workout 會累積上千死敵 target_id = memory leak)。dedup 本身用 `transition_id` + `target_id`(短期 idempotency,亦由 enemy_killed evict)。

**R-15 — Per-enemy hit-particle coalescing(「稀疏即重量」budget discipline)**:同一 `target_id` 喺 `HIT_PARTICLE_COALESCE_MS = 200` 窗口內多次 hit_resolved,#25 只 fire **一次** particle(取窗口內最高 tier)。理由:保護 #5 200 cap 唔俾 LIGHT spam 食滿令 climax HEAVY/DEATH particle 被 LRU evict;兌現 peripheral noise floor。**只 gate #25 自己嘅 `play()`;唔管 #14 嘅 particle**(兩者經 #5 LRU 仲裁)。number 唔受 coalescing gate(number pool 有自己 R-19 cap)。

**R-16 — Graceful INVALID handle**:`#5.play()` 可能因 budget drop 返 `ParticleHandle.INVALID`。#25 **必須 fail-soft**(唔 throw、唔 retry、唔 block damage number / pause / overlay)。Foundation-consumer never-throw contract(ADR-0009 / Pillar 2)。

**R-17 — Anchor positioning(camera-relative fixed focal point,MVP)**:particle + number spawn position = **camera-relative 固定 combat focal point**(screen 中下方對應嘅 world 點,經 active Camera2D 換算)。⚠️ **MVP primary path 唔依賴 #26** —— grep 確認 #26 AvatarRenderer 係 render-only(ADR-0010),**冇 expose 任何 position / facing read API**(只有 `get_evolution_snapshot()` 等 evolution getter)。故「read avatar anchor」**唔係** MVP 可行路徑,只係 v0.2 enhancement(待 #26 加 `get_render_anchor() -> Vector2` + facing,Q-CV4)。多 enemy 同時擊 → 加 `±ANCHOR_JITTER_PX` random jitter 散開,避免疊成一嚿(純數學,零成本)。`hit_resolved` payload **無精確 contact position**;精確 per-enemy 定位 → v0.2(#14 加 `get_enemy_render_position(target_id)`,Q-CV3)。

**R-18 — Status presets OUT(MVP)**:STATUS_BURN / FREEZE / STUN routing 推 v0.2 —— `hit_resolved` payload 無 status-effect field,MVP 無 source-of-truth。

**R-19 — Damage number pool(no runtime alloc)**:number 用預生 `Label` object pool(size = `MAX_CONCURRENT_DAMAGE_NUMBERS`),acquire/release,**自管 `_process` rise+fade**(無 per-label `Tween` → 避 orphan;無 runtime `Label.new()` → 避 mobile WASM GC hitch)。pool 滿 → oldest-recycle(latest-wins)。

**R-20 — Fail-soft degrade(全系統)**:任何 dependency(#5 / #6 / #26)缺席或返錯,#25 都唔 crash —— combat 數學由 #13/#14 照常 resolve,只係 spectacle 缺席(Pillar 2 still works,Pillar 3 degrades)。

### States and Transitions

#25 本質係 **event-driven、近乎 stateless 嘅 reactive coordinator** —— 無 game-domain state machine,但有兩組有限 sub-state:

**(1) System lifecycle substates**(對齊 #5/#6 pattern):

| Substate | Entry | Exit | Behavior |
|----------|-------|------|----------|
| **Active** | Boot 後 default | `GSM.state_changed → Suspended` | 接收 `hit_resolved` / `enemy_killed`,正常 routing(R-3..R-11);`_process` 推 number pool rise/fade + overlay decay |
| **Suspended** | `GSM.state_changed → Suspended`(直接覆蓋一切) | `GSM.state_changed → 非 Suspended` → Active | **Force reset**:number pool 全 release + hide、overlay force OFF、coalescing window clear、`_dedup` set clear;**reject** 所有 incoming signal(silent no-op + debug counter)。對齊 #6「Suspended 永遠覆蓋一切」契約(bfcache resume 無殘留 number / flash) |

**(2) Overlay primitive sub-state**(R-11):

| State | Entry | Exit | Behavior |
|-------|-------|------|----------|
| **IDLE** | default / flash 完 | CRITICAL/OVERKILL 觸發 → FLASHING | overlay `visible=false`,**zero per-frame cost**(short-circuit,抄 #6 epsilon gate) |
| **FLASHING** | CRITICAL(R-8)/ OVERKILL(R-10)觸發 | duration 完 → IDLE;新 climax → restart(latest-wins) | `ColorRect visible`,`_process` decay alpha → 0 |

**bfcache / Suspended reset** 對齊 #6 EC-10/11/12:resume 一刻 force overlay OFF + number pool clear + `_process(delta)` 入口 `delta = min(delta, MAX_FRAME_DELTA)` clamp(防大 delta 令 number / overlay 一 frame 跳完或殘留)。

### Interactions with Other Systems

| System | Type | Direction | Interface | Ownership | Notes |
|--------|------|-----------|-----------|-----------|-------|
| **#14 EnemyDirector** | Hard | subscribes | `hit_resolved(HitResolvedPayload)` + `enemy_killed(EnemyKilledPayload)` signal | #14 owns signal emission(per #13 Rule 3)+ enemy spawn/death/boss VFX(direct caller #5/#6/#7) | #25 係 per-hit reaction 層;**唔重做** #14 owned VFX(R-9/R-10/R-11) |
| **#13 CombatResolver** | Hard(schema) | reads schema | `DamageTier` / `HitOutcome` enum + `HitResolvedPayload` field schema | #13 owns combat math + enum/payload schema(pure static func,**NO signal**) | #25 consume `damage_tier`(FR Test #4 — no re-classify R-2);**唔直接 call #13** |
| **#5 ParticleSystemWrapper** | Hard | direct caller | `play(preset_id, position, mult) -> ParticleHandle` | #5 owns particle lifecycle + 200 cap + LRU eviction | #25 call `play(HIT_LIGHT/HIT_HEAVY)`;**share 200 cap globally w/ #14**(#5 LRU 仲裁,#25 唔自管預算);graceful INVALID(R-16);coalescing self-throttle(R-15) |
| **#6 ScreenEffects** | Hard | direct caller(`hit_pause` only)+ indirect(auto-dispatch shake) | `hit_pause(duration ≤ 0.12)` direct;shake 經 #6 auto-subscribe #5 `burst_started` | #6 owns trauma + shader uniform;#6 `_DISPATCH` map 4/9 preset → shake/pause | #25 direct `hit_pause` 填 HIT_HEAVY/DEATH 嘅 `pause=0` 缺口;**唔 direct shake**(R-13);PARRY 嘅 pause #6 已 auto 補 |
| **#26 AvatarRenderer** | **v0.2-only(NOT MVP dep)** | reads(anchor)— **future** | `get_render_anchor()`/facing read-only — **⚠️ grep 確認 #26 暫無此 API**(render-only per ADR-0010,只有 evolution getter) | #26 owns avatar visible state | **MVP 唔依賴 #26**(R-17 用 camera-relative fixed focal point);#26 anchor 係 v0.2 enhancement,待 #26 加 position/facing read API(Q-CV4)。MVP dep arrow 維持 `#25 → 5,6,13,14`(**唔加 26**) |
| **#1 GameStateMachine** | Soft | subscribes | `state_changed` → Suspended reset(Contract 6 `connect_for_initial_state`) | #1 owns canonical state | Suspended → force reset number/overlay(States table) |
| **#20 Gym-Mode HUD** | (boundary,no runtime link) | — | — | #20 owns workout-status HUD(player HP / EXP / connection / set-rep);**NOT enemy damage numbers** | **Ownership clarification(grep-verified 2026-06-11)**:`combat-resolver.md` 已將 damage number 歸 **#25**(L889「#25 owns Damage number popup color」+ L1170「#25 … Damage number rendering style」),**非 #20**。故 #25 own enemy damage number = 與 #13 一致(唔需 supersede,#13 已正確);#20 shipped 只 own workout-status(HP-depleting bar 折入 #25)。無 #13 patch 需要 |
| **#21 Loot Drop Modal** | (layer priority arbitration) | — | overlay layer ordering | #21 owns loot ceremony(CelebrationVFXLayer 110) | #25 CombatOverlayLayer(105)`< 110` → loot ceremony **永遠視覺壓過** combat overlay(Pillar 3「loot 永遠最大」);v0.2 afterglow 撞 loot ceremony 時 loot 贏(Edge Case) |
| **ADR-0001**(Web Export Budget Caps) | Hard(input scope) | amends | `CombatOverlayLayer` layer 105 新增 + owner autoload + BackBufferCopy enumeration note(105 `>100` immune,**唔加入 capture list** — 須喺 ADR 明寫防 phantom-citation) | ADR-0001 owns CanvasLayer topology + 200 cap | 跟 #5/#6/#21-#24 layer-amendment precedent;**ratification-gated**(epic/architecture-time gate,GDD 只 specify requirement) |

## Formulas

> #25 係 routing / presentation 系統 —— 無 balance 數學(嗰啲喺 #13 CombatResolver)。以下 5 條全部係 **presentation curve + 純 lookup**,所有時間以 60fps(`delta ≈ 0.0167s`)計。所有 input 上游已 clamp(`damage_tier` enum-typed;`hit_pause` 由 #6 Formula 3 max-remaining + `MAX_PAUSE_SEC=0.12` 再 clamp)。

### Formula 1 — Damage number rise + fade

floating number 喺 lifetime 內向上飄 + 後半段淡出。

`y_offset(t) = -DAMAGE_NUMBER_RISE_PX × ease_out(t / DAMAGE_NUMBER_LIFETIME_SEC)`
`alpha(t)    = 1.0 - smoothstep(DAMAGE_NUMBER_FADE_START_RATIO, 1.0, t / DAMAGE_NUMBER_LIFETIME_SEC)`

其中 `ease_out(x) = 1.0 - (1.0 - x)²`(quad ease-out),`t` = spawn 後經過秒數。

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| elapsed | t | float | [0, LIFETIME] | number spawn 後經過秒數 |
| rise distance | DAMAGE_NUMBER_RISE_PX | float | 24–56 px | 飄升總距離(向上為負 y) |
| lifetime | DAMAGE_NUMBER_LIFETIME_SEC | float | 0.5–1.2 s | number 存活時間 |
| fade start | DAMAGE_NUMBER_FADE_START_RATIO | float | 0.3–0.7 | 開始淡出嘅 lifetime 比例 |

**Output Range:** `y_offset ∈ [-RISE_PX, 0]`;`alpha ∈ [0, 1]`。`t ≥ LIFETIME` → number release 返 pool(R-19)。**Robustness**:`ease_out` / `smoothstep` 嘅 ratio `t/LIFETIME` 須 `clampf(.., 0.0, 1.0)` 先入 formula —— 否則 `t/LIFETIME > 2`(理論上 release 前唔會,但 MAX_FRAME_DELTA clamp 後仍可短暫 >1)時 `ease_out(x)=1-(1-x)²` 會掉頭變負。clamp 後永遠 monotone。
**Example:** `RISE_PX=40, LIFETIME=0.8, FADE_START=0.5`,t=0.4s(中點)→ `ease_out(0.5)=0.75` → `y_offset = -30px`;`smoothstep(0.5,1.0,0.5)=0` → `alpha=1.0`(剛開始淡)。t=0.8s → `y_offset=-40px, alpha=0`。

### Formula 2 — Overlay flash alpha decay(R-11)

CRITICAL / OVERKILL flash 由 peak opacity 線性衰減到 0。

`overlay_alpha(t) = OVERLAY_MAX_OPACITY × max(0.0, 1.0 - t / FLASH_DURATION_SEC)`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| elapsed | t | float | [0, FLASH_DURATION] | flash 觸發後經過秒數 |
| peak opacity | OVERLAY_MAX_OPACITY | float | 0.2–0.7 | flash 起始不透明度(**fillrate 直接 knob** + 唔遮死 set 中視線,Pillar 2);CRITICAL 預設 0.35 / OVERKILL 0.6 |
| flash duration | FLASH_DURATION_SEC | float | 0.08–0.25 s | CRITICAL 預設 0.18 / OVERKILL 0.12 |

**Output Range:** `overlay_alpha ∈ [0, OVERLAY_MAX_OPACITY]`。`t ≥ FLASH_DURATION` → overlay → IDLE(`visible=false`,zero cost)。latest-wins:新 climass 觸發 → `t` 重置 0 + 採新 climax 嘅 opacity/duration。
**Example:** `OVERKILL: MAX_OPACITY=0.6, DURATION=0.12`,t=0.06s(半程)→ `alpha = 0.6 × 0.5 = 0.30`。t=0.12s → `alpha=0` → IDLE。

### Formula 3 — Per-enemy hit-particle coalescing gate(R-15)

決定本次 hit 係咪 fire particle(防 noise floor + 保護 200 cap)。

```
should_emit_particle(target_id, now_ms) -> bool:
    # int-clean sentinel:first hit(無 entry)永遠 emit;唔用 -INF float(避 int/float 混算)
    if not _last_particle_ms.has(target_id) \
       or now_ms - _last_particle_ms[target_id] >= HIT_PARTICLE_COALESCE_MS:
        _last_particle_ms[target_id] = now_ms
        return true
    return false   # 窗口內已出過 → coalesce(唔重複 play)

# 清理:enemy_killed(target_id) → _last_particle_ms.erase(target_id)(R-14,防 leak)
# Suspended → _last_particle_ms.clear()(States table)
```

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| now | now_ms | int | ≥0 | 當前 monotonic ms |
| last emit | last | int | ≥0 或 -INF | 該 target 上次 fire particle 嘅 ms |
| coalesce window | HIT_PARTICLE_COALESCE_MS | int | 100–300 ms | 同一 target particle 最小間隔;對齊 #5 `EVICTION_MIN_LIFE_MS=150` + #6 peripheral 200ms register threshold |

**Output Range:** bool。`true` 比例隨 hit 頻率上升而下降(高頻 → 多數 coalesce)。**只 gate #25 自己 `play()`;number / pause / overlay 唔受此 gate**(各有自己 budget)。
**Example:** `COALESCE=200`,target=A:t=0ms hit → true(fire);t=120ms hit → false(coalesce,只彈 number);t=210ms hit → true。

### Formula 4 — Tier / outcome → hit_pause duration(piecewise lookup,R-7/R-8/R-10)

#25 direct hit_pause 嘅 duration(填 #6 auto-dispatch `pause=0` 缺口)。

```
hit_pause_sec(outcome, damage_tier) -> float:
    if outcome == OVERKILL:            return HIT_PAUSE_CRITICAL_SEC   # 0.080
    if outcome == KILLED:                                              # R-9 climax-kill carve-out
        if damage_tier == CRITICAL:    return HIT_PAUSE_CRITICAL_SEC   # 0.080 — 招牌 critical-劈死
        return 0.0                                                     # 普通擊殺:#14 death VFX own,#25 唔 pause
    match damage_tier:
        CRITICAL:                      return HIT_PAUSE_CRITICAL_SEC   # 0.080
        HEAVY:                         return HIT_PAUSE_HEAVY_SEC      # 0.065
        _ (MEDIUM/LIGHT/NEGLIGIBLE):   return 0.0
```

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| heavy pause | HIT_PAUSE_HEAVY_SEC | float | 0.0–0.12 s | HEAVY tier 凝固;`≤ #6 MAX_PAUSE_SEC=0.12` 否則被 #6 clamp |
| critical pause | HIT_PAUSE_CRITICAL_SEC | float | 0.0–0.12 s | CRITICAL tier + OVERKILL 凝固(較長 = peripheral tier signal 主載體) |

**Output Range:** `[0, 0.12]`。所有非 0 值 `< MAX_PAUSE_SEC` 故唔觸發 #6 clamp warning。**注意**:呢個 duration 經 `ScreenEffects.hit_pause()` 入 #6 嘅 max-remaining 合併(#6 Rule 8),#25 唔自己 stack。
**Example:** `(NORMAL_HIT, HEAVY)` → 0.065;`(CRITICAL_HIT, CRITICAL)` → 0.080;`(OVERKILL, CRITICAL)` → 0.080;`(KILLED, CRITICAL)` → 0.080(R-9 climax-kill carve-out);`(KILLED, MEDIUM)` → 0.0。

### Formula 5 — Combat-anchor spawn position + jitter(R-17,MVP)

particle / number 嘅 world spawn 點。

`spawn_pos = focal_base + Vector2(facing × ANCHOR_FORWARD_PX, ANCHOR_VERTICAL_PX) + jitter`
`jitter = Vector2(rng.randf_range(-J, J), rng.randf_range(-J, J))`,`J = ANCHOR_JITTER_PX`

其中 **MVP**:`focal_base` = camera-relative 固定 focal point(screen 中下方 → world,經 active Camera2D 換算),`facing = +1`(無 #26 facing source)。**v0.2**(若 #26 加 anchor API):`focal_base = avatar_render_anchor`、`facing = avatar_facing`(read-only,唔 mutate)。

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| focal base | focal_base | Vector2 | world coords | **MVP** = camera-relative fixed focal point;**v0.2** = #26 render anchor(read-only,#26 暫無此 API,Q-CV4) |
| facing | facing | int | {-1, +1} | **MVP** = +1 固定(#26 無 facing API);**v0.2** = 從 #26 read |
| forward offset | ANCHOR_FORWARD_PX | float | 16–64 px | anchor 喺 avatar 前方距離 |
| vertical offset | ANCHOR_VERTICAL_PX | float | -32–0 px | anchor 垂直微調(torso 高度) |
| jitter | ANCHOR_JITTER_PX | float | 0–48 px | 多 enemy 同擊散開避免疊;**presentation-only,排除 deterministic 斷言**(cosmetic RNG) |

**Output Range:** world Vector2 喺 avatar 周邊 box 內。`J=0` → 無 jitter(全部疊喺 focal point,測試用)。
**Example:** `focal_base=(400,300)(camera-relative), facing=+1, FORWARD=40, VERTICAL=-16, J=24` → base=(440,284) + jitter ∈ [(-24,-24),(24,24)]。

> ⚠️ **Determinism note**(coding-standards):Formula 5 嘅 `jitter` 用 RNG,純 cosmetic,**唔可** 入 deterministic unit assertion;測試用 `ANCHOR_JITTER_PX=0` 或注入 seeded RNG 驗 base position。其餘 4 條 formula 全 deterministic。

## Edge Cases

**[Particle / budget]**
- **EC-01 — If `#5.play()` 返 `ParticleHandle.INVALID`(budget LRU drop)**:#25 fail-soft —— damage number + hit_pause + overlay **照常**(三者唔依賴 particle handle);唔 retry、唔 throw、唔 block。Rationale:R-16 / ADR-0009 Foundation-consumer never-throw。
- **EC-02 — If 同一 frame 多個 enemy 被擊(N×hit_resolved)**:每個獨立 route;particle 各自經 R-15 coalescing gate;number 各自加 R-17 jitter 散開;**overlay latest-wins(全 frame 只一個 flash)**。
- **EC-03 — If hit 喺 coalesce 窗口內(R-15 返 false)**:particle **suppress**,但 **damage number 照彈**(number 唔受 coalescing gate)—— 玩家仍見到命中已登記,只係唔重複爆 particle。
- **EC-17 — If 單一快速 enemy LIGHT spam**:R-15 coalescing suppress 多餘 particle;number 受 pool cap(R-19)oldest-recycle。視覺 noise floor 受控。

**[Outcome / tier routing 衝突]**
- **EC-04 — If CRITICAL 之後 rapid succession 又 OVERKILL**:overlay latest-wins → OVERKILL flash **replace** CRITICAL flash(timer 重置 0 + 採 OVERKILL opacity/duration),**唔疊**。
- **EC-05 — If `outcome ∈ {KILLED, OVERKILL}` 同時 `damage_tier` 高**:R-3 outcome gate **FIRST** → 行 kill/overkill 分支,tier 分支 skip(無 double pause / double number)。
- **EC-06 — If `outcome == KILLED` 但 `damage_tier == NEGLIGIBLE`**(1-HP 目標被微傷擊殺):R-3 → KILLED 分支彈 kill-confirm number;NEGLIGIBLE tier 被 outcome gate 蓋過,**唔 silent**。
- **EC-13 — If `is_crit == true` 但 `damage_tier == HEAVY`**(暴擊但傷害 <40% maxHP):R-12 解耦 → number = 暖色 bouncy(`is_crit`);screen-feel = HEAVY(65ms,**無** flash)。**呢個係正確行為唔係 bug**。
- **EC-14 — If `damage_tier == CRITICAL` 但 `is_crit == false`**(大力非暴擊,≥40% maxHP):R-12 → flash + 80ms;number = 白色(無 crit style)。
- **EC-18 — If payload `damage_dealt ≤ 0` 但 `damage_tier != NEGLIGIBLE`**(上游異常):**信 `damage_tier`(R-2)**,唔 second-guess upstream(FR Test #4 — routing key 永遠係 tier,唔係 value)。

**[Idempotency / double-fire]**
- **EC-07 — If 一次擊殺同時 fire `hit_resolved(outcome=KILLED)` + `enemy_killed`**:R-14 dedup(`transition_id` + `target_id`)→ **只彈一次** number;`enemy_killed` 只做 non-visual hook(唔重複 feedback)。

**[Lifecycle / Suspended / bfcache]**
- **EC-08 — If `GSM.state_changed → Suspended` 喺 flash / number 進行中**:States table force reset —— overlay 即 OFF、number pool 全 release+hide、coalescing window + dedup set clear、reject 後續 signal(silent no-op + counter)。對齊 #6「Suspended 永遠覆蓋一切」。
- **EC-09 — If bfcache resume(Safari pagehide→pageshow)**:對齊 #6 EC-10/11/12 —— resume handler force overlay OFF + number pool clear + `_process(delta)` 入口 `delta = min(delta, MAX_FRAME_DELTA=0.1)` clamp(防大 delta 令 number 一 frame 跳完或 overlay 殘留)。Section B Falsifiable「peripheral 無殘留」binding。
- **EC-15 — If hit_resolved 喺 #6 HitPaused 期間到達**(get_tree().paused=true):autoload 係 `PROCESS_MODE_ALWAYS`(#6 Rule 10),#25 照收照 route;新 `hit_pause` 經 #6 max-remaining 合併;particle 下 frame spawn;number/overlay 經 #25 自己 `_process`(亦 ALWAYS)更新。與 #6 selective-freeze 一致。
- **EC-12 — If #25 call `hit_pause` 時 #6 已 paused**:#6 Rule 8 max-remaining(no stack / no extend)—— #25 唔自己管,直接 call,由 #6 仲裁。

**[Dependency 缺席 / anchor]**
- **EC-10 — #26 anchor 不可得 = MVP 正常狀態(非 fallback)**:grep 確認 #26 render-only 無 position API,故 MVP **永遠**用 camera-relative fixed focal point(R-17/F5 primary),`facing → +1`。此非 exceptional degrade —— 係設計 primary path。v0.2 #26 加 anchor API 後先切換。任何情況 fail-soft 唔 crash。
- **EC-19 — If signal 喺 boot 早期(camera 未 ready)到達**:`connect_for_initial_state`(Contract 6)處理 initial state;camera-relative focal point 未算到 → 用 screen-center world default,fail-soft(MVP 本身唔依賴 #26,EC-10 = primary path)。
- **EC-11 — If damage number pool 用盡(> MAX_CONCURRENT_DAMAGE_NUMBERS)**:R-19 oldest-recycle(latest-wins)—— 最新 hit 永遠顯示,最舊未完 number 被回收。

**[ADR ratification gate]**
- **EC-20 — If `CombatOverlayLayer`(105)未 ADR-0001 ratify**:overlay flash 係 ratification-gated feature(同 #5/#6 FR-1/2/3 gated AC 一樣)—— 未 ratify 前 #25 degrade 到 **pause + number only**(無 flash)。⚠️ **degrade-mode tier-separation 補償**:正常 mode 下 HEAVY(65ms)同 CRITICAL(80ms)嘅 peripheral 區分**主要靠 flash**(15ms pause 差低於 peripheral JND);flash 缺席時,改用 `CRITICAL_DEGRADE_PAUSE_SEC = 0.100`(取代 80ms)令 CRITICAL/OVERKILL pause 同 HEAVY 拉開 35ms,**保證 pause 單獨都撐到 top-tier 分離**(仍 < `MAX_PAUSE_SEC=0.12`)。唔 block 其餘 routing。

**[Loot ceremony 互動 — v0.2]**
- **EC-16(v0.2)— If climax afterglow 撞正 #21 loot ceremony**:**loot 贏**(Pillar 3「loot 永遠視覺最大」)—— afterglow 被 suppress / 壓低。CombatOverlayLayer(105)`< 110` 已結構保證 loot ceremony layer 蓋過;afterglow 額外要 logic suppress。MVP 無 afterglow 故此 EC v0.2-only。

## Dependencies

> 詳細 interface + signal contract 見 §Detailed Design「Interactions with Other Systems」表(避免重複);本 section 重點 = dependency type(hard/soft)+ bidirectional 一致性 + 設計時發現嘅 dep 變更。

| # | System | Type | Status | 缺席後果 |
|---|--------|------|--------|----------|
| **14** | EnemyDirector | **Hard** | Approved(merged) | 無 `hit_resolved`/`enemy_killed` → #25 完全無 input,零反應(但 graceful — combat 數學照 resolve) |
| **13** | CombatResolver | **Hard(schema)** | Approved(merged) | 無 `DamageTier`/`HitOutcome`/payload schema → 無 routing key |
| **5** | ParticleSystemWrapper | **Hard** | Approved(merged) | 無 `play()` → hit particle 缺席(Pillar 3 spectacle 減,Pillar 2 仍 work — graceful) |
| **6** | ScreenEffects | **Hard** | Approved(merged) | 無 `hit_pause` + auto-dispatch shake → hit-feel「凝固/震」缺席 |
| **26** | AvatarRenderer | **v0.2-only(NOT MVP)** | Approved(epic implemented,但**無 position/facing API**) | MVP **唔依賴**;v0.2 anchor enhancement 待 #26 加 read API。MVP 用 camera-relative fixed focal point(R-17/F5),非「fallback」而係 primary |
| **1** | GameStateMachine | **Soft** | Approved(merged) | 無 `state_changed` → Suspended reset 失效(bfcache 殘留風險),但正常運作不受影響 |
| **ADR-0001** | Web Export Budget Caps | **Hard(input scope)** | Accepted-structural | `CombatOverlayLayer(105)` amendment 未 ratify → EC-20 degrade(pause+number,無 flash) |

**Bidirectional 一致性:**
- ✅ #14 `enemy-director.md` L592 已列 #25 為 downstream consumer(`hit_resolved` routing,FR Test #4 binding)。
- ✅ #5 / #6「Depended On By」已列 #25(`#25 Combat Visual Feedback (direct caller + auto-dispatch via #5)`)。
- ✅ #13 已列 #25 為 `damage_tier` primary VFX router。
- ✅ **#26 AvatarRenderer 唔需列 #25**(MVP) —— grep 證實 #26 render-only(ADR-0010)零 position/facing API,故 **MVP 唔依賴 #26**;systems-index dep arrow 維持 `#25 → 5,6,13,14`(**唔加 26**)。#26 anchor 係 v0.2 enhancement(待 #26 加 `get_render_anchor()`);屆時先做 bidirectional 補登。原「設計時新發現 soft dep」結論經 grep 推翻 → 降為 v0.2。
- ⚠️ **#20 boundary**:#20 `gym-mode-hud.md` 唔列 #25(無 runtime link);ownership clarification 見 §Interactions 表(#25 own enemy damage number,#20 only workout-status)。

## Tuning Knobs

> 全部 #25-owned(Phase 5b 註冊入 `entities.yaml`)。每個列 safe range + 過高/過低後果。引用(非 owned)嘅上游 knob 喺尾。

| Knob | 預設 | Safe Range | 影響 / 過高 / 過低 |
|------|------|-----------|-------------------|
| `HIT_PAUSE_HEAVY_SEC` | 0.065 | 0.0–0.12 s | HEAVY 凝固時長。**過高**(>0.12)→ 被 #6 `MAX_PAUSE_SEC` clamp + Pillar 2 user-detectable freeze;**過低**(→0)→ HEAVY hit-feel 缺「重」感 |
| `HIT_PAUSE_CRITICAL_SEC` | 0.080 | 0.0–0.12 s | CRITICAL + OVERKILL 凝固(**flash ratified mode**)。flash 為主 peripheral tier marker,pause 為輔。過接近 HEAVY → tier 對比消失(故有 flash 撐)|
| `CRITICAL_DEGRADE_PAUSE_SEC` | 0.100 | 0.085–0.12 s | **flash 未 ratify(EC-20 degrade)時**取代 80ms,令 CRITICAL/OVERKILL pause 同 HEAVY(65ms)拉開 ≥35ms,**pause 單獨撐 top-tier 分離**(flash 缺席補償)。過接近 HEAVY → degrade mode 下 tier 不可辨 |
| `HIT_PARTICLE_COALESCE_MS` | 200 | 100–300 ms | per-enemy particle 節流。**過低**→ noise floor 升 + 200 cap 被 LIGHT spam 食滿 evict climax;**過高**→ 連續擊冇 particle feedback 覺脫節。對齊 #5 `EVICTION_MIN_LIFE_MS=150` |
| `MAX_CONCURRENT_DAMAGE_NUMBERS` | 12 | 8–16 | Label pool size。**過低**→ 多 enemy 時 number 頻繁被 recycle 閃爍;**過高**→ pool memory + 峰值 draw call 升(每個 ~1–2 draw call,share font atlas) |
| `DAMAGE_NUMBER_LIFETIME_SEC` | 0.8 | 0.5–1.2 s | number 存活。**過長**→ 疊到糊 + fillrate + pool churn;**過短**→ 眼角嚟唔切讀 |
| `DAMAGE_NUMBER_RISE_PX` | 40 | 24–56 px | 飄升距離。過大 → 飄出 anchor 區;過小 → 靜止感 |
| `DAMAGE_NUMBER_FADE_START_RATIO` | 0.5 | 0.3–0.7 | 開始淡出比例。過低 → 太快淡;過高 → 突然消失 |
| `CRITICAL_FLASH_DURATION_SEC` | 0.18 | 0.10–0.25 s | CRITICAL 全屏 flash 命時。越短 overlay overlap 窗口越細 |
| `OVERKILL_FLASH_DURATION_SEC` | 0.12 | 0.08–0.18 s | OVERKILL flash 命時。對齊 #6 `MAX_PAUSE_SEC` 嘅 peripheral 節奏 |
| `OVERLAY_MAX_OPACITY_CRITICAL` | 0.35 | 0.2–0.7 | **fillrate 直接 knob** + 唔遮死 set 中視線(Pillar 2)。過高 → 搶 attention + 蓋世界 |
| `OVERLAY_MAX_OPACITY_OVERKILL` | 0.6 | 0.2–0.7 | OVERKILL 可較高(更短命)。同上約束 |
| `ANCHOR_FORWARD_PX` | 40 | 16–64 px | anchor 喺 avatar 前方距離 |
| `ANCHOR_VERTICAL_PX` | -16 | -32–0 px | anchor 垂直(torso 高度) |
| `ANCHOR_JITTER_PX` | 24 | 0–48 px | 多 enemy 散開幅度。**0 = 全疊**(測試用);過大 → number 飄離 combat 區 |
| `MAX_FRAME_DELTA` | 0.1 | 0.05–0.2 s | `_process` delta clamp(bfcache 大 delta 防殘留),對齊 #6 同名 pattern |
| `OVERLAY_RESPECTS_MOTION_INTENSITY` | true | bool | MVP:overlay opacity × #6 `motion_intensity`(0 → 無 flash,**photosensitivity / reduce-motion accessibility**)。v0.2 可拆獨立 photosensitivity toggle(UX flag) |

**引用(非 owned)上游 knob:**
- `MAX_ACTIVE_PARTICLES = 200`(#5,ADR-0001)—— #25 唔自管,經 #5 LRU;只接受 INVALID handle。
- `MAX_PAUSE_SEC = 0.12`(#6)—— #25 所有 hit_pause 值 `≤` 此,唔觸發 clamp。
- `motion_intensity`(#6,player-facing a11y slider)—— #25 overlay opacity read-only 乘之(見上 `OVERLAY_RESPECTS_MOTION_INTENSITY`);hit_pause **唔**乘(對齊 #6「time perturbation ≠ vestibular」)。

## Visual/Audio Requirements

> 本系統係 Pillar 3 嘅 presentation 兌現載體,Visual/Audio = 核心唔係附錄。所有 spec 服從 Player Fantasy「Foveal punch, Peripheral pulse」+「稀疏即重量」+「乾淨定格 + 骯髒爆發」。

### Per-event visual feedback 表

| Event | Particle(#5) | Screen(#6) | Damage number | Overlay(#25) |
|-------|-------------|-----------|---------------|--------------|
| LIGHT hit | `HIT_LIGHT`(細 spark)| 無 | 細暗(foveal bonus)| 無 |
| MEDIUM hit | `HIT_LIGHT` | 無 | 中(白)| 無 |
| HEAVY hit | `HIT_HEAVY` | auto shake 0.4 + #25 pause 65ms | 大(白)| 無 |
| CRITICAL hit | `HIT_HEAVY` | auto shake 0.4 + #25 pause 80ms | 大(暖,若 `is_crit`)| **CRITICAL flash** |
| KILLED(tier < CRITICAL)| 無(死亡 VFX = #14)| #14 DEATH auto shake 0.3 | kill-confirm | 無 |
| KILLED(tier == CRITICAL)| 無(#14 DEATH)| #14 shake 0.3 + #25 pause 80ms | kill-confirm | **CRITICAL flash**(R-9 carve-out)|
| OVERKILL | 無(#14 DEATH)| #25 pause 80ms | overkill | **OVERKILL flash** |

### Damage number 視覺 spec
- **Base style**:high-contrast amber/white + 1px ink shadow(`#1A1D24`@40%,跟 #20 HUD popup convention),full-saturation(world layer 自然 pop against 低飽和世界,符 Layer Discipline)。
- **Crit style(`is_crit`)**:暖橙 + 較大字 + 輕微 bounce(overshoot settle)。**注意:crit 區分係 foveal bonus,唔係 tier 嘅 peripheral 主載體**(R-12)。
- **Motion**:Formula 1 rise + fade(自管 `_process`,無 bounce 除 crit)。
- **唔做**:tier 嘅 size/color 階梯做主要區分(眼角讀唔到)—— tier 由 pause + flash 承載。

### Overlay flash 視覺 spec(R-11)
- **CRITICAL flash**:全屏短促高對比 luminance pulse,`OVERLAY_MAX_OPACITY_CRITICAL=0.35`,`DURATION=0.18s`,線性衰減(Formula 2)。clean 全屏一致(「乾淨定格」)。
- **OVERKILL flash**:更強 `0.6` opacity,更短 `0.12s`。
- **實作**:`ColorRect` + analytic `canvas_item` shader(**無 texture / 無 art asset** —— 程序生成,對齊 #6 analytic-noise 取向);坐 `CombatOverlayLayer(105)`(>100 shake/BBCopy-immune)。
- **Accessibility**:opacity × #6 `motion_intensity`(=0 → 無 flash,photosensitivity 保護,AC-25)。**WCAG 2.3.1(three-flashes)compliance**:single flash ≤0.18s + R-11 single-instance latest-wins + R-15 coalescing 限制 flash 頻率,**結構上唔可能 >3 flash/sec**(連續 climax 互相 replace 唔疊加閃);故符合 WCAG 2.3.1 即使 `motion_intensity>0`。reduce-motion ≠ reduce-flash 嘅獨立 toggle 仍係 Q-CV6 v0.2。

### Art bible principle 對應
- **Particle Budget Rule** → R-15 coalescing 係呢條 rule 喺 #25 嘅 enforcement(唔做 noise-floor spammer,保護 200 cap)。
- **Layer Discipline** → overlay 全飽和(105 BBCopy-immune)、world 低飽和;number 全飽和 pop。
- **Silhouette First** → N/A(#25 唔產生 sprite asset,純 routing + 程序 overlay + font number)。

### Audio direction(co-trigger,唔 own playback)
- #25 係 **combat hit SFX 嘅天然 audio-trigger consumer**(per #4 AudioManager EG-1 — workout/presentation SFX forwarding 落 presentation consumer):tier event 觸發 → `AudioManager.play_sfx(cue)`(HEAVY thud / CRITICAL chime / OVERKILL impact / kill)。**#4 own playback + cue catalog;#25 只 trigger**。
- **Onset 對齊**(對齊 #20 convention):visual peak frame(pause 入、flash 起、number peak)== audio onset;**silent-mode 下 visual 必須獨立完整可讀**(SFX = enhancement 非 primary)。
- ⚠️ #25 ↔ #4 combat-hit cue 契約待對齊(Open Question Q-CV1)。

📌 **Asset Spec** — Visual/Audio 已定義。art bible approved 後,run `/asset-spec system:combat-visual-feedback` 產出 per-asset spec(主要 = damage number font + overlay flash shader params;**無 texture asset** 因 overlay analytic 生成)。

## UI Requirements

> #25 有真 UI(floating damage number + 全屏 combat overlay)—— 但係 **diegetic combat feedback**,唔係 menu/HUD-chrome。

- **Floating damage number**:Label pool(R-19)host = #25-owned `CombatNumberLayer`(`follow_viewport_enabled = true`,sort order 坐 ParticleLayer[10] 之上、HUDLayer[50] 之下);跟 world shake 一體(#6 world-shake shader uniform 施落此 layer)。**host topology(此 layer vs reparent 入 gameplay world、shake-uniform 接駁)= Q-CV2 ADR-0001 amendment scope** —— 原「唔開新 CanvasLayer」訴求同「autoload-owned + world-shaken」相衝(autoload Node2D 預設坐 root,唔會 render 落 world 10-50 層、亦唔食 world-shake uniform),故改由 #25 自管一個 follow-viewport layer 解決(churn 由 single-instance pool + IDLE short-circuit 控制)。
- **Combat overlay**(CRITICAL/OVERKILL flash):`CombatOverlayLayer(105)`,全屏,latest-wins single-instance。**需 ADR-0001 amendment**(layer 105 + owner autoload + BBCopy enumeration note,Q-CV2)。
- **Accessibility**:
  - overlay flash × `motion_intensity`(#6 a11y slider,read-only)→ reduce-motion / photosensitivity 用戶 0 = 無 flash(AC-25)。
  - damage number 無依賴 color 傳 tier(color-blind safe — tier 靠 pause/flash)。
  - 唔遮死 set 中視線(overlay opacity 上限 0.7,Pillar 2)。
- **唔 own**:player HP / EXP / connection / set-rep(嗰啲 #20 Gym-Mode HUD);enemy HP bar(#16 Boss / post-MVP)。

> **📌 UX Flag — Combat Visual Feedback**:本系統有 UI requirements(floating damage number + combat overlay)。Pre-Production 階段 run `/ux-design combat-visual-feedback`(或併入 combat HUD UX spec)產出 UX spec,**先於** epic。Stories 引用 `design/ux/combat-visual-feedback.md`,唔直接 cite 本 GDD。重點 cover:peripheral-glance legibility、damage-number 排版/jitter、overlay accessibility(motion_intensity / photosensitivity)、combat-anchor 定位 feel。systems-index #25 row 標註此 UX flag。

## Acceptance Criteria

> **Test seam**:#25 經 untyped DI seam 注入 mock `ParticleSystemWrapper` / `ScreenEffects` / `AvatarRenderer`(spy 記錄 `play()` / `hit_pause()` call args + count)+ **injectable monotonic clock**(`_now_ms()` 經 DI seam 注入 FakeClock,**唔直接 call `Time.get_ticks_msec()`**)—— F3 coalescing(AC-14)同 R-14 dedup(AC-13)係 time-dependent,靠真 clock 會 flaky(對齊本 project FakeClock 慣例,[[reference_test_persistence_isolation]] 家族)。routing logic 全 unit-testable + deterministic(jitter RNG 排除,Formula 5 note)。Visual/UI 部分 = ADVISORY(screenshot + lead sign-off)。Test path:`tests/unit/combat_visual_feedback/`、wiring `tests/integration/combat_visual_feedback/`、visual `production/qa/evidence/`。

**[Routing — core,全 BLOCKING unit 除註明]**
- **AC-01 [Integration | BLOCKING]**:GIVEN fresh #25 instance(real/fake #14 + MockPersistence-style inject),WHEN `_ready()`,THEN 經 Contract 6 `connect_for_initial_state` connect 到 #14 `hit_resolved` + `enemy_killed`。**用 fresh-instance wiring 驗**(per [[reference_gsm_subscription_pollution]] — 唔靠 real-autoload connection suite-order 存活)。
- **AC-02 [BLOCKING | unit]**(FR Test #4):GIVEN `hit_resolved{damage_tier=HEAVY, damage_dealt=1}`(tier 同 value 矛盾),WHEN route,THEN 用 `HIT_HEAVY` preset(信 tier,**唔** re-classify by value)。
- **AC-03 [BLOCKING | unit]**:GIVEN `damage_tier=NEGLIGIBLE` 且非 kill,WHEN route,THEN spy `#5.play` count==0 AND `#6.hit_pause` count==0 AND number count==0。
- **AC-04 [BLOCKING | unit]**:GIVEN `damage_tier=LIGHT`,WHEN route,THEN `play(HIT_LIGHT)` ×1 AND `hit_pause` ×0 AND number ×1。
- **AC-05 [BLOCKING | unit]**:GIVEN `damage_tier=MEDIUM`,WHEN route,THEN preset == `HIT_LIGHT`(**非** HIT_HEAVY)AND `hit_pause` ×0。
- **AC-06 [BLOCKING | unit]**:GIVEN `damage_tier=HEAVY, outcome=NORMAL_HIT`,WHEN route,THEN `play(HIT_HEAVY)` ×1 AND `hit_pause(0.065)` ×1 AND spy `#6.shake` direct-call count==0(shake 只靠 auto-dispatch)。
- **AC-07a [BLOCKING | unit]**(flash ratified):GIVEN `damage_tier=CRITICAL, outcome=CRITICAL_HIT` 且 `overlay_enabled=true`(config flag),WHEN route,THEN `play(HIT_HEAVY)` + `hit_pause(0.080)` + overlay → FLASHING。
- **AC-07b [BLOCKING | unit]**(EC-20 degrade):GIVEN 同上 但 `overlay_enabled=false`,WHEN route,THEN `play(HIT_HEAVY)` + `hit_pause(CRITICAL_DEGRADE_PAUSE_SEC=0.100)` + overlay 不 FLASHING + number 照彈。**兩個 AC 各 deterministic on config flag**(取代原合併 AC-07 嘅雙合法-outcome 歧義)。
- **AC-08 [BLOCKING | unit]**:GIVEN `outcome=KILLED`(非 OVERKILL)**且 `damage_tier < CRITICAL`**,WHEN route,THEN number ×1 AND `play(DEATH)` ×0 AND `#6.shake` direct ×0 AND `hit_pause` ×0 AND overlay 不 FLASHING。
- **AC-30 [BLOCKING | unit]**(R-9 climax-kill carve-out):GIVEN `outcome=KILLED` 且 `damage_tier == CRITICAL`,WHEN route,THEN kill-confirm number ×1 AND `hit_pause(0.080)` ×1 AND overlay → FLASHING(或 EC-20 degrade)AND `play(DEATH)` ×0 AND `#6.shake` direct ×0。驗招牌 critical-劈死 spectacle 可達。
- **AC-09 [BLOCKING | unit]**:GIVEN `outcome=OVERKILL`,WHEN route,THEN overlay FLASHING + `hit_pause(0.080)` + number ×1 AND `play(DEATH)` ×0 AND `#6.shake` direct ×0。
- **AC-10 [BLOCKING | unit]**:GIVEN `outcome=KILLED, damage_tier=HEAVY`,WHEN route,THEN 行 KILLED 分支 only(`hit_pause` ×0 — 無 HEAVY double)。驗 R-3 outcome-first gate。
- **AC-11 [BLOCKING | static/CI]**:GIVEN #25 source,WHEN grep `ScreenEffects.shake(`,THEN 0 results(只准 `.hit_pause(`)。R-13 double-shake guard CI lint。
- **AC-12 [BLOCKING | unit]**:GIVEN `is_crit=true, damage_tier=HEAVY`,THEN number = crit style + screen-feel=HEAVY(無 flash);GIVEN `is_crit=false, damage_tier=CRITICAL`,THEN flash + number = plain。驗 R-12 雙軸解耦。
- **AC-13 [BLOCKING | unit]**:GIVEN `hit_resolved{outcome=KILLED, transition_id=X, target_id=7}` + `enemy_killed{transition_id=X, target_id=7}`,WHEN 兩者 process,THEN number 恰好彈 1 次。驗 R-14 dedup。
- **AC-14 [BLOCKING | unit]**:GIVEN 同 `target_id` 兩 hit 相隔 < `HIT_PARTICLE_COALESCE_MS`,WHEN route,THEN `play` count==1(第二次 coalesce)AND number count==2(number 唔受 gate)。驗 R-15 + Formula 3。
- **AC-15 [BLOCKING | unit]**:GIVEN `#5.play` 返 `INVALID`,WHEN route,THEN 無 throw AND `hit_pause` + number 照常 fire。驗 R-16 fail-soft。
- **AC-16 [BLOCKING | unit]**:GIVEN overlay FLASHING + numbers active,WHEN `GSM.state_changed→Suspended`,THEN overlay OFF + pool 全 release + 後續 signal reject(no-op)。驗 States table。
- **AC-17 [BLOCKING | unit]**:GIVEN paused/residual,WHEN resume notification,THEN overlay OFF + pool clear + `_process` delta clamp ≤ `MAX_FRAME_DELTA`。驗 EC-09。
- **AC-18 [BLOCKING | unit]**:GIVEN MVP(無 #26 anchor API),WHEN route,THEN spawn at camera-relative fixed focal point AND 無 crash。驗 EC-10 / R-17 MVP primary path。
- **AC-19 [BLOCKING | unit]**:GIVEN number pool 滿,WHEN 新 hit,THEN oldest recycle AND 新 number 顯示。驗 R-19。
- **AC-23 [BLOCKING | unit]**:GIVEN CRITICAL flash 進行中 WHEN OVERKILL 觸發,THEN overlay 仍只 1 個 active(latest-wins,採 OVERKILL opacity/duration)。驗 R-11 / EC-04。
- **AC-25 [BLOCKING | unit]**:GIVEN `motion_intensity==0`,WHEN CRITICAL/OVERKILL,THEN overlay effective opacity == 0(無 flash)。accessibility / photosensitivity 保證。
- **AC-31 [BLOCKING | unit]**(R-14 eviction / F3 leak guard):GIVEN target_id=7 已喺 `_last_particle_ms`,WHEN `enemy_killed{target_id=7}`,THEN `_last_particle_ms.has(7)==false` AND dedup set 清 7。驗 dict 唔隨死敵增長。
- **AC-32 [BLOCKING | unit]**(EC-15):GIVEN #25 `PROCESS_MODE_ALWAYS` 且 `get_tree().paused==true`(#6 HitPaused),WHEN `hit_resolved` 到達,THEN #25 照 route(`play` + number acquire 唔被 tree-pause 凍)AND 無 crash。
- **AC-33 [BLOCKING | unit]**(EC-12):GIVEN #6 已 paused,WHEN #25 call `hit_pause(0.080)`,THEN 直接 forward 去 #6(唔自管 stack)—— spy #6.hit_pause 收到 0.080,由 #6 max-remaining 仲裁。
- **AC-34 [BLOCKING | unit]**(EC-19):GIVEN signal 喺 boot `connect_for_initial_state` initial-state 階段到達,WHEN route,THEN spawn at camera-relative focal point(無 #26 依賴)AND 無 crash。

**[Formula — BLOCKING unit]**
- **AC-20 [BLOCKING | unit]**:GIVEN `RISE_PX=40, LIFETIME=0.8, FADE_START=0.5`,WHEN t=0.4,THEN `y_offset≈-30` AND `alpha==1.0`;t=0.8 → `y_offset==-40, alpha==0`。驗 Formula 1。
- **AC-21 [BLOCKING | unit]**:GIVEN `OVERKILL MAX_OPACITY=0.6, DURATION=0.12`,WHEN t=0.06,THEN `overlay_alpha==0.30`;t≥0.12 → 0 + IDLE。驗 Formula 2。
- **AC-22 [BLOCKING | unit]**:GIVEN `(outcome,tier)` 各組合,WHEN `hit_pause_sec()`,THEN `(NORMAL,HEAVY)→0.065`、`(CRITICAL_HIT,CRITICAL)→0.080`、`(OVERKILL,*)→0.080`、`(KILLED,*)→0.0`、`(*,MEDIUM/LIGHT/NEGLIGIBLE)→0.0`。驗 Formula 4。

**[Ratification-gated — ADVISORY]**
- **AC-24 [ADVISORY | ratification-gated]**:GIVEN `CombatOverlayLayer(105)` 未 ADR-0001 ratify,WHEN CRITICAL/OVERKILL,THEN degrade 到 pause+number(無 flash)AND 無 crash。同 #5/#6 FR-1/2/3 gated AC class。**Gate honesty**:此 AC **唔可** auto-pass —— 未 ratify 期間 test 必須 `pending("ratification-gated: ADR-0001 CombatOverlayLayer amendment")` 顯式跳過(GUT `pending()`),**唔係** assert-true 假綠;ratify 後轉真斷言。(degrade 行為本身 = AC-07b,係 CI-testable;此 AC 淨係 gate 真 flash 渲染。)

**[Static / 衛生 — BLOCKING static]**
- **AC-29 [BLOCKING | static]**:GIVEN #25 source,WHEN grep `GPUParticles2D.new()` / per-label `Tween` / `Timer.new()`,THEN 0 results(particle 經 #5;number 用 pool + `_process` 自管,per R-19 防 orphan)。

**[Visual / Perf — ADVISORY,screenshot + lead sign-off]**
- **AC-26 [ADVISORY | visual]**:damage number 喺 peripheral glance(1 秒)可讀;tier 區分**主要靠 pause 時長 + flash**(非 number size/color — Player Fantasy design principle);number 係 foveal bonus。art-director sign-off。
- **AC-27 [ADVISORY | visual]**:CRITICAL flash 喺 peripheral 可被擒獲 AND 同 HEAVY(無 flash)明顯有別。「乾淨定格 + 骯髒爆發」tone。
- **AC-28 [ADVISORY | perf/integration]**:damage number 峰值 ≤ 16 draw call(share font atlas);全屏 overlay 同時 ≤ 1 active(≤1 blend pass);overlay IDLE 時 zero per-frame cost(short-circuit)。**Gate split**:draw-call / blend-pass / IDLE-short-circuit 三項 = **CI-testable**(spy active-overlay count ≤1、spy pool 峰值);**mobile Safari P95 frame ≤ 16.6ms = VS-tier hardware-gated**(ADR-0001 binding)——**唔可 headless CI auto-pass**,須真機量度或 `pending("VS-tier: real mobile Safari profiling")` 顯式跳過,防假綠。

## Open Questions

| ID | Question | Owner | 解決時機 |
|----|----------|-------|----------|
| **Q-CV1** | #25 ↔ #4 AudioManager combat-hit SFX cue 契約(cue catalog ownership + tier→cue map + onset timing)。#25 trigger / #4 playback。 | audio-director + #25 owner | #4 audio cue 落地時 / epic-time |
| **Q-CV2** | ADR-0001 amendment 覆蓋**兩個** #25-owned CanvasLayer:**(a)** `CombatNumberLayer`(`follow_viewport_enabled`,sort order 坐 ParticleLayer[10] 之上 HUDLayer[50] 之下,**入** world-shake shader-uniform 施加範圍 → 跟 world shake;確認接駁機制 vs reparent 替代方案)+ **(b)** `CombatOverlayLayer(105)`(layer number 確認 + owner autoload + BackBufferCopy enumeration note:105 `>100` immune 故**唔入** capture list,須明寫防 phantom-citation,對齊 [[feedback_lint_allowlist_adr_sync]])。 | technical-director + ADR-0001 owner | architecture / epic-time(overlay ratification-gated AC-24;number-layer ratify 前 fixed-viewport degrade) |
| **Q-CV3** | hit_resolved 精確 contact position —— v0.2 #14 加 `get_enemy_render_position(target_id) -> Vector2` 做 per-enemy 精確定位(MVP = combat-anchor 近似 R-17)。 | #14 owner + #25 owner | v0.2 |
| **Q-CV4** | ✅ **RESOLVED(grep-verified 2026-06-11)**:#26 AvatarRenderer 公開 API 只有 `get_visual_state/get_class_posture/get_evolution_tier/get_animation_state/get_evolution_snapshot` —— **零 position/facing**(render-only per ADR-0010)。決定:MVP 用 camera-relative fixed focal point(R-17/F5 primary,非 fallback),**#26 唔係 MVP dep**。v0.2 若需精確定位 → #26 加 `get_render_anchor() -> Vector2` + facing。**唔再 MVP-blocking**。 | #26 owner + #25 owner | v0.2(MVP 已 resolve)|
| **Q-CV5** | Afterglow 餘燼(v0.2)—— decay 實作(抄 #6 `u_world_saturation_drop` pattern)+ loot-ceremony priority(EC-16,loot 贏)。 | game-designer + technical-artist | v0.2 |
| **Q-CV6** | 獨立 photosensitivity toggle(v0.2)—— 與 `motion_intensity` 分離(reduce-motion ≠ reduce-flash 係兩條 a11y 軸)。 | ux-designer | v0.2 |
| **Q-CV7** | registry 註冊 #25 constant(16 knob)+ 「dual critical」disambiguation note(`DamageTier.CRITICAL` ratio vs `is_crit` roll)。 | #25 owner | Phase 5b(本 session) |
