extends Node
## CombatVisualFeedback (#25) — Pillar 3 per-hit reaction presentation coordinator.
##
## Event-driven, near-stateless reactive coordinator. Subscribes #14 EnemyDirector's
## `hit_resolved` / `enemy_killed` broadcasts + #1 GSM `state_changed`, and turns an
## already-resolved combat event into peripheral-glance sensory feedback:
##   - tier→particle preset routing via #5 `play()` (story 004+)
##   - hit-pause freeze via #6 `hit_pause()` (fills the #6 auto-dispatch pause=0 gap; story 005+)
##   - floating damage number (CombatNumberLayer Label pool; story 009)
##   - CRITICAL/OVERKILL flash overlay (CombatOverlayLayer 105; story 010)
##
## #25 owns NO combat math (#13 CombatResolver, pure static) and NO entity-lifecycle
## VFX (#14 enemy spawn/death/boss = #14's own direct calls). It is purely the
## reaction skin over a resolved hit. Fail-soft (R-20): any missing dependency →
## no crash, spectacle silently degrades (Pillar 2 still works).
##
## STORY 003 SCOPE: scaffold only — DI seam + subscription wiring + lifecycle
## substates + PROCESS_MODE_ALWAYS + handler entry points. Concrete routing
## (R-3..R-15) lands in stories 004-008; number-pool render in 009; overlay in 010;
## Suspended force-reset detail + bfcache in 012.
##
## Autoload tail-append after {#14, #6, #5, #1} per ADR-0008 G-CV-2 (story 001).

## #5 ParticleSystemWrapper has no class_name — preload to reference its closed
## PresetId library by name (#25 consumes only HIT_LIGHT / HIT_HEAVY; never adds a preset).
const PSW := preload("res://src/autoload/particle_system_wrapper.gd")
## Pure presentation formulas (F1-F5). preload (not `const := ClassName` — not a const expr).
const CvfFormulas := preload("res://src/core/combat_visual_feedback_formulas.gd")


# --- System lifecycle substates (GDD States table; detail in story 012) ---
enum Lifecycle {
	ACTIVE,     ## Boot default — receives hit_resolved/enemy_killed, routes normally
	SUSPENDED,  ## GSM SUSPENDED — force reset + reject incoming (silent no-op + debug counter)
}

# --- Overlay primitive sub-state (R-11) ---
enum OverlayState {
	IDLE,      ## visible=false, zero per-frame cost
	FLASHING,  ## CRITICAL/OVERKILL flash active (latest-wins single-instance)
}

# --- Flash climax kind (R-11; selects opacity/duration) ---
enum FlashKind {
	CRITICAL,  ## 0.35 opacity / 0.18s
	OVERKILL,  ## 0.6 opacity / 0.12s
}

# --- Damage-number visual style (R-12 dual-axis; keyed on is_crit ONLY) ---
enum NumberStyle {
	PLAIN,  ## white, no bounce (is_crit == false)
	CRIT,   ## warm-orange + bounce (is_crit == true) — foveal bonus, NOT the tier carrier
}

## _process delta clamp (EC bfcache / Suspended resume — large delta would make a
## number/overlay jump or linger for one frame; story 012 wires resume). Data-driven
## knob migrates to CombatVisualFeedbackConfig in story 016 (G-CV-5).
const MAX_FRAME_DELTA: float = 0.1

## G-CV-3 combat-hit SFX cue contract (consumer-forward): #25 TRIGGERS these event ids;
## #4 AudioManager owns the catalog + playback. Unknown ids no-op at #4 (Rule 8), so the
## catalog can land later (Q-CV1 erratum) without #25 churn. NEGLIGIBLE = no cue (silent).
const CUE_HIT_LIGHT: StringName = &"sfx_hit_light"
const CUE_HIT_HEAVY: StringName = &"sfx_hit_heavy"        ## thud
const CUE_HIT_CRITICAL: StringName = &"sfx_hit_critical"  ## chime
const CUE_OVERKILL: StringName = &"sfx_overkill"          ## impact
const CUE_KILL: StringName = &"sfx_kill"

