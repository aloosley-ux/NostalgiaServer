-- Local QA convenience only: explicit Tester allowlist, no GM promotion/reset.
local destinations = dofile('data-canary/lib/nostalgia/qa-destinations.lua')
local testers = {['Bastion Tester']=true,['Medic Tester']=true,
    ['Ranger Tester']=true,['Assault Tester']=true}
local function allowed(player) return testers[player:getName()] and Nostalgia.class(player) end
-- Native RME recipe authors the chest geometry. Seed empty QA chests only on
-- server startup; normal map saves retain their contents. No character reset.
local supplies=GlobalEvent('NostalgiaQASupplyChests')
supplies.onStartup=function()
    for _,p in ipairs({{1006,1009},{1056,1012}}) do
        local tile=Tile(Position(p[1],p[2],7))
        local chest=tile and tile:getItemById(2472)
        if chest and chest:isContainer() and chest:getSize()==0 then
            chest:addItem(3582,25); chest:addItem(3492,25); chest:addItem(3031,100)
        end
    end
    return true
end
supplies:register()
local function travel(player, name)
    local destination = destinations[name]
    if not destination then return false end
    local position = Position(destination.x,destination.y,destination.z)
    local tile = Tile(position)
    if not tile or not tile:getGround() then
        player:sendCancelMessage('QA destination is unavailable.'); return false
    end
    player:setTarget(nil)
    if not player:teleportTo(position, false) then
        player:sendCancelMessage('QA arrival tile is occupied. Try again.'); return false
    end
    player:sendTextMessage(MESSAGE_LOOK,'QA: ' .. name .. ' (' .. destination.x .. ',' .. destination.y .. ',' .. destination.z .. ').')
    return true
end
local command = TalkAction('!qa')
command.onSay = function(player, words, param)
    if not allowed(player) then player:sendCancelMessage('QA travel is restricted to the four Tester characters.'); return false end
    param = (param or ''):lower():match('^%s*(.-)%s*$')
    if param == '' or param == 'help' then
        local names={}
        for name in pairs(destinations) do names[#names+1]=name end
        table.sort(names)
        player:sendTextMessage(MESSAGE_LOOK,'!qa <destination>: ' .. table.concat(names,', ') .. '. !qa pos shows coordinates. Native PvE death preserves progression/equipment.')
    elseif param == 'pos' then
        local p=player:getPosition()
        player:sendTextMessage(MESSAGE_LOOK,'Position: ' .. p.x .. ',' .. p.y .. ',' .. p.z)
    elseif not travel(player,param) then
        player:sendCancelMessage('Unknown/unavailable QA destination. Use !qa help.')
    end
    return false
end
command:separator(' ')
command:groupType('normal')
command:register()
