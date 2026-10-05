-- Nostalgia gameplay adapts Canary's authoritative attacks, damage and KV persistence.
if not json then dofile('data-canary/lib/nostalgia/json.lua') end
Nostalgia = { math = dofile('data-canary/lib/nostalgia/math.lua'), sessions = {}, opcode = 121 }
local N = Nostalgia
local M, D = N.math, N.math.data
local C, P = D.balance.combat, D.balance.progression
N.classes = {[20]='Bastion', [21]='Medic', [22]='Ranger', [23]='Assault'}
N.resources = {Bastion='Resolve', Medic='Reserve', Ranger='Focus', Assault='Momentum'}
local slots = {helmet=CONST_SLOT_HEAD, chest=CONST_SLOT_ARMOR, legs=CONST_SLOT_LEGS, boots=CONST_SLOT_FEET, neck=CONST_SLOT_NECKLACE, ring=CONST_SLOT_RING, class_rig=CONST_SLOT_AMMO}
local function now() return systemTime() end
local function round(value) return math.floor(value + 0.5) end
function N.class(player) return N.classes[player:getVocation():getId()] end
function N.kv(player) return player:kv():scoped('nostalgia-v1') end
function N.item(item)
    return item and D.items[D.proxies[tostring(item:getId())]] or nil
end
function N.weapon(player)
    local left, right = player:getSlotItem(CONST_SLOT_LEFT), player:getSlotItem(CONST_SLOT_RIGHT)
    local a, b = N.item(left), N.item(right)
    if a and a.category == 'weapon' then return a, left end
    if b and b.category == 'weapon' then return b, right end
end
function N.skill(player, family)
    return M.skill(N.kv(player):get('xp-' .. family) or 0)
end
function N.gainSkill(player, family, seconds, efficiency, content)
    local kv = N.kv(player)
    local xp = kv:get('xp-' .. family) or 0
    local skill = M.skill(xp)
    kv:set('xp-' .. family, xp + M.skillGain(skill, seconds, efficiency, player:getLevel(), content))
end
function N.equipment(player)
    local armour, generation, potency = 0, 0, 0
    local class = N.class(player)
    for name, slot in pairs(slots) do
        local item = N.item(player:getSlotItem(slot))
        if item and item.equipment_slot == name and item.required_level <= player:getLevel() and (not item.class_name or item.class_name == class) and item.stats then
            armour = armour + (item.stats.armour or 0)
            generation = generation + (item.stats.resource_generation_bonus or 0)
            potency = potency + (item.stats.resource_spend_potency_bonus or 0)
        end
    end
    return armour, generation, potency
end
function N.refresh(player)
    local class = N.class(player)
    if not class then return end
    player:setMaxHealth(round(M.hp(player:getLevel(), class)))
    player:setMaxMana(C.class_resource.spend_cost)
    local value = M.clamp(N.kv(player):get('resource') or 0, 0, C.class_resource.spend_cost)
    player:addMana(round(value) - player:getMana())
end
function N.snapshot(player)
    local class, kv = N.class(player), N.kv(player)
    if not class then return end
    local weapon = N.weapon(player)
    local skills = {}
    for family, row in pairs(D.balance.weapon_families) do
        if row.class == class then skills[family] = N.skill(player, family) end
    end
    local supply = weapon and N.supply(weapon.weapon_family)
    local data = {version=1, class=class, level=player:getLevel(), xp=player:getExperience(), family=weapon and weapon.weapon_family or 'Unequipped',
        skills=skills, defence=N.skill(player, 'Defence'), recovery=N.skill(player, 'Recovery'),
        mastery=class == 'Medic' and N.skill(player, 'MedicMastery') or nil,
        resource_name=N.resources[class], resource=kv:get('resource') or 0, resource_max=C.class_resource.spend_cost,
        supply= supply and supply.display_name or '', supply_count=supply and player:getItemCount(supply.server_id) or 0}
    player:sendExtendedOpcode(N.opcode, json.encode(data))
    return data
