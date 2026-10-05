local N, D = Nostalgia, Nostalgia.math.data

local think = CreatureEvent('NostalgiaThink')
think.onThink = function(player, interval) N.think(player, interval); return true end
think:register()
local health = CreatureEvent('NostalgiaHealth')
health.onHealthChange = N.healthChange
health:register()
local advance = CreatureEvent('NostalgiaAdvance')
advance.onAdvance = function(player, skill)
    if N.class(player) and skill == SKILL_LEVEL then
        N.refresh(player)
        player:addHealth(player:getMaxHealth())
        N.snapshot(player)
    end
    return true
end
advance:register()
local death = CreatureEvent('NostalgiaDeath')
death.onDeath = function(player)
    if N.class(player) then
        N.sessions[player:getId()] = {guid=player:getGuid()}
        player:setDropLoot(false)
        player:setSkillLoss(false)
    end
    return true
end
death:register()
local logout = CreatureEvent('NostalgiaLogout')
logout.onLogout = function(player)
    if N.class(player) then N.sessions[player:getId()] = nil end
    return true
end
logout:register()
local opcode = CreatureEvent('NostalgiaOpcode')
opcode.onExtendedOpcode = function(player, code, buffer)
    if code ~= N.opcode or not N.class(player) then return true end
    if buffer == 'spend' then N.spend(player) elseif buffer == 'stats' then N.snapshot(player) end
    return true
end
opcode:register()
local spend = TalkAction('!resource')
spend.onSay = function(player) N.spend(player); return false end
spend:separator(' ')
spend:groupType('normal')
spend:register()
local stats = TalkAction('!nostalgia')
stats.onSay = function(player)
    local snapshot = N.snapshot(player)
    if snapshot then player:sendTextMessage(MESSAGE_LOOK, json.encode(snapshot)) end
    return false
end
stats:groupType('normal')
stats:register()

for _, item in pairs(D.items) do
    if item.server_id and item.category == 'weapon' then
        local weapon = Weapon(WEAPON_WAND)
        weapon:id(item.server_id)
        weapon:level(item.required_level)
        weapon:range(item.class_name == 'Bastion' and 1 or 7)
        weapon:mana(0)
        weapon:damage(0, 0)
        weapon.onUseWeapon = N.attack
        weapon:register()
    elseif item.server_id and item.category == 'medical' then
        local action = Action()
        action:id(item.server_id)
        action.onUse = function(player, usedItem, fromPosition, target)
            if not N.class(player) then return false end
            -- Use-on-self can resolve to an item/ground target, which has no
            -- isPlayer method. Only creature targets can select a recipient.
            local recipient = target and target.isPlayer and target:isPlayer() and target or player
            if N.heal(player, recipient) then usedItem:remove(1); return true end
            return false
        end
        action:register()
    end
end

for name, row in pairs(D.mobs) do
    local monsterType = Game.createMonsterType(row.name)
    local interval = D.balance.combat.stochastic.enemy_attack_interval[row.archetype]
    local stats = row.stats
    local damage = stats.total_pre_mitigation_dps * interval
    local variation = D.balance.combat.stochastic.enemy_hit_variance
    -- Native coins are integer units. Scale canonical economic value into cents,
    -- then split platinum/gold stacks so corpses remain practical containers.
    local value = stats.loot_value_reward_total * D.currency_scale
    local platinum = math.floor(value / 100)
    local gold = value - platinum * 100
    local loot = {}
    if platinum > 0 then loot[#loot+1] = {id=3035,chance=100000,maxCount=platinum * 2 - 1} end
    if gold > 0 then loot[#loot+1] = {id=3031,chance=math.min(100000,math.floor(gold * 100000)),maxCount=math.max(1,math.floor(gold * 2 - 1))} end
    loot[#loot+1] = {id=D.items['MED-01'].server_id,chance=12000,maxCount=2}
    for _, item in pairs(D.items) do
        if item.server_id and item.category == 'supply' then loot[#loot+1]={id=item.server_id,chance=2500,maxCount=5} end
        if item.server_id and item.category == 'weapon' and item.required_level == 1 and row.content_level >= 7 then
            loot[#loot+1]={id=item.server_id,chance=300,maxCount=1}
        end
    end
    monsterType:register({
        description = 'a ' .. row.name:lower(),
        experience = math.max(1, math.ceil(stats.raw_xp_reward_total * D.xp_scale)),
        outfit = {lookType=row.lookType},
        health = math.max(1, math.floor(stats.total_hp + 0.5)),
        maxHealth = math.max(1, math.floor(stats.total_hp + 0.5)),
        race = 'blood', corpse = row.corpse, speed = 85,
        changeTarget = {interval=4000, chance=10},
        strategiesTarget = {nearest=70, mostDamage=30},
        flags = {summonable=false, attackable=true, hostile=true, convinceable=false,
            pushable=true, canPushItems=false, canPushCreatures=false, staticAttackChance=90,
            targetDistance=1, runHealth=row.id == 'field_hare' and 3 or 0},
        attacks = {{name='melee', interval=interval * 1000, chance=100,
            minDamage=-math.max(1, math.floor(damage * (1 - variation))),
            maxDamage=-math.max(1, math.floor(damage * (1 + variation)))}},
        defenses = {defense=0, armor=0},
        loot = loot,
    })
end

-- Explicit opt-in, isolated native-engine fixtures; normal startup never runs tests.
if os.getenv('NOSTALGIA_TEST') == '1' then
    local event = GlobalEvent('NostalgiaEngineTests')
    event.onStartup = function() return dofile('tests/nostalgia/engine.lua') end
    event:register()
end
if os.getenv('NOSTALGIA_LIVE_TEST') == '1' then dofile('tests/nostalgia/live.lua') end
if os.getenv('NOSTALGIA_QA_TEST') == '1' then dofile('tests/nostalgia/qa.lua') end
