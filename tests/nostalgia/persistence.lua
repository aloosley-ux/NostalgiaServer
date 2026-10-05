-- Test-only snapshot of native equipment/containers and Nostalgia progression.
local N, D = Nostalgia, Nostalgia.math.data
local T = {}
local function describe(item)
    if not item then return '-' end
    local parts = {item:getId() .. ':' .. item:getCount()}
    if item:isContainer() then
        for index = 0, item:getSize() - 1 do parts[#parts+1] = describe(item:getItem(index)) end
    end
    return table.concat(parts, '/')
end
function T.capture(player)
    local result = {level=player:getLevel(), xp=player:getExperience(), inventory={}, progression={}}
    for slot = CONST_SLOT_HEAD, CONST_SLOT_AMMO do result.inventory[slot] = describe(player:getSlotItem(slot)) end
    local kv = N.kv(player)
    for _, key in ipairs({'resource','xp-fraction','xp-Defence','xp-Recovery','xp-MedicMastery'}) do
        result.progression[key] = kv:get(key) or 0
    end
    for family, row in pairs(D.balance.weapon_families) do
        if row.class == N.class(player) then
            for _, prefix in ipairs({'xp-','supply-debt-'}) do
                local key = prefix .. family
                result.progression[key] = kv:get(key) or 0
            end
        end
    end
    return result
end
function T.verify()
    local checks = 0
    for _, class in pairs(N.classes) do
        if not os.getenv('NOSTALGIA_TEST_CLASS') or os.getenv('NOSTALGIA_TEST_CLASS') == class then
            local player = assert(Game.getOfflinePlayer('Test ' .. class))
            local expected = json.decode(assert(N.kv(player):get('fixture-live-final')))
            local actual = T.capture(player)
            assert(actual.level == expected.level and actual.xp == expected.xp, class .. ' restarted Level/XP')
            checks = checks + 1
            for slot, value in ipairs(expected.inventory) do
                assert(actual.inventory[slot] == value, class .. ' restarted inventory slot ' .. slot)
                checks = checks + 1
            end
            for key, value in pairs(expected.progression) do
                assert(math.abs(actual.progression[key] - value) < 1e-9, class .. ' restarted ' .. key)
                checks = checks + 1
            end
        end
    end
    logger.info('NOSTALGIA RESTART PASS: ' .. checks .. ' live gameplay, logout and fresh-process persistence assertions.')
    return true
end
return T
