SurvivorSignal = SurvivorSignal or {}
local S = SurvivorSignal
S.module = "ZomputSurvivorSignal"
S.item = "SurvivorSignal.PhoneDevice"
S.legacyItem = "SurvivorSignal.Phone"

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
