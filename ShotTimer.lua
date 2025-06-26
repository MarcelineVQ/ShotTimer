local RELOAD_TIME = 0.5
local BAR_WIDTH = 180
local BAR_HEIGHT = 15
local ICON_SIZE = 20

local title_text = "|cf7ffd700["..GetAddOnMetadata("ShotTimer","Title").."]|r"

local shotTimer = CreateFrame("Frame", "ShotTimer", UIParent)
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
autoText:SetWidth(30) -- arbitrary, just needs to be 'big enough'
autoText:SetHeight(30) -- arbitrary, just needs to be 'big enough'
autoText:SetPoint("RIGHT", shotTimer, "RIGHT", 3, 0)

-- State
local auto_shot_start, auto_shot_duration = 0, 0
local unstarted = true
local ms_cd = 0
local in_combat = false
local frameLocked = false
local lastPosX, lastPosY
local auto_on = false
RangedSwingTime = 0

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
  -- Always update barHidden from DB in case it was changed
  barHidden = ShotTimerDB and ShotTimerDB.barHidden or false

  if barHidden then
    -- Hide only visuals, never the parent frame
    outline:Hide()
    greenBar:Hide()
    redBar:Hide()
    autoText:Hide()
    steadyShotIcon:Hide()
    -- shotTimer:Show() -- explicitly keep frame shown for OnUpdate!
    msBar:Hide()
    return
  end

  -- Otherwise, normal lock/unlock logic for showing/hiding
  if frameLocked then
    local now = GetTime()
    if auto_shot_duration > 0 and (now - auto_shot_start) < auto_shot_duration then
      shotTimer:Show()
      outline:Show()
      autoText:Show()
    else
      if not in_combat then
        shotTimer:Show()  -- DO NOT HIDE shotTimer, keep updating
      end
      outline:Show()
      autoText:Show()
    end
    outline:SetBackdropBorderColor(0,0,0,1)
  else
    -- Always visible, grayed border for feedback
    shotTimer:Show()
    outline:Show()
    autoText:Show()
    outline:SetBackdropBorderColor(1, 0.8, 0.1, 1)
  end

  -- greenBar/redBar/steadyShotIcon will be handled per update logic
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
  barHidden = false
  ShotTimerDB.barHidden = false
  UpdateShotTimerVisibility()
  DEFAULT_CHAT_FRAME:AddMessage("ShotTimer bar position reset to center.")
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

-- slightly arbitrary leeway adjustments, so you can clip auto a tiny bit since it's still a gain
local shots = {
  steady = { clip = 1.3, spell = "Steady Shot", id = nil },
  multi  = { clip = 0.5, spell = "Multi-Shot",  id = nil },
  aimed  = { clip = 3.0, spell = "Aimed Shot",  id = nil },
}

-- pet may attack target when:
-- your target is in combat and you are in combat
function ST_PetMayAttack()
  local target_exists = UnitIsVisible("target") and not UnitIsDead("target")
  local target_fighting = UnitAffectingCombat("target")
  local you_fighting = UnitAffectingCombat("player")

  return target_exists and target_fighting and you_fighting
end

function ST_SafePetAttack()
  if ST_PetMayAttack() then CastPetAction(1) end
end

function ST_AutoShot()
  if not auto_on then
    local target_exists = UnitIsVisible("target") and not UnitIsDead("target")
    if not target_exists then TargetNearestEnemy() end
    CastSpellByName("Auto Shot")
  end
end

function ST_SafeShot(shot)
  local spell = shots[shot]
  if not spell or (spell and not spell.id) or auto_shot_duration == RELOAD_TIME then return end
  local cd,started = GetSpellCooldown(spell.id, BOOKTYPE_SPELL)
  local now = GetTime()
  if cd ~= 1.5 and (now - (started + cd) > 0) and RangedSwingTime > spell.clip then
    CastSpellByName(spell.spell)
  end
end

