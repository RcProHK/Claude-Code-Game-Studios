#!/usr/bin/env sh
# CI Lint: No UI subscribes to GymSysBackendClient telemetry-class signals
#          (TR — login-gymsys-connection-ui G-LS-9 / AC-25; gymsys-backend-client.md L41)
#
# Purpose (separation of concerns — UI is a presentation consumer, not a telemetry sink):
#   #2 GymSysBackendClient emits two distinct signal categories:
#     * Connection-lifecycle + workout signals — UI MAY bind the lifecycle ones
#       (auth_required / drain_started / drain_completed).
#     * TELEMETRY-CLASS signals (10) + the TEST-SEAM signal substate_changed (1) —
#       these are diagnostic/observability surfaces. ONLY the #28 Telemetry consumer
#       (src/core/networking/telemetry_router.gd or equivalent) may subscribe to the
#       telemetry-class ones, and ONLY tests/** may subscribe to substate_changed.
#   If a UI layer binds these, presentation gets coupled to internal FSM/transport
#   churn and the observability contract leaks into the view tier.
#
# Forbidden signals (11) — ground truth: design/gdd/gymsys-backend-client.md L41:
#   10 telemetry-class:
#     protocol_error, dropped_poll_tick, session_evicted_by_browser,
#     persistence_volatile, inflight_cap_breached, logout_drain_timeout,
#     tombstones_trimmed, persistence_quota_exhausted, drain_in_progress, dropped_event
#   1 test-seam:
#     substate_changed
#   NOTE: drain_started / drain_completed are LEGAL (lifecycle) and are NOT forbidden;
#   only drain_in_progress is the telemetry-class member of the drain_* family.
#
# Scope (#2 L120 scope erratum — the crux of this lint):
#   The original #2 spec scoped this check to `src/ui/**` only. But the UI-class
#   coordinators that actually do the signal wiring (#21 loot_reveal, #22 character_screen,
#   #23 inventory_ui, #24 login_shell) live in `src/autoload/*_coordinator.gd`, NOT in
#   `src/ui/**`. Scanning only `src/ui/**` is a zero-coverage false green for exactly the
#   files that subscribe to signals. This lint therefore scans BOTH:
#     * src/ui/**/*.gd
#     * src/autoload/*_coordinator.gd   (UI-class autoload coordinators)
#
# Checks:
#   A. Ban-list (AC-25): no forbidden signal is `.connect(`-ed anywhere in scope.
#   B. #24 whitelist tripwire (robustness — default-deny on login_shell_coordinator.gd):
#      every `.connect(` signal token on the #24 coordinator must be a known-legit
#      signal. Catches a future telemetry binding on #24 even if it is somehow not in
#      the ban-list. GSM state_changed is bound via connect_for_initial_state (cfis),
#      which is NOT a `.connect(` and is naturally excluded from this scan.
#
# Exit: 0 PASS, 1 violation, 2 internal error (project CI lint convention).
#
# Governing docs: design/gdd/gymsys-backend-client.md (Rule 5, L41); design/gdd/
#   login-gymsys-connection-ui.md (Rule 2, AC-25, G-LS-9).

set -eu

if [ ! -d "src" ]; then
	echo "::error::[check_no_ui_subscribes_telemetry] src/ directory not found" >&2
	exit 2
fi

LOGIN_FILE="src/autoload/login_shell_coordinator.gd"

# 11 forbidden signal names (10 telemetry-class + 1 test-seam), alternation-joined.
FORBIDDEN='protocol_error|dropped_poll_tick|session_evicted_by_browser|persistence_volatile|inflight_cap_breached|logout_drain_timeout|tombstones_trimmed|persistence_quota_exhausted|drain_in_progress|dropped_event|substate_changed'

status=0

