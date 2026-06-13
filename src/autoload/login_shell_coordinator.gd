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
## Formula 1 rate-limit countdown (claim rate_limited path — story 006/008).
const ShellFormulas := preload("res://src/ui/login_shell/shell_formulas.gd")
## AC-UX layout / geometry contract (banner rect, yield glyph, touch floors — story 019).
const ACUXLayout := preload("res://src/ui/login_shell/acux_layout.gd")
const LoginForm := preload("res://src/ui/login_shell/login_form.gd")  ## story 015 LZ-Form

## GymSys base URL for the Option-B login() path (desktop/dev). 127.0.0.1 NOT localhost
## (GYM binds IPv4; Godot resolves localhost→::1 and hangs). Web export uses same-origin
## (relative) per ADR-0004 — override at deploy. (See docs/gymsys-integration-plan.md.)
const GYM_BASE := "http://127.0.0.1:8090"
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

## LOGIN sub-variant (story 009 — pulled from #2 get_auth_block_reason() on LOGIN entry).
## NORMAL shows the credential form; the other two replace it with a prompt (no form).
enum LoginVariant {
	NORMAL,           ## &"none" — username/password/toggle/submit form
	UPDATE_REQUIRED,  ## &"update_required" — 「呢個版本舊咗」prompt, NO form (AC-04)
	MISCONFIG,        ## &"carve_out_misconfig" — operator prompt + acknowledge guidance (AC-05)
}

## Logout-drain lifecycle (story 014 — Rule 12, optimistic + non-blocking background drain).
enum DrainState {
	NONE,      ## not draining
	DRAINING,  ## 已登出 — background drain in progress (drain_started not yet completed)
	SUCCESS,   ## 全部儲好喇 ✓ — auto-expires after DRAIN_SUCCESS_EXPIRE_SEC (F2)
	PARTFAIL,  ## part-fail — persistent WIPE-weight acknowledge-dismiss banner (never silent)
}

## ---- DI seams (UNTYPED — reference_gdscript_di_seam: a typed Node hint fails the
## compile-time member check against autoload scripts that expose no class_name). ----
var _gsm = null          ## GameStateMachine (#1) — cfis subscribe at _ready (AC-27)
var _client = null       ## GymSysBackendClient (#2) — auth/claim (stories 005/008)
var _login_in_progress: bool = false   ## Option-B login() in flight — anti-double-submit (story 015)
var _persistence = null  ## PersistenceLayer (#3) — critical_save_failed + get_pending_errors; #24 NEVER writes
var _streak = null       ## StreakSystem (#8) — streak_persistence_failed → FEATURE_DEGRADED banner
var _stat = null         ## StatSystem (#11) — stat_critical_save_failed → FEATURE_DEGRADED banner
var _ability = null      ## AbilitySystem (#12) — ability_unlock_save_failed → FEATURE_DEGRADED banner
var _platform = null     ## PlatformDetect — announce_aria (story 019 a11y)
var _character_screen = null  ## CharacterScreenCoordinator (#22) — request_open arbiter target
var _inventory_ui = null      ## InventoryUICoordinator (#23) — request_open arbiter target

## request_open last-wins pending target (story 013 — rapid-tap / concurrent race guard;
## a later request_open inside the same deferred window overwrites it, never double-opens).
var _pending_open_target: StringName = &""

## SR-announcement observable log (story 019 a11y) — [{text, politeness}] where
## politeness ∈ {"assertive","polite"}. Coordinator-local mirror of what was pushed
## through the PlatformDetect seam, so the error-vs-banner routing contract is testable
## even with no platform seam injected (real boot writes DOM; headless logs only).
var _aria_log: Array[Dictionary] = []

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
## DISCONNECTED entered FROM a workout-family state (story 012 — mid-workout network drop):
## stay HIDDEN + peripheral banner instead of the full DISCONNECTED_SHELL (Rule 9a — do not
## interrupt the workout with a full-screen surface; it may resume).
var _workout_disconnect: bool = false
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
## LOGIN sub-variant (story 009 — refreshed from #2 on each fresh LOGIN entry).
var _login_variant: int = LoginVariant.NORMAL

