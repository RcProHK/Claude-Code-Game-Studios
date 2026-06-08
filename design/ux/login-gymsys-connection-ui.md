# UX Spec: Login / GymSys Connection UI(Shell)

> **Status**: APPROVED(`/ux-review` 2026-06-08,0 BLOCKING;4 ADVISORY inline 收)
> **Author**: Frank + ux-designer
> **Last Updated**: 2026-06-08
> **Platform Target**: Web(browser primary)+ Desktop(secondary)— Godot 4.6 Web Export;**Primary input: Touch**(single-tap)+ Keyboard/Mouse secondary;**Gamepad: None**
> **Journey Phase(s)**: First-boot connect / Re-login / Home-base(IDLE)/ Worst-moment honesty(banner)— **player-journey map 未存在**(Open Questions OQ-UX1)
> **Template**: UX Spec
> **GDD**: `design/gdd/login-gymsys-connection-ui.md`(REVISED + cold-verify 2026-06-08;15 Rules / 5-state FSM / G-LS-1..9)

---

> **Mandate**: 本 UX spec 交付 GDD UI Requirements 章 + UX Flag 明文 defer 落 `/ux-design` 嘅 owned deliverables ——
> **(1) login form wireframe**、**(2) banner anatomy + #20 Z5/Z6 region non-overlap pixel pin**(GDD Rule 7 已 arbitrate 讓位*方向*,本 spec 釘*pixel*)、**(3) shell IDLE 入口佈局**(#22 UXQ-2 把 entry affordance 形態 defer 落 #24)、**(4) enabled / hidden / interactive-dimmed 狀態視覺 spec**。
> GDD 係 **requirements input**;本 spec **唔覆寫 GDD mechanics**(stories cite GDD for rules/FSM/severity;cite 本 spec for layout/pixel/glance)。沿用 #20/#22 spec 嘅 GDD↔spec 邊界先例。

---

## Purpose & Player Need

#24 係 Mirror Hero 嘅**帳號連接 + 系統誠實層 shell**。佢服務四個 player goal,但情感主軸只得一個 —— **「肯認衰嘅守門人」(The Sentinel That Never Lies)**:玩家正正喺最壞時刻(斷線 / 存檔失敗 / session 過期)望住呢個 surface,所以**佢現身嘅方式塑造玩家對成個系統嘅信任**。

| 玩家想做嘅事 | 完成 sentence「玩家嚟到呢個 surface 想…」 | 冇咗會點 |
|---|---|---|
| **連接帳號開始玩** | 「…一次過連到 GymSys,之後唔好再煩我。」 | 冇 token → #2 polling 永不開始 → game 冇入口 |
| **斷線時知道進度安全** | 「…知道我啱啱練嗰組冇白費。」 | 斷線變「停咗」嘅恐慌,玩家流失 |
| **session 過期快速返去** | 「…撳一兩下就接返,唔好打斷我練緊嗰組。」 | mid-set 彈全屏 form → 違 Pillar 2 |
| **入主畫面去 character/inventory** | 「…見到自己個 avatar,撳入去睇裝備。」 | #22/#23 冇 shell 接線 |
| **登出** | 「…安心熄 app,知道嘢儲好咗。」 | 「等緊 saving 唔好走」blocking modal → 違 Pillar 2 |

**呢個 UX spec 嘅唯一天職**:令上述每一個 surface 喺**最壞時刻誠實,但用唔搶 attention 嘅方式誠實**(layout / pixel / glance 層面兌現 GDD 嘅 architectural posture)。每個 banner / status / form / drain 都要過同一個 falsifiable 問題 —— **「呢個會唔會逼玩家停 set?」必須全部答 NO**。

> 詳細 fantasy / falsifiable design test 見 GDD Player Fantasy 章(Locker-Room WiFi / Silent Corruption / Mid-Set Logout / Honest Door 四個 test)。本 spec 唔重述,只負責 layout 兌現。

---

## Player Context on Arrival

#24 冇單一「到達時刻」—— 佢係 5 個 shell state 嘅 surface 集合,每個 state 玩家嘅情境/情緒都唔同。Layout 必須對每個情境調校:

| 情境(shell state) | 何時 | 之前喺做緊咩 | 假設情緒 | 自願 / 被 send |
|---|---|---|---|---|
| **首次連接(LOGIN, first-boot)** | 第一次開 game,零 token | 啱啱裝完 / 開 URL,未見過 game | 好奇 + 輕微設定焦慮(「要唔要開戶?難唔難?」) | 被 send(boot pull-check 強制) |
| **Re-login(LOGIN, session 失效)** | token 過期 / 401 latch / 另一 tab claim | 用緊 app 或返嚟想玩 | 輕微 friction「又要登入?」— 想最快接返 | 被 send,但 **mid-workout 時 banner-defer 唔即彈**(Pillar 2) |
| **主畫面(SHELL_IDLE)** | workout 之間 / 啱開 app 有 token | 啱完一組 / 啱開 app | 平靜、想睇 avatar / 入 screen | 自願(停留 + tap 入口) |
| **斷線(DISCONNECTED_SHELL)** | gym WiFi blip,non-workout | 啱睇緊主畫面 | **需要安心** —「我啲嘢仲喺度?」 | 被 send(GSM 落 DISCONNECTED) |
| **斷線 mid-set(banner only)** | WORKOUT_ACTIVE 系跌入 DISCONNECTED | **練緊一組** | 專注 lift,**唔應該被打斷** | 被 send 但 shell **留 HIDDEN**,只 peripheral banner |
| **登出(DRAINING)** | settings 內 tap logout | 決定收工 | 想安心熄 app | 自願 |
| **壞時刻(banner overlay,任何 state)** | 存檔失敗 / 斷線 / drain 部分失敗 | 任何 | 需要誠實但唔好驚嚇 | 被 send(error signal fire) |

**對 layout 嘅直接後果**:
- **首次 vs re-login** 用同一 LOGIN form,但 re-login 行 opaque scrim 完全遮住已 render 嘅 world(context 切換明示);first-boot 純 `ui_ink_bg` 底(零 world)。
- **斷線情境**全部係「等待」唔係「停咗」—— 視覺用 dim weight(唔配 amber urgency),copy lead with「GymSys 照記住,會自動補返」。
- **mid-set 斷線/re-login** 嘅 surface 必須 peripheral(bottom banner ≤10%),絕不全屏轉場。
- **壞時刻 banner** 出現喺玩家最 vulnerable 嗰刻 → 靜態紀律(零 animation/pulse/audio,Rule 8)係 binding,唔係 polish。

> **Gap**:`design/player-journey.md` 未存在 → 上述情緒/情境係由 GDD Player Fantasy + game-concept Flow State 推導,非 journey-map 實證。記入 OQ-UX1。

---

## Navigation Position

#24 **就係 navigation 嘅根** —— 佢唔係一個被其他 screen 連去嘅 destination,而係**承載其他 screen 入口嘅 shell 本身**。

```
[boot] ─pull-check─▶ #24 Shell
                       ├── LOGIN(全屏 form)──claim success──▶ landing shell state
                       ├── SHELL_IDLE(主畫面 home)
                       │      ├─ request_open(&"character_screen") ─▶ #22 Character Screen(CanvasLayer 60)
                       │      ├─ request_open(&"inventory") ────────▶ #23 Inventory UI(CanvasLayer 61)
                       │      └─ settings gear ─▶ logout ─▶ DRAINING
                       ├── DISCONNECTED_SHELL(主畫面 + reconnect)
                       └── HIDDEN(workout 系 — 入口唔 render)

[ErrorBannerLayer 111]  ◀── orthogonal overlay,任何 state 都疊現(#3/#8/#11/#12 error signal)
```

