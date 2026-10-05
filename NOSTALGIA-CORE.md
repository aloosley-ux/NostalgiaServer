# Play the local core sandbox

Launch `Run-Nostalgia.cmd` here, then `C:\AI\NostalgiaClient\Run-Nostalgia.cmd`.
Use `sandbox@nostalgia.local`; the existing password is the `account` field in
ignored `.local/credentials.json`. Choose Bastion/Medic/Ranger/Assault **Tester**.
The separate **Test** characters are disposable automated fixtures.

Spawn: Meridian Shelter, (1008,1010,7). Say `hi` then `trade` to Quartermaster.
Starter backpacks contain the other two class families, supplies and dressings.
Equip weapons in a hand, rigs in the ammo slot. Use dressings for healing.
The Nostalgia Character panel exposes the authoritative progression and resource;
its button or `!resource` spends that resource. `!nostalgia` prints the snapshot.
Leave the shelter eastward to hunt eight species across the original compact map.
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

## Remaining scope

Resource spends implement the canonical simulator's generic reserved budget;
named abilities, revives/cleanses, authored enemy specials and multiplayer group
balancing remain to implement. Extra ring/bracelet slots are not exposed yet.
Shop equipment prices and loot drop chances are sandbox values. Temporary
graphics stay in ignored standard client paths; no proprietary graphics are
committed. Client modules ran successfully, but visual QA was unavailable while
the desktop was locked. Unused upstream content still loads alongside the sandbox.
