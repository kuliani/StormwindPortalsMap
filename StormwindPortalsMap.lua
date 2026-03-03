-- StormwindPortalsMap.lua
local ADDON = ...
local f = CreateFrame("Frame")

-- === Settings you may tweak ===
local NPC_ID = 331          -- Maginor Dumas (from the WA export) [no longer required, but kept if you want it later]
local STORMWIND_MAP_ID = 84 -- WA zoneIds "84"
local REQUIRE_ALLIANCE = true

-- === SavedVariables ===
-- NOTE: Add this to your .toc:
-- ## SavedVariables: StormwindPortalsMapDB
StormwindPortalsMapDB = StormwindPortalsMapDB or {}
StormwindPortalsMapDB.button = StormwindPortalsMapDB.button or {}
local dbBtn = StormwindPortalsMapDB.button

-- Parse NPC ID from a UnitGUID (kept for reference; not used in the current toggle model)
local function GetNpcIdFromGuid(guid)
  if not guid then return nil end
  local unitType, _, _, _, _, npcId = strsplit("-", guid)
  if unitType ~= "Creature" and unitType ~= "Vehicle" then return nil end
  npcId = tonumber(npcId)
  return npcId
end

local function IsAlliance()
  local faction = UnitFactionGroup("player")
  return faction == "Alliance"
end

local function InStormwind()
  local mapId = C_Map.GetBestMapForUnit("player")
  return mapId == STORMWIND_MAP_ID
end

local function InWizardsSanctum()
  return GetSubZoneText() == "Wizard's Sanctum"
end

-- === Build UI ===
local frame = CreateFrame("Frame", "StormwindPortalsMapFrame", UIParent)
frame:SetSize(700, 460)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 70)
frame:SetFrameStrata("HIGH")
frame:Hide()

-- If you want the WHOLE overlay semi-transparent, uncomment this:
-- frame:SetAlpha(0.85)

-- Background (WA used "Artifacts-DeathKnightFrost-BG")
local bg = frame:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints(frame)

if bg.SetAtlas then
  bg:SetAtlas("Artifacts-DeathKnightFrost-BG", true)
else
  bg:SetTexture("Artifacts-DeathKnightFrost-BG")
end

-- Semi-transparent background (your current approach)
bg:SetAlpha(0.70)
bg:SetDesaturated(true)

-- Title text: "Wizard's Sanctum"
local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOP", frame, "TOP", 0, -25)
title:SetText("Wizard's Sanctum")
title:SetTextColor(0, 1, 0, 1)

-- Helper to make translucent rectangles (rooms/corridors)
local function MakeRect(w, h, x, y, a)
  local t = frame:CreateTexture(nil, "BORDER")
  t:SetSize(w, h)
  t:SetPoint("CENTER", frame, "CENTER", x, y)
  t:SetTexture("Interface\\Buttons\\WHITE8x8")
  t:SetVertexColor(0.5803922, 0.6588235, 0.8156863, a or 0.1066667)
  return t
end

-- Rooms/corridors (from your WA export)
MakeRect(540,  80, 0,  150, 0.1066667) -- Second Room
MakeRect( 70, 120, 0,   50, 0.1066667) -- Second Corridor
MakeRect(540,  80, 0,  -50, 0.1066667) -- First Room
MakeRect( 70, 100, 0, -140, 0.1066667) -- First Corridor

-- Helper to create an icon + label at an offset
local function MakeIconLabel(atlasOrTexture, label, x, y, size, labelColor)
  local icon = frame:CreateTexture(nil, "ARTWORK")
  icon:SetSize(size, size)
  icon:SetPoint("CENTER", frame, "CENTER", x, y)

  if icon.SetAtlas then
    icon:SetAtlas(atlasOrTexture, true)
  else
    icon:SetTexture(atlasOrTexture)
  end

  local fs = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  fs:SetPoint("TOP", icon, "BOTTOM", 0, 0)
  fs:SetText(label)
  fs:SetTextColor(
    (labelColor and labelColor.r) or 0,
    (labelColor and labelColor.g) or 0.7607844,
    (labelColor and labelColor.b) or 1,
    1
  )

  return icon, fs
end

-- Portal icons/labels
MakeIconLabel("TaxiNode_Continent_Alliance", "Bel'ameth",        -90,  190, 28)
MakeIconLabel("TaxiNode_Continent_Alliance", "Boralus",           90,  190, 28)
MakeIconLabel("TaxiNode_Continent_Alliance", "Dornogal",         -90,  -90, 28)
MakeIconLabel("TaxiNode_Continent_Alliance", "Oribos",          -180,  -10, 28)
MakeIconLabel("TaxiNode_Continent_Alliance", "Founder's Point",  -90,  -10, 28)
MakeIconLabel("TaxiNode_Continent_Alliance", "Dalaran, WotLK",    90,  -10, 28)
MakeIconLabel("TaxiNode_Continent_Alliance", "Exodar",           180,  -10, 28)
MakeIconLabel("TaxiNode_Continent_Alliance", "Silvermoon",      -270,  -50, 28)
MakeIconLabel("TaxiNode_Continent_Alliance", "Caverns of Time",  270,  -50, 28)
MakeIconLabel("TaxiNode_Continent_Alliance", "Valdrakken",      -180,  -90, 28)
MakeIconLabel("TaxiNode_Continent_Alliance", "Jade Forest",       90,  -90, 28)
MakeIconLabel("TaxiNode_Continent_Alliance", "Shattrath",        180,  -90, 28)
MakeIconLabel("TaxiNode_Continent_Alliance", "Azsuna",            90,  110, 28)
MakeIconLabel("TaxiNode_Continent_Alliance", "Ashran",           180,  110, 28)