## CombatNumberLayer sort order (ADR-0001 G-CV-1; 15 provisional, Q-CV2 ratification scope).
const NUMBER_LAYER: int = 15
## Damage-number colours (R-12 style axis). CRIT = warm orange, PLAIN = white.
const NUMBER_COLOR_PLAIN: Color = Color(1.0, 1.0, 1.0)
const NUMBER_COLOR_CRIT: Color = Color(1.0, 0.72, 0.30)


# --- Untyped DI seams (reference_gdscript_di_seam — typed Node breaks compile-time
# member check; tests inject fakes before add_child) ---
var _enemy_director = null   ## #14 EnemyDirector (HARD — hit_resolved / enemy_killed source)
var _gsm = null              ## #1 GameStateMachine (SOFT — Suspended reset, Contract 6)
var _particles = null        ## #5 ParticleSystemWrapper (HARD — play(); story 004+)
var _screen_fx = null        ## #6 ScreenEffects (HARD — hit_pause(); story 005+)
var _avatar = null           ## #26 AvatarRenderer (v0.2-only — anchor read; NOT MVP dep, R-17)
var _persistence = null      ## #3 PersistenceLayer (SOFT — settings.motion_intensity read, a11y)
var _audio = null            ## #4 AudioManager (SOFT — combat-hit cue trigger; G-CV-3 consumer-forward)
## Optional clock seam: an object exposing now_ms() -> int. Tests inject a controllable
## clock for dedup/coalescing (story 008); production falls back to Time.get_ticks_msec().
var _clock = null


# --- Near-stateless runtime containers ---
## R-14 short-term idempotency set: key "transition_id|target_id" → true. Guards against
## a duplicate hit_resolved emission spawning two reactions. Evicted per-target on
## enemy_killed + fully cleared on Suspended.
var _seen: Dictionary = {}
## R-15 / Formula 3 coalescing window: target_id (int) → last #25 particle emit ms.
## int-clean sentinel (`not has()` = first hit), never -INF. Evicted per-target on
## enemy_killed (leak guard — a 30-60min workout kills thousands of enemies) + cleared
## on Suspended.
var _last_particle_ms: Dictionary = {}

# --- Render hosts ---
var _number_layer: CanvasLayer = null    ## CombatNumberLayer (story 009)
var _overlay_layer: CanvasLayer = null   ## CombatOverlayLayer 105 (story 010)
## Cosmetic anchor jitter RNG (R-17/F5 — created once at boot, not per hit).
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## R-19 pre-instantiated Label pool (no runtime Label.new() per hit — AC-29).
var _number_pool: Array[Label] = []
## Active floating numbers: Array of {label, base: Vector2, t: float, color: Color}.
## _process ticks Formula 1 rise/fade; t ≥ LIFETIME → release back to the pool.
var _active_numbers: Array = []

# --- Lifecycle state ---
var _lifecycle: int = Lifecycle.ACTIVE
var _ready_complete: bool = false
## Debug-only: incoming signals rejected while SUSPENDED (States table; story 012 asserts).
var _rejected_while_suspended: int = 0
## Last per-frame delta after MAX_FRAME_DELTA clamp (bfcache resume observable, AC-17).
var _last_clamped_delta: float = 0.0
## Floating damage numbers spawned (real Label-pool render lands in story 009; this
## counter is the routing-level seam stories 004-008 assert against).
var _numbers_spawned: int = 0
## Style of the most recently spawned number (R-12; story 009 number pool consumes it).
var _last_number_style: int = NumberStyle.PLAIN
## Overlay primitive sub-state (R-11).
var _overlay_state: int = OverlayState.IDLE
## Live flash decay state (latest-wins single-instance).
var _overlay_t: float = 0.0
var _overlay_max_opacity: float = 0.0
var _overlay_duration: float = 0.0
## motion_intensity captured at flash start (a11y gate; 0 → no visible flash, AC-25).
var _overlay_motion_scale: float = 1.0
## ADR-0001 G-CV-1 ratification gate (EC-20). Pre-ratification = false → degrade:
## no flash + CRITICAL pause bumped to CRITICAL_DEGRADE_PAUSE_SEC. Story 016 wires from config.
var _overlay_enabled: bool = false
## Layer × ColorRect host for the full-screen flash (CombatOverlayLayer 105).
const OVERLAY_LAYER: int = 105
var _overlay_rect: ColorRect = null


