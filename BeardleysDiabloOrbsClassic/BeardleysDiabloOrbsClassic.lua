----------------------------------------------------------------------
-- Beardley's Diablo Orbs (Classic)
-- Original addon (c) 2019 Kulturnilpferd
-- https://github.com/Kulturnilpferd/BeardleysDiabloOrbsClassic
-- Repair & clean up code 2026 Valak11173
----------------------------------------------------------------------


----------------------------------------------------------------------
--  SETTINGS - the only things you should need to touch
----------------------------------------------------------------------
scaleFactor = 1.35        -- Scales the whole UI. Bigger number = bigger UI.
local showPetBar = true   -- set to false to leave the pet/vehicle bar alone


----------------------------------------------------------------------
--  INTERNAL HELPERS
----------------------------------------------------------------------

-- Sets the point we want, then locks SetPoint/ClearAllPoints so
-- nothing else can silently move the frame again. Safe to call more
-- than once on the same frame (e.g. from code that recalculates a
-- layout at runtime) - it quietly unlocks itself first.
local function lockPoint(frame, ...)
	if not frame then return end
	frame.SetPoint = nil
	frame.ClearAllPoints = nil
	frame:ClearAllPoints()
	frame:SetPoint(...)
	frame.SetPoint = function() end
	frame.ClearAllPoints = function() end
end

local function setFrameStratLevel(frame, strata, level)
	if not frame then return end
	frame:SetFrameStrata(strata)
	frame:SetFrameLevel(level)
end

-- Runs fn() and, if anything inside errors (usually because a frame
-- we expect no longer exists on this client), reports it to chat
-- instead of letting it silently break every other part of the addon.
local function safeCall(label, fn)
	local ok, err = pcall(fn)
	if not ok then
		print("|cffff4444Beardley's Diablo Orbs:|r '"..label.."' failed - "..tostring(err))
	end
end

local images = "Interface\\AddOns\\BeardleysDiabloOrbsClassic\\art\\"


----------------------------------------------------------------------
--  ARTWORK
----------------------------------------------------------------------

local function addArtworkFrame(frameName, parentFrame, file, frameStrata, frameLevel, offsetX, offsetY, height, width)
	local artworkFrame = CreateFrame("Frame", frameName, parentFrame)
	artworkFrame:SetPoint("BOTTOM", offsetX, offsetY)
	artworkFrame:SetFrameStrata(frameStrata)
	artworkFrame:SetFrameLevel(frameLevel)
	artworkFrame:SetHeight(height)
	artworkFrame:SetWidth(width)
	artworkFrame.texture = artworkFrame:CreateTexture(nil, "OVERLAY")
	artworkFrame.texture:SetTexture(file)
	artworkFrame.texture:SetAllPoints(artworkFrame)
	return artworkFrame
end

local function createArtwork()
	if not actionbarBackground then
		actionbarBackground = addArtworkFrame(nil, UIParent, images.."bar3.tga", "LOW", 9, 1, -4, 127, 491)
	end
	if not leftArtwork then
		leftArtwork = addArtworkFrame(nil, UIParent, images.."leftArtwork.tga", "MEDIUM", 9, -325, 0, 200, 200)
	end
	if not rightArtwork then
		rightArtwork = addArtworkFrame(nil, UIParent, images.."rightArtwork.tga", "MEDIUM", 9, 325, 0, 200, 200)
	end
end


----------------------------------------------------------------------
--  ORBS
----------------------------------------------------------------------

local function updateHealthOrb()
	local healthPercent = UnitHealth("player") / UnitHealthMax("player")
	BDOMod_HealthPercentage:SetText(floor(healthPercent * 100))
	BDOMod_HealthText:SetText(UnitHealth("player").." / "..UnitHealthMax("player"))
	BDOMod_RedOrb:SetHeight(healthPercent * 185)
	BDOMod_RedOrb:SetTexCoord(0, 1, 1 - healthPercent, 1)
end

local function updateManaOrb()
	local manaPercent = UnitPower("player") / UnitPowerMax("player")
	BDOMod_ManaPercentage:SetText(floor(manaPercent * 100))
	BDOMod_ManaText:SetText(UnitPower("player").." / "..UnitPowerMax("player"))
	BDOMod_BlueOrb:SetHeight(manaPercent * 185)
	BDOMod_BlueOrb:SetTexCoord(0, 1, 1 - manaPercent, 1)
