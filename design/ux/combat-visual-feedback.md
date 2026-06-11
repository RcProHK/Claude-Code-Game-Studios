# UX Spec: Combat Visual Feedback (#25)

> **Status**: ✅ APPROVED(`/ux-review` 2026-06-11 — 0 BLOCKING / 4 ADVISORY;output-only diegetic N/A-by-design section 與 avatar-renderer.md 先例一致)
> **Author**: user (frank) + ux-designer (full-autonomous inline)
> **Last Updated**: 2026-06-11
> **Journey Phase(s)**: In-workout combat (background auto-play) — no player-journey.md yet (gap noted in Open Questions)
> **Platform Target**: Web (HTML5/WASM) primary, Desktop secondary;mobile/tablet Safari budget binding
> **Template**: UX Spec
> **GDD**: `design/gdd/combat-visual-feedback.md`(APPROVED 2026-06-11)
> **Scope note**: #25 係 **output-only diegetic combat feedback**(per-hit reaction 層)—— **零玩家 input**。combat 喺玩家做 gym set 期間 background auto-play,玩家只用 peripheral glance。因此 Navigation / Entry-Exit / Interaction Map / Events 等「互動」section 誠實標 **N/A-by-design**(對齊 `design/ux/avatar-renderer.md` 同類 output-only spec 先例),full-spec 集中喺 **render-surface 嘅 peripheral legibility + tier 視覺辨識 + accessibility**。

---

## Purpose & Player Need

#25 嘅 player need 唔係「完成一個任務」,而係**喺餘光接收「呢下夠重」嘅感官回報**。玩家做緊一組深蹲、fovea(中央視覺)鎖喺啞鈴度,combat 喺畫面背景自動打;呢個 spec 要保證:**唔使望實畫面,單靠眼角一瞄(~1 秒)就讀到「啱啱發生咗勁嘢」**。

