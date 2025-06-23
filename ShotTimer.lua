local RELOAD_TIME = 0.5
local BAR_WIDTH = 180
local BAR_HEIGHT = 15
local ICON_SIZE = 18

-- ShotTimerDB = ShotTimerDB or {}
-- ShotTimerDB.framePos = ShotTimerDB.framePos or {}

local shotTimer = CreateFrame("Frame", "AutoShotTimerAnchor", UIParent)
-- local shotTimer = CreateFrame("Frame", "AutoShotTimerAnchor")
shotTimer:SetWidth(BAR_WIDTH)
shotTimer:SetHeight(BAR_HEIGHT)
shotTimer:Hide()

-- Outline
local outline = CreateFrame("Frame", nil, shotTimer)
outline:SetFrameLevel(shotTimer:GetFrameLevel() + 2)
outline:SetBackdrop({
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 7,
})
outline:SetBackdropBorderColor(0,0,0,1)
outline:SetAllPoints(shotTimer)
outline:Show()

-- bar does the job
-- Multi-Shot icon
-- local multiShotIcon = shotTimer:CreateTexture(nil, "ARTWORK")
-- multiShotIcon:SetTexture("Interface\\Icons\\Ability_UpgradeMoonGlaive")
-- multiShotIcon:SetHeight(ICON_SIZE)
-- multiShotIcon:SetWidth(ICON_SIZE)
-- multiShotIcon:SetPoint("BOTTOM", shotTimer, "TOP", -(ICON_SIZE/2), 0)

-- Steady Shot icon
local steadyShotIcon = shotTimer:CreateTexture(nil, "ARTWORK")
steadyShotIcon:SetTexture("Interface\\Icons\\Ability_Hunter_SteadyShot")
steadyShotIcon:SetHeight(ICON_SIZE)
steadyShotIcon:SetWidth(ICON_SIZE)
steadyShotIcon:SetPoint("BOTTOM", shotTimer, "TOP", 0, 0)

-- Red bar
local redBar = shotTimer:CreateTexture(nil, "ARTWORK")
redBar:SetTexture("Interface\\Buttons\\WHITE8x8")
redBar:SetHeight(BAR_HEIGHT-4)
redBar:SetWidth(0)
redBar:SetPoint("RIGHT", shotTimer, "RIGHT", -2, 0)
redBar:SetVertexColor(1, 0.40, 0.18, 1)

-- Green bar
local greenBar = shotTimer:CreateTexture(nil, "ARTWORK")
greenBar:SetTexture("Interface\\Buttons\\WHITE8x8")
greenBar:SetHeight(BAR_HEIGHT-4)
greenBar:SetWidth(0)
greenBar:SetPoint("RIGHT", redBar, "LEFT", 0, 0)
greenBar:SetVertexColor(0.30, 0.78, 0.36, 1)

-- Multishot bar
local msBar = shotTimer:CreateTexture(nil, "OVERLAY")
msBar:SetTexture("Interface\\Buttons\\WHITE8x8")
msBar:SetHeight(3)
msBar:SetWidth(BAR_WIDTH)
msBar:SetPoint("BOTTOMRIGHT", shotTimer, "BOTTOMRIGHT", -2, 2)
msBar:SetVertexColor(0.97, 0.85, 0.38, 1)

-- Text
local autoText = shotTimer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
autoText:SetPoint("RIGHT", shotTimer, "RIGHT", -3, 0)

-- State
local auto_shot_start, auto_shot_duration = 0, 0
local unstarted = true
local ms_cd = 0
local in_combat = false
local frameLocked = false
local lastPosX, lastPosY
local auto_on = false

-- Drag/Move logic
shotTimer:SetMovable(true)
shotTimer:EnableMouse(true)
shotTimer:RegisterForDrag("LeftButton")
shotTimer:SetScript("OnDragStart", function()
  if not frameLocked then this:StartMoving() end
end)
shotTimer:SetScript("OnDragStop", function()
  this:StopMovingOrSizing()
  local point, _, relPoint, x, y = this:GetPoint()
  ShotTimerDB.framePos.point = point
  ShotTimerDB.framePos.relPoint = relPoint
  ShotTimerDB.framePos.x = x
  ShotTimerDB.framePos.y = y
end)

