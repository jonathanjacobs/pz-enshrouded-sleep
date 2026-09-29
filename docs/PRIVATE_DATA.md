# Keeping private details out of the repository

Do not update for: this mod's own player names or server host names. They go in the `SENSITIVE_PATTERNS` secret and a patterns file outside the repository, never in this file.

This document owns what must never be written into the repository or its GitHub pages, the automated check that looks for it, and what to do when something gets through. Mod repositories are usually public, and modding work produces a steady stream of server logs, config files, and test notes, which are the usual route by which a private detail reaches GitHub.

## What stays out

- Server IP addresses and host names, including home-network addresses and the address of a rented test server.
- Steam IDs (the 17-digit SteamID64 values that appear in server logs) and player, admin, and account user names other than your own public modding identity.
- Server, admin, and RCON passwords, including the `Password=` and `RCONPassword=` lines of a server's `.ini` settings file.
- SFTP or other remote-access credentials, host key fingerprints, private keys, and access tokens.
- Chat messages and other content written by other players.

This applies to committed files and equally to commit messages, pull request text, issues, and comments. It applies to anything an AI coding agent writes into any of them: an agent summarizing a test session will copy details from a log unless told otherwise.

## Describe environments by kind

Validation history, spikes, and bug reports need to say where a test ran, but not which machine. Write the kind of environment and what matters about it, for example "a rented dedicated server on Linux, 3 players" or "a hosted game from the developer's machine with one other client". When quoting a log line, quote only the lines that matter and replace private values with placeholders such as `<server-ip>` or `<steam-id>`. Raw logs stay in a local folder outside the repository.

Keep real settings, such as a remote test server's SFTP details, in an ignored local file, and commit a copy with placeholder values under a name ending in `.example`, as [Local files and automation](TESTING.md#local-files-and-automation) describes.

Authenticate to GitHub with `gh auth login` or a credential helper. Do not put a token in a remote URL: when a URL is passed to `git push -u` or `git push --set-upstream`, Git saves the whole URL, token included, in `.git/config` as the branch's remote.

## Automated check

[`../tools/check-sensitive-content.sh`](../tools/check-sensitive-content.sh) looks for known patterns: IPv4 addresses, Steam IDs, server password settings, `KEY=value` settings whose key names a password, token, or secret, credentials inside URLs, GitHub tokens, and tracked `.env`, `*.pem`, `*.ppk`, and SSH private-key files. [`../tools/README.md`](../tools/README.md#check-sensitive-contentsh) lists the exact rules and exceptions.

It runs in two places:

- **Before a commit**, once the pre-commit hook is turned on with `git config core.hooksPath .githooks`. This is the only check that acts before a value reaches GitHub. See [`../.githooks/README.md`](../.githooks/README.md).
- **In CI**, through [`../.github/workflows/sensitive-content.yml`](../.github/workflows/sensitive-content.yml), on every tracked file, and on pull request titles, descriptions, and commit messages. The workflow log gives each location without repeating the matched text. By then the value is already on GitHub, so a CI failure means the steps below apply.

Player names and server host names have no fixed shape, so the check cannot find them unaided. Add them as project patterns, one regular expression per line, in a repository secret named `SENSITIVE_PATTERNS` for CI, and in a file outside the repository for the hook (`git config --global pzmod.sensitivePatternsFile /path/to/patterns.txt`). A file of those names inside the repository would publish them.

For a false positive, such as a four-part version number that looks like an IP address, reword the line where possible; otherwise add the marker `sensitive-content: allow` to it. Use the reserved documentation addresses `192.0.2.x`, `198.51.100.x`, or `203.0.113.x` for examples, which the check accepts.

The check does not read issues or issue comments, and it cannot recognize a private value that matches none of its patterns. A pass is not proof that the repository is clean.

## If private details reach GitHub

Act in this order. GitHub's page [Removing sensitive data from a repository](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository) covers steps 3 to 5 in detail.

1. **Rotate any credential first.** Change the server, admin, RCON, or SFTP password, or revoke the token. Removing it from the repository does not undo the exposure, and a rotated credential is harmless wherever copies survive.
2. **Issues, pull request descriptions, and comments:** edit the text, then delete the old revision from the edit history (select "edited", choose the revision, then "Delete revision from history"). Anyone who can read the repository can otherwise open the old revision.
3. **Committed files:** deleting the value in a new commit leaves it in Git history. Rewrite the history with `git filter-repo --sensitive-data-removal`, then force-push every affected branch and tag.
4. **Old commits stay viewable after the force-push**, at `https://github.com/<owner>/<repo>/commit/<old-sha>` and through any pull request that referenced them. Forks and other people's clones also keep them. Ask collaborators to delete their clones and clone again, because an old clone can push the value back.
5. **Purge the old commits from GitHub** by contacting GitHub Support with the repository name and the "first changed commits" that `git filter-repo` reports. For an early repository with no forks, stars, open pull requests, or users, deleting the repository and recreating it with the cleaned history is a faster option. Deleting a repository also deletes its issues, pull requests, and settings and cannot be undone, so only the owner should make that decision.
6. **Confirm** by opening each old commit URL. Each should return a "404 not found" page.

A Steam Workshop upload is a separate copy. If the value was in a published package or Workshop description, publish a corrected version as well; see [`RELEASING.md`](RELEASING.md).