func _ready() -> void:
	# Resolve dependency seams from the autoload tree unless a test pre-injected a fake.
	if _enemy_director == null:
		_enemy_director = _node_or_null(&"EnemyDirector")
	if _gsm == null:
		_gsm = _node_or_null(&"GameStateMachine")
	if _particles == null:
		_particles = _node_or_null(&"ParticleSystemWrapper")
	if _screen_fx == null:
		_screen_fx = _node_or_null(&"ScreenEffects")
	if _avatar == null:
		_avatar = _node_or_null(&"AvatarRenderer")
	if _persistence == null:
		_persistence = _node_or_null(&"PersistenceLayer")
	if _audio == null:
		_audio = _node_or_null(&"AudioManager")

	# EC-15: hit_resolved must be received while #6 holds a tree pause (hit_pause); the
	# number-pool rise/fade + overlay decay _process must keep ticking. PROCESS_MODE_ALWAYS.
	process_mode = Node.PROCESS_MODE_ALWAYS

	_build_number_layer()
	_build_overlay_layer()

	# #14 hit_resolved / enemy_killed are plain event broadcasts (not initial-state
	# sentinels) — raw .connect() with a has_signal guard, mirroring the shipped
	# loot_drop_system.gd precedent (LootDrop subscribes #14 enemy_killed the same way).
	# (check_enemy_director_signal_subscription only governs enemy_director.gd itself.)
	if _enemy_director != null:
		if _enemy_director.has_signal("hit_resolved") \
				and not _enemy_director.hit_resolved.is_connected(_on_hit_resolved):
			_enemy_director.hit_resolved.connect(_on_hit_resolved)
		if _enemy_director.has_signal("enemy_killed") \
				and not _enemy_director.enemy_killed.is_connected(_on_enemy_killed):
			_enemy_director.enemy_killed.connect(_on_enemy_killed)

	# GSM state_changed via Contract 6 connect_for_initial_state (boot back-fills the
	# current state to this late-booting tail autoload; raw state_changed.connect is
	# banned project-wide by check_attention_subscription).
	if _gsm != null and _gsm.has_method("connect_for_initial_state"):
		_gsm.connect_for_initial_state(_on_state_changed)

	_ready_complete = true


func _process(delta: float) -> void:
	if not _ready_complete or _lifecycle == Lifecycle.SUSPENDED:
		return
	# Clamp so a bfcache/resume frame can't make a number jump (Formula 1 ratio is also
	# clamped, so this is belt-and-braces). Story 012 wires bfcache resume.
	var clamped: float = minf(delta, MAX_FRAME_DELTA)
	_last_clamped_delta = clamped
	_tick_numbers(clamped)
	_tick_overlay(clamped)


# --- Signal handlers ----------------------------------------------------------

## #14 EnemyDirector.hit_resolved — the per-hit reaction entry point.
## Payload = CombatResolver.HitResolvedPayload (intrinsic: damage_tier / outcome /
## is_crit / damage_dealt / target_id / transition_id; NO position — ADR-0009).
## R-3 outcome-first gate; tier branch R-4..R-8 (HEAVY/CRITICAL → story 005).
func _on_hit_resolved(payload) -> void:
	if _lifecycle == Lifecycle.SUSPENDED:
		_rejected_while_suspended += 1
		return
	if payload == null:
		return
	# R-14 dedup: a duplicate hit_resolved (same transition_id + target_id) reacts once.
	# (Distinct hits on the same target carry distinct transition_ids, so legitimate
	# repeat hits are NOT blocked — only exact-duplicate emissions.)
	var key: String = _dedup_key(payload.transition_id, payload.target_id)
	if _seen.has(key):
		return
	_seen[key] = true
	# R-3: outcome gate FIRST. KILLED / OVERKILL take the kill branch (story 006);
	# everything else routes on damage_tier.
	var outcome: int = payload.outcome
	if outcome == CombatResolver.HitOutcome.KILLED or outcome == CombatResolver.HitOutcome.OVERKILL:
		_route_kill(payload)
		return
	_route_tier(payload)


