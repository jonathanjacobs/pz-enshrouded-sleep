# Agent project handoff

## Relationship to pz-mod-template

This mod was created from [pz-mod-template](https://github.com/jonathanjacobs/pz-mod-template); "Template version" under Project facts records the template release its files match. To take a later template release, read the `Upgrading` notes for each newer version in the template's `CHANGELOG.md`, apply the ones that fit this mod, and update the recorded version. Do not add a template file only to match the template's layout. When work here turns up a problem or lesson that would apply to any mod built from the template, open an issue on the template repository with the evidence (what happened, and the commit, log excerpt, or test that shows it), written in general terms and without this mod's private details.

## Privacy boundary

- Do not copy private assistant conversation content, titles, summaries, prompts, attachments, project metadata, inferred personal context, logs, or private game/server data into this repository without explicit permission.
- Do not add persona-identifying or personal information without an explicit request.
- Translate permitted requirements into impersonal, repository-native technical language.
- Apply this rule to source, docs, comments, commit messages, fixtures, logs, generated artifacts, and issue or pull-request text.
- Never write server IP addresses or host names, Steam IDs, other players' names, server, admin, or RCON passwords, SFTP credentials, or tokens into any of those places. Describe a test environment by its kind, such as "a rented dedicated server, 3 players", and replace private values in quoted log lines with placeholders such as `<server-ip>`. Summaries of test sessions are where these details most often slip in. `docs/PRIVATE_DATA.md` has the full list, the automated check, and the steps to take if something reaches GitHub.

## Start every task here

1. Run `git status --short --branch` and preserve unrelated user changes.
2. Read `docs/DOCUMENTATION_OWNERSHIP.md` before changing documentation.
3. Use the canonical document for the subject being changed:
   - behavior: the Requirements section of `docs/DESIGN.md`;
   - implementation: the Architecture section of `docs/DESIGN.md`, and `docs/adr/`;
   - planned work and milestones: `docs/ROADMAP.md`;
   - test procedure: `docs/TESTING.md`;
   - completed evidence: `docs/VALIDATION_HISTORY.md`;
   - experiments: `docs/spikes/`;
   - installation and configuration reference: `README.md`;
   - release checklist: `docs/RELEASING.md`;
   - Workshop publication: `docs/RELEASING.md`, with public text in `docs/workshop-description.bbcode`;
   - rollback: `docs/RELEASING.md`;
   - asset and third-party provenance: `CREDITS.md`;
   - private details kept out of the repository, and leak response: `docs/PRIVATE_DATA.md`;
   - external reference links: `docs/RESEARCH_LINKS.md`;
   - names that saves, server settings, or other mods depend on: Compatibility contracts in `docs/DESIGN.md`.
4. Treat reproducible tests and live Project Zomboid logs as stronger evidence than remembered API behavior or prior chat assertions. A description of what a change should do, including your own summary of code you just wrote, is not evidence that it does. Before interpreting any test or log, confirm the client and server ran the same package (see the build-stamp convention in `docs/DESIGN.md`); duplicate local and Workshop copies with the same Mod ID can load mixed Lua and sandbox-option versions.

## Project facts — complete before implementation

- Mod name: Enshrouded Sleep
- Mod ID: `pz-enshrouded-sleep`
- Steam Workshop ID: `3786842301`
- Supported Project Zomboid build: Build 42; `versionMin=42.20.0`, validated on 42.21.0 (`4a0e9546ec`)
- Primary multiplayer target: dedicated server only
- Current development branch/release state: `main` is the v1.0.x stable line. The v1.0.1 release decision is GO and its Workshop upload is pending; v1.0.0 is the version live on the Workshop.
- Template version: `v0.9.0` (the pz-mod-template release this repository's files match; update it after applying a template upgrade)

## Current development context

Keep this section short and current. Record what an agent starting cold must know that the code does not show: which branches are live and what each is for, which behavior has evidence and which does not yet, and any environment trap that has already produced a misleading result. Do not represent unproven behavior as proven here.

- `main` is the v1.0.x stable release line and includes the merged Rested / Well Rested implementation.
- `main` is the only long-lived branch. The merged `feature/sleep-benefits` branch has been deleted; its commits remain in `main`'s history. Current behavior and remaining live-validation boundaries are tracked on `main` in `docs/ROADMAP.md`, `docs/VALIDATION_HISTORY.md`, and `docs/spikes/SPIKE-007-sleep-benefits.md`.
- The server-authoritative XP path has focused one-player dedicated-server evidence. Broader multiplayer behavior remains a live-release validation item; do not represent it as already proven.
- Before interpreting a test, confirm the client and dedicated server run the same package. Duplicate local/Workshop copies with the same Mod ID can produce mixed Lua and sandbox-option versions.
- On a case-insensitive file system (Windows, default macOS), a root-level ignore pattern such as `Server/` also matches `42/media/lua/server/` unless it is anchored with a leading `/`. Check `git check-ignore -v` before assuming a new server Lua file is tracked. This repository's `.gitignore` is already anchored; the template's is not yet (see jonathanjacobs/pz-mod-template#2).
- Package gaps found when restructuring to pz-mod-template v0.9.0, left for a later release with its own test: (1) the root `mod.info` has `pzversion=42` and lacks the `category=` and `versionMin=` values that `42/mod.info` carries, where the template expects both files to carry the same values; (2) the build version is written as a literal in several runtime Lua files rather than defined once in a shared version module (see "Build stamp and version handshake" in `docs/DESIGN.md`).

## Engineering boundaries

- Target only the Project Zomboid build(s) recorded in `VERSION`, `README.md`, and the canonical project docs.
- Target dedicated multiplayer on the validated Build 42 line; standalone single-player remains out of scope unless the roadmap changes.
- Preserve server authority for shared multiplayer state, including sleep, clock, and benefit state; explicitly document any client-only behavior.
- Keep sleep benefits independently disableable, and keep presentation failures isolated from gameplay, clock, and awake-player-protection behavior.
- Treat compatibility contracts as fixed: the Mod ID, sandbox option names and defaults, ModData keys and the layout of saved data, client/server command module and command names, item and other script full type names, and Lua module paths other mods may `require`. The Compatibility contracts section of `docs/DESIGN.md` lists this mod's; a name of one of those kinds is a contract even before it is listed. Do not rename, remove, or change the meaning or default of one unless the task explicitly asks for it. When a task does, update that list, record what server operators and players must do in an `Upgrading` subsection of `CHANGELOG.md`, and choose the version number as `docs/RELEASING.md` describes.
- Keep file moves and renames in separate commits from behavior changes, so each can be reviewed and reverted on its own. Moving a Lua file changes its `require` path, which can itself break a contract.
- Avoid patching Project Zomboid Java/core files for ordinary Workshop distribution.
- Do not copy third-party mod code or artwork without verified permission. Record any permitted material, and the origin of every distributed asset, in `CREDITS.md` before distribution.
- Keep the pz-mod-template attribution block in `NOTICE`. Add this project's own name and copyright above it; do not remove or reword it, because Apache 2.0 requires it in every redistribution.
- Keep diagnostics off or low-volume by default; enable verbose logging only for focused evidence windows.
- Do not claim compatibility, performance, or release readiness beyond collected evidence.
- Keep the deployable mod tree under `Contents/mods/<mod-id>/`; do not package source-control metadata, saves, logs, private configuration, decompiled source, or extracted game assets.
- Write in American English (`behavior`, `authorize`, `neighbor`, `judgment`) in documentation, code comments, commit messages, and GitHub issues and issue comments. This does not extend to code: engine API names are spelled as Project Zomboid defines them, and several are British (`initialise()` on `ISUIElement`, for example). Never apply a spelling change to source files by blanket search and replace — a sweep that does exactly that can rename call sites and break working code. Correct spelling in prose by hand, and leave identifiers alone.
- Never hard-wrap markdown paragraphs. Write each paragraph as one unwrapped line and let the renderer wrap it. This applies to repository documents, GitHub issue bodies, issue comments, and pull request descriptions — GitHub renders those with hard line breaks enabled, so a newline inside a paragraph becomes a literal forced break when the window is resized. Fenced code blocks and table rows keep their own line structure.
- Track open defects and design questions as GitHub Issues once the repository has an issue tracker in use; cross-reference by issue number in `CHANGELOG.md`, `docs/ROADMAP.md`, and `docs/VALIDATION_HISTORY.md` entries so history stays navigable.

## Verification expectations

- When package structure, `mod.info`, sandbox options, translations, version strings, or required Lua modules change, run `bash tools/validate-package.sh` (the same check CI runs) before claiming success. When a regression is fixed, consider adding a guard for it to that script.
- When Lua changes, run `bash tools/check-lua-syntax.sh`. Without a Lua 5.1 compiler installed it reports the check as skipped; say so rather than claiming the syntax was checked, and rely on the CI job of the same name.
- Before committing, run `bash tools/check-sensitive-content.sh staged` unless the pre-commit hook is already on (`git config core.hooksPath` prints `.githooks`).
- When reporting work, name each check as passed, failed, or skipped, including checks a script skipped on its own and in-game tests that were not run. State a skipped or inconclusive check as plainly as a passed one; it is never a pass.
- Keep `VERSION`, the `modversion=` line in every `mod.info`, and any version reference in `README.md` aligned on every bump. Grep the repository for the previous version string rather than relying on memory of "the usual few spots" — a check that only covers some of the locations will eventually miss one and let them drift.
- If `tools/` has test-cycle scripts (see "Local files and automation" in `docs/TESTING.md`), use them for the mod-deploy and log-capture steps around a test run rather than repeating them by hand. Test logs, decompiled source, and research material live in local folders outside the repository; read them only where the user has granted access, and never copy them in.
- Keep the README files that index a folder current, in the same commit as the change. When a file or folder is added, removed, or renamed, update the README that lists it: `docs/README.md` for documents in `docs/`, `tools/README.md` for scripts, `.github/workflows/README.md` for workflows and job names, `.githooks/README.md` for hooks, `.claude/README.md` for Claude Code commands, the index tables in `docs/adr/README.md` and `docs/spikes/README.md` for each ADR and spike and its status, and the repository map in the root `README.md` where there is one. Give a new folder with more than one file a short README saying what it holds. `bash tools/validate-package.sh` warns when a file or folder in `docs/` is missing from `docs/README.md`, or when that index links to something that no longer exists.
- For runtime changes, update `docs/TESTING.md` before or with the implementation; add an entry to `docs/VALIDATION_HISTORY.md` only after a real test occurs.
- Use a spike document for bounded uncertainty or feasibility research. Promote conclusions into the requirements or architecture in `docs/DESIGN.md`, or into an ADR, only after evidence supports them.
- Recheck `git diff` for generated files, logs, server saves, Workshop artifacts, private configuration, and accidental Project Zomboid/third-party assets before committing.
