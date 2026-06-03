# Gym-Mode HUD (#20) — Design Review Log

## Review — 2026-06-03 (R7 fresh re-review) — Verdict: MAJOR REVISION NEEDED
Scope signal: XL
Specialists: game-designer · systems-designer · qa-lead · ux-designer · audio-director · ui-programmer · creative-director (senior synthesis, 6-specialist adversarial convergence)
Blocking items: 13 | Recommended: 10
Summary: R7 聲稱 inline-resolve 9 BLOCKING，但 7-specialist fresh adversarial re-review 揭示 R7 自己引入 ≥7 條新 phantom（主要源自 F5 handle-map + F8/F9 seam-requirement block + CR-12 B1 fix b）。CD grep-verified ability-system.md L413「無視 insertion order」invariant，確認 B1 fix = NEW PHANTOM。B2/B5/B6 tri-entangled（F5 kill-path + AC-EC-F4b + seam 簽名），源自 Godot tween `kill()` 唔 emit `finished` runtime behavior，紙面無法收斂。**CD binding process ruling：停止 paper review，轉 tween spike（handle-map + kill-restart Godot 4.6 runtime behavior 實測），再反向 author EC-F4 + F8 spec，之後 R8。** BOSS_ENCOUNTER EXP→◐ 違 CR-1 + Anchor moment 亦確認 BLOCKING。
Prior verdict resolved: No — R7 exit bar（new-phantom == 0）證偽；R7 自身 ≥7 新 phantom

### R7 fresh re-review 13 BLOCKING
- **B1 [NEW PHANTOM]** CR-12 insertion-order phantom: ability-system.md L233 唔含 iteration-order binding contract；L413 明文 insertion-order-agnostic → R7 B1 fix 同上游 invariant 相反
- **B2 [NEW PHANTOM]** F5 kill-path erase 缺獨立 code path：`kill()` 唔 emit `finished`，kill path 無獨立 `_active_tweens.erase()` → invariant `_active_tween_count == _active_tweens.size()` 即破
- **B3 [NEW PHANTOM]** F5 `_restart_count++` ordering 未 pin：kill→create sequence 中 `++` 位置未 spec → off-by-one cap-check risk
- **B4** AC-EC-F4b off-by-one self-contradiction：create tween = 1st event（唔 ++），snap 喺第 6 個 event；AC 斷言「第 5 個 event 嗰刻 snap」= internal contradiction
- **B5** AC-EC-F4b snap path `_on_tween_finished` undefined behavior：snap 後 `_active_tweens` 已 erase，callback 對不存在 handle 嘅語意未 spec
- **B6 [NEW PHANTOM]** F5 stale-reference + F8 seam 簽名矛盾：identity guard 需 `src_tween` param，但 F8 mandate single-`stat_id` seam → 內部 contract conflict
- **B7 [NEW PHANTOM]** F1 upper seam CI assert 缺失：只 assert `element_max < threshold_min`，缺 `threshold_max < ambient_min` → upper invariant seam CI 接唔住
- **B8** BOSS_ENCOUNTER EXP→◐ 違 CR-1 + Anchor moment：reward 延後至 REST_PERIOD 對焦 = CR-1 紅線④違反
- **B9 [NEW PHANTOM]** ◐ element motion event handling undefined：BOSS_ENCOUNTER EXP = ◐ 但仍收 stat_changed，skip-tween 定 dim-tween 未 spec
- **B10** AC-U-3 cluster icon ≤4 design-time CI 驗唔到 runtime count
- **B11** REST_PERIOD 無 element-count cap（L3 cockpit risk，R6 unswepped）
- **B12** Q-OQ1 #20 consumer stub missing：correlation-key route 下 #20 side conditional logic 未 spec
- **B13 [NEW PHANTOM]** CR-13 缺 Stagnation Mirror coverage（insertion-order 最老 abilities 永久霸 cluster）

### CD process ruling
Paper review saturation confirmed（7 輪後問題由 design 未清 → fix 製造新內部矛盾）。Tween runtime behavior（`kill()` 唔 emit `finished`，Tween identity after kill）係 paper 無法裁決嘅 root cause。**CD binding：轉 GDScript tween handle-map + kill-restart spike，由實測行為反向 author EC-F4 + F8，之後唯一 R8 verification pass。**

