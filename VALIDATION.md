# Validation — Build 42.21.0

## Version 1.1.1 — 2026-10-16

- Fixed percent labels that expanded to visible format-token suffixes in Build 42.21 translations. Literal percent characters are composed outside translated strings.
- The native radio sender resolves equipped devices or direct player containers; it cannot resolve an unequipped phone inside a bag. Added an owner-only, recursive item-ID state response after scans and custom battery insertion/removal. The client applies that state to the native DeviceData read by the standard power window, without sending a radio packet back.
- The scan popup reads the scanned phone's current condition and battery when available, so a later battery replacement does not leave an old percentage in the open result window.
- All 40 regression assertions and the three Python test cases pass, including literal percent output, recursive bag synchronization, native power changes and foreign item rejection.
- This patch has not been verified with two connected game clients. The v1.1.0 native engine probe below predates these changes.

## Version 1.1.0 — 2026-10-16

- 35 Lua regression assertions pass, including battery charge conservation, single consumption, owned-item validation, favourite protection, legacy migration, equipped-item deferral and one-time starter grants.
- Three Python test cases pass: server regression suite, Lua 5.1 syntax and EN/KO translation/placeholder parity.
- An isolated real Build 42.21.0 dedicated server reached startup and passed native Radio-class creation, electronics category, condition 100, battery insertion/removal, legacy condition/favourite preservation and single starter grant checks.
- All three production Lua sources compile using the engine's own Kahlua compiler.
- Engine probe: `[SIGNAL-V110] PASS Radio class, electronics, condition, native battery insertion/removal, legacy migration, single grant and Kahlua syntax`.
- The legacy normal-item definition is retained; a separate Radio item ID allows safe migration without loading old save bytes as a different Java item class.
- GUI appearance and real two-client synchronization, inventory save/reconnect lifecycle and third-party mod compatibility remain unverified. Native engine checks and test doubles do not establish these.

## Original release

Validated on 2026-10-15, using the installed 42.21.0 engine and an isolated dedicated-server container on the test NAS. Private infrastructure, addresses, credentials, saves and probe scripts are not part of this repository.

## Passed

- 22 Lua regression assertions in `tests/server_spec.lua`: costs, target eligibility, account cooldown, midnight, reconnect/respawn/phone swaps, broken phones, final-use snapshots, bags, sandbox limits, starter grant idempotency, invisible/dead targets, split-screen response identity and packet throttling.
- All three production Lua files compile with the game's own Kahlua compiler.
- Real dedicated-server startup reached `SERVER STARTED` and the mod's ready event.
- Real `instanceItem` creation: `SurvivorSignal.Phone`, weight 0.1, maximum and initial condition 100.
- Sandbox default durability loss 3.
- Real bag inventory search and condition-zero eligibility.
- EN/KO JSON files loaded using the game's translation reader. On a dedicated server, reloading Translator after mod initialization makes the probe's UI-key lookup available.
- `ModData.getOrCreate` is available. This confirms access to the persistent server data API; it is not a crash-recovery or disk-corruption test.
- Final NAS probe output: `[SIGNAL_ENGINE_PROBE] PASS item, durability, sandbox, bags, broken phone, translation, persistence`.
- Steam upload completed successfully; the public item metadata matches Workshop ID 3820241990 and the requested title.

The NAS run exposed the B42 item property change from `Type = Normal` to `ItemType = base:normal`; the published package includes the correction. Empty animation directories are included to avoid missing-directory warnings from the B42 loader.

## Still pending

Actual two-client gameplay, popup layout, minimap rendering, controller navigation, reconnect/save lifecycle over the network, conflict testing with other mods, and hostile client inventory tampering. Unit test doubles and server startup do not verify these. The daily rule and location disclosure are decided on the server, but this mod is not an anti-cheat system.

The test used a separate world and did not install the mod into the production world. The temporary test server is stopped after validation.
