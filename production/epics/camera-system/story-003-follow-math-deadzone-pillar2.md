# Story 003: Follow Mode Math + Dead-zone + Pillar 2 Lock-on Proof

> **Epic**: Camera System
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: L
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-01

## Context

**GDD**: `design/gdd/camera-system.md`
**Requirement**: `TR-camera-002`, `TR-camera-004`, `TR-camera-007`, `TR-camera-008`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001 (Web Export Budget Caps, **Accepted-structural 2026-05-30**)
**ADR Decision Summary**: Follow mode = Camera2D `position_smoothing_enabled` + `position_smoothing_speed=5.0`（frame-rate-independent exponential decay，Formula 1）。Dead-zone 8%×12% asymmetric。Pillar 2 hard contract：30px glance-back lock-on < 500ms（Formula 4，461ms）。

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: **`func update(delta)` DI seam 係 BLOCKING** — GUT headless 唔可靠真 `_process()` 做 deterministic frame-step。`_process(delta)` delegate `update(delta)`。Formula 1：`pos_new = pos_old + (target - pos_old) × (1 - exp(-k×delta))`，frame-rate-independent post-4.4。

**Control Manifest Rules (this layer — Foundation)**:
- Required: `update(delta)` DI seam；frame-rate-independent smoothing；dead-zone stability
- Forbidden: custom spring math（VS-tier 用 Godot built-in）
- Guardrail: Pillar 2 lock-on < 500ms（hard metric）

---

## Acceptance Criteria

*From GDD Section H, scoped to this story:*

- [ ] **AC-07** — target +200px horizontal, 6 frames @60fps → camera.position.x ≈ 78.7px（Formula 1: `200×(1-exp(-5.0×0.1))≈78.69`，±1px）。
- [ ] **AC-08** — target inside dead-zone box（< half-extent）→ camera position delta == 0（no movement）。
- [ ] **AC-09** [Pillar 2 / AC-D1] — target 30px offset，accumulate `update(1/60)` until `|cam-target| < 3.0px` → t_lock < 500ms（Formula 4，461ms，≤30 frames）。
- [ ] **AC-10** [AC-D4] — target jitter ±5px inside dead-zone 120 frames → camera position variance < 0.5px²（no oscillation）。
- [ ] **AC-30** [AC-G1] — Formula 4 safe-range corners：(5.0,3.0)→461ms / (5.0,8.0)→200ms / (8.0,3.0)→288ms / (8.0,8.0)→166ms 全 <500ms；out-of-range (4.9,2.9)→527ms >500（floor justified）。

---

## Implementation Notes

*Derived from ADR-0001 + GDD Rules 2/3 / Formula 1/4/5:*

- `update(delta)`：clamp `delta = min(delta, MAX_FRAME_DELTA)`；Following → apply dead-zone（target 喺 box 內 → no move）+ Formula 1 smoothing toward clamped target。
- Constants: `POSITION_SMOOTHING_SPEED=5.0`、`LOCK_ON_TOLERANCE_PX=3.0`、`MAX_FRAME_DELTA=0.1`、`DRAG_HORIZONTAL_MARGIN=0.04`、`DRAG_VERTICAL_MARGIN=0.06`。
- Formula 4 `glance_lock_on_time(d0, d_tol, k) = ln(d0/d_tol)/k` — **static pure func**（AC-30 零 stub）。
- Dead-zone extents（Formula 5）：`Vector2(viewport.x×(m_l+m_r), viewport.y×(m_t+m_b))/zoom` — 用 `_viewport_size_override` seam（deterministic，唔 call get_viewport().size）。

---

## Out of Scope

*Handled by neighbouring stories:*

- Story 004-005: focal tweens（Following 用 smoothing，Focal disable smoothing）
- Story 008: viewport resize recompute（呢度用固定 viewport）+ target-lost
- Story 007: Suspended reset

---

## QA Test Cases

> **Seams**: `func update(delta)` DI（AC-07/08/09/10 全依賴）；`_camera.position`/`_follow_target.global_position` injectable；Formula 4 static func（AC-30 零 stub）。全部 pure Formula 1+4+5 — 無需真 Camera2D node。determinism：jitter 用固定 pattern（alternate ±5）唔用 random。

- **AC-07**: Formula 1 decay
  - Given: camera+target same pos；k=5.0；dt=1/60；dead-zone disabled 或 200px > half-extent
  - When: target +200px x；`update(1/60)` × 6
  - Then: `assert_almost_eq(_camera.position.x, 78.69, 1.0)`（`200×(1-exp(-0.5))`）
  - Edge: y stays 0；optional frame-rate-independence（12 frames @1/120 同結果）

- **AC-08**: dead-zone no-move
  - Given: camera at origin；target moved < dead-zone half-extent horizontal
  - When: `update(1/60)` several frames
  - Then: `_camera.position == start`（exact，delta 0）
  - Edge: boundary at exactly half-extent（define inclusive/exclusive）；inside→0，just-outside→non-zero

- **AC-09**: Pillar 2 lock-on（BLOCKING，update(delta) 100% dependent）
  - Given: target 30px offset；k=5.0；d_tol=3.0
  - When: loop `update(1/60)` counting frames until `abs(cam.x-target.x) < 3.0`
  - Then: `frames × (1000/60) < 500ms`（≈461ms，≤30 frames）
  - Edge: guard infinite loop（cap 200 iters，fail fast if not locked）

- **AC-10**: dead-zone stability
  - Given: camera settled；target oscillates ±5px（inside dead-zone）120 frames
  - When: `update(1/60)` each frame，record position.x
  - Then: variance < 0.5px²
  - Edge: ±5px < dead-zone half-extent（precondition assert）；deterministic jitter（NO random）

- **AC-30**: Formula 4 safe-range corners（pure static）
  - When: eval `glance_lock_on_time(30, d_tol, k)` 5 corners
  - Then: (5.0,3.0)→~461、(5.0,8.0)→~200、(8.0,3.0)→~288、(8.0,8.0)→~166 全 <500（±5ms）；(4.9,2.9)→~527 >500（floor load-bearing）
  - Edge: ✗ corner 係重點（證 floor 非任意）；static func 無 camera/tween

---

## Test Evidence

**Story Type**: Logic / Performance
**Required evidence**:
- `tests/unit/camera/test_follow_mode_math.gd`（AC-07,08,10,30）+ `tests/performance/camera/test_pillar2_lockon.gd`（AC-09）

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001（camera registered + update seam）
- Unlocks: Story 004（Focal disable smoothing）、Story 008（viewport recompute）
