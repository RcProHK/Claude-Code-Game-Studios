# Gym-Mode HUD

> **Status**: R8 Revised (post 7th `/design-review` + **TWEEN SPIKE**) — R7 fresh-session re-review 2026-06-03 判 **MAJOR REVISION NEEDED**(13 BLOCKING,7 NEW PHANTOM;CD binding:停 paper review 轉 tween spike);spike `prototypes/tween-spike/test_tween_spike.gd`(12/12 pass,Godot 4.6.3)實測 tween runtime behavior,反向 author EC-F4/F8/AC-EC-F4b;13 BLOCKING 全部 inline-resolved,**pending fresh-session re-review**。
> **Author**: Frank + (creative-director · game-designer · ux-designer · ui-programmer · systems-designer · art-director · qa-lead · audio-director)
> **Last Updated**: 2026-06-03 (R8 — 7th design-review revision pass, tween-spike-grounded)
> **R8 revision (2026-06-03)** — CD binding ruling「停 paper review 轉 tween spike」執行後,spike-grounded inline-resolve R7 fresh re-review 13 BLOCKING:
> - **B2/B3/B4/B5/B6(tween cluster,spike-verified)**:EC-F4 + F8 + AC-EC-F4b 由 `prototypes/tween-spike/`(12/12 pass)反向 author——B2 kill path 獨立 erase(`kill()` 唔 emit finished,A1 verified)/ B3 `_restart_count++` 喺 kill-restart branch 最頭先於 cap-check / B4 off-by-one fix(snap 喺第 `max_tween_restart_count+1` 個 event,create 第 1 個唔算 restart)/ B5 empty-handle no-op(identity guard)/ B6 **2-param seam `_on_tween_finished(stat_id, src_tween)`** 取代 R7 single-param(single-param 做唔到 identity 比對,A4 verified `.bind` 可傳 2 param)。
> - **B1+B13(CR-12/AC-CR-12 sort key 重設計)**:改 `tier_ordinal DESC, class_ordinal ASC`(取代 R7 insertion-order)。tier_ordinal 由 **#20-owned `SkillIconRegistry`** 提供(9 MVP slot intrinsic 屬性,#12 published L386/L405 mapping)。**B1 phantom 消除**:唔依賴 Dictionary iteration order(ability-system.md L413 invariant 1 明文「無視 insertion order」→ #12 insertion-order-agnostic)、唔靠 timestamp、唔讀 internal(L696)。**B13 Stagnation Mirror 消除**:tier DESC = 最強(當前)技能先,非最舊霸位。CR-13 加第⑨條 anti-Stagnation 紅線。
> - **B7(F1 upper seam)**:CI joint assert 改兩條 conjunctive(`element<threshold` AND `threshold<ambient`)。
> - **B8(BOSS_ENCOUNTER EXP→○)**:R7 將 EXP 降 ◐ 違 CR-1④ + Anchor moment;R8 改 EXP 留 `○`(餘光可見,reward 即時接收),STAT 降 ◐;glance count BOSS == 4(HP+BossHP+SKILLS+EXP)≤5。順帶修正 matrix STAT=○ vs AC-U-3 count 既存矛盾。
> - **B9(EC-R6 新增)**:◐ deep-dim element 收 stat_changed → skip tween 直接 set(deep-dim 唔喺餘光,motion 無意義 + 食 budget);state 升 emphasis 時 snap reconcile。
> - **B10(AC-U-3 拆層)**:cluster icon cap design-time CI(驗 metadata + `cluster_icon_cap` field)vs runtime ≤4(AC-CR-12 display 邏輯 unit test)。
> - **B11(AC-U-2 cockpit bound)**:REST_PERIOD 雖豁免 glance budget,SKILLS list 仍須有界(top-N + scroll,非無限展開)。
> - **B12(Q-OQ1 #20 consumer stub)**:#20 預留兩條 co-design 分支 stub(correlation-key route / same-frame route),令 dev 入 sprint 有明確 wiring shape。
> **Spike findings**: `prototypes/tween-spike/SPIKE-FINDINGS.md`(authoritative reverse-author spec)。
> **Next**: `/clear` → **fresh-session `/design-review`** 獨立驗 R8(特別驗 tween cluster spec 同 spike reference impl 一致 + B1 sort-key 全鏈 + B8 矩陣/EC-S7/AC-U-3 三處對齊)。
> **PRIOR R7 note(archived)**:
> **R7 revision (2026-06-03)** — STRUCTURAL FREEZE Pass A verified 後 inline-resolve R6 fresh re-review 9 BLOCKING:
> - **B1(CR-12 sort key phantom fix — fix b)**:R6 改「Formula 3 order(tier desc)」仍係 phantom(ability-system.md L372 Formula 3 = emit order 非 collection order;L233 `get_unlocked_abilities()`=insertion-order Dictionary;L380 tier-**ascending** TIER_1 first,R6 讀反方向)。**fix(b)**:接受 insertion-order,#20 直接取頭 4 個(最早 unlock = insertion-order),deterministic + zero #12 churn + CI 可驗。改 CR-12 / AC-CR-12 / EC-S7。
> - **B2(citation 引錯)**:「AC-22/23」引錯(AC-22=cooldown test,AC-23=emit-order signal sequence)。改 cite 正確 line:ability-system.md L233(Dictionary返回)+ L696(NEVER access internal)。
> - **F1(alpha invariant safe-range flip)**:`deep_dim_element_alpha` 上界 0.30 > `deep_dim_alpha_threshold` 下界 0.25 → invariant FLIP 可能。**Fix**:收窄 `deep_dim_element_alpha` safe range 至 [0.15, 0.24](嚴格 < threshold min 0.25);加 CI 開機 assert joint safe-range 約束。
> - **F2(sync dispatch 未明文)**:stat_changed→tween path 嘅 synchronous dispatch 未 spec,AC-EC-F4b「即時讀」同 EC-R4 `call_deferred` 衝突。**Fix**:明文「stat_changed→tween path 用 plain `.connect()` synchronous,唔經 `call_deferred`;`call_deferred` 只限 EC-R4 unlock×state 同幀 race」。
> - **F5(`_active_tweens` handle-map 無定義)**:B9 防負-drift 核心機制但無 first-class 定義。**Fix**:EC-F4 補 `_active_tweens: Dictionary(stat_id→Tween)` first-class spec + invariant `_active_tween_count == _active_tweens.size()`。
> - **F7(REST_PERIOD 9-state gap + ▷ alpha unauthored)**:AC-U-3 counted(3)+exempted(5)=8,REST_PERIOD 兩 list 都冇;▷ surface alpha unauthored → CI undefined。**Fix**:REST_PERIOD 明文加入 exempted list,rationale「唯一對焦窗,豁免 glance budget」;▷ element 豁免 CI alpha 判定(對焦窗唔適用 0.3s glance budget)。
> - **F8/F9(test seam 未 mandate)**:AC-EC-F4b call private `_on_tween_finished` + 直接讀 `_restart_count` 但 GDD 未 mandate expose。**Fix**:EC-F4/AC-EC-F4b 補 seam-requirement block:①具名 callback `_on_tween_finished(stat_id)` ②`_restart_count` inspectable getter,同 AC-CR-2 嘅 `_active_tween_count` 同級 implementation requirement。
> - **correlation key forward-contract**:Q-OQ1/Prov-3 從未明文 author。**Fix**:Q-OQ1 補 forward-contract「co-design 須包含 correlation key requirement」。
> - **Q-OQ13 stale ×3**:Dependencies #4 / BLOCKED / QA flag 三處仍標為 sprint gate(Q-OQ13 已 RESOLVED R6)。**Fix**:三處 sweep 至 RESOLVED 狀態,gate count 6→5。
> - **RECOMMENDED sweep**:EXP anchor-loss rationale / IDLE 豁免 rationale / QA flag「四項 BINDING」/ Coverage Wilson superseded 標註。
> **Next**: `/clear` → **fresh-session `/design-review`** 獨立驗 R7。
> **PRIOR R6 note(archived)**:
> **R6 revision (2026-06-03)** — 解決 R5 fresh re-review 9 BLOCKING(CD MAJOR REVISION synthesis + 5-specialist adversarial convergence)+ sweep RECOMMENDED:
> - **B1(CR-12 phantom sort key)**:R5 Rec-3 將 SKILLS display-cap sort key pin「最近 unlock 時間 desc」係 **phantom interface**——`#12.get_unlocked_abilities()` 返 ID list 排 Formula 3 `(tier_ordinal, class_ordinal)`,**無 timestamp**;`first_unlocked_at_unix` 只喺 persistence-internal `UnlockRecord`,#12 closed API 明文「NEVER access internal」。#20 物理上攞唔到 unlock 時間。**CD Option (a) fix**:sort key 改用 **Formula 3 `(tier desc, class)` order**(#12 已 expose,deterministic,零 upstream churn,符合 consumer-no-upstream-churn 原則)。改 CR-12 / AC-CR-12 / EC-S7。
> - **B2(◐ deep-dim alpha operand 未定義)**:`deep_dim_alpha_threshold=0.35` 有閾值但 GDD 從未 author ◐ element 實際 alpha → AC-U-3 predicate「alpha ≤ 0.35?」左手有右手無 → CANNOT-RUN。Fix:加 `deep_dim_element_alpha=0.22` const(◐ 實際 alpha)+ invariant `deep_dim_element_alpha < deep_dim_alpha_threshold`;◉/○ 由構造 alpha > threshold。
> - **B3(0.35 撞 SUSPENDED effective_dim 0.35)**:AC-U-3 用 `≤` 令 SUSPENDED(effective_dim=0.35)全 element 判 deep-dim → count=0 coincidental pass。Fix:**AC-U-3 per-element glance count 只 apply 喺 non-freeze/non-dim state(WORKOUT_ACTIVE/COMBAT_ACTIVE/BOSS_ENCOUNTER)**;SUSPENDED/DISCONNECTED/LOOT_DROP 由 state 規則直接豁免 count(state-level freeze/dim ≠ per-element 餘光分類);兩個 alpha 軸數值拉開(element 0.22 vs threshold 0.35 vs SUSPENDED dim 0.35,後者唔再參與 count)。
> - **B4(AC-V-1 Wilson dead gate)**:R5 Rec-1 pin「95% Wilson CI 下界 ≥80%,N≥12」做 BINDING gate 數學上不可達(N=12 即使 100% 答中下界 ≈75.8%)→ binding gate 永卡 epic。**CD governance fix**:拆 binding statistical →(binding)protocol 交付 + point estimate ≥80%(N≥12)+ Likert ≥4/5 + 0px anchor;(ADVISORY)Wilson CI 報告做 context,**最終統計閾值 + 現實 N 由 /ux-design 用現實樣本量重設計**。dead binding gate 比無 gate 更壞(侵蝕全 project gate credibility)。
> - **B5(AC-U-3 count==3 未 assert)**:R5 B2 intent(count=3)只喺 EC-S7 散文,AC-U-3 本體只 `≤5` → count=5 regression 過 CI。Fix:AC-U-3 加 per-state exact-count table(WORKOUT_ACTIVE==3 / COMBAT_ACTIVE==3 / BOSS_ENCOUNTER==3),CI 逐 state assert exact 值。
> - **B6(IDLE audio deny 無 spy)**:Coverage 自檢 claim「IDLE via AC-CR-8」但 AC-CR-8 只 assert count/visual,無 SFX spy==0;實際 audio deny 只 3/5。Fix:新增 **AC-EC-S4-IDLE**(對稱其餘 3 deny-state,spy count==0);Coverage 改 4/5(+BOOTING not-rendered = 全覆蓋)。
> - **B7(AC-EC-F4b 非 deterministic + phantom-pass)**:(a)「await 1 frame」違 determinism 標準 + 撞 AC-CR-11 fake-timer 原則 → 改用 logical event-epoch seam(無 frame timing);(b)「final value==target」對 circuit-breaker 存在性零分辨力 → 加 snap-index 斷言(snap 觸發於第 N=max_tween_restart_count 個 event);(c)補 `_restart_count` lifecycle(tween 自然 finished → reset 0)。
> - **B8(EC-A6 false rationale)**:audio-director 核對 `audio-manager.md §84` 證 R5 deletion rationale 為**假**——Rule 3 priority-steal 只保 high 不被 lower steal,`audio_unlock_confirm`=mid 係 unlock-frame high flush 的合法 victim。Fix:deletion **動作保留**(舊機制用 phantom API),但 rationale 改寫為 explicit「接受 audio_unlock_confirm 最壞情況被同幀 high flush steal,enhancement-layer cost」;修 CR-10 對已刪 EC-A6 的 dangling ref;Q-OQ13 改「已驗證+接受 cost」非 false closure。
> - **B9(tween counter 負 drift)**:`_active_tween_count` 無 zero-floor,reduce_motion(無 ++)+ snap(--)可 drift 負。Fix:CR-2/EC-F4 補「decrement floored `max(count-1,0)` 且只在有對應 created tween(track by handle)時 --」;AC-CR-2 補負-floor 斷言。
> - **RECOMMENDED sweep**:disconnect_dim_multiplier 移出 Tuning Knobs(structural const)/ AC-KNOB-B 補 DISCONNECTED no-clamp case / AC-CR-8 EXP Integration fixture 邊界明文 / EXP bar 加 min_bar_height_px / CR-9 REST_PERIOD gate rationale + audio-gate 無 generational guard explicit / pending_buffer_cap rationale 對齊 EC-A1 / streak correlation key forward-contract flag。
> - **Process mandate(R6 exit bar)**:每條 cross-GDD claim 須 cite 上游 GDD line;**exit bar = new-phantom count == 0**——R6 須係最後一輪 phantom-introduction。
> **Next**: `/clear` → **fresh-session `/design-review`** 獨立驗 R6。
> **PRIOR R5 note(archived)**:
> **R5 revision (2026-06-03)** — 解決 R4 re-review 5 BLOCKING + 5 RECOMMENDED(CD synthesis + 5 specialist adversarial convergence):
> - **B1(deep-dim threshold const)**:加 `deep_dim_alpha_threshold` named constant(見 Constants 表 + Tuning Knobs)——EC-S7 counting rule「alpha > deep-dim threshold」唔計入 budget，AC-U-3 CI tool 依此判，但整份 R4 GDD 冇定義此值，CANNOT-RUN。R5 fix:constants 表加 `deep_dim_alpha_threshold=0.35`，AC-U-3 讀 config const。
> - **B2(矩陣 propagation gap)**:WORKOUT_ACTIVE/COMBAT_ACTIVE 矩陣嘅 STAT+SKILLS 由 ○ 降 ◐ deep-dim——R3 收斂3 改咗 EC-S7 counting rule(○ ambient 都計)但只回填 BOSS_ENCOUNTER，WORKOUT/COMBAT 矩陣冇同步 → 5 元素 zero headroom 撞 Pillar 2 anti-pattern③。R5 fix:WORKOUT_ACTIVE/COMBAT_ACTIVE STAT◐+SKILLS◐，餘光可見=HP+EXP+PROG=3；EC-S7/AC-U-3 對應更新。
> - **B3(circuit breaker counter desync)**:AC-EC-F4b「`_active_tween_count` 穩定」措辭遮蔽 desync——circuit breaker snap path = `--`（kill 舊）但**無 `++`**（snap = `set()`，唔創新 tween），若實作假設「kill 後必有 create」則 counter stuck 偏高 → AC-CR-2 idle-後-歸零永久 fail。R5 fix:EC-F4 補 snap path 明文；AC-EC-F4b 改斷言「idle 後 `_active_tween_count == 0`」+ 補 reset-then-resume 斷言。
> - **B4(LOOT dim multiplier const)**:`×0.4` LOOT_DROP dim multiplier 喺 AC-KNOB-B 及 Dim states 以字面嵌入，違反 R3 立下嘅「讀 config const 非字面」原則——同類危險嘅 LOOT 反裸奔。R5 fix:加 `loot_dim_multiplier`/`disconnect_dim_multiplier` const；AC-KNOB-B 讀 config const。
> - **B5(AC-CR-8 label + EC-A6/AC-EC-A6 DELETE)**:B5a: AC-CR-8 EXP forward contract assertions 標 "Logic unit" 但係 chain-level(#9 drop→#11 唔 emit→#20 唔收)，應係 Integration；補 CR-8 trust boundary prose。B5b: EC-A6/AC-EC-A6 整條 DELETE——#20 根本無法量 #4 voice count(#4 `_test_get_active_voice_count()` 係 internal test helper 非 public API)，且 #4 priority-steal 已保護 `audio_unlock_confirm`，#20 主動 yield 係多餘甚至有害(分幀 flush 拖慢高優先 SFX)；機制前提根本係錯。EC count 23→22。Q-OQ13 改「確認 #4 priority-steal 覆蓋 audio_unlock_confirm，#20 唔需要 voice budgeting」。
> - **Rec-1 fixes**:AC-V-1 pin「95% CI 下界 ≥80%（Wilson score interval，N≥12）」；AC-CR-12 skill ordering pin「最近 unlock 時間 desc」；AC-U-6 補 font hard floor；text_scale cross-knob 加 floor note；AC-EC-F4b reset-then-resume 斷言(同 B3)；AC-EC-S4 補 LOOT_DROP + SUSPENDED deny-side assertions。
> **Next**: `/clear` → **fresh-session `/design-review`** 獨立驗 R5。
> **R4 revision (2026-06-03)** — 解決 R3 re-review 3 BLOCKING + 10 RECOMMENDED(CD 裁決 + 5 specialist convergence):
> - **B1(EXP fabrication forward contract)**:AC-CR-8 補 `exp_fill delta==0` 斷言 + SUSPENDED 變體——#20 consumer 自己 own「EXP fill 唔因 IDLE/SUSPENDED stray set_logged 而跳格」嘅淨效果斷言,唔 patch #9。
> - **B2(EC-S4 stale ref)**:EC-S4 + AC-EC-S4 對齊 CR-9 audio gate——DISCONNECTED 期間 set_logged SFX 唔 trigger(DISCONNECTED 不在 gate list)。原「SFX 照 buffer/播」係 R3 audio scope-down 冇 sweep 嘅 stale ref。
> - **B3(AC-EC-F4b 缺失)**:補 AC-EC-F4b(circuit breaker livelock gate)+ Coverage 自檢——EC-F4 引用嘅 BLOCKING AC 原不存在。
> - **B4-降(avatar count)**:EC-S7 + 矩陣 BOSS_ENCOUNTER count 4→3——avatar = #26 AvatarRenderer territory,唔計入 #20 HUD glance budget,AC-U-3 CI 只 count #20-owned elements。
> - **B5-降(Boss HP invariant)**:Visual Boss HP 加 binding invariant「≥1 non-color channel 必存在」取代選項列舉——唔手波,channel type defer /ux-design 但 invariant 係 #20 GDD 嘅承諾。
> - **B6-降(EC-A6 AC)**:新增 AC-EC-A6(ADVISORY,unlock-frame voice headroom,runtime-validated)。
> - **Rec fixes**:AC-EC-R2 加 F4-B ordering 斷言;新增 AC-KNOB-B(dim product floor BLOCKING);CR-10 加 test DI seam spec;AC-V-1 bind CI 下界做 pass 條件;UI Requirements 加 overlay region rule;AC-U-3 加 CI tool deliverable 標注。
> **Next**: `/clear` → **fresh-session `/design-review`** 獨立驗 R4。
> **R3 revision (2026-06-03)** — 解決 R2 re-review 13 BLOCKING,4 CD 收斂裁決 + systemic 升級:
> - **收斂1(架構 re-wire,game-designer F1 + audio-director 項5)**:計數/EXP/progress 改行 **#9-validated path**(`set_progress_changed`/`phase_changed` + #11 `stat_changed`),raw `#2.set_logged` 只留 audio consumer;CR-9 audio gate scope down 到 **GSM-state-level** + 明文承認 residual false-positive(audio enhancement)。修 CR-8/CR-9/Overview/Interactions/AC-CR-8/AC-EC-R4/AC-EC-S1。**修復 count-path fabrication**(原 B1 decouple 將 fabrication 入口由 audio 搬去 count)。
> - **收斂2(phantom API,audio-director 項2 + qa #1)**:刪 Q-OQ11 `get_event_priority()`(#4 closed API 無此 method),#20 改直讀 `SfxCatalog.tres` priority data field。修 CR-10/AC-CR-10。
> - **收斂3(glance count,ux F-1 + game-designer F3)**:counting unit 重定義為「所有餘光可見 element(◉+○)」非只 emphasis;BOSS_ENCOUNTER EXP/PROG 降 `◐` deep-dim 退出餘光(矩陣);skill cluster icon sub-cap ≤4 + display cap。修矩陣/EC-S7/AC-U-3/CR-12。
> - **收斂4(HP rationale,game-designer F2)**:HP 留 L1(CD 維持),rationale 由「持續確認」改 **event-anchored reassurance**(habituation 校準)。
> - **systemic 升級(systems-designer point-fix→systemic)**:F3-A divisor=0 guard(`max(pulse_period,0.5)`)+ F3-B body clamp;KNOB-B floor clamp 由 SUSPENDED-only 升「所有 base_dim×state_multiplier≥0.30」;F4-A restart circuit breaker(`max_tween_restart_count`);SM-A state machine(BannerGate→Suspended transition + 終點 re-evaluate + SM-B AND guard + SM-C generational guard)。
> - **a11y(ux F-3/4/5/6/8)**:Boss HP + skill icon non-color shape channel(色盲);AC-V-1 protocol 重設計(peripheral+shake+secondary-load+N≥12,F-6 測錯 construct fix);layout-isolation rule(F-5);`text_scale`/min-font knob(F-8);reduce_motion 清單補齊 + flash 頻率上限(F-10/F-11)。
> - **qa(absolute 斷言 + const 化)**:AC-CR-8/EC-R4/EC-S1 改 absolute `==注入數`(非遞增/order-invariant phantom-green);AC-CR-2/10/11 讀 config const 非內聯 magic number。新增 AC-V-5(色盲)/ AC-U-6(min-font)。
> - **新 constant**:DIM_PRODUCT_FLOOR / MIN_PULSE_PERIOD / max_tween_restart_count / skill_cluster_display_cap / text_scale。新 Q-OQ13(unlock-frame voice budget)+ EC-A6。
> **Next**: `/clear` → **fresh-session `/design-review`** 獨立驗證 R3 re-wire(re-wire 最易留 stale ref);then `/ux-design gym-mode-hud`(交付 Q-OQ9 binding glance protocol + Boss HP 形態 + skill silhouette glyph set)。
> **PRIOR R2 note(archived)**:
> **Implements Pillar**: **Pillar 2 — 無壓力陪伴 (Frictionless Companion)** [PRIMARY owner]; supporting Pillar 1 / 3
> **System #**: 20 (Presentation / MVP tier)
> **Depends On**: #11 Stat (Approved) · #12 Ability (Approved) · #4 Audio Manager (Approved, merged) · #2 GymSys Client (`set_logged` source) · #9 WorkoutStateTracker (Approved) · #1 GSM (state) · soft: #6 / #8 / #33 / #21
> **Creative Director Review (CD-GDD-ALIGN)**: CONCERNS (accepted) 2026-06-03 — 0 BLOCKING; 4 findings inline-accepted (AD1 Boss/player HP semantic → `/ux-design` · AD2 AC-V-1 glance playtest protocol [必跟進] · C1 #2/#8 bidirectional gap [fallback AC 備] · C2 #33 input-gate deferred [AC-EC-S5 fallback]). 可推進至 Approved。
> **EG-2 absorbed** (from #4 Audio EG-1 Option B): silent-mode banner **audio-buffer gate** (CR-6/7/8) + audio-trigger consumer SFX forwarding (CR-9/10/11) — folded into Detailed Design. **R2 DECOUPLE (B1)**: banner 只 gate **audio buffer flush**,**唔 gate** workout 計數 / EXP 視覺反饋(Pillar 1 真身數據 ≠ audio gesture)。
> **R2 design-review revision (2026-06-03)** — independent adversarial review 解決 4 TRUE blockers:
> - **B1 (Pillar 1 危機)**: soft-gate 由「gate 計數+SFX」改為「只 gate audio buffer」。計數 + EXP 視覺反饋永不等 audio unlock。改 CR-8 / EC-R4 / EC-A1 / EC-S1 / AC-CR-8 / AC-EC-R4 / AC-EC-S1。
> - **B2 (cross-GDD 矛盾)**: `set_complete`=`low` priority(#4 catalog)同 CR-10 buffer mid/high 矛盾 → B1 decouple 後 soft-gate 不再背 Pillar 1,**留 low + 重寫 CR-8/CR-10 rationale**(audio buffer 純 enhancement,唔動 audio-manager.md)。
> - **B3 (visual-language 衝突)**: Boss HP(敵,depleting)改用 **enemy color token**(非 event_amber),同 Player HP(amber,non-depleting)餘光即時區分。改 Visual 持續顯示三條 + Q-OQ10 resolved。
> - **B4 (命脈 AC)**: AC-V-1 glance playtest protocol 由 downstream hope 升做 **#20 epic entry gate**(量化:tachistoscope ≥80% N≥8 / Likert ≥4/5 / anchor 0px)。改 Q-OQ9 + AC-V-1 + QA flag。
> - **+11 Recommended** 順手清(cross-knob floor clamp · F3 fmod · EC-F3 sanitize · flush_stagger_ms · priority API · #9 drop honor · max_concurrent_tweens · AC-CR-11 DI · AC-EC-S9 split · HP L1 rationale · skill-cluster count)。
> **Next**: run `/design-review design/gdd/gym-mode-hud.md` in a FRESH session for re-review; then `/ux-design gym-mode-hud` (**MUST** define AC-V-1 glance playtest protocol — now binding entry gate per B4).

---

## Overview

Gym-Mode HUD 係玩家做緊 gym set 期間、唯一持續顯示喺螢幕嘅 game UI 層。佢將三條 **read-only** 數據流——#11 Stat System 嘅 HP / EXP / stat、#12 Ability System 嘅已裝備技能、#9 WorkoutStateTracker 嘅 set / workout 進度——composite 成一個**高飽和 amber-gold、≤0.3 秒一眼讀到**嘅 status overlay,疊喺 desaturated（−30%）嘅 auto-combat 世界之上。玩家**唔需要 interact**:佢只係「眼角瞄一瞄」就知自己宜家幾強、打到邊、今日仲爭幾多組。呢個正正係 **Pillar 2 無壓力陪伴** 嘅化身——所有 input frictionless、所有 output ceremonial,絕不要求 mid-set 注意力。

除咗顯示,#20 仲孭起兩個 presentation-layer 職責(由 #4 Audio EG-2 relocate 落嚟):**(1) Silent-mode unlock banner**——web audio 要等用戶第一個 gesture 先解鎖,HUD 顯示「㩒一下開聲」banner。**呢個 banner 只 gate audio buffer flush,絕不 gate workout 計數或 EXP 視覺反饋**(B1 decouple):計數同視覺係 Pillar 1 真身數據,唔需要、亦唔應該等一個 audio gesture——玩家做第一組,EXP 即跳格、計數即開始,就算永不 tap banner(戶外/電話袋住/淨係當 idle companion),gameplay 一樣完整,只係冇聲(web audio 物理上未解鎖,聲本來就出唔到)。**(2) Audio-trigger consumer**——#20 用 dedicated child node `WorkoutAudioAdapter` 訂閱 #2 `set_logged`(**此 raw signal 只用嚟觸發 SFX,絕不驅動計數/視覺**——計數/視覺嘅數據源係 #9-validated `set_progress_changed`/`phase_changed` + #11 `stat_changed`,見 CR-8 R3 收斂1),喺 audio LOCKED 時 buffer mid/high priority SFX、`audio_unlocked` 後 flush,並 owns `set_complete` × `streak_chime` 同幀嘅 stagger。consumer 嘅 SFX trigger 用 **GSM-state-level gate**(CR-9 R3:#20 攞唔到 #9 per-set verdict,故 audio gate 只能 coarse,明文承認罕見 residual false-positive 可接受)。audio buffer 純屬 enhancement layer;設計上接受「未 unlock = 暫時冇聲」係正常 graceful degradation,唔會反過來拖累 core gameplay。

**點解要存在**:冇咗 #20,玩家喺 set 中間就完全冇 game 反饋——Pillar 2 嘅「陪伴」蒸發,Pillar 1 嘅「真身數據可見」同 Pillar 3 嘅「爆裝飽和文字」全部冇 surface。佢係呢個 idle-companion game 由「背景跑緊嘅嘢」變成「值得眼角瞄」嘅唯一橋樑。

## Player Fantasy

**核心 fantasy 一句**:玩家喺力竭邊緣咬牙做 rep,眼角餘光掃過 amber-gold 嘅戰報——HP 穩、EXP 啱啱跳——佢冇停、冇 tap、冇對焦,但**知道**自己嘅痛正即時化成力量。HUD 係**沉默見證者(The Silent Witness)**:在場、忠實、即時,但從不要求你回應佢。佢成功嘅標準,係 session 之後你話「我冇點留意過佢」——而你全程安心。

**Anchor metaphor —「餘光戰報 The Glance Dispatch」**:健身房牆上嗰塊鏡。你唔會盯住塊鏡做 rep,但每組之間、每下喘氣嘅瞬間,眼角會掃過——確認自己仲喺度、仲喺變強。HUD = 喺**餘光(peripheral vision)** 接收嘅鏡像戰報,唔需要對焦。呢個 metaphor 本身就 encode 晒設計約束:任何要求對焦先讀到嘅 element 都違反 fantasy。高飽和 amber-gold、大字、低密度、事件驅動 motion——全部由「餘光接收」直接推導,唔係事後加嘅 a11y 要求。

**Anchor moment（Pillar 1 × Pillar 2 交匯點）**:「咬牙第 8 rep,力竭邊緣,眼角餘光掃過——HP bar 冇跌、EXP 條剛因為上一組 set 跳咗一格、角色喺 desaturated 世界照打。你冇停低、冇 tap、冇對焦,但嗰 0.3 秒你**知道**:呢組捱落去佢就升。然後你迫返埋落去做埋最後兩下。」
- 餘光交付 80% 嘅 status;set 之間休息對焦只係**確認**剩低 20% detail——reward 唔係喺對焦先出現,而係喺餘光已經被看到。

**Voice —「沉默見證者」**(fit 現有 register 光譜:介乎 #26 ledger「唔講大話」同 #7 Silent Showrunner 之間,但唔撞 #9 oracle 嘅 loud register):
- **唔係 coach**——絕不可以有「Tap now / Push harder / 加油!」。任何 call-to-action / 祈使句都違反 Pillar 2。
- **唔係 oracle**——必須 mute,唔搶注意力。
- **係 witness**——見證你嘅努力,默默、忠實、即時反映,但**從不要求你回應**。Voice = 「在場而不出聲」。
- **視覺即聲音**——HUD 嘅 voice 幾乎全由視覺承載:amber-gold 嘅溫度、popup 嘅節奏、bar 嘅穩定。文字極少,愈少愈好。
- **慶典留俾出面**——ceremony 屬於掉裝(#21)同 Mirror Moment(#29),唔屬於持續 HUD。#20 嘅 witness 係**安靜嘅在場**,只係令你安心捱到 ceremony 出現嗰刻。

**此 fantasy 服務嘅 Pillars**:Pillar 2 無壓力陪伴(PRIMARY,直接化身);Pillar 1 真身真力(supporting——餘光確認「你嘅痛有 game 意義」);Pillar 3 爆裝刺激(supporting——HUD 只承載 reward 嘅日常 surface,peak ceremony 外置)。

**Anti-pattern 警告（design test 種子）**——主雷:**「焦慮儀表板 The Anxiety Dashboard」**,變成另一個嘈住你嘅 fitness app HUD:① 實時跳動數字製造焦慮(逼對焦監控);② notification / nag 行為(coach voice 變體);③ 資訊密度爆棚變 cockpit;④ 要求 mid-set 互動攞 reward(cardinal sin);⑤ HUD 太搶飽和反客為主,玩家盯 HUD 多過盯 lift。
- **一句總結**:fitness app 想你**盯住佢**(engagement = 收入);Mirror Hero 嘅 HUD 想你**忘記佢**(forget it = 成功)。

## Detailed Design

### Core Rules

| # | Rule |
|---|---|
| **CR-1** | **雙層資訊架構**:Tier 1 餘光層(力竭/shake 下 0.3 秒可讀,承載 80% status)vs Tier 2 對焦層(休息凝視先讀,20% detail)。**Reward 永不鎖 Tier 2**——必須喺餘光已被看到。 |
| **CR-2** | **事件驅動 motion only**:Tier 1 靜止為 default,motion 只由離散事件觸發(EXP 跳格 / HP tick / boss HP 跌)、one-shot、≤1s、自動 settle。**禁 idle 持續抖動 / 跳秒數字**(= Anxiety Dashboard 主雷①)。**同幀並發 tween 硬上限 `max_concurrent_tweens`(default 6)**:workout-complete 可同幀觸發 EXP 跳格 + level-up flash(3 件)+ MAX_HP step + ability flash + PROG step,須 cap 峰值避免 mobile Safari WASM burst-allocation GC stutter;超 cap 嘅低優先 motion 降級為瞬間 `set`(skip tween)。 |
| **CR-3** | **Update model = signal-driven + pull-on-init**:live update 靠 dep push signal(handler 自行 filter,例如 `stat_changed` by `stat_id`,只 redraw 該 sub-widget,**O(1) early-return 非 HUD stat_id** 防高頻 broadcast dispatch 成本);initial / resume 靠 pull query 補真值。**禁 `_process` 每幀 poll 攞 state**(data 一律 push/pull,唔輪詢)。**animation 用 Godot 4 `SceneTreeTween`(`create_tween()`,由 SceneTree 自管,唔經 node `_process`)**;bar value animation 嘅 idle-0-cost 由 **tween 完成即釋放 + `_active_tween_count` 歸 0** 體現(非靠 toggle `set_process`——SceneTreeTween 唔受 `_process` 驅動,R2 釐清原 mental-model 誤述)。**例外**:banner F3 脈動係正當持續 animation,可用 looping tween(`set_loops()`)或受控 `_process`,屬 CR-3 poll 禁令豁免(animation≠state poll),`audio_unlocked` 即 `kill()`/`pause()`。 |
| **CR-4** | **進度係 event-driven estimate,5s gap 靜止**:`set_progress` 一格一格跳(event-driven),**禁逐秒精確倒數**(逼對焦,違 CR-2)。#2 polling 5s gap 期間 HUD **靜止顯示最後 confirmed state**,絕不 interpolate / 估算推進(違反 Pillar 1 anti-fabrication + #9 Falsifiable Test)。set 之間 5s 靜止係 design intent。 |
| **CR-5** | **State-gated visibility**:HUD 顯示/隱藏/強調跟 GSM state(見 States 矩陣);modal(#21 loot)在場主動退讓;`is_input_permitted()==false` 唔收 tap。 |
| **CR-6** | **Banner 顯示條件**:`AudioManager.is_audio_unlocked()==false`(web pre-gesture LOCKED)且 HUD 已離開 Booting → 顯示邀請式「㩒一下開聲」banner(零祈使句,witness register)。`is_audio_unlocked()` 開機已 true(desktop / 已解鎖)→ banner 永不出現。 |
| **CR-7** | **Banner dismiss**:訂 `audio_unlocked`,玩家第一個 tap(= 核心 next-exercise input)自然 unlock → one-shot dismiss,記 `banner_dismissed_this_session`(in-memory,非 persisted)→ **本 session 永不再現**(resume 唔重彈)。 |
| **CR-8** | **計數/視覺行 #9-validated path,audio-buffer gate 只 gate 聲(B1 decouple + R3 收斂1 re-wire)**:`is_audio_unlocked()` 只做 **audio buffer flush** 嘅 ready signal——unlock 前 buffer mid/high SFX、unlock 後 flush。**workout 計數同 EXP 視覺反饋永不等 audio unlock**,但**計數/視覺嘅數據源係 #9-validated signal,絕不食 raw `#2.set_logged`**(R3 fix)——progress/計數綁 **#9 `set_progress_changed` / `phase_changed`**(#9 已經行 WST Rule 8 anti-fabrication validate,IDLE-without-`workout_started` / SUSPENDED 嘅 stray set_logged #9 已 drop,唔會 emit progress),EXP 綁 **#11 `stat_changed(EXP)`**(#11 喺 #9 validate 後先 update stat)。理由:計數/EXP 係 Pillar 1 真身數據,**真身數據必須只認 #9 已 validate 嘅事件**——若 #20 計數直食 raw `set_logged`(B1 decouple 原文之誤),reconnect burst / in-flight 嘅 stray `set_logged`(EC-S4)會令 HUD 計數+1 + EXP 跳格但 #9 判「冇發生」=Silent Witness 講大話=破 Pillar 1(game-designer F1 / audio-director 項5 收斂)。`set_logged` **只**喺 audio consumer path 用(CR-9),且該 path gate 自身。audio buffer 純 enhancement,「未 unlock = 暫冇聲」係正常 graceful degradation(web audio 物理上未解鎖,聲本來出唔到),唔拖累 gameplay。**EXP trust boundary(R5 B5a)**:`stat_changed(EXP)` 係由 #11 emit；#20 受 #11 作為 single source of truth 保護，**唔在 #20 側有 consumer-side EXP fabrication filter**——呢係設計意圖嘅 trust boundary。保證來自 #9 drop + #11 唔 emit；若 #11 bug emit spurious `stat_changed(EXP)`，防線喺 #11 唔喺 #20(#11 已 Approved，anti-fabrication 係佢職責)。 |
| **CR-9** | **Audio-trigger consumer 訂閱 + GSM-state-level gate(R3 收斂1 scope-down)**:dedicated child node `WorkoutAudioAdapter` 訂 `#2.set_logged`(**只此 path 食 raw set_logged,純為觸發 SFX,絕不驅動計數/視覺**)+ `AudioManager.audio_unlocked` +(co-design)#8 `streak_chime` 路由。實際 call `AudioManager.play_sfx(event_id)`。**Gate 機制(明文 wiring,非 hand-wave)**:#20 consumer **攞唔到 #9 嘅 per-set verdict**(EG-1 裁決 #9 係 pure data layer,永不 forward per-set 事件;#9 對 set_logged 嘅 Rule 8 drop 係 #9 內部 state,唔通知 #20)。故 #20 audio gate **只能做 GSM-state-level**:`GSM.get_current_state() ∈ {WORKOUT_ACTIVE, REST_PERIOD, COMBAT_ACTIVE, BOSS_ENCOUNTER}` 先觸發 SFX;SUSPENDED / IDLE / DISCONNECTED / LOOT_DROP / BOOTING 唔出聲。**REST_PERIOD 入 gate list 嘅 rationale(R6 Rec,audio R-5)**:一組 set 完成 → GymSys push `set_logged`,但因 5s polling lag,該 event 可能喺 GSM 已 transition 到 REST_PERIOD 之後先到達;呢個係**合法嘅組完 SFX**(set 確實完成),非 false-positive,故 REST_PERIOD 必須喺 gate list(否則 polling-lag 到達嘅組完 SFX 會被誤 deny)。**明文承認 residual false-positive**:呢個 coarse gate ≠ #9 Rule 8 fine verdict——罕見 edge(in-flight `set_logged` 喺 GSM IDLE 但 #9 已 drop,而 GSM 啱啱 transition 去 WORKOUT_ACTIVE)可能漏出**一聲** SFX。**audio gate 有意唔做 generational guard(R6 Rec,audio R-6)**:視覺 reconcile path 有 SM-C generational guard(in-flight transition 時 defer 一幀再 pull,防 mid-transition stale read);但 **audio gate 嘅 `get_current_state()` 有意唔做對應 guard**——audio 係 enhancement,接受偶發 mid-transition stale-state read 漏/多一聲 SFX,換取 audio path 簡單(唔值得為一聲 enhancement SFX 起 generational-aware 機制)。呢個 asymmetry 係 **explicit decision 非疏忽**。**呢個 cost 可接受**:audio buffer 純 enhancement(CR-8 已立此 framing),一聲 false-positive SFX 嘅 cost 遠低於 #20 重做 #9 truth(違 single-source + #20 內部禁起第二 state machine)嘅架構成本。**關鍵**:呢個 residual 只影響聲(enhancement),**唔影響計數/視覺**(計數行 #9-validated path,CR-8,根本唔受 audio gate 牽連)。 |
| **CR-10** | **Buffer policy + priority source(R3 收斂2:改讀 catalog data,刪 phantom API)**:Audio LOCKED 時 **mid/high** priority SFX → buffer(FIFO `_pending`,cap `pending_buffer_cap` 防 memory);**low priority 直接 drop 唔 buffer**。priority 嘅 source-of-truth 係 **#4 `SfxCatalog.tres`** data resource(`set_complete`=low / `streak_chime`=mid / `workout_complete`=high);**#20 consumer 作為 data consumer 直接 `load("res://.../SfxCatalog.tres")` 讀該 resource 嘅 `priority` field**(data-driven,非 hardcode priority 表,非新增 #4 code API)。**R3 fix**:原文要求 #4 expose `get_event_priority(event_id)` query method 係 **phantom dependency**——#4 已 Approved+merged,其 closed API surface 冇此 method 亦無 commitment;而 priority 本身係 catalog 嘅靜態 data field,#20 讀 data resource 已足,無須 runtime method API。catalog 加 event 須 co-design(#4 Rule),drift 風險受控。`audio_unlocked` 後 flush:flush 用 **independent `flush_stagger_ms`(anti-voice-steal,非借 `set_streak_chime_stagger_ms` 語意間距)**,並 priority-desc 排序 flush。**flush_stagger_ms scope 界定(R3,audio-director 項4)**:`flush_stagger_ms` 只 govern **#20 自己 flush 序列內部** 嘅 steal,**解決唔到** unlock 同幀 #4 self-SFX(`audio_unlock_confirm` mid + BGM crossfade)同 #20 flush 爭 8-voice pool 嘅跨系統 contention。**R6 B8 — contention 處置明文(取代已 rewrite 嘅 EC-A6 false closure)**:此 unlock-frame voice contention **真實存在且 #20 無法亦不應主動管理**(#20 攞唔到 #4 voice count;#4 Rule 3 priority-steal 只保 high 不被 lower steal,唔保 mid `audio_unlock_confirm` 對同幀 flush 嘅 high SFX)→ **明文接受 `audio_unlock_confirm` 最壞情況被 steal 嘅 enhancement-layer cost**(見 EC-A6 R6 + Q-OQ13 explicit-accept;**非**「上游已保護」假 closure)。**R6 B8 補充**:`flush_stagger_ms` priority-desc flush 當 `_pending` 長度 > 8-voice pool 時(`pending_buffer_cap=12` 可達)會有 flush 內部 self-steal(同級 steal 最舊)——亦屬可接受(buffered SFX 係 stale enhancement,補播部分被 steal 無損 gameplay)。**`set_complete`=low rationale(R3,audio-director 項1 校準)**:`set_complete`=low 係 #4 catalog **刻意設計**(Pillar 2 subtle confirmation,非 ritual peak;ritual peak 係 `workout_complete`/`loot_fanfare`=high);故 pre-unlock 一律 drop、unlock 後即播或被高優先 SFX steal 皆符合設計。**唔再用「視覺計數已 unlock 前完成」做 drop 理由**(該理由 conflate 咗「pre-unlock 物理靜音」同「priority buffer policy」兩件事)。**R4 test DI seam(Rec#6)**:`SfxCatalog` resource 路徑須可注入(如 `@export var sfx_catalog: SfxCatalog = preload("res://...")`),default = production path,test 可傳 fake catalog resource——對齊 AC-CR-10 injection seam + ITimerService pattern(AC-CR-11)。直接 hardcode `load()` 令 unit test 無法 fake priority → DI seam 係 implementation requirement,唔係 optional。 |
| **CR-11** | **Stagger ownership**:`set_complete` × `streak_chime` 同幀 → consumer 先播 set_complete,defer streak_chime **80–120ms**(`create_timer`,non-blocking)。此 consumer 係 same-frame funnel;`AudioManager` stateless gateway 唔 delay,delay 100% 喺 #20 側。 |
| **CR-12** | **數據語意(已拍板)+ ability display cap(R3 game-designer F5 / R8 B1+B13 re-design)**:**HP** = `get_stat(MAX_HP)` derive 嘅「身體力量」顯示(穩定/滿,反映 Pillar 1 真身力,**非** depleting combat bar——current-HP runtime owner 不存在,depleting bar 遞後,唔 fabricate);**技能** = `get_unlocked_abilities()`(「今日訓練啟動嘅已解鎖技能」,equip slot deferred 到 #30 v0.2)。**Display cap(R3)**:MVP 無 equip slot = `get_unlocked_abilities()` 無天然上限,隨訓練單調增長;故 **BOSS_ENCOUNTER 嘅 SKILLS cluster 顯示上限 = 最高 tier 嘅頭 4 個 + 「+N」摺疊**(`skill_cluster_display_cap=4`,對齊 EC-S7 pre-attentive sub-cap)。**R8 B1+B13 — sort key 改 `tier_ordinal DESC, class_ordinal ASC`(取代 R7 insertion-order)**:#20 維護一個 **#20-owned static `SkillIconRegistry`**(9 個 MVP-locked canonical ability_id → `{glyph_shape, tier_ordinal, class_ordinal}`;tier 係 slot identity 嘅 intrinsic 屬性——`STRIKE_TIER_3` 恆 tier 2,非 runtime state,#20 render icon 本身已需此 registry)。#20 對 `get_unlocked_abilities()` 返回嘅 ability_id set **施加自己嘅 sort**:`tier_ordinal DESC`(最強技能先)→ `class_ordinal ASC` tie-break(deterministic)→ 取頭 `skill_cluster_display_cap` 個 = **玩家當前最強嘅 4 個技能**。**B1 phantom 點解消失**:sort key = `tier_ordinal`(每個 ability_id 嘅**穩定 intrinsic 屬性**,#12 已 published 喺 ability-system.md L386/L405 `(tier_ordinal, class_ordinal)` mapping),**唔依賴 Dictionary iteration order**(L233 從未 author iteration-order binding contract;ability-system.md L413 invariant 1 明文「無視 insertion order」——#12 刻意 insertion-order-agnostic),**唔靠 timestamp**(#12 唔 expose),**唔讀 internal**(L696;tier 由 #20-owned registry 提供,非 `get_ability_state` 亦可)。direction DESC 係 #20 presentation choice,有意異於 #12 emit_order 嘅 tier-ASC(emit ASC = 升級 ceremony build-up;display DESC = glance「我最強」)。**B13 Stagnation Mirror 點解消失**:tier DESC = 顯示**最強(通常最近解鎖)**技能,反映玩家**當前**實力,唔再係 insertion-order 嘅最舊 TIER_1 永久霸位(原 insertion-order fix 令玩三個月後餘光接收到三個月前嘅自己 = 違 Player Fantasy「確認**仍在**變強」)。**撤銷嘅 phantom sort-key 歷史**:①「最近 unlock 時間 desc」(R5)#12 無 timestamp;②「Formula 3 emit order」(R6)emit order ≠ collection order 且方向讀反;③「insertion-order 頭 4」(R7)依賴 L233 從未 author 嘅 iteration contract + 違 L413 agnostic invariant + Stagnation Mirror。R8 改用 #20-owned registry 嘅 intrinsic tier_ordinal,三個 phantom 根因(依賴上游 ordering)一次過消除。防玩三個月後 cluster 爆 glance budget;完整列表留 L3 對焦層(REST_PERIOD)。 |
| **CR-13** | **Pillar 2 紅線(9 條)**:① 禁 mid-set 互動攞 reward(cardinal sin)② 禁祈使句 ③ 禁 idle motion ④ reward 禁鎖對焦層 ⑤ Tier 1 element 硬上限 ≤5 ⑥ modal 在場退讓 ⑦ 尊重 `is_input_permitted()` ⑧ shake 期間 Tier 1 仍可讀 ⑨ **(R8 B13 — anti-Stagnation Mirror)Tier 1/餘光 element 必須反映玩家*當前*狀態,禁顯示已被 superseded 嘅 stale snapshot**(如 SKILLS cluster 顯示最舊技能而非最強)——Player Fantasy 係「確認*仍在*變強」(現在式),餘光接收到過時嘅自己 = 隱蔽違反 Pillar 2「陪伴成長」;由 CR-12 R8 tier_ordinal DESC sort 兌現(最強技能先,非 insertion-order 最舊)。 |

**Information Tier 分配表**

| Element | Tier | 過「力竭 0.3 秒餘光測試」理由 |
|---|---|---|
| HP(身體力量,穩定) | L1 餘光主 | 大字高飽和固定 anchor,餘光直讀。**HP 留 L1 嘅 value 係 event-anchored reassurance(R3 收斂4,game-designer F2 校準)**——唔係靠「持續被掃描確認」(恆定值 0 bit/frame 會被大腦 habituate filter,「持續確認」rationale 喺注意力經濟前站唔穩);而係靠 **MAX_HP 升級嗰刻嘅 step 跳格**呢個稀有正向事件 = positive reinforcement anchor:每次身體變強,HP 喺 L1 主層跳一格,玩家餘光接到「我變強咗」。平時恆定唔郁係 default,**reassurance 嘅 emotional payload 喺升級事件**,而非 continuous glance。game-concept Anchor moment 明文「HP bar 冇跌」仍係 Pillar 1×2 情緒核心 + Submission safety anchor(「冇跌」=穩定背景,令升級 step 更突出)。故留 L1(CD 維持),但 rationale = event-anchored 非 continuous-confirmation |
| EXP(climbing) | L1 餘光主 | Anchor moment 主角,事件驅動跳格 |
| WorkoutPhase + 粗粒度進度 | L2 餘光次 | 餘光感知「進度感」,細節留 L3 |
| Boss HP(BOSS_ENCOUNTER) | L2→L1 | boss 戰時升 emphasis |
| avatar(desaturated 世界內) | L1 | silhouette 識別 |
| 精確 stat 數值 / 技能 icon 明細 / streak 數 | L3 對焦 | REST_PERIOD 先 surface,set 中唔逼睇 |
| 新技能解鎖 flash | 瞬時 L1 → 常駐 L3 | 一次性慶祝後退 ambient |

### States and Transitions

**HUD Element × GSM GameState 顯示矩陣**(◉Emphasis ○Ambient ◐Deep-dim〔退出餘光帶寬,對焦先見〕 ▷Surface —Hidden ▽Defer ❄Frozen)

> GSM `GameState` 真相(grep-verified):`BOOTING / DISCONNECTED / IDLE / WORKOUT_ACTIVE / REST_PERIOD / COMBAT_ACTIVE / BOSS_ENCOUNTER / LOOT_DROP / SUSPENDED`。`WARM_UP` / `WORKOUT_COMPLETE` 屬 **#9 WorkoutPhase**,唔係 GSM state。

| GameState | HP | EXP | STAT | SKILLS | PROG | BOSS | 重點 |
|---|---|---|---|---|---|---|---|
| BOOTING | — | — | — | — | — | — | HUD 未掛起,boot veil |
| DISCONNECTED | ○dim | — | — | — | — | — | 全 dim + 細 connection glyph,非 nag,唔彈 popup |
| IDLE | ○ | ○ | ○ | ○ | — | — | 待機 ambient;BannerGate 可疊出 |
| WORKOUT_ACTIVE | ◉ | ◉ | ◐ | ◐ | ○ | — | 餘光主場,HP+EXP emphasis；**R5 B2**:STAT/SKILLS 降 ◐(deep-dim,退出餘光帶寬)→ glance count=HP+EXP+PROG=**3≤5✅** |
| REST_PERIOD | ○ | ○ | ▷ | ▷ | ▷ | — | **唯一容許對焦窗**:PROG 升 surface(set X/Y + 下一動作提示) |
| COMBAT_ACTIVE | ◉ | ◉ | ◐ | ◐ | ○ | — | 同 WORKOUT_ACTIVE；STAT/SKILLS 降 ◐(**R5 B2**,count=3) |
| BOSS_ENCOUNTER | ◉ | ○ | ◐ | ◉ | ◐ | ◉ | 強調 BOSS HP + SKILLS,仍 non-interactive。**R8 B8 fix(game-designer BLOCKING — EXP 留餘光,honor CR-1)**:R7 將 EXP 降 ◐(退出餘光)違反 **CR-1 紅線④「reward 永不鎖 Tier 2 對焦層」+ Anchor moment「reward 喺餘光已被看到,唔係對焦先出現」**——Boss 戰正正係玩家做 set、最需要「我嘅 rep 有意義」即時確認嘅時刻,將 EXP 跳格 reward 延後至 REST_PERIOD 對焦 = 把 reward 移入對焦層 = CR-1④違反。**R8 改:EXP 留 `○ ambient`(餘光可見),STAT 由 `○` 降 `◐`(deep-dim)騰 budget**。餘光可見 = HP(◉)+ Boss HP(◉)+ SKILLS cluster(◉,算 1)+ EXP(○) = **4 ≤ 5 ✅**(STAT/PROG deep-dim 唔佔餘光;avatar = #26 territory 唔計入 #20 budget)。**順帶修正既存矛盾**:R7 matrix STAT=○ 但 AC-U-3 count=3 排除 STAT,兩者不一致——R8 將 STAT 明確降 ◐,matrix 同 AC-U-3 對齊。EXP reward「我捱落去佢就升」喺 Boss 戰全程餘光可見,Pillar 1×2 anchor 不被打斷。 |
| LOOT_DROP | ○dim | ○dim | — | — | ▽ | — | **主動 defer**,讓 #21 loot modal 做 ceremony;HUD 唔出 loot 文字 |
| SUSPENDED | ❄ | ❄ | ❄ | ❄ | ❄ | ❄ | **Freeze-dim**:凍結最後值 + 多 dim 一層,唔隱藏唔彈 popup |

*WORKOUT_ACTIVE 之下用 #9 WorkoutPhase 細分 PROG copy*:`WARM_UP`→「準備緊…」(ambient);`SET_ACTIVE`→ set X/Y + 動作名(ambient,絕不跳動);`REST_PERIOD`→ set 完成 + 下一動作 + 剩餘組數(surface);`WORKOUT_COMPLETE`→ 靜態結語(短暫過場,交棒 BOSS/LOOT)。

**HUD 內部 states(薄 view——只自有 3 個 state,其餘 derive GSM,唔重複 truth / 唔起第二個 state machine,避免同 ADR-0006 generational lock drift)**

> **R3 SM-A — banner-render 唔再係獨立 state,而係 Active/BannerGate 共用嘅 `is_audio_unlocked()==false` sub-condition**:呢個解決原 4-state table 嘅 transition 缺口(BannerGate→Suspended 無路徑 + Suspended 終點硬寫 Active 但 EC-S2 要 banner 復現,三處矛盾)。Banner 渲染由 `is_audio_unlocked()==false && !banner_dismissed_this_session` 決定,**任何 non-Suspended/non-Booting state 都可疊 banner**,唔再係一個會「離開唔返」嘅獨立 state。

| State | 進入 | 行為 | 離開(R3:終點 re-evaluate,非硬寫) |
|---|---|---|---|
| **Booting** | GSM BOOTING | 唔 render,boot veil | 離開 BOOTING 且 node ready → **branch**:`is_audio_unlocked() ? Active : BannerGate`(R3 SM-D:skip 喺 Booting 離開時 branch,唔「進入 BannerGate 再 evaluate 離開」) |
| **BannerGate** | `is_audio_unlocked()==false` 且離 Booting | render banner + ambient HUD 已可見;**workout 計數 + EXP 視覺照常運作(B1 decouple,唔 hold)**;只 audio buffer hold 待 flush | `audio_unlocked` → Active;**GSM SUSPENDED / page hidden → Suspended(R3 SM-A:補上此前缺失轉移)** |
| **Active** | 已 unlock(或 banner-dismissed) | 跟矩陣 derive GSM 渲染;flush audio buffer | GSM SUSPENDED / visibilitychange hidden → Suspended |
| **Suspended** | GSM SUSPENDED **或** Page hidden / bfcache pagehide(由 BannerGate 或 Active 任一進入) | **Freeze-dim**,停 motion/popup/SFX trigger | **離開 ⟺ DOM visible AND GSM≠SUSPENDED(R3 SM-B:AND guard,非 OR)** → reconcile → **branch**:`is_audio_unlocked() ? Active : BannerGate`(R3 SM-A:終點 re-evaluate,resume 仍 LOCKED 則返 BannerGate 令 banner 復現,對齊 EC-S2) |

**Banner Flow(audio-buffer gate ONLY,B1 decouple)**:出現(web LOCKED)→ 靜態「㩒一下開聲」+ 輕 amber 脈動(非 CTA 句)→ **此期間 workout 計數 + EXP 視覺已照常運作**(玩家做緊嘅 set 即時計即時跳格,banner 純粹邀請開聲)→ 玩家首 tap → unlock → emit `audio_unlocked` → flush buffered SFX(priority-desc + `flush_stagger_ms`)+ banner fade-out → Active。**unlock 純粹令之後嘅 SFX 出到聲 + 補播 buffered SFX,唔影響任何計數/視覺**(視覺無「補播」概念,因為從未 gate 過)。Skip 路徑:開機已 unlock。Session 規則:dismiss 後永不再現,resume 唔重彈。

**bfcache / focus-out resume reconcile**:進 Suspended = Freeze-dim。Resume 序:① 唔信 stale frame,先 pull 真值(`is_audio_unlocked()` / GSM `get_current_state()`〔係 method 唔係 `.current_state`〕/ #11 stat / #9 phase)。**R3 SM-C — generational guard(ADR-0006 read-side drift)**:reconcile pull GSM state 係單點快照,若 resume 嗰刻 GSM 正喺 in-flight transition(ADR-0006 generational lock 持有期),pull 到嘅可能 mid-transition stale。故 reconcile **只喺 GSM idle(無 in-flight transition)時 pull**——若偵測 transition 進行中(讀 GSM expose 嘅 transition/generation 標記,或 `state_changed` 未 settle)則 **defer 一幀** 再 pull,避免 read-side stale drift(#20 唔起第二 SM 但作為 external reader 仍須同步 generation)② bar 由 frozen 值**一次性 snap** 到真值(唔逐格補播 missed motion)③ **離開 Suspended ⟺ DOM visible AND GSM≠SUSPENDED(R3 SM-B)**;GSM 仍 SUSPENDED → HUD 停 Suspended 唔搶先 ④ banner 防重彈(`banner_dismissed_this_session` true → 永不重出,只 re-check `is_audio_unlocked()`,被 re-lock 則靜默 re-buffer;否則終點 branch 返 BannerGate 令 banner 復現,SM-A)⑤ 唔 double-flush SFX。**不變量**:resume 後 HUD == 當刻真值,零 stale / 零 double-popup / 零 double-SFX。

### Interactions with Other Systems

| Dep | Data IN → #20 | #20 → OUT | push/pull | Owner | 狀態 |
|---|---|---|---|---|---|
| **#11 Stat** | `stat_changed(stat_id,old,new,source,is_equip)` push + `get_stat()` | — | both | #11 | ✅(#11 已列 #20 consumer,指定 `connect_for_initial_state`) |
| **#12 Ability** | `ability_unlocked` push(icon flash)+ `get_unlocked_abilities()` | — | both | #12 | ✅ equip deferred |
| **#9 WST** | `phase_changed` / `set_progress_changed`(debounced 500ms)/ `dominant_class_changed` push + query | — | both | #9 | ✅(#9 列 #20 為 5 consumer 之一) |
| **#4 Audio** | `audio_unlocked` push + `is_audio_unlocked()` | `play_sfx(event_id)` | both + call-out | #4 | ✅ |
| **#2 GymSys** | `set_logged(exercise_id,reps,weight)` push(無 transition_id) | — | push | #2 | ✅ single-flight monotonic |
| **#1 GSM** | `state_changed(from,to,payload)` push + `current_state` pull | —(**絕不** drive transition) | both | #1 | ✅(#1 列 #20 soft dependent) |
| **#8 Streak** | streak 事件(供 stagger streak_chime) | — | TBD | #8 | ⚠️ co-design(Open Q) |
| **#6 ScreenEffects** | 無直接 call(topology coupling) | — | implicit | #6/ADR-0001 | ✅ HUD layer 50 < SE 100 |
| **#33 Attention** | `is_input_permitted()` pull | — | pull | #33 | ⚠️ Not Started,留 seam(Open Q) |

**Subscription wiring**(#20 唔係 autoload,喺 main scene instantiate,所有 autoload `_ready()` 已完):
1. 有 initial-state 概念嘅 signal 全用 `connect_for_initial_state`(`stat_changed` 有 CI lint `check_stat_changed_connect.gd` 強制;`ability_unlocked`;`state_changed`)——令 boot 即收 current value,唔會空白/stale。
2. 瞬時 event(`audio_unlocked` / `set_logged` / `phase_changed`)用 plain `.connect`,initial 用 query pull 補。
3. **pull-then-subscribe**:`_ready()` 先 pull 填 initial UI 再 connect 收後續 delta。
4. `_exit_tree()` kill tween + 清 `_pending` queue,避免 dangling `play_sfx` 喺 destroyed node。

**Provisional interface(carry 去 Open Questions)**:Prov-3 #8 streak signal-for-stagger(#8 GDD 未為 #20 expose);Prov-4 #33 `is_input_permitted()` 未 implement(banner tap 暫「直接 tap→unlock」,gating deferred wiring);Prov-5 `set_logged` 無 transition_id(可接受,server single-flight monotonic dedup)。

## Formulas

> #20 係 Presentation HUD,formula surface 偏薄——3 條真 formula,其餘係 constant(下表)。

### Formula 1 — EXP bar fill ratio

`exp_fill = clamp(current_exp / max(exp_to_next, 1), 0.0, 1.0)`

| Variable | Type | Range | Description |
|---|---|---|---|
| current_exp | int | [0, ∞) | #11 `get_stat(EXP)` 當前累積經驗 |
| exp_to_next | int | [1, ∞) | #11 升級所需(`max(.,1)` 防 div-by-zero) |
| exp_fill | float | [0.0, 1.0] | EXP bar 填充比例(clamped) |

**Output**:[0,1]。clamp 理由:cross-system stale 或剛升級瞬間(current ≥ to_next)唔可以令 bar overflow / 負值。**Example**:340/500 = **0.68**;邊界 500/500 = 1.0。

### Formula 2 — Tween duration(reduce_motion gate)

`tween_duration = reduce_motion ? 0.0 : base_tween_duration`

| Variable | Type | Range | Description |
|---|---|---|---|
| reduce_motion | bool | {T,F} | a11y / 系統 reduce-motion flag |
| base_tween_duration | float | [0.2, 0.5] | constant,default 0.3s |
| tween_duration | float | {0.0} ∪ [0.2,0.5] | SceneTreeTween 實際時長 |

**Output**:離散——reduce_motion 時恰好 0.0(瞬間 `set`,跳過 tween),否則 = base。**Example**:false → 0.3s lerp;true → 0.0 瞬間定位。

### Formula 3 — Banner amber 脈動 alpha

`banner_alpha = clamp(base_alpha + pulse_amp * (0.5 + 0.5 * sin(2π * fmod(t, P) / P)), 0.0, 1.0)`,其中 `P = max(pulse_period, MIN_PULSE_PERIOD)`(`MIN_PULSE_PERIOD = 0.5`)

| Variable | Type | Range | Description |
|---|---|---|---|
| base_alpha | float | [0.6, 0.8] | banner 底 alpha,default 0.7 |
| pulse_amp | float | [0.05, 0.15] | 脈動振幅(**僅 alpha,非 scale**),default 0.1 |
| t | float | [0, ∞) | 自 banner 出現累計秒數 |
| pulse_period | float | [1.5, 2.5] | 一個呼吸週期秒數,default 2.0s |
| banner_alpha | float | [base, base+amp] | 當前 alpha,硬 clamp ≤1.0 |

**Output**:`clamp(...,0,1)` 兌現「硬 clamp ≤1.0」(R3 F3-B:`clamp` 寫入 formula body,非只 prose 承諾——防 `base_alpha` config 誤設高值 + `pulse_amp` 上界令峰值 >1.0)。`fmod(t, P)` 已寫入 body(R2,非只 edge case)——避免 programmer 照字面餵 unwrapped `t`(長 session `t≈3600` 令 `sin()` 大 argument 精度劣化、相位漂移)。**R3 F3-A — divisor=0 guard(load-bearing,對齊 F1 `max(exp_to_next,1)` pattern)**:`P = max(pulse_period, 0.5)` 內嵌 formula body——若 `pulse_period` config 誤設 0(typo / `.tres` 缺欄位反序列化→0),`fmod(t, 0)` 會回 `NaN` → NaN alpha → pulse looping tween 永不 settle livelock(EC-F4)。內嵌 `max()` guard 係硬底,**不可只靠 EC-F7 clamp**(EC-F7 須明文 enumerate `pulse_period` 且保證 clamp 喺 evaluation 前;body guard 係 caller 漏 clamp 時嘅最後防線)。**Example**:base=0.7, amp=0.1, period=2.0, t=0.5 → 0.8(峰);t=1.5 → 0.7(谷);t=3600.5 →(`fmod`=0.5)→ 0.8(無漂移);**period=0 → P=0.5,alpha 不 NaN,tween 不 livelock(F3-A guard)**。
**CR-2 合規界定**:此脈動 **banner-only、非 HUD element**,只擺 alpha 唔擺 scale/position(唔搶餘光);`audio_unlocked` 一 emit **立即 kill tween + banner fade-out**。Banner 唔屬 Tier 1 餘光層,故豁免 CR-2「禁 idle motion」——但明示此豁免邊界,**任何 HUD element 不得援引此 formula 做 idle 動畫**。

### Constants(non-derived)

| Constant | 值 | safe range | 過低 | 過高 |
|---|---|---|---|---|
| `set_streak_chime_stagger_ms` | 100 | [80,120] | 兩聲黐埋分唔開 | streak_chime 似甩拍 |
| `flush_stagger_ms`(R2 新增) | 40 | [30,50] | flush 兩聲撞 voice steal | flush 尾巴拖太長似機關槍 |
| `max_concurrent_tweens`(R2 新增) | 6 | [4,8] | workout-complete burst 被截過多 motion(體感削弱) | 並發 tween 爆 mobile WASM GC stutter |
| `pending_buffer_cap` | 12 | [8,16] | burst 提早 drop SFX(擦 Pillar 1) | flush 堆串補播 + 食 memory |
| `glance_tier1_max` | 5 | ≤5 | 更安全 | 餘光 serial scan,破 0.3s(pre-attentive 4±1) |
| `world_desaturation` | 0.7(−30% sat) | [0.6,0.8] | 世界太灰失辨識 | 對比不足 HUD 唔跳出 |
| `base_dim` | 0.5 | [0.4,0.6] | dim 不足無狀態暗示 | 太黑似斷線/壞 |
| `freeze_dim_extra` | ×0.7(疊 base_dim) | [0.6,0.8] | freeze 同 disconnect 分唔開 | SUSPENDED 太黑似 crash |
| `icon_flash_duration` | 0.6s | [0.4,0.8] | flash 太快餘光接唔到 | 拖尾似 idle motion |
| `DIM_PRODUCT_FLOOR`(R3) | 0.30 | [0.28,0.35] | dim 乘積 floor(systemic) | 太低近全黑似 crash | 太高 dim 失狀態暗示 |
| `MIN_PULSE_PERIOD`(R3) | 0.5 | 固定 | F3 divisor guard 下限 | — | — |
| `max_tween_restart_count`(R3) | 5 | [3,8] | restart circuit breaker | 太低 motion 過早被 snap | 太高 livelock 風險窗大 |
| `skill_cluster_display_cap`(R3) | 4 | ≤4 | BOSS skill cluster icon 上限 | — | >4 餘光 serial scan |
| `loot_dim_multiplier`(R5) | 0.4 | [0.3,0.5] | LOOT_DROP state dim 乘數 | dim 太亮,loot ceremony 對比不足 | 近全黑(DIM_PRODUCT_FLOOR 兜底) |
| `disconnect_dim_multiplier`(R5) | 1.0 | fixed | DISCONNECTED dim 乘數(= base_dim 原值,無額外乘積) | — | — |
| `deep_dim_alpha_threshold`(R5) | 0.35 | [0.25,0.40] | ◐ deep-dim 退出餘光帶寬嘅 alpha 閾值；element effective alpha ≤ threshold → 唔計入 glance budget；CI tool `check_glance_tier1_count.gd` 依此判定 | 太高誤把 ◐ 計入 budget | 太低令 ○ ambient 被誤豁免；最終值由 /ux-design 驗收 |
| `deep_dim_element_alpha`(R6 B2;**R7 F1 收窄 upper bound**) | 0.22 | [0.15,**0.24**] | **◐ deep-dim element 嘅實際 effective alpha**(B2 fix:AC-U-3 predicate 嘅左手 operand)。**Invariant:`deep_dim_element_alpha < deep_dim_alpha_threshold`(0.22 < 0.35,margin 0.13)。R7 F1:upper bound 由 0.30 收窄至 0.24**——原 [0.15,0.30] 令 safe-range 邊界 max(element)=0.30 > min(threshold)=0.25 → invariant 可 FLIP;fix 後 max(element)=0.24 < min(threshold)=0.25,joint safe-range hypercube 任意組合 invariant 成立。**CI 開機 joint assert(R8 B7 — 兩條 conjunctive,補上半截 upper seam)**:`assert deep_dim_element_alpha_max < deep_dim_alpha_threshold_min` **AND** `assert deep_dim_alpha_threshold_max < ambient_alpha_min`(讀 config const 上下界,唔係只 check default 值)。**R8 B7 fix**:R7 只 assert 下半截(element < threshold),漏咗上半截(threshold < ambient)——若 `deep_dim_alpha_threshold` safe range 上界 0.40 被改近 `ambient_alpha` 下界 0.45,upper seam 可 FLIP 而 CI 接唔住。三段 invariant `element < threshold < ambient` 須兩條 assert 全覆蓋。**current safe-range margin**:下半截 max(element)=0.24 < min(threshold)=0.25(margin 0.01);上半截 max(threshold)=0.40 < min(ambient)=0.45(margin 0.05) | 太低 ◐ element 近全隱(對焦都睇唔到,違 Tier 2「對焦可讀」) | 太高升穿 threshold → 誤計入 glance budget |
| `ambient_alpha`(R6 B2) | 0.55 | [0.45,0.70] | **○ ambient element 嘅實際 effective alpha**(餘光可見,計入 glance budget)。**Invariant:`ambient_alpha > deep_dim_alpha_threshold`(0.55 > 0.35)** 確保 ○ 永遠計入、◐ 永遠唔計入,兩者唔會因 threshold 微調而 flip | 太低貼近 threshold,○/◐ 分界唔穩 | 太高搶 ◉ emphasis |

> *DISCONNECTED / LOOT_DROP / SUSPENDED 嘅 dim 統一由 `base_dim` × state multiplier 推導(共用 tuning point);SUSPENDED 額外乘 `freeze_dim_extra`。*
> *引用不重定:`set_progress_changed` debounce **500ms 由 #9 own**,#20 只 consume。*

### Negative-space block(故意冇 formula — Pillar 1 anti-fabrication)

1. **set_progress 內插**:5s polling gap 期間 **禁** 任何 `progress += elapsed/expected` 類推進。純 event-driven step,gap 內靜止顯示最後 confirmed state(CR-4)。
2. **HP fill ratio**:HP = `get_stat(MAX_HP)` 穩定顯示,**非** depleting bar,無 current-HP runtime owner,**禁** fabricate depleting fill(CR-12)。

*Cross-system flag*:`base_dim` / `world_desaturation` / `icon_flash_duration` 等屬 #20 內部 presentation constant,唔跨 GDD,毋須入 `entities.yaml`。

## Edge Cases

> 23 條,分 4 區。Severity:CRITICAL 0 / HIGH 11 / MEDIUM 9 / LOW 3(R2:EC-R4 由 CRITICAL 降 MEDIUM;R3:新增 EC-A6;R5:EC-A6 DELETE;**R6 B8:EC-A6 un-delete 做 LOW** —— R5 deletion 嘅 rationale「#4 priority-steal 已保護」經核對 `audio-manager.md §84` 為假,但 contention 真實存在,故 EC-A6 改寫為「明文接受 enhancement-layer cost」保留記錄;舊機制[讀 internal helper]仍刪,只保 design-acceptance 記錄)。

### A. Formula 邊界
- **EC-F1 [HIGH]** **If** `exp_to_next == 0`(max-level sentinel):F1 `max(0,1)=1` 做分母,current≥1 即 fill=1.0 滿條,無 div-by-zero/NaN。滿條 = max-level 正確語意。
- **EC-F2 [HIGH]** **If** `current_exp > exp_to_next`(升級瞬間未 reset / stale):clamp 1.0 滿條,無 overflow;下個 level-up `stat_changed` snap 返低位。單格 frame 顯滿可接受(當下值確 ≥ to_next,witness 唔講大話)。
- **EC-F3 [HIGH]** **If** `current_exp < 0` 或 `exp_to_next < 0`(非法 push):入 F1 前 sanitize **兩個** input——`current_exp := max(current_exp, 0)` **且** `exp_to_next := max(exp_to_next, 0)`(然後 F1 內部 `max(exp_to_next, 1)` 再保證分母 ≥1)。**注意**:F1 公式內嵌嘅 `max(exp_to_next, 1)` 係 load-bearing,sanitize 係 pre-call guard,兩者並存唔互相取代(R2 釐清:原文只 sanitize `current_exp`,漏咗 `exp_to_next` 負值)。結果 clamp 0.0 空條。
- **EC-F4 [MEDIUM]** **If** `current_exp/exp_to_next == NaN/INF`:入 F1 前 `is_nan/is_inf` guard,fallback 用上一 confirmed `exp_fill` 唔 redraw,log 一次。**唔餵 NaN 入 Tween**(NaN 令 SceneTreeTween 永不 settle、`finished` 永不 emit → `_active_tween_count` 永不歸 0,livelock)。**Boot-time guard(R2)**:若首 frame pull 即 NaN(從未有 confirmed 值),fallback 去 `0.0` 而非 undefined。**Restart livelock guard(R3 F4-A — 具體化,非 prose 願望)**:同 stat_id 高頻 kill-restart(EC-R2)嘅收斂**唔可以靠 OR(reduce_motion default-off + 未定義「最長壽命上限」)**,default config 下兩者皆失效。改為**硬 circuit breaker**:每個 stat_id 維護 `_restart_count`,**連續 kill-restart 達 `max_tween_restart_count(default 5)` 即強制 snap 到 latest target(跳過 tween),`_restart_count` 歸 0**。保證任何 `set_logged` reconnect burst(EC-S4)觸發嘅 `stat_changed` 連珠下,tween 喺有限次數內必 settle。對應 BLOCKING AC(AC-EC-F4b:高頻注入 N>5 個同 stat_id `stat_changed`,斷言 tween 喺 ≤`max_tween_restart_count` 次內被強制 snap)。**Counter ordering(R3 F4-B)**:EC-R2 restart 必須「先 kill 舊(`_active_tween_count--`)後 create 新(`_active_tween_count++`)」,保證 `max_concurrent_tweens` cap 不被 restart transient 突破(峰值不短暫 = N+1)。**Circuit breaker snap path counter(R5 B3)**:snap path = `_active_tween_count--`（kill 舊）且**不 increment**——snap = `set()`，唔創新 tween，F4-B 嘅「先 kill 後 create」唔適用此路徑。實作者不可假設「kill 後必有 create」;snap 後 idle,`_active_tween_count` 正確歸 0(非 stuck 偏高)。**Reset-then-resume**:snap + `_restart_count` 歸 0 係**一次性 reset**,唔係永久 snap-mode;`_restart_count` 歸 0 後,後續全新 event 應正常重啟 tween 計數。**`_restart_count` lifecycle 明文(R6 B7 — systems-designer R4:原本只定義「達 cap → snap → 歸 0」一條 reset path,未達 cap 時點 decay 未定義 → reset-then-resume 唔 deterministic)**:`_restart_count[stat_id]` 嘅完整生命週期 = ① kill-restart 一次 → `++` ② 達 `max_tween_restart_count` → snap + 歸 0 ③ **tween 自然 `finished`(非被 kill)→ `_restart_count[stat_id] := 0`**。第 ③ 條係關鍵——令「時序隔開嘅新 event」有 deterministic 機制 map 到 counter reset:event 之間若上一個 tween 有機會 settle(自然 finished)→ counter 清零 → 下一個正常 tween;只有真正密集 burst(tween 未 settle 又嚟)先會累積到 cap。AC-EC-F4b reset-then-resume 用此 `finished` seam(非 frame-timing)做 deterministic 驗證。**`_active_tween_count` zero-floor + handle-tracking(R6 B9)**:counter `--` 必須 `_active_tween_count = max(_active_tween_count - 1, 0)` **且只在有對應 created tween(track by tween handle/reference,非 blind `--`)時先 decrement**——防 reduce_motion path(F2 instant `set()` 從未 `++`)+ snap path(`--`)+ EC-F5 mid-flight kill 多路徑無配對 `++` 而 drift 負值(負 counter 令 AC-CR-2 idle==0 同 `max_concurrent_tweens` cap 判定失準、可 silently over-admit tween)。AC-EC-F4b 已更新斷言覆蓋 lifecycle 三條 + snap-index。**R7 F5 / R8 spike-grounded — `_active_tweens` handle-map first-class spec**:SUT 維護 `_active_tweens: Dictionary`(key = `stat_id: StringName`,value = live `Tween` reference;EC-R2 kill-restart 保證每 stat_id 最多一個 live tween)。**Invariant:`_active_tween_count == _active_tweens.size()`**(spike test_B2 verified 喺整個 restart burst 維持)。**R8 B2 — kill path 必須有獨立 erase code path(spike A1 verified:`kill()` 唔 emit `finished`)**:`_kill(stat_id)` 自帶 `if t != null and t.is_valid(): t.kill()` → `if _active_tweens.has(stat_id): _active_tweens.erase(stat_id); _active_tween_count = maxi(count-1, 0)`。**EC-R2 restart / EC-F5 reduce_motion mid-flight kill 一律行此 `_kill` 獨立 erase,絕不可靠 `_on_tween_finished` callback**(kill 唔觸發 finished,靠 callback 會令 dictionary entry 殘留 → invariant 即破)。Decrement 兩條入口互斥:① `_kill`(主動 kill 路徑)② `_on_tween_finished`(自然完成路徑,帶 identity guard,見 F8)。**呢個 dictionary 唔係 optional——係防負-drift + identity guard 嘅唯一地面真相**。**R7 F2 — synchronous dispatch 明文(F2 fix,治 AC-EC-F4b「即時讀」同 EC-R4 衝突)**:`stat_changed` → tween/snap handler 必須用 **plain `.connect()` synchronous** dispatch(signal handler 同步 fire,inject 後可即時讀 bar value);**唔可以係 `CONNECT_DEFERRED`**。`call_deferred` **只**限 EC-R4「audio_unlocked × state_changed→WORKOUT_ACTIVE 同幀 race」嘅 reconcile pass(唔覆蓋 normal stat_changed tween path)。呢個確保 AC-EC-F4b「注入第 N 個 event 嗰一刻即時讀」斷言 well-defined(同步 handler → 讀到最新值)。**R8 F8/F9 — test seam requirement block(spike-grounded;2-param seam 取代 R7 single-param)**(對齊 AC-CR-2 `_active_tween_count`「俾 test 讀」同 AC-CR-10/AC-CR-11 DI-seam 標準):① SUT 必須將 `tween.finished` 路由去**具名 2-param** internal callback **`_on_tween_finished(stat_id: StringName, src_tween: Tween)`**(非匿名 lambda),經 `tween.finished.connect(_on_tween_finished.bind(stat_id, t))` wire(spike A4 verified:`finished` 0-arg signal + `.bind(stat_id, t)` → callback 正確收 2 param)。callback 內**必須有 identity guard `if _active_tweens.get(stat_id) != src_tween: return`**(B6/spike test_B6:stale 舊 tween 殘響到達時唔誤刪新 entry);guard 通過後先 `_active_tweens.erase(stat_id)` + `_active_tween_count = maxi(count-1,0)` + `_restart_count[stat_id] = 0`(lifecycle ③ 自然完成 reset)。**R8 fix**:R7 嘅 single-`stat_id` seam 物理上做唔到 identity 比對 → 改 2-param。test 可直接 call `sut._on_tween_finished(stat_id, tween_ref)` 做 deterministic finished-event seam。② SUT 必須令 `_restart_count: Dictionary(stat_id→int)` **可被 test inspect**(public getter `_get_restart_count_for_test(stat_id)`),唔可純 private。**R8 B3 — `_restart_count++` ordering pin(spike test_B3/test_B4 verified)**:kill-restart branch 第一步 `_restart_count[stat_id] += 1` → **即 compare cap**(`if _restart_count[stat_id] >= max_tween_restart_count: snap + reset 0 + return`)→ 否則 `_kill` → `_create`。`++` 必須先於 cap-check 且先於 kill;create(首個 event,`_active_tweens` 無 entry)行 else 分支唔 `++`。組合呢個 seam-requirement block + F5 `_active_tweens` spec = AC-EC-F4b 全部斷言可 deterministic 驗證。
- **EC-F5 [HIGH]** **If** `reduce_motion` 喺 tween 跑緊由 false→true:in-flight tween 即 `kill()`+`set()` snap 到 target,`set_process(false)`,唔等自然完。反向 true→false 只影響之後新事件。
- **EC-F6 [MEDIUM]** **If** banner `t` 長累積溢出:`fmod(t,pulse_period)` 餵 sin,數學等價永不溢出。
- **EC-F7 [LOW]** **If** presentation constant(`world_desaturation`/`base_dim` 等)config 設 range 外:clamp safe range 用 default 唔 crash,log warning。

### B. Signal race / 同幀
- **EC-R1 [HIGH]** **If** 同幀多個 `stat_changed`(不同 stat_id):各 handler 按 stat_id filter 只 redraw 該 sub-widget(CR-3),各自起 tween,唔 batch full redraw(破 draw-call budget)。
- **EC-R2 [HIGH]** **If** 同一 stat_id tween 未完又嚟新 `stat_changed`:kill 舊 tween,由**當前 interpolated 值** restart 去新 target(唔由原起點重播 = 唔回跳,唔疊兩 tween)。reduce_motion 時直接 snap。
- **EC-R3 [HIGH]** **If** `state_changed`(GSM)同 `phase_changed`(#9)同幀語意矛盾:GSM state 為 visibility/emphasis 主權威(矩陣 driver),#9 phase 只供 PROG copy;各管各層唔互相否決。
- **EC-R4 [MEDIUM — B1 decouple 後由 CRITICAL 降級]** **If** `audio_unlocked` 同 GSM `state_changed`→WORKOUT_ACTIVE 同幀:**計數同 EXP 視覺完全唔受同幀 ordering 影響**(B1 decouple,計數從未 gate,任何 ordering 下照行)。唯一 ordering 關注係 audio buffer flush vs 矩陣 apply,而 audio 係 enhancement、非 critical,所以**唔需要強制 atomic ordering**。實作上兩個 handler 各自 set flag + `call_deferred` 一個 reconcile pass(避免 signal connect-order race),pass 內 unlock→flush 喺 matrix apply 前後皆可(視覺/計數結果相同)。原「首組 SFX flush 須先於計數」嘅 CRITICAL 約束隨 decouple 消失。
- **EC-R5 [MEDIUM]** **If** `ability_unlocked`(flash 0.6s)未完又嚟第二個:不同 icon slot 各自 one-shot 並行;同 slot 罕見重觸 kill-restart;flash 完一律退 L3 ambient。
- **EC-R6 [MEDIUM — R8 B9]** **If** `◐ deep-dim element`(退出餘光帶寬,如 BOSS_ENCOUNTER 嘅 STAT/PROG、WORKOUT_ACTIVE 嘅 STAT/SKILLS)收到 `stat_changed` / `set_progress_changed` value update:**直接 `set()` 更新底層 value,skip tween(唔播 motion、唔 `++ _active_tween_count`)**。理由:deep-dim element 唔喺 0.3s 餘光帶寬,motion 對 glance 零意義,且會白白食 `max_concurrent_tweens` budget + 喺 mobile WASM 製造 GC(CR-2)。value 仍即時更新(data 唔 stale),只係**唔以 tween 形式呈現**。**State transition 升 emphasis 時 reconcile**:當 element 由 `◐` 升返 `◉`/`○`(GSM state 切換,如 BOSS_ENCOUNTER→REST_PERIOD 令 STAT ◐→▷),**一次性 snap 到當前 value**(唔回播 deep-dim 期間 missed 嘅逐格 motion——對齊 bfcache reconcile「唔重播 missed motion」原則,EC-S9)。此規則令 ◐ element 嘅 motion 行為 deterministic,封死「deep-dim element 應 skip-tween 定 dim-tween」嘅 undefined gap。

### C. Audio consumer
- **EC-A1 [HIGH]** **If** workout 完從未 unlock(全程冇 tap):**計數 + EXP 視覺全程照常運作**(收斂1——計數行 #9-validated path,gameplay 完整,session 正常記錄,與 audio unlock 完全正交);只係 audio 層 `_pending` FIFO 超 `pending_buffer_cap` drop oldest、永不 unlock = 永不 flush、`_exit_tree` 清 `_pending`(CR-9 wiring 4)。無 gesture = web audio 物理上唔出聲,buffer 只係善意,丟咗都只係冇聲、唔影響任何 game state。
- **EC-A2 [MEDIUM]** **If** `streak_chime` 到但冇對應 `set_complete`(單獨):直接播唔 stagger;CR-11 stagger 只在 set_complete×streak_chime 同幀並存時觸發。
- **EC-A3 [MEDIUM]** **If** flush 進行中又嚟新 `set_logged`:入 `_pending` 隊尾經隊列消化(保 FIFO+stagger 不撞 voice-steal),唔插隊即播;flush 完隊列空恢復即播。
- **EC-A4 [HIGH]** **If** stagger timer(deferred streak_chime 100ms)未 fire 就 suspend/`_exit_tree`:timer callback guard 檢查 node still in tree + 非 Suspended,否則 drop 該 deferred chime(唔喺 freeze/destroyed 出聲)。
- **EC-A5 [LOW]** **If** flush 時 `_pending` 內出現 low priority(CR-10 理論不可能):防禦 assert,drop+log 唔播(出現即 buffer policy bug)。
- **EC-A6 [LOW — R6 B8 rationale rewrite;機制刪、cost 明文接受]** **If** unlock 同幀 #20 flush buffered SFX(含 `workout_complete`=high)同 #4 self-SFX(`audio_unlock_confirm`=mid)爭 8-voice pool:**接受 `audio_unlock_confirm` 喺最壞情況被同幀 flush 嘅 high SFX steal,屬 enhancement-layer 可接受 cost,#20 不採取任何主動 voice-budgeting**。**R6 B8 rationale 修正(audio-director 核對 `audio-manager.md §84`)**:R5 B5b 原 rationale「#4 priority-steal 全面保護 `audio_unlock_confirm`」**經核對為假**——#4 Rule 3 priority-steal **只保證 high 不被 lower steal**,`audio_unlock_confirm`=mid 只係相對 low 受保護;unlock-frame 正係唯一保證有 high buffered SFX(`workout_complete`)入 pool 嘅一幀,一個 high 入 pool 會 steal 任何非-high voice → mid 嘅 `audio_unlock_confirm` 係**合法 victim**。**原 EC-A6 機制(#20 讀 `_test_get_active_voice_count()` 主動 yield)刪除動作正確**:該 method 係 #4 internal test helper 非 public API(#20 量唔到 voice count),且分幀 flush 會拖慢 buffered high SFX。但**唔可以用「上游已保護」嘅假 rationale close 一個真實存在嘅 contention**——故保留此 EC 記錄 contention + 明文接受 cost(audio = enhancement,unlock confirm 偶被 steal 唔損 gameplay)。詳見 Q-OQ13(已改 explicit-accept,非 false closure)。

### D. State transition / provisional / web-perf
- **EC-S1 [HIGH]** **If** BannerGate 期間 GSM 已 WORKOUT_ACTIVE:HUD ambient 已顯示,**計數 + EXP 視覺即時運作**(收斂1——計數行 #9-validated path,唔 hold);只 audio SFX 入 buffer 待 unlock flush。首 tap→`audio_unlocked` 補播 buffered SFX。**GSM 自行前進唔被 HUD 阻**(HUD 絕不 drive GSM);banner gate 只限 #20 自己嘅 audio buffer flush,唔掂計數/視覺。
- **EC-S2 [MEDIUM]** **If** 進 SUSPENDED 但 banner 未 dismiss:Freeze-dim 疊 banner,pulse tween 暫停;Resume 仍 LOCKED 且 `banner_dismissed_this_session==false`→banner 復現+pulse 重啟;期間被 unlock 過 → 永不重出。
- **EC-S3 [HIGH]** **If** GSM 進 LOOT_DROP 但 #21 modal 未 ready/未實作:HUD 按矩陣主動 defer(HP/EXP ○dim,PROG ▽,唔出 loot 文字),維持 defer 直到離開 LOOT_DROP。**HUD 絕不 fallback 自畫 loot 文字**(越界違 CR-13⑥ + Layer Discipline)。留 seam(Open Q)。
- **EC-S4 [MEDIUM]** **If** DISCONNECTED 期間有 `set_logged` 到(reconnect burst / in-flight):**視覺靜、聲靜**——**SFX 唔 trigger(CR-9 gate:DISCONNECTED 不在 {WORKOUT_ACTIVE,REST_PERIOD,COMBAT_ACTIVE,BOSS_ENCOUNTER},唔 buffer 唔播)**;視覺維持 dim 不彈 popup(忠於斷線)。**R4 fix(B2)**:原「SFX 照 buffer/播」係 R3 audio scope-down 冇 sweep 嘅 stale ref——DISCONNECTED 出 SFX = false-positive(斷線期 game world 感知唔到 set),唔出聲係 witness 誠實;Resume 後若 GSM 進 WORKOUT_ACTIVE 則 normal trigger。
- **EC-S5 [HIGH]** **If** `is_input_permitted()`(#33)未 implement 時 banner tap:per Prov-4 直接 tap→unlock(gating deferred);banner tap = 解鎖 gesture 非 game 互動,唔違 Pillar 2(unlock 唔攞 reward);#33 ready 後 wrap game-affecting tap,banner-unlock tap 永遠豁免。
- **EC-S6 [MEDIUM]** **If** #8 streak signal 未 expose(Prov-3)時 set_complete 到:正常即播無 stagger;CR-11 邏輯休眠直到 #8 co-design 落實;唔因等一個唔存在嘅 chime 而 defer set_complete。
- **EC-S7 [HIGH]** **If** 餘光可見 element > `glance_tier1_max=5`:**design-time 硬約束非 runtime**。**R3 收斂3 — counting unit 重定義(ux F-1 fix)**:counting unit = **所有佔用 0.3s 餘光帶寬嘅 visible element**——即任何 alpha > deep-dim threshold 且喺 desaturated world 上有 figure-ground 對比者,**`◉` emphasis 同 `○` ambient 都計**(餘光 pre-attentive scan 唔分 emphasis 級別,任何在場高飽和 amber/crimson element 都佔一個 glance slot)。原 R2「只計 emphasis、○不計」係為過 gate 而偷換概念,實際 ○ ambient 仍佔餘光——已 fix。**唯一豁免**:`◐` deep-dim element 主動降到退出餘光帶寬(對焦先見),唔計入 budget。**R5 B1 + R6 B2/B3:threshold = `deep_dim_alpha_threshold`(default 0.35),被比較 operand = element 實際 effective alpha**——`◉`/`○` element effective alpha = `ambient_alpha(0.55)` 或更高(> threshold,**計入**);`◐` element effective alpha = `deep_dim_element_alpha(0.22)`(< threshold,**唔計**);invariant `deep_dim_element_alpha(0.22) < deep_dim_alpha_threshold(0.35) < ambient_alpha(0.55)` 保證分界穩定,唔會因 threshold 微調而 flip。CI tool `check_glance_tier1_count.gd` 讀 const 做判據,唔可 hardcode。**R6 B3 — counting scope 限定**:per-element alpha glance count **只 apply 喺有真實餘光競爭嘅 non-freeze/non-dim state(`WORKOUT_ACTIVE` / `COMBAT_ACTIVE` / `BOSS_ENCOUNTER`)**;`SUSPENDED` / `DISCONNECTED` / `LOOT_DROP` 由 **state-level 規則直接豁免 glance count**(state-level freeze/dim 係整體 HUD alpha override,語意 ≠ per-element 餘光分類——SUSPENDED effective_dim 碰巧 = 0.35 同 threshold 撞值純屬數軸重疊,唔應令 SUSPENDED 行 per-element 判定;呢個 scope 限定杜絕「調 DIM_PRODUCT_FLOOR 或 base_dim 竟 trip glance CI」嘅 nonsensical coupling)。**skill-icon cluster**:按 Gestalt proximity 算 **1 個 grouped element**,但 **cluster 內 icon 數設 sub-cap ≤4**(game-designer F3 / 對齊 pre-attentive subitizing 4±1;cluster 內 >4 icon 餘光會 serial scan 唔再係單一 texture region)——超 4 個 active ability 須摺疊「最高 tier 頭 4 + 『+N』」(見 CR-12 R8 display cap;sort key = `tier_ordinal DESC, class_ordinal ASC`,由 #20-owned `SkillIconRegistry` 提供 intrinsic tier_ordinal[ability-system.md L386/L405 published mapping];**唔依賴** Dictionary iteration order[L413 invariant 1 明文「無視 insertion order」]、**唔靠** timestamp[#12 唔 expose]、**唔讀** internal[L696];R7 insertion-order 已撤[違 L413 + Stagnation Mirror])。**BOSS_ENCOUNTER 重驗(R4 B4 avatar 移出 budget / R8 B8 EXP 留餘光)**:HP(◉)+ Boss HP(◉ crimson)+ SKILLS cluster(◉,算 1,icon ≤4)+ **EXP(○,R8 B8:留餘光 honor CR-1,唔再降 ◐)** = **4 餘光可見 ≤ 5 ✅**;STAT + PROG 喺 BOSS_ENCOUNTER 降 `◐` deep-dim **退出餘光**(矩陣 R8),故唔計。**avatar silhouette 唔計入 #20 HUD glance budget**——avatar = #26 AvatarRenderer territory(Q-OQ8 明文),唔屬 #20 HUD element;AC-U-3 CI tool 只 count #20-owned elements(冇 `glance_visible` metadata 嘅 #26 sprite 唔納入)。改 R3「4」→「3」。**WORKOUT_ACTIVE/COMBAT_ACTIVE 重驗(R5 B2 — 矩陣 propagate EC-S7 counting rule)**:STAT+SKILLS 降 ◐ deep-dim(退出餘光帶寬)→ 餘光可見 = HP(◉)+EXP(◉)+PROG(○) = **3 ≤ 5 ✅**;COMBAT_ACTIVE 同。AC-U-3 per-state WORKOUT_ACTIVE/COMBAT_ACTIVE count 須 == 3。新增 #20-owned 餘光可見 element / 拆散 cluster / cluster icon >4 必重驗(CI/review-time gate,AC-U-3);**runtime 唔自動隱藏**(自動隱破餘光穩定)。
- **EC-S8 [LOW]** **If** desktop(開機已 unlocked):BannerGate skip→Active,banner 永不出現,F3 永不執行,soft-gate 即解,`set_logged` 即時計數+即播。
- **EC-S9 [MEDIUM]** **If** pageshow/resume 後 pull 到 GSM state 同 freeze 前唔同(freeze@WORKOUT_ACTIVE,resume@LOOT_DROP):一次性 reconcile 到新 state 矩陣(snap),banner/buffer 按 reconcile 序;**唔重播 missed state 動畫**(bfcache 期 motion 無意義,Pillar 1 只認當下真值)。

## Dependencies

| Dep | 方向 | 硬/軟 | Interface | Bidirectional 狀態 |
|---|---|---|---|---|
| **#11 Stat System** | upstream | **Hard** | `stat_changed` push + `get_stat(MAX_HP/EXP/...)` query | ✅ #11 已列 #20 為 consumer(指定 `connect_for_initial_state`) |
| **#9 WorkoutStateTracker** | upstream | **Hard** | `phase_changed`/`set_progress_changed`(debounce 500ms)/`dominant_class_changed` + query | ✅ #9 已列 #20 為 5 consumer 之一 |
| **#1 Game State Machine** | upstream | **Hard** | `state_changed(from,to,payload)` + `current_state` pull | ✅ #1 已列 #20 為 soft dependent(reads `current_state` to switch HUD layout) |
| **#4 Audio Manager** | upstream | **Hard** | `is_audio_unlocked()`/`audio_unlocked`/`play_sfx()` + **讀 `SfxCatalog.tres` priority data field(R3 收斂2:取代原 phantom `get_event_priority()` method)** | ✅ EG-1 已將 workout-SFX forwarding ownership relocate 落 #20;✅ R3:priority 改讀 catalog data resource(非 #4 新 API),零 #4 churn;✅ Q-OQ13 RESOLVED(R6 explicit-accept:unlock-frame audio_unlock_confirm 最壞情況被同幀 high flush steal,enhancement-layer cost,#20 **無需** co-design + 無需 sprint gate) |
| **#2 GymSys Backend Client** | upstream | **Hard**(audio-consumer 角色) | `set_logged(exercise_id,reps,weight)` push(直接 subscribe) | ⚠️ **one-directional**——#2 GDD 未列 #20 為 subscriber。flag 補 #2 consumer 列表(Q-OQ5)。(R2:刪原「#18 先例」dead ref,#18 PR-Detection 未實作) |
| **#12 Ability System** | upstream | Soft | `ability_unlocked` push(icon flash)+ `get_unlocked_abilities()` | ✅ #12 framing 已提「ability unlock → #20 HUD icon flash」;equip API deferred |
| **#8 Streak System** | upstream | Soft(co-design) | streak 事件供 stagger `streak_chime` | ⚠️ **one-directional**——#8 GDD 未為 #20 expose streak signal。#8↔#20 co-design point(Prov-3) |
| **#6 Screen Effects** | sibling(topology) | Soft | 無直接 call;`hud_shakes_with_world=true` → HUD layer 50 < SE 100,跟世界 shake | ✅ topology-coupled,constant 由 #6 own(#20 為 referrer) |
| **#33 Attention Budget & Interaction Policy** | upstream | Soft(deferred) | `is_input_permitted()` pull gating | ⚠️ #33 **Not Started**;#20 留 deferred wiring seam(Prov-4) |
| **#21 Loot Drop Modal** | **downstream** | Soft | #20 喺 GSM LOOT_DROP **主動 defer**,讓 #21 做 ceremony 主角;#20 唔出 loot 文字 | ⚠️ #21 **Not Started**;defer 行為已定,#21 ready 後對接(EC-S3 seam) |

**Hard dependencies(缺則 #20 無法運作)**:#11(HP/EXP/stat 無數據源)、#9(無進度)、#1(無 state 切 layout)、#4(banner/SFX 係 #20 職責)、#2(audio-consumer 無 set_logged 源)。
**Soft dependencies(enhanced 但 works without)**:#12(技能可顯示空)、#8(無 stagger,chime 即播)、#6(無 shake coupling)、#33(無 gating,banner tap 仍 work)、#21(loot defer,#21 未 ready 仍 defer)。

**需補嘅 bidirectional gap**:① #2 GDD 加 #20 為 `set_logged` subscriber;② #8 GDD 為 #20 expose streak-event signal(co-design)。兩者 carry 去 Open Questions + 跨系統 gate。

## Tuning Knobs

**#20 owned knobs**

| Knob | Default | Safe range | 影響 gameplay aspect | 過高 | 過低 | Player-facing? |
|---|---|---|---|---|---|---|
| `base_tween_duration` | 0.3s | [0.2,0.5] | bar 動畫平滑度 | 拖尾似 idle motion | 跳得太硬冇平滑感 | 否 |
| `reduce_motion` | false | {T,F} | a11y——關晒 tween(瞬間 set) | — | — | **✅ a11y** |
| `set_streak_chime_stagger_ms` | 100 | [80,120] | 雙聲分離度 | streak_chime 似甩拍 | 兩聲黐埋 | 否 |
| `flush_stagger_ms`(R2) | 40 | [30,50] | flush 連播 anti-voice-steal 間距 | flush 尾巴拖長似機關槍 | 兩聲撞 voice steal | 否 |
| `max_concurrent_tweens`(R2) | 6 | [4,8] | 同幀並發 tween 峰值 cap | 並發 tween 爆 WASM GC stutter | burst motion 被截過多(體感削弱) | 否 |
| `pending_buffer_cap` | 12 | [8,16] | LOCKED buffer memory | flush 堆串 + 食 memory | burst 提早 drop SFX(擦 Pillar 1) | 否 |
| `glance_tier1_max` | 5 | ≤5 | 餘光 0.3s 可讀性(design-time) | 餘光 serial scan 破 0.3s | 更安全 | 否 |
| `base_dim` | 0.5 | [0.4,0.6] | DISCONNECTED/LOOT dim 程度 | 太黑似壞 | 無狀態暗示 | 否 |
| `freeze_dim_extra` | ×0.7 | [0.6,0.8] | SUSPENDED 額外 dim | 似 crash | freeze≈disconnect 分唔開 | 否 |
| `icon_flash_duration` | 0.6s | [0.4,0.8] | 技能解鎖 flash 時長 | 拖尾似 idle motion | 餘光接唔到 | 否 |
| `banner_base_alpha` | 0.7 | [0.6,0.8] | banner 可見度 | 太實搶餘光 | 睇唔到提示 | 否 |
| `banner_pulse_amp` | 0.1 | [0.05,0.15] | banner 呼吸感 | 抖到搶注意力 | 似靜態冇邀請感 | 否 |
| `banner_pulse_period` | 2.0s | [1.5,2.5] | banner 呼吸節奏 | 慢到察覺唔到 | 快到緊張 | 否 |
| `loot_dim_multiplier`(R5) | 0.4 | [0.3,0.5] | LOOT_DROP HUD dim 乘數 | loot ceremony 對比不足 | 近全黑(DIM_PRODUCT_FLOOR 兜底) | 否 |
| `disconnect_dim_multiplier`(R5;**R6 Rec:structural non-tunable**) | 1.0 | **fixed(非 tuning knob,結構常數)** | DISCONNECTED dim 乘數(base_dim 原值,無額外乘積)。**R6 Rec(systems R1)**:此值恆 1.0、無 safe range,唔符合「tuning knob = 可調 + 有 safe range」定義;留喺 Tuning Knobs 表只為 formula uniformity(統一 `base_dim × state_multiplier` shape)。明文標 **structural**,唔應被當作可調 knob | — | — | 否 |
| `deep_dim_alpha_threshold`(R5) | 0.35 | [0.25,0.40] | ◐ deep-dim 退出餘光帶寬 alpha 閾值；element alpha ≤ 此值 → 唔計入 glance budget；最終值由 /ux-design 驗 | 誤把 ◐ element 計入 budget | 誤豁免 ○ ambient | 否 |

**Cross-knob interactions**
- `reduce_motion=true` → `base_tween_duration` **失效**(F2 strictly 0),亦應令 `banner_pulse_amp` 視為 0(banner 靜態)、`icon_flash_duration` 縮至瞬顯。**R3 F-10 補齊清單**:reduce_motion master override 須同時覆蓋 ① bar **step ticker → 單次 snap**(唔逐格播)② popup **overshoot 1.1× → 無 bounce 直接定位** ③ level-up flash 三件 co-trigger **→ 靜態 amber(無白峰,亦 R3 F-11 photosensitivity:white-peak frame 受 reduce_motion 抑制)**。reduce_motion 係所有 motion knob 嘅 master override。
- **`text_scale`(R3 F-8 新增,player-facing a11y)**:default 1.0,safe range [0.8, 2.0],全 HUD 字號 master scale;`min_font_size_px` floor 保證最低可讀(見 AC-U-6)。MSDF 保 crisp 但唔保最低尺寸,故 text_scale 係獨立 a11y knob。
- **Flash 頻率上限(R3 F-11 photosensitivity)**:同類 white-peak flash(level-up)最小間隔須防高頻 set 完成觸發 >3Hz 白閃(WCAG 2.3.1 three-flash);實作加 flash debounce floor。
- `glance_tier1_max` × 實際 L1 element 數:design-time 互鎖,加 element 必重驗(EC-S7),非 runtime auto-hide。
- **`base_dim` × 任何 state multiplier:systemic product floor(R3 KNOB-B — 由 point-fix 升 systemic)**。R2 只為 SUSPENDED(`base_dim × freeze_dim_extra`)加 floor,但 **LOOT_DROP 嘅 `× 0.4` multiplier 同類危險未 cover**:`base_dim` 下界 `0.4 × 0.4 = 0.16` ≪ 危險閾值 0.28(HUD 近全黑,玩家以為 crash),比 SUSPENDED 更黑。故 R3 改為 **統一規則:任何 state 嘅有效 dim = `base_dim × state_multiplier`,一律 clamp `≥ DIM_PRODUCT_FLOOR(0.30)`**——涵蓋 SUSPENDED(`freeze_dim_extra`)、LOOT_DROP(`×0.4`)、DISCONNECTED 及任何未來 state multiplier。**Clamp 落點(R3 KNOB-A)**:clamp 嘅係**最終乘積值(effective display multiplier)**,**唔反推回 individual knob**(若反推 factor 會令某 knob 跌出自身 safe range);即 `effective_dim = max(base_dim × state_multiplier, 0.30)`,log warning。default:SUSPENDED `base_dim × freeze_dim_extra = 0.5 × 0.7 = 0.35` ✅、LOOT `base_dim × loot_dim_multiplier = 0.5 × 0.4 = 0.20 → clamp DIM_PRODUCT_FLOOR = 0.30`(**R5 B4:兩個 state multiplier 均讀 named const,唔用字面**;注:LOOT default 即觸發 clamp,建議 art-bible 同 #21 co-design 確認 LOOT dim 應否 ≥0.30 定放寬 floor,Q-OQ7 旁註)。
- **`world_desaturation` × `base_dim`:正交,無 joint danger(R3 KNOB-C 明文)**——`world_desaturation` 作用喺 world CanvasLayer 飽和度,`base_dim` 作用喺 HUD alpha/明度,兩者唔同 layer 唔同 channel(§Visual「#20 dim 係 alpha 層,同 MoodController saturation 層正交」),唔相乘喺同一 pixel,不構成 product danger。明文排除以防未來 reviewer 重提。

**Referenced knobs(非 #20 own,point to source)**
- `world_desaturation`(0.7 / −30% sat):屬 **art-bible Layer Discipline** 全域常數,#20 只 reference 確保 HUD 飽和度對比;**唔由 #20 重定**。
- `set_progress_changed` debounce(500ms):**#9 own**,#20 只 consume。
- `hud_shakes_with_world`(true):**#6 own**(registry),#20 為 referrer。
- `motion_intensity`(#6 a11y slider):若 master 場景將 `reduce_motion` 綁 #6 motion slider,則 #20 `reduce_motion` 應 derive 自該 a11y source(避免兩個獨立 a11y toggle)——co-design flag。

## Visual/Audio Requirements

**設計總綱**:所有 motion = 「Snap-in → Settle → 退場」三段,**絕無 idle 動畫**(banner 脈動唯一豁免)。餘光 0.3s 可讀靠三 channel:**位置固定** + **形狀** + **飽和 amber 對比 desaturated world**。

### Visual event feedback spec

| Event | 形態 | 色 | Motion | 時長 |
|---|---|---|---|---|
| **EXP popup / bar 跳格** | `+N` popup 由 bar 上緣冒出 + bar fill **step 跳格**(§7.D ticker,唔 smooth lerp) | `ui_amber_primary #F2A93B` + 1px ink shadow `#1A1D24`@40% | popup overshoot 1.1×→settle;bar 每格 ≤33ms | popup 250ms + hold 0.4s + fade 200ms |
| **Level-up flash**(每組完成) | 三件 co-trigger:avatar silhouette rim flash(衫光)+ 武器 glow pulse + `+EXP` popup | `event_white #FFFFFF` 首 frame → 0.1s 落 `event_amber`(§4.A;**唔用** loot 純白 burst 體積) | one-shot,peak 即衰減,無 hold loop | 0.4s |
| **Ability unlock flash** | 新 icon(16×16 solid silhouette + 1px ink outline)pop-in + amber 邊緣 flash | **R3 F-4:class 識別 primary channel = silhouette 形狀(非色)**——Strike/Control/Mobility 各用**不同 glyph shape**(如 Strike=尖角/拳、Control=環/鎖、Mobility=箭/翼,確切由 art-director 定),令色盲 + 餘光下靠輪廓即分;color family accent ≤3px(Strike `#E85A5A`/Control `#A66BC9`/Mobility `#5BA8E8`)只做 **enhancement 非 load-bearing**(≤3px accent 喺 16×16 餘光 + 色盲下零分離力,不可作主 channel) | scale 0.8→1.0 ease-out cubic 120ms + flash;one-shot → 退 L3 ambient(static,無脈動) | `icon_flash_duration` 0.6s |
| **Silent-mode banner**(脈動豁免) | 細 banner「㩒一下開聲」,**非 HUD element** | `event_amber` text + 1px ink shadow | **alpha 脈動** 0.7±0.1 / period 2s(**唔用 scale**);unlock 即 fade 200ms | 至 unlock |

### 持續顯示三條
- **HP(MAX_HP)**:圓角橫矩形 **6px 高**(§3.C 最粗=最重要);**non-depleting**(顯示身體力量上限,唔做 deplete 動畫,避免讀成「受傷」焦慮);只喺 MAX_HP **升級**時 step 跳格。Fill `event_amber`。
- **EXP bar**:圓角橫矩形 **3px 高**(HP 50% 厚=次要);事件驅動跳格。**R6 Rec(ux — min_bar_height_px floor)**:3px 係 logical 比例,但喺 phone DPI + peripheral(偏心 ≥10–15°)下 3px 物理高度可能跌穿 peripheral acuity 閾值(EXP 係 L1 餘光主角,讀唔到 = 破 Anchor moment)。故 EXP bar 實際 render 高度 = `max(hp_bar_height × 0.5, min_bar_height_px)`——`min_bar_height_px`(同 `text_scale`/`min_font_size_px` 同類 a11y floor)保證最低物理可讀高度,確切值由 `/ux-design` 喺 target device DPI 上量定(同 AC-V-1 peripheral protocol 一齊驗)。比例 0.5 維持「HP > EXP」視覺階層,但唔可跌穿 floor。
- **Boss HP**(BOSS_ENCOUNTER):圓角橫矩形,放 **screen 上方**(區隔玩家 HP);**depleting**(boss 受傷 deplete,同玩家 HP 語意相反)。fill 用 enemy color token `ui_enemy_threat`(建議 crimson `#C8453E`,最終色值 art-director 定),empty `ui_ink_mid #2D323D`;退場即移除。**R3 F-3 — 三重區分修正:color 對色盲/peripheral 唔可靠,須加 non-color glyph 做真正 load-bearing 區分**:
  - **問題**:① crimson vs amber 喺 deuteranopia/protanopia 餘光下塌向同軸、只剩 luminance 差,而 peripheral luminance 對比敏感度低 + dim state 進一步壓 luminance → color channel 對色盲失效;② 「行為(depleting)」係**時間維度資訊**,0.3s 餘光 single-frame 快照**零 bit**(睇唔到「正在 deplete」),CR-1 定義 Tier 1 = single-glance 可讀,故行為唔係有效 redundant channel;③ 餘下只有「位置(上方)」一個 load-bearing channel,但 BOSS_ENCOUNTER 多件 element 喺上方競爭。
  - **修正**:Boss HP 必須加一個 **non-color、glance-valid 嘅形態 channel**——enemy threat glyph/icon prefix(如骷髏/敵標)或明顯不同 bar 形態(端點方向 / 邊框 pattern / corner radius),令 single-frame 快照即可分 Boss HP vs Player HP,**唔靠色、唔靠 deplete 動畫**。確切形態 art-director + `/ux-design` 定。
  - **四重區分(R3)**:形態 glyph(primary,色盲+peripheral valid)+ color(crimson,enhancement)+ 位置(上方)+ 行為(deplete,僅對焦時 valid)。⚠️ `ui_enemy_threat` crimson 仍須同 §Visual Strike class 色 `#E85A5A` 區隔(Q-OQ10 status 降回 design-layer open,非「色值微調」)。
  - **R4 B5 binding invariant**：**Boss HP 必須有 ≥1 個 colorblind-safe non-color channel(形態 glyph prefix 或明顯不同 bar 形態,二選一)**，channel type 由 `/ux-design` 鎖定；此 invariant 係 AC-V-5「single-frame 可分」嘅 binding——唔可只靠 color。確切 channel type defer /ux-design 係合理 craft defer，但「有非色 channel」本身唔可 defer。

### Dim states(全部降 alpha/明度,**唔降飽和**——保 amber semantic,對齊 §4.D `ui_amber_dim`)
- DISCONNECTED → HUD alpha `base_dim 0.5`,**靜止**(無脈動避免讀成 error 焦慮)+ 可選 1px amber 離線 micro-icon。
- LOOT_DROP defer → HUD dim(建議 ×0.4 對齊 §4.E Loot World sat)+ 暫停所有 #20 motion,讓 #21 獨佔(§1.2 loot=金字塔頂)。
- SUSPENDED → ×0.7 + 凍結最後 frame(無 motion/fade,表「暫停而非斷開」)。

### Animation / 風格約束
- **Amber 張力平衡**:`event_amber #F2A93B` 永遠 100% 飽和,靠對比 `world_desaturation=0.7` 自動彈出,**唔靠 motion 搶眼**。張力釋放全喺事件瞬間,事件之間完全靜止——「色持續高張力,motion 瞬時低頻」= 存在但唔煩。禁 idle glow / 呼吸動畫(banner 例外)。
- **Outline/shadow**:HUD text/number **2px ink outline `#1A1D24`** 維持 shake 期間對比(`hud_shakes_with_world=true`)+ 1px hard shadow @40%(非 gaussian)。雙層保證 web Compatibility motion blur 下仍有 figure-ground 分離。
- **Font**:**MSDF font**(任何 scale crisp);數字用 monospace 變體避免跳格字寬抖動;中文用 Zpix style,禁 pixel+TTF 混排(§7.B)。

### 最直接 apply 嘅 art-bible principles
§1.2 P3 Layer Discipline(飽和=重要程度,#20 glanceability 根本)、§3.C/D UI Shape Grammar + Attention Hierarchy(HP 6px/EXP 3px;HUD rank 4 結構上唔搶 loot rank 2)、§7.A Frameless HUD(無框,depth 靠 contrast,服務 Silent Witness)、§7.D Snap+Settle+step ticker(motion personality 源頭)、§4.E Mood Override(`event_amber` 不受 mood saturation override,#20 dim 係 alpha 層,同 MoodController saturation 層正交)。

### #5 Particle
**#20 核心 HUD 唔需要 particle**——Control-node animation(Tween + shader rim flash)已足(particle budget 留俾 loot/combat;HUD particle 違「唔搶 loot attention」)。唯一可選:level-up spark `vfx_levelup_spark_micro.tres`(≤8 desktop/≤4 mobile),但 emit 喺 avatar sprite = **#26 AvatarRenderer territory,非 #20**;**MVP default 純 Control-node glow,particle defer**(#5/#26 coordination)。

### Performance Budget flag(R2 新增 — 量化數字 escalate 去 `/architecture-review`)
#20 係**常駐 overlay**(疊喺 combat + GPU particles 上,食 draw call 100% 時間),須遵 technical-preferences 全域 budget(≤200 draw call / 512MB / 16.6ms)。本 GDD 唔定最終數字(屬 architecture/TD 職責),但 flag 三個 #20 專屬 perf risk 待 `/architecture-review` + technical-artist 實機驗:**(1) HUD draw-call sub-budget**(多 Control + 每 text 2px outline + 1px shadow = 額外 pass,須 count + 分配);**(2) MSDF font shader 成本**(每 text element 一個 distance-field sample,Compatibility/WebGL + mobile Safari overdraw 敏感,須驗 MSDF node 上限);**(3) `max_concurrent_tweens` allocation 峰值**(已落 constant=6,CR-2)。`world_desaturation` 全屏 shader 成本歸屬 art-bible/#6,#20 唔可擅改 world CanvasLayer 拓撲(Q-OQ7 旁註)。

### Audio co-trigger(SFX palette 屬 #4,#20 只觸發)
level-up flash white-peak frame = `set_complete` SFX attack onset(同 frame);EXP popup peak ≈ tick onset;unlock flash scale 到 1.0 frame = chime onset;banner fade-out 200ms 與第一 SFX 同步(視覺退場=聲音接手)。**原則**:visual attack/peak frame 永遠對齊 audio onset,唔可 visual 先行等 audio;silent-mode 下 visual 必須**獨立完整可讀**(SFX 係 enhancement 非 primary,§4.B)。

## UI Requirements

**Glance Hierarchy(0.3s 餘光接收優先次序;positioning + 視覺重量綁定層級)**

| 層 | Element | Positioning(建議,`/ux-design` 定案) | 視覺重量 | 接收方式 |
|---|---|---|---|---|
| **L1 餘光主層** | **HP**、**EXP** | 固定 corner anchor(建議 top-left),最大字、最高 amber 飽和、最穩定位置 | 最重:大、亮、full-saturation | **0.3s 餘光直讀**,Anchor moment 主角 |
| **L2 餘光次層** | PROG(set X/Y)·(BOSS_ENCOUNTER)BOSS HP | L1 鄰近、次級字號 | 中:常駐但低於 L1 | 餘光感知「進度感 / boss 緊張感」,細節留 L3 |
| **L3 對焦層** | STAT 明細 · SKILLS 列表 · 下一動作提示 · 剩餘組數 | 較密較細,**REST_PERIOD 先升起** | 低:平時 ambient/折疊 | **要對焦先讀**;只喺 REST_PERIOD 容許 |

**核心 UI 規則(可落 AC)**
- **80/20 法則**:L1+L2 喺餘光交付 ≥80% status;L3 只承載 20% confirmation detail,且**只喺 rest 對焦**。reward 必須喺餘光已被看到,唔可「對焦先解鎖」。
- **Motion 紀律**:L1/L2 只可事件驅動 motion,**禁持續跳動數字**(Anxiety Dashboard 主雷)。idle 時靜止。
- **Layer Discipline**:HUD full saturation;world −30%。L1 飽和 ≥ L2 ≥ L3,確保餘光天然落 L1。
- **位置恆定**:L1 anchor 位置**跨所有 GSM state 絕不移動**(餘光靠肌肉記憶,移位 = 要重新對焦 = 破 fantasy)。
- **Overlay region non-overlap(R4 Rec#8)**:State-driven overlay(Boss HP、REST_PERIOD L3 surface、banner)各佔**唔同於 L1 anchor 嘅獨立 screen region**——overlay 唔同 L1 element 視覺重疊(否則 overlay 出現時 L1 anchor 被遮擋)。確切 region 由 `/ux-design` layout spec 定案。
- **Layout isolation(R3 F-5 — AC-V-1c「0px 位移」嘅實現約束)**:L1 anchor element **必須 absolute-positioned 喺獨立 layout context**(獨立 Control / CanvasLayer,唔參與會 reflow 嘅 flow container);**所有 state-driven element(BOSS_ENCOUNTER Boss HP「上方」/ REST_PERIOD L3 surface 升起 / banner)一律以 overlay 疊加,永不 push L1 嘅 layout flow**。否則 Boss HP 插入或 L3 升起會 reflow L1 → 違反 AC-V-1c 0px。banner 同樣非全屏遮蔽、唔 push L1(banner 後 ambient HUD 已可見)。此 rule 令 AC-V-1c 由「空頭支票」變可實現約束。

**Banner placement**:silent-mode banner 非全屏遮蔽(banner 後 ambient HUD 已可見);hit-area 大 tap target;`focus_mode = FOCUS_NONE`(唔搶 keyboard focus,one-tap touch design 無 hover state)。

**平台適配**:web mobile/tablet primary;觸控 one-tap;HUD element 必須喺**無對焦下靠形狀/顏色/位置區分,唔可靠讀字**;MSDF font 支撐任何 DPI/scale;細螢幕 legibility 由 `/ux-design` + scalable-text(Theme base font size 一個 knob 全 HUD 縮放)保證。

**邊界**:本 section 只定 UI 原則 + glance 結構;**詳細 per-screen layout(element 確切座標、密度、aspect-ratio 響應、touch target 尺寸)屬 `/ux-design gym-mode-hud` 嘅 UX-spec 職責**,stories 應 cite `design/ux/gym-mode-hud.md` 而非本 GDD。

## Acceptance Criteria

> **Test evidence 分流**:Logic/Integration = **BLOCKING**(headless GUT 可驗);Visual/Feel/UI = **ADVISORY**(餘光可讀、glance、shake 可讀 = 體感,headless 驗唔到,要 screenshot/playtest + lead sign-off)。BLOCKED 標記 = 依賴 #33/#8/#21/#2-GDD 未 ready,wiring deferred,AC gated。

### A. Core Rules ACs

**AC-CR-1**(雙層架構 / reward 不鎖 Tier 2)— GIVEN HUD WORKOUT_ACTIVE、L1 已渲染,WHEN reward 事件(EXP 跳格 / ability flash)觸發,THEN reward 首發 surface 喺 L1 餘光層(非 L3),L3 唔係該 reward 唯一觸發點。 *Visual · `production/qa/evidence/` · **ADVISORY***

**AC-CR-2**(事件驅動 motion / 禁 idle 抖動)— **BLOCKING 子集明確斷言序(R2 + R3 強化)**:GIVEN 注入一個 `stat_changed` 觸發 bar tween,WHEN tween settle 後 `await` 一幀再 idle 500ms,THEN `node.is_processing() == false` **AND** SUT 維護嘅 `_active_tween_count == 0`(因 Godot 4 冇 public processed-tween count API,SUT 必須喺 create/finished callback 維護一個 counter seam 俾 test 讀)**AND R3 independent cross-check(qa #5)**:bar 嘅 `value` 喺 idle 500ms 內 **delta == 0**(直接觀察 output,唔淨信 counter——防 counter bug phantom-pass:counter 啱但 tween 實際冇 kill)。**並驗 `max_concurrent_tweens`**:同幀注入 `max_concurrent_tweens + 2` 個 motion 事件,THEN `_active_tween_count ≤ max_concurrent_tweens`(**讀 config const,非字面 6**;超額降級瞬間 set)。**R6 B9 — counter zero-floor 斷言**:GIVEN `reduce_motion==true`(F2 instant set,從未 `++`),WHEN 同 stat_id 連續 `stat_changed` 觸發 snap/kill path,THEN `_active_tween_count` **永遠 ≥ 0(never negative)**——驗 decrement 行 `max(count-1,0)` + handle-tracking(只在有 created tween 時先 `--`);負 counter 會令本 AC idle==0 斷言同 cap 判定失準。視覺「無抖動」面 ADVISORY。 *Logic · `tests/unit/gym_mode_hud/` · **BLOCKING**(counter-seam + value-stability + zero-floor 三斷言)*

**AC-CR-3**(signal-driven + pull-on-init / 禁每幀 state poll)— GIVEN `_ready()` 完成,WHEN `stat_changed(stat_id=EXP)` push 到,THEN 只 EXP sub-widget redraw、非 HUD stat_id O(1) early-return、全程無 `_process` 每幀 poll 攞 state(data push/pull only);tween 用 `SceneTreeTween`,settle 後 `_active_tween_count` 歸 0(非靠 set_process toggle,見 CR-3 R2)。 *Logic · `tests/unit/gym_mode_hud/` · **BLOCKING***

**AC-CR-4**(event-driven step / 5s gap 靜止)— GIVEN 收到 `set_progress_changed` 後進入 polling gap,WHEN 5s 內無新 event,THEN 顯示值 delta==0(無 `progress += elapsed`)。 *Logic · `tests/unit/gym_mode_hud/` · **BLOCKING***

**AC-CR-5**(state-gated visibility / modal 退讓 / 拒 tap)— GIVEN GSM LOOT_DROP,WHEN apply 矩陣,THEN HP/EXP ○dim、PROG ▽defer、不渲染 loot 文字;且 `is_input_permitted()==false` 時 tap 唔被消費(early-return)。 *Logic · `tests/unit/gym_mode_hud/` · **BLOCKING**(input gate **BLOCKED on #33** — 見 AC-EC-S5)*

**AC-CR-6**(banner 顯示條件)— GIVEN `is_audio_unlocked()==false` 且離 Booting,WHEN 評估 BannerGate,THEN banner 顯示==true;GIVEN `is_audio_unlocked()==true`(desktop)THEN ==false(永不出現)。 *Logic · `tests/unit/gym_mode_hud/` · **BLOCKING***

**AC-CR-7**(banner dismiss / session 永不再現)— GIVEN banner 顯示中,WHEN 首 tap 觸發 `audio_unlocked`,THEN one-shot dismiss、`banner_dismissed_this_session==true`;WHEN 之後 resume 重評,THEN 不重現(即使再 LOCKED)。 *Logic · `tests/unit/gym_mode_hud/` · **BLOCKING***

**AC-CR-8**(計數行 #9-validated path,audio gate 只 gate 聲 — R3 收斂1 核心)— GIVEN audio LOCKED,WHEN #9 emit `set_progress_changed`(已 validate),THEN **progress/計數即更新 + EXP 視覺即跳格(不受 audio 狀態 gate)**;同時對應 SFX 只 mid/high 入 buffer(`set_complete`=low drop)。**R3 absolute 斷言(qa #2,非『遞增』)**:注入 3 個 #9-validated progress 事件,THEN `workout_progress` 最終 **== 3**(絕對值,非『遞增』——『遞增』喺 off-by-one/double-count regression 下 phantom-pass),且與 `is_audio_unlocked()` 無關。**R3 anti-fabrication 斷言(收斂1 核心 / game-designer F1）**:GIVEN GSM IDLE-without-`workout_started`,WHEN raw `#2.set_logged` 到(#9 會 drop,唔 emit progress),THEN **`workout_progress` 不變(==0)**——即 #20 計數**只認 #9-validated signal,唔食 raw set_logged**(防 Silent Witness 講大話);此 stray set_logged 連 audio 都因 GSM-state gate(CR-9)唔出聲。GIVEN 全程從未 unlock,THEN 計數/視覺仍完整(只係冇聲)。**R4 B1 EXP forward contract**:GIVEN GSM IDLE-without-`workout_started`,WHEN raw `#2.set_logged` 到,THEN 除 `workout_progress==0` 外,**`exp_fill` delta == 0**（#20 render 嘅 EXP fill 亦不變——封死 EXP fabrication 路徑,唔單靠 progress 斷言）。**SUSPENDED 變體**:GIVEN GSM SUSPENDED,WHEN raw `#2.set_logged` 到(#9 Rule 8 亦 drop),THEN `workout_progress` 不變 **AND** `exp_fill` delta == 0。**R5 B5a — EXP 斷言 label 修正**:呢兩條斷言係 chain-level（#9 drop → #11 唔 emit stat_changed(EXP) → #20 唔收 → exp_fill 不變），屬 **Integration**（tests/integration/）而非 unit；#20 本身無 consumer-side EXP fabrication filter——trust boundary 明文喺 CR-8 EXP trust boundary 段。**R6 Rec — Integration fixture 邊界明文(qa #2)**:此 chain test 用 **real #9 + real #11 + real #20**(三者皆 Approved/merged,CI available)+ **faked #2 source**(`set_logged` 由 test harness inject,因 #2 係 HTTP-polling backend client 無法喺 headless 真實 emit raw stray)。**責任界定**:呢條 test 實質**驗緊 #9/#11 嘅 anti-fabrication chain**(#20 喺 chain 中係**被動 no-op** — 佢冇收到 signal 所以唔 render);#20 側真正 own 嘅只係「#20 無加 consumer-side fabrication path」(negative assertion)。故 #20 epic **依賴 #9/#11 既有 anti-fabrication test 做主覆蓋**,本 Integration AC 喺 #20 側做 **chain-smoke gate**(確認 wiring 後 #20 確實 no-op、無 fabricate),唔重複 #9/#11 嘅 fine-grained drop 邏輯測試。 *Logic(progress/計數斷言) · `tests/unit/gym_mode_hud/` + **Integration(EXP forward contract,chain-smoke)** · `tests/integration/gym_mode_hud/` · **BLOCKING***

**AC-CR-9**(audio consumer 訂閱 + play_sfx)— GIVEN `WorkoutAudioAdapter` wire 好,WHEN unlock 後 `set_logged` 到,THEN call `play_sfx(event_id)` 一次(spy count==1、event_id 正確)。 *Integration · `tests/integration/gym_mode_hud/` · **BLOCKING**(streak_chime 路由 **BLOCKED on #8** — 見 AC-EC-S6;整合測前須 **#2 GDD 補列 #20 subscriber**)*

**AC-CR-10**(buffer policy — cap / low drop / flush;R3 收斂2:priority 由 catalog data 讀,無 phantom API)— GIVEN audio LOCKED + 注入 `SfxCatalog.tres`(或 test fake catalog resource)俾 SUT 讀 priority field,WHEN `pending_buffer_cap + 2` 個 mid/high event 連續到,THEN `_pending` size **≤ `pending_buffer_cap`**(讀 config const,非字面 12;FIFO drop oldest);low priority event(讀 catalog priority==low)唔入 buffer(直接 drop);`audio_unlocked` 後 flush 至空。**R3 fix(qa #1 / audio 項2)**:priority 來源係 SUT `load` 嘅 catalog resource data field(可注入 fake catalog 做 test seam),**唔再依賴 #4 `get_event_priority()` phantom method**——AC 即時可獨立測,無 BLOCKED-on-#4。 *Logic · `tests/unit/gym_mode_hud/` · **BLOCKING***

**AC-CR-11**(stagger — 斷言 scheduled param 非 wall-clock,R2)— GIVEN `set_complete`×`streak_chime` 同幀,WHEN consumer 處理,THEN 先 `play_sfx(set_complete)`、`streak_chime` 經一個**可注入 `ITimerService` seam** 排程 delay,**斷言排程 delay 參數 == `set_streak_chime_stagger_ms`**(讀 config const,R3 qa #3:刪內聯 `(100,∈[80,120])` 數字,該 default+range 屬 Tuning Knobs)(test 注入 fake timer 即時 advance,**唔 `await` 真 wall-clock**——SceneTreeTimer 由 `get_tree()` own 無法 spy + headless real-timer 非 deterministic 會 CI flaky,違 determinism 標準);`AudioManager` 側無 delay。 *Logic(fake-timer DI,非 SceneTreeTimer spy)· `tests/unit/gym_mode_hud/` · **BLOCKING**(BLOCKED on #8 — 同幀並存需 #8 chime 路由 + correlation key,見 Q-OQ1)*

**AC-CR-12**(數據語意 — HP non-depleting / 技能 source / cluster sort key — R8 B1+B13)— GIVEN HUD 渲染,WHEN 讀 HP 來源,THEN HP fill 綁 `get_stat(MAX_HP)`(非 depleting,只 MAX_HP 升級時 step);技能列表==`get_unlocked_abilities()`(無 fabricated current-HP)。**R8 B1+B13 cluster sort 斷言(tier_ordinal DESC,取代 R7 insertion-order)**:GIVEN `get_unlocked_abilities()` 返 ≥5 個 ability(**ability-system.md L233:返 read-only view;L413 invariant 1 明文「無視 insertion order」→ #12 insertion-order-agnostic,#20 唔可依賴 iteration order;L696:NEVER access internal**),WHEN BOSS_ENCOUNTER apply display cap,THEN #20 用 **#20-owned `SkillIconRegistry`** 嘅 `tier_ordinal` 對 ability_id set 施加 `tier_ordinal DESC, class_ordinal ASC` sort,顯示頭 `skill_cluster_display_cap(=4,讀 config const)` 個 = **最高 tier 嘅 4 個技能**,其餘摺疊「+N」。**斷言**:注入一組已知 tier_ordinal 嘅 ability_id(test fixture 含混合 tier),THEN 顯示嘅 4 個 == sort by `(tier_ordinal DESC, class_ordinal ASC)` 之頭 4;**deterministic(tie-break class_ordinal ASC)、唔依賴 collection iteration order、唔讀 timestamp、唔讀 #12 internal**。tier_ordinal 由 #20 static registry 提供(9 MVP slot intrinsic 屬性),非 runtime query → 零 #12 churn。**cite(R8)**:tier_ordinal mapping cite ability-system.md L386/L405(#12 published `(tier_ordinal, class_ordinal)`);insertion-order-agnostic cite L413 invariant 1;closed-API cite L696。**撤銷 R7 insertion-order phantom**(依賴 L233 從未 author 嘅 iteration contract + 違 L413)。 *Logic · `tests/unit/gym_mode_hud/` · **BLOCKING***

**AC-CR-13**(Pillar 2 紅線 9 條 — 複合,逐項分流):① 禁 mid-set 互動攞 reward / ④ reward 禁鎖對焦層 → **AC-CR-1**(ADVISORY);② 禁祈使句 → *UI · `production/qa/evidence/` copy walkthrough · **ADVISORY***;③ 禁 idle motion → **AC-CR-2**;⑤ Tier 1 ≤5 → *Logic design-time count gate · **ADVISORY**(EC-S7 runtime 唔 auto-hide)*;⑥ modal 退讓 → **AC-CR-5**+**AC-EC-S3**;⑦ 尊重 `is_input_permitted()` → **AC-CR-5**(**BLOCKED on #33**);⑧ shake 期間 Tier 1 可讀 → *Visual/Feel · `production/qa/evidence/` shake screenshot · **ADVISORY***;⑨ **(R8 B13)anti-Stagnation Mirror(Tier 1 反映當前非 stale)→ AC-CR-12**(cluster sort tier_ordinal DESC = 最強技能先,BLOCKING Logic;封死 insertion-order 最舊技能霸位)。

### B. Formula ACs

**AC-F1**(exp_fill — F1)— GIVEN `340/500` THEN `exp_fill==0.68`;`500/500` THEN `1.0`;`exp_to_next=0`(EC-F1)THEN `max(0,1)=1`、fill==1.0 無 NaN;`current_exp=-5`(EC-F3)THEN sanitize 後 0.0。 *Logic · `tests/unit/gym_mode_hud/` · **BLOCKING***

**AC-F2**(tween_duration — F2)— GIVEN `reduce_motion==false` THEN `==base(0.3)`;`==true` THEN `==0.0`(瞬間 set)。 *Logic · `tests/unit/gym_mode_hud/` · **BLOCKING***

**AC-F3**(banner_alpha — F3 + 邊界 + unlock kill)— GIVEN `base=0.7,amp=0.1,period=2.0`,`t=0.5` THEN `≈0.8`(峰,±0.001);`t=1.5` THEN `≈0.7`(谷);`t` 極大(EC-F6)用 `fmod` THEN ∈[base,base+amp] 不溢出;**R3 F3-A:`pulse_period=0` THEN `P=max(0,0.5)=0.5`、`banner_alpha` 不 NaN、pulse tween 不 livelock**;**R3 F3-B:`base=0.95,amp=0.15` THEN clamp 後 ≤1.0**(body clamp 兌現);`audio_unlocked` emit THEN pulse tween 即 `kill()`。 *Logic · `tests/unit/gym_mode_hud/` · **BLOCKING**(脈動「搶餘光」屬視覺,另見 AC-V-3)*

**AC-KNOB-B**(dim product floor — systemic clamp / R4 Rec#5 / **BLOCKING**)— GIVEN `base_dim=0.5` + LOOT_DROP state multiplier = `loot_dim_multiplier`(**讀 config const**，default=0.4，最危險組合 raw product=0.20),WHEN apply dim,THEN `effective_dim = max(base_dim × loot_dim_multiplier, DIM_PRODUCT_FLOOR) == DIM_PRODUCT_FLOOR`(**兩個 multiplier 均讀 config const，非字面 0.4 / 0.30**;**R5 B4 fix**);同驗 SUSPENDED：`max(base_dim × freeze_dim_extra, DIM_PRODUCT_FLOOR) == max(0.35, 0.30) == 0.35 > floor ✅`(clamp 不觸發 = pass-through 路徑覆蓋)。**R6 Rec — DISCONNECTED no-clamp case(對稱三個 defined state multiplier)**:`max(base_dim × disconnect_dim_multiplier, DIM_PRODUCT_FLOOR) == max(0.5 × 1.0, 0.30) == 0.50 > floor`(**讀 `disconnect_dim_multiplier` config const**;R5 新加 const 須有 AC 保護防誤改 0)。三 case 覆蓋:LOOT(clamp-active)/ SUSPENDED(at-product 0.35 無 clamp)/ DISCONNECTED(no-clamp 0.50)。floor 失守 → HUD 近全黑似 crash。 *Logic · `tests/unit/gym_mode_hud/` · **BLOCKING***

### C. Edge Case ACs(高 severity)

**AC-EC-R4**(unlock × WORKOUT_ACTIVE 同幀 — B1 decouple 後降 MEDIUM)— GIVEN `audio_unlocked` 同 `state_changed→WORKOUT_ACTIVE` 同幀,WHEN 處理(各 handler set flag + `call_deferred` reconcile pass),THEN **計數/EXP 視覺結果與 ordering 無關**。**R3 absolute 斷言(qa #2)**:注入 N=3 個 #9-validated progress 事件 + 任意 unlock/state ordering,THEN 最終 `workout_progress == 3`(**絕對值 == 注入數,非『兩 order 相等』**——order-invariant 只證一致不證正確,兩 order 一致咁錯會 phantom-green;故斷言絕對值)且 EXP fill 一致;audio flush 喺 reconcile pass 內完成、與 matrix apply 先後皆可(audio enhancement,無 atomic 要求)。原「SFX flush 須先於 count-start」斷言隨 decouple 移除。 *Logic(同幀注入兩 signal,斷言絕對計數 == 注入數)· `tests/unit/gym_mode_hud/` · **BLOCKING***

**AC-EC-A1**(LOCKED 全程冇 tap — cap 12)— GIVEN 全程 LOCKED 從未 tap,WHEN 20 個 `set_logged` 到再 `_exit_tree`,THEN `_pending` 全程 ≤12、永不 flush、`_exit_tree` 後清空(無 dangling `play_sfx`)。 *Logic · `tests/unit/gym_mode_hud/` · **BLOCKING***

**AC-EC-R2**(同 stat_id tween 未完又新事件)— GIVEN EXP tween 跑緊(t=0.15),WHEN 新 `stat_changed(EXP)` 到,THEN kill 舊 tween、由當前 interpolated 值 restart(無回跳/無疊);`reduce_motion==true` THEN 直接 snap。**R4 Rec#4 — F4-B ordering**：kill-restart 期間任意時刻 `_active_tween_count ≤ max_concurrent_tweens`(讀 config const)——先 kill(`_active_tween_count--`)後 create(`_active_tween_count++`),峰值唔短暫超 cap。 *Logic · `tests/unit/gym_mode_hud/` · **BLOCKING***

**AC-EC-A4**(stagger timer 未 fire 就 suspend/exit)— GIVEN deferred `streak_chime` timer(100ms)未 fire,WHEN `_exit_tree` 或進 Suspended,THEN guard 檢查(in-tree && 非 Suspended)不滿足則 drop(call count==0)。 *Logic · `tests/unit/gym_mode_hud/` · **BLOCKING***

**AC-EC-S9a**(reconcile 純邏輯 — R2 拆分,headless 可測)— GIVEN 抽出嘅 `reconcile(pulled_state)` method(不依賴 browser event),注入 freeze@WORKOUT_ACTIVE → pulled@LOOT_DROP,WHEN call,THEN 一次性 snap、apply LOOT_DROP 矩陣、`banner_dismissed_this_session` 防重彈、SFX flush 只觸發一次(double-flush guard)。 *Logic · `tests/unit/gym_mode_hud/` · **BLOCKING***
**AC-EC-S9b**(bfcache wiring — browser-only,ADVISORY)— GIVEN 真 web-export,WHEN tab-switch / back-forward 觸發 `pageshow`,THEN `reconcile()` 被正確 wire 調用。 *Visual/Integration · `production/qa/evidence/`(真 browser bfcache playtest protocol)· **ADVISORY**(headless 物理上無 DOM/bfcache,刪原「BLOCKING OR playtest」後門;依賴 Q-OQ12 SUSPENDED producer)*

~~**AC-EC-A6**~~(**R5 B5b DELETE,R6 B8 rationale 修正**)——**AC 刪除動作保留**(無 testable 斷言:EC-A6 R6 係「明文接受 contention cost」嘅 design acceptance,非可量 assertion;且舊機制讀 `_test_get_active_voice_count()` internal helper 不可測)。**但 R5 原 deletion rationale「#4 priority-steal 已全面保護 `audio_unlock_confirm`」經 audio-director 核對 `audio-manager.md §84` 證實為假**(Rule 3 只保 high 不被 lower steal,mid 係 unlock-frame high flush 合法 victim)。EC-A6(R6)已 un-delete 做 LOW EC 記錄真實 contention + 明文接受 cost;Q-OQ13 改 explicit-accept。**呢個 AC 仍刪**(設計接受無 test),但 contention **唔再被假 closure 掃入隱形**。

**AC-EC-S1**(BannerGate 期間 GSM 已 WORKOUT_ACTIVE — HUD 不阻 GSM)— GIVEN BannerGate、GSM 自行進 WORKOUT_ACTIVE,WHEN 觀察,THEN ambient 已顯示、**計數 + EXP 視覺即時運作(B1 decouple,唔 hold)**、只 audio SFX 入 buffer、**GSM 前進不被 HUD 阻**;首 tap 後補播 buffered SFX。**R3 absolute 斷言**:BannerGate 期間注入 3 個 #9-validated progress 事件,THEN `workout_progress == 3`(絕對值,與 BannerGate 狀態無關)。 *Logic · `tests/unit/gym_mode_hud/` · **BLOCKING***

**AC-EC-S4**(DISCONNECTED 期間 set_logged — 聲靜視覺靜 / R4 B2 fix)— GIVEN GSM DISCONNECTED 期間 `set_logged` 到,WHEN 處理,THEN **SFX 唔 trigger(CR-9 gate,spy call count == 0)**;視覺維持 dim 不彈 popup(忠於斷線)。GIVEN resume 後 GSM → WORKOUT_ACTIVE + `set_logged` 到,THEN SFX 正常 trigger(gate pass)。 *Logic(audio spy + visual-state 斷言)· `tests/unit/gym_mode_hud/` · **BLOCKING***

**AC-EC-S4-LOOT**(LOOT_DROP 期間 set_logged — CR-9 deny-side / **R5 Rec-2**)— GIVEN GSM LOOT_DROP 期間 `set_logged` 到(LOOT_DROP 唔在 CR-9 gate list),WHEN WorkoutAudioAdapter 處理,THEN **SFX 唔 trigger(spy call count == 0)**；visual 按矩陣 dim defer(EC-S3)。 *Logic(audio spy)· `tests/unit/gym_mode_hud/` · **BLOCKING***

**AC-EC-S4-SUSPENDED**(SUSPENDED 期間 set_logged — CR-9 deny-side / **R5 Rec-2**)— GIVEN GSM SUSPENDED 期間 raw `set_logged` 到(SUSPENDED 唔在 CR-9 gate list；#9 Rule 8 亦 drop),WHEN WorkoutAudioAdapter 處理,THEN **SFX 唔 trigger(spy call count == 0)**；Freeze-dim 維持。GIVEN resume 後 GSM → WORKOUT_ACTIVE + `set_logged` 到,THEN SFX 正常 trigger(gate pass，對稱 DISCONNECTED 嘅 AC-EC-S4 resume 場景)。 *Logic(audio spy)· `tests/unit/gym_mode_hud/` · **BLOCKING***

**AC-EC-S4-IDLE**(IDLE 期間 set_logged — CR-9 deny-side audio spy / **R6 B6**)— GIVEN GSM IDLE 期間 raw `set_logged` 到(IDLE 唔在 CR-9 gate list `{WORKOUT_ACTIVE,REST_PERIOD,COMBAT_ACTIVE,BOSS_ENCOUNTER}`),WHEN WorkoutAudioAdapter 處理,THEN **SFX 唔 trigger(spy call count == 0)**。**R6 B6 rationale**:R5 Coverage 自檢 claim「IDLE via AC-CR-8」係**錯位**——AC-CR-8 只 assert IDLE stray 嘅 `workout_progress`/`exp_fill` (count/visual side),**無 audio spy 斷言**;若有人改壞 CR-9 gate list 令 IDLE 漏出 SFX,AC-CR-8 接唔住(佢只驗計數唔變,SFX 照出)。本 AC 補上 IDLE audio deny-side enforceable gate,對稱其餘 3 個 deny-state(DISCONNECTED/LOOT/SUSPENDED)。GIVEN GSM 由 IDLE → WORKOUT_ACTIVE + `set_logged`,THEN SFX 正常 trigger(gate pass)。 *Logic(audio spy)· `tests/unit/gym_mode_hud/` · **BLOCKING***

**AC-EC-F4**(NaN/INF 唔餵 Tween)— GIVEN `exp_fill` 計出 NaN/INF,WHEN guard,THEN fallback 用上一 confirmed、唔 redraw、log 一次、唔餵 NaN 入 Tween(防永不 settle 燒 CPU)。 *Logic · `tests/unit/gym_mode_hud/` · **BLOCKING***

**AC-EC-F4b**(circuit breaker — livelock 收斂,R3 F4-A / R4 B3 / R5 B3 / R6 B7 / **R8:spike-grounded off-by-one + empty-handle + 2-param seam**)— GIVEN 同一 stat_id 連續收 **N ≥ `max_tween_restart_count + 1`(讀 config const)** 個 `stat_changed`(模擬高頻 reconnect burst),WHEN kill-restart 次數達 cap,THEN **強制 snap 到 latest target(跳過 tween)**且 `_restart_count[stat_id]` 歸 0。
**R8 spike grounding**:本 AC 嘅 timing/index 行為由 `prototypes/tween-spike/test_tween_spike.gd`(12/12 pass,Godot 4.6.3)實測確立;reference impl = SPIKE-FINDINGS.md `HudTweenManager`。

**斷言重寫(R8 — spike-verified)**:
- **(1) snap-index 分辨力 + off-by-one fix(R8 B4)**:**create(第 1 個 event)唔算 kill-restart**(`_restart_count` 不 `++`);之後每個 same-stat_id event 觸發一次 kill-restart `++`。故 `_restart_count` 喺**第 `max_tween_restart_count + 1` 個 event** 達 cap → snap。斷言:注入第 `max_tween_restart_count + 1` 個連續 same-stat_id event 嗰一刻(**即時讀,唔等 tween**),bar `value` **== latest target(instant snap,無 in-flight tween 中間值)** 且 `_restart_count[stat_id]` 喺嗰刻 == 0。**R8 fix**:R6/R7 寫「第 `max_tween_restart_count` 個 event snap」係 off-by-one(漏咗 create 第 1 個 event 唔係 restart)——spike test_B4 實測 snap 喺第 6 個 event(MAX=5);naive 無-breaker impl 喺第 `MAX+1` 個 event 仍係 tween 中間值,fail 此斷言。
- **(2) snap-path counter 歸零(R5 B3 保留 + spike test_B3 verified)**:snap 後 `_active_tween_count == 0`(snap path = `_kill`(`--`)+ `set_immediate`(唔 `++`),counter 正確歸零非 stuck;且 `_active_tween_count == _active_tweens.size()` invariant 維持)。
- **(3) empty/stale-handle no-op(R8 B5/B6 — spike test_B5/test_B6 verified)**:snap 後 `_active_tweens[stat_id]` 已 erase。GIVEN 一個 stale/empty handle 嘅 `_on_tween_finished(stat_id, stale_tween)` 殘響到達(stale_tween = 已 kill 嘅舊 tween 或 null),THEN **identity guard `_active_tweens.get(stat_id) != src_tween` 提早 return**,`_active_tween_count` 不變(無 double-decrement)、新 tween entry(若存在)不被誤刪。**此斷言證明 seam 必須係 2-param `_on_tween_finished(stat_id, src_tween: Tween)`**——single-`stat_id` 物理上做唔到 identity 比對(spike A4 verified `.bind(stat_id, tween)` 經 0-arg `finished` signal 正確傳 2 param)。
- **(4) reset-then-resume — deterministic logical-epoch seam**:**唔用 `await get_tree().process_frame`**(headless 非 deterministic + 違 Testing Standards + 撞 AC-CR-11 fake-timer 原則)。改用 **logical event-epoch seam**:`_restart_count[stat_id]` reset 條件 = 「上一個 tween **自然 `finished`(非被 kill)** → `_restart_count[stat_id] := 0`」(spike A2 verified:kill 唔 emit finished,只自然完成 emit,故 lifecycle ③ 只行自然路徑)。test 直接驅動:snap 後 fake-complete(call SUT `_on_tween_finished(stat_id, current_tween)` seam)→ assert `_restart_count==0` → 再注入新 `stat_changed(stat_id)` → assert **正常重啟 tween**(`_active_tween_count` 遞增、非瞬間 snap)。全程零 frame-timing 依賴。

**Seam mandate(R8 — ui-programmer R6 升 AC,同 AC-CR-2 `_active_tween_count` 同級 BLOCKING implementation requirement)**:SUT **必須** expose ① `_active_tweens: Dictionary(stat_id→Tween)` handle-map(F5);② **2-param** 具名 callback `_on_tween_finished(stat_id: StringName, src_tween: Tween)` 帶 identity guard(F8/B6),經 `tween.finished.connect(_on_tween_finished.bind(stat_id, t))` wire;③ `_get_restart_count_for_test(stat_id) -> int` inspectable getter(F9)。三者非 optional。 *Logic(logical-epoch seam,非 frame await)· `tests/unit/gym_mode_hud/` · **BLOCKING***

### D. Visual / Feel / UI ACs(天然 ADVISORY — headless 驗唔到)

**AC-V-1**(餘光 0.3s 可讀 — Glance Hierarchy,**R6 B4:binding/statistical 拆分 — 治 dead gate**)— GIVEN HUD WORKOUT_ACTIVE,WHEN tester 喺 **peripheral(偏心 ≥10–15°)+ secondary cognitive load + shake** 條件下 0.3s 餘光掃過,THEN L1 交付狀態、L1 飽和 ≥ L2 ≥ L3、L1 anchor 跨所有 state 不移動。

**R6 B4 — 拆 binding entry gate vs statistical threshold(治 R5 Rec-1 dead gate)**:R5 Rec-1 pin「95% Wilson CI 下界 ≥80% + N≥12」做 binding pass condition 係**數學上不可達**(N=12 即使 100% 答中,Wilson 95% 下界 ≈75.8% < 80%;要下界掂 80% @ 80% 點估需 N≈150)→ binding gate 永卡 epic,比無 gate 更壞(dead binding gate 侵蝕全 project gate credibility)。R6 重新分層:

- **BINDING(lead 不可 override)**:① quantitative protocol **必須交付**(peripheral fixation-cross + dual-task load + static/shaking 兩變體;protocol 未交付 = CANNOT-VERIFY,#20 唔可入 sprint);② **point estimate 答中率 ≥ 80%(N≥12)**;③ Likert「需唔需對焦」 ≥ 4/5;④ L1 anchor 跨 state 位移 = 0px。四項 conjunctive,任一 gross-fail = BLOCKING exit,須 escalate ux 重設計。
- **ADVISORY(report-for-context,非 pass/fail gate)**:Wilson 95% CI(下界)做 sample-confidence 報告——N=12 細樣本下界必偏低係已知統計事實,**唔做 binding pass 條件**;CI 下界用嚟向 reviewer 顯示 evidence strength,引導 /ux-design 決定要唔要加大 N。
- **/ux-design 交付物(B4)**:`/ux-design gym-mode-hud` 須用**現實可達嘅樣本量**重新計 protocol——定一個「point estimate ≥ 80% AND CI 下界 ≥ X(X 為現實閾值,如 ≥65%,並計出對應最小 N)」嘅可達 binding 標準,取代 R5 不可達嘅「下界 ≥80%」。binding 統計閾值由 /ux-design + qa-lead(識統計)落實。

**R3 fix(保留)**:原 tachistoscope-only(foveal-rested-static)測錯 construct,新 protocol match peripheral-fatigued-shaking 命脈。 *Visual/Feel · `production/qa/evidence/`(多 state screenshot + Q-OQ9 量化 protocol + lead sign-off)· **ADVISORY-RESULT / BINDING-PROTOCOL-DELIVERY-GATE***

**AC-V-2**(shake 期間 figure-ground)— GIVEN `hud_shakes_with_world==true` 世界 shake 中,WHEN 餘光讀數字,THEN 2px outline + 1px shadow 維持 figure-ground(數字可讀)。 *Visual/Feel · `production/qa/evidence/`(shake 截圖/錄影 + lead sign-off)· **ADVISORY***

**AC-V-3**(banner 邀請感非搶注意)— GIVEN banner 脈動中(F3),WHEN tester 觀察,THEN 讀成「呼吸/邀請」非「抖動/緊張」,唔搶餘光。 *Visual/Feel · `production/qa/evidence/`(錄影 + lead sign-off)· **ADVISORY***

**AC-V-4**(world desaturation 對比)— GIVEN world −30% sat、HUD full saturation,WHEN 截圖比對,THEN HUD amber 自然彈出(對比足、世界仍可辨識)。 *Visual · `production/qa/evidence/` · **ADVISORY***

**AC-V-5**(色盲區分 — R3 F-3/F-4 新增)— GIVEN BOSS_ENCOUNTER + 已解鎖多 class 技能,WHEN 截圖經 deuteranopia/protanopia/tritanopia simulation,THEN ① Boss HP vs Player HP 靠 **non-color 形態 channel**(glyph/形態)single-frame 可分(唔靠 crimson-amber luminance);② skill icon class 靠 **silhouette 形狀** 可分(唔靠 ≤3px color accent);③ Strike vs Boss crimson 可分。lead sign-off。 *Visual/a11y · `production/qa/evidence/`(3 色盲 simulation 截圖)· **ADVISORY***

**AC-U-6**(最低字號可讀 — R3 F-8 新增 / **R5 Rec-4:font hard floor**)— GIVEN web mobile 最細 supported resolution + `text_scale` default,WHEN 量 L1(HP/EXP)字號,THEN ≥ `min_font_size_px`(可讀閾值,確切數字 /ux-design 落實)。**R5 Rec-4 hard floor**:`text_scale` 調到 safe range 下界 0.8 時，`effective_font_px = max(base_font_px × text_scale, min_font_size_px)`——min_font_size_px 係 hard floor，scale 唔可跌穿（a11y knob 不可破壞 a11y 底線）;且 `text_scale` knob 調到 safe range 上下界 HUD 不破版。MSDF 保證 crisp 但唔保證可讀尺寸,故此 AC 獨立於 MSDF。 *UI · `production/qa/evidence/` · **ADVISORY**(數字 pending /ux-design)*

**AC-U-1**(banner copy 零祈使句)— GIVEN banner + 所有 PROG copy,WHEN copy walkthrough,THEN 無祈使句 / CTA(「㩒一下開聲」屬邀請非命令)。 *UI · `production/qa/evidence/` copy walkthrough · **ADVISORY***

**AC-U-2**(REST_PERIOD 唯一對焦窗 + cockpit bound)— GIVEN GSM REST_PERIOD,WHEN apply 矩陣,THEN L3(STAT/SKILLS/下一動作/剩餘組數)surface 升起;非 REST_PERIOD state L3 維持 ambient/折疊。**R8 B11 — REST_PERIOD cockpit bound(治 glance-budget 豁免後無上限)**:REST_PERIOD 雖**豁免 0.3s 餘光 glance budget**(對焦窗,可從容掃視),但**仍須 bound 同時 surface 嘅 element 數防 cockpit overload**——具體:SKILLS 完整列表**唔可無限展開**,沿用 display-cap 模式(top-N 可見 + scroll / 「展開更多」分頁,N 由 `/ux-design` 喺 target DPI 定;唔係 BOSS_ENCOUNTER 嘅 4-icon glance cap,而係對焦層較寬鬆但有界嘅 list cap)。STAT 明細同理分組。**rationale**:對焦窗 ≠ 無限資訊傾倒;REST_PERIOD 仍係 Pillar 2「無壓力」窗,塞爆 cockpit 違反「忘記佢」嘅成功標準。確切 layout / list cap 數值 defer `/ux-design`,但「對焦層有界、SKILLS 唔無限展開」係 #20 GDD 承諾。 *UI(visibility-flag 可部分 headless)· `production/qa/evidence/` walkthrough OR `tests/unit/` · **ADVISORY***

**AC-U-3**(餘光可見 count CI gate — R3 收斂3 重定義 + qa #6 grouping + R6 B2/B3/B5)— GIVEN HUD scene/source per-state,WHEN CI 跑 `tools/ci/check_glance_tier1_count.gd`,THEN 數「餘光可見 element」(標記 metadata `glance_visible==true` 且該 state 下 **element effective alpha > `deep_dim_alpha_threshold`**,**`◉`(alpha≥`ambient_alpha`)+ `○`(alpha=`ambient_alpha`)都計,`◐`(alpha=`deep_dim_element_alpha`,< threshold)+ `—`/`▽` 不計**)。**R6 B2 — operand 明文**:CI 讀每個 element 嘅 effective alpha(由 `ambient_alpha`/`deep_dim_element_alpha` const derive),同 `deep_dim_alpha_threshold` 比;三者 invariant `deep_dim_element_alpha < deep_dim_alpha_threshold < ambient_alpha` 由 CI 開機 assert(防有人調到 flip)。**R6 B3 + R7 F7 — scope 限定**:per-element count **只跑 `WORKOUT_ACTIVE` / `COMBAT_ACTIVE` / `BOSS_ENCOUNTER` 三個 state**;其餘 **6 個 state 由 state 規則豁免 per-element count**——

| 豁免 state | 豁免 rationale |
|---|---|
| `SUSPENDED` | state-level freeze-dim(有效 alpha=0.35 碰巧撞 threshold,不行 per-element 判定避免 nonsensical coupling) |
| `DISCONNECTED` | state-level dim(base_dim 0.5,唔係力竭場景) |
| `LOOT_DROP` | defer to #21 loot modal,HUD 主動退讓,唔行 glance count |
| `IDLE` | 無力竭認知負荷,唔係力竭 glance budget 約束場景(**R7 F7:IDLE 豁免 rationale 係「無力竭負荷」唔係「dim-collision」——IDLE 唔 dim,同 SUSPENDED 嘅豁免理由唔同**) |
| `BOOTING` | HUD 未 render |
| **`REST_PERIOD`**(**R7 F7 新增**) | **唯一容許對焦窗,L3 surface 有意升出餘光帶寬俾對焦,豁免 0.3s glance budget;▷ surface element 豁免 CI alpha 判定(對焦窗嘅 element visibility 由 layout rule 而非 glance budget 管)**。REST_PERIOD 唔係「dim state」,係「surface/focus state」——正確放入 state-rule 豁免嘅理由係「per-element glance count 唔適用對焦窗」。**R7 F7 根本**:原 B3 scope 只列 WORKOUT/COMBAT/BOSS(3)+ exempt(5 — SUSPENDED/DISCONNECTED/LOOT/IDLE/BOOTING)= 8;GSM 9 個 state,REST_PERIOD 兩 list 都冇 → CI tool 行為 undefined → CANNOT-RUN;而 ▷ surface alpha 從未 author(唔需要:REST_PERIOD 直接豁免,CI 唔量 ▷ alpha)。 |

(唔行 alpha 判定,覆蓋全部 9 GSM state)**R6 B5 — per-state exact-count table(取代純 `≤5`,封死 count=5 phantom-pass)**:CI 對每個 counted state assert **exact** expected count——

| State | Expected glance count | 組成 |
|---|---|---|
| `WORKOUT_ACTIVE` | **== 3** | HP(◉)+EXP(◉)+PROG(○);STAT/SKILLS=◐ 不計 |
| `COMBAT_ACTIVE` | **== 3** | 同 WORKOUT_ACTIVE |
| `BOSS_ENCOUNTER` | **== 4** | HP(◉)+Boss HP(◉)+SKILLS cluster(◉,算 1)+EXP(○,R8 B8 留餘光);STAT/PROG=◐ 不計,avatar=#26 不計 |

assert **exact `== expected`**(非 `≤ glance_tier1_max`)——`≤5` 會令 count=5 regression(STAT/SKILLS 誤升 ○)靜默過 CI,違 B2 intent;exact 值封死。**並** assert 每個 counted state `count ≤ glance_tier1_max`(讀 config,非字面 5)做 sanity upper-bound。**Grouping 規則(qa #6)**:skill-icon cluster 須有**單一 parent node 帶 metadata `glance_group==true`**,CI **數 parent 不數 children**(算 1 grouped element)。將 CR-13⑤ 由「靠 reviewer 記性」升做可執行 gate。**R8 B10 — cluster icon cap enforcement 拆 design-time / runtime 兩層(治 design-time CI 量唔到 runtime icon count)**:`get_unlocked_abilities()` 係 **runtime** 返回,實際 instantiate 幾多 child icon node 係 runtime 決定,**design-time 靜態 scan 嘅 `check_glance_tier1_count.gd` 物理上睇唔到**。故拆:**(a) design-time CI(本 AC-U-3)**只斷言 cluster parent (i) 帶 `glance_group==true` metadata (ii) 帶 `cluster_icon_cap` field 且 `== skill_cluster_display_cap(=4)` config const(防 field 漏設 / 誤設);**(b) runtime ≤4 enforcement 歸 AC-CR-12**(display cap 邏輯 unit test:注入 ≥5 ability,斷言實際 render child icon ≤ `skill_cluster_display_cap` + 其餘摺疊「+N」)。兩層互補:design-time 驗 metadata 結構正確,runtime 驗摺疊邏輯實際生效。原 R7「CI 斷言 cluster 內 active icon ≤4」係 design-time tool 做唔到嘅 runtime claim,已拆正。**R4 Rec#10 — CI tool deliverable**:`tools/ci/check_glance_tier1_count.gd` 係 **#20 epic deliverable,Epic 首 story 須建立(工具未存在前此 AC CANNOT-RUN)**;tool 須能讀 `glance_visible`/`glance_group`/`cluster_icon_cap` metadata + `glance_tier1_max`/`deep_dim_alpha_threshold`/`ambient_alpha`/`deep_dim_element_alpha` config const + per-state expected-count table。 *Logic(CI count-check)· `tools/ci/` · **BLOCKING***

**AC-U-4**(banner a11y — R2 新增)— GIVEN banner 顯示,WHEN 讀 `banner.focus_mode`,THEN == `Control.FOCUS_NONE`(唔搶 keyboard focus,one-tap touch design);且 `reduce_motion==true` 時 banner pulse 靜止(`banner_pulse_amp` 視為 0,master override)。 *Logic · `tests/unit/gym_mode_hud/` · **BLOCKING***

**AC-U-5**(banner touch target — R2 新增)— GIVEN banner tap target,WHEN 量 hit-area,THEN ≥ web touch 最小尺寸(建議 44×44 CSS px 等值,確切數字 `/ux-design` 落實)。 *UI · `production/qa/evidence/` · **ADVISORY**(數字 pending /ux-design)*

### E. Untestable / BLOCKED 標記彙總(QA gate 用)

**Untestable headlessly(ADVISORY,須 playtest + lead sign-off)**:AC-V-1(0.3s 餘光 / 80% status — 最需主觀評分)、AC-V-2/3/4、AC-CR-1、AC-CR-13⑧。

**BLOCKED(依賴未 ready,sprint 前須確認 dep 狀態)**:
- **#33**(Not Started):AC-CR-5 input-gate / AC-CR-13⑦。Prov-4 fallback = **AC-EC-S5**。
- **#8 expose**(Prov-3):AC-CR-9 streak 路由 / AC-CR-11 stagger 同幀(+ correlation key,Q-OQ1)。fallback = **AC-EC-S6**。
- **#2 GDD bidirectional**:AC-CR-9 整合測前須 #2 補列 #20 為 `set_logged` subscriber(Q-OQ5)。
- **#21**(Not Started):**AC-EC-S3** defer 行為 self-contained 可測,#21 對接 deferred。
- **~~#4 priority API(R2,Q-OQ11)~~ — R3 RESOLVED**:Q-OQ11 phantom API 已刪;#20 改直讀 `SfxCatalog.tres` priority data field(CR-10/AC-CR-10),AC-CR-10 即時可測,無 BLOCKED-on-#4。
- ~~**#4 unlock-frame voice budget**(R3,Q-OQ13)~~ — **✅ Q-OQ13 RESOLVED(R6)**:explicit-accept enhancement cost,**唔再係 sprint gate,唔需 co-design**。EC-A6(R6)已記錄為明文接受嘅 LOW EC;#20 無主動 voice-budgeting。
- **#1/platform_detect SUSPENDED producer**(R2,Q-OQ12):AC-EC-S9b bfcache wiring 須 upstream 將 `pageshow`→SUSPENDED 落地。

**Deferred-dep fallback ACs(dep ready 前可獨立過,BLOCKING self-contained)**:
- **AC-EC-S5**:GIVEN #33 未 implement,WHEN banner tap,THEN 走「直接 tap→unlock」、banner-unlock tap 永遠豁免 `is_input_permitted`。 *Logic · `tests/unit/gym_mode_hud/` · **BLOCKING***
- **AC-EC-S6**:GIVEN #8 streak signal 未 expose,WHEN `set_complete` 到,THEN 即播無 stagger(CR-11 邏輯休眠),唔因等唔存在嘅 chime 而 defer。 *Logic · `tests/unit/gym_mode_hud/` · **BLOCKING***
- **AC-EC-S3**:GIVEN GSM LOOT_DROP 但 #21 未 ready,WHEN apply 矩陣,THEN HUD 主動 defer、絕不 fallback 自畫 loot 文字。 *Logic · `tests/unit/gym_mode_hud/` · **BLOCKING***

### Coverage 自檢
- 每條 CR ≥1 AC(CR-1→AC-CR-1 … CR-13→8 項分流)✅
- 每條 formula ≥1 testable AC(F1→AC-F1 / F2→AC-F2 / F3→AC-F3,全 BLOCKING Logic)✅
- 指定 BLOCKING logic ACs 齊(CR-8 audio-buffer-gate / CR-10 / CR-11 DI-timer / EC-R4 order-invariant)✅
- 餘光/shake/glance 明確 ADVISORY(AC-V-1/2/3/4 + AC-CR-1 + AC-CR-13⑧)✅
- R2 新增 ACs:AC-U-3(L1-count CI gate)/ AC-U-4(banner focus_mode + reduce_motion)/ AC-U-5(touch target)/ AC-EC-S9a-b(reconcile 拆分)✅
- R3 新增 ACs:AC-V-5(色盲)/ AC-U-6(min-font)/ AC-EC-F4(NaN boot)✅
- **R4 新增 ACs**:AC-EC-F4b(circuit breaker livelock — EC-F4 dangling ref 補齊)/ AC-KNOB-B(dim product floor systemic)/ ~~AC-EC-A6~~(R5 DELETE)✅
- **R5 新增/修改 ACs**:AC-EC-S4-LOOT + AC-EC-S4-SUSPENDED(CR-9 deny-side 補齊)/ AC-EC-F4b 強化(desync 斷言 + reset-then-resume)/ AC-CR-8 EXP 部分 re-label Integration / AC-KNOB-B 讀 loot_dim_multiplier config const / **AC-V-1 pin 95% CI Wilson**(R5;**R6 B4 已撤——Wilson 降 advisory,binding 改 point estimate ≥80%;R5 呢條 historical record**) / AC-U-6 font hard floor ✅
- **R6 新增/修改 ACs**:AC-EC-S4-IDLE(B6 — IDLE audio deny spy)/ AC-CR-12 cluster sort 改 Formula-3 order(B1;**R7 B1 進一步改為 insertion-order fix b,AC-CR-12 同步更新**)/ AC-U-3 per-state exact-count table + scope 限定 + operand(B2/B3/B5)/ AC-V-1 拆 binding-protocol vs advisory-statistical(B4)/ AC-EC-F4b logical-epoch seam + snap-index(B7)/ AC-CR-2 counter zero-floor(B9)/ AC-KNOB-B DISCONNECTED case ✅
- **R7 新增/修改 ACs**:AC-CR-12 cluster sort 改 insertion-order + citation(B1/B2)/ AC-EC-F4b + EC-F4 加 F2 sync-dispatch spec + F5 handle-map spec + F8/F9 seam-requirement block / AC-U-3 REST_PERIOD 豁免 + IDLE rationale fix(F7) / Q-OQ1 correlation key forward-contract / Q-OQ13 stale ×3 清除(stale sweep) ✅
- **R8 新增/修改 ACs(spike-grounded + design fix)**:AC-CR-12 cluster sort 改 `tier_ordinal DESC`(B1+B13,#20-owned SkillIconRegistry,cite L386/L413/L696)/ AC-EC-F4b off-by-one(snap@MAX+1)+ empty-handle no-op + 2-param seam(B4/B5/B6,spike-verified)/ EC-F4 kill-path 獨立 erase + restart++ ordering(B2/B3)/ F1 CI joint assert 兩條 conjunctive(B7)/ 矩陣 BOSS_ENCOUNTER EXP ◐→○ + STAT ○→◐ + AC-U-3 BOSS count 3→4(B8 honor CR-1)/ EC-R6 ◐ element motion handling(B9)/ AC-U-3 cluster icon CI design-time/runtime 拆層(B10)/ AC-U-2 REST_PERIOD cockpit bound(B11)/ Q-OQ1 #20 consumer stub 兩分支(B12)/ CR-13⑨ anti-Stagnation Mirror(B13)✅
- **R8 spike grounding**:`prototypes/tween-spike/test_tween_spike.gd`(12 tests / 32 asserts / ALL PASS,Godot 4.6.3 + GUT 9.6.0)實測 kill()-唔-emit-finished / 自然完成-emit-once / kill-後-is_valid()==false / `.bind(stat_id,tween)`-2-param-arg-order / off-by-one snap@MAX+1 / identity-guard-stale-noop;SPIKE-FINDINGS.md = authoritative reverse-author spec ✅
- CR-9 deny-side audio spy 覆蓋(**R6 B6 修正**):DISCONNECTED(AC-EC-S4)+ **IDLE(AC-EC-S4-IDLE,新增 — 原 R5 誤 claim「via AC-CR-8」但 AC-CR-8 無 audio spy)** + LOOT_DROP(AC-EC-S4-LOOT)+ SUSPENDED(AC-EC-S4-SUSPENDED)= **4 個 deny-state 各有 spy count==0 斷言**;BOOTING HUD 不 render(CR-5,non-testable separately)= 全 5 deny-state 覆蓋。AC-CR-8 嘅 IDLE 斷言保留做 count/visual anti-fabrication side(同 audio spy 互補,非取代)✅
- **R7 cross-GDD claim citation(process mandate)**:B1 cite **ability-system.md L233**(get_unlocked_abilities 返 immutable Dictionary=insertion-order)+ **L696**(NEVER access internal);B8 cite audio-manager.md §84(Rule 3 priority-steal 只保 high)；**R6 phantom citation「AC-22/23」已撤**(AC-22=cooldown,AC-23=emit-order signal sequence,兩者都唔 support collection-order claim)✅

> **QA flag**:AC-V-1「0.3 秒餘光讀 80% status」係 Player Fantasy 命脈但 headless 完全驗唔到 → `/ux-design gym-mode-hud` 階段必須定量化 glance playtest protocol(**B4:升做 BINDING entry gate**,AC-V-1 **四項** BINDING 指標[protocol 交付 + point≥80% + Likert≥4/5 + 0px anchor]),否則此條 CANNOT-VERIFY,#20 唔可入 sprint。Sprint `/story-readiness` 須 re-check **5 個 dep/gate**:#33 / #8 / #2-GDD / #21 / **SUSPENDED producer(Q-OQ12)**(R3:原 Q-OQ11 #4 priority API resolved 移出 gate list;**R6:Q-OQ13 #4 unlock-frame voice budget RESOLVED explicit-accept,亦移出 gate list;R6 gate count 6→5**)。

## Open Questions

| ID | 問題 | Owner | Target resolution | 現狀 / 暫定 |
|----|------|-------|-------------------|-------------|
| **Q-OQ1** | #8 Streak 要為 #20 expose 「streak_chime 將 fire」signal,令 #20 可 stagger `set_complete`×`streak_chime`(CR-11)。**R7 correlation key forward-contract**:co-design 必須包含 **correlation key requirement** — `streak_chime` signal 須帶可關聯到 source set 嘅 key(例如 set sequence number / workout_event_id)，**或** #8 明文承諾「`streak_chime` 保證同觸發佢嘅 `set_complete` 同幀 emit」。若無 correlation key + 無同幀保證,CR-11 「同幀並存=同一組 set」嘅前提無法保證(#2 polling lag + #8 計算可能有 delta),stagger 機制 co-design 時會撞牆。**R8 B12 — #20 consumer-side conditional stub(治 forward-contract 只 spec #8 側,#20 側無對應結構)**:#20 `WorkoutAudioAdapter` 須**預留兩條 co-design 分支 stub**:**(分支 A,correlation-key route)**若 #8 提供 correlation key,#20 維護一個短壽命 `_pending_set_complete: Dictionary(correlation_key → timestamp)`,`streak_chime` 到達時按 key match 對應 `set_complete` 先觸發 stagger;**(分支 B,same-frame-guarantee route)**若 #8 承諾同幀 emit,#20 用現有「同幀並存」判定(同一 `_process`/signal frame 內兩者皆到)即觸發 stagger,無需 correlation map。**co-design 落實邊條,另一條 stub 移除**。**fallback(兩條都未落實)**:AC-EC-S6 — `set_complete` 即播無 stagger,CR-11 邏輯休眠。呢個 consumer-side stub 令 #20 dev 入 sprint 時**有明確 wiring shape**,唔會因 co-design 未定而 blocked。 | #8 Streak GDD + #20 | #8↔#20 co-design,sprint 前 | Prov-3。fallback **AC-EC-S6**(未 expose 時 set_complete 即播無 stagger)self-contained 可過;R8 #20 兩分支 stub 已 spec |
| **Q-OQ2** | #33 Attention Budget `is_input_permitted()` 未 implement(#33 Not Started),#20 input gating wiring deferred | #33 GDD | #33 author 後 | Prov-4。fallback **AC-EC-S5**(banner tap 直接 unlock,豁免 gating)可過 |
| **Q-OQ3** | Current-HP depleting bar 嘅 runtime owner 不存在(#13 pure static)。MVP HP=MAX_HP 顯示已定;depleting bar 何時/由邊個 system own? | game-designer / 新 combat-runtime-state owner | post-MVP(可折入 #25 Combat Visual Feedback) | 已拍板 MVP 唔做 depleting,唔 fabricate(CR-12)|
| **Q-OQ4** | Equip slot 概念(已裝備 vs 已解鎖技能)。MVP 顯示 `get_unlocked_abilities()` | #30 Skill Tree(v0.2) | v0.2 | 已拍板 equip deferred(CR-12)|
| **Q-OQ5** | #2 GymSys GDD 須補列 #20 為 `set_logged` subscriber(bidirectional gap)| #2 GDD | architecture / sprint 前 | AC-CR-9 整合測前置;#18 PR-Detection 先例 |
| **Q-OQ6** | #21 Loot Drop Modal(Not Started)對接:#20 LOOT_DROP defer handshake 細節 | #21 GDD | #21 author 後 | defer 行為已定(EC-S3),#21 ready 後對接;fallback AC-EC-S3 可過 |
| **Q-OQ7** | `reduce_motion` 應否 derive 自 #6 `motion_intensity` a11y slider(避免兩個獨立 a11y toggle)| #20 + #6 + master 場景 | `/ux-design` 階段 | co-design flag;Tuning Knobs Referenced 已記 |
| **Q-OQ8** | Level-up spark particle(`vfx_levelup_spark_micro.tres`)emit 喺 avatar sprite = #26 territory | #5 / #26 coordination | polish-pass | MVP default 純 Control-node glow,particle defer |
| **Q-OQ9** | **(B4 resolved-as-binding-gate;R3 F-6 protocol 重設計)** AC-V-1「0.3s 餘光讀 80% status」headless 驗唔到 → glance playtest protocol **升做 #20 epic ENTRY GATE**。**R3 fix(ux F-6:原 tachistoscope 測錯 construct)**:`/ux-design` **必須**交付量化 protocol,且 protocol 須 match Player Fantasy 嘅 **peripheral-fatigued-shaking** 命脈(非 foveal-rested-static):(a) **peripheral**——fixation cross 強制中央注視,HUD target 喺 gaze 偏心 ≥10–15°(非中央 flash);(b) **secondary load**——dual-task 模擬力竭認知佔用(tester 同時做 secondary motor task);(c) **shake 變體**——static + `hud_shakes_with_world` shaking 兩組,both ≥80%;(d) **R6 B4 — statistical 拆 binding/advisory(治 dead gate)**:**BINDING** = point estimate 答中率 **≥80%(N≥12)**;**ADVISORY** = 報 95% Wilson CI(下界)做 sample-confidence context,**唔做 binding pass 條件**(R5 Rec-1 嘅「Wilson 下界 ≥80% + N≥12」數學上不可達:N=12 即使 100% 答中下界 ≈75.8%,要下界掂 80% 需 N≈150 → dead binding gate,已撤);`/ux-design` + qa-lead 須用**現實樣本量**定可達 binding 統計標準(如「point estimate ≥80% AND CI 下界 ≥ 現實閾值 X,並計出對應最小 N」);(e) 主觀 Likert「需唔需對焦」≥4/5;(f) L1 anchor 跨 state 位移 = 0px。**四項 BINDING conjunctive(protocol 交付 + point ≥80% + Likert ≥4/5 + 0px)**;**gross-fail = BLOCKING exit,lead sign-off 不可 override,須 escalate ux 重設計**。protocol 未交付前 AC-V-1 標 **CANNOT-VERIFY**,#20 唔可入 sprint。 | qa-lead + ux-designer | `/ux-design gym-mode-hud`(epic 入 sprint 前) | **BINDING entry gate(protocol-delivery + point-estimate)**;statistical CI = advisory;Player Fantasy 命脈 |
| **Q-OQ10** | **(R3 status 降回 design-layer OPEN — ux F-4)** Boss HP / skill class 識別**唔可淨靠 color**:① Boss HP 須加 non-color glyph/形態 channel(色盲+peripheral valid,F-3);② skill icon 須 silhouette-shape encode class(F-4);③ `ui_enemy_threat` crimson 須同 Strike `#E85A5A` 區隔。原「✅ resolved 只剩色值微調」過度樂觀——係 design-layer 決策(redundant non-color coding)非色值微調 | art-director + ux-designer | `/ux-design gym-mode-hud` | ⚠️ **design-layer OPEN**(非只色值);須定 Boss HP 形態 + skill silhouette glyph set |
| **Q-OQ13** | **(R6 B8 改寫 — explicit-accept,非 false closure)** unlock 同幀 #4 self-SFX(`audio_unlock_confirm` mid)同 #20 flush(含 `workout_complete` high)嘅 8-voice pool contention。**R5 原 closure「#4 priority-steal 已全面保護 `audio_unlock_confirm`」經 audio-director 核對 `audio-manager.md §84` 證實為假**——Rule 3 priority-steal **只保 high 不被 lower steal**,mid 嘅 `audio_unlock_confirm` 係 unlock-frame high flush 嘅**合法 victim**。**R6 裁決(verified-and-accepted)**:#20 **確實**唔應主動 yield(攞唔到 #4 voice count;分幀 flush 拖慢 high SFX),但 contention **真實存在**,故**明文接受**「`audio_unlock_confirm` 最壞情況被同幀 high flush steal」做 enhancement-layer cost(unlock confirm 偶被 steal 唔損 gameplay,audio = enhancement)。EC-A6(R6)un-delete 記錄此 cost;AC-EC-A6 仍刪(設計接受無 test)。 | #4 Audio + #20 | — | **✅ RESOLVED(R6)** — verified `#4 §84` + explicit-accept enhancement cost;非「上游已保護」假設;無需 co-design |
| **Q-OQ12** | **(R2 新增,ui-programmer flag)** GSM `SUSPENDED` enum 有定義但**無 producer** 將 browser `visibilitychange`/`pageshow`→SUSPENDED(JavaScriptBridge 受 ADR-0001 鎖 `platform_detect.gd`)。#20 bfcache reconcile 依賴呢個 upstream producer | #1 GSM / platform_detect / TD | architecture(#20 dev 前) | cross-system gate;非 #20 design 缺陷,upstream 缺口 |
