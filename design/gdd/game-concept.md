# Game Concept: 鏡像勇者 (Mirror Hero)

*Created: 2026-05-25*
*Status: Draft*

---

## Elevator Pitch

> 一個 2D 側面 RPG（楓之島 + DNF 風格），玩家嘅真實 gym 訓練數據驅動 in-game avatar 嘅力量。Game 喺 workout 期間 background auto-play，每完成一個動作（4 組）切換下一個 = 玩家唯一輸入；每日完成完整 workout = 一件隨機裝備。Workout = boss kill，real PR = 真實能力進化。

**10-second test**：玩家係咁做 — 一邊喺 gym 做 lift，一邊喺手機/平板/電腦見到自己嘅角色喺 2D 世界 auto-fight，揀下一個動作 = 揀下一個關卡，做完一日 = 必爆裝。✓

---

## Core Identity

| Aspect | Detail |
| ---- | ---- |
| **Genre** | 2D Side-scrolling action RPG (idle-companion 子類，gym-integrated) |
| **Platform** | Web (browser primary) + Desktop (secondary) — Godot 4.6 + Web Export |
| **Target Audience** | 25-40 歲，中重度 RPG loot-grinder × gym 訓練者 (見 Target Player Profile) |
| **Player Count** | Single-player |
| **Session Length** | 30-90 分鐘（與真實 workout session 等長） |
| **Monetization** | Premium / 暫不考慮 |
| **Estimated Scope** | Large (~24-30 個月達到 v1.0, solo part-time, velocity × 0.5) |
| **Comparable Titles** | MapleStory (grind+loot) / DNF (戰鬥 feel) / Hades (run-based loot) / Habitica (fitness gamification) |

---

## Core Fantasy

**身體越強，角色越強 — real reps become real power.**

四個 player fantasy 合一，互相加強：

1. **零碳變強嘅 grind 感** — 你由零開始嘅每一磅都喺 game 入面留下足跡
2. **Body↔Avatar 同步感** — 真實 PR 直接重塑 in-game 能力，唔可以氪金、唔可以 cheat
3. **全自動 idle，但有 meaningful choice** — 揀下一個動作 = 揀下一條 game 路線，唔需要拎手機操作
4. **Routine-fit** — Game 喺你做 gym 期間運行，唔需要另外 carve out 玩 game 時間

呢個 game 解決一個問題：**有 fitness 系統幫你 grind 身體，但冇 fitness 系統幫你獲得 grind RPG 嘅情感獎勵**。鏡像勇者 將呢兩件事合一。

---

## Unique Hook

> **Like Pokémon evolution, AND ALSO YOU yourself are evolving** — 每次真實嘅 PR 突破都會重塑你個角色嘅能力。Game 唔係坐喺 desk 前面玩，係喺 gym 做 lift 期間 background 跑。你嘅 reps 就係 game 嘅輸入，你嘅 PR 就係 game 嘅升級條件。

呢個 hook 對 gameplay 嘅直接影響：
- **冇 in-game shortcut**：所有能力解鎖只能透過真實訓練達成 — anti-pillar #1 lock
- **動作類型 = 職業選擇**：今日練推 = 可用 strike abilities；今日練腿 = 可用 mobility abilities — Muscle = Class
- **進度週期同身體週期同步**：你嘅 deload week → game 進入 「rest zone」narrative，係 feature 唔係 bug

---

## Player Experience Analysis (MDA Framework)

### Target Aesthetics

| Aesthetic | Priority | How We Deliver It |
| ---- | ---- | ---- |
| **Sensation** | **1 (Primary)** | DNF 重擊 + hit pause + screen shake + GPU particle storm，loot drop 視覺 over-the-top |
| **Challenge** | 2 | 真實 PR breakthrough = unfakeable challenge；workout consistency 推動 streak buff |
| **Fantasy** | 3 | Body-avatar embodiment — 角色 literally 等於你嘅身體 |
| **Discovery** | 4 | 解鎖技能 / 武器 / zone 透過 PR + 持續訓練 |
| **Expression** | 5 | 用 push/pull/leg 訓練配比 build 自己嘅角色 class |
| **Submission** | 6 | Background auto-play 提供 mid-set relaxing flow |
| **Narrative** | N/A (MVP) | 推遲至 v0.2+ |
| **Fellowship** | N/A (MVP) | 推遲至 T3 Full Vision (careful design) |