end
function N.supply(family)
    for _, item in pairs(D.items) do
        if item.server_id and item.category == 'supply' and item.source_level == 1 then
            for _, compatible in ipairs(item.compatible_weapon_families or {}) do
                if compatible == family then return item end
            end
        end
    end
end
function N.fail(player, message)
    local s = N.sessions[player:getId()]
    if not s or now() >= (s.messageAt or 0) then
        player:sendCancelMessage(message)
        if s then s.messageAt = now() + 2000 end
    end
    return false
end
function N.attack(player, variant)
    local class, session = N.class(player), N.sessions[player:getId()]
    if not class or not session then return false end
    local weapon = N.weapon(player)
    if not weapon or weapon.class_name ~= class then return N.fail(player, 'Equip a weapon belonging to your class.') end
    if player:getLevel() < weapon.required_level then return N.fail(player, 'This weapon requires Level ' .. weapon.required_level .. '.') end
    local target = Creature(variant:getNumber())
    local mob = target and D.mobs[target:getName():lower()]
    if not target or not target:isMonster() or not mob then return N.fail(player, 'This weapon requires a Nostalgia enemy.') end
    local pos, dest = player:getPosition(), target:getPosition()
    local range = class == 'Bastion' and 1 or 7
    if pos.z ~= dest.z or pos:getDistance(dest) > range or not pos:isSightClear(dest) then return false end
    if player:getTile():hasFlag(TILESTATE_PROTECTIONZONE) or target:getTile():hasFlag(TILESTATE_PROTECTIONZONE) then return false end
    local at = now()
    if at < (session.attackAt or 0) then return false end
    local kv = N.kv(player)
    local supply = N.supply(weapon.weapon_family)
    if not supply then return N.fail(player, 'No compatible combat supply.') end
    -- Fractional units persist by family; attacks never get free supplies on logout.
    local debtKey = 'supply-debt-' .. weapon.weapon_family
    local debt = kv:get(debtKey) or 0
    local units = weapon.stats.supply_units_per_attack
    local consumed = math.floor(debt + units + 1e-9)
    if player:getItemCount(supply.server_id) < math.max(1, consumed) then return N.fail(player, 'Out of ' .. supply.display_name .. '.') end
    if consumed > 0 and not player:removeItem(supply.server_id, consumed) then return false end
    kv:set(debtKey, debt + units - consumed)
    session.attackAt = at + round(weapon.stats.attack_interval * 1000)
    session.activeUntil, session.content = at + math.max(2000, round(weapon.stats.attack_interval * 1000) + 500), mob.content_level
    session.family = weapon.weapon_family
    local direct, status = M.damage(weapon.stats, player:getLevel(), N.skill(player, weapon.weapon_family), mob, math.random() < weapon.stats.crit_chance)
    -- Preserve the canonical mean at every magnitude despite integer engine HP.
    local hit = math.floor(direct) + (math.random() < direct % 1 and 1 or 0)
    if class ~= 'Bastion' then pos:sendDistanceEffect(dest, CONST_ANI_SMALLSTONE) end
    if hit > 0 then doTargetCombatHealth(player, target, COMBAT_PHYSICALDAMAGE, -hit, -hit, CONST_ME_HITAREA, ORIGIN_SPELL) end
    if status > 0 and target:getHealth() > 0 and math.random() < C.stochastic.status_application_chance then
        session.statusSequence = (session.statusSequence or 0) + 1
        local condition = Condition(CONDITION_BLEEDING, CONDITIONID_COMBAT, 1000 + session.statusSequence % 32)
        condition:setParameter(CONDITION_PARAM_OWNER, player:getId())
        condition:setParameter(CONDITION_PARAM_DELAYED, true)
        local ticks = math.floor(C.stochastic.status_duration_seconds / C.stochastic.status_tick_seconds)
        local expected = status / C.stochastic.status_application_chance / ticks
        local amount = math.floor(expected) + (math.random() < expected % 1 and 1 or 0)
        if amount > 0 then condition:addDamage(ticks, C.stochastic.status_tick_seconds * 1000, -amount); target:addCondition(condition) end
    end
    return true
