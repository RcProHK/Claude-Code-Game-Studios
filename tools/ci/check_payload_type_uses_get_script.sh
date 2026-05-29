#!/usr/bin/env sh
# CI Lint: payload_type must use get_script().get_global_name(), never get_class()
#          (ADR-0006 Contract 3 — Story 004 AC-06 — TR-persist-005)
#
# Purpose:
#   Object.get_class() returns the ENGINE BASE class string for GDScript
#   classes. Any subclass of Resource (BossPayload, StateTransitionPayload,
#   LootPayload, ...) returns the literal string "Resource" from get_class()
#   — NEVER the registered class_name. Using get_class() for the payload_type
#   field silently corrupts PersistenceLayer's forward-recovery dispatch:
#     ClassDB.instantiate("Resource") → bare Resource with no @export fields
#     → BossOutcome semantics lost → #15 LootDrop merge logic + #29 Mirror
#       Moment weekly progression both miscount the outcome.
#
#   The correct binding is `get_script().get_global_name()` which returns
#   the registered class_name (e.g., "BossPayload"). This lint enforces
#   the binding across src/**/*.gd on every push/PR.
#
# Behavior:
#   * Scans every .gd file under src/ recursively.
#   * Flags any non-comment line containing the pattern
#     `payload_type` followed (on the same line) by `=` and `.get_class(`.
#   * Comment-line filter: lines whose first non-whitespace char is `#`
#     are skipped (prevents this file's own docstring examples from
#     tripping false positives — and any in-code comments demonstrating
#     the forbidden pattern).
#   * Inline-comment filter: only the prefix before the first `#` on each
#     line is scanned (so `# explanation: don't use get_class()` after
#     real code does not interfere).
#   * Exit 0 on PASS, 1 on violation, 2 on internal error (matches the
#     project-wide CI lint exit convention — see
#     `tools/ci/check_no_await_in_persistence.sh`).
#
# Limitations (documented v1):
#   * Multi-line case `payload_type = \n  some_obj.get_class()` NOT detected.
#     Line-by-line scan; defer to v2 if a real multi-line violation surfaces.
#   * Chained-call case `payload_type = wrapper().get_class()` IS detected
#     (the regex matches `.get_class(` anywhere after `payload_type` + `=`).
#
# Forbidden alternatives:
#   * Do NOT special-case via inline `# noqa` markers. There is no safe
#     get_class() here — escalate via ADR addendum if a legitimate exception
#     is ever discovered.
#
# Governing docs:
#   * ADR-0006 (State Machine Contract, Contract 3 — Serialization Envelope)
#   * design/gdd/persistence-layer.md (Rule 4 — payload_type binding)
#   * docs/architecture/tr-registry.yaml (TR-persist-004, TR-persist-005)
#   * production/epics/persistence-layer/story-004-serializable-resource-envelope.md AC-06

set -eu

SCAN_ROOT="src"

if [ ! -d "$SCAN_ROOT" ]; then
	echo "::error::[check_payload_type_uses_get_script] scan root not found: $SCAN_ROOT" >&2
	exit 2
fi

# Collect .gd files under src/. Use POSIX find — same dependency footprint
# as check_no_await_in_persistence.sh (no ripgrep required in CI image).
gd_files=$(find "$SCAN_ROOT" -type f -name "*.gd" 2>/dev/null) || {
	echo "::error::[check_payload_type_uses_get_script] find failed under $SCAN_ROOT" >&2
	exit 2
}

if [ -z "$gd_files" ]; then
	# Empty src/ — PASS without false fail (matches precedent in
	# check_connect_for_initial_state_bind.gd).
	echo "[check_payload_type_uses_get_script] PASS — 0 .gd files under $SCAN_ROOT"
	exit 0
fi

# Strategy per file:
#   1. Strip inline comments: for each line, keep only the prefix before the
#      first `#`. Full-line comments collapse to empty; inline comments lose
#      their trailing portion.
#   2. Match the forbidden pattern as a regex against the stripped code.
#      Pattern: `payload_type` ... `=` ... `.get_class(` on the same line.
#   3. Report violations in `path:line: original-text` format (CI parsers
#      consume this format directly).
#
# We use awk (POSIX) so we do not depend on ripgrep / bash-isms.

violations_found=0
violation_output=""

for f in $gd_files; do
	file_violations=$(
		awk -v fpath="$f" '
			{
				original = $0
				hash_idx = index($0, "#")
				if (hash_idx > 0) {
					code = substr($0, 1, hash_idx - 1)
				} else {
					code = $0
				}
				# Forbidden pattern: payload_type ... = ... .get_class(
				# - `payload_type` must appear before `=`
				# - `.get_class(` must appear after `=`
				# This catches:
				#   payload_type = x.get_class()
				#   payload_type=foo.get_class()
				#   self.payload_type = self.get_class()
				#   var payload_type := bar.get_class()
				if (match(code, /payload_type[^=]*=[^#]*\.get_class[ \t]*\(/)) {
					printf("%s:%d:%s\n", fpath, NR, original)
				}
			}
		' "$f"
	) || {
		echo "::error::[check_payload_type_uses_get_script] awk failed scanning $f" >&2
		exit 2
	}

	if [ -n "$file_violations" ]; then
		violations_found=1
		if [ -n "$violation_output" ]; then
			violation_output="$violation_output
$file_violations"
		else
			violation_output="$file_violations"
		fi
	fi
done

if [ "$violations_found" -eq 1 ]; then
	echo "::error::Forbidden \`payload_type = ....get_class()\` pattern (ADR-0006 Contract 3 / Story 004 AC-06)"
	echo ""
	echo "Object.get_class() returns the engine base class string for GDScript"
	echo "classes — Resource subclasses ALL return \"Resource\", silently corrupting"
	echo "PersistenceLayer forward-recovery dispatch. Use get_script().get_global_name()"
	echo "instead to obtain the registered class_name (e.g. \"BossPayload\")."
	echo ""
	echo "See:"
	echo "  * ADR-0006 Contract 3 — Serialization Envelope"
	echo "  * design/gdd/persistence-layer.md Rule 4"
	echo "  * src/core/boss_payload.gd for a correct example"
	echo ""
	echo "Violations:"
	printf '%s\n' "$violation_output" | while IFS= read -r line; do
		echo "  $line"
	done
	exit 1
fi

echo "[check_payload_type_uses_get_script] PASS — no forbidden get_class() usage in $SCAN_ROOT"
exit 0