### Key Dynamics (Emergent player behaviors)
- **玩家會調整真實訓練計劃以匹配 game build** — 例如想解鎖某 push ability → 加大胸推 frequency。**呢個係 feature** — game 幫你 reinforce gym discipline
- **玩家會 cap loot drop 圖、share 突破 PR 同同步 unlock 嘅 ability**（DNF 文化）
- **玩家會比較自己 month-on-month 嘅 avatar evolution**（Mirror Moment effect）
- **玩家會用「我要爆裝」做心理動力捱完最後一組**

### Core Mechanics
1. **Real-workout → in-game progression bridge** — GymSys workout 數據 polling → 即時 game state update
2. **Auto-combat side-scroller** — Avatar persistent 行進，DNF combo 風格 hit-based
3. **Exercise-type → ability-class mapping** — Push / Pull / Leg 三類映射 strike / control / mobility
4. **Loot drop system** — workout completion 必爆 1 件，rarity 由 volume + PR + streak 決定
5. **Avatar progression** — 真實 PR 解鎖 new ability slots；持續訓練解鎖 zones / cosmetics

---

## Player Motivation Profile

### Primary Psychological Needs Served

| Need | How This Game Satisfies It | Strength |
| ---- | ---- | ---- |
| **Autonomy** | 揀邊個動作 = 揀邊條 game 路線；build 邊類型角色完全自主 | **Core** |
| **Competence** | 真實 PR = 真實能力提升，呢個 signal 唔可以 fake — 比所有 game 嘅虛擬升級更滿足 | **Core (super-power)** |
| **Relatedness** | MVP/v1.0 偏弱（純 single-player）；T3 Full Vision 加入 careful-designed friend leaderboard | **Minimal** (intentional) |

### Player Type Appeal (Bartle Taxonomy)

- [x] **Achievers** (⭐⭐⭐⭐⭐) — Loot collection、PR climb、ability unlock chain
- [x] **Explorers** (⭐⭐⭐) — Zone unlock through training milestones、ability tree exploration
- [ ] **Socializers** (⭐) — 故意 underweight，避免 social comparison 損害較弱玩家
- [ ] **Killers/Competitors** (⭐) — 避免 PVP / 真實重量公開比較（anti-pillar #4）

### Flow State Design

- **Onboarding curve**：首 5 分鐘 = 連接 GymSys 帳號 → demo workout → 必爆首件裝備 → 教 muscle=class mapping。NO tutorial wall — 一切 in-context 解釋。
- **Difficulty scaling**：唔靠 in-game 難度，靠**真實訓練強度自然增長**。Boss tier 跟玩家 1RM 進度自動調整 enemy stats。
- **Feedback clarity**：每組完成 → 視覺 micro-level-up（衫光、武器 glow、+EXP popup）；每動作完成 → mini-boss + minor loot；每 workout 完成 → final boss + guaranteed drop。
- **Recovery from failure**：缺一日 workout = 唔損 avatar 能力，只損 streak buff。NO permadeath。

---

## Core Loop

### Moment-to-Moment (30 seconds)
玩家做緊一組 lift（10-30 秒）。Game 喺 background **持續 auto-play DNF 風格戰鬥**：
- Avatar combo strikes，hit pause + screen shake + 粒子爆發
- 唔需要玩家睇 — 但**眼角瞄到都係視覺獎勵**
- Background music 微弱 in-game，唔搶 set 注意力

**Intrinsic satisfaction**：粒子 + hit pause 喺所有 gaming 入面係最便宜嘅爽感，呢個 game 將每組 lift 嘅「咬牙最後一 rep」嘅情緒同 onscreen 嘅 combat climax 平行播放。

### Short-Term (5-15 minutes) — Exercise-switch Loop
玩家做完一個動作（4 組） → 喺 GymSys 揀下一個動作：
- 切換瞬間：當前 enemy wave clear，**mini-boss spawn**
- Mini-boss 類型由下一個動作決定：推類 → 攻擊型 mini-boss；拉類 → 機關房；腿類 → 移動關卡
- 擊敗 mini-boss → minor loot drop（uncommon-rare 範圍）
- 「one more exercise」心理：仲有 2 個動作要做 → 「再打多個 mini-boss」

### Session-Level (30-120 minutes) — Workout Loop
玩家完成完整 workout（5-8 個動作）：
- 最後動作完成 → **Final Boss spawn**
- Avatar 用今日累積能力（即係今日訓練啟動嘅技能組）打 boss
- 擊敗 → **必爆 1 件 daily guaranteed drop**
- Loot rarity 公式：base rarity × (workout volume modifier) × (PR breakthrough modifier) × (streak modifier)

