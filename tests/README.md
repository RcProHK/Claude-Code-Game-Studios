# Test Infrastructure

**Engine**: Godot 4.6
**Test Framework**: GUT (Godot Unit Testing) v7.x
**CI**: `.github/workflows/tests.yml`
**Setup date**: 2026-05-28 (originally scaffolded for GdUnit4; migrated to GUT v7.x per `.claude/docs/technical-preferences.md` line 43)

## Directory Layout

```
tests/
  unit/           # Isolated unit tests (formulas, state machines, logic)
  integration/    # Cross-system and save/load tests
  smoke/          # Critical path test list for /smoke-check gate
  evidence/       # Screenshot logs and manual test sign-off records
  gut_runner.gd       # GUT v7.x headless CI runner
  gdunit4_runner.gd   # DEPRECATED — pending deletion (see file for details)
```

## Installing GUT v7.x

Manual install required — see `addons/gut/README.md` for full instructions.

```
Option A — Godot AssetLib:
  1. Open Godot → AssetLib → search "GUT" (by bitwes)
  2. Select GUT v7.x (NOT v9 — project pinned to v7.x)
  3. Download & Install
  4. Enable: Project → Project Settings → Plugins → Gut ✓

Option B — Manual clone:
  cd addons/
  git clone --branch v7.4.1 https://github.com/bitwes/Gut.git gut
```

Verify install: `res://addons/gut/gut_cmdln.gd` exists.

## Running Tests

```bash
# Headless (CI / command line)
godot --headless --script tests/gut_runner.gd

# Or direct GUT CLI (post-install):
godot --headless -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit,res://tests/integration -gexit

# In-editor
# Open editor → GUT panel (bottom) → Run All Tests
```

## Test Naming

- **Files**: `[system]_[feature]_test.gd`
- **Functions**: `test_[scenario]_[expected]()`
- **Example**: `combat_damage_test.gd` → `test_base_attack_returns_expected_damage()`
- **Base class**: `extends GutTest`

## GUT v7.x Assertion Reference

```gdscript
extends GutTest

func test_example() -> void:
    assert_eq(actual, expected)              # equality (==)
    assert_ne(actual, unexpected)            # inequality (!=)
    assert_true(condition)                   # truthy
    assert_false(condition)                  # falsy
    assert_lt(value, max)                    # less than (<)
    assert_lte(value, max)                   # less than or equal (<=)
    assert_gt(value, min)                    # greater than (>)
    assert_gte(value, min)                   # greater than or equal (>=)
    assert_almost_eq(value, expected, err)   # float tolerance
    assert_null(value) / assert_not_null(value)
    assert_has(collection, element)
    assert_does_not_have(collection, element)
```

## Story Type → Test Evidence

| Story Type | Required Evidence | Location | Gate |
|---|---|---|---|
| Logic | Automated unit test — must pass | `tests/unit/[system]/` | BLOCKING |
| Integration | Integration test OR playtest doc | `tests/integration/[system]/` | BLOCKING |
| Visual/Feel | Screenshot + lead sign-off | `tests/evidence/` | ADVISORY |
| UI | Manual walkthrough OR interaction test | `tests/evidence/` | ADVISORY |
| Config/Data | Smoke check pass | `production/qa/smoke-*.md` | ADVISORY |

## CI

Tests run automatically on every push to `main` and on every pull request.
A failed test suite blocks merging — never skip or disable failing tests.
Fix the underlying issue instead.

CI workflow installs GUT v7.x via `git clone --branch v7.4.1` if `addons/gut/`
is not committed to the repository. Once user commits GUT addon to repo, CI
will use the committed version.