# --- Check A: ban-list across UI scope --------------------------------------
# Two binding forms are matched:
#   1. Godot 4 signal-object form:  <obj>.SIGNAL.connect(
#   2. Godot 3 / defensive string form:  <obj>.connect("SIGNAL"  or  .connect('SIGNAL'
# A leading boundary (^|[^A-Za-z0-9_]) prevents matching a longer identifier that
# merely ends in a forbidden name (e.g. my_dropped_event).
# rg exit codes: 0 match, 1 no-match (PASS), 2+ real error — distinguished so a bad
# regex / IO error is never silently swallowed as "clean" (lint_allowlist_adr_sync:
# check the exit code, do not grep for the word FAIL).
set +e
violations=$(
	rg -n -g 'src/ui/**/*.gd' -g 'src/autoload/*_coordinator.gd' \
		-e "(^|[^A-Za-z0-9_])($FORBIDDEN)\.connect\(" \
		-e "\.connect\([[:space:]]*[\"']($FORBIDDEN)[\"']" \
		src/
)
rc=$?
set -e
if [ "$rc" -gt 1 ]; then
	echo "::error::[check_no_ui_subscribes_telemetry] rg failed (exit $rc) scanning UI scope" >&2
	exit 2
fi

if [ -n "$violations" ]; then
	echo "::error::UI layer subscribes to a forbidden telemetry-class / test-seam signal (AC-25)"
	echo ""
	echo "These signals are observability-only. UI (src/ui/** + src/autoload/*_coordinator.gd)"
	echo "MUST NOT .connect( any of: $FORBIDDEN"
	echo "Route them to the #28 Telemetry consumer (telemetry_router.gd); substate_changed"
	echo "is tests-only. Offending references:"
	echo "$violations" | while IFS= read -r line; do
		echo "  $line"
	done
	status=1
fi

# --- Check B: #24 login_shell_coordinator .connect( whitelist (default-deny) -
# Allowed signal tokens on the #24 coordinator:
#   3 lifecycle (from #2, the telemetry-source class): auth_required, drain_started,
#     drain_completed
#   4 error-consumer (Rule 5 — NOT #2 telemetry; from #3/#8/#11/#12 persistence/save):
#     critical_save_failed, streak_persistence_failed, stat_critical_save_failed,
#     ability_unlock_save_failed
#   2 added 2026-06-13 (GymSys Option B login, story 015):
#     logged_in  — #2 Option-B auth-lifecycle signal (same class as auth_required; NOT
#                  telemetry — reflects login() success into the shell via notify_claim_succeeded)
#     submitted  — the LoginForm's own submit signal (UI-internal: the form telling #24 the
#                  user pressed 登入 → submit_login; definitely not a telemetry surface)
# GSM state_changed is bound via connect_for_initial_state (not .connect) → excluded.
if [ -f "$LOGIN_FILE" ]; then
	ALLOWED=" auth_required drain_started drain_completed critical_save_failed streak_persistence_failed stat_critical_save_failed ability_unlock_save_failed logged_in submitted "

	set +e
	tokens=$(
		rg -o --no-filename --no-line-number -r '$1' \
			'([A-Za-z_][A-Za-z0-9_]*)\.connect\(' \
			"$LOGIN_FILE"
	)
	trc=$?
	set -e
	if [ "$trc" -gt 1 ]; then
		echo "::error::[check_no_ui_subscribes_telemetry] rg failed (exit $trc) scanning $LOGIN_FILE" >&2
		exit 2
	fi

	# `$tokens` holds only [A-Za-z0-9_] identifiers, so unquoted word-splitting is
	# safe and keeps the loop in the main shell (no subshell → status persists).
	for tok in $tokens; do
		case "$ALLOWED" in
			*" $tok "*) : ;;  # known-legit
			*)
				echo "::error file=$LOGIN_FILE::Non-whitelisted .connect( signal on #24 coordinator: '$tok' (AC-25 default-deny)"
				echo "  login_shell_coordinator.gd may only .connect( these signals:"
				echo "  $ALLOWED"
				echo "  If '$tok' is a new legitimate consumer, add it to the ALLOWED set here"
				echo "  AND confirm it is not a telemetry-class signal."
				status=1
				;;
		esac
	done
fi

if [ "$status" -eq 0 ]; then
	echo "[check_no_ui_subscribes_telemetry] PASS — no UI telemetry subscriptions; #24 connects within whitelist"
fi
exit "$status"