**自然停止點**：workout 結束 = 一日 game 結束。**回來嘅原因**：下一日 workout 解鎖下一個 zone 嘅 progression。

### Long-Term Progression (days/weeks/months)
- **真實 PR 突破** → 解鎖新招式 / 新 ability slot
- **連續 7/14/30 日 streak** → 解鎖新 zone / boss / rare cosmetic
- **每週**：Mirror Moment — avatar 必須有 visible 進化（衫升級、姿勢變、武器演化、新動畫）
- **每月**：新 boss 池解鎖，當前 build 同 boss 嘅 mechanical 對應

### Retention Hooks
- **Curiosity** — Locked zones, locked ability tiers, locked cosmetics
- **Investment** — 累積裝備、persistent character、build identity
- **Mastery** — PR climb 直接 visible 喺 in-game 能力
- **Mirror Moment** — 每週 visible 進化嘅 anticipation
- **Social** (T3 only) — Friend leaderboard 比較**進步幅度**（唔比較絕對重量）

---

## Game Pillars

### Pillar 1: 真身真力 (Real Body, Real Power)
Avatar 嘅強度只能由真實訓練累積得到 — 唔可以氪金、唔可以 in-game grind shortcut、唔可以由非阻力訓練（cardio / 步數）替代。

*Design test*: 「呢個能力可唔可以唔做 gym 都解鎖到？」應答 **NO**。

### Pillar 2: 無壓力陪伴 (Frictionless Companion)
Game 喺 workout 期間 BACKGROUND 存在，唔搶 lift 注意力。任何要求玩家 mid-set 拎手機操作嘅 mechanic 都唔該。

*Design test*: 「呢個 mechanic 會唔會逼玩家停 set？」應答 **NO**。

### Pillar 3: DNF 式爆裝刺激 (Drop Euphoria)
每次掉裝都係 dopamine peak，視覺音效要 over-the-top 滿足。Loot drop 唔可以「不知不覺發生」 — 要有儀式感。

*Design test*: 「爆裝畫面值唔值得 cap 圖、發朋友圈？」應答 **YES**。

### Pillar 4: 肌群即職業 (Muscle = Class)
當日訓練嘅肌群直接決定當日 avatar 可用嘅技能組。推 / 拉 / 腿三大類各對應 strike / control / mobility 能力族系。

*Design test*: 「腿日可唔可以打到 boss 用 push attack？」應答 **NO**。

### Pillar 5: 鏡像時刻 (Mirror Moment)
每週 avatar 必須有 visible、可截圖嘅進化反映真實 body change（衫升級、姿勢變、武器演化、新動畫）。呢個係單機 game 嘅 retention 心臟。

*Design test*: 「玩家做完 4 週訓練，打開 game 第一眼睇唔睇到自己變咗？」應答 **YES**。

### Anti-Pillars (What This Game Is NOT)

- **NOT 氪金 / in-game currency 加速進度** — 違反 Pillar 1（真身真力）。所有付費只可以係 cosmetic 或 quality-of-life，唔可以買 power。
- **NOT Set 中要求玩家 attention 嘅 mechanic** — 違反 Pillar 2。例如「呢一秒 tap 一下先有 buff」係禁忌。
- **NOT Permadeath / weekly reset / progress 懲罰** — 違反 routine-fit 嘅基本承諾。缺日只係 delay bonus，唔可以拎走玩家已得嘅嘢。
- **NOT 跨用戶 PVP / 真實重量公開比較** — 違反 Pillar 1 嘅精神。你只能同你自己嘅過去比，永遠唔比較絕對重量。T3 leaderboard 只比較 **relative progress %**。
- **NOT 用 cardio / 步數 / 其他非阻力訓練數據加 avatar 攻擊力** — 違反 Pillar 1。Apple Watch / Fitbit 整合不可侵蝕 strength training 嘅核心地位。

---

## Visual Identity Anchor ⭐

> **呢個 section 係 art bible 嘅種子。所有後續 art decision 都要 trace 返呢條 rule。**

### Selected Direction: A — Maple Pixel + Particle Storm

### One-Line Visual Rule
**每個 element 都係「乾淨剪影 + 骯髒粒子」 — character 輪廓永遠清晰，所有爆發感都用粒子層疊在外。**

### Supporting Visual Principles

