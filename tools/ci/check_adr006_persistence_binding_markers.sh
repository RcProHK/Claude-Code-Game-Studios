#!/usr/bin/env sh
# Gate: ADR-006 binding markers present in PersistenceLayer + 6 test files exist
# Story 015 AC-32 — runs AFTER all 15 persistence-layer stories complete
# Exit 0 on PASS, 1 on any failure.
set -eu

SOURCE="src/autoload/persistence_layer.gd"
FAIL=0

if [ ! -f "$SOURCE" ]; then
	echo "::error::Source file not found: $SOURCE"
	exit 2
fi

# Check 6 binding markers
for marker in \
	"# ADR-006 Contract 3: SerializableResource envelope" \
	"# ADR-006 Contract 4: autoload position 1 + sync _ready" \
	"# ADR-006 Contract 9: clock-drift TTL" \
	"# ADR-006 Contract 10: migration chain bounded" \
	"# ADR-006 Contract 11: best-effort IDB fence" \
	"# ADR-006 Contract 14: test spy interface"; do
	if ! rg --quiet --fixed-strings "$marker" "$SOURCE" 2>/dev/null; then
		echo "::error::MISSING MARKER: $marker"
		FAIL=1
	else
		echo "  OK: $marker"
	fi
done

# Check 6 test files exist
for test_file in \
	"tests/unit/persistence-layer/test_adr006_c3_serializable_envelope.gd" \
	"tests/unit/persistence-layer/test_adr006_c4_autoload_sync.gd" \
	"tests/unit/persistence-layer/test_adr006_c9_clock_drift_ttl.gd" \
	"tests/integration/persistence-layer/test_adr006_c10_migration_chain.gd" \
	"tests/unit/persistence-layer/test_adr006_c11_idb_fence.gd" \
	"tests/unit/persistence-layer/test_adr006_c14_test_spy.gd"; do
	if [ ! -f "$test_file" ]; then
		echo "::error::MISSING TEST FILE: $test_file"
		FAIL=1
	else
		echo "  OK: $test_file"
	fi
done

if [ $FAIL -eq 0 ]; then
	echo "[check_adr006_persistence_binding_markers] PASS — all 6 markers + 6 test files verified"
fi
exit $FAIL
