require "SurvivorSignal/Shared"
local S = SurvivorSignal
local ticks = 0
local lastRequest = {}
local pending = setmetatable({}, {__mode="k"})
local function state()
    local data = ModData.getOrCreate(S.module)
    data.used = data.used or {}
    return data
end
local function reply(p, command, args)
    sendServerCommand(p, S.module, command, args)
end
function S.migrate(p, container, depth)
    container = container or p:getInventory()
    depth = depth or 0
    if depth > 16 then return end
    local items = container:getItems()
    -- Backward iteration: replacing one legacy item must not skip a neighbour.
    for i=items:size()-1,0,-1 do
        local old = items:get(i)
        if old:getFullType() == S.legacyItem and not old:isEquipped() then
            local device = instanceItem(S.item)
            if device then
                device:setCondition(old:getCondition())
                device:setFavorite(old:isFavorite())
                if old:isCustomName() then device:setName(old:getName()); device:setCustomName(true) end
                device:getDeviceData():setHasBattery(true)
                device:getDeviceData():setPower(1)
                container:AddItem(device)
                device:SynchSpawn()
                container:Remove(old)
                sendRemoveItemFromContainer(container, old)
            end
        elseif old:IsInventoryContainer() then S.migrate(p, old:getInventory(), depth + 1) end
    end
end

function S.grant(p)
    if not S.alive(p) then return end
    S.migrate(p)
    local md = p:getModData()
    if S.phone(p:getInventory(), true) then md.SurvivorSignalGranted = true end
    if md.SurvivorSignalGranted then return true end
    -- Reserve before item creation; use the native spawn path exactly once.
    md.SurvivorSignalGranted = true
    local item = p:getInventory():AddItem(S.item)
    if not item then md.SurvivorSignalGranted = nil; return end
    item:getDeviceData():setHasBattery(true)
    item:getDeviceData():setPower(1)
    item:SynchSpawn()
    return true
end

function S.changeBattery(p, args)
    if not S.alive(p) or type(args) ~= "table" or not S.itemId(args.phoneId) then return end
    local inventory = p:getInventory()
    local phone = inventory:getItemWithIDRecursiv(args.phoneId)
    if not phone or phone:getFullType() ~= S.item then return end
    local data = phone:getDeviceData()
    if args.remove == true then
        if data:getHasBattery() then data:getBattery(inventory) end
        return
    end
    if not S.itemId(args.batteryId) then return end
    local battery = inventory:getItemWithIDRecursiv(args.batteryId)
    if not battery or battery:getFullType() ~= "Base.Battery" or battery:isFavorite()
        or battery:getCurrentUsesFloat() <= 0 then return end
    if data:getHasBattery() and data:getPower() >= 0.999 then return end
    -- Native device methods preserve the removed battery's charge and synchronize
    -- creation/removal. Never create a second copy with a manual network packet.
    if data:getHasBattery() then data:getBattery(inventory) end
    data:addBattery(battery)
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
    local device = phone:getDeviceData()
    device:setPower(math.max(0, device:getPower()-0.03))
    device:transmitBatteryChangeServer()
    sendItemStats(phone)
    reply(p, "result", {day=today, rows=rows, condition=phone:getCondition(),
        power=math.floor(S.power(phone)*100+0.5), playerNum=p:getPlayerNum(), username=name})
end
Events.OnClientCommand.Add(function(module, command, p, args)
    if module ~= S.module or not p then return end
    if command == "starter" then
        if not S.alive(p) then return end
        if type(args)=="table" and (args.hasPhone==true or args.granted==true) then
            p:getModData().SurvivorSignalGranted=true
        end
        if not pending[p] then pending[p]=ticks end
        return
    end
    if command == "battery" then
        local name = p:getUsername()
        if lastRequest[name] and ticks-lastRequest[name] < 30 then return end
        lastRequest[name]=ticks
        S.changeBattery(p,args)
        return
    end
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
    for i=0,players:size()-1 do
        local p=players:get(i)
        if S.alive(p) then S.migrate(p) end
        if S.alive(p) and pending[p] and ticks-pending[p] >= 120 and S.grant(p) then
            pending[p]=nil
            reply(p,"starterAck",{username=p:getUsername()})
        end
    end
end)
