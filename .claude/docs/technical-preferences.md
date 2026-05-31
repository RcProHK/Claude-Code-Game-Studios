# Technical Preferences

<!-- Populated by /setup-engine. Updated as the user makes decisions throughout development. -->
<!-- All agents reference this file for project-specific standards and conventions. -->

## Engine & Language

- **Engine**: Godot 4.6
- **Language**: GDScript
- **Rendering**: Godot Forward+ (Desktop), Compatibility (Web Export)
- **Physics**: Godot Jolt (default in 4.6)

## Input & Platform

<!-- Written by /setup-engine. Read by /ux-design, /ux-review, /test-setup, /team-ui, and /dev-story -->
<!-- to scope interaction specs, test helpers, and implementation to the correct input methods. -->

- **Target Platforms**: Web (primary), Desktop (secondary)
- **Input Methods**: Keyboard/Mouse, Touch
- **Primary Input**: Touch (single-tap — next exercise selection during gym session)
- **Gamepad Support**: None
- **Touch Support**: Partial (web mobile/tablet)
- **Platform Notes**: Web Export (HTML5/WASM) is primary target; Godot Compatibility renderer required for web; one-tap input design — no hover-only interactions; browser memory budget applies (~512MB ceiling)

## Naming Conventions

- **Classes**: PascalCase (e.g., `PlayerController`)
- **Variables**: snake_case (e.g., `move_speed`)
- **Signals/Events**: snake_case past tense (e.g., `health_changed`)
- **Files**: snake_case matching class (e.g., `player_controller.gd`)
- **Scenes/Prefabs**: PascalCase matching root node (e.g., `PlayerController.tscn`)
- **Constants**: UPPER_SNAKE_CASE (e.g., `MAX_HEALTH`)

## Performance Budgets

- **Target Framerate**: 60 fps
- **Frame Budget**: 16.6 ms
- **Draw Calls**: ≤ 200 (2D web target)
- **Memory Ceiling**: 512 MB (browser constraint)

## Testing

- **Framework**: GUT (Godot Unit Testing) v9.x (pinned v9.6.0) — 9.x is the Godot 4.x line; 7.x is Godot 3.x only
- **Minimum Coverage**: [TO BE CONFIGURED]
- **Required Tests**: Balance formulas, gameplay systems, networking (if applicable)

## Forbidden Patterns

<!-- Updated by ADR-003 + ADR-001 (2026-05-26) -->
- `window.localStorage` — use `user://` (FileAccess / PersistenceLayer) instead. ~5MB quota + requires JavaScriptBridge. CI: `tools/ci/check_local_storage_calls.gd`. (ADR-003)
- `SubViewport.stretch_shrink = [float]` — integer property; float silently truncates. Use code-set `SubViewport.size = display_size * Vector2(1.05, 1.05)`. (ADR-001)
- Direct `Camera2D.position/zoom/make_current()` mutation outside `src/autoload/camera_controller.gd`. CI: `tools/ci/check_camera_callers.gd`. (ADR-001)
- Direct `Camera2D.offset` mutation outside `src/autoload/screen_effects.gd` — shake uses shader uniform path. CI: `tools/ci/check_screen_effects_callers.gd`. (ADR-001)
- Direct `GPUParticles2D` instantiation outside `src/autoload/particle_system_wrapper.gd`. CI: `tools/ci/check_particle_callers.gd`. (ADR-001)
- Raw `JavaScriptBridge.eval()` calls outside `src/autoload/platform_detect.gd`. CI: `tools/ci/check_platform_detect_callers.gd`. (ADR-001)

## Allowed Libraries / Addons

<!-- Add approved third-party dependencies here -->
- [None configured yet — add as dependencies are approved]

## Architecture Decisions Log

