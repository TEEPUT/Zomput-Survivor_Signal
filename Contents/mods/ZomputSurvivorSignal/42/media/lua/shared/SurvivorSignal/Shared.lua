SurvivorSignal = SurvivorSignal or {}
local S = SurvivorSignal
S.module = "ZomputSurvivorSignal"
S.item = "SurvivorSignal.Phone"

function S.day()
    local t = getGameTime()
    return string.format("%04d-%02d-%02d", t:getYear(), t:getMonth()+1, t:getDay()+1)
end

-- Only inventory and carried bags; never floors, vehicle seats, or nearby containers.
function S.phone(container, includeBroken)
    if not container then return nil end
    local items = container:getItems()
    for i=0,items:size()-1 do
        local item = items:get(i)
        if item:getFullType() == S.item and (includeBroken or item:getCondition() > 0) then return item end
        if item:IsInventoryContainer() then
            local phone = S.phone(item:getInventory(), includeBroken)
            if phone then return phone end
        end
    end
end

function S.loss()
    local n = tonumber(SandboxVars and SandboxVars.SurvivorSignal and SandboxVars.SurvivorSignal.DurabilityLoss) or 3
    if n ~= n then n = 3 end
    return math.max(0, math.min(100, math.floor(n)))
end

function S.alive(p)
    return p and not p:isDead() and p:getHealth() > 0
end