end

local POWER_TYPE_COLORS = {
	[0] = {0.2, 0.2, 1.0},    -- Mana
	[1] = {1.0, 0.15, 0.15},  -- Rage
	[2] = {1.0, 0.4, 0.03},   -- Focus
	[3] = {1.0, 1.0, 0.0},    -- Energy
	[6] = {0.2, 0.75, 1.0},   -- Runic Power
}

local function updatePowerType()
	local color = POWER_TYPE_COLORS[UnitPowerType("player")]
	if color and BDOMod_BlueOrb then
		BDOMod_BlueOrb:SetVertexColor(color[1], color[2], color[3])
		BDOMod_BlueOrb:SetTexCoord(0, 1, 0, 1)
	end
end

local function setupOrbs()
	BDOMod_RedOrb:SetVertexColor(0.7, 0.0, 0.0)
	BDOMod_RedOrb:SetTexCoord(0, 1, 0, 1)

	BDOMod_HealthText:SetFont("Fonts\\FRIZQT__.TTF", 12)
	BDOMod_HealthPercentage:SetFont("Fonts\\FRIZQT__.TTF", 25)
	BDOMod_HealthText:SetText(UnitHealth("player").." / "..UnitHealthMax("player"))
	BDOMod_HealthPercentage:SetText(100)

	BDOMod_ManaText:SetFont("Fonts\\FRIZQT__.TTF", 12)
	BDOMod_ManaPercentage:SetFont("Fonts\\FRIZQT__.TTF", 25)
	BDOMod_ManaText:SetText(UnitPower("player").." / "..UnitPowerMax("player"))
	BDOMod_ManaPercentage:SetText(100)

	-- Mouseover/click/right-click on the health orb behaves like the stock player frame
	local healthOrbButton = CreateFrame("Button", nil, BDOMod_HealthOrb, "SecureUnitButtonTemplate")
	healthOrbButton:SetPoint("BOTTOM", BDOMod_HealthOrb, "BOTTOM", 0, 0)
	healthOrbButton:SetWidth(185)
	healthOrbButton:SetHeight(185)
	healthOrbButton:RegisterForClicks("AnyUp")
	healthOrbButton:SetAttribute("unit", "player")
	healthOrbButton:SetAttribute("*type1", "target")
	healthOrbButton:SetAttribute("*type2", "togglemenu")
	healthOrbButton:SetScript("OnEnter", function()
		GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
		GameTooltip:SetUnit("player")
		GameTooltip:Show()
	end)
	healthOrbButton:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
end


----------------------------------------------------------------------
--  BOTTOM BAR LAYOUT (built once at PLAYER_ENTERING_WORLD)
----------------------------------------------------------------------

local BAR_OFFSETS_12 = { -246, -201, -156, -111, -66, -21, 21, 66, 111, 156, 201, 246 }
local STANCE_OFFSETS = { -318, -286, -256, -226, -196, -166 }

local function hideMainBarChrome()

	if MainMenuBarRightEndCap then MainMenuBarRightEndCap:Hide() end
	if MainMenuBarLeftEndCap then MainMenuBarLeftEndCap:Hide() end
	if MainMenuBarTexture0 then MainMenuBarTexture0:Hide() end
	if MainMenuBarTexture1 then MainMenuBarTexture1:Hide() end
	if MainMenuBarTexture2 then MainMenuBarTexture2:Hide() end
	if MainMenuBarTexture3 then MainMenuBarTexture3:Hide() end
	if MainMenuBarPageNumber then MainMenuBarPageNumber:Hide() end

	-- Hide the max level bar and all of its pieces, grey bar at max level made of 5 bars.
	local maxLevelBars = {
		MainMenuBarMaxLevelBar,
		MainMenuMaxLevelBar0,
		MainMenuMaxLevelBar1,
		MainMenuMaxLevelBar2,
		MainMenuMaxLevelBar3,
	}

	for _, bar in ipairs(maxLevelBars) do
		if bar then
			bar:Hide()
			bar:SetScript("OnShow", function(self)
				self:Hide()
			end)
		end
	end
end




local function layoutMainActionBar()
	for i = 1, 12 do
		local button = _G["ActionButton"..i]
		lockPoint(button, "BOTTOM", UIParent, "BOTTOM", BAR_OFFSETS_12[i], 29)
		if button then button:SetScale(scaleFactor * 60 / 100) end
	end
