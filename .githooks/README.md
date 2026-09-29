# Git hooks

Git runs a file in this folder when its name matches a hook, such as `pre-commit`, once a clone is set to use the folder. This README is never run.

| Hook | What it does |
| --- | --- |
| `pre-commit` | Runs [`../tools/check-sensitive-content.sh`](../tools/check-sensitive-content.sh) on the files in each commit, and stops the commit if one contains a server IP address, Steam ID, password, token, or is a local secrets file. |

Turn the hooks on once in each clone:

```bash
git config core.hooksPath .githooks
```

That setting replaces any hooks already in `.git/hooks` for that clone. `git commit --no-verify` skips the hook for one commit; the same check still runs in CI. The hook is the only check that acts before anything reaches GitHub, which matters because a pushed value stays in Git history. [`../docs/PRIVATE_DATA.md`](../docs/PRIVATE_DATA.md) describes what the check looks for and what to do when something gets through.
