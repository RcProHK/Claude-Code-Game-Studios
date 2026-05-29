# Art Bible: 鏡像勇者 (Mirror Hero)

> **Status**: Complete — 2026-05-28
> **Visual Identity Anchor**: Direction A — Maple Pixel + Particle Storm
> **AD-ART-BIBLE Sign-Off**: CONCERNS Accepted — 2026-05-28 (Creative Director agentId a765e30c2c3eb4003)
> **6 Concerns resolved inline**: C1 sprite sub-caps / C2 loot timeline clarification / C3 enemy px-level spec / C4 NPC explicit MVP budget / C5 event layer boundary / C6 combat climax duration disambiguation

---

## Table of Contents

1. [Visual Identity Statement](#1-visual-identity-statement)
2. [Mood & Atmosphere](#2-mood--atmosphere)
3. [Shape Language](#3-shape-language)
4. [Color System](#4-color-system)
5. [Character Design Direction](#5-character-design-direction)
6. [Environment Design Language](#6-environment-design-language)
7. [UI/HUD Visual Direction](#7-uihud-visual-direction)
8. [Asset Standards](#8-asset-standards)
9. [Reference Direction](#9-reference-direction)

---

## 1. Visual Identity Statement

### 1.1 One-Line Visual Rule

**「乾淨剪影 + 骯髒粒子」— Character 輪廓永遠 readable，所有爆發感都用粒子層疊在剪影之外。**

呢條 rule 將 Mirror Hero 嘅視覺語言切成兩個互不干擾嘅 layer：**形體層**（sprite silhouette、animation、pose）負責「呢個係咩」嘅瞬間識別；**粒子層**（VFX、loot burst、stat flash）負責「呢一刻發生緊咩」嘅 dopamine 觸發。兩層永遠分工，永遠唔互相吞噬。

呢個切割解決咗 Mirror Hero 最特殊嘅 design constraint：玩家**唔會盯住屏幕**。佢哋一邊舉鐵一邊用眼角掃畫面，所以視覺資訊必須喺 0.3 秒內 readable，而高潮 moment（loot drop）要用粒子體積去「攞返」眼球。剪影做日常 baseline，粒子做事件 spike。

---

### 1.2 Supporting Visual Principles

#### Principle 1: Silhouette First（剪影先決）

**說明**: 所有 character、enemy、avatar、boss 都必須喺 16×16 greyscale 純黑剪影狀態下，**即時可辨認類型**。Sprite design 必須先確立剪影 shape，後加 detail；唔可以靠顏色或 detail texture 去區分角色類型。剪影嘅 distinctness 由三個 axis 構成：**輪廓寬高比**（瘦長 vs 寬扁）、**頭身比例**（avatar 4 頭身、boss 2 頭身、雜兵 3 頭身）、**附件 silhouette**（武器伸出嘅角度與長度）。動作嘅 telegraphing 都靠剪影 — 出拳前嘅 wind-up pose 喺剪影層面已經要睇得出「呢個係 Strike 類動作」。

**Design Test**: 當「呢個 enemy sprite 加咩 detail 先夠靚？」呢個問題出現時，呢條原則話**「detail 加幾多都唔重要 — 先 print 一張 32px 純黑剪影擺枱面三米遠，認唔到類型就推倒重畫，認到先講 detail」**。

**服務 Pillar**:
- **P2 無壓力陪伴**（主要）— 玩家用眼角睇畫面時，剪影係唯一可靠嘅 readability channel，detail 喺呢個距離全部變 noise。
- **P4 肌群即職業**（次要）— Push/Pull/Leg 三種技能類型必須喺剪影層面已經有 distinct posture，肌群差異要可以「一眼睇得出」而唔係靠 icon。

---

#### Principle 2: Particle Budget Rule（粒子預算階梯）

**說明**: 粒子數量係**遊戲狀態嘅明度尺**，唔係裝飾。Combat baseline 設定為 N 粒子/秒；loot drop moment 必須係 **3N**，造成可感知嘅「體積膨脹」— 玩家眼角會自動被體積大嘅 cluster 吸引。粒子層級由低到高：環境塵埃（0.2N）→ 普通 hit（1N）→ 技能爆發（1.5N）→ **loot drop（3N，純白 burst → rarity-tinted trail）**。

技術實作用 GPUParticles2D（透過 `particle_system_wrapper.gd` autoload，遵守 ADR-0001），Mobile Safari fallback 自動降到 0.5× density 但**保留 burst 嘅形狀**（係 density 降，唔係 emitter 數降，唔可以令 loot 變得「冇感覺」）。粒子永遠喺 sprite 上層，永遠唔遮蓋 silhouette readability — 用 additive blend + edge feather 確保剪影邊緣依然睇得出。

**Design Test**: 當「呢個技能特效要唔要再大啲？」呢個問題出現時，呢條原則話**「先錄一秒 loot drop 同呢個技能特效並排播放 — 如果眼球會先飛去技能而唔係 loot，特效要 scale down 到 loot 永遠贏」**。Loot 必須係視覺金字塔頂，所有其他特效都係 supporting cast。

**服務 Pillar**:
- **P3 DNF 式爆裝刺激**（主要）— 粒子體積就係 dopamine 嘅 carrier。3× burst 唔係誇張，係 ritual。每次 drop 都要令玩家「即使冇望住都感受到」。
- **P2 無壓力陪伴**（次要）— 粒子預算階梯確保「冇事發生」嘅 baseline 真係安靜，眼角唔會被無關 idle VFX 騷擾。

---

#### Principle 3: Layer Discipline（層級飽和度紀律）

**說明**: 畫面分三條飽和度 channel，永遠分開唔互染：

1. **World Layer**（背景、地形、environment props）— **desaturated 30%**，低明度對比，earth tones（深綠 / 暗褐 / 灰青）。佢嘅職責係「存在但唔搶眼」，類似楓之島地圖嘅 mute feeling。
2. **Character Layer**（avatar、enemy、boss sprite）— 中度飽和，色相 anchor 喺 world palette 之上少少跳，足夠分離 figure-ground 但唔會 punch out。
3. **Event Layer**（HUD、stat number、loot text、爆裝特效）— **100% 飽和，HDR-bright**，amber-gold for stat、純白→rarity color for loot。佢嘅職責係「眼角一掃即讀」。

呢三層永遠唔可以「中間混色」— world 唔可以突然有純飽和嘅 environment，HUD 唔可以為咗「貼合場景氣氛」而 desaturate。紀律嘅意義在於：**玩家學會咗「飽和度 = 重要程度」之後，呢個視覺語言喺成個遊戲生命週期都成立**。

**Design Test**: 當「呢個 UI element / VFX 應該用咩顏色先 fit 個場景？」呢個問題出現時，呢條原則話**「先問佢屬於邊一層 — World 就 desaturate，Event 就拉到 100% 飽和，唔可以為咗『美感』而違反 layer 規則」**。

**服務 Pillar**:
- **P2 無壓力陪伴**（主要）— Desaturated world 確保 background 真係 background，玩家舉鐵時眼角望落去唔會被搶注意力。
- **P3 DNF 式爆裝刺激**（次要）— 100% 飽和嘅 loot text 同 desaturated world 嘅對比，係 dopamine spike 嘅放大器。
- **P5 鏡像時刻**（次要）— 截圖時，avatar 嘅 distinct 飽和度 channel 確保佢喺任何背景前都 pop，週進化截圖永遠有 visual punch。

---

### 1.3 Pillar Coverage Summary

呢 3 條 principles 用**「分層 + 紀律 + 階梯」**嘅組合策略 cover 哂 5 個 pillars：

- **P1 真身真力** — 由 Silhouette First 間接 serve：avatar 嘅 visual progression（headcount、武器尺寸、posture confidence）全部喺剪影層面表達，冇真 PR = 剪影冇變化 = 視覺上 cheat 唔到。
- **P2 無壓力陪伴** — 三條原則同時 serve：剪影確保眼角掃就讀到；Layer Discipline 確保 world 真係 quiet；Particle Budget 確保 baseline 階段粒子真係少。
- **P3 DNF 式爆裝刺激** — 主要由 Particle Budget（3× burst）+ Layer Discipline（100% 飽和 event layer 對比 desaturated world）合力放大。剪影層保持冷靜，粒子層獨佔 dopamine。
- **P4 肌群即職業** — 由 Silhouette First 直接 serve：Push/Pull/Leg 三類技能喺剪影層面已經有 distinct telegraph，肌群差異 = posture 差異 = 一眼識別。
- **P5 鏡像時刻** — 由 Silhouette First（avatar 進化喺剪影層面 visible）+ Layer Discipline（avatar 喺截圖中永遠 pop）共同 serve。

整體 visual identity 嘅 thesis：**剪影 carry identity（who/what），粒子 carry event（when/how much），飽和度 carry priority（read me first / later / never）**。三條 channel 永遠分工，玩家就算冇盯住屏幕，視覺資訊都 reach 到佢。

---

## 2. Mood & Atmosphere

Mirror Hero 嘅情緒設計核心張力係 **「靜 vs 爆」**：90% 時間（組間 + 換動作）必須係安靜陪伴，唔搶 lift attention（P2）；剩 10% 時間（loot drop + final boss kill）必須係儀式感爆發 dopamine peak（P3）。呢個對比唔係靠音效或者 gameplay，而係靠 **lighting、saturation、particle density 三條軸** 嘅幅度差距嚟實現。

每個 state 嘅 mood 都對應「Visual Identity」三條原則嘅其中一條主導：靜態 state 由 **Silhouette First** 主導（粒子最少、輪廓最 clean）；爆發 state 由 **Particle Budget Rule** 主導（3× baseline 粒子）；過渡 state 由 **Layer Discipline** 主導（飽和度階梯切換）。

### 2.1 Mood Table（6 個 Game States）

| State | 情緒目標 | 光線特質 | 大氣描述詞 | 能量等級 | 視覺分離手段 | Pillar |
|-------|---------|---------|-----------|---------|------------|--------|
| **During Set**（組間 baseline） | 「窗外嘅黃昏，唔搶你注意，但你知佢喺度」— 周邊視覺存在感，但中央焦點留俾現實世界 | 黃昏側光，色溫 warm（~3800K），低對比（shadow lift +15%），無 specular highlight | 柔和、遠景、呼吸感、低語、霧化 | **measured** | 粒子密度 1× baseline；World −30% 飽和；Character mid-tone；無 screen shake；無強對比閃光 | **P2** |
| **Exercise Switch**（mini-boss spawn） | 「天色微微一沉，有嘢嚟」— 預兆感，但唔驚嚇，類似 BGM 過門 | 色溫由 warm 滑向 neutral（3800K → 5000K），對比 +20%，rim light 標示 mini-boss spawn 位置 | 預示、聚焦、收束、靜電、傾斜 | **energized** | 粒子密度 1.5×；World 飽和由 −30% 提升到 −15%；Character rim light 強化輪廓 | **P4**（職業切換對應肌群切換） |
| **Combat Climax / Ability Use** | 「一拳清光，順暢俐落」— 短促爆發但唔拖延，類似格鬥遊戲 hit confirm | 色溫短暫 cool flash（~6500K）標示 ability cast frame，對比高（瞬間 +40%） | 鋒利、迸發、劈開、瞬閃、震盪 | **frenetic**（持續 < 2 秒） | 粒子 2× baseline，只在 ability 路徑線上；Event layer 100% 飽和（Strike 紅 / Control 紫 / Mobility 藍）；輕微 screen shake（mobile disabled） | **P4** |
| **Loot Drop Ritual** | 「DNF 暴擊 — 世界停一拍，光柱劈開背景」— 必須係今日 highlight，可截圖、可炫耀 | 背景瞬間 desaturate −60%（戲劇靜止），裝備位置爆發白金色光柱由下而上（warm gold ~2700K），rarity 越高加入紫色 fringe | 神聖、加冕、定格、輝光、降臨 | **ceremonial** | 粒子密度 **3× baseline**（mobile 0.5×）；World −60% desaturate；Event 100% 飽和爆光柱；time-stop hold ~0.4 秒 | **P3** |
> **Loot Drop Timeline Clarification**（三個數字係 OVERLAP，唔係 sequence）: time-stop window = 0.4s（世界凍結 + UI modal open）；UI animation duration = 1.2s（modal open + particle burst，Section 7.D）；Total saturation override duration = 2.0s（Burst 0.15s + Settle 1.05s + Recover 0.8s，Section 4.E）。三者同時開始，各自獨立 complete。
| **Daily Workout Complete**（Final Boss Kill） | 「鏡像進化嘅一刻」— 比 Loot Drop 更靜、更長、更莊重；唔係爆發係加冕 | Final boss 死亡 fade to white（1 秒），鏡頭拉近 avatar，portrait studio lighting（key + fill light，5500K neutral，high contrast），背景虛化 | 莊嚴、凝視、加冕、回望、definitive | **ceremonial**（持續 4-6 秒，比 loot drop 長 10×） | 粒子密度 0.5×（極簡）；World 完全模糊+desaturate；Character 100% 飽和 + 銳化；無 screen shake；專屬截圖 frame | **P5** |
| **Menu / Lobby / Rest State** | 「靜止嘅鏡房，等你返嚟」— avatar idle，背景 abstract 漸變，俾玩家 ownership 感 | 平光（無方向性），色溫 neutral（5000K），低對比，無 ambient particle | 平靜、留白、自我、鏡面、停泊 | **contemplative** | 粒子完全停（0×）；World −50%；Character 100% 飽和（凸顯今日成果）；無動畫除 idle breathing | **P5** |

### 2.2 「靜 vs 爆」對比驗證

**During Set（baseline）** vs **Loot Drop Ritual** 五軸差距驗證：

| 軸 | During Set | Loot Drop | 差距 |
|---|-----------|-----------|------|
| 粒子密度 | 1× baseline | 3× baseline | **3 倍** |
| World 飽和度 | −30% | −60% | **2 倍 desaturation depth** |
| 對比度 | low（shadow lift +15%） | high（光柱 +40%） | **動態範圍翻倍** |
| 色溫 | warm 3800K 穩定 | warm gold 2700K + rarity shift | **戲劇性偏移** |
| 時間感 | 持續、呼吸 | time-stop 0.4 秒 | **停頓 vs 流動** |

五軸同時拉開，先至可以做到「玩家明明喺做 deadlift，但係 loot 掉嘅一刻會抬頭睇」嘅效果 — 即係 P2（安靜陪伴）+ P3（儀式爆發）嘅核心張力。

### 2.3 設計意圖補充

- **During Set 唔可以太靜**：完全無動靜會令玩家忘記 game 存在，Loot Drop 就冇對比衝擊。保留 1× 粒子做「呼吸」— ambient presence 而唔係 silent void。
- **Final Boss Kill 比 Loot Drop 更靜**：Loot 係頻繁 dopamine（每組可能都有）。最後 boss kill 改用「portrait studio」靜態加冕語言，與爆發式 loot 形成 hierarchy。
- **Exercise Switch 做 pacing buffer**：baseline 直接跳 climax 太突兀。色溫由 warm 滑向 neutral 係預兆語言，類似電影 pre-chorus build-up。
- **Mobile 0.5× 粒子處理 ceremonial 感**：粒子減半但保留色溫偏移 + time-stop + 光柱核心元素。Ritual 感由「節奏 + 色彩」承擔，唔靠純粒子數量。

---

## 3. Shape Language

Shape language 係 Mirror Hero 嘅視覺骨架。當 pixel 精度只得 16-32px、player 隨時可能瞇眼睇電話，**形狀比顏色更早被大腦解讀**。所以每一條原則都圍繞一個核心信念：「乾淨剪影 + 骯髒粒子」嘅前半段——剪影必須先做對，粒子先有意義。

### 3.A Character Silhouette Philosophy

**Avatar 嘅進化感 — 三層輪廓規則**

Avatar 係 player 自己嘅鏡像（P5），所以「進化」唔可以靠換 model——要靠**幾何 silhouette 嘅單調遞增**：

| Tier | 訓練時數 | 頭身比 | 肩寬 | 武器 Scale | Silhouette 形狀 |
|------|---------|-------|------|-----------|----------------|
| Tier 1（Beginner） | 0–10 小時 | 2.5:1 | 8px | 0.4× | 倒置雞蛋形（egg-down）— 「未成形」 |
| Tier 2（Intermediate） | 10–50 小時 | 3:1 | 10px | 0.55× | 沙漏形（hourglass）— 「人形 archetype」 |
| Tier 3（Advanced） | 50+ 小時 | 3.5:1 | 12px | 0.7× | 正三角形（triangle-up）— 「英雄 archetype」 |

**關鍵限制**：任何 tier 嘅 base silhouette 必須喺 64×64 pixel preview 內，唔睇顏色都辨認到屬於邊個 tier（P1 design test）。Tier 之間嘅差異靠**輪廓 diff**，唔係細節堆砌；任何細節（盔甲紋、肌肉線）都收喺 silhouette 內部，唔可以「漏出」邊緣。

**Design Test**: 當美術師問「呢套裝甲做唔做粗肩？」——答案要睇玩家 tier。Tier 2 角色穿 Tier 3 cosmetic skin，silhouette 仍然必須係 hourglass 而唔係 triangle，**因為 silhouette 屬於成長系統，唔屬於 cosmetic 系統**。

**Enemy 三類型嘅 silhouette 識別**（服務 P4）

| 類型 | 訓練對應 | Silhouette Primitive | 視覺隱喻 | 範例 |
|------|---------|---------------------|---------|------|
| Push 類 | 胸／肩／三頭 | 寬扁橫矩形（T 形） | 「推力向外擴張」 | Bench Tyrant |
| Pull 類 | 背／二頭 | 倒三角（V-down） | 「拉力向內收攏」 | Lat Wraith |
| Leg 類 | 股／臀／小腿 | 倒梯形（trapezoid-down） | 「腿型穩定、地面 anchor」 | Squat Colossus |

三個 primitive 永遠唔可以混用。即使某 boss 屬於複合訓練，都必須選定一個主類型，另一個只可以喺粒子層表達。

**Design Test**: 當新 boss 設計 ambiguous（例如「deadlift 算 pull 定 leg？」）——答案係**揀視覺上重心更低嘅 primitive**。Deadlift silhouette 重心在地面（leg trapezoid），即使二頭都受力，主類仍然係 leg。**幾何 primitive 跟視覺重心，唔跟解剖學分類。**

**Final Boss 嘅比例差距**

- Scale = mini-boss 嘅 2.2×（mini-boss ≈ 32×48px → final boss ≈ 70×106px）
- Silhouette primitive 採用 player 當前 tier 嘅形狀，但**鏡像左右翻轉 + 比例放大**（P5 核心視覺）
- 武器 scale 1.0×（超出 player 武器上限 0.7×，係「distorted mirror」警示）

**Design Test**: Final boss 唔需要比 mini-boss 大十倍。Mirror Hero 嘅震撼來自「呢個係我自己嘅歪曲版」嘅認知，2.2× 係 silhouette readability 上限。

---

### 3.B Environment Geometry

**主導語言：Angular-Organic Hybrid**

- **可互動地形（platforms / walls / hazards）**：全部用 **45° / 90° angular geometry**，邊緣硬，corner 唔加 anti-alias。「規則明確」幾何訊號——player 一眼識別「有 affordance」。
- **背景 element（trees, ruins, distant mountains）**：**organic curves，輪廓帶 1-2px noise dithering**。「無法互動」幾何訊號——再靚都係 decoration。

Angular 主導嘅理由（P2）：player 疲勞狀態下，curved platform 喺低光低對比下會被誤讀成 background；angular 邊緣即使 JPEG artifact 都保留 silhouette 識別度。粒子（dust, vegetation sway）只加喺 organic background 嗰邊，唔可以模糊 platform 邊緣。

**Platform vs Decoration Shape Contrast Rule**

- **Platform（可踏）**：horizontal-dominant rectangle，最短邊 ≥ 8px。**Top edge 必須係單一直線**，唔可以有 organic break。
- **Decoration（唔可踏）**：vertical-dominant 或 organic blob。**Top edge 必須有至少一個 organic break**（凹陷、葉子、岩石突起）。

**Design Test**: 倒下嘅樹幹形狀似 platform——必須喺頂部加最少一支樹枝 break top edge。呢個規則比色相差異更可靠，因為 Loot Drop 時 world −60% 飽和，色相差會被壓平，但 **shape break 永遠 readable**。

---

### 3.C UI Shape Grammar

**Hybrid 策略：核心 HUD 用 screen-space，儀式時刻用 diegetic**

- **Screen-space HUD**（health, exp, exercise progress, skill cooldowns）：永遠 anchor 喺 screen 邊緣，唔受 camera 影響。形狀用**圓角矩形（corner radius = 2px on 16px base）**——軟過 angular world，硬過 organic background，**喺 shape hierarchy 佔獨立一層**。
- **Diegetic UI**（Loot Drop reward 展示、Final Boss Kill portrait frame、Menu avatar 展示）：embedded 喺 world，跟 angular geometry 一致。

**HUD 元素幾何規則**

| HUD 元素 | 形狀 | 原因 |
|---------|------|------|
| Health bar | 圓角橫矩形，6px 高，1px corner | 連續血量 = 連續 bar；最重要資訊，最粗 |
| Exp bar | 圓角橫矩形，3px 高（health 50%） | Thickness hierarchy = importance hierarchy |
| Exercise progress | 圓環（外徑 16px，stroke 2px） | Discrete countdown（一圈 = 一組完成）。**形跟 function 同步，服務 P1** |
| Skill cooldowns | 16×16 正方形 icon + 順時針扇形遮罩 | Square ≠ circle，避免與 exercise ring 混淆 |

**Design Test**: 加新 HUD element（例如 streak counter）——先決定**連續（bar）定 discrete（ring/icon）**，再決定 size hierarchy（比 health 大 = 比 health 重要，呢個訊號要諗清楚）。

---

### 3.D Hero Shapes vs Supporting Shapes — Attention Hierarchy

| Rank | 形狀 | 保留俾 | 服務 Pillar |
|------|------|--------|-----------|
| 1（最吸眼） | 正三角向上（▲） | Tier 3 avatar、combat climax particle vector、final boss kill portrait accent | **P1**（最高 tier = 最吸眼） |
| 2 | 圓形（●） | Loot Drop reward orb、exercise progress ring、avatar head | **P3**（loot 係全 screen 最高 attention circle） |
| 3 | 沙漏形（⧗） | Tier 2 avatar、exercise switch rim light 輪廓 | **P5**（日常嘅鏡像，readable 但唔喧嘩） |
| 4 | 橫矩形（▬） | Push enemy、health bar、platform | **P2**（readable 但唔搶眼） |
| 5（最 recede） | 倒三角/倒梯形（▽） | Pull/Leg enemy、background ruins、decoration | — |

**核心 thesis**：呢個 hierarchy 全部建立喺**乾淨剪影**之上。粒子可以加喺任何 shape 周圍，但**粒子永遠唔可以改變 shape 嘅 attention rank**——Tier 1 avatar 加再多粒子都唔可以搶過 Tier 3 嘅 attention，因為**粒子係裝飾，剪影係結構**。

**Design Test**: 提議俾 Tier 2 avatar 加 circle halo 突出存在感——halo 係 circle（rank 2），會搶走原本歸 Loot orb 嘅視覺位置。如果一定要加，halo 必須係 hourglass-shaped，**跟返 avatar 自己嘅 tier shape**，咁先唔會打亂 hierarchy。

---

## 4. Color System

### 4.A Primary Palette（7 色制）

World 4 色（earth tone foundation）+ Character 1 色（neutral base）+ Event 2 色（amber + pure white）。Hue cluster 喺 60°–180°（warm-green 至 cool-cyan），刻意避開紅同橙，令 Event Layer 嘅 amber-gold 同 loot 純白 pop 出嚟唔撞色。`world_*` hex **已 baked in −30% desaturation**，唔需要 shader 再減。

| Token | Hex | 名稱 | Layer | Role / 意義 | Saturation Override |
|-------|-----|------|-------|-------------|---------------------|
| `world_moss` | `#3E5B3A` | 深苔綠 | World | Primary ground / vegetation — Set 期出現比例最高 | Loot Drop 期間 ×0.4 |
| `world_bark` | `#5C4A36` | 暗樹皮褐 | World | Architecture / wood / rock shadow — visual weight + silhouette anchor | Loot Drop 期間 ×0.4 |
| `world_slate` | `#4A5A66` | 灰青石 | World | Cool shadow / metal / distant 山 — P2 冷靜感 | Loot Drop 期間 ×0.4 |
| `world_ash` | `#7A7468` | 灰白塵 | World | Highlight / fog / dust — World 唯一接近 neutral，做光位過渡 | Combat Climax ×1.1（slight cool shift） |
| `char_linen` | `#C9B89A` | 亞麻膚色 | Character | 皮膚、布料、leather base (S≈25%)，連接 World 同 Event | Final Boss Kill ×1.2（portrait highlight） |
| `event_amber` | `#F2A93B` | 琥珀金 | Event | HUD 主色、stat number、XP bar、interactable highlight。代表 P1「行動轉化成數字」 | 永遠 100%，不受 mood override 影響 |
| `event_white` | `#FFFFFF` | 純白爆光 | Event | Loot drop 第一 frame burst、critical hit flash、P5 鏡像時刻 reveal | 永遠 100%，0.1s 後 transition 去 rarity color |

**Key rule**: `event_amber` 同 `event_white` **只可以喺 Event Layer 用**。NPC 著黃衫會被誤讀成 interactable — 寫死入 art review checklist。

**Event Layer color leak rule（UI 邊界）**: Screen-space HUD 上嘅 amber accent（active state ≤3px，Section 7.C）係 Event Layer 嘅 UI affordance signal，**唔係** Character Layer 嘅 visual property。Rule：ambient/character colour 唔可以帶 amber；amber 只出現喺 user-actionable UI element 嘅 active state 或 stat readout。future NPC portrait 上嘅 UI element（例如 dialogue await indicator）若用 amber，必須係 HUD layer anchor，唔可以 bake 入 character sprite。

---

### 4.B Semantic Color Usage

任何 semantic meaning 都必須有 **shape + animation + (可選) audio** 至少兩個 non-color channel backup。Color 係 enhancement，唔係 primary signaling。

| Semantic | Primary Color | Hex | Shape Backup | Animation Backup | Audio Backup |
|----------|--------------|-----|--------------|-----------------|--------------|
| Damage incoming | 危險紅 | `#D94B3E` | 三角形 warning ▲ | 0.15s shake + 8Hz flash | Sharp blip 1.2kHz |
| Safe / Heal / Positive | 治癒綠 | `#6FB87A` | 十字 ✚ icon | Slow pulse 1.5Hz | Soft sine 440Hz |
| Loot — Common | 白→白 | `#FFFFFF` | 小圓 orb 8px | Single bounce | "Tink" |
| Loot — Uncommon | 白→綠 | `#6FB87A` | 中圓 orb 12px | 短 trail 0.3s | Tink + harmonic |
| Loot — Rare | 白→藍 | `#4D8FD6` | 大圓 orb 16px + 1 satellite | Trail 0.5s + sparkle | Tink + chime |
| Loot — Epic | 白→紫 | `#9B5FCC` | 大圓 orb 16px + 2 satellite + 光環 | Trail 0.8s + rotating sparkle | Tink + 3-note chime |
| Loot — Legendary | 白→橙 | `#FF8C42` | 巨圓 orb 24px + 光柱 + screen vignette | Trail 1.2s + screen shake + slowmo 0.3s | Full fanfare 3 layered notes |
| Push / Strike class | Strike 紅 | `#E85A5A` | 直線/方形 hitbox cue | 直線 dash 動畫 | Heavy thud |
| Pull / Control class | Control 紫 | `#A66BC9` | 弧線/菱形 hitbox cue | 拉扯/旋轉動畫 | Whoosh + held tone |
| Leg / Mobility class | Mobility 藍 | `#5BA8E8` | 流線/平行四邊形 hitbox cue | 滑步/軌跡殘影 | Wind / quick whoosh |
| Progress / Growth (P5) | Amber-gold | `#F2A93B` | 上升箭頭 ▲ + 數字 tick | Number count-up 0.5s | Rising 3-note motif |

**重要設計 note**:
- 危險紅 `#D94B3E` 同 Strike 紅 `#E85A5A` 刻意分開（深淺差異 + shape backup 區分：warning = ▲，skill = 直線/方形）
- Rarity ladder **唔用 red**（避免同 damage 撞）。Legendary 用橙 `#FF8C42` 而唔係紅
- Player class color 同 enemy color 共用一套：紅敵人 = Push family，紫敵人 = Pull family，藍敵人 = Leg family

---

### 4.C Colorblind Safety

| Risk pair | 影響人口 | 撞色情境 | 補救機制 |
|-----------|---------|---------|---------|
| 危險紅 vs 治癒綠 | Deuteranopia ~6% 男性 | 戰鬥中同屏出現 | Shape: 危險 = ▲，治癒 = ✚。Animation: 危險 8Hz，治癒 1.5Hz（頻率差 5×）。Brightness: V ratio ≈1.18× |
| Legendary 橙 vs 危險紅 | Protanopia ~1% 男性 | Boss 戰時 loot drop 同 warning 同屏 | Shape: Legendary = 圓 24px + 光柱；damage = ▲ ≤12px。Animation: Legendary 有 slowmo 0.3s，damage 冇（unambiguous channel）。Audio: 三層 fanfare vs 單一 blip |
| Strike 紅 vs Control 紫 | Tritanopia ~0.01% | Skill family 識別 | Shape: Strike = 直線/方形；Control = 弧線/菱形（shape 完全唔同）。Animation: Strike dash，Control 旋轉（motion vector 完全唔同） |
| Loot 綠 vs 藍 | Deuteranopia + low contrast | Uncommon vs Rare 區分 | Size: 12px vs 16px（33% 大過）。Satellite: 無 vs 1 個。Audio: harmonic vs chime（不同 instrument） |
| Loot 藍 vs 紫 | Tritanopia | Rare vs Epic 區分 | Satellite: 1 vs 2 個 + 光環。Audio: 1-note vs 3-note chime |

**QA Protocol**: 每個 build 嘅 critical scene（combat、loot drop、boss intro）export 一張 desaturated screenshot。所有 gameplay-critical info 必須喺黑白下 readable。由 `qa-tester` 加入 regression suite。

---

### 4.D UI Palette

| Token | Hex | 用途 | S | V |
|-------|-----|------|---|---|
| `ui_amber_primary` | `#F2A93B` | Stat number、XP bar fill、active highlight | 76% | 95% |
| `ui_amber_dim` | `#A87526` | Inactive HUD、tooltip border、disabled icon | 76% | 66% |
| `ui_ink_bg` | `#1A1D24` | HUD panel 背景、menu base | 24% | 14% |
| `ui_ink_mid` | `#2D323D` | Panel 中層、separator、button rest | 20% | 24% |
| `ui_ink_hi` | `#4A5260` | Panel highlight、button hover、focus ring | 18% | 38% |
| `ui_text_primary` | `#F5EFE0` | 主要文字（warm white，輕微 amber tint） | 10% | 96% |
| `ui_text_dim` | `#9A958A` | 次要文字、disabled text | 8% | 60% |

**Key notes**:
- `event_amber` = `ui_amber_primary` 同一 hex（HUD amber = Event Layer amber，semantic 一致）
- `ui_amber_dim` 係 **brightness-reduced**，唔係 desaturated（保留 amber semantic identity）
- Text 用 warm white `#F5EFE0`，唔用 pure white（pure white reserved for loot burst）
- `ui_ink_*` 三層提供 HUD panel depth（Godot: `StyleBoxFlat` fill/inner/outer border）

---

### 4.E Per-Mood State Saturation Override Rules

`MoodController.gd` autoload 根據 game state event 切換 saturation 參數：

| Mood State | World Sat Mult | Character Sat Mult | Event Sat Mult | Color Temp (K) | Transition Duration | 觸發 Event |
|------------|---------------|-------------------|---------------|----------------|--------------------|-----------| 
| **During Set** (default) | 1.00 | 1.00 | 1.00 | 3800 | — | `gym_set_started` |
| **Exercise Switch** | 1.00 → 1.05 | 1.00 | 1.00 → 1.10 | 3800 → 5000 | 0.8s ease-in-out | `exercise_switched` |
| **Combat Climax** | 1.10 | 1.15 | 1.20 | 5000 → 6500 | 0.4s ease-out | `combat_climax_entered` |
> **Combat Climax Duration Clarification**：呢度嘅 0.4s 係 saturation shader transition 嘅 ramp-up 時間；Section 2.1 嘅「<2s」係整個 ability 動畫 + VFX 持續時長（唔係 shader duration）。兩個數字唔衝突，一個係 visual effect transition，一個係 gameplay moment 長度。
| **Loot Drop Burst** (0–0.15s) | 0.40 | 0.60 | 1.50 (overdrive) | 6500 → 2700 | 0.15s instant (TRANS_EXPO) | `loot_dropped` frame 0 |
| **Loot Drop Settle** (0.15–1.2s) | 0.40 | 0.80 | 1.20 | 2700 | 1.05s ease-out | `loot_dropped` post-burst |
| **Loot Drop Recover** (1.2–2.0s) | 0.40 → 1.00 | 0.80 → 1.00 | 1.20 → 1.00 | 2700 → 3800 | 0.8s ease-in | `loot_resolved` |
| **Final Boss Kill** | 0.70 | 1.20 | 1.00 | 6500 → 5500 | 1.5s slow ease (TRANS_SINE) | `boss_killed` |
| **Menu** | 0.85 | 0.85 | 1.00 | 5000 | 0.3s | `menu_opened` |

**Godot implementation notes**:
- **Per-layer shader approach**（推薦）：World Layer 用獨立 `CanvasLayer` + `CanvasItemMaterial` shader，uniform `world_saturation: float` 由 `MoodController` tween。避免 `Environment.adjustment_saturation` global 影響 HUD。
- **Event Sat Mult > 1.0**：Loot Drop Burst 嗰陣用 additive `CanvasItemMaterial` blend mode 做 HDR bloom 效果，唔係真係改 saturation value 超過 1.0（會 clip）。
- **Color temp simulation**：Compatibility renderer 用 warm tint overlay `Color(#F2A93B)` × 0.08 alpha（暖）/ cool tint `Color(#A8C8E8)` × 0.08 alpha（冷）做 approximation。Exact shader 由 `technical-artist` 實作。
- **Loot Drop 三階段總時長 2.0s**：0.15s 爆光（surprise）+ 1.05s settle（睇清楚 rarity）+ 0.8s recover（返正常）= P3 dopamine spike formula。

---

## 5. Character Design Direction

### 5.A Player Avatar Design Direction

**Visual Archetype**: Mirror Hero avatar 係「**健身房凡人**蛻變成**神話原型**」嘅視覺旅程。Tier 1 唔係英雄，係剛剛踏入 gym 嘅普通人；Tier 3 先至到「神祇 / 圖騰」級別。直接服務 **P1 真身真力**（你練幾多就變幾多）同 **P5 鏡像時刻**（最終照鏡見到嘅，係你自己嘅神化版本）。

**Tier Distinguishing Features**:

| Tier | Costume | 武器姿態 | Body Language |
|------|---------|---------|---------------|
| Tier 1 (egg-down 2.5:1) | 短袖 T-shirt + 運動短褲，char_linen S ≈20% | 武器低垂/拖地，似負擔多過工具 | 微駝背，步幅細 |
| Tier 2 (hourglass 3:1) | 加 vest/護腕/綁腿，linen S 30%，武器握把加 skill family color accent | 武器側持/平舉，平衡開始穩 | 挺胸，步幅闊 |
| Tier 3 (triangle-up 3.5:1) | Cape/圖騰披肩/紋身，linen S 40% + skill family color flow 入 costume trim | 武器高舉過頭/反手 grip，似武器係身體延伸 | 微仰首，gait 帶 swagger |

**Expression / Pose Style**: Pixel art 16-32px 唔可能做面部細節，全部 expression 靠 silhouette + pose 表達。**「剪影誇張，內部克制」**原則 — 外輪廓 push 到接近 caricature（Tier 3 肩寬可去到 head 嘅 3 倍），但內部 shading 只用 2-3 個 tone，唔加面部 micro-expression。

**LOD Philosophy**: Game camera distance（sprite ≈ 螢幕 8-12% 高度）下，**保留**：silhouette 外輪廓、武器 scale、skill family color accent、Tier-defining costume element（cape/vest）。**捨棄**：面部五官、衣服 fold detail、武器紋飾。

**Design Test**: 將 sprite 縮到 32×64px 截圖，遮住 80% 內部 detail，仍能一眼分出 tier。

---

### 5.B Enemy Type Design Rules

| Type | Visual Identity | Family Resemblance Rule |
|------|----------------|------------------------|
| Push（橫矩形） | 厚重盔甲/厚皮，Silhouette width:height = **2:1**（flat 扁），盔甲覆蓋 ≥60% silhouette area；Base color: `world_bark #5C4A36` + `world_ash #7A7468` highlight；動作 timing: core action 4f，每 frame hold ≥3 frames（weighty feel）| 同 family 共用「厚」motif — 同一塊厚墊 asset 重用 3 次 |
| Pull（倒 V） | 觸手/鎖鏈/鈎爪，Silhouette width:height = **1:2**（tall 高）；Base color: `world_slate #4A5A66` + cool tint 10%；粒子拖尾 0.5s（長）；動作 timing: 4f animation 每 frame hold 1 frame（jerky = no hold = immediate next frame）| 同 family 共用「鈎」motif — 鈎/鏈/觸鬚都係 silhouette 上同一個 hook curve |
| Leg（倒梯形） | 強壯下肢 + 簡單上身，Silhouette width:height = **1.5:1**，下盤（>=60% height）明顯闊過上盤；Base color: `world_moss #3E5B3A` + warm orange `#B86040` 10% tint；動作 timing: 4f，anticipation 2f + explosive 1f + recovery 1f（= speed burst）| 同 family 共用「腳踏實地」motif — sprite 底部接近螢幕 1px，無浮空 |

**Visual Hierarchy（regular → mini-boss → final boss）**:
1. **Regular enemy**: 1× scale，silhouette primitive 純粹，family color accent 5% 面積
2. **Mini-boss**: 1.4× scale，silhouette 加 1 個 break feature，family color accent 升到 15% + 持續「骯髒粒子」aura
3. **Final boss**: player 鏡像翻轉 × 2.2×，反用 player char_linen base 但 S 推到 60-70%（過飽和警示），粒子量 ×3 — 服務 **P5 鏡像時刻**

**Design Test**: 三隻同 family 嘅 enemy 排成一行，玩家應能一眼分 tier（regular/mini/final），同時感覺佢哋係「一家人」。

---

### 5.C NPC / Non-combat Character Direction

**MVP: No NPC — rule reserved for v0.2+**
**Asset budget for v0.1 = 0 NPC sprites / 0 NPC animations.** 呢個係 intentional scope cut，唔係 oversight。

預留 rule（v0.2+ 啟動時 reference）：NPC 用 egg-down 2.5:1 但 char_linen S < 15%（接近灰），無 skill family color accent，無「骯髒粒子」。Head 比例放大（cartoon 4:1 head-to-body）作 friendly read，呼應 **P2 無壓力陪伴**。

---

### 5.D Character Animation Direction

**Animation Frame Counts**:
- Idle: 2 frames
- Core action (walk/run): 4 frames
- Skill: 6-8 frames（2 anticipation + 1 hold + 1 strike + 2 recovery 最小結構）
- Off-screen unit: animation paused

**「一眼睇出係咩 ability」Keyframe Rule**（**P4 服務**）:
- 每個 skill 必須有 1 個 signature silhouette frame（hold ≥ 100ms），截圖即認
- Strike skill: 武器最高點/最遠延伸，紅粒子 radial burst
- Control skill: avatar 雙臂展開，紫粒子 ring expand
- Mobility skill: avatar 騰空/軌跡明顯，藍粒子 trail

**「乾淨剪影 + 骯髒粒子」Animation Rule**: 粒子全部集中喺 hold + strike frame emit，anticipation / recovery 保持 silhouette 乾淨。

**LOD（mobile web 60fps）**: 同屏最多 8 個 character animation playing。Regular enemy 可降至 3 frames，mini-boss 保 4-6，player + final boss 保 8。

**Design Test**: 將任何一個 skill animation 截圖 signature frame，貼比未玩過嘅人睇，佢應該能講出「呢個係攻擊 / 控制 / 移動」。

---

## 6. Environment Design Language

### 6.A Architectural Style / World Identity

Mirror Hero 嘅 world 係 **gym session 嘅心理投影地圖**——玩家現實做 workout，game world 同步推進。Environment 唔係一個獨立 fantasy world，而係**「身體狀態嘅外化地景」**。唔做 explicit gym echo（唔會有啞鈴造型嘅石頭），而係用 **loose metaphor**——將 workout 嘅「物理感」翻譯成地形質感。

**Architectural Style: "Worn Wilderness"** — 半廢墟、半原野嘅混合。無高聳城堡，無 hi-fi industrial。主導 elements：
- 風化嘅石塊平台（angular，platform 用途）
- 雜亂生長嘅苔蘚同灌木（organic，background 用途）
- 偶爾出現嘅人造遺跡（破碎石柱、倒塌木橋）——暗示「曾經有人到過」

人造 vs 自然比例 = **30% / 70%**——人造痕跡係 storytelling hook，但唔可以蓋過 organic background（避免 P2「無壓力」被 cold industrial tone 破壞）。

**Design Test**: 隨意 screenshot 一個 environment frame，蒙住所有 character/UI，問：「呢個地方似唔似一個你會喺度坐低抖氣嘅地方？」如果答案係「似戰場/似 boss room」，即係 fail P2。

---

### 6.B Texture Philosophy

| Texture Layer | 密度規則 | Palette Anchor | Pillar |
|--------------|---------|---------------|--------|
| Platform top (1-2px band) | 高密度：每 4px 一個 pixel detail（裂紋、邊角磨損） | `world_slate` 為主 | P5（剪影清晰） |
| Platform body | 中密度：每 8px 一個 detail cluster | `world_bark` / `world_slate` mix | P2（讀得舒服） |
| Ground tile（walkable） | 中密度，detail 用 −10% value variant | `world_moss` 為主 | P4（職業 zone 變奏） |
| Background wall / cliff | 低密度：大塊 solid color + 偶爾 organic break | `world_moss` desat | P2（唔搶 attention） |
| Sky / ceiling void | 極低密度：純 gradient 或 single tone | `world_ash` | P5（鏡像背景空間） |

**核心 rule**：**「越近 player 越多 detail，越遠越 solid」**——pixel art 嘅 depth illusion，同 shape language 對齊（platform = angular 高 detail / background = organic 低 detail）。

**唔做 painted blend**：所有 pixel boundary 必須 hard edge，唔可以用 anti-alias gradient 假扮 painted。原因：(1) LPC asset reuse 全部係 hard-edge style；(2) draw call 預算 200，texture atlas 必須緊湊。

**Design Test**: Zoom 200% 檢查 platform top 1-2px band。如果 platform 邊緣 detail 密度同 background cliff 一樣，即係 fail——player 腳下唔夠 read。

---

### 6.C Prop Density Rules

**Sparse 主導**——MVP zone baseline 係**每 64×64 tile 區域 0-2 個 prop**（唔係 1-4）。Player 喺做 workout，視線週期性離開 screen，返嚟視野要立即 read 到 platform + character，唔可以被 prop 蓋過（P2）。

| Layer | Prop Density (per 64×64) | Saturation Rule | 行為 |
|-------|-------------------------|----------------|------|
| Foreground（player layer） | **0 prop** | — | Player + platform only，剪影必須乾淨 |
| Midground（1-2 tile 深） | 1-2 prop max | 跟已鎖定 −30% world palette | Static，唔郁，唔閃 |
| Background（3+ tile 深） | 2-3 prop OK | 額外 −10% value | 可以有 organic break，但唔可以有對比色 |

**Ambient vs Attention-grabbing 規則**：prop 嘅 value contrast 同 background 差距**必須 ≤ 15%**。超過即係 attention-grabbing prop，必須移走或 desaturate。Exception：loot 本身（P3，要搶眼）——但 environment prop 永遠唔係例外。

**Design Test**: 將 screenshot 轉 greyscale，眯眼睇 3 秒。如果有任何 environment prop 第一眼跳出嚟（唔係 character/loot），即係 fail。

---

### 6.D Environmental Storytelling Guidelines

唔靠 text，靠**三層 visual signal**：
1. **地形質感 = workout type metaphor**（loose，唔 literal）
2. **風化程度 = 距離初始點嘅遠近**（越深越破舊，暗示 progression）
3. **Organic vs 人造比例變化 = zone identity**（每個 zone 比例唔同）

**MVP Zone — "Quiet Grove"（靜謐林地）**:
- Workout type metaphor：Full-body starter zone，地形 metaphor 係**平衡**——平台高度差適中，無極端 vertical jump，無 heavy stone overhang
- Mood：黃昏 warm earth，`world_moss` 主導 70% + `world_bark` 25% + `world_slate` 5%
- Storytelling details：
  - 偶然破碎石柱（暗示「曾有英雄到過」——不解釋係邊個，留 P5 鏡像 reveal）
  - 苔蘚生長方向統一（暗示有風/時間流動，ambient 唔搶眼）
  - 平台邊緣磨損程度由淺入深（player 進入越深越破舊）

**禁止**：唔放招牌、唔放可讀文字、唔放敵人屍體（P2 violation）、**唔放 explicit gym reference**（dumbbell / weight plate 造型 props 禁止）。

**Design Test**: 俾未玩過嘅人睇 3 張 screenshot，問：「呢個地方畀人嘅感覺係咩？」包含「平靜 / 探索 / 有歷史」= pass；包含「危險 / 戰鬥 / 緊張」= fail P2。

---

## 7. UI/HUD Visual Direction

### 7.A Visual Style for UI（Diegetic vs Screen-space）

Mirror Hero 嘅 UI 採用 **「Screen-space 為骨，Diegetic 為魂」** 嘅 hybrid strategy。Auto-combat gameplay 決定咗玩家絕大部分時間係「睇」多過「按」，所以 mid-set 期間 UI 必須**退讓**，唔可以同 character silhouette 爭視線。

**Screen-space HUD（mid-set 持續顯示）**:
- **無 frame、無 border、無 box** — HUD element 直接浮喺 screen edge（health/exp bar 貼底，exercise ring 貼右上），唔加裝飾性外框。Frame 會引入額外 silhouette noise，違反「乾淨剪影」rule。
- **Drop shadow 統一規範**：所有 HUD element 加 1px offset、`ui_ink_bg #1A1D24` @ 40% opacity 嘅 hard shadow（唔係 gaussian blur shadow — pixel art 唔用）。將 UI 推前半個 z-layer，但唔起到 frame 嘅 visual weight。
- **Depth 感靠 contrast**：HUD 永遠 100% flat 2D。Depth 感由 layer discipline 提供 — World −30% saturation 後，`ui_amber_primary #F2A93B` 自動「彈出」。**服務 P2（無壓力陪伴）**：玩家唔使主動 focus，HUD 自己浮現。

**Diegetic UI moments（cinematic 時刻）**:
- **Loot Drop Modal（P3 核心）**：背景 world 0.4s freeze + 額外 −50% desaturate（World 變近乎 grayscale）。Loot 圖示 100% 飽和配粒子環繞。Modal 邊框用 **pixel-illustrated 風格**——模仿「破爛布旗/鐵鏽金屬條」嘅 dirty silhouette，對應 One-Line Rule「骯髒粒子」一半。
- **Final Boss Kill Portrait（P5）**：pixel-illustrated frame，hand-drawn 質感（唔對稱，有 chip/scratch detail）。**只喺 P5 moment 出現一次**，rare = memorable。
- **Menu / Settings**：metagame layer，可較重 frame，但仍保持 amber + ink 兩色 palette。

**UI 同 World 自動分隔的三條 rule**：(1) 飽和度差異（HUD 100% vs World 70%）、(2) Shadow offset（HUD 有 1px hard shadow，World 無）、(3) Pixel grid alignment（HUD 嚴格對齊 16px grid，World 可 sub-pixel scroll）。

---

### 7.B Typography Direction

**Bitmap pixel font 為 primary，TTF 為 fallback**。Pixel art 同 TTF 混用會即刻破壞 visual cohesion — anti-aliased 軟邊同 pixel art 硬邊衝突。

**Font 推薦**：base font **m5x7** 或 **m6x11**（free pixel font）；中文 body 用 **Zpix 12px**（pixel-style 中文 bitmap font）。唔好混用 — 一個 screen 唔可以同時出現 pixel 英文同 system 預設 TTF 中文。

| Tier | Size | Color | 用途 |
|------|------|-------|------|
| H1 Header | 11px (m6x11) + 1px ink shadow | `ui_text_primary` | Modal title、boss name |
| Body | 7px (m5x7) | `ui_text_primary` | Tooltip、description |
| Number (HUD) | 7px monospace + 1px shadow | `ui_amber_primary` | HP「45/100」、stat |
| Dim / meta | 7px | `ui_text_dim` | Timestamp、secondary info |

---

### 7.C Iconography Style

**Solid-fill silhouette + 1px ink outline，無 inner detail line** — 直接從 One-Line Rule「乾淨剪影」extend，icon 本質就係 micro-silhouette。

**16×16 icon 辨識度 rule**: 必須喺 8×8 thumbnail downscale 後仍可辨認（squint test）。Pixel coverage 40-70%（<40% 太空，>70% 太實）。Active 狀態加 amber `#F2A93B` 點綴 ≤3px。

**Skill family icon 設計方向**（服務 P4）:

| Family | Silhouette Archetype | 視覺 Cue |
|--------|---------------------|---------|
| Strike | 對角線、銳角、向前突出 | 拳頭/劍尖/衝擊 |
| Control | 對稱、向外輻射、圓弧 | 鎖鏈/力場/抓握 |
| Mobility | 流線、向上/向側、留 negative space | 風/腳印/軌跡 |

呢個 archetype rule 確保玩家**唔使識字都讀到 skill family**（P2 accessibility）。

---

### 7.D UI Animation Feel

整體 animation personality：**Snap + Settle**（唔用 bounce — 太可愛，唔夾 dirty particle 嘅 grounded tone）。

| Animation | Curve | Duration | Pillar |
|-----------|-------|----------|--------|
| HUD element appear | ease-out cubic | 120ms | P2 — 唔搶 attention |
| HP/EXP bar fill | ease-out quad | 200ms | P1 — 反饋真實 |
| Number ticker | step (每 33ms +1) | 變動量決定 | P1 — 數字「跳」感 |
| Damage number pop | overshoot 1.1× → settle | 250ms | P3 — 爽感 |
| Loot reveal modal | freeze 0.4s → scale 0.8→1.0 elastic-light → particle burst | 1.2s 總長 | P3 — 開箱高潮 |
| Cooldown sweep | linear 順時針扇形 | = skill cooldown | P2 — 可預測 |

**Loot reveal 係 game 最 dramatic UI moment**：World freeze + desaturate 同時，loot icon 由 modal 中心 0.8× elastic-light overshoot 到 1.0×，同步觸發 rarity 粒子 burst。Rarity 越高，freeze 時間越長（COMMON 0.2s → LEGENDARY 0.8s）——令玩家**physically 感受稀有度**（P3 核心）。

**Number ticker 用 step function**（唔係 smooth lerp）：pixel art game 嘅 number 應該「跳」唔應該「滑」，每個 frame 都係 valid integer，呼應 pixel grid discipline。

> **UX Alignment Note**: ux-designer 需要 review 呢節嘅 touch target sizes（minimum 44×44px on mobile）、input routing（screen-space HUD 唔需要 touch interaction — 玩家唔 mid-set tap HUD），以及 accessibility 確認。呢個 review 將喺 `/ux-design` skill 執行。

---

## 8. Asset Standards

> 呢個 section 係 binding standard。任何 asset import 前必須通過 `tools/ci/asset_validator.gd` 檢查（見 D.4）。違反任何 **HARD** limit 係 block PR merge 嘅 condition。

### 8.A File Format Standards

| Asset 類型 | Format | 理由 | 違反後果 |
|-----------|--------|------|---------|
| Sprite (character/prop) | **PNG-8 indexed** (≤256 colors) | LPC palette ≤96 colors；PNG-8 比 PNG-24 細 60-70%，直接減 WASM bundle | bundle >50MB → web load 超時 |
| Sprite sheet (animation) | **Single PNG, power-of-2 dimensions** (256/512/1024) | Godot `AtlasTexture` 共用 1 個 GPU texture → draw call batch | non-PO2 觸發 NPOT fallback，draw call 翻倍 |
| Tilemap source | **Single PNG atlas, 16px tile aligned** | TileSet 共用 source → 1 draw call per layer | 每個 tile 獨立 texture = draw call >200 **(HARD)** |
| UI element | **PNG-24 (with alpha)** | UI 需要 alpha gradient；PNG-8 dither edge 破壞 silhouette-first | — |
| Audio (SFX) | **OGG Vorbis q4 (~96 kbps mono)** | Godot 4.6 web `AudioStreamOggVorbis` hardware-accelerated；WAV 體積 ×10 | WAV 入 bundle → 超 50MB |
| Audio (BGM) | **OGG Vorbis q5 stereo, ≤2MB per loop** | Streaming friendly；MP3 在 Safari 有 latency issue | — |

**Naming convention (HARD)**: 全部 `snake_case`，跟 entity registry。
- Sprite: `<entity>_<state>_<dir>.png` → `hero_idle_south.png`
- Atlas: `<entity>_sheet.png` + `<entity>_sheet.tres`
- Particle: `vfx_<event>_<variant>.tres` → `vfx_loot_drop_epic.tres`（ADR-0001 一致）
- License: 每個 LPC-derived asset 附 `<filename>.license.md`（LPC = CC-BY-SA 3.0 + GPL 3.0）**(HARD)**

---

### 8.B Texture Resolution Tiers + LOD

| 用途 | Base Size | Desktop/Mobile | 理由 |
|-----|---------|---------------|------|
| Character (hero) | **32×32 px** | 32×32 native | LPC base size；downscale 破壞 pixel grid |
| Enemy / boss | 32×32 至 **64×64 px** | native | Boss silhouette 需要 readable |
| Environment tile | **16×16 px** | 16×16 native | Tilemap 對齊；mobile 唔降 tile，改降 layer 數 |
| UI icon | **64×64 px** export (design at 32×32) | Desktop 64 / Mobile 32 | UI 可雙 tier |
| UI panel (9-slice) | **128×128 max** | 128×128 | 9-slice corner 唔 scale |
| Atlas texture **(HARD)** | — | **2048×2048 max** | mobile Safari WebGL2 `MAX_TEXTURE_SIZE` safe floor；4096 在舊 iPad VRAM allocation fail |

**Mobile 0.5× 降級策略**（pixel art **唔降 sprite resolution**）:
1. 減 particle count（0.5× multiplier，≤100 active）
2. 減 parallax layer 數（3 → 1）
3. Disable post-process glow（Compatibility renderer 仍 expensive）

---

### 8.C Sprite 同 Frame Budget

| Budget 項目 | Limit | 計算依據 | 違反後果 |
|-----------|-------|---------|---------|
| 同屏 visible Sprite2D **(HARD)** | **≤150** | 200 draw call - 50 (UI/HUD/tilemap reserved) | fps <60，CI block |
| Sprite count sub-breakdown | — | Entities (player+enemies): ≤40 / Projectiles + ability VFX sprites: ≤20 / Tilemap visible chunks: ≤60 / HUD elements: ≤15 / Misc (props, effects): ≤15 = 150 total | Sub-caps 唔係 HARD，但超過任何一組需要 lead sign-off |
| Animation frame per animation | **≤16 frames** | LPC walk cycle 8 frames，attack 6 frames | atlas 過大 + 工作量爆炸 |
| AnimationPlayer track per scene | **≤32** | Godot 4.6 animation tree 性能 sweet spot | tween 計算卡頓 |
| Atlas memory per scene **(HARD)** | **≤64 MB VRAM** | 512MB ceiling - 200MB engine/audio/code - 200MB safety | mobile Safari OOM crash |
| 單一 PNG file size | **≤1 MB** | 50MB bundle / ~50 sprite sheets | bundle 超 50MB |
| Audio SFX per clip | **≤100 KB** | OGG q4 mono @ 1s ≈ 12KB | 同上 |
| Audio BGM per loop | **≤2 MB** | OGG q5 stereo @ 60s ≈ 1.8MB | 同上 |

---

### 8.D Import Settings + Pipeline Rules

**D.1 Godot 4.6 Import Preset（Pixel Art，HARD）**

```
Filter: Nearest              # Linear filter = pixel art 糊 → reject
Mipmaps: Off                 # 2D 唔需要，浪費 33% VRAM
Compression Mode: Lossless   # VRAM Compressed 在 Web Compatibility 有 artifact
Fix Alpha Border: On         # 防止 atlas bleeding
```

Preset 存於 `assets/.godot_import_presets/pixel_art.tres`，所有 sprite import 必須引用。

**D.2 LPC Asset Pipeline**

```
LPC download (Universal Sprite Sheet generator)
  → 工具：LPC Spritesheet Generator (web tool, free)
  → 輸出：32×32 character sheet PNG
  → Step 1: Aseprite ($20 one-time) — 拆分 + repalette 至 Mirror Hero 6-color palette
  → Step 2: TexturePacker (free tier) — 重新 atlas，PO2 align
  → Step 3: 複製到 assets/sprites/<category>/，套用 pixel_art.tres preset
  → Step 4: 寫對應 .tres AtlasTexture region 定義 + <filename>.license.md
```

**D.3 Particle `.tres` Organization（ADR-0001 一致）**

```
assets/vfx/particles/
  ├── vfx_loot_drop_common.tres
  ├── vfx_loot_drop_epic.tres
  ├── vfx_hit_impact.tres
  └── _shared_materials/
       └── particle_shader_additive.tres
```

**`CPUParticles2D` 嚴禁使用（HARD）** — Compatibility renderer 在 mobile 性能差 ×3（ADR-0001 cross-reference：GPUParticles2D only，via `particle_system_wrapper.gd` autoload）。Particle `.tres` 必須 declare `amount` field，總和 ≤200（desktop）/ ≤100（mobile）。

**D.4 CI/CD Asset Validation（`tools/ci/asset_validator.gd`）**

每個 PR 自動 check：

| Check | HARD block / Warning |
|-------|---------------------|
| PNG dimension power-of-2 | HARD |
| Filename snake_case + entity registry 一致 | HARD |
| Atlas ≤2048×2048 | HARD |
| Particle amount 總和 ≤200 | HARD |
| 無 CPUParticles2D reference | HARD |
| PNG file size ≤1MB | Warning + lead sign-off |
| LPC-derived asset 有 .license.md | Warning + lead sign-off |
| Import preset = pixel_art.tres | Warning + lead sign-off |
| WASM bundle simulation <50MB | Warning + lead sign-off |

---

## 9. Reference Direction

呢個 reference set 嘅策略係「**design reference 同 art reference 分開**」——game-concept.md 列嘅 5 個（MapleStory/DNF/Hades/Habitica/Zwift）主要 inform gameplay loop 同 player fantasy，但實際 visual execution 要從更窄、更具體嘅 indie pixel art 同 motion design 提取。每個 reference 只取**一樣具體嘢**，絕不整體模仿，咁先可以避免「四不像」hybrid 風格。所有 reference 加埋服務一條核心 visual rule：**乾淨剪影 + 骯髒粒子**——sprite 要 readable，VFX 要 dirty 同有重量。

| Reference | 具體 Visual Element 提取 | 明確要 AVOID / DIVERGE | Pillar 服務 |
|-----------|------------------------|----------------------|------------|
| **MapleStory**（Nexon, 2003）| **角色 silhouette 比例**：egg-shaped head 約佔總高 40%，body 60%，hand/foot 用 chunky 2-3px block 表達——確保 16-32px 細 sprite 喺 Web zoom-out 仍然 readable | **唔取**佢嘅 over-saturated 糖果色（pink/cyan/yellow 並用）同密集 NPC town 構圖；Mirror Hero 嘅 World 係 sparse earth tones，唔係 carnival | P2 Readability |
| **Dead Cells**（Motion Twin, 2018）| **Hit pause + screen freeze 4-6 frame**：重擊瞬間整個畫面凍結，再配 white flash 1 frame，先放 particle storm——令 16px sprite 打得「重」 | **唔取**佢嘅 hand-drawn rim lighting（每個 sprite 有 backlight glow）——Mirror Hero 用 flat shading，rim light 留畀 Event moment | P3 Impact Feel |
| **Noita**（Nolla Games, 2020）| **粒子個別 lifetime + gravity + fade curve**：唔係 uniform sheet；爆擊時 30-60 particle 各自飛散，部分留低做 ground decal 2-3 秒 | **唔取**佢嘅 falling-sand 全屏破壞——淨係喺 hit/loot moment 用 dirty particle，background 保持 static | P3 Particle Budget Rule |
| **Hyper Light Drifter**（Heart Machine, 2016）| **UI 留白比例**：HUD 元素佔屏幕邊緣 <15%，corner-anchored，中央 70% 完全留畀 gameplay；chunky 6-8px pixel font，無 border 無 panel frame | **唔取**佢嘅 neon pink/cyan dystopia palette；Mirror Hero HUD 用 amber #F2A93B + white，warm 而非 cold | P2 Frameless HUD |
| **《幽靈公主》森林戲份**（Studio Ghibli）| **「worn nature」色溫**：moss green #3E5B3A 同 earth brown #5C4A36 互補，sky 用 desaturated steel blue #4A5A66；陽光透樹葉用 warm 偏黃，唔係純白 | **唔取** Ghibli 嘅 painterly 質感同 hand-drawn line——呢個 reference 純粹係**色卡來源**，唔係 rendering style | P2 World Mood |
| **Celeste**（Maddy Makes Games, 2018）| **Idle animation secondary motion**：角色 idle 時頭髮/衣袖/披風有 2-3px sway（8-12 frame loop），令 16px sprite 有「生命感」 | **唔取**佢嘅 mountaineering platformer level layout 同 vertical camera——Mirror Hero 係 side-scroll combat arena | P5 Avatar Life |
| **Loop Hero**（Four Quarters, 2021）| **Loot rarity 靠 border thickness + corner ornament density**：common = 1px border 無 ornament，legendary = 3px border + 四角 filigree | **唔取**佢嘅 monochrome green CRT 美術——Mirror Hero loot 用 white→green→blue→purple→orange 五階 hue shift | P3 Loot Clarity |

**Reference 查找 guide**：當 art team 有疑問「應該點畫」嘅時候，先查呢個 table：
- Sprite 比例 → MapleStory
- Hit feel / timing → Dead Cells
- Particle behavior → Noita
- HUD layout → Hyper Light Drifter
- World color palette → 《幽靈公主》
- Idle animation → Celeste
- Loot card rarity → Loop Hero

**唔好同時參考兩個 reference 做同一個 element**，否則必然撞風格。