- **核心 need**:peripheral-glance 之下,combat 嘅 tier escalation(普通擊 vs 毀滅一擊)要**即時可辨**,而毋須玩家用 attention budget 去解讀數字。
- **冇咗會點**:combat 照樣 100% 正確 resolve(數學係 #13/#14 owned),但畫面靜默 —— Pillar 2(無壓力陪伴)仍 work,Pillar 3(Drop Euphoria 重擊快感)spectacle 缺席。即「眼角瞄到都係視覺獎勵」嘅 game-concept 兌現載體消失。
- **一句講晒**:玩家(被動)接收 combat feedback 時,想要嘅係 *「身體 peak 嗰刻,畫面邊緣同步開花」* —— 唔係去睇、係被抓到。

> Design principle(inherit GDD Section B,load-bearing 約束本 spec 全部 layout/state 決定):**「Foveal punch, Peripheral pulse」** —— tier signal **必須 encode 喺 peripheral-legible 維度**(全屏定格時長、高對比突發、邊緣動態),**唔可以淨靠 foveal channel**(數字 size/color 眼角讀唔到)。

---

## Player Context on Arrival

| 維度 | 狀態 |
|------|------|
| **何時遇到** | 任何 combat GSM state(`COMBAT_ACTIVE` / `BOSS_ENCOUNTER`)期間,即玩家做緊一組 workout |
| **之前做緊咩** | 物理運動(推 rep、咬牙、力竭)—— attention 主要喺身體,唔喺 screen |
| **情緒狀態** | 體力消耗中、注意力極有限、device 距離 30-60cm、只有間歇 peripheral glance(黃金 glance 時刻往往係 *set 之後* 抬頭嗰一瞄,唔係 hit 發生嗰 0.3 秒) |
| **自願定被送** | **被送**(combat 由系統 auto-play 觸發);玩家從不主動「打開」呢個 feedback 層 |
| **input** | **無** —— 玩家對 #25 零互動(見 Interaction Map N/A) |

**設計含義**:因為玩家注意力被身體佔據 + glance 稀疏,(1)tier signal 要喺最少注視時間內讀到 → 走 peripheral channel(pause/flash);(2)floor 層要有低強度持續存在感(「角色一直幫緊我打」),但唔可以嘈到搶 attention(Pillar 2「稀疏即重量」);(3)climax 應留少許餘韻俾「遲到一瞥」接得返(afterglow → v0.2,Q-CV5)。

---

## Navigation Position

**N/A-by-design** —— #25 唔係一個可導航嘅 screen,係一個**常駐 diegetic feedback 層**,喺 combat GSM state 期間自動 active,無 menu entry / back button / 玩家可達路徑。

唯一「位置」概念 = render 拓撲(見 Layout Specification):兩個 #25-owned CanvasLayer —— `CombatNumberLayer`(follow-viewport,sort 坐 ParticleLayer[10] 上 / HUDLayer[50] 下)+ `CombatOverlayLayer`(105,全屏)。兩者均 below loot ceremony(CelebrationVFXLayer 110)→ loot 永遠視覺壓過 combat overlay。

---

## Entry & Exit Points

**N/A as navigation** —— 無玩家觸發嘅 entry/exit。以 **lifecycle**(非 navigation)描述:

| Lifecycle | 觸發 | 行為 |
|-----------|------|------|
| **Active** | boot 後 default;combat state 期間 | 接收 `hit_resolved`/`enemy_killed` → routing(GDD R-3..R-11);`_process` 推 number pool rise/fade + overlay decay |
| **Suspended** | `GSM.state_changed → Suspended`(bfcache / background) | force reset:number pool 全 release+hide、overlay OFF、coalescing/dedup clear、reject incoming(silent no-op)。對齊 #6「Suspended 永遠覆蓋一切」契約 — resume 無殘留 |

玩家**唔可以**「離開」呢個層 —— 佢喺背景持續存在,只隨 GSM lifecycle 開關。

---

## Layout Specification

### Information Hierarchy

按 **peripheral-glance 可讀性** 排(唔係 foveal 重要性):

1. **Tier escalation signal(最高 peripheral 優先)** = **hit-pause 定格 + climax flash**。全屏定格係唯一一個眼角 100% 捕捉得到嘅效果(peripheral vision 對 motion 突然消失最敏感);flash 係高對比突發。**tier 主要靠呢兩者承載,唔靠數字。**
2. **Hit registration(foveal bonus)** = **floating damage number**。俾偶然真係盯住嘅玩家睇「數值紋理」;眼角只當佢係「有嘢登記咗」嘅模糊動態。
3. **Climax peak marker** = flash overlay(CRITICAL/OVERKILL/critical-kill)= 情緒峰值的驚嘆號,稀疏出現。
4. **Co-triggered(非 #25-render)** = particle(#5)+ shake(#6 auto-dispatch)+ SFX(#4)—— #25 觸發但唔自 render。

> ⚠️ **唔做**:用「數字大細 / 顏色階梯」做 tier 主要區分 —— 眼角讀唔到,違反 Player Fantasy design principle。number color(暖/白)只係 `is_crit` 嘅 foveal bonus,**唔係 tier 載體**。

### Layout Zones

| Zone | Render host | Sort | 內容 | Shake-affected |
|------|-------------|------|------|----------------|
| **Combat Number Plane** | `CombatNumberLayer`(#25-owned CanvasLayer,`follow_viewport_enabled=true` 跟 active Camera2D) | ParticleLayer[10] 上 / HUDLayer[50] 下 | floating damage number(world-anchored 喺 combat focal point) | **是**(#6 world-shake shader uniform 施落此 layer → 跟 world 一齊震) |
| **Combat Overlay Plane** | `CombatOverlayLayer`(#25-owned,layer 105) | 全屏,>100 故 shake/BBCopy-immune;<110 故 loot ceremony 永遠蓋過 | climax flash(CRITICAL/OVERKILL/critical-kill,single-instance latest-wins) | **否**(>100 immune;flash 本身唔需跟 shake) |

> **host topology**:兩個 layer 均 #25-owned(autoload 自管),`CombatNumberLayer` 用 follow-viewport 解決「autoload-owned 但要 world-anchored + shaken」嘅矛盾。兩 layer 嘅 ADR-0001 amendment = Q-CV2 ratification scope。未 ratify 前:overlay degrade(無 flash,EC-20)、number 用 fixed-viewport(仍可讀,唔跟 shake)。

### Component Inventory

| Component | Zone | Pattern | Interactive | Notes |
|-----------|------|---------|-------------|-------|
| **Floating damage number** | Number Plane | **[P-10 damage-number-popup](interaction-patterns.md)**(⚠️ 需 sync — 見 Cross-Ref) | **否** | Label pool(`MAX_CONCURRENT_DAMAGE_NUMBERS=12`,acquire/release,`_process` 自管 rise+fade,**無 per-label Tween / 無 runtime alloc**);number style = `is_crit`(暖橙 bounce)vs plain(白);**tier 唔靠 number** |
| **Combat climax flash** | Overlay Plane | **NEW pattern → combat-climax-flash**(library 無,flag 入 library) | **否** | 全屏 ColorRect + analytic shader(無 texture asset);single-instance latest-wins;CRITICAL opacity 0.35 / OVERKILL 0.6;Formula 2 線性衰減;× motion_intensity |
| Hit particle | (render = #5,非 #25-layer) | — | 否 | #25 `play(HIT_LIGHT/HIT_HEAVY)` 觸發,#5 own render + 200 cap;coalescing(GDD R-15) |
| Screen shake | (render = #6 shader uniform) | — | 否 | #6 auto-dispatch(HIT_HEAVY/DEATH burst → shake);#25 **唔 direct shake**(R-13) |

### ASCII Wireframe

```
┌─────────────────────────── viewport(combat 進行中)───────────────────────────┐
│                                                                              │
│   [Gym-Mode HUD #20:HP / EXP / set-rep — 唔受 #25 影響,layer 50]            │
│                                                                              │
│                                                                              │
│                          ·  particle spark (#5)                              │
│                       847        ← floating damage number (Number Plane)     │
│                    ╱  avatar combat focal point(camera-relative,MVP)        │
│              [avatar silhouette #26]   ← 多 enemy 同擊 → number ±jitter 散開  │
│                                                                              │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
  普通 hit:細暗 number,無 flash,無 pause(floor 層)

┌──────────── CRITICAL / OVERKILL / critical-kill(climax)─────────────────────┐
│▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│ ← 全屏 flash (Overlay Plane 105)
│▓▓                                                                        ▓▓│   + hit-pause 定格 80ms
│▓▓                   1240!     ← critical number(暖橙 bounce 若 is_crit)  ▓▓│   + shake (#6 auto 0.4)
│▓▓                  ╱ focal point                                          ▓▓│
│▓▓           [avatar]                                                      ▓▓│
│▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│
└──────────────────────────────────────────────────────────────────────────────┘
  peripheral 上:全屏 luminance pulse + motion 突然定格 = 眼角必抓到「大事」
  (motion_intensity=0 → flash + shake 消失,**pause 保留** = 仍有 climax 感)
```

---

## States & Variants

| State / Variant | 觸發 | Number | Pause(#25 direct) | Flash(Overlay) | Particle / Shake |
|-----------------|------|--------|-------------------|----------------|------------------|
| **NEGLIGIBLE**(非 kill) | `damage_tier=NEGLIGIBLE` | — | — | — | — (零反應,floor 由 LIGHT 撐) |
| **LIGHT** | `damage_tier=LIGHT` | 細暗 | — | — | HIT_LIGHT;無 shake |
| **MEDIUM**(MVP) | `damage_tier=MEDIUM` | 中(白) | — | — | HIT_LIGHT(共用);無 shake |
| **HEAVY** | `damage_tier=HEAVY` | 大(白) | 65ms | — | HIT_HEAVY → auto shake 0.4 |
| **CRITICAL** | `damage_tier=CRITICAL` | 大(暖若 is_crit) | 80ms | **CRITICAL flash** | HIT_HEAVY → auto shake 0.4 |
| **KILLED**(tier<CRITICAL) | `outcome=KILLED` | kill-confirm | — | — | 死亡 VFX = #14(auto shake 0.3) |
| **KILLED**(tier==CRITICAL) | `outcome=KILLED` 招牌 carve-out | kill-confirm | 80ms | **CRITICAL flash** | #14 DEATH shake 0.3 + #25 flash/pause |
| **OVERKILL** | `outcome=OVERKILL` | overkill | 80ms | **OVERKILL flash** | #14 DEATH shake 0.3 |
| **Degrade(EC-20)** | `CombatOverlayLayer` 未 ratify | 照彈 | **CRITICAL→100ms**(加闊補償 flash 缺席) | 無 | 照常 |
| **Reduced-motion** | `motion_intensity==0` | 照彈 | **保留**(visual freeze ≠ vestibular) | **無**(opacity×0) | shake 消失 |
| **Suspended** | `GSM→Suspended`(bfcache) | 全 release+hide | force OFF | force OFF | — (reject incoming) |
| **Empty(無 combat)** | 非 combat state | 無 | 無 | 無(IDLE zero-cost short-circuit) | 無 |

---

## Interaction Map

**N/A-by-design** —— #25 **零玩家 input**。combat 係 background auto-play;damage number 同 flash overlay 都係**非互動 diegetic feedback**,玩家從不 tap / click / hold / drag 佢哋。

- **無 tap target**:damage number 唔可 tap(唔似 P-09 single-tap-exercise-switch 嘅 GymSys input);overlay 唔截 input。
- **input passthrough**:兩個 #25 CanvasLayer 必須 `mouse_filter = IGNORE`(Control)/ 唔放 input-consuming node —— 確保唔偷走玩家對下層(HUD #20 / GymSys exercise-switch)嘅 one-tap(AC 驗)。
- 唯一「input」相關 = **accessibility setting**(`motion_intensity` slider),但嗰個係 **#22 Character Screen / #6 owned**(P-07 motion-intensity-slider),唔喺 #25 render surface;#25 只 read-only 消費。

---

## Events Fired

**幾乎 N/A** —— #25 係 signal **consumer**(subscribe #14),唔係 player-facing event emitter。

| 來源 action | Event Fired | Payload | Notes |
|-------------|-------------|---------|-------|
| (無玩家 action) | — | — | 玩家對 #25 零互動 |
| 每次 routing 完成 | (可選)telemetry hook `combat_feedback_shown{tier, outcome}` | tier/outcome | **deferred 去 #28 Telemetry**;MVP 唔 fire;`enemy_killed` 已係 #25 嘅 non-visual cleanup hook(evict coalescing dict),非 analytics |

**無 persistent state write** —— #25 唔改 save data / progress / economy(純 presentation)。

---

## Transitions & Animations

| Transition | Spec | Reduced-motion alternative |
|------------|------|----------------------------|
| **Damage number 出現** | spawn at focal point + jitter;Formula 1 `y_offset` ease-out rise + 後半 `alpha` smoothstep fade(`LIFETIME` 0.8s default);`is_crit` 加 overshoot bounce(settle) | number 照彈(rise+fade 係資訊性非 vestibular,保留);bounce 可由 reduce-motion 拆走(advisory) |
| **Damage number 消失** | `t ≥ LIFETIME` → release 返 pool;pool 滿 → oldest-recycle(latest-wins) | 同上 |
| **Climax flash 出現** | Formula 2 `overlay_alpha = MAX_OPACITY × max(0, 1 − t/DURATION)` 線性衰減;latest-wins reset | **motion_intensity=0 → opacity×0 = 無 flash**;pause 保留 |
| **Hit-pause 定格** | #25 direct `hit_pause(0.065/0.080)`(填 #6 HIT_HEAVY/DEATH pause=0 缺口);經 #6 max-remaining 合併 | **pause 保留**(a11y doc:visual freeze 明確 distinct from vestibular shake,motion_intensity=0 唔取消 pause) |
| **Screen enter / exit** | N/A(#25 唔係 screen;隨 GSM combat-state lifecycle 開關,無 screen-transition 動畫) | — |
| **bfcache resume** | force overlay OFF + number pool clear + `_process` 入口 `delta = min(delta, MAX_FRAME_DELTA=0.1)` clamp(防大 delta 令 number 一 frame 跳完 / overlay 殘留) | — |

> **Motion-sickness 風險**:全屏 flash = luminance pulse(photosensitivity 而非 vestibular)。MVP 用 `motion_intensity` 一併 gate(=0 → 無 flash);獨立 photosensitivity toggle(reduce-motion ≠ reduce-flash 係兩條軸)→ Q-CV6 v0.2。WCAG 2.3.1(≤3 flash/sec)由 single-instance latest-wins + coalescing 結構保證。

---

## Data Requirements

| Data | Source System | Read / Write | Notes |
|------|--------------|--------------|-------|
| `damage_tier`(routing key) | #14 EnemyDirector `hit_resolved` payload | Read | FR Test #4 — **必消費 tier,唔可 re-classify by value**(GDD R-2) |
| `outcome`(KILLED/OVERKILL/…) | #14 `hit_resolved` payload | Read | R-3 outcome-first gate |
| `is_crit`(number style) | #14 `hit_resolved` payload | Read | 與 `DamageTier.CRITICAL` 雙軸解耦(R-12) |
| `target_id` / `transition_id` | #14 `hit_resolved` / `enemy_killed` | Read | dedup(R-14)+ coalescing key(R-15);無 `position` field(R-17) |
| combat focal point | active Camera2D(camera-relative) | Read | MVP primary;**#26 anchor API grep 證實唔存在 → v0.2-only**(R-17/Q-CV4) |
| `motion_intensity` | #6 ScreenEffects / `settings.motion_intensity` | Read | overlay opacity × 之(a11y);hit_pause **唔**乘 |
| (internal)coalescing / dedup / pool state | #25 自管 | Read/Write(internal) | 非 game state;`enemy_killed` evict per-target entry(防 leak) |

**架構關注**:#25 **零 game-state write**(presentation-only,fail-soft)。唯一 read-only 跨系統 = #14 payload(hard)+ camera(soft)+ #6 motion_intensity(soft)。combat 數學由 #13/#14 owned,#25 缺席 = graceful degrade。

---

## Accessibility

> Tier = **WCAG AA Core + Motion Safety**(`design/accessibility-requirements.md`,binding from MVP)。

| 要求 | #25 如何滿足 |
|------|-------------|
| **Color independence**(每 semantic ≥2 非-color signal) | tier **唔靠 color 傳達** —— 走 pause 時長 + flash presence + particle 大細(#5);number color(暖/白)只係 `is_crit` 嘅 foveal bonus,**非 tier 載體**。greyscale 下 tier 仍可讀(QA desaturated screenshot protocol) |
| **Motion safety**(`motion_intensity` 0-1,default 1) | overlay flash opacity × `motion_intensity`(=0 → 無 flash);shake 由 #6 gate(=0 → 無 shake);**hit_pause 保留**(a11y doc §2:visual freeze distinct from vestibular)→ motion-sensitive 用戶仍有 climax 定格感 |
| **Photosensitivity**(WCAG 2.3.1 ≤3 flash/sec) | single-instance latest-wins(連續 climax 互相 replace 唔疊)+ coalescing → 結構上唔可能 >3 flash/sec;single flash ≤0.18s。獨立 reduce-flash toggle → Q-CV6 v0.2 |
| **Input simplicity**(single-tap primary) | #25 零 input;CanvasLayer `mouse_filter=IGNORE` 確保唔偷 GymSys/HUD 嘅 one-tap |
| **Contrast / glance readability**(30-60cm,peripheral) | number = high-contrast amber/white + 1px ink shadow;overlay 高對比 luminance pulse;**tier 走 peripheral channel**(pause/flash)正正係 glance-first |
| **Screen reader**(v0.2+ deferred) | damage number = 純 feedback,gameplay 唔依賴讀佢(P-10 + a11y doc:SR ignore);combat outcome 嘅 canonical truth 喺 #14,非 #25 render |

---

## Localization Considerations

#25 嘅 l10n surface **極細**(diegetic feedback 主要係數字 + 程序 overlay,無大量文字):

| 元素 | l10n 考量 | 優先 |
|------|-----------|------|
| **Damage number** | 純數字;**locale digit grouping**(千分位 — 大傷害如 `1,240` vs `1240`)應跟 locale。字寬:5 位數 fit focal area | LOW(數字短) |
| **Kill-confirm marker** | 建議用 **icon / glyph**(✕ / 骷髏)而非文字「擊殺」—— 避 l10n + peripheral 上 glyph 比字快讀 | MED(若用文字需 l10n + 字寬) |
| **Overlay flash** | 純程序 luminance,**零文字** | — |
| Accessibility setting label | `motion_intensity` slider 文字喺 #22(P-07),非 #25 | — |

**無 40% text-expansion 風險**(無 layout-critical 文字 label)。kill-confirm 若最終用文字 → flag 俾 localization engineer;預設用 glyph 規避。

---

## Acceptance Criteria

> 對應 GDD §Acceptance Criteria;UX-specific(ADVISORY screenshot + lead sign-off,除註明)。

- [ ] **UX-01 [perf]** damage number 峰值 ≤ 16 draw call(share font atlas);全屏 overlay 同時 ≤ 1 active(≤1 blend pass);overlay IDLE 時 zero per-frame cost。(對應 GDD AC-28 CI-testable 部分)
- [ ] **UX-02 [peripheral legibility / 核心 purpose]** 喺固定 viewport + 1 秒 glance(fovea 唔對準 focal point),tester 能分辨「普通 hit(無 flash)」vs「climax(flash + 定格)」**主要靠 flash + pause**,非 number size/color。art-director sign-off。(GDD AC-26/27)
- [ ] **UX-03 [tier 區分]** HEAVY(無 flash)同 CRITICAL(flash + 80ms)喺 peripheral 明顯有別;degrade mode(無 flash)下靠 `CRITICAL_DEGRADE_PAUSE_SEC=0.100` vs HEAVY 65ms 嘅 ≥35ms 差仍可辨。
- [ ] **UX-04 [accessibility — motion]** `motion_intensity=0` 時:**無 flash + 無 shake**,但 **hit_pause 定格仍在**(climax 感保留)。可驗(spy overlay opacity==0 + #6 shake==0 + hit_pause 照 fire)。(GDD AC-25)
- [ ] **UX-05 [accessibility — color independence]** desaturated(greyscale)screenshot 下,tier escalation 仍可讀(tier 靠 pause/flash/particle,非 color)。QA desaturated protocol。
- [ ] **UX-06 [input non-interference]** #25 兩個 CanvasLayer **唔截 input** —— combat 進行中 + flash active 時,玩家對 HUD(#20)/ GymSys exercise-switch 嘅 one-tap **照常生效**(`mouse_filter=IGNORE` 驗)。
- [ ] **UX-07 [lifecycle]** bfcache resume(Safari pagehide→pageshow)後:無殘留 number / 無殘留 flash(force clear + delta clamp)。(GDD AC-17)
- [ ] **UX-08 [l10n]** damage number 跟 locale digit grouping;kill-confirm 用 glyph(無 layout-critical 文字)或若用文字則 fit + 已交 localization。

---

## Open Questions

| ID | Question | Owner | 解決時機 |
|----|----------|-------|----------|
| **UXQ-CV1** | combat-hit SFX cue 契約(tier→cue + onset 對齊 visual peak;silent-mode 下 visual 必須獨立完整可讀)。= GDD Q-CV1。 | audio-director + #25 owner | #4 audio cue 落地 / epic-time |
| **UXQ-CV2** | `CombatNumberLayer` + `CombatOverlayLayer(105)` ADR-0001 amendment(兩層)+ BBCopy enumeration。= GDD Q-CV2。 | technical-director + ADR-0001 owner | architecture / epic-time |
| **UXQ-CV6** | 獨立 photosensitivity toggle(reduce-motion ≠ reduce-flash 兩條 a11y 軸 — MVP 用 motion_intensity 一併 gate)。= GDD Q-CV6。 | ux-designer | v0.2 |
| **UXQ-P10-SYNC** | **P-10 damage-number-popup pattern 已 drift** vs APPROVED #25 GDD(P-10:cap 6 / spawn at hit position / overshoot scale / family color;#25:cap 12 / camera-relative focal / Formula 1 rise+fade / 無 family color / tier 唔靠 number)。需 sync P-10 至 #25 GDD(跟 G-CS-6/G-LM-7 sync-note 先例)。 | ux-designer | epic-time(pattern library pass) |
| **UXQ-NEWPATTERN** | **combat-climax-flash 係新 pattern**(全屏 single-instance latest-wins luminance pulse,× motion_intensity,layer 105,無 texture)→ 加入 `interaction-patterns.md`(建議 P-19)。 | ux-designer | epic-time(pattern library pass) |
| **UXQ-JOURNEY** | 無 `design/player-journey.md` —— 本 spec 嘅 player context 係由 game-concept + GDD Section B 推斷。建議 combat/workout journey phase 正式 map。 | ux-designer | 之後 dedicated player-journey pass |
| **UXQ-CV3** | hit 精確 contact position(per-enemy 定位)— MVP camera-relative focal 近似;v0.2 #14 加 `get_enemy_render_position`。= GDD Q-CV3。 | #14 + #25 owner | v0.2 |
| **UXQ-CV4** | #26 render anchor read API — grep 證實暫無(render-only);v0.2 #26 加 `get_render_anchor()` 先做精確 avatar-relative 定位。= GDD Q-CV4(MVP 已 resolve = camera-relative)。 | #26 + #25 owner | v0.2 |
