#!/usr/bin/env sh
# CI Lint: no `await` in GameStateMachine (ADR-0006 Contract 12)
#
# Purpose:
#   GameStateMachine is autoload pos 2 — boot-time sync discipline (Contract 4).
#   A single `await` here suspends `_ready()` and lets pos 3+ autoloads run
#   against a half-initialised GSM (state_changed subscriber miss, transition
#   primitive locks held mid-step). Contract 12 enforces this via scan-entire-file
#   rule on the state machine file set.
#
# Behavior:
#   * Scans src/autoload/game_state_machine.gd for `\bawait\b`
#   * EXCLUDES lines starting with `#` (comment lines may document the rule)
#   * Exit 0 on PASS, 1 on violation, 2 on internal error
#
# When src/core/state_machine/ is populated by future stories, this script
# extends to scan that directory too.
#
# Governing docs:
#   * ADR-0006 Contract 12 (@no-await scan-entire-file)
#   * production/epics/game-state-machine/story-007-no-await-ci-test-spy.md AC-18a
set -eu

TARGET="src/autoload/game_state_machine.gd"
FAIL=0

if [ ! -f "$TARGET" ]; then
	echo "::error::[check_no_await_in_state_machine] target file not found: $TARGET" >&2
	exit 2
fi

violations=$(
	awk '
		{
			hash_idx = index($0, "#")
			if (hash_idx > 0) {
				code = substr($0, 1, hash_idx - 1)
			} else {
				code = $0
			}
			if (match(code, /(^|[^A-Za-z0-9_])await([^A-Za-z0-9_]|$)/)) {
				printf("%d:%s\n", NR, $0)
			}
		}
	' "$TARGET"
) || {
	echo "::error::[check_no_await_in_state_machine] awk failed" >&2
	exit 2
}

if [ -n "$violations" ]; then
	echo "::error file=$TARGET::Forbidden \`await\` in GameStateMachine (ADR-0006 Contract 12)"
	echo "Violations:"
	echo "$violations" | while IFS= read -r line; do echo "  line $line"; done
	exit 1
fi

echo "[check_no_await_in_state_machine] PASS — no \`await\` found in $TARGET"
exit 0
