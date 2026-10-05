local N, D = Nostalgia, Nostalgia.math.data
local npcType = Game.createNpcType('Quartermaster')
local keywordHandler = KeywordHandler:new()
local handler = NpcHandler:new(keywordHandler)
local stock = {}
for _, item in pairs(D.items) do
    if item.server_id then
        local level = item.required_level or item.source_level or 1
        local price = item.shop_price
        stock[#stock + 1] = {itemName=item.display_name, clientId=item.server_id, buy=price, sell=math.max(1, math.floor(price / 4))}
    end
end
table.sort(stock, function(a, b) return a.clientId < b.clientId end)
local config = {
    name='Quartermaster', description='the shelter quartermaster', health=100, maxHealth=100,
    walkInterval=2000, walkRadius=0, outfit={lookType=128, lookHead=95, lookBody=85, lookLegs=76, lookFeet=95},
    flags={floorchange=false}, shop=stock,
}
npcType.onThink = function(npc, interval) handler:onThink(npc, interval) end
npcType.onAppear = function(npc, creature) handler:onAppear(npc, creature) end
npcType.onDisappear = function(npc, creature) handler:onDisappear(npc, creature) end
npcType.onMove = function(npc, creature, from, to) handler:onMove(npc, creature, from, to) end
npcType.onSay = function(npc, creature, kind, message) handler:onSay(npc, creature, kind, message) end
npcType.onCloseChannel = function(npc, player) handler:onCloseChannel(npc, player) end
npcType.onBuyItem = function(npc, player, itemId, subType, amount, ignore, backpacks)
    npc:sellItem(player, itemId, amount, subType, 0, ignore, backpacks)
end
npcType.onSellItem = function(npc, player, itemId, subtype, amount, ignore, name, cost)
    player:sendTextMessage(MESSAGE_TRADE, string.format('Sold %dx %s for %d credits.', amount, name, cost))
end
npcType.onCheckItem = function() end
handler:setMessage(MESSAGE_GREET, 'Welcome to the Meridian shelter. Ask for {trade}: all twelve weapon families, early upgrades, armour, class rigs, dressings and supplies. Hunt the fields to the east; return here after injury.')
handler:setMessage(MESSAGE_FAREWELL, 'Keep your supplies stocked. Your chosen family grows through use.')
handler:addModule(FocusModule:new(), config.name, true, true, true)
npcType:register(config)
