# ADR-0001: Godot Web Export Budget Caps

## Status
**Accepted (structural) 2026-05-30** — ratified via `/architecture-review` focused ratification (cross-ADR conflict scan clean; depends only on ADR-006 Accepted; engine audit clean Godot 4.6). The **structural decisions** (renderer-per-platform, CanvasLayer topology, mobile detection, CI enforcement mechanisms, GPU particle-cap concept) are sound design choices with no measurement gate and are now Accepted. The CPU budget **numeric figures remain Provisional** pending VS-tier mobile profiling on target hardware; the CPU-benchmark RATIFICATION-GATED acceptance criteria (e.g. CombatResolver AC-35, #5/#6/#7 CPU-budget ACs) stay gated until measured values land. Update the provisional numbers with `(measured YYYY-MM-DD)` tags to mark the ADR *fully* Accepted.
*(Previously: Proposed — structural decisions intended for Accepted; CPU budget values Provisional pending VS-tier profiling.)*

**Amendment 2026-06-07 (#21 G-LM-1)** — additive topology revision: added `CelebrationVFXLayer` (110, ALWAYS) + `ModalLayer` (120, ALWAYS) above ScreenEffectsLayer (BackBufferCopy-immune; L109 HUD knob precedent); pinned viewport residence (root viewport, `follow_viewport=false`, explicit world→screen anchor transform required); ruled modal blur **CUT from MVP** (opacity-only — avoids a second WebGL2 framebuffer copy; v0.2 re-price if revisited). Additive, no constraint conflict, no measurement gate — no re-ratification needed (ADR-0008 amendment precedent).

**Amendment 2026-06-07 (#22 G-CS-7)** — additive topology revision: added `CharacterScreenLayer` (**60**, PAUSABLE) between HUDLayer (50) and ScreenEffectsLayer (100), owned by `CharacterScreenCoordinator` autoload (instantiated in `_ready`, pre-warmed `visible=false` — #21 coordinator precedent). **Placement is load-bearing, < 100 by design**: the P-07 motion-intensity slider preview (HIT_HEAVY shake on release) must visibly shake the Character Screen itself — BackBufferCopy capture enumeration updated to **layers 0/10/50/60** so #22 rides the real ScreenEffects shader path (>100 placement would leave the preview shaking a fully-occluded world = silently dead feature). Constraints: >50 (above #20 HUD for workout-transition fade ordering), <110/120 (below #21 layers — force-close ≤150ms coexists with deferred loot reveal). Mood/saturation note: at layer 60 #22 pixels pass through the saturation chain; in IDLE/DISCONNECTED steady state the chain is identity (`u_world_saturation_drop` driven only by #21 ceremony; LOOT_DROP state force-closes #22) — residual recovery tail ≤2s decays to identity, accepted. Additive, no constraint conflict, no measurement gate — no re-ratification needed.

**Amendment 2026-06-07 (#23 G-IU-2)** — additive topology revision: added `InventoryUILayer` (**61**, PAUSABLE) immediately above CharacterScreenLayer (60), owned by `InventoryUICoordinator` autoload (instantiated in `_ready`, pre-warmed `visible=false` — #21/#22 coordinator precedent). BackBufferCopy capture enumeration updated to **layers 0/10/50/60/61** — mechanically the capture is positional (everything < 100 is captured; `src/autoload/screen_effects.gd` L370-371 documents the >100-immune topology), so 61 would be captured regardless; the explicit enumeration is updated in sync because a stale enumeration is a phantom-citation breeding ground (G-CS-7 precedent). Constraints: >60 (above #22 — the #22↔#23 CLOSING×OPENING crossfade draws incoming #23 over outgoing #22), <110/120 (below #21 layers). Mood/saturation note: at layer 61 #23 pixels pass through the saturation chain; in IDLE/DISCONNECTED steady state the chain is identity (#22 Rule 34-equivalent; LOOT_DROP state force-closes #23); the crossfade transient draws both full-screen surfaces simultaneously for ≤CLOSE_ANIM_MS — accepted, far below the mobile 150 draw-call cap. Additive, no constraint conflict, no measurement gate — no re-ratification needed.

**Amendment 2026-06-08 (#24 G-LS-1)** — additive topology revision, **two layers** added by `LoginShellCoordinator` autoload (instantiated in `_ready`, both pre-warmed `visible=false` — #21/#22/#23 coordinator precedent): (1) `LoginShellLayer` (**62**, PAUSABLE) immediately above InventoryUILayer (61) — full-screen login form / shell-entry surface. BackBufferCopy capture enumeration updated to **layers 0/10/50/60/61/62** — positional capture (< 100) means 62 is captured regardless; the explicit enumeration is updated in sync (stale-enumeration phantom-citation hazard — G-CS-7/G-IU-2 precedent). PAUSABLE for the #22/#23 reason (only opens in GSM IDLE/DISCONNECTED/BOOTING login states; inert during #6 `hit_pause`/ceremony freezes). Constraints: >61 (above #23 — #24 is the topmost in-world overlay), <100 (below ScreenEffectsLayer — login surface stays in the captured/desaturatable band; IDLE/DISCONNECTED steady-state chain is identity, #22/#23 Rule 34-equivalent). (2) `ErrorBannerLayer` (**111**, ALWAYS) between CelebrationVFXLayer (110) and ModalLayer (120) — error/status banner stack, **>100 = shake/saturation-immune** (banner must read truthfully during world desaturation — error honesty is Pillar-2 load-bearing) and **<120** (the #21 loot reveal modal is a sacred moment that may cover the banner; banner re-emerges after — GDD Rule 7). Banner backdrop is **opacity-only — a second BackBufferCopy is FORBIDDEN** (same ruling as the #21 modal-blur CUT; AC-36 enforces `find_children("*","BackBufferCopy")` empty). Two-layer split is load-bearing: `ErrorBannerLayer` (111 ALWAYS) is independent of shell state so ONGOING/WIPE banners surface over WORKOUT_ACTIVE even while `LoginShellLayer` (62 PAUSABLE) stays hidden (EC-E3/AC-54). Additive, no constraint conflict, no measurement gate — no re-ratification needed.

## Date
2026-05-26

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Rendering + Core |
| **Knowledge Risk** | HIGH — Godot 4.6 is post-LLM-cutoff (May 2025). Several rendering and Camera2D APIs changed in 4.4–4.6. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/modules/rendering.md`, `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/deprecated-apis.md` |
| **Post-Cutoff APIs Used** | `Camera2D.position_smoothing_enabled` + `position_smoothing_speed` (frame-rate-independent exponential decay, validated for Godot 4.x); `GPUParticles2D` on Compatibility/WebGL 2 (transform feedback supported); `JavaScriptBridge.eval()` (4.x canonical JS interop); `Shader Baker` (4.5+ — startup stutter reduction, Compatibility renderer coverage to verify on 4.6); `RenderingServer.global_shader_parameter_set` (type must match shader uniform declaration; registration via `global_shader_parameter_add` or Project Settings → Shader Globals required before use) |
| **Verification Required** | VS-tier: (1) GPUParticles2D transform-feedback stability on iOS Safari WebGL2; (2) Camera2D position_smoothing under Compatibility renderer; (3) Focal tween frame budget on mobile; (4) Shader Baker coverage for Compatibility backend in Godot 4.6; (5) BackBufferCopy framebuffer copy cost on mobile Safari (budget ≥0.5ms GPU on mobile — known iOS Safari bottleneck) |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-006 State Machine Contract (Accepted 2026-05-28 — N-002 sync 2026-05-28) — PROCESS_MODE_ALWAYS whitelist concept (Contract 4 + Rule 10); CI static analysis patterns (Contract 12) |
| **Enables** | ADR-002 (GymSys Integration Protocol — constrained by Web Export memory/polling cadence); ADR-003 (Save State Strategy — WASM memory budget informs IndexedDB quota); ADR-007 (AccessibilityBus.reduce_motion — cross-system motion accessibility spin-off flagged by #7 Camera GDD design-review) |
| **Blocks** | VS-tier implementation stories for #5 ParticleSystemWrapper (AC-24), #6 ScreenEffects (AC-27, AC-33, AC-34, AC-35), #7 Camera (AC-33, AC-34, AC-35) — all ADR-001 RATIFICATION-GATED |
| **Ordering Note** | Must be Accepted (structural) before Foundation autoload implementation begins. CPU budget provisional values must be updated with measured figures before marking fully Accepted. |

## Context

### Problem Statement
Mirror Hero uses Godot 4.6 Web Export (HTML5/WASM) targeting iOS Safari as primary deployment. Three approved Foundation-tier GDDs (#5 ParticleSystemWrapper, #6 ScreenEffects, #7 Camera) define performance constraints pending formal ratification. This ADR establishes the specific budget caps, renderer choices, CanvasLayer topology, mobile detection approach, and CI enforcement mechanisms that gate those systems' ADR-001-RATIFICATION-GATED acceptance criteria.

### Constraints
- **Primary platform**: Web Export (iOS Safari, mobile browser, single-thread WASM by default)
- **Engine**: Godot 4.6 — Compatibility renderer required for Web Export (WebGL 2); Forward+/Mobile renderer unavailable on web; Compositor post-process chains inaccessible on Compatibility renderer
- **Memory**: ~512MB browser ceiling (WASM heap + GPU textures + audio within this envelope)
- **Target framerate**: 60fps (16.6ms frame budget)
- **Team size**: Solo developer — device testing limited to personal iPhone 12 + desktop browser (no device farm)
- **Game concept hard governance**: `MAX_ACTIVE_PARTICLES = 200` (§8 of game-concept.md — non-negotiable mobile cap)

### Requirements
- Ratify GPU particle cap (mobile + desktop tiers) — #5 FR-1
- Define CPU budget per autoload (ScreenEffects, Camera, ParticleWrapper) — #6 FR-1, #7 FR-1
- Specify renderer per platform — #6 Rule 14 CanvasLayer topology ratification
- Own CanvasLayer topology as architectural standard — TD-ADR ruling
- Ratify SubViewport oversample approach (correct implementation) — #6 Rule 14 BLOCKING fix
- Define mobile UA detection as shared utility — TD-ADR PlatformDetect requirement
- Specify CI enforcement scope and split timing — #6 FR-3, #7 FR-3
- Set WASM bundle size target

## Decision

### Two-Tier Budget Model

**Mobile is the canonical spec.** Desktop headroom is a bonus, never an assumption. Drop Euphoria VFX (#5 particle burst, #6 shake/hit-pause, #7 focal zoom) MUST deliver euphoric feel at mobile-tier budgets. Desktop 2× is gravy.

Runtime-detected two-tier budget via `PlatformDetect` autoload (see Architecture Diagram):

| Parameter | Mobile Tier (iOS Safari, Android Chrome) | Desktop Tier (Chrome, Safari, Firefox) |
|-----------|------------------------------------------|----------------------------------------|
| `GPU_PARTICLE_CAP` (`MAX_ACTIVE_PARTICLES`) | **200** (game-concept hard governance §8) | **400** (2× mobile headroom) |
| `MOBILE_FALLBACK_MULTIPLIER` (#5 FR-1) | **0.5×** | **1.0×** |
| **ScreenEffects CPU** (shake + hit_pause per frame) | ≤ **0.3ms** p95 *(provisional)* | ≤ **0.5ms** p95 *(provisional)* |
| **Camera CPU** (smoothing + focal tween per frame) | ≤ **0.1ms** p95 *(provisional)* | ≤ **0.2ms** p95 *(provisional)* |
| **ParticleWrapper CPU** (pool management per frame) | ≤ **0.5ms** p95 *(provisional)* | ≤ **0.8ms** p95 *(provisional)* |
| **Total Foundation autoloads CPU** | ≤ **2.0ms** p95 *(provisional)* | ≤ **3.0ms** p95 *(provisional)* |
| **Draw calls** | ≤ **150** | ≤ **200** |
| **Memory ceiling** | **512MB** (browser WASM constraint) | **512MB** (consistent) |
| **WASM bundle (compressed)** | ≤ **50MB** | ≤ **50MB** |

*Provisional* = intent value. Replace with measured values post VS-tier profiling (see Validation Criteria). ADR status upgrades from Proposed → Accepted after measured values confirm or revise.

---

### Renderer Choice

| Target | Renderer | Rationale |
|--------|----------|-----------|
| Web Export (all browsers) | **Compatibility** (WebGL 2 / OpenGL 3.3) | Only renderer available in WASM export. Forward+/Mobile not applicable to web target. |
| Desktop native (development/secondary) | **Forward+** | Godot 4.6 default. SSR, glow, SMAA available. |

**Implication**: Compositor post-processing (`CompositorEffect`) is NOT available on Compatibility renderer. BackBufferCopy + ShaderMaterial is the correct screen-space effect chain for Web Export (validated in #6 ScreenEffects Rule 14).

---

### CanvasLayer Topology (ADR-001 owns; GDD #6 references)

This topology is the project architectural standard. All systems that render to screen must respect this layering. Changes require ADR revision.

```
Root
├─ GameLayer          (CanvasLayer layer=0,   process_mode=PAUSABLE)
│  └─ Camera2D        (owned by #7 CameraSystem autoload)
│  └─ World content   (avatar, enemies, projectiles)
│
├─ ParticleLayer      (CanvasLayer layer=10,  process_mode=PAUSABLE)
│  └─ GPUParticles2D  (spawned by #5 ParticleSystemWrapper pool)
│
├─ HUDLayer           (CanvasLayer layer=50,  process_mode=PAUSABLE)
│  └─ HP bar, damage numbers, cooldown timers
│
├─ CharacterScreenLayer (CanvasLayer layer=60, process_mode=PAUSABLE)  [#22 revision 2026-06-07]
│  └─ Character Screen full-screen overlay (owned by CharacterScreenCoordinator; pre-warmed visible=false)
│
├─ InventoryUILayer   (CanvasLayer layer=61, process_mode=PAUSABLE)  [#23 revision 2026-06-07]
│  └─ Inventory/Mailbox full-screen overlay (owned by InventoryUICoordinator; pre-warmed visible=false)
│
├─ LoginShellLayer    (CanvasLayer layer=62, process_mode=PAUSABLE)  [#24 revision 2026-06-08]
│  └─ Full-screen login form / shell-entry surface (owned by LoginShellCoordinator; pre-warmed visible=false)
│
├─ ScreenEffectsLayer (CanvasLayer layer=100, process_mode=ALWAYS)
│  ├─ BackBufferCopy  (captures layers 0/10/50/60/61/62 into screen texture)  [#22 revision: +60; #23 revision: +61; #24 revision: +62]
│  └─ ColorRect (full-screen, ShaderMaterial reads u_shake_offset uniform)
│
├─ CelebrationVFXLayer (CanvasLayer layer=110, process_mode=ALWAYS)   [#21 revision 2026-06-07]
│  └─ LOOT preset pool nodes (reparented by #5 via register_celebration_layer handshake — G-LM-2)
│
├─ ErrorBannerLayer    (CanvasLayer layer=111, process_mode=ALWAYS)   [#24 revision 2026-06-08]
│  └─ Error/status banner stack (owned by LoginShellCoordinator; >100 shake/saturation-immune, <120 below loot modal; opacity-only backdrop — no 2nd BackBufferCopy)
│
└─ ModalLayer          (CanvasLayer layer=120, process_mode=ALWAYS)   [#21 revision 2026-06-07]
   └─ Loot reveal modal / catch-up surfaces (owned by LootRevealCoordinator)
```

**HUD position knob**: `HUD_SHAKES_WITH_WORLD: bool = true` (default, #6 Section G) — default = HUDLayer below ScreenEffectsLayer (shaken, DNF unified feel). Toggle `false` = HUDLayer above ScreenEffectsLayer (immune, readability priority for accessibility).

#### #21 Loot Drop Modal layers (revision 2026-06-07 — G-LM-1)

- **`CelebrationVFXLayer` (110, ALWAYS)** + **`ModalLayer` (120, ALWAYS)** — single owner = `LootRevealCoordinator` autoload (instantiates both in `_ready`, pre-warmed `visible=false`). Precedent for >100 placement: the L109 HUD knob already established that layers may sit above ScreenEffectsLayer for immunity.
- **>100 = outside BackBufferCopy capture**: BackBufferCopy at layer 100 captures layers 0/10/50/60/61/62 only (#22 revision added 60; #23 revision added 61; #24 revision added 62) — content on 110/111/120 is **immune to saturation (world −60% desaturation) and shader shake**. This is the mechanism behind #21 AC-75/AC-87 (loot burst stays fully saturated while the world desaturates; art bible「爆裝特效全飽和」) and #24's `ErrorBannerLayer` (111) reading truthfully through world desaturation.
- **Viewport residence (① 釘實)**: both layers attach to the **root viewport** (autoload-owned). World content lives inside the GameLayer **SubViewport** (see SubViewport Oversample above) where Camera2D resides — therefore `follow_viewport_enabled` is **meaningless on these layers and must stay `false`** (screen-space layers). World-anchored positions (e.g. #21 `reveal_anchor_pos` from the `avatar_anchor` group) **must be explicitly transformed** SubViewport-world → root-viewport-screen coordinates at call time (via the game viewport's canvas transform / camera screen mapping) before being passed to `ParticleSystemWrapper.play()` or used to place burst/modal anchors. No implicit follow.
- **Modal blur (② 裁決 — MVP = opacity-only)**: the GDD's 8% modal-local blur would require a **second** BackBufferCopy per frame on Compatibility/WebGL2 (the first is ScreenEffectsLayer's; ≥0.5ms GPU each on mobile Safari). **Decision: blur is CUT from MVP — opacity-only fallback** (`ui_ink_bg` 92% opacity flat backdrop, zero extra framebuffer copy). Desktop-tier blur is a v0.2 enhancement and must be re-priced into the budget table if revisited. #21 stories implement opacity-only.

#### #22 Character Screen layer (revision 2026-06-07 — G-CS-7)

- **`CharacterScreenLayer` (60, PAUSABLE)** — single owner = `CharacterScreenCoordinator` autoload (instantiates in `_ready`, pre-warmed `visible=false`; #21 coordinator precedent). PAUSABLE (not ALWAYS): the screen only opens in GSM IDLE/DISCONNECTED — it has no need to run while the tree is paused, and PAUSABLE keeps it inert during #6 `hit_pause`/ceremony freezes.
- **<100 placement is load-bearing (P-07 preview mechanism)**: the motion-intensity slider's release-time HIT_HEAVY preview must shake the Character Screen itself — at layer 60 the screen's pixels ride the BackBufferCopy→shader path (capture enumeration now 0/10/50/60/61/62 — #23 added 61, #24 added 62), so "feel the result" is literally honoured. A >100 placement would leave the preview shaking a world fully occluded by the opaque overlay (feature silently dead). Consequence accepted: #22 pixels also pass the saturation chain — identity in IDLE/DISCONNECTED steady state (`u_world_saturation_drop` is #21-ceremony-driven only; LOOT_DROP state force-closes #22); residual recovery tail ≤2s decays to identity.
- **Ordering constraints**: >50 (above #20 HUDLayer — workout-transition fade ordering: #22 force-close fade renders above the HUD fading in); <110/120 (below #21 layers — deferred loot reveal on IDLE entry force-closes #22 within ≤150ms while the #21 modal appears above it).
- **G-CS-4 interaction note**: the #6 preview API used by P-07 (`preview_hit_heavy()` or equivalent) must be **shake-only — never `hit_pause`** (tree pause would freeze the PAUSABLE CharacterScreenLayer mid-drag).

#### #23 Inventory UI layer (revision 2026-06-07 — G-IU-2)

- **`InventoryUILayer` (61, PAUSABLE)** — single owner = `InventoryUICoordinator` autoload (instantiates in `_ready`, pre-warmed `visible=false`; #21/#22 coordinator precedent). PAUSABLE for the same reason as #22: the surface only opens in GSM IDLE/DISCONNECTED, and PAUSABLE keeps it inert during #6 `hit_pause`/ceremony freezes.
- **Capture enumeration sync**: BackBufferCopy capture is positional — everything below layer 100 is captured (see `src/autoload/screen_effects.gd` L370-371: layers > 100 are BackBufferCopy-immune by topology), so 61 is mechanically captured with or without this note. The explicit enumeration (now **0/10/50/60/61/62** — #24 added 62) is updated anyway: a stale documented enumeration is a phantom-citation breeding ground for downstream GDDs/verifiers (G-CS-7 precedent).
- **Ordering constraints**: >60 (above #22 CharacterScreenLayer — the #22↔#23 CLOSING×OPENING crossfade renders incoming #23 above outgoing #22, so the handoff reads visually clean); <110/120 (below #21 layers — LOOT_DROP force-close coexists with deferred loot reveal, #21 modal renders above).
- **Mood/saturation note**: at layer 61 #23 pixels pass through the saturation chain; in IDLE/DISCONNECTED steady state the chain is identity (`u_world_saturation_drop` is #21-ceremony-driven only — #22 Rule 34-equivalent reasoning; LOOT_DROP state force-closes #23). The #22↔#23 crossfade transient draws **both** full-screen surfaces simultaneously for ≤CLOSE_ANIM_MS — accepted: two full-screen Controls are a handful of draw calls, far below the mobile 150 draw-call cap.

#### #24 Login Shell layers (revision 2026-06-08 — G-LS-1)

- **`LoginShellLayer` (62, PAUSABLE)** — single owner = `LoginShellCoordinator` autoload (instantiates in `_ready`, pre-warmed `visible=false`; #21/#22/#23 coordinator precedent). Topmost in-world overlay (just above #23 InventoryUILayer 61). PAUSABLE for the #22/#23 reason: the login surface only shows in GSM BOOTING/IDLE/DISCONNECTED login states and must stay inert during #6 `hit_pause`/ceremony freezes. **Capture enumeration sync**: capture is positional (everything < 100 captured; `src/autoload/screen_effects.gd` L370-371), so 62 is captured regardless; the explicit enumeration is updated to **0/10/50/60/61/62** anyway (stale-enumeration phantom-citation hazard — G-CS-7/G-IU-2 precedent). Ordering: >61 (above #23), <100 (inside the captured band — IDLE/DISCONNECTED steady-state saturation chain is identity, #22/#23 Rule 34-equivalent).
- **`ErrorBannerLayer` (111, ALWAYS)** — also owned by `LoginShellCoordinator`, placed between CelebrationVFXLayer (110) and ModalLayer (120). **>100 placement is load-bearing**: the banner must read truthfully while the world desaturates during a #21 ceremony (error honesty is Pillar-2 load-bearing — a desaturated "disconnected" banner that fades into the mood would be a dishonest steady-state signal). **<120**: the #21 loot reveal modal is a sacred moment that may fully cover the banner; the banner re-emerges after the modal closes (GDD Rule 7). ALWAYS (not PAUSABLE): error/status surfacing is independent of tree pause and of shell state.
- **Two-layer split is load-bearing (EC-E3 / AC-54)**: because `ErrorBannerLayer` (111 ALWAYS) is decoupled from `LoginShellLayer` (62 PAUSABLE), an ONGOING/WIPE error fired while the shell is HIDDEN (e.g. GSM WORKOUT_ACTIVE) surfaces the banner **over the workout** without ever showing the login surface. Rule 1's single-coordinator ownership ≠ single layer.
- **Banner backdrop = opacity-only — a 2nd BackBufferCopy is FORBIDDEN** (GDD Rule 8): same ruling as the #21 modal-blur CUT — a second per-frame framebuffer copy (≥0.5ms GPU mobile Safari) is not in budget. The banner uses a flat `ui_ink_bg` opacity backdrop, zero extra framebuffer copy. Enforced by AC-36 (`find_children("*","BackBufferCopy",true)` on both #24 layer scenes must be empty) and AC-35b (no AnimationPlayer/AudioStreamPlayer — banner is static: zero animation / zero audio / zero pulse).

**BackBufferCopy GPU cost note**: BackBufferCopy triggers a framebuffer copy per frame on WebGL 2. On mobile Safari this can cost ≥0.5ms GPU. This is included in the total Foundation budget (see Two-Tier model). If VS-tier profiling exceeds mobile budget, mitigation = reduce BackBufferCopy frequency (every N frames) or skip during low-trauma idle frames.

---

### SubViewport Oversample (Corrected Implementation)

**Intent**: Provide a 5% pixel bleed buffer at GameLayer viewport edges to prevent black-border clipping during maximum shake displacement (±MAX_OFFSET_PX = 4.0px).

**Incorrect approach (do NOT use)**: `SubViewport.stretch_shrink = 1.05` — `stretch_shrink` is an **integer** property in Godot 4.x; float value truncates to `1` (no effect).

**Correct approach**: Set SubViewport.size to 5% larger than display viewport in code:

```gdscript
# In master scene _ready() and on viewport resize signal
func _update_gameview_size() -> void:
    var display_size: Vector2i = get_viewport().size
    game_layer_subviewport.size = Vector2i(
        int(display_size.x * 1.05),
        int(display_size.y * 1.05)
    )
```

Memory cost: ~1.1× GameLayer viewport texture (≈12MB on iPhone 12 1170×2532 at 1.0 scale — within 512MB budget).

**Note**: #6 ScreenEffects GDD Rule 14 must be updated to reflect this corrected implementation (tracking: next /design-review pass for #6 or via /consistency-check).

---

### Mobile Platform Detection (PlatformDetect Autoload)

All Foundation autoloads use a shared `PlatformDetect` autoload for mobile/desktop branching. **No raw `JavaScriptBridge.eval` calls outside `platform_detect.gd`** (enforced by CI script — see CI Enforcement below).

```gdscript
# src/autoload/platform_detect.gd
extends Node

var is_mobile_web: bool = false

func _ready() -> void:
    process_mode = PROCESS_MODE_ALWAYS
    if OS.get_name() == "Web":
        var ua: String = JavaScriptBridge.eval("navigator.userAgent")
        is_mobile_web = "Mobile" in ua or "Android" in ua
    # Computed once at boot — no polling
```

**Autoload position**: position 3 (locked per project.godot ground truth 2026-05-28 — F-SETUP-4 + N-001 sync 2026-05-28; PlatformDetect at exactly pos 3, after PersistenceLayer pos 1 + GameStateMachine pos 2 per ADR-006 Contract 4). Project.godot is the canonical autoload position registry; ADR-001 prose previously left flexibility as "3 or later" (Revised 2026-05-27 per /architecture-review B-2), now specific. Specific position correctness rationale:
1. `is_mobile_web` is computed once at PlatformDetect's `_ready()` and never changes thereafter (immutable session-scope value)
2. Foundation autoloads that need `is_mobile_web` (#5 ParticleSystemWrapper, #6 ScreenEffects, #7 Camera) all run at autoload position later than PlatformDetect — they receive the correctly-detected value when they read it during their own `_ready()` or first frame
3. PersistenceLayer (position 1) does NOT need `is_mobile_web` — its `_detect_storage_mode()` uses `FileAccess.open()` probe (filesystem-based detection), not UA-based
4. If a future autoload at position 2 needed `is_mobile_web`, it could lazy-read on first frame (post-_ready) — not at construction time

This avoids the prior conflict with ADR-006 Contract 4 (which locks position 1=PersistenceLayer, 2=GSM; no position 0 defined in Godot autoload conventions).

**Edge cases**: Bot crawlers / headless browsers report desktop UA — acceptable (they get desktop budget). Electron webview may report `"Electron"` without `"Mobile"` — treated as desktop (acceptable). iPad Safari in desktop-mode reports desktop UA — treated as desktop (acceptable; iPad has higher fillrate).

---

### CI Enforcement Scope and Timing

Split into two landing phases:

**Phase A — Land with respective system implementation** (before ADR-001 ratification):

| Script | Enforces | Trigger |
|--------|----------|---------|
| `tools/ci/check_particle_callers.gd` | No direct GPUParticles2D instantiation outside #5 ParticleSystemWrapper (#5 Rule 16) | Land with #5 VS-tier implementation story |
| `tools/ci/check_autoload_process_modes.gd` | All autoloads declare `process_mode = PROCESS_MODE_ALWAYS` in `_ready()` (#6 FR-3, ADR-006 Contract 4) | Land with first autoload VS-tier implementation story |

**Phase B — Land at ADR-001 ratification** (gate for Status: Accepted):

| Script | Enforces | Trigger |
|--------|----------|---------|
| `tools/ci/check_screen_effects_callers.gd` | No `Camera2D.offset` mutation outside #6 ScreenEffects autoload (#6 Rule 15). Note: `Engine.time_scale` originally in this rule's scope but ScreenEffects implementation uses `get_tree().paused` instead — N-006 sync 2026-05-28 keeps `Engine.time_scale` ban as intentional conservative guard against future drift toward time_scale-based pause patterns | ADR-001 Accepted |
| `tools/ci/check_camera_callers.gd` | No `Camera2D.position/zoom/make_current()` mutation outside #7 Camera autoload (#7 Rule 13) | ADR-001 Accepted |
| `tools/ci/check_focal_caller_states.gd` | `Camera.request_focal()` callers must reference GSM state check (#7 FR-3) | ADR-001 Accepted |
| `tools/ci/check_platform_detect_callers.gd` | No raw `JavaScriptBridge.eval` calls outside `src/autoload/platform_detect.gd` | ADR-001 Accepted |

All scripts: EXIT(1) blocking on violation. Owned by devops-engineer sprint task.

---

### Validation Methodology (VS-tier profiling)

1. **Test device (mobile)**: iPhone 12 Pro / iPhone 14, iOS 17+, Safari latest
2. **Test device (desktop)**: MacBook / PC, 1920×1080, Chrome latest
3. **Tooling**: `Performance.get_monitor()` GDScript singleton (reliable per-system budget in WASM — preferred over browser performance profiler for Godot-level measurements); `Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME` for draw call count
4. **Scenario**: 8 enemies simultaneous HIT_HEAVY sustained 60s (worst-case particle + shake + camera composite)
5. **Pass criterion**: P95 frame time ≤ 16.6ms on mobile; ≤ 12ms on desktop (4.6ms safety buffer)
6. **Post-profiling**: Update provisional CPU values in Two-Tier table, add `(measured YYYY-MM-DD)` tag, change ADR Status: Proposed → Accepted

---

### Architecture Diagram

```
Web Export Frame Budget (16.6ms total @ 60fps)
├─ PlatformDetect (boot-only detection, 0ms per-frame)
│
├─ Foundation autoloads combined (≤ 2.0ms mobile / ≤ 3.0ms desktop)
│  ├─ ScreenEffects CPU: ≤ 0.3ms (Trauma² decay + hit_pause timer)
│  ├─ Camera CPU: ≤ 0.1ms (exponential position smoothing + focal tween if active)
│  └─ ParticleWrapper CPU: ≤ 0.5ms (pool LRU, budget ledger)
│
├─ BackBufferCopy GPU: ≤ 0.5ms mobile (framebuffer copy — iOS Safari WebGL2)
├─ GPU particles: 200 mobile / 400 desktop (transform feedback, GPU-side)
│
├─ HUD + game logic + physics (~8ms reserved)
└─ Reserve / render settle (~4ms mobile / 6ms desktop)

WASM bundle: ≤ 50MB compressed
Memory: ≤ 512MB (WASM heap + textures + audio)
Draw calls: ≤ 150 mobile / ≤ 200 desktop
```

---

### Key Interfaces

```gdscript
# PlatformDetect autoload (src/autoload/platform_detect.gd)
var is_mobile_web: bool  # read-only after _ready()

# Project constants (shared via Platform autoload or ProjectSettings)
const GPU_PARTICLE_CAP_MOBILE: int   = 200   # game-concept hard governance §8
const GPU_PARTICLE_CAP_DESKTOP: int  = 400
const CPU_BUDGET_SCREEN_EFFECTS_MS: float = 0.3  # provisional
const CPU_BUDGET_CAMERA_MS: float         = 0.1  # provisional
const CPU_BUDGET_PARTICLE_WRAPPER_MS: float = 0.5  # provisional
const WASM_BUNDLE_SIZE_CAP_BYTES: int     = 52_428_800  # 50MB

# SubViewport size helper (master scene)
func _update_gameview_size() -> void  # call on _ready + viewport resize
```

---

## Alternatives Considered

### Alternative 1: Fixed Conservative Cap (Single Web Tier)
- **Description**: Single budget table for all web targets (200 particles, conservative CPU)
- **Pros**: Simpler — no UA detection code path; easier to test
- **Cons**: Desktop browser wastes 2× fillrate headroom; visual downgrade on high-end hardware
- **Rejection Reason**: game-concept.md already implies tier differentiation via `MOBILE_FALLBACK_MULTIPLIER = 0.5` (#5 GDD); tiered model is architecturally embedded. Desktop parity foregoes meaningful visual uplift for minimal code simplicity gain.

### Alternative 2: Adaptive Per-Device Boot Benchmark
- **Description**: 1-second micro-benchmark at first boot determines which tier to apply
- **Pros**: Most accurate per-device budgets
- **Cons**: +1s cold-start cost; benchmark results can vary with thermal throttle and background tabs; VS-tier complexity overhead
- **Rejection Reason**: VS-tier scope constraint; UA-tier approximation acceptable given team size and target market (iOS Safari = mobile, desktop Chrome = desktop — high-confidence two-category mapping)

### Alternative 3: Compositor Post-Processing for Screen Shake
- **Description**: Use Godot 4.3+ `Compositor` + `CompositorEffect` for screen-space shake
- **Pros**: Modern, structured post-processing API; correct pattern for desktop
- **Cons**: Compositor is NOT available in Compatibility renderer (Web Export) — incompatible with primary target
- **Rejection Reason**: BackBufferCopy + ShaderMaterial is the only valid post-process path for Compatibility/WebGL 2. Confirmed by engine-reference rendering module.

### Alternative 4: Shader Clamp for Shake Edge (No SubViewport Oversample)
- **Description**: Clamp `u_shake_offset` so it never exceeds screen edge; skip 5% oversample
- **Pros**: Simpler — no SubViewport resize code
- **Cons**: At MAX_OFFSET_PX = 4.0px, edge clamp cuts off 4px of world content at screen edge during peak shake. Visual artifact is minor (0.2% of 1920px width) but detectable on mobile where viewport is smaller
- **Rejection Reason**: SubViewport code-set size is low complexity (single function) and definitively prevents the edge artifact. Accepted at minimal cost.

---

## Consequences

### Positive
- Three GDDs' ADR-001-gated ACs can proceed to VS-tier measurement and final acceptance
- CanvasLayer topology formally owned by ADR — no ambiguity about authoritative spec source
- PlatformDetect autoload establishes single-file UA detection — testable on desktop editor, greppable via CI
- Mobile-canonical framing prevents Pillar 3 drift (content spec'd to mobile, not desktop)

### Negative
- Provisional CPU values mean ADR Status stays Proposed until VS-tier playtest
- 50MB bundle cap constrains asset decisions (compressed audio, texture atlases)
- SubViewport resize code must handle viewport size changes (window resize in desktop, orientation change in mobile)
- BackBufferCopy GPU cost on mobile Safari is known pain point — may need framebuffer optimization if budget exceeded

### Risks
- **Risk 1**: VS-tier profiling shows 200 mobile particles exceed P95 budget. **Mitigation**: MOBILE_FALLBACK_MULTIPLIER 0.5→0.3 already available; cap can reduce to 120. Plan B documented.
- **Risk 2**: iOS Safari bfcache + WebGL2 context loss invalidates SubViewport size. **Mitigation**: #6 ScreenEffects + #7 Camera GDDs handle bfcache via Suspended cancel + NOTIFICATION_APPLICATION_RESUMED patterns.
- **Risk 3**: Camera2D exponential smoothing behaves differently under Compatibility vs Forward+ renderer. **Mitigation**: VS-tier spike (Q-R2 from #7 GDD) — fallback = snap-follow (disable smoothing on mobile if overshoot detected at P95).
- **Risk 4**: 50MB bundle cap tight if large audio or texture assets added. **Mitigation**: Godot Export Templates (~25-35MB WASM) + game data ≤ 15MB = achievable for VS-tier; monitor at each tier gate.
- **Risk 5**: Shader Baker Compatibility renderer coverage in Godot 4.6 unverified. **Mitigation**: VS-tier cold-start timing test — if Shader Baker doesn't cover Compatibility, remove from ADR Performance Implications note.

---

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| particle-system-wrapper.md (#5) | FR-1: `MAX_ACTIVE_PARTICLES = 200` mobile Safari P95 ≤ 16.6ms ratification | Ratifies 200/400 tier caps; defines VS-tier profiling methodology; provisional CPU ≤ 0.5ms |
| particle-system-wrapper.md (#5) | game-concept §8 hard governance: GPU cap = 200 | Formally ratified as project constant `GPU_PARTICLE_CAP_MOBILE = 200` |
| screen-effects-system.md (#6) | FR-1: Shake CPU budget allocation (separate from #5 GPU) | Provisional ≤ 0.3ms per frame mobile; measurement methodology via `Performance.get_monitor()` |
| screen-effects-system.md (#6) | FR-3: PROCESS_MODE_ALWAYS whitelist CI drift detection | Ratifies `check_autoload_process_modes.gd` + `check_screen_effects_callers.gd` scope and landing timing |
| screen-effects-system.md (#6) | Rule 14: CanvasLayer topology + BackBufferCopy pattern | ADR-001 takes ownership of topology as architectural standard; #6 references |
| screen-effects-system.md (#6) | Rule 14: SubViewport oversample | Corrects `stretch_shrink` (integer, cannot be 1.05) → code-set `SubViewport.size *= 1.05` |
| camera-system.md (#7) | FR-1: `position_smoothing_speed` cross-platform behaviour | Provisional ≤ 0.1ms CPU; Compatibility renderer confirmed for web; measurement methodology |
| camera-system.md (#7) | FR-2: Focal tween 60fps Compatibility renderer | Compatibility renderer ratified; Tween PAUSABLE pattern valid; profiling methodology defined |
| camera-system.md (#7) | FR-3: Focal caller CI enforcement | Ratifies `check_focal_caller_states.gd` + `check_camera_callers.gd` scope and landing timing |

---

## Performance Implications
- **CPU**: Foundation autoloads collectively ≤ 2.0ms mobile / ≤ 3.0ms desktop (provisional, measured at VS-tier via `Performance.get_monitor()`)
- **Memory**: 512MB WASM ceiling; SubViewport 1.05× oversample ≈ +10% per viewport texture (≈12MB on iPhone 12)
- **Load Time**: WASM bundle ≤ 50MB compressed; Shader Baker (Godot 4.5+) may reduce first-frame stutter — coverage for Compatibility renderer to verify at VS-tier
- **GPU**: BackBufferCopy ≥ 0.5ms per frame on mobile Safari (known iOS WebGL2 framebuffer copy cost; included in total frame budget)

---

## Migration Plan

ADR-001 is a new ADR (no prior decision to migrate from). Applies to all new VS-tier implementation:

1. **Immediately**: devops-engineer implements Phase A CI scripts (`check_particle_callers.gd` + `check_autoload_process_modes.gd`) — land with #5/#6 implementation
2. **At ADR acceptance**: devops-engineer implements Phase B CI scripts (4 remaining) + confirms in pipeline
3. **Scene scaffolding**: master scene implements `PlatformDetect` autoload (position 3+ per ADR-006 Contract 4 — see Mobile Platform Detection section for rationale) + `_update_gameview_size()` SubViewport code
4. **VS-tier profiling**: run 8-enemy HIT_HEAVY scenario on iPhone 12 + Chrome desktop; fill in measured CPU values; update ADR Status → Accepted
5. **Post-VS-tier**: GDD #6 Rule 14 updated to reflect corrected SubViewport.size approach (tracking via `/consistency-check` or next `#6 design-review` pass)

---

## Validation Criteria

1. Phase A CI scripts in pipeline (blocking) before first Foundation autoload implementation PR
2. Phase B CI scripts in pipeline (blocking) before ADR-001 Status: Accepted
3. VS-tier profiling: P95 frame time ≤ 16.6ms on iPhone 12 Pro Safari at 8-enemy HIT_HEAVY sustained
4. `PlatformDetect.is_mobile_web` returns correct values on: iPhone Safari, Android Chrome, desktop Chrome, desktop Safari
5. `SubViewport.size` code correctly resizes on viewport-changed signal
6. WASM bundle: `du -sh dist/*.pck.gz` < 50MB on VS-tier export
7. All ADR-001-gated ACs in #5/#6/#7 unblocked after validation

---

## Related Decisions
- **ADR-006**: State Machine Contract — PROCESS_MODE_ALWAYS concept (Contract 4); CI static analysis patterns (Contract 12); autoload boot order (Contract 4)
- **ADR-002** (pending): GymSys Integration Protocol — polling cadence constrained by Web Export single-thread WASM
- **ADR-003** (pending): Save State Strategy — WASM memory/IndexedDB quota expectations from this ADR
- **ADR-007** (pending — spin-off from #7 Camera GDD design-review): AccessibilityBus.reduce_motion — cross-system motion accessibility contract for Camera + ScreenEffects + future systems
- **game-concept.md §8**: Hard governance "GPU particles max 200 active" — source of `GPU_PARTICLE_CAP_MOBILE = 200`
