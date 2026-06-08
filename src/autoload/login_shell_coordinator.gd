## LoginShellCoordinator — #24 Login / GymSys Connection UI autoload.
## (story 003 scaffold: single coordinator + 2 CanvasLayers + 4 sub-controllers
##  + cfis GSM connect + zero-persist invariant. FSM dispatch = story 004;
##  banner severity/dedup = story 010; claim/logout flows = stories 008/014.)
##
## Driving GDD: design/gdd/login-gymsys-connection-ui.md (✅ APPROVED 2026-06-08)
## UX spec:     design/ux/login-gymsys-connection-ui.md (✅ APPROVED)
## Governing ADRs:
##   - ADR-0001 (#24 G-LS-1 revision): LoginShellLayer 62 PAUSABLE (inside the
##     BackBufferCopy capture band 0/10/50/60/61/62) + ErrorBannerLayer 111 ALWAYS
##     (>100 shake/saturation-immune; <120 below #21 loot modal; opacity-only
##     backdrop — NO 2nd BackBufferCopy, AC-36).
##   - ADR-0006 C6: connect_for_initial_state for GSM (boot-surface — see below).
##   - ADR-0008 (G-LS-2): tail append after InventoryUICoordinator — NO #21/#22/#23
##     boot-order constraint (convention, not binding).
##
## ============ Rule 1 — single-coordinator ownership ============
## ONE autoload owns BOTH CanvasLayers + ALL 4 responsibilities. The 4
## sub-controllers (LoginPanel / ConnectionStatus / BannerStack / ShellEntry) are
## coordinator-owned CHILD NODES — NOT a second autoload. The established #22/#23
## file-split pattern (one autoload coordinator + src/ui/[system]/*.gd helper files)
## applies: BannerStack + shell transitions are extracted to
## src/ui/login_shell/banner_stack.gd + shell_transitions.gd so the AC-35a
## banner-static-discipline grep scope is unambiguous — the LEGITIMATE animated
## state-transition cross-fade lives in shell_transitions.gd and is never mistaken
## for a forbidden banner pulse (the banner itself is zero-animation). "唔開第二
## autoload" (Rule 1) and "拆 file" do not conflict — precedent says so; Rule 14's
## ScreenLifecycleFsm extraction is NOT a file-layout mandate.
## ===============================================================
##
## Boot-surface (≠ #22/#23 overlay): the shell is the always-listening boot surface,
## so GSM is connected via connect_for_initial_state at _ready() (AC-27) — NOT on an
## open() like the #22/#23 CLOSED-at-boot overlays. The shell must receive the
## current GSM state from boot (boot-race close — AC-03/AC-53, story 004/005).
##
## Zero-persist invariant (= #23 negative AC-37): #24 owns NO persisted state. The
## only token write in a claim cycle comes from #2 GymSysBackendClient, never #24.
## AC-02 pins this from the scaffold: a full claim+logout cycle touches
## PersistenceLayer zero times.
extends Node

## ADR-0001 #24 G-LS-1 revision — pinned layer numbers.
const LOGIN_SHELL_LAYER: int = 62    ## PAUSABLE, inside BackBufferCopy capture
const ERROR_BANNER_LAYER: int = 111  ## ALWAYS, >100 immune / <120 below #21 modal

## File-split helpers (AC-01 / AC-35a grep scope — see header).
const BannerStack := preload("res://src/ui/login_shell/banner_stack.gd")
const ShellTransitions := preload("res://src/ui/login_shell/shell_transitions.gd")

## GSM enum source (referenced for state mapping — #21/#23 precedent).
const GSMScript := preload("res://src/autoload/game_state_machine.gd")

## Error severity classification (Rule 5/6 — Source enum for the 4-system consumer).
const ESM := preload("res://src/ui/login_shell/error_severity_map.gd")
## Data-driven severity map instance (designer edits .tres, not code — Rule 6).
const ERROR_SEVERITY_MAP_PATH: String = "res://assets/data/error_severity_map.tres"

## Cross-fade duration (GDD「轉場紀律」SHELL_FADE_SEC default 0.25s; story 004).
## No hard-cut — onset transient = attention event. No abort mid-tween (EC-E1).
const SHELL_FADE_MS: float = 250.0