## R-2/R-4/R-5/R-6: tier branch. Routing key is ALWAYS payload.damage_tier — NEVER
## re-classified from damage_dealt/damage_raw (FR Test #4, AC-02). HEAVY/CRITICAL
## (hit_pause + R-13 guard) lands in story 005.
func _route_tier(payload) -> void:
	var tier: int = payload.damage_tier
	match tier:
		CombatResolver.DamageTier.NEGLIGIBLE:
			return  # R-4: zero reaction (Pillar 2 noise suppression; LIGHT is the floor)
		CombatResolver.DamageTier.LIGHT, CombatResolver.DamageTier.MEDIUM:
			# R-5 / R-6: MVP shares HIT_LIGHT (no shake, no pause); tier distinction is
			# number style only (is_crit → story 007). #6 auto-dispatch is NO-OP for HIT_LIGHT.
			_play_preset(PSW.PresetId.HIT_LIGHT, payload)
			_spawn_number(payload)
			_play_cue(payload.outcome, tier)
		CombatResolver.DamageTier.HEAVY, CombatResolver.DamageTier.CRITICAL:
			_route_heavy(payload)  # story 005


## R-7/R-8 HEAVY/CRITICAL: both share HIT_HEAVY (closed library has no HIT_CRITICAL).
## #6 auto-dispatches shake(0.4) from the HIT_HEAVY burst — #25 NEVER direct-shakes (R-13).
## #25 direct-calls hit_pause (Formula 4) to fill the #6 auto-dispatch pause=0 gap, and
## fires the CRITICAL flash overlay (R-11) when ratified; pre-ratification (EC-20 degrade)
## the flash is skipped and the CRITICAL pause bumps to CRITICAL_DEGRADE_PAUSE_SEC.
func _route_heavy(payload) -> void:
	_play_preset(PSW.PresetId.HIT_HEAVY, payload)
	_spawn_number(payload)
	var outcome: int = payload.outcome
	var tier: int = payload.damage_tier
	# R-12: screen-feel (flash + pause) keyed on damage_tier. Flash only when ratified.
	if _overlay_enabled and CvfFormulas.wants_flash(outcome, tier):
		_request_flash(_flash_kind(outcome))
	_hit_pause(CvfFormulas.hit_pause_sec(outcome, tier, _overlay_enabled))
	_play_cue(outcome, tier)


## R-9/R-10 KILLED/OVERKILL kill branch. ALWAYS spawns a kill/overkill-confirm number.
## #25 NEVER play(DEATH) (#14 owns enemy death VFX) and NEVER direct-shakes (#14 DEATH
## already auto-dispatches shake 0.3 — a #25 shake = double). The climax pause + flash
## are #25's additive celebration layer:
##   - OVERKILL → flash + hit_pause(0.080)                          (R-10)
##   - KILLED + CRITICAL tier → flash + hit_pause(0.080)            (R-9 招牌「一刀劈死」carve-out)
##   - KILLED + lower tier → kill number only (no pause, no flash)  (稀疏即重量)
## F4 / wants_flash already encode the carve-out; the router just consults them. EC-20
## degrade applies identically (no flash, pause → 0.100).
func _route_kill(payload) -> void:
	_spawn_number(payload)
	var outcome: int = payload.outcome
	var tier: int = payload.damage_tier
	if _overlay_enabled and CvfFormulas.wants_flash(outcome, tier):
		_request_flash(_flash_kind(outcome))
	_hit_pause(CvfFormulas.hit_pause_sec(outcome, tier, _overlay_enabled))
	_play_cue(outcome, tier)


# --- Effect emission (fail-soft — R-16/R-20) ----------------------------------

