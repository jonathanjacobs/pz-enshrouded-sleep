# Shared tools

Add a tool here only when it is genuinely reusable across this repository. Document its prerequisites, inputs, outputs, and how to run it. Do not add generated release output to this directory.

## `validate-package.sh`

Checks the deployable package and the public text that describes it. CI runs it on every push and pull request to `main` as the `validate-package` job in [`../.github/workflows/validate-package.yml`](../.github/workflows/validate-package.yml); run it locally before committing a version bump, package-structure change, sandbox option, or translation.

```bash
bash tools/validate-package.sh
```

Prerequisites: bash with `grep`, `sed`, `awk`, `od`, and `stat` (Git Bash on Windows is enough). An optional argument names a different repository root. The script prints one line per problem and exits non-zero on any error; warnings do not fail it.

It always checks:

- exactly one mod under `Contents/mods/`, a `common/` and `42/` folder, and no stray root-level runtime copy;
- both `mod.info` files: `id=` matches the folder, `modversion=` matches `VERSION`, no legacy `version=` key, and `42/mod.info` has `versionMin=`;
- version drift: bold `**vX.Y.Z**` labels in `README.md`, `[b]Version:[/b]` in `docs/workshop-description.bbcode`, `vX.Y.Z` in the `workshop.txt` description, and runtime Lua build stamps (`BUILD_VERSION = "X.Y.Z"`, `buildVersion = "X.Y.Z"`, `Loaded vX.Y.Z`) must all match `VERSION`;
- every sandbox option has a `translation =` line with an EN `Sandbox_<key>` label (JSON or `Sandbox_EN.txt`), and every sandbox page has a label;
- no logs, backups, archives, `.env` files, or Java sources/classes inside the package;
- `NOTICE` still carries the pz-mod-template attribution block (a warning, never an error);
- `[center]` and `[br]` in the Workshop description, which Steam does not render;
- every file and folder in `docs/` listed in `docs/README.md`, and every link in that index pointing at something that exists (warnings, never errors);
- PNG identity of any artwork present, and `preview.png` at 256×256 and at most 1000 KB.

Once `workshop.txt` has a numeric `id=`, it also requires `preview.png` and the `poster=`/`icon=` files named in `42/mod.info`, and rejects leftover `[PLACEHOLDER]` text in the Workshop description.

Add project-specific regression guards in the marked section near the end of the script. Add a guard only for a defect or design boundary that has already mattered once, and comment what it protects.

This repository's guards:

- both `mod.info` files carry the same `id=`, `name=`, `description=`, `author=`, `category=`, `modversion=`, and `versionMin=` values;
- the build version is defined only in `42/media/lua/shared/EnshroudedSleep/Version.lua`; any other runtime Lua file with a `BUILD_VERSION = "x.y.z"` or `buildVersion = "x.y.z"` literal, a `Loaded vx.y.z` banner, or an `Enshrouded Sleep vx.y.z` header fails.

## `check-lua-syntax.sh`

Checks that every tracked `.lua` file parses as Lua 5.1, the language Project Zomboid's Kahlua interpreter reads, so a syntax error shows up in seconds instead of after a server start and client join. CI runs it as the "Check Lua syntax" job in [`../.github/workflows/validate-package.yml`](../.github/workflows/validate-package.yml).

```bash
bash tools/check-lua-syntax.sh
```

Prerequisites: a Lua 5.1 compiler, `luac5.1` or a `luac` that reports version 5.1 (on Debian or Ubuntu, including WSL, the `lua5.1` package). Without one the script reports the check as skipped and exits 0; `--require-compiler`, which CI passes, turns that into a failure. A file that parses can still fail at runtime, so a pass shows only that the syntax is valid Lua 5.1.

## `check-sensitive-content.sh`

Looks for private details that must not reach GitHub. [`../docs/PRIVATE_DATA.md`](../docs/PRIVATE_DATA.md) owns the rules and the steps to take after a leak; this section lists what the script matches.

```bash
bash tools/check-sensitive-content.sh [staged | tracked | text LABEL]
```

`staged` checks the files in the next commit and is what the pre-commit hook in [`../.githooks/`](../.githooks/) runs. `tracked`, the default, checks every tracked file. `text` checks standard input, which CI uses for pull request text and commit messages. Any finding exits non-zero. In GitHub Actions the log gives each location without the matched text.

Prerequisites: bash and Git built with PCRE support, which Git for Windows and the CI runner both are.

It reports:

- tracked `.env`, `.env.<name>`, and `<name>.env` files, `*.pem` and `*.ppk` files, and SSH private keys (`id_rsa`, `id_ed25519`, and similar); a name ending in `.example` is allowed;
- IPv4 addresses, except loopback (`127.x.x.x`), `0.0.0.0`, `255.255.255.255`, and the documentation ranges `192.0.2.x`, `198.51.100.x`, and `203.0.113.x`;
- 17-digit SteamID64 values;
- `Password=` and `RCONPassword=` lines with a value, as in a server `.ini` settings file;
- `KEY=value` lines whose upper-case key contains `PASSWORD`, `PASSWD`, `TOKEN`, `SECRET`, or `API_KEY`, unless the value is empty, quoted empty, or a `<placeholder>`;
- a user name and password or token inside a URL, and GitHub personal access tokens;
- project patterns, one regular expression per line, from the `SENSITIVE_PATTERNS` environment variable (a repository secret in CI) and from the file named by `git config pzmod.sensitivePatternsFile`.

A line containing `sensitive-content: allow` is skipped, for a false positive that cannot be reworded.
