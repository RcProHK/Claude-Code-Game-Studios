## SourceReceipt — F-12 workout provenance receipt for #17 Equipment & Inventory
##
## Driving GDD: design/gdd/equipment-inventory.md Rule 10 (F-12 binding)
## Driving Story: production/epics/equipment-inventory/story-001-data-types-stat-table.md
## Governing ADRs:
##   * ADR-0006 (Accepted) Contract 3 — SerializableResource dict envelope
##   * ADR-0009 (Accepted) — persisted payloads as typed envelopes
##
## WHY this exists (Pillar 1 anti-fabrication):
## A LEGENDARY drop MUST carry the real workout that minted it ("鍛造自 180kg × 5").
## A LEGENDARY without a receipt is a fabrication — receive_loot rolls it back
## (EC-2, drop-hydration scope only). Receipt-bearing items are immune to mailbox
## auto-salvage / hard-cap evict (GDD A3 — never silently expire).
##
## Consumers: #29 Mirror Moment (ceremony narrative payload), #22 Character Screen
## (hover/inspect display). Other tiers carry source_receipt = null (nullable).
class_name SourceReceipt extends SerializableResource


## Unix timestamp (seconds) of the workout that minted this item. 0 = unset.
@export var workout_date_unix: int = 0


## PR snapshot at mint time: { exercise_id: StringName-as-String -> one_rm_kg: float }.
## JSON-native keys/values only (round-trip safety per Contract 3).
@export var pr_snapshot: Dictionary = {}


## Total volume aggregation output (#9 WST) at mint time.
@export var volume_snapshot: float = 0.0


## Pre-rendered ledger-voice signature ("鍛造自 180kg × 5", #26 ledger voice).
## Rendered ONCE at mint — display layers never re-derive it.
@export var signature_text: String = ""


## Convert to plain Dictionary per ADR-0006 Contract 3.
## payload_type via get_script().get_global_name() (NOT get_class() — TR-persist-005;
## CI lint check_payload_type_uses_get_script enforces this).
func to_dict() -> Dictionary:
	return {
		"payload_type": get_script().get_global_name(),
		"workout_date_unix": workout_date_unix,
		"pr_snapshot": pr_snapshot,
		"volume_snapshot": volume_snapshot,
		"signature_text": signature_text,
	}


## Reconstruct from a to_dict() Dictionary. Defensive against missing keys
## (older schema tombstones) per Contract 3.
static func from_dict(data_dict: Dictionary) -> SerializableResource:
	var receipt: SourceReceipt = SourceReceipt.new()
	receipt.workout_date_unix = int(data_dict.get("workout_date_unix", 0))
	receipt.pr_snapshot = data_dict.get("pr_snapshot", {})
	receipt.volume_snapshot = float(data_dict.get("volume_snapshot", 0.0))
	receipt.signature_text = String(data_dict.get("signature_text", ""))
	return receipt