## Scaffold-only: last lifecycle event tag (AC-02 cycle observability; zero persist).
var _last_lifecycle_event: StringName = &""

## Test clock override for banner timestamps (>= 0 → use this instead of Time; story 011).
var _clock_override_ms: int = -1

## ---- claim flow (story 008) ----
## G-LS-3 GATED: #2 claim_session async signature + cancellation are unpinned and #2 is
## a stub, so the claim is mock-scoped — submit_claim() initiates; notify_claim_result()
## is the completion callback the #2 client (or a test) invokes. The await/signal
## mechanism is pinned later in the #2 erratum.
const CLAIM_TIMEOUT_MS: float = 10000.0  ## injected-clock cancel fallback (no native await-timeout)

var _claim_loading: bool = false       ## submit disabled + loading shown
var _claim_pending: bool = false       ## a claim is in flight (timeout/cancel window)
var _claim_succeeded: bool = false     ## claim OK — yield landing until GSM leaves BOOTING
var _claim_elapsed_ms: float = 0.0     ## injected-clock cancel timer
var _claim_session_calls: int = 0      ## anti-double-submit observability (AC-06)
var _claim_error_copy: String = ""     ## inline error message ("" = none); zero raw HTTP
var _claim_show_retry: bool = false    ## network_error / server_error show a retry button
## rate_limited countdown state (dispatched to Formula 1 — story 006).
var _rate_limit_retry_after: int = 0
var _rate_limit_t_start_ms: int = 0

## ---- logout drain (story 014) ----
var _drain_state: int = DrainState.NONE
var _drain_count: int = 0               ## drain_started(N) — items draining in background
var _drain_failed: int = 0              ## drain_completed(_, failed) — part-fail count
var _drain_success_start_ms: int = 0    ## F2 success-expire anchor


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
	# #2 Option-B client (2026-06-13) emits logged_in(ok) from login(); reflect success into
	# the shell via the verified notify_claim_succeeded() path. has_signal-guarded so the
	# full-ADR-0002 (claim/token) client without this signal stays unaffected.
	if _client != null and _client.has_signal("logged_in"):
		_client.logged_in.connect(_on_gym_logged_in)
	# Rule 5: #24 is the sole UI consumer of the 4 upstream error signals.
	_wire_error_consumers()
	# Boot-window race close (story 005 / Rule 2): a tail autoload misses any signal a
	# producer sync-emitted from its own _ready() before #24 connected. Pull the two
	# critical ones (auth + pending errors) instead of trusting the signal.
	_boot_pull_check_sweep()
	# Idle unless the cfis sentinel already queued a settle (real GSM defers it to
	# next frame; a mock may fire synchronously). _request_settle re-enables _process.
	set_process(_settle_pending or _fading)


## Boot-Window Signal Sweep (story 005 — GDD Rule 2 boot-race table). The signal-only
## model leaves a tail autoload (ADR-0008 — #24 boots last) racing every producer's
## _ready() sync-emit. The two HIGH/MED-severity signals are PULLED, not awaited:
##   - #2 is_auth_required() (G-LS-4(c) — fatal: a missed auth_required = black screen)
##   - #3 get_pending_errors() (G-LS-8 — buffered backlog the connect missed)
## #8/#11/#12 are NOT pulled: they are LOW-severity and rely on the EC-E6 contract that
## they never sync-emit at boot. GSM is covered by cfis. Both pulled APIs are #2/#3
## ADDITIVE getters (not yet implemented — G-LS-3/4/8 erratum), so has_method-guarded
## and mock-scoped here; real wiring lands with the #2/#3 erratum.
func _boot_pull_check_sweep() -> void:
	var found_auth: bool = false
	if _client != null and _client.has_method("is_auth_required") and _client.is_auth_required():
		_auth_required = true
		found_auth = true
	if _persistence != null and _persistence.has_method("get_pending_errors"):
		for code in _persistence.get_pending_errors():
			_banner_stack.dispatch_error(ESM.Source.PERSISTENCE, StringName(code), &"", _now_ms())
		_refresh_banner_layer_visibility()
	# Force a synchronous LOGIN entry ONLY when auth was pull-detected (AC-53 — the shell
	# must already be LOGIN by end of _ready, never waiting on a signal/advance). Other
	# boot states settle normally via the cfis sentinel + advance (story 004 unchanged).
	if found_auth:
		_settle_pending = false
		_begin_transition_if_needed()


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
	_login_panel = LoginForm.new()      ## story 015 LZ-Form (username/password/toggle/submit)
	_login_panel.name = "LoginPanel"
	_shell_layer.add_child(_login_panel)
	if _login_panel.has_signal("submitted"):
		_login_panel.submitted.connect(submit_login)

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
	if _character_screen == null:
		_character_screen = get_node_or_null("/root/CharacterScreenCoordinator")
	if _inventory_ui == null:
		_inventory_ui = get_node_or_null("/root/InventoryUICoordinator")


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
	# #2 logout-drain signals (story 014 — mock-scoped; #2 stub has none yet).
	if _client != null and _client.has_signal("drain_started"):
		_client.drain_started.connect(_on_drain_started)
	if _client != null and _client.has_signal("drain_completed"):
		_client.drain_completed.connect(_on_drain_completed)