1. **Silhouette First** — 任何 enemy / avatar 喺 16x16 greyscale 都要即時可識別類型（推 / 拉 / 腿 mini-boss 類）。Sprite design 過程中先剪影、後 detail。
   - *Design test*: 縮圖到 32px 純剪影，仍能辨認係邊類動作對應嘅 enemy？

2. **Particle Budget Rule** — Loot drop 時粒子數量係平時 combat 嘅 3 倍，造成視覺「體積膨脹」感。粒子用 GPU 唔用 CPU。Mobile-Safari fallback 自動降 0.5x multiplier。
   - *Design test*: 錄一秒 loot drop 片段，喺旁邊有人打架嘅情況下，眼球先落邊？應該係 loot。

3. **Layer Discipline** — World layer 永遠 desaturated 30%；HUD + loot text + 爆裝特效全飽和。任何 asset 入 world layer 都要做 saturation check。
   - *Design test*: 同一畫面入面，loot drop 嘅明度對比 background，足唔足以「眼角瞄到」就讀到？

### Color Philosophy

- **World palette**：低飽和 earth tones（楓之島地圖 feeling）— 深綠 / 暗褐 / 灰青，襯托 character
- **HUD / stat display**：高飽和 amber-gold — 一眼讀到 HP / EXP / 進度
- **Loot effect**：純白 burst → 彩色 trail（rarity → 色調：white → green → blue → purple → orange）
- **黑/白螢幕測試**：唔靠 color 都要打得 — type 識別靠 silhouette + animation

### Solo-Dev Path
- Sprite asset：用 LPC (Liberated Pixel Cup) open-source set 改 — 大幅降低原創成本
- Particle：Godot **GPUParticles2D**（唔用 CPUParticles2D — Web Export perf 差異大）
- Screen shake：用 shader uniform，**唔用 redraw**

---

## Inspiration and References

| Reference | What We Take From It | What We Do Differently | Why It Matters |
| ---- | ---- | ---- | ---- |
| **MapleStory** | Grind addiction, loot rarity tiers, pixel charm, side-scroll combat | Grind 喺真實世界發生，唔係 in-game 刷怪 | Validates 「pixel 2D side-scroll RPG + loot」係持久玩法 |
| **DNF (地下城與勇士)** | 重擊 hit pause, combo particle storm, screen shake feel | 用真 PR 解鎖招式而非 in-game 升級 | Validates「重擊 feel」係可以好夠 dopamine 即使做 idle-watchable |
| **Hades** | Run-based loot pipeline, character evolution between runs | Run = workout, 唔 permadeath, NO 重置 | Validates 變化 loot drop + character growth 嘅長期 retention |
| **Habitica** | Real-life habit → game stat | 只認 resistance training，唔玩 universal habit；無 social pressure | Validates fitness gamification market 但比 Habitica 更聚焦 |
| **Zwift** (cycling) | 真實運動同 in-game 同步運行 | 不需要 hardware、適合 strength training 場景 | Validates「運動期間 background game」市場 |

**Non-game inspirations**：
- 健身 culture 入面「PR breakthrough」嘅儀式感
- 鏡子（mirror）作為健身房 staple — Mirror Moment pillar 嘅命名來源
- 「日積月累見變化」嘅 transformation narrative（健身前後對比照）

---

## Target Player Profile

| Attribute | Detail |
| ---- | ---- |
| **Age range** | 25-40 歲 |
| **Gaming experience** | Mid-core to Hardcore（玩過 MMORPG 或 ARPG 長期 grinder） |
| **Time availability** | 30-90 分鐘 gym session，3-5 次/週 |
| **Platform preference** | 手機 + 平板（gym 場景），desktop（home review） |
| **Current games they play** | MapleStory / DNF / Diablo IV / POE / Hades / Habitica |
| **What they're looking for** | 將真實 gym 嘅 grind discipline 同 RPG 嘅 dopamine reward 連住嘅 game |
| **What would turn them away** | 氪金 power、強制 PVP、要 carve out 額外時間玩、cardio-as-power 嘅 watered-down 變體 |

---

## Technical Considerations