## G-CV-3 combat-hit cue (consumer-forward, onset-aligned with the visual peak). #25 only
## TRIGGERS — #4 owns playback + catalog (fail-soft if #4 absent → silent-mode, the visual
## stays fully readable on its own, Pillar 2). NEGLIGIBLE → no cue.
func _play_cue(outcome: int, tier: int) -> void:
	var cue: StringName = _cue_for(outcome, tier)
	if cue == &"":
		return
	if _audio != null and _audio.has_method("play_sfx"):
		_audio.play_sfx(cue)


## tier/outcome → #4 cue event id. Mirrors the visual escalation (OVERKILL impact /
## critical-kill + CRITICAL chime / kill / HEAVY thud / light tick). NEGLIGIBLE = silent.
func _cue_for(outcome: int, tier: int) -> StringName:
	if outcome == CombatResolver.HitOutcome.OVERKILL:
		return CUE_OVERKILL
	if outcome == CombatResolver.HitOutcome.KILLED:
		return CUE_HIT_CRITICAL if tier == CombatResolver.DamageTier.CRITICAL else CUE_KILL
	match tier:
		CombatResolver.DamageTier.CRITICAL:
			return CUE_HIT_CRITICAL
		CombatResolver.DamageTier.HEAVY:
			return CUE_HIT_HEAVY
		CombatResolver.DamageTier.LIGHT, CombatResolver.DamageTier.MEDIUM:
			return CUE_HIT_LIGHT
		_:
			return &""

## Route a particle preset through #5 (shares the global 200 cap; #5 arbitrates LRU).
## Never instantiates GPUParticles2D directly (ADR-0001). R-15 coalescing gates ONLY
## this play() (number/pause/overlay are unaffected — they have their own budgets).
## Graceful no-op if #5 absent (R-16 INVALID handle / R-20 fail-soft).
func _play_preset(preset_id: int, payload) -> void:
	if not _should_emit_particle(payload.target_id, _now_ms()):
		return  # EC-03: coalesced — particle suppressed, but number still spawns in the router
	if _particles != null and _particles.has_method("play"):
		_particles.play(preset_id, _focal_point(payload), 1.0)


## Formula 3 (R-15) — per-target particle coalescing gate. Mutates _last_particle_ms
## (stateful, so it lives here not in the pure formulas file). First hit (no entry)
## always emits via the int-clean `not has()` sentinel.
func _should_emit_particle(target_id: int, now_ms: int) -> bool:
	if not _last_particle_ms.has(target_id) \
			or now_ms - int(_last_particle_ms[target_id]) >= CvfFormulas.HIT_PARTICLE_COALESCE_MS:
		_last_particle_ms[target_id] = now_ms
		return true
	return false


## R-13 double-shake guard: #25 ONLY ever direct-calls #6 hit_pause — NEVER shake.
## shake is provided by #6 auto-dispatch off the #5 HIT_HEAVY/DEATH burst. Enforced by
## check_cvf_no_direct_shake.gd (AC-11). Null/zero-safe (fail-soft R-20).
func _hit_pause(duration: float) -> void:
	if duration <= 0.0:
		return
	if _screen_fx != null and _screen_fx.has_method("hit_pause"):
		_screen_fx.hit_pause(duration)


## R-11: enter (or restart) the FLASHING overlay. Latest-wins single-instance — a new
## climax resets t=0 and adopts the new climax's opacity + duration (≤1 active, EC-04).
func _request_flash(kind: int) -> void:
	_overlay_state = OverlayState.FLASHING
	_overlay_t = 0.0
	# Capture motion_intensity once at flash start (a11y gate; 0 → invisible flash). hit_pause
	# is NOT scaled — a visual freeze is distinct from vestibular motion (a11y doc §2).
	_overlay_motion_scale = _motion_intensity()
	if kind == FlashKind.OVERKILL:
		_overlay_max_opacity = CvfFormulas.OVERLAY_MAX_OPACITY_OVERKILL
		_overlay_duration = CvfFormulas.OVERKILL_FLASH_DURATION_SEC
	else:
		_overlay_max_opacity = CvfFormulas.OVERLAY_MAX_OPACITY_CRITICAL
		_overlay_duration = CvfFormulas.CRITICAL_FLASH_DURATION_SEC
	if _overlay_rect != null:
		_overlay_rect.color.a = _overlay_max_opacity * _overlay_motion_scale
		_overlay_rect.visible = true