-- Lock/Unlock visual state & visibility logic
local function UpdateShotTimerVisibility()
  if frameLocked then
    -- Show only if timer active
    local now = GetTime()
    if auto_shot_duration > 0 and (now - auto_shot_start) < auto_shot_duration then
      shotTimer:Show()
    else
      if not in_combat then
        shotTimer:Hide()
      end
    end
    shotTimer:SetBackdropBorderColor(0,0,0,1)
  else
    -- Always visible, grayed border for feedback
    shotTimer:Show()
    outline:SetBackdropBorderColor(1, 0.8, 0.1, 1)
  end
end

local function SetFrameLocked(lock)
  frameLocked = lock
  ShotTimerDB.locked = lock
  if lock then
    shotTimer:EnableMouse(false)
    outline:SetBackdropBorderColor(0,0,0,1)
  else
    shotTimer:EnableMouse(true)
    outline:SetBackdropBorderColor(1, 0.8, 0.1, 1)
  end
  UpdateShotTimerVisibility()
end

local function ResetShotTimerPosition()
  shotTimer:ClearAllPoints()
  shotTimer:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  ShotTimerDB.framePos = { point = "CENTER", relPoint = "CENTER", x = 0, y = 0 }
  DEFAULT_CHAT_FRAME:AddMessage("AutoShot bar position reset to center.")
end

local function SetShotTimerPosition()
  shotTimer:ClearAllPoints()
  shotTimer:SetPoint(
    ShotTimerDB.framePos.point or "CENTER",
    UIParent,
    ShotTimerDB.framePos.relPoint or "CENTER",
    (ShotTimerDB.framePos.x or 0) * (1 / (ShotTimerDB.scale or 1)) or 0,
    (ShotTimerDB.framePos.y or 0) * (1 / (ShotTimerDB.scale or 1)) or 0
  )
end

-- Slash handler
SLASH_SHOTTIMER1 = "/shottimer"
SlashCmdList["SHOTTIMER"] = function(msg)
  msg = string.lower(msg or "")
  if string.find(msg, "unlock") then
    SetFrameLocked(false)
    DEFAULT_CHAT_FRAME:AddMessage("ShotTimer bar unlocked. Drag to reposition, then /autoshot lock.")
  elseif string.find(msg, "lock") then
    SetFrameLocked(true)
    DEFAULT_CHAT_FRAME:AddMessage("ShotTimer bar locked.")
  elseif string.find(msg, "reset") then
    ResetShotTimerPosition()
    SetFrameLocked(false)
    shotTimer:SetScale(1)
    DEFAULT_CHAT_FRAME:AddMessage("ShotTimer bar reset.")
  elseif string.find(msg, "scale") then
    local _,_,scale = string.find(msg, "scale%s+(%d*%.?%d+)")
    scale = tonumber(scale)
    if scale and scale > 0.3 and scale < 3 then
      ShotTimerDB.scale = scale
      shotTimer:SetScale(scale)
      SetShotTimerPosition()
      DEFAULT_CHAT_FRAME:AddMessage(string.format("ShotTimer scale set to %.2f", scale))
    else
      DEFAULT_CHAT_FRAME:AddMessage("Usage: /shottimer scale 1.2 (range: 0.5–2)")
    end
  else
    DEFAULT_CHAT_FRAME:AddMessage("ShotTimer ".. GetAddOnMetadata("ShotTimer","Version") ..": /autoshot lock | unlock | reset")
  end
end

