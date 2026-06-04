## IInputPolicy — Input permission interface (ADR-0006 Contract 13)
##
## Story 008 deliverable: protocol class that input handlers inject via
## constructor. Decouples handlers from `GameStateMachine.current_state` —
## any object exposing `is_input_permitted() -> bool` can play the role.
##
## Implementations:
##   - `AttentionBudgetPolicy` (#33 Story 001 injection seam; full Hybrid derivation Story 002)
##     — derives from live `GameStateMachine.get_current_state()` + `WorkoutStateTracker.get_current_phase()`
##   - `MockInputPolicy` (tests/mocks/) — explicit permitted flag per method
##
## ## Pillar 2 enforcement layer
## This interface places Pillar 2 enforcement at the INPUT BOUNDARY, not at
## the state-machine boundary. GameStateMachine remains a read-only source of
## truth; IInputPolicy is the gate that input handlers respect. ADR-0006 line
## 637: "Refactor-safe — input handlers depend on abstraction, not concretion."
##
## ## Interface extension note (Story 001 / #33 GDD B-C2)
## ADR-0006 Contract 13 originally defined only `is_input_permitted()`.
## #33 GDD B-C2 decision added `is_notification_permitted()` as the second
## pure pull predicate — both belong on the same interface so a single
## MockInputPolicy can stub both in tests. This extension is within #33's
## latitude as the Pillar 2 constitutional owner. A future ADR-0006 addendum
## should formalize this addition to Contract 13 if required.
class_name IInputPolicy extends RefCounted


## Returns true if input events should be processed in the current context.
## Override in subclasses. Default implementation pushes an error so a missing
## override fails fast in debug builds.
##
## Production: derives from live GSM state + WST phase (Hybrid derivation,
##   AttentionBudgetPolicy #33 Story 002).
## Tests: returns `_permitted` flag (MockInputPolicy).
func is_input_permitted() -> bool:
	push_error("IInputPolicy.is_input_permitted() not overridden by %s" % get_class())
	return false


## Returns true if non-critical notifications are permitted in the current context.
## Override in subclasses. Default implementation pushes an error so a missing
## override fails fast in debug builds.
##
## Introduced by #33 GDD B-C2 (Story 001). Full Formula 2 derivation owned by
## Story 003. SET_ACTIVE phase and lifecycle states suppress notifications to
## enforce Pillar 2 "no interruptions during sets".
##
## Production: AttentionBudgetPolicy (Story 003 full derivation).
## Tests: returns `_notification_permitted` flag (MockInputPolicy).
func is_notification_permitted() -> bool:
	push_error("IInputPolicy.is_notification_permitted() not overridden by %s" % get_class())
	return false
