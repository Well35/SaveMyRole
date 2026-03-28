-- SaveMyRole.lua
-- Saves your preferred group role per spec and auto-applies it when joining a group.

local ADDON_NAME = "SaveMyRole"

local wasInGroup    = false
local loginDone     = false
local uiCreated     = false
local talentedHooked = false
local roleBtn       = nil
local rolePopup     = nil
local viewedSpec    = nil

local ROLES = {
    { key = "TANK",    label = "Tank" },
    { key = "HEALER",  label = "Healer" },
    { key = "DAMAGER", label = "DPS" },
}

local ROLE_LABEL = {}
for _, r in ipairs(ROLES) do ROLE_LABEL[r.key] = r.label end

local function GetActiveSpec()
    return (GetActiveTalentGroup and GetActiveTalentGroup()) or 1
end

local function GetViewedSpec()
    return viewedSpec or GetActiveSpec()
end

local function GetRoleForSpec(spec)
    if not SaveMyRoleConfig.specRoles then
        SaveMyRoleConfig.specRoles = {}
    end
    if SaveMyRoleConfig.specRoles[spec] == nil then
        SaveMyRoleConfig.specRoles[spec] = "DAMAGER"
    end
    return SaveMyRoleConfig.specRoles[spec]
end

local function GetPreferredRole()
    return GetRoleForSpec(GetActiveSpec())
end

local function SetPreferredRole(role)
    if not SaveMyRoleConfig.specRoles then
        SaveMyRoleConfig.specRoles = {}
    end
    SaveMyRoleConfig.specRoles[GetViewedSpec()] = role
end

local function ApplyPreferredRole()
    local role = GetPreferredRole()
    if role and IsInGroup() then
        UnitSetRole("player", role)
    end
end

local function IsTalentedLoaded()
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        return C_AddOns.IsAddOnLoaded("Talented") or C_AddOns.IsAddOnLoaded("Talented_Classic")
    end
    return IsAddOnLoaded("Talented") or IsAddOnLoaded("Talented_Classic")
end

