#!/usr/bin/env sh
# CI Lint: no PersistenceLayer.write() calls inside write_completed handlers
#          (AC-29 — prevents recursive write re-entrance)
#
# If a consumer connects to `write_completed` and calls `PersistenceLayer.write()`
# from within the handler, every write triggers another write → infinite recursion.
# This lint catches the static pattern.
#
# Exit 0 on PASS, 1 on violation, 2 on internal error.
set -eu

violations=$(
	rg --glob "*.gd" --no-filename "\bPersistenceLayer\.write\b" src/ 2>/dev/null | awk '
		{
			hash_idx = index($0, "#")
			if (hash_idx > 0) { code = substr($0, 1, hash_idx - 1) }
			else { code = $0 }
			if (match(code, /PersistenceLayer\.write[[:space:]]*(/) ) {
				printf "%s\n", $0
			}
		}
	' || true
)

if [ -n "$violations" ]; then
	echo "::error::Potential PersistenceLayer.write() re-entrance found in src/"
	echo "$violations"
	exit 1
fi

echo "[check_no_write_reentrance] PASS — no PersistenceLayer.write() re-entrance patterns found"
exit 0
