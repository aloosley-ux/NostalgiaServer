# Play the local core sandbox

Launch `Run-Nostalgia.cmd` here, then `C:\AI\NostalgiaClient\Run-Nostalgia.cmd`.
Use `sandbox@nostalgia.local`; the existing password is the `account` field in
ignored `.local/credentials.json`. Choose Bastion/Medic/Ranger/Assault **Tester**.
The separate **Test** characters are disposable automated fixtures.

Spawn: Meridian Shelter, (1008,1010,7). Say `hi` then `trade` to Quartermaster.
Starter backpacks contain the other two class families, supplies and dressings.
Equip weapons in a hand, rigs in the ammo slot. Use dressings for healing.
The existing Skills window (Alt+S) displays authoritative Nostalgia Level/XP,
class, current weapon family/skill, Defence, Recovery, Medic mastery when
applicable, resource and supply count. Its button or `!resource` spends the
existing generic resource. `!nostalgia` remains a diagnostic snapshot.
Use `!qa help` for the four Testers' travel destinations, or `!qa pos` for
coordinates. The expanded Meridian QA district has separate species rooms,
movement, ranged, pack, healing/death, door/container and two-floor test areas.
PvE deaths return you to shelter with progression and equipment preserved.

## Implementation

Canary retains movement, targeting, containers, NPC shops, loot and database
inventory. Nostalgia Lua owns canonical damage, mitigation, recovery, independent
family/Defence/Recovery XP, Medic mastery, resources and supply accounting.
Native C++ provides the canonical Level curve/cadence, bypasses stock skill and
mitigation rules for Nostalgia classes, and saves character KV in the same
transaction as experience/items. Data is generated from `C:\AI\Nostalgia`;
see its `data/opentibia/README.md` for regeneration.

## Validation

Both native Release builds passed. Formula parity: 504 assertions / 72 cases.
`python tools/test-engine.py` passes 149 native checks across all classes;
`python tools/test-engine.py --restart` passes 25 fresh-process checks.
Then `python tools/test-live.py` runs actual TCP login, all twelve native weapon
families, supplies, healing, Defence, resources, fractional kill XP with zero
stamina, loot, NPC purchase, container opening, client HUD and two deaths per
class. It also restarts Canary to verify 88 exact played-state persistence checks.
Tests require the existing ignored client `.local/test-login.lua` credentials.
`python tools/test-qa.py` additionally runs all four actual Tester characters,
checks the integrated Skills UI and modern modules, docking/collapse/fallback,
map ground/LOS, travel, both stair pairs, TCP movement/door use and world chest
opening. It compares inventory/progression and restores positions on logout.
Stop manual server/client instances before running tests.
See `C:\AI\Nostalgia\docs\35_CLIENT_INTEGRATION_AND_MANUAL_QA_SANDBOX.md`
for the asset diagnosis, RME launcher and human testing checklist.

## Remaining scope

Resource spends implement the canonical simulator's generic reserved budget;
named abilities, revives/cleanses, authored enemy specials and multiplayer group
balancing remain to implement. Extra ring/bracelet slots are not exposed yet.
Shop equipment prices and loot drop chances are sandbox values. Temporary
graphics stay in ignored standard client paths; no proprietary graphics are
committed. Native client screenshots now verify coherent 15.25 ground and the
four Testers' Skills panels. Some weapon/supply/creature graphics remain explicit
temporary proxies; the local sound pack is absent. Native RME asset loading was
checked, but interactive editor open/edit/save round-trip remains a human check.
Unused upstream content still loads alongside the sandbox.
