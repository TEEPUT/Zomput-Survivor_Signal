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
local function list(items) return {size=function() return #items end,get=function(_,i) return items[i+1] end} end
local function phone(condition)
    return {getFullType=function() return 'SurvivorSignal.Phone' end,
        getCondition=function(self) return self.condition end,
        setCondition=function(self,n) self.condition=n end,
        IsInventoryContainer=function() return false end,condition=condition}
end
local function inventory(items)
    return {getItems=function() return list(items) end,AddItem=function() local p=phone(100); items[#items+1]=p; return p end}
end
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
print(tostring(count)..' checks passed')
