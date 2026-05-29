## IInputPolicy — Input permission interface (ADR-0006 Contract 13)
##
## Story 008 deliverable: protocol class that input handlers inject via
## constructor. Decouples handlers from `GameStateMachine.current_state` —
## any object exposing `is_input_permitted() -> bool` can play the role.
##
## Implementations:
##   - `AttentionBudgetPolicy` (Story 015 stub; #33 epic full impl)
##     — derives from `GameStateMachine.get_current_state()`
##   - `MockInputPolicy` (tests/mocks/) — explicit permitted flag
##
## ## Pillar 2 enforcement layer
## This interface places Pillar 2 enforcement at the INPUT BOUNDARY, not at
## the state-machine boundary. GameStateMachine remains a read-only source of
## truth; IInputPolicy is the gate that input handlers respect. ADR-0006 line
## 637: "Refactor-safe — input handlers depend on abstraction, not concretion."
class_name IInputPolicy extends RefCounted


## Returns true if input events should be processed in the current substate.
## Override in subclasses. Default implementation pushes an error so a missing
## override fails fast in debug builds.
##
## Production: derives from `GameStateMachine.current_state` against the
## INPUT_BLOCKED_STATES list (Story 015).
## Tests: returns `_permitted` flag (MockInputPolicy).
func is_input_permitted() -> bool:
	push_error("IInputPolicy.is_input_permitted() not overridden by %s" % get_class())
	return false
