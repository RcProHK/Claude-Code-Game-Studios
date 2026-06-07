# UX Spec: Character Screen(#22)

> **Status**: APPROVED(/ux-review 2026-06-07 — 0 blocking / 3 advisory 已修)
> **Author**: frank + ux-designer(/ux-design,full-autonomous;derived from APPROVED GDD 2026-06-07)
> **Last Updated**: 2026-06-07
> **Journey Phase(s)**: 未知 — 冇 player-journey.md(見 Open Questions)
> **Platform Target**: Web(primary)/ Desktop(secondary);Touch primary(single-tap)+ Keyboard/Mouse;Gamepad none(authoritative: technical-preferences.md)
> **Template**: UX Spec
> **Source of truth**: `design/gdd/character-screen.md`(APPROVED 2026-06-07,57 ACs)— 本 spec 引用 GDD Rule/EC/AC 編號;衝突時 GDD 為準

---

## Purpose & Player Need

玩家嚟呢度想做三樣嘢:**回望**(睇返自己用真實訓練刻低嘅 stat 數字 + first-seen watermark 第一格刻度 — Pillar 1「門框刻度」)、**整理**(manual equip / unequip / lock / salvage 身上 4 件裝備)、**較校**(motion / reduce-motion / MASTER volume settings)。

「The player arrives at this screen wanting to ___」:**「睇下我而家去到邊」** — 唔係攞 reward(嗰啲喺 #21 burst 完),係 dopamine 嘅沉澱。冇呢個 screen,workout 嘅累積就只係 combat 入面嘅隱形 multiplier,Pillar 1 嘅 retention loop 斷裂。

## Player Context on Arrival

- **時機**:workout 以外時間(GSM `IDLE` / `DISCONNECTED` only — GDD Rule 1)。Anchor scenario:rest day 夜晚攤喺梳化(GDD Player Fantasy)。
- **嚟之前做緊乜**:啱啱 boot game(IDLE)/ 啱啱完成 workout 返到 IDLE(可能袋住新 loot)/ offline 狀態下打開 app。
- **情緒假設**:**calm、唔趕時間、主動打開** — 同 #21(workout 期間、burst、被動彈出)完全相反嘅 temporal mode。設計可以假設玩家有 >2s 注意力(正因如此 workout 期間鎖死 — #33 glance budget)。
- **自願 vs 被send**:永遠自願(shell 入口 tap)。Game 永不主動彈呢個 screen(SUSPENDED resume 都唔 auto-reopen — GDD Rule 3,CD 裁決 3)。

## Navigation Position

This screen lives at: **[shell home(#24,未 design)] → Character Screen** — top-level destination,但 **state-gated**(只喺 GSM ∈ {IDLE, DISCONNECTED} reachable;其他 state 入口 affordance 隱藏 — GDD Rule 1,Q-CS1 provisional)。冇第二個入口路徑(MVP)。Runtime form = autoload coordinator + CanvasLayer 60(GDD Rule 34)— 喺 #20 HUD(50)之上、#21 modal(110/120)之下。

## Entry & Exit Points

| Entry Source | Trigger | Player carries this context |
|---|---|---|
| Shell home nav(#24 provisional)| 入口 affordance tap(GSM IDLE/DISCONNECTED 先顯示)| 無 — 每次 open clean-slate(`active_panel=STATS`、`modal=NONE` — Rule 5);data 第一 frame sync read 齊(Rule 7)|

| Exit Destination | Trigger | Notes |
|---|---|---|
| Shell home | X button(≥48px,persistent)/ ESC(desktop;modal open 時第二下先閂 screen — EC-07)| CLOSING 出場 animation 120-150ms;**唔 cancel 任何已發出嘅 #17 write**(Rule 6)|
| **#23 Inventory UI** | LOADOUT panel header「查看全部 →」link(≥48px;#23 G-IU-4)| normal close → 同 gesture deferred open #23(sequential;CLOSING×OPENING crossfade 接受 — 61>60 冚住);雙 cue 各一響(誠實聲);GSM race → #23 double guard 拒,兩邊 CLOSED 無 limbo(#23 EC-11)|
| (force)workout states | GSM `state_changed` → ∉ {IDLE, DISCONNECTED} | FORCE_CLOSING ≤150ms;modal 一律 cancel(SALVAGE_CONFIRM 永不 confirm — EC-01);**零 SFX**(CD C1)|
| (snap)SUSPENDED | tab hidden | instant snap CLOSED,無 animation;pending settings write critical flush 先行(EC-27);resume 唔 auto-reopen |

One-way notes:exit 全部可逆(re-open 隨時得,只要 GSM permitted);唯一不可逆嘅嘢係 salvage(由兩步 modal friction 保護,唔係 navigation 層面)。

---

## Layout Specification

### Information Hierarchy

(由 GDD Player Fantasy + Pillar 1 推導;ranked)

1. **Stat 數字 ×7(+ watermark 第一格刻度)** — screen 嘅存在理由;STATS 係 default tab
2. **Avatar(visual state + Class label + T[n] tier badge)** — persistent,「望住自己」
3. **Loadout 4 slot cards(provenance + rarity + AntiSnowball badge)** — 第二 tab
4. **Offline banner / persist-fail banner** — status,出現時必須即時可見但唔搶 amber
5. **Settings(P-07 / P-08 / MASTER volume)** — on-demand,第三 tab
6. **Milestone hint、forge shards、lock 狀態** — discoverable,唔使即時見到

### Layout Zones

**自動裁決(推薦採納,rationale)**:單欄 portrait-first(Web mobile primary,touch single-tap);desktop 將成個 column 置中(max-width ~560px),唔做兩欄 — 內容係 ledger 列表,闊屏兩欄會拆散「一本簿」嘅閱讀順序。Min wireframe target **360×560**(GDD UI Requirements)。

| Zone | 內容 | Scroll |
|---|---|---|
| Z1 Header(fixed)| offline banner 位(出現時頂部 strip)+ persist-fail banner 位(其下)+ close X(右上 ≥48px)| 固定 |
| Z2 Avatar panel(fixed,persistent — 唔屬 tab 軸)| avatar sprite(32×32 @3-4× 整數 scale)+ tick-mark tier rule(側邊)+「Class: [name]」label + P-04 icon +「T[n]」badge + milestone hint 行 | 固定 |
| Z3 Tab bar(fixed)| STATS(default)/ LOADOUT / SETTINGS | 固定 |
| Z4 Tab content | per-tab 內容 | **scroll container**(GDD ux R4)|
| Z5 Modal layer | SALVAGE_CONFIRM / ITEM_INSPECT(panel)/ SLOT_PICKER(bottom sheet)+ scrim | — |
| Z6 Toast | 底部,同屏最多 1 條(新取代舊)| — |

並發 messaging priority(GDD pinned):offline banner > persist-fail banner > error toast > lock nudge / backfill note(per-card overlay strip)。

### Component Inventory

**Z4 — STATS tab**(P-03 ticker **唔適用** — F1 cubic lerp 經 formatter,G-CS-6 sync note):
| Component | Type | 內容 | Interactive | Pattern |
|---|---|---|---|---|
| Stat row ×7 | 數據行 | label(左,Zpix)+ 數字(右對齊 m6x11 columnar,5-digit width 預留)+ ↑/↓ arrow(8×8 sprite,settle 後 hold ~1.2s)| 否 | columnar 收據排版(GDD Style)|
| Watermark 行(per stat)| dim 文字行 | 「⌜[date]:[value]⌟」— 只喺 `fmt(current)≠fmt(watermark)` 時 render(Rule 31)| 否 | **NEW:ledger-watermark-line** |

**Z4 — LOADOUT tab**:
| Component | Type | 內容 | Interactive | Pattern |
|---|---|---|---|---|
| Slot card ×4(3 functional + 1 cosmetic)| card,**3 zones**(Rule 22)| name + P-06 rarity badge + provenance_text;「更換」button;lock toggle | 主體 tap→ITEM_INSPECT;更換→SLOT_PICKER;lock toggle→set_lock | P-06;**NEW:three-zone-item-card** |
| Empty slot card | card | 1px pixel-dotted outline + slot silhouette glyph + dim label | tap→SLOT_PICKER 直入 | — |
| AntiSnowball row | text chip | 「+[eff] / +[raw](受真身上限約束)」(F4;effective amber / raw `ui_amber_dim`)| 否(tooltip ledger voice)| — |
| Aggregate row | 數據行 | 「+0」照 render(EC-12)| 否 | — |
| Forge shards row | 數據行 | `get_forge_shards()` verbatim int(禁 K/M 縮寫)| 否 | — |
| Lock nudge strip | overlay strip(唔推 layout)| 「未上鎖 — 下次自動換裝可能換走佢 [鎖定]」;[鎖定] = inline one-tap | [鎖定] tap → set_lock + 變「已鎖定」| **NEW:inline-nudge-strip** |
| Backfill note strip | overlay strip | 「自動補上 [item]」(EC-13a)| 否 | 同上 strip 處理 |

**Z4 — SETTINGS tab**:
| Component | Type | Pattern |
|---|---|---|
| Motion intensity slider + 「[pct]%」label | slider | **P-07**(F2 quantize 係 #22 實作細節)|
| Reduce-camera-motion toggle | toggle | **P-08**(一掣兩 consumer:#7 camera + Rule 11 avatar freeze)|
| MASTER volume slider | slider | P-02 track 同款(Rule 33;零 SFX)|

**Z5 — Modals**:
| Component | Type | 內容 | Pattern |
|---|---|---|---|
| SALVAGE_CONFIRM | center modal + scrim ~60% | yield preview + provenance + rarity badge + warning 行(equipped:「會自動卸下(如有後備會自動補上)」)+ LEGENDARY signature_text + **明確 cancel button(keyboard default focus)** + confirm CTA(`#D94B3E` 1px border)| **NEW:destructive-confirm-modal** |
| ITEM_INSPECT | panel | detail + provenance 全文 + signature + salvage 入口(locked → disabled + hint)| — |
| SLOT_PICKER | bottom sheet + scrim | slot-filtered rows(F3 sort)+ row count(「34 件」)+ empty-state copy;**scroll + virtualized**(120 件 worst case)| **NEW:bottom-sheet-picker** |

### ASCII Wireframe

```
360×560(mobile browser chrome 後)            ┌─ Z5 SLOT_PICKER(bottom sheet)
┌─────────────────────────────────────┐      ┌─────────────────────────────┐
│ [⛓ offline banner — 出現時]      [X]│ Z1   │ ▔▔▔ 後備裝備 — 34 件 ▔▔▔   │
├─────────────────────────────────────┤      │ ┌─────────────────────────┐ │
│  │  ┌──────────┐                    │      │ │ 鐵劍      [RARE] +3 STR │ │
│  ├T3│ avatar   │  Class: STRIKE 🗡  │ Z2   │ ├─────────────────────────┤ │
│  ├T2│ (breath) │  T3                │      │ │ 木棍    [COMMON] +1 STR │ │
│  ├T1│          │  下次 Mirror       │      │ │  ...(scroll)           │ │
│  │  └──────────┘  Moment 就快到     │      └─────────────────────────────┘
├─────────────────────────────────────┤
│ [STATS]   LOADOUT   SETTINGS        │ Z3
├─────────────────────────────────────┤
│  STR                          47 ↑  │ Z4(scroll)
│   ⌜1月12日:30⌟                      │ ← watermark dim 行
│  DEX                          31    │
│  VIT                          38    │
│  max_hp                     1240    │
│  attack_power                 96 ↑  │
│  move_speed                  210    │
│  crit_chance                  7%    │
│                                     │
│            [toast 位 — Z6]          │
└─────────────────────────────────────┘
左側 tick-mark tier rule(1px vertical + notches,current tier amber ≤3px)= Z2 裝飾簽名
```

---

## States & Variants

| State / Variant | Trigger | What Changes |
|---|---|---|
| Default(OPEN)| open() 成功 + 入場 animation 完 | — |
| OPENING | open() 獲准 | 入場 slide-up + fade 150-200ms;content 第一 frame 已 final(**禁 staggered pop-in**)|
| CLOSING / FORCE_CLOSING / CLOSED | Rule 3/5 | 出場 120-150ms / ≤150ms fast path / hidden + 零 subscription |
| Offline(DISCONNECTED)| GSM toggle(Rule 4)| **只加 offline banner**(頂部 ink strip + `ui_text_dim` + broken-link glyph,static);全功能照行(EC-30)|
| Persist-fail(Private Mode)| ADR-0003 detect-and-gate | banner「設定今次有效,未能儲存」;watermark 行唔 render(Rule 31)|
| Empty loadout slot | slot 冇 item | dotted outline + silhouette + dim label(L0);aggregate「+0」照 render |
| Empty picker | slot-filter 0 件 | sheet 照開 + 「呢個 slot 暫時冇後備裝備」+ close(EC-20)|
| Fresh install | settings keys 唔存在 | defaults render(100% / toggle off — AC-40);watermark 第一次 open 寫入、suppress(唔 render 廢話行)|
| Reduce-motion ON | P-08 / persisted | avatar breathing freeze 第一 frame + posture instant cut(Rule 11;同屏即場生效)|
| Loading | — | **冇 loading state** — 全 local sync read(Rule 7),OPENING 係純 animation state |
| Timer-bearing transients | — | toast **3000ms** auto-dismiss(`ERROR_TOAST_DURATION_MS`)/ lock nudge **5000ms**(`LOCK_NUDGE_DURATION_MS`)/ arrow settle 後 hold **~1.2s** fade 200ms — 全部行 injected clock(GDD seam)|

---

## Interaction Map

Mapping for: **Touch(primary,single-tap)+ Keyboard/Mouse(desktop)**。Gamepad: none(tech-prefs)。全部 tap target ≥48px(AC-45a 自動驗)。無 hover-only、無 long-press(Rule 22)。

| Component | Action | Input | Feedback(visual/audio)| Outcome |
|---|---|---|---|---|
| 入口 affordance(shell)| tap | touch / click | `ui_charscreen_open`(thock+紙)| open() → OPENING |
| Close X | tap | touch / click / ESC | `ui_charscreen_close`(短 reverse)| CLOSING(player-initiated 先有 SFX)|
| Tab | tap | touch / click | snap-switch 80-120ms,silent | active_panel 切換 + visibility re-read(Rule 23)|
| Slot card 主體 | tap | touch / click | `ui_sheet_open` | ITEM_INSPECT |
| 「更換」button | tap | touch / click | `ui_sheet_open` | SLOT_PICKER(bottom sheet)|
| Lock toggle | tap | touch / click | `ui_lock_on` / `ui_lock_off`(細金屬 click)| `set_lock(item_id, bool)` → 同 frame re-read |
| Picker row | tap | touch / click | slot card crossfade ~120ms + stat tween + `ui_equip_settle`(settle 1 響)+ lock nudge | `equip(item_id, slot)` → 同 frame re-read;close sheet |
| Nudge [鎖定] | tap | touch / click | nudge 變「已鎖定」| `set_lock(item_id, true)` |
| Salvage 入口(inspect 內)| tap | touch / click | `ui_sheet_open`(modal)| SALVAGE_CONFIRM |
| Salvage confirm CTA | tap | touch / click / ENTER(focus 唔 default 喺度)| card fade-collapse 200ms + shards snap + `ui_salvage_execute` | `salvage(item_id)` |
| Modal cancel / scrim / ESC 第一下 | tap / key | touch / click / ESC | `ui_sheet_close` | dismiss modal = cancel(EC-07;destructive-safe)|
| P-07 slider | drag / release | touch drag / mouse / ←→(±10pct)| label 即時;release → HIT_HEAVY preview shake(**screen 自己都震** — layer 60)| per-frame coalesced setter;release persist(debounce)|
| P-08 toggle | tap | touch / click / SPACE | `ui_toggle_flip` + avatar 即場 freeze/恢復 | `set_motion_reduction` + persist + Rule 11 |
| Volume slider | drag / release | 同 P-07 | 音量變化本身係 feedback(全程零 SFX)| G-CS-11 linear setter(persistence #4 own)|

**Keyboard-only path(desktop)**:TAB 順序 = close X → tab bar → tab content(rows/cards/controls 順序)→ modal 內(default focus = cancel);ESC = modal 先、screen 後。

## Events Fired

MVP **零 analytics event**(#28 Telemetry v0.2 — 刻意,唔係漏)。Persistent game-state writes(架構 attention 項):

| Player Action | Event / Write | Payload |
|---|---|---|
| equip / unequip / set_lock / salvage | #17 command(synchronous Dictionary return;persistence #17 own)| item_id, slot |
| P-07 / P-08 settle | `PersistenceLayer.write("settings.*", v, …)`(close path → flush=true)| quantized 值 |
| Volume settle | #4 setter(persistence #4 own `audio.master_db`)| linear s |
| 第一次讀 stat | `charscreen.stat_watermark.[stat_id]` write-once | {value, date} |
| 開 screen / 閂 screen | 無 event(pure overlay — Rule 2)| — |
| SFX / ARIA | `play_sfx(event_id)` ×11 cues;`announce_aria`(Rule 12/32)| — |

## Transitions & Animations

| Transition | Spec |
|---|---|
| Screen enter | opaque `ui_ink_bg` slide-up + fade **150-200ms ease-out**;content 一次過 final(禁 staggered pop-in — #21 S1 紀律)|
| Screen exit(player)| 120-150ms ease-in |
| Force-close | ≤150ms fast path(`FORCE_CLOSE_MAX_MS` knob);SUSPENDED = instant snap |
| Tab switch | snap 80-120ms |
| Bottom sheet / modal | slide-up 150-200ms + scrim;**無 elastic**(#21 ceremony 文法)|
| Stat tween | F1:300ms(200-400 band)cubic ease-out,**零 overshoot**(pinned);↑/↓ arrow settle 後 hold ~1.2s fade 200ms |
| Slot card 更新 | crossfade ~120ms |
| Salvage 執行 | card fade-out + collapse 200ms;shards **snap**(無 celebration)|
| Reduced motion | P-08 ON → avatar breathing freeze + posture instant cut(Rule 11);screen 自身 enter/exit fade 保留(≤200ms 短 fade,唔屬 camera/shake motion class;P-07=0% 殺晒 shake)|

**Motion sickness audit**:本 screen 零 shake 零 particle 零 parallax(L0-L3 ceiling = static amber accent);唯一 motion = 短 fade/slide + stat tween + avatar 2-frame breathing(P-08 freeze)。

## Data Requirements

| Data | Source System | Read / Write | Notes |
|---|---|---|---|
| 7 stats | #11 `get_stat` + `stat_changed` subscribe | Read | 禁 poll / 禁 `_base`;EQUIPMENT source 先 tween |
| Loadout / item detail / aggregate / shards / yield | #17 getters(G-CS-1 gated:`get_loadout` / `get_items_for_slot`)| Read | `get_item()` 回 live ref — read-only-by-discipline |
| Equip / unequip / lock / salvage | #17 commands | Write | synchronous return;同 frame re-read;NO optimistic UI |
| Avatar visual ×5 getters + `avatar_visual_updated` | #26(CR-11)| Read | plain connect(cfis 係 phantom — Pass 1)|
| GSM state | #1 `get_current_state` + `state_changed`(cfis)| Read | force-close driver |
| settings.* / charscreen.* | #3 PersistenceLayer | Read+Write | G-CS-3 namespace;close path flush |
| Motion / camera / volume setters | #6 / #7 / #4 | Write(setter)| 值 semantics 由 consumer own;#22 純 UI surface |

**架構 flag**:#22 唔 own 任何 game data(GDD Overview);唯一 #22-owned persist = `charscreen.stat_watermark`(presentation-layer 記錄,write-once)。

## Accessibility

(Tier:accessibility-requirements.md — 未定名 tier 但有 binding 條款;G-LM-6 / #21 story-025 先例 = SR announcements BLOCKING 級)

- **Keyboard-only**:全 interactive elements TAB-reachable(順序見 Interaction Map);ESC modal-first;slider ←→ ±10pct(clamp 唔 wrap,EC-28);destructive modal default focus = cancel(AC-51)
- **Gamepad**:N/A(tech-prefs none)
- **Contrast / font**:CJK body **Zpix 12px floor**(AC-43a 自動驗);amber/ink 雙色紀律;greyscale check §4.C(AC-47)
- **Color-independent**:↑/↓ arrow 方向由 glyph 形狀 carry(**永不紅綠**);rarity 永配文字 label(P-06);lock on/off 兩款 glyph
- **Screen reader**(`platform_detect.announce_aria`,shipped):avatar 變化(Rule 12,coalesce)/ command 結果 + settle coalesced stat announce(Rule 32)/ settings 值(EC-28 coalesce)/ toast = live region;AC-44 真 AT walkthrough(#26 L994 audit gate 驗收位)
- **Reduced motion**:P-08(host 喺本 screen)→ camera + avatar breathing freeze;P-07 0% → 零 shake;EC-24 唔 fake shake
- **Touch**:全部 ≥48px(AC-45a/b);card 3-zone 分割每 zone 獨立 ≥48px

## Localization Considerations

- **最長文字元素**:provenance_text(「拾於 6月3日・腿日」~10 字,安全)/ LEGENDARY `signature_text`(可長 — wrap 優先,死限 ellipsis + inspect 全文;EC-14)/ lock nudge ~20 字(LOCK_NUDGE_DURATION_MS 下限 4s 由 CJK 讀速推導)
- **Layout-critical**:tab labels(一行)/ AntiSnowball badge 文案(同 F4 數字 bijective — 唔可以斷行拆數字)/「[鎖定]」inline action(一個 tap word)— **HIGH PRIORITY for 40% expansion check**
- **逐 string font 指派表**:CJK(Zpix)vs latin/數字(m6x11)混排 baseline — **本 spec 留俾 implementation 前嘅 string table**(GDD ux R5 mandate;#21 L578-583 先例:11px latin H1 < 12px CJK 係接受嘅 inversion,hierarchy 由 position/weight 補)
- **Locale formats**:watermark / provenance dates = **device local**(EC-15;跨 timezone 顯示日期可變 — 接受並寫明);數字無千分位(ledger verbatim;shards 禁 K/M)

## Acceptance Criteria

(Spec-level — GDD 57 ACs 係 implementation 真源;呢度係 QA 可獨立行嘅 screen-level checks)

- [ ] **Performance**:screen open 由 tap 到 content 完整可見 ≤ 200ms(一個 enter animation 內;冇 loading state — 數據第一 frame 已齊);60fps 期間 4-row 並行 tween 唔跌 frame(mobile tier:AC-49 RATIFICATION-GATED)
- [ ] **Navigation**:GSM IDLE 時 shell 入口 tap → screen 開;X / ESC 閂返;workout state 時入口唔存在;force-close ≤150ms 兼 modal 全 cancel
- [ ] **Empty/error**:空 slot 顯示 dotted empty-state;picker 0 件照開 sheet + copy;command error → toast(同屏最多 1 條)+ 對應 ARIA announce;offline 時全功能照用、唯一分別係 banner
- [ ] **Accessibility**:keyboard-only 行到晒全部 interactive elements(modal default focus = cancel);全 tap targets ≥48px;CJK 字永不細過 12px;SR 聽到 equip/salvage/error/avatar/settings 五類 announcement
- [ ] **Core purpose(門框)**:stat 變化只喺 EQUIPMENT source 先有 tween+arrow(reconciliation = snap);watermark 行喺 current≠first-seen 時出現、新帳號唔出廢話行;provenance 日期全 tier 可達(inspect)
- [ ] **Destructive 保護**:salvage 由 tap 到執行必經 confirm modal;scrim tap / ESC 第一下 = cancel;locked item salvage 入口 disabled + hint
- [ ] **Settings 即時性**:slider drag 期間 screen 實時反映(motion 值 per-frame apply);P-08 ON 嗰下 avatar 同屏停止 breathing;release 後 preview shake 震埋成個 screen(layer 60)
- [ ] **Resolution/viewport**:360×560 min viewport 下 Z1-Z3 fixed zones 全可見、Z4 scroll 正常、無 horizontal scroll;desktop 寬屏 content column 置中(max-width ~560px)無拉伸

## Open Questions

| ID | Question | Owner |
|---|---|---|
| UXQ-1 | **Player journey map 未建立**(`design/player-journey.md` 唔存在;template @ `.claude/docs/templates/player-journey.md`)— 本 spec 嘅 arrival context 係由 GDD Player Fantasy 推導,journey 建立後要 reconcile | producer / ux |
| UXQ-2 | 入口 affordance 喺 shell 嘅具體形態(icon?label?位置?)— Q-CS1,#24 design 時連 hidden-vs-greyed + flicker 一齊裁 | #24 |
| UXQ-3 | 逐 string font 指派表(CJK/latin 混排)— implementation 前以 string table 形式補(GDD ux R5) | epic story |
| UXQ-4 | 4 個 NEW patterns(ledger-watermark-line / three-zone-item-card / inline-nudge-strip / destructive-confirm-modal / bottom-sheet-picker)入 pattern library — 隨 G-CS-6 errata batch 或獨立 /ux-design patterns session | ux |
| UXQ-5 | Accessibility tier 未正式定名(條款散喺 accessibility-requirements.md)— 考慮 WCAG-AA baseline;/gate-check 會驗 | producer |

---

## Cross-Reference Check(2026-06-07)

- **GDD requirements**:UI Requirements 全章 cover(layout 結構 / pattern 引用 / 實作要求 / 入口 provisional);Visual/Audio 全 per-event 表反映喺 Interaction Map + Transitions ✓
- **New patterns to add to library**:5 個(UXQ-4)— flagged as gap,唔 block
- **Navigation mismatches**:none(#20/#21 唔直接互通;shell #24 未 design = provisional,非 mismatch)
- **Accessibility gaps**:tier 未定名(UXQ-5);條款層面全 cover
- **Missing empty states**:none(slot / picker / fresh-install / watermark suppress 全有)