end

local function layoutMultiBarButtons()
	for i = 1, 12 do
		local left = _G["MultiBarBottomLeftButton"..i]
		lockPoint(left, "BOTTOM", UIParent, "BOTTOM", BAR_OFFSETS_12[i], 75)
		if left then left:SetScale(scaleFactor * 60 / 100) end

		local right = _G["MultiBarBottomRightButton"..i]
		lockPoint(right, "BOTTOM", UIParent, "BOTTOM", BAR_OFFSETS_12[i], 132)
		if right then right:SetScale(scaleFactor * 60 / 100) end
	end
end

local function layoutStanceBar()
	for i = 1, 6 do
		local button = _G["StanceButton"..i]
		lockPoint(button, "BOTTOM", UIParent, "BOTTOM", STANCE_OFFSETS[i], 1)
		if button then button:SetScale(scaleFactor * 48 / 100) end
	end
end

local function layoutPetBar()
	if not showPetBar then return end
	local bar = PetActionBarFrame
	if not bar then return end
	if MainMenuExpBar then
		lockPoint(bar, "BOTTOMLEFT", MainMenuExpBar, "TOPLEFT", -12, 50)
	else
		lockPoint(bar, "BOTTOM", UIParent, "BOTTOM", -77, 194)
	end
	bar:SetScale(scaleFactor * 60 / 100)
	-- Blizzard also likes to resize this one back to its default; block that too.
	bar.SetSize = function() end
	bar.SetWidth = function() end
	bar.SetHeight = function() end
end

local MICRO_BUTTONS_LEFT = {
	{"CharacterMicroButton", -92},
	{"SpellbookMicroButton", -67},
	{"TalentMicroButton", -42},
	{"QuestLogMicroButton", -17},
}
local MICRO_BUTTONS_RIGHT = {
	{"WorldMapMicroButton", 42},
	{"HelpMicroButton", 67},
	{"MainMenuMicroButton", 92},
	{"SocialsMicroButton", 117},
}

local function layoutMicroMenu()
	for _, entry in ipairs(MICRO_BUTTONS_LEFT) do
		local button = _G[entry[1]]
		lockPoint(button, "BOTTOM", UIParent, "BOTTOM", entry[2], -2)
		if button then button:SetScale(scaleFactor * 42 / 100) end
	end
	for _, entry in ipairs(MICRO_BUTTONS_RIGHT) do
		local button = _G[entry[1]]
		lockPoint(button, "BOTTOM", UIParent, "BOTTOM", entry[2], -2)
		if button then button:SetScale(scaleFactor * 42 / 100) end
	end

--Social Button:
	
	local socialButton = GuildMicroButton or SocialsMicroButton
	lockPoint(socialButton, "BOTTOM", UIParent, "BOTTOM", 17, -2)
	if socialButton then socialButton:SetScale(scaleFactor * 42 / 100) end

--Action Bar Page Number:

	if MainActionBar
		and MainActionBar.ActionBarPageNumber
		and MainActionBar.ActionBarPageNumber.Text then

		local pageText = MainActionBar.ActionBarPageNumber.Text
		lockPoint(pageText, "BOTTOM", UIParent, "BOTTOM", 5, 7)
		pageText:SetScale(scaleFactor * 62 / 100)
	end

--Action Bar Arrow Up:
	
	if MainActionBar
		and MainActionBar.ActionBarPageNumber
		and MainActionBar.ActionBarPageNumber.UpButton then

		local upButton = MainActionBar.ActionBarPageNumber.UpButton
		lockPoint(upButton, "BOTTOM", UIParent, "BOTTOM", 20, 16) 
		upButton:SetScale(scaleFactor * 42 / 100)
	end

--Action Bar Arrow Down:

	if MainActionBar
		and MainActionBar.ActionBarPageNumber
		and MainActionBar.ActionBarPageNumber.DownButton then

		local downButton = MainActionBar.ActionBarPageNumber.DownButton
		lockPoint(downButton, "BOTTOM", UIParent, "BOTTOM", 20, -2) 
		downButton:SetScale(scaleFactor * 42 / 100)
	end

	lockPoint(MainMenuBarPerformanceBarFrame, "BOTTOM", UIParent, "BOTTOM", 3, -9)
	if MainMenuBarPerformanceBarFrame then
		MainMenuBarPerformanceBarFrame:SetScale(scaleFactor * 33 / 100)
		setFrameStratLevel(MainMenuBarPerformanceBarFrame, "MEDIUM", 1)
	end