## ---- 4-system error handlers (Rule 5 → BannerStack.dispatch_error) ----

func _on_persistence_error(error_code: String, key: String) -> void:
	_banner_stack.dispatch_error(ESM.Source.PERSISTENCE, StringName(error_code), key, _now_ms())
	_refresh_banner_layer_visibility()
	announce_banner_status("存檔錯誤：%s" % error_code)  # peripheral → polite (AC a11y)


func _on_streak_error(error_code: String, key: String) -> void:
	_banner_stack.dispatch_error(ESM.Source.STREAK, StringName(error_code), key, _now_ms())
	_refresh_banner_layer_visibility()
	announce_banner_status("連續紀錄暫時無法儲存")  # FEATURE_DEGRADED → polite


func _on_stat_error(stat_id: StringName) -> void:
	# #11/#12 are source-classified FEATURE_DEGRADED — error_code is irrelevant; the
	# stat_id is the dedupe key.
	_banner_stack.dispatch_error(ESM.Source.STAT, &"", stat_id, _now_ms())
	_refresh_banner_layer_visibility()
	announce_banner_status("屬性數值暫時無法儲存")  # FEATURE_DEGRADED → polite


func _on_ability_error(ability_id: StringName) -> void:
	_banner_stack.dispatch_error(ESM.Source.ABILITY, &"", ability_id, _now_ms())
	_refresh_banner_layer_visibility()
	announce_banner_status("技能解鎖暫時無法儲存")  # FEATURE_DEGRADED → polite


## ---- a11y SR announcements (story 019 / AC-UX a11y) ----
## Canvas is opaque to the DOM accessibility tree, so ALL SR announcements route
## through the PlatformDetect.announce_aria JS-bridge seam (#21/#22/#23 precedent).
## TWO politeness lanes (UX L492): a LOGIN inline error preempts (assertive — the
## player just submitted and awaits a verdict); a peripheral banner is polite (does
## NOT interrupt the SR). Both also land in _aria_log so the routing is headless-testable.

## Assertive: LOGIN form inline error (claim verdict / rate-limit). Preempts.
func announce_inline_error(text: String) -> void:
	_announce(text, true)


## Polite: peripheral banner status (save-failed / disconnect / drain). Non-interrupting.
func announce_banner_status(text: String) -> void:
	_announce(text, false)


func _announce(text: String, assertive: bool) -> void:
	_aria_log.append({"text": text, "politeness": "assertive" if assertive else "polite"})
	if _platform != null and _platform.has_method("announce_aria"):
		_platform.announce_aria(text, assertive)


## Banners are display-only (ErrorBannerLayer is a non-interactive CanvasLayer surface):
## a banner appearing NEVER grabs keyboard focus from the LOGIN form (UX L493 / AC a11y).
func banner_grabs_focus() -> bool:
	return false


