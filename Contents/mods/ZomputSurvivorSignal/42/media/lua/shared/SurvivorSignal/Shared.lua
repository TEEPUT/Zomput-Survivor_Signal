SurvivorSignal = SurvivorSignal or {}
local S = SurvivorSignal
S.module = "ZomputSurvivorSignal"
S.item = "SurvivorSignal.PhoneDevice"
S.legacyItem = "SurvivorSignal.Phone"
S.historyLimit = 7

function S.validLifeId(id)
    return type(id)=="string" and #id==36
        and id:match("^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$")~=nil
end

-- UUID lives in the character save, so native descriptor counters may safely restart.
-- The server binds it once at character initialization and owns all scan/history data.
function S.characterKey(p)
    local lifeId=p and p:getModData().SurvivorSignalLifeId
    if S.validLifeId(lifeId) then return "life:"..lifeId end
    -- Compatibility for characters initialized by an older client.
    local descriptor = p and p:getDescriptor()
    local id = descriptor and descriptor:getID()
    if type(id) ~= "number" or id ~= id or id < 0 or id ~= math.floor(id) then return nil end
    return tostring(id)
end

function S.isPhone(item)
    return item and (item:getFullType() == S.item or item:getFullType() == S.legacyItem)
end

function S.power(item)
    if not item or item:getFullType() ~= S.item then return 0 end
    local data = item:getDeviceData()
    if not data or not data:getHasBattery() then return 0 end
    return data:getPower()
end

function S.itemId(value)
    return type(value)=="number" and value==math.floor(value) and value>=-2147483648 and value<=2147483647
end

function S.status(condition, power)
    return getText("IGUI_SurvivorSignal_ConditionLabel")..": "..tostring(condition).."% | "
        ..getText("IGUI_SurvivorSignal_BatteryLabel")..": "..tostring(power).."%"
end

-- Native radio packets cannot address an unequipped device inside a bag.
-- Resolve by owned recursive item ID, without echoing a client radio packet.
function S.applyDeviceState(p, args)
    if not p or type(args)~="table" or not S.itemId(args.phoneId)
        or type(args.power)~="number" or args.power~=args.power
        or type(args.condition)~="number" or args.condition~=args.condition then return false end
    local phone=p:getInventory():getItemWithIDRecursiv(args.phoneId)
    if not phone or phone:getFullType()~=S.item then return false end
    local data=phone:getDeviceData()
    data:setHasBattery(args.hasBattery==true)
    data:setPower(args.hasBattery==true and math.max(0,math.min(1,args.power)) or 0)
    phone:setCondition(math.max(0,math.min(phone:getConditionMax(),args.condition)))
    return true
end

-- One horizontal world tile is one metre. Map north is -Y, east is +X;
-- the character's facing and the isometric screen rotation do not affect this.
function S.relativeLocation(originX, originY, targetX, targetY)
    local dx, dy = targetX-originX, targetY-originY
    local distance = math.floor(math.sqrt(dx*dx+dy*dy)+0.5)
    if dx == 0 and dy == 0 then return distance, "Here" end
    local ax, ay = math.abs(dx), math.abs(dy)
    local boundary = math.sqrt(2)-1 -- nearest of eight 45-degree compass sectors
    if ay <= ax*boundary then return distance, dx > 0 and "E" or "W" end
    if ax <= ay*boundary then return distance, dy > 0 and "S" or "N" end
    if dy < 0 then return distance, dx > 0 and "NE" or "NW" end
    return distance, dx > 0 and "SE" or "SW"
end

function S.day()
    local t = getGameTime()
    return string.format("%04d-%02d-%02d", t:getYear(), t:getMonth()+1, t:getDay()+1)
end

-- Only inventory and carried bags; never floors, vehicle seats, or nearby containers.
function S.phone(container, includeBroken, depth)
    if not container then return nil end
    depth = depth or 0
    if depth > 16 then return nil end
    local items = container:getItems()
    for i=0,items:size()-1 do
        local item = items:get(i)
        if S.isPhone(item) and (includeBroken or (item:getCondition() > 0 and S.power(item) > 0)) then return item end
        if item:IsInventoryContainer() then
            local phone = S.phone(item:getInventory(), includeBroken, depth + 1)
            if phone then return phone end
        end
    end
end

function S.battery(container, depth)
    if not container or (depth or 0) > 16 then return nil end
    local items, best = container:getItems(), nil
    for i=0,items:size()-1 do
        local item = items:get(i)
        local candidate
        if item:getFullType() == "Base.Battery" and not item:isFavorite() and item:getCurrentUsesFloat() > 0 then
            candidate = item
        elseif item:IsInventoryContainer() then candidate = S.battery(item:getInventory(), (depth or 0) + 1) end
        if candidate and (not best or candidate:getCurrentUsesFloat() > best:getCurrentUsesFloat()) then best = candidate end
    end
    return best
end

function S.loss()
    local n = tonumber(SandboxVars and SandboxVars.SurvivorSignal and SandboxVars.SurvivorSignal.DurabilityLoss) or 3
    if n ~= n then n = 3 end
    return math.max(0, math.min(100, math.floor(n)))
end

function S.alive(p)
    return p and not p:isDead() and p:getHealth() > 0
end