<!-- Quick reference linking to full ADRs in docs/architecture/ — last updated 2026-05-26 -->
- ADR-0001 (Accepted-structural 2026-05-30): Godot Web Export Budget Caps — two-tier GPU/CPU budgets (mobile 200/2ms, desktop 400/3ms); CanvasLayer topology; SubViewport oversample fix; CI scripts; WASM bundle ≤50MB. Structural decisions Accepted (renderer/topology/CI/particle-cap); CPU budget *numbers* remain Provisional pending VS-tier mobile profiling — CPU-benchmark RATIFICATION-GATED ACs (combat AC-35, #5/#6/#7 CPU ACs) stay gated. [docs/architecture/adr-0001-web-export-budget-caps.md]
- ADR-0002 (Accepted-data-contract 2026-05-31): GymSys Integration Protocol — HTTP polling (5s ±0.5s); differential event cursor (DB BIGINT + server_epoch_id); session lock (POST /session/claim + X-Session-Token); LootDrop endpoints (per-table UNIQUE); SSE v0.2 path (JavaScriptBridge EventSource). **Signal/event data contract Locked** (5 workout signals + payload schemas, cursor, cadence, idempotency tables) — unblocks WST story-012 mock-scoped ACs. **Transport/CORS empirical validation stays VS-tier-gated**; fully Accepted requires live-backend validation (architecture-review-ratification-2026-05-31 + 2026-05-30 honesty gate). [docs/architecture/adr-0002-gymsys-integration-protocol.md]
- ADR-0003 (Accepted 2026-05-30): Save State Strategy — backend-primary + IndexedDB (user://) secondary; unsynced-only LootDrop client wins; detect-and-gate for Private Mode (banner + loot disable); Safari ITP touch-refresh; schema migration 900ms ceiling; localStorage FORBIDDEN. Ratified — structural; #3 PersistenceLayer implemented + CI-green validates IPersistence in practice. [docs/architecture/adr-0003-save-state-strategy.md]
- ADR-0006: State Machine Contract — transition atomicity (generational lock); transition_id collision-safety; tombstone forward-recovery; autoload sequential boot (Contract 4); connect_for_initial_state sentinel (Contract 6); IPersistence interface; 15 contracts total. [docs/architecture/adr-0006-state-machine-contract.md]
- ADR-0004 (Accepted-structural 2026-05-31): CORS / Cross-Origin Auth Topology — nginx reverse proxy (same origin); /mirror-hero/ game static; /api/game/ proxy to GymSys:9120; relative URLs in HTTPRequest; FastAPI APIRouter /api/game prefix. Resolves game-concept.md Q1. Topology design Accepted (no measurement gate); **VS-tier deployment/CORS empirical validation stays Provisional** (real nginx + GymSys deploy). Satisfies design-level CORS resolution for ADR-0002 data-contract ratification. [docs/architecture/adr-0004-cors-cross-origin-auth-topology.md]
- ADR-0005 (Accepted 2026-05-30): Loot Rarity Formula — loot_rarity_score = workout_score×0.75 + rng_roll×0.25; workout_score = clamp(volume×PR×streak, 0, 1); Pillar 3 floor final_tier=max(raw,COMMON); Pillar 1 proof: max RNG=0.25 < EPIC threshold(0.72); data-driven LootRarityConfig.tres; RNG seeded on transition_id. Resolves game-concept.md Q2. Ratified — formula complete + deterministic, no ADR deps; reconciles prior systems-index/technical-preferences status discrepancy. [docs/architecture/adr-0005-loot-rarity-formula.md]
- ADR-0007 (Accepted 2026-05-29): Class & Domain Enum Convention — two enum families: Outcome/State (ordinal 0 = safe default, e.g. GameState/BossOutcome) vs Classification (declaration order load-bearing, sentinel UNKNOWN last, zero-default fabrication FORBIDDEN). Locks AbilityClass {STRIKE,CONTROL,MOBILITY,UNKNOWN}; resolves #9 UNKNOWN vs #15 NEUTRAL divergence; string-name serialization via find_key/get. Closes GAP-001. [docs/architecture/adr-0007-class-enum-convention.md]
- ADR-0008 (Proposed): Autoload Position Map — project.godot is sole ground-truth for absolute positions (F-SETUP-4); partial-order constraints (1-2 locked ADR-0006 C4; PlatformDetect early; LootDrop≺EnemyDirector; Particle≺ScreenEffects); insertion rules for unwritten #33 AttentionBudget / #4 Audio / #28 Telemetry; corrects registry PlatformDetect pos 0→3. Closes GAP-002. [docs/architecture/adr-0008-autoload-position-map.md]
- ADR-0009 (Accepted 2026-05-29): Signal Payload Schema Convention — payloads minimal + intrinsic (event data + transition_id); cross-cutting context (workout_id) late-bound at handler with explicit null branch (generalizes #15 §7.5/INV-12); persisted payloads = typed SerializableResource envelopes; signal/field naming. Closes GAP-003. [docs/architecture/adr-0009-signal-payload-schema-convention.md]
- ADR-0010 (Proposed): Mirror Moment Ceremony Ownership Split — identity vs celebration seam: #26 AvatarRenderer owns visible state + evolution-tier + snapshot/hook API (render-only); #29 MirrorMoment owns weekly ceremony (cadence + non-workout gate + reveal + screenshot prompt + celebration VFX), one-directional dep on #26. Unblocks #26 BLOCKED gate. Closes GAP-004. [docs/architecture/adr-0010-mirror-moment-ceremony-ownership.md]

## Engine Specialists

<!-- Written by /setup-engine when engine is configured. -->
<!-- Read by /code-review, /architecture-decision, /architecture-review, and team skills -->
<!-- to know which specialist to spawn for engine-specific validation. -->

- **Primary**: godot-specialist
- **Language/Code Specialist**: godot-gdscript-specialist (all .gd files)
- **Shader Specialist**: godot-shader-specialist (.gdshader files, VisualShader resources)
- **UI Specialist**: godot-specialist (no dedicated UI specialist — primary covers all UI)
- **Additional Specialists**: godot-gdextension-specialist (GDExtension / native C++ bindings only)
- **Routing Notes**: Invoke primary for architecture decisions, ADR validation, and cross-cutting code review. Invoke GDScript specialist for code quality, signal architecture, static typing enforcement, and GDScript idioms. Invoke shader specialist for material design and shader code. Invoke GDExtension specialist only when native extensions are involved.

### File Extension Routing

<!-- Skills use this table to select the right specialist per file type. -->
<!-- If a row says [TO BE CONFIGURED], fall back to Primary for that file type. -->

| File Extension / Type | Specialist to Spawn |
|-----------------------|---------------------|
| Game code (.gd files) | godot-gdscript-specialist |
| Shader / material files (.gdshader, VisualShader) | godot-shader-specialist |
| UI / screen files (Control nodes, CanvasLayer) | godot-specialist |
| Scene / prefab / level files (.tscn, .tres) | godot-specialist |
| Native extension / plugin files (.gdextension, C++) | godot-gdextension-specialist |
| General architecture review | godot-specialist |