## SR-announcement observable log — [{text, politeness}] (story 019 test surface).
func get_aria_log() -> Array[Dictionary]:
	return _aria_log


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
	if _claim_pending:
		# Injected-clock cancel fallback (AC-22 / EC-A1): GDScript has no native
		# await-timeout, so a hung claim is bounded here.
		_claim_elapsed_ms += delta_ms
		if _claim_elapsed_ms >= CLAIM_TIMEOUT_MS:
			_cancel_claim()
	if _fading:
		_fade_elapsed_ms += delta_ms
		if _fade_elapsed_ms >= SHELL_FADE_MS:
			_complete_fade()
	if _drain_state == DrainState.SUCCESS:
		# Formula 2 auto-expire of the「全部儲好喇 ✓」notice (DRAIN_SUCCESS_EXPIRE_SEC).
		if not ShellFormulas.banner_visible(_now_ms(), _drain_success_start_ms, ShellFormulas.DRAIN_SUCCESS_EXPIRE_SEC):
			_drain_state = DrainState.NONE
			_banner_stack.clear_drain_status()
			_refresh_banner_layer_visibility()
	if not _settle_pending and not _fading and not _claim_pending and _drain_state != DrainState.SUCCESS:
		set_process(false)  # idle — zero processing when settled (#23 precedent)


## GSM observer (cfis-subscribed). Untyped params (project DI discipline). Records
## the live GSM state and queues a settle — never transitions inline.
func _on_gsm_state_changed(from_state, to_state, _payload) -> void:
	var from: int = int(from_state)
	_gsm_state = int(to_state)
	# A SUSPENDED interrupt cancels an in-flight claim (EC-A1 — backgrounded mid-claim;
	# the await would hang, so cancel deterministically rather than show a false failure).
	if _gsm_state == GSMScript.GameState.SUSPENDED and _claim_pending:
		_cancel_claim()
	_update_disconnect_surface(from)  # story 012 — DISCONNECTED status banner + workout flag
	_try_complete_landing()  # yield landing — exit LOGIN once GSM has left BOOTING
	_request_settle()


## Manage the DISCONNECTED status banner + the workout-disconnect flag (story 012).
## Entering DISCONNECTED from a workout-family state = a mid-workout drop → stay HIDDEN
## with a peripheral banner (Rule 9a); from non-workout → DISCONNECTED_SHELL. The banner
## is set/cleared immediately — never debounced (EC-C1: a DISCONNECTED↔IDLE flicker just
## toggles the banner; both shell states keep entry affordances enabled).
func _update_disconnect_surface(from_state: int) -> void:
	if _gsm_state == GSMScript.GameState.DISCONNECTED:
		_workout_disconnect = _is_workout_family(from_state)
		_banner_stack.set_disconnected_status(true, _now_ms())
	else:
		_workout_disconnect = false
		_banner_stack.set_disconnected_status(false)
	_refresh_banner_layer_visibility()


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
			# A mid-workout drop stays HIDDEN (banner-only, Rule 9a); a non-workout
			# disconnect surfaces the full DISCONNECTED_SHELL (story 012 / AC-37).
			return ShellState.HIDDEN if _workout_disconnect else ShellState.DISCONNECTED_SHELL
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
		_refresh_login_variant()  # story 009 — pull the block reason on each fresh entry
		# Sequencing (story 014 / AC-41/42): a drain-SUCCESS notice (「可以安心熄 app」)
		# must not coexist with the login form (「請再登入」) — clear it on LOGIN entry. A
		# part-fail WIPE banner is HONEST and persists through re-login (cleared on ack).
		if _drain_state == DrainState.SUCCESS or _drain_state == DrainState.DRAINING:
			_drain_state = DrainState.NONE
			_banner_stack.clear_drain_status()
			_refresh_banner_layer_visibility()
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


## Logout requested → DRAINING (optimistic「已登出」, AC-41). Calls #2
## clear_session_token(USER_EXPLICIT) immediately + raises the「已登出」drain banner, with
## ZERO blocking modal (Fantasy Test 3) and ZERO persist writes (#2 owns the token drain).
## DRAINING exits to LOGIN when the token clears and #2 fires auth_required (sequencing
## below). clear_session_token is a #2 method (stub) → has_method-guarded, mock-scoped.
func request_logout() -> void:
	_last_lifecycle_event = &"logout"
	_draining = true
	_drain_state = DrainState.DRAINING
	if _client != null and _client.has_method("clear_session_token"):
		_client.clear_session_token(&"USER_EXPLICIT")
	_banner_stack.set_drain_status(ESM.Severity.NOTIFICATION, _now_ms())
	_refresh_banner_layer_visibility()
	_request_settle()


