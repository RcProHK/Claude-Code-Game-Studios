# Claude Code Game Studios -- Game Studio Agent Architecture

Indie game development managed through 49 coordinated Claude Code subagents.
Each agent owns a specific domain, enforcing separation of concerns and quality.

## Communication Language (MANDATORY)

**All user-facing responses MUST be written in 廣東話 / 繁體中文 (Cantonese / Traditional Chinese).**

This rule applies to:
- The main Claude session
- ALL spawned subagents (every agent in `.claude/agents/`)
- ALL skills (every skill in `.claude/skills/`)
- ALL Task tool invocations
- AskUserQuestion prompts and option labels
- Tool call status updates and end-of-turn summaries

**Exceptions (keep in English):**
- Technical terms: GDD, ADR, API, SSE, signal, node, scene, etc.
- File paths, skill names, agent names, command names
- Code identifiers (variable names, function names, class names)
- Code blocks and shell commands
- Frontmatter keys and YAML field names

**Document content** (GDDs, ADRs, design docs, code comments): 混用中文 + 英文 tech term — 跟 user 既有 production system（GymSys、studiosys）風格。

**Reason**: User 母語廣東話，呢個 project 全程用中文溝通。違反呢條 rule 等於忽略 user 嘅明確指示。

## Technology Stack

- **Engine**: Godot 4.6
- **Language**: GDScript
- **Version Control**: Git with trunk-based development
- **Build System**: SCons (engine), Godot Export Templates
- **Asset Pipeline**: Godot Import System + custom resource pipeline

> **Note**: Engine-specialist agents exist for Godot, Unity, and Unreal with
> dedicated sub-specialists. Use the set matching your engine.

## Project Structure

@.claude/docs/directory-structure.md

## Engine Version Reference

@docs/engine-reference/godot/VERSION.md

## Technical Preferences

@.claude/docs/technical-preferences.md

## Coordination Rules

@.claude/docs/coordination-rules.md

## Collaboration Protocol

**User-driven collaboration, not autonomous execution.**
Every task follows: **Question -> Options -> Decision -> Draft -> Approval**

- Agents MUST ask "May I write this to [filepath]?" before using Write/Edit tools
- Agents MUST show drafts or summaries before requesting approval
- Multi-file changes require explicit approval for the full changeset
- No commits without user instruction

See `docs/COLLABORATIVE-DESIGN-PRINCIPLE.md` for full protocol and examples.

> **First session?** If the project has no engine configured and no game concept,
> run `/start` to begin the guided onboarding flow.

## Coding Standards

@.claude/docs/coding-standards.md

## Context Management

@.claude/docs/context-management.md
