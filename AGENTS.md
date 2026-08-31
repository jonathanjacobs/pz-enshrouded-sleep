# Codex project handoff

This repository is the authoritative development workspace for Enshrouded Sleep. Use the current branch and canonical repository documentation as the source of truth.

## Privacy boundary

- Do not copy private assistant conversation content, conversation titles, summaries, prompts, attachments, project metadata, or inferred personal context into this repository unless the user explicitly permits the specific material.
- Do not add persona-identifying or personal information unless the user explicitly requests the specific addition.
- Translate permitted development requirements into impersonal, repository-native technical language; do not attribute them to private conversations.
- Treat this rule as applying to source, documentation, comments, commit messages, fixtures, logs, generated artifacts, and issue or pull-request text prepared from this workspace.

## Start every task here

1. Run `git status --short --branch` and preserve unrelated user changes.
2. Read `docs/DOCUMENTATION_OWNERSHIP.md` before changing documentation.
3. Use the canonical source for the subject being changed:
   - behavior: `docs/REQUIREMENTS.md`;
   - implementation: `docs/ARCHITECTURE.md` and `docs/adr/`;
   - current work and release gates: `docs/ROADMAP.md`;
   - test procedures: `docs/TESTING.md`;
   - completed evidence: `docs/VALIDATION_HISTORY.md`;
   - experimental evidence: `docs/spikes/`;
   - deployment and rollback: `docs/DEPLOYMENT.md`;
   - release packaging: `docs/RELEASE_CHECKLIST.md` and `docs/STEAM_WORKSHOP.md`.
4. Treat live Project Zomboid logs and reproducible tests as stronger evidence than remembered API behavior or prior chat assertions.

## Current development context

- `main` is the v1.0.0 Release Candidate line and includes the merged Rested / Well Rested implementation.
- `feature/sleep-benefits` is retained as development history; current behavior and remaining live-validation boundaries are tracked on `main` in `docs/ROADMAP.md`, `docs/VALIDATION_HISTORY.md`, and `docs/spikes/SPIKE-007-sleep-benefits.md`.
- The server-authoritative XP path has focused one-player dedicated-server evidence. Broader multiplayer behavior remains a live-release validation item; do not represent it as already proven.
- Before interpreting a release-candidate test, confirm the client and dedicated server run the same package. Duplicate local/Workshop copies with the same Mod ID can produce mixed Lua and sandbox-option versions.
- Keep sleep benefits independently disableable and presentation failures isolated from gameplay, clock, and awake-player-protection behavior.

## Engineering boundaries

- Target dedicated multiplayer on the validated Build 42 line; standalone single-player remains out of scope unless the roadmap changes.
- Preserve server authority for shared sleep, clock, and benefit state.
- Avoid patching Project Zomboid Java/core files for ordinary Workshop distribution.
- Do not copy third-party mod code or artwork without verified permission. Record provenance in the existing policy/licensing files.
- Keep diagnostics low-volume by default and enable verbose output only for focused evidence windows.
- Do not claim compatibility, performance, or release readiness beyond collected evidence.

## Verification expectations

- Run the repository validation workflow or its local equivalent when changing package structure, sandbox options, translations, or required Lua modules.
- For runtime changes, update the appropriate test procedure before or with the implementation and record results only after a real test occurs.
- Recheck `git diff` for accidental generated files, logs, server saves, Workshop artifacts, or private configuration before committing.
