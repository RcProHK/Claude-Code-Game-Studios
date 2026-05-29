## MockInputPolicy — Test stand-in for IInputPolicy (ADR-0006 Contract 14)
##
## Story 008 deliverable: gives tests an explicit toggle for input permission
## without needing to drive `GameStateMachine` into specific substates.
##
## Usage:
## ```gdscript
## var policy := MockInputPolicy.new()
## policy.set_permitted(false)
## var handler := MyInputHandler.new(policy)  # DI
## handler.process_event(event)
## assert_eq(handler.processed_count, 0, "blocked by policy")
## ```
class_name MockInputPolicy extends IInputPolicy

## Permission flag. Tests toggle via `set_permitted()` between scenarios.
var _permitted: bool = true

## Number of times `is_input_permitted()` was called — lets tests verify the
## handler actually consulted the policy (rather than checking GSM state directly).
var call_count: int = 0


func is_input_permitted() -> bool:
	call_count += 1
	return _permitted


func set_permitted(value: bool) -> void:
	_permitted = value


func reset() -> void:
	_permitted = true
	call_count = 0
