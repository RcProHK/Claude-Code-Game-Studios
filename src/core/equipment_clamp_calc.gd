## EquipmentClampCalc — Formula 4 AntiSnowball clamp for #17 (Pass 1 rewrite)
##
## Driving GDD: design/gdd/equipment-inventory.md Formula 4 + Rule 8 + D3/D4/D8
## Driving Story: production/epics/equipment-inventory/story-008-aggregation-antisnowball-push.md
## Governing ADRs: FR-Equipment-AntiSnowball (#13 binding — ANTISNOWBALL_MULT
## LOCKED 3.0, NOT a knob); ADR-0009 (modifier payload shape)
##
## FORMULA (double lower + double upper bound):
##   cap       = max(ANTISNOWBALL_FLOOR, ANTISNOWBALL_MULT × stat_derived_atk)
##   effective = clamp(raw_atk, 0, min(cap, EQUIPMENT_ATK_MOD_MAX))
## plus per-key #11 contract clamps on every derived key (solves the cap>+300
## range collision — original CD ADVISORY-3, absorbed in Pass 1).
##
## D8 NOTE: derived-keys-only means raw_atk = Σ ATTACK_POWER deltas — there is
## no STR/DEX amplification branch for the clamp to miss (the Pass 1 spec hole
## is structurally closed).
##
## Fresh-account worked example: SDA 28 → cap = max(30, 84) = 84; LEGENDARY
## weapon raw 90 → effective 84 → "+84 / +90 受真身上限約束" badge (Pillar 1).
class_name EquipmentClampCalc


## FR-Equipment-AntiSnowball multiplier — LOCKED, changing it breaches the #13
## contract (equipment-derived ATK ≤ 3 × stat-derived ATK).
const ANTISNOWBALL_MULT: float = 3.0

## Defense-in-depth floor (D4): real fresh accounts sit at cap 84 (SDA 28);
## the floor only binds on the #11 corruption-clamp path (SDA → 0).
const ANTISNOWBALL_FLOOR: float = 30.0

## #11 per-key contract ceilings (registry equipment_*_mod ranges — NOT knobs).
const EQUIPMENT_ATK_MOD_MAX: float = 300.0
const EQUIPMENT_HP_MOD_MAX: float = 500.0
const EQUIPMENT_MOVE_MOD_MAX: float = 100.0
const EQUIPMENT_CRIT_MOD_MAX: float = 0.20


## Apply Formula 4 + per-key contract clamps to a raw aggregate.
## Input: raw aggregate dict (4 derived keys, non-negative per the D8 guard).
## Returns a NEW dict — never mutates the input.
static func clamp_aggregate(raw: Dictionary, stat_derived_atk: float) -> Dictionary:
	var out: Dictionary = {}
	for key: Variant in raw:
		out[key] = float(raw[key])

	if out.has(&"attack_power"):
		out[&"attack_power"] = clampf(
			out[&"attack_power"], 0.0,
			minf(atk_cap(stat_derived_atk), EQUIPMENT_ATK_MOD_MAX))
	if out.has(&"max_hp"):
		out[&"max_hp"] = clampf(out[&"max_hp"], 0.0, EQUIPMENT_HP_MOD_MAX)
	if out.has(&"move_speed"):
		out[&"move_speed"] = clampf(out[&"move_speed"], 0.0, EQUIPMENT_MOVE_MOD_MAX)
	if out.has(&"crit_chance"):
		out[&"crit_chance"] = clampf(out[&"crit_chance"], 0.0, EQUIPMENT_CRIT_MOD_MAX)
	return out


## The AntiSnowball cap for a given stat-derived ATK (pre #11-range intersection).
static func atk_cap(stat_derived_atk: float) -> float:
	return maxf(ANTISNOWBALL_FLOOR, ANTISNOWBALL_MULT * stat_derived_atk)
