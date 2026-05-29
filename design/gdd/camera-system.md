# Camera System

> **Status**: Approved with revisions (CD-GDD-ALIGN passed + Pass 1/2/3/4 reviews — Pass 3 full adversarial (5 specialists): 7 BLOCKING + Batch 2 accessibility + 4 Pass 4 lean items all patched inline; 17 total patches across Pass 1-4; see [reviews/camera-system-review-log.md](reviews/camera-system-review-log.md))
> **Author**: Frank + creative-director (Section B Silent Showrunner framing + Phase 5a-bis gate) + game-designer + ux-designer + gameplay-programmer (Section C 14 rules synthesis) + systems-designer (Section D 5 formulas + Section E 24 edge cases) + qa-lead (Section H 35 ACs synthesis)
> **Last Updated**: 2026-05-26
> **Creative Director Review (CD-GDD-ALIGN)**: APPROVED 2026-05-26 — 10 findings (8 ALIGN + 2 ADVISORY resolved inline, 0 BLOCKING, 0 CONCERNS). CD assessment: "matches or exceeds the #6 ScreenEffects precedent strength on every measured dimension: indirect fantasy framing rigour, Falsifiable Test enumeration, Risk Register binding to a real ratification gate, CI + runtime + AC three-layer enforcement of pillar contracts, and channel separation as creative principle rather than engineering shortcut". Foundation tier fantasy vocabulary partition now complete (4-way: #1 temporal / #5 peripheral visual / #6 peripheral kinaesthetic / #7 spatial framing).
> **Implements Pillar**: Pillar 2 (Frictionless Companion) primary; Pillar 3 (Drop Euphoria) supporting
> **System #**: 7 (Foundation / VS tier)
> **Depends On**: (none — Foundation leaf)
> **Depended On By**: #14 EnemyDirector (explicit per systems-index); likely future implicit: #21 Loot Drop Modal / #25 Combat Visual Feedback / #26 Avatar Renderer
> **Governing ADRs**: ADR-006 State Machine Contract (Contract 4 autoload sequential + Contract 6 connect_for_initial_state — Camera subscribes to GSM state_changed); ADR-001 Web Export Budget Caps (pending — Camera CPU + fillrate budget gate-binding)
> **Locked constraints from sister GDDs**:
> - #6 ScreenEffects Rule 14: GameLayer = CanvasLayer 0 (Camera住呢度); ScreenEffectsLayer = CanvasLayer 100 BackBufferCopy
> - #6 CI Rule 15: NO Camera2D.offset mutation outside ScreenEffects autoload
> - #6 stretch_shrink = 1.05 SubViewport oversample (Camera must tolerate 5% bleed)
> - #6 EC-18: Camera2D missing/disabled does NOT crash shake (graceful decouple)
> - #1 GSM: subscribe via connect_for_initial_state per ADR-006 Contract 6; Suspended entry cancels in-flight motion

## Overview

Camera System 係 Mirror Hero 處理 2D gameplay viewport 嘅 Foundation 層 singleton autoload — own 一個 Camera2D node parented to GameLayer (CanvasLayer 0 per #6 ScreenEffects Rule 14 locked topology)，做 active gameplay scene 嘅 viewport coordinator。系統暴露兩個 motion mode：(1) **Follow mode** (default) — 平滑跟隨 avatar via Camera2D built-in `position_smoothing_enabled` + dead-zone drag margins；(2) **Focal mode** — 短暫 zoom + recenter 為 Boss spawn / LootDrop ritual moment 提供鏡頭聚焦（recenter 喺玩家可預期嘅 ritual moment fire，唔係 mid-rep 嘅 surprise pan）。訂閱 #1 GameStateMachine `state_changed` via `connect_for_initial_state` per ADR-006 Contract 6 — Suspended state 強制 cancel in-flight focal tween + reset 回 follow mode default zoom；bfcache resume 後 restore last known state。系統嚴格 decouple from #6 ScreenEffects：依承 CI Rule 15 禁止 caller 喺 ScreenEffects autoload 之外嘅 file mutate `Camera2D.offset`（shake 走 shader uniform path），所以本 system 唔可以加 ad-hoc shake / jitter — Camera 同 ScreenEffects 各 own 一個 viewport perturbation channel，互不干涉。系統 stateless from gameplay perspective — 唔 own 任何 game state，唔 emit gameplay event，純粹係「目前該睇邊度」嘅 reactive viewport controller，同 #1 GSM 嘅 architectural posture「invisible reliability」一致：玩家 mid-set glance 期間，camera follow 應該係 imperceptible smooth；只有 Boss / LootDrop 等 ritual moment 嘅 focal emphasis 先構成 deliberate signal。VS-tier scope 鎖死 single behaviour 跨 desktop + mobile；mobile-specific zoom / follow 調整、SubViewport `stretch_shrink = 1.05` oversample 嘅 viewport edge coordination 將喺 ADR-001 Web Export Budget Caps input scope 處理。

## Player Fantasy

**Indirect Showrunner Fantasy — 沉默嘅 Showrunner (Silent Showrunner)**:

玩家心入面嘅 felt promise：「**我做緊 bench press 第 8 rep，下巴貼地 grinding。冇望畫面 50 秒咁啦 — 但啱啱見到 bar racked 上嗰個瞬間 peripheral 一掃，個 avatar 仲喺正中度，剛剛 PARRY 完。冇追、冇搵、冇 cognitive cost — 個畫面就「正好喺嗰度」等我。Boss 入場嗰一吓我有少少察覺 — 畫面 push-in 咗少少，啲背景模糊咗 — 但又冇激烈到分散我注意力。set 結束嗰刻我 sit up 一望，全螢幕 zoom 緊 boss 嘅 deathblow — DNF 嗰種 cinematic rally feeling — 啱啱好 hit me。**」

呢個 fantasy 唔由 Camera 自己 emit 任何敘事 text — 而係由佢嘅 **architectural posture** 強制：

- **Critically-damped Follow mode 嘅 silent contract** (default mode — `Camera2D.position_smoothing_enabled = true` + 適度 drag margins) — Avatar 永遠喺 screen central region 嘅 expected location，glance-back lock-on 時間 < 500ms。Camera 嘅最高紀律係「冇必要時絕不行動」— mid-rep 任何 zoom / jerk / cut 都係 showrunner 嘅 professional failure，violates Pillar 2 mid-set frictionless contract
- **Focal mode 嘅 cinematic push-in** (Boss spawn / LootDrop ritual moments — short zoom + recenter tween) — 模仿電視導播喺關鍵時刻嘅 push-in shot，觀眾無意識咁接受「呢一刻好重要」嘅訊號。但 Focal 只喺 player **可預期** 嘅 ritual moment fire (Boss 出場、LootDrop reveal 兩種事件)，從唔喺 mid-rep / mid-set 出現。Pillar 3 嘅「值得 cap 圖」DNF rally feel 通過 cinematic framing 而非 sudden surprise 達成
- **Channel separation as creative principle** — Camera 唔 own shake / jitter — 任何 `Camera2D.offset` mutation 由 #6 ScreenEffects shader uniform path 處理 (#6 CI Rule 15 禁止外部 file 寫 offset)。Showrunner 唔會用 zoom 表達「擊中」(嗰個係 ScreenEffects 嘅 channel)，亦唔會用 shake 表達「呢段重要」(嗰個係 Camera 嘅 channel)。Decoupling 唔係 engineering shortcut，而係 *cinematographic separation of concerns*
- **Suspended state cancel + bfcache resume restore** — Showrunner respect real-world priority：當 browser suspend / page lifecycle 中斷，camera 立即 cancel in-flight focal tween + reset 回 follow mode default zoom。Resume 時 restore last known state (follow target + position) — 玩家從唔會 catch 到「半路 ritual 卡住」嘅 incoherent frame

呢個 indirect Showrunner fantasy 同 GDD #1 GSM 嘅「invisible reliability」、#5 ParticleSystemWrapper 嘅「眼角擒獲」、#6 ScreenEffects 嘅「眼角嘅爆擊」一齊形成 **Foundation tier 嘅統一 fantasy vocabulary**：

- #1 owns *temporal* continuity (state machine reliability)
- #5 owns *peripheral visual* signal (particle burst attention capture)
- #6 owns *peripheral kinaesthetic* signal (shake + hit pause 體感印章)
- **#7 (this system) owns *spatial* framing** (camera 決定 player 嘅眼睛去邊)

四個 Foundation system 各 own player's attention 嘅 distinct channel，互不干涉，合起來保證 Pillar 2 嘅「workout 期間 BACKGROUND 存在」 contract 完整。

呢個 indirect fantasy 直接 enables：

- **Pillar 2 (無壓力陪伴 — primary owner)** — Critically-damped Follow + zero mid-rep camera motion + Suspended state respect → Camera 唔會破壞 mid-set peripheral safety。Glance-back lock-on time < 500ms = Camera 嘅 frictionless contract 嘅 hard metric
- **Pillar 3 (DNF 式爆裝刺激 — supporting owner via cinematic framing)** — Focal mode 嘅 cinematic push-in 喺 Boss spawn / LootDrop ritual moment 加 dopamine peak 嘅 cinematographic weight。同 #5 (particle burst) + #6 (shake + hit pause) 嘅 sensation hierarchy 合作 deliver 完整 DNF feel — 視覺爆發 + 體感印章 + cinematic framing 三者 stacked

**Falsifiable design test** — 任何 client-side path 引致以下情境 = bug，唔係 acceptable behavior：

1. **CombatActive-state Focal trigger** — EnemyDirector 喺 active combat (non-boss) 期間觸發 `request_focal()` (e.g. trash mob killcam 嘅 random focal moment) → 玩家被迫聚焦畫面打斷 set → **Pillar 2 mid-combat frictionless contract 違反 + showrunner predictability 失效**
2. Follow mode smooth pursuit overshoot / oscillate (e.g. `position_smoothing_speed` 配置錯誤令 camera 喺 avatar 周圍 wobble) → glance-back 時 camera 仲喺「追」avatar，未 settle → **lock-on time > 500ms + Showrunner predictability test fail**
3. Bfcache resume 時 camera stuck 喺 half-zoomed Focal mode (Suspended cancel 漏 trigger) → resume 第一 frame 玩家見到 incoherent partial-zoom → **Showrunner respect real-world priority contract 違反**
4. Camera 喺 ScreenEffects autoload 之外嘅 file 加咗 ad-hoc `Camera2D.offset` mutation (e.g. EnemyDirector 想加「boss spawn camera punch」自定 jitter) → effect stack 同 ScreenEffects shake 互相 stomp + channel purity 崩潰 → **CI Rule 15 違反 + Showrunner Channel separation principle 違反**
5. Focal mode tween ease-in 而非 ease-out (push-in 感受變「被拉去」而非「想望過去」) → cinematographic invitation 變 cinematographic coercion → **DNF rally feel 失效**
6. **WorkoutActive-state Focal trigger** — random ambient script (e.g. background NPC quest trigger, environmental cue, time-based scripted event) 喺 mid-set rest 期間觸發 `request_focal()` (尚未進入 BOSS_ENCOUNTER / LOOT_DROP state) → Pillar 2 隱形契約被打破 → **Camera 主動「邀請」player 望畫面 = anti-Pillar-2 violation；distinct from Test #1 (CombatActive) — WorkoutActive 嘅 Focal trigger 屬 ambient script / scene-level violation，唔係 combat AI 嘅 violation path**

### Fantasy Risk Register

呢個 indirect fantasy 嘅 「showrunner posture」 framing 係 contingent on 以下 invariants 喺 **ADR-001 ratification + VS-tier playtest** 真正 enforced，否則 Player Fantasy paragraph 變 retroactive lie：

| # | Contingent Invariant | Owner | Fallback if Dropped |
|---|---------------------|-------|---------------------|
| FR-1 | Follow mode `position_smoothing_speed` 配置令 critically-damped 行為 cross-platform (desktop + mobile Safari Compatibility renderer) 一致 — 唔會有 platform-specific overshoot | ADR-001 + VS-tier `/playtest-report` | 若 mobile Compatibility renderer 出現 overshoot → 平台分別配置 smoothing_speed；或喺 mobile auto-disable smoothing (snap follow) — Pillar 2 protected at cinematic loss |
| FR-2 | Focal mode 嘅 zoom + recenter tween 喺 60fps target 達成 perceptually smooth (**quart ease-out** entry + **cubic ease-in-out** exit)；Web Export Compatibility 模式下唔可以 frame-drop 到 < 30fps mid-Focal | ADR-001 frame budget allocation | 若 Focal 期間 frame drop → 縮短 Focal duration 至 0.4s (原 ~0.8s)；OR 喺 mobile auto-disable Focal (snap to zoom，無 tween) — Pillar 3 ritual emphasis 弱化但保留 |
| FR-3 | Focal mode 嘅 trigger 限喺 #1 GSM 通知嘅 BossEncounter / LootDrop entry — 唔會喺 WorkoutActive / CombatActive 直接觸發 (mid-set 隱形契約 hard guarantee) | gameplay-programmer + CI script | 若 caller violation → Camera autoload 喺 `_request_focal()` 入口 assert `GSM.current_state ∈ {BOSS_ENCOUNTER, LOOT_DROP}` else silently drop + push_warning + drop counter — fail-loud at runtime |

**Ratification gate binding**: ADR-001 review MUST verify implementation satisfies FR-1 + FR-2 + FR-3 before Status: Accepted。若 ADR-001 lands without 任何一個 → revisit this Player Fantasy paragraph with the corresponding fallback framing。

## Detailed Rules

### Internal States (4)

| State | Entry | Exit | Behaviour |
|-------|-------|------|-----------|
| **Booting** | Autoload `_ready()` | First successful `connect_for_initial_state(GSM.state_changed)` resolved + scene calls `register_camera()` | `set_follow_target()` queued (single deferred slot); `request_focal()` silent reject; zoom = `DEFAULT_ZOOM`; no Camera2D mutation until scene registers |
| **Following** | Booting complete OR `clear_focal()` exit OR GSM exits SUSPENDED with valid cached target | `request_focal()` accepted OR GSM enters SUSPENDED | Critically-damped smoothing toward `follow_target.global_position` via Camera2D built-in (`position_smoothing_enabled = true`, `position_smoothing_speed = 5.0`); drag margins active (8% × 12% asymmetric); world bounds clamped per scene-set `Camera2D.limit_*` |
| **Focal** | `request_focal()` accepted AND GSM state ∈ {`BOSS_ENCOUNTER`, `LOOT_DROP`} | Tween completion → auto-transition Following OR explicit `clear_focal()` OR GSM SUSPENDED | Tween active (Camera2D zoom + position, **ease-out quart** entry 0.6s / **ease-in-out cubic** exit 0.5s); follow smoothing disabled (smoothing handed back on Following entry); `request_focal()` re-entry strict-reject |
| **Suspended** | GSM `state_changed → SUSPENDED` (覆蓋一切) | GSM `state_changed → 非 SUSPENDED` (handler return → Following with cached target if valid, else Booting fallback) | Force reset: `_active_tween.kill()` if any; `_camera.zoom = DEFAULT_ZOOM`; `_camera.reset_smoothing()`; cache `_follow_target.get_path()` to `_cached_target_path: NodePath`; reject all API calls (silent + counter) |

**Suspended 永遠覆蓋一切** (per Section B Showrunner respect real-world priority contract — bfcache resume / page suspend = cancel 殘留 Focal tween)。Focal 唔可以 race Suspended — Suspended entry sequence (Rule 8) 強制 cancel tween + reset zoom。

### Interactions (6)

1. **Upstream: `GameStateMachine.connect_for_initial_state(_on_gsm_state_changed)`** → ADR-006 Contract 6 subscription。Suspended entry triggers Rule 8 cancel-all sequence; non-Focal GSM states (WORKOUT_ACTIVE / COMBAT_ACTIVE / etc.) gate-reject any in-flight `request_focal()` per Rule 4
2. **Upstream: Scene bootstrap** — scene root 喺 `_ready()` 之後 call `Camera.register_camera(camera2d_ref)` 將 Camera2D node reference 交畀 autoload；同時 set world bounds via `camera2d_ref.limit_*` (scene-direct，per Rule 10)
3. **Upstream: Caller path** — `set_follow_target(node)` / `request_focal(target_pos, duration, zoom)` / `clear_focal()` 嘅 caller (scene script、#14 EnemyDirector boss spawn、#21 LootDrop Modal ritual entry)。Caller 必須係 trusted gameplay code，唔可以 random script 直接 reach Camera2D
4. **Downstream: Camera2D rendering** — autoload write Camera2D properties (position via smoothing, zoom via tween); render pipeline (CanvasLayer 0 GameLayer per #6 Rule 14 topology) 自動 apply
5. **Downstream: `focal_completed(target_position: Vector2)` signal** — emit 喺 Focal exit (tween complete or `clear_focal()`)，畀 caller chain follow-up actions (e.g. #21 LootDrop Modal 等 focal complete 先 reveal modal content)
6. **Forbidden coupling: #6 ScreenEffects** — Camera autoload 唔可以 mutate `Camera2D.offset` (#6 owns 經 shader uniform path); #6 嘅 `u_shake_offset` shader uniform 同 Camera transform 互不干涉 — Camera 寫 position / zoom，shader 寫 offset，render pipeline composite。Rule 13 CI enforce

### Rules (14)

#### Rule 1 — Closed API surface

```gdscript
# Public API (called by trusted gameplay code only)
func register_camera(cam: Camera2D) -> void           # scene bootstrap injection (once per scene)
func unregister_camera() -> void                      # scene tear-down explicit unbind (kills tweens, clears _camera ref) — see EC-17/EC-20
func set_follow_target(node: Node2D) -> void          # Following mode pursuit target
func request_focal(target_position: Vector2, duration: float = 0.6, zoom_level: float = 1.4) -> void
func clear_focal() -> void                             # explicit early exit (auto-fires on tween complete)
# Future-reserved (post-#22 GDD): func set_motion_reduction(enabled: bool) -> void  # per UI Requirements Q-V1

# Signals (Interaction #5)
signal focal_completed(target_position: Vector2)
signal camera_target_lost()                            # Unified loss signal: emitted on (a) Rule 9 bfcache resume stale NodePath, (b) EC-01 set_follow_target(null), (c) EC-16 _follow_target queue_free'd mid-frame
signal focal_target_clamped(requested: Vector2, clamped: Vector2)  # EC-23 — Camera2D.limit_* clamped Focal target
```

No return values for action APIs (closed library, caller 唔 handle handle)。Rule 13 CI enforce 唔可以喺 wrapper 之外嘅 file mutate Camera2D properties (`position` / `zoom` / `offset` / `make_current` / `limit_*` 以外嘅 properties)。NaN / ±INF 喺 `target_position` / `duration` / `zoom_level` → reject + `push_error` + early return (Foundation autoload 唔 throw — 同 #5/#6 一致)。

Rationale: closed primitive 同 #5/#6 architectural posture 一致 — Showrunner Channel separation (Section B) 喺 API 層 enforce。

#### Rule 2 — Follow mode: Critically-damped smoothing via Godot built-in

用 Godot 4.6 `Camera2D.position_smoothing_enabled = true` + `position_smoothing_speed = 5.0` (Godot default critically-damped sweet spot — exponential decay `pos = lerp(pos, target, 1 - exp(-speed × delta))`; settle ~200ms 至 63%, ~600ms 至 95%)。**Reject** custom spring math: VS-tier scope，Godot built-in 已滿足 < 500ms glance-back lock-on metric (Section B Falsifiable Test #2)。

Rationale: Hades baseline 用同類 critically-damped speed (~5.0)；DNF town camera 同類 settle profile。> 8.0 = snappy/rubber-band (Maple jump-cam complaint)，< 3.0 = sluggish。5.0 = competitive middle ground，frame-rate independent post-Godot-4.4。

#### Rule 3 — Drag margin defaults: 8% × 12% asymmetric dead-zone

```gdscript
_camera.drag_horizontal_enabled = true
_camera.drag_vertical_enabled = true
_camera.drag_left_margin = 0.04   # 8% total horizontal dead-zone (4% each side)
_camera.drag_right_margin = 0.04
_camera.drag_top_margin = 0.06    # 12% total vertical dead-zone (6% each side)
_camera.drag_bottom_margin = 0.06
```

Rationale: 2D side-scroller vertical motion (jumps / falls) 比 horizontal walks 更不 perceptible — 寬鬆 vertical dead-zone 避免 frequent vertical correction triggering peripheral motion sickness。Mid-bench-press peripheral glance test 嘅 hard metric。Hades / DNF Mobile 用類似 asymmetric (wider vertical) pattern。

Mobile-specific bump (12% × 16%) defer ADR-001 — VS-tier single behaviour cross-platform。

#### Rule 4 — Focal state gating (HARD enforcement per Pillar 2 mid-set contract)

```gdscript
func request_focal(target_position: Vector2, duration: float = 0.6, zoom_level: float = 1.4) -> void:
    if not _is_finite_vec2(target_position) or not is_finite(duration) or not is_finite(zoom_level):
        push_error("Camera.request_focal: NaN/INF rejected"); _rejected_calls += 1; return
    if _state == State.SUSPENDED or _state == State.BOOTING:
        _rejected_calls += 1; return  # silent reject
    if _gsm.current_state not in [GameStateMachine.State.BOSS_ENCOUNTER, GameStateMachine.State.LOOT_DROP]:
        push_warning("Camera.request_focal rejected: GSM state=%s (mid-set frictionless contract)" % _gsm.current_state)
        _focal_gating_rejected_count += 1
        return
    if _state == State.FOCAL:
        push_warning("Camera.request_focal rejected: active Focal in progress (strict reject — see focal_completed signal for chaining)")
        _focal_reentry_dropped_count += 1
        return  # Rule 5 re-entry guard
    _enter_focal(target_position, duration, zoom_level)
```

Rationale: Section B Falsifiable Test #1 + #6 binding — mid-WorkoutActive / mid-CombatActive Focal 觸發 = Pillar 2 violation。Hard runtime assert + `_focal_gating_rejected_count` telemetry counter surface caller bugs。**GSM `current_state` ordering contract (ADR-006 Contract 7 cross-reference)**: Rule 4 line `_gsm.current_state not in [...]` 假設 GSM 喺 `state_changed.emit()` 之前 已 set `current_state`（write-before-emit ordering）。Implementer 必須 verify：ADR-006 Contract 7 race guard 保證呢個 ordering；若 GSM 用 emit-then-write pattern，EnemyDirector 喺 signal handler 內 call `request_focal()` 時 read 見 OLD state → silent reject + ritual lost (same-frame race)。

#### Rule 5 — Re-entry guard: Strict reject (depth = 0)

Active Focal + 新 `request_focal()` → silent reject + `_focal_reentry_dropped_count += 1` + `push_warning`。Caller 想 chain → subscribe `focal_completed(target_position)` signal 等 current Focal 完成先 fire 下一個。**唔 queue** (per #6 Rule 8 同類 max-remaining philosophy — ritual moments 唔 stack)。**唔 max-remaining** (Focal duration 唔似 hit_pause 嘅 60ms — Focal 600ms duration max-remaining 會引致 unpredictable composition)。

Rationale: ritual moments 係 deliberate cinematographic beat，queuing / max-remaining 會引入 unpredictable timing。Caller responsible for ordering via signal chain。Mirror #6 Rule 12 strict depth = 0 stance。

#### Rule 6 — Focal mode tween spec

```gdscript
func _enter_focal(target_position: Vector2, duration: float, zoom_level: float) -> void:
    _state = State.FOCAL
    _camera.position_smoothing_enabled = false  # disable follow during Focal
    var resolved_target := target_position
    if not _is_finite_vec2(target_position) and _follow_target:
        resolved_target = _follow_target.global_position  # fallback to follow target if caller passes invalid
    # Tween bound to Camera2D (not autoload) — scene-free Camera2D auto-kills tween, prevents NPE on freed node
    _active_tween = _camera.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PAUSABLE)  # Rule 12
    _active_tween.set_parallel(true)
    _active_tween.tween_property(_camera, "position", resolved_target, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
    _active_tween.tween_property(_camera, "zoom", Vector2(zoom_level, zoom_level), duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
    _active_tween.chain().tween_callback(_on_focal_complete.bind(resolved_target))
```

Default `duration = 0.6s`, `zoom_level = 1.4x` (motion safety cap — 玩家 mid-set physical exertion + steep zoom = vestibular conflict risk；1.4x 仍提供 cinematic push-in 嘅 DNF rally feel 但低於 1.5x cap)。Recenter target = caller-provided world position (fallback to `_follow_target.global_position` if NaN)。

Rationale: ease-out quart 前 30% duration covers 76% zoom distance (Section D Formula 2) → camera 「lunges」 first，then settles → 玩家 perceive 為「invitation」(camera 主動帶你睇)，唔係「pulled」(camera 強迫 player 望)。Quart over cubic：cubic only delivers 65.7% in 30% time，weakens lunge perception；quart matches DNF Otherverse portal push-in snappiness。Section B Falsifiable Test #5 binding。

#### Rule 7 — Focal exit: 0.5s ease-in-out symmetric

```gdscript
func _on_focal_complete(target_position: Vector2) -> void:
    focal_completed.emit(target_position)
    # 自動 transition Following — exit tween (bound to Camera2D per Rule 6 pattern)
    _exit_tween = _camera.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PAUSABLE)
    _exit_tween.set_parallel(true)
    # is_instance_valid guards against freed Node2D (queue_free'd mid-Focal — EC-16)
    var return_pos := _follow_target.global_position if is_instance_valid(_follow_target) else target_position
    _exit_tween.tween_property(_camera, "position", return_pos, 0.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
    _exit_tween.tween_property(_camera, "zoom", DEFAULT_ZOOM, 0.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
    _exit_tween.chain().tween_callback(_on_focal_exit_complete)

func _on_focal_exit_complete() -> void:
    _state = State.FOLLOWING
    _camera.position_smoothing_enabled = true  # re-enable follow
```

Rationale: ease-in-out symmetric breath-out feel (Hades pacing) — 玩家 absorb cinematic beat 之後 efficient 但 smooth return to baseline。0.3s snap-back = jarring；0.5s = breath out。Section B Falsifiable Test #5 binding (cinematographic invitation 嘅 ease-out 對應 exit 嘅 symmetric ease)。

#### Rule 8 — GSM Suspended cancel sequence

```gdscript
func _on_gsm_state_changed(new_state: GameStateMachine.State) -> void:
    if new_state == GameStateMachine.State.SUSPENDED:
        # CRITICAL: kill tweens first, THEN manually execute cleanup — prevents state leak
        # (_exit_tween.kill() blocks _on_focal_exit_complete callback, so cleanup must happen explicitly:
        #  reset zoom + re-enable smoothing to avoid leaving _state=FOCAL on resume — see godot-gdscript review)
        if _active_tween: _active_tween.kill(); _active_tween = null
        if _exit_tween: _exit_tween.kill(); _exit_tween = null
        _camera.zoom = DEFAULT_ZOOM
        _camera.position_smoothing_enabled = true  # force re-enable (covers mid-Focal-entry + mid-exit-tween cases)
        _camera.reset_smoothing()  # snap to target, reset velocity
        _cached_target_path = _follow_target.get_path() if is_instance_valid(_follow_target) else NodePath("")
        _state = State.SUSPENDED
    elif _state == State.SUSPENDED:
        # 非 SUSPENDED → restore Following (Rule 9)
        _restore_from_suspend()
```

Rationale: Section B Falsifiable Test #3 binding — bfcache resume 一刻唔可以見到 half-zoomed Focal frame。`Camera2D.reset_smoothing()` 確保 smoothing velocity = 0 + position snap to target (avoid post-resume rubber-band)。**Web Export bfcache note**: `TWEEN_PROCESS_PAUSABLE` tracks `SceneTree.paused` — **唔** 自動 pause on browser `visibilitychange` / page-hide events。Web Export 嘅 GSM SUSPENDED 由 JS visibility bridge → GymSys polling pause → `state_changed(SUSPENDED)` signal 觸發，唔係由 Tween system 自動觸發。唔可以靠 Tween freeze 作為 Web Export suspend 保護 — Rule 8 GSM signal-driven kill-all 係唯一可靠路徑。

#### Rule 9 — bfcache resume restore

```gdscript
func _restore_from_suspend() -> void:
    var resolved := get_node_or_null(_cached_target_path) as Node2D if not _cached_target_path.is_empty() else null
    if resolved:
        _follow_target = resolved
        # CRITICAL: snap-to-target BEFORE re-enabling smoothing — prevents bfcache resume teleport
        # (delta=MAX_FRAME_DELTA=0.1s × Formula 1 would jump 39.3% of offset in single frame — visible jolt)
        _camera.global_position = resolved.global_position
        _camera.reset_smoothing()  # zero velocity, prevents post-resume rubber-band
        _state = State.FOLLOWING
    else:
        _follow_target = null
        _state = State.BOOTING  # scene re-registration required
        camera_target_lost.emit()  # signal — scene should re-set_follow_target() or fall back to spawn anchor
```

Rationale: Section B Falsifiable Test #3 + #4 — bfcache resume + WASM reinit 後 scene tree 可能已重建，cached NodePath 可能 stale。`camera_target_lost` signal 畀 scene root 接住 → set 新 spawn anchor。Persistence ban (Rule 14) 意味唔可以 read PersistenceLayer 嘅 cached target — scene 主動 re-wire。

#### Rule 10 — World bounds: scene-direct `Camera2D.limit_*`

Scene 喺 `register_camera()` 之後直接寫 `camera2d_ref.limit_left = -1024`, `limit_right = 4096`, etc.。Camera autoload 唔提供 `set_world_bounds()` API — world geometry 係 scene-level concern，autoload 唔擁有。CI Rule 13 嘅 banned list **唔包括** `limit_*` properties (intentional carve-out — limit_* 屬於 scene/world setup，唔屬於 camera behaviour mutation)。

Rationale: Architectural — world bounds = scene 知道，camera autoload 唔需要知道。Scene 直接配置 keeps autoload API surface minimal。Camera autoload 響應「跟邊個」+「點 frame ritual」，scene 響應「world 點大」。

#### Rule 11 — Default zoom constant

```gdscript
const DEFAULT_ZOOM: Vector2 = Vector2(1.0, 1.0)
```

Single source of truth for: Booting initial zoom + Suspended-restore zoom + Focal-exit return zoom。Tuning knob (Section G)，但所有 internal restore path 都 reference 呢個 const，唔 hardcode。

#### Rule 12 — Tween `process_mode = PAUSABLE` (DNF freeze consistency with #6)

所有 Focal tween (entry + exit + cleanup) 用 `Tween.TWEEN_PROCESS_PAUSABLE`，即 `get_tree().paused = true` (#6 hit_pause) 期間 Focal tween 自動 freeze。Camera autoload 自己 process_mode = `PROCESS_MODE_PAUSABLE` (default — 唔 override)。

Rationale: DNF feel consistency — 敵人凍住 mid-air 嗰 60ms 期間，Camera Focal tween 都應該凍住 (avoid「enemy 凍住但 camera 仍 zoom」嘅 perceptual disconnect)。Mirror #6 Rule 10 PROCESS_MODE_ALWAYS 嘅相反 — Camera 屬於 gameplay-visual layer，唔屬於 always-tick infrastructure (state machine / persistence / particles)。

唯一例外：autoload 自己嘅 GSM signal handler (`_on_gsm_state_changed`) 必須 fire — 由 signal mechanism (not _process) 觸發，paused 唔影響 signal delivery。

#### Rule 13 — CI enforcement: closed API surface (`tools/ci/check_camera_callers.gd`)

仿照 #6 `check_screen_effects_callers.gd` pattern。GDScript script run via `godot --headless --script`:

```gdscript
# Pseudo-code
const VIOLATIONS = [
    r"Camera2D\.[^.]*\.position\s*=",
    r"Camera2D\.[^.]*\.zoom\s*=",
    r"\.make_current\s*\(",
    r"get_viewport\(\)\.get_camera_2d\(\)",
]
const WHITELIST_PATHS = [
    "src/autoload/camera_controller.gd",
    "tests/",
    "tools/debug/",
]
# Note: Camera2D.limit_* intentionally NOT in VIOLATIONS — scene-direct per Rule 10
# Note: Camera2D.offset intentionally NOT here — owned by #6 ScreenEffects check (separate CI script)
# Walk all .gd files outside whitelist, regex match each VIOLATION → exit(1)
```

Additional CI check: 驗證 `_DEFAULT_ZOOM` / `_active_tween` 等 internal state 唔被外部 reference (private convention)。

Build fail = blocking。

#### Rule 14 — Persistence ban

Camera autoload 唔可以 read / write PersistenceLayer。Camera state (`_follow_target`, `_cached_target_path`, zoom, position) 完全 derived from (current scene + GSM state + register_camera/set_follow_target calls)。Hard reload (WASM reinit) → autoload 重 boot → Booting state → 等 scene re-register → 默認 follow target = scene spawn anchor。

Rationale: 同 #5 ParticleSystemWrapper Rule 16 + #6 ScreenEffects Rule 16 一致 — wrapper 只係 effect runtime，唔係 state owner。Scene bootstrap 永遠 reset 到 known-good default，no save/load coupling required。Test enforcement: `tests/unit/camera/no_persistence_test.gd` 驗證 Camera 唔 reference `PersistenceLayer` autoload。

## Formulas

呢個 section 鎖低所有 Camera follow / focal interpolation 嘅 mathematical specification。所有 example 跟 60fps (delta = 1/60 ≈ 0.0167s) 計算。3 mandatory formulas + 2 helpers covering Section C Rules 2, 6, 7。所有 invariants binding to Section H Acceptance Criteria。

### Formula 1 (Mandatory) — `follow_position_after_smoothing` (Godot Camera2D built-in formalization)

The `follow_position_after_smoothing` formula is defined as:

`pos_new = pos_old + (target - pos_old) × (1 - exp(-POSITION_SMOOTHING_SPEED × delta))`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| pos_old | p₀ | Vector2 (px) | unbounded | Camera position at previous frame |
| target | T | Vector2 (px) | unbounded | Follow target world position (avatar + dead-zone clamped — see Helper 2) |
| POSITION_SMOOTHING_SPEED | k | float (const) | 5.0 (Section G) | Critically-damped exponential decay rate |
| delta | Δt | float (s) | (0, MAX_FRAME_DELTA = 0.1] | Frame delta, clamped to prevent spiral-of-death |
| pos_new | p₁ | Vector2 (px) | asymptotically bounded to target | Output position next frame |

**Output Range:** Asymptotically converges to `target`; with dead-zone (Rule 3), settles into 8% × 12% viewport box around target。Frame-rate-independent post-Godot-4.4 (exponential decay holds regardless of fps)。

**Settle math (Pillar 2 derivation)**:
- Residual fraction at time t: `r(t) = exp(-k × t)`
- t to 63% closure (one time constant): `1/5.0 = 200ms`
- t to 95% closure: `3/5.0 = 600ms`
- **t to 3px tolerance from 30px offset (realistic glance-back delta)**: `ln(30/3) / 5.0 = ln(10) / 5.0 = 461ms` ✓ **within Pillar 2 < 500ms hard metric**

**Example — Glance-back from 30px offset @ 60fps:**

| Frame | time (ms) | residual offset (px) |
|-------|-----------|----------------------|
| 0 | 0.0 | 30.0 |
| 12 | 200 | 11.04 (63% closure) |
| 27 | 450 | 3.16 (95.4% closure) |
| 28 | 467 | **3.00 ✓ Pillar 2 metric satisfied** |
| 36 | 600 | 1.49 (95% closure approach) |

**Pillar 2 lock-on metric**: settle-to-within-3px ≤ 500ms (3px tolerance choice rationale: 16px sprite base × 3 zoom = 48px effective screen size → 3px = 6.25% displacement, sub-pixel-perceptible threshold for peripheral vision)。

### Formula 2 (Mandatory) — `quart_ease_out_value` (Focal entry interpolation)

The `quart_ease_out_value` formula is defined as:

`value(t) = start + (end - start) × (1 - pow(1 - t, 4))`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| t | t | float | [0.0, 1.0] | Normalized tween time = `elapsed / FOCAL_ENTRY_DURATION` |
| start | s | Vector2 / float | unbounded | Value at t=0 (e.g., pre-focal position or DEFAULT_ZOOM 1.0) |
| end | e | Vector2 / float | unbounded | Value at t=1 (e.g., focal target position or zoom 1.4) |
| FOCAL_ENTRY_DURATION | T_in | float (const) | 0.6s (Section G) | Total tween duration |
| value(t) | v | Vector2 / float | linearly bounded [start, end] | Interpolated output |

**Output Range:** Monotonic increasing from `start` to `end`; bounded by both endpoints; never overshoots。

**Front-load property (Section B Falsifiable Test #5 binding)**: At t = 0.3, `1 - 0.7⁴ = 1 - 0.2401 = 0.7599` → **covers 76% of distance in 30% of time** → camera "lunges" first, then settles → 玩家 perceive "invitation" (camera 主動帶你睇)。

**Why quart over cubic**:
- Cubic ease-out at t=0.3: `1 - 0.7³ = 0.657` → only 65.7% in 30% time → weaker lunge perception
- Quart at t=0.3: 76% → matches DNF Otherverse portal push-in snappiness reference
- Cubic feels「subtle invitation」(soft pull)；quart feels「decisive invitation」(showrunner conviction) — better matches Section B "Silent Showrunner" framing

**Example — Zoom 1.0 → 1.4 over 0.6s:**

| t | elapsed (ms) | (1-t)⁴ | eased weight | zoom value |
|---|--------------|--------|-------------|------------|
| 0.0 | 0 | 1.000 | 0.000 | 1.000 |
| 0.1 | 60 | 0.656 | 0.344 | 1.138 |
| 0.2 | 120 | 0.410 | 0.590 | 1.236 |
| **0.3** | **180** | **0.240** | **0.760** | **1.304** ← 76% of [1.0→1.4] distance |
| 0.5 | 300 | 0.063 | 0.937 | 1.375 |
| 1.0 | 600 | 0.000 | 1.000 | 1.400 |

### Formula 3 (Mandatory) — `cubic_ease_in_out_value` (Focal exit interpolation)

The `cubic_ease_in_out_value` formula is defined as:

```
value(t) = start + (end - start) × f(t)
where f(t) = 4 × t³                       if t < 0.5
           = 1 - pow(-2 × t + 2, 3) / 2   if t ≥ 0.5
```

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| t | t | float | [0.0, 1.0] | Normalized tween time = `elapsed / FOCAL_EXIT_DURATION` |
| start | s | Vector2 / float | unbounded | Focal-state value (zoom 1.4 / focal position) |
| end | e | Vector2 / float | unbounded | Resume-state value (DEFAULT_ZOOM / follow target position) |
| FOCAL_EXIT_DURATION | T_out | float (const) | 0.5s (Section G) | Total exit tween duration |
| f(t) | f | float | [0.0, 1.0] | S-curve weight |

**Output Range:** Symmetric around t=0.5 (f(0.5) = 0.5 exactly); monotonic increasing；never overshoots。

**Symmetric property (Section H AC-D3 binding)**: `f(t) + f(1-t) = 1` 對任何 t ∈ [0, 1] hold。Mid-point f(0.5) = 0.5 exact (assert ±1e-6 tolerance)。

**Why cubic ease-in-out over quart**: 0.3s vs 0.5s ease-in-out cubic gives "breath out" feel (Hades post-encounter pacing) — symmetric acceleration into / deceleration out of mid-point。Quart ease-in-out 嘅 S-curve 太陡，感受 jarring (mid-point velocity 太快)。Entry quart (decisive) + exit cubic (breath out) 嘅 asymmetric curve choice 對應 "invitation in, settle out" 嘅 cinematographic narrative。

**Example — Zoom 1.4 → 1.0 over 0.5s:**

| t | elapsed (ms) | f(t) | zoom value |
|---|--------------|------|------------|
| 0.0 | 0 | 0.000 | 1.400 |
| 0.25 | 125 | 0.0625 | 1.375 |
| **0.5** | **250** | **0.500** | **1.200** ← exact midpoint |
| 0.75 | 375 | 0.9375 | 1.025 |
| 1.0 | 500 | 1.000 | 1.000 |

### Formula 4 (Helper) — `glance_lock_on_time` (Pillar 2 numerical proof)

Pure helper for AC-D1 numerical validation — derives settle time from initial offset under Formula 1。

The `glance_lock_on_time` formula is defined as:

`t_lock = ln(d_initial / d_tolerance) / POSITION_SMOOTHING_SPEED`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| d_initial | d₀ | float (px) | (0, viewport_width / 2] | Initial camera-to-target distance (worst-case glance scenario) |
| d_tolerance | d_tol | float (px) | 3.0 (Section G `LOCK_ON_TOLERANCE_PX`) | Distance below which camera "locked on" |
| POSITION_SMOOTHING_SPEED | k | float (const) | 5.0 (Section G) | From Formula 1 |
| t_lock | t_lock | float (s) | (0, ∞) | Time required to settle within tolerance |

**Output Range:** Unbounded above (large d_initial → long settle), but Pillar 2 hard contract requires `t_lock ≤ 0.5s` for `d_initial ≤ 30px` (realistic mid-set glance delta band)。

**Worked example** — Pillar 2 metric validation:
- d_initial = 30px, d_tol = 3.0, k = 5.0
- t_lock = ln(30/3) / 5.0 = ln(10) / 5.0 = 2.303 / 5.0 = **461ms ✓**

Section H AC-D1 binding: assert `glance_lock_on_time(30.0, 3.0, 5.0) < 500.0`。

### Formula 5 (Helper) — `dead_zone_box_world_extents` (debug overlay + AC-D4 test)

Derives dead-zone box dimensions in world coordinates from Rule 3 drag margins + viewport size + current zoom。

The `dead_zone_box_world_extents` formula is defined as:

`extents_world = Vector2(viewport.x × (margin_left + margin_right), viewport.y × (margin_top + margin_bottom)) / zoom`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| viewport | V | Vector2 (screen px) | engine-set | Camera viewport size from `get_viewport_rect().size` |
| margin_left | m_l | float | 0.04 (Section G) | Rule 3 drag_left_margin |
| margin_right | m_r | float | 0.04 (Section G) | Rule 3 drag_right_margin |
| margin_top | m_t | float | 0.06 (Section G) | Rule 3 drag_top_margin |
| margin_bottom | m_b | float | 0.06 (Section G) | Rule 3 drag_bottom_margin |
| zoom | z | Vector2 | [0.5, 3.0] | Current Camera2D.zoom |
| extents_world | E_w | Vector2 (world units) | bounded by viewport / min_zoom | Dead-zone box dimensions in world coords |

**Output Range:** Bounded by viewport size / zoom；Pillar 2 invariant: 大 viewport 或低 zoom → dead-zone box 較大 (proportional)。

**Worked example** — Desktop 1920×1080 viewport, zoom 1.0:
- extents_world.x = 1920 × (0.04 + 0.04) / 1.0 = 153.6 world units
- extents_world.y = 1080 × (0.06 + 0.06) / 1.0 = 129.6 world units
- Dead-zone box ≈ 154 × 130 world units centred on Camera2D position

Section H AC-D4 binding: assert avatar 喺 dead-zone box 邊緣 + target 喺 box 對邊 → camera_position 不變 (no oscillation)。

### Math Invariants → Section H AC promotion candidates

以下 4 條 invariants 將 promote 入 Section H Acceptance Criteria (Section H drafting 時 qa-lead 會 expand):

- **AC-D1 (Pillar 2 lock-on time)**: `glance_lock_on_time(30.0, 3.0, 5.0) < 500ms` — Pillar 2 hard contract numerical proof
- **AC-D2 (Quart ease-out front-load)**: `quart_ease_out_value(0.3, 0, 100) ≥ 75.0` — Section B Falsifiable Test #5 binding (76% in 30% time)
- **AC-D3 (Cubic ease-in-out symmetry)**: `abs(cubic_ease_in_out_value(0.5, 0, 1) - 0.5) ≤ 1e-6` — exit tween symmetric breath-out invariant
- **AC-D4 (Dead-zone stability)**: Avatar 喺 dead-zone box edge + target opposite edge → camera_position delta == 0 (no oscillation per Helper 2)

### Section G knob preview (formal Section G drafting 時 expand)

呢個 Section D introduces 6 個 tuning knobs (全部 deferred to Section G):

| Knob | Default | Safe Range | Source |
|------|---------|-----------|--------|
| `POSITION_SMOOTHING_SPEED` | 5.0 | [3.0, 8.0] | Formula 1, critically-damped sweet spot |
| `LOCK_ON_TOLERANCE_PX` | 3.0 | [1.0, 8.0] | Formula 4, Pillar 2 sub-pixel-perceptible threshold |
| `FOCAL_ENTRY_DURATION` | 0.6s | [0.4, 1.0] | Formula 2, DNF cinematic push-in band |
| `FOCAL_EXIT_DURATION` | 0.5s | [0.3, 0.8] | Formula 3, Hades breath-out pacing |
| `FOCAL_ZOOM_DEFAULT` | 1.4x | [1.2, 1.5] | Rule 6, motion safety cap |
| `MAX_FRAME_DELTA` | 0.1s | [0.05, 0.2] | Formula 1, bfcache resume clamp (mirror #6 同名 knob) |

Drag margins (`DRAG_HORIZONTAL_MARGIN = 0.04` × 2 + `DRAG_VERTICAL_MARGIN = 0.06` × 2 = 8% × 12% asymmetric per Rule 3) 同 `DEFAULT_ZOOM = Vector2(1.0, 1.0)` per Rule 11 — 額外 3 knobs，總共 Section G 涵蓋 9 knobs。

## Edge Cases

呢個 section 列出 24 個 explicitly-handled edge cases，按 7 個 categories 排列。每個 case 標明 condition + exact resolution + rationale。所有 cases 跨 Section B (Falsifiable Tests) / Section C (Rules) / Section D (Formulas) 已 verified — 唔重複 already-locked invariants，只 cover boundary scenarios。

### Input validation (EC-01 ~ EC-05)

- **EC-01 — If `set_follow_target(null)` called**: accept, state stays `Following`, `_follow_target` cleared, camera 凍結 at last position; emit `camera_target_lost()` signal。*Rationale*: avatar despawn / scene transition 係 valid lifecycle event；freeze 比 snap-to-origin safer (Pillar 2 — no surprise camera motion)；gameplay code 可訂閱 signal 主動 re-register。Single signal unified across (a) bfcache stale path (Rule 9), (b) explicit null set (本 EC), (c) queue_free mid-frame (EC-16) — caller distinguishes context via current `_state`。
- **EC-02 — If `request_focal(target_position, ...)` 接收 NaN / ±INF 喺 target_position / duration / zoom_level**: `is_finite()` check fail → reject + `push_error("Camera.request_focal: NaN/INF rejected from <caller stack>")`, `_rejected_calls += 1`, no state change。*Rationale*: NaN target propagates 入 Formula 2 quart ease-out → 永久 broken camera matrix；fail-loud 令 upstream bug 早期 surface (mirror #6 EC-01 pattern)。
- **EC-03 — If `request_focal(duration < 0)` or `duration > MAX_FOCAL_DURATION = 10.0s`**: clamp to `[0.1, 10.0]` + `push_warning("Camera.request_focal: duration %.2f clamped" % duration)`。*Rationale*: 10s ceiling 防 designer typo lock 玩家 indefinitely；0.1s floor 確保 tween 有 valid duration (低於會引致 frame-1 instant snap，唔成 "cinematic")。
- **EC-04 — If `request_focal(zoom_level <= 0)`**: reject + `push_error`，no state change。*Rationale*: Godot Camera2D zoom=0 → division by zero in projection matrix；負 zoom inverts viewport。Fail-loud。
- **EC-05 — If `request_focal(zoom_level > FOCAL_ZOOM_CAP = 4.0)`**: clamp to `FOCAL_ZOOM_CAP` + `push_warning`。*Rationale*: 4.0x 極端 zoom 露 world-bound edge + 大 vestibular risk；clamp 防 designer 意外配置。Section G knob `FOCAL_ZOOM_CAP = 4.0` (Camera autoload-owned hard ceiling)。

### State machine boundary (EC-06 ~ EC-10)

- **EC-06 — If `request_focal()` while `_state == Booting`** (no register_camera yet): silent reject (no warning — boot order race expected at app startup)，`_rejected_calls` 唔 increment。*Rationale*: 無 Camera2D handle 無嘢可以 tween；queue 引入 unbounded backlog 風險。Subscribe scene's `register_camera()` 確保 first Camera2D 注入後 Booting → Following。
- **EC-07 — If GSM transitions OUT of {BOSS_ENCOUNTER, LOOT_DROP} mid-Focal** (e.g. emergency state change while in BOSS_ENCOUNTER Focal — say BOSS→IDLE force-clear scenario): force `clear_focal()` immediately + skip exit tween (snap return to Following defaults)。*Rationale*: Rule 4 gating 要 hard — cinematic during gameplay menu = bug；snap return acceptable 因為 GSM state change 本身就係 dramatic event。
- **EC-08 — If `request_focal()` 期間 active exit tween 仲 progressing** (Focal callback done，breath-out tween ongoing): reject (depth=0 strict per Rule 5)。*Rationale*: 對齊 Rule 5 + #6 ScreenEffects Rule 12 一致 strict reject stance；caller chain via `focal_completed` signal (signal fire 已喺 exit tween 開始之前)。
- **EC-09 — If `state_changed → SUSPENDED` fired during Focal entry tween** (e.g. browser tab loses focus 200ms into 600ms entry tween): `_active_tween.kill()` 同 frame，snap Camera2D 到 current interpolated position，transition Suspended (Rule 8)。*Rationale*: Rule 8 cancel-all sequence；Suspended 優先過 cinematic；snap-mid-tween 較 fade-out 更 honest (玩家 next bfcache resume 唔會見 phantom partial-zoom frame)。
- **EC-10 — If Focal `duration` might expire while `_state == Suspended`**: Rule 8 SUSPENDED entry already kills `_active_tween` + resets zoom + re-enables smoothing (complete cleanup)。**No deferred callback, no `_focal_exit_pending` flag** — once Rule 8 runs, Focal is fully cancelled。Resume (Rule 9) transitions to Following, not Focal-completion。**Removed `_focal_exit_pending` pattern (Pass 3 patch)**: was specced defensively assuming `TWEEN_PROCESS_PAUSABLE` auto-freezes on Web Export page-hide — that assumption is incorrect。`TWEEN_PROCESS_PAUSABLE` tracks `SceneTree.paused`, NOT browser `visibilitychange` / bfcache events。Browser backgrounding does NOT auto-set `get_tree().paused` in Web Export (see Rule 8 Web Export note)。Rule 8 GSM-signal-driven kill-all is the single authority — deferred flag contradicts Rule 8 and is not needed。*Rationale*: Simpler state model consistent with Rule 8 cancel-all precedent；Web Export correctness requires explicit GSM SUSPENDED signal path, not Tween system assumptions。

### bfcache / Web Export (EC-11 ~ EC-14)

- **EC-11 — If bfcache resume restores stale `_cached_target_path` to freed node**: Rule 9 handler detects via `get_node_or_null()` returning null → fall back to `BOOTING` state + emit `camera_target_lost`，scene root subscribe 而 re-register。*Rationale*: Section B Falsifiable Test #4 binding；freed instance 唔可以 silently 跟 (NPE in next `_process`)；scene 主動 re-wire 保 Persistence ban (Rule 14)。
- **EC-12 — If WASM reinit between page show/hide loses autoload state**: Hard reload path → Camera autoload `_ready()` fresh → Booting → scene 再 register。**不 persist** to `user://state.json` per Rule 14 absolute persistence ban。*Rationale*: 寧願閃黑 1 frame (Camera2D `Vector2.ZERO` default position) 也唔 introduce PersistenceLayer coupling。Scene bootstrap 永遠 reset 到 known-good default。
- **EC-13 — If window focus loss mid-Focal entry**: Tween `PROCESS_MODE_PAUSABLE` 自動 pause；focus regain → tween resume 由原 interpolated point 繼續。*Rationale*: 同 #6 hit_pause semantics align — focus loss = world freezes, includes camera。Tween-internal `paused` state by Godot Tween system 處理。
- **EC-14 — If viewport resize mid-Focal** (devtools open / mobile orientation change): recenter against new viewport size 下一 frame，**不** re-tween。Camera2D position 維持 world-coordinate target (recompute screen position from world coords automatically by Camera2D)。*Rationale*: 避免 visible jolt；final position 已 world-coord locked，viewport size change 只影響 projection。Dead-zone box size auto-recompute via Helper 2 (Formula 5)。

### Cross-system race / dependency (EC-15 ~ EC-18)

- **EC-15 — If `request_focal()` before GSM autoload `_ready()` complete** (race despite ADR-006 Contract 4 sequential _ready): reject + `push_warning("Camera.request_focal before GSM ready")`。*Rationale*: Rule 4 需要 read `GSM.current_state` — GSM 未 ready = unsafe gate；可能引致 wrong state decision。ADR-006 Contract 4 sequential boot (PersistenceLayer pos 1 → GSM pos 2 → ... → Camera pos N+) 確保 Camera autoload `_ready()` 之前 GSM 已 ready，但 hot-reload / editor scenarios 唔保證。
- **EC-16 — If `_follow_target.queue_free()` during smoothing** (avatar dies mid-frame): next `_process` 入口 detect via `is_instance_valid(_follow_target)` → false → freeze camera at last position + emit `camera_target_lost()` signal + 清空 `_follow_target = null`。Gameplay code (e.g. respawn handler) 接住 signal 然後 `set_follow_target(new_avatar)`。*Rationale*: avatar lifecycle 由 gameplay code own，Camera 唔知 respawn timing；signal hand-off 保持 decoupled。Signal name unified per Rule 1 (was `follow_target_lost` pre-revision — see /design-review 2026-05-26)。
- **EC-17 — If scene change while Focal active**: GSM 喺 transition `* → SUSPENDED` 或 scene change pre-hook 觸發 `_force_clear_focal_sync()` (synchronous cleanup) → kill all tweens，reset zoom，clear `_camera` reference (since old Camera2D node 將 freed)。新 scene `_ready()` → `register_camera(new_camera2d)` → Booting → Following。*Rationale*: 防 dangling tween 引 freed Camera2D NPE；synchronous cleanup 必須喺 scene tear-down 之前完成。
- **EC-18 — If hot-reload triggers `register_camera()` with new Camera2D instance** (dev workflow): replace `_camera` handle，kill active tween (if any)，transition Booting → Following with cached `_follow_target` (if still valid)。*Rationale*: dev workflow 唔好 crash；新 Camera2D 即時可用。

### Camera2D node lifecycle (EC-19 ~ EC-20)

- **EC-19 — If `register_camera(null)` or freed Camera2D instance**: reject + `push_error("Camera.register_camera: invalid Camera2D instance")`，state 維持 Booting。*Rationale*: 早 fail 易 debug；scene 必須提供 valid Camera2D。
- **EC-20 — If `register_camera()` called twice in one scene** (dual Camera2D bug): reject second call + `push_error("Camera.register_camera: already registered; first NodePath=%s, second=%s" % [old_path, new_path])`。Scene must explicit `unregister_camera()` (single-Camera2D model)。*Rationale*: 單 Camera2D autoload model — silent overwrite = lost reference bug + dangling tween on first Camera2D。

### Numerical / formula boundary (EC-21 ~ EC-23)

- **EC-21 — If `delta == 0` (single-step debug / editor pause)**: Formula 1 `pos_new = pos_old + (target - pos_old) × (1 - exp(0)) = pos_old + 0 = pos_old`，no NaN，position 不變。*Rationale*: Mathematical identity — `1 - exp(0) = 0` → no movement at delta=0 (GUT debugger single-step expected behavior，唔需要 special handling)。
- **EC-22 — If world bounds (`Camera2D.limit_*`) not set by scene** (limit_left/right/top/bottom 仍係 Godot default INT_MIN/INT_MAX): `push_warning("Camera: world bounds not set on register_camera — unbounded follow allowed")` 一次 per scene。Camera 仍 follow normally (no enforcement)。*Rationale*: 唔係所有 scenes 都 has bounds (e.g. menu / cutscene) — warn 提示 designer 但唔 block；Rule 10 scene-direct policy 留 scene 控制。
- **EC-23 — If Focal `target_position` outside `Camera2D.limit_*` clamp range**: tween completes normally — Camera2D 自動 clamp final position to within limits，zoom tween 仍 apply。Emit `focal_target_clamped(requested: Vector2, clamped: Vector2)` NEW signal 畀 VFX / dialogue system 補償 (e.g. 顯示 indicator arrow 指向 off-screen boss)。*Rationale*: 玩家會 perceive 「zoom-only-not-recenter」 — 要 detectable signal；clamping 比 reject 較 graceful (Pillar 2 — Camera 唔 surprise reject ritual moment)。Section H **AC-E1** new candidate: `focal_target_clamped` emit 喺 target 超 bound case + exit handler restore follow normal。

### CI / contract violation runtime (EC-24)

- **EC-24 — If `Camera2D.offset != Vector2.ZERO` detected at frame end** (debug build only, runtime catch supplementing Rule 13 CI static check): `if OS.is_debug_build(): if _camera.offset != Vector2.ZERO: push_error("Camera.offset must be zero — owned by #6 ScreenEffects shader uniform")` + counter increment。**Exact equality intentional** (唔用 `is_equal_approx`) — any mutation = contract violation, sub-epsilon writes (e.g. `offset = Vector2(0.0001, 0)`) still count。**Not `assert()`** (crashes GUT test runner in debug mode — replaced per AC-29 Pass 3 patch)。*Rationale*: Rule 13 CI 係 static check (catches direct property writes)；runtime guard catch dynamic violations (e.g. animation player modifying offset)。#6 ScreenEffects shake 走 shader uniform path 唔寫 Camera2D.offset — invariant 跨兩 system enforce。

### Cross-reference verification

- **Section B Falsifiable Tests coverage**:
  - Test #1 (mid-rep Focal trigger) — covered by Rule 4 gating (NOT edge case — invariant)
  - Test #2 (Follow overshoot / oscillate) — covered by EC-21 delta=0 + AC-D1 numerical proof (Section D)
  - Test #3 (bfcache resume stuck Focal) — covered by EC-09 + EC-11 + EC-12 + EC-13
  - Test #4 (Camera2D.offset mutation外部) — covered by EC-24 runtime guard + Rule 13 CI static
  - Test #5 (ease-in vs ease-out wrong) — covered by Section D Formula 2 (NOT edge case — formula spec)
  - Test #6 (mid-WorkoutActive Focal) — covered by Rule 4 gating (NOT edge case — invariant)
- **Section D AC-D candidates coverage**:
  - AC-D1 (Pillar 2 lock-on time) — covered by EC-21 delta=0 + EC-14 viewport resize
  - AC-D2 (Quart ease-out front-load) — covered by EC-02 NaN + EC-09 Suspended mid-entry
  - AC-D3 (Cubic ease-in-out symmetry) — covered by EC-10 Focal expires during Suspended (defer pattern preserves symmetry)
  - AC-D4 (Dead-zone stability) — covered by EC-14 viewport resize (Helper 2 auto-recompute)
- **Sister #6 ScreenEffects edge cases — no duplicates**: 本 GDD edge cases 全部聚焦 Camera node lifecycle + register_camera + Focal tween state + world bounds clamp；#6 edge cases cover shake math + dispatch table + hit_pause selective freeze — 兩者解耦無 overlap。

## Dependencies

### Upstream Dependencies (本 system requires)

| # | System | Layer | Hard/Soft | Nature of dependency |
|---|--------|-------|-----------|----------------------|
| **#1** | GameStateMachine | Foundation / VS | **Soft (subscriber + read-only state query)** | Subscribe `state_changed(from: String, to: String, payload: StateTransitionPayload)` via `connect_for_initial_state(_on_gsm_state_changed)` helper (ADR-006 Contract 6) — initial state replay required because Camera autoload position > GSM position 2。Suspended state entry triggers Rule 8 cancel-all sequence (kill tween + reset zoom + cache target NodePath)。Rule 4 reads `GSM.current_state` synchronously to gate `request_focal()` to {BOSS_ENCOUNTER, LOOT_DROP} only。 |
| **Scene root** | (per-scene gameplay scene) | Variable | **Hard (Camera2D injection contract)** | Each gameplay scene 必須 `register_camera(camera2d_ref)` after scene `_ready()` 將 Camera2D node reference 交畀 Camera autoload；同時 set world bounds via `camera2d_ref.limit_*` (scene-direct per Rule 10)。Scene 亦負責 call `set_follow_target(avatar)` after avatar spawn。Scene tear-down 必須 call `Camera.unregister_camera()` (public API, per Rule 1 + EC-17) 避免 dangling tween reference freed Camera2D。 |

**ADRs referenced (upstream constraints)**:
- **ADR-006 State Machine Contract** (Contract 4: autoload sequential `_ready`; Contract 6: `connect_for_initial_state`; Contract 7: race guard) — ratified Proposed
- **ADR-001 Web Export Budget Caps** — pending, FR-1/FR-2/FR-3 (Section B Risk Register) gated on ADR-001 ratification (Camera CPU budget + Focal tween frame budget + Focal trigger gating CI enforcement)

### Downstream Dependents (systems that depend on 本 system)

**Per skill bidirectional consistency rule**: 以下 entries 必須喺對應 GDD 寫成時加入該 GDD 嘅 "depends on: #7 Camera System" 句段。

| # | System | Layer | Tier | Status | Nature of dependency |
|---|--------|-------|------|--------|----------------------|
| **#14** | EnemyDirector | Core / VS | **Pending GDD** | **Hard (direct caller for boss-spawn Focal)** | Call `Camera.request_focal(boss.global_position, 0.6, 1.4)` on boss spawn → cinematic push-in for Boss reveal moment。Subscribe `focal_completed(target_position)` signal optional (e.g. boss intro animation 等 Focal complete 先 start)。Per Rule 4 gating，#14 必須喺 GSM state == BOSS_ENCOUNTER 之後先 call request_focal — order: #14 calls trigger GSM transition `* → BOSS_ENCOUNTER` first → Camera Focal request 之後 fire。**Rep-phase timing contract (Pillar 2 — Section B 「mid-rep camera motion = showrunner professional failure」)**: #14 EnemyDirector MUST defer boss spawn / GSM BOSS_ENCOUNTER trigger until `WorkoutTracker.rep_phase ∈ {REST, ECCENTRIC_BOTTOM}` (confirmed rest between sets OR eccentric bottom — NOT during mid-rep concentric/peak phase)。Camera GDD 唔 enforce rep_phase gate directly (唔 own WorkoutTracker dep) — 呢個 contract 屬 #14 EnemyDirector GDD Section C implementation responsibility。See also Q-F4 (new) for WorkoutTracker.rep_phase enum source-of-truth。 |
| **#21** | Loot Drop Modal | Presentation / Pre-MVP | **Pending GDD** | **Hard (direct caller for loot reveal Focal)** | Call `Camera.request_focal(loot.global_position, 0.6, 1.4)` on LootDrop modal entry → cinematic push-in for loot reveal ritual moment。Subscribe `focal_completed(target_position)` signal to chain modal content reveal (modal UI appears after Focal complete)。Per Rule 4 gating，#21 必須喺 GSM state == LOOT_DROP 之後先 call request_focal。 |
| **#25** | Combat Visual Feedback | Presentation / MVP | **Pending GDD** | **Soft (read-only `focal_completed` + `camera_target_lost` signals)** | 訂閱 `focal_completed` 為咗 sync VFX (e.g. boss "你死定" speech bubble 喺 Focal complete 出現)；訂閱 `camera_target_lost` 為咗 avatar respawn case 處理 (e.g. respawn VFX placement)。**唔 call** Camera API direct — Pillar 2 mid-set frictionless contract 禁止 #25 觸發 Focal during WorkoutActive / CombatActive。 |
| **#26** | Avatar Renderer | Presentation / VS | **Pending GDD** | **Soft (scene bootstrap caller for `set_follow_target`)** | Scene `_ready()` 之後 instantiate avatar → call `Camera.set_follow_target(avatar)` 設 Following target。Avatar despawn / queue_free → Camera 自動 detect via `is_instance_valid()` (EC-16) + emit `camera_target_lost` — #26 subscribe 而 re-set 新 avatar instance (respawn case)。 |

**Provisional contract lock note**: 全部 4 個 downstream entries 喺其 GDD 未寫成前 unilaterally locked from Camera side。當 #14, #21, #25, #26 GDDs 寫成時 expect contract delta — submit ADR if downstream needs Camera API change。Wrapper API 係 source of truth per Section C closed primitive contract。

### Bidirectional Consistency Check (next-revision requirements)

呢度列出 cross-system GDD updates needed:

- **#1 GameStateMachine** (already lists #7 ✗ — needs add)：next revision **必須** add #7 to "Downstream Dependents — Soft dependents" table。Expected entry: "**#7 Camera System** subscribes via `connect_for_initial_state` (ADR-006 Contract 6)；Suspended state triggers Rule 8 cancel-all sequence (kill tween + reset zoom)。Rule 4 reads `current_state` synchronously to gate `request_focal()` to {BOSS_ENCOUNTER, LOOT_DROP}"。同 #5 + #6 一齊 batch 處理 #1 GSM revision (now needs 3 entries: #5, #6, #7)。
- **#6 ScreenEffects** (currently does NOT list #7)：考慮加入「Camera owns `Camera2D.offset` ban — CI Rule 15 inherited from #6 (#6 owns shake via shader uniform path)」note。或者保持現狀 — #6 嘅 CI Rule 15 已 enforce 跨 systems，Camera GDD Rule 13 + EC-24 已 mirror enforce。**不需要 reciprocal add**：#6 Rule 15 CI script (`check_screen_effects_callers.gd`) 唔 reference Camera-specific paths，呢個係 single-direction enforcement。
- **#14 EnemyDirector / #21 Loot Drop Modal / #25 Combat Visual Feedback / #26 Avatar Renderer** (all pending GDDs)：authoring 時 list Camera System as upstream dependency per nature spec above。

### Open Items (carry forward)

- **Q-F1 NEW**: #1 GSM next revision 要加 Camera #7 bidirectional entry — defer to next /design-review GSM session or `/consistency-check` pass
- **Q-F2 NEW**: VS-tier first scene scaffolding 要 cover scene tear-down → Camera `_force_clear_focal_sync()` hook 邊個觸發 (scene root vs GSM pre-transition hook) — defer to VS sprint planning
- **Q-F3 NEW**: Mobile-specific drag margin (12% × 16%) + smoothing speed (4.0) 調整 → ADR-001 input scope

## Tuning Knobs

呢個 section 列出所有 designer / programmer-facing tunable values，安全範圍同 extreme behavior。9 個 owned knobs (6 numeric + 3 layout/visual) + cross-knob invariants。

### Owned by Camera System (designer-facing — designers 可 tune without code change)

| Knob | Default | Safe Range | Source / Used By | Too high (above safe range) | Too low (below safe range) |
|------|---------|------------|------------------|----------------------------|---------------------------|
| `POSITION_SMOOTHING_SPEED` | 5.0 | [5.0, 8.0] **(revised — see cross-knob invariant #1)** | Formula 1 (follow_position_after_smoothing); Section C Rule 2 | > 8.0 → snappy / rubber-band feel (Maple jump-cam complaint); overshoot risk at higher speeds | < 5.0 → Pillar 2 lock-on > 500ms metric fail at LOCK_ON_TOLERANCE_PX default 3.0 (was [3.0, 8.0] pre-revision but k=3 + d_tol=3 yields ln(10)/3 = 768ms ✗); revised floor enforces default behaviour as worst-case |
| `LOCK_ON_TOLERANCE_PX` | 3.0 | [3.0, 8.0] **(revised — see cross-knob invariant #1)** | Formula 4 (glance_lock_on_time); Pillar 2 metric | > 8.0 → metric trivially satisfied (camera 仲喺 8px 偏差就「lock-on」)，Pillar 2 contract 失意義 | < 3.0 → at minimum SMOOTH=5.0, Pillar 2 t_lock > 500ms; revised floor (was 1.0) eliminates safe-range corner that violates Pillar 2 hard contract (see cross-knob invariant #1 below) |
| `FOCAL_ENTRY_DURATION` | 0.6s | [0.4, 1.0] | Formula 2 (quart_ease_out_value); Section C Rule 6 | > 1.0 → 玩家 attention drift mid-Focal，cinematic moment 拖延 (DNF reference 0.5-0.8s band exceeded) | < 0.4 → entry tween too snappy，「lunge」感受變「snap」(invitation 變 jump-cut) |
| `FOCAL_EXIT_DURATION` | 0.5s | [0.3, 0.8] | Formula 3 (cubic_ease_in_out_value); Section C Rule 7 | > 0.8 → exit tween 拖太耐，return-to-baseline 感受變「lingering」(Hades pacing exceeded) | < 0.3 → exit snap-back jarring，「breath-out」感受變「kick」 |
| `FOCAL_ZOOM_DEFAULT` | 1.4x | [1.2, 1.5] | Section C Rule 6 default param; Section D Formula 2 example | > 1.5 → 玩家 mid-set vestibular conflict risk (Pillar 2 motion safety cap violation) | < 1.2 → zoom 太微，cinematic push-in 感受不到 (Pillar 3 DNF rally feel 失效) |
| `FOCAL_ZOOM_CAP` | 4.0x | [2.0, 6.0] | EC-05 hard ceiling param validation | > 6.0 → extreme zoom 露 world-bound edge + 大 motion sickness risk；clamp 失意義 | < 2.0 → designer 配置稍大 ritual zoom 都 hit cap，限制 cinematic flexibility |
| `MAX_FRAME_DELTA` | 0.1s | [0.05, 0.2] | Formula 1 delta clamp; bfcache resume safety (mirror #6 同名 knob) | > 0.2 → bfcache 30s 後 single-frame catch-up 仍可能引致 smoothing overshoot | < 0.05 → 50ms lag spike 已 clamp，catch-up timer 累積 (cosmetic only — Camera 唔 process critical timer) |
| `MAX_FOCAL_DURATION` | 10.0s | [3.0, 30.0] | EC-03 ceiling clamp | > 30.0 → designer 配置 lockout 嚴重；caller bug 鎖玩家 30+ 秒 | < 3.0 → legitimate long Focal use case (e.g. boss death animation) 被 clamp |
| `DEFAULT_ZOOM` | Vector2(1.0, 1.0) | each axis [0.5, 2.0] | Section C Rule 11 single source of truth | Each axis > 2.0 → initial / Suspended-restore zoom 已 zoomed-in，違反 Following mode baseline | Each axis < 0.5 → 初始 wide-angle viewport 露 world edge / mobile fillrate cost |

### Layout knobs (Rule 3 — owned compile-time constants but designer-tunable)

| Knob | Default | Safe Range | Used By |
|------|---------|------------|---------|
| `DRAG_HORIZONTAL_MARGIN` | 0.04 (each side) | [0.0, 0.20] | Rule 3 dead-zone box width (8% total); too high → camera 追唔到 fast-moving avatar；too low → frequent horizontal correction (peripheral motion noise) |
| `DRAG_VERTICAL_MARGIN` | 0.06 (each side) | [0.0, 0.20] | Rule 3 dead-zone box height (12% total); side-scroller asymmetric default per Hades / DNF Mobile pattern |

### Read-only by Camera (owned elsewhere — referenced for context)

| Knob | Owner | Used By Camera For |
|------|-------|---------------------|
| `GameStateMachine.State` enum | #1 GSM | Rule 4 Focal gating (BOSS_ENCOUNTER / LOOT_DROP whitelist) |
| Scene's `Camera2D.limit_*` properties | per-scene (Rule 10 scene-direct) | EC-23 Focal target clamp behaviour |
| Viewport size (engine-set, JS bridge for Web Export) | Godot engine | Helper 2 dead_zone_box_world_extents recompute (EC-14 viewport resize) |

### Knobs explicitly NOT exposed (compile-time constants — designer 改要 GDD revision)

呢啲 values 鎖死喺 Section C，**唔可以 runtime tune** — 改要：(1) propose Section C Rule revision，(2) update Rule 13 CI script if needed，(3) re-run FR-1/FR-2/FR-3 Risk Register playtest：

| Constant | Value | Why locked compile-time |
|----------|-------|------------------------|
| Focal gating GSM states whitelist | {BOSS_ENCOUNTER, LOOT_DROP} only | Section B locked Pillar 2 mid-set frictionless contract；改 = anti-Pillar-2 violation |
| Re-entry guard depth | 0 (strict reject) | Rule 5 Section B Showrunner channel separation principle；改 = ritual moments stack unpredictably |
| Quart ease-out for entry tween | TRANS_QUART, EASE_OUT | Formula 2 derived from Section B "decisive invitation" framing；改 = cinematographic feel 改變 |
| Cubic ease-in-out for exit tween | TRANS_CUBIC, EASE_IN_OUT | Formula 3 derived from Hades "breath out" pacing；改 = exit feel 改變 |
| Persistence ban (Rule 14) | NO PersistenceLayer read/write | Architectural — Camera = derived state，scene 永遠 reset 到 known-good default |
| Tween process_mode | PAUSABLE | Rule 12 DNF hit_pause freeze consistency；改 = perceptual disconnect with #6 ScreenEffects |
| CI banned APIs (Rule 13) | Camera2D.position/zoom/make_current/get_viewport_camera | Closed API contract；改 = architectural posture 改變 |

### Tuning Knob Interaction Warnings (invariants — Section H AC binding)

以下 cross-knob invariants 必須喺所有 default + safe range boundary 上 hold；違反 = Section H AC fail：

1. **Pillar 2 lock-on time**: `ln(30 / LOCK_ON_TOLERANCE_PX) / POSITION_SMOOTHING_SPEED ≤ 0.5` — 確保 30px glance-back delta 喺 500ms 內 settle (Formula 4 derivation)
   - At default (LOCK_ON=3.0, SMOOTH=5.0): `ln(10)/5 = 461ms ✓`
   - At worst safe-range corner (LOCK_ON=3.0, SMOOTH=5.0 — post-/design-review-revision): `ln(10)/5 = 461ms ✓` — **invariant now holds across entire safe range** (was failing pre-revision at LOCK_ON=1.0/SMOOTH=3.0 corner — see /design-review 2026-05-26)
   - **Derivation for future knob revision**: `SMOOTH_min ≥ 2 × ln(30/LOCK_ON_min)`. To lower LOCK_ON_TOLERANCE_PX floor below 3.0, MUST simultaneously raise POSITION_SMOOTHING_SPEED floor: e.g. LOCK_ON_min=2.0 → SMOOTH_min ≥ 5.42; LOCK_ON_min=1.0 → SMOOTH_min ≥ 6.81。Joint constraint binds — single-knob change invalidates Pillar 2 contract
2. **`FOCAL_ENTRY_DURATION > FOCAL_EXIT_DURATION`**: entry 嘅 "decisive invitation" 應該長過 exit 嘅 "breath out"，cinematographic narrative invariant
   - At default: 0.6 > 0.5 ✓
3. **`FOCAL_ZOOM_DEFAULT ≤ FOCAL_ZOOM_CAP`**: default 必須 below hard ceiling
   - At default: 1.4 < 4.0 ✓
4. **`DRAG_VERTICAL_MARGIN ≥ DRAG_HORIZONTAL_MARGIN`**: side-scroller asymmetric pattern preservation
   - At default: 0.06 > 0.04 ✓
5. **`MAX_FRAME_DELTA ≥ 2 × (1/60)`**: bfcache delta clamp 至少 ≥ 2 frames @ 60fps，否則 catch-up 失效 (mirror #6 invariant)
   - At default: 0.1 ≥ 0.0333 ✓

### Section H AC promotion candidates (from invariants above)

- **AC-G1**: Pillar 2 lock-on invariant holds at ALL 4 post-revision safe-range corners: (k=5.0, d_tol=3.0) → 461ms ✓; (k=5.0, d_tol=8.0) → 200ms ✓; (k=8.0, d_tol=3.0) → 288ms ✓; (k=8.0, d_tol=8.0) → 166ms ✓。NEGATIVE test: just-below-floor (k=4.9, d_tol=2.9 — outside revised safe range) → 527ms ✗ (documents why floor was raised from old [3.0,8.0]/[1.0,8.0] pre-/design-review revision)
- **AC-G2**: `FOCAL_ENTRY_DURATION > FOCAL_EXIT_DURATION` holds across all safe range boundaries
- **AC-G3**: `FOCAL_ZOOM_DEFAULT ≤ FOCAL_ZOOM_CAP` holds (trivial but binding)

## Visual/Audio Requirements

**N/A — pure infrastructure。** Camera System 唔 own 任何 visual / audio output。所有 visual / audio expression 由 downstream consumers 處理：

- Focal mode 嘅 cinematic push-in feel 由 Camera2D position + zoom 動畫 deliver — 無需要 additional sprite / particle / shader
- Boss spawn / LootDrop ritual moment 嘅 visual emphasis 由 #5 ParticleSystemWrapper (particle burst) + #6 ScreenEffects (shake + hit pause) + #25 Combat Visual Feedback / #21 Loot Drop Modal 各自處理
- Audio cue for ritual moments 由 #4 AudioManager (pending GDD) 訂閱 `state_changed → BOSS_ENCOUNTER / LOOT_DROP` 而非 Camera signals

Camera autoload 嘅 implementation 內絕對唔可以 reference `AudioStreamPlayer`、`GPUParticles2D`、`Sprite2D`、`Tween` 喺 Camera2D 之外嘅 visual node。Camera 嘅唯一 "visual" output 係 Camera2D 嘅 position / zoom (rendered by Godot engine automatically)。

**Debug overlay (dev-only)**: 建議實作 `DebugCameraOverlay` Control node (gated by `OS.is_debug_build()`) display：current Camera2D position + zoom，current state (Booting / Following / Focal / Suspended)，current follow_target NodePath，dead-zone box visualization (per Formula 5 `dead_zone_box_world_extents`)，last Focal target + clamped position (EC-23 case)。**唔屬於 production UI**。

## UI Requirements

本 system **唔 own 任何 UI surface** — Camera autoload 係 backend Foundation service，唔 render menu / HUD / modal / overlay。但本 system **預留 1 個未來 player-facing UI requirement** — 全部 UI 由 #20 Gym-Mode HUD + #21 Loot Drop Modal + #22 Character Screen + #23 Inventory UI 各自處理。

### No UI surface owned (production)

- Focal mode 嘅 cinematic 感受純粹由 Camera transform 動畫 deliver，唔需要 overlay UI (e.g. 無 "ZOOM!" 字幕、無 letterbox bars)
- Follow mode 嘅 dead-zone box / smoothing path **唔顯示** 喺 production UI (player 應該 perceive 不到 Camera 嘅存在 — Section B "Silent Showrunner" framing)
- Avatar lost / target stale state (EC-16, EC-11) 唔顯示 player-facing error message — emit signals 等 scene / gameplay code 處理 (e.g. respawn handler 主動 set 新 target)
- "Reduce Camera Motion" accessibility toggle (Q-V1 below) 嘅 UI surface 由 #22 Character Screen GDD owner 處理 — Camera autoload 只 expose backend `set_motion_reduction(enabled: bool)` API (similar to #6 ScreenEffects motion_intensity slider pattern)

### Future surface: Camera Motion accessibility toggle (Q-V1 reservation)

預留 backend API contract for future #22 Character Screen accessibility settings panel：

| Element | Specification |
|---------|---------------|
| Owner | #22 Character Screen GDD (pending — accessibility settings panel) |
| Backend contract | `Camera.set_motion_reduction(enabled: bool)` setter call from SettingsManager autoload |
| Default value | false (full motion — Mirror Hero healthy adult gym context) |
| When enabled (`true`) | Focal mode disabled entirely — `request_focal()` silently no-op (does NOT push_warning, expected user opt-out)；Follow mode `position_smoothing_enabled = false` + **drag margins ALL set to 0.0 (dead-zone = 0%, camera hard-locked to avatar center)** — eliminates optical flow (continuous lerp) AND dead-zone edge-crossing discontinuity (stroboscopic jumps) completely。**`snap follow` pattern removed (Pass 3 accessibility fix)**: prior spec's "snap follow" (smoothing=false but non-zero dead-zone) creates stroboscopic discontinuity at dead-zone edge crossings — a photosensitive / vestibular-migraine trigger class distinct from optical flow；dead-zone 0% hard-lock (camera always exactly centred on avatar, no camera motion at all) is the correct vestibular-safe pattern per Apple HIG Reduce Motion principles。 |
| UI label | 「降低畫面動態」/ "Reduce Camera Motion" |
| UI hint | 「禁用 zoom 動畫 + camera 鎖定 avatar 中心，保留遊戲性 (Boss / Loot 仍然觸發 ritual 但只用 audio / particle channel)」 |

> **📌 UX Flag — Camera motion reduction toggle**: 呢個 system 預留 1 個未來 player-facing UI requirement (motion reduction accessibility toggle)。喺 Phase 4 (Pre-Production)，run `/ux-design` to create UX spec for **#22 Character Screen — Accessibility Settings Panel** 嘅 motion reduction toggle element **before** writing epics。Stories that reference呢個 toggle 應該 cite `design/ux/character-screen-accessibility.md`，**唔好** cite 本 GDD directly。本 GDD 只 own backend contract (setter API + default value + behaviour spec)，不 own visual chrome / placement / interaction design。同 #6 ScreenEffects motion_intensity slider UX Flag 並列 — 兩個 toggle 都屬於 motion accessibility cluster，#22 GDD owner 可以考慮 unified panel section。
>
> Note this in the systems index for #22 Character Screen system when added。

## Acceptance Criteria

呢個 section 列出 **35 個 acceptance criteria** binding to Sections C-G。Test type / gate level / source 全 enumerated。**Breakdown: 31 BLOCKING + 1 ADVISORY + 3 ADR-001 RATIFICATION-GATED**。

### Core API & Validation (Rules 1, 4-5, ECs 01-05)

- **AC-01**: GIVEN Camera autoload in Booting state, WHEN scene calls `register_camera(camera2d_ref)` with valid Camera2D + then `set_follow_target(avatar_node2d)`, THEN state transitions Booting → Following within 1 frame, `_follow_target` reference stored。Source: Rule 1, EC-19 | Type: Logic | Gate: BLOCKING | File: `tests/unit/camera/camera_api_test.gd`
- **AC-02**: GIVEN Following state, WHEN `request_focal(target, duration=NaN)` OR `request_focal(target_pos=Vector2(NaN, 0))` OR any param ±INF called, THEN `is_finite()` check fails → reject + `push_error` + `_rejected_calls += 1`，no state change (EC-02)。Source: Rule 4 input validation, EC-02 | Type: Logic | Gate: BLOCKING | File: `tests/unit/camera/camera_validation_test.gd`
- **AC-03**: GIVEN Following state, WHEN `request_focal(target, duration=15.0, zoom=5.0)` called, THEN duration clamped to MAX_FOCAL_DURATION=10.0 + zoom clamped to FOCAL_ZOOM_CAP=4.0 before tween begins，both clamps emit `push_warning`。Source: Rule 4, EC-03, EC-05 | Type: Logic | Gate: BLOCKING | File: `tests/unit/camera/camera_validation_test.gd`
- **AC-04**: GIVEN Booting state, WHEN scene calls `register_camera(null)` OR `register_camera(freed_camera2d)`, THEN reject + `push_error`，state remains Booting (EC-19)。Source: Rule 1, EC-19 | Type: Logic | Gate: BLOCKING | File: `tests/unit/camera/camera_register_test.gd`
- **AC-05**: GIVEN Camera autoload registered once, WHEN second `register_camera()` call fires, THEN reject + `push_error("already registered; first NodePath=%s, second=%s")`，first Camera2D reference 保持 (EC-20)。Source: Rule 1, EC-20 | Type: Logic | Gate: BLOCKING | File: `tests/unit/camera/camera_register_test.gd`
- **AC-06a [current scope — VS-tier]**: GIVEN Camera autoload (before #22 Character Screen GDD lands), WHEN introspect public methods via `get_method_list()` + signals via `get_signal_list()`, THEN exactly 5 public methods (`register_camera`, `unregister_camera`, `set_follow_target`, `request_focal`, `clear_focal`) + 3 signals (`focal_completed`, `camera_target_lost`, `focal_target_clamped`) — **`set_motion_reduction` MUST NOT be present** (no stub until #22 GDD ratified)，all other methods prefixed `_`。Source: Rule 1, EC-17/EC-20, EC-23 | Type: Integration | Gate: BLOCKING | File: `tests/integration/camera/camera_api_surface_test.gd`
- **AC-06b [post-#22 GDD scope]**: GIVEN Camera autoload after #22 Character Screen GDD authored + SettingsManager contract ratified, WHEN introspect public methods, THEN `set_motion_reduction(enabled: bool)` exists as 6th public method (extend AC-06a test)。Source: UI Requirements future contract | Gate: post-#22 GDD ratification | File: `tests/integration/camera/camera_api_surface_test.gd`

### Follow Math (Rules 2-3, Formula 1, ECs 21-22)

- **AC-07**: GIVEN Following with target stationary, target moves to (+200px, 0) at frame N, WHEN 6 frames elapsed @ 60fps via `Camera.update(1.0/60.0)` mock-delta injection (total elapsed t = 6/60 = 0.1s), THEN camera position at frame N+6 matches cumulative-form solution `pos(t) = target × (1 - exp(-k × t)) = 200 × (1 - exp(-5.0 × 0.1)) = 200 × 0.393 = 78.7px` within ±1px tolerance (Formula 1 frame-iterated; exponential decay aggregates over n frames as `1 - exp(-k × n × delta_per_frame)`)。**AC wording revised /design-review 2026-05-26 — was `exp(-5.0 × 0.1)` ambiguously suggesting single-frame delta = 0.1s; cumulative form clarifies n=6 frames each delta=1/60**。Source: Formula 1, Rule 2 | Type: Logic | Gate: BLOCKING | File: `tests/unit/camera/camera_follow_math_test.gd`
- **AC-08**: GIVEN Following with dead-zone box (default 8% × 12% = ~154 × 130 world units @ 1920×1080 viewport, zoom 1.0), target moves <77px from box centre horizontally (within H half-extent), THEN camera position delta == 0 (no movement，AC-D4 binding)。Source: Rule 3, Formula 5, EC-22 | Type: Logic | Gate: BLOCKING | File: `tests/unit/camera/camera_deadzone_test.gd`
- **AC-09 [AC-D1 + Falsifiable Test #2 binding, Pillar 2]**: GIVEN target snaps from camera position by 30px in single frame (realistic glance-back delta), POSITION_SMOOTHING_SPEED=5.0, LOCK_ON_TOLERANCE_PX=3.0, WHEN test driver calls `Camera.update(1.0/60.0)` in a loop (mock-delta injection — Camera autoload MUST expose `func update(delta: float) -> void` to enable deterministic frame-stepping outside real `_process()`), THEN `t_lock < 500ms` measured by accumulating injected delta until `abs(camera.position - target) < 3.0` (Formula 4 numerical proof: 461ms expected, ≤ 30 simulated frames @ 60fps)。**Architectural note (revised /design-review 2026-05-26)**: `update(delta)` dependency injection is BLOCKING — relying on real `_process` callback prevents GUT determinism。Internal `_process` simply calls `update(get_process_delta_time())`。Source: Formula 1+4, Falsifiable Test #2, AC-D1 | Type: Performance | Gate: BLOCKING | File: `tests/performance/camera/pillar2_lockon_test.gd`
- **AC-10 [AC-D4 binding, Falsifiable Test #2]**: GIVEN target jitters ±5px inside dead-zone box for 2s (120 frames @ 60fps), WHEN sampling camera position each frame, THEN camera position variance < 0.5 px² (proves no oscillation — dead-zone stability)。Source: Rule 3, EC-22 | Type: Logic | Gate: BLOCKING | File: `tests/unit/camera/camera_deadzone_test.gd`

### Focal Tween (Rules 6-7, Formulas 2-3, ECs 23)

- **AC-11 [AC-D2 + Falsifiable Test #5 binding, Pillar 3]**: GIVEN Focal entry tween duration=0.6s starting at t=0, WHEN sampled at t=0.18s (30% of duration), THEN tween value ≥ 76% of [start, end] distance (Formula 2 quart ease-out front-load — 「decisive invitation」property)。Source: Formula 2, Falsifiable Test #5, AC-D2 | Type: Logic | Gate: BLOCKING | File: `tests/unit/camera/focal_easing_test.gd`
- **AC-12 [AC-D3 binding]**: GIVEN Focal exit tween duration=0.5s, WHEN sampled at t=0.25s (50%), THEN tween value == 50% of [start, end] distance within ±1e-6 tolerance (Formula 3 cubic ease-in-out symmetric)。Source: Formula 3, AC-D3 | Type: Logic | Gate: BLOCKING | File: `tests/unit/camera/focal_easing_test.gd`
- **AC-13 [Rule 11 binding]**: GIVEN `request_focal(target_pos)` called without explicit duration/zoom params, THEN defaults applied: `duration = FOCAL_ENTRY_DURATION (0.6s)`, `zoom_level = FOCAL_ZOOM_DEFAULT (1.4x)`; Focal exit tween uses `FOCAL_EXIT_DURATION (0.5s)` + return to `DEFAULT_ZOOM (Vector2(1.0, 1.0))`。Source: Rule 6, Rule 7, Rule 11 | Type: Logic | Gate: BLOCKING | File: `tests/unit/camera/camera_focal_test.gd`
- **AC-14 [Rule 12 binding, DNF freeze consistency]**: GIVEN Focal entry tween running, WHEN `get_tree().paused = true` fires (mid-tween from #6 hit_pause), THEN tween 自動 freeze (process_mode = PAUSABLE)；when `paused = false`, tween resumes from same interpolated point without phase jump (`focal_completed` signal NOT premature emit)。Source: Rule 12, EC-13 | Type: Integration | Gate: BLOCKING | File: `tests/integration/camera/camera_pause_test.gd`
- **AC-15 [AC-G2 binding]**: GIVEN any knob configuration within safe ranges, WHEN read `FOCAL_ENTRY_DURATION` 同 `FOCAL_EXIT_DURATION`, THEN `entry > exit` invariant holds (cinematographic narrative: invitation longer than breath-out)。Source: Cross-knob G2 | Type: Logic | Gate: BLOCKING | File: `tests/unit/camera/camera_invariants_test.gd`

### State Machine (Rules 4-5, 8, ECs 06-10)

- **AC-16 [Rule 5 strict reject]**: GIVEN Focal state active, WHEN second `request_focal()` called, THEN reject + `push_warning("active Focal in progress")` + `_focal_reentry_dropped_count += 1`，current tween continues unaffected。Source: Rule 5, EC-08 | Type: Logic | Gate: BLOCKING | File: `tests/unit/camera/camera_state_test.gd`
- **AC-17 [Rule 8 + Falsifiable Test #3]**: GIVEN Focal entry tween mid-flight (300ms into 600ms tween), WHEN GSM emits `state_changed(SUSPENDED)`, THEN tween `kill()` immediately + Camera2D snaps to current interpolated position (NOT default — avoids visible reset jolt) + zoom resets to `DEFAULT_ZOOM` + `_cached_target_path` saved + state == Suspended within 1 frame。Source: Rule 8, EC-09, Falsifiable Test #3 | Type: Integration | Gate: BLOCKING | File: `tests/integration/camera/camera_suspend_test.gd`
- **AC-18 [Rule 9 bfcache restore]**: GIVEN Suspended state with valid `_cached_target_path`, WHEN GSM emits `state_changed(IDLE / WORKOUT_ACTIVE / etc.)`, THEN state → Following with cached target via `get_node_or_null(cached_path)` resolved；if NodePath stale (freed) → state → Booting + `camera_target_lost()` signal emit。Source: Rule 9, EC-11 | Type: Integration | Gate: BLOCKING | File: `tests/integration/camera/camera_resume_test.gd`
- **AC-19 [Rule 4 Focal gating, Falsifiable Test #1 + #6, Pillar 2 hard contract]**: GIVEN `_gsm.current_state == WORKOUT_ACTIVE` (or COMBAT_ACTIVE / IDLE / RestPeriod / etc., NOT in {BOSS_ENCOUNTER, LOOT_DROP}), WHEN `request_focal(target)` called by ANY caller, THEN reject + `push_warning("rejected: GSM state=%s (mid-set frictionless contract)")` + `_focal_gating_rejected_count += 1`，state remains Following。Source: Rule 4, Falsifiable Test #1, Falsifiable Test #6 | Type: Integration | Gate: BLOCKING | File: `tests/integration/camera/camera_focal_gating_test.gd`
- **AC-20 [EC-07]**: GIVEN Focal active喺 BOSS_ENCOUNTER, WHEN GSM transitions OUT (e.g. emergency → IDLE), THEN `_force_clear_focal_sync()` triggers immediately — tween killed + skip exit tween (snap return to Following defaults)，state == Following within 1 frame。Source: Rule 4, EC-07 | Type: Integration | Gate: BLOCKING | File: `tests/integration/camera/camera_focal_force_clear_test.gd`

### bfcache / Resume / Lifecycle (Rules 9, 14, ECs 11-14, 16)

- **AC-21 [Rule 14 persistence ban, EC-12]**: GIVEN Camera autoload entire lifecycle (Booting / Following / Focal / Suspended / resume), WHEN scanning all `_ready()` / `_on_gsm_state_changed()` / `_apply_focal()` / `_restore_from_suspend()` code paths, THEN ZERO calls to `PersistenceLayer.read()` / `PersistenceLayer.write()` / `FileAccess` (grep verify)。Hard reload (WASM reinit) → fresh Booting state with no persisted recovery。Source: Rule 14, EC-12 | Type: Static / Integration | Gate: BLOCKING | File: `tests/unit/camera/no_persistence_test.gd`
- **AC-22 [EC-16 camera_target_lost]**: GIVEN Following with valid `_follow_target`, WHEN `_follow_target.queue_free()` mid-frame, WHEN next `_process()` enters, THEN `is_instance_valid(_follow_target)` returns false → `_follow_target = null` + camera freezes at last position + `camera_target_lost()` signal emit exactly 1 time (unified signal per Rule 1 — covers EC-01 + EC-16 + Rule 9 stale-path cases)。Source: Rule 9, EC-16 | Type: Logic | Gate: BLOCKING | File: `tests/unit/camera/camera_target_lost_test.gd`
- **AC-23 [EC-14 viewport resize]**: GIVEN Following state, WHEN viewport size changes (mock devtools open / window resize), THEN dead-zone box world extents auto-recompute next frame per Formula 5 (no visible jolt — camera position 維持 world-coord locked)；Focal entry tween, if active, continues uninterrupted with target world coord preserved。Source: EC-14, Formula 5 | Type: Integration | Gate: BLOCKING | File: `tests/integration/camera/camera_viewport_test.gd`

### Cross-System Contracts (Section F upstream + downstream)

- **AC-24 [ADR-006 Contract 6 binding]**: GIVEN Camera autoload `_ready()`, WHEN GSM subscription created, THEN uses `GameStateMachine.connect_for_initial_state(_on_gsm_state_changed)` helper (NOT direct `.connect()`) — verified by grep scan of camera_controller.gd source。Initial state delivery via sentinel payload (per Contract 6)。Source: ADR-006 Contract 6 | Type: Static / Integration | Gate: BLOCKING | File: `tests/integration/camera/camera_gsm_subscription_test.gd`
- **AC-25 [Falsifiable Test #4 binding, #6 decoupling]**: GIVEN #6 ScreenEffects shake active (`shake(1.0, 0.1)` writes `u_shake_offset` shader uniform to `Vector2(4.0, 0.0)`), WHEN inspect `_camera.offset` at every frame during shake, THEN `_camera.offset == Vector2.ZERO` 永遠成立 (Camera autoload 從不寫 offset — #6 走 shader path 唔走 Camera transform path)。Source: Rule 13, EC-24, Falsifiable Test #4 | Type: Integration | Gate: BLOCKING | File: `tests/integration/camera/camera_screen_fx_decouple_test.gd`
- **AC-26 [AC-E1 binding, EC-23]**: GIVEN Camera2D world bounds set via scene `limit_left=-1024, limit_right=1024`, WHEN `request_focal(target_position=Vector2(5000, 0), zoom=1.4)` called during BOSS_ENCOUNTER, THEN entry tween completes，final Camera2D position clamped to (1024, 0) by Godot Camera2D `limit_*` engine behaviour，zoom tween reaches 1.4x normally，`focal_target_clamped(requested=Vector2(5000,0), clamped=Vector2(1024,0))` signal emit exactly 1 time。Source: EC-23, AC-E1, Rule 10 | Type: Integration | Gate: BLOCKING | File: `tests/integration/camera/focal_target_clamp_test.gd`
- **AC-27 [Future #22 UI contract]**: GIVEN SettingsManager autoload calls `Camera.set_motion_reduction(true)` (when implemented post-#22 GDD), WHEN `request_focal()` called subsequently during BOSS_ENCOUNTER, THEN call silently no-op (NOT push_warning — expected user opt-out per UI Requirements Q-V1 contract)；Following mode: `position_smoothing_enabled = false` + `drag_left_margin = drag_right_margin = drag_top_margin = drag_bottom_margin = 0.0` (dead-zone 0% hard-lock — camera always exactly centred on avatar, no movement at all — eliminates both optical flow AND stroboscopic edge-crossing; per Q-V1 Pass 3 accessibility fix)。Source: UI Requirements future contract | Type: Integration | Gate: BLOCKING | File: `tests/integration/camera/camera_motion_reduction_test.gd`

### CI Enforcement (Rule 13, EC-24)

- **AC-28 [Rule 13 CI script]**: GIVEN repo source, WHEN `tools/ci/check_camera_callers.gd` runs via `godot --headless --script`, THEN scans all `.gd` files OUTSIDE whitelist (`src/autoload/camera_controller.gd`, `tests/`, `tools/debug/`) for banned patterns (`Camera2D\.[^.]*\.position\s*=`, `Camera2D\.[^.]*\.zoom\s*=`, `\.make_current\s*\(`, `get_viewport\(\)\.get_camera_2d\(\)`)。Zero matches required，violation → exit(1) blocking。Source: Rule 13 | Type: Static / CI | Gate: BLOCKING | File: `tools/ci/check_camera_callers.gd` + `tests/unit/ci/check_camera_callers_test.gd`
- **AC-29 [EC-24 runtime guard, debug build only]**: GIVEN test fixture injects `_camera.offset = Vector2(1.0, 0)` (simulating slipped Rule 13 violation — e.g. AnimationPlayer modifies offset bypassing CI), WHEN `_process()` exits AND `OS.is_debug_build() == true`, THEN `push_error("Camera.offset must be zero — owned by #6 ScreenEffects shader uniform")` captured via test error hook + violation counter incremented。**Impl note**: replace any `assert(_camera.offset == ...)` with `if OS.is_debug_build(): if _camera.offset != Vector2.ZERO: push_error(...)` — same semantics, GUT-safe (assert() crashes GUT test runner in debug mode)。Source: Rule 13, EC-24 | Type: Logic | Gate: BLOCKING | File: `tests/unit/camera/camera_offset_assert_test.gd`

### Pillar 2 Hard Guarantee (Cross-knob invariants)

- **AC-30 [AC-G1 + Pillar 2 hard contract]**: GIVEN revised safe knob ranges (POSITION_SMOOTHING_SPEED ∈ **[5.0, 8.0]**, LOCK_ON_TOLERANCE_PX ∈ **[3.0, 8.0]** — post-/design-review Pass 1 revision), WHEN Formula 4 evaluated at all 4 safe-range corners (d_initial=30px), THEN ALL ≤ 500ms: (k=5.0, d_tol=3.0) → `ln(10)/5 = 461ms ✓`; (k=5.0, d_tol=8.0) → `ln(30/8)/5 = 200ms ✓`; (k=8.0, d_tol=3.0) → `ln(10)/8 = 288ms ✓`; (k=8.0, d_tol=8.0) → `ln(3.75)/8 = 166ms ✓`。ADDITIONALLY GIVEN just-below-floor combination (k=4.9, d_tol=2.9 — outside revised safe range), THEN `ln(30/2.9)/4.9 = 527ms ✗` (documents why revised floor is necessary)。**Note**: old [3.0,8.0]/[1.0,8.0] references in earlier spec versions were stale — this AC now matches Section G post-revision ranges (Pass 3 fix)。Source: Cross-knob G1, Falsifiable Test #2 | Type: Logic | Gate: BLOCKING | File: `tests/unit/camera/cross_knob_invariants_test.gd`

### Pillar 3 Hard Guarantee (Cinematographic feel)

- **AC-31 [AC-G3 binding]**: GIVEN any default knob load, WHEN read FOCAL_ZOOM_DEFAULT 同 FOCAL_ZOOM_CAP, THEN `FOCAL_ZOOM_DEFAULT (1.4) ≤ FOCAL_ZOOM_CAP (4.0)` (trivial but binding — guards against future knob revision that breaks default validity)。Source: Cross-knob G3 | Type: Logic | Gate: BLOCKING | File: `tests/unit/camera/cross_knob_invariants_test.gd`
- **AC-32 [Falsifiable Test #5 binding, Pillar 3 supporting]**: GIVEN human playtest panel (n ≥ 5) on mobile Safari iOS 17+ baseline device, WHEN BOSS_ENCOUNTER / LOOT_DROP Focal entry tween presented in random session order, THEN ≥ 80% panelists describe Focal feel as「invitation / 主動帶我望」(NOT「pulled / 被迫聚焦」)。Quart ease-out 「decisive lunge」property validated perceptually。Source: Section B Falsifiable Test #5, Formula 2 | Type: Visual | Gate: ADVISORY | File: `production/qa/evidence/pillar3_focal_invitation_playtest.md`

### ADR-001 RATIFICATION-GATED (3 ACs)

- **AC-33 [FR-1, Risk Register binding]**: GIVEN mobile Safari iOS 17+ baseline (iPhone 12 portrait), WHEN sustained gameplay scene with Following active (avatar pursuit) + occasional Focal mode (every 30s for 1s) for 60s session, THEN P95 CPU cost per frame for Camera autoload ≤ value allocated in **ADR-001 (pending ratification)**，cross-platform consistent (desktop + mobile Compatibility renderer no perceptible deviation)。Source: Risk Register FR-1 | Type: Performance | Gate: ADR-001 RATIFICATION-GATED | File: `tests/performance/camera/mobile_safari_p95_test.gd`
- **AC-34 [FR-2, Risk Register binding]**: GIVEN 60fps target device + Focal entry tween 0.6s + Focal exit tween 0.5s, WHEN tween active over 60s sample, THEN zero frame drops detected via `Engine.get_frames_per_second()` sampling — Web Export Compatibility 模式下唔可以 frame-drop 到 < 30fps mid-tween。If frame drop observed → ADR-001 fallback: Focal duration shrinks to 0.4s (entry) / 0.3s (exit)，OR mobile auto-disable Focal (snap zoom)。Source: Risk Register FR-2 | Type: Performance | Gate: ADR-001 RATIFICATION-GATED | File: `tests/performance/camera/focal_smoothness_test.gd`
- **AC-35 [FR-3, Risk Register binding]**: GIVEN CI gate script `tools/ci/check_focal_caller_states.gd`, WHEN scans `src/` for `Camera.request_focal(...)` callers AND cross-checks against `tools/ci/focal_caller_whitelist.txt` (explicit authorized caller list — each line: `src/path/to/caller.gd:function_name`), THEN any caller NOT in whitelist → CI fail with diagnostic naming offending file + line。**Q-R3 resolved (Pass 3)**: heuristic = explicit whitelist file (NOT function-name pattern matching, NOT comment context analysis) — mirrors Rule 13 WHITELIST_PATHS pattern, requires PR review for any new authorized caller。First authorized callers at VS-tier: `src/systems/enemy_director/enemy_director.gd:_on_boss_spawn` + `src/systems/loot_drop/loot_drop_modal.gd:_on_loot_drop_entry`。Source: Risk Register FR-3, Rule 4 | Type: Static / CI | Gate: ADR-001 RATIFICATION-GATED | File: `tools/ci/check_focal_caller_states.gd` + `tools/ci/focal_caller_whitelist.txt` + `tests/unit/ci/focal_caller_gate_test.gd`

### Total count + breakdown

**36 ACs total** (qa-lead synthesis + 3 main session refinements + Pass 3 AC-06 split):
- **32 BLOCKING**: AC-01 to AC-31 (excluding AC-32) + AC-06a + AC-06b (AC-06 split into 2 per Pass 3; AC-06a = VS-tier current scope, AC-06b = post-#22 GDD gate)
- **1 ADVISORY**: AC-32 (Focal invitation perceptual playtest)
- **3 ADR-001 RATIFICATION-GATED**: AC-33 (FR-1 mobile P95), AC-34 (FR-2 60fps smoothness), AC-35 (FR-3 caller gating CI)

### Coverage Map

| Section | Source items | ACs binding | Coverage |
|---------|--------------|-------------|----------|
| C — Rules 1, 4-5 (API) | 3 rules | AC-01, 02, 03, 04, 05, 06a, 06b | 7/3 ✓ over |
| C — Rules 2-3 (Follow) | 2 rules | AC-07, 08 | 2/2 ✓ |
| C — Rules 6-7 (Focal) | 2 rules | AC-11, 12, 13, 14, 15 | 5/2 ✓ over |
| C — Rule 8 (Suspended) | 1 rule | AC-17 | 1/1 ✓ |
| C — Rule 9 (bfcache restore) | 1 rule | AC-18, 22 | 2/1 ✓ |
| C — Rule 10 (world bounds) | 1 rule | AC-26 (via EC-23) | 1/1 ✓ |
| C — Rule 11 (DEFAULT_ZOOM) | 1 rule | AC-13, 31 | 2/1 ✓ |
| C — Rule 12 (PAUSABLE) | 1 rule | AC-14 | 1/1 ✓ |
| C — Rule 13 (CI) | 1 rule | AC-25, 28, 29 | 3/1 ✓ |
| C — Rule 14 (Persistence ban) | 1 rule | AC-21 | 1/1 ✓ |
| D — Formula ACs (D1-D4) | 4 candidates | Folded into AC-09 (D1), AC-11 (D2), AC-12 (D3), AC-10 (D4) | 4/4 ✓ |
| E — Edge cases (HIGH impact) | 24 ECs | Covered: 01→AC22, 02→AC02, 03/05→AC03, 07→AC20, 08→AC16, 09→AC17, 11→AC18, 12→AC21, 13→AC14, 14→AC23, 16→AC22, 19→AC04, 20→AC05, 21→AC07 (delta=0), 22→AC09, 23→AC26, 24→AC25/29 | HIGH covered (LOW-impact ECs 06/10/15/17/18 covered by code review + manual smoke) |
| F — Cross-system contracts | 4 downstream | AC-24 (GSM upstream), AC-26 (#14/#21 caller), AC-27 (#22 future) | partial (#25/#26 downstream ACs pending GDD) |
| G — Knob ACs (G1-G3) | 3 candidates | Folded into AC-30 (G1), AC-15 (G2), AC-31 (G3) | 3/3 ✓ |
| B — Falsifiable Tests #1-6 | 6 tests | T#1→AC19, T#2→AC09/AC10, T#3→AC17, T#4→AC25, T#5→AC11/AC32, T#6→AC19/AC33 | 6/6 ✓ |
| Risk Register FR-1/2/3 | 3 invariants | AC-33, 34, 35 | 3/3 ✓ |

### Noteworthy Gaps (flagged for next-revision)

1. **Section F downstream contract #25 Combat Visual Feedback + #26 Avatar Renderer** — 暫無 explicit AC binding 因為 #25 / #26 GDDs 未 authored。`follow_target_lost` + `focal_completed` signal contracts covered by AC-22 + AC-32，但 downstream consumer-side timing 留待 #25 / #26 GDD ratification 後 supplement (AC-36/37 candidates)
2. **Section E low-impact ECs (EC-06, 10, 15, 17, 18)** — deliberately untested per AC scope discipline (focus on HIGH-impact ECs)。Covered by code review + manual smoke check
3. **AC-33 (FR-1 mobile Safari P95) — exact CPU budget value 待 ADR-001 ratification**。AC structure 已 lock，threshold 數字 fill-in-blank
4. **AC-35 (FR-3 CI script for caller gating)** — script logic 需要 design (heuristic: function name pattern + comment context analysis)；devops-engineer sprint coordination needed

## Open Questions

本 GDD 識別 7 個 open questions across Section F (3 carried forward) + Section B Risk Register (3) + V/A-UI (1)。每個 question 包：owner / trigger / default if未 resolved / risk if未 resolved。

### Q-F1 — #1 GSM bidirectional dependency entry

- **Question**: #1 GameStateMachine GDD `Downstream Dependents > Soft dependents` 表 currently does NOT list #7 Camera System — 需要加 entry "subscribes via `connect_for_initial_state` per ADR-006 Contract 6；Suspended state triggers Rule 8 cancel-all sequence"
- **Owner**: Next /design-review GameStateMachine session OR /consistency-check pass
- **Trigger**: Camera autoload implementation start OR #1 GSM next revision
- **Default if未 resolved**: Bidirectional consistency violation — #1 GSM 唔 mention #7，唔影響 implementation correctness 但違反 coding-standards.md "Dependencies must be bidirectional"
- **Risk if未 resolved**: Future GDD revision 同 architecture-review 會 flag missing reciprocal entry

### Q-F2 — Scene tear-down hook for `_force_clear_focal_sync()`

- **Question**: EC-17 specifies scene change while Focal active → `_force_clear_focal_sync()` synchronous cleanup required。Hook 邊個觸發 — scene root `_exit_tree()` OR GSM pre-transition hook (e.g. emit `state_changed_pre_transition` signal)?
- **Owner**: VS-tier sprint planning + scene scaffolding decision
- **Trigger**: VS-tier first scene change implementation
- **Default if未 resolved**: Scene root `_exit_tree()` cleanup (簡單，但 race condition risk if tween fires same frame as scene unload)
- **Risk if未 resolved**: Dangling tween references freed Camera2D node → NPE in `_on_focal_complete` callback

### Q-F3 — Mobile-specific tuning knobs deferred to ADR-001

- **Question**: VS-tier 鎖定 single behaviour cross-platform，但 ux-designer 提出 mobile recommendations — dead-zone 12% × 16% asymmetric + smoothing_speed 4.0 (vs desktop default 8% × 12% + 5.0)。ADR-001 input scope 處理 mobile-specific overrides 嘅 mechanism (per-platform knob set OR runtime device detection switch)？
- **Owner**: ADR-001 authoring + technical-director
- **Trigger**: ADR-001 Web Export Budget Caps ratification gate
- **Default if未 resolved**: VS-tier single behaviour (8% × 12% + 5.0) 跨 desktop + mobile — 可能 mobile peripheral motion sickness 風險
- **Risk if未 resolved**: VS-tier mobile Safari playtest 出現 motion sickness reports → retro-fit mobile-specific tuning，可能 break Section G cross-knob invariants

### Q-R1 — FR-1 ADR-001 CPU budget allocation for Camera

- **Question**: ADR-001 必須 specify Camera autoload CPU budget allocation — separate from #5 GPU budget + #6 CPU budget
- **Owner**: ADR-001 authoring (queued)
- **Trigger**: ADR-001 / Web Export Budget Caps ratification
- **Default if未 resolved**: AC-33 結構 lock，threshold 數字 fill-in-blank pending ADR-001
- **Risk if未 resolved**: VS-tier mobile Safari playtest 可能發現 sustained Following + Focal active 超出 budget — 需要 fallback (snap follow / disable Focal mobile / etc.)

### Q-R2 — FR-2 Web Export Compatibility renderer Focal smoothness

- **Question**: Knowledge gap — Godot 4.6 `Camera2D.position_smoothing_speed` + Tween cubic interpolation 喺 Compatibility renderer (WebGL 2 mobile Safari) 嘅 frame budget behaviour 未驗證；位 ADR-001 input scope 嘅 spike task list?
- **Owner**: VS-tier prototype + engine-programmer
- **Trigger**: ADR-001 input gathering phase
- **Default if未 resolved**: 假設 Camera2D smoothing + Tween 喺 Compatibility 模式達成 60fps — 可能 fail
- **Risk if未 resolved**: Mid-Focal frame drop → AC-34 fail → ADR-001 fallback retro-fit (Focal duration shrink OR mobile snap zoom)

### ~~Q-R3~~ ✅ RESOLVED (Pass 3 2026-05-26) — FR-3 CI script heuristic locked

- **Resolution**: heuristic = explicit whitelist file (`tools/ci/focal_caller_whitelist.txt`) — mirror Rule 13 WHITELIST_PATHS pattern。AC-35 updated。See AC-35 for full spec。
- **Owner**: devops-engineer to implement script + maintain whitelist at VS-tier sprint planning。

### Q-V1 — Camera motion reduction accessibility toggle UX design

- **Question**: `set_motion_reduction(enabled: bool)` UI surface 由 #22 Character Screen GDD owner 處理 — toggle 名稱 / placement / "live preview" mechanism / motion_intensity slider integration (與 #6 ScreenEffects motion_intensity slider 並列 OR unified single panel)?
- **Owner**: #22 Character Screen GDD owner + accessibility-specialist + ux-designer
- **Trigger**: #22 GDD authoring (Accessibility Settings Panel section)
- **Default if未 resolved**: Reservation pattern only (per UI Requirements future surface contract) — backend API contract locked, UI defer
- **Risk if未 resolved**: #22 GDD owner 可能 design 唔到 unified accessibility cluster (Camera + ScreenEffects motion controls)，玩家見到兩個分散 toggle 而非 single integrated panel section
