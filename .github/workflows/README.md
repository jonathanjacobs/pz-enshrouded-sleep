# GitHub Actions workflows

GitHub runs each `.yml` file in this folder when its trigger happens: a push to `main`, a pull request to `main`, or a manual run. It ignores other files, including this README.

| Workflow | Job name | Question it answers |
| --- | --- | --- |
| `validate-package.yml` | `validate-package` | Is the package layout, `mod.info`, version, translation, and artwork set consistent? Runs [`../../tools/validate-package.sh`](../../tools/validate-package.sh). |
| `validate-package.yml` | `Check Lua syntax` | Does every tracked `.lua` file parse as Lua 5.1? Runs [`../../tools/check-lua-syntax.sh`](../../tools/check-lua-syntax.sh). |
| `validate-release-candidate.yml` | `validate-package` (workflow "Validate Enshrouded Sleep release") | Do the Enshrouded Sleep-specific release invariants hold: required runtime files, sandbox option names, defaults, and translations, version labels and build stamps, Workshop identity, the server-authoritative XP path, and public wording that must stay in sync? Carried over from the mod's repository. |
| `sensitive-content.yml` | `Check for private details` | Did a server address, Steam ID, password, token, or secrets file reach the repository, a pull request, or a commit message? Runs [`../../tools/check-sensitive-content.sh`](../../tools/check-sensitive-content.sh). |

Use the job names when choosing required status checks in branch protection. GitHub offers branch protection on the free plan for public repositories. None of these checks shows that the mod works in game.

The other files in `.github/`:

| File | Use |
| --- | --- |
| `pull_request_template.md` | The questions each pull request description answers |
| `ISSUE_TEMPLATE/` | Bug report and feature request forms for players and server operators |
| `FUNDING.yml` | Optional sponsor links, all comments until filled in |

This README sits in `workflows/` because GitHub shows a README placed directly in `.github/` on the repository's front page in place of the root `README.md`. Do not add one there.