| Consideration | Assessment |
| ---- | ---- |
| **Recommended Engine** | Godot 4.6 — 2D 強、Web Export native、open source、user 已選定 |
| **Key Technical Challenges** | 1) Godot Web Export 粒子 perf on mobile Safari (HIGH risk)、2) GymSys backend ↔ Game realtime sync、3) Save state durability、4) Layered character sprite Z-order (v0.2+) |
| **Art Style** | Pixel art (16-32px sprite base)，layered character (v0.2+) |
| **Art Pipeline Complexity** | Low-Med — LPC asset 修改 + 少量原創 |
| **Audio Needs** | Moderate — SFX-heavy（hit feedback + loot fanfare），background music subtle |
| **Networking** | GymSys backend polling (MVP, 5s interval) → SSE (v0.2 upgrade)。NO PVP / multiplayer until T3 |
| **Content Volume (v1.0)** | 5-10 zones × 20 bosses × 30-100 items |
| **Procedural Systems** | Loot table generation（rarity weighted），enemy wave variation。NO procedural levels in MVP/v0.2 |
| **Save State** | **Backend-primary**（`game_state.json` per user in GymSys backend），IndexedDB cache via `user://` FileAccess for offline boot per ADR-0003 (N-005 sync 2026-05-28 — ADR-0003 supersedes prior "localStorage cache" prose; localStorage explicitly FORBIDDEN per ADR-0003 forbidden pattern) |

---

## Risks and Open Questions

### Design Risks
- **Auto-play 夠唔夠 watchable** 喺玩家 mid-set glance 一秒之間？— Mitigation: Vertical slice 測試
- **Muscle=Class mapping** 嘅平衡：某類動作太多人練 / 某類偏冷門，dominant strategy 風險 — Mitigation: 設計階段做 ability synergy 確保跨類 build 可行
- **Mirror Moment** 嘅 weekly update 對 art pipeline 嘅持續壓力 — Mitigation: 預製 evolution stages，唔係 ad-hoc

### Technical Risks
- **Godot Web Export 粒子 perf on mobile Safari**（HIGH）— Mitigation: GPU particles + budget cap 200 active + fallback 0.5x
- **GymSys integration architecture** — Mitigation: polling MVP，明確 protocol，SSE upgrade planned
- **Save state durability** — Mitigation: backend-primary 由 day 1，IndexedDB (via `user://`) 只做 cache per ADR-0003 (N-005 sync 2026-05-28)
- **Layered sprite system** (v0.2+) — Mitigation: 推遲到 v0.2，MVP 用 single sprite
- **CORS / cross-origin auth** — Mitigation: 早期決定 game 同 GymSys 嘅 deployment topology

### Market Risks
- **Niche audience**：gym 訓練 ∩ RPG loot grinder — Mitigation: validate via solo dev MVP，唔需 mass market 證明 PMF
- **Education cost**：解釋「game 同 gym 連住」對外人 — Mitigation: 1 段 30 秒 demo video 解決

### Scope Risks
- **Solo + first-time game dev + 4 個 parallel production system** → velocity × 0.5 — Mitigation: Producer rebased timeline 接受
- **MVP scope creep**：layered char / 多 boss / 多 zone 容易蔓延入 MVP — Mitigation: anti-pillar 強制守住 MVP 邊界
- **第一次接觸 Godot 4.6** — Mitigation: vertical slice 包 engine 學習 buffer

### Open Questions
- **Q1**: GymSys 同 game 嘅 deployment topology 點接？(Same backend / 並行 service / Embed iframe?) — 由 Vertical Slice 階段嘅 ADR 解決
- **Q2**: Loot rarity 公式具體 weight 點分配？— 由 systems-designer + balance-check 喺 design phase 確定
- **Q3**: PR detection — 真 1RM PR 觸發稀有 drop 要 server-side 判定，邊度比較 historical max？— 由 GymSys API extension ADR 處理
- **Q4**: 「鏡像時刻」每週解鎖嘅 visible change 規則點定？(訓練 frequency? Volume? PR count?) — 由 systems-designer 設計

---

## MVP Definition (T0)

**Core hypothesis**：「玩家做緊 gym set 期間，眼角瞄到 auto-combat 仲會被吸引；做完一日 workout 後爆裝感覺值得做返第二日。」

如果呢條 hypothesis 經 MVP 驗證 = `PROCEED` to T1。如果 hypothesis 失敗（玩家完全唔睇畫面 OR 爆裝唔覺爽）= `PIVOT` 或 `KILL`。

### Required for MVP (T0)
1. **Godot 4.6 Web Export build** — 可喺 desktop 同 mobile Safari 跑
2. **GymSys backend integration** — polling /api/game/state every 5s，read workout data
3. **Backend save state** — `game_state.json` per user in GymSys backend（day 1）
4. **1 zone** with auto-combat
5. **3 exercise mappings**：1 push（e.g. bench press）+ 1 pull（e.g. row）+ 1 leg（e.g. squat）
6. **1 final boss**（workout-complete trigger）
7. **5 件裝備**：5 rarity tiers 各 1 件（或 same tier 5 件 different stat）
8. **DNF feel三件套**：hit pause + GPU particles (≤200 active) + screen shake
9. **Base avatar**（單 sprite，無 layered system）