## The flash climax kind for a (outcome, tier): OVERKILL → OVERKILL flash; everything
## else that flashes (CRITICAL tier, critical-kill carve-out) → CRITICAL flash.
func _flash_kind(outcome: int) -> int:
	return FlashKind.OVERKILL if outcome == CombatResolver.HitOutcome.OVERKILL else FlashKind.CRITICAL


## a11y motion-intensity [0,1] (UX-04 / AC-25). Source of truth is #6 ScreenEffects, but it
## exposes no getter (grep-verified) — so prefer a future get_motion_intensity() (has_method
## guard) then read settings.motion_intensity from persistence (the shipped source, #22 writes
## it there). Default 1.0 (full) — fail-soft. Scales the flash opacity ONLY (never hit_pause).
func _motion_intensity() -> float:
	if _screen_fx != null and _screen_fx.has_method("get_motion_intensity"):
		return clampf(_screen_fx.get_motion_intensity(), 0.0, 1.0)
	if _persistence != null and _persistence.has_method("read"):
		var v = _persistence.read("settings.motion_intensity")
		if v != null:
			return clampf(float(v), 0.0, 1.0)
	return 1.0


# --- Overlay primitive (R-11 / Formula 2; CombatOverlayLayer 105) -------------

## Full-screen flash host. ColorRect + flat alpha (no texture, ≤1 blend pass). >100 so
## shake/BBCopy-immune (ADR-0001 G-CV-1). Pre-warmed hidden — IDLE = zero per-frame cost.
func _build_overlay_layer() -> void:
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.name = "CombatOverlayLayer"
	_overlay_layer.layer = OVERLAY_LAYER
	add_child(_overlay_layer)
	_overlay_rect = ColorRect.new()
	_overlay_rect.color = Color(1.0, 1.0, 1.0, 0.0)
	_overlay_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE  # never steal the one-tap (UX-06)
	_overlay_rect.visible = false
	_overlay_layer.add_child(_overlay_rect)


## Formula 2 decay tick. IDLE short-circuits (zero cost). t ≥ duration → IDLE + hide.
func _tick_overlay(delta: float) -> void:
	if _overlay_state != OverlayState.FLASHING:
		return
	_overlay_t += delta
	if _overlay_t >= _overlay_duration:
		_overlay_state = OverlayState.IDLE
		if _overlay_rect != null:
			_overlay_rect.visible = false
		return
	if _overlay_rect != null:
		_overlay_rect.color.a = CvfFormulas.overlay_alpha(_overlay_t, _overlay_max_opacity, _overlay_duration) * _overlay_motion_scale


## Force the overlay OFF (Suspended / bfcache resume — States table).
func _overlay_off() -> void:
	_overlay_state = OverlayState.IDLE
	_overlay_t = 0.0
	if _overlay_rect != null:
		_overlay_rect.visible = false


## Spawn a floating damage number (R-19 pool). R-12: STYLE keyed on `is_crit` ONLY
## (warm-orange vs plain white) — independent of the damage_tier/outcome screen-feel.
func _spawn_number(payload) -> void:
	_numbers_spawned += 1
	var style: int = NumberStyle.CRIT if payload.is_crit else NumberStyle.PLAIN
	_last_number_style = style
	_acquire_number(_focal_point(payload), style, payload.damage_dealt)


# --- Damage-number pool (R-19 / Formula 1; no runtime alloc — AC-29) ----------

## Pre-instantiate the Label pool + its follow-viewport host once at boot. Per-hit spawns
## acquire/recycle from this pool — never Label.new() at runtime (mobile WASM GC hitch).
func _build_number_layer() -> void:
	_number_layer = CanvasLayer.new()
	_number_layer.name = "CombatNumberLayer"
	_number_layer.layer = NUMBER_LAYER
	# follow_viewport_enabled is the design intent (numbers ride the world+shake); the
	# exact接駁 vs fixed-viewport degrade is Q-CV2 ratification scope (story 011 focal).
	_number_layer.follow_viewport_enabled = true
	add_child(_number_layer)
	for _i: int in CvfFormulas.MAX_CONCURRENT_DAMAGE_NUMBERS:
		var lbl := Label.new()
		lbl.visible = false
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE  # never steal the one-tap (UX-06)
		_number_layer.add_child(lbl)
		_number_pool.append(lbl)


