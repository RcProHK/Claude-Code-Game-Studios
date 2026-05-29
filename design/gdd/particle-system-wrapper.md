# Particle System Wrapper

> **Status**: Approved (CD-GDD-ALIGN passed 2026-05-26)
> **Author**: Frank + systems-designer (×2) + qa-lead + art-director + creative-director
> **Last Updated**: 2026-05-26 (rev: lean design-review — Rule 5 tier-selection fix, Rule 15 Suspended note clarification, section header standardised)
> **Creative Director Review (CD-GDD-ALIGN)**: APPROVED 2026-05-26 — 8 findings ✓, 4 advisory observations non-blocking (Pillar 5 future preset evaluation, ADR-001 FR-1/2/3 ratification gate, 5% telemetry retune workflow, audio bank parity CI). Strongest pillar-coherent GDD to-date per CD assessment.
> **Implements Pillar**: Pillar 3 (Drop Euphoria — over-the-top particle storm infrastructure) + Pillar 2 (Frictionless Companion — mobile Safari perf budget enforcement)
> **System #**: 5 (Foundation / VS tier)
> **Depends On**: (none — Foundation leaf-edge)
> **Depended On By**: #14 EnemyDirector (combat VFX spawn), #21 Loot Drop Modal (Pillar 3 signature burst), #25 Combat Visual Feedback (hit/parry/status particles)
> **Governing ADRs**: ADR-001 Web Export Budget Caps (to be authored AFTER this GDD as input scope), ADR-005 Loot Rarity Formula (influences burst variance preset selection)

## Overview