local function MakeBackdropFrame(parent, w, h)
    local f = CreateFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    f:SetSize(w, h)
    if f.SetBackdrop then
        f:SetBackdrop({
            bgFile   = "Interface/Buttons/WHITE8X8",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            edgeSize = 10,
            insets   = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        f:SetBackdropColor(0, 0, 0, 0.97)
        f:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    else
        local bg = f:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0, 0, 0, 0.97)
    end
    return f
end

local function UpdateRoleButton()
    if not roleBtn then return end
    local role = GetRoleForSpec(GetViewedSpec())

    if role then
        roleBtn.icon:SetAtlas(GetMicroIconForRole(role))
        roleBtn.icon:Show()
        roleBtn.offLabel:Hide()
    else
        roleBtn.icon:Hide()
        roleBtn.offLabel:Show()
    end

    if rolePopup and rolePopup:IsShown() then
        for _, row in ipairs(rolePopup.rows) do
            row.radio:SetChecked(row.roleKey == role)
        end
    end
end

local function CreateRoleUI()
    if uiCreated then return end

    local parent
    if IsTalentedLoaded() then
        parent = TalentedFrame
    else
        parent = PlayerTalentFrame
    end
    if not parent then return end

    uiCreated = true

    roleBtn = CreateFrame("Button", "SaveMyRoleMainBtn", parent)
    roleBtn:SetSize(34, 34)

    if IsTalentedLoaded() then
        roleBtn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -4, -34)
        roleBtn:SetFrameStrata("DIALOG")
    else
        roleBtn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -35, -40)
        roleBtn:SetFrameStrata("HIGH")
    end

    roleBtn:SetNormalTexture("")
    roleBtn:SetHighlightTexture("")
    roleBtn:SetPushedTexture("")
    roleBtn:SetDisabledTexture("")

    local icon = roleBtn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(28, 28)
    icon:SetPoint("CENTER")
    icon:SetVertexColor(1, 1, 1)
    roleBtn.icon = icon

    local offLabel = roleBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    offLabel:SetPoint("CENTER")
    offLabel:SetText("Role")
    offLabel:SetTextColor(0.6, 0.6, 0.6)
    roleBtn.offLabel = offLabel

    roleBtn:SetScript("OnEnter", function(self)
        self.icon:SetVertexColor(0.7, 0.7, 0.7)
        local spec = GetViewedSpec()
        local role = GetRoleForSpec(spec)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Preferred Group Role")
        GameTooltip:AddLine("Currently: " .. (ROLE_LABEL[role] or role), 1, 1, 1)
        GameTooltip:AddLine("Click to change", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    roleBtn:SetScript("OnLeave", function(self)
        self.icon:SetVertexColor(1, 1, 1)
        GameTooltip:Hide()
    end)

    local popupW = 140
    local popupH = 28 + #ROLES * 26
    rolePopup = MakeBackdropFrame(parent, popupW, popupH)
    rolePopup:SetPoint("BOTTOMLEFT", roleBtn, "TOPRIGHT", 4, -10)
    rolePopup:SetFrameStrata("TOOLTIP")
    rolePopup:Hide()

    local header = rolePopup:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    header:SetPoint("TOPLEFT", rolePopup, "TOPLEFT", 8, -6)
    header:SetText("Set Role")
    header:SetTextColor(1, 0.82, 0)
    rolePopup.header = header

    rolePopup.rows = {}
    for i, roleInfo in ipairs(ROLES) do
        local row = CreateFrame("Button", "SaveMyRolePopupRow" .. i, rolePopup)
        row:SetSize(popupW - 10, 24)
        row:SetPoint("TOPLEFT", rolePopup, "TOPLEFT", 5, -(22 + (i - 1) * 26))
        row.roleKey = roleInfo.key

        local rowHl = row:CreateTexture(nil, "HIGHLIGHT")
        rowHl:SetAllPoints()
        rowHl:SetColorTexture(1, 1, 1, 0.1)

        local radio = CreateFrame("CheckButton", nil, row, "UIRadioButtonTemplate")
        radio:SetSize(16, 16)
        radio:SetPoint("LEFT", row, "LEFT", 2, 0)
        radio:EnableMouse(false)
        if radio:GetFontString() then radio:GetFontString():Hide() end
        row.radio = radio

        local rowIcon = row:CreateTexture(nil, "ARTWORK")
        rowIcon:SetSize(16, 16)
        rowIcon:SetPoint("LEFT", row, "LEFT", 22, 0)
        rowIcon:SetAtlas(GetMicroIconForRole(roleInfo.key))

        local rowLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        rowLabel:SetPoint("LEFT", row, "LEFT", 42, 0)
        rowLabel:SetText(roleInfo.label)
        rowLabel:SetTextColor(1, 1, 1)

        row:SetScript("OnClick", function(self)
            SetPreferredRole(self.roleKey)
            rolePopup:Hide()
            UpdateRoleButton()
            ApplyPreferredRole()
        end)

        rolePopup.rows[i] = row
    end

    roleBtn:SetScript("OnClick", function(self)
        if rolePopup:IsShown() then
            rolePopup:Hide()
        else
            rolePopup:Show()
            UpdateRoleButton()
        end
    end)

    if IsTalentedLoaded() then
        -- Talented_SpecTabs creates Talented.tabs with .spec1 / .spec2 checkbuttons.
        if Talented and Talented.tabs then
            for specIndex, specKey in ipairs({ "spec1", "spec2" }) do
                local tab = Talented.tabs[specKey]
                if tab then
                    tab:HookScript("OnClick", function()
                        viewedSpec = specIndex
                        UpdateRoleButton()
                    end)
                end
            end
        end
    else
        -- Standard Blizzard dual-spec tabs
        for i = 1, 2 do
            local tab = _G["PlayerSpecTab" .. i]
            if tab then
                local specIndex = i
                tab:HookScript("OnClick", function()
                    viewedSpec = specIndex
                    UpdateRoleButton()
                end)
            end
        end
    end

    parent:HookScript("OnHide", function()
        rolePopup:Hide()
    end)

    UpdateRoleButton()
end

local function HookTalentFrame()
    if IsTalentedLoaded() then
        if talentedHooked then return end
        talentedHooked = true

        local function onTalentedShow()
            if not uiCreated then
                CreateRoleUI()
            end
            UpdateRoleButton()
        end

        if TalentedFrame then
            TalentedFrame:HookScript("OnShow", onTalentedShow)
        else

            hooksecurefunc("ToggleTalentFrame", function()
                if not TalentedFrame then return end
                if not uiCreated then

                    TalentedFrame:HookScript("OnShow", onTalentedShow)
                    CreateRoleUI()
                end
                UpdateRoleButton()
            end)
        end
    else
        if PlayerTalentFrame then
            PlayerTalentFrame:HookScript("OnShow", function()
                CreateRoleUI()
                UpdateRoleButton()
            end)
        end
    end
end

local smrFrame = CreateFrame("Frame", "SaveMyRoleFrame")
smrFrame:RegisterEvent("ADDON_LOADED")
smrFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
smrFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
smrFrame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")

smrFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        if not SaveMyRoleConfig then
            SaveMyRoleConfig = {}
        end
        -- Migrate old single-role save to per-spec table
        if SaveMyRoleConfig.preferredRole then
            SaveMyRoleConfig.specRoles = SaveMyRoleConfig.specRoles or {}
            if not SaveMyRoleConfig.specRoles[1] then
                SaveMyRoleConfig.specRoles[1] = SaveMyRoleConfig.preferredRole
            end
            SaveMyRoleConfig.preferredRole = nil
        end
        HookTalentFrame()

    elseif event == "PLAYER_ENTERING_WORLD" then
        if not uiCreated then
            HookTalentFrame()
        end
        if not loginDone then
            loginDone = true
            wasInGroup = IsInGroup()
            if wasInGroup then
                ApplyPreferredRole()
            end
        end

    elseif event == "ACTIVE_TALENT_GROUP_CHANGED" then
        -- Spec switched — track the new active spec and apply its role
        viewedSpec = GetActiveSpec()
        UpdateRoleButton()
        ApplyPreferredRole()

    elseif event == "GROUP_ROSTER_UPDATE" then
        local inGroup = IsInGroup()
        if inGroup and not wasInGroup then
            ApplyPreferredRole()
        end
        wasInGroup = inGroup
    end
end)

SLASH_SAVEMYROLE1 = "/smr"
SLASH_SAVEMYROLE2 = "/savemyrole"
SlashCmdList["SAVEMYROLE"] = function()
    local numSpecs = (GetNumTalentGroups and GetNumTalentGroups()) or 1
    if numSpecs > 1 then
        for s = 1, numSpecs do
            local r = (SaveMyRoleConfig.specRoles and SaveMyRoleConfig.specRoles[s])
            print("|cff00ff00SaveMyRole:|r Spec " .. s .. ": " .. (ROLE_LABEL[r] or "None"))
        end
    else
        local role = GetPreferredRole() or "None"
        print("|cff00ff00SaveMyRole:|r Preferred role is " .. role)
    end
end