-- Slash handler
SLASH_SHOTTIMER1 = "/shottimer"
SlashCmdList["SHOTTIMER"] = function(msg)
  msg = string.lower(msg or "")
  if msg == "auto" then ST_AutoShot()
  elseif msg == "steady" then ST_SafeShot("steady")
  elseif msg == "aimed" then ST_SafeShot("aimed")
  elseif msg == "multi" then ST_SafeShot("multi")
  elseif msg == "petattack" then ST_SafePetAttack()
  elseif msg == "lock" or msg == "unlock" then
    frameLocked = not frameLocked
    SetFrameLocked(frameLocked)
    DEFAULT_CHAT_FRAME:AddMessage(title_text.." bar "..(frameLocked and "" or "un").."locked. Drag to reposition, then /shottimer lock.")
  elseif msg == "show" or msg == "hide" then
    barHidden = not barHidden
    ShotTimerDB.barHidden = barHidden
    UpdateShotTimerVisibility()
    DEFAULT_CHAT_FRAME:AddMessage(title_text.." bar ".. (barHidden and "hidden" or "shown" )..".")
  elseif string.find(msg, "lock") then
    SetFrameLocked(true)
    DEFAULT_CHAT_FRAME:AddMessage(title_text.." bar locked.")
  elseif string.find(msg, "reset") then
    ResetShotTimerPosition()
    SetFrameLocked(false)
    shotTimer:SetScale(1)
    DEFAULT_CHAT_FRAME:AddMessage(title_text.." bar reset.")
  elseif string.find(msg, "scale") then
    local _,_,scale = string.find(msg, "scale%s+(%d*%.?%d+)")
    scale = tonumber(scale)
    if scale and scale > 0.3 and scale < 3 then
      ShotTimerDB.scale = scale
      shotTimer:SetScale(scale)
      SetShotTimerPosition()
      DEFAULT_CHAT_FRAME:AddMessage(string.format(title_text.." scale set to %.2f", scale))
    else
      DEFAULT_CHAT_FRAME:AddMessage("Usage: /shottimer scale 1.2 (range: 0.5–2)")
    end
  else
    DEFAULT_CHAT_FRAME:AddMessage(title_text.." "..GetAddOnMetadata("ShotTimer","Version") ..":")
    DEFAULT_CHAT_FRAME:AddMessage("/shottimer lock | scale | reset | hide")
    DEFAULT_CHAT_FRAME:AddMessage("/shottimer auto | steady | aimed | multi | petattack")
  end
end

-- OnUpdate bar logic
function ShotTimer_OnUpdate(elapsed)
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

  RangedSwingTime = total - fill

  local barMax = (BAR_WIDTH - 4)
  local redFraction = RELOAD_TIME / total
  local redLen = barMax * redFraction

  local remainingFraction = 1 - (fill / total)
  local greenLen = barMax * remainingFraction - redLen

  if fill + RELOAD_TIME > total then
    redLen = barMax * remainingFraction
    greenLen = 0
  end

  if RangedSwingTime > 1.5 then
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

  autoText:SetText(string.format("%.1f", RangedSwingTime))

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
end

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

local elapsed = 0
shotTimer:SetScript("OnUpdate", function ()
    elapsed = elapsed + arg1
    if elapsed > 0.015 then
      elapsed = 0
      ShotTimer_OnUpdate(elapsed)
    else
      return
    end
end)

shotTimer:SetScript("OnEvent", function ()
  shotTimer[event](shotTimer,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9)
end)
shotTimer:RegisterEvent("VARIABLES_LOADED")

function shotTimer:LEARNED_SPELL_IN_TAB()
  local i = 1
  while true do
    local spellName = GetSpellName(i, BOOKTYPE_SPELL)
    if not spellName then break end
    for k,shot in pairs(shots) do
      if not shot.id and shot.spell == spellName then
        -- print(spellName .. " " .. i)
        shots[k].id = i
        break
      end
    end
    i = i + 1
  end
end

function shotTimer:PLAYER_ENTERING_WORLD()
  self:LEARNED_SPELL_IN_TAB()
end

function shotTimer:VARIABLES_LOADED()

  local _,class = UnitClass("player")
  if class ~= "HUNTER" then
    shotTimer:Hide()
    return
  end

  shotTimer:RegisterEvent("UNIT_CASTEVENT")
  shotTimer:RegisterEvent("START_AUTOREPEAT_SPELL")
  shotTimer:RegisterEvent("PLAYER_REGEN_DISABLED")
  shotTimer:RegisterEvent("PLAYER_REGEN_ENABLED")
  shotTimer:RegisterEvent("PLAYER_DEAD")
  shotTimer:RegisterEvent("LEARNED_SPELL_IN_TAB")
  shotTimer:RegisterEvent("PLAYER_ENTERING_WORLD")

  -- SavedVars
  ShotTimerDB = ShotTimerDB or {}
  ShotTimerDB.framePos = ShotTimerDB.framePos or {}
  ShotTimerDB.scale = ShotTimerDB.scale or 1.3
  ShotTimerDB.barHidden = ShotTimerDB.barHidden or 

  shotTimer:SetScale(ShotTimerDB.scale)
  SetShotTimerPosition()

  if ShotTimerDB.locked == nil then
    frameLocked = false                -- default to unlocked for first-time users
    ShotTimerDB.locked = false         -- persist this default
  else
    frameLocked = ShotTimerDB.locked
  end

  auto_shot_duration = RELOAD_TIME
  RangedSwingTime = RELOAD_TIME

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