end
function N.gainExperience(player, target, exp)
    -- Explicit quest/script rewards are already raw Nostalgia XP.
    if not target then return exp end
    local mob = target and D.mobs[target:getName():lower()]
    if not mob then return 0 end
    -- Engine damage sharing is retained; round residual XP only after relevance.
    -- Canary shares integer kill credit. Fixed-point transport keeps small kills
    -- meaningful when multiple characters contribute damage or share a party.
    local sourceReward = math.max(1, math.ceil(mob.stats.raw_xp_reward_total * D.xp_scale))
    local share = math.min(1, exp / sourceReward)
    local party = player:getParty()
    if party and N.class(party:getLeader()) and party:isSharedExperienceActive() and party:isSharedExperienceEnabled() then
        share = share / (party:getMemberCount() + 1)
    end
    local kv = N.kv(player)
    local actual = mob.stats.raw_xp_reward_total * share * M.content(player:getLevel(), mob.content_level).xp + (kv:get('xp-fraction') or 0)
    kv:set('xp-fraction', actual % 1)
    return math.floor(actual)
end
function N.healthChange(player, attacker, primary, primaryType, secondary, secondaryType, origin)
    if not N.class(player) or primaryType == COMBAT_HEALING then return primary, primaryType, secondary, secondaryType end
    local mob = attacker and D.mobs[attacker:getName():lower()]
    if not mob then return primary, primaryType, secondary, secondaryType end
    local s = N.sessions[player:getId()]
    if s then s.pressureUntil, s.content = now() + 2000, mob.content_level end
    local armour = N.equipment(player)
    local guard = s and now() < (s.guardUntil or 0) and s.guard or 0
    local multiplier = (1 - M.reduction(armour, N.skill(player, 'Defence'), N.class(player), mob.stats.enemy_pressure, guard)) * M.content(player:getLevel(), mob.content_level).incoming
    -- Creature health-change receives positive damage from Canary.
    return round(primary * multiplier), primaryType, round(secondary * multiplier), secondaryType
end
function N.heal(player, target)
    local session = N.sessions[player:getId()]
    if not session then return false end
    target = target or player
    if target ~= player then
        local pos, dest = player:getPosition(), target:getPosition()
        if N.class(player) ~= 'Medic' or not target:isPlayer() or pos.z ~= dest.z or pos:getDistance(dest) > 7 or not pos:isSightClear(dest) then return false end
        if not player:getParty() or player:getParty() ~= target:getParty() then return N.fail(player, 'Treat members of your party.') end
    end
    if now() < (session.healAt or 0) or target:getHealth() >= target:getMaxHealth() then return false end
    local proficiency = N.skill(player, target == player and 'Recovery' or 'MedicMastery')
    local amount = target:getMaxHealth() * C.healing_unit_fraction_of_hp * M.scale(proficiency, 'recovery')
    if N.class(player) == 'Medic' then amount = amount * D.balance.classes.Medic.recovery_coeff end
    local healed = math.min(round(amount), target:getMaxHealth() - target:getHealth())
    target:addHealth(healed)
    target:getPosition():sendMagicEffect(CONST_ME_MAGIC_BLUE)
    session.healAt = now() + C.stochastic.healing_protocol_cooldown_seconds * 1000
    session.treatmentUntil = now() + C.stochastic.healing_protocol_cooldown_seconds * 1000
    if target ~= player then session.masteryUntil = session.treatmentUntil end
    return true
