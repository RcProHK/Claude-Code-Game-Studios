# GUT (Godot Unit Test) v7.x — Installation Required

**Status**: NOT INSTALLED — placeholder directory only.

This directory is a placeholder. The actual GUT v7.x addon must be installed
manually via Godot's AssetLib OR cloned from the GUT GitHub repo.

## Why this matters

`project.godot` references this autoload-less directory. Tests under `tests/`
expect GUT classes (e.g., `GutTest`, `assert_eq`, `assert_true`) which are
unavailable until GUT is properly installed.

## Installation (Foundation chain step 3 — `/test-setup`)

### Option A — Godot AssetLib (recommended)

1. Open Godot Editor → AssetLib tab
2. Search "GUT" (by Butch Wesley / bitwes)
3. Select **GUT v7.x** (NOT v9 — project pinned to v7.x per `.claude/docs/technical-preferences.md`)
4. Install → enable as plugin in Project Settings → Plugins

### Option B — Manual clone

```bash
cd addons/
git clone --branch v7.4.1 https://github.com/bitwes/Gut.git gut
# Replace v7.4.1 with the latest v7.x patch release
```

After installation, enable in Project Settings → Plugins → check "Gut".

## Why GUT v7.x specifically (not gdunit4)

Per `.claude/docs/technical-preferences.md` line 43:
> **Framework**: GUT (Godot Unit Testing) v7.x

The previous `tests/gdunit4_runner.gd` was a stale stub referencing a different
framework — it has been replaced with `tests/gut_runner.gd` (GUT-compatible).

## Running tests

After installation:

```bash
# Headless run for CI
godot --headless --script tests/gut_runner.gd

# Interactive run from Godot Editor
# Open editor → GUT panel (bottom) → Run All Tests
```

## Next steps

Foundation chain step 3 (`/test-setup`) will:
1. Verify GUT v7.x install
2. Scaffold test directory structure
3. Wire up GitHub Actions CI workflow
4. Migrate existing `tests/unit/loot/loot_rarity_formula_test.gd` to GUT format if needed
