# Screen Effects System

> **Status**: Approved (CD-GDD-ALIGN passed 2026-05-26, full mode, single session, single pass)
> **Author**: Frank + creative-director (a3f030c3f0317d5eb / a776bf78f6926ccd7) + systems-designer (a49e21644f8a9e98d / ac5b3b4ef4bd6a623 / aaba3cf41b12031a9) + gameplay-programmer (ab3b4b6bd141d9c87) + technical-artist (aaf1677901d9b4b93) + qa-lead (a0407ddf3a9318391) + art-director (a1e7fc6de719120e7)
> **Last Updated**: 2026-05-26
> **Implements Pillar**: Pillar 1 (co-presence via 體感 channel) + Pillar 2 (hero owner — workout-time background existence) + Pillar 3 (co-owner with #5 via 體感 channel; #5 owns 視覺 channel)
> **System #**: 6 (Foundation / VS tier)
> **Depends On**: #5 ParticleSystemWrapper (soft, burst_started signal) + #1 GameStateMachine (soft, state_changed via connect_for_initial_state per ADR-006 Contract 6) + SettingsManager autoload (soft, pending #22)
> **Depended On By**: #4 AudioManager (pending — hit_pause_started subscriber) + #14 EnemyDirector (direct caller + auto-dispatch via #5) + #21 Loot Drop Modal (auto-dispatch via #5) + #25 Combat Visual Feedback (direct caller + auto-dispatch via #5)
> **Governing ADRs**: ADR-006 State Machine Contract (Contract 6 for GSM subscription; Contract 4 for autoload sequential _ready) — ratified Proposed; ADR-001 Web Export Budget Caps — pending, FR-1/FR-2/FR-3 Risk Register binding
> **Creative Director Review (CD-GDD-ALIGN)**: APPROVED 2026-05-26 (agentId a776bf78f6926ccd7) — 8 findings (4 ALIGN + 4 ADVISORY OBSERVATIONS, 0 BLOCKING, 0 CONCERNS). CD assessment: "達到 #5 ParticleSystemWrapper 確立嘅「strongest pillar-coherent GDD to-date」precedent — 連同 #5 確立 Mirror Hero Foundation Sensation Infrastructure 嘅 architectural template". 4 advisory observations 傳遞到 #5 / #22 / #4 GDD authoring batch (FR-2 fallback path crystallize at VS-tier playtest, HUD readability sub-test in AC-28, audio fade-in curve audible-click validation, Q-F6 AudioManager ducking latency budget).

## Overview

Screen Effects System 係 Mirror Hero 處理「DNF feel 三件套」當中**非粒子**兩件（screen shake + hit pause）嘅 Foundation 層 singleton autoload — #5 Particle System Wrapper own 粒子，本系統 own 鏡頭擾動 + 時間擾動，三件套合一先 deliver 完整 Sensation #1 primary aesthetic。系統純粹係一個 typed API surface + closed effect library + state-aware coordinator：(1) 暴露 `shake(intensity: float, duration: float)` 同 `hit_pause(duration: float)` 兩個原語 API 畀 caller（主要係 #25 Combat Visual Feedback + #21 Loot Drop Modal 同各自 narrative wrapper），所有 caller 不可繞過去自己改 `Camera2D.offset` 或 `Engine.time_scale`，否則 effect stack 互相打斷（與 #5 嘅 closed preset 哲學一致）；(2) 維護一個 `ParticleSystemWrapper.burst_started` signal 嘅 **per-preset auto-reaction table** — 收到 `HIT_HEAVY` → shake intensity 0.4 / duration 0.12s，`PARRY` → shake 0.6/0.08s + hit_pause 0.06s，`DEATH` → shake 0.3/0.18s，`LOOT_RARE_BURST` → shake 0.2/0.15s（per #5 Section C 提議數值，本 GDD 鎖定為 source of truth）；HIT_LIGHT / STATUS_* / 普通 LOOT_BURST **唔觸發 shake/pause** — sensation hierarchy 要求 noise floor 嚴肅；(3) hit pause 採用 **selective freeze** — 用 Godot 4.6 `process_mode` 白名單機制凍結 gameplay scene tree 但 NOT freeze #1 GameStateMachine / #2 GymSysClient / #3 PersistenceLayer / autoload layer，避免 polling timer / state machine ticker 因 60ms hit pause 而 desync（`Engine.time_scale = 0` 嘅粗暴方案 reject）；(4) 訂閱 `GameStateMachine.state_changed`，喺 Suspended state 自動 cancel 所有 in-flight shake/pause 並 reject 新 request（防 background tab resume 時殘留 shake 撞 mid-frame jank）；(5) 提供 `set_motion_intensity(scale: float)` runtime knob (0.0..1.0) 由 #22 Character Screen settings 控制 — Pillar 2 嘅 accessibility 約束，shake amplitude 對 motion-sensitive 玩家 mid-set glance 唔可以引發 vestibular discomfort，`scale = 0.0` 完全 disable shake 但保留 hit pause（hit pause 唔屬 vestibular trigger）。系統 stateless from gameplay perspective — 唔 own 任何 game state，唔做 game logic decision，唔 emit 任何 gameplay event；純粹係「啲嘢已經發生咗，我做視覺/時間反應」嘅 reactive infrastructure。Implementation 嘅 `Camera2D` ownership topology、`process_mode` whitelist 具體範圍、Web Export bfcache restore 行為將喺 ADR-001 input scope 列為 budget validation item，本 GDD 屬 ADR-001 input scope。

## Player Fantasy

**Direct + Infrastructure fantasy — 眼角嘅爆擊 (Peripheral Strike)**:

玩家心入面嘅 felt promise：「**我做緊 bench press 第 8 rep，下巴貼地 grinding，視線冇離開 barbell — 但我眼角餘光啱啱感受到一吓凝固 + 輕震，唔需要轉頭都知 avatar 中咗 PARRY。Rep 推完放低 bar 嗰刻先擰頭睇，screen 上 particle trail 仲喺度漂浮，aftermath waiting 我嚟到。**」

呢個 fantasy 唔由 Screen Effects 自己 emit 任何敘事 text — 而係由佢嘅 **architectural posture** 強制：

- **Closed primitive surface** (`shake(intensity, duration)` + `hit_pause(duration)`) + **closed effect library** (HIT_HEAVY / PARRY / DEATH / LOOT_RARE_BURST 四個 trigger 級別嚴格鎖死，HIT_LIGHT / STATUS_* / 普通 LOOT_BURST 完全冇 shake/pause) — 確保 sensation hierarchy 嘅 noise floor 嚴肅到每一吓 shake 都 register 為「呢個係 worth-noticing event」嘅體感印章。Caller 不可繞過去自己 mutate `Camera2D.offset` 或 `Engine.time_scale`，否則 effect stack 互相 stomp，sensation hierarchy 崩潰
- **Per-preset auto-reaction table 嘅 intensity/duration 限喺 peripheral perception 範圍** (HIT_HEAVY 0.4/0.12s、PARRY 0.6/0.08s、DEATH 0.3/0.18s、LOOT_RARE_BURST 0.2/0.15s) — 玩家**唔需要 foveal vision 都接收到 sensation signal**。呢個 budget 唔係 designer "juice"，係 **peripheral receivability claim**：太弱 → 眼角失去 signal、Pillar 3 失效；太強 → mid-set vestibular discomfort、Pillar 2 違反。每一個 value 都係 peripheral-perception band 嘅 tight target
- **Selective freeze via `process_mode` whitelist** (而非 `Engine.time_scale = 0`) — Hit pause 凍結 gameplay scene tree 但 autoload 層 (GSM / GymSysClient / PersistenceLayer / ParticleSystemWrapper) 繼續 tick — 玩家潛意識永遠唔會因 60ms 嘅體感印章而 register 到「game 卡咗」嘅 micro-anxiety (Pillar 2 silent guarantee)
- **Suspended state auto-cancel** (subscribed to GameStateMachine.state_changed) — bfcache resume / tab visibility regain 嘅一瞬間，殘留 shake/pause 唔會撞 mid-frame jank。Pillar 2 嘅 「background existence」承諾延伸到 page lifecycle 邊緣

呢個 architectural-felt fantasy 同 GDD #5 ParticleSystemWrapper 嘅 「眼角擒獲 (Peripheral Capture)」係 **paired sensation infrastructure** — #5 own peripheral 嘅**視覺** signal (粒子 = 「望住」呢個 channel)，本 system own peripheral 嘅**體感** signal (shake + hit pause = 「冇望都感受到」呢個 channel)。兩個 channel 各自 architectural locked，合起來 deliver「DNF feel 三件套」嘅完整 peripheral promise。任何「呢度 shake 大少少應該得喎」嘅 ad-hoc 意圖都會被 closed primitive + closed effect library 強制 reject — 同 #5 嘅 「closed preset library」係同一個 architectural posture。

### Motion intensity slider — 校準感官 channel 闊度，非 accessibility afterthought

`set_motion_intensity(scale: float, 0.0..1.0)` 係呢個 fantasy 嘅 **first-class component**，唔係 「accommodate 弱小玩家嘅 concession」。每個玩家嘅 peripheral motion sensitivity 唔同 — 有啲玩家 0.4 intensity 已經分散 mid-rep 注意力，有啲玩家要 0.7 先 register signal。Slider 畀玩家**主動校準自己感官 channel 嘅 signal-to-noise ratio**。

`scale = 0.0` 路徑 (完全 disable shake、**保留 hit pause**) 係呢個 framing 嘅 honest endpoint：hit pause 本質上唔屬 vestibular trigger (時間擾動 ≠ 空間擾動)，所以即使最高 motion sensitivity 嘅玩家都仍可以收到 PARRY 嘅「凝固一吓」嘅 narrative signal，只係冇咗 shake 嘅 spatial reinforcement。呢個 split design 服務 Pillar 2 嘅 「workout-time use」reality：mid-set vestibular discomfort 對任何玩家都係 violation，唔係只係 「accessibility user」嘅事。

呢個 direct fantasy 直接 enables：

- **Pillar 1 (真身真力 — co-owner via co-presence)** — 玩家 grinding 緊嘅身體 effort 同 avatar 嘅 high moment 喺潛意識度 co-present，physical 出力嘅 release 同畫面 hit pause 嘅 release momentum 喺時間軸上 brush against each other (NOT 強制 sync — system 唔識真實 rep tempo)。「身體越強、avatar 越強」嘅 narrative 通過 peripheral 體感 co-presence 而非 foveal spectating 而 deliver
- **Pillar 2 (無壓力陪伴 — hero owner)** — Sensation hierarchy 嘅嚴肅 noise floor + intensity band 嘅 peripheral receivability budget + selective freeze 嘅 autoload 豁免 + Suspended auto-cancel — 四重 architectural guarantee Pillar 2 嘅 「workout 期間 BACKGROUND 存在」 promise。Motion intensity slider 將呢個 guarantee 延伸到 individual sensitivity 範圍
- **Pillar 3 (DNF 式爆裝刺激 — co-owner via 體感 channel)** — Sensation hierarchy 嘅嚴肅性 (HIT_LIGHT 冇 shake) 令 HIT_HEAVY / PARRY / DEATH / LOOT_RARE_BURST 嘅每一次 trigger 都成為 meaningful 體感印章 — DNF dopamine 通過 peripheral 體感 channel 而非 foveal attention demand 而 deliver。爆裝刺激嘅「儀式感」延伸到 set 期間嘅 rare drop event

**Falsifiable design test** — 任何 client-side path 引致以下情境 = bug，唔係 acceptable behavior：

1. 玩家做 bench press、avatar 啱啱 PARRY，但 shake 0.6 intensity 喺 mid-rep peripheral glance 中無法被 register 到 (intensity band 過弱或 implementation 未到 specified amplitude) → **眼角嘅爆擊 fantasy 違反 + Pillar 3 體感 channel 失效**
2. 玩家 set motion_intensity = 0.0 後，PARRY 仍然冇 hit pause (hit pause 錯誤 bound 到 shake intensity 而非自己嘅 duration argument) → **scale = 0.0 honest endpoint contract 違反 + accessibility user 失去 PARRY narrative signal**
3. Hit pause 60ms 期間 GameStateMachine 漏 tick (selective freeze whitelist 錯把 autoload 包入 frozen scope) → GymSys polling missed + state machine desync → **Pillar 2 silent guarantee 違反 + 玩家 register 到「game 卡咗」嘅 micro-anxiety**
4. EnemyDirector 同時 fire 8 個 HIT_HEAVY shake，shake 互相 stack 引致 mid-rep amplitude 超出 0.4 budget 上限 (shake combiner 冇實 max-clamp 同 envelope) → mid-set vestibular signal 變 mid-set vestibular discomfort → **Pillar 2 violation**
5. bfcache resume 一刻有殘留 in-flight shake (Suspended state auto-cancel 漏 trigger 或 timer race) → resume 第一 frame 出現未 expected 嘅 shake → 玩家 register 到「呢度有 jank」 → **bfcache silent guarantee 違反**
6. Caller 繞過 wrapper 自己改 `Camera2D.offset` 加自定 shake (e.g. #14 EnemyDirector 想加「老闆 spawn 大震」自定 shake) → effect stack 同 wrapper 嘅 shake 互相 stomp + sensation hierarchy 崩潰 → **closed primitive contract 違反 + 全 system 視覺一致性失效**

### Fantasy Risk Register

呢個 direct fantasy 嘅 「architectural posture」 framing 係 contingent on 以下 invariants 喺 **ADR-001 ratification + VS-tier playtest** 真正 enforced，否則 Player Fantasy paragraph 變 retroactive lie：

| # | Contingent Invariant | Owner | Fallback if Dropped |
|---|---------------------|-------|---------------------|
| FR-1 | Shake CPU cost (per active shake frame) + hit_pause selective-freeze overhead 喺 mobile Safari P95 frame time 預算內 — ADR-001 必須 ratify Screen Effects 嘅 CPU budget allocation (同 #5 嘅 GPU 預算分開 account) | ADR-001 | 若 budget 超出 → 限制 shake concurrent 數至 1 (新 shake replace 舊 shake，唔 stack)；OR 喺 mobile auto-降 default `motion_intensity = 0.6` — Pillar 2 protected at sensation cost |
| FR-2 | Per-preset auto-reaction table 嘅 intensity/duration values 喺 peripheral receivability playtest 中 PASS — HIT_HEAVY vs PARRY vs DEATH 喺 mid-set glance test 中可被玩家 unambiguously 「感受」分辨 (體感 signature 唔重疊) | art-director + VS-tier `/playtest-report` | 若分辨失敗 → 加大某 preset 嘅 intensity 或 duration 差距 (e.g. PARRY 提至 0.7/0.10s)；NOT 加 audio cue (本 system 唔 own audio) |
| FR-3 | Selective freeze `process_mode` whitelist 完整 cover 所有 critical autoload (GSM / GymSysClient / PersistenceLayer / ParticleSystemWrapper) 同未來 autoload — VS-tier CI test 必須 enforce whitelist drift detection (new autoload registered 但未加入 whitelist = build fail) | gameplay-programmer + tools/ci script | 若 CI enforcement 唔可行 → fallback hit pause 縮短到 30ms (大幅降低 single missed tick 嘅 detectable probability)；OR 強制 hit pause 只 freeze specific Camera2D + visual layer subset |

**Ratification gate binding**: ADR-001 review MUST verify implementation satisfies all 3 invariants before Status: Accepted。FR-3 嘅 CI enforcement 必須喺 first VS-tier autoload 增加之前 in-place — 否則 hit pause selective freeze contract 變 trust-based 而非 architectural locked。若 ADR-001 lands without FR-1/FR-2/FR-3 任何一個 → revisit this Player Fantasy paragraph with the corresponding fallback framing。

## Detailed Rules

### Internal States (4)

| State | Entry | Exit | Behaviour |
|-------|-------|------|-----------|
| **Active** | Boot 後 default state | 收到 `hit_pause()` → HitPaused；`GSM.state_changed → Suspended` → Suspended | 每 frame `_process` 更新 trauma decay，write `RenderingServer.global_shader_parameter_set("u_shake_offset", offset)`；接收 `shake()` / `hit_pause()` / dispatch events |
| **HitPaused** | `hit_pause(d)` call (從 Active 或本身) — set `get_tree().paused = true` | `_pause_remaining_sec <= 0` → 還原 `get_tree().paused = false` → Active | `process_mode = PROCESS_MODE_ALWAYS` 令 ScreenEffects 自己繼續 tick (decay pause timer)；其他 PAUSABLE nodes (gameplay + HUD + particles) 全凍；`shake()` 接收但 amplitude 凍喺 entry 嗰刻 value (見 Rule 5) |
| **Suspended** | `GSM.state_changed → Suspended`（直接覆蓋任何 state） | `GSM.state_changed → 非 Suspended` (state_changed handler return → Active) | Force reset: `_trauma = 0; _pause_remaining_sec = 0; _emit_depth = 0; get_tree().paused = false`；shader uniform force write `Vector2.ZERO`；reject 所有 `shake()` / `hit_pause()` / dispatch events (silent no-op + debug counter increment) |
| **Booting** | Boot 期間 (before first `_ready` returns) | `_ready()` complete → Active | API rejection (autoload not ready)；register `connect_for_initial_state` callback；register global shader uniform；CI 第一次 invocation 嘅 guard |

**Suspended 永遠覆蓋一切** (per locked Player Fantasy contract — bfcache resume = Suspended cancel 殘留 shake)。HitPaused 唔可以 race Suspended — Suspended entry sequence (Rule 13) 強制清空所有 pause / trauma / queue。

### Interactions (6)

1. **Upstream: `ParticleSystemWrapper.burst_started(preset_id, position)`** → ScreenEffects auto-dispatch (Rule 9 dispatch table). `position` argument reserved (forward-compat 未來 positional shake)
2. **Upstream: `GameStateMachine.connect_for_initial_state(_on_gsm_state_changed)`** → ADR-006 Contract 6 subscription. Suspended entry triggers Rule 13 cancel-all sequence
3. **Upstream: SettingsManager autoload** (pending #22 Character Screen GDD) → call `ScreenEffects.set_motion_intensity(scale)` 喺 boot (load saved value) + user 改 a11y slider 時。ScreenEffects 唔 read PersistenceLayer 直接 (per Rule 16)
4. **Downstream: Caller direct API path** — gameplay code (e.g. #14 EnemyDirector 老闆出場大震、#25 Combat Visual Feedback parry counter-shake、scripted narrative moments) call `shake()` / `hit_pause()` 直接，繞過 dispatch table (closed primitive 不變)
5. **Downstream: Render pipeline** — ScreenEffects 唔 own visual node。Game world owns CanvasLayer topology (Rule 14)；ScreenEffects 只寫 `RenderingServer.global_shader_parameter_set("u_shake_offset", offset)` per frame
6. **Downstream: `hit_pause_started(duration_ms: int)` signal** — emit 喺 hit_pause entry，畀 #4 AudioManager (pending GDD) subscribe 做 audio ducking。AudioServer 唔聽 `SceneTree.paused`，要自行 ducking。Signal payload `duration_ms` 已 clamp (見 Rule 2)

### Rules (16)

#### Rule 1 — `shake(intensity: float, duration: float) -> void` signature

Primary primitive。`intensity ∈ [0, 1]` clamped；`duration ∈ [0, 0.5s]` clamped (hard ceiling — 超出視為 caller bug，`push_warning("shake duration > 0.5s clamped to 0.5s")` + clamp)。No return value：closed library，caller 唔需要 handle handle。

Rationale: duration ceiling 防止 caller accident 寫 `shake(1.0, 10.0)` 違反 peripheral receivability band (Section B Falsifiable Test #1)。NaN / ±INF 喺 intensity / duration → reject + `push_error`，return early (Foundation autoload 唔 throw — Pillar 2 frictionless 一致 #5 Rule 1)。

#### Rule 2 — `hit_pause(duration: float) -> void` signature

`duration ∈ [0, 0.12s]` clamped (DNF 上限 = 2 個 60Hz frame)。No return value。超過 0.12s clamp + `push_warning("hit_pause duration > 0.12s clamped — violates Pillar 2 user-detectable freeze threshold")`。

Rationale: locked Player Fantasy contract「不可 cascade 長到玩家可 register 卡咗」+ Section B Falsifiable Test #3。125ms 係 human-detectable interruption threshold (心理學 literature)；0.12s 留 5ms safety margin。

#### Rule 3 — `set_motion_intensity(scale: float)` a11y knob

`scale ∈ [0, 1]` clamped。Setter 唔 cancel active shake — 下一 `shake()` call 先生效 (避免 mid-shake amplitude jump aesthetic bug)。Setter `_motion_intensity == 0.0` 觸發一次 latch-clear: `RenderingServer.global_shader_parameter_set("u_shake_offset", Vector2.ZERO)` (per Rule 6 short-circuit 之前確保 latched uniform 唔殘留 last value)。

`hit_pause()` **唔受 motion_intensity 影響** (per Section B locked contract「time perturbation ≠ vestibular」)。setter signature `func set_motion_intensity(scale: float) -> void` — 任何 caller 包括 SettingsManager autoload + debug console 都用同一 entry。

#### Rule 4 — Shake math: **Trauma² decay model** (Yoshi/Vlachos GDC pattern)

Maintain internal `_trauma: float ∈ [0, 1]` + `_trauma_decay_rate: float`。每 frame:

```gdscript
func _process(delta: float) -> void:
    delta = min(delta, 0.1)  # bfcache resume large-delta clamp (Rule 13)
    if _state == State.SUSPENDED: return
    if _state == State.HIT_PAUSED:
        # decay shake amplitude 凍喺 entry value，唔更新 trauma；只 decrement pause timer
        _pause_remaining_sec -= delta
        if _pause_remaining_sec <= 0.0: _exit_hit_paused()
        return
    if _motion_intensity == 0.0:
        return  # short-circuit, uniform 已 latch-clear (Rule 3)
    if _trauma > _TRAUMA_EPSILON:
        _trauma = max(0.0, _trauma - _trauma_decay_rate * delta)
        var offset := pow(_trauma, 2) * _MAX_OFFSET_PX * _noise_sample()
        RenderingServer.global_shader_parameter_set("u_shake_offset", offset)
    elif _trauma_just_zeroed:  # one-shot clear when trauma 第一次跌到 0
        RenderingServer.global_shader_parameter_set("u_shake_offset", Vector2.ZERO)
        _trauma_just_zeroed = false
```

**`_noise_sample()` implementation**: cheap deterministic hash `Vector2(sin(time * 137.0), sin(time * 211.0))` (NOT Perlin — peripheral 12-frame shake 唔 perceive smooth-ness)。

**Constants (deferred to Section G Tuning Knobs)**: `_MAX_OFFSET_PX = 4.0` (peripheral receivability band — 16px sprite × 3 zoom = 48px effective → 4px = 8.3% displacement，solid 唔噪)；`_TRAUMA_EPSILON = 0.01` (decay 停止 threshold)。

**為何 Trauma² over Perlin / Sinusoidal**:
- Perlin smooth feel 太「液態」缺乏 hit impact punch (technical-artist confirmed mobile WebGL 2 dependent texture read 貴)
- Sinusoidal 太 predictable，feel 似 motor 震動而非 hit
- Trauma² squared decay = Vlambeer / Yoshi / Vlachos pattern (GDC 2013 validated) — peripheral receivability band 內最 solid 嘅 impact feel

#### Rule 5 — Shake combiner: **Trauma additive with hard clamp**

新 `shake(i, d)` call → `_trauma = min(1.0, _trauma + (i * _motion_intensity))`；`_trauma_decay_rate = max(_trauma_decay_rate, 1.0 / d)` (取較快衰減速度)。

motion_intensity multiply 喺 trauma 累加之前 (Rule 7 確認 input-side composition)。

**HitPaused 期間 `shake()` call**: trauma 加埋 (next Active frame 會 apply)，但 uniform 唔 update 直到 HitPaused exit (visual freeze contract — DNF 「凝固一吓」feel)。

**Falsifiable Test #4 compliance**: 8 × HIT_HEAVY (each 0.4) additive = 3.2 → clamp 1.0，shader output `pow(1.0, 2) × 4px × noise = 4px max`。即使 worst-case saturate 都喺 peripheral receivability band 上限內 (Rule 6 budget enforced)。

**為何 over Replace / Envelope-max / Replace-if-stronger**:
- Replace: 8 個 HIT_HEAVY 連發只記最後一個，feel 缺積累感
- Envelope-max: 同 intensity 連發完全無 reinforce
- Replace-if-stronger: 弱 hits invisible
- Additive + clamp: feel 累積、bounded、deterministic

#### Rule 6 — Per-frame shake budget enforcement (Falsifiable Test #4 binding)

Frame-level invariant: `pow(_trauma, 2) * _MAX_OFFSET_PX ≤ _MAX_OFFSET_PX` (since `_trauma ≤ 1.0` clamped Rule 5)。CI test (`tests/unit/screen_effects/shake_combiner_test.gd`) simulate 8 concurrent HIT_HEAVY dispatch → assert `_test_get_current_shake_amplitude() ≤ _MAX_OFFSET_PX` per frame。

呢條 rule 主要係 documentation + test contract — runtime clamp 已 enforce。

#### Rule 7 — `motion_intensity` composition: **input-side multiplication**

Dispatch 入口 (Rule 9) 同 direct caller path (Rule 11 funnel) 都係:
```gdscript
var effective_intensity := raw_intensity * _motion_intensity
```
喺 trauma 累加之前 multiply。`hit_pause()` 不乘 motion_intensity。

**為何 input-side over output-side**:
- Output-side (final offset × motion_intensity) 會令 decay curve 同 raw call 嘅 trauma 累計唔對應，debug 困難
- Input-side: `motion_intensity = 0.0` → effective_intensity = 0 → trauma 加 0 → 完全短路 (Section B honest endpoint contract)
- Input-side: 「a11y user 同 default user 嘅 shake duration 一致，只係 amplitude 縮放」semantics 清晰

#### Rule 8 — `hit_pause` re-entry: **max-remaining, no extend**

新 `hit_pause(d')` 期間另一 call: `_pause_remaining_sec = min(_MAX_PAUSE_SEC, max(_pause_remaining_sec, d'))`。**唔加埋**，**唔 queue**。

**為何 over ignore / replace / queue**:
- Ignore: 強力 effect 被弱 effect 遮蓋 (PARRY 被後續 HIT_HEAVY 蓋過)
- Replace: 弱 effect 截短強 effect，feel 突兀
- Queue: cascade 風險，違反 Pillar 2 cascade ban
- Max-remaining: bounded by Rule 2 0.12s ceiling，cascade-free，強者 wins

#### Rule 9 — `burst_started` dispatch table: **static const Dictionary lookup**

ScreenEffects autoload `_ready()` 訂閱 `ParticleSystemWrapper.burst_started`:
```gdscript
ParticleSystemWrapper.burst_started.connect(_on_burst_started)
```

Dispatch via static const:
```gdscript
const _DISPATCH: Dictionary = {
    ParticleSystemWrapper.PresetId.HIT_HEAVY:       {"shake": Vector2(0.4, 0.12), "pause": 0.0},
    ParticleSystemWrapper.PresetId.PARRY:           {"shake": Vector2(0.6, 0.08), "pause": 0.06},
    ParticleSystemWrapper.PresetId.DEATH:           {"shake": Vector2(0.3, 0.18), "pause": 0.0},
    ParticleSystemWrapper.PresetId.LOOT_RARE_BURST: {"shake": Vector2(0.2, 0.15), "pause": 0.0},
}
```

Preset 唔喺 table → NO-OP (HIT_LIGHT / STATUS_LIGHT / STATUS_HEAVY / STATUS_BUFF / LOOT_BURST — 5 presets 嚴肅 noise floor)。

**Position argument received but unused** — forward-compat (future positional shake e.g. earthquake 由 grid origin 衰減)。Comment `# position reserved for future positional shake`。

**為何 Dictionary over match / strategy pattern**:
- Match expression: 9 preset 寫 9 case，data-driven 失效；新增 preset 要改 match
- Strategy pattern: overkill，dispatch 只係 2 個 primitive call
- Dictionary: static const, CI 可以 grep verify against #5 PresetId enum (Rule 15)，lookup O(1)

#### Rule 10 — Selective freeze via `get_tree().paused` + autoload `PROCESS_MODE_ALWAYS`

HitPaused entry → `get_tree().paused = true`。所有 autoload (`GameStateMachine` / `GymSysClient` / `PersistenceLayer` / `ParticleSystemWrapper` / `ScreenEffects` 自己 + future expansion) 喺 `_ready` 強制 `process_mode = PROCESS_MODE_ALWAYS` — 即 hit pause 期間 autoload 繼續 tick (GymSys polling 唔 missed，state machine 唔 desync — Section B Falsifiable Test #3 satisfied)。

Gameplay nodes / HUD layer / ParticleLayer 預設 `PROCESS_MODE_INHERIT` (繼承 root = PAUSABLE)。Hit pause 期間：
- Gameplay scene tree freeze (enemy / avatar / projectile / state ticking)
- **HUD freeze** (HP bar tick / damage numbers 都凝固 — DNF feel consistency，全畫面凝固一吓重量感加倍；60ms < 250ms human reaction threshold，acceptable input lag)
- **Particles freeze** (GPUParticles2D 預設 PAUSABLE — `speed_scale` 自然凍住，particles 同 boss 一齊凝固，「凝固一吓 with particles」DNF unified feel)
- ScreenEffects 自己 ALWAYS — `_process(delta)` 繼續 tick 但只 decrement `_pause_remaining_sec` (shake amplitude 凍喺 entry value per Rule 5)

HitPaused exit → `get_tree().paused = false`。

**AudioServer 唔聽 SceneTree.paused** — 必須 emit `hit_pause_started(duration_ms)` signal (Interaction #6) 畀 #4 AudioManager subscribe 做 ducking。本 system 唔 own audio ducking。

**絕對唔 touch `Engine.time_scale`** — 會凍 autoload 嘅 delta-based timer (GymSysClient polling timer / SceneTreeTimer)，違反 Section B locked contract。CI enforce (Rule 15)。

#### Rule 11 — Direct caller path 同 dispatch path 統一過 `_apply_shake(intensity, duration)` internal

兩個 entry (Rule 9 dispatch / Rule 1 public API) funnel 過 single internal method:
```gdscript
func _apply_shake(intensity: float, duration: float) -> void:
    if _state == State.SUSPENDED:
        _rejected_calls += 1; return
    if _emit_depth >= _MAX_EMIT_DEPTH:
        push_warning("ScreenEffects.shake re-entry depth=%d, dropping" % _emit_depth)
        _dropped_by_depth_guard += 1; return
    _emit_depth += 1
    var effective := intensity * _motion_intensity  # Rule 7
    _trauma = min(1.0, _trauma + effective)         # Rule 5
    _trauma_decay_rate = max(_trauma_decay_rate, 1.0 / duration)
    _emit_depth -= 1
```

Single point of truth，CI test 只需 cover 一個 path (Rule 6 + Rule 7 + Rule 12 共用)。

#### Rule 12 — Re-entry guard via `_emit_depth` counter: **depth = 0 (strict reject)**

`shake()` / `hit_pause()` callback 入面 (e.g. signal handler chain) 再 trigger 同類 call → `_dropped_by_depth_guard += 1` + `push_warning`。`_MAX_EMIT_DEPTH = 0` (即第一個 nested call 已 drop)。

**為何 strict 0 over depth 2 (#5 pattern)**:
- Shake/pause 唔似 #5 particle burst 需要 frame coherence — 直接 drop 最簡單
- Section C 16 rules 未見到 legitimate nested call use case
- 未來如真 surface need (e.g. burst_started → shake → ... → 再 burst_started)，可 promote to 1 — conservative 預設最安全
- 配合 `bfcache + delta clamp` (Rule 13)，re-entry race 接近 0 probability

#### Rule 13 — GSM Suspended subscription + bfcache hardening

`_ready()`:
```gdscript
GameStateMachine.connect_for_initial_state(_on_gsm_state_changed)
```

Handler:
```gdscript
func _on_gsm_state_changed(new_state: GameStateMachine.State) -> void:
    if new_state == GameStateMachine.State.SUSPENDED:
        # Force reset all (Suspended 覆蓋一切)
        _trauma = 0.0; _trauma_decay_rate = 0.0
        _pause_remaining_sec = 0.0
        _emit_depth = 0
        if get_tree().paused: get_tree().paused = false  # release hit pause
        RenderingServer.global_shader_parameter_set("u_shake_offset", Vector2.ZERO)
        _state = State.SUSPENDED
    elif _state == State.SUSPENDED:
        # 非 Suspended → 還原 Active (其他 state transitions no-op)
        _state = State.ACTIVE
```

**bfcache hardening** (Web Export iOS Safari specific):
- `_notification(NOTIFICATION_APPLICATION_RESUMED)` + `_notification(NOTIFICATION_WM_WINDOW_FOCUS_IN)` 雙 hook — force trigger Suspended exit sequence (Safari bfcache restore behavior 跨版本不一致)
- `_process(delta)` 入口 `delta = min(delta, 0.1)` 避免 bfcache resume 第一 frame 大 delta 令 trauma 一次 decay 完
- WebGL 2 context loss 後 shader uniform 可能 reset to default → Suspended exit 強制 re-set `u_shake_offset = Vector2.ZERO` 確保 known state

#### Rule 14 — CanvasLayer topology

ScreenEffects autoload 唔 own scene node — topology 由 **ADR-0001 Web Export Budget Caps 正式 own**，本 GDD 係 consumer / referrer。Master scene setup enforces per ADR-0001 specification:

```
Root
├─ GameLayer        (CanvasLayer layer=0, PAUSABLE)
│  └─ World content (avatar, enemies, projectiles)
├─ ParticleLayer    (CanvasLayer layer=10, PAUSABLE) ← #5 ParticleSystemWrapper spawn 落呢度
├─ HUDLayer         (CanvasLayer layer=50, PAUSABLE — DNF feel freeze 一致)
└─ ScreenEffectsLayer (CanvasLayer layer=100, ALWAYS)
   ├─ BackBufferCopy
   └─ ColorRect (full-screen, ShaderMaterial reads u_shake_offset)
```

**Shake affects GameLayer + ParticleLayer + HUDLayer** (BackBufferCopy capture 三者，post-process pass 加 offset)。如果 HUD 需要免 shake (readability concern)，可加 HUDLayer 移到 ScreenEffectsLayer (layer=100) 之上 (e.g. HUDLayer layer=200)，避免被 capture。

**Tuning knob (Section G)**: `HUD_SHAKES_WITH_WORLD: bool = true` (default) — 控制 HUDLayer 喺 ScreenEffectsLayer 之上定之下。Section H AC 必須 cover 兩個 mode。

**Viewport oversample**: GameLayer SubViewport 以 code-set 方式 oversample 5% (ADR-0001 BLOCKING fix — `SubViewport.stretch_shrink` 係 integer property，1.05 silently truncates to 1，**唔可以** 用 `stretch_shrink = 1.05`)。正確實現：
```gdscript
# master scene _ready() + viewport resize handler
var display_size: Vector2i = get_viewport().size
game_layer_subviewport.size = Vector2i(int(display_size.x * 1.05), int(display_size.y * 1.05))
```
Memory cost ≈ 1.1× viewport texture (12MB on 1170×2532 iPhone 12 — well within 512MB browser budget)。Ownership: ADR-0001 Web Export Budget Caps ratifies this approach。

#### Rule 15 — CI enforcement: closed primitive contract (`tools/ci/check_screen_effects_callers.gd`)

仿照 #5 `check_particle_callers.gd` pattern。GDScript script run via `godot --headless --script`:

```gdscript
# Pseudo-code
const VIOLATIONS = [
    r"Camera2D\..*\.offset\s*=",
    r"Engine\.time_scale\s*=",
    r"get_tree\(\)\.paused\s*=",
    r"RenderingServer\.global_shader_parameter_set\(\s*[\"']u_shake_offset",
]
const WHITELIST_PATHS = [
    "src/autoload/screen_effects.gd",
    "tests/",
    "tools/debug/",
]
# Walk all .gd files outside whitelist, regex match each VIOLATION → exit(1)
```

**Additional CI check**: verify `_DISPATCH` dictionary keys ⊆ `ParticleSystemWrapper.PresetId` enum values (drift detection — 新 preset 加入 #5 但未加入 dispatch table → build fail)。

**Additional CI check**: verify all autoload `_ready` declare `process_mode = PROCESS_MODE_ALWAYS` (FR-3 Risk Register binding — new autoload 加入但 forget ALWAYS → build fail)。

Build fail = blocking。

#### Rule 16 — Persistence ban

ScreenEffects 唔可以 read/write PersistenceLayer。`_motion_intensity` 由 SettingsManager autoload (pending #22) boot setter call 一次 + user 改 a11y slider 時 setter call。ScreenEffects 內部唔知 motion_intensity persist 邊度。

Rationale: 同 #5 Rule 16 一致 — wrapper 只係 effect runtime，唔係 state owner。Test enforcement: `tests/unit/screen_effects/no_persistence_test.gd` 驗證 ScreenEffects 唔 reference `PersistenceLayer` autoload。

## Formulas

呢個 section 鎖低所有 shake / hit_pause 計算嘅 mathematical specification。所有 example 跟 60fps (delta = 1/60 ≈ 0.0167s) 計算。3 mandatory formulas + 2 helpers covering Section C Rules 4, 5, 7, 8。所有 invariants binding to Section H Acceptance Criteria。

### Formula 1 (Mandatory) — `shake_offset_per_frame` (Trauma² decay)

The `shake_offset_per_frame` formula is defined as:

`shake_offset_per_frame = pow(trauma, 2) × MAX_OFFSET_PX × noise_sample(time)`

每 frame update trauma:

`trauma = max(0.0, trauma - trauma_decay_rate × delta)`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| trauma | t | float | [0.0, 1.0] | Current accumulated trauma (decays each frame) |
| MAX_OFFSET_PX | M | float (const) | 4.0 px (Section G) | Maximum shake amplitude at trauma=1.0 |
| noise_sample(time) | n(τ) | Vector2 | [-1, 1] each axis | Cheap deterministic hash (Formula 4) |
| trauma_decay_rate | k | float | [2.0, 100.0] /sec | Decay rate set by most recent shake call |
| delta | Δt | float | [0, 0.1] sec | Frame delta time (Rule 13 clamp at 0.1s) |
| time | τ | float | [0, ∞) sec | Engine elapsed time |
| shake_offset_per_frame | O | Vector2 | [-M, M] each axis | Pixel offset written to shader uniform |

**Output Range:** Vector2 each axis ∈ [-4.0px, +4.0px] worst case (trauma=1.0)。Trauma < `TRAUMA_EPSILON` (0.01) → skip evaluation, one-shot clear uniform to `Vector2.ZERO`。motion_intensity = 0 → entire shake pipeline bypassed (Section B Falsifiable Test #2 compliance — `hit_pause` 仍然 fire per Rule 3)。

**Example — PARRY shake (intensity=0.6, duration=0.08s, motion_intensity=1.0):**

After Formula 2 combiner: `trauma = 0.6`, `decay_rate = 1/0.08 = 12.5 /sec`。Decay duration ≈ 0.048s ≈ 2.9 frames @ 60fps。

| Frame | time (s) | trauma | trauma² | noise.x | offset.x (px) |
|-------|----------|--------|---------|---------|---------------|
| 0 | 0.0000 | 0.600 | 0.360 | -0.42 | -0.605 |
| 1 | 0.0167 | 0.391 | 0.153 | +0.78 | +0.477 |
| 2 | 0.0334 | 0.183 | 0.033 | -0.91 | -0.120 |
| 3 | 0.0501 | 0.000 | 0.000 | — | 0.000 (decay floor hit, one-shot clear) |

PARRY 短促 punctuation feel — 3 frames 內完成 sensation discharge，符合 peripheral receivability 同 noise floor 嚴肅性 design intent。

### Formula 2 (Mandatory) — `trauma_combiner` (Rule 5 + Rule 7 + amendment)

Combine 新 shake call 入 existing trauma state，input-side motion_intensity composition (Rule 7)。**Amendment**：加 `MIN_SHAKE_DURATION` clamp 防 division-by-zero。

The `trauma_combiner` formula is defined as:

`trauma_new = min(1.0, trauma_old + raw_intensity × motion_intensity)`

`trauma_decay_rate_new = max(trauma_decay_rate_old, 1.0 / max(MIN_SHAKE_DURATION, duration))`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| trauma_old | t₀ | float | [0.0, 1.0] | Pre-call trauma state |
| raw_intensity | i | float | [0.0, 1.0] | Preset shake intensity (Rule 9 dispatch table or direct caller) |
| motion_intensity | m | float | [0.0, 1.0] | Player accessibility slider (Section G) |
| duration | d | float | [0.0, 0.5] sec | Caller-requested decay window (Rule 1 clamp) |
| MIN_SHAKE_DURATION | d_min | float (const) | 0.01 sec (Section G) | Denominator floor to prevent div-by-zero |
| trauma_decay_rate_old | k₀ | float | [2.0, 100.0] /sec | Existing decay rate |
| trauma_new | t₁ | float | [0.0, 1.0] | Clamped post-combiner trauma |
| trauma_decay_rate_new | k₁ | float | [2.0, 100.0] /sec | Faster of (old, requested) |

**Output Range:** trauma_new hard-clamped 到 [0.0, 1.0] — overflow scenarios silently saturate (intentional — protects vestibular safety per Pillar 2)。decay_rate 永遠 monotonically non-decreases per call (never slows decay — AC-D4 invariant)。

**Example A — Single PARRY at trauma=0, motion=1.0:**
- `trauma_new = min(1.0, 0.0 + 0.6 × 1.0)` = **0.6**
- `decay_rate_new = max(0, 1/max(0.01, 0.08)) = max(0, 12.5)` = **12.5 /sec**

**Example B — 8 concurrent HIT_HEAVY (Section B Falsifiable Test #4):**
- 8 × 0.4 × 1.0 = 3.2 raw additive
- `trauma_new = min(1.0, 0.0 + 3.2)` = **1.0** ✓ (clamp holds, max offset = 4.0px, never exceeds budget)
- `decay_rate_new = max(0, 1/0.12)` = **8.33 /sec** — full decay 喺 0.12s 內，即使 saturation 都係 short-lived

**Example C — PARRY at trauma=0.4 existing, motion=0.5:**
- `trauma_new = min(1.0, 0.4 + 0.6 × 0.5)` = **0.7**
- `decay_rate_new = max(k₀, 12.5)` — take faster of (existing, requested)

**Example D — degenerate caller `shake(0.5, 0.0)` (Amendment safety net):**
- `trauma_new = min(1.0, 0.0 + 0.5 × 1.0)` = **0.5**
- `decay_rate_new = max(0, 1/max(0.01, 0.0)) = max(0, 100)` = **100 /sec** — instant flash (decays in 0.005s) instead of division-by-zero crash

### Formula 3 (Mandatory) — `pause_max_remaining` (Rule 8)

Hit-pause combiner using max-remaining rule — overlapping pauses do NOT stack。

The `pause_max_remaining` formula is defined as:

`pause_remaining_new = min(MAX_PAUSE_SEC, max(pause_remaining_old, requested_duration))`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| pause_remaining_old | p₀ | float | [0.0, MAX_PAUSE_SEC] | Current remaining pause |
| requested_duration | d | float | [0.0, ∞) sec | Caller-requested pause length (Rule 2 will clamp before reaching this formula but redundant safety) |
| MAX_PAUSE_SEC | P_max | float (const) | 0.12 sec (Section G) | Safety ceiling — 玩家 register「卡」threshold |
| pause_remaining_new | p₁ | float | [0.0, 0.12] sec | Post-combiner pause remaining |

**Output Range:** [0.0, 0.12] seconds hard-clamped。Requested durations > MAX_PAUSE_SEC trigger `push_warning()` (debug only — never affects gameplay timing — gameplay timing already clamped per Rule 2)。

**hit_pause does NOT receive motion_intensity multiplier** (Rule 7 + Section B locked) — accessibility opt-out only kills shake, not pause。

**Example A — `hit_pause(0.06)` at p₀=0:**
- `p₁ = min(0.12, max(0, 0.06))` = **0.06s**

**Example B — `hit_pause(0.04)` at p₀=0.06 (Rule 8 max-remaining):**
- `p₁ = min(0.12, max(0.06, 0.04))` = **0.06s** — no extend, existing PARRY pause preserved

**Example C — `hit_pause(0.5)` at p₀=0 (caller bug, clamp + warning):**
- `p₁ = min(0.12, max(0, 0.5))` = **0.12s** + `push_warning("hit_pause request 0.5s exceeds MAX_PAUSE_SEC")`

### Formula 4 (Optional Helper) — `noise_sample`

Cheap deterministic 2D hash (Rule 4 referenced) — replaces Perlin noise for zero allocation。

`noise_sample(time) = Vector2(sin(time × 137.0), sin(time × 211.0))`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| time | τ | float | [0, ∞) sec | Engine elapsed time (e.g. `Time.get_ticks_msec() / 1000.0`) |
| noise_sample | n | Vector2 | [-1, 1] each axis | Pseudo-random offset direction |

**Output Range:** Each axis bounded by sin() ∈ [-1, 1]。137 / 211 = 大 co-prime multipliers → x/y axes decorrelate visually。Deterministic — same `time` always produces same offset (replay-safe + GUT test 可 reproduce)。

**Example — at t=1.234s:**
- noise.x = sin(1.234 × 137.0) = sin(169.058 rad) ≈ **+0.547**
- noise.y = sin(1.234 × 211.0) = sin(260.374 rad) ≈ **-0.918**
- Returns Vector2(+0.547, -0.918)

### Formula 5 (Optional Helper) — `peripheral_amplitude_at_intensity` (Pre-computed table)

Derived constant table — max amplitude per preset assuming motion_intensity=1.0:

`max_amplitude = raw_intensity² × MAX_OFFSET_PX`

| Preset | raw_intensity | max_amplitude (px @ MAX=4.0) | Gap from prev tier |
|--------|---------------|------------------------------|--------------------|
| LOOT_RARE_BURST | 0.2 | **0.16 px** | — (baseline) |
| DEATH | 0.3 | **0.36 px** | +0.20 px (2.25× ratio) |
| HIT_HEAVY | 0.4 | **0.64 px** | +0.28 px (1.78× ratio) |
| PARRY | 0.6 | **1.44 px** | +0.80 px (2.25× ratio) |
| (max possible direct caller) | 1.0 | 4.00 px | — |

**Distinguishability check (FR-2 Risk Register monitor)**:
- PARRY (1.44px) vs HIT_HEAVY (0.64px) = 2.25× ratio ✓ peripheral hierarchy clear
- LOOT_RARE_BURST (0.16px) — **sub-pixel risk on low-DPI displays**：1080p screen 喺 standard zoom 可能 imperceptible。FR-2 Risk Register **must monitor** via VS-tier playtest；fallback options: 增 raw_intensity 至 0.3 OR 提升 MAX_OFFSET_PX
- Pillar 3 sensation hierarchy invariant: `max_amplitude(PARRY) ≥ 2 × max_amplitude(HIT_HEAVY)` must hold across all Section G knob tuning (Section H AC-D6)

### Math Invariants → Section H AC promotion candidates

以下 6 條 invariants 將 promote 入 Section H Acceptance Criteria (Section H drafting 時 qa-lead 會 expand):

- **AC-D1 (Trauma saturation safety)**: 8 個並發 HIT_HEAVY 合成 trauma 必須 ≤ 1.0 (Falsifiable Test #4 binding)
- **AC-D2 (Motion intensity zero bypass)**: motion_intensity = 0.0 → shake_offset_per_frame = Vector2.ZERO，但 hit_pause 照常 fire (Falsifiable Test #2 binding)
- **AC-D3 (Pause ceiling clamp)**: hit_pause(d) 即使 d > 1.0s，pause_remaining_new ≤ MAX_PAUSE_SEC，並 emit push_warning
- **AC-D4 (Decay monotonicity)**: trauma_decay_rate_new ≥ trauma_decay_rate_old 永遠成立 — 後續 call 只能加快衰減
- **AC-D5 (Trauma epsilon termination)**: trauma < TRAUMA_EPSILON → shake evaluation 完全 skip，guarantee zero per-frame cost when idle (FR-1 budget protection)
- **AC-D6 (Peripheral hierarchy gap)**: `max_amplitude(PARRY) ≥ 2 × max_amplitude(HIT_HEAVY)` — locks sensation hierarchy 入 sub-pixel domain，防止未來 Section G tuning 意外 collapse tier distinction (Pillar 3 binding)

### Section G knob preview (formal Section G drafting 時 expand)

呢個 Section D introduces 5 個 tuning knobs (全部 deferred to Section G):

| Knob | Default | Safe Range | Source |
|------|---------|-----------|--------|
| `MAX_OFFSET_PX` | 4.0 px | [2.0, 8.0] | Formula 1, peripheral receivability budget |
| `MAX_PAUSE_SEC` | 0.12 sec | [0.04, 0.12] | Formula 3, Rule 2 ceiling |
| `MIN_SHAKE_DURATION` | 0.01 sec | [0.005, 0.05] | Formula 2 amendment, denominator floor |
| `TRAUMA_EPSILON` | 0.01 | [0.001, 0.05] | Formula 1, decay floor |
| `motion_intensity` | 1.0 | [0.0, 1.0] | Formula 1+2, Rule 3 a11y slider |

## Edge Cases

呢個 section 列出 19 個 explicitly-handled edge cases，按 7 個 categories 排列。每個 case 標明 condition + exact resolution + rationale。所有 cases 跨 Section B (Falsifiable Tests) / Section C (Rules) / Section D (Formulas) 已 verified — 唔重複 already-locked invariants，只 cover boundary scenarios。

### Input validation (EC-01 ~ EC-06)

- **EC-01 — If `shake(NaN, d)` or `shake(i, NaN)` called**: `is_finite()` check fail → reject + `push_warning("ScreenEffects.shake: NaN rejected from <caller stack>")`, `_rejected_calls += 1`, no trauma added, no return value side effect. *Rationale*: NaN trauma 會 poison Formula 1 decay (NaN² 仍係 NaN，永遠殘留)，違反 Section B Falsifiable Test #5 (bfcache resume 無殘留 shake)。
- **EC-02 — If `shake(±INF, d)` or `shake(i, ±INF)` called**: `is_finite()` check fail (before Rule 1 clamp) → reject + push_warning。*Rationale*: INF silent clamp 變 1.0 會 mask underlying caller bug (e.g. caller-side division by zero)；fail-loud 令 upstream bug 早期 surface。
- **EC-03 — If `hit_pause(NaN)` or `hit_pause(negative)` called**: `is_finite()` check fail OR `< 0` check → reject + push_warning，`_pause_remaining_sec` 不變。*Rationale*: negative duration 經 Formula 3 `max()` silently no-op，bug 難 catch；NaN 同 INF 同樣需要 fail-loud。
- **EC-04 — If `set_motion_intensity(NaN)` called**: `is_finite()` check fail → reject + push_warning，retain 先前 value。*Rationale*: NaN 會 propagate 入 Formula 1 final offset (offset × NaN = NaN) → 違反 Section B Falsifiable Test #6 (closed primitive contract — shader uniform 必須 valid)。
- **EC-05 — If `set_motion_intensity(x)` 且 `x ∉ [0.0, 1.0]`**: silently clamp 到 `[0.0, 1.0]`，**NO log**。*Rationale*: 此係 settings UI slider 邊界 expected behavior — log 會 spam settings panel 嘅 every-tick events；NaN case 不同 (EC-04 fail-loud)。
- **EC-06 — If `shake(0.0, d)` called (zero intensity, valid duration)**: `_total_calls += 1` (caller intent recorded) 但 Formula 2 `trauma_new = trauma_old + 0 × motion = trauma_old` → no trauma added，no decay_rate update。*Rationale*: 區分「caller 唔識 API (warning-worthy)」vs「caller 故意 mute (analytics-valid)」，方便 telemetry 分析 (e.g. #14 EnemyDirector 是否 ever 用 0 intensity)。

### State machine boundary (EC-07 ~ EC-09)

- **EC-07 — If `shake()` / `hit_pause()` called during Booting state (before `_ready` 完成)**: silent reject (no warning — boot order race expected at app startup)，`_rejected_calls` 唔 increment。*Rationale*: queue 引入 unbounded backlog 風險 (e.g. EnemyDirector pre-boot script 連發 100 個 shake)，且 Booting 期間 trauma 應該係 0 (玩家未 entered gameplay)。Subscribe `GSM.connect_for_initial_state` (Rule 13) 確保 first `state_changed` deliver 後 Booting → Active。
- **EC-08 — If `GSM.state_changed → Suspended` fired mid-frame during shake decay**: current frame `_process` 完成 (trauma decay 正常 run，shader uniform 正常 update) → next-frame entry 入 Suspended (Rule 13 sequence force reset)。*Rationale*: mid-frame 強制中斷會引發 trauma 卡半 frame，下次 resume 出現殘留 shader uniform → 違反 Section B Falsifiable Test #5；natural-end-of-frame transition 避免呢個 race。
- **EC-09 — If `shake()` AND `hit_pause()` same frame fired**: 兩者獨立 register。`hit_pause` 令 `get_tree().paused = true`，ScreenEffects autoload `PROCESS_MODE_ALWAYS` 繼續 tick，**但** Formula 1 decay 喺 HitPaused state 內凍結 (Rule 4 `_process` skips trauma update during HitPaused — shake amplitude 凍喺 entry value)。HitPaused exit 後 trauma resume decay。*Rationale*: DNF feel intent — shake 「凝固一吓」with hit pause；若 shake 期間 continue decay 會令 PARRY (0.6 shake + 0.06 pause) 嘅 visual punch 提前消散，違反 Section B「peripheral 體感印章」contract。

### bfcache / Web Export (EC-10 ~ EC-12)

- **EC-10 — If bfcache resume 一刻 `get_tree().paused == true` latched (Safari 從 snapshot 恢復)**: `_notification(NOTIFICATION_APPLICATION_RESUMED)` handler 強制 `get_tree().paused = false`, `_pause_remaining_sec = 0`, `_trauma = 0`, shader uniform reset to `Vector2.ZERO`。*Rationale*: Section B Falsifiable Test #5 binding；Safari bfcache snapshot 包括 SceneTree.paused 狀態，naive resume 會 stuck 喺 paused state，永久 freeze gameplay。
- **EC-11 — If bfcache resume 一刻 shader uniform 仍保留 last value (WebGL context survived snapshot)**: resume handler 顯式呼叫 `RenderingServer.global_shader_parameter_set("u_shake_offset", Vector2.ZERO)`，唔依賴 WebGL context loss 自然 reset。*Rationale*: Safari bfcache 通常 preserve WebGL 2 state；唔顯式 reset 會出現 resume 第一 frame visual jitter — 違反 Section B Test #5「peripheral 餘光感受到 jank」failure mode。
- **EC-12 — If first `_process(delta)` after resume delta == 30s (freeze duration)**: Rule 13 `delta = min(delta, MAX_FRAME_DELTA = 0.1s)` clamp，防止 trauma 一 frame 全部 decay (30s × 12.5 decay rate = 375 × trauma → instant zero)。*Rationale*: 大 delta 通過 → trauma 一 frame 跳完 → shake 視覺消失，但 frame budget 同時 catch-up 大量 missed _process ticks 引發 multi-frame stutter (Section B Falsifiable Test #5 binding)。

### Cross-system race / dependency (EC-13 ~ EC-15)

- **EC-13 — If ParticleSystemWrapper autoload 未 ready 時 ScreenEffects `_ready` 跑 (autoload order race despite ADR-006 Contract 4 sequential)**: defer `burst_started.connect()` call 到 first `_process()` frame using `if not is_instance_valid(ParticleSystemWrapper): call_deferred("_connect_burst_listener")` pattern。如 3 frames 後仍 missing → `push_error("ScreenEffects: ParticleSystemWrapper autoload missing — auto-dispatch disabled")` 並 disable burst dispatch (caller direct path 仍 works)。*Rationale*: ADR-006 Contract 4 sequential `_ready` order 確保 #5 先 init，但 hot-reload / editor scenarios 唔保證；graceful degradation 比 crash 重要 (Pillar 2 frictionless)。
- **EC-14 — If `burst_started` fires with PresetId not in `_DISPATCH` table (e.g. future #5 加入新 preset 但本 GDD dispatch table 未更新)**: silent skip (NO shake, NO pause)，唔 push_warning (#5 PresetId enum closed contract — 任何新 preset 必須通過 #5 GDD update + Rule 15 CI script 強制同步 dispatch table)。`_dispatch_missed_count += 1` telemetry only。*Rationale*: Rule 15 CI script 已 catch enum drift；runtime warning 會 spam log 喺新 preset rollout phase；telemetry counter 足以 surface issue。
- **EC-15 — If SettingsManager autoload (pending #22) missing on boot**: `_motion_intensity` 預設 = `1.0` (full effect)，`push_info("ScreenEffects: SettingsManager autoload absent — motion_intensity defaults to 1.0")` 一次 per session。*Rationale*: Mirror Hero healthy adult gym context + Section B Falsifiable Test #1 (PARRY 0.6 intensity 必須 register) — default 0.0 會 silent violate fantasy；default 1.0 user opt-out via SettingsManager (when shipped)。accessibility-specialist sign-off pending #22 GDD authoring。

### Numerical / formula boundary (EC-16 ~ EC-17)

- **EC-16 — If trauma falls into `(0, TRAUMA_EPSILON)` range 之後 caller 再 `shake(i, d)` (asymptote risk)**: Formula 2 combiner `trauma_new = min(1.0, 0.005 + i × motion)` 將 trauma 重新推高過 EPSILON，Rule 4 short-circuit 解除，shake 正常 resume。`_trauma_just_zeroed = false` (因為 trauma > EPSILON 期間 reset 過 flag)。*Rationale*: Section D AC-D5 binding；naive implementation 可能 stuck trauma 喺 0.005 永遠 decay 唔到 0，浪費 frame budget evaluate trauma² × 4.0 × noise (sub-pixel offset 視覺上唔可見)。
- **EC-17 — If `delta == 0` (editor pause / single-step debug)**: Formula 1 trauma decay 唔 run (`decay_rate × 0 = 0`)，`_pause_remaining_sec` 唔 tick (frozen)。狀態 deterministic — same state preserved。*Rationale*: replay test + GUT debugger single-step expected behavior；唔需要 special handling (Formula 1 math 自然 yields zero update)。

### Rendering / Camera2D (EC-18)

- **EC-18 — If Camera2D missing or disabled when `shake()` fires (Rule 14 expected topology not present)**: trauma 正常累積，shader offset 正常 set via `RenderingServer.global_shader_parameter_set` (effects 走 ShaderMaterial 路徑非 `Camera2D.offset`)。Rule 14 contract 維持 — shake 效果通過 ScreenEffectsLayer post-process ColorRect 應用，唔依賴 Camera2D 存在。*Rationale*: 確認 Section B Falsifiable Test #6 (closed primitive — caller 不可改 Camera2D.offset) + Rule 14 CanvasLayer topology — ScreenEffects 對 Camera2D presence 解耦，避免 boot order 同 Camera2D late-spawn 引發 NPE。

### Re-entry / depth guard (EC-19 — extension of Rule 12 cross-system signal case)

- **EC-19 — If `shake()` called from inside `hit_pause_started` signal handler (cross-system signal feedback loop, e.g. AudioManager 接收 hit_pause_started 然後 trigger 自己嘅 shake feedback)**: Rule 12 `_emit_depth` counter set/reset 喺 wrapper `_apply_shake()` entry/exit；re-entry detect (`_emit_depth > MAX_EMIT_DEPTH (0)` strict check) → reject + `push_warning("ScreenEffects: re-entry from signal handler depth=1 — dropped")` + `_dropped_by_depth_guard += 1`。*Rationale*: depth = 0 strict policy (Rule 12 user decision)；feedback loop 通常 indicates caller-side bug；drop + log 比 cascade safer。

### Cross-reference verification

- **Section B Falsifiable Tests coverage**:
  - Test #1 (PARRY shake register) — covered by EC-15 default 1.0 + Section D AC-D6 distinguishability gap
  - Test #2 (motion=0 hit_pause preserved) — covered by Section D AC-D2 (NOT edge case — invariant)
  - Test #3 (GSM tick during hit_pause) — covered by Rule 10 autoload PROCESS_MODE_ALWAYS (NOT edge case)
  - Test #4 (8 HIT_HEAVY budget) — covered by Section D AC-D1 (NOT edge case — invariant)
  - Test #5 (bfcache no residual shake) — covered by EC-10 + EC-11 + EC-12
  - Test #6 (closed primitive) — covered by EC-18 + Rule 15 CI script
- **Sister #5 ParticleSystemWrapper edge cases — no duplicates**: 本 GDD edge cases 全部聚焦 ScreenEffects 接收端 + dispatch table + shader pipeline；#5 edge cases cover particle pool / LRU eviction / preset registry — 兩者解耦。

## Dependencies

### Upstream Dependencies (本 system requires)

| # | System | Layer | Hard/Soft | Nature of dependency |
|---|--------|-------|-----------|----------------------|
| **#5** | ParticleSystemWrapper | Foundation / VS | **Soft (subscriber pattern)** | Subscribe `burst_started(preset_id: PresetId, position: Vector2)` signal via direct `.connect()` (per Q-V6 resolution below). Dispatch table (Rule 9) maps 4 of 9 PresetId → shake/pause primitives. Position arg reserved, unused v1. wrapper fails without crash if #5 absent (Rule 13 graceful degradation EC-13)。 |
| **#1** | GameStateMachine | Foundation / VS | **Soft** | Subscribe `state_changed(new_state: State)` via `connect_for_initial_state(_on_gsm_state_changed)` helper (ADR-006 Contract 6) — initial state replay required because ScreenEffects autoload position 14 > GSM position 2 (F-SYNC-2 sync 2026-05-28; pre-VS draft claimed pos 5 + pos 1 — both stale)。Suspended state entry triggers Rule 13 force-reset sequence (trauma + pause_remaining + shader uniform clear)。 |
| **SettingsManager autoload** | (pending #22 Character Screen GDD) | Presentation / MVP | **Soft (optional caller)** | Optional caller of `ScreenEffects.set_motion_intensity(scale)` 於 boot (load saved a11y value) + on user slider change。當 #22 GDD 未 authored / SettingsManager autoload 唔存在，ScreenEffects 預設 `_motion_intensity = 1.0` (per EC-15)。Never reads PersistenceLayer 直接 (Rule 16)。 |

**ADRs referenced (upstream constraints)**:
- **ADR-006 State Machine Contract** (Contract 4: autoload sequential `_ready`; Contract 6: `connect_for_initial_state`) — ratified Proposed
- **ADR-001 Web Export Budget Caps** — pending, FR-1/FR-2/FR-3 (Section B Risk Register) gated on ADR-001 ratification

### Downstream Dependents (systems that depend on 本 system)

**Per skill bidirectional consistency rule**: 以下 entries 必須喺對應 GDD 寫成時加入該 GDD 嘅 "depends on: #6 Screen Effects System" 句段。

| # | System | Layer | Tier | Status | Nature of dependency |
|---|--------|-------|------|--------|----------------------|
| **#4** | AudioManager | Foundation / VS | **Pending GDD** | **Hard (signal subscriber)** | Subscribe `hit_pause_started(duration_ms: int)` signal (Interaction #6) for audio ducking — AudioServer 唔聽 SceneTree.paused，必須自行 ducking。Signal payload `duration_ms` ≤ MAX_PAUSE_SEC × 1000 = 120ms (Rule 2 clamp guaranteed)。If absent → ScreenEffects 仍 functions, signal goes uncaught (no-listener safe per Godot signal semantics, EC-19 graceful)。 |
| **#14** | EnemyDirector | Core / VS | **Pending GDD** | **Hard (direct caller for boss-spawn shake + auto-dispatch via #5)** | (a) Direct API: call `ScreenEffects.shake(intensity, duration)` for boss-spawn-shake / 老闆出場大震 narrative moments (繞過 dispatch table — closed primitive unchanged); (b) Auto-dispatch: #14 calls `ParticleSystemWrapper.play(HIT_HEAVY/PARRY/DEATH)` → #5 emits `burst_started` → ScreenEffects auto-shake/pause (Rule 9 dispatch table)。Dedup vs #25: #14 owns hit-confirm side; #25 owns visual-clarity side。 |
| **#21** | Loot Drop Modal | Presentation / Pre-MVP | **Pending GDD** | **Hard (auto-dispatch via #5)** | #21 calls `ParticleSystemWrapper.play(LOOT_RARE_BURST, item_world_pos)` → #5 emits `burst_started` → ScreenEffects auto-dispatch shake 0.2 / 0.15s (Rule 9)。普通 LOOT_BURST NO shake/pause (sensation noise floor — Section B locked)。#21 唔需要 direct call ScreenEffects API。 |
| **#25** | Combat Visual Feedback | Presentation / MVP | **Pending GDD** | **Hard (direct caller for parry counter-shake + auto-dispatch via #5)** | (a) Direct API: optional `ScreenEffects.shake(intensity, duration)` for parry counter-shake / status apply moments overriding Rule 9 baseline; (b) Auto-dispatch: #25 calls `ParticleSystemWrapper.play(PARRY/STATUS_*)` → #5 emits `burst_started` → ScreenEffects auto-shake/pause for PARRY only (STATUS_* NO shake/pause per Rule 9 sensation noise floor)。 |

**Provisional contract lock note**: 全部 4 個 downstream entries 喺其 GDD 未寫成前 unilaterally locked from ScreenEffects side。當 #4, #14, #21, #25 GDDs 寫成時 expect contract delta — submit ADR if downstream needs ScreenEffects API change。Wrapper API 係 source of truth per Section C closed primitive contract。

### Bidirectional Consistency Check (next-revision requirements)

呢度列出 cross-system GDD updates needed:

- **#5 ParticleSystemWrapper** (already lists #6 ✓ — line 974, 1002, 1012, EC-13)：confirms `burst_started(preset_id, position)` signal contract，no revision needed unless EC13 Rule 11 helper API mandate policy changes
- **#1 GameStateMachine** (currently does NOT list #6 ✗)：next revision **必須** add #6 to "Downstream Dependents — Soft dependents" table，line ≈370 (與 #5 同樣 flagged at #5 line 1003)。Expected entry: "**#6 Screen Effects System** subscribes via `connect_for_initial_state` (ADR-006 Contract 6)；Suspended state triggers Rule 13 cancel-all sequence"。同 #5 GDD 一齊 batch 處理 #1 GSM revision，避免 #1 多次 propagate
- **#22 Character Screen** (pending GDD)：authoring 時 list ScreenEffects as upstream dependency (SettingsManager autoload → `set_motion_intensity(scale)` setter call contract)
- **#4 AudioManager** (pending GDD)：authoring 時 list ScreenEffects as upstream (subscribe `hit_pause_started(duration_ms: int)` signal for audio ducking)
- **#14 EnemyDirector** + **#21 Loot Drop Modal** + **#25 Combat Visual Feedback** (pending GDDs)：authoring 時 list ScreenEffects as upstream for direct API calls (#14, #25) or implicit auto-dispatch (#21 via #5)

### Q-V6 Resolution (from #5 ParticleSystemWrapper Open Questions)

**Q-V6 from #5**: 「EC13 既 `request_burst_started_connect(callable)` helper API (per Rule 11 amendment) — 係 mandate use (所有 subscriber 必須用)，定 recommended (autoload order 保證下直接 `.connect()` 都 acceptable)？」

**Resolution (by this GDD — #6 Screen Effects System)**:

**RECOMMENDED, NOT MANDATE**。本 GDD chooses **direct `.connect()`** (per Section C Rule 9) — `ParticleSystemWrapper.burst_started.connect(_on_burst_started)`。

**Rationale**:
- ADR-006 Contract 4 sequential `_ready` order locks ParticleSystemWrapper (position 12) before ScreenEffects (position 14) — NPE-on-null-signal 嘅 race window 不存在 under current autoload topology (F-SYNC-2 sync 2026-05-28; was ambiguous `#5 (position 4) before #6 (position 5)` conflating system IDs with autoload positions)
- Section C Rule 9 採用 direct connect 保持 API surface minimal (與 #5 line 526 stance 一致：「Wrapper 唔提供 `connect_for_initial_state()` helper for burst_started — 一行 `.connect()` 已足夠，helper 反而增加 surface area」)
- EC-13 (本 GDD) 已 cover autoload race graceful degradation via `call_deferred` retry pattern
- `request_burst_started_connect(callable)` helper 仍由 #5 提供作 future-proof option — 任何 future subscriber (or future autoload reorder) 可 promote to helper without API breaking change

**Q-V6 closed**：marked RESOLVED in #5 GDD next revision batch (alongside #1 GSM dependents update)。

### Open Items (carry forward)

- **Q-F1 NEW**: #4 AudioManager GDD authoring 時 confirm `hit_pause_started(duration_ms: int)` signal payload schema (currently spec'd as int milliseconds — confirm vs alternative float seconds)
- **Q-F2 NEW**: ADR-001 ratification 必須 specify ScreenEffects CPU budget allocation (FR-1 Risk Register binding) — separate from #5 GPU budget
- **Q-F3 NEW**: VS-tier first autoload addition 必須 enforce Rule 15 CI script `EXPECTED_AUTOLOADS` whitelist update (FR-3 Risk Register binding) — `tools/ci/check_screen_effects_callers.gd` must surface drift
- **Q-F4 NEW**: Rule 14 CanvasLayer topology (GameLayer 0 / ParticleLayer 10 / HUDLayer 50 / ScreenEffectsLayer 100) — 由邊個 system / scene 負責 enforce？建議 master scene setup ADR scope (likely covered by ADR-001 input scope per Rule 14 note)
- **Q-F5 NEW**: HUD_SHAKES_WITH_WORLD knob (Section G pending) — designer-facing toggle controls HUDLayer position relative to ScreenEffectsLayer。若 toggle true → HUDLayer < ScreenEffectsLayer (shaken)；若 false → HUDLayer > ScreenEffectsLayer (immune)。實作機制由 #22 Character Screen GDD owner / master scene owner confirm

## Tuning Knobs

呢個 section 列出所有 designer / player-facing tunable values，安全範圍同 extreme behavior。9 個 owned knobs + 5 個 compile-time constants explicitly NOT exposed。

### Owned by ScreenEffects (designer-facing — designers 可 tune without code change)

| Knob | Default | Safe Range | Source / Used By | Too high (above safe range) | Too low (below safe range) |
|------|---------|------------|------------------|----------------------------|---------------------------|
| `MAX_OFFSET_PX` | 4.0 px | [2.0, 8.0] | Formula 1 (shake_offset_per_frame); FR-2 Risk Register tuning lever | > 8.0 → 違反 Section B「peripheral receivability band」上限 → mid-set vestibular discomfort → Pillar 2 violation | < 2.0 → 16px sprite × 3 zoom 上 < 4% displacement → peripheral 失去 signal → Pillar 1/3 DNF feel 失效；LOOT_RARE_BURST (raw 0.2² × M) 落入 sub-pixel imperceptible |
| `MAX_PAUSE_SEC` | 0.12 sec | [0.04, 0.12] | Formula 3 (pause_max_remaining); Rule 2 ceiling | > 0.12 → 玩家可 register「卡」 (250ms reaction threshold safety margin lost) → Pillar 2 violation Section B Test #3 | < 0.04 → PARRY hit pause < 2 frames @ 60fps → 視覺凝固 feel 太短近乎冇 → DNF feel 失效 |
| `MIN_SHAKE_DURATION` | 0.01 sec | [0.005, 0.05] | Formula 2 amendment (decay_rate denominator clamp) | > 0.05 → 任何短促 shake (e.g. `shake(0.5, 0.001)`) decay_rate cap at 20 /sec → shake 持續超預期長度 → 違反 Section B peripheral receivability band | < 0.005 → 邊界保護失效，degenerate caller `shake(_, 0.0001)` decay_rate = 10000 /sec → trauma 一 frame 內完全消散 (cosmetic glitch but not crash) |
| `TRAUMA_EPSILON` | 0.01 | [0.001, 0.05] | Formula 1 short-circuit threshold (AC-D5 binding) | > 0.05 → trauma 0.02..0.05 範圍 short-circuit 過早 → shake decay 尾段斷崖式 disappear → visual artifact | < 0.001 → trauma 永遠 decay 唔到 0 (asymptote)，frame budget 浪費 evaluate sub-pixel offset (FR-1 protection 失效) |
| `MAX_FRAME_DELTA` | 0.1 sec | [0.05, 0.2] | Rule 13 bfcache delta clamp (EC-12 binding) | > 0.2 → bfcache 30s resume 之後 trauma 一 frame 跳完 + multi-frame stutter → 違反 Section B Test #5 | < 0.05 → 50ms 以上 lag spike 都被 clamp → catch-up timer 累積，hit_pause remaining tick 慢 → cosmetic only |
| `MAX_EMIT_DEPTH` | 0 (strict reject) | [0, 2] | Rule 12 re-entry guard | > 2 → 允許 cascade > 2 levels → 違反 Pillar 2 cascade ban；burst_started → shake → hit_pause_started → shake → ... 可能 stack overflow | < 0 → invalid value (clamp 到 0) |
| `WARNING_THROTTLE_MS` | 1000 ms | [500, 5000] | Log spam control (per EC-01..05 push_warning calls) | > 5000 → 連續 warning suppressed 5+ 秒，debug 困難 | < 500 → 短時間連發 warning 仍 spam log，throttle 失效 |
| `HUD_SHAKES_WITH_WORLD` | true | [true, false] | Rule 14 CanvasLayer topology toggle (Q-F5) | N/A boolean — true: HUD 跟住 shake (DNF unified feel); false: HUD immune (readability priority) | N/A — see "Interaction warnings" below for cross-knob effect |
| `motion_intensity` ⭐ | 1.0 | [0.0, 1.0] | **Player-facing accessibility slider** (Rule 3, Formula 1+2, Section B fantasy contract). Owned by SettingsManager autoload pending #22 GDD | > 1.0 (UI clamp) → silently clamp to 1.0 (EC-05) | 0.0 → shake 完全 short-circuit (uniform latch-clear)；**hit_pause 保留** (Rule 7 + Section B Test #2 binding — time perturbation ≠ vestibular) |

### Read-only by ScreenEffects (owned elsewhere — referenced for context)

| Knob | Owner | Used By ScreenEffects For |
|------|-------|---------------------------|
| ParticleSystemWrapper.PresetId enum values | #5 GDD | Rule 9 dispatch table lookup (Rule 15 CI verify ⊆ enum) |
| GameStateMachine.State enum values | #1 GDD | Rule 13 Suspended state transition guard |
| Future autoload list | ADR-006 Contract 4 + Rule 15 CI script | Rule 10 PROCESS_MODE_ALWAYS whitelist; Rule 13 bfcache resume handler |

### Knobs explicitly NOT exposed (compile-time constants — designer 改要 GDD revision)

呢啲 values 鎖死喺 Section C Rule 9 dispatch table，**唔可以 runtime tune** — 改要：(1) propose Section C Rule 9 revision，(2) update Rule 15 CI script，(3) re-run FR-2 Risk Register playtest：

| Constant | Value | Why locked compile-time |
|----------|-------|------------------------|
| HIT_HEAVY shake intensity / duration | 0.4 / 0.12s | Section B sensation hierarchy noise floor — locked from #5 Section C; designer tweaks break peripheral receivability band invariant (AC-D6 binding) |
| PARRY shake intensity / duration | 0.6 / 0.08s | 同上 — PARRY peripheral signature 喺 1.44px @ MAX=4.0；改 intensity 會違反 AC-D6 (PARRY ≥ 2× HIT_HEAVY) |
| PARRY hit_pause duration | 0.06 sec | DNF combat punctuation signature；半 frame 級調整都改變 hit feel character — 屬 Section B fantasy contract scope |
| DEATH shake intensity / duration | 0.3 / 0.18s | DEATH 延長 duration 強調 weight；intensity 0.3 低於 HIT_HEAVY 0.4 保持 sensation hierarchy；改 ⇒ FR-2 playtest re-run |
| LOOT_RARE_BURST shake intensity / duration | 0.2 / 0.15s | Pillar 3 sensation channel signature；FR-2 Risk Register monitor (sub-pixel risk @ low-DPI)；改 ⇒ revisit MAX_OFFSET_PX |
| HIT_LIGHT / STATUS_* / LOOT_BURST dispatch | NO shake/pause | Section B 「sensation hierarchy 嚴肅 noise floor」locked contract — 加 shake 違反 fantasy；改 = GDD-level decision，非 designer tweak |
| Autoload position | 14 (after ParticleSystemWrapper position 12; F-SYNC-2 sync 2026-05-28 — was claimed pos 5/pos 4) | ADR-006 Contract 4 sequential `_ready` order；改 autoload position triggers full FR-3 Risk Register re-validation |
| CanvasLayer layer numbers (0/10/50/100) | Per Rule 14 topology | Determines BackBufferCopy capture scope; changing breaks Rule 14 + HUD_SHAKES_WITH_WORLD knob semantics |
| `_DISPATCH` Dictionary signature | `{PresetId: {"shake": Vector2, "pause": float}}` | Rule 9 + Rule 15 CI script lookup contract；改 = runtime crash |

### Tuning Knob Interaction Warnings (invariants — Section H AC binding)

以下 cross-knob invariants 必須喺所有 default + safe range boundary 上 hold；違反 = Section H AC fail：

1. **`MAX_OFFSET_PX × (PARRY_intensity)² ≥ 2 × MAX_OFFSET_PX × (HIT_HEAVY_intensity)²`** — Section D AC-D6 binding (Pillar 3 hierarchy gap)
   - At default: 4.0 × 0.36 = 1.44px ≥ 2 × 4.0 × 0.16 = 1.28px ✓
   - At MAX_OFFSET_PX = 2.0: 0.72 ≥ 0.64 ✓ (margin tightens; FR-2 sensitivity)
2. **`MAX_PAUSE_SEC ≤ 0.12 sec`** — Pillar 2 user-detectable freeze threshold (250ms reaction safety)；hard ceiling，never violated by safe range
3. **`MIN_SHAKE_DURATION ≤ MAX_PAUSE_SEC / 12`** — ensures shake decay_rate 最壞情況 (100 /sec @ MIN_SHAKE_DURATION = 0.01) 唔會引發 shake 喺 hit_pause 60ms 內未完成 visible decay (visual coherence)
   - At default: 0.01 ≤ 0.01 ✓ (exact boundary — at boundary, decay completes exactly within max pause)
4. **`TRAUMA_EPSILON < (any preset raw_intensity)²`** — ensures sensation hierarchy lowest preset (LOOT_RARE_BURST 0.04) 唔會喺 first frame 已 short-circuit
   - At default: 0.01 < 0.04 ✓
   - At TRAUMA_EPSILON = 0.05: 0.05 > 0.04 → LOOT_RARE_BURST 第一 frame 已 短路 → sensation 完全消失 → **invariant fails** (safe range upper bound chosen specifically to prevent this)
5. **`MAX_FRAME_DELTA ≥ 2 × (1 / 60)`** — bfcache delta clamp 必須 ≥ 2 frames @ 60fps (33ms)，否則 6-frame hit pause cascade catch-up impossible
   - At default: 0.1 ≥ 0.0333 ✓
6. **`motion_intensity = 0.0`** → `shake_offset_per_frame = Vector2.ZERO` AND `hit_pause(d) → pause_remaining = d` — Section B Test #2 binding (Rule 7 + EC-15 default 1.0 confirm)
7. **`HUD_SHAKES_WITH_WORLD = false`** → HUDLayer position > ScreenEffectsLayer position — Rule 14 topology invariant (Q-F5 implementation owner confirm)

### Section H AC promotion candidates (from invariants above)

- **AC-G1**: 在所有 safe range boundary 上 invariant #1 (AC-D6) hold
- **AC-G2**: 在所有 safe range boundary 上 invariant #4 (TRAUMA_EPSILON vs LOOT_RARE_BURST) hold
- **AC-G3**: motion_intensity = 0.0 → shake_offset_per_frame = Vector2.ZERO AND hit_pause 照 fire (Section D AC-D2 generalize)
- **AC-G4**: HUD_SHAKES_WITH_WORLD toggle 在 default + alternate value 上 effect 正確 (Rule 14 binding)

## Visual/Audio Requirements

### Visual — Shake Aesthetic Direction

呢個系統嘅視覺核心係 **「solid impact, not motor vibration」**。Trauma² decay (Formula 1) 嘅 character 係前段 punch 重、尾段 fade fast — 一拳落地之後 energy bleeds out exponentially，唔係手機 buzz 嗰種 constant-amplitude 抖震。呢個 character 對 Section B「眼角嘅爆擊」極其關鍵：玩家做 bench press 第 8 rep grinding 嘅時候，foveal vision 鎖實 barbell，peripheral vision 只 register **「有嘢撞落嚟」嘅 first frame energy spike** — Trauma² 嘅 front-loaded curve 保證呢個 first-frame impact 唔會被 motor-buzz 稀釋。

點解唔用 Perlin？Perlin noise 嘅 smoothness 對 ≥30 frame 嘅長 shake (e.g. earthquake ambient) 有 visual benefit，但我哋最長 shake 係 DEATH 0.18s ≈ 12 frames @ 60fps — peripheral channel 喺 12 frame 內根本 perceive 唔到 smoothness texture，多花 cycles 計 Perlin 係純浪費。`Vector2(sin(t × 137), sin(t × 211))` 嘅 137/211 prime multipliers 提供 **decorrelated X/Y axes** (兩條軸唔會 sync 出現「斜線抖」visual artifact)，同時 deterministic — 同一個 trauma curve 每次播都係 identical motion，方便 playtest panel n≥5 (AC-28) 做 unambiguous discrimination test。

Visual texture 重要 vs 唔重要嘅 cross-reference：**長 shake (>0.3s) texture 重要、短 shake (<0.2s) energy envelope 重要**。我哋 4 個 active preset 全部 ≤0.18s，所以 envelope (Trauma² front-load) 係 hero，noise texture 係 supporting role。

### Visual — Per-Preset Feel Specifications

| Preset | Feel Keyword | Raw Intensity | Duration | Max Amplitude | Peripheral Signature Differentiator |
|--------|--------------|---------------|----------|---------------|-------------------------------------|
| `HIT_HEAVY` | **「Solid thump」** — 一拳落到肉，乾淨收 | 0.4 | 0.12s | 0.64 px | Medium amplitude, no pause — most common combat feel baseline |
| `PARRY` | **「凝固一吓 + counter-tension release」** — 時間停半秒，跟住 spring back | 0.6 | 0.08s | **1.44 px (highest)** | **Unique hit_pause 0.06s** — 唯一一個 preset 帶 pause，peripheral 一感受到「卡一卡」就知係 PARRY |
| `DEATH` | **「Heavy fade」** — 重物倒地，餘震拖長 | 0.3 | **0.18s (longest)** | 0.36 px | Lower amplitude but extended duration — peripheral 讀到「拖尾感」唔同其他 sharp impact |
| `LOOT_RARE_BURST` | **「Subtle pulse」** — 一下輕推，提示性而非衝擊性 | 0.2 | 0.15s | 0.16 px ⚠️ | Sub-pixel risk (FR-2 monitor) — 接近 peripheral threshold，靠 #5 particle accent 增強識別 |

**Peripheral discrimination logic**：4 個 active preset 沿三軸分開 — **amplitude** (PARRY 最高 / LOOT_RARE_BURST 最低)、**duration** (DEATH 最長 / PARRY 最短)、**pause presence** (PARRY 獨有)。三軸組合保證 AC-28 panel test 可以 unambiguous 分辨。

### Visual — HUD_SHAKES_WITH_WORLD Toggle Intent

**Default `true` (DNF unified feel)**：HUD numbers、HP bar、damage numbers 同 world 一齊郁。重量感加倍 — 玩家視覺上感受到「成個畫面被打到」，包括 UI chrome 本身。呢個 mode 係 default — 強化「眼角爆擊」signature。

**Toggle `false` (readability priority)**：HUD 永遠 pixel-sharp 唔郁。適合需要實時讀 HP 數字 / cooldown timer 嘅 critical moment context。Future surface mechanism (UI accessibility setting OR auto-toggle during boss fights) 由 #22 Character Screen GDD owner 同 accessibility-specialist 協調 — 本 GDD 只 lock toggle semantics + rendering pipeline contract (Rule 14)。

### Visual — Viewport Oversample Note

Code-set SubViewport.size × 1.05 對應 5% 邊緣 bleed (約 36px @ 720p horizontal)。Max shake amplitude 1.44 px (PARRY peak) << 36 px bleed budget — 確認 **任何 preset shake 都 safely 包含喺 oversample envelope 內**，玩家睇唔到 viewport edge clipping / 黑邊 artifact。**注意**: `SubViewport.stretch_shrink` 係 integer property，唔可以寫 1.05 — ADR-0001 已記錄正確 code-set 實現。

### Audio — Hit Pause Coordination Direction (for #4 AudioManager GDD)

ScreenEffects 唔 own audio direct，但 emit `hit_pause_started(duration_ms: int)` signal 畀 #4 AudioManager subscribe (AudioServer 唔聽 `SceneTree.paused`，必須 explicit signal pathway)。

60ms hit_pause 期間 audio direction：**Full duck combat SFX to -∞dB, keep ambient music at background level**。

Three options evaluated by art-director:

| Option | Behavior | Verdict |
|--------|----------|---------|
| **Full duck (-∞dB) combat SFX + keep BGM** | Combat SFX silenced, ambient music 保留 background level | ✅ **Recommended** |
| Low-pass filter sweep | 模擬「水底凝固」 — cinematic but 60ms 太短聽唔出 | ❌ Too short to perceive |
| Pitch bend down | 模擬時間扭曲 — interesting but 同 DNF reference 唔 match | ❌ Off-reference |

Combat SFX silence 強化 visual freeze 嘅「時間停咗」perception；ambient music 保留 background 維持 **Pillar 2 mid-set background music 連續性** — 玩家做 set 中間 PARRY 一吓，個 music 唔可以斷，否則破壞 workout-time existence contract。Reference DNF：佢哋 hit pause 期間 combat SFX cuts，BGM 保留。

### Audio — Signal Payload Semantics

`hit_pause_started(duration_ms: int)` payload contract：
- `duration_ms` 由 ScreenEffects clamp guaranteed ≤ 120ms (per Rule 2 MAX_PAUSE_SEC)，AudioManager 可以 trust 唔需要 re-clamp
- AudioManager 應該 schedule **fade-in resume (~10-15ms ramp)** 喺 pause exit，避免 abrupt unmute audible click artifact
- Cross-reference Q-F1: 呢個 contract 喺 #4 AudioManager GDD authoring 時 confirm — 包括 fade-in curve shape (linear vs exponential) 同 per-bus ducking granularity

> **📌 Asset Spec** — Visual/Audio requirements defined。After art bible approved, run `/asset-spec system:screen-effects-system` to produce per-preset visual reference clips (4 frame-by-frame breakdowns of HIT_HEAVY / PARRY / DEATH / LOOT_RARE_BURST shake curves)、HUD toggle comparison screenshots、audio ducking reference WAV clips, dimensions, and generation prompts from this section.

## UI Requirements

本 system **唔 own UI surface** — ScreenEffects 係 backend service autoload，唔 render menu / HUD / modal。但本 system **contributes 1 UI requirement** 畀其他 system implement：

### Motion Intensity Slider (owned by #22 Character Screen GDD)

| Element | Specification |
|---------|---------------|
| Owner | #22 Character Screen GDD (pending — accessibility settings panel) |
| Backend contract | `ScreenEffects.set_motion_intensity(scale: float)` setter call per Section F Upstream contract |
| Slider range | [0.0, 1.0] continuous |
| Default value | 1.0 (per EC-15 — Mirror Hero healthy adult gym context; SettingsManager loaded value override on boot) |
| Step granularity | 0.05 (20 steps) — granular enough畀 motion-sensitive user 微調 |
| UI label | 「畫面震動強度」/ "Screen Motion Intensity" |
| UI hint | 「降低或關閉 shake；hit pause 唔受影響 (時間擾動唔屬 vestibular trigger)」/ Explanation that hit pause remains active even at 0.0 (per Rule 7 + AC-08 contract) |
| Live preview | 滑動時 fire `shake(0.6, 0.08)` PARRY-equivalent live preview burst 畀 user 感受當前 setting (recommended — #22 GDD owner decide) |

> **📌 UX Flag — Screen Effects motion intensity slider**: 呢個 system contributes 1 player-facing UI requirement (motion intensity accessibility slider)。喺 Phase 4 (Pre-Production)，run `/ux-design` to create UX spec for **#22 Character Screen — Accessibility Settings Panel** 嘅 motion intensity slider element **before** writing epics。Stories that reference呢個 slider 應該 cite `design/ux/character-screen-accessibility.md`，**唔好** cite 本 GDD directly。本 GDD 只 own backend contract (setter API + default value + valid range)，不 own visual chrome / placement / interaction design。
>
> Note this in the systems index for #22 Character Screen system when added。

### No other UI surface owned

- Shake offset 通過 shader uniform 應用，**唔 render 任何 UI overlay**
- Hit pause 通過 SceneTree.paused 應用，**唔 render 「PAUSED」 indicator** (per Pillar 2 — 60ms 期間玩家唔應該 register「卡咗」)
- No debug HUD overlay default — `get_debug_stats() -> Dictionary` 可以 expose 但 by separate dev tool, NOT in shipped player UI (per Rule 16 persistence ban philosophy)

## Acceptance Criteria

呢個 section 列出 **29 個 acceptance criteria** binding to Sections C-G。Test type / gate level / source 全 enumerated。**Breakdown: 25 BLOCKING + 1 ADVISORY + 3 ADR-001 RATIFICATION-GATED**。

### Core API & Validation (Rules 1-3, ECs 01-06)

- **AC-01**: GIVEN ScreenEffects in Active state, WHEN caller invokes `shake(intensity: 0.6, duration: 0.08)`, THEN Formula 2 combiner runs once，`_apply_shake(0.6, 0.08)` funnel receives the call (Rule 11 single-point-of-truth)，trauma += 0.6 × motion_intensity. Source: Rule 1, Rule 11 | Type: Logic | Gate: BLOCKING | File: `tests/unit/screen_effects/shake_api_test.gd`
- **AC-02**: GIVEN ScreenEffects autoload registered, WHEN caller invokes `hit_pause(duration: 0.0)` or `hit_pause(-0.5)`, THEN call rejected with push_warning，`_pause_remaining_sec` 不變 (EC-03 binding)。 Source: Rule 2, EC-03 | Type: Logic | Gate: BLOCKING | File: `tests/unit/screen_effects/hit_pause_api_test.gd`
- **AC-03**: GIVEN ScreenEffects autoload registered, WHEN `set_motion_intensity(1.5)` called, THEN value silently clamped to 1.0 (no log, EC-05); WHEN `set_motion_intensity(NaN)` called, THEN value rejected with push_warning, previous value retained (EC-04). Source: Rule 3, EC-04, EC-05 | Type: Logic | Gate: BLOCKING | File: `tests/unit/screen_effects/motion_intensity_test.gd`
- **AC-04**: GIVEN `shake()` called with NaN intensity OR NaN duration OR ±INF, WHEN Rule 1 `is_finite()` check runs (before clamp), THEN call rejected with push_warning + `_rejected_calls += 1` (EC-01 + EC-02 binding). Source: Rule 1, EC-01, EC-02 | Type: Logic | Gate: BLOCKING | File: `tests/unit/screen_effects/shake_api_test.gd`

### Shake Math (Rules 4-7, Formulas 1-2)

- **AC-05**: GIVEN trauma value T = 0.6 at frame N, WHEN 1 frame elapses (delta = 1/60) with no new shake input AND decay_rate = 12.5, THEN trauma at frame N+1 = max(0, 0.6 - 12.5 × 0.0167) = 0.391 AND rendered offset.x = pow(0.391, 2) × MAX_OFFSET_PX × noise.x (Formula 1 Trauma² decay)。 Source: Rule 4, Formula 1, AC-D4 | Type: Logic | Gate: BLOCKING | File: `tests/unit/screen_effects/trauma_decay_test.gd`
- **AC-06**: GIVEN trauma value T1 = 0.4 from active shake (HIT_HEAVY 已 fire), WHEN second `shake(0.4, 0.12)` arrives same frame, THEN combined trauma = min(1.0, 0.4 + 0.4) = 0.8 (Formula 2 additive combiner)；decay_rate stays at max(12.5, 8.33) = 12.5 (Rule 5 monotonicity). Source: Rule 5, Formula 2, AC-D1 | Type: Logic | Gate: BLOCKING | File: `tests/unit/screen_effects/shake_combiner_test.gd`
- **AC-07** [Falsifiable Test #4 binding]: GIVEN 8 simultaneous HIT_HEAVY shake requests same frame (8 × `shake(0.4, 0.12)`), WHEN Formula 2 combiner runs, THEN final trauma = min(1.0, 8 × 0.4) = 1.0 (clamped)，shader uniform offset 絕對唔超出 MAX_OFFSET_PX (Rule 6 budget invariant)。Performance side: AC-27 (FR-1 ADR-001 RATIFICATION-GATED) covers per-frame CPU budget. Source: Rule 6, Section B Test #4, AC-D1 | Type: Logic | Gate: BLOCKING | File: `tests/unit/screen_effects/shake_combiner_test.gd`
- **AC-08** [Falsifiable Test #2 binding + AC-G3 generalize]: GIVEN `_motion_intensity = 0.0`, WHEN any `shake(i, d)` called (direct caller path OR dispatch table path), THEN trauma += 0 (no accumulation), `shake_offset_per_frame = Vector2.ZERO`, shader uniform latch-cleared once; BUT `hit_pause(d)` 照常 fire (Rule 7 + Section B locked: time perturbation ≠ vestibular)。 Source: Rule 7, AC-D2, AC-G3, Test #2 | Type: Logic | Gate: BLOCKING | File: `tests/unit/screen_effects/motion_intensity_test.gd`
- **AC-09**: GIVEN trauma value T < TRAUMA_EPSILON (0.01), WHEN Formula 1 decay tick runs, THEN trauma evaluation completely skipped (AC-D5 short-circuit)，one-shot clear shader uniform to Vector2.ZERO (Rule 4 `_trauma_just_zeroed` flag)。 Source: Rule 4, AC-D5, AC-G2 | Type: Logic | Gate: BLOCKING | File: `tests/unit/screen_effects/trauma_decay_test.gd`

### Hit Pause (Rules 8, 10, Formula 3)

- **AC-10**: GIVEN active hit_pause with `_pause_remaining_sec = 0.06`, WHEN new `hit_pause(0.04)` arrives, THEN remaining = max(0.06, 0.04) = 0.06 (Formula 3 max-remaining, no extend)。 Source: Rule 8, Formula 3 | Type: Logic | Gate: BLOCKING | File: `tests/unit/screen_effects/hit_pause_combiner_test.gd`
- **AC-11**: GIVEN `hit_pause(0.5)` called (caller bug, exceeds MAX_PAUSE_SEC=0.12)，WHEN Formula 3 runs, THEN pause_remaining clamped to MAX_PAUSE_SEC = 0.12s + push_warning emitted (AC-D3 binding)。 Source: Rule 2, Rule 8, AC-D3 | Type: Logic | Gate: BLOCKING | File: `tests/unit/screen_effects/hit_pause_ceiling_test.gd`
- **AC-12** [Falsifiable Test #3 binding]: GIVEN ScreenEffects autoload (PROCESS_MODE_ALWAYS) + GymSysClient autoload (PROCESS_MODE_ALWAYS), WHEN `hit_pause(0.12)` triggers `get_tree().paused = true`, THEN ScreenEffects `_process(delta)` continues ticking AND GymSysClient polling timer continues firing during 120ms freeze window; gameplay nodes (PAUSABLE) freeze。 Source: Rule 10, Section B Test #3 | Type: Integration | Gate: BLOCKING | File: `tests/integration/screen_effects/selective_freeze_test.gd`
- **AC-13**: GIVEN hit_pause completes (`_pause_remaining_sec <= 0`), WHEN HitPaused → Active transition, THEN `get_tree().paused = false` restored within 1 frame，`hit_pause_started` signal NOT re-emitted on exit。 Source: Rule 10, Interaction #6 | Type: Integration | Gate: BLOCKING | File: `tests/integration/screen_effects/hit_pause_lifecycle_test.gd`

### Dispatch Table (Rule 9, Interactions 1+4)

- **AC-14** [Falsifiable Test #1 binding]: GIVEN ParticleSystemWrapper emits `burst_started(PresetId.PARRY, position)`, WHEN ScreenEffects `_on_burst_started` handler runs, THEN auto-invoke `_apply_shake(0.6, 0.08)` AND `hit_pause(0.06)` per Rule 9 dispatch table。 Source: Rule 9, Interaction #1, Test #1 | Type: Integration | Gate: BLOCKING | File: `tests/integration/screen_effects/burst_dispatch_test.gd`
- **AC-15**: GIVEN ParticleSystemWrapper emits `burst_started(PresetId.HIT_LIGHT|STATUS_LIGHT|STATUS_HEAVY|STATUS_BUFF|LOOT_BURST, position)`, WHEN `_on_burst_started` handler runs, THEN preset NOT in `_DISPATCH` table → silent skip, no shake/pause, no log, `_dispatch_missed_count` unchanged for known presets (only EC-14 unknown PresetId increments counter)。 Source: Rule 9 (5 no-op presets), Section B sensation hierarchy noise floor | Type: Integration | Gate: BLOCKING | File: `tests/integration/screen_effects/burst_dispatch_test.gd`

### State Machine (Rules 12-13, ECs 07-12)

- **AC-16**: GIVEN ScreenEffects in Active state with `_emit_depth = 0`, WHEN `_apply_shake()` callback recursively invokes `_apply_shake()` (nested call detected via depth check), THEN re-entry rejected + push_warning + `_dropped_by_depth_guard += 1` (Rule 12 MAX_EMIT_DEPTH=0 strict)。 Source: Rule 12, EC-19 | Type: Logic | Gate: BLOCKING | File: `tests/unit/screen_effects/reentry_guard_test.gd`
- **AC-17** [Falsifiable Test #5 binding]: GIVEN GameStateMachine emits `state_changed(Suspended)` mid-active-shake (trauma=0.5, pause_remaining=0.03), WHEN Rule 13 Suspended entry sequence runs, THEN trauma=0, pause_remaining=0, shader uniform force-write Vector2.ZERO, `get_tree().paused = false` (if was true), state = SUSPENDED。 Source: Rule 13, EC-08, EC-10, Test #5 | Type: Integration | Gate: BLOCKING | File: `tests/integration/screen_effects/bfcache_suspend_test.gd`
- **AC-18** [Falsifiable Test #5 binding]: GIVEN bfcache resume after 30s page freeze (NOTIFICATION_APPLICATION_RESUMED fires), WHEN Rule 13 resume handler runs, THEN no residual shake offset visible first post-resume frame，no pending hit_pause from pre-suspend session applied，delta clamped to MAX_FRAME_DELTA=0.1 (EC-12)。 Source: Rule 13, EC-10, EC-11, EC-12 | Type: Integration | Gate: BLOCKING | File: `tests/integration/screen_effects/bfcache_resume_test.gd`
- **AC-19**: GIVEN ScreenEffects in Booting state (before `_ready()` 完成), WHEN external system invokes `shake()` / `hit_pause()` / `set_motion_intensity()` API, THEN call silent reject, `_rejected_calls` 唔 increment (Booting expected race per EC-07)。 Source: Rule 13, EC-07 | Type: Logic | Gate: BLOCKING | File: `tests/unit/screen_effects/boot_race_test.gd`

### Topology & CI (Rules 14-16)

- **AC-20** [AC-G4 binding]: GIVEN `HUD_SHAKES_WITH_WORLD = true` (default), WHEN shake amplitude > 0 applied, THEN HUDLayer position < ScreenEffectsLayer position → HUD pixels visibly offset; GIVEN toggle = false, THEN HUDLayer position > ScreenEffectsLayer → HUD pixels remain at identity transform (visual diff test)。 Source: Rule 14, AC-G4 | Type: Visual | Gate: ADVISORY | File: `production/qa/evidence/screen_effects_hud_toggle.md`
- **AC-21** [Falsifiable Test #6 binding]: GIVEN any .gd file in `src/` outside `src/autoload/screen_effects.gd` / `tests/` / `tools/debug/` whitelist, WHEN `tools/ci/check_screen_effects_callers.gd` runs via `godot --headless --script`, THEN build fails (exit code 1) if grep finds: `Camera2D.*\.offset\s*=`, `Engine\.time_scale\s*=`, `get_tree\(\)\.paused\s*=`, or `RenderingServer\.global_shader_parameter_set\(\s*["']u_shake_offset`。 Source: Rule 15, EC-18, Test #6 | Type: Logic | Gate: BLOCKING | File: `tests/unit/ci/check_screen_effects_callers_test.gd`
- **AC-22**: GIVEN ScreenEffects state mid-session (trauma=0.6, motion=0.5, pause_remaining=0.03), WHEN session terminates and new session boots, THEN `_trauma=0`, `_motion_intensity=1.0` (or SettingsManager value if available per EC-15), `_pause_remaining_sec=0` — no values persist (Rule 16 persistence ban，`tests/unit/screen_effects/no_persistence_test.gd` 驗證 ScreenEffects 唔 reference PersistenceLayer)。 Source: Rule 16 | Type: Logic | Gate: BLOCKING | File: `tests/unit/screen_effects/persistence_ban_test.gd`

### Cross-System Contracts (Section F)

- **AC-23**: GIVEN ParticleSystemWrapper `burst_started` signal emits at 60Hz peak (worst-case 8 bursts/sec sustained), WHEN ScreenEffects handler runs, THEN handler returns within per-frame budget (AC-27 FR-1 binding) AND does NOT block particle pipeline (signal handler ≤ 0.1ms p95)。 Source: Section F upstream #5, Rule 6 | Type: Performance | Gate: BLOCKING | File: `tests/performance/screen_effects/particle_dispatch_perf_test.gd`
- **AC-24**: GIVEN SettingsManager autoload (when implemented post-#22 GDD) calls `ScreenEffects.set_motion_intensity(0.5)` setter, WHEN Rule 3 setter executes, THEN `_motion_intensity = 0.5` stored，next `shake()` call uses 0.5 multiplier in Formula 2 (Section F Upstream SettingsManager contract — setter pattern, not signal)。 Source: Section F upstream SettingsManager, Rule 3 | Type: Integration | Gate: BLOCKING | File: `tests/integration/screen_effects/settings_propagation_test.gd`
- **AC-25**: GIVEN `hit_pause(d)` activates (Rule 2 + Rule 10), WHEN entering HitPaused state, THEN `hit_pause_started(duration_ms: int)` signal emit same frame as `get_tree().paused = true` (no 1-frame lag — both synchronous)，subscribers (e.g. future #4 AudioManager) receive signal payload with `duration_ms ≤ 120` (Rule 2 ceiling)。 Source: Section F downstream Interaction #6, Rule 10 | Type: Integration | Gate: BLOCKING | File: `tests/integration/screen_effects/hit_pause_signal_timing_test.gd`

### Pillar 3 Hard Guarantee

- **AC-26**: GIVEN 4 active dispatch presets {LOOT_RARE_BURST=0.2, DEATH=0.3, HIT_HEAVY=0.4, PARRY=0.6} 排序 by raw_intensity, WHEN evaluated at MAX_OFFSET_PX boundary (2.0/4.0/8.0), THEN (a) each preset's raw_intensity² >= TRAUMA_EPSILON (AC-G2 LOOT_RARE_BURST 0.04 > 0.01)；(b) max_amplitude(PARRY) >= 2 × max_amplitude(HIT_HEAVY) (AC-D6/G1 hierarchy gap invariant: 1.44px >= 1.28px @ default)。 Source: AC-D6, AC-G1, AC-G2 | Type: Logic | Gate: BLOCKING | File: `tests/unit/screen_effects/hierarchy_invariant_test.gd`

### ADR-001 RATIFICATION-GATED (3 ACs)

- **AC-27 [FR-1]**: GIVEN mobile Safari iOS 17+ on iPhone 12 / equivalent baseline target hardware, WHEN sustained shake load test runs (60s continuous `shake(0.4, 0.12)` HIT_HEAVY dispatch at 8 Hz + sustained `hit_pause(0.06)` at 2 Hz), THEN P95 CPU cost per frame for ScreenEffects ≤ value allocated in **ADR-001 (pending ratification)** separate from #5 GPU budget。 Source: Risk Register FR-1, Rule 6 | Type: Performance | Gate: ADR-001 RATIFICATION-GATED | File: `tests/performance/screen_effects/mobile_safari_p95_test.gd`
- **AC-28 [FR-2]**: GIVEN human playtest panel (n ≥ 5) on mobile Safari iOS 17+ device, WHEN sequence of HIT_HEAVY / PARRY / DEATH / LOOT_RARE_BURST shakes presented in random order during mid-set glance condition (10-30s rep window simulation), THEN ≥ 80% panelists correctly distinguish all 4 peripheral 體感 signatures (FR-2 binding — hierarchy gap perceptually validated)。LOOT_RARE_BURST 0.16px sub-pixel risk flagged if < 80%。 Source: Risk Register FR-2, AC-G1, AC-D6 | Type: Visual | Gate: ADR-001 RATIFICATION-GATED | File: `production/qa/evidence/screen_effects_peripheral_playtest.md`
- **AC-29 [FR-3]**: GIVEN `tools/ci/check_screen_effects_callers.gd` script + `EXPECTED_AUTOLOADS` whitelist, WHEN new autoload added to `project.godot` `[autoload]` section without corresponding `EXPECTED_AUTOLOADS` whitelist entry + `process_mode = PROCESS_MODE_ALWAYS` declaration, THEN CI fails build (exit 1) with explicit message naming offending autoload (FR-3 binding — autoload drift detection)。 Source: Risk Register FR-3, Rule 10, Rule 15 | Type: Logic | Gate: ADR-001 RATIFICATION-GATED | File: `tests/unit/ci/autoload_whitelist_drift_test.gd`

### Total count + breakdown

**29 ACs total** (qa-lead synthesis + 5 surgical fixes for API alignment):
- **25 BLOCKING**: AC-01 to AC-19, AC-21, AC-22, AC-23, AC-24, AC-25, AC-26
- **1 ADVISORY**: AC-20 (HUD topology toggle visual diff — production/qa/evidence)
- **3 ADR-001 RATIFICATION-GATED**: AC-27 (FR-1 CPU), AC-28 (FR-2 playtest), AC-29 (FR-3 CI drift)

### Coverage Map

| Section | Source items | ACs binding | Coverage |
|---------|--------------|-------------|----------|
| C — Rules 1-3 (API) | 3 rules | AC-01, 02, 03, 04 | 4/3 ✓ over |
| C — Rules 4-7 (Math) | 4 rules + 2 formulas | AC-05, 06, 07, 08, 09 | 5/6 ✓ |
| C — Rules 8, 10 (Hit Pause) | 2 rules + 1 formula | AC-10, 11, 12, 13 | 4/3 ✓ |
| C — Rule 9 (Dispatch) | 4 active + 5 no-op | AC-14, 15 | 2/2 ✓ |
| C — Rules 12-13 (State) | 2 rules | AC-16, 17, 18, 19 | 4/2 ✓ |
| C — Rules 14-16 (Topology/CI) | 3 rules | AC-20, 21, 22 | 3/3 ✓ |
| D — Formula ACs (D1-D6) | 6 candidates | Folded into AC-05/06/07/08/09/26 | 6/6 ✓ |
| E — Edge cases (HIGH impact) | 12 ECs (01-12, 18, 19) | Covered via AC-04, 02, 14/15, 16-19, 20-22 | HIGH covered |
| F — Cross-system contracts | 4 downstream | AC-23, 24, 25 | 3/4 (AudioManager AC pending #4 GDD) |
| G — Knob ACs (G1-G4) | 4 candidates | Folded into AC-08, 20, 26, 09 | 4/4 ✓ |
| B — Falsifiable Tests #1-6 | 6 tests | All covered: T#1→AC-14, T#2→AC-08, T#3→AC-12, T#4→AC-07, T#5→AC-17/18, T#6→AC-21 | 6/6 ✓ |
| Risk Register FR-1/2/3 | 3 invariants | AC-27, 28, 29 | 3/3 ✓ |

### Noteworthy Gaps (flagged for next-revision)

1. **Section F downstream contract #4 (AudioManager ducking)** — 暫無 AC binding 因為 #4 AudioManager GDD 未 authored。`hit_pause_started` signal contract covered by AC-25，但 audio-side ducking response timing 留待 #4 GDD ratification 後 supplement (AC-30 candidate)
2. **Section E low-impact ECs (EC-13, 14, 15, 16, 17)** — deliberately untested per AC scope discipline (focus on HIGH-impact ECs)。Covered by code review + manual smoke check
3. **AC-27 (FR-1 mobile Safari P95) — exact CPU budget value 待 ADR-001 ratification**。AC structure 已 lock，threshold 數字 fill-in-blank
4. **CI script coverage (AC-21, AC-29)** — assumes `tools/ci/check_screen_effects_callers.gd` 由 devops-engineer author。需 coordinate with devops sprint

## Open Questions

本 GDD 識別 7 個 open questions across Section F (5 carried forward) + Section H + V/A (2 new)。每個 question 包：owner / trigger / default if未 resolved / risk if未 resolved。

### Q-F1 — `hit_pause_started(duration_ms)` payload type

- **Question**: AudioManager subscribe `hit_pause_started(duration_ms: int)` — int milliseconds 定 float seconds?
- **Owner**: #4 AudioManager GDD authoring (pending)
- **Trigger**: #4 GDD authoring start
- **Default if未 resolved**: `int milliseconds` (per Section C Interaction #6 + AC-25 locked spec)
- **Risk if未 resolved**: 若 future audio system 需要 sub-ms precision (e.g. sample-accurate ducking)，可能 push to float — minor refactor

### Q-F2 — ADR-001 CPU budget allocation for ScreenEffects

- **Question**: ADR-001 必須 specify ScreenEffects CPU budget allocation (FR-1 Risk Register) — separate from #5 GPU budget
- **Owner**: ADR-001 authoring (queued)
- **Trigger**: ADR-001 / Web Export Budget Caps ratification
- **Default if未 resolved**: AC-27 結構 lock，threshold 數字 fill-in-blank pending ADR-001
- **Risk if未 resolved**: VS-tier mobile Safari playtest 可能發現 sustained shake load 超出 budget，要 retro-fit fallback (e.g. concurrent shake limit 1)

### Q-F3 — CI script `EXPECTED_AUTOLOADS` whitelist enforcement

- **Question**: Rule 15 CI script + FR-3 binding — VS-tier first autoload addition 必須 enforce whitelist update。誰負責 author + maintain `tools/ci/check_screen_effects_callers.gd`?
- **Owner**: devops-engineer (coordinate per AC-21 + AC-29)
- **Trigger**: VS-tier sprint planning OR first autoload addition post-#5
- **Default if未 resolved**: AC-21 + AC-29 BLOCKING — sprint review fails without CI ready
- **Risk if未 resolved**: 新 autoload silent forget PROCESS_MODE_ALWAYS → hit pause 期間 GymSys polling missed → Falsifiable Test #3 violation in production

### Q-F4 — CanvasLayer topology enforcement (Rule 14)

- **Question**: GameLayer 0 / ParticleLayer 10 / HUDLayer 50 / ScreenEffectsLayer 100 — 由邊個 system / scene 負責 enforce 呢個 topology?
- **Owner**: Master scene setup (likely ADR-001 input scope OR a #00 Scene Topology GDD if created)
- **Trigger**: VS-tier scene scaffolding
- **Default if未 resolved**: Documentation in Rule 14 + EC-18 (Camera2D missing graceful) — runtime check via test
- **Risk if未 resolved**: Wrong topology → HUD_SHAKES_WITH_WORLD knob unpredictable (Q-F5 cascade)

### Q-F5 — HUD_SHAKES_WITH_WORLD knob runtime implementation

- **Question**: `HUD_SHAKES_WITH_WORLD = false` → HUDLayer position > ScreenEffectsLayer。實作機制 — runtime layer reordering 定 compile-time layer assignment?
- **Owner**: #22 Character Screen GDD owner + master scene owner
- **Trigger**: #22 GDD authoring OR accessibility settings sprint
- **Default if未 resolved**: Compile-time layer assignment based on initial knob value (no runtime toggle) — V1 simplest
- **Risk if未 resolved**: 若 future 需 in-session toggle (e.g. boss fight auto-disable shake)，需要 runtime layer swap mechanism — minor refactor

### Q-V1 NEW — Sub-pixel risk for LOOT_RARE_BURST (FR-2 monitor)

- **Question**: LOOT_RARE_BURST max_amplitude 0.16px (raw_intensity 0.2² × MAX_OFFSET_PX 4.0) 喺 low-DPI displays (1080p standard zoom) 可能 imperceptible — playtest n≥5 panel 結果如何?
- **Owner**: art-director + qa-lead (FR-2 Risk Register monitor binding to AC-28)
- **Trigger**: VS-tier playtest panel session
- **Default if未 resolved**: 接受 FR-2 fallback options (per Section B Risk Register: 增 raw_intensity 至 0.3 OR 提升 MAX_OFFSET_PX 至 5.0+) — wait playtest result
- **Risk if未 resolved**: Pillar 3 LOOT_RARE_BURST sensation channel 失效 — drop event「冇感覺」喺 體感 layer，純靠 #5 particle visual carry — Pillar 3 二重保護退化到單線

### Q-V2 NEW — Audio ducking fade-in curve shape

- **Question**: `hit_pause_started` exit 後，AudioManager fade-in resume 10-15ms ramp 用 linear 定 exponential curve?
- **Owner**: #4 AudioManager GDD owner + audio-director
- **Trigger**: #4 GDD authoring (Audio Requirements subsection)
- **Default if未 resolved**: Linear (simpler, predictable; 10ms 短 enough 兩種 curve perceptual 差異微小)
- **Risk if未 resolved**: Exponential 可能更 natural for fade-in，但 micro-perceptual benefit only — defer to audio-director sign-off
