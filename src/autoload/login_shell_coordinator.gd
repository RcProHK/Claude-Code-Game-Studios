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

## ---- DI seams (UNTYPED — reference_gdscript_di_seam: a typed Node hint fails the
## compile-time member check against autoload scripts that expose no class_name). ----
var _gsm = null          ## GameStateMachine (#1) — cfis subscribe at _ready (AC-27)
var _client = null       ## GymSysBackendClient (#2) — auth/claim (stories 005/008)
var _persistence = null  ## PersistenceLayer (#3) — get_pending_errors (story 010); #24 NEVER writes
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

## Scaffold-only: coarse last-seen GSM state. Real 5-state shell FSM = story 004.
var _gsm_state: int = -1
## Scaffold-only: last lifecycle event tag (AC-02 cycle observability; zero persist).
var _last_lifecycle_event: StringName = &""


func _ready() -> void:
	_instantiate_layers()
	_instantiate_sub_controllers()
	_resolve_default_seams()
	# Boot-surface: connect_for_initial_state at _ready (AC-27 / ADR-0006 C6).
	# No plain-connect fallback (cfis lint discipline — every real GSM + mock
	# implements cfis; a fallback would be dead code, #23 _subscribe_all precedent).
	if _gsm != null and _gsm.has_method("connect_for_initial_state"):
		_gsm.connect_for_initial_state(_on_gsm_state_changed)


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
	if _platform == null:
		_platform = get_node_or_null("/root/PlatformDetect")


## Scaffold GSM handler — records the latest state so story 004 can build the
## 5-state shell FSM on top. Untyped params (project DI discipline). Ghost-safe:
## a deferred cfis sentinel may call this after teardown, but a bare int record
## is harmless.
func _on_gsm_state_changed(_from_state, to_state, _payload) -> void:
	_gsm_state = int(to_state)


## ---- lifecycle entry points (scaffold — zero-persist invariant, AC-02) ----
## Real claim-landing FSM = story 008; logout drain = story 014. These scaffold
## entry points exist so the zero-persist invariant is pinned from day one:
## neither touches PersistenceLayer (the only token write is #2's, story 008).

## Claim succeeded → shell leaves LOGIN toward the landing state. Scaffold:
## records the event; performs ZERO persist writes (#24 owns no persisted state).
func notify_claim_succeeded() -> void:
	_last_lifecycle_event = &"claim_succeeded"


## Logout requested → shell returns to LOGIN. Scaffold: records the event;
## performs ZERO persist writes (the #2 token drain is story 014, not a #24 write).
func request_logout() -> void:
	_last_lifecycle_event = &"logout"


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
