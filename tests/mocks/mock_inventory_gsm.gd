## MockInventoryGSM — GSM test double for #17 InventorySystem tests (seam 6).
##
## Duck-types the Contract 6 surface InventorySystem touches:
## connect_for_initial_state(callable). The REAL state_changed signature is
## typed `(from_state: GameState, to_state: GameState, payload)` — INT enum
## args, not StringName (combined-gate lesson 2026-06-06) — so deliver() sends
## the real GameState ordinals.
class_name MockInventoryGSM extends RefCounted

const _GSMScript = preload("res://src/autoload/game_state_machine.gd")


var handler: Callable = Callable()


func connect_for_initial_state(callable: Callable) -> void:
	handler = callable


## Simulate a GSM delivery with a raw GameState ordinal.
func deliver(state: int) -> void:
	if handler.is_valid():
		handler.call(_GSMScript.GameState.BOOTING, state, null)


## Convenience: deliver SUSPENDED.
func deliver_suspended() -> void:
	deliver(_GSMScript.GameState.SUSPENDED)


## Convenience: deliver a non-suspended gameplay state (IDLE).
func deliver_gameplay() -> void:
	deliver(_GSMScript.GameState.IDLE)
