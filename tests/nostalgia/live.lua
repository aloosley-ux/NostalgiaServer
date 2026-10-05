-- Native network fixtures: only opt-in Test characters are changed.
local N, D = Nostalgia, Nostalgia.math.data
local states, checks = {}, 0
local persistence = dofile('tests/nostalgia/persistence.lua')
local function check(value, message)
    assert(value, 'LIVE: ' .. message)
    checks = checks + 1
end
local function finish(player, state)
    player:setTarget(nil)
    local enemy = state.enemy and Monster(state.enemy)
    if enemy then enemy:remove() end
    check(N.skill(player, 'Defence') > 1 and N.skill(player, 'Recovery') > 1, 'universal progression')
    -- Incoming damage actually passes through the health-change/Defence hook.
    local position = player:getPosition()
    check(position.x == 1010 and position.y == 1037, 'unplanned respawn during weapon trials: ' .. position.x .. ',' .. position.y)
    local before = player:getHealth()
    local mob = assert(Game.createMonster('Field Hare', Position(1011,1037,7), false, true))
    local accepted = doTargetCombatHealth(mob, player, COMBAT_PHYSICALDAMAGE, -50, -50, CONST_ME_NONE)
    check(player:getHealth() < before and before - player:getHealth() < 50, 'native defence mitigation: before=' .. before .. ', after=' .. player:getHealth() .. ', accepted=' .. tostring(accepted) .. ', manaShield=' .. tostring(player:hasCondition(CONDITION_MANASHIELD)) .. ', mana=' .. player:getMana())
    check(N.heal(player, player), 'native consumable healing')
    check(not N.heal(player, player), 'healing cooldown')
    -- A native monster death credits fractional canonical XP and native loot.
    state.xp, state.fraction, state.level = player:getExperience(), N.kv(player):get('xp-fraction') or 0, player:getLevel()
    state.rewardEnemy, state.rewardAt = mob:getId(), systemTime()
    doTargetCombatHealth(player, mob, COMBAT_PHYSICALDAMAGE, -99999, -99999, CONST_ME_NONE)
    state.awaitReward = true
end
local function verifyReward(player, state)
    local pending = Monster(state.rewardEnemy)
    if pending then
        check(systemTime() - state.rewardAt < 8000, 'native kill pending: HP=' .. pending:getHealth())
        return false
    end
    local actual = player:getExperience() - state.xp + (N.kv(player):get('xp-fraction') or 0) - state.fraction
    local expected = D.mobs['field hare'].stats.raw_xp_reward_total * N.math.content(state.level,1).xp
    check(math.abs(actual - expected) < 1e-7, 'native kill XP/relevance/fraction: actual=' .. actual .. ', expected=' .. expected)
    local corpse = Tile(Position(1011,1037,7)):getItemById(D.mobs['field hare'].corpse)
    check(corpse and corpse:isContainer() and corpse:getSize() > 0, 'native corpse/container loot')
    check(player:save(), 'online character transaction')
    state.expectedXP, state.expectedFamily = player:getExperience(), N.weapon(player).weapon_family
    state.expectedSkill = N.skill(player,state.expectedFamily)
    state.deaths = 0
    state.verifyDeath = true
    local enemy = assert(Game.createMonster('Feral Hog',Position(1011,1037,7),false,true))
    doTargetCombatHealth(enemy,player,COMBAT_PHYSICALDAMAGE,-999999,-999999,CONST_ME_NONE)
    enemy:remove()
    return true
end
local event = CreatureEvent('NostalgiaLiveTest')
event.onThink = function(player, interval)
    local id, at = player:getId(), systemTime()
    local state = states[id]
    if not state then
        state = {at=at, phase=0, families={}}
        states[id] = state
        for _, item in pairs(D.items) do
            if item.server_id and item.category == 'weapon' and item.required_level == 1 and item.class_name == N.class(player) then
                state.families[#state.families+1] = item
            end
        end
        table.sort(state.families, function(a,b) return a.weapon_family < b.weapon_family end)
        check(#state.families == 3, 'three class weapon families')
        N.kv(player):set('resource',100)
        check(not N.spend(player) and N.kv(player):get('resource') == 100, 'safe-area spend blocked without cost')
        return true
    end
    if state.verifyDeath then
        local pos = player:getPosition()
        check(pos.x == 1008 and pos.y == 1010 and pos.z == 7, 'native safe-area respawn')
        check(player:getExperience() == state.expectedXP and N.weapon(player).weapon_family == state.expectedFamily
            and N.skill(player,state.expectedFamily) == state.expectedSkill, 'no PvE progression or equipment loss')
        check(player:getHealth() == player:getMaxHealth(), 'respawn restores HP')
        state.deaths = state.deaths + 1
        if state.deaths < 2 then
            player:teleportTo(Position(1010,1037,7),true)
            local enemy = assert(Game.createMonster('Feral Hog',Position(1011,1037,7),false,true))
            doTargetCombatHealth(enemy,player,COMBAT_PHYSICALDAMAGE,-999999,-999999,CONST_ME_NONE)
            enemy:remove()
        else
            N.kv(player):set('fixture-live-final', json.encode(persistence.capture(player)))
            check(player:save(), 'post-death online save')
            logger.info('NOSTALGIA LIVE CLASS PASS: ' .. N.class(player) .. '; two deaths/returns without loss')
            player:sendExtendedOpcode(122, 'class-pass')
            state.verifyDeath, state.done = false, true
        end
        return true
    end
    if state.awaitReward then state.awaitReward = not verifyReward(player,state); return true end
    if state.done or at - state.at < 6000 then return true end
    if state.phase > 0 then
        local mob = state.enemy and Monster(state.enemy)
        check(mob and mob:getHealth() < state.health, 'accepted native attack: ' .. state.family.weapon_family)
        local supply = N.supply(state.family.weapon_family)
        check(player:getItemCount(supply.server_id) < state.stock, 'actual supply consumption: ' .. state.family.weapon_family)
        check(N.skill(player,state.family.weapon_family) > state.skill, 'family progression: ' .. state.family.weapon_family)
        check((N.kv(player):get('resource') or 0) > 0, 'time-based role resource generation')
        player:setTarget(nil)
        mob:remove()
    else
        check(player:teleportTo(Position(1010,1037,7), true), 'native sandbox hunting position')
        player:setStamina(0) -- Nostalgia has no Tibia stamina gating or bonus.
        player:addHealth(-30)
    end
    state.phase = state.phase + 1
    if state.phase > #state.families then finish(player, state); return true end
    local old, oldItem = N.weapon(player)
    if oldItem then oldItem:remove(1) end
    state.family = state.families[state.phase]
    check(player:addItem(state.family.server_id,1,false,1,CONST_SLOT_LEFT), 'equip real family weapon')
    state.stock = player:getItemCount(N.supply(state.family.weapon_family).server_id)
    state.skill = N.skill(player,state.family.weapon_family)
    -- A low-pressure real species with fixture HP survives each family window.
    local mob = assert(Game.createMonster('Burrow Grazer', Position(1011,1037,7), false, true))
    mob:setMaxHealth(500)
    mob:addHealth(500)
    state.enemy, state.health = mob:getId(), mob:getHealth()
    check(player:setTarget(mob), 'native combat target')
    if N.class(player) == 'Medic' then player:addHealth(-80) end
    N.kv(player):set('resource',100)
    check(N.spend(player) and N.kv(player):get('resource') == 0, 'native class resource spend')
    check(not N.spend(player), 'resource cannot be spent twice')
    state.at = at
    return true
end
event:register()