## #2 drain_started(N) — items being drained in the background (AC: 「背景儲緊 N 樣」).
func _on_drain_started(item_count: int) -> void:
	_drain_count = item_count
	if _drain_state == DrainState.DRAINING:
		_banner_stack.set_drain_status(ESM.Severity.NOTIFICATION, _now_ms())
		_refresh_banner_layer_visibility()


## #2 drain_completed(saved, failed) — AC-42 / EC-B8. failed > 0 → the drain notice is
## REPLACED by a persistent WIPE-weight acknowledge-dismiss banner (never silent — #2's
## tombstone「會試返」is true). failed == 0 (incl. drain_completed(0,0)) → 「全部儲好喇 ✓」
## that auto-expires after DRAIN_SUCCESS_EXPIRE_SEC (Formula 2).
func _on_drain_completed(saved: int, failed: int) -> void:
	_drain_failed = failed
	if failed > 0:
		_drain_state = DrainState.PARTFAIL
		_banner_stack.set_drain_status(ESM.Severity.WIPE, _now_ms())
	else:
		_drain_state = DrainState.SUCCESS
		_drain_success_start_ms = _now_ms()
		_banner_stack.set_drain_status(ESM.Severity.NOTIFICATION, _now_ms())
		set_process(true)  # arm the F2 success-expire tick
	_refresh_banner_layer_visibility()


## ---- claim flow (story 008 — G-LS-3 mock-scoped) ----

## Submit the login form. Disables submit + shows loading immediately and counts the
## call (AC-06 anti-double-submit: a second tap while loading is a no-op). Initiates the
## claim through #2 if present; the completion arrives via notify_claim_result().
func submit_claim(username: String, password: String) -> void:
	if _claim_loading:
		return  # anti-double-submit (AC-06 / EC-A4)
	_claim_loading = true
	_claim_error_copy = ""
	_claim_show_retry = false
	_claim_succeeded = false
	_claim_session_calls += 1
	_claim_pending = true
	_claim_elapsed_ms = 0.0
	set_process(true)  # arm the injected-clock cancel timer
	if _client != null and _client.has_method("claim_session"):
		_client.claim_session(username, password)  # mock-scoped; result via notify_claim_result


## Option-B (cookie) login path for the credential form (story 015). Calls the #2 client's
## login(); success arrives via logged_in → _on_gym_logged_in → notify_claim_succeeded().
## Distinct from submit_claim() (the full-ADR-0002 session-claim path) — a real form wires to
## whichever the live #2 client supports. has_method-guarded (no-op for a claim-only client).
func submit_login(username: String, password: String) -> void:
	if _login_in_progress:
		return  # anti-double-submit (story 015 / AC-06 spirit)
	if _client != null and _client.has_method("login"):
		_login_in_progress = true
		if _login_panel != null and _login_panel.has_method("set_submitting"):
			_login_panel.set_submitting(true)
		_client.login(GYM_BASE, username, password)


## #2 Option-B logged_in(ok) → reflect into the shell. Success reuses the verified
## notify_claim_succeeded() path; failure logs (full error-copy mapping for the cookie path
## is story-015 form work — kept FSM-safe here).
func _on_gym_logged_in(ok: bool) -> void:
	_login_in_progress = false
	if _login_panel != null and _login_panel.has_method("set_submitting"):
		_login_panel.set_submitting(false)
	if ok:
		notify_claim_succeeded()
	else:
		push_warning("[LoginShell] GymSys login failed")
	# Credential residue (AC-50): wipe the password field on any resolve. On failure the
	# username is preserved for re-entry (EC-A3); on success the form leaves the shell.
	if _login_panel != null and _login_panel.has_method("clear_password"):
		_login_panel.clear_password()