-- Exit icon uses WarlockPortalAlliance
do
  local icon = frame:CreateTexture(nil, "ARTWORK")
  icon:SetSize(32, 32)
  icon:SetPoint("CENTER", frame, "CENTER", 0, -190)
  if icon.SetAtlas then
    icon:SetAtlas("WarlockPortalAlliance", true)
  else
    icon:SetTexture("WarlockPortalAlliance")
  end

  local fs = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  fs:SetPoint("TOP", icon, "BOTTOM", 1, 3)
  fs:SetText("Exit")
  fs:SetTextColor(1, 1, 1, 1)
end

-- === Toggle button (movable + Show/Hide text) ===
local userWantsShown = false

local btn = CreateFrame("Button", "StormwindPortalsMapToggleButton", UIParent, "UIPanelButtonTemplate")
btn:SetSize(140, 24)
btn:SetFrameStrata("HIGH")
btn:SetMovable(true)
btn:EnableMouse(true)
btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
btn:Hide()

local function ApplyButtonPosition()
  btn:ClearAllPoints()
  if dbBtn.point then
    btn:SetPoint(dbBtn.point, UIParent, dbBtn.relativePoint, dbBtn.xOfs or 0, dbBtn.yOfs or 0)
  else
    btn:SetPoint("CENTER", UIParent, "CENTER", 0, -220) -- default
  end
end

local function SaveButtonPosition()
  local point, _, relativePoint, xOfs, yOfs = btn:GetPoint(1)
  dbBtn.point = point
  dbBtn.relativePoint = relativePoint
  dbBtn.xOfs = math.floor((xOfs or 0) + 0.5)
  dbBtn.yOfs = math.floor((yOfs or 0) + 0.5)
end

local function UpdateButtonText()
  btn:SetText(userWantsShown and "Hide Portals Map" or "Show Portals Map")
end

btn:RegisterForDrag("LeftButton")

btn:SetScript("OnDragStart", function(self)
  if not IsShiftKeyDown() then return end
  if self.SetButtonState then self:SetButtonState("NORMAL") end
  self:StartMoving()
end)

btn:SetScript("OnDragStop", function(self)
  self:StopMovingOrSizing()
  SaveButtonPosition()
  if self.SetButtonState then self:SetButtonState("NORMAL") end
end)



btn:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_TOP")
  GameTooltip:AddLine("Stormwind Portals Map")
  GameTooltip:AddLine("Left-click: Show/Hide", 1, 1, 1)
  GameTooltip:AddLine("Shift+Drag: Move button", 1, 1, 1)
  GameTooltip:AddLine("Right-click: Reset position", 1, 1, 1)
  GameTooltip:Show()
end)

btn:SetScript("OnLeave", function()
  GameTooltip:Hide()
end)


btn:SetScript("OnClick", function(_, mouseButton)
  if mouseButton == "RightButton" then
    -- Reset position on right-click
    dbBtn.point, dbBtn.relativePoint, dbBtn.xOfs, dbBtn.yOfs = nil, nil, nil, nil
    ApplyButtonPosition()
    return
  end

  -- Left click toggles visibility
  userWantsShown = not userWantsShown
  UpdateButtonText()

  if userWantsShown then
    frame:Show()
  else
    frame:Hide()
  end
end)

-- Apply initial position/text
ApplyButtonPosition()
UpdateButtonText()

-- === Show/hide logic ===
local function UpdateVisibility()
  if REQUIRE_ALLIANCE and not IsAlliance() then
    btn:Hide()
    frame:Hide()
    return
  end

  if not InStormwind() or not InWizardsSanctum() then
    btn:Hide()
    frame:Hide()
    userWantsShown = false -- reset when leaving
    UpdateButtonText()
    return
  end

  btn:Show()
  UpdateButtonText()

  if userWantsShown then
    frame:Show()
  else
    frame:Hide()
  end
end

f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
f:RegisterEvent("ZONE_CHANGED")
f:RegisterEvent("ZONE_CHANGED_INDOORS")

f:SetScript("OnEvent", function()
  UpdateVisibility()
end)

-- Optional: manual toggle for testing
SLASH_STORMWINDPORTALSMAP1 = "/swpm"
SlashCmdList.STORMWINDPORTALSMAP = function()
  userWantsShown = not userWantsShown
  UpdateButtonText()

  if userWantsShown and InStormwind() and InWizardsSanctum() then
    frame:Show()
    btn:Show()
    print("StormwindPortalsMap: shown")
  else
    frame:Hide()
    print("StormwindPortalsMap: hidden")
  end
end
