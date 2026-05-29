# Tech Debt Register

> Tracked advisory deviations from story close-outs. See `/tech-debt` for full analysis.

---

- **2026-05-29** (Story 003 — Atomic Flush): **`Object.set(DIRTY_VAR_NAME)` test seam** — tests access `_dirty` via reflection `PersistenceLayer.set(&"_dirty", false)`. Add `_test_force_clean()` debug helper in Story 005 (test spy) to eliminate string-name coupling. Effort: S. — tracked from `production/epics/persistence-layer/story-003-atomic-flush-path.md`

- **2026-05-29** (Story 003 — Atomic Flush): **Debounce coalescing not tested** — AC-04b uses `flush=true` (synchronous) instead of real timer fire to prove atomic single-blob pattern. Add `test_debounce_coalesces_writes` integration test (inject fake clock or use `await get_tree().create_timer()`) in Story 006 or integration pass. Effort: S. — tracked from `production/epics/persistence-layer/story-003-atomic-flush-path.md`

- **2026-05-29** (Story 002 — In-Memory Cache): **AC-02 FileAccess spy probe missing** — "zero file I/O" claim proved via implementation code path, not via observable FileAccess.open() call counter. Add MockFileFactory-based spy assertion in Story 003 when IFileFactory is wired into PersistenceLayer. Effort: S. — tracked from `production/epics/persistence-layer/story-002-in-memory-cache.md`

- **2026-05-29** (Story 002 — In-Memory Cache): **`_cache` accessed via reflection in tests** — `PersistenceLayer.get(&"_cache").clear()` in before_each() is a reflection hack. Introduce `_clear_cache_for_testing()` debug helper in Story 005 (test spy contract) when the test infrastructure layer is solidified. Effort: S. — tracked from `production/epics/persistence-layer/story-002-in-memory-cache.md`

- **2026-05-29** (Story 001 — Sync Interface No-Await CI): **EC-4 string literal false-positive** — `check_no_await_in_persistence.sh` awk script would false-positive on `"await"` inside GDScript string literals (e.g., `push_error("no await allowed")`). Acceptable for stub-only file at VS tier; requires token-aware parser or quote-aware grep when full implementation lands. Effort: S. — tracked from `production/epics/persistence-layer/story-001-sync-interface-no-await.md`

- **2026-05-29** (Story 001 — Sync Interface No-Await CI): **Missing positive control test** — `tools/ci/check_no_await_in_persistence.sh` has no automated test that injects a real `await` statement and verifies the script returns exit 1 (guards against CI script always returning PASS). Effort: S. — tracked from `production/epics/persistence-layer/story-001-sync-interface-no-await.md`
