-- Define addon namespace
local LooTracker = LibStub("AceAddon-3.0"):NewAddon("LooTracker", "AceEvent-3.0", "AceConsole-3.0")
local AceGUI = LibStub("AceGUI-3.0")

-- Default settings for the addon
LooTracker.defaults = {
    profile = {
        rarityFilters = {
            Common = true,
            Uncommon = true,
            Rare = true,
            Epic = true,
            Legendary = true,
            Vanity = true,
        },
        showMinimapButton = true,
        fontSize = 14,
        frameSize = {width = 300, height = 300},  -- Changed to a table
        keybind = "None",
        closeWithESC = true,
        debugMode = false,
        minimapButtonPosition = {},
        framePoint = {"CENTER", 0, 0},
        itemsPerPage = 10, -- Default number of items per page for pagination
        hideRollMessages = false -- Option to hide /roll messages
    }
}

-- Initialize or load saved variables
function LooTracker:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("LooTrackerDB", self.defaults, true)
    self.settings = self.db.profile
    self.currentPage = 1 -- Track the current page for pagination
    self.items = {} -- Placeholder for item list to display

    self:CreateMainFrame()
    self:RegisterChatCommand("lt", "OnChatCommand")
    self:RegisterEvent("CHAT_MSG_SYSTEM", "FilterRollMessages") -- Event to capture /roll messages
end

-- Set up the main frame when the addon is enabled
function LooTracker:OnEnable()
    self:UpdateLootDisplay() -- Ensure the display is updated after enabling
end

-- Create the main frame
function LooTracker:CreateMainFrame()
    self.frame = CreateFrame("Frame", "LooTrackerFrame", UIParent)
    self.frame:SetSize(self.db.profile.frameSize.width, self.db.profile.frameSize.height)
    self.frame:SetPoint(unpack(self.db.profile.framePoint))
    self.frame:EnableMouse(true)
    self.frame:SetMovable(true)
    self.frame:SetResizable(true)
    self.frame:SetClampedToScreen(true)

    self.frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 32, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    self.frame:SetBackdropColor(0, 0, 0, 1)

    self.frame:SetScript("OnMouseDown", function() self.frame:StartMoving() end)
    self.frame:SetScript("OnMouseUp", function() self.frame:StopMovingOrSizing() end)

    self:CreateScrollFrame() -- Create scroll frame
    self:CreatePaginationButtons() -- Add pagination buttons

    -- Show the frame if it was previously open
    if self.db.profile.showMainFrame then
        self.frame:Show()
    end
end

-- Create a scroll frame for displaying loot items
function LooTracker:CreateScrollFrame()
    self.scrollFrame = CreateFrame("ScrollFrame", nil, self.frame, "UIPanelScrollFrameTemplate")
    self.scrollFrame:SetPoint("TOPLEFT", 10, -30)
    self.scrollFrame:SetSize(self.frame:GetWidth() - 30, self.frame:GetHeight() - 70)

    self.scrollChild = CreateFrame("Frame", nil, self.scrollFrame)
    self.scrollChild:SetSize(self.scrollFrame:GetWidth(), self.scrollFrame:GetHeight())
    self.scrollFrame:SetScrollChild(self.scrollChild)

    -- Placeholder for the loot display
    self.itemList = {}
end

-- Create pagination buttons
function LooTracker:CreatePaginationButtons()
    local prevButton = CreateFrame("Button", nil, self.frame, "UIPanelButtonTemplate")
    prevButton:SetSize(60, 25)
    prevButton:SetText("Prev")
    prevButton:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", 10, 10)
    prevButton:SetScript("OnClick", function() self:GoToPreviousPage() end)

    local nextButton = CreateFrame("Button", nil, self.frame, "UIPanelButtonTemplate")
    nextButton:SetSize(60, 25)
    nextButton:SetText("Next")
    nextButton:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -10, 10)
    nextButton:SetScript("OnClick", function() self:GoToNextPage() end)
end

-- Pagination logic: Go to the previous page
function LooTracker:GoToPreviousPage()
    if self.currentPage > 1 then
        self.currentPage = self.currentPage - 1
        self:UpdateLootDisplay()
    end
end

-- Pagination logic: Go to the next page
function LooTracker:GoToNextPage()
    local maxPage = math.ceil(#self.items / self.db.profile.itemsPerPage)
    if self.currentPage < maxPage then
        self.currentPage = self.currentPage + 1
        self:UpdateLootDisplay()
    end
end

-- Update loot display based on current page and rarity filter
function LooTracker:UpdateLootDisplay()
    local visibleItems = {}

    -- Apply rarity filter and pagination
    for _, item in ipairs(self.items) do
        if self.settings.rarityFilters[item.rarity] then
            table.insert(visibleItems, item)
        end
    end

    -- Paginate the visible items
    local startIdx = (self.currentPage - 1) * self.db.profile.itemsPerPage + 1
    local endIdx = math.min(startIdx + self.db.profile.itemsPerPage - 1, #visibleItems)

    -- Display the paginated items
    self:DisplayItems(visibleItems, startIdx, endIdx)
end

-- Display a subset of items in the scroll frame
function LooTracker:DisplayItems(itemsToDisplay, startIdx, endIdx)
    -- Clear current item list
    for _, item in ipairs(self.itemList) do
        item:Hide()
    end

    -- Create new display for the current items in the page
    for i = startIdx, endIdx do
        local item = itemsToDisplay[i]
        if not self.itemList[i] then
            self.itemList[i] = self.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        end

        local itemFont = self.itemList[i]
        itemFont:SetText(item.name .. " (Rarity: " .. item.rarity .. ")")
        itemFont:SetPoint("TOPLEFT", 10, -30 * (i - startIdx + 1))
        itemFont:Show()
    end
end

-- Filter and suppress /roll messages if enabled
function LooTracker:FilterRollMessages(_, message)
    if self.settings.hideRollMessages and message:find("/roll") then
        return true -- Suppress the message
    end
end

-- Handle chat commands
function LooTracker:OnChatCommand(input)
    if input == "show" then
        self.frame:Show()
    elseif input == "hide" then
        self.frame:Hide()
    elseif input == "ui" then
        self.frame:SetShown(not self.frame:IsShown()) -- Toggle the main frame
    else
        self:Print("Unknown command. Use 'show', 'hide', or 'ui'.")
    end
end

-- Register and enable the addon
LooTracker:OnEnable()