## Shell internal FSM (story 004 — 5 states; NOT GSM states. The shell OBSERVES
## GSM + #2 signals and derives its own state; it NEVER requests a GSM transition
## [ADR-0006 — GSM owns states, #24 owns 分流]. Banner stack is an orthogonal
## overlay [Rule 7], independent of this FSM.)
enum ShellState {
	HIDDEN,              ## GSM in BOOTING(token)/workout-family/SUSPENDED — no shell surface
	LOGIN,               ## auth_required (highest-priority interrupt) — full-screen form
	SHELL_IDLE,          ## GSM IDLE + token — entry affordances + green status
	DISCONNECTED_SHELL,  ## GSM DISCONNECTED (non-workout) — reconnect + entry still enabled
	DRAINING,            ## logout tap — optimistic「已登出」+ drain banner (story 014 fills content)
}

## ---- DI seams (UNTYPED — reference_gdscript_di_seam: a typed Node hint fails the
## compile-time member check against autoload scripts that expose no class_name). ----
var _gsm = null          ## GameStateMachine (#1) — cfis subscribe at _ready (AC-27)
var _client = null       ## GymSysBackendClient (#2) — auth/claim (stories 005/008)
var _persistence = null  ## PersistenceLayer (#3) — critical_save_failed + get_pending_errors; #24 NEVER writes
var _streak = null       ## StreakSystem (#8) — streak_persistence_failed → FEATURE_DEGRADED banner
var _stat = null         ## StatSystem (#11) — stat_critical_save_failed → FEATURE_DEGRADED banner
var _ability = null      ## AbilitySystem (#12) — ability_unlock_save_failed → FEATURE_DEGRADED banner
var _platform = null     ## PlatformDetect — announce_aria (story 019 a11y)

## ---- owned CanvasLayers (Rule 1: coordinator is the sole instantiator) ----
var _shell_layer: CanvasLayer = null
var _banner_layer: CanvasLayer = null

## ---- 4 coordinator-owned sub-controllers (Rule 1 — NOT autoloads) ----
var _login_panel: Node = null        ## full-screen form host (story 015)
var _connection_status: Node = null  ## disconnected surface (story 012)
var _banner_stack: Node = null       ## BannerStack (banner_stack.gd; severity = story 010)
var _shell_entry: Node = null        ## IDLE entry affordances (story 013)
var _shell_transitions = null        ## ShellTransitions cross-fade helper (story 004 wires)

## ---- shell FSM state (story 004) ----
var _state: int = ShellState.HIDDEN
## Last-seen GSM state (observability; drives _derive_target).
var _gsm_state: int = -1
## Outstanding auth requirement — set on #2 auth_required, cleared on claim success.
## When true + GSM not workout-family ⇒ LOGIN; + GSM workout-family ⇒ deferred (Rule 9a).
var _auth_required: bool = false
## Logout in progress (DRAINING; story 014 fills the optimistic surface + drain banner).
var _draining: bool = false
## A re-derive is queued for the next advance() tick (the「下一 frame」discipline:
## observer handlers never transition synchronously — they flag + settle next tick).
var _settle_pending: bool = false
## Cross-fade in progress (no abort mid-tween — EC-E1). `_state` is the LOGICAL
## state (flips at transition start); `_fading` is the visual catch-up animating
## from the previous surface.
var _fading: bool = false
var _fade_elapsed_ms: float = 0.0
## How many times LOGIN was freshly entered (AC-24 idempotence observability —
## a re-fired auth_required while already LOGIN must NOT re-enter / re-render).
var _login_entry_count: int = 0

## Scaffold-only: last lifecycle event tag (AC-02 cycle observability; zero persist).
var _last_lifecycle_event: StringName = &""

## Test clock override for banner timestamps (>= 0 → use this instead of Time; story 011).
var _clock_override_ms: int = -1


func _ready() -> void:
	_instantiate_layers()
	_instantiate_sub_controllers()
	_resolve_default_seams()
	# Boot-surface: connect_for_initial_state at _ready (AC-27 / ADR-0006 C6).
	# No plain-connect fallback (cfis lint discipline — every real GSM + mock
	# implements cfis; a fallback would be dead code, #23 _subscribe_all precedent).
	if _gsm != null and _gsm.has_method("connect_for_initial_state"):
		_gsm.connect_for_initial_state(_on_gsm_state_changed)
	# #2 GymSysBackendClient auth_required (mock-scoped — the real #2 is a STUB with
	# no signals yet: G-LS-3/4 erratum, VS-tier-gated. The has_signal guard makes
	# this a no-op against the stub and live for an injected mock / future real #2.
	# drain_started/drain_completed = story 014.) #24 never requests a GSM transition.
	if _client != null and _client.has_signal("auth_required"):
		_client.auth_required.connect(_on_auth_required)
	# Rule 5: #24 is the sole UI consumer of the 4 upstream error signals.
	_wire_error_consumers()
	# Idle unless the cfis sentinel already queued a settle (real GSM defers it to
	# next frame; a mock may fire synchronously). _request_settle re-enables _process.
	set_process(_settle_pending or _fading)


