#!/usr/bin/env sh
# CI Lint: forward-recovery must NOT call _generate_transition_id()
# (ADR-0006 Contract 2 line 153 binding)
#
# Forward-recovery replays a transition from a persisted tombstone. The
# tombstone carries the ORIGINAL transition_id which may already be committed
# to the backend. Regenerating would produce a duplicate transition record
# and break the chain integrity.
#
# Behavior: scan all `_forward_recover*` functions in src/autoload/game_state_machine.gd
# for `_generate_transition_id` calls. Fail if found.
set -eu

TARGET="src/autoload/game_state_machine.gd"
FAIL=0

if [ ! -f "$TARGET" ]; then
	echo "::error::[check_forward_recover_no_generate] target file not found: $TARGET" >&2
	exit 2
fi

# Extract forward_recover function bodies + scan for _generate_transition_id
# Use awk to capture each function's body and check it.
violations=$(
	awk '
		/^func _forward_recover/ { in_func = 1; func_name = $0; next }
		in_func && /^func / { in_func = 0; next }
		in_func && /_generate_transition_id/ {
			# Strip inline comments
			hash_idx = index($0, "#")
			if (hash_idx > 0) {
				code = substr($0, 1, hash_idx - 1)
			} else {
				code = $0
			}
			if (index(code, "_generate_transition_id") > 0) {
				printf "%d: in %s — %s\n", NR, func_name, $0
			}
		}
	' "$TARGET"
)

if [ -n "$violations" ]; then
	echo "::error file=$TARGET::Forbidden: _generate_transition_id() in forward-recovery path"
	echo "$violations"
	exit 1
fi

echo "[check_forward_recover_no_generate] PASS — forward-recovery reuses tombstone transition_id"
exit 0