## Acquire a pooled Label for a new number. Pool full → oldest-recycle (latest-wins,
## EC-11/R-19). Fail-soft if the host was never built (degraded — number simply absent).
func _acquire_number(base_pos: Vector2, style: int, value: int) -> void:
	if _number_layer == null or _number_pool.is_empty():
		return
	var lbl: Label = _free_label()
	if lbl == null:
		var oldest: Dictionary = _active_numbers[0]
		_active_numbers.remove_at(0)
		lbl = oldest["label"]
	var col: Color = NUMBER_COLOR_CRIT if style == NumberStyle.CRIT else NUMBER_COLOR_PLAIN
	lbl.text = str(value)
	lbl.position = base_pos
	lbl.modulate = Color(col.r, col.g, col.b, 1.0)
	lbl.visible = true
	_active_numbers.append({"label": lbl, "base": base_pos, "t": 0.0, "color": col})


## A pool Label not currently in the active list, else null (→ oldest-recycle).
func _free_label() -> Label:
	for lbl: Label in _number_pool:
		var in_use: bool = false
		for e: Dictionary in _active_numbers:
			if e["label"] == lbl:
				in_use = true
				break
		if not in_use:
			return lbl
	return null


## Advance every active number's Formula 1 rise+fade; release expired ones to the pool.
func _tick_numbers(delta: float) -> void:
	var i: int = _active_numbers.size() - 1
	while i >= 0:
		var e: Dictionary = _active_numbers[i]
		e["t"] = float(e["t"]) + delta
		if float(e["t"]) >= CvfFormulas.DAMAGE_NUMBER_LIFETIME_SEC:
			_release_number(e["label"])
			_active_numbers.remove_at(i)
		else:
			var lbl: Label = e["label"]
			var base: Vector2 = e["base"]
			lbl.position = base + Vector2(0.0, CvfFormulas.number_y_offset(e["t"]))
			var c: Color = e["color"]
			lbl.modulate = Color(c.r, c.g, c.b, CvfFormulas.number_alpha(e["t"]))
		i -= 1


func _release_number(lbl: Label) -> void:
	lbl.visible = false


## Release every active number (Suspended force-reset; full bfcache wiring = story 012).
func _release_all_numbers() -> void:
	for e: Dictionary in _active_numbers:
		_release_number(e["label"])
	_active_numbers.clear()


## R-17 / Formula 5: hit spawn position. MVP = camera-relative fixed focal point + the
## deterministic anchor offset + cosmetic jitter. The #14 payload has NO contact position
## and #26 exposes no anchor/facing API (render-only, ADR-0010) — so this never queries
## #26 (that is the v0.2 enhancement, Q-CV4). facing fixed +1 (no #26 facing source).
func _focal_point(_payload) -> Vector2:
	var base: Vector2 = CvfFormulas.anchor_base(_camera_relative_focal(), 1)
	var j: float = CvfFormulas.ANCHOR_JITTER_PX
	return base + Vector2(_rng.randf_range(-j, j), _rng.randf_range(-j, j))


## MVP camera-relative focal: the world point at screen lower-centre via the active
## Camera2D. EC-19 fail-soft: camera not ready (boot) → screen-centre default, no crash.
func _camera_relative_focal() -> Vector2:
	var vp := get_viewport()
	if vp == null:
		return Vector2.ZERO
	var cam := vp.get_camera_2d()
	if cam == null:
		# EC-19: no active camera yet → screen-centre world default (this IS the MVP
		# normal state when no camera is mounted, not a degraded fallback — EC-10).
		return vp.get_visible_rect().size * 0.5
	var vp_size: Vector2 = vp.get_visible_rect().size
	var down: float = vp_size.y * 0.25 / maxf(cam.zoom.y, 0.001)
	return cam.get_screen_center_position() + Vector2(0.0, down)


