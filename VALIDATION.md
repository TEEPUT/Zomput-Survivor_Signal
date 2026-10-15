# Validation — Build 42.21.0

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
