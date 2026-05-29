# SerializableResource Round-Trip Tests — Story 004 AC-05 / AC-05b
#
# Scope: proves the Resource → Dictionary → Resource round-trip preserves all
# typed fields across the persistence boundary, AND that `payload_type` is
# emitted via `get_script().get_global_name()` (NOT `get_class()` which would
# silently corrupt to the literal string "Resource" for any GDScript subclass).
#
# AC-05 (Story 004 line 32):
#   GIVEN BossPayload.new() with outcome=DEFEATED, boss_id=42,
#         hp_at_interrupt=100, hp_max=200,
#   WHEN  to_dict() → write("pending_transition", ...) → read() →
#         BossPayload.from_dict(),
#   THEN  restored outcome==DEFEATED, boss_id==42, hp_at_interrupt==100,
#         hp_max==200; payload_type == "BossPayload" (NOT "Resource").
#
# AC-05b (Story 004 line 33):
#   GIVEN BossPayload.new() with outcome=ABANDONED (default enum value = 0)
#         AND hp_at_interrupt=0 (zero integer),
#   WHEN  to_dict() → from_dict() round-trip,
#   THEN  outcome==ABANDONED (not corrupted to "DEFEATED" by null-find_key
#         fallback); hp_at_interrupt==0 (zero preserved, not dropped as falsy).
#
# Scope deviation from Story 004 minimum:
#   This suite adds two defensive tests beyond the strict AC mandate:
#     (5) StateTransitionPayload with nested BossPayload — exercises the
#         documented "caller pre-converts nested SerializableResource"
#         responsibility (state_transition_payload.gd line 43-47).
#     (6) BossPayload.from_dict() defensive missing-key handling — exercises
#         the ADR-0006 Contract 3 read path defense (serializable_resource.gd
#         line 41-42 binding).
#   Both are documented contract behaviors; the extension is cheap, increases
#   regression protection against forward-recovery corruption bugs, and was
#   recommended in the implementation plan.
#
# Test isolation:
#   These tests construct fresh BossPayload / StateTransitionPayload instances
#   per test (Resource.new() — no autoload state mutation, no FileAccess I/O).
#   No before_each / after_each required.
#
# Framework: GUT (Godot Unit Testing) v7.x
# Governing ADRs: ADR-0006 Contract 3 (Serialization Envelope)
# Driving Story: production/epics/persistence-layer/story-004-serializable-resource-envelope.md
extends GutTest


# ----------------------------------------------------------------------------
# AC-05: Full-field round-trip + payload_type preservation
# ----------------------------------------------------------------------------

func test_boss_payload_round_trip_preserves_all_fields() -> void:
	# Arrange — populate every @export field with a distinct non-default value
	# so any silent drop / corruption is detectable in assertions.
	var original: BossPayload = BossPayload.new()
	original.outcome = BossPayload.BossOutcome.DEFEATED
	original.boss_id = 42
	original.hp_at_interrupt = 100
	original.hp_max = 200

	# Act — full round-trip through the Contract 3 envelope.
	var serialized: Dictionary = original.to_dict()
	var restored: BossPayload = BossPayload.from_dict(serialized)

	# Assert — every @export field equals the original.
	assert_eq(
		restored.outcome,
		BossPayload.BossOutcome.DEFEATED,
		"outcome must round-trip to DEFEATED (was %d)" % restored.outcome
	)
	assert_eq(restored.boss_id, 42, "boss_id must round-trip to 42")
	assert_eq(restored.hp_at_interrupt, 100, "hp_at_interrupt must round-trip to 100")
	assert_eq(restored.hp_max, 200, "hp_max must round-trip to 200")


