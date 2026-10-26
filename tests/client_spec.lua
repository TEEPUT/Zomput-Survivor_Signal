-- Exercise the actual menu/window callbacks without a running renderer.
local root=arg[1] or "Contents/mods/ZomputSurvivorSignal/42/media/lua"
package.path=root.."/shared/?.lua;"..root.."/client/?.lua;"..package.path
for _,name in ipairs({'ISUI/ISPanel','ISUI/ISButton','ISUI/ISScrollingListBox',
    'ISUI/ISModalDialog','ISUI/Maps/ISMiniMap','ISUI/ISInventoryPane'}) do package.loaded[name]=true end
local handlers,commands,panels={},{},{}
Events=setmetatable({}, {__index=function(t,key)
    local e={Add=function(fn) handlers[key]=handlers[key] or {}; table.insert(handlers[key],fn) end}
    rawset(t,key,e); return e
end})
local function emit(key,...) for _,fn in ipairs(handlers[key] or {}) do fn(...) end end
local function panel()
    return {children={},initialise=function() end,addChild=function(self,child) table.insert(self.children,child) end,
        addToUIManager=function(self) self.visible=true end,removeFromUIManager=function(self) self.visible=false end}
end
ISPanel={new=function() local p=panel();table.insert(panels,p);return p end,render=function()end}
ISButton={new=function(_,x,y,w,h,title,target,callback)
    return {title=title,target=target,callback=callback,initialise=function()end,
        setEnable=function(self,value) self.enabled=value end}
end}
ISScrollingListBox={new=function() return {items={},initialise=function()end,
    addItem=function(self,text,item) table.insert(self.items,{text=text,item=item}) end} end}
ISModalDialog={new=function()return panel()end}
ISMiniMapOuter={render=function()end}; ISInventoryPane={drawItemDetails=function()end}
UIFont={Small=1,Medium=2}
function getPlayerScreenLeft()return 0 end
function getPlayerScreenTop()return 0 end
function getText(key)return key end
function getRandomUUID()return '11111111-1111-4111-8111-111111111111' end
function instanceof()return true end
function sendClientCommand(p,module,command,args) commands[#commands+1]={command=command,args=args} end
local phone={getFullType=function() return 'SurvivorSignal.PhoneDevice' end,getCondition=function()return 100 end,
    IsInventoryContainer=function()return false end,getID=function()return 1 end,
    getDeviceData=function()return {getHasBattery=function()return false end,getPower=function()return 0 end} end}
local md={}
local player={id='10',getUsername=function()return 'A' end,isDead=function()return false end,getHealth=function()return 100 end,
    getDescriptor=function(self)return {getID=function()return tonumber(self.id) end} end,getModData=function()return md end,
    getInventory=function()return {getItems=function()return {size=function()return 1 end,get=function()return phone end} end,
        getItemWithIDRecursiv=function()return phone end} end}
function getSpecificPlayer(n) if n==0 then return player end end
require 'SurvivorSignal/Client'
local count=0
local function check(ok,label)assert(ok,label);count=count+1;print('PASS '..label)end
local function button(p,key) for _,c in ipairs(p.children) do if c.title=='IGUI_SurvivorSignal_'..key then return c end end end
local function result(index)
    emit('OnServerCommand',SurvivorSignal.module,'result',{username='A',characterId='10',
        day='1993-07-01',time='12:34',originX=0,originY=0,condition=97,power=97,
        rows={{name='B',x=1200,y=1600}},historyIndex=index,historyCount=2})
end
result(1)
local first=panels[#panels]
check(first.children[1].items[1].text:find('2000m',1,true)~=nil,'saved record renders relative metres')
local close=button(first,'Close');close.callback(close.target)
check(not first.visible,'close dismisses only the current window')
local options={}
local context={addOption=function(_,title,target,callback,...)
    local option={title=title,target=target,callback=callback,args={...}};options[#options+1]=option;return option
end}
emit('OnFillInventoryObjectContextMenu',0,context,{phone})
local history
for _,o in ipairs(options) do if o.title=='IGUI_SurvivorSignal_Reopen' then history=o end end
check(history and not history.notAvailable,'history menu remains available after closing without working battery')
history.callback(history.target)
check(commands[#commands].command=='history','reopen requests server history without a new scan')
result(1)
local reopened=panels[#panels]
check(reopened.visible,'server restores the saved result after window was closed')
local older=button(reopened,'Older');older.callback(older.target)
check(commands[#commands].command=='history' and commands[#commands].args.index==2,'older button selects previous saved record')
result(2)
local olderPanel=panels[#panels]
check(not button(olderPanel,'Older').enabled and button(olderPanel,'Newer').enabled,'history navigation respects record bounds')
emit('OnCreatePlayer',0);player.id='11'
check(not olderPanel.visible,'new character closes the previous character window')
local before=#panels;result(1)
check(#panels==before,'late response belonging to dead character is ignored')
print(tostring(count)..' client checks passed')
