#!/usr/bin/env sh
# CI Lint: Streak mutator ban + binding marker (TR-streak-002, ADR-0006 Contract 12)
#
# Purpose (Pillar 1 anti-fabrication — closed API):
#   StreakSystem owns the streak count and the streak.* persistence namespace.
#   No other game code may mutate `_streak_count` or write a `streak.*` key directly;
#   doing so would bypass the drift gate / consecutive-day classification and let a
#   streak be fabricated. This lint enforces that closed-API boundary.
#
# Checks:
#   1. No `_streak_count` assignment outside src/autoload/streak_system.gd
#   2. No `write("streak.` call outside src/autoload/streak_system.gd
#   3. (AC-ss-ci-3) The ADR-006 Contract 4 binding marker is present in streak_system.gd
#
# Exit: 0 PASS, 1 violation, 2 internal error (project CI lint convention).
#
# Governing docs: ADR-0006 Contract 12; design/gdd/streak-system.md; TR-streak-002.

set -eu

STREAK_FILE="src/autoload/streak_system.gd"

if [ ! -f "$STREAK_FILE" ]; then
	echo "::error::[check_streak_mutator_ban] streak_system.gd not found: $STREAK_FILE" >&2
	exit 2
fi

status=0

# --- Check 1+2: forbidden mutations / writes outside streak_system.gd -------
# rg exit codes: 0 match, 1 no-match (PASS), 2+ real error. Distinguish them so
# a bad regex / IO error is not silently swallowed as "clean".
# Regex notes:
#   * leading (^|[^A-Za-z0-9_]) avoids matching identifiers like my_streak_count
#   * [-+*/%]?= covers =, +=, -=, *=, /=, %=
#   * ([^=]|$) excludes the == comparison while still matching a trailing `=` at EOL
set +e
violations=$(
	rg -n -g '*.gd' -g '!src/autoload/streak_system.gd' \
		-e '(^|[^A-Za-z0-9_])_streak_count[[:space:]]*[-+*/%]?=([^=]|$)' \
		-e 'write\([[:space:]]*"streak\.' \
		src/
)
rc=$?
set -e
if [ "$rc" -gt 1 ]; then
	echo "::error::[check_streak_mutator_ban] rg failed (exit $rc) while scanning src/" >&2
	exit 2
fi

if [ -n "$violations" ]; then
	echo "::error file=$STREAK_FILE::Forbidden streak mutation / streak.* write outside streak_system.gd (TR-streak-002)"
	echo ""
	echo "StreakSystem is a closed API. Mutate the streak count and write streak.*"
	echo "keys ONLY from src/autoload/streak_system.gd. Offending references:"
	echo "$violations" | while IFS= read -r line; do
		echo "  $line"
	done
	status=1
fi

# --- Check 3 (AC-ss-ci-3): binding marker present --------------------------
if ! rg -q 'ADR-006 Contract 4:' "$STREAK_FILE"; then
	echo "::error file=$STREAK_FILE::Missing binding marker '# ADR-006 Contract 4:' (AC-ss-ci-3)"
	echo "  streak_system.gd must document its connect_for_initial_state compliance"
	echo "  with a '# ADR-006 Contract 4:' comment near the GSM subscription."
	status=1
fi

if [ "$status" -eq 0 ]; then
	echo "[check_streak_mutator_ban] PASS — closed API intact + binding marker present"
fi
exit "$status"
