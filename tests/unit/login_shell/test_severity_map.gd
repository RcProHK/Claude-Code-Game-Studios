extends GutTest
## Story 010 — error_severity_map.tres correctness. Covers AC-30 / AC-31 / AC-32 +
## source-first FEATURE_DEGRADED + UNMAPPED default-deny (12 + 3 mappings).
##
## GDD: Rule 6 severity table. Loads the data-driven .tres and queries each code.

const ESM := preload("res://src/ui/login_shell/error_severity_map.gd")
const MAP_PATH := "res://assets/data/error_severity_map.tres"

const ONGOING_CODES := [&"QUOTA_EXHAUSTED", &"READ_ONLY_FILESYSTEM"]
const WIPE_CODES := [
	&"INVALID_JSON", &"EMPTY_FILE", &"UNREGISTERED_PAYLOAD_TYPE", &"FLUSH_FAILED",
	&"MIGRATION_TIMEOUT", &"MIGRATION_CHAIN_TOO_LONG", &"SCHEMA_DOWNGRADE", &"FILE_TOO_LARGE",
]
const TRANSIENT_CODES := [&"NOT_READY", &"MIGRATION_IN_PROGRESS"]

var _map


func before_each() -> void:
	_map = load(MAP_PATH)


func test_tres_loads_with_script() -> void:
	assert_not_null(_map, "error_severity_map.tres loads")
	assert_true(_map.has_method("classify_code"), "loaded instance is an ErrorSeverityMap")


# --- AC-30: ONGOING 2 codes, dismissable=false ---

func test_ac30_ongoing_codes_classify_and_flags() -> void:
	for code in ONGOING_CODES:
		assert_eq(_map.classify_code(code), ESM.Severity.ONGOING, "%s → ONGOING" % code)
	assert_false(ESM.is_dismissable(ESM.Severity.ONGOING), "AC-30: ONGOING dismissable=false")


# --- AC-31: WIPE 8 codes (acknowledge-dismissable) + sibling FEATURE_DEGRADED ---

func test_ac31_wipe_codes_classify_acknowledge_dismissable() -> void:
	assert_eq(WIPE_CODES.size(), 8, "exactly 8 WIPE codes")
	for code in WIPE_CODES:
		assert_eq(_map.classify_code(code), ESM.Severity.WIPE, "%s → WIPE" % code)
	assert_true(ESM.is_dismissable(ESM.Severity.WIPE), "AC-31: WIPE acknowledge-dismissable=true")


func test_ac31_siblings_source_first_feature_degraded_auto_clear() -> void:
	# #8/#11/#12 are classified by SOURCE → FEATURE_DEGRADED, regardless of error_code.
	for src in [ESM.Source.STREAK, ESM.Source.STAT, ESM.Source.ABILITY]:
		assert_eq(
			_map.classify_source_first(src, &"ANYTHING"),
			ESM.Severity.FEATURE_DEGRADED,
			"source %d → FEATURE_DEGRADED (source-first, ignores code)" % src)
	assert_true(ESM.is_auto_clear_on_success(ESM.Severity.FEATURE_DEGRADED), "AC-31: auto_clear_on_success=true")


# --- AC-32: TRANSIENT 2 codes → F2 TTL ---

func test_ac32_transient_codes_classify_and_ttl() -> void:
	for code in TRANSIENT_CODES:
		assert_eq(_map.classify_code(code), ESM.Severity.TRANSIENT, "%s → TRANSIENT" % code)
	assert_eq(
		ESM.ttl_sec(ESM.Severity.TRANSIENT),
		ESM.ShellFormulas.TRANSIENT_BANNER_TTL_SEC,
		"AC-32: TRANSIENT uses F2 TTL (5.0)")
	assert_eq(
		ESM.ttl_sec(ESM.Severity.ONGOING),
		ESM.ShellFormulas.PERSISTENT_TTL_SENTINEL,
		"persistent classes get the never-expire sentinel")


# --- Total coverage: exactly 12 #3 codes mapped ---

func test_twelve_persistence_codes_total() -> void:
	var total: int = ONGOING_CODES.size() + WIPE_CODES.size() + TRANSIENT_CODES.size()
	assert_eq(total, 12, "12 #3 codes (2 ONGOING + 8 WIPE + 2 TRANSIENT)")


# --- UNMAPPED default-deny ---

func test_unmapped_code_is_default_deny_not_silent() -> void:
	assert_eq(
		_map.classify_code(&"FUTURE_CODE_13"),
		ESM.Severity.UNMAPPED,
		"unmapped #3 code → UNMAPPED (never silent — EC-B9)")
	# UNMAPPED ranks AS ONGOING for the main-slot comparator (highest-safe weight).
	assert_eq(
		ESM.priority_weight(ESM.Severity.UNMAPPED),
		ESM.priority_weight(ESM.Severity.ONGOING),
		"UNMAPPED priority weight == ONGOING")


# --- priority order: ONGOING > WIPE > FEATURE_DEGRADED > TRANSIENT (Rule 7) ---

func test_priority_weight_order() -> void:
	var ongoing := ESM.priority_weight(ESM.Severity.ONGOING)
	var wipe := ESM.priority_weight(ESM.Severity.WIPE)
	var fd := ESM.priority_weight(ESM.Severity.FEATURE_DEGRADED)
	var transient := ESM.priority_weight(ESM.Severity.TRANSIENT)
	assert_true(ongoing > wipe, "ONGOING > WIPE")
	assert_true(wipe > fd, "WIPE > FEATURE_DEGRADED")
	assert_true(fd > transient, "FEATURE_DEGRADED > TRANSIENT")