### Next
tween spike（1 日 GDScript prototype，headless GUT 驗 kill-restart counter + `finished` 行為）→ 反向 patch EC-F4/F8/AC-EC-F4b → 同步修 B1(#12 co-design author iteration-order contract) + B8(BOSS_ENCOUNTER EXP rationale) → R8 fresh-session /design-review

---

## Review — 2026-06-03 (R7 Pass A + inline revision) — Verdict: MAJOR REVISION NEEDED → 修訂完成 R7 (pending fresh re-review)
Scope signal: L
Specialists: Pass A (verifier-driven grep-verify) — incorporates R6 session's 4-specialist adversarial findings; STRUCTURAL FREEZE protocol (no new adversarial spawns)
Blocking items: 9 (全部 Pass-A-verified fix path) | Recommended: 8
Prior verdict resolved: R6 MAJOR REVISION NEEDED 9 BLOCKING + STRUCTURAL FREEZE → Pass A verification 完成 → R7 inline-resolved 全部 9 BLOCKING

### R7 解決 9 BLOCKING
- **B1/B2 [Pass-A-verified]** — CR-12 sort key 改 insertion-order fix(b) + citation 修正(ability-system.md L233/L696 取代 phantom AC-22/23)
- **F1** — deep_dim_element_alpha safe range 收窄至 [0.15, 0.24](嚴格 < threshold 下界 0.25) + CI joint safe-range assert
- **F2** — stat_changed→tween path synchronous dispatch 明文(plain .connect,唔係 call_deferred;`call_deferred` 只限 EC-R4)
- **F5** — `_active_tweens: Dictionary` handle-map first-class spec + invariant `_active_tween_count == _active_tweens.size()`
- **F7** — REST_PERIOD 明文加入 B3 exempted list(「唯一對焦窗,豁免 glance budget」),▷ alpha 豁免 CI 判定;IDLE 豁免 rationale 改正(「無力竭負荷」非「dim-collision」)
- **F8/F9** — test seam requirement block:①具名 callback `_on_tween_finished(stat_id)` ②`_restart_count` inspectable getter;同 AC-CR-2 同級 implementation requirement
- **Correlation key** — Q-OQ1 補 forward-contract(co-design 須包含 correlation key requirement)
- **Q-OQ13 stale ×3** — Dependencies #4 / BLOCKED / QA flag 三處 sweep 至 RESOLVED;gate count 6→5

### 8 RECOMMENDED — swept
EXP anchor-loss rationale / IDLE 豁免 rationale fix / QA flag「四項 BINDING」/ Coverage Wilson superseded 標註 / R7 cross-GDD citation / coverage R7 ACs

### Next
`/clear` → fresh-session `/design-review design/gdd/gym-mode-hud.md` 獨立驗 R7 → `/ux-design gym-mode-hud`(AC-V-1 protocol + Boss HP glyph + skill silhouette + min_bar_height_px)

---

## Review — 2026-06-03 (R6 fresh re-review) — Verdict: MAJOR REVISION NEEDED + **STRUCTURAL FREEZE**
Scope signal: L
Specialists: game-designer · systems-designer · qa-lead · audio-director · creative-director (senior synthesis, full mode; main-reviewer 獨立 grep-verify B1)
Blocking items: 9 | Recommended: 8
Prior verdict resolved: R5 MAJOR REVISION NEEDED 9 BLOCKING → R6 inline-resolved → R6 fresh re-review **仍判 MAJOR REVISION NEEDED**(9 新/復發 BLOCKING)→ **CD 裁 STRUCTURAL FREEZE,停止 inline patch**

### CD process verdict — STRUCTURAL FREEZE(escalation ladder 第 3 級)
R5 已設 exit bar「new-phantom count == 0」。R6 實測**至少 4 個新 phantom**:B1 fix 自己(Formula 3 emit-order misread + 方向讀反 + citation gate-gaming)、F1(alpha invariant safe-range flip)、F5(handle-map 無定義)、F7(REST_PERIOD 9-state gap + ▷ alpha unauthored)。連續第 5 輪 review 都揭新 phantom。**Inline-revision 模式結構性失效**:每輪修 named instance 都喺鄰近表面引入同型新缺陷(B2 修 operand-missing → F7 喺 ▷ 復發;R5 撤 timestamp phantom → R6 引入 emit-order phantom;seam mandate 立咗但新 seam 唔跟)。B2 citation gate-gaming(cite 存在但指向錯 AC)係質變信號——開始 game process mandate 本身。**裁決:停 inline patch,改 3 dedicated verification pass,由 verifier 主動 grep ground-truth,唔靠作者自報 citation。**

### 9 BLOCKING(R6 fresh re-review)
- **B1 [game-designer + main-reviewer grep-verified;CD 裁定 — qa-lead 反對被駁回]** — R6 CR-12「`get_unlocked_abilities()` collection 按 Formula 3 order 排,攞頭 4 = 最高 tier 優先」係**新 phantom**:Formula 3(ability-system.md L372)= emit order(signal 次序)非 collection order;`get_unlocked_abilities()`(L233)返 read-only Dictionary = insertion order ≈ 時間 asc;方向讀反(Formula 3 係 tier-**ascending** TIER_1 first,R6 寫 tier desc);L847「order per Formula 3」只係 first-boot coincidence。
- **B2 [game-designer]** — citation「AC-22/23」引錯(AC-22=cooldown,AC-23=emit-order signal sequence),gate-gaming process mandate。
- **B3 [game-designer]** — `AbilityState` 含唔含 tier field 未 verify(B1 fix 前置)。
- **F1 [systems-designer]** — alpha 三軸 invariant safe-range 邊界 FLIP(deep_dim_element_alpha 上界 0.30 > deep_dim_alpha_threshold 下界 0.25);GDD line 244/245 親口承諾守唔住嘅 invariant = R6 B2 fix 引入嘅 phantom guarantee。
- **F2 [systems-designer]** — synchronous dispatch 未明文,AC-EC-F4b「即時讀」同 EC-R4 `call_deferred` reconcile 衝突。
- **F5 [systems-designer]** — B9 handle-tracking map(`_active_tweens`)係防負-drift 核心機制但無 first-class 定義(shape/invariant 全未 spec)。
- **F7 [qa-lead]** — B5 per-state exact-count table 漏 REST_PERIOD(9-state gap:counted 3 + exempted 5 = 8);▷ surface alpha unauthored → CI 撞 REST_PERIOD undefined,係 B2「operand-missing → CANNOT-RUN」喺 ▷ 復發。
- **F8/F9 [qa-lead + systems-designer 收斂]** — AC-EC-F4b call private `_on_tween_finished(stat_id)` + 直接讀 `_restart_count[stat_id]`,GDD 未 mandate expose 做 documented test seam(對比 AC-CR-2/CR-10/CR-11 已立標準)。
- **correlation key [audio-director]** — CR-11 stagger 假設「同幀並存=同一組 set」但 set_complete(#2 polling)同 streak_chime(#8)兩獨立 path 唔保證同幀;Q-OQ1/Prov-3 從未 author correlation-key forward-contract。

### 8 RECOMMENDED
Q-OQ13 stale ×3(Dependencies #4 ⚠️ co-design / BLOCKED「sprint 前須確認」/ QA flag 6-gate list;audio-director 評 BLOCKING,game/qa 評 RECOMMENDED — CD 歸 Pass A)/ BOSS_ENCOUNTER EXP→◐ anchor-loss cost 未 acknowledge(R5 已 flag「未落地」R6 又冇處理)/ REST_PERIOD SKILLS 列表無 cap(L3 cockpit risk)/ IDLE 豁免 rationale 同 B3 dim-collision 對唔上 / QA flag「三指標」應為「四項 BINDING」/ test seam 地位不一致 / CR-10↔EC-A6 rationale 重複 / Coverage Wilson pin 缺 superseded 標註。

### Specialist disagreement(CD 已裁)
B1 嚴重性:qa-lead 查 L847「order per Formula 3」判 B1 sound;game-designer + main-reviewer grep L372-398 證 Formula 3 = emit order + tier-ascending,L847 只係 first-boot coincidence。**CD 裁 game-designer 正確,qa-lead 跌入 first-boot-coincidence trap**。B1 = BLOCKING 確立。

### CD 三個 verification pass(取代 inline patch)
- **Pass A — cross-GDD contract grep-verify**:逐條 cross-GDD claim grep 上游 line 確認語意(收 B1/B2/B3 + Q-OQ13 stale + correlation key)。**最少強制呢個**(phantom 重災區)。
- **Pass B — test-seam catalog 子文件**(建議 `design/gdd/gym-mode-hud-test-seams.md`):集中 author 全部 test seam(`_active_tween_count`/`_restart_count`/`_on_tween_finished`/`_active_tweens`)+ shape + invariant + expose mandate(收 F5/F8/F9/F2)。
- **Pass C — alpha invariant range-closure**:CI assert safe-range 邊界亦滿足 invariant(收 F1 + REST_PERIOD ▷ alpha + EXP anchor)。
- **B1 採 fix (b)**:#20 接受 insertion-order,改寫 CR-12 rationale(零 #12 churn)。

### Next
`/clear` → **Pass A(cross-GDD contract grep-verify)** 喺 fresh session 做(verifier 主動 grep,唔靠作者自報 citation)→ B/C 收入 R7。**唔再 inline patch 直到 verification pass 完成。**

---

## Review — 2026-06-03 (R5 fresh re-review) — Verdict: MAJOR REVISION NEEDED → 修訂完成 R6 (pending fresh re-review)
Scope signal: L
Specialists: game-designer · systems-designer · qa-lead · ux-designer · audio-director · creative-director (senior synthesis, 5-specialist adversarial convergence; full mode)
Blocking items: 9 | Recommended: 11
Prior verdict resolved: R4 NEEDS REVISION 5 BLOCKING → R5 全部 resolved → R5 fresh re-review 判 **MAJOR REVISION NEEDED**(CD 由 specialist 一致 NEEDS REVISION 升級,理由 = recurring-phantom **process defect** 非 design defect)→ R6 全部 9 BLOCKING inline-resolved

### CD 升級理由(synthesis)
5 個 specialist 一致判 NEEDS REVISION(個別 item local fixable),但 CD 升 **MAJOR REVISION NEEDED**:第 4 次連續 NEEDS REVISION,「修 named instance、喺 less-scrutinized fix 引入新 phantom」嘅 pattern 重複出現——R5 自己引入 3 個新缺陷:CR-12 timestamp phantom(Rec-3)、Wilson dead gate(Rec-1)、EC-A6 false rationale(B5b)。base rate 證明「再修 N 條就 ship」係假。R6 附 **process mandate:exit bar = new-phantom count == 0,每條 cross-GDD claim 須 cite 上游 GDD line**。

### 9 真 Blocking — R6 resolved
- **B1 [game-designer × systems-designer converge]** — CR-12 sort key「最近 unlock 時間 desc」係 phantom interface:`#12.get_unlocked_abilities()` 返 Formula 3 order 無 timestamp,`first_unlocked_at_unix` persistence-only,closed API「NEVER access internal」。**Fix:CD Option (a)** 改 sort key 用 #12 Formula 3 `(tier desc, class)` order(零 #12 churn)。
- **B2 [game-designer × systems-designer × ux-designer 三 converge]** — `deep_dim_alpha_threshold=0.35` 有閾值無 operand,GDD 從未 author ◐ element 實際 alpha → AC-U-3 CANNOT-RUN。**Fix:加 `deep_dim_element_alpha=0.22` + `ambient_alpha=0.55` const + invariant `0.22 < 0.35 < 0.55`**。
- **B3 [systems-designer]** — `deep_dim_alpha_threshold` 0.35 撞 SUSPENDED effective_dim 0.35,`≤` 令 SUSPENDED count=0 coincidental pass + tuning coupling nonsensical。**Fix:AC-U-3 per-element count 只 apply non-freeze/dim state;SUSPENDED/DISCONNECTED/LOOT state-rule 直接豁免**。
- **B4 [qa-lead × ux-designer converge]** — AC-V-1「Wilson CI 下界 ≥80% + N≥12」數學不可達(N=12 100% 答中下界 ≈75.8%)= dead binding gate 永卡 epic。**Fix:CD governance — 拆 binding(protocol 交付 + point≥80% + Likert + 0px)vs advisory(Wilson report-only);現實 N 留 /ux-design 重設計**。
- **B5 [qa-lead]** — AC-U-3 count==3 只喺 EC-S7 散文,AC 本體只 `≤5` → count=5 regression phantom-pass(B2 fix 空頭支票)。**Fix:加 per-state exact-count table,CI assert exact**。
- **B6 [qa-lead]** — IDLE audio deny 無 spy 斷言,Coverage 自檢「via AC-CR-8」誤分類(AC-CR-8 只 count/visual);實際 audio spy 3/5。**Fix:新增 AC-EC-S4-IDLE(spy==0)**。
- **B7 [qa-lead × systems-designer converge]** — AC-EC-F4b「await 1 frame」非-deterministic + 違 Testing Standards + 撞 AC-CR-11;且「final value==target」對 circuit-breaker 零分辨力 phantom-pass。**Fix:改 logical event-epoch seam(無 frame timing)+ snap-index 斷言 + `_restart_count` lifecycle(tween finished → reset)**。
- **B8 [audio-director,核對 audio-manager.md §84]** — EC-A6 DELETE rationale「#4 priority-steal 已保護 audio_unlock_confirm」**證實為假**(Rule 3 只保 high 不被 lower steal,mid 係 unlock-frame high flush 合法 victim);Q-OQ13 false closure;CR-10 dangling ref。**Fix:deletion 動作保留(假 API 機制),rationale 改 explicit「接受 enhancement-layer cost」;EC-A6 un-delete 做 LOW;修 CR-10 ref;Q-OQ13 改 verified-and-accepted**。
- **B9 [game-designer]** — `_active_tween_count` 無 zero-floor,reduce_motion(無 ++)+ snap(--)可 drift 負。**Fix:`max(count-1,0)` floor + handle-tracking;AC-CR-2 加 zero-floor 斷言**。

### 11 Recommended — swept(部分)
AC-KNOB-B DISCONNECTED no-clamp case / disconnect_dim_multiplier structural 標註 / CR-9 REST_PERIOD gate rationale + audio-gate 無 generational-guard explicit / AC-CR-8 Integration fixture 邊界 + chain-smoke 責任界定 / EXP bar min_bar_height_px floor / Coverage 自檢 R6 + cross-GDD citation。**未逐一落地(留 /ux-design 或 next-pass)**:level-up flash per-set cadence AC(game R1)/ HP L1 MAX_HP 升級 cadence 明文(game R2)/ BOSS_ENCOUNTER EXP 降 ◐ anchor-loss rationale(game R3)/ REST_PERIOD layered surfacing(game R4 × ux)/ pending_buffer_cap rationale 對齊(audio R-3)/ streak correlation key forward-contract(audio R-8)/ catalog priority-drift 守「改 existing」(audio R-7)/ #2 bidirectional escalate(game R6)。

### CD binding 裁決
1. MAJOR not NEEDS — recurring-phantom pattern = process defect,R6 須係最後一輪 phantom-introduction(exit bar = 0 new phantom)。
2. CR-12 → Formula 3 order(consumer-no-upstream-churn 原則)。
3. Wilson dead binding gate = governance problem(impossible gate 比無 gate 更壞,侵蝕 project gate credibility)→ 拆 binding/advisory。
4. EC-A6 deletion action 對、rationale 假 → 保留 deletion + rewrite,唔可用 false closure 掃真 risk 入隱形。

### Next
`/clear` → fresh-session `/design-review design/gdd/gym-mode-hud.md` 獨立驗 R6(re-wire 最易留 stale ref;特別驗 CR-12 Formula-3 order 一致性 + B2/B3 alpha 三軸 invariant + B4 binding/advisory 拆分無殘留 dead-gate 措辭)→ `/ux-design gym-mode-hud`(交付 AC-V-1 現實-N binding protocol + ◐/ambient alpha 驗收 + min_bar_height_px + Boss HP glyph + skill silhouette glyph set)

---

## Review — 2026-06-03 (R4 re-review) — Verdict: NEEDS REVISION → 修訂完成 R5 (pending fresh re-review)
Scope signal: L
Specialists: game-designer · systems-designer · qa-lead · ux-designer · audio-director · creative-director (senior synthesis, 5-specialist adversarial convergence)
Blocking items: 5 (B1 deep-dim threshold / B2 WORKOUT matrix propagation / B3 circuit breaker counter desync / B4 LOOT dim const / B5 AC-CR-8 re-label + EC-A6 DELETE) | Recommended: 5
Prior verdict resolved: R4 NEEDS REVISION 5 BLOCKING → R5 全部 inline-resolved

### R4→R5 真 Blocking 5 條 — resolved
- **B1 [systems-designer × qa-lead converge]** — `deep_dim_alpha_threshold` 未定義為 named constant：EC-S7 counting rule + AC-U-3 CI tool 都靠此 threshold 判定 ◐ element 唔計入 glance budget，但 GDD 完全冇定義值，AC-U-3 CANNOT-RUN。Fix：加 `deep_dim_alpha_threshold=0.35` 入 Constants 表 + Tuning Knobs，AC-U-3 讀 config const。
- **B2 [game-designer BLOCKING]** — WORKOUT_ACTIVE/COMBAT_ACTIVE 矩陣 STAT+SKILLS 仍係 ○，但 R3 EC-S7 counting rule 改咗（○都計），矩陣冇 propagate → 5 元素 zero headroom 撞 Pillar 2 anti-pattern③。Fix：WORKOUT_ACTIVE/COMBAT_ACTIVE STAT◐+SKILLS◐，count=3；EC-S7 補 WORKOUT_ACTIVE 重驗段；AC-U-3 更新。
- **B3 [systems-designer BLOCKING]** — Circuit breaker snap path counter desync：AC-EC-F4b「穩定」措辭遮蔽 bug（snap path `--` 無 `++`，counter 可能 stuck 偏高）。Fix：EC-F4 補明文；AC-EC-F4b 改斷言「idle 後 `_active_tween_count == 0`」+ 補 reset-then-resume 斷言。
- **B4 [systems-designer × qa-lead converge]** — LOOT_DROP dim multiplier `×0.4` 裸 literal 無 named const，違反 R3 立下嘅「讀 config const」原則。Fix：加 `loot_dim_multiplier` / `disconnect_dim_multiplier` const；AC-KNOB-B 讀 config const。
- **B5 [CD binding]** — B5a：AC-CR-8 EXP forward contract 標 Logic unit 但係 chain-level Integration；補 CR-8 trust boundary prose。B5b：EC-A6/AC-EC-A6 整條 DELETE——假 API dependency（#4 voice count 無 public API）+ #4 priority-steal 已保護 audio_unlock_confirm，機制前提錯；Q-OQ13 改為 RESOLVED。

### 5 Recommended — all swept
AC-V-1 pin 95% CI Wilson score interval；AC-EC-S4 補 LOOT_DROP+SUSPENDED deny-side ACs（CR-9 deny-side 4/5 coverage）；CR-12 排序語意 pin「最近 unlock 時間 desc」；AC-U-6 補 font hard floor；AC-EC-F4b reset-then-resume 斷言（同 B3）。

### CD binding 裁決
- EC-A6/AC-EC-A6 整條 DELETE：audio-director 嘅 domain authoritative call，#4 priority-steal 已覆蓋，#20 主動 yield 係多餘。
- AC-CR-8 EXP 斷言：re-label Integration（chain-level）+ trust boundary prose；唔係要求 #20 加 consumer-side filter（CD 維持 trust #11 原則）。

### Next
`/clear` → fresh-session `/design-review design/gdd/gym-mode-hud.md` 獨立驗 R5 → `/ux-design gym-mode-hud`（交付 AC-V-1 binding glance protocol + Boss HP 形態 + skill silhouette glyph set）

---

## Review — 2026-06-03 (R3 re-review) — Verdict: NEEDS REVISION → 修訂完成 R4 (pending fresh re-review)
Scope signal: L
Specialists: game-designer · systems-designer · ux-designer · audio-director · qa-lead · creative-director (senior synthesis, 5-specialist adversarial convergence)
Blocking items: 3 (B1 EXP forward contract / B2 EC-S4 stale ref / B3 AC-EC-F4b missing) | Recommended: 10
Prior verdict resolved: R3 MAJOR REVISION NEEDED 13 BLOCKING → R3 re-review 判 3 BLOCKING (B1/B2/B3) + 10 Recommended → R4 全部 inline-resolved

### R3→R4 真 Blocking 3 條 — resolved
- **B1 [game-designer convergent]** — AC-CR-8 只斷 progress，漏斷 EXP delta==0：IDLE/SUSPENDED stray set_logged → EXP 可能跳格但 progress 唔郁 = 半 fabrication（跨 GDD boundary gap，#9 Rule 6 stat call 無顯式 short-circuit 保證）。**Fix：#20 加 consumer-side EXP forward contract**——AC-CR-8 補 `exp_fill delta==0` + SUSPENDED 變體斷言；唔 patch #9（CD 裁決：consumer 自己 own 淨效果斷言）。
- **B2 [game-designer + audio-director convergent]** — EC-S4 + AC-EC-S4 stale ref：DISCONNECTED set_logged 仍寫「SFX 照 buffer/播」，直接違反 CR-9 gate（DISCONNECTED 唔出聲）。R3 audio scope-down 冇 sweep EC-S4。**Fix：EC-S4 + AC-EC-S4 改為 SFX 唔 trigger(CR-9 gate)**；rationale 更新「斷線唔出聲係 witness 誠實」。
- **B3 [systems-designer + qa-lead convergent]** — AC-EC-F4b 缺失：EC-F4 明文引用 BLOCKING AC 但 AC 章節完全冇此 entry。circuit breaker(F4-A，最關鍵 livelock 收斂)無 test gate。**Fix：補 AC-EC-F4b（注入 N>max_tween_restart_count 同 stat_id，斷言 snap + _restart_count 歸 0）+ Coverage 自檢**。

### B4/B5/B6 降 RECOMMENDED — resolved
- **B4-降(avatar count)**: EC-S7 + 矩陣 BOSS_ENCOUNTER count 4→3；avatar = #26 territory 唔計入 #20 HUD budget；AC-U-3 CI 只 count #20-owned elements。
- **B5-降(Boss HP invariant)**: Visual Boss HP 加 binding invariant「≥1 non-color channel 必存在」，channel type defer /ux-design，但 invariant 自身係 #20 GDD 承諾。
- **B6-降(EC-A6 AC)**: 新增 AC-EC-A6(ADVISORY，unlock-frame voice headroom，runtime-validated)。

### 10 Recommended — all swept
AC-CR-8 EXP delta==0 + SUSPENDED variant；AC-EC-R2 F4-B ordering；AC-KNOB-B dim product floor(BLOCKING)；CR-10 DI seam spec；AC-V-1 bind CI 下界；UI Requirements overlay region rule；AC-U-3 CI tool deliverable 標注；Coverage 自檢補 R3/R4 AC 列。

### CD binding 裁決
consumer GDD 可 own「自己 render 嘅淨效果」forward contract，唔使 patch 已 merged upstream data-layer GDD——此原則可重用。

### Next
`/clear` → fresh-session `/design-review design/gdd/gym-mode-hud.md` 獨立驗 R4 → `/ux-design gym-mode-hud`(交付 AC-V-1 binding glance protocol + Boss HP 形態 + skill silhouette glyph set)

---

## Review — 2026-06-03 — Verdict: NEEDS REVISION → 修訂完成 R3 (superseded by above R3 re-review)
Scope signal: L
Specialists: game-designer · systems-designer · ux-designer · ui-programmer · audio-director · performance-analyst · qa-lead · creative-director (senior synthesis)
Blocking items: 4 (B1-B4) | Recommended: 11 (+5 bonus/new ACs)
Prior verdict resolved: First independent review — 推翻 authoring-time CD-GDD-ALIGN「可推進至 Approved」(同一作者鏈 self-review,catch 唔到 cross-GDD 矛盾 + soft-gate Pillar 1 嚴重性)

### Verdict rationale (creative-director synthesis)
Authoring-time CD gate 係同一作者鏈 self-review,冇獨立 plug-in #4 priority catalog 比對,所以漏咗 B1(soft-gate 困住計數 = 破 Pillar 1)同 B2(cross-GDD set_complete=low 自打嘴巴)。呢個 independent adversarial gate 嘅價值正喺度。但 4 個 blocker 全部局部、修法已知、唔使重 design → 判 NEEDS REVISION 而非 MAJOR REVISION。所有修訂「跟推薦」inline 完成同一 session。

### 4 TRUE Blockers — resolved
- **B1 [game-designer / ux-designer / audio-director convergent]** — Soft-gate 困住 workout 計數 = 破 Pillar 1。永不 tap banner 嘅玩家成個 session game-state 層「冇發生過」。**Fix: DECOUPLE** — banner 只 gate audio buffer flush;計數 + EXP 視覺反饋永不等 audio unlock。改 Overview / CR-8 / CR-3 / BannerGate / Banner Flow / EC-R4(CRITICAL→MEDIUM)/ EC-A1 / EC-S1 / AC-CR-8 / AC-EC-R4 / AC-EC-S1。
- **B2 [audio-director]** — `set_complete`=`low` priority(audio-manager.md line 368)同 CR-10「只 buffer mid/high」矛盾 → soft-gate 要保護嘅聲根本唔入 buffer,raison d'être 自我推翻。**Fix(跟推薦):留 low + 重寫 CR-8/CR-10 rationale**(B1 decouple 後 soft-gate 唔再背 Pillar 1,audio buffer 純 enhancement);唔郁 audio-manager.md(零 cross-GDD churn)。
- **B3 [game-designer / ux-designer]** — Boss HP(敵,depleting)vs Player HP(玩家,non-depleting)同 `event_amber` 同 rounded rect,餘光 0.3s single-frame 分唔到行為,notch 下位置崩。GDD-layer visual-language 衝突(amber 一義兩用),非 /ux-design layout 問題。**Fix(跟推薦):不同 color token** — Boss HP 改 `ui_enemy_threat` crimson(建議 `#C8453E`,須同 §293 Strike `#E85A5A` 區隔);三重區分 color(主)+ 位置 + 行為;amber 語意回復單一(玩家力量)。改 Visual 持續顯示三條 + Q-OQ10 resolved。
- **B4 [qa-lead]** — AC-V-1(0.3s 餘光 ≥80% status)係 Player Fantasy 命脈但 spatial 前提全 defer /ux-design → 現狀 un-verifiable hand-waving。**Fix:升 BINDING entry gate** — /ux-design 必須交付量化 protocol(tachistoscope ≥80% N≥8 / Likert ≥4/5 / anchor 0px),未交付 = AC CANNOT-VERIFY、#20 唔可入 sprint。改 Q-OQ9 / AC-V-1 / QA flag。

### Specialist disagreement adjudicated
- **HP non-depleting bar 應否 demote 出 L1?** game-designer 想 demote(0 bit/frame);作者刻意 HP=MAX_HP 避免 fabricate depleting bar(Pillar 1)。**CD 裁:HP 留 L1** — game-concept Anchor moment「HP bar 冇跌」係 Pillar 1×2 情緒核心 + Submission reassurance anchor + Silent Witness 化身。要求補 rationale:「HP 喺 L1 嘅 value 唔係 information delta,係 positional-stability reassurance」(已落 Information Tier table)。

### 11 Recommended — swept
cross-knob joint-range floor clamp(`base_dim × freeze_dim_extra ≥ 0.30`)· F3 `fmod` 入 formula body · EC-F3 sanitize 補 `exp_to_next` 負值 · `flush_stagger_ms`=40(獨立 anti-voice-steal,非借 100ms)· #4 `get_event_priority()` query API(Q-OQ11,CR-10 前置)· CR-9 honor #9 SUSPENDED/IDLE drop verdict(anti-fabrication)· `max_concurrent_tweens`=6(workout-complete burst cap)· AC-CR-11 改 DI fake-timer 斷言 scheduled param(非 SceneTreeTimer wall-clock,解 CI flaky)· AC-EC-S9 拆 9a(Logic reconcile BLOCKING)/ 9b(bfcache wiring ADVISORY)· HP L1 reassurance rationale · skill-icon cluster = 1 grouped element(Gestalt,BOSS_ENCOUNTER L1=4≤5 重驗)。

### Bonus fixes
#18 dead cross-ref 刪(PR-Detection 未實作)· CR-3 / AC-CR-3 SceneTreeTween mental-model 修正(原誤述 set_process 驅動 tween)· EC-F4 boot-time first-value NaN→0.0 guard + restart livelock guard · Performance Budget flag(draw-call / MSDF / tween allocation → /architecture-review)· 新增 AC-U-3(L1-count CI gate)/ AC-U-4(banner focus_mode + reduce_motion)/ AC-U-5(touch target)。

### Cross-system gates surfaced (not GDD defects)
- Q-OQ11: #4 expose `get_event_priority()` (priority source-of-truth #4 SfxCatalog.tres)
- Q-OQ12: GSM `SUSPENDED` enum 有定義但無 producer(browser visibilitychange/pageshow→SUSPENDED;JavaScriptBridge ADR-0001 鎖 platform_detect.gd)— upstream #1/platform_detect/TD 缺口
- Q-OQ5: #2 GDD 補列 #20 為 set_logged subscriber
- Q-OQ1: #8 expose streak signal + correlation key(CR-11 同幀因果判定)

### Next
1. `/clear` → fresh-session `/design-review design/gdd/gym-mode-hud.md` re-review(獨立驗證 R2 修訂)
2. `/ux-design gym-mode-hud` — 交付 AC-V-1 binding glance protocol(B4 entry gate)+ spatial layout / 6px 可讀性 / Boss crimson 色值
3. architecture-review — perf budget 量化 + Q-OQ11/Q-OQ12 cross-system gates

---

## Review — 2026-06-03 (R2 re-review) — Verdict: MAJOR REVISION NEEDED
Scope signal: L
Specialists: game-designer · systems-designer · ux-designer · audio-director · qa-lead · creative-director (senior synthesis, ground-truth verified)
Blocking items: 13 (跨 5 domain) | Recommended: ~20 | Nice-to-have: ~10
Prior verdict resolved: R2 修訂(B1-B4)方向全部正確,但**揭露新問題 + 未竟之處** → re-review 由 NEEDS REVISION **降級** MAJOR REVISION NEEDED

### 降級理由(CD synthesis)
(1) **架構互斥要 re-wire 非補 guard**:CR-9「honor #9 per-set drop verdict」同 EG-1 裁決(#9 pure data 永不 forward per-set,consumer 直訂 raw #2)**架構互斥**——#20 直訂 raw set_logged 物理上攞唔到 #9 per-set verdict。B1 decouple 將計數路徑搬去直訂 raw `#2.set_logged`,fabrication 入口由 audio path 轉移到 **count path**(game-designer F1 + audio-director 項5 兩 domain 獨立 converge):IDLE/SUSPENDED stray set_logged(reconnect burst)會令 HUD 計數+1+EXP 跳格但 #9 drop → Silent Witness 講大話 → 破 Pillar 1。(2) **review pass 引入新 blocker**(Q-OQ11 `get_event_priority()` 係 phantom API——#4 已 Approved+merged 嘅 closed API 冇此 method,CD grep 確認)= regression signal。(3) **point-fix 病灶**(systems-designer):R2 全部只修被點名 instance 唔修整類(fmod 修大-arg 漏 divisor=0 / joint-clamp 修 SUSPENDED 漏 LOOT / livelock 修 NaN-into-tween 漏 restart 收斂 / EC-S7 count 漏 ambient)→ false-confidence。(4) **B4 entry gate 測錯 construct**(ux F-6):tachistoscope 300ms=foveal-rested-static,但命脈係 peripheral-fatigued-shaking → false-pass gate 比冇 gate 更危險。但 vision 穩 + B1 方向對 → 唔到 REJECT-重 design。

### 13 BLOCKING(按 domain)
- **[game-designer] F1**: 計數路徑繞過 #9 phase gate → Silent Witness 可講大話(CR-8 缺 #9-phase-validity gate,只 CR-9 補咗 audio 側)
- **[systems-designer] F3-A**: F3 banner_alpha body 對 `pulse_period=0` 無 guard → fmod(t,0)=NaN → pulse tween livelock(F1 有內嵌 max() guard,F3 冇)
- **[systems-designer] KNOB-B**: cross-knob floor clamp point-fix——R2 只修 SUSPENDED,`base_dim×LOOT(×0.4)`=0.16 無 floor。應 systemic「所有 base_dim×state_multiplier≥floor」
- **[systems-designer] F4-A**: EC-F4 restart livelock 收斂靠 OR(reduce_motion default-off + 未定義「最長壽命上限」)→ default config 兩條件皆失效;同 EC-R2 kill-restart 製造唔收斂
- **[systems-designer] SM-A**: HUD state machine 缺 BannerGate→Suspended 轉移;resume 終點硬寫 Active 但 EC-S2 要 banner 復現,table/EC-S2/reconcile④ 三處矛盾
- **[ux-designer] F-1**: EC-S7 BOSS_ENCOUNTER count 只計 ◉ emphasis 漏 ○ ambient 餘光佔用,實際 ≥5(6 件)破 4±1;AC-U-3 CI gate false-green
- **[ux-designer] F-3**: crimson vs amber 色盲靠 luminance peripheral 失效;「行為(depleting)」backup 喺 0.3s 快照零 bit → 三重區分實為單一(位置);無色盲 AC
- **[ux-designer] F-4**: Strike/Control/Mobility 3色 + Boss crimson 色盲互撞;≤3px accent 餘光零分離;Q-OQ10「✅resolved」過度樂觀;icon silhouette 應 encode class
- **[ux-designer] F-5**: AC-V-1c「0px 位移」冇對應 layout-isolation design rule;BOSS_ENCOUNTER Boss HP「上方」+ REST_PERIOD L3 升起 reflow 未 spec
- **[ux-designer] F-6**: tachistoscope 300ms 測錯 construct(foveal-rested-static vs 命脈 peripheral-fatigued-shaking);protocol 冇 eccentricity/secondary-load/shake;N≥8 偏低 → entry gate false-pass
- **[ux-designer] F-8**: 冇 min-font-size knob/AC,accessibility checklist 第3/7項無對應
- **[audio-director] 項5**: CR-9×EG-1 架構互斥(同 game-designer F1 同根),須 scope down GSM-state-level gate + 明文承認 audio residual false-positive 可接受
- **[audio-director] 項2 / [qa-lead] #1**: Q-OQ11 `get_event_priority()` phantom dep(#4 closed API 無此 method),令 AC-CR-10 掛 fictional dep 無法測。改:#20 直讀 `SfxCatalog.tres` priority field

### 額外 qa-lead BLOCKING
- **#2**: AC-EC-R4/AC-CR-8 只有相對/遞增斷言缺 absolute-value → order-invariant 證一致不證正確(兩 order 一致咁錯 phantom-green)。加 `count==注入數` 絕對斷言
- **#3**: magic numbers 內聯(cap12/concurrent6/stagger100)違 no-hardcoded-data;斷言須讀 config const

### CD binding 裁決(4 個 cross-domain 收斂點)
1. **收斂1**(最高):#20 計數/EXP/progress 改行 **#9 phase-aware path**;raw `#2.set_logged` 只留 audio consumer + 明文承認 audio residual false-positive 可接受;CR-9 scope down 到「audio gate 自身 SFX 喺 #9 phase-valid query 之上」
2. **收斂2**:刪 Q-OQ11 gate;#20 直讀 `SfxCatalog.tres` priority field(零 #4 churn);AC-CR-10 即時可測
3. **收斂3**:glance counting unit 重定義為「所有佔 0.3s 餘光帶寬嘅 visible element」(◉+○+avatar+boss),改 CI predicate,誠實重 count
4. **收斂4**(accept):HP 留 L1,rationale 由「持續確認」改 **event-anchored reassurance**

### Specialist disagreement(已仲裁)
- HP demote:game-designer 同意上一輪 CD「留 L1」,只要求 rationale 改 event-anchored。**無人反對留 L1**,CD 維持留 L1。
- 無其他實質 disagreement;5 domain 高度 converge(收斂1 跨 game-designer×audio-director,收斂2 跨 audio-director×qa-lead,收斂3 跨 ux×game-designer)。

### R3 必做清單(優先序)
1. 收斂1 re-wire(計數行 #9 phase-aware) 2. 收斂2 刪 Q-OQ11 改讀 catalog 3. 收斂3 重 count glance + 改 AC-U-3 CI predicate 4. invariant 升級寫「所有 X」(F3-A divisor guard / KNOB-B systemic floor / F4-A 收斂 constant+AC / SM-A state transition) 5. B3 色盲 silhouette-encode + 色盲 AC / B4 AC-V-1 protocol 加 peripheral+shake+secondary-load+N≥12 6. qa 絕對斷言 + const 化 + AC-CR-10 fallback 7. HP rationale + F-8 min-font knob + F-5 layout-isolation rule
**R3 完必須 fresh-session 獨立 re-review**(verify re-wire 喺 EC/AC 全鏈一致,最易留 stale ref)。
