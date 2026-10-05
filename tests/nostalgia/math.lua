local M = dofile('data-canary/lib/nostalgia/math.lua')
local cases = dofile(arg[1])
local checked = 0
local function near(a, b, name)
    assert(math.abs(a - b) <= 1e-8 * math.max(1, math.abs(b)), name .. ': ' .. tostring(a) .. ' ~= ' .. tostring(b))
    checked = checked + 1
end
for _, case in ipairs(cases) do
    local direct, status = M.damage(case.weapon, case.level, case.level, case.mob, false)
    near(direct, case.direct, case.family .. ' direct')
    near(status, case.status, case.family .. ' status')
    local crit = M.damage(case.weapon, case.level, case.level, case.mob, true)
    near(crit, direct * case.weapon.crit_multiplier, 'critical')
    near(M.hp(case.level, case.class_name), case.hp, 'hp')
    near(M.skill(case.xp), case.level, 'skill inversion')
    near(M.skillRate(case.level), case.rate, 'skill rate')
    near(M.reduction(case.armour, case.level, case.class_name, case.mob.stats.enemy_pressure), case.reduction, 'mitigation')
end
assert(M.skill(0) == 1)
assert(M.content(100, 1).xp == M.data.balance.combat.content_scaling.minimum_xp_relevance)
assert(M.content(1, 100).incoming > 1)
assert(M.challenge(1, 100) == M.data.balance.combat.challenge.maximum)
print('PASS: ' .. #cases .. ' family/level cases; ' .. checked .. ' Python/Lua parity assertions.')
