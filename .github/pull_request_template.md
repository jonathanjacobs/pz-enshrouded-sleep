## What changed and why

Describe the change, the reason for it, and who notices it: players, server operators, or other mods. Cite requirements (`R1`, …) and issues by number.

## What was checked

List each check and what was observed: `validate-package.sh`, the Lua syntax check, and any in-game test (which one from `docs/TESTING.md`, on what topology). Name skipped, incomplete, or not-run checks just as plainly. Passing CI shows the package is well-formed and the Lua parses; it does not show that the mod works in game.

Describe servers by kind, such as "a rented dedicated server". This text is checked for IP addresses, Steam IDs, and passwords.

## Compatibility and multiplayer

Does this rename, remove, or change the meaning or default of a compatibility contract in `docs/DESIGN.md` (Mod ID, sandbox options, ModData keys, command names, script types, required Lua paths), or change which side owns multiplayer state? If so, name it and link the `Upgrading` note in `CHANGELOG.md`. Otherwise write `No`.

## Assets and outside material

Does this add a distributed asset or any third-party code, art, audio, or data? If so, confirm it is recorded in `CREDITS.md`. Otherwise write `No`.
