require "SurvivorSignal/Shared"
local S = SurvivorSignal
local ticks = 0
local lastRequest = {}
local function state()
    local data = ModData.getOrCreate(S.module)
    data.used = data.used or {}
    return data
end
local function reply(p, command, args)
    sendServerCommand(p, S.module, command, args)
end
local function grant(p)
    if not S.alive(p) then return end
    local md = p:getModData()
    if md.SurvivorSignalGranted then return end
    local item = p:getInventory():AddItem(S.item)
    if not item then return end
    md.SurvivorSignalGranted = true
    sendAddItemToContainer(p:getInventory(), item)
end
function S.scan(p)
    if not S.alive(p) then return end
    local phone = S.phone(p:getInventory())
    if not phone then reply(p, "error", {key="NoPhone"}); return end
    local data, today = state(), S.day()
    local name = p:getUsername()
    if data.used[name] == today then reply(p, "error", {key="Used"}); return end
    -- Nothing supplied by the client determines identity, position, cost or cooldown.
    local rows = {}
    local players = getOnlinePlayers()
    for i=0,players:size()-1 do
        local other = players:get(i)
        if other ~= p and S.alive(other) and S.phone(other:getInventory())
                and not other:isInvisible() then
            rows[#rows+1] = {name=other:getUsername(), x=math.floor(other:getX()),
                y=math.floor(other:getY()), z=math.floor(other:getZ())}
        end
    end
    table.sort(rows, function(a,b) return a.name < b.name end)
    -- Reserve the account's day before the reply, including empty scans and final use.
    data.used[name] = today
    phone:setCondition(math.max(0, phone:getCondition()-S.loss()))
    sendItemStats(phone)
    reply(p, "result", {day=today, rows=rows, condition=phone:getCondition(),
        playerNum=p:getPlayerNum()})
end
Events.OnClientCommand.Add(function(module, command, p, args)
    if module ~= S.module or not p then return end
    if command == "scan" then
        local name = p:getUsername()
        if lastRequest[name] and ticks-lastRequest[name] < 30 then return end
        lastRequest[name] = ticks
        S.scan(p)
    end
end)
Events.OnServerStarted.Add(function()
    print("[ZomputSurvivorSignal] ready; durability loss="..S.loss().."%")
end)
-- Dedicated-server starter grants, also covering existing saves and reconnects.
Events.OnTick.Add(function()
    ticks = ticks+1
    if ticks % 120 ~= 0 then return end
    local players = getOnlinePlayers()
    for i=0,players:size()-1 do grant(players:get(i)) end
end)
