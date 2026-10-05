-- Run explicitly from an ignored local startup script after provisioning.
-- Tests use separate temporary characters, not the playable testers.
local N, D = Nostalgia, Nostalgia.math.data
if os.getenv('NOSTALGIA_LIVE_RESTART_VERIFY') == '1' then
    return dofile('tests/nostalgia/persistence.lua').verify()
end
local checks = 0
local function check(value, message) assert(value, message); checks = checks + 1 end
for vocation, class in pairs(N.classes) do
    local player = assert(Game.getOfflinePlayer('Test ' .. class))
    check(N.class(player) == class, 'class identity')
    if os.getenv('NOSTALGIA_RESTART_VERIFY') == '1' then
        local weapon = N.weapon(player)
        check(weapon and weapon.class_name == class, 'restarted equipment')
        check(N.skill(player, weapon.weapon_family) > 1 and N.skill(player, 'Defence') > 1 and N.skill(player, 'Recovery') > 1, 'restarted independent progression')
        check(N.kv(player):get('resource') == 100, 'restarted resource')
        check(player:getLevel() == 3 and player:getExperience() == Game.getExperienceForLevel(3), 'restarted native Level/XP')
        check(N.kv(player):get('supply-debt-' .. weapon.weapon_family) == 0.45, 'restarted fractional supply debt')
        if class == 'Medic' then check(N.skill(player,'MedicMastery') > 1, 'restarted Medic mastery') end
    else
    -- Client packets are irrelevant to an offline engine fixture.
    local snapshot = N.snapshot
    N.snapshot = function() end
    check(N.login(player), 'login/starter')
    N.snapshot = snapshot
    check(player:getMaxHealth() == math.floor(N.math.hp(1, class) + 0.5), 'class HP')
    local weapon = N.weapon(player)
    check(weapon and weapon.class_name == class, 'starter weapon')
    check(player:getSlotItem(CONST_SLOT_NECKLACE) and player:getSlotItem(CONST_SLOT_RING), 'starter native accessories')
    check(bit.band(ItemType(D.items['NEC-01'].server_id):getSlotPosition(), SLOTP_NECKLACE) ~= 0
        and bit.band(ItemType(D.items['RING-01'].server_id):getSlotPosition(), SLOTP_RING) ~= 0, 'native accessory slots')
    for family, familyData in pairs(D.balance.weapon_families) do
        if familyData.class == class then
            check(N.skill(player, family) == 1, 'initial independent skill')
            check(N.supply(family) and player:getItemCount(N.supply(family).server_id) >= 100, 'compatible supply')
            local available = false
            for _, item in pairs(D.items) do
                if item.server_id and item.category == 'weapon' and item.weapon_family == family and item.required_level == 1
                    and player:getItemCount(item.server_id) > 0 then available = true end
            end
            check(available, 'playable starter family')
        end
    end
    local primary = weapon.weapon_family
    N.gainSkill(player, primary, 30, D.balance.progression.hunting_skill_efficiency, 1)
    N.gainSkill(player, 'Defence', 20, D.balance.progression.defence_hunting_efficiency, 1)
    N.gainSkill(player, 'Recovery', 20, D.balance.progression.recovery_hunting_efficiency, 1)
    if class == 'Medic' then
        N.gainSkill(player,'MedicMastery',30,D.balance.progression.hunting_skill_efficiency,1)
        check(N.skill(player,'MedicMastery') > 1, 'independent Medic mastery')
    end
    check(N.skill(player, primary) > 1, 'primary progress')
    for family, familyData in pairs(D.balance.weapon_families) do
        if familyData.class == class and family ~= primary then check(N.skill(player, family) == 1, 'no equalisation') end
    end
    check(N.skill(player, 'Defence') > 1 and N.skill(player, 'Recovery') > 1, 'universal progress')
    for _, level in ipairs({2,3,15,30,100,200,750}) do
        check(Game.getExperienceForLevel(level) == math.ceil(D.level_thresholds[level]), 'canonical native Level curve at ' .. level)
    end
    check(player:addExperience(Game.getExperienceForLevel(3), false), 'native XP award')
    check(player:getLevel() == 3, 'native Level progression')
    N.refresh(player)
    check(player:getMaxHealth() == math.floor(N.math.hp(3, class) + 0.5), 'derived HP after levelling')
    local mob = assert(Game.createMonster('Field Hare', Position(1011,1037,7),false,true))
    local expected = D.mobs['field hare'].stats.raw_xp_reward_total * N.math.content(3,1).xp
    local paid = N.gainExperience(player,mob,math.ceil(D.mobs['field hare'].stats.raw_xp_reward_total * D.xp_scale))
    check(math.abs(paid + (N.kv(player):get('xp-fraction') or 0) - expected) < 1e-10, 'native fractional XP storage')
    N.kv(player):set('xp-fraction',0)
    local reward = math.ceil(D.mobs['field hare'].stats.raw_xp_reward_total * D.xp_scale)
    local partial = math.floor(reward / 4)
    paid = N.gainExperience(player,mob,partial)
    check(math.abs(paid + (N.kv(player):get('xp-fraction') or 0) - expected * partial / reward) < 1e-10, 'partial kill credit preserves fractional XP')
    N.kv(player):set('xp-fraction',0)
    mob:remove()
    local kv = N.kv(player)
    kv:set('resource', 100)
    kv:set('supply-debt-' .. primary,0.45)
    N.refresh(player)
    check(player:getMana() == 100, 'resource native display')
    local armour = N.equipment(player)
    check(armour > 0, 'equipment contributes')
    check(player:save(), 'native save')
    local guid = player:getGuid()
    N.sessions[player:getId()] = nil
    player = nil
    collectgarbage('collect')
    local restored = assert(Game.getOfflinePlayer(guid))
    check(N.skill(restored, primary) > 1 and N.skill(restored, 'Defence') > 1, 'persistent skills')
    check(N.weapon(restored).weapon_family == primary, 'persistent equipment')
    check(N.kv(restored):get('resource') == 100, 'persistent resource')
    end
end
logger.info('NOSTALGIA ' .. (os.getenv('NOSTALGIA_RESTART_VERIFY') == '1' and 'RESTART' or 'ENGINE') .. ' PASS: ' .. checks .. ' native engine/persistence assertions across four classes.')
return true
