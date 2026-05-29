#!/usr/bin/env sh
# CI Lint: PersistenceLayer must NEVER emit tombstone_write_completed
#          (ADR-0006 Contract 11 signal-split — that signal is GSM-owned)
#
# Purpose:
#   PersistenceLayer is an infrastructure layer with no domain knowledge.
#   `tombstone_write_completed(transition_id, latency_ms)` carries domain
#   semantic (`transition_id` is GSM-specific) — it belongs on
#   GameStateMachine, NOT PersistenceLayer. If persistence code emits it
#   directly, the domain boundary collapses and GSM can no longer own the
#   semantics of its own tombstone write cycle.
#
#   GSM subscribes to `PersistenceLayer.write_completed` and filters for
#   key == "pending_transition", then emits its OWN
#   `tombstone_write_completed(transition_id, latency_ms)` signal.
#   (See design/gdd/persistence-layer.md Rule 11 "owner split" + AC-19.)
#
# Behavior:
#   * Scans src/autoload/persistence_layer.gd for the string
#     "tombstone_write_completed".
#   * Strips inline comments before searching (awk strip — same approach as
#     check_no_await_in_persistence.sh Story 001 precedent).
#   * Exit 0 on PASS (zero matches), 1 on violation, 2 on internal error.
#
# Governing docs:
#   * ADR-0006 Contract 11 (IDB fence semantics + tombstone telemetry split)
#   * design/gdd/persistence-layer.md Rule 11 (signal surface + owner split)
#   * production/epics/persistence-layer/story-006-idb-fence-telemetry.md AC-19

set -eu

TARGET="src/autoload/persistence_layer.gd"

# AC-19 note: story references src/foundation/persistence/ but actual file is
# src/autoload/persistence_layer.gd (autoload convention). Scanning the
# specific known file is more targeted and CI-portable.
if [ ! -f "$TARGET" ]; then
	echo "::error::[check_no_tombstone_signal_in_persistence] target file not found: $TARGET" >&2
	exit 2
fi

violations=$(
	awk '
		{
			# Strip inline comments (chars after first #) before searching.
			hash_idx = index($0, "#")
			if (hash_idx > 0) {
				code = substr($0, 1, hash_idx - 1)
			} else {
				code = $0
			}
			# Match the literal string tombstone_write_completed in non-comment code.
			if (index(code, "tombstone_write_completed") > 0) {
				printf "%d:%s\n", NR, $0
			}
		}
	' "$TARGET"
) || {
	echo "::error::[check_no_tombstone_signal_in_persistence] awk failed" >&2
	exit 2
}

if [ -n "$violations" ]; then
	echo "::error file=$TARGET::Forbidden: tombstone_write_completed in PersistenceLayer"
	echo ""
	echo "PersistenceLayer is an infrastructure layer — it must not emit"
	echo "domain-semantic signals. tombstone_write_completed belongs on"
	echo "GameStateMachine (ADR-0006 Contract 11 signal-split)."
	echo ""
	echo "Fix: remove tombstone_write_completed from PersistenceLayer."
	echo "GSM subscribes to write_completed and emits its own signal."
	echo ""
	echo "Violations in $TARGET:"
	echo "$violations" | while IFS= read -r line; do echo "  $line"; done
	exit 1
fi

echo "[check_no_tombstone_signal_in_persistence] PASS — no tombstone_write_completed in $TARGET"
exit 0
