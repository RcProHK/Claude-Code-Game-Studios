## MockInventoryStat — StatSystem test double for #17 InventorySystem tests (seam 2).
##
## Duck-types the #11 surface InventorySystem touches: is_boot_completed() +
## get_attack_power_excluding_equipment() (G-2 APIs) + apply_equipment_modifier
## (push spy — records {id, deltas} per call). `sda` defaults to the fresh-
## account golden 28.0 (cap 84).
class_name MockInventoryStat extends RefCounted


var sda: float = 28.0
var pushes: Array[Dictionary] = []


func is_boot_completed() -> bool:
	return true


func get_attack_power_excluding_equipment() -> float:
	return sda


func apply_equipment_modifier(equipment_id: StringName, modifier) -> void:
	pushes.append({"id": equipment_id, "deltas": modifier.deltas.duplicate()})
