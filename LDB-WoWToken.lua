local a_name, a_env = ...
if not a_env.load_this then return end

local sv_name = "SV_LDBWoWToken"

local GetCurrentMarketPrice = C_WowTokenPublic.GetCurrentMarketPrice
local UpdateMarketPrice = C_WowTokenPublic.UpdateMarketPrice
local GetMoneyString = GetMoneyString
local After = C_Timer.After
local LE_TOKEN_RESULT_SUCCESS = LE_TOKEN_RESULT_SUCCESS
local time = time
local date = date
local tinsert = table.insert
local RED_FONT_COLOR_CODE = RED_FONT_COLOR_CODE
local GREEN_FONT_COLOR_CODE = GREEN_FONT_COLOR_CODE

local history_length = 10
local history_cutout = history_length + 2

local qtip = LibStub("LibQTip-1.0")
local ldb = LibStub:GetLibrary("LibDataBroker-1.1")
local LibToast = LibStub("LibToast-1.0", 1)

local dataobj = ldb:NewDataObject(a_name, {
   label = a_name,
   type = "data source",
   icon = "Interface\\Icons\\WoW_Token01",
})

if LibToast then
   -- /run LibStub("LibToast-1.0"):Spawn("LDB-WoWToken", 123, 456)
   LibToast:Register(a_name, function(toast, new_price, diff)
      toast:SetFormattedTitle("%s", a_name)
      toast:SetFormattedText("%s %s", new_price, (diff or ""))
   end)
end

local function InitSV(sv_name)
   if not _G[sv_name]                   then _G[sv_name] = {} end

   if not _G[sv_name].history_timestamp then _G[sv_name].history_timestamp = {} end
   if not _G[sv_name].history_price     then _G[sv_name].history_price = {} end
end
InitSV(sv_name)

local current_price
local current_h2

local event_frame = CreateFrame("Frame")

local function DiffString(now, before)
   local swap = SV_LDBWoWToken.diff_colors == "seller"

   local diff = now - before
   local color, sign
   if diff < 0 then
      color = swap and RED_FONT_COLOR_CODE or GREEN_FONT_COLOR_CODE
      sign = "-"
      diff = -diff
   else
      color = swap and GREEN_FONT_COLOR_CODE or RED_FONT_COLOR_CODE
      sign = "+"
   end
   return color .. sign .. GetMoneyString(diff, true)
end

local function OnTokenPriceUpdate(self, event, result)
   local sv = _G[sv_name]
   local history_timestamp = sv.history_timestamp
   local history_price     = sv.history_price

   local new_price
   if event == "_MANUAL_UPDATE" then
      new_price = result
   else
      if result ~= LE_TOKEN_RESULT_SUCCESS then new_price = nil else new_price = GetCurrentMarketPrice() end
   end

   if new_price == current_price and current_h2 == history_price[2] then return end

   current_price = new_price
   if current_price then
      if current_price ~= history_price[1] then
         tinsert(history_timestamp, 1, time())
         tinsert(history_price, 1, current_price)
         history_timestamp[history_cutout] = nil
         history_price[history_cutout] = nil
      end
      local diff
      if history_price[2] then
         diff = DiffString(history_price[1], history_price[2])
      end
      local money_string = GetMoneyString(current_price, true)
      dataobj.text = money_string .. " " .. (diff or "")
      if LibToast and SV_LDBWoWToken.diff_libtoast ~= false then LibToast:Spawn(a_name, money_string, diff) end
      if SV_LDBWoWToken.diff_chat ~= false then print(a_name .. ": " .. money_string .. " " .. (diff or "")) end
   else
      dataobj.text = "N/A"
   end
   current_h2 = history_price[2]
end

local function OnLoaded(self)
   local sv = _G[sv_name]
   local history_price     = sv.history_price

   local pre_load_price = current_price
   current_price = history_price[1]
   OnTokenPriceUpdate(self, "_MANUAL_UPDATE", pre_load_price)
   event_frame:SetScript("OnEvent", OnTokenPriceUpdate)
   event_frame:UnregisterEvent("ADDON_LOADED")
   -- Literally WTF? After wouldn't take built-in C_WowTokenPublic.UpdateMarketPrice as argument. Is that a quirk of new C-side After?
   After(1, function() UpdateMarketPrice() end)
end

event_frame:RegisterEvent("TOKEN_MARKET_PRICE_UPDATED")
event_frame:RegisterEvent("ADDON_LOADED")
event_frame:SetScript("OnEvent", function(self, event, result)
   if event == "ADDON_LOADED" then
      if result == a_name then
         OnLoaded(self)
      end
   else
      OnTokenPriceUpdate(self, event, result)
   end
end)

local function UpatePriceAndReschedule()
   UpdateMarketPrice()
   After(60, UpatePriceAndReschedule)
end
After(1, UpatePriceAndReschedule)

local tooltip

function dataobj:OnEnter()
   local sv = _G[sv_name]
   local history_timestamp = sv.history_timestamp
   local history_price     = sv.history_price

   tooltip = qtip:Acquire(a_name, 3, "LEFT", "RIGHT", "RIGHT")
   tooltip:AddHeader("Time", "Price", "Diff")
   for idx = 1, history_length do
      local price = history_price[idx]
      local diff
      if price then
         local older_price = history_price[idx + 1]
         if older_price then
            diff = DiffString(price, older_price)
         end
         price = GetMoneyString(price, true) or ""
         tooltip:AddLine(date("%Y/%m/%d (%a) %H:%M", history_timestamp[idx]), price, diff or "")
      end
   end
   tooltip:SmartAnchorTo(self)
   tooltip:Show()
end

function dataobj:OnLeave()
   qtip:Release(tooltip)
   tooltip = nil
end
