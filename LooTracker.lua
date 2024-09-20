-- Define addon namespace
local LooTracker = LibStub("AceAddon-3.0"):NewAddon("LooTracker", "AceEvent-3.0", "AceConsole-3.0")
local AceGUI = LibStub("AceGUI-3.0")
local LDB = LibStub("LibDataBroker-1.1")
local LDBIcon = LibStub("LibDBIcon-1.0")

-- Default settings for the addon
LooTracker.defaults = {
    profile = {
        rarity = "Rare",
        showMinimapButton = true,
        fontSize = 14,
        frameSize = 300,
        keybind = "None",
        closeWithESC = true,
        debugMode = false,
        minimapButtonPosition = {},
        framePoint = {"CENTER", 0, 0}
    }
}

-- Initialize or load saved variables
function LooTracker:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("LooTrackerDB", self.defaults, true)
    self.settings = self.db.profile

    self:UpdateMinimapButton()
    self:RegisterChatCommand("lt", "OnChatCommand")
    self:CreateMainFrame()
    self:CreateOptionsButton()
end

-- Set up the main frame when the addon is enabled
function LooTracker:OnEnable()
    if not self.db then
        print("Database is not initialized!")
        return
    end

    local point, x, y = unpack(self.db.profile.framePoint)
    self.frame:SetPoint(point, UIParent, point, x, y)
    self:RegisterEvent("ADDON_LOADED", "OnAddonLoaded")
end

-- Create the main frame
function LooTracker:CreateMainFrame()
    self.frame = CreateFrame("Frame", "LooTrackerFrame", UIParent)
    self.frame:SetSize(self.db.profile.frameSize, self.db.profile.frameSize)
    self.frame:SetPoint("CENTER")
    self.frame:SetResizable(true)
    self.frame:SetMovable(true)
    self.frame:EnableMouse(true)
    self.frame:SetScript("OnMouseDown", function(self) self:StartMoving() end)
    self.frame:SetScript("OnMouseUp", function(self) self:StopMovingOrSizing() end)

    self.frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 32, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    self.frame:SetBackdropColor(0, 0, 0, 1)
    self.frame:SetBackdropBorderColor(1, 1, 1, 1)
    self.frame:Hide()

    self:CreateResizeGrip()
    self:CreateOptionsButton() -- Moved button creation here
end

-- Create resize grip
function LooTracker:CreateResizeGrip()
    local resizeGrip = CreateFrame("Frame", nil, self.frame)
    resizeGrip:SetSize(20, 20)
    resizeGrip:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", 0, 0)
    resizeGrip:EnableMouse(true)

    -- Add a texture for the resize grip
    resizeGrip.texture = resizeGrip:CreateTexture(nil, "ARTWORK")
    resizeGrip.texture:SetAllPoints()
    resizeGrip.texture:SetTexture("Interface\\Buttons\\UI-Panel-ResizeHandle")

    resizeGrip:SetScript("OnMouseDown", function()
        self.frame:StartSizing("BOTTOMRIGHT")
    end)

    resizeGrip:SetScript("OnMouseUp", function()
        self.frame:StopMovingOrSizing()
        local width, height = self.frame:GetSize()
        self.db.profile.frameSize = width -- Save the new size
    end)
end

-- Create the options button inside the frame
function LooTracker:CreateOptionsButton()
    local optionsButton = CreateFrame("Button", "LooTrackerOptionsButton", self.frame, "UIPanelButtonTemplate")
    optionsButton:SetSize(100, 25)
    optionsButton:SetText("Options")
    optionsButton:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -10, -10)
    optionsButton:SetScript("OnClick", function()
        self:ToggleOptionsFrame()
    end)
end

-- Toggle options frame visibility
function LooTracker:ToggleOptionsFrame()
    if not self.optionsFrame then
        print("Options frame is nil, initializing...")
        self:InitializeOptionsFrame()
    end

    if self.optionsFrame and self.optionsFrame.frame then
        self.optionsFrame.frame:SetShown(not self.optionsFrame.frame:IsShown())
    else
        print("Failed to create options frame.")
    end
end

