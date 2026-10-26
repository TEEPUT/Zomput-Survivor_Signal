require "SurvivorSignal/Shared"
local S = SurvivorSignal
local ticks = 0
local lastRequest = setmetatable({}, {__mode="k"})
local pending = setmetatable({}, {__mode="k"})
local characterBindings = setmetatable({}, {__mode="k"})
local function characterKey(p)
    local key=characterBindings[p]
    if not key then key=S.characterKey(p); characterBindings[p]=key end
    return key
end
local function state()
    local data = ModData.getOrCreate(S.module)
    data.characters = data.characters or {}
    return data
end
function S.characterState(p)
    local key = characterKey(p)
    if not key then return nil end
    local data, name = state(), p:getUsername()
    data.characters[name] = data.characters[name] or {}
    local characters = data.characters[name]
    local record = characters[key]
    local age = p:getHoursSurvived()
    -- Also guard native ID reuse after a death or a new life with a lower age.
    if not record or record.dead or (record.age and age+0.01 < record.age) then
        record = {history={}}
        characters[key] = record
    end
    record.age = age
    return record
end
local function noteDeath(p)
    if not p or not p:isDead() then return end
    local key = characterKey(p)
    local characters = state().characters[p:getUsername()]
    if key and characters and characters[key] then characters[key].dead=true end
end
local function allowRequest(p, command)
    local requests = lastRequest[p] or {}
    lastRequest[p] = requests
    if requests[command] and ticks-requests[command] < 30 then return false end
    requests[command] = ticks
    return true
end
local function reply(p, command, args)
    sendServerCommand(p, S.module, command, args)
end
local function replyRecord(p, saved, index, count)
    reply(p, "result", {day=saved.day, time=saved.time, rows=saved.rows,
        phoneId=saved.phoneId, condition=saved.condition, power=saved.power,
        originX=saved.originX, originY=saved.originY,
        playerNum=p:getPlayerNum(), username=p:getUsername(), characterId=characterKey(p),
        historyIndex=index, historyCount=count})
end
function S.readHistory(p, args)
    if not S.alive(p) then return end
    if not S.phone(p:getInventory(), true) then reply(p,"error",{key="CarryPhone"}); return end
    local record = S.characterState(p)
    if not record then reply(p,"error",{key="CharacterNotReady"}); return end
    local index = type(args)=="table" and args.index or 1
    if index == nil then index=1 end
    if type(index)~="number" or index~=math.floor(index) or index<1 or index>#record.history then
        reply(p,"error",{key="NoHistory"}); return
    end
    replyRecord(p, record.history[index], index, #record.history)
end
function S.syncDevice(p, phone)
    local data=phone:getDeviceData()
    reply(p,"deviceState",{username=p:getUsername(),phoneId=phone:getID(),
        condition=phone:getCondition(),hasBattery=data:getHasBattery(),power=data:getPower()})
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
        S.syncDevice(p,phone)
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
    S.syncDevice(p,phone)
end
function S.scan(p)
    if not S.alive(p) then return end
    local phone = S.phone(p:getInventory())
    if not phone then reply(p, "error", {key="NoPhone"}); return end
    local record, today = S.characterState(p), S.day()
    if not record then reply(p,"error",{key="CharacterNotReady"}); return end
    if record.lastDay == today then reply(p, "error", {key="Used"}); return end
    -- Nothing supplied by the client determines identity, position, cost or cooldown.
    local rows = {}
    local players = getOnlinePlayers()
    for i=0,players:size()-1 do
        local other = players:get(i)
        if other ~= p and S.alive(other) and S.phone(other:getInventory())
                and not other:isInvisible() then
            rows[#rows+1] = {name=other:getUsername(), x=other:getX(),
                y=other:getY(), z=math.floor(other:getZ())}
        end
    end
    table.sort(rows, function(a,b) return a.name < b.name end)
    -- Reserve this character's day, including empty scans and final use.
    record.lastDay = today
    phone:setCondition(math.max(0, phone:getCondition()-S.loss()))
    local device = phone:getDeviceData()
    device:setPower(math.max(0, device:getPower()-0.03))
    device:transmitBatteryChangeServer()
    sendItemStats(phone)
    S.syncDevice(p,phone)
    local t=getGameTime()
    local saved={day=today,time=string.format("%02d:%02d",t:getHour(),t:getMinutes()),
        rows=rows,phoneId=phone:getID(),condition=phone:getCondition(),
        power=math.floor(S.power(phone)*100+0.5),originX=p:getX(),originY=p:getY()}
    table.insert(record.history,1,saved)
    while #record.history>S.historyLimit do table.remove(record.history) end
    replyRecord(p,saved,1,#record.history)
end
Events.OnClientCommand.Add(function(module, command, p, args)
    if module ~= S.module or not p then return end
    if command == "starter" then
        if not S.alive(p) then return end
        if not characterBindings[p] and type(args)=="table" and S.validLifeId(args.lifeId) then
            local md=p:getModData()
            if not S.validLifeId(md.SurvivorSignalLifeId) then md.SurvivorSignalLifeId=args.lifeId end
            characterBindings[p]=S.characterKey(p)
        end
        if type(args)=="table" and (args.hasPhone==true or args.granted==true) then
            p:getModData().SurvivorSignalGranted=true
        end
        if not pending[p] then pending[p]=ticks end
        return
    end
    if command == "battery" then
        if not allowRequest(p,command) then return end
        S.changeBattery(p,args)
        return
    end
    if command == "scan" then
        if not allowRequest(p,command) then return end
        S.scan(p)
    elseif command == "history" then
        if allowRequest(p,command) then S.readHistory(p,args) end
    end
end)
Events.OnPlayerDeath.Add(noteDeath)
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
        noteDeath(p)
        if S.alive(p) then S.migrate(p) end
        if S.alive(p) and pending[p] and ticks-pending[p] >= 120 and S.grant(p) then
            pending[p]=nil
            reply(p,"starterAck",{username=p:getUsername()})
        end
    end
end)