func test_boss_payload_round_trip_preserves_payload_type_not_resource() -> void:
	# Arrange — any populated BossPayload works; payload_type is type-derived.
	var original: BossPayload = BossPayload.new()
	original.outcome = BossPayload.BossOutcome.DEFEATED
	original.boss_id = 42
	original.hp_at_interrupt = 100
	original.hp_max = 200

	# Act
	var serialized: Dictionary = original.to_dict()

	# Assert — payload_type MUST be the registered class_name string, NOT the
	# engine base class string. This is the load-bearing assertion that proves
	# get_script().get_global_name() is wired (TR-persist-005 binding). If
	# someone refactors to get_class(), this assertion fails with
	# expected "BossPayload" got "Resource".
	assert_true(
		serialized.has("payload_type"),
		"to_dict() must emit a payload_type field for PersistenceLayer dispatch"
	)
	assert_eq(
		serialized["payload_type"],
		"BossPayload",
		"payload_type must equal class_name \"BossPayload\" — NEVER engine base \"Resource\" (TR-persist-005)"
	)


# ----------------------------------------------------------------------------
# AC-05b: Default-enum + zero-int preservation
# ----------------------------------------------------------------------------

func test_boss_payload_round_trip_preserves_abandoned_default_enum() -> void:
	# Arrange — outcome=ABANDONED is enum value 0 (load-bearing default per
	# BossPayload.BossOutcome doc comment). Tests that a freshly-constructed
	# BossPayload with no field mutations round-trips to ABANDONED, NOT
	# corrupted by null-find_key fallback or implicit truthy/falsy handling.
	var original: BossPayload = BossPayload.new()
	# Explicitly assert pre-condition before mutating anything else.
	assert_eq(
		original.outcome,
		BossPayload.BossOutcome.ABANDONED,
		"sanity: BossPayload default outcome must be ABANDONED (enum value 0)"
	)
	original.boss_id = 7
	original.hp_at_interrupt = 50
	original.hp_max = 150

	# Act
	var serialized: Dictionary = original.to_dict()
	var restored: BossPayload = BossPayload.from_dict(serialized)

	# Assert — ABANDONED preserved through the round-trip. The risk this guards
	# against: BossOutcome.find_key(0) returning the string "ABANDONED" but a
	# downstream BossOutcome.get("ABANDONED", DEFEATED) lookup using DEFEATED
	# as a wrong default — that bug would silently grant loot on a "should-not-
	# loot" outcome (Pillar 3 violation).
	assert_eq(
		restored.outcome,
		BossPayload.BossOutcome.ABANDONED,
		"outcome=ABANDONED (enum 0) must round-trip to ABANDONED, NOT corrupted to DEFEATED"
	)


func test_boss_payload_round_trip_preserves_zero_hp_at_interrupt() -> void:
	# Arrange — hp_at_interrupt=0 is the DEFEATED-case value (boss HP driven
	# to 0 via combat). A naive `to_dict` that drops falsy values would lose
	# this distinction, indistinguishable from "key not set" on restore.
	var original: BossPayload = BossPayload.new()
	original.outcome = BossPayload.BossOutcome.DEFEATED
	original.boss_id = 5
	original.hp_at_interrupt = 0   # the load-bearing zero
	original.hp_max = 200

	# Act
	var serialized: Dictionary = original.to_dict()
	var restored: BossPayload = BossPayload.from_dict(serialized)

	# Assert — zero preserved across the boundary, not silently dropped/defaulted.
	assert_true(
		serialized.has("hp_at_interrupt"),
		"to_dict() must emit hp_at_interrupt even when value is 0 (no falsy-drop)"
	)
	assert_eq(
		serialized["hp_at_interrupt"],
		0,
		"hp_at_interrupt=0 must serialize as the integer 0, not omitted"
	)
	assert_eq(
		restored.hp_at_interrupt,
		0,
		"hp_at_interrupt=0 must round-trip to 0 (DEFEATED outcome semantic)"
	)


# ----------------------------------------------------------------------------
# Extension test 5: StateTransitionPayload with nested BossPayload
# ----------------------------------------------------------------------------
#
# Exercises the documented contract from state_transition_payload.gd line 43-47:
# "any nested SerializableResource inside `data` must itself have been
# pre-converted to Dictionary by the caller". This proves the call-site pattern
# that GameStateMachine uses when persisting a BossEncounter→LootDrop tombstone:
# StateTransitionPayload.data["boss"] = boss_payload.to_dict() (NOT the raw
# Resource — which would silently drop typed fields per ADR-0006 line 266).