-- OnUpdate bar logic
local elapsed = 0
shotTimer:SetScript("OnUpdate", function()
  elapsed = elapsed + arg1
  if elapsed > 0.015 then elapsed = 0 else return end -- don't be a hog

  local now = GetTime()
  local total = auto_shot_duration
  local fill = now - auto_shot_start
  local ms_cd_dur = now - ms_cd

  -- Movement detection: Only reset if we're currently in the 0.5s reload window
  local posX, posY = GetPlayerMapPosition("player")
  if posX and posY then
    if lastPosX ~= nil and lastPosY ~= nil then
      if (posX ~= lastPosX or posY ~= lastPosY)
        and (auto_shot_duration == RELOAD_TIME or fill > auto_shot_duration) and auto_on
      then
        -- Player moved during RELOAD_TIME bar, reset it
        auto_shot_duration = RELOAD_TIME
        auto_shot_start = now
      end
    end
    lastPosX, lastPosY = posX, posY
  end

  if total < RELOAD_TIME then total = RELOAD_TIME end
  if fill > total then fill = total end
  if fill < 0 then fill = 0 end

  local barMax = (BAR_WIDTH - 4)
  local redFraction = RELOAD_TIME / total
  local redLen = barMax * redFraction

  local remainingFraction = 1 - (fill / total)
  local greenLen = barMax * remainingFraction - redLen

  if fill + RELOAD_TIME > total then
    redLen = barMax * remainingFraction
    greenLen = 0
  end

  local rem = total - fill
  if rem > 1.5 then
    steadyShotIcon:Show()
  else
    steadyShotIcon:Hide()
  end

  if greenLen > 0 then
    greenBar:Show()
    greenBar:SetWidth(greenLen)
  else
    greenBar:Hide()
  end
  if redLen > 0 then
    redBar:Show()
    redBar:SetWidth(redLen)
  else
    redBar:Hide()
  end

  autoText:SetText(string.format("%.1f", rem))

  -- Multishot bar logic
  local ms_duration = 10
  local ms_elapsed = now - (ms_cd or 0)
  local ms_width = 0
  if ms_cd and ms_elapsed < ms_duration then
    msBar:Show()
    ms_width = (BAR_WIDTH - 4) * (1 - (ms_elapsed / ms_duration))
    if ms_width < 0 then ms_width = 0 end
    msBar:SetWidth(ms_width)
  else
    msBar:Hide()
  end

  -- Visibility logic
  UpdateShotTimerVisibility()
end)

local function ResetAutoShot(cast_check)
  local now = GetTime()
  local off_cooldown = now - auto_shot_start >= auto_shot_duration
  if cast_check then
    if off_cooldown then
      auto_shot_duration = RELOAD_TIME
      auto_shot_start = GetTime()
      unstarted = false
    end
  else
    if unstarted then
      unstarted = false
      auto_shot_duration = RELOAD_TIME
    else
      auto_shot_duration = UnitRangedDamage("player")
    end
    auto_shot_start = GetTime()
  end
end

shotTimer:SetScript("OnEvent", function ()
  shotTimer[event](shotTimer,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9)
end)
shotTimer:RegisterEvent("UNIT_CASTEVENT")
shotTimer:RegisterEvent("START_AUTOREPEAT_SPELL")
shotTimer:RegisterEvent("VARIABLES_LOADED")
shotTimer:RegisterEvent("PLAYER_REGEN_DISABLED")
shotTimer:RegisterEvent("PLAYER_REGEN_ENABLED")
shotTimer:RegisterEvent("PLAYER_DEAD")

function shotTimer:VARIABLES_LOADED()
  -- SavedVars
  ShotTimerDB = ShotTimerDB or {}
  ShotTimerDB.framePos = ShotTimerDB.framePos or {}
  ShotTimerDB.scale = ShotTimerDB.scale or 1

  shotTimer:SetScale(ShotTimerDB.scale or 1)
  SetShotTimerPosition()

  if ShotTimerDB.locked == nil then
    frameLocked = false                -- default to unlocked for first-time users
    ShotTimerDB.locked = false         -- persist this default
  else
    frameLocked = ShotTimerDB.locked
  end

  greenBar:SetWidth(0)
  redBar:SetWidth(0)
  UpdateShotTimerVisibility()
end

function shotTimer:PLAYER_REGEN_DISABLED()
  in_combat = true
end

function shotTimer:PLAYER_REGEN_ENABLED()
  in_combat = false
end

function shotTimer:PLAYER_DEAD()
  in_combat = false
end

local spells_of_interest = {
  ["Steady Shot"] = true,
  ["Aimed Shot"] = true,
  ["Multi-Shot"] = true,
}

function shotTimer:UNIT_CASTEVENT(caster,target,action,spell_id,cast_time)
  if not UnitIsUnit("player", caster) then return end
  local spellname = SpellInfo(spell_id)

  if spell_id == 75 then
    if action == "FAIL" then
      -- fail logic
      auto_on = false
    elseif action == "CAST" then
      ResetAutoShot()
    end
  elseif spells_of_interest[spellname] then
    if action == "START" then
      -- starting spell
    elseif action == "CAST" then
      if spellname == "Multi-Shot" then
        ms_cd = GetTime()
      end
      ResetAutoShot(true)
    end
  end
  UpdateShotTimerVisibility()
end

function shotTimer:START_AUTOREPEAT_SPELL()
  ResetAutoShot(true)
  UpdateShotTimerVisibility()
  auto_on = true
end
