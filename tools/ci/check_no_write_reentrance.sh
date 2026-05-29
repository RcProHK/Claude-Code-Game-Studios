#!/usr/bin/env sh
# CI Lint: no PersistenceLayer.write() calls inside `write_completed` handlers
#          (AC-29 — prevents recursive write re-entrance)
#
# If a consumer connects a handler to `write_completed` and that handler calls
# `.write()` / `PersistenceLayer.write()`, every write fires another write →
# infinite recursion. This lint scans ONLY the bodies of handlers connected to
# `write_completed` in src/ (NOT every write call — legitimate writers such as
# GameStateMachine persisting its transition counter are not re-entrance).
#
# AC-29: "GIVEN static analyzer scans handlers connected to write_completed,
#         THEN zero handlers contain PersistenceLayer.write( literal pattern."
#
# Scope: src/ only (tests/ may connect for instrumentation — not production).
# Handler forms recognised at a `write_completed.connect(...)` site:
#   - named method:   write_completed.connect(_on_write_done)
#   - Callable:       write_completed.connect(Callable(self, "_on_write_done"))
#   - self.method:    write_completed.connect(self._on_write_done)
#   - inline lambda:  write_completed.connect(func(...): ... )  (body scanned in-place)
#
# Exit 0 on PASS, 1 on violation, 2 on internal error.
set -eu

if ! command -v rg >/dev/null 2>&1; then
	echo "::error::[check_no_write_reentrance] rg (ripgrep) not found on PATH" >&2
	exit 2
fi

if [ ! -d src ]; then
	echo "::error::[check_no_write_reentrance] src/ directory not found (run from repo root)" >&2
	exit 2
fi

# Collect src .gd files (null-safe). No files == trivially clean.
files=$(rg --glob "*.gd" --files src/ 2>/dev/null || true)
if [ -z "$files" ]; then
	echo "[check_no_write_reentrance] PASS — no .gd files under src/"
	exit 0
fi

violations=$(
	printf '%s\n' "$files" | tr '\n' '\0' | xargs -0 -r awk '
		# --- helpers -------------------------------------------------------
		# strip a trailing line comment (naive: first unquoted-ish #). Good
		# enough for catching commented-out .write( calls.
		function strip_comment(s,   h) {
			h = index(s, "#")
			if (h > 0) return substr(s, 1, h - 1)
			return s
		}
		function indent_of(s,   i, c) {
			i = 0
			while (i < length(s)) {
				c = substr(s, i + 1, 1)
				if (c == " " || c == "\t") i++; else break
			}
			return i
		}
		function has_write_call(s) {
			# matches  .write(  or  PersistenceLayer.write(  with optional ws
			return (s ~ /\.write[[:space:]]*\(/)
		}

		# --- per-file processing ------------------------------------------
		# We buffer each file fully, then analyse, so handler funcs defined
		# before OR after the connect site are both found.
		FNR == 1 && NR > 1 { analyse() }   # flush previous file
		{ line[FNR] = $0; nlines = FNR; fname = FILENAME }
		END { analyse() }

		function analyse(   i, n, code, ind, j, jind, hname, body, watch, k,
		                    lam_ind, in_lam, found, msg) {
			n = nlines
			delete watch          # watch[handler_name] = connect-site lineno
			# Pass 1: find write_completed.connect(...) sites
			for (i = 1; i <= n; i++) {
				code = strip_comment(line[i])
				if (code !~ /write_completed[[:space:]]*\.[[:space:]]*connect[[:space:]]*\(/) continue

				# ---- inline lambda? scan the lambda body in place ----
				if (code ~ /connect[[:space:]]*\([[:space:]]*func/) {
					# single-line lambda: check the connect line itself
					if (has_write_call(substr(code, index(code, "func")))) {
						report(fname, i, "inline lambda")
						continue
					}
					# multi-line lambda: body is indented deeper than the
					# connect statement; scan until indentation drops back.
					lam_ind = indent_of(line[i])
					for (j = i + 1; j <= n; j++) {
						if (line[j] ~ /^[[:space:]]*$/) continue
						jind = indent_of(line[j])
						if (jind <= lam_ind) break
						if (has_write_call(strip_comment(line[j]))) {
							report(fname, j, "inline lambda body")
							break
						}
					}
					continue
				}

				# ---- named handler: extract identifier ----
				hname = code
				sub(/.*connect[[:space:]]*\([[:space:]]*/, "", hname)
				# Callable(self, "name")  or  Callable(self,"name")
				if (hname ~ /Callable/) {
					if (match(hname, /"[A-Za-z_][A-Za-z0-9_]*"/)) {
						hname = substr(hname, RSTART + 1, RLENGTH - 2)
					} else { continue }
				} else {
					# self._on_x  ->  _on_x ;  trim at first non-ident char
					sub(/^self[[:space:]]*\.[[:space:]]*/, "", hname)
					if (match(hname, /^[A-Za-z_][A-Za-z0-9_]*/)) {
						hname = substr(hname, RSTART, RLENGTH)
					} else { continue }
				}
				if (hname != "") watch[hname] = i
			}

			# Pass 2: scan body of each watched named handler
			for (k in watch) {
				for (i = 1; i <= n; i++) {
					code = line[i]
					# top-level func definition (column 0)
					if (code ~ ("^func[[:space:]]+" k "[[:space:]]*\\(")) {
						# body = until next top-level func or EOF
						for (j = i + 1; j <= n; j++) {
							if (line[j] ~ /^func[[:space:]]/) break
							if (has_write_call(strip_comment(line[j]))) {
								report(fname, j, "handler " k " (connected at line " watch[k] ")")
								break
							}
						}
						break
					}
				}
			}
		}
		function report(f, ln, what) {
			printf "%s:%d: write() call inside write_completed %s\n", f, ln, what
		}
	'
)

if [ -n "$violations" ]; then
	echo "::error::PersistenceLayer.write() re-entrance found inside write_completed handler(s) in src/"
	echo "$violations"
	exit 1
fi

echo "[check_no_write_reentrance] PASS — no .write() re-entrance inside write_completed handlers in src/"
exit 0