func test_state_transition_payload_round_trip_with_nested_boss_payload_in_data() -> void:
	# Arrange — construct the nested envelope the way GameStateMachine does
	# when serializing a BossEncounter exit tombstone.
	var boss: BossPayload = BossPayload.new()
	boss.outcome = BossPayload.BossOutcome.INTERRUPTED_WITH_CREDIT
	boss.boss_id = 99
	boss.hp_at_interrupt = 75
	boss.hp_max = 150

	var stp: StateTransitionPayload = StateTransitionPayload.new()
	stp.transition_id = "tx_test_round_trip_42"
	stp.source_event = "workout_completed"
	# Caller responsibility per state_transition_payload.gd line 43-47:
	# pre-convert nested SerializableResource before assigning into `data`.
	stp.data = {"boss": boss.to_dict()}

	# Act — round-trip the outer envelope, then reconstruct the nested boss.
	var outer_dict: Dictionary = stp.to_dict()
	var restored_outer: StateTransitionPayload = StateTransitionPayload.from_dict(outer_dict)
	var nested_dict: Dictionary = restored_outer.data["boss"]
	var restored_boss: BossPayload = BossPayload.from_dict(nested_dict)

	# Assert — outer fields preserved.
	assert_eq(restored_outer.transition_id, "tx_test_round_trip_42")
	assert_eq(restored_outer.source_event, "workout_completed")

	# Assert — nested BossPayload all fields preserved through 2-layer round-trip.
	assert_eq(
		restored_boss.outcome,
		BossPayload.BossOutcome.INTERRUPTED_WITH_CREDIT,
		"nested outcome must survive outer-envelope round-trip"
	)
	assert_eq(restored_boss.boss_id, 99)
	assert_eq(restored_boss.hp_at_interrupt, 75)
	assert_eq(restored_boss.hp_max, 150)


# ----------------------------------------------------------------------------
# Extension test 6: defensive against missing keys (older-schema tombstones)
# ----------------------------------------------------------------------------
#
# ADR-0006 Contract 3 line 41-42 (serializable_resource.gd from_dict doc comment):
# "MUST be defensive against missing keys (use `data.get(key, default)`) since
# tombstones may originate from older schema versions before migration completes."
# This test proves the defensive defaults are wired correctly so a partial /
# corrupted tombstone restores to a SAFE BossPayload (no crash, conservative
# values), not a half-instantiated one that crashes on first field access.

func test_boss_payload_from_dict_defensive_against_missing_keys() -> void:
	# Arrange — simulate an older-schema tombstone that only has outcome
	# (e.g., a hypothetical pre-Decision-#2 tombstone before hp tracking).
	var partial_dict: Dictionary = {
		"outcome": "DEFEATED",
		# boss_id, hp_at_interrupt, hp_max all missing.
	}

	# Act — must not crash; must return a valid BossPayload with safe defaults.
	var restored: BossPayload = BossPayload.from_dict(partial_dict)

	# Assert — provided field preserved; missing fields fall back to safe defaults.
	assert_not_null(restored, "from_dict must return a valid BossPayload, not null")
	assert_eq(
		restored.outcome,
		BossPayload.BossOutcome.DEFEATED,
		"provided outcome field must be honored"
	)
	assert_eq(restored.boss_id, 0, "missing boss_id must default to 0")
	assert_eq(restored.hp_at_interrupt, 0, "missing hp_at_interrupt must default to 0")
	assert_eq(restored.hp_max, 0, "missing hp_max must default to 0")

	# Additional defensive case: completely unknown outcome string must fall
	# back to ABANDONED (the conservative fail-safe), NOT crash and NOT silently
	# grant loot via a DEFEATED fallback.
	var unknown_outcome_dict: Dictionary = {
		"outcome": "TOTALLY_MADE_UP_OUTCOME_42",
		"boss_id": 1,
		"hp_at_interrupt": 1,
		"hp_max": 1,
	}
	var conservative_restore: BossPayload = BossPayload.from_dict(unknown_outcome_dict)
	assert_eq(
		conservative_restore.outcome,
		BossPayload.BossOutcome.ABANDONED,
		"unknown outcome string must fall back to ABANDONED (Pillar 3 fail-safe)"
	)