end

--Bags:

local BAG_SLOTS = {
	{"MainMenuBarBackpackButton", 400, 1, 38},
	{"KeyRingButton", 217, 0, 37},
	{"CharacterBag0Slot", 360, 1, 38},
	{"CharacterBag1Slot", 320, 1, 38},
	{"CharacterBag2Slot", 280, 1, 38},
	{"CharacterBag3Slot", 240, 1, 38},
}

local function layoutBags()
	for _, entry in ipairs(BAG_SLOTS) do
		local name, x, y, scalePct = entry[1], entry[2], entry[3], entry[4]
		local button = _G[name]
		lockPoint(button, "BOTTOM", UIParent, "BOTTOM", x, y)
		if button then button:SetScale(scaleFactor * scalePct / 100) end
	end
end

local function layoutChatFrames()
	for i = 1, 7 do
		setFrameStratLevel(_G["ChatFrame"..i], "MEDIUM", 1)
		setFrameStratLevel(_G["ChatFrame"..i.."EditBox"], "MEDIUM", 1)
	end
end

local function reconfigUI()
	hideMainBarChrome()

	if BDOMod_HealthOrb then BDOMod_HealthOrb:SetScale(scaleFactor * 70 / 100) end
	if BDOMod_ManaOrb then BDOMod_ManaOrb:SetScale(scaleFactor * 70 / 100) end
	if actionbarBackground then actionbarBackground:SetScale(scaleFactor * 90 / 100) end
	if leftArtwork then leftArtwork:SetScale(scaleFactor) end
	if rightArtwork then rightArtwork:SetScale(scaleFactor) end

	layoutMainActionBar()
	layoutMultiBarButtons()
	layoutStanceBar()
	layoutPetBar()
	layoutMicroMenu()
	layoutBags()
	layoutChatFrames()

	if CastingBarFrame then CastingBarFrame:SetScale(scaleFactor * 75 / 100) end

	lockPoint(ActionBarUpButton, "BOTTOM", UIParent, "BOTTOM", 358, 42)
	if ActionBarUpButton then ActionBarUpButton:SetScale(scaleFactor * 46 / 100) end

	lockPoint(ActionBarDownButton, "BOTTOM", UIParent, "BOTTOM", 358, 25)
	if ActionBarDownButton then ActionBarDownButton:SetScale(scaleFactor * 46 / 100) end

	lockPoint(MainMenuExpBar, "BOTTOM", UIParent, "BOTTOM", -3, 228)
	if MainMenuExpBar then MainMenuExpBar:SetScale(scaleFactor * 31 / 100) end
end


----------------------------------------------------------------------
--  DYNAMIC BITS - these re-run on their own triggers, not just once
----------------------------------------------------------------------

local function handleExpReputationBars()

    if MainStatusTrackingBarContainer and MainStatusTrackingBarContainer:IsShown() then
        MainStatusTrackingBarContainer:SetScale(scaleFactor * 31 / 100)

        if SecondaryStatusTrackingBarContainer and SecondaryStatusTrackingBarContainer:IsShown() then
            SecondaryStatusTrackingBarContainer:SetScale(scaleFactor * 31 / 100)

            lockPoint(SecondaryStatusTrackingBarContainer, "BOTTOM", UIParent, "BOTTOM", -3, 236)
            lockPoint(MainStatusTrackingBarContainer, "BOTTOM", UIParent, "BOTTOM", -3, 222)

        else
            lockPoint(MainStatusTrackingBarContainer, "BOTTOM", UIParent, "BOTTOM", -3, 228)
        end

    elseif SecondaryStatusTrackingBarContainer and SecondaryStatusTrackingBarContainer:IsShown() then

        SecondaryStatusTrackingBarContainer:SetScale(scaleFactor * 31 / 100)
        lockPoint(SecondaryStatusTrackingBarContainer, "BOTTOM", UIParent, "BOTTOM", -3, 230)

    end
end