-- Initialize the options frame using AceGUI
function LooTracker:InitializeOptionsFrame()
    if not self.optionsFrame then
        print("Creating options frame...")
        self.optionsFrame = AceGUI:Create("Frame")
        self.optionsFrame:SetTitle("LooTracker Options")
        self.optionsFrame:SetStatusText("Adjust your settings here.")
        self.optionsFrame:SetLayout("Flow")
        self.optionsFrame:SetWidth(400)
        self.optionsFrame:SetHeight(400)
        self.optionsFrame:SetCallback("OnClose", function(widget) widget:Hide() end)
        self.optionsFrame:Hide()

        -- Minimap button checkbox
        local minimapCheckbox = AceGUI:Create("CheckBox")
        minimapCheckbox:SetLabel("Show Minimap Button")
        minimapCheckbox:SetValue(self.settings.showMinimapButton)
        minimapCheckbox:SetCallback("OnValueChanged", function(_, _, value)
            self.settings.showMinimapButton = value
            self:UpdateMinimapButton()
        end)
        self.optionsFrame:AddChild(minimapCheckbox)

        -- Call to create rarity toggle buttons
        self:CreateRarityToggleButtons()
    end
end

function LooTracker:CreateRarityToggleButtons()
    if not self.optionsFrame then
        print("Options frame not found.")
        return
    end

    local rarities = {
        {name = "Common", color = "|cffffffff"},
        {name = "Uncommon", color = "|cff1eff00"},
        {name = "Rare", color = "|cff0070dd"},
        {name = "Epic", color = "|cffa335ee"},
        {name = "Legendary", color = "|cffff8000"},
        {name = "Vanity", color = "|cffe5cc80"}
    }

    for _, rarity in ipairs(rarities) do
        local toggleButton = AceGUI:Create("CheckBox")
        toggleButton:SetLabel(rarity.color .. rarity.name .. "|r")
        toggleButton:SetValue(self.settings[rarity.name] or false)
        toggleButton:SetCallback("OnValueChanged", function(_, _, value)
            self.settings[rarity.name] = value
            print(rarity.name .. " set to " .. tostring(value))
            self:UpdateLootDisplay()
        end)

        self.optionsFrame:AddChild(toggleButton)
    end

    print("Rarity toggle buttons created.")
end

function LooTracker:UpdateLootDisplay()
    local visibleItems = {}

    -- Logic to filter and display items based on selected rarities
    for rarity, isEnabled in pairs(self.settings) do
        if isEnabled then
            for _, item in ipairs(items) do
                if item.rarity == rarity then
                    table.insert(visibleItems, item)
                end
            end
        else
            for _, item in ipairs(items) do
                if item.rarity == rarity then
                end
            end
        end
    end

    -- Update the display with the visible items
    self:DisplayItems(visibleItems)
end

function LooTracker:DisplayItems(itemsToDisplay)
    -- Clear current display
    print("Current visible items:")
    for _, item in ipairs(itemsToDisplay) do
        print("- " .. item.name .. " (Rarity: " .. item.rarity .. ")")
    end
end

-- Update minimap button visibility and customization
function LooTracker:UpdateMinimapButton()
    if not self.settings then return end

    if self.settings.showMinimapButton then
        if not self.dataObject then
            self.dataObject = LDB:NewDataObject("LooTracker", {
                type = "data source",
                text = "LooTracker",
                icon = "Interface\\Icons\\INV_Misc_Coin_01",
                OnClick = function(_, button)
                    if button == "LeftButton" then
                        self.frame:SetShown(not self.frame:IsShown())
                    end
                end,
            })
        end

        if not LDBIcon:IsRegistered("LooTracker") then
            LDBIcon:Register("LooTracker", self.dataObject, self.db.profile.minimapButtonPosition)
        else
            LDBIcon:Show("LooTracker")
        end
    else
        LDBIcon:Hide("LooTracker")
    end
end

-- Handle chat commands
function LooTracker:OnChatCommand(input)
    if input == "show" then
        self.frame:Show()
    elseif input == "hide" then
        self.frame:Hide()
    elseif input == "ui" or input == "ltui" then
        self.frame:SetShown(not self.frame:IsShown()) -- Toggle the main frame
    else
        self:Print("Unknown command. Use 'show', 'hide', or 'ltui'.")
    end
end

-- Handle addon loading
function LooTracker:OnAddonLoaded(addonName)
    if addonName == "LooTracker" then
        -- Perform additional initialization here if needed
        print("LooTracker Loaded!")
    end
end

-- Set up the main frame and options frame when the addon is enabled
LooTracker:OnEnable()