### Explicitly NOT in MVP (推遲到 v0.2+)
- Layered character sprite system
- 多 zones / 多 bosses / 多 items
- SSE upgrade（用 polling）
- 完整 skill trees
- Mirror Moment animations（weekly evolution）
- 朋友 leaderboard
- Web Push notifications

### Scope Tiers (Producer rebased)

| Tier | Content | Features | Timeline (cumulative) |
| ---- | ---- | ---- | ---- |
| **Vertical Slice** | Single test scene (Godot Web + 50 particles + GymSys polling + 1 boss kill) | Engine learning + integration POC | **3-4 週 + 1 週 buffer** |
| **MVP (T0)** | 1 zone, 3 exercises, 1 boss, 5 items, base avatar | Core loop only, polling integration, backend save state, DNF feel | **+3-4 個月**（累計 ~4-5 個月） |
| **v0.2 (T1)** | Layered char + 2-3 zones + 3-5 bosses + 15-30 items | + SSE upgrade + 完整 skill trees (Pillar 4) + Mirror Moment animations (Pillar 5) | **+4-6 個月**（累計 ~8-11 個月） |
| **v1.0 (T2)** | 5-10 zones + 20 bosses + 30-100 items | + 進化系統 + class spec system + balance polish | **+12-18 個月**（累計 ~20-29 個月） |
| **Full Vision (T3)** | All above + 朋友 leaderboard + seasonal content + community feature | + Web Push notification + post-launch live-ops | **post-v1.0** |

**Hard governance rules**:
- **Velocity multiplier**：× 0.5（4 個 parallel production system 嘅 reality）
- **每月 hard checkpoint**：超時 20% → 即觸發 re-scope，唔好 sunk cost
- **Vertical Slice failure criteria**：>5 週仍未跑通基本 loop → pivot to native desktop export 或 scope cut
- **每 tier 完結**：強制 playtest + retro 先入下一 tier

---

## Next Steps

按照 `/brainstorm` Path A 推進：

- [ ] **`/setup-engine`** — Configure Godot 4.6，populate version-aware reference docs（Godot 4.4-4.6 喺 LLM knowledge cutoff 之後，必須建立 engine-reference）
- [ ] **`/art-bible`** — 以 Visual Identity Anchor (Direction A) 為種子，產出完整 art bible（gates 所有 asset production；required before Technical Setup gate）
- [ ] **`/design-review design/gdd/game-concept.md`** — Validate concept completeness before downstream
- [ ] **`/prototype`** — Vertical-slice style 概念 prototype（3-4 週）— Godot Web Export + 50 particles + GymSys polling + 1 boss kill loop。**Fail criteria written in BEFORE start.**
- [ ] **`/map-systems`** — Decompose concept into systems with dependencies
- [ ] **`/design-system [system-name]`** — Author per-system GDDs (e.g., combat, loot, progression, exercise-mapping, mirror-moment)
- [ ] **`/review-all-gdds`** — Cross-system consistency check
- [ ] **`/gate-check`** — Validate readiness before architecture phase
- [ ] **`/create-architecture`** — Master architecture blueprint + Required ADR list
- [ ] **`/architecture-decision`** (×N) — Including required ADRs:
  - ADR-001: Godot Web Export budget caps (particles / draw call / bundle size)
  - ADR-002: GymSys integration protocol (polling MVP → SSE v0.2)
  - ADR-003: Save state strategy (backend-primary + IndexedDB via `user://` FileAccess; localStorage FORBIDDEN — N-005 sync 2026-05-28)
  - ADR-004: CORS / cross-origin auth topology
  - ADR-005: Loot rarity formula
- [ ] **`/create-control-manifest`** — Compile decisions into actionable rules sheet
- [ ] **`/architecture-review`** — Bootstrap TR registry
- [ ] **`/ux-design`** — Author UX specs for key screens（gym-mode HUD, loot drop modal, character screen）
- [ ] **`/vertical-slice`** — Production-quality end-to-end build (Pre-Production gate)
- [ ] **`/playtest-report`** — Document each playtest session
- [ ] **`/create-epics`** → **`/create-stories`** → **`/sprint-plan`** → enter Production