Particle System Wrapper 係 Mirror Hero 唯一嘅 client-side particle 接觸層 — 一個 Foundation 層 singleton autoload，封裝所有 Godot 4.6 `GPUParticles2D` 嘅生命週期、preset 管理、budget enforcement 同 mobile Safari fallback 行為。Wrapper 本身唔 own 任何 gameplay state — 純粹係一個 typed API surface + closed preset library + frame-budget enforcer。佢嘅職責有四：(1) 暴露單一 `play(preset_id: PresetId, position: Vector2, multiplier: float = 1.0) -> ParticleHandle` API 畀所有 VFX consumer (#14 EnemyDirector / #21 Loot Drop Modal / #25 Combat Visual Feedback) 統一調用 — 消除「每個 system 自己 `new GPUParticles2D()`」嘅 anti-pattern；(2) 維護一個 **closed preset library** — combat 類 (`HIT_LIGHT` / `HIT_HEAVY` / `PARRY` / `DEATH`)、loot 類 (`LOOT_BURST` / `LOOT_RARE_BURST`)、status 類 (`STATUS_BURN` / `STATUS_FREEZE` / `STATUS_STUN`) — 每個 preset 嘅視覺特徵（emitter shape、lifetime、color ramp、texture）由本 GDD 內 lock 死，consumer **唔可以 ad-hoc 加 variant**，保證 game-concept Visual Identity Anchor「乾淨剪影 + 骯髒粒子」rule 全 game 一致；(3) enforce 硬性 frame-budget cap — `MAX_ACTIVE_PARTICLES = 200` 全 frame 上限（per game-concept hard governance 第 8 條 + ADR-001 input scope），超 budget 觸發 LRU eviction（最舊嘅 emitter 提早 `restart()` stop）；mobile Safari user-agent 偵測後自動 apply `MOBILE_FALLBACK_MULTIPLIER = 0.5` particle count；loot drop preset 自動套用 `LOOT_BURST_MULTIPLIER = 3.0`（Pillar 3 over-the-top 保證）；(4) **僅暴露 `burst_started(preset_id, position)` signal**，畀 #6 Screen Effects System 同 #1 GameStateMachine 用嚟 co-trigger hit pause + screen shake — 本 wrapper 嚴格 own particles only，唔 own 任何 non-particle「DNF feel 三件套」其他元素。系統 stateless from gameplay perspective — 唔解釋 preset 觸發嘅 gameplay semantic（由 caller own），唔做 conflict resolution（concurrent burst 由 LRU eviction policy 處理）。所有 budget enforcement runtime policy + per-device measured caps + WebGL 2 feature detection 將喺 **ADR-001 Godot Web Export Budget Caps** lock 死，本 GDD 屬 ADR-001 嘅 input scope；本 GDD 同 **ADR-005 Loot Rarity Formula** 間接相關 — loot rarity tier 對應 `LOOT_BURST` vs `LOOT_RARE_BURST` preset 選擇（具體 mapping 將喺 #15 Loot Drop System GDD authoring 時 lock）。

## Player Fantasy

**Direct fantasy — 眼角擒獲 (Peripheral Capture)**:

玩家心入面嘅 felt promise：「**就算我冇望住，個畫面都會喺啱啱嗰一秒拉走我嘅眼球。** Mirror Hero 嘅粒子唔係 background ambient — 係 silent siren。我做緊 squat 第 5 rep bottom hold、視線本來鎖喺鏡入面自己嘅姿勢，屏幕角落爆出一陣紫色粒子潮 — 1 秒之內已經 register 到『loot 跌咗』，rep 完成放低杠就即刻擰頭睇 replay。粒子係喺周邊視覺先攔截到我，唔係要我望住先驚動我。」

呢個 fantasy 唔由 wrapper 自己 emit 任何敘事 text — 而係由佢嘅 **architectural posture** 強制：
- **Closed preset library** + **lock 死嘅 visual scale** (`HIT_LIGHT < HIT_HEAVY < LOOT_BURST < LOOT_RARE_BURST`) 確保每個 burst 級別都對應一個可分辨嘅 peripheral signature — 玩家眼角喺 200ms 內就 register 到「呢個係 hit / 呢個係 loot」嘅分別
- **3× `LOOT_BURST_MULTIPLIER`** 唔係 designer "juice"，係 **visual claim** — 確保 loot burst 喺周邊視覺強度上永遠 dominate combat burst 3 倍，符合 Visual Identity Anchor「設計 test：錄一秒 loot drop 片段，旁邊有人打架嘅情況下，眼球先落邊？」嘅 ground truth
- **200 cap budget enforcement** 同樣係 fantasy 一部分 — 唔 jank 就係玩家可以唔擔心 mid-set 拎電話、唔需要 close app 重開嘅 quiet promise（Pillar 2 silent guarantee）

呢個 architectural-felt fantasy 同 GDD #3 PersistenceLayer 嘅「存咗就係存咗」係 **paired infrastructure postures** — 兩者都唔係 designer 用 juice / polish 加埋去嘅 surface feel，係 wrapper class 一啟動就 architectural locked 嘅 invariant。GDD #3 architectural 拒絕 fabricate persistence；本 wrapper architectural 拒絕 sacrifice peripheral capture 同 frame budget。任何「我加多 50 個 particle 應該得喎」嘅 ad-hoc 意圖都會被 closed preset + LRU eviction 強制 reject。

呢個 direct fantasy 直接 enables：
- **Pillar 3 (Drop Euphoria — primary owner)** — `LOOT_BURST` / `LOOT_RARE_BURST` preset 嘅 3× scale + lock 死嘅 color ramp（white → green → blue → purple → orange per game-concept Color Philosophy）確保「值唔值得 cap 圖、發朋友圈」design test 喺每次 drop 都 PASS
- **Pillar 2 (Frictionless Companion — co-owner via budget enforcement)** — 200 active cap + mobile 0.5× fallback 確保 workout-time frame rate 唔會掉到「玩家被迫 mid-set 諗咩事」嘅 threshold。Wrapper 係 Pillar 2 嘅 silent guard
- **Visual Identity Anchor** (game-concept locked, art-bible seed) — closed preset library 係呢個 visual identity 嘅 enforcement vehicle — 唔 own visual identity 嘅 design，own visual identity 嘅 consistency

**Falsifiable design test** — 任何 client-side path 引致以下情境 = bug，唔係 acceptable behavior：
1. 玩家做 squat、屏幕角落有 loot burst，但 mid-set glance 一秒內無法分辨「呢個係 loot 還是 combat hit」(visual signature 唔夠 distinct，preset scale 失層次) → **眼角擒獲 fantasy 違反**
2. Loot rare drop 嘅 burst 同 normal drop 嘅 burst 喺周邊視覺強度上冇明顯區別 (`LOOT_RARE_BURST` vs `LOOT_BURST` scale 失序) → **Pillar 3 escalation gradient 崩潰**
3. EnemyDirector 同時 spawn 12 個 enemy 各自 fire `HIT_HEAVY`，超過 `MAX_ACTIVE_PARTICLES = 200`，但 wrapper 冇 LRU eviction，mobile Safari frame drop 到 < 30fps → 玩家被迫意識到 game 卡 → **Pillar 2 violated**
4. Consumer (#21 Loot Drop Modal) 想加新 preset `LOOT_LEGENDARY_BURST` 但繞過 wrapper 自己 `new GPUParticles2D()` 加 600 particle storm → budget bypass → Pillar 2 + 視覺 inconsistency 雙重 violate
5. Mobile Safari 偵測失敗、fallback multiplier 唔 apply，desktop-class 粒子強度跑喺 iPhone Safari → frame drop → Pillar 2 silent violation (見 Q-V1)

### Fantasy Risk Register

呢個 direct fantasy 嘅「architectural posture」framing 係 contingent on 以下 invariants 喺 **ADR-001 ratification** 真正 enforced，否則 Player Fantasy paragraph 變 retroactive lie：

| # | Contingent Invariant | Owner | Fallback if Dropped |
|---|---------------------|-------|---------------------|
| FR-1 | `MAX_ACTIVE_PARTICLES = 200` cap 喺 mobile Safari 上實測 P95 frame time ≤ 16.6ms (60fps budget) — ADR-001 必須 ratify per-device measured cap，唔係 hand-wave 200 | ADR-001 | Lower cap to measured-safe value (e.g. 120 on mobile)；OR wrapper 自動降級 fallback multiplier 至 0.3× — Pillar 2 protected at visual cost |
| FR-2 | `LOOT_BURST` vs `LOOT_RARE_BURST` visual signature 喺 1 秒 peripheral glance test 中可被玩家 unambiguously 分辨 — `/playtest-report` 驗證 | art-director + #21 owner | 若分辨失敗 → 加 audio cue 強化（但本 wrapper 唔 own audio），或重做 preset color ramp escalation |
| FR-3 | Mobile Safari user-agent 偵測 100% accurate — `JavaScriptBridge.eval("navigator.userAgent")` 喺所有 iOS Safari variant (mobile / iPad / Safari WebView) 都 catch 到 | gameplay-programmer + VS spike | Boot 時若 user-agent 偵測 ambiguous → 默認當 mobile (conservative — 寧願 desktop 見少啲 particle，唔好 mobile 用戶 jank) |

**Ratification gate binding**: ADR-001 review MUST verify implementation satisfies all 3 invariants before Status: Accepted。若 ADR-001 lands without one of FR-1/FR-2/FR-3 → revisit this Player Fantasy paragraph with the corresponding fallback framing。

## Detailed Rules

### Core Rules

#### Rule 1 — `play()` 係單一進入口，arguments sync validation

**Signature (locked)**:
```gdscript
func play(preset_id: PresetId, position: Vector2, multiplier: float = 1.0) -> ParticleHandle
```

進入 `play()` 第一步 sync validate，永遠唔 `await`：
1. `preset_id` 必須係 `PresetId` enum value (GDScript typed enum compile-time 保證 + runtime `assert(preset_id in PRESET_TABLE)` 防 reflection / network route 後入錯值)
2. `position` 含 `NaN` / `±INF` → reject + return `ParticleHandle.INVALID` (Foundation 唔可以 throw — Pillar 2 frictionless)
3. `multiplier` clamp 到 `[0.1, MAX_CALLER_MULTIPLIER (=1.5)]` (`< 0.1` short-circuit return invalid handle; `> 1.5` clamp + `push_warning`)

#### Rule 2 — `play()` 立即返回 ParticleHandle，emission GPU-async

`play()` 返回時保證：handle 已分配 / pool slot reserved (或 invalid handle returned) / `burst_started` signal 已 emit (見 Rule 11)。GPU 實際 particle spawn 仍係下一 `_process` frame；caller 唔需要等。Fire-and-forget pattern。

#### Rule 3 — `ParticleHandle` contract

```gdscript
class_name ParticleHandle extends RefCounted

const INVALID: ParticleHandle  # singleton sentinel

var preset_id: PresetId            # read-only
var spawn_time_ms: int             # Time.get_ticks_msec() at play() call
var _pool_index: int               # -1 if INVALID
var _generation: int               # monotonic counter — prevents stale handle reuse
var was_downscaled: bool           # always false in v1 (Tier 1 auto-downscale rejected per Rule 9)

func alive() -> bool               # true 如果 slot._generation == handle._generation
func stop(fade: bool = true) -> void  # 主動停止，fade=true 用 one_shot=true 自然衰減
func position() -> Vector2         # 最後 emit position
```

**Generation counter 防 stale handle bug**：每個 pool slot 有自己 `_generation: int`。`play()` 攞到 slot 時 `generation += 1` 然後寫入 handle。LRU evict 後 slot generation 已經 bump，舊 handle `.alive()` 自動 return false，即使 slot 已被另一個 preset 重用都唔會錯認。

**Lifecycle**: Handle 係 `RefCounted` — caller drop reference 後自動 free。Wrapper **唔 hold strong reference** 落 handle，pool slot 只記 `generation` 同 `is_emitting`。Handle leak 只係 RefCounted idiom，唔會洩漏 GPUParticles2D。

#### Rule 4 — Object pool: pre-spawned 16 nodes, segmented by capacity tier

Boot 階段 pre-spawn **16 個 `GPUParticles2D`** node，split 落 3 tier：

| Tier | Pool Size | `amount` buffer (locked, no realloc) | 服務 presets |
|------|-----------|--------------------------------------|-------------|
| SMALL | 8 nodes | 32 | HIT_LIGHT (base 8), STATUS_BURN/FREEZE/STUN (≤16) |
| MEDIUM | 6 nodes | 96 | HIT_HEAVY (18), PARRY (14), DEATH (28), LOOT_BURST mobile (36) |
| LARGE | 2 nodes | 256 | LOOT_BURST desktop (72), LOOT_RARE_BURST desktop (144) |

**唔用 on-demand spawn 既理由**：WebGL 2 Compatibility renderer runtime `add_child(GPUParticles2D)` 會 trigger shader compile + buffer alloc — mobile Safari 上會見到 visible hitch。Pre-spawn 16 ≈ 2.5MB VRAM (0.5% of 512MB ceiling)，可接受。

**Material handling**: 9 preset 各自一個 **preloaded `ParticleProcessMaterial`** resource (color_ramp / texture / emission_shape / spread_deg / scale_curve / gravity / drag 全 lock 喺 .tres，attribute 對應 Visual/Audio Requirements section 嘅 Preset Library Table)。Pool node 喺 acquire 時 hot-swap `process_material = PRESET_TABLE[preset_id].material` + 設定 `amount` + `lifetime` + `global_position` → `restart(false)` → `emitting = true`。

`restart()` 既 `keep_seed` parameter 係 Godot 4.4+ available (per `docs/engine-reference/godot/breaking-changes.md`)，`false` = 隨機 seed 確保 burst 多樣性。

#### Rule 5 — `amount` 改動觸發 buffer realloc → tier 選擇而非 quantize

Godot 既 `GPUParticles2D.amount` setter 會 reallocate GPU buffer (WebGL 2 worst-case 5-15ms hitch)。本 wrapper **唔做 runtime quantization**，反而靠 Rule 4 既 tier system — 每個 tier node 既 `amount` boot 時設定，runtime 永不改 amount，只改 `process_material` + `lifetime` + `position`。

Tier 選擇邏輯：
```gdscript
func _select_tier(preset_id: PresetId, final_count: int) -> String:
    # LOOT presets always use LARGE tier (Rule 4 design intent — dedicated nodes, Pillar 3 guarantee)
    if preset_id in [PresetId.LOOT_BURST, PresetId.LOOT_RARE_BURST]:
        return "LARGE"
    if final_count <= 32: return "SMALL"
    if final_count <= 96: return "MEDIUM"
    if final_count <= 256: return "LARGE"
    push_warning("ParticleWrapper: final_count %d exceeds LARGE buffer; clamping" % final_count)
    return "LARGE"  # final_count silently clamped at compose time (Rule 7 max=256)
```

#### Rule 6 — Active particle counting: CPU ledger, O(1) incremental

Wrapper hold:
- `var _active_particle_total: int = 0`
- `var _ledger: Dictionary[int, Dictionary]` keyed by `handle_id` (value = `{count, spawn_time_ms, preset_id, pool_index}`)

`play()` 成功 allocate → `_active_particle_total += final_count` + insert ledger entry。

Emitter expire 由 `get_tree().create_timer(lifetime + LEDGER_EXPIRE_SAFETY_MS=50ms).timeout` callback 觸發 `_on_expire(handle_id)` → `_ledger.erase(handle_id)` + `_active_particle_total -= count` + 釋放 pool node 返 free list。

**Acceptable drift**: ±15% over-estimate (CPU ledger 仍 hold 但 GPU 粒子已 alpha-fade 完)。**唔容許 under-estimate** — ledger 保守傾向高估，保證 `MAX_ACTIVE_PARTICLES = 200` 係 ceiling 而非 average。

**Justification versus per-frame recompute**: O(1) ledger 避免每 `_process` iterate 16 nodes 計 emitting state；亦避免 `GPUParticles2D.emitting` flag 喺 `one_shot=true` 模式下 reset-after-spawn 既 false-negative count。

#### Rule 7 — Multiplier composition order (locked)

```
final_count = clamp(round(base × loot_mult × mobile_mult × caller_mult), 1, 256)
```

| Step | Factor | When applied |
|------|--------|--------------|
| 1 | `preset.count` | base from `PRESET_TABLE` (per Visual Spec table) |
| 2 | `× LOOT_BURST_MULTIPLIER (3.0)` | if `preset_id in [LOOT_BURST, LOOT_RARE_BURST]` |
| 3 | `× MOBILE_FALLBACK_MULTIPLIER (0.5)` | if `_is_mobile == true` |
| 4 | `× caller_multiplier` | clamped `[0.1, 1.5]` per Rule 1 |
| 5 | `clamp(round(...), 1, 256)` | floor=1 (1-particle still emits valid burst), ceiling=256 (= LARGE tier buffer, exceed → silent clamp + `push_warning`) |

**Pillar 3 sanity check**: HIT_LIGHT mobile = 8×0.5 = 4; LOOT_BURST mobile = 24×3×0.5 = 36; ratio LOOT/HIT = 9× — loot 視覺特權喺 mobile 上面仍然 trump combat noise。

**Worked examples**:

| Scenario | base | loot_mult | mobile_mult | caller_mult | final_count |
|---|---|---|---|---|---|
| Desktop HIT_LIGHT | 8 | 1.0 | 1.0 | 1.0 | 8 |
| Mobile HIT_HEAVY | 18 | 1.0 | 0.5 | 1.0 | 9 |
| Desktop LOOT_BURST | 24 | 3.0 | 1.0 | 1.0 | 72 |
| Mobile LOOT_BURST | 24 | 3.0 | 0.5 | 1.0 | 36 |
| Desktop LOOT_RARE_BURST | 48 | 3.0 | 1.0 | 1.0 | 144 |
| Desktop LOOT_RARE_BURST + caller=1.5 | 48 | 3.0 | 1.0 | 1.5 | 216 |
| Desktop LOOT_RARE_BURST + caller=2.0 (clamped to 1.5) | 48 | 3.0 | 1.0 | 1.5 | 216 + `push_warning` (caller clamped) |

#### Rule 8 — LRU eviction: pure age-only + single floor (Hybrid Pillar 3 protection)

**Data structure**: `_age_queue: Array[int]` of handle_ids，insertion-ordered (oldest at index 0)。Ledger (Rule 6) hold spawn_time。

**Eviction trigger**: BEFORE allocating new emitter — `_active_particle_total + final_count > MAX_ACTIVE_PARTICLES` (= 200)。

**Algorithm**:
```gdscript
const EVICTION_MIN_LIFE_MS := 150

func _try_evict(needed: int, is_loot_request: bool) -> bool:
    var now := Time.get_ticks_msec()
    for handle_id in _age_queue.duplicate():  # snapshot — mutating during iter
        var entry: Dictionary = _ledger.get(handle_id, {})
        if entry.is_empty(): continue
        var age_ms: int = now - (entry.spawn_time_ms as int)
        # Hybrid carve-out (Rule 9 dispatched here):
        if age_ms < EVICTION_MIN_LIFE_MS:
            # Floor-protected. LOOT incoming 可 bypass to evict non-LOOT slot.
            if not is_loot_request: continue
            if entry.preset_id in [PresetId.LOOT_BURST, PresetId.LOOT_RARE_BURST]: continue  # never evict LOOT
        _force_expire(handle_id)
        if _active_particle_total + needed <= MAX_ACTIVE_PARTICLES: return true
    return false
```

**Eviction action**: `emitter.emitting = false` only (**NOT `restart()`**) — 現存 GPU 粒子繼續 natural-fade lifetime (1-2 frame visible tail，視覺上係 fade-out 而非 hard cut)。Ledger 即時 `-= count` (假裝 already free，呢個係 Rule 6 ±15% drift 既 source)。Pool node 入 "draining" state，直到 lifetime 真正完先 release 返 free list。

**`EVICTION_MIN_LIFE_MS = 150ms` rationale**: 對應 ~9 frames @ 60fps，足夠玩家 peripheral 1 秒內 register 一個 burst (Player Fantasy 既 200ms peripheral threshold 之內安全)。< 100ms 太短 loot 會 mid-spawn 切走；> 300ms LRU 失效 combat heavy frame 太多 reject。

#### Rule 9 — All-protected fallback (Hybrid LOOT carve-out)

當 `_try_evict` return `false` (所有 emitter 都 within floor)，**根據 incoming preset 分流**：

| Incoming preset class | All-protected 行為 |
|---|---|
| **LOOT_BURST / LOOT_RARE_BURST** | **Bypass floor** — Rule 8 邏輯內含 `is_loot_request=true` path，揀最舊既 non-LOOT slot evict。如所有 16 slot 都係 LOOT_* (實際唔會 hit — LARGE tier 只 2 nodes，最多 2 個 LOOT 並發)：reject。**Pillar 3 trumps Pillar 2** — loot moment 一定出。 |
| **Combat / Status preset** | **Clean reject** — return `ParticleHandle.INVALID`，**唔 emit `burst_started` signal** (防止 #6 Screen Effects 觸發 ghost shake，#1 GSM 觸發 ghost hit pause)。`push_warning` throttled to 1 per `WARNING_THROTTLE_MS = 1000ms` (避 log flood)。Telemetry counter `_dropped_play_calls += 1` for #28 monitoring。 |

**唔做 auto-downscale (拒絕 SD 提案 Tier 1)**: ×0.5 silent visual degradation 對 caller 唔透明，會引發「點解我個 combat hit 細咗一半」既 debugging confusion。Hard reject 簡單 + 可 telemetry 監測。`was_downscaled` field 喺 v1 永遠 `false` (預留 future flexibility)。

**Telemetry trigger**: 若 wrapper 偵測 `_dropped_play_calls / _total_play_calls > 5%` per session → push event to telemetry layer for designer review (knob retune signal)。

#### Rule 10 — Mobile UA detection: boot-cached, conservative default, override API

```gdscript
var _is_mobile: bool = false
var _mobile_override: Variant = null  # null = auto-detect, true/false = force

func _detect_mobile() -> bool:
    if _mobile_override != null: return _mobile_override
    if not OS.has_feature("web"): return false
    var ua_var = JavaScriptBridge.eval("navigator.userAgent", true)
    if ua_var == null or typeof(ua_var) != TYPE_STRING:
        push_warning("ParticleWrapper: UA detection failed; defaulting to MOBILE (FR-3 conservative)")
        return true
    var ua := (ua_var as String).to_lower()
    if "iphone" in ua or "ipod" in ua or "ipad" in ua: return true
    if "macintosh" in ua:
        # iPad-pretending-Mac since iPadOS 13
        var tp = JavaScriptBridge.eval("navigator.maxTouchPoints", true)
        return typeof(tp) == TYPE_INT and (tp as int) > 1
    if "android" in ua or "mobile" in ua: return true
    return false
```

**Cached 一次喺 `_ready()`** — UA mid-session 唔會變。**Manual override** `set_mobile_override(value: Variant)` (null / true / false) — debug-only, gated by `OS.is_debug_build()`，production no-op。

**Conservative default on ambiguity**: 寧願 desktop 用戶見少 0.5× particles (acceptable visual downgrade)，唔好 mobile 用戶 jank (Pillar 2 violation)。**呢個係 Player Fantasy FR-3 既 architectural enforcement**。

**UA pattern table**:

| Device | UA contains | Detection |
|--------|-------------|-----------|
| iPhone Safari / Chrome iOS / Firefox iOS | `iphone` | MOBILE |
| iPad Safari (legacy iOS 12-) | `ipad` | MOBILE |
| iPad Safari (iPadOS 13+) | `macintosh` + `maxTouchPoints > 1` | MOBILE |
| Android Chrome / Mobile | `android` + `mobile` | MOBILE |
| Android Tablet | `android` 但冇 `mobile` | MOBILE (conservative fallthrough) |
| In-app WebView (iOS) | host app + `webkit` + `iphone` | MOBILE |
| Real Mac Safari | `macintosh` + `maxTouchPoints == 0` | DESKTOP |
| Windows / Linux | `windows nt` / `linux x86_64` | DESKTOP |
| Fallthrough (UA null / unknown) | (none of above) | **MOBILE** (FR-3 conservative) |

#### Rule 11 — `burst_started` signal: sync emit, AFTER allocation, BEFORE `emitting = true`

**Signal signature (locked)**:
```gdscript
signal burst_started(preset_id: PresetId, position: Vector2)
```

**Emit placement** (inside `play()`):
```gdscript
# ... validation, compose, evict, acquire node ...
if node == null or handle == INVALID:
    return INVALID  # NO signal emit (ghost-shake guard)
_apply_preset(node, preset_id, final_count, position)
node.restart(false)
burst_started.emit(preset_id, position)   # ← HERE: same frame as emitting=true
node.emitting = true
return handle
```

**Justification**:
- **Option BEFORE allocation**: ghost-shake risk if allocation fail (#6 螢幕震但無對應視覺) — rejected
- **Option `call_deferred` to next frame**: 1-frame perceptual desync between particles + shake/pause — rejected (Pillar 2 frictionless violation)
- **Option AFTER allocation BEFORE `emitting=true`** (chosen): consumer 收到時 emitter 已 ready，下一 `_process` frame render 三者 (粒子 + shake + pause) same-frame coincident — perceptual sync optimal

**Ghost-shake guard**: signal emit ONLY when all 3 conditions met:
1. compose success (Rule 7)
2. evict success or unneeded (Rule 8 + 9)
3. node acquire success (Rule 4 free list non-empty)

任何 fail → `return INVALID` 不 emit signal。

#### Rule 12 — Re-entry guard: nested `play()` from signal handler queued, not denied

```gdscript
var _emit_depth: int = 0
var _deferred_plays: Array = []

func play(preset_id, position, multiplier = 1.0) -> ParticleHandle:
    if _emit_depth > 0:
        # Inside signal callback — queue and return PENDING placeholder
        var pending := ParticleHandle.new(_next_handle_id)
        pending._pool_index = -1  # PENDING marker
        _deferred_plays.append({"args": [preset_id, position, multiplier], "handle": pending})
        return pending

    _emit_depth += 1
    var handle := _execute_play(preset_id, position, multiplier)
    _emit_depth -= 1
    if _emit_depth == 0: _flush_deferred()  # call_deferred to _process end
    return handle
```

**Justification**: 拒絕 re-entry 會令 #6 / #25 既 chain effect 隨機消失。Queue 落同 frame end 既 ~0ms latency imperceptible，但保證 deterministic 行為。Test `tests/unit/particle_wrapper/test_reentrant_play_queued.gd` verify queue + drain order。

#### Rule 13 — Preset table: closed const dict, CI static check enforced

```gdscript
enum PresetId {
    HIT_LIGHT, HIT_HEAVY, PARRY, DEATH,
    LOOT_BURST, LOOT_RARE_BURST,
    STATUS_BURN, STATUS_FREEZE, STATUS_STUN,
}

const PRESETS := {
    PresetId.HIT_LIGHT: {
        count = 8, lifetime = 0.25,
        material = preload("res://assets/vfx/presets/hit_light.tres"),
        z_index = 5,
    },
    # ... 9 entries total per Visual/Audio Requirements section ...
}
```

**Schema fields locked**:
- `count: int` — base pre-multiplier particle count (per Visual Spec table)
- `lifetime: float` — seconds, drives natural fade
- `material: ParticleProcessMaterial` — preloaded `.tres`; encapsulates color_ramp / texture / emission_shape / spread_deg / scale_curve / gravity / drag (per Visual Spec Preset Library Table)
- `z_index: int` — world layer ordering: combat=5, status=4, loot=7 per art-bible Layer Discipline (loot 一定上於 combat)

**CI static check** (locked): `tools/ci/check_particle_callers.gd` grep all `play(` call sites in `src/`，confirm 第一個 arg 係 `ParticleSystemWrapper.PresetId.*` enum reference，**唔係** magic int / String / runtime expression。Violation = build fail。

**呢個係 closed preset library 既 enforcement vehicle** — 防止 consumer 通過 reflection / `Variant` 繞過 preset 加 ad-hoc variant。任何加新 preset 嘅意圖 = 改 `PresetId` enum + 加 `PRESETS` entry + 新 `.tres` material + ADR 記錄變更，no shortcut。

#### Rule 14 — Boot sequence: autoload position 12 (F-SYNC-2 sync 2026-05-28 — pre-VS draft claimed pos 4; project.godot ground truth = pos 12 per Presentation-tier late-boot architecture; PersistenceLayer = pos 1 not pos 3, GameStateMachine = pos 2 not pos 1)

**Autoload order**:
1. `GameStateMachine` (#1)
2. `GymSysBackendClient` (#2)
3. `PersistenceLayer` (#3)
4. **`ParticleSystemWrapper` (#5)** ← here
5. (其他 foundation)

**Justification**: ParticleWrapper 係 leaf-edge dependency (Rule 16 — no save/runtime deps)，但其他 system 喺 startup 期間可能 immediately call `play()` (boot enemy spawn burst 等) — wrapper 必須 ready before them。Position 4 確保 wrapper init 完之前 critical infrastructure (GSM / GymSys / Persistence) 已 done。

**`_ready()` ≤ 80ms on mobile Safari cold boot** (budget):

| Phase | Cost | Notes |
|-------|------|-------|
| `_detect_mobile()` (JS bridge × 1-2) | 5-10ms | cross JS/Wasm bridge call |
| Pool spawn × 16 (GPUParticles2D init) | 20-30ms | empty `emitting=false` |
| 9 preloaded materials cached (`preload(...)` const) | ~0ms | load at .gd parse time, not `_ready` |
| GSM subscription via `connect_for_initial_state` (ADR-006 Contract 6) | <1ms | |
| Optional `_warm_shaders()` (off-screen invisible burst per preset for JIT compile) | 0 or 500-1000ms | enabled iff `SHADER_PREWARM_ENABLED = true`; runs inside loading screen, NOT counted in 80ms budget |
| **Total** | **~60-80ms** | within budget ✓ |

**Booting 期間 `play()` 行為**: `_booted: bool = false` before `_ready` done → return `INVALID` + log warning (defensive — autoload order 理論上保證安全，但 #1/#3 早期 signal handler 可能 fire 早期事件)。

#### Rule 15 — GameStateMachine subscription: drain on Suspended

Wrapper subscribe `GameStateMachine.state_changed` via `connect_for_initial_state` per ADR-006 Contract 6:

```gdscript
GameStateMachine.connect_for_initial_state(_on_gsm_state_changed)

func _on_gsm_state_changed(from: String, to: String, payload: StateTransitionPayload) -> void:
    match to:
        "suspended": _drain()
        # other states = no action (Active service)
```

| GSM State (per `game_state_enum` registry constant) | Wrapper Action |
|---|---|
| `booting` | reject play() per Rule 14 |
| `idle` / `workout_active` / `rest_period` / `combat_active` / `boss_encounter` / `loot_drop` | normal service |
| `suspended` | `_drain()` — set `emitting=false` 所有 emitting node, preserve pool. Mobile Safari background tab throttle requestAnimationFrame，accumulated particles resume 時爆 budget — preventive drain。 |
| `disconnected` | normal service (particles 不依賴網絡) |

**Resume from Suspended**: 下一個 `state_changed(suspended → X)` 觸發 wrapper internal `_resumed_at_ms` reset；無遺留 emitter state need restore (intentional — loss of mid-air combat burst on suspend acceptable per Pillar 2 design)。

#### Rule 16 — Wrapper persists nothing

**No PersistenceLayer (#3) interaction**. Wrapper boot state 永遠由 `PRESETS` const + runtime pool 組成。

Test `tests/unit/particle_wrapper/test_no_persistence_hooks.gd` enforce:
- 無 reference to `PersistenceLayer` instance / autoload path
- 無 `save_*` / `load_*` method existence on wrapper
- 無 `user://` file path reference

PersistenceLayer 只需要 autoload order 先於 wrapper (position 1 before position 12 — F-SYNC-2 sync 2026-05-28)，但係 **boot ordering only, NOT runtime dependency**。Wrapper stateless from persistence perspective。

### States and Transitions

Wrapper **有 internal lifecycle states 但對 gameplay 透明** (caller 唔需要 query state；service API 就係 `play()`)。State 影響 `play()` 既 accept/reject + pool 既 active/dormant 行為。

#### State table

| State | Entry trigger | Exit trigger | `play()` behaviour | Pool behaviour |
|-------|---------------|--------------|-------------------|----------------|
| `Booting` | autoload `_init` | `_ready` done (Rule 14) | return `INVALID`, log warn | pool not yet allocated |
| `Active` | `_ready` end / GSM resume from Suspended | GSM `Suspended` / `_exit_tree` | full service per Rule 1-12 | normal operation |
| `Suspended` | GSM `state_changed(* → suspended)` | GSM `state_changed(suspended → *)` | reject silently (all preset classes uniformly rejected — lifecycle gate precedes Rule 9, no LOOT/combat differentiation in this state) | `_drain()` — all `emitting=false`, pool preserved |
| `Draining` | `_exit_tree()` start | tree exit done | reject silently | iterate pool, force expire all, `queue_free` nodes |

#### Transition diagram

```
[autoload init]
      │
      ▼
   ┌────────┐
   │Booting │
   └───┬────┘
       │ _ready done
       ▼
   ┌─────────┐  ◄── GSM(suspended → X) ── ┌─────────────┐
   │ Active  │                              │  Suspended  │
   │         │ ── GSM(X → suspended) ───►  │  (drained)  │
   │         │                              └─────────────┘
   │         │
   │         │ ── _exit_tree ──────────►   ┌─────────────┐
   └─────────┘                              │  Draining   │
                                            └──────┬──────┘
                                                   │ tree exit done
                                                   ▼
                                                (gone)
```

#### Why not stateless

Stateless design 表面上簡單，但會撞 3 個 bug pattern：

1. **Boot race** — 早期 autoload (#1 / #3) `_ready` 入面 emit signal，#5 未 ready 就 `play()` → NPE 落 pool array
2. **Tab-hide leak** — 無 `Suspended` drain，mobile Safari background tab 既 particle accumulate，resume 一刻爆 budget
3. **Shutdown spam** — 退出時 tree teardown 順序未保證，drain order 亂可能 access 已 `queue_free` 既 node

呢 3 case 全部要 explicit state，所以 stateful — 但 state 純 wrapper internal，caller API 仍然係 stateless service shape。

#### State transitions are atomic and synchronous

State 變更全部 sync，無 intermediate state。`Active → Suspended` 既 `_drain()` 喺 transition handler 入面 inline 跑完先 return — drain ≈ 16 iterations of `emitter.emitting = false`，<0.5ms，no risk of partial state。

### Interactions with Other Systems

所有下游 contract 標 `[PROVISIONAL — confirms when [system] GDD authored]`。Wrapper 唔等下游就 freeze API；下游 GDD 邊到 wrapper assumption 唔啱，submit ADR 改 wrapper (本 GDD 係 source of truth)。

#### #14 EnemyDirector → Wrapper [PROVISIONAL]

**[PROVISIONAL — confirms when #14 EnemyDirector GDD authored]**

| Event | Wrapper call | Position contract |
|-------|--------------|-------------------|
| Enemy take light hit | `play(HIT_LIGHT, hit_global_pos)` | hit collision point, not enemy center |
| Enemy take heavy hit | `play(HIT_HEAVY, hit_global_pos)` | same |
| Enemy parried | `play(PARRY, parry_global_pos)` | weapon clash point |
| Enemy death | `play(DEATH, enemy_global_pos)` | enemy center, post-death pose |
| Enemy ignites | `play(STATUS_BURN, target_feet_pos)` | feet emission (disc radius 8px at feet per Visual Spec) |
| Enemy frozen | `play(STATUS_FREEZE, target_torso_pos)` | torso surround (sphere radius 16px) |
| Enemy stunned | `play(STATUS_STUN, target_head_pos + Vector2(0, -14))` | head offset (orbit ring radius 14px above) |

**Loop status presets**: STATUS_BURN / STATUS_FREEZE / STATUS_STUN 既 baseline 設計成 single per-second burst (preset count = "per second" convention per Visual Spec Table)。EnemyDirector 想 continuous burn effect 要自己 timer trigger `play()` 每 1.0s。Wrapper **唔提供 looping primitive** — 簡化 LRU + budget account。

**Frame budget hint**: EnemyDirector 一個 frame 內最多 `play()` 8 次 (4 enemy × 2 status)。超出由 LRU 處理，唔需要 Director 自己 throttle。

**Accepted worst-case budget overrun**: 8 enemies × HIT_HEAVY (18) + 2 × STATUS_BURN steady (8 avg) + 1 × LOOT_BURST (72) = **224 particles desktop, exceeds 200 cap by 12%** (per Art Director Block D budget check)。**設計決定**：accept overrun + rely on LRU eviction (Rule 8) + telemetry track eviction rate via Rule 9 `_dropped_play_calls` counter。若 session reject rate > 5% → designer retune trigger (knob `MAX_ACTIVE_PARTICLES` 或 preset count 調整)。Mobile worst-case (0.5×) = 112 particles, safe ✓。

#### #21 Loot Drop Modal → Wrapper [PROVISIONAL]

**[PROVISIONAL — confirms when #21 Loot Drop Modal GDD authored]**

| Event | Wrapper call | Notes |
|-------|--------------|-------|
| Modal opens (common drop, white/green/blue tier) | `play(LOOT_BURST, item_world_pos)` | fired same frame as modal-appear animation start |
| Modal opens (rare drop, purple/orange tier) | `play(LOOT_RARE_BURST, item_world_pos)` | per Visual Spec: LOOT_RARE_BURST 只 fire for purple/orange rarity tier |
| Modal closes | (nothing) | particles 自然 fade per preset lifetime (0.9s / 1.6s) |

**Position contract**: `item_world_pos` 係 loot icon 落地時既 world coord，**唔係** modal UI 既 screen coord。Loot Modal 要自己 do reverse projection screen→world。Wrapper 從來唔處理 UI / CanvasLayer particle — preset 全部 `z_index` 喺 world layer (per Rule 13)，但 LOOT_* 嘅 `world_layer = false` flag 喺 Visual Spec 入面表示**唔做 desaturate 30% 處理** (保持完全飽和)。

**Re-trigger guard**: Modal 關完再開 (dismiss then peek again) 唔再 play()。由 Modal 邏輯記低「已 burst 過呢個 drop」flag。

**Pillar 3 priority guarantee**: 即使 wrapper budget 全滿且所有 emitter 都 within `EVICTION_MIN_LIFE_MS = 150ms` floor，LOOT_* incoming 仍可 bypass floor evict 最舊 non-LOOT slot (per Rule 9 LOOT carve-out)。**Loot moment 一定有粒子出**，除非極端 case (16 slot 全部都係 LOOT_* — 實際唔會 hit，LARGE tier 只 2 nodes 故最多 2 個 LOOT 並發)。

#### #25 Combat Visual Feedback → Wrapper [PROVISIONAL]

**[PROVISIONAL — confirms when #25 Combat Visual Feedback GDD authored]**

| Event | Wrapper call | Notes |
|-------|--------------|-------|
| Successful parry window hit | `play(PARRY, weapon_clash_pos)` | duplicate of EnemyDirector path |
| Status apply (burn / freeze / stun) | `play(STATUS_*, target_pos)` | dedup vs EnemyDirector via signal coordination |

**Dedup rule**: EnemyDirector 同 CVF 都會想 trigger 同一個 PARRY burst。**EnemyDirector 唔 call**，CVF 係 owner。EnemyDirector 既 parry signal 由 CVF subscribe，CVF 再 call `wrapper.play()`。呢個由 CVF GDD 寫，wrapper 唔 enforce — wrapper 對重複 play() 既 LRU 處理就係 budget protection。

#### #6 Screen Effects + #1 GameStateMachine ← `burst_started` signal [PROVISIONAL]

**[PROVISIONAL — confirms when #6 Screen Effects GDD authored]**

**Signal signature (locked, per Rule 11)**:
```gdscript
signal burst_started(preset_id: PresetId, position: Vector2)
```

**Subscription pattern** (consumer side):
```gdscript
# Inside #6 Screen Effects autoload _ready():
ParticleSystemWrapper.burst_started.connect(_on_particle_burst)

func _on_particle_burst(preset_id: int, position: Vector2) -> void:
    match preset_id:
        ParticleSystemWrapper.PresetId.HIT_HEAVY:
            shake.kick(intensity=0.4, duration=0.12)
        ParticleSystemWrapper.PresetId.PARRY:
            shake.kick(intensity=0.6, duration=0.08)
            hit_pause.freeze(0.06)
        ParticleSystemWrapper.PresetId.DEATH:
            shake.kick(intensity=0.3, duration=0.18)
        ParticleSystemWrapper.PresetId.LOOT_RARE_BURST:
            shake.kick(intensity=0.2, duration=0.15)
        _:
            pass  # no shake / pause for light hits, status, common loot
```

**Wrapper 唔提供 `connect_for_initial_state()` helper for `burst_started`**: signal payload 簡單 (2 args)，subscriber boot order 由 autoload position 保證 (ParticleSystemWrapper at position 12 before ScreenEffects at position 14 — F-SYNC-2 sync 2026-05-28; was ambiguous `#4 before #6` notation conflating system IDs with autoload positions)。一行 `.connect()` 已足夠，helper 反而增加 surface area。

**(注意：wrapper 自己反向 subscribe `GameStateMachine.state_changed` 時用 ADR-006 Contract 6 helper — 兩個方向不對稱係 intentional：wrapper 對 GSM 係 late subscriber 需要 initial state replay；GSM 對 wrapper 係 implicit downstream consumer，burst events 只 forward-only)**

**Hit-pause timing contract**: subscriber 必須理解 `burst_started` emit 喺 `emitting=true` 之前 (Rule 11)。即係 subscriber freeze `GameStateMachine.timescale → 0` 既 frame，particle 都會喺 paused 狀態出現，hit-pause 同 visual 對齊。**呢個係 contract，唔好 break**。

#### #1 GameStateMachine ← Wrapper subscription

Wrapper 反向 subscribe per ADR-006 Contract 6:
```gdscript
# Inside ParticleSystemWrapper _ready():
GameStateMachine.connect_for_initial_state(_on_gsm_state_changed)
```

Action mapping per Rule 15 state table。Initial state delivery 用 ADR-006 sentinel `payload.source_event == "initial_state"`。

#### #3 PersistenceLayer ↔ Wrapper

**No interaction** (per Rule 16). Test `tests/unit/particle_wrapper/test_no_persistence_hooks.gd` enforce 三條 invariant (無 reference / 無 save load method / 無 user:// path)。

PersistenceLayer 只需要 autoload position 1 行先 wrapper 既 position 12，但 boot ordering only — runtime 無 interaction (F-SYNC-2 sync 2026-05-28; pre-VS draft claimed pos 3 + pos 4).

#### Downstream open questions to confirm later

呢 3 個 question 留畀對應 GDD author 答，wrapper 提供 default：

1. **#14**: Multi-hit combo HIT_LIGHT spam (5-hit combo within 0.5s) — wrapper default 全部 `play()`，LRU 處理 budget。EnemyDirector 想 throttle 要自己加 cooldown。
2. **#21**: Common-vs-rare drop visual differentiation — wrapper default 用 LOOT_BURST vs LOOT_RARE_BURST 既 preset separation (per Visual Spec rarity-tier mapping: white/green/blue → LOOT_BURST，purple/orange → LOOT_RARE_BURST)。
3. **#25**: Parry success vs perfect parry — 暫時 PARRY 一個 preset。若要 perfect parry 視覺特權，新 PresetId 加入 closed library 需要 ADR (locked schema 改動，per Rule 13 CI enforcement)。

## Formulas

### Formula 1 — final_count multiplier composition

呢條係 Particle System Wrapper 嘅 main quantity formula — 將 preset base count 經三層 multiplier (loot privilege、mobile downscale、caller hint) composite 出 emitter 實際要 spawn 嘅粒子數量。Multiplier 嘅 **apply order matters**：先 loot、再 mobile、最後 caller，係因為 (a) loot 屬於 preset-class privilege (上游 design intent)，(b) mobile 屬於 device-class downscale (中游 hardware concession)，(c) caller 屬於 per-call hint (下游 micro-adjust)。三者順序對應 ownership tier：design → platform → call site。`round()` 喺所有 multiply 之後先做一次，避免中間 truncation 累積誤差。

The `final_count` formula is defined as:

`final_count = clamp(round(preset.count × loot_mult × mobile_mult × caller_mult), 1, 256)`

Apply order (固定，不可重排):
1. `preset.count` — base lookup from `PRESET_TABLE` (Rule 13)
2. `× loot_mult` — loot-class privilege multiplier
3. `× mobile_mult` — mobile downscale
4. `× caller_mult` — caller hint (已喺 Rule 1 clamp 過)
5. `round()` — GDScript built-in `round()`，half-away-from-zero
6. `clamp(_, 1, 256)` — final guard

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Preset base count | `preset.count` | int | [4, 48] | 由 `PRESET_TABLE[preset_id].count` lookup (Rule 13 closed enum, 9 preset entries) |
| Loot multiplier | `loot_mult` | float | {1.0, 3.0} | `3.0` 當 `preset_id ∈ {LOOT_BURST, LOOT_RARE_BURST}`，否則 `1.0` (Pillar 3 Drop Euphoria privilege) |
| Mobile multiplier | `mobile_mult` | float | {0.5, 1.0} | `0.5` 當 `_is_mobile == true`，否則 `1.0` (web mobile fillrate concession) |
| Caller multiplier | `caller_mult` | float | [0.1, 1.5] | 由 Rule 1 caller validation 預先 clamp，formula 假設 input 已在範圍 |
| Final emitter count | `final_count` | int | [1, 256] | Emitter `amount` 屬性實際設定值 |

**Output Range:** `[1, 256]` (integer)，clamp 兩端強制。
- **Ceiling (256)** — Hard cap，防止任何 future preset / caller combo 意外炸 GPU。當 `intermediate > 256` (clamp 啟動) 必須 trigger `push_warning("[Particles] final_count ceiling clamp engaged: preset=%s intermediate=%d" % [preset_id, intermediate])` — 呢個係 design-time signal，indicate PRESET_TABLE 或 caller 用法走偏。
- **Floor (1)** — 永遠唔會 emit 0 粒子。若 caller 用 `0.1` × mobile `0.5` × tiny preset (e.g. STATUS base=4) → intermediate `0.2` → `round()` = `0` → clamp 拉返 `1`。Pillar 3 invariant：feedback 一定要有 visible particle，即使 minimum burst。
- **Rounding** — `round()` half-away-from-zero (GDScript built-in，非 banker's rounding)，確保 `4.5 → 5`、`0.5 → 1`，避免 floor=0 issue。

**`push_warning` triggers:**
- `intermediate > 256` — ceiling clamp 啟動 (design budget exceeded)
- `caller_arg ∉ [0.1, 1.5]` — 呢個 warning 由 Rule 1 caller validation 處理，formula 本身假設 `caller_mult` 已 clamp，故唔重複 emit

**Worked Examples:**

| # | Scenario | preset.count | loot_mult | mobile_mult | caller_mult | intermediate | final_count |
|---|---|---|---|---|---|---|---|
| 1 | Desktop HIT_LIGHT | 8 | 1.0 | 1.0 | 1.0 | 8.0 | **8** |
| 2 | Mobile HIT_HEAVY | 18 | 1.0 | 0.5 | 1.0 | 9.0 | **9** |
| 3 | Desktop LOOT_BURST | 24 | 3.0 | 1.0 | 1.0 | 72.0 | **72** |
| 4 | Mobile LOOT_BURST | 24 | 3.0 | 0.5 | 1.0 | 36.0 | **36** |
| 5 | Desktop LOOT_RARE_BURST | 48 | 3.0 | 1.0 | 1.0 | 144.0 | **144** |
| 6 | Desktop LOOT_RARE_BURST + caller=1.5 | 48 | 3.0 | 1.0 | 1.5 | 216.0 | **216** |
| 7 (BOUNDARY) | Hypothetical preset.count=64 + LOOT_RARE + caller=1.5 | 64 | 3.0 | 1.0 | 1.5 | 288.0 | **256** (ceiling clamp + `push_warning`) |
| 8 (BOUNDARY) | Mobile STATUS minimum + caller=0.1 | 4 | 1.0 | 0.5 | 0.1 | 0.2 → round=0 | **1** (floor clamp，never emit 0) |

**Pillar 3 sanity check — LOOT/HIT visual ratio:**
- Desktop: `LOOT_BURST(72) ÷ HIT_LIGHT(8) = 9.0×`
- Mobile: `LOOT_BURST(36) ÷ HIT_LIGHT(4) = 9.0×`

Loot 視覺特權喺 desktop 同 mobile 都 maintain **9× ratio**，即係 player 喺任何 platform 都會感受到 loot moment 嘅 visual weight 明顯壓過普通 hit feedback。呢個係 Visual Identity Anchor 嘅 compliance check — 將來如果調 `loot_mult` 或 `mobile_mult` 必須重新驗證呢個 ratio 喺 ≥ 6× 以上 (game-concept Pillar 3 governance)。

---

### Formula 2 — is_floor_protected (eviction guard predicate)

呢條係 `_try_evict()` 內每個 candidate slot 嘅 protection check — 決定一個 active particle slot 喺 `EVICTION_MIN_LIFE_MS` floor 期間係咪可以被 evict。Hybrid carve-out (Rule 9) 嘅核心：**LOOT request 可以 bypass floor 去 evict non-LOOT**，但 **LOOT slot 永遠唔比 LOOT evict** (Pillar 3 hard invariant)。

The `is_floor_protected` formula is defined as:

```
is_floor_protected(age_ms, preset_id, is_loot_request) -> bool:
  if age_ms >= EVICTION_MIN_LIFE_MS:
    return false
  if not is_loot_request:
    return true
  if preset_id in {LOOT_BURST, LOOT_RARE_BURST}:
    return true
  return false
```

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Slot age | `age_ms` | int | [0, ∞) | `Time.get_ticks_msec() - slot.spawn_time_ms`，候選 eviction target 已存活毫秒數 |
| Slot preset id | `preset_id` | PresetId (enum) | 9-value closed enum | 候選 slot 嘅 preset identity (HIT_LIGHT, HIT_HEAVY, PARRY, DEATH, STATUS_BURN, STATUS_FREEZE, STATUS_STUN, LOOT_BURST, LOOT_RARE_BURST) |
| Loot request flag | `is_loot_request` | bool | {true, false} | 當前發起 emit 嘅 request 係咪 LOOT 類 (即 `requested_preset_id ∈ {LOOT_BURST, LOOT_RARE_BURST}`) |
| Eviction floor constant | `EVICTION_MIN_LIFE_MS` | int | 150 (fixed) | 見 Section G Tuning Knobs — `150ms` floor 防止 mid-spawn visual cut |
| Protected? | `is_floor_protected` | bool | {true, false} | `true` = skip 呢個 candidate；`false` = 可以 evict |

**Truth Table:**

| `age_ms` | `is_loot_request` | `slot.preset_id ∈ LOOT_*` | `is_floor_protected` | Notes |
|---|---|---|---|---|
| ≥ 150 | * | * | **false** | Over floor — 任何 request 都可 evict |
| < 150 | false | false | **true** | Non-LOOT request 尊重 floor on 所有 slot |
| < 150 | false | true | **true** | Non-LOOT request 尊重 floor (兼且 LOOT slot 額外受 Pillar 3 invariant 保護) |
| < 150 | true | false | **false** | **LOOT carve-out** — LOOT request bypass floor 去 evict non-LOOT |
| < 150 | true | true | **true** | **LOOT-never-evicts-LOOT** (Rule 9 invariant，Pillar 3 hard guarantee) |

**Output Range:** `bool`。`true` → caller (`_try_evict()` loop) 必須 skip 呢個 candidate；`false` → candidate 可入 eviction pool，由 LRU (oldest `spawn_time_ms` first) 排序揀。

**Worked Examples:**

1. **80ms-old HIT_LIGHT slot, LOOT_BURST request** → `age < 150`, `is_loot_request = true`, slot 唔係 LOOT → `false` → **可以 evict** (LOOT carve-out 啟動)
2. **80ms-old HIT_LIGHT slot, HIT_HEAVY request** → `age < 150`, `is_loot_request = false` → `true` → **不可 evict** (non-LOOT 尊重 floor，`_try_evict()` 失敗 → clean reject + `push_warning`)
3. **80ms-old LOOT_BURST slot, LOOT_RARE_BURST request** → `age < 150`, `is_loot_request = true`, slot 係 LOOT → `true` → **不可 evict** (Pillar 3 invariant — LOOT 永不被 LOOT 取代，clean reject)
4. **200ms-old LOOT_BURST slot, 任何 request** → `age ≥ 150` → `false` → **可以 evict** (over floor，無論 request type)

**Rationale (why 150ms):** Section C Rule 8 已論證 — `150ms ≈ 9 frames @ 60fps`，剛好足夠 player peripheral vision register 一個 burst event (peripheral 1s 安全 window 嘅下限)。`< 100ms` 太短，loot mid-spawn 會被切到視覺 incomplete；`> 300ms` 太長，combat heavy frame (連續多 hit) 會令 LRU pool 經常空，eviction 失敗率上升。150ms 係 visibility-vs-throughput 嘅平衡點。

---

### Formula 3 — needs_eviction (overflow predicate)

Trivial predicate，喺 `play()` 入口 — 計完 `final_count` (Formula 1) 之後、allocate emitter 之前判斷係咪要 call `_try_evict()`。

The `needs_eviction` formula is defined as:

`needs_eviction(active_total, final_count) = (active_total + final_count) > MAX_ACTIVE_PARTICLES`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Active particle ledger | `active_total` | int | [0, MAX_ACTIVE_PARTICLES] | `_active_particle_total` ledger 當前值；Rule 6 容許 ±15% over-estimate drift (ledger 保守 ≥ 實際 GPU count) |
| New burst count | `final_count` | int | [1, 256] | 由 Formula 1 計出嘅新 emitter `amount` |
| Budget cap constant | `MAX_ACTIVE_PARTICLES` | int | 200 (fixed) | 見 Section G — 200 active particle hard ceiling (game-concept governance + ADR-001) |
| Need eviction? | `needs_eviction` | bool | {true, false} | `true` → call `_try_evict(final_count)` before alloc；`false` → 直接 alloc emitter |

**Output Range:** `bool`。Inequality 係 strict `>` (非 `≥`) — `active_total + final_count == 200` 仍然 OK (剛好填滿)；`201` 先 trigger eviction。

**Worked Examples:**

1. `active_total = 120, final_count = 72` (Desktop LOOT_BURST) → `192 > 200` → `false` → **唔需要 evict**，直接 alloc
2. `active_total = 180, final_count = 72` → `252 > 200` → `true` → **需要 evict ≥ 52 個 particle**，call `_try_evict(72)`
3. `active_total = 200, final_count = 1` → `201 > 200` → `true` → **boundary case**，即使 minimum burst (Formula 1 floor=1) 喺 budget cap 都要 trigger eviction

**Note on ledger drift (Rule 6 interaction):** `_active_particle_total` ±15% over-estimate 嘅含意係 — 實際 GPU 上 active 粒子可能 ≤ 200 (ledger 高估)，但 `needs_eviction` 用 ledger 值就會比實際更早 trigger eviction。呢個係 **intentional ceiling-not-average enforcement**：寧可保守過早 evict (極少 visual hiccup)，都唔可以 under-count 令 GPU 真正爆 200 (per-frame draw call spike)。Rule 6 嘅 drift budget 同 Formula 3 嘅 strict `>` 一齊保證 budget 係 **hard ceiling**，唔係 soft target。

## Edge Cases

### Edge Case 1 — _ready exceeds 80ms boot budget

**If** wrapper `_ready()` 期間 (Rule 14 boot budget) `Time.get_ticks_msec() - _boot_start_ms >= 80` 喺 pool prebuild loop 內部命中: Abort 同步 prebuild，切換 lazy-init mode。具體：
- 每完成一個 tier 既 prebuild check budget；命中 → 剩低 tier 唔再預建
- `_booted = true` 照樣 set (wrapper accept `play()` requests)
- 第一個 lazy tier 既 `play()` trigger `_ensure_tier(tier_id)`，consume ~5-15ms first-frame jank
- Engine log: `[ParticleWrapper] boot_budget_overrun: completed_tiers=%d remaining=%d` (debug-only)

**Rationale**: 80ms 係 Web Export cold-start ceiling，超咗寧願 trade 一次 lazy jank 都好過 block boot。Lazy fallback 保 wrapper API contract 唔變，caller 完全無感。

---

### Edge Case 2 — LARGE tier exhausted, 3rd LOOT incoming, both floor-protected

**If** LARGE tier 2 nodes 全 active 且兩個都 `is_floor_protected = true` (Formula 2 — `age_ms < 150 && slot.preset_id ∈ LOOT_*`)，第 3 個 LOOT_BURST / LOOT_RARE_BURST request 入嚟: Reject silently，return `INVALID` handle，**NOT emit `burst_started`** (Rule 11 ghost-shake guard)。

具體:
- `needs_eviction = true` (LARGE tier 滿)
- `_try_evict()` 遍歷 LARGE candidates → 全部 `is_floor_protected = true` (Rule 9 LOOT-never-evicts-LOOT invariant)
- `_dropped_play_calls += 1` (Rule 9 telemetry counter)
- `push_warning` throttled per Rule 9 (`WARNING_THROTTLE_MS = 1000ms`)

**Rationale**: Pillar 3 hard invariant — LOOT 從不被 LOOT replace。LARGE tier 2 nodes + 兩個 LOOT 既 150ms 同 frame 並發係極罕 timing race，accept 第 3 個無 burst 換 budget integrity。

---

### Edge Case 3 — `navigator.userAgent` returns non-string

**If** `JavaScriptBridge.eval("navigator.userAgent", true)` 返回 `null` / `undefined` / non-`TYPE_STRING`: `_is_mobile = true` (MOBILE conservative per Rule 10 FR-3)。

具體:
- `if typeof(ua_var) != TYPE_STRING: push_warning(...) ; return true`
- Use MOBILE multiplier (Formula 1 `mobile_mult = 0.5`)

**Rationale**: Detect 失敗時揀低-budget 路線係 fail-safe direction — over-emit 喺 mobile 會掉 frame (Pillar 2 violation)，under-emit 喺 desktop 只係少啲 particle (acceptable visual downgrade)。對齊 Rule 10 + FR-3 invariant。

---

### Edge Case 4 — iPad reporting Mac UA without touch capability

**If** UA contains `macintosh` + `navigator.maxTouchPoints == 0` (real Mac OR rare iPad with touch hardware disabled): Classify as DESKTOP per Rule 10 detect table。

**Rationale**: Touch absent 既 iPad input model 等同 desktop (鍵盤+觸控板)，iPad Pro GPU 足以 handle DESKTOP budget。Edge case install base 細到可忽略 (acceptable miscategorization)。

---

### Edge Case 5 — `JavaScriptBridge.eval` 喺 non-Web export

**If** `OS.has_feature("web") == false` (desktop editor playtest / native standalone build): Skip JavaScriptBridge call entirely → `_is_mobile = false` (DESKTOP)。

具體:
- Rule 10 detect logic 第一步 `if not OS.has_feature("web"): _is_mobile = false; return`
- 永遠唔 touch `JavaScriptBridge.eval` (喺 non-web 會 push_warning + return null)

**Rationale**: Editor playtest + native standalone 都係 dev 環境，DESKTOP budget 啱睇 full visual fidelity for iteration。對齊 Rule 10 fallback chain。

---

### Edge Case 6 — Signal handler synchronous re-entry into `play()`

**If** `burst_started` signal handler 內部直接 call `wrapper.play(...)` (synchronous re-entry，e.g. #6 Screen Effects 觸發鏈鎖 effect): Queue 入 `_deferred_plays` array per Rule 12 re-entry guard，由 frame-end `_flush_deferred()` drain。

具體:
- `play()` 入口 check `if _emit_depth > 0: ... _deferred_plays.append({...}); return pending`
- Pending handle 返畀 caller，`_pool_index = -1` 標記 (caller 通常 fire-and-forget，唔 hold reference)
- `_flush_deferred()` 透過 `call_deferred` 喺 `_process` end 重 call `_execute_play()`

**Rationale**: 拒絕 re-entry 會令 #6 / #25 既 chain effect 隨機消失。Queue 落同 frame end 既 ~0ms latency imperceptible，但保證 deterministic 行為。對齊 Rule 12。

---

### Edge Case 7 — 16 slot 全部係 LOOT (theoretical)

**If** 理論上 request 出現 16 個 concurrent LOOT bursts: Unreachable in production — LARGE tier 只 2 nodes (Rule 4 pool config locked)，所以同時 active LOOT 上限永遠 ≤ 2。任何第 3 個 LOOT 入嚟既 request 行 Edge Case 2 既 reject path。

**Rationale**: Documented for completeness only — pool sizing 既 hard cap 物理上禁止呢個 state。若 future GDD 改 LARGE tier size，呢個 case 要重新 evaluate (escalate trigger)。

---

### Edge Case 8 — `Suspended → Suspended` 重複 transition

**If** GSM emit `state_changed` 帶 `new_state = "suspended"` 但 wrapper 內部 `_lifecycle_state` 已經係 `Suspended`: Idempotent — `_drain()` 安全重 call。

具體:
- `_on_gsm_state_changed()` 唔做 `if old == new: return` early exit (保 idempotency)
- `_drain()` loop iterates 所有 pool nodes set `emitting=false`; 第 2 次 call 時所有 node 已 set，effectively no-op
- `_active_particle_total` 喺 ledger expire callback 既 `max(0, total - n)` 保護下唔會 underflow

**Rationale**: GSM `connect_for_initial_state` pattern (ADR-006 Contract 6) 會 emit synthetic initial state，可能 race 入真實 transition → 重複 Suspended 唔可預防，必須 idempotent。對齊 Rule 15 state table。

---

### Edge Case 9 — `_exit_tree` during active emit

**If** wrapper `_exit_tree()` 觸發時仲有 N 個 active emitters (Rule 15 `Draining` state entry): Force-expire + queue_free，唔等 natural lifetime。

具體:
- `_lifecycle_state = Draining` (Rule 15 entry)
- `play()` reject: `if _lifecycle_state == Draining: return INVALID` (no signal, no log)
- For each pool node across all tiers: `emitter.emitting = false`; cancel 對應 ledger expire timer (avoid Rule 6 timer leak); `node.queue_free()`
- `_active_particle_total = 0`

**Rationale**: Scene teardown 必須 deterministic，唔可以 leak timer 入 SceneTree。Force-expire cut 緊 visual 但 `_exit_tree` contract 就係 immediate cleanup。對齊 Rule 15 Draining state spec。

---

### Edge Case 10 — SMALL tier exhausted, 9th HIT_LIGHT incoming, all 8 floor-protected

**If** 8 個 HIT_LIGHT 同一 frame 內 fire (e.g. AOE attack hits 8 enemies)，SMALL tier 8 nodes 全 active 且全部 `age_ms < 150` (`is_floor_protected = true` per Formula 2)，第 9 個 HIT_LIGHT 入嚟: Reject silently，return `INVALID`，**NOT emit `burst_started`** (ghost-shake guard per Rule 11)。

具體:
- `is_loot_request = false` (HIT_LIGHT) → Formula 2 truth table row 2 → 所有 8 candidates `is_floor_protected = true` → no victim
- 視覺結果: 8 enemies 有 hit particle，第 9 個 enemy 無 — acceptable 1-frame burst spike degradation
- `_dropped_play_calls += 1`

**Rationale**: SMALL tier 8 nodes 已係 generous budget (8-enemy AOE)，9+ concurrent same-frame 係 design outlier — AOE design 應該 cap target count。Floor 150ms 保證 8 個 hit feedback 可見，第 9 個 invisible 比 evict mid-anim hit (causing pop) 視覺上 acceptable。對齊 Formula 2 + 3。

---

### Edge Case 11 — Booting → Active 之間 GSM `state_changed` arrives

**If** wrapper `_ready()` 仲未 set `_booted = true` (仲喺 prebuild loop)，GSM 透過 `connect_for_initial_state` 觸發 synthetic initial-state emit: Buffer the state event，apply after boot completes。

具體:
- Wrapper 既 `_on_gsm_state_changed(old, new, source_event)`: `if not _booted: _pending_initial_state = new; _pending_source_event = source_event; return`
- `_ready()` 末段 (boot complete): `_booted = true`; if `_pending_initial_state != null`: call `_on_gsm_state_changed(...)` 重 dispatch
- 期間任何 `play()` call 被 reject (Rule 14 `_booted == false` hard gate)

**Rationale**: 雖然 autoload boot order 保證 (#1 GSM < #4 wrapper)，但 GSM `connect_for_initial_state` synthetic emit 喺 wrapper `.connect()` 嗰刻 fire — 可能落入 wrapper `_ready()` 中段 (pool prebuild 同 `.connect()` 之間)。Buffer 模式比 race window 設計安全。對齊 Rule 14 + ADR-006 Contract 6 sentinel pattern。

---

### Edge Case 12 — Active → Suspended transition 期間收到 `play()`

**If** GSM `state_changed(active, suspended)` handler 既 `_drain()` loop 中段，caller 同 frame 之後 sync call `play()`: Reject the `play()` call。

具體 (no new marker flag — reuse `_lifecycle_state` directly):
- Transition handler 入口**第一行** set `_lifecycle_state = Suspended` (在 `_drain()` loop 之前)
- `play()` 入口 check `if _lifecycle_state in [Booting, Suspended, Draining]: return INVALID` — 自動 reject
- Drain loop 後續無需新 flag

**Rationale**: 將 state transition atomic — set state BEFORE side-effect (drain) 確保任何 mid-transition incoming call 自動 reject。比新增 `_in_transition: bool` flag 簡單，無 name collision (Rule 15 `Draining` state 仍 reserved for `_exit_tree`)。對齊 Rule 12 既 critical-section spirit。

---

### Edge Case 13 — Screen Effects connect 早過 wrapper boot (autoload race) — ACCEPTED Rule 11 amendment

**If** future refactor 將 ScreenEffects autoload position (currently 14) 改至 < ParticleSystemWrapper position (currently 12) — i.e., subscriber boots BEFORE wrapper — 或 subscriber 喺 `_init()` 內 (而非 `_ready()` 內) call `.connect()`: `.connect()` 會 NPE on null wrapper signal (F-SYNC-2 sync 2026-05-28; was ambiguous `#6 ... < #4` notation)。

**Mitigation (Rule 11 amendment)**: Wrapper expose idempotent helper:

```gdscript
func request_burst_started_connect(c: Callable) -> void:
    if _booted:
        burst_started.connect(c)
    else:
        _pending_connects.append(c)

# In _ready() end (after _booted = true):
for c in _pending_connects:
    burst_started.connect(c)
_pending_connects.clear()
```

具體 contract:
- Helper caller 喺 wrapper 未 ready 時 buffer，wrapper boot 完成 drain
- 現階段 autoload position 12 (wrapper) < position 14 (ScreenEffects) boot order 保證下，直接 `.connect()` 都 work (F-SYNC-2 sync 2026-05-28)
- Helper 純粹 future-proof — 推薦但唔 mandate (一行 `.connect()` 仍 acceptable)

**Rationale**: Autoload order 係 fragile 約定。提供 helper API 將 connect timing 從 caller 責任變 wrapper 責任，對齊 ADR-006 Contract 6 既 decouple-from-publisher-boot-timing semantic。**Rule 11 補充記錄**: signal payload 不變 (`burst_started(preset_id, position)`)；新加 1 helper public method，總 API surface = `play()`、`stop()` (on handle)、`burst_started` (signal)、`request_burst_started_connect(callable)`。

---

### Edge Case 14 — GSM `initial_state` sentinel match fall-through

**If** GSM `connect_for_initial_state` callback 收到 `source_event == "initial_state"` (ADR-006 Contract 6 sentinel)，wrapper Rule 15 state transition match 表無顯式 handle 此 source: Fall-through to general state-apply — treat as direct transition to `new_state`，跳過 drain animation。

具體:
- `_on_gsm_state_changed(from, to, payload)`: `if payload.source_event == "initial_state": _apply_state_direct(to); return`
- `_apply_state_direct(state)`: set `_lifecycle_state = state` 但唔 trigger `_drain()` (initial state 本來就無 prior emitter to drain)
- 等同 boot-time silent sync — wrapper align with GSM 既 current state，無 side effect

**Rationale**: `initial_state` sentinel 本質係 sync 而非 transition，唔應該觸發 drain。Fall-through to silent apply 對齊 ADR-006 Contract 6 既「subscriber 用嚟 align state，唔係 react to user action」semantic。

---

### Edge Case 15 — Ledger drift causing permanent over-budget reject — ACCEPTED Rule 6 amendment

**If** 某個 ledger expire callback 失敗 fire (e.g. node `queue_free` 提前 → timer orphaned → ledger decrement 永遠唔行)，`_active_particle_total` 永久偏高 → 終於 > `MAX_ACTIVE_PARTICLES` → wrapper 永久 reject 所有 incoming `play()`: Periodic ledger reconcile via `_process()` (every 2 seconds)。

具體 (Rule 6 safety net amendment):
- Wrapper hold: `var _ledger_reconcile_accumulator: float = 0.0`
- `_process(delta)`: `_ledger_reconcile_accumulator += delta; if _ledger_reconcile_accumulator >= 2.0: _reconcile_ledger(); _ledger_reconcile_accumulator = 0.0`
- `_reconcile_ledger()`: walk all 16 pool nodes, for each node currently `emitting == true OR (Time.get_ticks_msec() - node._spawn_time_ms) < node._lifetime_ms` accumulate `count`; set `_active_particle_total = sum`
- 任何 ledger drift (高或低) 每 2 秒自動 self-heal

**Rationale**: Web Export 環境下 Godot timer reliability 唔係 100% (tab background throttle、GC pause、bfcache restore)，ledger 純依賴 timer callback decrement 係 fragile。2-second reconcile 既 cost 細 (walk 16 nodes ~微秒級)，但保證 wrapper 唔會 brick。對齊 Rule 6 既 leak prevention spirit。**Rule 6 補充記錄**: ledger 仍 primary maintained by O(1) incremental update (per `play()` + per expire callback)，reconcile loop 純粹 safety net，唔取代主邏輯。

---

### Edge Case 16 — Material hot-swap pre-first-frame race (WebGL 2 async pipeline)

**If** `acquire()` 內部 `process_material = PRESET_TABLE[preset_id].material` hot-swap 後即時 `restart(false)` + `emitting = true`，但 WebGL 2 async shader compile / texture upload pipeline 仲未 bind 新 material: 第 1 frame burst 可能 render 用前一 preset 既舊 material (visual artifact)。

具體 mitigation:
- Wrapper acquire path: `process_material = ...; node.restart(false); call_deferred("_begin_emit", node)`
- `_begin_emit(node)`: `node.emitting = true`
- Trade-off: caller 收到 `handle` valid，但 visual 出現延遲 1 frame (~16.6ms @ 60fps)
- 對 HIT / LOOT / STATUS 類 short burst：1-frame delay imperceptible
- `burst_started.emit` 時序維持 Rule 11 contract — emit AFTER allocation BEFORE `emitting=true`，即 emit 喺 `call_deferred` 之前 (`burst_started.emit(...)` 緊接 `restart(false)` 之後，唔 defer)

**Rationale**: WebGL 2 driver state 同 Godot CPU-side state 之間有 implicit pipeline barrier，hot-swap 後 same-frame emit 係已知 race。1-frame defer 係 cheapest fix，唔影響 `burst_started` signal timing (consumer #6 / #25 仍 receive sync emit，唔覺得有 desync)。對齊 Rule 4 hot-swap + Rule 11 signal timing。

---

### Edge Case 17 — Resume from Suspended: mid-air emitter age_ms validity

**If** wrapper 進入 Suspended (Rule 15) 時某 emitter `spawn_time_ms = T₀, lifetime = 400ms`，suspended at `T₀+200ms`，Suspended 持續 wall-clock 5 秒後 resume → Active，pool node 內部 `_spawn_time_ms` 是否 stale: Non-issue — Rule 15 `Suspended` entry 嘅 `_drain()` 已 force-release 所有 active nodes，resume 時 pool 全空 free。

具體:
- Suspended entry 既 `_drain()` 已 `emitter.emitting = false` + cancel ledger timer + release back to free list
- Pool node 既 `_spawn_time_ms` 喺 next `acquire()` 時 overwrite (`= Time.get_ticks_msec()`)
- LRU eviction floor (`EVICTION_MIN_LIFE_MS = 150ms` per Formula 2) 永遠基於 fresh post-resume spawn time
- Wall-clock 跨 Suspended 既 stale state 不存在

**Rationale**: Suspended `_drain()` 既根本性 reset 確保「mid-air emitter 跨 suspend」physically 不存在。對齊 Rule 15 + Formula 2 age_ms 計算 invariant。

---

### Edge Case 18 — [PROVISIONAL — confirms when #21 Loot Drop Modal GDD authored] 重複觸發 same drop

**If** [PROVISIONAL — confirms when #21 GDD authored] #21 Loot Drop Modal 用「dismiss → peek again」pattern 對同一 drop 重複 trigger burst (e.g. player tap-close 後再 tap-open 同一 loot card): Wrapper 視每次 `play()` call 為 independent burst，**無 dedup logic**。

具體:
- 第 1 次 `play(LOOT_BURST, pos)` acquires LARGE tier node A
- Dismiss 期間 node A 仍 emit / lifecycle 中 (or 已 release back to pool depending on timing)
- 第 2 次 `play(LOOT_BURST, pos)` acquires LARGE tier node B (or 重用 A if released + LRU re-pick)
- 兩次 burst 視覺重疊 (acceptable — loot card 視覺加強)
- 第 3 次 budget overflow → 行 Edge Case 2 reject path

**Rationale**: Wrapper 唔知 caller 既「dismiss/peek 邏輯」existence — dedup 屬 caller responsibility (#21 GDD 要決定係咪 throttle 自己既 burst trigger，e.g. flag `_already_burst_for_drop_id: bool`)。Wrapper 維持 stateless-per-call contract 簡單可預測。Provisional 因 #21 GDD 未寫。

---

### Edge Case 19 — [PROVISIONAL — confirms when #14 EnemyDirector GDD authored] HIT_LIGHT chained combo bursts

**If** [PROVISIONAL — confirms when #14 GDD authored] #14 Combat 設計連擊每 hit fire `HIT_LIGHT`，玩家達到 9-hit combo 喺 1 秒內: SMALL tier 8 nodes pool + 150ms floor 之下，第 9 hit 既 fate 取決於 combo timing。

具體:
- **If hit interval > 150ms**: 每個 hit 既前一 burst 已過 floor → LRU 可 evict → 第 9 hit 視覺正常 emit
- **If hit interval < 150ms** (rapid attack pattern): 第 9 hit 時前 8 hits 全 floor-protected → reject (Edge Case 10 path)
- Wrapper 唔做 combo-aware special handling — 純粹 same `play()` reject contract

**Rationale**: Combo cadence 由 #14 GDD 決定。如果 cadence < 150ms 同時要求每 hit visual feedback，#14 應該用 separate preset (e.g. `HIT_COMBO` with MEDIUM tier larger budget) 而唔係依賴 wrapper 改 floor。Provisional 因 #14 GDD 未寫。

## Dependencies

### Upstream Dependencies

**(none)** — Particle System Wrapper 係 Foundation leaf-edge。不依賴任何 game system runtime data。

唯一 runtime infrastructure 依賴 (NOT a Foundation peer dep but engine/ADR-level):
- **Godot 4.6 GPUParticles2D + ParticleProcessMaterial** (engine, locked per `docs/engine-reference/godot/VERSION.md`)
- **WebGL 2 / Compatibility renderer** (per project technical-preferences.md — Web Export primary target)
- **`JavaScriptBridge` API** (engine — Web Export only; non-Web export gracefully degrades per Edge Case 5)

### Boot-Order-Only Dependency

| System | Why required | Runtime interaction |
|---|---|---|
| **#3 PersistenceLayer** (autoload position 1 — F-SYNC-2 sync 2026-05-28, was claimed pos 3) | Boot ordering only — wrapper position 12 must be ≥ position 1 to ensure foundation infra ready when later autoloads init | **None** — Rule 16 + `tests/unit/particle_wrapper/test_no_persistence_hooks.gd` enforce zero runtime interaction (no reference to PersistenceLayer, no save/load methods, no `user://` paths) |

### Downstream Dependents (5 systems)

每個 downstream 都係 **hard dependency** (downstream system 無 wrapper 就無 particle effects)，但 wrapper API 對 downstream 係 **fire-and-forget** — wrapper 唔 require downstream presence to function (Foundation invariant)。

| # | System | Layer/Tier | Hard/Soft | Data Interface (wrapper → downstream / downstream → wrapper) |
|---|---|---|---|---|
| **#14** | EnemyDirector | Core / VS | **Hard** (combat 無 particle = combat 無 feedback) | downstream → wrapper: `play(HIT_LIGHT/HIT_HEAVY/PARRY/DEATH/STATUS_*, world_pos)` per Section C #14 interaction contract |
| **#21** | Loot Drop Modal | Presentation / Pre-MVP | **Hard** (Pillar 3 signature — modal 開但無 particle = ritual 不完整) | downstream → wrapper: `play(LOOT_BURST/LOOT_RARE_BURST, item_world_pos)` per Section C #21 interaction contract |
| **#25** | Combat Visual Feedback | Presentation / MVP | **Hard** (parry / status apply 無 particle = combat clarity 下降) | downstream → wrapper: `play(PARRY/STATUS_*, target_pos)` per Section C #25 interaction contract; dedup vs #14 via CVF owning the call site |
| **#6** | Screen Effects System | Foundation / VS | **Soft** (subscriber pattern — wrapper functions without #6 attached) | wrapper → downstream: `burst_started(preset_id, position)` signal; downstream → wrapper: `request_burst_started_connect(callable)` registration helper (per EC13 Rule 11 amendment) |
| **#1** | Game State Machine | Foundation / VS | **Soft** (wrapper subscribes; functions without GSM transitions but loses Suspended drain optimization) | downstream → wrapper: `GameStateMachine.state_changed(from, to, payload)` signal; wrapper subscribes via `connect_for_initial_state` (ADR-006 Contract 6); action per Rule 15 state table |

### Provisional Downstream (interface confirmed when each GDD authored)

Per Section C 既 `[PROVISIONAL — confirms when #X GDD authored]` mark — wrapper API 係 **source of truth**，downstream GDD 邊到 wrapper assumption 唔啱，submit ADR 改 wrapper：

- **#14 EnemyDirector** — final preset list per enemy archetype; combo-burst handling (Edge Case 19 path)
- **#21 Loot Drop Modal** — common-vs-rare preset mapping (white/green/blue → LOOT_BURST，purple/orange → LOOT_RARE_BURST per Visual Spec Table); dismiss-then-peek dedup (Edge Case 18 caller responsibility)
- **#25 Combat Visual Feedback** — perfect parry preset (if needed) — new `PresetId` enum value requires ADR per Rule 13

### Governing ADRs

| ADR | Status | Relationship to wrapper |
|---|---|---|
| **ADR-001** Godot Web Export Budget Caps | Not yet authored — wrapper GDD 係 **input scope** | Ratifies `MAX_ACTIVE_PARTICLES = 200`、`MOBILE_FALLBACK_MULTIPLIER = 0.5`、per-device measured caps、WebGL 2 feature detection; Player Fantasy FR-1/2/3 ratification gate-binding |
| **ADR-005** Loot Rarity Formula | Not yet authored | Influences LOOT_BURST vs LOOT_RARE_BURST preset selection mapping (鎖在 #15 Loot Drop System GDD 時 confirm) |
| **ADR-006** State Machine Contract | **Ratified 2026-05-25** (Status: Proposed) | Contract 6 inherited — wrapper uses `connect_for_initial_state(callable)` helper for GSM subscription; sentinel `payload.source_event == "initial_state"` handling per Rule 15 + Edge Case 14 |

### Bidirectional Sync Requirements

呢個 section 既 contracts MUST be reflected back when each dependent's GDD is authored. Per `.claude/rules/design-docs.md` "Dependencies must be bidirectional":

| When this GDD is authored | Must add to its Dependencies section |
|---|---|
| **#14 EnemyDirector** | "**#5 Particle System Wrapper** (hard) — calls `play(HIT_*/STATUS_*/DEATH)` for combat VFX per #5 Section C interaction contract" |
| **#21 Loot Drop Modal** | "**#5 Particle System Wrapper** (hard) — calls `play(LOOT_BURST/LOOT_RARE_BURST)` for Pillar 3 signature burst per #5 Section C interaction contract; dismiss/peek dedup caller responsibility per #5 Edge Case 18" |
| **#25 Combat Visual Feedback** | "**#5 Particle System Wrapper** (hard) — calls `play(PARRY/STATUS_*)` for combat clarity feedback per #5 Section C interaction contract; owns dedup vs #14 EnemyDirector" |
| **#6 Screen Effects System** | "**#5 Particle System Wrapper** (soft subscriber) — subscribes to `burst_started(preset_id, position)` via `request_burst_started_connect(callable)` helper per #5 Edge Case 13 Rule 11 amendment" |
| **#1 Game State Machine** | (already authored, Approved 2026-05-25) — when next revised, add to Dependents list: "**#5 Particle System Wrapper** subscribes via `connect_for_initial_state`; Suspended state triggers `_drain()` per #5 Rule 15" |

### Failure Mode Matrix

| Failure | Impact | Wrapper's compensation |
|---|---|---|
| #14 EnemyDirector absent / not yet authored | No combat particles | Wrapper service unaffected; pool sits idle |
| #21 Loot Drop Modal absent | No LOOT_BURST triggered | LOOT presets unused but pool LARGE tier still allocated (acceptable VRAM waste during VS) |
| #25 absent | No PARRY / status particles via CVF path | #14 can directly call wrapper as fallback (caller responsibility per Section C interaction notes) |
| #6 Screen Effects absent / fails to subscribe | No shake / hit-pause on burst | Wrapper still emits particles + signal; signal goes uncaught (acceptable, signal pattern is fire-and-forget) |
| #1 GSM absent / no Suspended transition emitted | No drain on background tab | Particles accumulate during background; on resume LRU + budget cap catch up — Pillar 2 mild degradation but not catastrophic |
| #3 PersistenceLayer absent | Boot order broken | Wrapper still boots (no runtime dep per Rule 16); but global game broken upstream |

## Tuning Knobs

呢度列明所有 wrapper-owned designer-tunable constants。每個 knob 有 default value + safe range + 對 gameplay/perf 既具體影響。

**Knob ownership rule**: 所有 knob 都係 const at GDScript level (`const KNOB_NAME := value` in wrapper source)，**唔係** runtime mutable。改動要 (a) code change + redeploy，OR (b) data-driven 變 `@export var` 並由 #28 Telemetry 觸發 retune (post-MVP enhancement)。

### Owned Knobs

#### G.1 — Budget caps (ADR-001 ratification gate-binding)

| Knob | Default | Safe Range | Source | What breaks |
|---|---|---|---|---|
| `MAX_ACTIVE_PARTICLES` | `200` | `100..400` (per-device measured by ADR-001) | game-concept hard governance §8 + Formula 3 | Below 100: combat heavy frame (8 enemies × HIT_HEAVY = 144) 永久 reject — Pillar 2 violation。Above 400: mobile Safari fillrate exceeded — Pillar 2 violation。 |
| `MOBILE_FALLBACK_MULTIPLIER` | `0.5` | `0.3..0.7` | Rule 10 + Formula 1 | Below 0.3: mobile loot bursts (24×3×0.3=22 particles) 視覺 weak — Pillar 3 9× ratio compliance fail。Above 0.7: 接近 desktop budget，mobile fillrate jank。 |
| `LOOT_BURST_MULTIPLIER` | `3.0` | `2.0..4.0` | Rule 7 + Formula 1 | Below 2.0: Pillar 3 LOOT/HIT ratio drops below 6× sanity check (Formula 1 sanity check 鎖死)。Above 4.0: LOOT_RARE_BURST desktop = 48×4=192 single burst 接近 cap — 連續 2 LOOT impossible without eviction。 |
| `MAX_CALLER_MULTIPLIER` | `1.5` | `1.2..2.0` | Rule 1 + Formula 1 | Below 1.2: caller emphasize 機制過弱 — boss-kill loot 同 normal loot 視覺無差。Above 2.0: LOOT_RARE caller=2.0 = 48×3×2=288 → Formula 1 ceiling clamp 永久觸發，knob 失效。 |

**⚠ ADR-001 ratification gate-binding**: 呢 4 個 knob 既 final values + per-device measured cap 必須喺 ADR-001 ratify Status: Accepted 時 lock。Player Fantasy FR-1 invariant 必須驗證 `MAX_ACTIVE_PARTICLES = X` 喺 mobile Safari P95 frame time ≤ 16.6ms。

#### G.2 — Pool sizing + lifecycle (Rule 4 + Rule 14)

| Knob | Default | Safe Range | Source | What breaks |
|---|---|---|---|---|
| `POOL_SIZE_SMALL` | `8` | `4..16` | Rule 4 (8-enemy AOE assumption) | Below 4: AOE frequent reject (Edge Case 10 path 高頻)。Above 16: VRAM waste；only useful if AOE design 變更。 |
| `POOL_SIZE_MEDIUM` | `6` | `4..10` | Rule 4 (HIT_HEAVY + PARRY + DEATH + mobile LOOT_BURST 共用) | Below 4: heavy combat moments (multiple enemy deaths) frequent reject。Above 10: redundant if MAX_ACTIVE_PARTICLES unchanged。 |
| `POOL_SIZE_LARGE` | `2` | `2..4` | Rule 4 (concurrent LOOT cap) | Cannot go below 2 (Pillar 3 invariant — must support 1 LOOT_RARE_BURST + 1 LOOT_BURST concurrent for boss-kill + chest-open coincidence)。Above 4: VRAM waste — LARGE tier 接近 0.5MB/node。 |
| `AMOUNT_BUFFER_SMALL` | `32` | (fixed; locked) | Rule 4 | DO NOT TUNE — Godot `amount` setter trigger GPU buffer realloc (Rule 5)。Change requires Rule 5 reroute redesign。 |
| `AMOUNT_BUFFER_MEDIUM` | `96` | (fixed; locked) | Rule 4 | DO NOT TUNE — same as above。 |
| `AMOUNT_BUFFER_LARGE` | `256` | (fixed; locked) | Rule 4 + Formula 1 ceiling | DO NOT TUNE — must match Formula 1 `clamp(_, 1, 256)` ceiling。 |
| `MAX_BOOT_BUDGET_MS` | `80` | `60..120` | Rule 14 + Edge Case 1 | Below 60: lazy-init fallback (Edge Case 1) 永久觸發 — first-burst jank 變慣性。Above 120: mobile Safari TTI 受影響 (Pillar 2 silent violation)。 |
| `SHADER_PREWARM_ENABLED` | `true` | `{true, false}` | Rule 14 + Edge Case 16 | If false: first-burst per preset 第 1 frame 可能 visual artifact (Edge Case 16 path 一次性 cost)。If true: boot consumes 500-1000ms inside loading screen (acceptable trade for first-impression clean visuals)。 |

#### G.3 — Eviction policy (Rule 8 + Formula 2)

| Knob | Default | Safe Range | Source | What breaks |
|---|---|---|---|---|
| `EVICTION_MIN_LIFE_MS` | `150` | `100..250` | Rule 8 + Formula 2 rationale | Below 100: loot mid-spawn 被切到視覺 incomplete (peripheral capture fantasy 失敗)。Above 250: combat heavy frame LRU 無 victim available → reject rate 升 → `_dropped_play_calls / total > 5%` trigger telemetry retune warning。 |
| `WARNING_THROTTLE_MS` | `1000` | `500..5000` | Rule 9 + Edge Case 2/10 | Below 500: log spam during normal combat reject。Above 5000: real budget issues (e.g. consistent 5%+ reject rate) get hidden — debug 痛苦。 |

#### G.4 — Ledger telemetry (Rule 6 + Edge Case 15)

| Knob | Default | Safe Range | Source | What breaks |
|---|---|---|---|---|
| `LEDGER_EXPIRE_SAFETY_MS` | `50` | `20..100` | Rule 6 | Below 20: GPU 粒子仲 alpha-fade 緊 ledger 已 expire → ±15% drift 變 negative drift (under-count)。Above 100: ledger 過長 hold expired entries → memory creep + over-budget reject rate 升。 |
| `LEDGER_RECONCILE_INTERVAL_S` | `2.0` | `1.0..5.0` | Edge Case 15 Rule 6 amendment | Below 1.0: `_process` overhead noticeable on mobile (walk 16 nodes × N times/sec)。Above 5.0: brick recovery delay too long — wrapper 永久 reject window 達 5 秒玩家可感知。 |
| `DROP_RATE_TELEMETRY_THRESHOLD` | `0.05` (5%) | `0.02..0.10` | Rule 9 telemetry trigger | Below 2%: noisy false positives (single bad combat frame trigger retune)。Above 10%: actual budget issues 漠視。 |

#### G.5 — Caller validation (Rule 1)

| Knob | Default | Safe Range | Source | What breaks |
|---|---|---|---|---|
| `CALLER_MULTIPLIER_MIN` | `0.1` | `0.05..0.3` | Rule 1 + Formula 1 boundary | Below 0.05: `caller_mult × mobile × small preset = sub-1 round → floor=1` 永久觸發，knob 失效。Above 0.3: caller intent 「淡化」效果範圍縮窄。 |
| `MAX_CALLER_MULTIPLIER` | `1.5` | `1.2..2.0` | (already in G.1) | (see G.1) |

### Knob Interaction Warnings

呢啲 invariant 喺 tuning 時必須維持：

1. **Pillar 3 9× ratio invariant** (Formula 1 sanity check):
   ```
   (LOOT_BURST.count × LOOT_BURST_MULTIPLIER × MOBILE_FALLBACK_MULTIPLIER) ÷
   (HIT_LIGHT.count × MOBILE_FALLBACK_MULTIPLIER) ≥ 6.0
   ```
   調 `LOOT_BURST_MULTIPLIER` 必須重新驗證。

2. **Single-LOOT-burst-fits-budget invariant**:
   ```
   LOOT_RARE_BURST.count × LOOT_BURST_MULTIPLIER × MAX_CALLER_MULTIPLIER ≤ AMOUNT_BUFFER_LARGE
   ```
   即 `48 × 3 × 1.5 = 216 ≤ 256` ✓。如 `LOOT_BURST_MULTIPLIER` 升 `4.0` → `48 × 4 × 1.5 = 288 > 256` → Formula 1 ceiling clamp 永久觸發。

3. **Concurrent-2-LOOT-fits-budget invariant** (Pillar 3 boss-kill + loot-chest coincidence):
   ```
   2 × LOOT_BURST.count × LOOT_BURST_MULTIPLIER × MOBILE_FALLBACK_MULTIPLIER ≤ MAX_ACTIVE_PARTICLES × 0.8
   ```
   即 desktop: `2 × 24 × 3 × 1.0 = 144 ≤ 200 × 0.8 = 160` ✓。確保 2 LOOT 並發仍留 20% combat headroom。

4. **Boot budget invariant**:
   ```
   POOL_SIZE_SMALL × ~3ms + POOL_SIZE_MEDIUM × ~3ms + POOL_SIZE_LARGE × ~5ms +
     JS_DETECT_MS (~10ms) ≤ MAX_BOOT_BUDGET_MS
   ```
   即 `8×3 + 6×3 + 2×5 + 10 = 62ms ≤ 80ms` ✓。調 `POOL_SIZE_*` 任一 + `MAX_BOOT_BUDGET_MS` ↓ → Edge Case 1 lazy fallback 觸發 frequency 升。

5. **Eviction-floor-vs-warning-throttle invariant**:
   ```
   WARNING_THROTTLE_MS ≥ EVICTION_MIN_LIFE_MS × 5
   ```
   即 `1000ms ≥ 150 × 5 = 750ms` ✓。確保 warning 唔會 spam 過 floor 多 burst window。

### Tuning Knob Reference Map (where each knob is used)

| Knob | Section C | Section D | Section E | Section H (planned) |
|---|---|---|---|---|
| `MAX_ACTIVE_PARTICLES` | Rule 6, Rule 8 trigger | Formula 3 | Edge Case 2, 10, 15 | AC-budget-cap-enforcement |
| `MOBILE_FALLBACK_MULTIPLIER` | Rule 7, Rule 10 | Formula 1 | Edge Case 3, 4, 5 | AC-mobile-fallback |
| `LOOT_BURST_MULTIPLIER` | Rule 7 | Formula 1 (sanity check) | — | AC-loot-ratio-Pillar-3 |
| `MAX_CALLER_MULTIPLIER` | Rule 1 | Formula 1 | — | AC-caller-validation |
| `EVICTION_MIN_LIFE_MS` | Rule 8 | Formula 2 | — | AC-LRU-eviction-floor |
| `POOL_SIZE_*` / `AMOUNT_BUFFER_*` | Rule 4, Rule 5 | — | Edge Case 7, 10 | AC-pool-tier-routing |
| `MAX_BOOT_BUDGET_MS` | Rule 14 | — | Edge Case 1 | AC-boot-budget |
| `SHADER_PREWARM_ENABLED` | Rule 14 | — | Edge Case 16 | AC-prewarm-flag |
| `LEDGER_*` | Rule 6 | — | Edge Case 15 | AC-ledger-reconcile |
| `WARNING_THROTTLE_MS` | Rule 9 | — | Edge Case 2, 10 | AC-log-throttle |
| `DROP_RATE_TELEMETRY_THRESHOLD` | Rule 9 | — | — | AC-telemetry-trigger |
| `CALLER_MULTIPLIER_MIN` | Rule 1 | Formula 1 boundary | — | AC-caller-floor |

### Knobs Owned by Other Systems (NOT this GDD)

- **Loot rarity tier → preset selection mapping** — owned by #15 Loot Drop System GDD + ADR-005
- **GymSys polling rate / fallback timeouts** — owned by #2 GymSys Backend Client GDD
- **`STATE_TRANSITION_FALLBACK_MS`** — owned by #1 Game State Machine GDD
- **Per-device performance budgets** — owned by ADR-001 (post-VS measured)

## Visual/Audio Requirements

### Visual Spec Table — 9 Presets

| preset_id | base_count | tier | lifetime_s | emission_shape | shape_param | spread_deg | direction | velocity_min/max (px/s) | gravity | drag | scale_curve | color_ramp | texture | z_index | screen_space | special_visual_intent |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `HIT_LIGHT` | 8 | SMALL | 0.25 | `EMISSION_SHAPE_POINT` | n/a | 35 | `Vector3(0, -1, 0)` 偏上 | (90, 140) | `Vector3(0, 60, 0)` | 0.25 | `[(0.0, 0.5), (0.2, 0.9), (1.0, 0.0)]` | `[(0.0, Color(1, 1, 1, 1.0)), (0.4, Color(0.85, 0.92, 1, 0.9)), (1.0, Color(0.7, 0.8, 1, 0))]` | `res://assets/vfx/textures/spark_sharp.png` | 5 | false | 短促銀白火星 — 普通輕擊嘅 neutral feedback |
| `HIT_HEAVY` | 18 | MEDIUM | 0.40 | `EMISSION_SHAPE_SPHERE` | radius=6px | 120 | `Vector3.ZERO` 放射 | (140, 220) | `Vector3(0, 140, 0)` | 0.35 | `[(0.0, 0.6), (0.15, 1.3), (0.6, 1.0), (1.0, 0.0)]` | `[(0.0, Color(1, 0.95, 0.85, 1.0)), (0.3, Color(1, 0.55, 0.25, 0.95)), (1.0, Color(0.4, 0.15, 0.1, 0))]` | `res://assets/vfx/textures/spark_chunk.png` | 5 | false | 厚重橘紅碎片爆散 — 重擊撞擊感 |
| `PARRY` | 14 | MEDIUM | 0.35 | `EMISSION_SHAPE_RING` | radius=10px, inner_radius=8px | 360 | `Vector3.ZERO` 環向 | (180, 240) | `Vector3.ZERO` | 0.55 | `[(0.0, 1.1), (0.2, 1.4), (1.0, 0.0)]` | `[(0.0, Color(1.4, 1.4, 1.4, 1.0)), (0.3, Color(0.7, 0.95, 1.0, 0.95)), (1.0, Color(0.3, 0.6, 0.9, 0))]` | `res://assets/vfx/textures/spark_streak.png` | 5 | false | 環狀冷白衝擊波 — 防禦成功既高反差 ping |
| `DEATH` | 28 | MEDIUM | 0.65 | `EMISSION_SHAPE_SPHERE` | radius=4px | 180 | `Vector3.ZERO` 全向 | (60, 180) | `Vector3(0, 220, 0)` | 0.20 | `[(0.0, 0.4), (0.25, 1.2), (0.8, 0.8), (1.0, 0.0)]` | `[(0.0, Color(0.85, 0.8, 0.75, 1.0)), (0.4, Color(0.55, 0.5, 0.5, 0.85)), (1.0, Color(0.2, 0.2, 0.25, 0))]` | `res://assets/vfx/textures/dust_soft.png` | 5 | false | 灰白塵霧加碎片 — 敵人解體既終結感 |
| `STATUS_BURN` | 4 | SMALL | 0.30 | `EMISSION_SHAPE_BOX` | extent=(6, 8, 0) | 15 | `Vector3(0, -1, 0)` 上升 | (40, 80) | `Vector3(0, -60, 0)` | 0.15 | `[(0.0, 0.4), (0.5, 0.9), (1.0, 0.0)]` | `[(0.0, Color(1, 0.6, 0.2, 0.9)), (0.5, Color(1, 0.3, 0.1, 0.8)), (1.0, Color(0.4, 0.1, 0, 0))]` | `res://assets/vfx/textures/ember_soft.png` | 4 | false | 細小橘紅餘燼向上飄 — 持續燃燒嘅 ambient loop |
| `STATUS_FREEZE` | 5 | SMALL | 0.45 | `EMISSION_SHAPE_SPHERE` | radius=10px | 360 | `Vector3.ZERO` | (10, 30) | `Vector3(0, 30, 0)` | 0.70 | `[(0.0, 0.3), (0.4, 0.7), (1.0, 0.0)]` | `[(0.0, Color(0.85, 0.95, 1, 0.9)), (0.5, Color(0.55, 0.8, 1, 0.75)), (1.0, Color(0.3, 0.5, 0.85, 0))]` | `res://assets/vfx/textures/crystal_shard.png` | 4 | false | 慢速懸浮冰晶 — 凍結既靜態 crystalline 感 |
| `STATUS_STUN` | 6 | SMALL | 0.50 | `EMISSION_SHAPE_RING` | radius=12px, inner_radius=11px | 360 | `Vector3.ZERO` 環繞 | (30, 50) | `Vector3.ZERO` | 0.40 | `[(0.0, 0.5), (0.5, 0.8), (1.0, 0.0)]` | `[(0.0, Color(1, 0.95, 0.5, 0.9)), (0.5, Color(1, 0.85, 0.3, 0.85)), (1.0, Color(0.6, 0.5, 0.2, 0))]` | `res://assets/vfx/textures/star_simple.png` | 4 | false | 頭頂環繞既黃色小星 — 經典 stun 視覺語言 |
| `LOOT_BURST` | 24 (×3 = 72/36) | LARGE / MEDIUM | 0.90 | `EMISSION_SHAPE_SPHERE` | radius=8px | 360 | `Vector3(0, -1, 0)` 偏上放射 | (160, 260) | `Vector3(0, 280, 0)` | 0.30 | `[(0.0, 0.7), (0.2, 1.4), (0.7, 1.1), (1.0, 0.0)]` | `[(0.0, Color(1.3, 1.3, 1.1, 1.0)), (0.3, Color(0.6, 1.0, 0.7, 0.95)), (0.7, Color(0.3, 0.8, 0.5, 0.85)), (1.0, Color(0.2, 0.5, 0.3, 0))]` | `res://assets/vfx/textures/spark_round.png` | 7 | false | 噴泉式綠白火花拋物線下落 — Common-Uncommon drop 既「值得睇」基線 |
| `LOOT_RARE_BURST` | 48 (×3 = 144/72) | LARGE | 1.60 | `EMISSION_SHAPE_RING` | radius=14px, inner_radius=10px | 360 | `Vector3.ZERO` 環向加上拋 | (120, 320) | `Vector3(0, 160, 0)` | 0.18 | `[(0.0, 0.8), (0.15, 1.7), (0.5, 1.5), (0.85, 1.0), (1.0, 0.0)]` | `[(0.0, Color(1.5, 1.4, 1.6, 1.0)), (0.25, Color(0.85, 0.55, 1.0, 0.95)), (0.6, Color(0.6, 0.4, 1.0, 0.9)), (0.85, Color(1.0, 0.65, 0.3, 0.85)), (1.0, Color(0.6, 0.3, 0.2, 0))]` | `res://assets/vfx/textures/spark_streak.png` | 7 | false | 雙環紫橘漸變綻放 + 長尾條紋 — Rare+ drop 既「cap 圖朋友圈」signature moment |

> **Color value 註**: 部分 ramp keypoint 既 RGB > 1.0 (e.g. `Color(1.3, 1.3, 1.1, 1.0)`) 係刻意 HDR overbright — 配合 Godot 4.6 glow rework，畀 LOOT 既起爆 frame 喺 bloom pass 突出，呼應 Visual Identity Anchor 既「乾淨剪影 + 骯髒粒子」對比。

---

### Visual Focus Blocks

#### 1. FR-2 distinguishability (LOOT_BURST vs LOOT_RARE_BURST)

兩者**唔可以**只係 count 翻倍 — 否則 peripheral glance 下玩家會覺得「啱啱嗰嚿應該係 Rare 啊？定係 Common 但近啲？」。所以四個 axis 全部分開：(1) **Color** — `LOOT_BURST` 用 white → green → 深綠 (rarity philosophy 既 Common-Uncommon band)，`LOOT_RARE_BURST` 用 white → 紫 → 深紫 → 橘 collapse (Rare-Epic-Legendary band 既 purple/orange 既濃縮預告)；(2) **Emission shape** — burst 用 sphere 點狀放射，rare 用 ring 雙環綻放，silhouette 明顯唔同；(3) **Scale curve peak** — burst peak `1.4` @ t=0.2，rare peak `1.7` @ t=0.15 並維持 `1.5` 到 t=0.5，rare 既「大 + 持續」感 1 秒內讀得到；(4) **Lifetime** — 0.90s vs 1.60s，rare 既長尾條紋係識別 anchor。四 axis 同時偏移就算 peripheral vision 都唔會撈亂。

#### 2. Combat hierarchy (HIT_LIGHT < HIT_HEAVY < PARRY < DEATH)

四個 preset 形成 escalation ladder，每級 visual weight 都至少 2× 上一級可感知差異：`HIT_LIGHT` 8 粒短促銀白 spark 0.25s — 純 feedback noise，唔搶 attention；`HIT_HEAVY` 18 粒橘紅 chunk 0.40s + 球狀放射 — 暖色 + 質感破碎暗示「打到肉」；`PARRY` 14 粒環狀冷白衝擊波 1.4× peak scale — 唯一用 ring shape 既 combat preset，silhouette 獨特，玩家見到就知「啱啱嗰下係 parry」；`DEATH` 28 粒全向灰塵 0.65s + 重力下沉 — 唯一用 desaturated 灰白 palette 既 combat preset，配合最長 lifetime，視覺上「事件已完結」既終結 punctuation。四個 preset 一齊出現都唔會撈亂，因為每個都 own 唯一既 (shape × color band × lifetime) tuple。

#### 3. Status readability (STATUS_BURN / STATUS_FREEZE / STATUS_STUN)

三個 status loop 都係 SMALL tier 細粒，但用**完全唔同既 motion language** 等玩家唔需要讀 tooltip：`STATUS_BURN` 既 box emission + 負 gravity 形成「火苗向上飄」既 ember 上升流，配橘紅 ramp，呼應現實燃燒既物理直覺；`STATUS_FREEZE` 既 sphere emission + 極低 velocity (10-30 px/s) + 高 drag (0.70) 形成「冰晶懸浮唔郁」既靜態 crystalline 感，配冷藍 ramp，speed 本身就係 readability cue (「凍 = 慢」)；`STATUS_STUN` 既 ring emission + 360° 環繞既 motion 直接借用世界級 cartoon 既「頭頂轉星星」visual idiom — 黃色小星 + ring path 係 universal 既 stun shorthand，玩家見到 0.5 秒內讀得到。三個 status 同時 stack 喺一個敵人身上都因為 motion profile 完全分離而唔會視覺撞車。

#### 4. Pillar 3 budget sanity check

Desktop `LOOT_RARE_BURST` = 144 particles，mobile = 72 particles — 兩個數值都係刻意「踩到 frame budget 邊緣但唔越界」既設定。配合 art-bible 既 white → purple → orange rarity color philosophy 既 collapse、HDR overbright keypoint (>1.0 RGB) 喺 bloom pass 既起爆 frame、1.7× peak scale 既「過大」瞬間 + 1.60s 既長尾條紋，呢個 preset 既設計 brief 就係：玩家 drop Rare+ 嘅一刻會**反射性想 screenshot**。Visual Identity Anchor 既「乾淨剪影 + 骯髒粒子」喺呢度體現為「平時 minimal 既戰鬥場景突然爆出 144 粒紫橘狂歡」既反差。Formula 1 sanity check 鎖死 LOOT_BURST 視覺權重 ≥6× HIT_LIGHT，但實際比例（按 count × lifetime × peak scale 估計）desktop 接近 18×，刻意 over-deliver 確保 Drop Euphoria pillar 永遠唔會被 combat noise 蓋過。

---

### Audio Direction (Co-Trigger Contract Only)

Wrapper 嚴格 own particles only，**唔 own SFX** — 呢個係 Foundation infra 分職 SRP 既硬規矩 (#4 Audio Manager 會 own 整個 audio 域)。但 `burst_started(preset_id: PresetId, position: Vector2)` signal 係 wrapper 對外既 single co-trigger contract：#4 Audio Manager subscribe 呢個 signal，按 `preset_id` lookup 對應 audio cue，喺**同一個 frame** 同 particle burst 同步出聲，達到 visual-audio crunch perception。設計建議畀 audio team：每個 `preset_id` 應該對應**唯一一個** audio cue (1-to-1 mapping)，e.g. `HIT_HEAVY` → impact thump、`PARRY` → metallic ping、`LOOT_RARE_BURST` → 短 fanfare chord、`STATUS_BURN` → low crackle loop。Rule 13 既 closed-enum 規矩同樣適用 audio side — 將來加新 preset 必須**同步**喺 audio bank 加新 cue，否則會出現 silent burst，呢個應該係 CI check 既一條 rule (preset enum diff → audio bank diff parity)。

---

📌 **Asset Spec** — Visual/Audio requirements are defined. After the art bible is approved, run `/asset-spec system:particle-system-wrapper` to produce per-asset visual descriptions, dimensions, and generation prompts from this section.

## UI Requirements

**N/A — Particle System Wrapper 唔 own 任何 UI surface**。

### Rationale

呢個 wrapper 係 Foundation infrastructure (per systems-index.md Layer = Foundation)，純粹 own world-layer GPU particles。具體：

- **All particles 喺 world layer，不喺 UI layer**: Visual/Audio Spec Table 9 個 preset 全部 `z_index` 喺 4-7 range (world layer per art-bible Layer Discipline)；全部 `screen_space=false`。
- **No CanvasLayer interaction**: Wrapper 唔 spawn 任何 `GPUParticles2D` 到 `CanvasLayer` 樹下 — 所有 pool node 喺 `_ready()` `add_child()` 到 wrapper autoload (default world scene tree)。
- **No HUD / menu / overlay integration**: Wrapper 唔接收 `mouse_entered` / `gui_input` / focus / theme 等 UI events；唔 expose 任何 `Control` node API；唔 reference `theme` resource。

### UI surfaces owned by 其他 GDD

| UI surface | Owner | Relationship to wrapper |
|---|---|---|
| Loot drop modal animation + card layout | **#21 Loot Drop Modal GDD** | Modal triggers `wrapper.play(LOOT_BURST/LOOT_RARE_BURST, item_world_pos)` per Section F bidirectional sync; modal UI itself (card design, dismiss button, peek state) entirely owned by #21 |
| Combat HUD (health bars, damage numbers) | **#20 Gym-Mode HUD GDD** | HUD does NOT subscribe to wrapper signals; combat feedback particles 喺 world layer underneath HUD |
| Character screen / inventory | **#22 Character Screen + #23 Inventory UI GDDs** | No interaction with wrapper |
| Settings menu (particle quality toggle) | **NOT IMPLEMENTED** in MVP — wrapper knobs (per Section G) 係 const，唔 expose 畀玩家 tune |

### Implications for `/ux-design`

當 #21 Loot Drop Modal 或 #25 Combat Visual Feedback 喺 Pre-Production 階段 author UX spec 時 (per skill recommendation: "Run `/ux-design` to create a UX spec for each screen or HUD element this system contributes to **before** writing epics")：

- UX spec **唔需要** reference 呢個 wrapper GDD 既 UI section (因為 wrapper 唔 own UI)
- UX spec **需要** reference Visual/Audio Requirements section 既 preset Visual Spec Table — 用嚟協調 modal animation timing 同 particle burst 既 visual coincidence (e.g. `LOOT_RARE_BURST` lifetime 1.60s 要 align modal card flip animation duration)
- UX spec 內既 particle integration 描述應該係 `"#5 Particle System Wrapper triggered via play(LOOT_BURST, pos) — see #5 Visual Spec Table for preset visual signature"` 而唔係重複描述粒子行為

## Acceptance Criteria

### AC-01 — `play()` API contract + ParticleHandle sync return

**GIVEN** ParticleWrapper autoload 已 initialized (Active state)，並且呼叫 `play(PresetId.HIT_LIGHT, Vector2(100, 100), 1.0)`，**WHEN** 同步立即檢查返回值，**THEN** 返回一個 valid `ParticleHandle` (RefCounted, `alive() == true`, `_generation > 0`)，且 caller frame 內無 GPU emit blocking (測量 call duration < 1ms)。

**Source**: Rule 1 + Rule 2 + Rule 3
**Test Type**: Logic
**Gate**: BLOCKING
**Test file path**: `tests/unit/particle_wrapper/test_play_api_handle_contract.gd`

實作 note: Fixture 需 stub GPU emit 為 no-op；assert `handle.get_class() == "ParticleHandle"`、`handle._generation` strictly monotonic increasing across consecutive `play()` calls。

---

### AC-02 — `play()` input validation (NaN reject + multiplier clamp)

**GIVEN** ParticleWrapper Active，**WHEN** 呼叫 `play(PresetId.HIT_LIGHT, Vector2(NAN, 100), 1.0)` 或 `play(PresetId.HIT_LIGHT, Vector2(0, 0), 9999.0)`，**THEN** 第一個 call 返回 `ParticleHandle.INVALID` (NaN position rejected)，第二個 call multiplier 被 clamp 到 `MAX_CALLER_MULTIPLIER = 1.5` + emit `push_warning`，且 `burst_started` signal 都唔會喺 reject case emit。

**Source**: Rule 1 + Rule 11 (ghost-shake guard)
**Test Type**: Logic
**Gate**: BLOCKING
**Test file path**: `tests/unit/particle_wrapper/test_play_input_validation.gd`

實作 note: Parameterised test — Vector2(NAN, 0), Vector2(0, NAN), Vector2(INF, 0), multiplier values [0.05, 0.1, 1.0, 1.5, 1.51, 100.0]. Assert clamp boundary inclusive at 0.1 / 1.5。

---

### AC-03 — Object pool size + tier split invariant

**GIVEN** ParticleWrapper 完成 `_ready()`，**WHEN** inspect internal pool 結構，**THEN** total node count == 16，split 為 SMALL=8 / MEDIUM=6 / LARGE=2，且 9 個 ParticleProcessMaterial resources 已 preloaded (`PRESETS.size() == 9`)，每個 tier 嘅 amount buffer 分別為 32 / 96 / 256。

**Source**: Rule 4
**Test Type**: Logic
**Gate**: BLOCKING
**Test file path**: `tests/unit/particle_wrapper/test_pool_structure_invariant.gd`

實作 note: Reflection-style access via `get("_pool_small")` etc.；assert const values from `ParticleSystemWrapper.POOL_TIER_COUNTS`。

---

### AC-04 — Tier selection algorithm by `amount` (no runtime realloc)

**GIVEN** ParticleWrapper Active，**WHEN** 呼叫 `play()` final_count 落入 [1..32] / [33..96] / [97..256] 三個 range，**THEN** 分別 acquire SMALL / MEDIUM / LARGE tier 嘅 pool node，且 acquired node 嘅 `amount` property 已喺 boot 時 set，runtime 期間從未被 reassign (assert via spy on `amount` setter — call count == 0 post-boot)。

**Source**: Rule 5
**Test Type**: Logic
**Gate**: BLOCKING
**Test file path**: `tests/unit/particle_wrapper/test_tier_selection_no_realloc.gd`

實作 note: Parameterised final_count = [1, 32, 33, 96, 97, 256]；spy 用 Godot signal proxy 或 monkey-patch setter。

---

### AC-05 — CPU ledger O(1) incremental update + ±15% drift tolerance

**GIVEN** ParticleWrapper Active 並有 N 個 active particles tracked in `_ledger`，**WHEN** 連續觸發 50 次 `play()` + natural particle expiry sequence，**THEN** ledger update 每次係 O(1) (no full iteration — assert via profiler hook call count == 50, NOT 50*N)，且 ledger value 對比 ground-truth full scan 嘅 drift 維持喺 ±15% 之內。

**Source**: Rule 6
**Test Type**: Logic
**Gate**: BLOCKING
**Test file path**: `tests/unit/particle_wrapper/test_ledger_incremental_drift.gd`

實作 note: Ground-truth helper `_debug_full_scan_count()` 唔可以喺 production code path call；deterministic seeded particle lifetime via mock RNG。

---

### AC-06 — Formula 1 multiplier composition (canonical worked examples)

**GIVEN** Section D Formula 1 既 8 個 canonical worked examples (e.g. Mobile LOOT_BURST: `preset.count=24, loot_mult=3.0, mobile_mult=0.5, caller_mult=1.0`)，**WHEN** 對每個 case 呼叫 `play(preset_id, pos, caller_mult)` 喺對應 platform context，**THEN** final_count exact match Section D table (Mobile LOOT_BURST = `clamp(round(24×3.0×0.5×1.0), 1, 256) == 36`)。

**Source**: Rule 7 + Formula 1
**Test Type**: Logic
**Gate**: BLOCKING
**Test file path**: `tests/unit/particle_wrapper/test_formula_composition_order.gd`

實作 note: 必須 parameterised test 驗證全部 8 個 GDD Section D worked examples (data table)；assert apply order matters per LOCKED multiplier sequence (loot → mobile → caller)。

---

### AC-07 — Formula 1 clamp boundaries [1, 256]

**GIVEN** Section D Formula 1 boundary examples #7 + #8: 假設 preset.count=64 + loot+caller max = `intermediate 288` (above ceiling)，OR preset.count=4 + mobile + caller=0.1 = `intermediate 0.2 round 0` (below floor)，**WHEN** compute final_count，**THEN** 第一個 case clamp 到 ceiling 256 + `push_warning` emit ("[Particles] final_count ceiling clamp engaged")；第二個 case clamp 到 floor 1 (never emit 0)。

**Source**: Formula 1 boundary
**Test Type**: Logic
**Gate**: BLOCKING
**Test file path**: `tests/unit/particle_wrapper/test_formula_clamp_boundaries.gd`

實作 note: Boundary value test — 屬於 coding-standards.md exception case (numeric boundary IS the point)。Spy on `push_warning` for ceiling case。

---

### AC-08 — LRU eviction age-only + 150ms floor protection

**GIVEN** active pool 已滿 (`_active_particle_total + final_count > MAX_ACTIVE_PARTICLES = 200`)，且最舊 particle age = 100ms，第二舊 age = 200ms，**WHEN** 新 non-LOOT `play()` 嚟到觸發 `_try_evict()`，**THEN** evict 第二舊 (age 200ms > `EVICTION_MIN_LIFE_MS=150ms`)，第一舊 (100ms) 受 floor protection；evicted particle 設為 `emitting=false` (NOT `restart()` / NOT `queue_free()`)，保留 natural fade。

**Source**: Rule 8 + Formula 2
**Test Type**: Logic
**Gate**: BLOCKING
**Test file path**: `tests/unit/particle_wrapper/test_lru_age_floor_protection.gd`

實作 note: Mock `Time.get_ticks_msec()` for deterministic age；spy on evicted node assert `emitting == false` AND no `restart()` call。

---

### AC-09 — Hybrid LOOT carve-out: LOOT bypasses floor for non-LOOT victims

**GIVEN** active pool 飽和，所有 active particles age < 150ms (全部 floor-protected per Formula 2)，但其中 6 個係 HIT_LIGHT，2 個係 LOOT_BURST，**WHEN** 新 LOOT_RARE_BURST `play()` 嚟到，**THEN** evict 一個 HIT_LIGHT (`is_floor_protected = false` per Formula 2 truth table row 4 — LOOT carve-out)；2 個 LOOT slot 受保護 unchanged (row 5 — LOOT-never-evicts-LOOT)；新 LOOT request 成功 acquire；`burst_started.emit(LOOT_RARE_BURST, ...)`。

**Source**: Rule 9 + Formula 2
**Test Type**: Logic
**Gate**: BLOCKING
**Test file path**: `tests/unit/particle_wrapper/test_loot_carve_out_eviction.gd`

實作 note: Setup active set 必須 deterministic — preset IDs + ages 由 test fixture explicit declare。

---

### AC-10 — Combat all-protected silent reject + telemetry

**GIVEN** active pool 飽和，全部 active particles 都係 floor-protected (age < 150ms) 且全部係 LOOT presets (no non-LOOT victim available — 即 Edge Case 2 path)，**WHEN** 新 HIT_HEAVY (non-LOOT) `play()` 嚟到，**THEN** 返回 `ParticleHandle.INVALID` (`alive() == false`)，`burst_started` signal 唔 emit (ghost-shake guard per Rule 11)，`_dropped_play_calls` counter +1，`push_warning` throttled per `WARNING_THROTTLE_MS=1000ms`，無 exception raise (silent reject)。

**Source**: Rule 9 + Rule 11 + EC2 + EC10
**Test Type**: Logic
**Gate**: BLOCKING
**Test file path**: `tests/unit/particle_wrapper/test_combat_all_protected_silent_reject.gd`

實作 note: Assert `_dropped_play_calls` 喺 reject case +1，accept case 不變；signal monitor (Godot `watch_signals`) assert zero `burst_started` emission。

---

### AC-11 — Mobile UA detection boot-cached + conservative default

**GIVEN** 測試環境 stub `OS.has_feature("web") == true` + `JavaScriptBridge.eval("navigator.userAgent", true)` 返回 "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0...)"，**WHEN** ParticleWrapper `_ready()` 完成，**THEN** `_is_mobile == true`，且 Formula 1 `mobile_mult = MOBILE_FALLBACK_MULTIPLIER (0.5)`；GIVEN UA detection 拋 exception 或返回 non-`TYPE_STRING`，**WHEN** boot，**THEN** `_is_mobile` 預設 `true` (conservative per FR-3 + Rule 10 fallthrough table)。

**Source**: Rule 10 + EC3-5
**Test Type**: Logic
**Gate**: BLOCKING
**Test file path**: `tests/unit/particle_wrapper/test_mobile_ua_detection_conservative.gd`

實作 note: Parameterised UA strings — iPhone, iPad (legacy + iPadOS 13+ with maxTouchPoints>1), Android, desktop Mac Safari (maxTouchPoints==0), null, malformed；assert detection result is boot-time cached (subsequent `JavaScriptBridge.eval` swap does NOT change `_is_mobile`)。

---

### AC-12 — `burst_started` signal sync emit AFTER alloc BEFORE `emitting=true`

**GIVEN** ParticleWrapper Active 並有 listener connected to `burst_started`，**WHEN** `play(PresetId.HIT_LIGHT, Vector2(50, 50))` 成功 acquire，**THEN** signal emit sequence 嚴格係: (1) pool acquire 成功 → (2) `_apply_preset(node, ...)` → (3) `node.restart(false)` → (4) `burst_started.emit(PresetId.HIT_LIGHT, Vector2(50, 50))` → (5) `node.emitting = true`；listener handler 喺 signal callback 中 inspect `node.emitting == false`。

**Source**: Rule 11
**Test Type**: Logic
**Gate**: BLOCKING
**Test file path**: `tests/unit/particle_wrapper/test_burst_started_signal_ordering.gd`

實作 note: Listener 喺 callback 內 store snapshot of `node.emitting`；assert post-call `emitting == true` AND snapshot `emitting == false`。

---

### AC-13 — Re-entry guard: nested `play()` from signal handler deferred

**GIVEN** `burst_started` listener handler 自己再 call `play(PresetId.HIT_LIGHT, ...)`，**WHEN** outer `play()` trigger signal，**THEN** nested call **唔** synchronously execute pool acquire；nested call 被 queue 入 `_deferred_plays` array (returned handle 有 `_pool_index = -1` PENDING marker)，喺 `_flush_deferred()` 中 drain via `call_deferred`；無 stack overflow、無 re-entrant pool corruption。

**Source**: Rule 12 + EC6
**Test Type**: Logic
**Gate**: BLOCKING
**Test file path**: `tests/unit/particle_wrapper/test_signal_re_entry_deferred.gd`

實作 note: Frame counter via `Engine.get_process_frames()` snapshot before/after；assert nested call execution frame > outer call frame；assert `_emit_depth` counter goes 0 → 1 → 0 cleanly。

---

### AC-14 — Rule 13 CI static check: magic int/string preset ID rejected at build

**GIVEN** 一個 fixture file `tests/fixtures/bad_preset_caller.gd` 內含 `ParticleSystemWrapper.play(42, Vector2.ZERO)` 或 `ParticleSystemWrapper.play("HIT_LIGHT", Vector2.ZERO)`，**WHEN** 運行 `tools/ci/check_particle_callers.gd`，**THEN** tool exit code != 0，stderr 含 violation 報告 (file path + line number)；GIVEN fixture file 用 `ParticleSystemWrapper.PresetId.HIT_LIGHT`，**WHEN** 同樣 tool 跑，**THEN** exit code == 0。

**Source**: Rule 13
**Test Type**: Logic (build-time tool)
**Gate**: BLOCKING
**Test file path**: `tests/unit/particle_wrapper/test_preset_id_ci_check.gd`

實作 note: 呢個 AC 唔係 runtime test，而係 build-time grep / AST check tool 嘅 acceptance test；CI pipeline 必須將呢個 check integrate 入 pre-merge gate (per coding-standards.md "blocking gate in CI")。

---

### AC-15 — Autoload position 12 + boot budget ≤80ms (F-SYNC-2 sync 2026-05-28 — was claimed pos 4)

**GIVEN** Godot project autoload list，**WHEN** inspect order，**THEN** ParticleSystemWrapper 排第 12 位 (在 PersistenceLayer pos 1, GameStateMachine pos 2, PlatformDetect pos 3, GymSysBackendClient pos 4, StatSystem pos 5, AbilitySystem pos 6, StreakSystem pos 7, WorkoutStateTracker pos 8, LootDropSystem pos 9, EnemyDirector pos 10, AvatarRenderer pos 11 之後)；GIVEN cold boot，**WHEN** ParticleSystemWrapper `_ready()` 完成，**THEN** elapsed time ≤ `MAX_BOOT_BUDGET_MS = 80`；若超過，trigger lazy fallback path (per EC1 + AC-18)。

**Source**: Rule 14 + EC1 + Knob `MAX_BOOT_BUDGET_MS`
**Test Type**: Logic
**Gate**: BLOCKING
**Test file path**: `tests/unit/particle_wrapper/test_autoload_order_boot_budget.gd`

實作 note: Project settings parse via `ProjectSettings.get_setting("autoload/...")`；boot time measure with `Time.get_ticks_usec()` 包圍 `_ready()`。

---

### AC-16 — GSM `connect_for_initial_state` subscription (ADR-006 Contract 6)

**GIVEN** GameStateMachine 喺 ParticleSystemWrapper `_ready()` 之前已經 transition 到 Active state，**WHEN** ParticleSystemWrapper subscribe via `GameStateMachine.connect_for_initial_state(_on_gsm_state_changed)`，**THEN** ParticleSystemWrapper 接收到 synthetic initial-state callback (`payload.source_event == "initial_state"`)，無 missed event；assert `_lifecycle_state == Active` 喺 first frame 結束時；`_apply_state_direct()` 處理 sentinel (per EC14 fall-through)。

**Source**: Rule 15 + ADR-006 Contract 6 + EC14
**Test Type**: Integration
**Gate**: BLOCKING
**Test file path**: `tests/integration/particle_wrapper/test_gsm_initial_state_subscribe.gd`

實作 note: Requires GSM stub that simulates pre-existing state；test order matters (GSM init → ParticleSystemWrapper init)。

---

### AC-17 — Wrapper persists nothing (3 invariants)

**GIVEN** ParticleSystemWrapper 跑完 100 次 `play()` 並 trigger save game flow，**WHEN** inspect persistence layer，**THEN** 3 invariants 全部 hold: (1) `PersistenceLayer.get_save_data()` 不含任何 `particle_*` key；(2) `ParticleSystemWrapper` 唔 expose `save_*` / `load_*` public method；(3) `particle_system_wrapper.gd` source code grep 唔到 `PersistenceLayer` import 或 reference，亦無 `user://` path reference。

**Source**: Rule 16
**Test Type**: Logic (architectural invariant)
**Gate**: BLOCKING
**Test file path**: `tests/unit/particle_wrapper/test_no_persistence_invariant.gd`

實作 note: 第 (3) 個 invariant 用 file content grep — assert `"PersistenceLayer" not in file_content` AND `"user://" not in file_content` AND no method matching regex `^func (save|load)_.*`。

---

### AC-18 — EC1: Boot exceed 80ms → lazy fallback path

**GIVEN** ParticleSystemWrapper `_ready()` 因為 pool prebuild 而超過 `MAX_BOOT_BUDGET_MS=80`，**WHEN** boot budget check 觸發 fallback (per EC1)，**THEN** 剩低 tier 唔再預建；`_booted = true` 照樣 set；engine_log 含 `[ParticleWrapper] boot_budget_overrun: completed_tiers=%d remaining=%d`；first `play()` of unbuilt tier trigger `_ensure_tier(tier_id)` consume ~5-15ms first-frame jank (acceptable trade-off)。

**Source**: EC1 + Rule 14
**Test Type**: Logic
**Gate**: BLOCKING
**Test file path**: `tests/unit/particle_wrapper/test_ec1_lazy_fallback.gd`

實作 note: Inject artificial delay via test hook `_simulate_slow_boot_per_tier_ms = 30`；assert no exception on first lazy `play()` call; engine_log captured via custom test logger。

---

### AC-19 — EC12: Active→Suspended atomic mid-flight reject (state transition)

**GIVEN** ParticleSystemWrapper Active，`play()` 正在 execute 到第 4 行 (allocation 完成但 `emitting = true` 未 set)，**WHEN** GSM emit `state_changed(active, suspended)` synchronously (e.g. from another autoload's signal handler)，**THEN** transition handler 入口**第一行** set `_lifecycle_state = Suspended` (在 `_drain()` 之前)；in-flight `play()` 後續 call 自動 hit `if _lifecycle_state in [Booting, Suspended, Draining]: return INVALID` (per EC12 fix)；無 ghost particle leak (pool node 返回 free list)；signal `burst_started` 唔 emit。

**Source**: EC12 + Rule 15 (Active↔Suspended transition)
**Test Type**: Integration
**Gate**: BLOCKING
**Test file path**: `tests/integration/particle_wrapper/test_ec12_suspended_atomic_reject.gd`

實作 note: 需要 test hook 喺 `play()` mid-execution inject GSM signal；assert pool free count restored；assert `_lifecycle_state` 寫入 ordering 確實 atomic。

---

### AC-20 — EC15: `_reconcile_ledger()` 2-second polling drift correction

**GIVEN** `_active_particle_total` ledger 因為 untracked particle timer leak 而 drift 到 ground truth +20% 之外 (超出 ±15% tolerance per Rule 6)，**WHEN** 經過 `LEDGER_RECONCILE_INTERVAL_S = 2.0` 秒，**THEN** `_reconcile_ledger()` 觸發 full scan (walk all 16 pool nodes per node `emitting==true OR (Time.get_ticks_msec() - _spawn_time_ms) < _lifetime_ms`)，將 ledger 校正到 ground truth (drift = 0%)；reconcile cost (測量 walk time) ≤ 1ms desktop / ≤ 2ms mobile。

**Source**: EC15 + Rule 6 amendment + Knob `LEDGER_RECONCILE_INTERVAL_S`
**Test Type**: Logic
**Gate**: BLOCKING
**Test file path**: `tests/unit/particle_wrapper/test_ec15_ledger_reconcile.gd`

實作 note: Mock `Time.get_ticks_msec()` + accumulator delta 推進 2 秒；assert reconcile triggered exactly once at 2.0s boundary, NOT polled every frame。

---

### AC-21 — EC16: Material hot-swap pre-first-frame race (`call_deferred`)

**GIVEN** pool node 喺同一 frame 內 (a) `acquire()` + `process_material = PRESET_TABLE[preset_id].material` hot-swap + (b) `_begin_emit(node)` 設 `emitting = true`，**WHEN** check execution order，**THEN** `_begin_emit()` 透過 `call_deferred("_begin_emit", node)` queue 到 frame end，確保 WebGL 2 material binding 完成；first emitted particle batch 使用正確 material (不會用前一個 acquire 嘅 stale material visual artifact)。`burst_started.emit` 仍 sync 喺 `restart(false)` 之後 (Rule 11 timing 維持)。

**Source**: EC16 + Rule 4 + Rule 11
**Test Type**: Logic
**Gate**: BLOCKING
**Test file path**: `tests/unit/particle_wrapper/test_ec16_material_hot_swap_defer.gd`

實作 note: Spy on `call_deferred` invocation；inspect `process_material` instance ID 喺 emit moment 對比 acquire moment；`burst_started` listener assert receive sync (NOT deferred)。

---

### AC-22 — State transition: Booting → Active correctness + GSM signal buffer

**GIVEN** ParticleSystemWrapper 進入 `_ready()` 但仲未 set `_booted = true`，期間 GSM emit `state_changed` (per EC11)，**WHEN** init sequence 完成 (pool built, materials cached, GSM `.connect_for_initial_state()`, UA detected)，**THEN** `_lifecycle_state` transition Booting → Active 嘅次序係 atomic (no intermediate state observable from outside)；任何喺 Booting 期間嘅 `play()` call 都 silent reject (return INVALID, no exception)；buffered GSM signal 喺 transition 後 drain via `_on_gsm_state_changed()` 重 dispatch (per EC11)。

**Source**: Section C State Table + EC11 + Rule 14
**Test Type**: Integration
**Gate**: BLOCKING
**Test file path**: `tests/integration/particle_wrapper/test_state_booting_to_active.gd`

實作 note: External observer 用 `_process` hook 嘗試 catch intermediate state；assert never observe state ∉ {Booting, Active}；inject premature GSM signal、assert `_pending_initial_state` buffered + drained。

---

### AC-23 — State transition: Active → Draining clean drain on `_exit_tree`

**GIVEN** ParticleSystemWrapper Active 並有 5 個 active particles (across SMALL + MEDIUM tier)，**WHEN** `_exit_tree()` 觸發 (scene change / quit)，**THEN** `_lifecycle_state = Draining` per Rule 15 + EC9；所有 in-flight `play()` reject (return INVALID, no signal, no log)；現有 pool nodes loop iterate 設 `emitter.emitting = false` + cancel ledger expire timer (avoid Rule 6 timer leak) + `node.queue_free()`；`_active_particle_total = 0`；無 orphaned RID via `RenderingServer.get_rendering_info()` post-drain。

**Source**: Section C State Table + EC9 + Rule 15
**Test Type**: Integration
**Gate**: BLOCKING
**Test file path**: `tests/integration/particle_wrapper/test_state_active_to_draining.gd`

實作 note: Assert no orphaned RID via `RenderingServer.get_rendering_info_resource_count_by_type(RenderingServer.INFO_TYPE_PARTICLES)` decremented to 0 post-drain。

---

### AC-24 — [ADR-001 RATIFICATION-GATED] FR-1: P95 frame time ≤ 16.6ms on mobile Safari at MAX_ACTIVE_PARTICLES

**GIVEN** Mirror Hero build deploy 到 iOS Safari (baseline device TBD by ADR-001 ratification — likely iPhone 12 or 13 baseline，per VS-tier device profiling pass)，**WHEN** trigger sustained worst-case scenario (LOOT_RARE_BURST × 4 simultaneous, sustained 30s rolling)，**THEN** P95 frame time over 30s window ≤ 16.6ms 喺 `MAX_ACTIVE_PARTICLES = 200` cap 下；若未達標，ADR-001 必須 ratify per-device measured cap (e.g. 150 for iPhone 11 baseline, 250 for iPhone 14 baseline) + revise Knob G.1 default value。

**Source**: FR-1 + Knob `MAX_ACTIVE_PARTICLES`
**Test Type**: Integration (device profiling)
**Gate**: ADVISORY (cross-reference verify at ADR-001 ratification, NOT at wrapper unit test)
**Test file path**: `production/qa/evidence/adr-001-fr1-mobile-p95.md`

實作 note: 呢個 AC 唔可以喺 wrapper 自己 verify — 需要 device farm + production build；wrapper 階段只交付 `MAX_ACTIVE_PARTICLES` knob，cap value 由 ADR-001 ratification 決定。Test methodology details (frame measurement tooling, device matrix) defined at ADR-001 authoring time。

---

### AC-25 — [ADR-001 RATIFICATION-GATED] FR-2: LOOT_BURST vs LOOT_RARE_BURST peripheral 1-second glance distinguishability

**GIVEN** playtest cohort (sample size + statistical methodology defined at vertical-slice playtest protocol authoring time — typically n ≥ 8 + binomial test threshold)，**WHEN** 每人觀察隨機交替播放嘅 LOOT_BURST 同 LOOT_RARE_BURST 各 N 次 (peripheral vision setup, 中心 fixation target)，每次 1 秒 glance，**THEN** correct classification rate 達 protocol-defined threshold 確認 visual signature unambiguously distinguishable；若 fail → 加 audio cue 強化 (但 wrapper 唔 own audio — escalate #4 Audio Manager)，或重做 preset color ramp escalation。

**Source**: FR-2
**Test Type**: Visual/Feel (playtest)
**Gate**: ADVISORY (ADR-001 ratification-gated)
**Test file path**: `production/qa/evidence/adr-001-fr2-peripheral-glance-test.md`

實作 note: 需 art-director + ux-designer 設計 controlled playtest protocol；wrapper 階段只交付 2 個 preset 配置 hooks，視覺差異化由 VFX artist 創作後 ratify。

---

### AC-26 — [ADR-001 RATIFICATION-GATED] FR-3: iOS Safari UA detection 100% accuracy across variants

**GIVEN** UA detection 跑喺真實 iOS device matrix (matrix defined at ADR-001 ratification): iPhone Safari, iPad Safari, iPad iPadOS-as-desktop mode, in-app WebView (Twitter/Facebook embedded browser)，**WHEN** ParticleSystemWrapper boot 完成，**THEN** `_is_mobile` 正確判定 (iPhone/iPad/WebView → true，true desktop Mac Safari → false) 喺 100% test cases (zero false negative)；若有 false negative，escalate art-director + technical-director for ADR-001 ratification 加 conservative override list (e.g. specific UA regex augmentation per Rule 10)。

**Source**: FR-3 + Rule 10
**Test Type**: Integration (device matrix)
**Gate**: ADVISORY (ADR-001 ratification-gated)
**Test file path**: `production/qa/evidence/adr-001-fr3-ua-detection-device-matrix.md`

實作 note: Device matrix details (specific iOS versions, embedded browser host apps) defined at ADR-001 authoring time。Wrapper 階段交付 Rule 10 detection logic + Edge Case 3/4/5 fallthrough behavior。

---

### AC-27 — Pillar 3 ADVISORY: LOOT moment 「值唔值得 cap 圖／發朋友圈」 playtest

**GIVEN** vertical slice build 含 polished LOOT_RARE_BURST，**WHEN** playtest cohort (sample size defined at VS playtest protocol time) 經歷數次 RARE loot drop moments，post-session interview 問: 「呢個 loot moment 你有冇衝動 cap 圖 share？」，**THEN** spontaneous 正面回應率達 protocol-defined threshold (without leading question)；qualitative feedback document 由 game-designer + art-director 共同 sign-off。

**Source**: Pillar 3 Player Fantasy (Section B Visual Identity Anchor design test)
**Test Type**: Visual/Feel (playtest)
**Gate**: ADVISORY
**Test file path**: `production/qa/evidence/pillar3-loot-share-worthiness-playtest.md`

實作 note: 呢個 AC 唔 gate wrapper merge，gate 嘅係 vertical slice milestone；wrapper 階段只交付 preset hook，視覺成果由後續 VFX iteration 決定。

---

### Coverage Matrix Summary

| Source | AC IDs |
|---|---|
| Rule 1 + 2 + 3 (ParticleHandle contract) | AC-01, AC-02 |
| Rule 4 (Pool structure) | AC-03 |
| Rule 5 (Tier selection no realloc) | AC-04 |
| Rule 6 (Ledger O(1) + drift) | AC-05 |
| Rule 7 + Formula 1 (Composition) | AC-06, AC-07 |
| Rule 8 + Formula 2 (LRU + floor) | AC-08 |
| Rule 9 (LOOT carve-out) | AC-09, AC-10 |
| Rule 10 (Mobile UA) | AC-11 |
| Rule 11 (Signal contract) | AC-12 |
| Rule 12 (Re-entry guard) | AC-13 |
| Rule 13 (CI static check) | AC-14 |
| Rule 14 (Autoload + boot budget) | AC-15 |
| Rule 15 (GSM subscription) | AC-16 |
| Rule 16 (No persistence) | AC-17 |
| Formula 3 (needs_eviction) | AC-08, AC-10 (via budget cap enforcement) |
| EC1 (Lazy fallback) | AC-18 |
| EC2 / EC10 (Floor protection reject) | AC-10 |
| EC6 (Signal re-entry) | AC-13 |
| EC11 (Boot signal buffer) | AC-22 |
| EC12 (Suspended atomic) | AC-19 |
| EC14 (initial_state sentinel) | AC-16 |
| EC15 (Ledger reconcile) | AC-20 |
| EC16 (Hot-swap defer) | AC-21 |
| State: Booting→Active | AC-22 |
| State: Active↔Suspended | AC-19 |
| State: Active→Draining | AC-23 |
| FR-1 [ADR-001 GATED] | AC-24 |
| FR-2 [ADR-001 GATED] | AC-25 |
| FR-3 [ADR-001 GATED] | AC-26 |
| Pillar 3 ADVISORY playtest | AC-27 |

**Total**: 27 ACs — 23 BLOCKING (Rule + EC + Integration) + 4 ADVISORY (3 ADR-001 RATIFICATION-GATED FR + 1 Pillar 3 playtest)。

## Open Questions

呢度列明本 GDD 設計過程中 surface 但 cannot fully resolve 既 question — 等到指定 owner 喺指定 trigger 時 resolve。

### Q-V1 — Mobile UA Detection P95 accuracy across iOS Safari device matrix

**Question**: Rule 10 + AC-26 既 UA detection logic 喺真實 iOS Safari device matrix (iPhone 11/12/13/14, iPad Pro/Air, iPad iPadOS-as-desktop mode, in-app WebView Twitter/Facebook) 上 false-negative rate 係咪 0% (per FR-3 invariant)？

**Owner**: ADR-001 ratification (cross-references AC-26 `[ADR-001 RATIFICATION-GATED]`)
**Trigger**: ADR-001 authoring + VS-tier device profiling pass
**Default if未 resolved**: Conservative MOBILE fallback per Rule 10 fallthrough table — UA ambiguous → `_is_mobile = true`
**Risk if未 resolved before VS implementation**: 部分 iOS device 既 desktop multipliers 應用 → mobile Safari fillrate jank (Pillar 2 silent violation per FR-3 Risk Register)

---

### Q-V2 — `_ready()` actual boot duration on mobile Safari cold boot

**Question**: Rule 14 + AC-15 既 `MAX_BOOT_BUDGET_MS = 80` 喺真實 mobile Safari cold boot (16 GPUParticles2D node + 9 ParticleProcessMaterial preload + JS bridge UA detect) 上實測耗時係幾多？係咪需要 frequent trigger EC1 lazy fallback path？

**Owner**: gameplay-programmer (during VS implementation pass)
**Trigger**: VS-tier first integration with #14 EnemyDirector
**Default if未 resolved**: 80ms target，超過 trigger Edge Case 1 lazy fallback
**Risk if未 resolved before VS implementation**: 若實測 >150ms → 需要 amend Knob `MAX_BOOT_BUDGET_MS` 或 redesign pool prebuild strategy (e.g. defer LARGE tier to loading screen)

---

### Q-V3 — ADR-001 ratification of FR-1/FR-2/FR-3 ratification gate

**Question**: Player Fantasy Risk Register 既 3 個 invariant (FR-1 mobile P95 frame time，FR-2 LOOT distinguishability，FR-3 UA detection accuracy) — ADR-001 ratify 既時候真係滿足 hard guarantee 定 fall back to 既 alternate framing？

**Owner**: technical-director + art-director (ADR-001 ratification gate review)
**Trigger**: ADR-001 authoring kick-off
**Default if未 resolved**: 本 GDD Player Fantasy paragraph 仍 claim direct fantasy「眼角擒獲」— 若任何 FR 失敗，需要 revise Player Fantasy paragraph 配合 fallback framing per FR Register
**Risk if未 resolved**: Player Fantasy paragraph 變 retroactive lie，影響 future GDD reviewer trust + 玩家 actual experience 走樣

---

### Q-V4 — Downstream provisional contracts (#14 / #21 / #25) confirmation

**Question**: Section C 6 interaction contracts 對 #14 EnemyDirector / #21 Loot Drop Modal / #25 Combat Visual Feedback 既 assumption — 例如 LOOT rarity tier → preset mapping (`LOOT_BURST` for white/green/blue，`LOOT_RARE_BURST` for purple/orange)，係咪同 #15 Loot Drop System GDD + ADR-005 最終決定一致？

**Owner**: 各 dependent GDD authoring (#14, #15, #21, #25)
**Trigger**: 對應 GDD `/design-system` skill 進入 Section C 設計時
**Default if未 resolved**: Wrapper API freezes per Section C contracts + Section F bidirectional sync requirements；downstream 邊到 wrapper assumption 唔啱，submit ADR 改 wrapper
**Risk if未 resolved**: Wrapper hold premature lock on preset mapping → downstream creative space 受 wrapper constraint 而非 design intent → could force wrapper redesign mid-VS

---

### Q-V5 — Rule 13 CI static check tool implementation

**Question**: AC-14 既 `tools/ci/check_particle_callers.gd` static check tool 既具體 implementation (grep-based vs AST-based)、CI integration point (pre-commit hook vs GitHub Actions vs both)、false-positive handling (e.g. comment-out call sites) 邊個團隊 own?

**Owner**: devops-engineer + tools-programmer (collaboration)
**Trigger**: VS-tier CI pipeline setup (per `/test-setup` skill execution)
**Default if未 resolved**: Wrapper merge 時 manually grep verify (advisory)；CI integration deferred
**Risk if未 resolved**: 玩家無 build-time enforcement → consumer 違反 Rule 13 closed enum convention → 視覺 inconsistency + budget leak (磁性的 long-term defect)

---

### Q-V6 — Edge Case 13 helper API adoption policy

**Question**: EC13 既 `request_burst_started_connect(callable)` helper API (per Rule 11 amendment) — 係 mandate use (所有 subscriber 必須用)，定 recommended (autoload order 保證下直接 `.connect()` 都 acceptable)？

**Owner**: tech-debt review + #6 Screen Effects GDD authoring
**Trigger**: #6 Screen Effects GDD authoring，or first wrapper subscriber implementation post-VS
**Default if未 resolved**: 推薦但非 mandate — `.connect()` 仍 acceptable under current autoload order #4 < #6
**Risk if未 resolved**: 若 future refactor 改 autoload order，`.connect()` 直接寫法 break — 需要 retrofit 所有 subscriber 改 helper

---

### Q-V7 — Edge Case 15 reconcile cost on mobile profiling

**Question**: EC15 既 `_reconcile_ledger()` 2-second polling (walk 16 pool nodes) 實測 cost on iOS Safari low-tier device (iPhone 11) 係幾多？係咪需要 amend `LEDGER_RECONCILE_INTERVAL_S` 或改用 event-driven trigger (e.g. only run when `_dropped_play_calls / _total_play_calls > threshold`)？

**Owner**: performance-analyst (VS-tier profiling pass)
**Trigger**: VS-tier profiling milestone
**Default if未 resolved**: 2.0s interval acceptable per art-director's mobile budget assessment
**Risk if未 resolved**: 若 reconcile cost > 0.5ms on iPhone 11 → `_process` overhead 開始觸發 Pillar 2 silent violation