## Pre-warmed, hidden until a shell state opens them (FSM = story 004).
func _instantiate_layers() -> void:
	_shell_layer = CanvasLayer.new()
	_shell_layer.name = "LoginShellLayer"
	_shell_layer.layer = LOGIN_SHELL_LAYER
	_shell_layer.process_mode = Node.PROCESS_MODE_PAUSABLE
	# Screen-space layer on the root viewport (#21 viewport-residence precedent):
	# follow_viewport is meaningless here and must stay false.
	_shell_layer.follow_viewport_enabled = false
	_shell_layer.visible = false
	add_child(_shell_layer)

	_banner_layer = CanvasLayer.new()
	_banner_layer.name = "ErrorBannerLayer"
	_banner_layer.layer = ERROR_BANNER_LAYER
	# ALWAYS: error/status surfacing is independent of tree pause AND of shell
	# state — an ONGOING/WIPE banner must render over a paused WORKOUT_ACTIVE world
	# even while LoginShellLayer (PAUSABLE) stays hidden (EC-E3 / AC-54).
	_banner_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	_banner_layer.follow_viewport_enabled = false
	_banner_layer.visible = false
	add_child(_banner_layer)


## Rule 1: the 4 sub-controllers are coordinator-owned child Nodes, NOT autoloads.
## Behaviour is filled in by later stories — here they are shells so the
## single-coordinator topology is established and grep-verifiable.
func _instantiate_sub_controllers() -> void:
	_login_panel = Node.new()
	_login_panel.name = "LoginPanel"
	_shell_layer.add_child(_login_panel)

	_connection_status = Node.new()
	_connection_status.name = "ConnectionStatus"
	_shell_layer.add_child(_connection_status)

	_shell_entry = Node.new()
	_shell_entry.name = "ShellEntry"
	_shell_layer.add_child(_shell_entry)

	# BannerStack (4th sub-controller) — extracted to banner_stack.gd. Hosts the
	# banner stack under the ALWAYS ErrorBannerLayer (zero animation — Rule 8).
	_banner_stack = BannerStack.new()
	_banner_stack.name = "BannerStack"
	_banner_layer.add_child(_banner_stack)

	# ShellTransitions — cross-fade tween helper (the LEGITIMATE state-transition
	# animation, NOT a banner pulse). Story 004 wires the FSM through it.
	_shell_transitions = ShellTransitions.new()


func _resolve_default_seams() -> void:
	if _gsm == null:
		_gsm = get_node_or_null("/root/GameStateMachine")
	if _client == null:
		_client = get_node_or_null("/root/GymSysBackendClient")
	if _persistence == null:
		_persistence = get_node_or_null("/root/PersistenceLayer")
	if _streak == null:
		_streak = get_node_or_null("/root/StreakSystem")
	if _stat == null:
		_stat = get_node_or_null("/root/StatSystem")
	if _ability == null:
		_ability = get_node_or_null("/root/AbilitySystem")
	if _platform == null:
		_platform = get_node_or_null("/root/PlatformDetect")


## Wire the 4 upstream error signals into the BannerStack (Rule 5 — #24 is the SOLE
## UI consumer; zero silent-swallow). Plain `.connect` (not cfis): these are transient
## EVENTS, not state — there is no initial-state to deliver, and the boot-window race
## is closed by story 005's get_pending_errors() pull-check, not by cfis. has_signal
## guards keep this safe if an upstream signature drifts (G-LS-9 erratum territory).
func _wire_error_consumers() -> void:
	# Data-driven severity map: prefer the .tres; fall back to script defaults.
	if ResourceLoader.exists(ERROR_SEVERITY_MAP_PATH):
		var map = load(ERROR_SEVERITY_MAP_PATH)
		if map != null:
			_banner_stack.set_severity_map(map)
	if _persistence != null and _persistence.has_signal("critical_save_failed"):
		_persistence.critical_save_failed.connect(_on_persistence_error)
	if _streak != null and _streak.has_signal("streak_persistence_failed"):
		_streak.streak_persistence_failed.connect(_on_streak_error)
	if _stat != null and _stat.has_signal("stat_critical_save_failed"):
		_stat.stat_critical_save_failed.connect(_on_stat_error)
	if _ability != null and _ability.has_signal("ability_unlock_save_failed"):
		_ability.ability_unlock_save_failed.connect(_on_ability_error)


## ---- 4-system error handlers (Rule 5 → BannerStack.dispatch_error) ----

