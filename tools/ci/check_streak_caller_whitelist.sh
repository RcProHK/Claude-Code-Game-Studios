#!/usr/bin/env sh
# CI Lint: Streak buff multiplier caller whitelist (TR-streak-002, ADR-0006 Contract 12)
#
# Purpose (Pillar 1 anti-fabrication):
#   `get_streak_buff_multiplier()` feeds the loot rarity / Mirror Moment ceremony.
#   Only the two sanctioned consumers may read it; any other caller risks coupling
#   gameplay logic to the streak buff in unintended ways. This lint enforces the
#   caller whitelist.
#
# Whitelist (may reference get_streak_buff_multiplier):
#   * src/autoload/streak_system.gd            (defines it)
#   * src/**/loot_drop_system.gd               (loot rarity modifier)
#   * src/**/mirror_moment_system.gd           (ceremony intensity)
#
# Exit: 0 PASS, 1 violation, 2 internal error (project CI lint convention).
#
# Governing docs: ADR-0006 Contract 12; design/gdd/streak-system.md; TR-streak-002.

set -eu

if [ ! -d "src" ]; then
	echo "::error::[check_streak_caller_whitelist] src/ directory not found" >&2
	exit 2
fi

# rg exit codes: 0 match, 1 no-match (PASS), 2+ real error.
# Path-anchored excludes (not bare basenames) so a stray same-named file in a
# different directory cannot be silently whitelisted.
set +e
violations=$(
	rg -n -g '*.gd' \
		-g '!src/autoload/streak_system.gd' \
		-g '!**/loot_drop_system.gd' \
		-g '!**/mirror_moment_system.gd' \
		'get_streak_buff_multiplier' \
		src/
)
rc=$?
set -e
if [ "$rc" -gt 1 ]; then
	echo "::error::[check_streak_caller_whitelist] rg failed (exit $rc) while scanning src/" >&2
	exit 2
fi

if [ -n "$violations" ]; then
	echo "::error::get_streak_buff_multiplier called outside the whitelist (TR-streak-002)"
	echo ""
	echo "Only loot_drop_system.gd and mirror_moment_system.gd may call"
	echo "get_streak_buff_multiplier(). Offending references:"
	echo "$violations" | while IFS= read -r line; do
		echo "  $line"
	done
	exit 1
fi

echo "[check_streak_caller_whitelist] PASS — no out-of-whitelist callers"
exit 0
