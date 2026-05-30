## test_backend_unknown_rarity_tier_fallback.gd — Story 010 AC-44
##
## Governing story: production/epics/loot-drop-system/story-010-idempotency-guards.md
## Governing ADRs : ADR-0005 (INV-4 rarity tier enum consistency); EC-22
##
## AC-44: LootDropParser.parse_backend_ack() must reject unknown rarity_tier
## strings (e.g. "MYTHIC") with CRITICAL telemetry and empty-dict return.
## It must NOT silently default to COMMON (that would hide contract violations).
## Valid tiers must pass through unchanged.
extends GutTest


func before_each() -> void:
	LootDropParser.clear_telemetry()


func after_each() -> void:
	LootDropParser.clear_telemetry()


# ── AC-44: unknown tier rejected ──────────────────────────────────────────────

func test_ac44_mythic_tier_returns_empty_dict() -> void:
	var response := {"rarity_tier": "MYTHIC", "canonical_id": "C-001"}
	var result := LootDropParser.parse_backend_ack(response)
	assert_eq(result.size(), 0,
		"AC-44: 'MYTHIC' (unknown tier) must return empty dict {}")


func test_ac44_mythic_tier_emits_critical_unknown_tier_telemetry() -> void:
	LootDropParser.parse_backend_ack({"rarity_tier": "MYTHIC"})
	var events := LootDropParser.get_telemetry("loot.backend.unknown_tier")
	assert_eq(events.size(), 1,
		"AC-44: unknown tier must emit loot.backend.unknown_tier telemetry exactly once")


func test_ac44_critical_severity_in_telemetry() -> void:
	LootDropParser.parse_backend_ack({"rarity_tier": "ULTRA"})
	var events := LootDropParser.get_telemetry("loot.backend.unknown_tier")
	assert_eq(events.size(), 1)
	assert_eq(events[0]["data"]["severity"], "CRITICAL",
		"AC-44: unknown tier telemetry must have severity='CRITICAL'")


func test_ac44_received_tier_in_telemetry_data() -> void:
	LootDropParser.parse_backend_ack({"rarity_tier": "MYTHIC"})
	var events := LootDropParser.get_telemetry("loot.backend.unknown_tier")
	assert_eq(events[0]["data"]["received"], "MYTHIC",
		"AC-44: telemetry must record the received (invalid) tier string")


func test_ac44_no_silent_common_default() -> void:
	# The return must be {} — NOT {"rarity_tier": "COMMON"} or any other default.
	var result := LootDropParser.parse_backend_ack({"rarity_tier": "MYTHIC"})
	assert_false(result.has("rarity_tier"),
		"AC-44: reject must return {} — no rarity_tier key, no silent COMMON default")


func test_ac44_no_crash_on_unknown_tier() -> void:
	# The function must complete without crashing.
	LootDropParser.parse_backend_ack({"rarity_tier": "MYTHIC"})
	pass_test("AC-44: parse_backend_ack with unknown tier must not crash")


# ── Valid tiers pass through ───────────────────────────────────────────────────

func test_valid_common_tier_passes() -> void:
	var response := {"rarity_tier": "COMMON", "canonical_id": "C-002"}
	var result := LootDropParser.parse_backend_ack(response)
	assert_eq(result, response,
		"Valid 'COMMON' tier must pass through unchanged")
	assert_eq(LootDropParser.get_telemetry("loot.backend.unknown_tier").size(), 0,
		"Valid tier must NOT emit unknown_tier telemetry")


func test_valid_uncommon_passes() -> void:
	var response := {"rarity_tier": "UNCOMMON"}
	var result := LootDropParser.parse_backend_ack(response)
	assert_eq(result.get("rarity_tier"), "UNCOMMON", "'UNCOMMON' must pass through")


func test_valid_rare_passes() -> void:
	var result := LootDropParser.parse_backend_ack({"rarity_tier": "RARE"})
	assert_eq(result.get("rarity_tier"), "RARE", "'RARE' must pass through")


func test_valid_epic_passes() -> void:
	var result := LootDropParser.parse_backend_ack({"rarity_tier": "EPIC"})
	assert_eq(result.get("rarity_tier"), "EPIC", "'EPIC' must pass through")


func test_valid_legendary_passes() -> void:
	var result := LootDropParser.parse_backend_ack({"rarity_tier": "LEGENDARY"})
	assert_eq(result.get("rarity_tier"), "LEGENDARY", "'LEGENDARY' must pass through")


func test_empty_rarity_tier_string_is_rejected() -> void:
	var result := LootDropParser.parse_backend_ack({"rarity_tier": ""})
	assert_eq(result.size(), 0, "Empty rarity_tier string must be rejected")


func test_missing_rarity_tier_field_is_rejected() -> void:
	var result := LootDropParser.parse_backend_ack({"canonical_id": "C-003"})
	assert_eq(result.size(), 0, "Missing rarity_tier field must be rejected")


func test_lowercase_tier_is_rejected() -> void:
	# Case-sensitive: "common" ≠ "COMMON".
	var result := LootDropParser.parse_backend_ack({"rarity_tier": "common"})
	assert_eq(result.size(), 0,
		"Lowercase 'common' must be rejected (case-sensitive enum names)")
