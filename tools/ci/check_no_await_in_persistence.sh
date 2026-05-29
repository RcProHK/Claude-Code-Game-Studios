#!/usr/bin/env sh
# CI Lint: No `await` in PersistenceLayer (ADR-0006 Contract 4)
#
# Purpose:
#   PersistenceLayer is autoload position 1. Other autoloads (pos 2+) call
#   `read()` synchronously from their `_ready()`. A single `await` in
#   persistence_layer.gd suspends `_ready()` mid-boot and lets pos 2+ run
#   against a half-initialized PersistenceLayer — boot crash or silent save
#   corruption.
#
# Behavior:
#   * Scans src/autoload/persistence_layer.gd
#   * Flags any non-comment line containing an `await` expression
#   * Exit 0 on PASS, 1 on violation, 2 on internal error (matches the
#     project-wide CI lint exit convention used by tools/ci/*.gd).
#
# False positives we explicitly handle:
#   * Full-line comments (line starts with optional whitespace then `#`)
#   * Inline comments where `#` appears before `await` on the same line
#   * String literals containing the word "await" (rare — flagged only if
#     they look like statements; reviewer can ack with a noqa-style comment)
#
# Forbidden alternatives:
#   * Do NOT special-case via inline `# noqa` markers — escalate instead.
#     The whole point of this lint is that there is no safe `await` here.
#
# Governing docs:
#   * ADR-0006 (State Machine Contract, Contract 4: Autoload Sequential Boot)
#   * design/gdd/persistence-layer.md
#   * src/autoload/persistence_layer.gd (file header)

set -eu

TARGET="src/autoload/persistence_layer.gd"

if [ ! -f "$TARGET" ]; then
	echo "::error::[check_no_await_in_persistence] target file not found: $TARGET" >&2
	exit 2
fi

# Strategy:
#   1. Strip inline comments: for each line, keep only the part before the
#      first `#`. This collapses both full-line comments (becomes empty) and
#      inline `# ...` comments (drops the trailing portion).
#   2. Search the stripped text for `await` as a whole word.
#   3. Map matches back to the original line numbers for diagnostic output.
#
# We use awk (POSIX) for the stripping + matching so we avoid bash-isms.

violations=$(
	awk '
		{
			original = $0
			# Drop inline comments: keep only the prefix before the first `#`.
			# This is an approximation — it does not parse string literals — but
			# GDScript style here forbids embedding `#` inside strings on this
			# file, and the lint errs on the side of false positives (safer).
			hash_idx = index($0, "#")
			if (hash_idx > 0) {
				code = substr($0, 1, hash_idx - 1)
			} else {
				code = $0
			}
			# Match `await` as a whole word: must be preceded by start-of-line
			# or non-identifier char, and followed by non-identifier char.
			if (match(code, /(^|[^A-Za-z0-9_])await([^A-Za-z0-9_]|$)/)) {
				printf("%d:%s\n", NR, original)
			}
		}
	' "$TARGET"
) || {
	echo "::error::[check_no_await_in_persistence] awk failed while scanning $TARGET" >&2
	exit 2
}

if [ -n "$violations" ]; then
	echo "::error file=$TARGET::Forbidden \`await\` in PersistenceLayer (ADR-0006 Contract 4)"
	echo ""
	echo "PersistenceLayer is autoload position 1 — its _ready() must remain"
	echo "synchronous. Adding \`await\` here breaks the sequential boot chain"
	echo "and causes downstream autoloads to run against half-initialized"
	echo "PersistenceLayer state."
	echo ""
	echo "Violations in $TARGET:"
	echo "$violations" | while IFS= read -r line; do
		echo "  line $line"
	done
	echo ""
	echo "See src/autoload/persistence_layer.gd file header for allowed"
	echo "alternatives (synchronous FileAccess, call_deferred, post-boot signals)."
	exit 1
fi

echo "[check_no_await_in_persistence] PASS — no \`await\` found in $TARGET"
exit 0
