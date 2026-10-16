-- Engine-independent regression tests. Run with Lua 5.1+ or fengari.
local root = arg[1] or "Contents/mods/ZomputSurvivorSignal/42/media/lua"
package.path = root.."/shared/?.lua;"..root.."/server/?.lua;"..package.path
local handlers = {}
Events = setmetatable({}, {__index=function(t,k)
    local event={Add=function(fn) handlers[k]=fn end}; rawset(t,k,event); return event
end})
local date = 1
function getGameTime() return {getYear=function() return 1993 end,getMonth=function() return 6 end,getDay=function() return date end} end
SandboxVars={SurvivorSignal={DurabilityLoss=3}}
local storage={}
ModData={getOrCreate=function() return storage end}
local responses={}
function sendServerCommand(p,module,command,args) responses[#responses+1]={command=command,args=args} end
function sendItemStats() end
function sendAddItemToContainer() end
function sendRemoveItemFromContainer() end
local function list(items) return {size=function() return #items end,get=function(_,i) return items[i+1] end} end
local nextID=0
local function phone(condition,fullType)
    nextID=nextID+1
    local data={has=true,power=1}
    function data:getHasBattery() return self.has end
    function data:setHasBattery(value) self.has=value end
    function data:getPower() return self.power end
    function data:setPower(value) self.power=value end
    function data:transmitBatteryChangeServer() end
    function data:getBattery(inv)
        local old=phone(100,'Base.Battery'); old.charge=self.power
        inv:AddItem(old); self.has=false; self.power=0
    end
    function data:addBattery(battery)
        self.power=battery:getCurrentUsesFloat(); self.has=true
        battery.owner:Remove(battery)
    end
    return {getFullType=function() return fullType or 'SurvivorSignal.PhoneDevice' end,
        id=nextID,getID=function(self) return self.id end,
        getDeviceData=function() return data end,
        isFavorite=function(self) return self.favorite or false end,
        setFavorite=function(self,value) self.favorite=value end,
        isEquipped=function(self) return self.equipped or false end,
        isCustomName=function() return false end,
        getCurrentUsesFloat=function(self) return self.charge or 1 end,
        SynchSpawn=function(self) self.spawns=(self.spawns or 0)+1 end,
        getCondition=function(self) return self.condition end,
        setCondition=function(self,n) self.condition=n end,
        IsInventoryContainer=function() return false end,condition=condition}
end
local function inventory(items)
    local inv={getItems=function() return list(items) end}
    function inv:AddItem(value)
        local p=type(value)=='string' and phone(100,value) or value
        items[#items+1]=p; p.owner=self; return p
    end
    function inv:Remove(value) for i=#items,1,-1 do if items[i]==value then table.remove(items,i) end end end
    function inv:getItemWithIDRecursiv(id)
        for _,item in ipairs(items) do
            if item.getID and item:getID()==id then return item end
            if item:IsInventoryContainer() then
                local found=item:getInventory():getItemWithIDRecursiv(id); if found then return found end
            end
        end
    end
    for _,item in ipairs(items) do item.owner=inv end
    return inv
end
function instanceItem(fullType) return phone(100,fullType) end
local function player(name,items)
    local md={}
    return {getUsername=function() return name end,getInventory=function() return inventory(items) end,
        isDead=function(self) return self.dead or false end,getHealth=function() return 100 end,
        isInvisible=function(self) return self.hidden or false end,getModData=function() return md end,
        getX=function() return 123.5 end,getY=function() return 456.7 end,getZ=function() return 1 end,
        getPlayerNum=function() return 0 end}
end
local aPhone,bPhone=phone(100),phone(100)
local a,b=player('A',{aPhone}),player('B',{bPhone})
local empty=player('NoPhone',{})
local players={a,b,empty}
function getOnlinePlayers() return list(players) end
require 'SurvivorSignal/Server'
local function last() return responses[#responses] end
local count=0
local function check(ok,label) assert(ok,label); count=count+1; print('PASS '..label) end
SurvivorSignal.scan(a)
check(aPhone.condition==97,'default three percent cost')
check(#last().args.rows==1 and last().args.rows[1].name=='B','only carried working phone targets')
check(last().args.rows[1].x==123 and last().args.rows[1].z==1,'server position including floor')
check(last().args.username=='A','response identifies requesting split-screen account')
SurvivorSignal.scan(a)
check(last().args.key=='Used' and aPhone.condition==97,'duplicate scan is free and rejected')
a=player('A',{phone(100)})
SurvivorSignal.scan(a)
check(last().args.key=='Used','reconnect / respawn / different phone cannot bypass account day')
date=2; SurvivorSignal.scan(a)
check(last().command=='result','midnight resets daily permission')
SurvivorSignal.scan(empty)
check(last().args.key=='NoPhone' and not storage.used.NoPhone,'no phone does not consume day')
date=3; bPhone.condition=0; players={a,b}; SurvivorSignal.scan(a)
check(#last().args.rows==0,'broken target excluded and empty scan accepted')
date=4; SandboxVars.SurvivorSignal.DurabilityLoss=100; SurvivorSignal.scan(a)
check(last().args.condition==0,'final use clamps durability to zero')
date=5; SurvivorSignal.scan(a)
check(last().args.key=='NoPhone','broken requester rejected')
check(SurvivorSignal.phone(a:getInventory(),true)~=nil,'final-use snapshot can remain while broken phone is carried')
local nestedPhone=phone(50)
local bag={getFullType=function() return 'Base.Bag' end,IsInventoryContainer=function() return true end,getInventory=function() return inventory({nestedPhone}) end}
check(SurvivorSignal.phone(inventory({bag}))==nestedPhone,'nested carried bag supported')
SandboxVars.SurvivorSignal.DurabilityLoss=-9
check(SurvivorSignal.loss()==0,'negative sandbox value clamped')
SandboxVars.SurvivorSignal.DurabilityLoss=999
check(SurvivorSignal.loss()==100,'excess sandbox value clamped')
SandboxVars.SurvivorSignal.DurabilityLoss='invalid'
check(SurvivorSignal.loss()==3,'invalid sandbox value uses default')
local new=player('New',{}); players={new}
handlers.OnClientCommand(SurvivorSignal.module,'starter',new,{})
for i=1,240 do handlers.OnTick() end
check(new:getInventory():getItems():size()==1,'starter grant is idempotent')
date=6; bPhone.condition=100; b.hidden=true; players={new,b}; SurvivorSignal.scan(new)
check(#last().args.rows==0,'invisible administrator excluded')
date=7; b.hidden=false; b.dead=true; SurvivorSignal.scan(new)
check(#last().args.rows==0,'dead target excluded')
date=8; b.dead=false; players={new}; SandboxVars.SurvivorSignal.DurabilityLoss=0
SurvivorSignal.scan(new)
check(last().args.condition==94,'zero-cost setting preserves current condition')
local before=#responses
handlers.OnClientCommand('ForeignModule','scan',new,{})
check(#responses==before,'foreign network module ignored')
handlers.OnClientCommand(SurvivorSignal.module,'scan',new,{x=99,day='forged'})
before=#responses
handlers.OnClientCommand(SurvivorSignal.module,'scan',new,{})
check(#responses==before,'duplicate packets throttled')

local ownerPhone=phone(43)
local owner=player('BatteryOwner',{ownerPhone})
local battery=phone(100,'Base.Battery'); battery.charge=0.6
owner:getInventory():AddItem(battery)
ownerPhone:getDeviceData():setPower(0.2)
SurvivorSignal.changeBattery(owner,{phoneId=ownerPhone:getID(),batteryId=battery:getID()})
check(math.abs(ownerPhone:getDeviceData():getPower()-0.6)<0.0001,'replacement preserves actual battery charge')
check(owner:getInventory():getItemWithIDRecursiv(battery:getID())==nil,'installed battery consumed exactly once')
check(ownerPhone:getCondition()==43,'battery replacement does not repair physical condition')
check(owner:getInventory():getItems():size()==2,'old partial battery returned without duplicate phone')
SurvivorSignal.changeBattery(owner,{phoneId=ownerPhone:getID(),remove=true})
check(not ownerPhone:getDeviceData():getHasBattery(),'battery can be removed')
check(SurvivorSignal.phone(owner:getInventory())==nil,'unpowered phone cannot scan or appear in targets')
local stranger=player('Other',{})
SurvivorSignal.changeBattery(stranger,{phoneId=ownerPhone:getID(),remove=true})
check(not ownerPhone:getDeviceData():getHasBattery(),'foreign phone id cannot be manipulated')
local favorite=phone(100,'Base.Battery'); favorite.favorite=true
owner:getInventory():AddItem(favorite)
SurvivorSignal.changeBattery(owner,{phoneId=ownerPhone:getID(),batteryId=favorite:getID()})
check(not ownerPhone:getDeviceData():getHasBattery(),'favorite battery not automatically consumed')
local legacy=phone(34,'SurvivorSignal.Phone'); legacy.favorite=true
local existing=player('Legacy',{legacy}); players={existing}
handlers.OnClientCommand(SurvivorSignal.module,'starter',existing,{hasPhone=true})
for i=1,240 do handlers.OnTick() end
local migrated=SurvivorSignal.phone(existing:getInventory(),true)
check(existing:getInventory():getItems():size()==1,'legacy migration plus starter request leaves one phone')
check(migrated:getFullType()==SurvivorSignal.item and migrated:getCondition()==34 and migrated:isFavorite(),
    'legacy phone becomes device with preserved condition and favorite')
local equipped=phone(21,'SurvivorSignal.Phone'); equipped.equipped=true
local held=player('Held',{equipped}); SurvivorSignal.migrate(held)
check(held:getInventory():getItems():get(0)==equipped,'equipped legacy phone waits for unequip')
local carried=player('AlreadyOwned',{phone(100)})
players={carried}; handlers.OnClientCommand(SurvivorSignal.module,'starter',carried,{})
for i=1,240 do handlers.OnTick() end
check(carried:getInventory():getItems():size()==1,'existing device prevents a second starter grant')
local hinted=player('ClientAlreadyGranted',{})
players={hinted}; handlers.OnClientCommand(SurvivorSignal.module,'starter',hinted,{granted=true})
for i=1,240 do handlers.OnTick() end
check(hinted:getInventory():getItems():size()==0,'persisted client grant acknowledgement prevents refill after loss')
print(tostring(count)..' checks passed')
