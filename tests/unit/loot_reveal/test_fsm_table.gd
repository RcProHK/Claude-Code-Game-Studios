extends GutTest
## Story 003 — FSM 8-state × in_catchup table-driven edge law.
## Covers AC-37: every on-table edge applies; every off-table (state, flag, to)
## triple is rejected loudly (push_error + state unchanged) — never silent.
##
## GDD: design/gdd/loot-drop-modal.md States and Transitions (Pass 1 8-state fix).

const CoordinatorScript := preload("res://src/autoload/loot_reveal_coordinator.gd")

const S := CoordinatorScript.ModalState

const ALL_STATES: Array = [
	S.HIDDEN, S.ENTRY, S.CEREMONY, S.STEADY,
	S.EXITING, S.CATCHUP_PROMPT, S.CATCHUP_STREAM, S.CATCHUP_GRID,
]


func _make() -> Node:
	var c: Node = CoordinatorScript.new()
	# Seams stay null — FSM engine has no GSM/#15 dependency; _ready builds layers.
	add_child_autofree(c)
	return c


func _force(c: Node, state: int, in_catchup: bool) -> void:
	c._state = state
	c._in_catchup = in_catchup


# --- AC-37 positive: full table sweep — every legal edge applies ---

func test_every_on_table_edge_transitions() -> void:
	var c: Node = _make()
	for from_state: int in ALL_STATES:
		for flag: bool in [false, true]:
			var legal: Array = (CoordinatorScript.EDGE_TABLE[from_state] as Dictionary)[flag]
			for to_state: int in legal:
				_force(c, from_state, flag)
				var ok: bool = c._transition(to_state)
				assert_true(ok, "edge %s(flag=%s) -> %s must be legal" % [
					S.find_key(from_state), flag, S.find_key(to_state)])
				assert_eq(c._state, to_state, "state advanced to target")


# --- AC-37 negative: every off-table triple rejected, state unchanged ---

func test_every_off_table_edge_is_rejected_loudly() -> void:
	var c: Node = _make()
	var swept: int = 0
	for from_state: int in ALL_STATES:
		for flag: bool in [false, true]:
			var legal: Array = (CoordinatorScript.EDGE_TABLE[from_state] as Dictionary)[flag]
			for to_state: int in ALL_STATES:
				if to_state in legal:
					continue
				_force(c, from_state, flag)
				var ok: bool = c._transition(to_state)
				assert_false(ok, "off-table edge %s(flag=%s) -> %s must be rejected" % [
					S.find_key(from_state), flag, S.find_key(to_state)])
				assert_eq(c._state, from_state, "state unchanged after rejection")
				swept += 1
	assert_gt(swept, 0, "negative sweep actually exercised")


# --- HIDDEN entry resets the catch-up flag + hides surfaces ---

func test_terminal_exit_to_hidden_resets_in_catchup_flag() -> void:
	var c: Node = _make()
	_force(c, S.CATCHUP_GRID, true)
	c.get_modal_layer().visible = true
	assert_true(c._transition(S.HIDDEN))
	assert_false(c.is_in_catchup(), "in_catchup auto-resets on HIDDEN entry")
	assert_false(c.get_modal_layer().visible, "modal layer hidden on terminal exit")
	assert_false(c.get_celebration_vfx_layer().visible, "vfx layer hidden on terminal exit")


# --- Key GDD-named edges exist (regression pins against table edits) ---

func test_gdd_named_edges_present() -> void:
	var t: Dictionary = CoordinatorScript.EDGE_TABLE
	assert_true(S.CATCHUP_PROMPT in (t[S.HIDDEN] as Dictionary)[false], "HIDDEN -> CATCHUP_PROMPT (depth >= threshold)")
	assert_true(S.ENTRY in (t[S.ENTRY] as Dictionary)[false], "ENTRY -> ENTRY (rollback re-query next)")
	assert_true(S.CATCHUP_GRID in (t[S.EXITING] as Dictionary)[true], "EXITING -> CATCHUP_GRID (ceremonies done)")
	assert_true(S.CATCHUP_GRID in (t[S.CEREMONY] as Dictionary)[true], "CEREMONY -> CATCHUP_GRID (in_catchup rollback, ceremonies cleared)")
	assert_true(S.HIDDEN in (t[S.CATCHUP_GRID] as Dictionary)[true], "CATCHUP_GRID -> HIDDEN (terminal emit — Pass 1 GSM deadlock fix)")
	assert_true(S.ENTRY in (t[S.CATCHUP_STREAM] as Dictionary)[true], "CATCHUP_STREAM -> ENTRY (RARE+ ceremonies)")
	assert_eq((t[S.STEADY] as Dictionary)[false], [S.EXITING], "STEADY only exits via EXITING (S3 rollback = display no-op)")