func _on_persistence_error(error_code: String, key: String) -> void:
	_banner_stack.dispatch_error(ESM.Source.PERSISTENCE, StringName(error_code), key, _now_ms())
	_refresh_banner_layer_visibility()


func _on_streak_error(error_code: String, key: String) -> void:
	_banner_stack.dispatch_error(ESM.Source.STREAK, StringName(error_code), key, _now_ms())
	_refresh_banner_layer_visibility()


func _on_stat_error(stat_id: StringName) -> void:
	# #11/#12 are source-classified FEATURE_DEGRADED — error_code is irrelevant; the
	# stat_id is the dedupe key.
	_banner_stack.dispatch_error(ESM.Source.STAT, &"", stat_id, _now_ms())
	_refresh_banner_layer_visibility()


func _on_ability_error(ability_id: StringName) -> void:
	_banner_stack.dispatch_error(ESM.Source.ABILITY, &"", ability_id, _now_ms())
	_refresh_banner_layer_visibility()


## Banner arrival clock. The coordinator is NOT a formula path (the AC-51 clock-seam
## grep targets shell_formulas.gd), so it is the legitimate injected-clock SOURCE here;
## tests override via `_clock_override_ms` (>= 0) for deterministic timestamps.
func _now_ms() -> int:
	if _clock_override_ms >= 0:
		return _clock_override_ms
	return Time.get_ticks_msec()


## ErrorBannerLayer (111 ALWAYS) visibility is driven SOLELY by whether a banner
## exists — INDEPENDENT of the shell FSM / LoginShellLayer (two-layer separation,
## Rule 1 / AC-54 / EC-E3): an ONGOING/WIPE banner surfaces over a paused
## WORKOUT_ACTIVE world even while the login surface stays hidden.
func _refresh_banner_layer_visibility() -> void:
	_banner_layer.visible = _banner_stack.count() > 0


## ---- shell FSM (story 004) ----
## Discipline (= #22/#23): ONE injected clock. Production _process feeds
## advance(delta*1000); tests call advance(delta_ms) directly. No engine Tween /
## SceneTreeTimer for any state-bearing timing. Observer handlers NEVER transition
## synchronously — they flag + settle on the next advance tick (the「下一 frame」rule).

func _process(delta: float) -> void:
	advance(delta * 1000.0)


## Single timing entry point — settle queued re-derives, then tick the cross-fade.
func advance(delta_ms: float) -> void:
	if _settle_pending:
		_settle_pending = false
		_begin_transition_if_needed()
	if _fading:
		_fade_elapsed_ms += delta_ms
		if _fade_elapsed_ms >= SHELL_FADE_MS:
			_complete_fade()
	if not _settle_pending and not _fading:
		set_process(false)  # idle — zero processing when settled (#23 precedent)


## GSM observer (cfis-subscribed). Untyped params (project DI discipline). Records
## the live GSM state and queues a settle — never transitions inline.
func _on_gsm_state_changed(_from_state, to_state, _payload) -> void:
	_gsm_state = int(to_state)
	_request_settle()


## #2 auth_required observer (mock-scoped). reason is forwarded by #2 (G-LS-4
## get_auth_block_reason分流 = story 009); story 004 only latches the requirement.
func _on_auth_required(_reason = null) -> void:
	_auth_required = true
	_request_settle()


## Queue a next-tick re-derive (the「下一 frame」discipline — AC-03/AC-38).
func _request_settle() -> void:
	_settle_pending = true
	set_process(true)


## Derive the correct shell state from the live GSM state + flags.
## LOGIN is the highest-priority interrupt — EXCEPT mid-workout, where Rule 9(a)
## defers it (banner-only; the full-screen form must not seize a workout moment —
## Pillar 2 binding). DRAINING ranks above the plain GSM mapping.
func _derive_target() -> int:
	if _auth_required and not _is_workout_family(_gsm_state):
		return ShellState.LOGIN
	if _draining:
		return ShellState.DRAINING
	return _shell_state_for_gsm(_gsm_state)


## GSM → shell state map (non-LOGIN/DRAINING band). Only IDLE/DISCONNECTED surface
## a shell; everything else (BOOTING/workout-family/SUSPENDED) is HIDDEN.
func _shell_state_for_gsm(gsm: int) -> int:
	match gsm:
		GSMScript.GameState.IDLE:
			return ShellState.SHELL_IDLE
		GSMScript.GameState.DISCONNECTED:
			return ShellState.DISCONNECTED_SHELL
		_:
			return ShellState.HIDDEN