## Claim completion callback (#2 client or test invokes). Maps the result to a 4-code
## error surface — NEVER leaks a raw HTTP code (Rule 3 / #2 L310 contract). Ghost-safe:
## a result arriving after a cancel/timeout is ignored.
func notify_claim_result(code: StringName, retry_after: int = 0) -> void:
	if not _claim_pending:
		return  # ghost result after cancel/timeout (AC-22 race) — ignore
	_claim_pending = false
	_claim_loading = false
	match code:
		&"success":
			# Yield landing (AC-07/08): do NOT assume IDLE. Stay LOGIN until GSM actually
			# leaves BOOTING, then derive the landing state from the live GSM.
			_claim_succeeded = true
			_try_complete_landing()
		&"invalid_credentials":
			_claim_error_copy = "username 或者 password 唔啱"  # field-level, no side disclosed
		&"network_error":
			_claim_error_copy = "而家連唔到，請再試一次"
			_claim_show_retry = true
		&"server_error":
			# session conflict also buckets here (AC-23) — no conflict-specific copy.
			_claim_error_copy = "伺服器嗰邊出咗少少問題，請再試一次"
			_claim_show_retry = true
		&"rate_limited":
			_rate_limit_retry_after = retry_after
			_rate_limit_t_start_ms = _now_ms()  # Formula 1 countdown (story 006)
		_:
			# Defensive default-deny — an unknown result code is still surfaced, never
			# silently swallowed, and never leaks the raw value.
			_claim_error_copy = "登入遇到未知問題，請再試一次"
			_claim_show_retry = true
	# Inline error (LOGIN form response) → ASSERTIVE SR announcement (AC a11y / UX L204):
	# the player just submitted and is awaiting a verdict, so it preempts (vs the polite
	# peripheral banners). success/landing announces nothing here (state change speaks).
	if _claim_error_copy != "":
		announce_inline_error(_claim_error_copy)
	elif code == &"rate_limited":
		announce_inline_error("已達嘗試上限，請稍候再試")


## Cancel an in-flight claim (SUSPENDED interrupt or injected-clock timeout — EC-A1).
## Re-enables submit with an INTERRUPTED message — explicitly NOT a「登入失敗」(the claim
## never failed; it was interrupted), so the player is not falsely told they were rejected.
func _cancel_claim() -> void:
	_claim_pending = false
	_claim_loading = false
	_claim_succeeded = false
	_claim_error_copy = "登入程序中途中斷，請再試一次"


## Complete the yield-landing once the claim succeeded AND GSM has left BOOTING (States
## table LOGIN exit). Clears auth so the FSM derives the real landing state.
func _try_complete_landing() -> void:
	if not _claim_succeeded:
		return
	if _gsm_state == GSMScript.GameState.BOOTING or _gsm_state == -1:
		return  # still booting — keep showing the login/loading surface
	_auth_required = false
	_claim_succeeded = false
	_request_settle()


## Rate-limit countdown seconds remaining (0 = submit re-enabled). Formula 1 (story 006).
func get_rate_limit_seconds() -> int:
	if _rate_limit_retry_after <= 0:
		return 0
	return ShellFormulas.display_seconds(_rate_limit_retry_after, _rate_limit_t_start_ms, _now_ms())


## ---- LOGIN sub-variant dispatch (story 009 — G-LS-4 mock-scoped) ----

## Pull the auth-block reason on LOGIN entry (forbidden-signal ban → a pull-model getter
## is the only legal channel for these P0-6/P0-7 prompts). get_auth_block_reason() is a
## #2 additive getter (not yet shipped — G-LS-4); has_method-guarded, defaults to NORMAL.
func _refresh_login_variant() -> void:
	var reason: StringName = &"none"
	if _client != null and _client.has_method("get_auth_block_reason"):
		reason = _client.get_auth_block_reason()
	match reason:
		&"update_required":
			_login_variant = LoginVariant.UPDATE_REQUIRED
		&"carve_out_misconfig":
			_login_variant = LoginVariant.MISCONFIG
		_:
			_login_variant = LoginVariant.NORMAL


func get_login_variant() -> int:
	return _login_variant


## Only the NORMAL variant shows the credential form — UPDATE_REQUIRED / MISCONFIG
## replace it with a prompt (AC-04/05: no form input behind an unactionable block).
func should_show_form() -> bool:
	return _login_variant == LoginVariant.NORMAL