end
function N.spend(player)
    local class, s, kv = N.class(player), N.sessions[player:getId()], N.kv(player)
    if not class or not s then return false end
    local resource = kv:get('resource') or 0
    local cost = C.class_resource.spend_cost
    if resource < cost then return N.fail(player, N.resources[class] .. ' requires ' .. cost .. '.') end
    local weapon, target = N.weapon(player), player:getTarget()
    local mob = target and D.mobs[target:getName():lower()]
    if player:getTile():hasFlag(TILESTATE_PROTECTIONZONE) then return N.fail(player, 'Leave the safe area before spending your resource.') end
    if weapon and (weapon.class_name ~= class or player:getLevel() < weapon.required_level) then return false end
    if class ~= 'Bastion' and class ~= 'Medic' and (not weapon or not mob or not target:isMonster()) then return N.fail(player, 'Select a Nostalgia enemy in range.') end
    if target then
        local pos, dest = player:getPosition(), target:getPosition()
        local range = class == 'Bastion' and 1 or 7
        if pos.z ~= dest.z or pos:getDistance(dest) > range or not pos:isSightClear(dest) or target:getTile():hasFlag(TILESTATE_PROTECTIONZONE) then return false end
    end
    local _, _, potency = N.equipment(player)
    kv:set('resource', resource - cost)
    local classData = D.balance.classes[class]
    -- Convert the simulator's time-averaged budget to a bounded timed guard.
    s.guardUntil = now() + C.stochastic.resource_guard_duration_seconds * 1000
    s.guard = math.min(C.stochastic.max_resource_guard_damage_reduction, classData.resource_defence_bonus * C.class_resource.target_spend_seconds / C.stochastic.resource_guard_duration_seconds * (1 + potency))
    if class == 'Medic' then
        player:addHealth(round(player:getMaxHealth() * C.healing_unit_fraction_of_hp * M.scale(N.skill(player, 'MedicMastery'), 'recovery') * (1 + potency)))
        local party = player:getParty()
        if party then
            local allies = party:getMembers(); table.insert(allies, party:getLeader())
            for _, ally in ipairs(allies) do
                local pos, dest = player:getPosition(), ally:getPosition()
                if ally ~= player and pos.z == dest.z and pos:getDistance(dest) <= 7 and pos:isSightClear(dest) then ally:addHealth(round(ally:getMaxHealth() * C.healing_unit_fraction_of_hp * (1 + D.balance.groups.medic_group_healing_bonus))) end
            end
        end
    end
    if mob and weapon and weapon.class_name == class then
        local direct, status = M.damage(weapon.stats, player:getLevel(), N.skill(player, weapon.weapon_family), mob, false)
        local expected = direct * (1 + weapon.stats.crit_chance * (weapon.stats.crit_multiplier - 1)) + status
        local damage = round(expected / weapon.stats.attack_interval * C.class_resource.target_spend_seconds * classData.resource_offence_bonus * (1 + potency))
        if damage > 0 then doTargetCombatHealth(player, target, COMBAT_PHYSICALDAMAGE, -damage, -damage, CONST_ME_HITAREA, ORIGIN_SPELL) end
    end
    player:getPosition():sendMagicEffect(CONST_ME_MAGIC_GREEN)
    N.refresh(player); N.snapshot(player)
    return true
