require "SurvivorSignal/Shared"
require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISScrollingListBox"
require "ISUI/ISModalDialog"
require "ISUI/Maps/ISMiniMap"
require "ISUI/ISInventoryPane"
local S = SurvivorSignal
local snapshots, windows = {}, {}
local function text(key) return getText("IGUI_SurvivorSignal_"..key) end
local function closeWindow(panel)
    if panel then panel:removeFromUIManager() end
end
local function show(pn, result)
    closeWindow(windows[pn])
    local panel = ISPanel:new(getPlayerScreenLeft(pn)+30, getPlayerScreenTop(pn)+60, 460, 330)
    panel:initialise()
    panel.moveWithMouse = true
    panel.backgroundColor = {r=0.06,g=0.08,b=0.07,a=0.96}
    local list = ISScrollingListBox:new(12, 48, 436, 228)
    list:initialise(); list.itemheight = 24
    function list:doDrawItem(y, item, alt)
        self:drawText(item.text, 6, y+3, 0.75, 0.95, 0.75, 1, UIFont.Small)
        return y+self.itemheight
    end
    for _,r in ipairs(result.rows) do
        local metres, direction = S.relativeLocation(result.originX, result.originY, r.x, r.y)
        list:addItem(r.name.."  "..metres.."m "..text("Direction_"..direction), r)
    end
    if #result.rows == 0 then list:addItem(text("Empty"), {}) end
    panel:addChild(list)
    function panel:render()
        ISPanel.render(self)
        self:drawText("Survivor Signal | "..result.day, 12, 10, 0.6, 1, 0.6, 1, UIFont.Medium)
        local p=getSpecificPlayer(pn)
        local phone=p and result.phoneId and p:getInventory():getItemWithIDRecursiv(result.phoneId)
        local condition,power=result.condition,result.power or 0
        if phone and phone:getFullType()==S.item then
            condition=phone:getCondition(); power=math.floor(S.power(phone)*100+0.5)
        end
        self:drawText(S.status(condition,power), 12, 31, 1,1,1,1,UIFont.Small)
    end
    local button = ISButton:new(330, 289, 115, 28, text("Close"), panel, closeWindow)
    button:initialise(); panel:addChild(button)
    panel:addToUIManager(); windows[pn] = panel
end
Events.OnServerCommand.Add(function(module, command, args)
    if module ~= S.module then return end
    if command == "deviceState" then
        for pn=0,3 do
            local p=getSpecificPlayer(pn)
            if p and p:getUsername()==args.username then S.applyDeviceState(p,args) end
        end
    elseif command == "result" then
        local pn = args.playerNum or 0
        -- Server-side player slots need not match local split-screen slots.
        if args.username then
            for i=0,3 do
                local localPlayer = getSpecificPlayer(i)
                if localPlayer and localPlayer:getUsername() == args.username then pn=i; break end
            end
        end
        -- Older servers may not include the scan origin during a rolling update.
        -- Capture it once; reopening must not recalculate from a moved player.
        if args.originX == nil or args.originY == nil then
            local p = getSpecificPlayer(pn)
            if not p then return end
            args.originX, args.originY = p:getX(), p:getY()
        end
        snapshots[pn] = args
        show(pn, args)
    elseif command == "starterAck" then
        for i=0,3 do
            local p=getSpecificPlayer(i)
            if p and p:getUsername()==args.username then p:getModData().SurvivorSignalGranted=true end
        end
    elseif command == "error" then
        local modal = ISModalDialog:new(100,100,440,150,text(args.key),false,nil,nil)
        modal:initialise(); modal:addToUIManager()
    end
end)
Events.OnFillInventoryObjectContextMenu.Add(function(pn, context, items)
    local p = getSpecificPlayer(pn)
    if not S.alive(p) then return end
    local found, selected = false, nil
    for _,entry in ipairs(items) do
        local item = instanceof(entry,"InventoryItem") and entry or (entry.items and entry.items[1])
        if S.isPhone(item) then found = true; selected = selected or item end
    end
    if not found then return end
    local status=context:addOption(S.status(selected:getCondition(),
        math.floor(S.power(selected)*100+0.5)),nil,nil)
    status.notAvailable=true
    if selected:getFullType()==S.item and p:getInventory():getItemWithIDRecursiv(selected:getID())==selected then
        local device=selected:getDeviceData()
        local battery=S.battery(p:getInventory())
        local replace=context:addOption(text("ReplaceBattery"),p,function(player,phoneId,batteryId)
            sendClientCommand(player,S.module,"battery",{phoneId=phoneId,batteryId=batteryId})
        end,selected:getID(),battery and battery:getID() or nil)
        replace.notAvailable=not battery or (device:getHasBattery() and device:getPower()>=0.999)
        if device:getHasBattery() then
            context:addOption(text("RemoveBattery"),p,function(player,phoneId)
                sendClientCommand(player,S.module,"battery",{phoneId=phoneId,remove=true})
            end,selected:getID())
        end
    end
    local option = context:addOption(text("Scan"), p, function(player)
        sendClientCommand(player, S.module, "scan", {})
    end)
    option.notAvailable = not S.phone(p:getInventory())
    local saved = snapshots[pn]
    if saved and saved.day == S.day() and S.phone(p:getInventory(), true) then
        context:addOption(text("Reopen"), pn, function(n) show(n, saved) end)
    end
end)