## Operator action for the MISCONFIG carve-out prompt (AC-05). Calls the real #2 hook
## (#2 L149 acknowledge_carve_out_fix() — already exists) when present.
func acknowledge_carve_out() -> void:
	if _client != null and _client.has_method("acknowledge_carve_out_fix"):
		_client.acknowledge_carve_out_fix()


## ---- DISCONNECTED reconnect (story 012 — G-LS-4 mock-scoped) ----

## The「再試一次」/ reconnect affordance. Requests an immediate #2 poll — a sense-of-agency
## affordance ONLY; #24 never writes its own backoff (the cadence is #2's job — ADR-0002).
## request_immediate_poll() is a #2 additive getter (not yet shipped — G-LS-4); guarded.
func request_reconnect() -> void:
	if _client != null and _client.has_method("request_immediate_poll"):
		_client.request_immediate_poll()


## True while a mid-workout drop is showing the peripheral banner (shell stays HIDDEN).
func is_workout_disconnect() -> bool:
	return _workout_disconnect


## ---- entry affordance + mutual-exclusion arbiter (story 013 — Rule 10/11) ----

## Central mutual-exclusion arbiter (Rule 11). Closes whatever screen is open, then
## defer-opens the target (last-wins latch — a rapid second request_open overwrites the
## pending target rather than queueing a double-open). #24 NEVER subscribes #22/#23 state
## — it actively calls them behind has_method guards (the #22 G-IU-4 glue discipline).
func request_open(screen_id: StringName) -> void:
	_pending_open_target = screen_id
	_close_open_screens()
	call_deferred("_apply_pending_open")


func _close_open_screens() -> void:
	if _character_screen != null and _character_screen.has_method("close"):
		_character_screen.close()
	if _inventory_ui != null and _inventory_ui.has_method("close"):
		_inventory_ui.close()


## Deferred open of the latched target (AC-40). Double guard: NEVER bypass the screen's
## own can_open() (defense in depth) — a false result is logged and the open is skipped,
## never forced (EC-E4). last-wins: only the final pending target is honoured.
func _apply_pending_open() -> void:
	var target: StringName = _pending_open_target
	_pending_open_target = &""
	var screen = _resolve_open_target(target)
	if screen == null:
		return
	if screen.has_method("can_open") and not screen.can_open():
		push_warning("LoginShellCoordinator.request_open(%s) — can_open() false, not forced (EC-E4)" % target)
		return
	if screen.has_method("open"):
		screen.open()


func _resolve_open_target(screen_id: StringName):
	match screen_id:
		&"character_screen":
			return _character_screen
		&"inventory":
			return _inventory_ui
		_:
			return null


## Entry affordances are rendered only in the steady shell states (SHELL_IDLE /
## DISCONNECTED_SHELL); workout-family / LOGIN / DRAINING states hide them entirely
## (Rule 10 — enabled/hidden two-state, NEVER a greyed disabled full-feature surface).
func is_entry_visible() -> bool:
	return _state == ShellState.SHELL_IDLE or _state == ShellState.DISCONNECTED_SHELL


## Entry-card alpha (Rule 10 three-state, applied only while is_entry_visible()):
## 1.0 = enabled (screen can_open()); 0.55 = interactive-dimmed (rare can_open()==false
## race — still tappable → inline reason, NOT greyed-disabled). alpha != desaturate.
func get_entry_card_alpha(screen_id: StringName) -> float:
	var screen = _resolve_open_target(screen_id)
	if screen != null and screen.has_method("can_open") and not screen.can_open():
		return 0.55
	return 1.0


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


## ---- claim getters (story 008) ----

func is_claim_loading() -> bool:
	return _claim_loading


func get_claim_session_calls() -> int:
	return _claim_session_calls


func get_claim_error_copy() -> String:
	return _claim_error_copy


func get_claim_show_retry() -> bool:
	return _claim_show_retry


## ---- drain getters (story 014) ----

func get_drain_state() -> int:
	return _drain_state


func get_drain_count() -> int:
	return _drain_count


func get_drain_failed() -> int:
	return _drain_failed