- **Root level**:#24 shell 係 top-level,玩家開 game 第一個(同唯一)嘅 home surface。
- **#22/#23 係 context-dependent**:只喺 `SHELL_IDLE` / `DISCONNECTED_SHELL` 經入口卡 reachable;workout 系 state 入口卡唔 render(整個 shell HIDDEN)。
- **單一入口路徑**(MVP):#22/#23 冇第二條到達路徑 —— 全部經 shell 入口卡 + 中央 `request_open` arbiter(GDD Rule 11)。
- **Banner layer 係 orthogonal**:唔屬 navigation tree,任何 navigation state 之上都可疊現(連 workout HIDDEN 都照出 —— `ErrorBannerLayer` 111 ALWAYS,GDD EC-E3)。
- **#27 Onboarding** 係 host 關係:#27 choreograph 首 5 分鐘流程,#24 只提供 LOGIN surface 本身(MVP 唔含 tutorial 內容)。

---

## Entry & Exit Points

### 進入 #24 各 state

| Entry Source | Trigger | 玩家帶住嘅 context |
|---|---|---|
| **Boot pull-check** | `_ready()` → `is_auth_required()==true`(G-LS-4(c),**唔靠 signal** — boot-race 收口) | 零 token,零 game state;純 `ui_ink_bg` 底 |
| `auth_required()` signal(#2) | 任何 shell state fire(401 latch / 410 update / logout 完成) | 已 render world(re-login → opaque scrim 遮);**mid-workout 時 banner-defer 唔即入 LOGIN** |
| GSM `state_changed` → IDLE | claim success 後 #2 polling 反映 / workout 完結 | 有 token;avatar 由 #26 已 render |
| GSM `state_changed` → DISCONNECTED | WiFi blip(non-workout) | 本地 view 全功能(ADR-0003 unsynced-only client wins) |
| logout tap(settings 內) | 玩家主動 | 即時 optimistic「已登出」 |
| #3/#8/#11/#12 error signal | 任何時刻(含 boot-window pull-check) | banner overlay,唔改 navigation state |

### 離開 #24 各 surface

| Exit Destination | Trigger | 不可逆 state 變化 |
|---|---|---|
| Landing shell state(IDLE/LOOT_DROP…) | claim success **+ GSM 離開 BOOTING**(yield landing state,唔假設 IDLE) | token 已由 #2 寫入(#24 唔掂 persistence) |
| #22 Character Screen | 入口卡 tap → `request_open(&"character_screen")` | 現 open screen 先 close(deferred,last-wins latch) |
| #23 Inventory UI | 入口卡 tap → `request_open(&"inventory")` | 同上互斥 |
| DRAINING → LOGIN | logout → `clear_session_token(USER_EXPLICIT)` → drain → `auth_required` | **token 已清**(不可逆 — 要重新登入);drain 背景進行 |
| HIDDEN | GSM 入 workout 系 state | shell surface 全收(login layer visible=false);banner layer 不受影響 |

**One-way / 不可逆注記**:
- **logout 係單向**:tap 即清 token(optimistic),冇「取消登出」—— gear 收一層 + 破壞性動作唔用 amber 係**唯一**誤撳防護(GDD Rule 12)。
- **claim success → landing** 唔保證去 IDLE:reconciliation 可直落 LOOT_DROP(deferred reveal,EC-A5)→ shell 入 HIDDEN 畀 #21 接手。**入口設計唔可假設 success 之後一定見到主畫面**。

---

## Layout Specification

### Information Hierarchy

#24 有三個獨立 layout context(LOGIN 全屏 / SHELL_IDLE 主畫面 / Banner overlay),各有自己嘅 hierarchy:

**LOGIN(全屏 form)** — 任務:最快令玩家連到,壞情況誠實分流。
1. **最先睇到**:title lockup「MIRROR HERO」(身份確認,呢個係邊個 game)
2. **焦點**:form(username → password → toggle → submit)—— submit 係**唯一 amber**,視覺終點
3. **條件性**:inline error(submit 之後先出)/ rate-limit 倒數 / update-required prompt(取代 form)/ misconfig prompt(operator-facing)
4. **可發現**:show-password toggle(預設收埋密碼)

**SHELL_IDLE(主畫面 home)** — 任務:情感焦點喺 avatar,入口清晰但唔搶戲。
1. **最先睇到 / 情感焦點**:**avatar**(#26 喺 GameLayer render,世界相機自然置中 —— shell 唔 own avatar,呢個係 Mirror Moment 嘅日常預覽)
2. **主要 action**:#22 / #23 兩張入口卡(平等、大 target、icon + text label 雙 channel)
3. **狀態確認**:connection status dot(綠 = 連住)
4. **收一層**:settings gear(內含 logout —— 破壞性動作唔同主入口同級)

**Banner overlay(orthogonal,任何 state)** — 任務:誠實但 peripheral。
1. **主 slot 永遠係最高 severity 嗰一條**(Priority:DISCONNECTED > ONGOING > WIPE > FEATURE_DEGRADED > TRANSIENT > 通知類)
2. **其餘 collapse 做「+N」counter**(tap 展開 detail list)
3. banner 永遠喺**周邊**(bottom ≤10%)—— 唔入 foveal,唔搶 avatar / form 焦點

> **Hierarchy binding**:avatar 喺 SHELL_IDLE 係**情感焦點**(GDD UI Requirements 明文「world avatar 自然置中 —— 情感焦點」),入口卡唔可遮 avatar、唔可比 avatar 更搶眼;banner **永不**升上 foveal(違反 = 變 attention surface,證偽 Pillar 2)。

### Layout Zones

**Reference viewport**:portrait-first 360×640(web mobile primary,touch single-tap;對齊 #22 360×560 min target,#24 多 banner 區用 640 高)。Desktop:整個 form / shell column 置中,`max-width ~480px`,兩側 letterbox `ui_ink_bg`(唔做兩欄 —— login 同 home 都係單一焦點內容)。所有座標用 **safe-zone inset ≥16px**。

採 **Arrangement A — Avatar-centric home + bottom honesty strip**(3 個 arrangement 比較後採;rationale:avatar 留 center 兌現情感焦點,所有 chrome 推去四邊 + 底,banner 永遠 bottom = 同 #20 HUD 周邊紀律一致,玩家肌肉記憶統一):

| Zone | State | 位置 | 內容 | Layer |
|---|---|---|---|---|
| **LZ-Form** | LOGIN | 螢幕**垂直置中**,form card 寬 `min(viewport−32px, 360px)` | title lockup + form card(username/password/toggle/submit)+ inline error 區 | LoginShellLayer 62 |
| **LZ-Avatar** | SHELL_IDLE / DISCONNECTED_SHELL | center(world camera 自然置中,**shell 唔 own**) | #26 avatar(GameLayer render) | GameLayer(非 #24) |
| **LZ-Status** | IDLE / DISCONNECTED | **top-right** safe-zone | connection status dot + label(綠「已連線」/ dim「連線斷咗」)+ banner-yield glyph 寄居位 | LoginShellLayer 62 |
| **LZ-Settings** | IDLE / DISCONNECTED | **top-left** safe-zone corner | settings gear(`ui_text_dim`,內含 logout) | LoginShellLayer 62 |
| **LZ-Entry** | IDLE / DISCONNECTED | **bottom 之上**(banner 區之上,離底 safe-zone)水平並排 | #22 / #23 兩張入口卡(平等寬) | LoginShellLayer 62 |
| **LZ-Banner** | 任何 state(orthogonal) | **螢幕最底**,full-width,anchored bottom safe-zone | 單 banner slot + 「+N」counter | ErrorBannerLayer 111 |

**Zone isolation rule(binding,鏡 #20 AC-V-1 0px 紀律)**:
- **LZ-Banner 喺獨立 layer(111),永不 push LZ-Entry / LZ-Avatar 嘅 layout flow** —— banner 出現/消失唔可令入口卡或 avatar 位移。Entry/Avatar 喺 LoginShellLayer(62),banner 喺 ErrorBannerLayer(111),物理上分層保證隔離。
- **LZ-Entry 距 LZ-Banner 頂緣留 ≥8px dead gap**(防 banner ≤10% + entry card 嘅 tap target 互撞 —— 同 #23 P-13 row「≥8px dead gap」先例一致)。
- **LZ-Form(LOGIN)出現時 LZ-Entry / Status / Settings 全收**(LOGIN 係全屏 takeover);LZ-Banner 照常(banner orthogonal,但 LOGIN 期間多數係 drain 通知 / boot-window error)。

### Banner Region Pixel Pin（#20 Z5/Z6 non-overlap）

> **本節係 UX Flag 點名嘅核心 deliverable**。GDD Rule 7 已 GDD-level arbitrate 三條讓位 *方向 / 優先權*(binding);本節**只釘 pixel region**,唔改 mechanics。三方 bottom 撞:#20 **Z5** REST panel(bottom slide-up,layer 50)+ #20 **Z6** silent-mode toast(bottom-center,layer 50)+ #24 **LZ-Banner**(bottom full-width,layer 111)。`ErrorBannerLayer` 111 > #20 HUD 50 → #24 預設 draw 喺 #20 之上,所以**收口 = #24 讓位**。

**Region 定義(360×640 reference;`H`=viewport 高,`W`=闊;side/bottom safe inset = 16px)**:

| Region | 幾何 | 用途 |
|---|---|---|
| **R-Default**(主 banner) | full-width `x∈[16, W−16]`;bottom-anchored `y∈[H−16−h, H−16]`;`h = clamp(round(BANNER_MAX_HEIGHT_PCT × H), 44, min(round(0.10×H), 72))` → 640 高 = **44–64px** | 單 banner slot + 「+N」counter;無 REST 衝突時嘅常態位 |
| **R-Toast**(輕量) | bottom-center `width = min(W−32, 320)`;height 44px;bottom-anchored same inset | TRANSIENT toast **+ #20 Z6 silent toast 共用嘅單一 slot**(constraint 2) |
| **R-Glyph**(讓位態) | 16×16 at ErrorBannerLayer top-right `x∈[W−32, W−16], y∈[16, 32]` | persistent banner 讓 REST 時 collapse 到嘅 status glyph(constraint 1/3);**在 ErrorBannerLayer(ALWAYS)上,workout HIDDEN 期間仍可見** |

**桌面 / 高螢幕注記**:`0.10×H` 喺大窗(如 900px → 90px)會過高 → R-Default `h` **絕對上限 72px**(content 維持 2-line top-aligned,多出高度作 bottom padding,banner **唔**因高螢幕而長大字 —— 維持 peripheral class)。此 72px ceiling 係 ux refinement,唔違反 GDD `BANNER_MAX_HEIGHT_PCT` knob(knob 管 %,ceiling 管絕對 px)。

---

**三條讓位 constraint 嘅 pixel 兌現**(GDD Rule 7 方向 → 本 spec pixel):

**Constraint 1 + 3 — REST panel(Z5)升起時 #24 banner 讓位**
- **Trigger**:shell observe GSM == `REST_PERIOD`(Z5 唯一 surface state)。
- **persistent banner(ONGOING / WIPE / FEATURE_DEGRADED)→ collapse 到 R-Glyph**(top-right 16×16,**唔**用 R-Default bottom strip)。揀 collapse-to-glyph **而非**「stack 到 REST panel 之上邊緣」係因為:Z5 slide-up 高度 art-director 可微調,棧喺其上緣 = fragile pixel 依賴 #20 內部數值;glyph 寄 top-right = 對 #20 layout 變化免疫(more robust)。
- **glyph 視覺**:沿用該 banner 嘅 severity glyph(⚠ amber [ONGOING/WIPE] / ⚠ dim [FEATURE_DEGRADED])—— non-color encode 保留;**非互動**(REST 期間唔邀請 tap)。
- **TRANSIENT toast → 抑制入 queue**(REST 短,唔閃);REST 完若仍喺 TTL 內 → 補出 R-Toast,否則自然 drop(TRANSIENT = race,acceptable)。
- **REST 完(GSM 離開 REST_PERIOD)→ R-Glyph re-expand 返 R-Default**(誠實唔丟,只暫讓)。
- **唔遮 tap window**:REST panel 嘅「下一動作 tap」係 workout 神聖時刻(同 #21 loot modal sacred 同理)—— glyph 喺 top-right,**物理上零 overlap** Z5 嘅 bottom slide-up tap target。

**Constraint 2 — Z6 silent toast 同 #24 TRANSIENT toast 共用單一 R-Toast slot**
- 兩者皆 peripheral bottom-center 單行 toast;**永不同時雙 toast**(兩個 toast 疊 = clutter,迫近 modal 體感)。
- **共用幾何 = R-Toast**(同一 bottom-center slot);**讓位方向:#24 TRANSIENT defer 畀 #20 Z6**(workout 情境下 Z6「㩒一下開聲」係 workout-relevant invite,#24 TRANSIENT 係會自動 expire 嘅 persistence race)。
- 因兩者**唔同 layer / 唔同 owner**(#20 layer 50 vs #24 layer 111),「單 slot」嘅**仲裁機制**(邊個 check 邊個)係 epic / architecture 關注;本 spec 釘 **geometry(同一 R-Toast)+ rule(never both visible)+ defer direction(#24 讓 Z6)**。記入 OQ-UX2 畀 epic 落實機制。

---

**驗證**:呢三條 pixel 約束由 AC-UX-3 / AC-UX-4 斷言(region rect 量度 + 互斥)。`/ux-review` 應驗 R-Default/R-Toast/R-Glyph 三 region 同 #20 Z5/Z6 零 tap-target overlap。

### Component Inventory

| Component | Zone | 類型 | 內容 | 互動 | Pattern / 視覺 |
|---|---|---|---|---|---|
| Title lockup | LZ-Form | display | 「MIRROR HERO」 | 否 | m6x11 大階,`ui_text_primary`,**唔用 amber**,零 logo asset |
| Username field | LZ-Form | input | ASCII LineEdit | 鍵入 | input 底 ink−10%,text ≥16px,≥44px 高 |
| Password field | LZ-Form | input | `LineEdit.secret=true` | 鍵入 | 同上;預設收埋 |
| Show-password toggle | LZ-Form | input | 眼睛 icon | tap | `ui_icon_eye_toggle_16`,**≥44px** tap target |
| Submit button | LZ-Form | input | 「登入」 | tap | **唯一 amber**(`event_amber #F2A93B` fill + ink label);≥44px |
| Inline error 區 | LZ-Form | feedback | 4-code copy / 倒數 / prompt | (retry 掣可 tap) | `ui_text_primary` + ⚠ glyph,**零 red**;ARIA assertive |
| Retry 掣(inline) | LZ-Form | input | 「再試一次」 | tap | network/server error 出;≥44px |
| Update-required prompt | LZ-Form | display | 「呢個版本舊咗…」 | 否 | 取代 form(`get_auth_block_reason()==update_required`) |
| Misconfig prompt | LZ-Form | display | operator 指引 | 否 | operator-facing(`carve_out_misconfig`) |
| Avatar | LZ-Avatar | display | #26 render | 否 | **#24 唔 own**(GameLayer,世界相機置中) |
| Connection status dot | LZ-Status | display | 綠 dot +「已連線」/ dim + slash +「連線斷咗」 | 否 | `ui_icon_disconnected_slash_8` 做 non-color encode |
| Settings gear | LZ-Settings | input | gear icon → settings(內含 logout) | tap | `ui_icon_settings_gear_16`,`ui_text_dim`,**唔用 amber**,≥44px |
| Char entry card | LZ-Entry | input | icon + 「角色」label | tap → `request_open(&"character_screen")` | `ui_icon_char_entry_16` + Zpix label;frameless;≥48px;可借 #22 `ui_card_item_bg` 9-slice |
| Inventory entry card | LZ-Entry | input | icon + 「背包」label | tap → `request_open(&"inventory")` | `ui_icon_bag_entry_16` + Zpix label;同上 |
| Banner — main slot | LZ-Banner(R-Default) | overlay/feedback | 最高 severity 一條 + glyph | (ONGOING minimize tap / WIPE dismiss tap / 「+N」expand tap) | 見「Banner 視覺區分」(GDD)；**零 animation/pulse/audio** |
| Banner — 「+N」counter | LZ-Banner | overlay | collapsed count | tap → 展開 detail list | 同 banner 視覺 weight |
| Banner — yield glyph | R-Glyph | display | severity glyph 16×16 | 否(REST 期間) | top-right;ALWAYS layer |
| TRANSIENT toast | R-Toast | overlay | 暫態 copy + ⓘ glyph | 否(auto-expire) | `ui_ink_bg`@40%,`ui_text_dim` |
| Drain banner | LZ-Banner | overlay | 「已登出 — 緊要嘢背景儲緊…」/「全部儲好喇 ✓」 | 否(non-interactive) | text + ✓ glyph(唔純 spinner);part-fail → persistent acknowledge |
| Reconnect 掣(disconnect banner 內) | LZ-Banner | input | 「再試一次」 | tap → `request_immediate_poll()` | text 掣 ≥44px;狀態用 text 唔純 spinner |

**新 pattern flag**:#24 banner system(severity-stacked peripheral honesty banner)、login-form、entry-card、drain-banner、connection-status-dot **未喺 interaction-patterns library**。對應 library 既有 gap:「Toast notification / inline message」(Medium MVP)+「Loading state / spinner」(Medium MVP)。Cross-Reference Check 會 flag 加入(見文末)。

### ASCII Wireframe

**(1) LOGIN — first-boot / re-login(全屏 form,垂直置中)**
```
┌─────────────────────────────┐ 360×640, ui_ink_bg 全屏
│                             │  (first-boot=純底;re-login=opaque scrim 遮 world)
│                             │
│        MIRROR HERO          │  ← title lockup, m6x11 大階, 非 amber
│                             │
│   ┌─────────────────────┐   │
│   │ Username            │   │  ← ASCII LineEdit, ≥16px, ≥44px 高
│   ├─────────────────────┤   │
│   │ Password        [👁] │   │  ← secret=true + show-toggle ≥44px
│   ├─────────────────────┤   │
│   │ ⚠ username 或 password │  │  ← inline error 區(submit 後;零 red)
│   │   唔啱,再試下?       │   │
│   └─────────────────────┘   │
│   ┌─────────────────────┐   │
│   │        登入          │   │  ← submit = 唯一 amber, ≥44px
│   └─────────────────────┘   │
│                             │
└─────────────────────────────┘
  變體:rate_limited → submit disable +「等 {N} 秒再試」倒數
        update_required → prompt 取代 form(唔顯示 input)
        carve_out_misconfig → operator prompt + 指引
```

**(2) SHELL_IDLE — 主畫面 home(avatar-centric)**
```
┌─────────────────────────────┐
│ ⚙                    ● 已連線 │  ← LZ-Settings(gear,左上) · LZ-Status(綠 dot,右上)
│                             │
│                             │
│           \o/               │  ← LZ-Avatar(#26 render,center,情感焦點)
│           /|\               │     shell 唔 own,世界相機自然置中
│           / \               │
│                             │
│                             │
│  ┌──────────┐ ┌──────────┐  │  ← LZ-Entry:兩卡平等並排,icon+label 雙 channel
│  │   [人]    │ │   [袋]    │  │     ≥48px tap;modulate.a=1.0 (enabled)
│  │   角色    │ │   背包    │  │
│  └──────────┘ └──────────┘  │
│                             │  ← ≥8px dead gap
│ ··········(LZ-Banner 區,常態空)··········│  ← R-Default(無 error 時零 draw)
└─────────────────────────────┘
```

**(3) DISCONNECTED_SHELL — 斷線主畫面(non-workout)**
```
┌─────────────────────────────┐
│ ⚙              ⃠ 連線斷咗     │  ← status:dim + slash glyph(非色 encode)
│           \o/               │  ← avatar 一樣置中(進度/裝備一樣都冇少)
│           /|\               │
│  ┌──────────┐ ┌──────────┐  │  ← 入口卡照 enabled(對齊 #22 EC-30 全功能本地 view,唔 grey)
│  │   角色    │ │   背包    │  │
│  └──────────┘ └──────────┘  │
│ ┌─────────────────────────┐ │  ← LZ-Banner(R-Default):dim weight + slash glyph
│ │ ⃠ 連線斷咗 — GymSys 照記住, │ │     +「再試一次」text 掣 ≥44px → request_immediate_poll()
│ │   連返之後自動補返。 [再試一次]│ │
│ └─────────────────────────┘ │
└─────────────────────────────┘
```

**(4) Banner anatomy — 3 visual weight(semantic 4 class → visual 3,色+glyph 雙 encode)**
```
重 (ONGOING / WIPE):                    中 (FEATURE_DEGRADED):
┌▌────────────────────────────┐         ┌─────────────────────────────┐
│▌⚠ 偵測到存檔問題 — 你嘅進度    │ amber   │ ⚠ 連勝記錄今次冇儲到,         │ dim flat
│▌會由 GymSys 守住。      [知道喇]│ 4px bar │   下次成功會自動補返。         │ ui_text_dim ~70%
└▌────────────────────────────┘ + ⚠     └─────────────────────────────┘ + ⚠dim

輕 (TRANSIENT,R-Toast bottom-center):
        ┌───────────────────┐
        │ ⓘ 系統忙緊,陣間再試  │  ui_ink_bg@40%, ~5s auto-expire
        └───────────────────┘
```

**(5) REST 讓位(constraint 1/3)— workout REST_PERIOD 期間 persistent banner collapse**
```
┌─────────────────────────────┐
│ [#20 HUD …]            [⚠]   │  ← #24 yield glyph(R-Glyph 16×16 top-right,ALWAYS layer)
│                             │     persistent banner 收埋呢度,唔搶 REST
│         (avatar)            │
│ ┌─────────────────────────┐ │
│ │ ▷ Set 3/5 · 下一個:Squat  │ │  ← #20 Z5 REST panel slide-up(layer 50)
│ │   剩 2 組      [tap 區]    │ │     #24 banner 零 overlap 呢個 tap window
│ └─────────────────────────┘ │
└─────────────────────────────┘
  REST 完 → glyph re-expand 返 R-Default bottom banner(誠實唔丟)
```

**(6) mid-set 斷線(Rule 9a)— shell 留 HIDDEN,只 peripheral banner**
```
┌─────────────────────────────┐
│ [#20 HUD — workout 照行]      │  ← shell HIDDEN(login layer visible=false)
│         (combat auto-play)   │
│                             │
│ ┌─────────────────────────┐ │  ← ErrorBannerLayer 111(ALWAYS)照出
│ │ ⃠ 連線斷咗 — 你嘅訓練 GymSys│ │     bottom peripheral,零全屏轉場,零 modal
│ │   照記住,連返自動補返。[再試]│ │     (Locker-Room WiFi Test binding)
│ └─────────────────────────┘ │
└─────────────────────────────┘
```

> ASCII 係 layout 意圖示意(非 pixel-perfect);確切 px 由 R-Default/R-Toast/R-Glyph region 定義 + art-director 微調 spacing。Glyph(⚠ ⃠ ⓘ ✓ 👁)對應 GDD「Asset 需求」8 sprites。

---

## States & Variants

Shell internal FSM 有 5 個 state(GDD States table 定義,**唔係** GSM state)。Banner stack 係 **orthogonal overlay**,任何 state 都可疊現。本表係 layout 層面嘅 state→visual 對照(mechanics 見 GDD):

| Shell State | Layout 形態 | 入口卡 | Banner |
|---|---|---|---|
| `HIDDEN` | 零 shell surface(LoginShellLayer visible=false) | 唔 render | ErrorBannerLayer 照常(R-Default / R-Glyph if REST) |
| `LOGIN` | LZ-Form 全屏(first-boot 純底 / re-login opaque scrim) | 收(全屏 takeover) | 照常(多為 drain 通知 / boot-window error) |
| `SHELL_IDLE` | LZ-Avatar + LZ-Entry + LZ-Status(綠)+ LZ-Settings | enabled(`modulate.a=1.0`) | R-Default(常態空) |
| `DISCONNECTED_SHELL` | 同 IDLE 但 status = dim+slash | **照 enabled**(唔 grey,Rule 10) | disconnect dim banner + 「再試一次」 |
| `DRAINING` | optimistic「已登出」+ avatar 漸隱去 LOGIN | 收 | drain banner(text+✓;part-fail→persistent) |

### LOGIN sub-variant（`get_auth_block_reason()` 分流）

| Variant | Trigger | 顯示 |
|---|---|---|
| Normal form | `&"none"` | username/password/toggle/submit |
| Update-required | `&"update_required"`(410) | prompt「呢個版本舊咗,要更新先連到」**取代 form**(唔顯示 input) |
| Misconfig | `&"carve_out_misconfig"` | operator-facing prompt + `acknowledge_carve_out_fix()` 指引 |

### LOGIN 內部 error 變體（claim 4-code,inline,form 保留)

| Variant | 顯示 | submit |
|---|---|---|
| `invalid_credentials` | field-level「username 或 password 唔啱,再試下?」(唔分邊欄) | re-enable;清 password、保 username |
| `network_error` | 「而家連唔到伺服器,睇下 WiFi?」+ retry 掣 | re-enable |
| `rate_limited` | 「等 {N} 秒再試」**live 倒數**(N>99 → m:ss) | disable 至 N=0 |
| `server_error`(含 session-conflict) | 「伺服器嗰邊出咗少少問題,陣間再試下。」+ retry | re-enable |

### 入口卡 state（enabled / interactive-dimmed / hidden 三態 — Rule 10）

| State | modulate.a | 可 tap | 何時 |
|---|---|---|---|
| **enabled** | 1.0 | 是 → `request_open` | SHELL_IDLE / DISCONNECTED_SHELL steady-state(**唯一常態**) |
| **interactive-dimmed** | 0.55 | 是 → tap 出 inline reason(唔 force open) | **罕見 race**:`can_open()` false(GSM 離 IDLE 但 shell 未轉 HIDDEN 嗰瞬);≠ greyed disable |
| **hidden** | — | 否(唔 render) | 非 permitted state(workout 系)= shell 整個 HIDDEN |

> **無 greyed disabled 態**(GDD Rule 10 整套刪 directional-debounce):grey 一個全功能本地 view = 細講大話(對齊 #22 EC-30)。`alpha 0.55` interactive-dimmed ≠ desaturate(desaturate 係 §4.E World Layer/MoodController 工具,UI chrome dimmed 語言 = alpha)。

### Banner orthogonal overlay state

| Banner 態 | 觸發 | 視覺 |
|---|---|---|
| 空 | 無 active error | R-Default 零 draw(idle 零 draw-call) |
| 單 banner | 一條 active | R-Default,severity weight 視覺 |
| stacked(+N) | 多條 | 主 slot = 最高 severity + 「+N」counter |
| yielded(glyph) | REST_PERIOD 期間有 persistent | R-Glyph top-right 16×16 |
| toast | TRANSIENT / 通知類 | R-Toast bottom-center,auto-expire |

---

## Interaction Map

**Input methods**(由 `technical-preferences.md` 載入,唔再問):Touch(primary,single-tap)+ Keyboard/Mouse(secondary)。**Gamepad: None** → 唔做 gamepad focus order。Keyboard tab order 係 a11y 必需(WCAG AA)。

| Element | Action | Touch / Keyboard | 即時 feedback | Outcome |
|---|---|---|---|---|
| Username field | focus + 鍵入 | tap / Tab→鍵入 | caret(native)+ input 下陷態 | 內存(提交瞬間,Rule 15) |
| Password field | focus + 鍵入 | tap / Tab→鍵入 | secret dots | 同上;resolve 後即清 |
| Show-password toggle | toggle | tap / Tab→Enter | 眼睛 open/closed glyph 切換 | password `secret` true↔false |
| Submit | confirm | tap / Enter(form) | 即時 disable + loading 態 | `await claim_session(u,p)`(G-LS-3) |
| Retry 掣(network/server error) | retry | tap | disable + loading | 重提 claim |
| Banner main(ONGOING) | acknowledge-to-minimize | tap | collapse 做 peripheral status glyph | banner minimized(下次被 block action 再 inline 彈) |
| Banner main(WIPE) | acknowledge-dismiss | tap | banner 消失 | 事件已完結,誠實已交付 |
| Banner「+N」counter | expand | tap | 展開 detail list(append-safe) | 顯示全部 collapsed banner |
| Reconnect「再試一次」 | retry poll | tap | text「連緊…」 | `request_immediate_poll()`(G-LS-4) |
| Char entry card | open | tap | 0.25s cross-fade out | `request_open(&"character_screen")` |
| Inventory entry card | open | tap | 0.25s cross-fade out | `request_open(&"inventory")` |
| entry card(interactive-dimmed) | tap-when-blocked | tap | inline reason text | **唔** force open(EC-E4) |
| Settings gear | open settings | tap / Tab→Enter | settings 展開 | 內含 logout |
| Logout(settings 內) | logout | tap | 即時「已登出」optimistic | `clear_session_token(USER_EXPLICIT)` → DRAINING |

**Navigation target 驗證**:`request_open` 目標(#22 / #23)各有 approved UX spec(`character-screen.md` / `inventory-ui.md`)—— entry/exit 對齊(本 spec 係 #22 UXQ-2 嘅 closure;#22/#23 嘅「shell 入口 tap」entry 由本 spec 釘形態)。

**Keyboard tab order(LOGIN)**:username → password → show-toggle → submit(GDD UI Requirements 明文;banner 出現唔搶 form focus)。
**Keyboard tab order(SHELL_IDLE)**:char card → inventory card → settings gear(banner 若 interactive 則最後,唔搶主流程)。

---

## Events Fired

#24 係 thin presentation shell —— 玩家 action 主要 **call #2 / shell 方法**,唔 fire analytics event(#28 Telemetry GDD 未 author)。下表記每個 action 嘅 outcome 渠道:

| Player Action | 渠道(call / signal) | Payload / Data | 持久 state 變化? |
|---|---|---|---|
| Submit | `GymSysClient.claim_session(u, p)` | username, password(內存,resolve 即清) | **間接**:成功後 **#2** 寫 token(#24 零 persist) |
| Retry(error) | 同 `claim_session` | 同上 | 同上 |
| Reconnect 掣 | `GymSysClient.request_immediate_poll()` | — | 否(觸發 #2 poll,節奏 #2 own) |
| Logout | `GymSysClient.clear_session_token(USER_EXPLICIT)` | reason enum | **是 — 不可逆**:#2 清 token + 背景 drain(**flag 畀 architecture**) |
| Char/Inventory entry tap | `shell.request_open(screen_id)` | `&"character_screen"` / `&"inventory"` | 否(navigation,各 screen 自己 own state) |
| Banner acknowledge | shell 內部 banner state | dedupe_key | 否(UI-only,#24 零 persist) |
| Misconfig acknowledge | `GymSysClient.acknowledge_carve_out_fix()` | — | 視 #2 實作 |

**Analytics 注記**:本 MVP **零 analytics event**(#28 未 author)。將來值得 instrument 嘅點:login success/failure rate、error_code 分布、reconnect tap 頻率、logout drain part-fail 率 —— 記入 OQ-UX3,待 #28 Telemetry GDD 統一裁。

**Architecture flag**:**logout(`clear_session_token`)**係唯一 modify persistent state(token)嘅 action,且**不可逆**(清咗要重新登入)。已由 GDD Rule 12 gear-收一層 + 非-amber 視覺防誤撳;architecture team 注意 token 清除嘅 atomicity(#2 own)。#24 本身**零 persistence write**(AC-02 守)。

---

## Transitions & Animations

**全域紀律**:shell state 切換一律 **cross-fade ≤ `SHELL_FADE_SEC`(0.25s,ease-out cubic)**,**唔 hard-cut**(hard-cut 嘅 onset transient 係 attention event,Rule 10 binding)。Banner **零 animation**(Rule 8 — 靜態紀律係 Pillar 2 binding)。

| Transition | 動畫 | 注記 |
|---|---|---|
| 任何 shell state ↔ state | cross-fade 0.25s opacity | LOGIN 最高優先 interrupt(但 mid-workout 401 行 banner-defer,唔即彈全屏) |
| claim success → landing | form cross-fade out + 等 GSM 離 BOOTING(yield landing,唔假設 IDLE) | reconciliation 可直落 LOOT_DROP → HIDDEN(EC-A5) |
| entry card → #22/#23 open | 0.25s cross-fade out(shell)→ #22/#23 自己 OPENING | 互斥:現 open 先 close(deferred last-wins) |
| enabled ↔ interactive-dimmed | cross-fade(無 debounce settle — 已刪) | 罕見 race;alpha 1.0↔0.55 |
| LOGIN cross-fade 途中 GSM 直落 LOOT_DROP | **cross-fade 跑完唔 abort**(EC-E1)→ 完 check state → HIDDEN | 動畫 integrity > immediacy |
| Banner 出現 / 消失 | **零 animation**(即現 / 即去) | 唔援引 #20 silent-mode pulse formula(#20 pulse 係邀請式,#24 係誠實 — pulse=urgency 違 Pillar 2) |
| Drain banner | text 狀態切換(「儲緊…」→「儲好喇 ✓」)+ 2s auto-expire | 唔純 spinner(reduce-motion + SR) |

**Reduced-motion(WCAG Motion Safety — accessibility tier binding)**:
- Banner 本身已**完全靜態**(零 motion)→ 天然滿足 reduce-motion。
- shell cross-fade 係 **opacity-only**(無 scale / translate / 光流)→ **無前庭風險**,reduce-motion 下**保留**(opacity fade 比 hard-cut 更 gentle,符合 Apple HIG)。
- 零 flashing(WCAG 2.3.1 — 靜態紀律順帶滿足)。
- **無 spinner-only loading**:所有等待態(連緊…/儲緊…)用 **text 狀態**,reduce-motion 玩家唔靠 spinner 旋轉理解狀態。

**Minimum required 兌現**:enter = LOGIN form cross-fade in / shell cross-fade in;exit = cross-fade out;state-change animation = enabled↔interactive-dimmed cross-fade + drain text 切換。

---

## Data Requirements

#24 係 read-only display(零 gameplay 數值,零 persistence key — Rule 15)。所有顯示數據由上游 own;#24 只 surface。

| Data | Source System | Read / Write | 即時? | Notes |
|---|---|---|---|---|
| username / password | (玩家鍵入) | 內存 only | — | **永不 persist**;提交瞬間存在,resolve 即清(Rule 15;credential residue AC-50) |
| `auth_required()` | #2 | Read(signal + `is_auth_required()` pull) | event | boot pull-check 收 race(G-LS-4(c)) |
| `get_auth_block_reason()` | #2 | Read(pull) | on LOGIN entry | LOGIN sub-variant 分流 |
| `SessionClaimResult`(error_code, retry_after) | #2 | Read | on claim resolve | 4-code error map + rate-limit 倒數 |
| GSM `state_changed`(from,to,payload) | #1 | Read(`connect_for_initial_state`) | real-time | shell FSM 分流;boot 即收 current state |
| `critical_save_failed`(code,key) | #3 | Read(signal + `get_pending_errors()` pull) | event | severity map(12 code);boot-window pull(G-LS-8) |
| `streak/stat/ability_*_failed` | #8/#11/#12 | Read | event | FEATURE_DEGRADED banner |
| `drain_started(N)` / `drain_completed(committed,timeout)` | #2 | Read | event | drain banner 數字 |
| `retry_after` 倒數 clock | injected clock(test)/ `Time.get_ticks_msec()`(runtime) | Read | per-frame | monotonic;Formula 路徑唔可直 call ticks(AC-51) |
| token | #2 | **#24 唔掂**(#2 write) | — | claim success 後 #2 寫;#24 零 persist(AC-02) |
| a11y settings(motion intensity / reduce-motion) | #22 unified panel | **#24 唔 own** | — | logout/login UI 唔改 a11y;#22 own |

**Null / unavailable 處理**(上游 data 缺/異常時顯示什麼 — substantive 分支由 GDD 守,本 spec 列 surface 行為):
- `auth_required` 漏收(boot-race)→ `is_auth_required()` pull-check 兜(GDD G-LS-4(c));`get_auth_block_reason()` 未知值 → fallback normal form。
- `critical_save_failed` 未知 error_code → UNMAPPED default-deny ONGOING banner(GDD Rule 5/6,**永不 silent**)。
- `retry_after` absent/0/負 → 即時 re-enable,**唔顯示倒數**(GDD F1 / EC-D1)。
- avatar(#26)未 render → LZ-Avatar 空(world camera 自然處理,shell 唔 own —— 唔係 #24 的 null 責任)。
- GSM payload null → shell 只讀 from/to state 分流,唔依賴 payload 內容(GDD ADR-0009 late-bind 原則)。

**架構關注(UX spec 唔裁,只 flag)**:
- **claim_session delivery mechanism**(await-coroutine vs completion-signal + cancellation 語意)= **G-LS-3 blocking gate**,login form story 前必釘(#2 erratum)。本 spec 嘅 submit→loading→result feedback 假設 result **一定 resolve**(cancelled 帶語意 result 或 timer race)。
- **#2 三個 additive API**(`get_auth_block_reason` / `request_immediate_poll` / `is_auth_required`)= **G-LS-4** consumer-forward;`get_pending_errors` = **G-LS-8**。本 spec 假設其存在(mock-scoped 先行)。
- 數據交付方式(polling vs push)係 architecture decision,非本 spec 範疇(ADR-0002)。

---

## Accessibility

**Committed tier**:`design/accessibility-requirements.md` = **WCAG AA Core + Motion Safety**。#24 係玩家最 vulnerable 時刻嘅 surface → a11y 唔係 polish。

| 要求 | #24 兌現 |
|---|---|
| **Canvas → DOM 不透明(關鍵限制)** | canvas 對 DOM accessibility tree 不透明,VoiceOver 讀唔到 canvas 內容 → **所有 SR 公告(error / banner / status / drain)必經 `PlatformDetect.announce_aria`** JS-bridge 推入 DOM ARIA-live element(**唔靠 4.5 AccessKit** — AccessKit native-only;#21/#22/#23 已建 seam)。ADR-001:raw `JavaScriptBridge.eval` 只准喺 `platform_detect.gd`。 |
| **ARIA live politeness** | error = `assertive`(打斷,玩家提交後等緊回應);banner = `polite`(peripheral 唔打斷 SR) |
| **Keyboard-only path** | LOGIN tab order:username→password→toggle→submit;SHELL_IDLE:char→inventory→gear;**banner 出現唔搶 form focus** |
| **Gamepad** | None(tech-prefs)— 唔做 gamepad order |
| **Color independence(每語意 ≥2 non-color signal)** | error ⚠ glyph(零 red)/ disconnect ⃠ slash glyph / 完成 ✓ glyph / info ⓘ glyph;banner 重-weight 多 4px amber accent bar 做第二 encode(squint test 守) |
| **Touch target ≥44×44px** | toggle / submit / retry / reconnect / gear / entry card(≥48px)全部達標 |
| **Text contrast WCAG AA** | `ui_text_primary #F5EFE0` on `ui_ink_bg #1A1D24` ≈ 14.8:1(過 AA 4.5:1 normal + 3:1 large)/ dim text ~70% on ink ≈ 7:1 過 AA;具體 ratio table 見 `design/accessibility-requirements.md` §對比度。**dim banner copy(FEATURE_DEGRADED `ui_text_dim` 70%)係 normal text → 必須驗 ≥4.5:1**(art-director 量) |
| **Input font ≥16px(iOS auto-zoom 防)** | display ≥16px;**但 canvas LineEdit 路線大機會 no-op**(iOS focus-zoom 由 DOM input font 觸發,canvas 對 iOS 係一整塊 WebGL)→ **G-LS-6 spike 必驗項**,唔可預設已解決 |
| **Motion Safety** | banner 完全靜態(零 motion);cross-fade opacity-only(無前庭風險);零 flashing;無 spinner-only(text 狀態) |
| **4.6 dual-focus(breaking change)** | 4.5→4.6 把 touch focus 同 keyboard focus 分離 →「keyboard tab 順序」同「touch tap」係兩條 path,`grab_focus()` 只郁 keyboard focus → **G-LS-6 spike 必須兩種 input 都實機驗** |

**G-LS-6 iOS Safari spike(epic story 001,HIGH risk)連帶驗 a11y 實機**:VoiceOver 讀 announce_aria 公告 / keyboard 唔遮 form / dual-focus 兩 path / canvas auto-zoom 真實行為。spike 結果決定 LineEdit vs DOM `<input>` overlay 路線(若 LineEdit 喺 iOS Safari 連 keyboard 都彈唔出 → MVP 被迫行 DOM overlay,經 platform_detect seam)。

---

## Localization Considerations

MVP copy register = **廣東話口語 witness 語氣**(同 #20 silent-mode banner 一致,零責備零 jargon)。字型:Zpix 12px CJK + m6x11 latin(#21 先例)。i18n 結構同 studiosys/Stage 先例(繁中 + English)。

| 元素 | 最長 string(現 copy) | 風險 | Mitigation |
|---|---|---|---|
| **WIPE banner copy** | 「你喺 GymSys 嘅進度全部安全,會自動補返。(啱啱本機快取重新整理咗;極少數情況:未上傳嘅戰利品要重爆。)」 | **HIGH** — 長,加括號 caveat | R-Default 允許 **2-line wrap**(≤64px 內);英譯 +40% → 主句 lead-with-impact 保留,caveat 可截短 |
| **disconnect banner** | 「連線斷咗 — 你嘅訓練 GymSys 照記住,連返之後自動補返。」+「再試一次」掣 | **MED** | 2-line;「再試一次」掣 label 必須單行(英「Retry」短,中「再試一次」OK) |
| **rate-limit 倒數** | 「等 {N} 秒再試」/ N>99「等 {m}:{ss} 再試」 | LOW | `{N}` / `{m}:{ss}` locale 數字格式;留 placeholder 闊度 |
| **drain banner** | 「已登出 — 緊要嘅嘢背景儲緊({N} 樣),可以安心熄 app。」 | MED | `{N}` 數字;2-line |
| **submit / entry label** | 「登入」/「角色」/「背包」 | LOW | 短;英「Log in」/「Character」/「Bag」需驗卡寬(「Character」較長) |
| **update-required prompt** | 「呢個版本舊咗,要更新先連到」 | LOW | prompt 區有空間 |

**HIGH PRIORITY for localization engineer**:
1. **WIPE banner**(最長 + 情感關鍵 lead-with-impact 結構)—— 英譯必須**保留「進度安全」主句行先**,caveat 入括號可彈性;唔可變成「重置咗 / 可能冇咗」行先(否則摧毀「肯認衰所以我信佢」fantasy)。
2. **banner ≤10% + 2-line wrap 上限** —— 任何語言 banner copy 必須 2 line 內裝得落(≤64px @ 640);英 / 德譯 +40% 膨脹係 layout-critical,超出要截 caveat 唔可加 line。
3. **entry card label** —— 卡寬固定,label 必須單行;「Character」(9 char)/「Inventory」(9)需驗卡寬足夠或用「Char」/「Bag」短 label。

**數字 / locale 格式**:rate-limit `{N}` 秒 / `{m}:{ss}`、drain `{N}` 樣 —— 跟 locale 數字格式(MVP 繁中阿拉伯數字)。

---

## Acceptance Criteria

> 本 spec 嘅 AC 係 **layout / pixel / glance** 層面(QA 唔使讀其他 doc 就驗到);GDD mechanics(FSM / severity / formula)由 GDD 自己 56 個 AC 守。Story 同時 cite 兩份。

- [ ] **AC-UX-1（login form layout）**:LOGIN 全屏量度 → title lockup 垂直在 form 之上 · form card 寬 `min(viewport−32px, 360px)` 置中 · **submit 係唯一 amber 元素**(其餘零 amber)· inline error 區在 submit 之上 · input ≥44px 高。*Visual · ADVISORY*(`production/qa/evidence/acux1-login-form.png`)
- [ ] **AC-UX-2（banner region ≤10%）**:R-Default banner 量度 `rect.size.y == clamp(round(0.10×H), 44, 72)`,bottom-anchored(底緣 = viewport 底 − 16px safe inset),full-width(±16 inset);跨 360×640 / 360×560 / desktop 三 viewport 皆成立。**Small-viewport floor(ux-review #3)**:`0.10×H < 44`(如 `H<440` landscape)時 **44px touch floor 勝 peripheral %**(a11y ≥44px 係 hard 要求,peripheral ≤10% 係 soft 目標 —— interactive banner 寧可佔 >10% 都要可 tap);此情況 banner 接受 >10% 但仍 bottom-anchored single-line。*Logic(measure rect)· BLOCKING*
- [ ] **AC-UX-3（REST 讓位零 overlap）**:GSM=REST_PERIOD + persistent banner active → banner collapse 到 R-Glyph(top-right 16×16),`R-Glyph ∩ Z5(REST panel rect) == ∅`(零 tap-target overlap);REST 完 → re-expand R-Default。*Logic(rect intersect)· BLOCKING*
- [ ] **AC-UX-4 [GATED OQ-UX2]（單 toast slot 互斥）**:#20 Z6 silent toast active 期間 #24 TRANSIENT 要求顯示 → #24 defer(R-Toast 同一時刻最多一個 toast visible);兩 toast 共用 R-Toast 幾何。**GATED**:依賴未解嘅跨系統仲裁機制(OQ-UX2 — #20 expose `is_silent_toast_active()` 或 shared toast-busy flag);mock-scoped 先行(#24 observe mock flag 驗 defer),真接線 epic story 另開。*Integration · GATED*
- [ ] **AC-UX-5（entry card 三態）**:SHELL_IDLE / DISCONNECTED_SHELL → 入口卡 `modulate.a==1.0`(enabled,無 greyed);`can_open()` false race → `0.55`(interactive-dimmed)但仍 tappable→inline reason;workout 系 state → 入口卡唔 render(hidden)。*Integration · BLOCKING*
- [ ] **AC-UX-6（keyboard tab order）**:LOGIN tab 序 = username→password→toggle→submit;banner 出現唔搶 form focus。*UI(manual walkthrough)· ADVISORY*(`acux6-tab-order.md`)
- [ ] **AC-UX-7（color independence + announce_aria）**:error/disconnect/done/info banner 皆有 non-color glyph(⚠ / ⃠ / ✓ / ⓘ);desaturated 截圖全 banner 可區分;所有 SR 公告經 `PlatformDetect.announce_aria`(grep:`ErrorBannerLayer`/login 路徑零 raw VoiceOver 假設)。*Visual + Static · ADVISORY*(`acux7-colorblind.png`)
- [ ] **AC-UX-8（touch target ≥44px）**:toggle / submit / retry / reconnect / gear ≥44×44px;entry card ≥48px。*Logic(measure)· BLOCKING*
- [ ] **AC-UX-9（cross-fade ≤0.25s + banner 零 animation）**:shell state 轉場 cross-fade ≤ `SHELL_FADE_SEC`(0.25s);banner scene 零 AnimationPlayer / 零 tween(鏡 GDD AC-35a/35b)。*Logic + Static · BLOCKING*
- [ ] **AC-UX-10（avatar 情感焦點）**:SHELL_IDLE → LZ-Avatar 在 center(#26 render,shell 唔 own),入口卡 / banner 零 overlap avatar 中心 foveal 區。*Visual · ADVISORY*(`acux10-shell-idle.png`)
- [ ] **AC-UX-11（shell open perf）**:SHELL_IDLE 由 GSM 入 IDLE 到 first frame 入口卡 render ≤ 1 frame budget(16.6ms 內無 layout thrash);banner idle 零 draw-call 貢獻(pre-warmed visible=false)。*Performance · ADVISORY*

**Coverage**:performance→AC-UX-11;navigation→AC-UX-5(entry)/Interaction Map target 驗;error/empty→AC-UX-2/3/4/7;accessibility→AC-UX-6/7/8/9;core-purpose(誠實 peripheral banner)→AC-UX-2/3/4 + AC-UX-10(avatar 焦點)。UX Flag 四 deliverable:form→AC-UX-1;banner pixel pin→AC-UX-2/3/4;shell 入口佈局→AC-UX-5/10;enabled/hidden/dimmed→AC-UX-5。

---

## Open Questions

| ID | Question | Owner | Status |
|----|----------|-------|--------|
| **OQ-UX1** | `design/player-journey.md` 未存在 → 本 spec 嘅情緒/情境由 GDD Player Fantasy + game-concept Flow State 推導,非 journey-map 實證。Template 在 `.claude/docs/templates/player-journey.md`。 | ux-designer | OPEN — 跨 spec gap(#20/#22/#23 同樣);建議 MVP 前補一份 |
| **OQ-UX2** | R-Toast 單 slot 互斥(constraint 2)嘅**跨系統仲裁機制**:#20 Z6(layer 50)同 #24 TRANSIENT(layer 111)唔同 owner,「邊個 check 邊個 active」未定。本 spec 釘 geometry + rule + defer direction(#24 讓 Z6),機制留 epic。 | #24 epic + #20 | OPEN — epic 落實(傾向:#24 observe 一個 shared toast-busy flag 或 #20 expose `is_silent_toast_active()`) |
| **OQ-UX3** | Analytics instrument 點(login success/fail rate / error_code 分布 / reconnect tap / drain part-fail)— MVP 零 event。 | #28 Telemetry | OPEN — defer #28 GDD authoring |
| **OQ-UX4** | Desktop letterbox vs 全屏 stretch:`max-width 480px` 置中 + 兩側 `ui_ink_bg` letterbox(本 spec 採)vs 全屏 stretch。採 letterbox 因 login/home 係單一焦點內容,闊屏 stretch 會令 form / 入口卡過散。 | ux + art-director | RESOLVED(letterbox)— 留記錄,art-director 可微調 max-width |
| **OQ-UX5** | banner 2-line wrap 上限 vs ≤10% height:長 copy(WIPE)2-line @ 12px CJK + glyph + padding 喺 44–64px 內裝唔裝得落,需 art-director 量 + G-LS-6 spike 連帶驗 iOS 真實字高。 | art-director + G-LS-6 | OPEN — epic 視覺 story 量度(Localization HIGH #2 連動) |

### 上游 deferred(本 spec 閉嘅）
- **#22 UXQ-2**(入口 affordance 喺 shell 嘅具體形態:icon? label? 位置?)→ **本 spec 釘**:LZ-Entry 兩卡並排,`ui_icon_char_entry_16`/`ui_icon_bag_entry_16` + Zpix label「角色」/「背包」,bottom 之上,≥48px,enabled/interactive-dimmed/hidden 三態。
- **#22 Q-CS1 flicker**(原 hidden-vs-greyed + IDLE↔DISCONNECTED flicker)→ GDD Rule 10 已裁(enabled/hidden 二態,flicker 天然消失);本 spec layout 兌現。

---

> **Verdict**: **APPROVED**(`/ux-review` 2026-06-08,0 BLOCKING;4 ADVISORY inline 收:header Platform Target / AC-UX-4 GATED-OQ-UX2 / small-viewport 44px floor / null-handling + contrast citation)。UX Flag 四 deliverable 全交付(form wireframe / banner R-Default-R-Toast-R-Glyph pixel pin + #20 non-overlap / shell 入口佈局 / enabled-hidden-dimmed 三態)。NEXT: `/create-epics`(epic 紀律:story 001 = G-LS-6 iOS spike;login form story 前提 = G-LS-3 claim 簽名 + cancellation pin)。
