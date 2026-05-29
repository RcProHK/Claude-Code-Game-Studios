# IInputPolicy — Story 008 AC-15a/15b/input-1 Interface Tests
#
# Scope: verifies the IInputPolicy contract (Contract 13) — interface shape,
# MockInputPolicy behaviour, and file existence.
#
# AC-15a: MockInputPolicy(_permitted=false) blocks input event processing
# AC-15b: `is_input_permitted()` returns bool with no parameters
# AC-gsm-input-1: src/core/i_input_policy.gd file exists
#
# Framework: GUT (Godot Unit Testing) v7.x
# Governing ADRs: ADR-0006 Contract 13 (IInputPolicy interface)
extends GutTest


## AC-15a: MockInputPolicy with _permitted=false blocks input.
## Simulates input handler doing the right thing (consulting policy first).
func test_mock_input_policy_permitted_false_blocks_input() -> void:
	# Arrange
	var policy := MockInputPolicy.new()
	policy.set_permitted(false)

	# Act — simulate handler checking policy before processing
	var processed_count: int = 0
	if policy.is_input_permitted():
		processed_count += 1

	# Assert
	assert_eq(processed_count, 0, "AC-15a: blocked-policy handler must drop input")
	assert_eq(policy.call_count, 1, "Policy must be consulted exactly once")


## AC-15a (positive): MockInputPolicy with _permitted=true allows input.
func test_mock_input_policy_permitted_true_allows_input() -> void:
	# Arrange
	var policy := MockInputPolicy.new()
	policy.set_permitted(true)  # explicit (default is also true)

	# Act
	var processed_count: int = 0
	if policy.is_input_permitted():
		processed_count += 1

	# Assert
	assert_eq(processed_count, 1, "Allowed-policy handler must process input")


## AC-15b: is_input_permitted() returns bool.
func test_iinputpolicy_method_returns_bool_type() -> void:
	# Arrange
	var policy := MockInputPolicy.new()

	# Act
	var result: Variant = policy.is_input_permitted()

	# Assert
	assert_true(result is bool, "is_input_permitted() must return bool")


## AC-15b: method takes no parameters (verified by direct call without args).
func test_iinputpolicy_method_accepts_no_parameters() -> void:
	# If method required parameters, the call below would fail at parse time.
	var policy := MockInputPolicy.new()
	var _result: bool = policy.is_input_permitted()
	# Test passes if we got here without crash
	assert_true(true, "AC-15b: method signature accepts zero arguments")


## AC-gsm-input-1: IInputPolicy is a real class accessible globally.
func test_iinputpolicy_class_exists_and_extends_refcounted() -> void:
	# Direct instantiation proves the class_name is registered.
	var policy: IInputPolicy = IInputPolicy.new()
	assert_not_null(policy, "IInputPolicy.new() must return a valid instance")
	assert_true(policy is RefCounted, "IInputPolicy must extend RefCounted")


## Additional: MockInputPolicy extends IInputPolicy (Liskov compatibility).
func test_mock_input_policy_is_an_iinputpolicy() -> void:
	var mock := MockInputPolicy.new()
	assert_true(mock is IInputPolicy, "MockInputPolicy must be a subtype of IInputPolicy")