local function handleMultiBars()
	if MultiBarRight then MultiBarRight:SetScale(scaleFactor * 58 / 100) end
	if MultiBarLeft then MultiBarLeft:SetScale(scaleFactor * 58 / 100) end
end

local function handleVehicleLeaveButton()
	lockPoint(MainMenuBarVehicleLeaveButton, "BOTTOM", UIParent, "BOTTOM", 260, 180)
	if MainMenuBarVehicleLeaveButton then
		MainMenuBarVehicleLeaveButton:SetScale(scaleFactor * 58 / 100)
	end
end

-- Unused by default, kept as a utility if you ever want to let a frame
-- be shift-click dragged around, e.g. makeFrameMovable(SomeFrame)
local function makeFrameMovable(frame, button)
	if not frame then return end
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:SetUserPlaced(true)
	frame:SetClampedToScreen(true)
	frame:SetClampRectInsets(0, 0, 0, 0)
	frame:RegisterForDrag(button or "LeftButton")
	frame:SetScript("OnDragStart", function(self)
		if IsShiftKeyDown() then
			self:StartMoving()
		end
	end)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
	end)
end

local function hookingScripts()

	if MainStatusTrackingBarContainer then
		MainStatusTrackingBarContainer:HookScript("OnShow", function()
			if UnitXPMax("player") == 0 and not GetWatchedFactionInfo() then
				MainStatusTrackingBarContainer:Hide()
			end
		end)
	end

	if SecondaryStatusTrackingBarContainer then
		SecondaryStatusTrackingBarContainer:HookScript("OnShow", function()
			if not GetWatchedFactionInfo() then
				SecondaryStatusTrackingBarContainer:Hide()
			end
		end)
	end

	if VerticalMultiBarsContainer then
		VerticalMultiBarsContainer:HookScript("OnEvent", function()
			handleMultiBars()
		end)
	end
end




----------------------------------------------------------------------
--  EVENTS - hooked up from the addon's XML file, keep these names
----------------------------------------------------------------------

function BDOMod_OnLoad()
	BDOMod_HealthOrb:RegisterEvent("UNIT_HEALTH")
	BDOMod_HealthOrb:RegisterEvent("UNIT_POWER_UPDATE")
	BDOMod_HealthOrb:RegisterEvent("UNIT_DISPLAYPOWER")
	BDOMod_HealthOrb:RegisterEvent("PLAYER_ENTERING_WORLD")
	BDOMod_HealthOrb:RegisterEvent("SPELL_UPDATE_USABLE")
	BDOMod_HealthOrb:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
	BDOMod_HealthOrb:RegisterEvent("PLAYER_LEVEL_UP")
	BDOMod_HealthOrb:RegisterEvent("UPDATE_EXHAUSTION")
	BDOMod_HealthOrb:RegisterEvent("UPDATE_FACTION")

end

function BDOMod_OnEvent(event)
	if event == "PLAYER_ENTERING_WORLD" then
		safeCall("setupOrbs", setupOrbs)
		safeCall("createArtwork", createArtwork)
		safeCall("reconfigUI", reconfigUI)
		safeCall("hookingScripts", hookingScripts)
		safeCall("handleExpReputationBars", handleExpReputationBars)
		safeCall("handleMultiBars", handleMultiBars)
		safeCall("handleVehicleLeaveButton", handleVehicleLeaveButton)
		safeCall("updatePowerType", updatePowerType)
		safeCall("updateHealthOrb", updateHealthOrb)
		safeCall("updateManaOrb", updateManaOrb)
		return
	end
	if event == "UNIT_DISPLAYPOWER" then
		safeCall("updatePowerType", updatePowerType)
		safeCall("updateHealthOrb", updateHealthOrb)
		safeCall("updateManaOrb", updateManaOrb)
		return
	end
	if event == "UNIT_HEALTH" then
		safeCall("updateHealthOrb", updateHealthOrb)
		return
	end
	if event == "UNIT_POWER_UPDATE" then
		safeCall("updateManaOrb", updateManaOrb)
		return
	end
	if event == "SPELL_UPDATE_USABLE" or event == "ACTIONBAR_PAGE_CHANGED" then
		if not UnitAffectingCombat("player") then
			safeCall("handleMultiBars", handleMultiBars)
			safeCall("handleVehicleLeaveButton", handleVehicleLeaveButton)
		end
		return
	end
end