## ErrorSeverityMap — #24 data-driven #3 error_code → severity classification (story 010).
##
## Driving GDD: design/gdd/login-gymsys-connection-ui.md Rule 5 (source-first dispatch)
## + Rule 6 (4 semantic severity classes, data-driven .tres + UNMAPPED default-deny).
## Owner: LoginShellCoordinator (#24) — a read-only design Resource loaded from
## assets/data/error_severity_map.tres (#3's 12 error codes carved into ONGOING / WIPE
## / TRANSIENT; designers add a 13th code by editing the .tres, no code change).
##
## NO class_name (preload-referenced) — dodges the global-class-cache staleness that
## bites class_name adds (reference_dev_environment). The .tres references this script
## by path, not by registered class.
##
## Severity is assigned SOURCE-FIRST (Rule 5): #8/#11/#12 → FEATURE_DEGRADED by signal
## SOURCE (never by error_code — prevents a sibling code string colliding with a #3
## code and being mis-classified as acknowledge-dismissable WIPE). #3 → .tres lookup;
## a miss is NOT silently dropped — it falls through to UNMAPPED (ONGOING-weight,
## "偵測到未知存檔問題"), because GDD L30 defines "any error reaching #24 that produces
## no surface = bug" + falsifies Pillar 1 zero-silent-swallow (EC-B9 / AC-52).
extends Resource

const ShellFormulas := preload("res://src/ui/login_shell/shell_formulas.gd")

## 4 semantic error classes (Rule 6) + UNMAPPED forward-compat default-deny +
## DISCONNECTED connection-status class (story 011 — ranks ABOVE all error classes).
## Ordinal order is NOT the priority order — use priority_weight() for the comparator.
enum Severity { TRANSIENT, FEATURE_DEGRADED, WIPE, ONGOING, UNMAPPED, DISCONNECTED, NOTIFICATION }

## The 4 upstream error sources (Rule 5). #3 = PersistenceLayer (code-classified);
## #8/#11/#12 = STREAK/STAT/ABILITY (source-classified → FEATURE_DEGRADED).
enum Source { PERSISTENCE, STREAK, STAT, ABILITY }

## #3 codes carved by their REAL persistence outcome (Rule 6 / persistence-layer.md
## Rule 9). Data-driven: a new #3 code is added by the designer here in the .tres.
@export var ongoing_codes: Array[StringName] = [
	&"QUOTA_EXHAUSTED", &"READ_ONLY_FILESYSTEM",
]
@export var wipe_codes: Array[StringName] = [
	&"INVALID_JSON", &"EMPTY_FILE", &"UNREGISTERED_PAYLOAD_TYPE", &"FLUSH_FAILED",
	&"MIGRATION_TIMEOUT", &"MIGRATION_CHAIN_TOO_LONG", &"SCHEMA_DOWNGRADE", &"FILE_TOO_LARGE",
]
@export var transient_codes: Array[StringName] = [
	&"NOT_READY", &"MIGRATION_IN_PROGRESS",
]


## #3-only classification: ONGOING / WIPE / TRANSIENT; a miss → UNMAPPED (default-deny,
## never silent — AC-52 / EC-B9). StringName equality is value-based, safe here.
func classify_code(error_code: StringName) -> int:
	if error_code in ongoing_codes:
		return Severity.ONGOING
	if error_code in wipe_codes:
		return Severity.WIPE
	if error_code in transient_codes:
		return Severity.TRANSIENT
	return Severity.UNMAPPED


## Source-first dispatch (Rule 5). #8/#11/#12 → FEATURE_DEGRADED by SOURCE (error_code
## ignored). #3 (PERSISTENCE) → code lookup.
func classify_source_first(source: int, error_code: StringName) -> int:
	if source == Source.STREAK or source == Source.STAT or source == Source.ABILITY:
		return Severity.FEATURE_DEGRADED
	return classify_code(error_code)  # source == PERSISTENCE (#3)


## Main-slot priority weight (Rule 7 ladder: DISCONNECTED > ONGOING > WIPE >
## FEATURE_DEGRADED > TRANSIENT). UNMAPPED ranks AS ONGOING (default-deny is
## highest-safe error weight). Explicit mapping — the enum ordinal is not the order.
static func priority_weight(severity: int) -> int:
	match severity:
		Severity.DISCONNECTED:
			return 5
		Severity.ONGOING, Severity.UNMAPPED:
			return 4
		Severity.WIPE:
			return 3
		Severity.FEATURE_DEGRADED:
			return 2
		Severity.TRANSIENT:
			return 1
		_:
			return 0


## ---- per-class flags (AC-30/31/32) ----

## ONGOING/UNMAPPED = acknowledge-to-minimize (not fully dismissable → false).
## WIPE = acknowledge-dismissable (the event already happened) → true.
## FEATURE_DEGRADED = auto-clear on next success / TRANSIENT = auto-expire → not manual.
static func is_dismissable(severity: int) -> bool:
	return severity == Severity.WIPE


## #8/#11/#12 FEATURE_DEGRADED banners clear when that feature next saves successfully.
static func is_auto_clear_on_success(severity: int) -> bool:
	return severity == Severity.FEATURE_DEGRADED


## TTL for Formula 2 auto-expire. TRANSIENT → TRANSIENT_BANNER_TTL_SEC; everything
## else → the persistent sentinel (never auto-expires — Rule 6).
static func ttl_sec(severity: int) -> float:
	if severity == Severity.TRANSIENT:
		return ShellFormulas.TRANSIENT_BANNER_TTL_SEC
	return ShellFormulas.PERSISTENT_TTL_SENTINEL