## Workout-family = the in-session states where a full-screen login form would
## seize a sacred moment (Rule 9a defer). SUSPENDED/BOOTING are NOT workout-family.
func _is_workout_family(gsm: int) -> bool:
	return gsm == GSMScript.GameState.WORKOUT_ACTIVE \
		or gsm == GSMScript.GameState.REST_PERIOD \
		or gsm == GSMScript.GameState.COMBAT_ACTIVE \
		or gsm == GSMScript.GameState.BOSS_ENCOUNTER \
		or gsm == GSMScript.GameState.LOOT_DROP


## Transition toward the derived target if it differs from the current state.
## The LOGICAL `_state` flips immediately (so「下一 frame 入 LOGIN」holds — AC-03),
## and a cross-fade animates the visual catch-up. While a fade is in flight we do
## NOT start another (EC-E1: no abort mid-tween — the in-flight fade re-derives the
## live target on completion).
func _begin_transition_if_needed() -> void:
	if _fading:
		return  # EC-E1 — the current fade owns the screen until it completes
	var target: int = _derive_target()
	if target == _state:
		return  # already there — no re-enter / no re-render (AC-24 idempotence)
	_state = target
	# Incoming surface becomes visible immediately so「下一 frame ... visible == true」
	# holds (AC-03); a HIDDEN target keeps the surface visible during the fade-out
	# and is hidden at completion. The alpha ramp itself is cosmetic.
	if target != ShellState.HIDDEN:
		_shell_layer.visible = true
	if target == ShellState.LOGIN:
		_login_entry_count += 1
	_fade_elapsed_ms = 0.0
	_fading = true


## Cross-fade complete: finalize layer visibility (a HIDDEN target hides now), then
## re-derive against the LIVE GSM state — GSM may have moved during the fade, which
## we deliberately did not chase mid-tween (EC-E1).
func _complete_fade() -> void:
	_fading = false
	_fade_elapsed_ms = 0.0
	_shell_layer.visible = (_state != ShellState.HIDDEN)
	var live: int = _derive_target()
	if live != _state:
		_request_settle()  # GSM changed mid-fade — chase the live target (EC-E1)


## ---- lifecycle entry points (scaffold — zero-persist invariant, AC-02) ----
## Real claim-landing FSM = story 008; logout drain = story 014. These scaffold
## entry points exist so the zero-persist invariant is pinned from day one:
## neither touches PersistenceLayer (the only token write is #2's, story 008).

## Claim succeeded → clears the auth requirement so the shell leaves LOGIN and
## cross-fades to the landing state derived from the live GSM state (States table
## LOGIN exit). Performs ZERO persist writes — the only token write is #2's (AC-02).
func notify_claim_succeeded() -> void:
	_last_lifecycle_event = &"claim_succeeded"
	_auth_required = false
	_draining = false
	_request_settle()


## Logout requested → DRAINING (optimistic「已登出」; story 014 fills the surface +
## drain banner). DRAINING exits to LOGIN when the token is cleared and #2 fires
## auth_required. Performs ZERO persist writes (#2 owns the token drain — AC-02).
func request_logout() -> void:
	_last_lifecycle_event = &"logout"
	_draining = true
	_request_settle()


## ---- getters (test surface + later-story wiring points) ----

func get_shell_layer() -> CanvasLayer:
	return _shell_layer


func get_banner_layer() -> CanvasLayer:
	return _banner_layer


func get_banner_stack() -> Node:
	return _banner_stack


func get_shell_transitions():
	return _shell_transitions


func get_gsm_state() -> int:
	return _gsm_state


func get_last_lifecycle_event() -> StringName:
	return _last_lifecycle_event


## ---- FSM getters (story 004) ----

## Current settled shell state (ShellState enum).
func get_state() -> int:
	return _state


## Rule 9(a) mid-workout defer flag (AC-38) — auth is required but the live GSM
## state is workout-family, so LOGIN entry is deferred (banner-only). Clears
## automatically once GSM leaves the workout family (LOGIN is then derivable).
func get_pending_auth_required() -> bool:
	return _auth_required and _is_workout_family(_gsm_state)


## Whether a cross-fade is currently in flight (EC-E1 — no abort mid-tween).
func is_fading() -> bool:
	return _fading


## Cross-fade progress 0.0→1.0 (cosmetic; sub-controllers read this to modulate
## their incoming/outgoing alpha — CanvasLayer itself has no modulate).
func get_fade_alpha() -> float:
	if not _fading:
		return 1.0
	return ShellTransitions.cross_fade_alpha(_fade_elapsed_ms)


## How many times LOGIN was freshly entered (AC-24 idempotence assertion seam).
func get_login_entry_count() -> int:
	return _login_entry_count