## #14 EnemyDirector.enemy_killed — NON-VISUAL cleanup hook (R-14). The kill VISUAL
## already fired via hit_resolved(outcome=KILLED/OVERKILL) — enemy_killed must NOT spawn
## a second number/pause. Its sole job is to evict this enemy's per-target state so the
## coalescing + dedup dicts do not grow unbounded across a 30-60min workout.
## NOTE (grep-verified erratum): the enemy id lives in `enemy_instance_id` here, NOT
## `target_id` — but it equals hit_resolved.target_id (both = the enemy's instance_id).
func _on_enemy_killed(payload) -> void:
	if _lifecycle == Lifecycle.SUSPENDED:
		_rejected_while_suspended += 1
		return
	if payload == null:
		return
	var enemy_id: int = payload.enemy_instance_id
	_last_particle_ms.erase(enemy_id)
	_evict_seen_for_target(enemy_id)


## #1 GSM.state_changed via connect_for_initial_state (callable receives the full
## state_changed signature). SUSPENDED → force reset + reject incoming (GDD States table,
## #6「Suspended 永遠覆蓋一切」). Leaving Suspended → Active + force-clear residual.
func _on_state_changed(_from_state, to_state, _payload) -> void:
	if to_state == _gsm_state(&"SUSPENDED"):
		_enter_suspended()
		return
	# Leaving Suspended (or any non-Suspended state) → Active. Belt-and-braces: clear any
	# residual visual that survived the enter-clear (guarantees no leftover flash/number).
	if _lifecycle == Lifecycle.SUSPENDED:
		_force_reset()
	_lifecycle = Lifecycle.ACTIVE


# --- Lifecycle transitions ----------------------------------------------------

## Suspended overrides everything (mirrors #6 contract) + rejects incoming.
func _enter_suspended() -> void:
	_lifecycle = Lifecycle.SUSPENDED
	_force_reset()


## Clear ALL transient visual state — overlay OFF, number pool released, coalescing +
## dedup dicts cleared. Shared by Suspended enter, resume, and bfcache (EC-08/09): after
## this there is provably no residual flash or mid-rise number.
func _force_reset() -> void:
	_last_particle_ms.clear()
	_seen.clear()
	_release_all_numbers()
	_overlay_off()


## bfcache resume hardening (EC-09): Safari pageshow may restore a snapshot with a latched
## flash / mid-rise number — force a clean state. The _process MAX_FRAME_DELTA clamp handles
## the large first-frame delta (AC-17). Mirrors screen_effects.gd _notification.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		_force_reset()


# --- Helpers ------------------------------------------------------------------

## R-14 dedup key. transition_id + target_id uniquely identify one resolved hit.
func _dedup_key(transition_id: String, target_id: int) -> String:
	return transition_id + "|" + str(target_id)


## Evict every _seen entry for one enemy (called on its enemy_killed). Keys end with
## "|<target_id>"; the set is short-lived (cleared on Suspended) so the scan is cheap.
func _evict_seen_for_target(target_id: int) -> void:
	var suffix: String = "|" + str(target_id)
	for k: String in _seen.keys():
		if k.ends_with(suffix):
			_seen.erase(k)


## Monotonic clock through the injectable seam (Forbidden: direct Time.get_ticks_msec()
## elsewhere — F3 coalescing is time-dependent and would flake on the real clock; tests
## inject a controllable FakeClock). This is the single sanctioned Time fallback site.
func _now_ms() -> int:
	if _clock != null and _clock.has_method("now_ms"):
		return int(_clock.now_ms())
	return Time.get_ticks_msec()


## Resolve a GSM GameState enum value through the untyped seam (String() key so a
## StringName resolves against the String-keyed enum dict on every Godot 4 minor).
## Returns -1 if GSM is absent (fail-soft).
func _gsm_state(name: StringName) -> int:
	if _gsm != null and "GameState" in _gsm:
		return int(_gsm.GameState[String(name)])
	return -1


func _node_or_null(autoload_name: StringName):
	var root := get_node_or_null("/root")
	if root == null:
		return null
	return root.get_node_or_null(NodePath(String(autoload_name)))
