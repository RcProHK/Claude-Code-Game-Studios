# Sprite Pipeline Quickstart — 由零到「個 scene 有真角色」

> 為 first-time game dev 寫嘅實操指南(Windows + Godot 4.6.3)。
> 正規 binding standard 喺 `design/art/art-bible.md` §8;呢度係**操作化**版本,先求快見到嘢。
> 目標:換走 playable slice 入面個程序生成嘅人形,變成一隻真 pixel-art 角色。

---

## 先搞清楚:兩條 Track(唔好溝亂)

| | Track 1 — Prototype(先做呢個) | Track 2 — Production(之後) |
|---|---|---|
| 目的 | 最快喺 `PlayableSlice.tscn` 睇到真角色,驗 watchability | 真正 ship 落 game 嘅 asset |
| 放邊 | `prototypes/vertical-slice/art/` | `assets/sprites/avatar/` |
| 標準 | **放寬**(prototype-code rule)— 唔使 PO2、唔過 asset_validator | **嚴格** — PO2 / pixel_art preset / asset_validator 5 條 HARD / `.license.md` |
| PO2 煩惱 | ❌ 唔使理 | ✅ 要(256/512/1024) |
| 邊個接線 | **我**(畀我個 PNG 就得) | 我接落 #26 AvatarRenderer |

**強烈建議先行 Track 1** —— 你想睇嘅係「換咗真 sprite 之後似唔似 game / mid-set 一眼睇唔睇得明」,呢個 prototype 就答到,唔使一開始就同 PO2 / atlas budget 搏鬥。

---

## Track 1 — 最快路(~20 分鐘,全免費,零安裝)

### Step 1 — 整一隻 LPC 角色(免費 web tool,唔使裝嘢)
1. 去 **LPC Spritesheet Generator**:https://sanderfrenken.github.io/Universal-LPC-Spritesheet-Character-Generator/
2. 左邊揀部件砌一隻角色(body / 髮 / 衫 / 武器)。我哋第一隻做 **avatar T1 STRIKE = 啱啱入 gym 嘅普通人**(art-bible §5.A):
   - 簡單運動裝(短袖 T + 短褲),唔好太多裝飾(T1 = 樸素)
   - 想佢揸把近身武器(STRIKE class)就揀個 weapon
3. 撳 **Download** → 落到一張 PNG sprite sheet(LPC 標準格式,已經係 pixel art + 透明背景,即用得)。

> ⚠️ License:LPC = **CC-BY-SA 3.0 / GPL**。download 個頁有個「credits」list,**copy 低**(production 階段每個 asset 要附 `.license.md`,prototype 階段你只要留住份 credit text)。

### Step 2 — 放入 prototype art 資料夾
1. 喺 `prototypes/vertical-slice/` 開個 `art/` 資料夾。
2. 將張 sheet 改名做 `hero_strike_lpc_sheet.png`,擺入 `prototypes/vertical-slice/art/`。
   - (Track 1 唔使 PO2,唔使過 validator —— prototype 放寬)

### Step 3 — 掉個 PNG 嘅 frame 資訊畀我
LPC 標準 sheet 每格通常係 **64×64 px**,每行係一個動作(walk / idle / spellcast…)。你只要話我知:
- 張 sheet 幾多 px 闊 × 幾多 px 高(Windows 右鍵 → 內容 → 詳細資料,或 Godot import dock 睇得到)
- 你想用邊一行做 idle / 邊一行做 walk(或者你唔知就話我知,我用 LPC 標準 layout 預設)

**然後我幫你做晒呢啲(你唔使寫 code):**
- 喺 `playable_slice.gd` 用 `AtlasTexture` / `SpriteFrames` 切出 idle + walk frames
- 換走個程序人形,變成你張真 sheet 嘅 `AnimatedSprite2D`
- 接 idle 2-frame loop + 行 set 時 play walk
- F5 你就睇到真角色喺度郁

### Step 4 — F5 睇結果
換完之後撳 F5,你應該見到:一隻真 pixel-art 角色企喺地面、idle 緊、做 workout 時 play 動畫、爆裝時跳一下。**呢個就答到「似唔似 game」+「mid-set 一眼睇唔睇得明」。**

---

## Track 2 — Production 正規路(之後先做,art-bible §8.D)

當你滿意 prototype、要做真 ship asset:

1. **整 frame**:LPC generator → 用 **Aseprite**($20 一次性,pixel art 業界標準)或免費 **Photopea**(web,似 Photoshop)拆 frame + repalette 去 Mirror Hero 6-color palette(art-bible §4)。
2. **砌 atlas**:用 **TexturePacker**(免費 tier)或手動,排成 **power-of-2 尺寸**(256/512/1024)—— 呢個係 asset_validator HARD check #1。
3. **命名**(art-bible §8.A,HARD):
   - 單 frame:`hero_idle_south.png`(`<entity>_<state>_<dir>`)
   - atlas:`hero_t1_strike_sheet.png` + 對應 `.tres`
4. **放** `assets/sprites/avatar/`,每個 LPC-derived asset 附 `<filename>.license.md`(CC-BY-SA credit)。
5. **Import 設定**(art-bible §8.D D.1 / `assets/.godot_import_presets/pixel_art.tres`):
   | 設定 | 值 | 點解 |
   |------|-----|------|
   | Filter | **Nearest** | Linear = pixel art 糊 |
   | Mipmaps | **Off** | 2D 唔需要,慳 33% VRAM |
   | Compression | **Lossless** | Web Compatibility VRAM-compress 有 artifact |
   | Fix Alpha Border | **On** | 防 atlas bleeding |
   > Godot 入面:揀張 PNG → Import dock → 設上面 4 個值 → 「Preset ▾ → Save as Default for PNG」(之後每張自動跟)。
6. **驗**:`godot --headless --path . --script tools/ci/asset_validator.gd` → 要 **EXIT 0 / 0 HARD**。
   - 5 條 HARD:PO2 / snake_case / atlas≤2048 / particle amount≤200 / 無 CPUParticles2D
7. **接線**:畀我,我接落 `AvatarRenderer.register_sprite()` + `derive_sprite_frames()`(#26 render-only seam),唔再用 prototype 嘅 placeholder。
8. **更新** `design/registry/entities.yaml` `entities:` 把呢個 entity 入 registry,然後我哋可以將 `asset_validator` 嘅 entity-registry check 由 SKIPPED 升做 HARD。

---

## 邊樣係你、邊樣係我

| 你做(美術創作,我做唔到) | 我做(code / 接線 / 驗證) |
|---|---|
| 揀 LPC 部件砌角色、揀 palette、判斷靚唔靚 | 切 frame / 砌 SpriteFrames / AtlasTexture |
| 判斷 mid-set 一眼睇唔睇得明(silhouette) | 換走 placeholder、接 idle/walk/skill 動畫 |
| 親自 Milestone 1 playtest | 接 #26 AvatarRenderer、跑 asset_validator |

---

## 最快開始
1. 開 LPC generator 砌一隻 T1 STRIKE 角色 → download。
2. 擺 `prototypes/vertical-slice/art/hero_strike_lpc_sheet.png`。
3. 喺 chat 話我:「sheet 整好喇,XXX px 闊 YYY px 高」→ 我即刻接落個 scene。