end
function N.think(player, interval)
    local class, s = N.class(player), N.sessions[player:getId()]
    if not class or not s then return end
    local seconds = math.min(interval / 1000, 2)
    local at, content = now(), s.content or player:getLevel()
    local attacking, pressured = at < (s.activeUntil or 0), at < (s.pressureUntil or 0)
    if attacking and s.family then N.gainSkill(player, s.family, seconds, P.hunting_skill_efficiency, content) end
    if pressured then N.gainSkill(player, 'Defence', seconds, P.defence_hunting_efficiency, content) end
    if (attacking or pressured) and player:getHealth() < player:getMaxHealth() then N.gainSkill(player, 'Recovery', seconds, P.recovery_hunting_efficiency, content) end
    if class == 'Medic' and at < (s.masteryUntil or 0) then N.gainSkill(player, 'MedicMastery', seconds, P.hunting_skill_efficiency, content) end
    local role = (class == 'Bastion' and pressured) or (class == 'Medic' and (at < (s.treatmentUntil or 0) or ((attacking or pressured) and player:getHealth() < player:getMaxHealth()))) or ((class == 'Ranger' or class == 'Assault') and attacking)
    if role then
        local kv = N.kv(player)
        local _, generation = N.equipment(player)
        kv:set('resource', math.min(C.class_resource.spend_cost, (kv:get('resource') or 0) + C.class_resource.base_generation_per_second * seconds * M.challenge(player:getLevel(), content) * (1 + generation)))
    end
    N.refresh(player)
    local rate
    if attacking or pressured then rate = M.recovery(player:getLevel(), N.skill(player, 'Recovery'), class) * C.stochastic.passive_recovery_share
    elseif not player:hasCondition(CONDITION_INFIGHT) then rate = C.out_of_combat_recovery_fraction_per_second * player:getMaxHealth() end
    if rate and player:getHealth() < player:getMaxHealth() then
        s.healFraction = (s.healFraction or 0) + rate * seconds
        local amount = math.floor(s.healFraction)
        if amount > 0 then player:addHealth(amount); s.healFraction = s.healFraction - amount end
    end
    N.snapshot(player)
end
function N.login(player)
    local class = N.class(player)
    if not class then return true end
    N.sessions[player:getId()] = {guid=player:getGuid()}
    player:registerEvent('NostalgiaThink')
    player:registerEvent('NostalgiaHealth')
    player:registerEvent('NostalgiaOpcode')
    player:registerEvent('NostalgiaLogout')
    player:registerEvent('NostalgiaAdvance')
    player:registerEvent('NostalgiaDeath')
    if os.getenv('NOSTALGIA_LIVE_TEST') == '1' and player:getName():match('^Test ') then
        player:registerEvent('NostalgiaLiveTest')
    end
    player:setDropLoot(false); player:setSkillLoss(false)
    player:removeCondition(CONDITION_REGENERATION)
    N.refresh(player)
    local kv = N.kv(player)
    if not kv:get('starter-issued') then
        if not player:getSlotItem(CONST_SLOT_BACKPACK) then player:addItem(2854, 1, false, 1, CONST_SLOT_BACKPACK) end
        for _, identity in ipairs({'ARM-01-H','ARM-01-C','ARM-01-L','ARM-01-B','NEC-01','RING-01'}) do
            local item = D.items[identity]
            player:addItem(item.server_id, 1, false, 1, slots[item.equipment_slot])
        end
        local starter = D.items[D.starter[class]]
        player:addItem(starter.server_id, 1, false, 1, CONST_SLOT_LEFT)
        for _, item in pairs(D.items) do
            if item.server_id and item.category == 'rig' and item.class_name == class and item.required_level == 1 then player:addItem(item.server_id, 1, false, 1, CONST_SLOT_AMMO) end
        end
        for family, familyData in pairs(D.balance.weapon_families) do
            if familyData.class == class then local supply = N.supply(family); player:addItem(supply.server_id, 100) end
        end
        player:addItem(D.items['MED-01'].server_id, 50)
        player:addMoney(300)
        player:addHealth(player:getMaxHealth())
        kv:set('starter-issued', true)
    end
    if not kv:get('starter-families-issued') then
        local complete = true
        for _, item in pairs(D.items) do
            if item.server_id and item.category == 'weapon' and item.class_name == class and item.required_level == 1
                and item.item_id ~= D.starter[class] and not player:addItem(item.server_id, 1) then complete = false end
        end
        if complete then kv:set('starter-families-issued', true) end
    end
    player:sendTextMessage(MESSAGE_LOGIN, 'Welcome to Nostalgia. ' .. class .. ': independent weapon Skills, Defence and Recovery. Your backpack contains the other starter families. Quartermaster at the shelter; use dressings to heal and !resource to spend ' .. N.resources[class] .. '.')
    N.snapshot(player)
    return true
end
return N
