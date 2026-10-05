-- Map and playable Tester smoke checks, enabled only by the QA test runner.
local N = Nostalgia
local destinations = dofile('data-canary/lib/nostalgia/qa-destinations.lua')
local capture = dofile('tests/nostalgia/persistence.lua').capture
local states, checks = {}, 0
local function check(value, message) assert(value, 'QA: ' .. message); checks=checks+1 end
local startup = GlobalEvent('NostalgiaQAMap')
startup.onStartup = function()
    for y=976,1055 do for x=976,1071 do
        check(Tile(Position(x,y,7)):getGround()~=nil,'surface ground at ' .. x .. ',' .. y)
    end end
    for name,p in pairs(destinations) do
        local tile=Tile(Position(p.x,p.y,p.z))
        check(tile and tile:getGround(),name .. ' has native ground')
        check(not tile:hasFlag(TILESTATE_BLOCKSOLID),name .. ' is walkable')
    end
    check(Tile(Position(1008,1010,7)):getGround():getId()==409,'shelter uses 15.25 flooring, never ring 406')
    check(Tile(Position(1008,1010,7)):hasFlag(TILESTATE_PROTECTIONZONE),'safe spawn')
    local chest=Tile(Position(1006,1009,7)):getItemById(2472)
    check(chest and chest:isContainer() and chest:getSize()==3,'native supply/loot chest contents')
    check(not Position(1034,1010,7):isSightClear(Position(1040,1010,7)),'ranged divider blocks sight')
    check(Position(1030,1011,7):isSightClear(Position(1030,1006,7)),'clear ranged lane')
    check(Tile(Position(1059,1020,7)):getItemById(1629),'native closed door')
    logger.info('NOSTALGIA QA MAP PASS: ' .. checks .. ' map/destination checks.')
    return true
end
startup:register()
local login = CreatureEvent('NostalgiaQALogin')
login.onLogin = function(player)
    if not player:getName():match(' Tester$') then return true end
    local p=player:getPosition()
    states[player:getId()]={position={x=p.x,y=p.y,z=p.z}}
    player:registerEvent('NostalgiaQALogout')
    player:registerEvent('NostalgiaQARequest')
    return true
end
login:register()
local logout=CreatureEvent('NostalgiaQALogout')
logout.onLogout=function(player)
    local state=states[player:getId()]
    if state then
        player:teleportTo(Position(state.position.x,state.position.y,state.position.z),true)
        states[player:getId()]=nil
    end
    return true
end
logout:register()
local request=CreatureEvent('NostalgiaQARequest')
request.onExtendedOpcode=function(player,code,buffer)
    if code~=123 or not states[player:getId()] then return true end
    if buffer=='floors' then
        -- Other login handlers finish normal idempotent starter provisioning
        -- before this client request. Smoke actions must preserve that state.
        states[player:getId()].before=capture(player)
        player:teleportTo(Position(983,1014,7),true)
        check(player:move(DIRECTION_NORTH)==RETURNVALUE_NOERROR,'native upward stairs')
        check(player:getPosition().z==6,'arrived upstairs')
        player:move(DIRECTION_SOUTH)
        check(player:getPosition().z==7,'native downward stairs')
        player:teleportTo(Position(984,1049,7),true)
        player:move(DIRECTION_SOUTH)
        check(player:getPosition().z==8,'native cellar descent')
        player:move(DIRECTION_NORTH)
        check(player:getPosition().z==7,'native cellar ascent')
        player:teleportTo(Position(1008,1010,7),true)
        player:sendExtendedOpcode(123,'floors-pass')
    elseif buffer=='finish' then
        local before,after=states[player:getId()].before,capture(player)
        check(after.level==before.level and after.xp==before.xp,'Tester Level/XP preserved')
        for slot,value in ipairs(before.inventory) do check(after.inventory[slot]==value,'Tester equipment/container unchanged') end
        for key,value in pairs(before.progression) do check(after.progression[key]==value,'Tester progression unchanged: ' .. key) end
        logger.info('NOSTALGIA QA TESTER PASS: ' .. player:getName() .. ', state preserved, native floors/travel/UI.')
        player:sendExtendedOpcode(123,'tester-pass')
    end
    return true
end
request:register()
