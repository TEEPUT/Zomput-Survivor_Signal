require "SurvivorSignal/Shared"
require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISScrollingListBox"
require "ISUI/ISModalDialog"
require "ISUI/Maps/ISMiniMap"
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
        list:addItem(r.name.."  X:"..r.x.." Y:"..r.y.." Z:"..r.z, r)
    end
    if #result.rows == 0 then list:addItem(text("Empty"), {}) end
    panel:addChild(list)
    function panel:render()
        ISPanel.render(self)
        self:drawText("Survivor Signal | "..result.day, 12, 10, 0.6, 1, 0.6, 1, UIFont.Medium)
        self:drawText(text("Snapshot").." | "..result.condition.."%", 12, 31, 1,1,1,1,UIFont.Small)
    end
    local button = ISButton:new(330, 289, 115, 28, text("Close"), panel, closeWindow)
    button:initialise(); panel:addChild(button)
    panel:addToUIManager(); windows[pn] = panel
end
Events.OnServerCommand.Add(function(module, command, args)
    if module ~= S.module then return end
    if command == "result" then
        local pn = args.playerNum or 0
        snapshots[pn] = args
        show(pn, args)
    elseif command == "error" then
        local modal = ISModalDialog:new(100,100,440,150,text(args.key),false,nil,nil)
        modal:initialise(); modal:addToUIManager()
    end
end)
Events.OnFillInventoryObjectContextMenu.Add(function(pn, context, items)
    local p = getSpecificPlayer(pn)
    if not S.alive(p) then return end
    local found = false
    for _,entry in ipairs(items) do
        local item = instanceof(entry,"InventoryItem") and entry or (entry.items and entry.items[1])
        if item and item:getFullType() == S.item then found = true end
    end
    if not found then return end
    local option = context:addOption(text("Scan"), p, function(player)
        sendClientCommand(player, S.module, "scan", {})
    end)
    option.notAvailable = not S.phone(p:getInventory())
    local saved = snapshots[pn]
    if saved and saved.day == S.day() and S.phone(p:getInventory(), true) then
        context:addOption(text("Reopen"), pn, function(n) show(n, saved) end)
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