-- A normal inventory item never receives vanilla's weapon condition row.
-- Add that row for our phone without changing other items or their tooltips.
local oldDetails=ISInventoryPane.drawItemDetails
function ISInventoryPane:drawItemDetails(item,y,xoff,yoff,red)
    if not S.isPhone(item) then return oldDetails(self,item,y,xoff,yoff,red) end
    local color=getCore():getGoodHighlitedColor()
    self:drawTextAndProgressBar(getText("IGUI_invpanel_Condition")..":",
        item:getCondition()/math.max(1,item:getConditionMax()), xoff,
        self.headerHgt+y*self.itemHgt+yoff,
        {r=0.6,g=0.8,b=0.5,a=0.6},{r=color:getR(),g=color:getG(),b=color:getB(),a=1})
end

-- Ask only after local character/inventory initialization. The hint can decline a
-- starter grant, never request extra copies. Server inventory is checked again.
local starterSent={}
Events.OnCreatePlayer.Add(function(pn) starterSent[pn]=nil end)
Events.OnTick.Add(function()
    for pn=0,3 do
        local p=getSpecificPlayer(pn)
        if S.alive(p) and not starterSent[pn] then
            starterSent[pn]=true
            sendClientCommand(p,S.module,"starter",{hasPhone=S.phone(p:getInventory(),true)~=nil,
                granted=p:getModData().SurvivorSignalGranted==true})
        end
    end
end)
-- Draw after the Java map renderer; keep coordinates clipped to the minimap.
local oldRender = ISMiniMapOuter.render
function ISMiniMapOuter:render()
    if oldRender then oldRender(self) end
    local pn = self.playerNum or self.inner.playerNum or 0
    local p, saved = getSpecificPlayer(pn), snapshots[pn]
    if not S.alive(p) or not S.phone(p:getInventory(), true) or not saved or saved.day ~= S.day() then return end
    local inner, api = self.inner, self.inner.mapAPI
    for _,r in ipairs(saved.rows) do
        local x,y = api:worldToUIX(r.x,r.y), api:worldToUIY(r.x,r.y)
        if x >= 5 and y >= 5 and x < inner.width-5 and y < inner.height-5 then
            self:drawRect(inner.x+x-3,inner.y+y-3,6,6,1,0.25,1,0.4)
        end
    end
end
local n = 0
Events.OnTick.Add(function()
    n=n+1; if n%60 ~= 0 then return end
    for pn, saved in pairs(snapshots) do
        local p = getSpecificPlayer(pn)
        if not S.alive(p) or not S.phone(p:getInventory(), true) or saved.day ~= S.day() then
            closeWindow(windows[pn]); windows[pn]=nil; snapshots[pn]=nil
        end
    end
end)
