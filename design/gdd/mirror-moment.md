# Mirror Moment System (#29)

> **Status**: **✅ APPROVED — /design-review 2026-06-10**(NEEDS REVISION → revise-now → APPROVED 同 session;1 BLOCKING B-1 [celebration-burst layer routing] + R-1 [caption #9 source] + R-2 [ADR-0010 Key Interfaces] 全部 resolved)。所有上游 citation grep-verify EXACT against shipped #26 v2.1 + GSM/#5 src。Coupled pair 完成:#26 AvatarRenderer APPROVED + 本 GDD 一齊 ratify **ADR-0010 Proposed→Accepted**(#26 holds tier-state/snapshot/signal,#29 holds zero tier-state + owns ceremony — ADR validation criteria 全部滿足)。**NEXT**:/ux-design(coupled pair)→ /create-epics。
> **Creative Director Review (CD-GDD-ALIGN, degraded-inline)**: pillar 對齊 self-check 通過 — **P5 PRIMARY**(慶典交付 Pillar 5 weekly visible-evolution,REFLECTION+EVOLUTION 雙慶典守 weekly cadence)· **P3** screenshot-share dopamine(FT-2 ≥30%)· **P2** non-workout gate 三層防(#26 CR-15 defer + CR-M3 present gate + #33 soft)· **P1** zero-fabrication(CR-M6 fresh snapshot + CR-M14 no-tier-compute + CR-M15 honest skip)。0 pillar drift。Full multi-specialist CD synthesis 留 fresh-session /design-review。
> **Author**: Frank + agents (degraded-inline: game-designer + systems-designer + art-director + ux-designer + qa-lead perspectives; full multi-agent /design-review pending fresh session)
> **Last Updated**: 2026-06-10
> **Implements Pillar**: **Pillar 5 (Mirror Moment) PRIMARY** — owns the weekly ceremony · Pillar 3 (Drop Euphoria) supporting — screenshot-share dopamine · Pillar 2 (Frictionless Companion) constraint — never fires mid-workout · Pillar 1 (Real Body, Real Power) constraint — ceremony renders only real change, never fabricates
> **System #**: 29 (Polish tier)
> **Depends On**: #26 AvatarRenderer (HARD) · #17 Equipment & Inventory (Soft) · #18 PR Detection (Soft) · #1 GSM (gate) · #3 PersistenceLayer (`mirror_moment.*`) · #5 ParticleSystemWrapper (celebration VFX) · #33 Attention Budget (Soft)
> **Depended On By**: (none — terminal Polish system)
> **Governing ADRs**: **ADR-0010 Mirror Moment Ceremony Ownership Split** (Proposed → ratified by #26 APPROVED + this GDD) · ADR-0001 Web Export Budget Caps (CanvasLayer topology + particle budget) · ADR-0003 Save State Strategy (`mirror_moment.*` namespace) · ADR-0006 State Machine Contract (Contract 6 `connect_for_initial_state`, non-workout gating via GSM state) · ADR-0009 Signal Payload Schema (transition_id correlation)

---

## Overview

Mirror Moment System (#29) 係 Mirror Hero 嘅 **weekly 慶典 orchestrator** —— Pillar 5(鏡像時刻)嘅交付者。佢一個禮拜搞一次,喺玩家**唔喺 gym set 期間**(non-workout context)打開 game 嗰一刻,將「你今個禮拜真實訓練令 avatar 變咗嘅嘢」砌成一個**可截圖、可分享**嘅 reveal moment。冇 #29,#26 Avatar Renderer 會默默換 sprite 但冇人為呢個變化「停一停、影張相、認返自己變強咗」—— 而嗰個停頓正正係單機 game 嘅 retention 心臟(game-concept Retention Hooks:「每週 visible 進化嘅 anticipation」)。

**單一職責(ADR-0010 binding seam)**:#29 **own 慶典,唔 own 形象**。佢 own 三件嘢 —— (1) **WHEN**:weekly cadence detection + Pillar-2 non-workout gate(幾時夠鐘、喺咩 context 先彈);(2) **COMPOSITION**:before→after reveal 構圖、screenshot prompt(MVP v1 唯一交付物)、share-card framing;(3) **CELEBRATION**:經 #5 ParticleSystemWrapper 嘅慶祝粒子放大。佢**唔 own** avatar 嘅 visible state、evolution tier、sprite —— 嗰啲全部係 #26。#29 對 #26 嘅關係係**單向、唯讀**:佢訂閱 #26 嘅 `avatar_evolution_milestone` / `avatar_micro_evolution` 做 trigger,call `#26.get_evolution_snapshot()` 攞當前 render state 去砌 portrait,但**永不**計算或儲存 evolution tier(任何 tier 計算邏輯出現喺 #29 = CI 違規)。呢個就係 ADR-0010「identity vs celebration」嘅縫:silhouette 由 #26 載住 identity,#29 嘅粒子只載 celebration。

**Data 層面**:#29 維護一個薄薄嘅 `mirror_moment.*` persistence state(上次慶典時間、上次慶典 tier、pending 慶典、本週有冇變化)—— **零 evolution-tier state**。每次收到 #26 milestone signal 就 set pending flag + persist(確保 tier-up 永不因為玩家遲開 game 而失落);每次符合 cadence + context gate 就呈現一次慶典。

**Player-facing 層面**:星期日朝早,玩家做完一週第三次訓練,喺更衣室打開 Mirror Hero。唔使 swipe、唔使入 menu —— 畫面自動停一停,avatar 擺出 hero pose,旁邊一個淡淡嘅「上週」ghost 對比,一行 caption「第 6 週 · STRIKE · 進化到 T2」,加一個「截圖分享」affordance。玩家影張相,發去朋友圈。**呢一秒就係 4 週訓練嘅 visible receipt。**

**MVP scope(locked per ADR-0010 + systems-index CD-SYSTEMS resolution)**:**screenshot-only** —— weekly threshold 過(#26 sprite swap)→ #29 砌一個 minimal before/after share-card + screenshot prompt + 一下慶祝粒子 burst。**NOT in MVP(推遲 v0.2 "full layered ceremony")**:多 beat 編排嘅 reveal choreography、9:16 layered portrait compositing、in-app capture-to-PNG、share funnel deep-link、ghost overlay 動畫。MVP 證明「呢個 moment 值唔值得截圖分享」(FT-2 ≥30% weekly self-initiated share);v0.2 先加重慶典製作。

**Player interaction model**:**passive-trigger, active-share** —— 玩家唔操作慶典幾時出(系統 detect),但慶典出現後玩家主動截圖、分享、dismiss。所有慶典內容 100% derive from #26 snapshot(+ optional #17/#18 narrative payload)—— 慶典唔可以講大話,冇真實變化就冇慶典(Pillar 1)。

## Player Fantasy

### Core Identity:「停一停,認返自己」(The Pause Where You Recognise Yourself)

> **#26 係本帳簿,默默記住你 deposit 過嘅每一磅。#29 係每週一次,將呢本帳簿揭出嚟、打 spotlight、叫你影張相嘅一刻。**

健身房入面個鏡係 staple —— 你練完一組,望一望鏡,確認「我啱啱舉起咗」。Mirror Moment 就係 game 入面嗰塊鏡。它唔係新嘅力量、唔係新嘅 loot —— 它係**一個被設計過嘅停頓**:每週一次,game 主動同你講「埋嚟睇,你呢一週真係變咗」。

錨定時刻:**星期日朝早,更衣室,鏡前。** 你做完一週第三次 leg day,部機都未放低,順手打開 Mirror Hero。畫面冇等你揀 —— 它自己停低,avatar 擺出一個 still 嘅 hero pose,旁邊浮一個 30% 透明嘅「上週」ghost,你一眼睇到剪影闊咗。一行字:**「第 6 週 · 你練咗 18 次 · STRIKE 進化到 T2」**。一個「截圖分享」掣。你撳一下,張相入咗相簿,你 send 去 group chat:「睇下我隻 character。」

呢個 fantasy 服務嘅情緒係 **Achiever 嘅 transformation pride**(game-concept:健身前後對比照嘅儀式感)—— 但關鍵係**佢唔可以 fake**。你個 character 變咗,係因為你真係練咗。截圖之所以值得分享,正正因為旁邊嗰個人知道:呢個唔係課金、唔係刷怪,係佢真係去咗 gym。

### 同 #26 嘅情感分工(ADR-0010 在 fantasy 層的體現)

| | #26 Avatar Renderer | #29 Mirror Moment |
|---|---|---|
| 隱喻 | **帳簿**(ledger)—— 一直喺度,默默記 | **鏡 + spotlight**(mirror)—— 每週一次,叫你停低睇 |
| 情緒 | 確認感(「我練咗」,mid-set 0.3s glance) | 慶祝 + 自豪 + 分享衝動(「睇下我」,週末停頓) |
| 玩家動作 | 唔做嘢(被動 render) | 主動截圖、分享、dismiss |
| 失敗後果 | avatar 唔變 → 形象斷裂 | 變咗但冇人為佢停一停 → retention 心臟停跳 |

#26 令 avatar 真係變;#29 令呢個變化**值得被見證**。冇 #29,玩家可能成個月都唔為自己嘅進化停過一秒 —— 變化發生咗,但情感獎勵漏咗。

### Pillar 5 = 單機 retention 心臟

game-concept 寫明:「Mirror Moment — 每週 visible 進化嘅 anticipation」係四大 retention hook 之一,亦係**唯一**針對「下一週點解要返嚟」嘅 hook(其餘三個 Curiosity / Investment / Mastery 都係 within-session)。Pillar 5 design test:「玩家做完 4 週訓練,打開 game 第一眼睇唔睇到自己變咗?」應答 **YES** —— 呢個「第一眼」就係 #29 製造嘅停頓。

### Fantasy Boundary

**In scope(#29 做)**:weekly 停頓嘅編排 · before→after / 本週回顧 構圖 · screenshot prompt + share-card framing(MVP 唯一交付)· 慶祝粒子 burst(#5,celebration only)· non-workout gate(永不喺 set 中彈,Pillar 2)· honest「冇變化就冇慶典」(Pillar 1)。

**Explicitly NOT(#29 唔做)**:**任何 evolution-tier 計算 / visible state derivation(→ #26)** · sprite 換邊個版本(→ #26)· 製造一個冇真實 data backing 嘅「你變強咗」假象(Pillar 1 violation)· mid-workout 彈慶典(Pillar 2 violation)· 每日彈(cadence 係 weekly,日日彈 = 通知疲勞 + 貶值)· 攞走玩家已得嘅嘢做「慶典」籌碼(anti-pillar)。

### Falsifiable Tests

| # | Test | Falsification trigger | Pillar | Owner |
|---|------|----------------------|--------|-------|
| **FT-2** | **Screenshot share rate**(由 #26 遷移嚟,ADR-0010)| 慶典上線後,weekly self-initiated screenshot/share < 30%(playtest telemetry `mirror.shared`)| P5 | **#29** |
| **FT-M1** | **Weekly pause noticeability** | 5 playtester 做完 ≥2 週訓練,< 80% 喺週末 first-open 注意到慶典出現過 | P5 | #29 |
| **FT-M2** | **No-fabrication audit** | 任何一次慶典內容(tier / caption / before-after)唔 100% derive from #26 snapshot(+ #17/#18 payload)→ audit fail | P1 | #29 |
| **FT-M3** | **Non-workout gate** | 任何一次慶典喺 GSM ∈ {WORKOUT_ACTIVE, REST_PERIOD} 期間呈現 | P2 | #29 |

### Design Test for Future Ceremony Features

「慶典加個新元素(連擊計分 / 排行榜對比 / 每日簽到獎)」proposal 出現時問:**「呢個元素係咪每週一次、唔搶 set 注意、而且呈現嘅嘢 100% 嚟自玩家真實訓練 data?」** 任何一條答唔到 → 唔加。守住 Pillar 5 嘅「每週、停頓、誠實」三性。

## Detailed Design

### Ownership Seam with #26 Avatar Renderer (ADR-0010)

ADR-0010 將 Pillar 5 沿「**identity vs celebration**」縫一分為二。本 GDD 同 #26 v2.1 一齊 ratify 呢個 ADR(Proposed → Accepted)。下表係 binding ownership;任何一格越界 = 設計違規。

| Concern | Owner | Interface |
|---------|-------|-----------|
| Derive + render avatar visible state (posture / tier / anim / sprite) | **#26** | internal — #29 唔掂 |
| Evolution-tier state + history + monotonic lock | **#26** | #29 **唯讀**,經 snapshot |
| Tier-promotion detection + milestone trigger | **#26** | #26 emit `avatar_evolution_milestone(tier, source_metrics)` |
| Weekly micro-evolution delta (shader) | **#26** | #26 emit `avatar_micro_evolution(delta_kind, source_metrics)` |
| Current render-state snapshot (sprite paths + hero pose frame + prior tier) | **#26** | `#26.get_evolution_snapshot() -> AvatarEvolutionSnapshot` |
| **慶典幾時出**(weekly cadence + non-workout gate) | **#29** | own |
| **Reveal 構圖**(before→after / 本週回顧 / 9:16 canvas / ghost offset / divider / tier badge) | **#29** | own — 用 snapshot 砌 |
| **Screenshot prompt + share-card framing**(MVP 交付) | **#29** | own |
| **Celebration VFX choreography**(粒子放大,celebration only) | **#29** | 經 `#5.play(...)` |
| FT-2 share-rate falsifiable test | **#29** | own |

**單向依賴(binding)**:#29 → #26,**永無 back-edge**。#26 對 #29 一無所知(冇任何 `#29.*` reference 出現喺 `src/autoload/avatar_renderer.gd`)。#29 holds **zero** tier-derivation code;#26 holds **zero** ceremony-composition code。CI-MM-1 lint 守住:`src/**/mirror_moment*.gd` 唔可以出現任何 evolution-tier 計算(無 `S_t`/`A_t`/`D_t` threshold compare、無 `effective_tier = max(...)` pattern)—— tier 只可以由 `get_evolution_snapshot().tier` 讀入。

**#26 對 #29 暴露嘅完整 contract(grep-verified against avatar-renderer.md v2.1)**:

```gdscript
# Signals #29 subscribes to (via connect_for_initial_state, ADR-0006 Contract 6):
signal avatar_evolution_milestone(tier: int, source_metrics: Dictionary)   # CR-5 — the big ceremony trigger
signal avatar_micro_evolution(delta_kind: StringName, source_metrics: Dictionary)  # CR-5b — weekly shader delta marker

# Read-only API #29 calls:
func get_evolution_snapshot() -> AvatarEvolutionSnapshot   # CR-11 — the ceremony seam

# AvatarEvolutionSnapshot (read-only resource #29 composes from):
#   tier: int                          # current evolution_tier
#   class_posture: StringName          # STRIKE/CONTROL/MOBILITY
#   sprite_frames_resource_path: String        # "after" sprite
#   hero_pose_frame: int               # the still "mirror" pose frame index
#   prior_tier: int                    # last-ceremonied tier (for ghost/before)
#   prior_sprite_frames_resource_path: String  # "before" sprite (ghost)
#   source_metrics: Dictionary         # {stat_total, ability_count, max_class_depth, achieved_at_unix}
#   snapshot_taken_unix: int
```

> **#26 已替 #29 做嘅 timing 保證**:#26 CR-15 將 `avatar_evolution_milestone` emit **deferred while GSM ∈ {WORKOUT_ACTIVE, REST_PERIOD}**,所以 #29 **永不會喺 set 中收到** milestone signal。#29 仍然獨立 gate 自己嘅**呈現**(CR-M3)做 defense-in-depth,但 trigger 端已經安全。

### Core Rules

15 binding rules + 4 CI lints。每條 rule implementation-binding,tagged 去 falsifiable test 或 pillar。每個常數 single-defined 喺 **Tuning Knobs**。

#### Cadence + Gating

| # | Rule | Binding |
|---|------|---------|
| **CR-M1** | **單一 weekly cadence,content-adaptive** — #29 只有**一個** cadence engine:`MIRROR_CADENCE_SECONDS`(604800 = 7日,parity #26 `MILESTONE_CADENCE_SECONDS`)。一個 cadence window 內**最多呈現一次**慶典。Cadence 用 server-time-sanity-checked wall-clock(`TimeProvider.now_unix()`;同 #17 Rule 4 一致 —— persisted monotonic anchor 跨 WASM reload 歸零會 poison drift,故用 wall-clock + #2 server-time sanity)。窗口邊界 = `now_unix - last_ceremony_unix >= MIRROR_CADENCE_SECONDS`。慶典**內容**由 CR-M2 按本週實際變化選;cadence 只決定「夠唔夠鐘」。 | P5 + Formula 1 |
| **CR-M2** | **Content tier 三選一(Formula 2)** — cadence window 開 + safe context 時,按本週實際變化選慶典類型:(a) **EVOLUTION**(有 pending tier-up,`pending_evolution_ceremony == true`)→ before→after reveal + 慶祝 burst + screenshot prompt(大慶典);(b) **REFLECTION**(無 tier-up 但 `week_had_change == true`,即收過 `avatar_micro_evolution`)→ 當前 avatar hero pose + 本週回顧 caption + screenshot prompt(輕慶典,守住 Pillar 5 weekly cadence);(c) **NONE**(本週零變化,`week_had_change == false` 且無 pending)→ **唔呈現**(Pillar 1 誠實,見 CR-M15)。 | P5 + P1 + Formula 2 |
| **CR-M3** | **Non-workout presentation gate(Pillar 2 defense-in-depth)** — 慶典**呈現**只可以喺 GSM `get_current_state()` ∈ `{IDLE}` 嘅安全 context。明確排除:`{WORKOUT_ACTIVE, REST_PERIOD}`(set 中,Pillar 2 核心)· `{COMBAT_ACTIVE, BOSS_ENCOUNTER}`(打緊,唔搶戰鬥)· `{LOOT_DROP}`(#21 modal 進行中,唔疊 modal)· `{BOOTING, DISCONNECTED, SUSPENDED}`(未 ready)。若 #33 Attention Budget 在席,額外經 `#33.is_input_permitted()` 確認(Soft dep —— 唔在席則只用 GSM gate)。Gate 唔過 → 慶典 hold,下次入 IDLE 再試(CR-M4 latch 保住)。 | P2 + FT-M3 |
| **CR-M4** | **Pending-milestone latch(tier-up 永不失落)** — 收到 `#26.avatar_evolution_milestone(tier, source_metrics)` → set `pending_evolution_ceremony = true` + 記 `pending_tier = tier` + `pending_source_metrics = source_metrics` + **即時 persist**(`mirror_moment.*`)。即使玩家成個禮拜都唔喺 non-workout context 開 game(每次練完即 quit),pending 跨 session / 跨 crash 保住,下次安全 open flush。Latch 喺慶典**成功呈現後**先清(CR-M9)。 | P5 + CR-M13 |

> **N-2 相位差註記(intentional,非 drift bug)**:#26 micro-evolution cadence anchored to `account_created_unix`(固定週錨);#29 ceremony cadence anchored to `last_ceremony_unix`(滑動,每次呈現重設)。兩者皆 604800s,但相位可偏移。`week_had_change` 係 **sticky boolean**(收 micro/milestone 置 true,**只喺慶典呈現後**清 CR-M9)—— 呢個 stickiness 正正吸收咗相位差:只要上次慶典後收過任何 micro-evolution,window 開時 REFLECTION 必觸發;真零訓練週(無 micro)先 NONE skip(CR-M15 誠實)。故相位偏移**唔會**丟失慶典。

#### Composition + Collapse

| # | Rule | Binding |
|---|------|---------|
| **CR-M5** | **Before→after collapse(多 tier-up 折一次)** — 一個 cadence window 內可能收到**多個** milestone(老用戶 server backfill / 快速進步,T1→T2→T3 同週)。慶典**唔**逐個 tier 開 N 次 —— `get_evolution_snapshot()` 嘅 `prior_tier` = 上次**慶典過**嘅 tier,`tier` = 當前最新 tier,一個 before→after 直接由 last-ceremonied 跳到 current(中間 tier 唔逐格演)。Caption 顯示 net 變化(「T0 → T2」)。呢個係 #26 snapshot 已經保證嘅語意(prior = `last_emitted`/last-ceremonied),#29 只係 trust 佢。 | P5 + EC-MM-4 |
| **CR-M6** | **Snapshot-at-present(唔 cache stale state)** — 慶典**呈現嗰一刻**先 call `get_evolution_snapshot()` 攞 fresh state,**唔**用 milestone signal payload 入面嘅 `source_metrics` 當 render source(payload 只用嚟 latch + telemetry)。理由:milestone 可能 latch 咗幾日先呈現,期間 avatar 可能再變(再 tier-up / micro-evolution / posture swap)—— 慶典必須反映**呈現時**嘅真相,唔係 trigger 時嘅。`source_metrics` 入 narrative payload 做「呢次升級嘅成因」歷史註記。 | P1 + FT-M2 |
| **CR-M7** | **Screenshot prompt + share-card(MVP 唯一交付)** — 每次呈現(EVOLUTION 或 REFLECTION)必含一個 **bounded share-card region**(一個固定 aspect 嘅 Control,內含 avatar hero pose + caption + tier badge)+ 一個 **screenshot affordance**(「截圖分享」掣)。MVP:撳掣 = 顯示 native-screenshot hint(「用裝置截圖功能影低呢個畫面」)+ 將 share-card 推到最乾淨狀態(暫隱周邊 UI chrome)。**In-app capture-to-PNG(`get_viewport().get_texture()` → `user://` / download)推 v0.2** —— MVP 信玩家自己截圖(web export file-save 跨瀏覽器唔可靠)。撳掣 emit `mirror.share_prompted`;玩家確認影咗(或 dismiss)emit `mirror.shared` / `mirror.share_skipped`(FT-2 telemetry)。 | P3 + P5 + FT-2 |
| **CR-M8** | **Celebration VFX = #5,celebration-only** — 慶祝粒子**只**經 `#5.ParticleSystemWrapper.play(preset_id, position, multiplier)`(grep-verified `particle_system_wrapper.gd:419`,`preset_id: PresetId` enum,`play()` 係唯一 trigger method)。#29 **唔**自己 instantiate `GPUParticles2D`(technical-preferences forbidden pattern;#5 係唯一 owner)。EVOLUTION → 一下 celebration burst preset;REFLECTION → 無 burst 或極輕(輕慶典唔放大)。Mobile 0.5× density 由 #5 內部 / ADR-0001 處理,#29 platform-transparent。**粒子坐 CelebrationVFXLayer 110**(modal-class VFX layer,**非** world ParticleLayer z≥20 —— modal overlay 之上;grep-verified #5 只 reparent LOOT-preset/LARGE-tier 節點上 `_celebration_layer`,故 `CELEBRATION_BURST_PRESET` 必為 LOOT preset,B-1),share-card chrome 坐 ModalLayer 120。**Celebration-layer infra 依賴**:#5 `register_celebration_layer` handshake 須 live(CelebrationVFXLayer 110 persistent registered,IDLE 慶典時 #21 modal 唔 active 但 layer 仍在席)。ADR-0010:silhouette(#26)載 identity,#29 粒子只載 celebration —— degrade 粒子唔影響 avatar 可辨識度。 | P3 + ADR-0001 + ADR-0010 |

#### Anti-Fabrication + Ownership

| # | Rule | Binding |
|---|------|---------|
| **CR-M9** | **Once-per-window + dismiss(唔 nag)** — 慶典**成功呈現**後即 set `last_ceremony_unix = now_unix` + `last_ceremony_tier = snapshot.tier` + 清 `pending_evolution_ceremony` + 清 `week_had_change` + persist。同一 cadence window 內**唔再**呈現(即使玩家再開 game 幾次)。玩家 dismiss(撳關 / 影完相 / auto-dismiss)都算「呈現過」—— **影唔影相唔影響** window 標記(唔可以因為玩家唔影相就日日 re-nag,Pillar 2)。`CEREMONY_AUTO_DISMISS_SECONDS`(default 0 = manual dismiss only)。 | P2 + P5 |
| **CR-M10** | **Narrative payload(optional,null-safe)** — 慶典 caption 可選地 enrich:(a) 若本週有 LEGENDARY drop 帶 `SourceReceipt`(#17 Rule 10,`signature_text` 如「鍛造自 180kg × 5」)→ 顯示「本週簽名戰利品」一行;(b) 若本週有 PR breakthrough(#18 context)→ 顯示「本週 PR:Bench 65kg」一行。**兩者皆 Soft + null-safe**:#17/#18 唔在席 / 本週無 receipt / 無 PR → 嗰行**唔出**,慶典照常(只用 #26 snapshot 嘅 stat_total / ability_count / tier)。#29 **唔**自己揾 loot / 判 PR —— 只係 read 已存在嘅 receipt payload。 | P5 narrative + Soft dep |
| **CR-M11** | **Bootstrap from canonical state(replay-safe)** — `_ready()` 用 `connect_for_initial_state`(ADR-0006 Contract 6)訂 `#26.avatar_evolution_milestone` + `#26.avatar_micro_evolution` + GSM `state_changed`。Boot 時 `PersistenceLayer.read("mirror_moment")` rebuild latch(`pending_evolution_ceremony` / `week_had_change` / `last_ceremony_unix`)。若 persisted `pending_evolution_ceremony == true` → boot 後第一次入 safe context flush(CR-M3)。Idempotent:重收同一 milestone(bootstrap re-derivation / signal replay)唔會開兩次 —— `pending` 係 boolean latch,重 set true 係 no-op;window 標記防重呈現。 | ADR-0006 Contract 6 |
| **CR-M12** | **Suspended / bfcache during ceremony** — 慶典呈現緊時 GSM 入 SUSPENDED(tab 切走 / bfcache)→ pause 慶典 overlay(暫停粒子 + 凍 share-card),**唔**清 window 標記(慶典未算 dismiss)。Resume:`delta ≤ BFCACHE_CONTINUE_THRESHOLD_MS`(30000,parity #26)→ 繼續慶典;`> 30s` / negative-delta → 收起慶典 overlay,**保留 window 標記**(當「呈現過」,唔重彈,避免 resume spam)。Pending latch 若未呈現過 → 跨 suspend 保住。 | ADR-0006 + #26 bfcache parity |
| **CR-M13** | **Persistence schema(`mirror_moment.*`)** — 經 PersistenceLayer(ADR-0003 IPersistence):`last_ceremony_unix:int`(0 = never)· `last_ceremony_tier:int` · `pending_evolution_ceremony:bool` · `pending_tier:int` · `pending_source_metrics:Dictionary` · `week_had_change:bool` · `ceremony_count:int`(lifetime,telemetry)· `last_shared_unix:int`(FT-2)· `schema_version:int = 1`。**零 evolution-tier 計算 state**(無 threshold / 無 historical-max —— 嗰啲係 #26.`avatar.evolution_tier_history.*`)。Field change → ADR-0003 900ms migration。 | ADR-0003 + CR-M14 |
| **CR-M14** | **Render-only-consumer ownership boundary(ADR-0010,CI-MM-1)** — `src/**/mirror_moment*.gd` 含**零** tier-derivation:無 `S_t`/`A_t`/`D_t`/`S_peak_t` threshold、無 `effective_tier = max(computed, historical)` pattern、無 `get_stat()` 直 derive tier、無 write `avatar.evolution_tier_history.*`。Tier 只可以由 `#26.get_evolution_snapshot().tier` / milestone signal payload 讀入。任何違反 = CI-MM-1 fail。反向亦然:`avatar_renderer.gd` 含零 `mirror_moment` reference(#26 端 CI,#26 CR-17 已涵蓋)。 | ADR-0010 + P1 |
| **CR-M15** | **Honest no-change skip(Pillar 1)** — `week_had_change == false` 且無 pending → **唔呈現任何慶典**(CR-M2 case c)。#29 **永不**製造一個冇真實 data backing 嘅「你變強咗」。本週零訓練 → 鏡入面冇新嘢 → 唔停頓(可選 `NO_CHANGE_NUDGE_ENABLED`,default **false** for MVP —— 連 nudge 都唔出,避免「未練就 nag」嘅 Pillar-2 摩擦)。`week_had_change` 由 `avatar_micro_evolution`(代表本週有真實 stat delta,#26 Formula 3b 已 gate `rolling_7day_stat_delta > 0`)或 milestone 置 true。 | P1 + P2 |

### CI Lint Suite

| Script | Path | Target |
|--------|------|--------|
| **CI-MM-1** | `tools/ci/check_mirror_moment_no_tier_compute.gd` | `src/**/mirror_moment*.gd` 零 tier-derivation literal / pattern(CR-M14);tier 只經 snapshot/signal 讀入 |
| **CI-MM-2** | `tools/ci/check_mirror_moment_no_particle_instantiation.gd` | #29 source 零直接 `GPUParticles2D` instantiate;粒子只經 `#5.play()`(CR-M8 + technical-preferences) |
| **CI-MM-3** | `tools/ci/check_mirror_moment_cadence_data_driven.gd` | `MIRROR_CADENCE_SECONDS` 等 cadence 常數 load from `mirror_moment_config.tres`,零 hardcoded literal in `.gd`(CR-M1);+ parity assert `== #26.MILESTONE_CADENCE_SECONDS` |
| **CI-MM-4** | `tools/ci/check_mirror_moment_persistence_namespace.gd` | #29 persistence write 只落 `mirror_moment.*` namespace,零 write `avatar.*`(CR-M13 + CR-M14 ownership) |

### States and Transitions

#29 internal orchestration FSM = 4 states(DORMANT / ARMED / PRESENTING / PAUSED)+ Booting bootstrap phase。慶典 overlay 係 PRESENTING 嘅 UI surface,唔係獨立 game state(#29 唔改 GSM)。

| State | Entry | Allowed actions | Exit |
|-------|-------|-----------------|------|
| **Booting** | `_ready()`,`connect_for_initial_state` 完成前 | connect 3 subscriptions + read `mirror_moment.*` rebuild latch + receive INITIAL_STATE sentinel | rebuild 完 → **DORMANT**(若 persisted pending + safe context 則直接評估去 ARMED) |
| **DORMANT** | default;呈現過後 / window 未開 / 本週無變化 | listen `#26.avatar_evolution_milestone`(→ latch CR-M4)· `#26.avatar_micro_evolution`(→ `week_had_change=true`)· GSM `state_changed`(→ 每次評估 Formula 1) | Formula 1 `should_arm == true`(cadence window 開 ∧ has_change ∧ 本 window 未呈現)→ **ARMED** |
| **ARMED** | cadence window 開 + (pending_evolution ∨ week_had_change) + 本 window 未呈現 | 繼續 latch 新 signal(CR-M4/M5 collapse);等 safe context | GSM `get_current_state() == IDLE` ∧ CR-M3 gate pass(含 #33 soft)→ **PRESENTING**;cadence window 跨過(極罕,見 EC-MM-7)→ 重評估 |
| **PRESENTING** | ARMED + safe context | call `get_evolution_snapshot()`(CR-M6 fresh)· Formula 2 選 EVOLUTION/REFLECTION · 砌 share-card · EVOLUTION 播 `#5.play()` burst · 顯示 screenshot prompt(CR-M7)· 接受 screenshot / dismiss | dismiss / auto-dismiss / screenshot-confirmed → set window markers + 清 latch(CR-M9)→ **DORMANT**;GSM SUSPENDED → **PAUSED** |
| **PAUSED** | PRESENTING + GSM SUSPENDED | 凍 overlay + 暫停粒子;唔清 window 標記 | resume `≤30s`(`BFCACHE_CONTINUE_THRESHOLD_MS`)→ **PRESENTING**;`>30s` / negative-delta → 收 overlay + 標記「呈現過」(保 window marker,防 resume spam)→ **DORMANT** |

```
        _ready() → [Booting] → (read latch + INITIAL_STATE) → [DORMANT]
                                                                  │  Formula 1 should_arm
                                                                  ▼
        [DORMANT] ◄──────────────── (dismiss / screenshot / >30s resume) ──────── [ARMED]
            ▲                                                                        │  GSM == IDLE
            │                                                                        │  ∧ CR-M3 gate
            │                                                                        ▼
            └────────────── (window markers set, latch cleared) ◄────────────── [PRESENTING] ⇄ [PAUSED]
                                                                          (GSM SUSPENDED / resume ≤30s)
```

> **#29 唔擁有任何 GSM transition** —— 慶典純粹係 IDLE 之上嘅 UI overlay。玩家 dismiss 後返 IDLE,game 繼續。Pillar 2:慶典只喺玩家**已經唔喺 set 中**先彈,而且 dismiss 零成本。

### Interactions with Other Systems

| System | Direction | Data flow | Hard/Soft | Interface owner |
|--------|-----------|-----------|-----------|-----------------|
| **#26 AvatarRenderer** | #29 ← #26 | `avatar_evolution_milestone(tier, source_metrics)` → latch(CR-M4)· `avatar_micro_evolution(delta_kind, source_metrics)` → `week_had_change`(CR-M2b)· `get_evolution_snapshot() -> AvatarEvolutionSnapshot` → 砌 portrait(CR-M6)| **HARD** | #26 owns signals + snapshot API(ADR-0010);#29 read-only |
| **#1 GSM** | #29 ← #1 | `state_changed(from, to, payload)` + `get_current_state() -> GameState` → CR-M3 safe-context gate + Formula 1 評估 + SUSPENDED handling(CR-M12)| **HARD** | #1 owns state;#29 唔改 GSM(慶典係 overlay) |
| **#3 PersistenceLayer** | #29 ↔ #3 | read/write `mirror_moment.*`(CR-M13 latch + window markers + FT-2 counters)| **HARD** | #3 owns IPersistence(ADR-0003) |
| **#5 ParticleSystemWrapper** | #29 → #5 | `play(preset_id, position, multiplier)` celebration burst(EVOLUTION only,CR-M8);**LOOT preset → LARGE tier → CelebrationVFXLayer 110 residence**(B-1)| **HARD**(慶典視覺)| #5 owns 粒子(技術前提:#29 唔自 instantiate;celebration-residence handshake `register_celebration_layer` 須 live)|
| **#9 Workout-State Tracker** | #29 ← #9 | 本週 / 累積訓練次數 + 週數 → caption optional enrich(「第 N 週 · 練咗 M 次」,R-1,null-safe)| **SOFT** | #9 owns workout surface;#29 read-only,缺則 caption 退化為純 tier/class(AC-06)|
| **#17 Equipment & Inventory** | #29 ← #17 | 本週 LEGENDARY drop 嘅 `SourceReceipt.signature_text` → narrative caption 一行(CR-M10a,null-safe)| **SOFT** | #17 owns `SourceReceipt`(registry,「供 #29 ceremony narrative」);#29 read-only,缺則略 |
| **#18 PR Detection** | #29 ← #18 | 本週 PR breakthrough context(`pr_snapshot` via #17 receipt 或 #18 telemetry surface)→ narrative caption 一行(CR-M10b,null-safe)| **SOFT** | #18 owns PR facts;#29 read-only,缺則略 |
| **#33 Attention Budget** | #29 ← #33 | `is_input_permitted()` → CR-M3 額外 gate(non-workout context 確認)| **SOFT** | #33 owns policy;唔在席則只用 GSM gate |
| **#28 Telemetry** | #29 → #28 | `mirror.share_prompted` / `mirror.shared` / `mirror.share_skipped`(FT-2)· `mirror.ceremony_presented` · `mirror.no_change_skip`(CR-M15)| Soft | #28 owns sink;#29 emit-only |

**接線方向註記(CR-M4 latch)**:#29 訂 #26 嘅 signal。#26 早 boot(Presentation tier,#29 係 Polish tier 更後 boot per ADR-0008),所以 #29 `_ready()` 時 #26 已 ready —— 用 `connect_for_initial_state`(ADR-0006 Contract 6)接住 boot 時已發生嘅 milestone(replay-safe,CR-M11)。**冇 back-edge**:#26 唔訂 #29 任何嘢(ADR-0010 單向)。

**Soft-dep 缺席行為(binding)**:#17 / #18 / #33 任何一個 Not Started / 未 wire → 慶典**照常呈現**,只係少咗對應 narrative 行 / 多一層 gate 安全網。#29 嘅核心(cadence + non-workout gate + reveal + screenshot)只依賴 #26 + #1 + #3 + #5(全部 shipped)。呢個保證 #29 MVP 可以喺 #17/#18/#33 任何成熟度下落地。

## Formulas

> #29 係 ceremony orchestrator —— 佢 **re-derive 零 upstream value**。Evolution tier 由 #26 owns(Formula 2),loot rarity 由 ADR-0005 owns,PR 由 #18 owns。#29 三條 formula 全部係 **gating / selection logic**,唔涉 balance 數值。所有 tier 數字由 `get_evolution_snapshot()` 讀入(CR-M14)。

### Formula 1 — `ceremony_arm_check`(cadence + change + once-per-window gate)

決定 DORMANT → ARMED 轉換。

```
should_arm = cadence_open and has_change and not presented_this_window

cadence_open        = (now_unix - last_ceremony_unix) >= MIRROR_CADENCE_SECONDS
has_change          = pending_evolution_ceremony or week_had_change
presented_this_window = (now_unix - last_ceremony_unix) < MIRROR_CADENCE_SECONDS
                        # 即 cadence_open 嘅否定 — 同一變數,單一真相源
```

| Symbol | Type | Range | Source |
|--------|------|-------|--------|
| `now_unix` | int | wall-clock unix sec(server-time-sanity-checked,CR-M1)| `TimeProvider.now_unix()` |
| `last_ceremony_unix` | int | 0(never)or unix sec | `mirror_moment.*`(CR-M13)|
| `MIRROR_CADENCE_SECONDS` | int | 604800(7日,parity #26)| Tuning Knobs |
| `pending_evolution_ceremony` | bool | — | latch(CR-M4)|
| `week_had_change` | bool | — | `avatar_micro_evolution` / milestone(CR-M2)|
| `should_arm` | bool | — | output |

**Output Range**: bool。`cadence_open` 同 `presented_this_window` 係同一比較嘅互補(寫成兩條只為可讀,實作共用一個 `cadence_open` 變數,`presented_this_window = not cadence_open`)。**Epoch-zero 註記**:fresh account `last_ceremony_unix == 0` → `cadence_open` 恆 true,但 `has_change` 要求收過 #26 signal —— 而 #26 自己 gate 咗 first-boot(epoch-zero guard + 48h grace,#26 Formula 3),所以 #29 唔會喺零訓練嘅新帳號彈慶典(繼承 #26 嘅 gate,唔重複)。

**Example**: `now=1_000_000`,`last_ceremony=300_000`(Δ=700_000 > 604_800 ✓ cadence_open),`pending=true` → `should_arm = true ∧ true ∧ true = **true**` → ARMED。

| now-last (Δs) | pending | week_had_change | should_arm | 原因 |
|---|---|---|---|---|
| 700000 | true | false | **true** | cadence 開 + 有 tier-up |
| 700000 | false | true | **true** | cadence 開 + micro-only 變化 |
| 700000 | false | false | false | 本週零變化(CR-M15 skip) |
| 300000 | true | true | false | cadence 未到(本 window 已呈現過) |

### Formula 2 — `content_tier_selection`(EVOLUTION / REFLECTION / NONE)

ARMED → PRESENTING 時(已過 safe-context gate)選慶典類型。

```
content = (pending_evolution_ceremony) ? EVOLUTION
        : (week_had_change)            ? REFLECTION
        :                                NONE
```

| Symbol | Type | Range | Source |
|--------|------|-------|--------|
| `pending_evolution_ceremony` | bool | — | latch(CR-M4),呈現後清 |
| `week_had_change` | bool | — | micro-evolution marker |
| `content` | enum | {EVOLUTION, REFLECTION, NONE} | output |

**Output Range**: exactly one of {EVOLUTION, REFLECTION, NONE}。優先序 EVOLUTION > REFLECTION:同週**既有 tier-up 又有 micro-evolution** → 行大慶典 EVOLUTION(tier-up 蓋過 micro)。NONE 喺 ARMED 階段理論上唔可達(Formula 1 `has_change` gate 已擋),但作 defense-in-depth 保留(若 race condition 令 flag 喺 arm 同 present 之間被清 → 收 overlay,當 CR-M15 skip)。

| pending | week_had_change | content | 慶典 |
|---|---|---|---|
| true | true | **EVOLUTION** | tier-up 蓋過 micro,行大慶典 |
| true | false | **EVOLUTION** | 純 tier-up(server backfill 罕見)|
| false | true | **REFLECTION** | 純 micro-evolution 週,輕慶典 |
| false | false | NONE | defense-in-depth(理論不可達)|

### Formula 3 — `before_after_resolution`(reveal 構圖 source,collapse-aware)

PRESENTING 時砌 reveal 用邊兩個 sprite。**全部由 `get_evolution_snapshot()` 讀入,#29 零計算**(CR-M6 fresh snapshot)。

```
snap = #26.get_evolution_snapshot()                  # fresh at present-time
after_tier   = snap.tier
after_sprite = snap.sprite_frames_resource_path
hero_frame   = snap.hero_pose_frame
prior_tier   = snap.prior_tier                        # last-ceremonied (collapse handled by #26)
prior_sprite = snap.prior_sprite_frames_resource_path

show_ghost = (content == EVOLUTION) and (prior_tier < after_tier) and (prior_sprite != "")
             # REFLECTION → 無 before/after(同 tier);first-ever tier-up 無 prior_sprite → 無 ghost
```

| Symbol | Type | Range | Source |
|--------|------|-------|--------|
| `after_tier` / `prior_tier` | int | 0..3 | `snap.tier` / `snap.prior_tier`(#26) |
| `after_sprite` / `prior_sprite` | String | res:// path or `""` | snapshot(#26)|
| `hero_frame` | int | 0..frame_count-1 | `snap.hero_pose_frame`(#26)|
| `show_ghost` | bool | — | output |

**Output**: 構圖指令。`show_ghost == true` → 砌「上週 ghost(prior_sprite @ 30% opacity)+ 當前(after_sprite)」before→after(CR-M5 collapse 已由 #26 snapshot 保證 prior = last-ceremonied,中間 tier 唔逐格)。`show_ghost == false`(REFLECTION 同 tier / first-ever 無 prior)→ 單 frame hero pose,無 ghost(caption 改「首次進化」或「本週回顧」)。

| content | prior_tier | after_tier | prior_sprite | show_ghost | 構圖 |
|---|---|---|---|---|---|
| EVOLUTION | 1 | 2 | (有) | **true** | T1 ghost → T2 當前 |
| EVOLUTION | 0 | 3 | (有,T0) | **true** | T0 ghost → T3 當前(collapse,跳中間)|
| EVOLUTION | 0 | 1 | `""`(首次)| false | 單 frame +「首次進化」|
| REFLECTION | 2 | 2 | (有 T2) | false | 單 frame +「本週回顧」(micro shader 已上身)|

## Edge Cases

#### Cadence + Latch

- **EC-MM-1 — 同週多個 tier-up**:若一個 cadence window 內收到多個 `avatar_evolution_milestone`(T1→T2→T3 同週,老用戶 backfill)→ **唔開 N 次慶典**;latch 保持單一 `pending`,呈現時 `get_evolution_snapshot()` 嘅 `prior_tier`(last-ceremonied)→ `tier`(current)一個 before→after collapse(CR-M5 / Formula 3),caption 顯示 net 跳(「T0 → T3」)。
- **EC-MM-2 — tier-up 喺 set 中發生**:#26 已 defer `avatar_evolution_milestone` emit while GSM ∈ {WORKOUT_ACTIVE, REST_PERIOD}(#26 CR-15),所以 #29 **唔會喺 set 中收到** trigger。即使收到(防禦)→ latch only,CR-M3 present gate 仍擋住呈現,等出 set 入 IDLE 先彈。
- **EC-MM-3 — 玩家永不喺 non-workout context 開 game**:玩家每次練完即 quit(從未入 IDLE)→ `pending` 跨 session 持久(CR-M4 persist)→ 下次任何 safe-context open flush。**永不失落 tier-up**。
- **EC-MM-4 — pending 跨多週未呈現**:玩家離開 3 週後先開 game,期間 server backfill 升咗幾 tier → 開 game 時 **呈現一次**(collapse,EC-MM-1 同理),`last_ceremony_unix` set 為 now → 下個 window 重新計。**唔 queue 3 個積壓慶典**(避免 ceremony spam,Pillar 2)。
- **EC-MM-5 — cadence window 邊界喺 ARMED 期間跨過**:ARMED 等緊 safe context 時 `now` 超過下個 window 邊界(極罕,要 ARMED 等足 7日)→ 不影響:has_change 仍 true,present gate 一過即呈現,呈現後 `last_ceremony_unix = now` 重設 window。唔會「因為超時而取消」(已 armed 嘅變化唔可以蒸發,anti-pillar)。
- **EC-MM-6 — clock skew / 離線 server-time sanity fail**:`TimeProvider` 偏差超 `CLOCK_SANITY_TOLERANCE_SEC`(經 #2 server-time,parity #17 Rule 4)→ **寧可唔 arm**(grace),下次 boot server sync 後再試。誤判後果 = 「遲一次慶典」唔係「假慶典」,風險已降級。

#### Composition + Snapshot

- **EC-MM-7 — 首次 tier-up,無 prior sprite**:`get_evolution_snapshot().prior_sprite_frames_resource_path == ""`(T0→T1,從未慶典過)→ `show_ghost = false`,單 frame hero pose + caption「**首次進化**」(無 before/after ghost)。
- **EC-MM-8 — snapshot sprite path 失效 / load 失敗**:`after_sprite` load 返 null(asset 缺 / .tres misconfig)→ #26 嘅 `_derive_sprite_frames` 已有 `EMERGENCY_AVATAR.tres` fallback(#26 EC-ASSET-1),#29 直接用 snapshot 俾嘅 path 唔自己 re-resolve;若連 fallback 都空 → 收慶典 + emit `mirror.snapshot_invalid` CRITICAL telemetry,標記 window「呈現過」(唔卡死喺 ARMED 重試 loop)。
- **EC-MM-9 — REFLECTION 但 snapshot tier 同 prior 一樣**:`content == REFLECTION` ∧ `prior_tier == after_tier`(預期)→ 無 ghost,單 frame +「本週回顧」(micro-evolution shader 已上身於 avatar,#26 CR-5b,玩家見到嘅就係已 shift 嘅 hue/outline)。
- **EC-MM-10 — `pending_source_metrics` 持久 dict 損壞**:boot read 返 malformed dict → **null-safe drop**,改用呈現時 fresh snapshot render(CR-M6),narrative「成因」行略過(唔 block 慶典)。
- **EC-MM-11 — #26 snapshot 喺 boot 未 ready 返 null**:`connect_for_initial_state` 保證 #26 早於 #29 boot(ADR-0008),但防禦:`get_evolution_snapshot()` 返 null → 慶典留 ARMED,下個 frame / 下次 GSM tick 重試(唔 crash)。

#### Presentation + Lifecycle

- **EC-MM-12 — 玩家 dismiss 但唔截圖**:set window markers(`last_ceremony_unix` / 清 latch),emit `mirror.share_skipped`,**唔重彈**呢個 window(CR-M9,Pillar 2 唔 nag)。FT-2 telemetry 記低 skip。
- **EC-MM-13 — 截圖後即 dismiss**:emit `mirror.shared` + `last_shared_unix = now`,window done,返 DORMANT。
- **EC-MM-14 — transient IDLE flicker(IDLE 一閃即入 COMBAT)**:玩家啱啱開 game,GSM IDLE→COMBAT 快速跳(下一個 workout 即開)→ 加 `CEREMONY_PRESENT_DELAY_FRAMES`(default 6 frame ≈ 0.1s)stable-IDLE 確認先呈現;delay 內離開 IDLE → 留 ARMED,等下次 stable IDLE。避免慶典閃一下就被 combat 蓋。
- **EC-MM-15 — bfcache / SUSPENDED 喺慶典中**:CR-M12 —— pause overlay,resume ≤30s 繼續,>30s / negative-delta 收 overlay + 保 window marker(當呈現過,防 resume spam)。Pending 若未呈現過則跨 suspend 保住。
- **EC-MM-16 — LOOT_DROP modal(#21)佔住畫面時 window 開**:CR-M3 gate 排除 LOOT_DROP → 慶典留 ARMED,等 #21 modal 收 + GSM 返 IDLE 先彈(唔疊兩個 modal,Pillar 3 ritual 唔互搶)。
- **EC-MM-17 — crash 喺慶典呈現中途**:`pending` / `week_had_change` / `last_ceremony_unix` 全部 persist;若 crash 喺 set marker **之前** → 重 boot re-arm 重呈現(idempotent,玩家最多多睇一次,可接受);crash 喺 set marker **之後** → window 已標記,唔重呈現。

#### Anti-Fabrication + Soft Dep

- **EC-MM-18 — 本週零訓練**:`week_had_change == false` ∧ 無 pending → Formula 1 `has_change == false` → 唔 arm → **無慶典**(CR-M15 honest skip)。`NO_CHANGE_NUDGE_ENABLED` default false → 連 nudge 都唔出。emit `mirror.no_change_skip` telemetry。
- **EC-MM-19 — #17 / #18 Soft dep 缺席或本週無 receipt/PR**:`SourceReceipt` null / 無 LEGENDARY drop / 無 PR / 系統 Not Started → narrative 對應行**唔出**,慶典只用 #26 snapshot(stat_total / ability_count / tier / posture)照常呈現(CR-M10 null-safe)。
- **EC-MM-20 — 同週多次 micro-evolution signal**:`avatar_micro_evolution` 收多次 → `week_had_change` 係 boolean,重 set true = no-op(idempotent),唔影響慶典(CR-M2)。

## Dependencies

### Upstream(#29 依賴)

| System | Hard/Soft | 用途 | Interface | Bidirectional check |
|--------|-----------|------|-----------|---------------------|
| **#26 AvatarRenderer** | **HARD** | ceremony trigger(2 signals)+ render-state snapshot(ADR-0010 seam)| `avatar_evolution_milestone` · `avatar_micro_evolution` · `get_evolution_snapshot()` | ✅ #26 v2.1 "Depended On By" 列 **#29 Mirror Moment System (Not Started — owns ceremony, consumes `avatar_evolution_milestone` + `get_evolution_snapshot()`)** |
| **#1 GSM** | **HARD** | safe-context gate + SUSPENDED handling | `state_changed` · `get_current_state()` | #29 係 read-only consumer(同 #26/#22 一樣訂 state_changed);#1 唔需列每個 consumer |
| **#3 PersistenceLayer** | **HARD** | `mirror_moment.*` latch + window markers | IPersistence(ADR-0003)| #29 新增 `mirror_moment.*` namespace(同 #8 `streak.*` / #17 `inventory.*` 並列);#3 namespace-agnostic |
| **#5 ParticleSystemWrapper** | **HARD** | celebration burst(EVOLUTION)| `play(preset_id, position, multiplier)` | #5 係 fire-and-forget owner;#29 係 caller(同 #6/#15/#21/#26 一樣);#5 唔列 caller |
| **#9 Workout-State Tracker** | **SOFT** | caption optional enrich:週數 + 訓練次數(「第 N 週 · 練咗 M 次」)| read #9 workout surface | #29 read-only consumer;缺則 caption 退化純 tier/class(R-1,AC-06 null-safe);marquee caption 例(Overview/Fantasy)係 **enriched form**,base form 無 N/M |
| **#17 Equipment & Inventory** | **SOFT** | `SourceReceipt.signature_text` narrative 行 | read `SourceReceipt`(registry)| ✅ #17 Rule 10:「供 **#29 Mirror Moment ceremony narrative payload** + #22 hover」 |
| **#18 PR Detection** | **SOFT** | 本週 PR context narrative 行 | read PR snapshot(via #17 receipt / #18 surface)| ✅ #18 Overview:「Pillar 5 — supporting:PR 係 evolution 鏈嘅最強驅動」;cadence 表「每週 = #8 streak + #26 Mirror Moment」 |
| **#33 Attention Budget** | **SOFT** | non-workout gate 額外確認 | `is_input_permitted()` | #33 policy-provider;#29 optional consumer,缺則只用 GSM gate |
| **#28 Telemetry** | Soft | FT-2 share-rate + ceremony events | emit-only | #28 sink-agnostic |

### Downstream(依賴 #29)

**冇。** #29 係 terminal Polish system —— 冇任何系統 read #29 嘅 output。慶典係 player-facing 終點,唔餵任何下游 data layer。呢個 confirm 咗 ADR-0010 嘅單向性:#29 → #26 single edge,#29 自己冇 out-edge。

### Hard vs Soft 總結

- **Hard(4)**:#26 / #1 / #3 / #5 —— 全部 **shipped + approved**。#29 MVP 核心(cadence + gate + reveal + screenshot + celebration)只需呢四個,**全部已落地** → #29 可即時開 epic 無上游 block。
- **Soft(5)**:#9 / #17 / #18 / #33 / #28 —— caption enrich(週數/次數)+ narrative 行 + gate 安全網 + telemetry。任何一個缺席,慶典 degrade gracefully(caption 退化純 tier/class / 少一行 narrative / 少一層 gate),核心不變。

### 依賴方向圖

```
#11 Stat ┐                         (read-only snapshot + 2 trigger signals)
         ├→ #26 AvatarRenderer ──────────────────────────────► #29 Mirror Moment
#12 Ability ┘  (owns tier + sprite)                            (owns ceremony)
                                                                  │ │ │ │
                          ┌───────────────────────────────────────┘ │ │ └──→ #5 Particle (celebration burst)
                   #1 GSM (safe-context gate) ◄──────────────────────┘ │
                   #3 Persistence (mirror_moment.*) ◄──────────────────┘
                          ▲ soft narrative
                   #17 SourceReceipt ·· #18 PR context ·· #33 gate (all null-safe)

         (NO back-edge: #26 知 #29 不存在 — ADR-0010 單向)
         (NO down-edge: #29 係 terminal,冇下游)
```

## Tuning Knobs

全部 load from `assets/data/mirror_moment_config.tres`(CI-MM-3:零 hardcoded literal in `.gd`)。

| Knob | Default | Safe Range | 影響 | 太高 | 太低 |
|------|---------|-----------|------|------|------|
| `MIRROR_CADENCE_SECONDS` | 604800(7日)| **DESIGN-FROZEN == #26 `MILESTONE_CADENCE_SECONDS`**(CI-MM-3 parity assert)| 慶典週期 | 慶典太疏 → Pillar 5 weekly 承諾失效 | 慶典太密 → 通知疲勞 + 截圖貶值 |
| `WEEKLY_REFLECTION_ENABLED` | true | {true, false} | 開唔開 REFLECTION 輕慶典(micro-only 週)| (true)守住 weekly cadence | false → 只剩 tier-up 大慶典 → 多週無慶典,違 Pillar 5 weekly。**建議保持 true** |
| `CEREMONY_PRESENT_DELAY_FRAMES` | 6(≈0.1s)| [0, 30] | stable-IDLE 確認延遲(EC-MM-14)| > 30 → 玩家覺得「卡咗先彈」 | 0 → transient IDLE flicker 中閃慶典 |
| `CELEBRATION_PARTICLE_MULTIPLIER` | 1.0 | [0.5, 2.0] | EVOLUTION burst 強度(經 #5)| > 2.0 撞 ADR-0001 particle budget(200 active)| < 0.5 慶祝感不足。Mobile 0.5× 由 #5 內部疊乘,#29 唔重複降 |
| `CEREMONY_AUTO_DISMISS_SECONDS` | 0(manual-only)| [0, 30] | 自動收慶典秒數 | > 30 玩家未睇完就 stuck overlay | 0–5 之間:< 截圖時間 → 玩家未影到相就消失。**0 = 永遠等玩家撳**(MVP 建議)|
| `NO_CHANGE_NUDGE_ENABLED` | **false** | {true, false} | 零訓練週出唔出「未練」nudge | true → 「未練就 nag」Pillar 2 摩擦。MVP **必 false** | (false)誠實沉默 |
| `BFCACHE_CONTINUE_THRESHOLD_MS` | 30000 | **== #26 `BFCACHE_CONTINUE_THRESHOLD_MS`**(parity)| 慶典中 suspend resume 續演上限(CR-M12)| > 30s resume 後突然彈舊慶典 spammy | < 30s 短暫切 tab 都重起慶典 |
| `SHARE_CARD_ASPECT` | `"viewport"`(MVP)| {`"viewport"`, `"9:16"`, `"1:1"`} | share-card framing | — | MVP `"viewport"` = 全屏乾淨截圖;`"9:16"` layered portrait 推 **v0.2** |
| `CELEBRATION_BURST_PRESET` | `PresetId.LOOT_*`(引用 #5 enum,epic 時 pin)| #5 `PresetId` 成員 | EVOLUTION burst 用邊個 #5 preset | — | 須係 #5 已定義 preset(#5 9-preset closed set;若加新 avatar-evolution preset → #5 GDD revision,R-5 同款 coupling)|

### 引用(非 #29 own)

| Knob | Owner | #29 用途 |
|------|-------|---------|
| `MILESTONE_CADENCE_SECONDS` = 604800 | **#26** | parity 源 — `MIRROR_CADENCE_SECONDS` 必須等於佢 |
| `CLOCK_SANITY_TOLERANCE_SEC` | #17 Rule 4 pattern / #2 server-time | wall-clock sanity(CR-M1 / EC-MM-6),follow 同款 tolerance |
| `PresetId.*` particle presets | **#5** | `CELEBRATION_BURST_PRESET` 必選 #5 closed-set 成員 |

> **Cross-knob INV**:`MIRROR_CADENCE_SECONDS == #26.MILESTONE_CADENCE_SECONDS`(CI-MM-3 硬 assert)。理由:#26 milestone 嘅 cadence gate(Formula 3,7日)同 #29 慶典 cadence 必須同步 —— 若 #29 cadence < #26,#29 會 arm 但無新 milestone(空轉 REFLECTION);若 #29 cadence > #26,#26 emit 嘅 milestone 會 latch 等過耐先呈現(tier-up 滯後)。兩者鎖死同值最 coherent。

## Visual/Audio Requirements

> Art-direction 全部 trace 返 game-concept Visual Identity Anchor(Direction A:Maple Pixel + Particle Storm)。**ADR-0010 鐵律**:silhouette(#26)載 identity,#29 粒子只載 celebration —— 任何 #29 視覺**唔可以**改變 avatar 嘅可辨識度,只可以喺佢周圍加慶祝層。

### Visual — Evolution Ceremony(EVOLUTION,大慶典)

1. **「身體版爆裝」framing**:呢個 moment 借用 Pillar 3 嘅 loot-drop 視覺語言 —— 純白 burst → 彩色 trail(game-concept Color Philosophy)—— 但**對象係玩家自己嘅 avatar**,唔係掉落物。情感目標:「呢件 LEGENDARY 就係我自己」。
2. **Before→after 構圖(MVP minimal)**:當前 avatar 喺 hero pose(`snap.hero_pose_frame`,still frame)置中、全飽和;上週 ghost(`prior_sprite`)@ **30% opacity**(對齊 Layer Discipline 嘅 world-desaturate 對比邏輯)offset 喺側 / 後,做「你由呢度行到呢度」嘅 silent 對比。Ghost **唔郁**(MVP 無動畫;v0.2 先加 morph)。
3. **Celebration burst(經 #5)**:tier-up 一刻,avatar 背後一下 `#5.play(CELEBRATION_BURST_PRESET, avatar_center, CELEBRATION_PARTICLE_MULTIPLIER)`。**粒子坐 CelebrationVFXLayer 110**(modal-class VFX layer,**唔係** world ParticleLayer z≥20)—— 因為慶典係 >100 modal overlay,z=20 嘅 world burst 會 render 喺 modal backdrop(110+)**之下**被遮。grep-verified #5 機制:**只有 LOOT preset**(`LOOT_BURST`/`LOOT_RARE_BURST`)→ LARGE tier(`_select_tier`)→ 經 `register_celebration_layer` handshake reparent 上 `_celebration_layer`(= CelebrationVFXLayer 110,#21-owned persistent shared infra,`_apply_celebration_residence`);所以 `CELEBRATION_BURST_PRESET` **必須**係 LOOT preset 先上到 110(見 B-1 / Q-OQ-PRESET HARD 約束)。**唔遮 silhouette**(burst 由中心向外、密度向邊緣遞減,中心留空俾 avatar)。Mobile 0.5× density 由 #5 自動(ADR-0001),silhouette 不受影響(CR-M8 / CR-M14 of #26)。
4. **Tier badge + caption**:高飽和 amber-gold(HUD palette)tier badge(「T2」)+ 一行 caption(中文,「第 6 週 · STRIKE · 進化到 T2」);若有 #17 signature loot / #18 PR → 多一兩行 narrative(CR-M10),字級細過主 caption。
5. **Layer Discipline**:慶典期間 world layer 維持 desaturate 30%(甚至加深至 dim,聚焦 avatar);share-card 內容全飽和。確保「眼球先落 avatar + tier badge」(對齊 Art Bible Design test:loot vs background 明度對比)。

### Visual — Weekly Reflection(REFLECTION,輕慶典)

- 無 before/after ghost、**無 celebration burst**(micro-evolution 唔放大,CR-M8)。
- 當前 avatar hero pose + micro-evolution shader(已上身於 avatar,#26 CR-5b:hue shift / outline brightness / breathing —— #29 唔重畫,只係 frame 住佢)。
- Caption「本週回顧 · 你練咗 N 次」(N 由 snapshot source_metrics / #9 surface;缺則只「本週回顧」)。輕量、靜,但仍可截圖(守 Pillar 5 weekly + FT-2)。

### Audio Direction(經 #4 Audio Manager,Soft)

- **EVOLUTION**:一下 **ascending evolution fanfare** SFX(借 loot LEGENDARY fanfare 家族,但獨立 cue —— 「自己進化」≠「掉落物」)。經 #4 `play_sfx` / BGM duck(慶典期間 background BGM 輕 duck,聚焦 fanfare)。#4 唔在席 → 靜默 degrade,慶典照彈。
- **REFLECTION**:極輕 chime 或無聲(唔搶,輕慶典)。
- **無 audio = 唔 block 慶典**:audio 純 enhancement(同 #4 EG-2 consumer 模式一致 — presentation 層 trigger SFX,唔 patch 上游)。

> **📌 Asset Spec** — Visual/Audio requirements 已定義。Art bible approved 後,run `/asset-spec system:mirror-moment` 產出 per-asset 視覺描述(celebration burst preset 參數 / tier badge 樣式 / share-card frame chrome / fanfare SFX spec)。

> **Particle ownership + layer-residence 註記(B-1 HARD 約束,非單純 coupling flag)**:慶典 burst 要 render 喺 CelebrationVFXLayer 110(modal 之上)先睇得到。grep-verified #5:**只有** LOOT preset(`LOOT_BURST`/`LOOT_RARE_BURST`)→ LARGE tier → reparent 上 `_celebration_layer`(`_select_tier:599` + `_apply_celebration_residence:359`);其餘 preset 留 world layer(z≤7)→ 喺 backdrop 之下被遮。**所以 `CELEBRATION_BURST_PRESET` 必須係 LOOT preset** —— MVP **鎖定復用現有 loot-celebration preset**(唯一上到 110 而免 #5 amendment 嘅路)。若硬要**新** avatar-evolution preset → #5 amendment 要做**兩件事**:(a) closed-set-of-9 → N(#5 GDD revision + PRESET_TABLE + material .tres + 2 硬 `size==9` test 同步,#26 R-5 同款)**加**(b) 新 preset 納入 LARGE-tier + celebration-residence carve-out(`_select_tier` / `_is_loot`-class 路徑),否則 burst 上唔到 110。epic 時由 art-director + #5 owner 拍板(Q-OQ-PRESET);MVP 預設 = 復用。

## UI Requirements

### Ceremony Overlay（PRESENTING state）

- **CanvasLayer topology（ADR-0001）**：慶典 overlay 坐 **CelebrationVFXLayer 110**（粒子 + avatar hero pose composite）+ **ModalLayer 120**（share-card chrome + screenshot 掣 + dismiss），對齊 #21 Loot Drop Modal 已確立嘅 >100 modal topology。慶典係 modal-class overlay：彈出時 backdrop opacity-only dim（**NO 2nd BackBufferCopy** — 沿 #24 ErrorBanner AC-36 慳 budget），game 唔 pause（GSM 仍 IDLE，慶典只係 overlay）。
- **Backdrop**：半透明 dim 罩（world layer 已 desaturate）；撳 backdrop = dismiss（CR-M9）。
- **Share-card region**：一個 bounded Control（`SHARE_CARD_ASPECT`，MVP = viewport），內含 avatar hero pose + ghost（EVOLUTION）+ tier badge + caption + narrative 行。**呢個 region 就係玩家會截圖嘅嘢** — 邊界要乾淨（截圖時周邊 chrome 暫隱，CR-M7）。

### Screenshot Prompt（MVP 唯一交付）

- **「截圖分享」掣**：share-card 下方，amber-gold 高飽和（call-to-action）。撳 →（MVP）暫隱所有非-card chrome（dismiss 掣、backdrop 文字）→ 顯示 1 行 hint「用裝置截圖功能影低呢個畫面 📸」→ emit `mirror.share_prompted`。3 秒後 / 玩家再撳 → chrome 復原 + 「影咗喇 ✓ / 跳過」二選。
- **In-app capture（v0.2）**：MVP **唔**做 in-app capture-to-PNG（web export `get_viewport().get_texture()` → file download 跨瀏覽器唔可靠）。v0.2 加「儲存圖片」一鍵（desktop download / mobile share-sheet）。MVP 信玩家用 OS 截圖。
- **Dismiss affordance**：右上「✕」+ 撳 backdrop + （optional）`CEREMONY_AUTO_DISMISS_SECONDS`。Dismiss 零摩擦（Pillar 2）。

### Interaction States

| Element | Default | Hover/Focus | Active | Disabled |
|---------|---------|-------------|--------|----------|
| 截圖分享 掣 | amber-gold fill | brighten + scale 1.05 | press depress | （無 disabled state — 永遠可撳）|
| ✕ dismiss | low-emphasis outline | brighten | press | — |
| share-card | static | —（唔互動，純展示）| — | — |

### Accessibility（沿 #24 / #19 a11y 模式）

- **Screen-reader**：慶典彈出 → `platform_detect.announce_aria("Mirror Moment：第 N 週進化到 T{tier}", polite)`（#24 Story 019 additive 2-arg announce + polite region，back-compat）。截圖掣 + dismiss 有 ARIA label。
- **Reduced-motion**：尊重 `motion_intensity` a11y slider（#6 owns）— celebration burst 降密度 / 關（slider=0 → 靜態 share-card，無粒子動畫）。慶典**內容**（avatar + caption + badge）唔受 reduced-motion 影響（資訊唔靠 motion 傳遞）。
- **Touch target**：截圖掣 + ✕ ≥ 44×44 px（web mobile/tablet，technical-preferences touch primary）。
- **One-tap**：dismiss / screenshot 全部單撳（無 hover-only、無 drag）。

### Non-Goals（UI 唔做）

- 唔做 in-app social share deep-link（Twitter/IG SDK）→ v0.2/T3。
- 唔做慶典歷史 gallery（睇返舊慶典）→ v0.2。
- 唔做手動「重睇本週慶典」入口 → MVP 一次過（dismiss 即 window done）。

> **📌 UX Flag — Mirror Moment**：呢個 system 有 UI requirements（ceremony overlay + screenshot prompt + share-card）。Phase 4（Pre-Production）run `/ux-design mirror-moment` 為慶典 overlay + screenshot flow 出 UX spec **之前** 寫 epic。Stories 引用 `design/ux/mirror-moment.md`，唔直接引 GDD。同 `/ux-design avatar-renderer`（#26 UX Flag）一齊做（coupled pair，共用 avatar hero-pose 視覺）。已記入 systems-index #29 row。

## Acceptance Criteria

> 格式 GIVEN-WHEN-THEN,每條 QA 可獨立驗證。Gate level:**BLOCKING**(logic / 必過)/ **ADVISORY**(visual-feel / playtest)。Story type 大部分 = Logic(cadence/gate/latch state machine,unit-testable via injected GSM + snapshot mock)+ UI(overlay,manual walkthrough)。

### Cadence + Gating

- **AC-01**(CR-M1 / Formula 1,BLOCKING)— **GIVEN** `last_ceremony_unix=300000` + `now=1000000`(Δ=700000 > 604800)+ `pending=true`,**WHEN** GSM 入 IDLE,**THEN** `should_arm==true` → ARMED → 呈現一次慶典。
- **AC-02**(CR-M1 / Formula 1,BLOCKING)— **GIVEN** 同一 cadence window 內已呈現過一次(`now-last < 604800`),**WHEN** 玩家再開 game 入 IDLE 兼 `pending`/`week_had_change` 仍 true,**THEN** **唔再呈現**(`should_arm==false`)。
- **AC-03**(CR-M3 / FT-M3,BLOCKING)— **GIVEN** cadence window 開 + has_change,**WHEN** GSM `get_current_state() ∈ {WORKOUT_ACTIVE, REST_PERIOD, COMBAT_ACTIVE, BOSS_ENCOUNTER, LOOT_DROP, SUSPENDED}`,**THEN** 慶典**唔呈現**,留 ARMED;**WHEN** GSM 轉 IDLE,**THEN** 先呈現。
- **AC-04**(CR-M3 #33 soft,ADVISORY)— **GIVEN** #33 在席且 `is_input_permitted()==false`,**WHEN** GSM==IDLE,**THEN** 慶典仍 hold(額外 gate);#33 不在席 → 只用 GSM gate 即呈現。

### Content Selection

- **AC-05**(CR-M2 / Formula 2,BLOCKING)— **GIVEN** `pending_evolution_ceremony==true`,**WHEN** present,**THEN** content==EVOLUTION(before→after + burst + screenshot)。
- **AC-06**(CR-M2 / Formula 2,BLOCKING)— **GIVEN** `pending==false` ∧ `week_had_change==true`,**WHEN** present,**THEN** content==REFLECTION(單 frame + 回顧 caption + screenshot,**無 burst**)。
- **AC-07**(CR-M2 / CR-M15,BLOCKING)— **GIVEN** `pending==false` ∧ `week_had_change==false`,**WHEN** cadence window 開 + IDLE,**THEN** **無慶典呈現**,emit `mirror.no_change_skip`。
- **AC-08**(Formula 2 優先序,BLOCKING)— **GIVEN** 同週既有 tier-up 又有 micro-evolution(pending==true ∧ week_had_change==true),**WHEN** present,**THEN** content==EVOLUTION(tier-up 蓋過 micro)。

### Latch + Collapse + Snapshot

- **AC-09**(CR-M4,BLOCKING)— **GIVEN** 收到 `avatar_evolution_milestone(2, m)`,**WHEN** 玩家從未入 non-workout context 兼 app 被 kill 重開,**THEN** boot read `mirror_moment.*` 後 `pending_evolution_ceremony==true` ∧ `pending_tier==2`,下次 IDLE flush 呈現(tier-up 永不失落)。
- **AC-10**(CR-M5 / Formula 3 / EC-MM-1,BLOCKING)— **GIVEN** 一 window 內收 `milestone(1)`→`milestone(2)`→`milestone(3)` + last-ceremonied tier=0,**WHEN** present,**THEN** **單一**慶典,`get_evolution_snapshot()` prior_tier=0 / tier=3 → 一個 T0→T3 before→after(**唔開 3 次**)。
- **AC-11**(CR-M6,BLOCKING)— **GIVEN** milestone latch 咗 3 日,期間 avatar 再 micro-evolve,**WHEN** present,**THEN** render 用 **present-time** `get_evolution_snapshot()`(fresh),唔用 latch 時嘅 payload 做 render source。
- **AC-12**(EC-MM-7 / Formula 3,BLOCKING)— **GIVEN** 首次 tier-up(`prior_sprite_frames_resource_path==""`),**WHEN** present EVOLUTION,**THEN** `show_ghost==false`,單 frame + caption「首次進化」(無 ghost,無 crash)。

### Screenshot + Celebration

- **AC-13**(CR-M7,BLOCKING/UI)— **GIVEN** 慶典呈現,**WHEN** 玩家撳「截圖分享」,**THEN** 非-card chrome 暫隱 + 顯示 native-screenshot hint + emit `mirror.share_prompted`;確認後 emit `mirror.shared` + `last_shared_unix=now`。
- **AC-14**(CR-M8,BLOCKING)— **GIVEN** content==EVOLUTION,**WHEN** present,**THEN** celebration 經 `#5.play(CELEBRATION_BURST_PRESET, …)`(唔自 instantiate `GPUParticles2D`);content==REFLECTION → **無** `#5.play` burst call。
- **AC-15**(CR-M8 / ADR-0001,ADVISORY/visual)— **GIVEN** mobile platform,**WHEN** EVOLUTION burst 播,**THEN** 粒子 0.5× density(由 #5),avatar silhouette 可辨識度不變(screenshot 對比 desktop)。

### Lifecycle + Persistence

- **AC-16**(CR-M9,BLOCKING)— **GIVEN** 慶典呈現,**WHEN** 玩家 dismiss(撳✕ / backdrop / 影完相),**THEN** `last_ceremony_unix=now` + 清 `pending` + 清 `week_had_change` + persist;同 window 唔重呈現(**影唔影相都一樣**標記)。
- **AC-17**(CR-M11,BLOCKING)— **GIVEN** boot 時 #26 已發出過 milestone(replay),**WHEN** `connect_for_initial_state` 接住 INITIAL_STATE,**THEN** latch 正確 rebuild,**唔**因 replay 開兩次慶典(idempotent boolean latch)。
- **AC-18**(CR-M12 / EC-MM-15,BLOCKING)— **GIVEN** 慶典呈現中 GSM SUSPENDED,**WHEN** resume Δ≤30000ms,**THEN** 續演;**WHEN** resume Δ>30000ms / negative,**THEN** 收 overlay + 保 window marker(唔重彈)。
- **AC-19**(CR-M13,BLOCKING)— **GIVEN** 慶典 dismiss,**WHEN** persist,**THEN** 只寫 `mirror_moment.*` namespace,**零** write `avatar.*`(CI-MM-4 + schema_version=1)。
- **AC-20**(CR-M14 / CI-MM-1,BLOCKING)— **GIVEN** static lint 掃 `src/**/mirror_moment*.gd`,**THEN** 零 tier-derivation pattern(無 `S_t`/`A_t`/`D_t` threshold、無 `effective_tier=max(...)`、無 `get_stat()` derive tier);tier 只經 snapshot/signal。

### Soft Dep + Falsifiable

- **AC-21**(CR-M10 / EC-MM-19,BLOCKING)— **GIVEN** 本週無 LEGENDARY drop(`SourceReceipt` null)且無 PR,**WHEN** present,**THEN** narrative 行**唔出**,慶典只用 #26 snapshot 照常呈現(null-safe,無 crash)。
- **AC-22**(CR-M10,ADVISORY)— **GIVEN** 本週有 LEGENDARY drop 帶 `signature_text="鍛造自 180kg × 5"`,**WHEN** present EVOLUTION,**THEN** caption 多一行顯示該 signature_text。
- **AC-23**(FT-2,ADVISORY/playtest)— **GIVEN** 慶典上線 ≥2 週 telemetry,**THEN** weekly self-initiated `mirror.shared` rate ≥ 30%(否則 FT-2 falsified → 重檢 share affordance)。
- **AC-24**(FT-M1,ADVISORY/playtest)— **GIVEN** 5 playtester 做 ≥2 週訓練,**WHEN** 週末 first-open,**THEN** ≥80% 注意到慶典出現過。
- **AC-25**(FT-M2,BLOCKING/audit)— **GIVEN** runtime audit 任何一次慶典,**THEN** 100% render field 可 trace 返 `get_evolution_snapshot()`(+ optional #17/#18 payload);無任何 fabricated field。
- **AC-26**(EC-MM-14,ADVISORY)— **GIVEN** ARMED 等緊兼 GSM IDLE 一閃即入 COMBAT(< `CEREMONY_PRESENT_DELAY_FRAMES`),**THEN** 慶典**唔**閃,留 ARMED 等下次 stable IDLE。

## Open Questions

| ID | Question | Owner | Target resolution | 預設(若無 input)|
|----|----------|-------|-------------------|------------------|
| **Q-OQ-PRESET** | EVOLUTION celebration burst 用**現有 #5 loot preset** 定**新 avatar-evolution preset**?**B-1 HARD 約束**:只有 LOOT preset(→LARGE tier→celebration-residence)先 render 上 CelebrationVFXLayer 110;新 preset 要 #5 amendment **兩件事**(size==9→N **加** LARGE-tier/celebration-residence carve-out)否則 burst 上唔到 modal layer。| art-director + #5 owner | **pre-`/create-stories`**(scope gate)| **復用現有 loot-celebration preset**(唯一免 #5 amendment 而 burst 正確 layer 嘅路;MVP 鎖定)|
| **Q-OQ-CAPTION-N** | caption 嘅週數 + 訓練次數(EVOLUTION「第 N 週 · 練咗 M 次」**及** REFLECTION「本週練咗 M 次」)由邊度讀?**確認 source = #9 WST**(`snapshot.source_metrics` 只有 `{stat_total, ability_count, max_class_depth, achieved_at_unix}`,**無** weekly count / 無 account-creation week,砌唔到 N/M,R-1)。| epic wiring(#9 Soft dep)| epic time | 經 #9 surface;缺 #9 → caption 退化純 tier/class(「進化到 T{n}」/「本週回顧」,null-safe,AC-06)|
| **Q-OQ-PR-CONTEXT** | #18 PR context 經邊個 surface 讀(#17 `SourceReceipt.pr_snapshot` vs #18 直接 telemetry)?| epic wiring | epic time | 經 #17 receipt(已 wired path,#17 Rule 10)|
| **Q-OQ-CAPTURE** | MVP 確認 **native-screenshot-only**(無 in-app capture-to-PNG)?web export file-save 跨瀏覽器風險。| ux-designer | `/ux-design mirror-moment` | **native-only**(in-app capture → v0.2,已 locked 喺 CR-M7)|
| **Q-OQ-V0.2-SCOPE** | v0.2「full layered ceremony」範圍(9:16 layered portrait / 多 beat reveal choreography / ghost morph 動畫 / social share deep-link / 慶典歷史 gallery)— 確認全部 out of MVP?| game-designer | v0.2 GDD extension | 全部 v0.2(systems-index 已標「v0.2: full layered」)|
| **Q-OQ-ADR0010** | ADR-0010 Status `Proposed → Accepted` — 本 GDD APPROVED + #26 已 APPROVED → 兩者一齊 ratify。/design-review APPROVE 後更新 ADR-0010 Status。| architect | `/design-review` 後 | Accept(#26 已 render-only 落地,#29 holds zero tier-state — ADR validation criteria 滿足)|

### 已解決(設計中拍板,記錄備案)

- **Q-RESOLVED-CADENCE**(game-concept Q4「weekly visible-change 規則」)— **單一 weekly cadence,content-adaptive**(CR-M1/M2):tier-up → EVOLUTION 大慶典,micro-only → REFLECTION 輕慶典,零變化 → skip。**規則本身**(邊個 tier、幾時升)由 **#26 Formula 2/3 owns**;#29 只反應 #26 milestone signal + 自己 own cadence/gate/composition。game-concept Q4 以此關閉(#29 唔重複定 visible-change rule)。
- **Q-RESOLVED-WEEKLY-GUARANTEE** — Pillar 5「每週必有 visible 進化」由 **REFLECTION 輕慶典**(micro-evolution 週)+ EVOLUTION 大慶典(tier-up 週)共同兌現;`WEEKLY_REFLECTION_ENABLED=true` 守住 weekly cadence。零訓練週**唔**兌現(誠實 > 每週,Pillar 1 > 機械式 weekly)。
