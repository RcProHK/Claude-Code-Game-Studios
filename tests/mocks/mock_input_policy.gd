## MockInputPolicy — Test stand-in for IInputPolicy (ADR-0006 Contract 14)
##
## Story 008 deliverable: gives tests an explicit toggle for input permission
## without needing to drive `GameStateMachine` into specific substates.
##
## Story 001 update (#33): added `_notification_permitted` / `is_notification_permitted()`
## to match the extended IInputPolicy interface (GDD B-C2). Both stub values are
## independent — tests can set one without affecting the other.
##
## Usage:
## ```gdscript
## var policy := MockInputPolicy.new()
## policy.set_permitted(false)
## var handler := MyInputHandler.new(policy)  # DI
## handler.process_event(event)
## assert_eq(handler.processed_count, 0, "blocked by policy")
##
## # Notification stub:
## policy.set_notification_permitted(false)
## assert_false(policy.is_notification_permitted())
## ```
class_name MockInputPolicy extends IInputPolicy

## Permission flag for is_input_permitted(). Tests toggle via set_permitted().
var _permitted: bool = true

## Permission flag for is_notification_permitted(). Tests toggle via set_notification_permitted().
## Independent from _permitted — can be set separately for each predicate.
var _notification_permitted: bool = true

## Number of times `is_input_permitted()` was called — lets tests verify the
## handler actually consulted the policy (rather than checking GSM state directly).
var call_count: int = 0

## Number of times `is_notification_permitted()` was called.
var notification_call_count: int = 0


func is_input_permitted() -> bool:
	call_count += 1
	return _permitted


## Returns the notification permission stub flag.
## Full Formula 2 derivation is owned by AttentionBudgetPolicy Story 003.
func is_notification_permitted() -> bool:
	notification_call_count += 1
	return _notification_permitted


func set_permitted(value: bool) -> void:
	_permitted = value


func set_notification_permitted(value: bool) -> void:
	_notification_permitted = value


func reset() -> void:
	_permitted = true
	_notification_permitted = true
	call_count = 0
	notification_call_count = 0
