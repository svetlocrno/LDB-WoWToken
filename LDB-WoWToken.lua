local addon_name, addon_env = ...

local GetCurrentMarketPrice = C_WowTokenPublic.GetCurrentMarketPrice
local UpdateMarketPrice = C_WowTokenPublic.UpdateMarketPrice
local GetMoneyString = GetMoneyString
local After = C_Timer.After
local LE_TOKEN_RESULT_SUCCESS = LE_TOKEN_RESULT_SUCCESS
local time = time
local date = date
local tinsert = table.insert

local history_length = 10
local history_cutout = history_length + 2

local qtip = LibStub("LibQTip-1.0")
local ldb = LibStub:GetLibrary("LibDataBroker-1.1")

local dataobj = ldb:NewDataObject(addon_name, {
   label = addon_name,
   type = "data source",
   icon = "Interface\\Icons\\WoW_Token01",
})

local history_timestamp = {}
local history_price = {}

local current_price
local event_frame = CreateFrame("Frame")
event_frame:RegisterEvent("TOKEN_MARKET_PRICE_UPDATED")
event_frame:SetScript("OnEvent", function(self, event, result)
   if result ~= LE_TOKEN_RESULT_SUCCESS then new_price = nil end
   local new_price = GetCurrentMarketPrice()
   if new_price == current_price then return end
   current_price = new_price
   if current_price then
      dataobj.text = GetMoneyString(current_price, true)
      tinsert(history_timestamp, 1, time())
      tinsert(history_price, 1, current_price)
      history_timestamp[history_cutout] = nil
      history_price[history_cutout] = nil
   else
      dataobj.text = ""
   end
end)

local function UpatePriceAndReschedule()
   UpdateMarketPrice()
   After(60, UpatePriceAndReschedule)
end
After(1, UpatePriceAndReschedule)

local tooltip

function dataobj:OnEnter()
   tooltip = qtip:Acquire(addon_name, 3, "LEFT", "RIGHT", "RIGHT")
   tooltip:AddHeader("Time", "Price", "Diff")
   for idx = 1, history_length do
      local price = history_price[idx]
      local diff
      if price then
         local older_price = history_price[idx + 1]
         if older_price then
            diff = price - older_price
            local sign
            if diff < 0 then
               sign = "-"
               diff = -diff
            else
               sign = "+"
            end
            diff = sign .. GetMoneyString(diff, true)
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