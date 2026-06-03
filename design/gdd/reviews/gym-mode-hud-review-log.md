# Gym-Mode HUD (#20) — Design Review Log

## Review — 2026-06-03 — Verdict: NEEDS REVISION → 修訂完成 (pending fresh re-review)
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
