-- ==============================================================================
-- 🌟 เรื่องโปร Hub | ProScript - Ultimate Mobile & PC Edition (v9.0)
-- Features:
--   1. Premium Cyber-Green Aesthetic UI (Glow Strokes, Smooth Corners, Modern Pro Layout)
--   2. Restored v5.0 Step-Lerp Float Collector (Zero Physics Sparks, Smooth LuckySpots Tour)
--   3. Cross-Platform Universal Support (Mobile Touch Drag, On-Screen Quick Boost & Jump Buttons)
--   4. Instant Auto-Accelerate Boost & W/Throttle Speed Boost (VMAX & Thrust Presets)
--   5. Unlimited Air Jump, Ghost Mode, Infinite SP, Auto Whirl, and Anti-AFK
--   6. Official Channel Credits & Discord Community (https://discord.gg/gZpkSgmR8)
-- ==============================================================================

-- Clean up existing UI instances and connections
local ParentGui = (gethui and gethui())
    or (pcall(function() return game:GetService("CoreGui") end) and game:GetService("CoreGui"))
    or game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")

if parentGui and parentGui:FindFirstChild("RuengProHubUI") then
    parentGui.RuengProHubUI:Destroy()
end
if _G.RuengProDisconnect then
    pcall(_G.RuengProDisconnect)
end

-- Services initialization
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

-- Runtime configuration state
local Config = {
    AutoFarmMoney = false,
    InstantAutoBoost = false,
    ManualKeyBoost = true,
    InfiniteSP = true,
    InfiniteJump = true,
    GhostMode = true,
    AutoWhirlSkill = false,
    AntiAFK = true,
    VmaxKmh = 600,
    AccelRate = 5.0,
    JumpPower = 48,
    CapturedPickupArgs = nil
}

-- Backup stock vehicle physics values
local StockPhysics = {
    vmax = 100,
    btPower = 2.6,
    btDuration = 3.5,
    btNeedSP = 50
}

-- Safe reference lookup for game folders and remotes
local RBRCQuest = ReplicatedStorage:WaitForChild("RBRCQuest", 5)
local QuestRemotes = RBRCQuest and RBRCQuest:WaitForChild("Remotes", 5)
local WhirlCast = QuestRemotes and QuestRemotes:WaitForChild("WhirlCast", 5)
local WhirlHit = QuestRemotes and QuestRemotes:WaitForChild("WhirlHit", 5)
local WhirlClaim = QuestRemotes and QuestRemotes:WaitForChild("WhirlClaim", 5)

local RaycityPickups = ReplicatedStorage:WaitForChild("RaycityPickups", 5)
local PickupRemotes = RaycityPickups and RaycityPickups:WaitForChild("Remotes", 5)
local PickupEat = PickupRemotes and PickupRemotes:WaitForChild("PickupEat", 5)

local RaycityStreaming = ReplicatedStorage:WaitForChild("RaycityStreaming", 5)
local StreamingRemotes = RaycityStreaming and RaycityStreaming:WaitForChild("Remotes", 5)
local FocusUp = StreamingRemotes and StreamingRemotes:WaitForChild("FocusUp", 5)

-- Hook metamethod to capture exact PickupEat arguments
pcall(function()
    if hookmetamethod and getnamecallmethod then
        local oldNamecall
        oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            local args = {...}
            if (method == "FireServer" or method == "InvokeServer") and not checkcaller() then
                if self.Name == "PickupEat" then
                    Config.CapturedPickupArgs = args
                end
            end
            return oldNamecall(self, ...)
        end)
    end
end)

-- ==============================================================================
-- 1. Ghost Mode Bypass & Clean RCDrive Physics Table Lock
-- ==============================================================================

local Renv = getrenv and getrenv()
local RShared = Renv and Renv.shared
local RHooks = RShared and RShared.RCDrivePairHooks
if RHooks then
    if not Renv._origTrafficHook and RHooks.traffic then
        Renv._origTrafficHook = RHooks.traffic
    end
    if not Renv._origMovHook and RHooks.mov then
        Renv._origMovHook = RHooks.mov
    end
end

local function ApplyGhostMode(enable)
    pcall(function()
        LocalPlayer:SetAttribute("RaycityGM", true)
        LocalPlayer:SetAttribute("GmCheatOn", true)
        LocalPlayer:SetAttribute("GmCheatGhost", enable)
    end)

    if RHooks then
        if enable then
            RHooks.traffic = function() return nil end
            RHooks.mov = function() return nil end
        else
            if Renv._origTrafficHook then RHooks.traffic = Renv._origTrafficHook end
            if Renv._origMovHook then RHooks.mov = Renv._origMovHook end
        end
    end

    local trafficCars = Workspace:FindFirstChild("RBRCTrafficCars")
    if trafficCars and enable then
        for _, part in ipairs(trafficCars:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
    end
end
ApplyGhostMode(Config.GhostMode)

-- Retrieve active vehicle model and root BasePart
local function GetVehicleModelAndPart()
    local myCar = Workspace:FindFirstChild("MyCar")
    if myCar and myCar:IsA("Model") then
        local root = myCar:FindFirstChild("Root")
            or myCar:FindFirstChild("Hull")
            or myCar.PrimaryPart
            or myCar:FindFirstChildWhichIsA("BasePart", true)
        return myCar, root
    end

    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum and hum.SeatPart then
            local seatModel = hum.SeatPart:FindFirstAncestorOfClass("Model")
            if seatModel then
                return seatModel, hum.SeatPart
            end
        end
        return char, char:FindFirstChild("HumanoidRootPart")
    end
    return nil, nil
end

-- Locate LocalPlayer's active RCDrive physics table in Garbage Collector
local ActivePhysTable = nil
local LastGcScanTime = 0

local function GetCarPhysicsTable(forceScan)
    if not getgc then return nil end
    local _, root = GetVehicleModelAndPart()
    if not root then return nil end
    local rootPos = root.Position

    if not forceScan and ActivePhysTable and type(ActivePhysTable) == "table" and rawget(ActivePhysTable, "p") and rawget(ActivePhysTable, "cf") then
        local ok, currentPos = pcall(function() return ActivePhysTable.cf.Position * 2 end)
        if ok and currentPos and (currentPos - rootPos).Magnitude < 25 then
            return ActivePhysTable
        end
    end

    if not forceScan and (tick() - LastGcScanTime < 0.8) then
        return ActivePhysTable
    end
    LastGcScanTime = tick()

    local bestMatch = nil
    local minDistance = math.huge

    for _, v in pairs(getgc(true)) do
        if type(v) == "table" and rawget(v, "wheels") and rawget(v, "p") and rawget(v, "cf") then
            local ok, cfPos = pcall(function() return v.cf.Position * 2 end)
            if ok and cfPos then
                local dist = (cfPos - rootPos).Magnitude
                if dist < minDistance then
                    minDistance = dist
                    bestMatch = v
                end
            end
        end
    end

    if bestMatch and minDistance < 40 then
        ActivePhysTable = bestMatch
        if type(bestMatch.p) == "table" then
            StockPhysics.vmax = bestMatch.p.vmax or 100
            StockPhysics.btPower = bestMatch.p.btPower or 2.6
            StockPhysics.btDuration = bestMatch.p.btDuration or 3.5
            StockPhysics.btNeedSP = bestMatch.p.btNeedSP or 50
        end
    end

    return ActivePhysTable
end
GetCarPhysicsTable(true)

-- ==============================================================================
-- 2. Premium Cyber-Green Aesthetic UI Construction (Mobile & PC)
-- ==============================================================================

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "RuengProHubUI"
ScreenGui.Parent = ParentGui
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 999999
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Floating Menu Button (Cyber Green Glow)
local FloatingPill = Instance.new("TextButton")
FloatingPill.Name = "FloatingPill"
FloatingPill.Parent = ScreenGui
FloatingPill.BackgroundColor3 = Color3.fromRGB(10, 20, 15)
FloatingPill.Position = UDim2.new(0.02, 0, 0.16, 0)
FloatingPill.Size = UDim2.new(0, 155, 0, 40)
FloatingPill.Font = Enum.Font.GothamBold
FloatingPill.Text = "✨ เปิด/ปิด เมนู"
FloatingPill.TextColor3 = Color3.fromRGB(0, 255, 128)
FloatingPill.TextSize = 13
FloatingPill.Active = true

local PillCorner = Instance.new("UICorner")
PillCorner.CornerRadius = UDim.new(0, 20)
PillCorner.Parent = FloatingPill

local PillStroke = Instance.new("UIStroke")
PillStroke.Color = Color3.fromRGB(0, 255, 128)
PillStroke.Thickness = 2
PillStroke.Parent = FloatingPill

-- Floating Quick Jump Button
local QuickJumpPill = Instance.new("TextButton")
QuickJumpPill.Name = "QuickJumpPill"
QuickJumpPill.Parent = ScreenGui
QuickJumpPill.BackgroundColor3 = Color3.fromRGB(15, 30, 20)
QuickJumpPill.Position = UDim2.new(0.02, 0, 0.25, 0)
QuickJumpPill.Size = UDim2.new(0, 155, 0, 40)
QuickJumpPill.Font = Enum.Font.GothamBold
QuickJumpPill.Text = "🦘 กระโดดลอยตัว"
QuickJumpPill.TextColor3 = Color3.fromRGB(255, 230, 80)
QuickJumpPill.TextSize = 13
QuickJumpPill.Active = true

local QJCorner = Instance.new("UICorner")
QJCorner.CornerRadius = UDim.new(0, 20)
QJCorner.Parent = QuickJumpPill

local QJStroke = Instance.new("UIStroke")
QJStroke.Color = Color3.fromRGB(255, 215, 60)
QJStroke.Thickness = 2
QJStroke.Parent = QuickJumpPill

-- Floating Quick Boost Button
local QuickBoostPill = Instance.new("TextButton")
QuickBoostPill.Name = "QuickBoostPill"
QuickBoostPill.Parent = ScreenGui
QuickBoostPill.BackgroundColor3 = Color3.fromRGB(12, 28, 18)
QuickBoostPill.Position = UDim2.new(0.02, 0, 0.34, 0)
QuickBoostPill.Size = UDim2.new(0, 155, 0, 40)
QuickBoostPill.Font = Enum.Font.GothamBold
QuickBoostPill.Text = "🚀 พุ่งออโต้: OFF"
QuickBoostPill.TextColor3 = Color3.fromRGB(160, 245, 185)
QuickBoostPill.TextSize = 13
QuickBoostPill.Active = true

local QBCorner = Instance.new("UICorner")
QBCorner.CornerRadius = UDim.new(0, 20)
QBCorner.Parent = QuickBoostPill

local QBStroke = Instance.new("UIStroke")
QBStroke.Color = Color3.fromRGB(0, 230, 118)
QBStroke.Thickness = 2
QBStroke.Parent = QuickBoostPill

-- Main Window Frame
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Parent = ScreenGui
MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
MainFrame.BackgroundColor3 = Color3.fromRGB(10, 15, 12)
MainFrame.BorderSizePixel = 0
MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
MainFrame.Size = UDim2.new(0, 440, 0, 520)
MainFrame.Active = true

-- Responsive UIScale for Mobile Screens
local MainScale = Instance.new("UIScale")
MainScale.Parent = MainFrame

local function UpdateResponsiveScale()
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local vp = cam.ViewportSize
    local minDim = math.min(vp.X, vp.Y)
    if minDim < 520 then
        MainScale.Scale = math.clamp(minDim / 520, 0.65, 1.0)
    else
        MainScale.Scale = 1.0
    end
end
UpdateResponsiveScale()
if Workspace.CurrentCamera then
    Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(UpdateResponsiveScale)
end

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 14)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(0, 255, 128)
MainStroke.Thickness = 2.5
MainStroke.Parent = MainFrame

-- Title Bar (Branded Theme)
local TitleBar = Instance.new("Frame")
TitleBar.Name = "TitleBar"
TitleBar.Parent = MainFrame
TitleBar.BackgroundColor3 = Color3.fromRGB(16, 25, 18)
TitleBar.BorderSizePixel = 0
TitleBar.Size = UDim2.new(1, 0, 0, 52)
TitleBar.Active = true

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 14)
TitleCorner.Parent = TitleBar

local TitleFix = Instance.new("Frame")
TitleFix.Parent = TitleBar
TitleFix.BackgroundColor3 = Color3.fromRGB(16, 25, 18)
TitleFix.BorderSizePixel = 0
TitleFix.Position = UDim2.new(0, 0, 1, -12)
TitleFix.Size = UDim2.new(1, 0, 0, 12)

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Parent = TitleBar
TitleLabel.BackgroundTransparency = 1
TitleLabel.Position = UDim2.new(0, 16, 0, 6)
TitleLabel.Size = UDim2.new(1, -95, 0, 22)
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.Text = "เรื่องโปร Hub | ProScript"
TitleLabel.TextColor3 = Color3.fromRGB(0, 255, 128)
TitleLabel.TextSize = 16
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left

local SubTitleLabel = Instance.new("TextLabel")
SubTitleLabel.Parent = TitleBar
SubTitleLabel.BackgroundTransparency = 1
SubTitleLabel.Position = UDim2.new(0, 16, 0, 28)
SubTitleLabel.Size = UDim2.new(1, -95, 0, 18)
SubTitleLabel.Font = Enum.Font.GothamSemibold
SubTitleLabel.Text = "ช่อง: เรื่องโปร | Discord: discord.gg/gZpkSgmR8"
SubTitleLabel.TextColor3 = Color3.fromRGB(130, 240, 175)
SubTitleLabel.TextSize = 11
SubTitleLabel.TextXAlignment = Enum.TextXAlignment.Left

local MinBtn = Instance.new("TextButton")
MinBtn.Parent = TitleBar
MinBtn.BackgroundTransparency = 1
MinBtn.Position = UDim2.new(1, -78, 0, 0)
MinBtn.Size = UDim2.new(0, 36, 1, 0)
MinBtn.Font = Enum.Font.GothamBold
MinBtn.Text = "—"
MinBtn.TextColor3 = Color3.fromRGB(180, 240, 195)
MinBtn.TextSize = 16

local CloseBtn = Instance.new("TextButton")
CloseBtn.Parent = TitleBar
CloseBtn.BackgroundTransparency = 1
CloseBtn.Position = UDim2.new(1, -40, 0, 0)
CloseBtn.Size = UDim2.new(0, 40, 1, 0)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(255, 90, 90)
CloseBtn.TextSize = 16

MinBtn.Activated:Connect(function()
    MainFrame.Visible = false
end)

CloseBtn.Activated:Connect(function()
    if _G.RuengProDisconnect then pcall(_G.RuengProDisconnect) end
    ScreenGui:Destroy()
end)

-- Touch & Mouse Safe Dragging Helper
local function MakeTouchDraggable(dragHandle, targetFrame, onTapCallback)
    local dragging = false
    local dragInput = nil
    local dragStart = nil
    local startPos = nil
    local movedDistance = 0

    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = targetFrame.Position
            movedDistance = 0

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    if dragging then
                        dragging = false
                        if movedDistance < 10 and onTapCallback then
                            onTapCallback()
                        end
                    end
                end
            end)
        end
    end)

    dragHandle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            movedDistance = delta.Magnitude
            if movedDistance >= 6 then
                targetFrame.Position = UDim2.new(
                    startPos.X.Scale,
                    startPos.X.Offset + delta.X,
                    startPos.Y.Scale,
                    startPos.Y.Offset + delta.Y
                )
            end
        end
    end)
end

MakeTouchDraggable(TitleBar, MainFrame, nil)
MakeTouchDraggable(FloatingPill, FloatingPill, function()
    MainFrame.Visible = not MainFrame.Visible
end)

-- Status & Telemetry Dashboard
local InfoPanel = Instance.new("Frame")
InfoPanel.Parent = MainFrame
InfoPanel.BackgroundColor3 = Color3.fromRGB(14, 22, 16)
InfoPanel.Position = UDim2.new(0, 14, 0, 60)
InfoPanel.Size = UDim2.new(1, -28, 0, 56)

local InfoCorner = Instance.new("UICorner")
InfoCorner.CornerRadius = UDim.new(0, 10)
InfoCorner.Parent = InfoPanel

local InfoStroke = Instance.new("UIStroke")
InfoStroke.Color = Color3.fromRGB(0, 200, 100)
InfoStroke.Thickness = 1.5
InfoStroke.Parent = InfoPanel

local TelemetryLabel = Instance.new("TextLabel")
TelemetryLabel.Parent = InfoPanel
TelemetryLabel.BackgroundTransparency = 1
TelemetryLabel.Position = UDim2.new(0, 12, 0, 6)
TelemetryLabel.Size = UDim2.new(1, -24, 0, 20)
TelemetryLabel.Font = Enum.Font.GothamBold
TelemetryLabel.Text = "ความเร็ว: 0 km/h | 🌟 เรื่องโปร Hub พร้อมใช้งาน"
TelemetryLabel.TextColor3 = Color3.fromRGB(0, 255, 140)
TelemetryLabel.TextSize = 12
TelemetryLabel.TextXAlignment = Enum.TextXAlignment.Left

local StatusBox = Instance.new("TextLabel")
StatusBox.Parent = InfoPanel
StatusBox.BackgroundTransparency = 1
StatusBox.Position = UDim2.new(0, 12, 0, 28)
StatusBox.Size = UDim2.new(1, -24, 0, 22)
StatusBox.Font = Enum.Font.Code
StatusBox.Text = "Status: เปิดใช้งานระบบลอยเก็บของ + สปีดแฮกมือถือ"
StatusBox.TextColor3 = Color3.fromRGB(180, 245, 205)
StatusBox.TextSize = 11
StatusBox.TextXAlignment = Enum.TextXAlignment.Left

-- Scrollable Controls Container
local Container = Instance.new("ScrollingFrame")
Container.Name = "Container"
Container.Parent = MainFrame
Container.BackgroundTransparency = 1
Container.Position = UDim2.new(0, 14, 0, 126)
Container.Size = UDim2.new(1, -28, 1, -174)
Container.CanvasSize = UDim2.new(0, 0, 0, 540)
Container.ScrollBarThickness = 4
Container.ScrollBarImageColor3 = Color3.fromRGB(0, 230, 118)
Container.ScrollingDirection = Enum.ScrollingDirection.Y

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.Parent = Container
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayout.Padding = UDim.new(0, 8)

UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    Container.CanvasSize = UDim2.new(0, 0, 0, UIListLayout.AbsoluteContentSize.Y + 14)
end)

-- Footer Credits & Discord Bar (Branded)
local FooterBar = Instance.new("Frame")
FooterBar.Parent = MainFrame
FooterBar.BackgroundColor3 = Color3.fromRGB(16, 25, 18)
FooterBar.Position = UDim2.new(0, 14, 1, -42)
FooterBar.Size = UDim2.new(1, -28, 0, 32)

local FooterCorner = Instance.new("UICorner")
FooterCorner.CornerRadius = UDim.new(0, 8)
FooterCorner.Parent = FooterBar

local CreditText = Instance.new("TextLabel")
CreditText.Parent = FooterBar
CreditText.BackgroundTransparency = 1
CreditText.Position = UDim2.new(0, 10, 0, 0)
CreditText.Size = UDim2.new(1, -125, 1, 0)
CreditText.Font = Enum.Font.GothamBold
CreditText.Text = "YouTube: เรื่องโปร | Discord"
CreditText.TextColor3 = Color3.fromRGB(0, 255, 130)
CreditText.TextSize = 11
CreditText.TextXAlignment = Enum.TextXAlignment.Left

local CopyDiscordBtn = Instance.new("TextButton")
CopyDiscordBtn.Parent = FooterBar
CopyDiscordBtn.BackgroundColor3 = Color3.fromRGB(0, 210, 105)
CopyDiscordBtn.Position = UDim2.new(1, -112, 0.5, -11)
CopyDiscordBtn.Size = UDim2.new(0, 104, 0, 22)
CopyDiscordBtn.Font = Enum.Font.GothamBold
CopyDiscordBtn.Text = "คัดลอก Discord"
CopyDiscordBtn.TextColor3 = Color3.fromRGB(10, 15, 12)
CopyDiscordBtn.TextSize = 11

local CopyCorner = Instance.new("UICorner")
CopyCorner.CornerRadius = UDim.new(0, 6)
CopyCorner.Parent = CopyDiscordBtn

CopyDiscordBtn.Activated:Connect(function()
    if setclipboard then
        setclipboard("https://discord.gg/gZpkSgmR8")
        CopyDiscordBtn.Text = "คัดลอกสำเร็จ!"
        task.wait(1.5)
        CopyDiscordBtn.Text = "คัดลอก Discord"
    else
        StatusBox.Text = "Discord: https://discord.gg/gZpkSgmR8"
    end
end)

-- Mobile & PC Compatible UI Builders
local function CreateToggle(titleText, defaultState, callback)
    local ToggleFrame = Instance.new("Frame")
    ToggleFrame.Parent = Container
    ToggleFrame.BackgroundColor3 = Color3.fromRGB(18, 26, 20)
    ToggleFrame.Size = UDim2.new(1, -6, 0, 42)

    local FrameCorner = Instance.new("UICorner")
    FrameCorner.CornerRadius = UDim.new(0, 9)
    FrameCorner.Parent = ToggleFrame

    local Label = Instance.new("TextLabel")
    Label.Parent = ToggleFrame
    Label.BackgroundTransparency = 1
    Label.Position = UDim2.new(0, 14, 0, 0)
    Label.Size = UDim2.new(1, -78, 1, 0)
    Label.Font = Enum.Font.GothamSemibold
    Label.Text = titleText
    Label.TextColor3 = Color3.fromRGB(235, 250, 235)
    Label.TextSize = 12
    Label.TextXAlignment = Enum.TextXAlignment.Left

    local ToggleBtn = Instance.new("TextButton")
    ToggleBtn.Parent = ToggleFrame
    ToggleBtn.BackgroundColor3 = defaultState and Color3.fromRGB(0, 215, 105) or Color3.fromRGB(38, 50, 40)
    ToggleBtn.Position = UDim2.new(1, -60, 0.5, -11)
    ToggleBtn.Size = UDim2.new(0, 48, 0, 22)
    ToggleBtn.Text = ""

    local BtnCorner = Instance.new("UICorner")
    BtnCorner.CornerRadius = UDim.new(1, 0)
    BtnCorner.Parent = ToggleBtn

    local Indicator = Instance.new("Frame")
    Indicator.Parent = ToggleBtn
    Indicator.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Indicator.Position = defaultState and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
    Indicator.Size = UDim2.new(0, 16, 0, 16)

    local IndCorner = Instance.new("UICorner")
    IndCorner.CornerRadius = UDim.new(1, 0)
    IndCorner.Parent = Indicator

    local enabled = defaultState

    local function SetState(newState, triggerCallback)
        enabled = newState
        if enabled then
            TweenService:Create(ToggleBtn, TweenInfo.new(0.18), {BackgroundColor3 = Color3.fromRGB(0, 215, 105)}):Play()
            TweenService:Create(Indicator, TweenInfo.new(0.18), {Position = UDim2.new(1, -19, 0.5, -8)}):Play()
        else
            TweenService:Create(ToggleBtn, TweenInfo.new(0.18), {BackgroundColor3 = Color3.fromRGB(38, 50, 40)}):Play()
            TweenService:Create(Indicator, TweenInfo.new(0.18), {Position = UDim2.new(0, 3, 0.5, -8)}):Play()
        end
        if triggerCallback then
            callback(enabled)
        end
    end

    ToggleBtn.Activated:Connect(function()
        SetState(not enabled, true)
    end)

    return SetState
end

local function CreatePresetRow(headerTitle, presets, onSelect)
    local BoxFrame = Instance.new("Frame")
    BoxFrame.Parent = Container
    BoxFrame.BackgroundColor3 = Color3.fromRGB(18, 26, 20)
    BoxFrame.Size = UDim2.new(1, -6, 0, 66)

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 9)
    Corner.Parent = BoxFrame

    local Header = Instance.new("TextLabel")
    Header.Parent = BoxFrame
    Header.BackgroundTransparency = 1
    Header.Position = UDim2.new(0, 14, 0, 4)
    Header.Size = UDim2.new(1, -28, 0, 20)
    Header.Font = Enum.Font.GothamBold
    Header.Text = headerTitle
    Header.TextColor3 = Color3.fromRGB(0, 255, 140)
    Header.TextSize = 12
    Header.TextXAlignment = Enum.TextXAlignment.Left

    local count = #presets
    for i, item in ipairs(presets) do
        local btn = Instance.new("TextButton")
        btn.Parent = BoxFrame
        btn.BackgroundColor3 = Color3.fromRGB(26, 40, 30)
        btn.Size = UDim2.new((1 / count) - 0.02, 0, 0, 28)
        btn.Position = UDim2.new(((i - 1) / count) + 0.01, 0, 0, 30)
        btn.Font = Enum.Font.GothamBold
        btn.Text = item.Label
        btn.TextColor3 = Color3.fromRGB(220, 250, 230)
        btn.TextSize = 11

        local bCorner = Instance.new("UICorner")
        bCorner.CornerRadius = UDim.new(0, 6)
        bCorner.Parent = btn

        btn.Activated:Connect(function()
            onSelect(item.Value, Header)
        end)
    end
end

-- ==============================================================================
-- 3. Step-Lerp Float Collector Engine
-- ==============================================================================

local function ExtractTargetCFrame(obj)
    if not obj then return nil end
    if obj:IsA("BasePart") then
        return obj.CFrame
    elseif obj:IsA("Model") then
        return obj:GetPivot()
    elseif obj:IsA("Attachment") then
        return obj.WorldCFrame
    end
    local subPart = obj:FindFirstChildWhichIsA("BasePart", true)
    if subPart then return subPart.CFrame end
    local subAtt = obj:FindFirstChildWhichIsA("Attachment", true)
    if subAtt then return subAtt.WorldCFrame end
    return nil
end

local CurrentGlideCFrame = nil

local function SyncCarCFrameCleanly(model, rootPart, phys, stepCF)
    rootPart.AssemblyLinearVelocity = Vector3.zero
    rootPart.AssemblyAngularVelocity = Vector3.zero
    model:PivotTo(stepCF)

    if phys and phys.cf then
        pcall(function()
            phys.cf = CFrame.new(stepCF.Position / 2) * (stepCF - stepCF.Position)
            if phys.v then phys.v = Vector3.zero end
        end)
    end
end

local function DriveCarToPointSafely(targetCFrame)
    local model, rootPart = GetVehicleModelAndPart()
    if not model or not rootPart then return end

    local phys = GetCarPhysicsTable(false)
    local targetPos = targetCFrame.Position

    if FocusUp then
        pcall(function() FocusUp:FireServer(targetPos) end)
    end

    local raycastParam = RaycastParams.new()
    raycastParam.FilterType = Enum.RaycastFilterType.Exclude
    raycastParam.IgnoreWater = true
    local filterList = {model}
    if LocalPlayer.Character then table.insert(filterList, LocalPlayer.Character) end
    if Workspace:FindFirstChild("RBRCTrafficCars") then table.insert(filterList, Workspace.RBRCTrafficCars) end
    if Workspace:FindFirstChild("RaycityLuckySpots") then table.insert(filterList, Workspace.RaycityLuckySpots) end
    if Workspace:FindFirstChild("RBRCFieldMarkers") then table.insert(filterList, Workspace.RBRCFieldMarkers) end
    raycastParam.FilterDescendantsInstances = filterList

    local rayResult = Workspace:Raycast(Vector3.new(targetPos.X, targetPos.Y + 150, targetPos.Z), Vector3.new(0, -300, 0), raycastParam)
    local safeY = targetPos.Y + 3.5
    if rayResult and rayResult.Position then
        safeY = math.max(targetPos.Y + 1.5, rayResult.Position.Y + 3.5)
    end

    local safeTargetCF = CFrame.new(targetPos.X, safeY, targetPos.Z)
    local startPos = rootPart.Position
    local distance = (startPos - safeTargetCF.Position).Magnitude

    if distance > 4 then
        local steps = math.clamp(math.floor(distance / 15), 2, 35)
        for i = 1, steps do
            if not Config.AutoFarmMoney then
                CurrentGlideCFrame = nil
                return
            end

            model, rootPart = GetVehicleModelAndPart()
            if not model or not rootPart then break end
            phys = GetCarPhysicsTable(false)

            local alpha = i / steps
            local lerpPos = startPos:Lerp(safeTargetCF.Position, alpha)

            local stepRay = Workspace:Raycast(Vector3.new(lerpPos.X, lerpPos.Y + 100, lerpPos.Z), Vector3.new(0, -200, 0), raycastParam)
            local currentGroundY = stepRay and (stepRay.Position.Y + 3.5) or lerpPos.Y

            local lookDir = (safeTargetCF.Position - lerpPos)
            local flatLook = Vector3.new(lookDir.X, 0, lookDir.Z)
            local stepCF = flatLook.Magnitude > 0.1
                and CFrame.lookAt(Vector3.new(lerpPos.X, currentGroundY, lerpPos.Z), Vector3.new(lerpPos.X, currentGroundY, lerpPos.Z) + flatLook.Unit)
                or CFrame.new(lerpPos.X, currentGroundY, lerpPos.Z)

            CurrentGlideCFrame = stepCF
            SyncCarCFrameCleanly(model, rootPart, phys, stepCF)
            task.wait(0.02)
        end
    end

    if Config.AutoFarmMoney and model and rootPart then
        CurrentGlideCFrame = safeTargetCF
        SyncCarCFrameCleanly(model, rootPart, phys, safeTargetCF)
    end
end

local function TriggerPickupCollection(item)
    if not item then return end
    local _, rootPart = GetVehicleModelAndPart()

    if firetouchinterest and rootPart then
        if item:IsA("BasePart") then
            pcall(firetouchinterest, rootPart, item, 0)
            pcall(firetouchinterest, rootPart, item, 1)
        else
            for _, part in ipairs(item:GetDescendants()) do
                if part:IsA("BasePart") then
                    pcall(firetouchinterest, rootPart, part, 0)
                    pcall(firetouchinterest, rootPart, part, 1)
                end
            end
        end
    end

    if PickupEat then
        pcall(function()
            if Config.CapturedPickupArgs then
                PickupEat:FireServer(unpack(Config.CapturedPickupArgs))
            end
            PickupEat:FireServer(item.Name)
            PickupEat:FireServer(item)
            local spotId = item:GetAttribute("Id") or item:GetAttribute("SpotId") or item:GetAttribute("Index")
            if spotId then
                PickupEat:FireServer(spotId)
            end
        end)
    end
end

-- ==============================================================================
-- 4. Populate Menu Controls
-- ==============================================================================

CreateToggle("🎁 ออโต้ลอยเก็บเหรียญ/กล่องเงิน (LuckySpots - ลอยนุ่มไม่บัค)", Config.AutoFarmMoney, function(state)
    Config.AutoFarmMoney = state
    if not state then
        CurrentGlideCFrame = nil
        StatusBox.Text = "Status: หยุดระบบออโต้ลอยเก็บของแล้ว"
    else
        GetCarPhysicsTable(true)
        StatusBox.Text = "Status: กำลังลอยไปเก็บเหรียญและกล่อง LuckySpots..."
    end
end)

local SetInstantBoostToggle
local function UpdateQuickBoostVisual(state)
    if state then
        QuickBoostPill.Text = "🚀 พุ่งออโต้: ON"
        QuickBoostPill.BackgroundColor3 = Color3.fromRGB(0, 160, 80)
        QuickBoostPill.TextColor3 = Color3.fromRGB(255, 255, 255)
    else
        QuickBoostPill.Text = "🚀 พุ่งออโต้: OFF"
        QuickBoostPill.BackgroundColor3 = Color3.fromRGB(12, 28, 18)
        QuickBoostPill.TextColor3 = Color3.fromRGB(160, 245, 185)
    end
end

SetInstantBoostToggle = CreateToggle("🚀 บูสความไวเร่งทันทีออโต้ (กดปุ๊บรถพุ่งเองทันที - มือถือ/PC)", Config.InstantAutoBoost, function(state)
    Config.InstantAutoBoost = state
    UpdateQuickBoostVisual(state)
    GetCarPhysicsTable(true)
    if state then
        StatusBox.Text = string.format("Status: เปิดบูสพุ่งเร่งทันทีออโต้! (%d km/h | x%.1f)", Config.VmaxKmh, Config.AccelRate)
    else
        StatusBox.Text = "Status: ปิดบูสพุ่งเองออโต้"
    end
end)

MakeTouchDraggable(QuickBoostPill, QuickBoostPill, function()
    SetInstantBoostToggle(not Config.InstantAutoBoost, true)
end)

CreateToggle("⚡ สปีดแฮกตอนกดคันเร่ง/เดินหน้า (รองรับปุ่มคันเร่งมือถือ & W)", Config.ManualKeyBoost, function(state)
    Config.ManualKeyBoost = state
    GetCarPhysicsTable(true)
end)

CreatePresetRow(
    string.format("🏁 ความเร็วสูงสุด (VMAX): %d km/h", Config.VmaxKmh),
    {
        {Label = "450 km/h", Value = 450},
        {Label = "600 km/h", Value = 600},
        {Label = "900 km/h", Value = 900},
        {Label = "1500 km/h", Value = 1500}
    },
    function(val, headerLabel)
        Config.VmaxKmh = val
        headerLabel.Text = string.format("🏁 ความเร็วสูงสุด (VMAX): %d km/h", Config.VmaxKmh)
    end
)

CreatePresetRow(
    string.format("🔥 อัตราเร่งกระชาก (Boost Thrust): x%.1f", Config.AccelRate),
    {
        {Label = "x2.0 (นุ่ม)", Value = 2.0},
        {Label = "x5.0 (พุ่งไว)", Value = 5.0},
        {Label = "x10.0 (จรวด)", Value = 10.0},
        {Label = "x20.0 (ติดทันที)", Value = 20.0}
    },
    function(val, headerLabel)
        Config.AccelRate = val
        headerLabel.Text = string.format("🔥 อัตราเร่งกระชาก (Boost Thrust): x%.1f", Config.AccelRate)
    end
)

CreateToggle("🦘 กระโดดลอยตัวไม่จำกัด (ปุ่ม 🦘 บนจอมือถือ & Spacebar)", Config.InfiniteJump, function(state)
    Config.InfiniteJump = state
    QuickJumpPill.Visible = state
end)

CreateToggle("✨ ไนโตร SP ไม่ลด (Infinite Boost SP)", Config.InfiniteSP, function(state)
    Config.InfiniteSP = state
end)

CreateToggle("👻 ขับทะลุรถ NPC 100% (Ghost Mode Bypass)", Config.GhostMode, function(state)
    Config.GhostMode = state
    ApplyGhostMode(state)
end)

CreateToggle("🌪️ ออโต้สกิลพายุหมุนเก็บแต้ม (Auto Whirl Skill)", Config.AutoWhirlSkill, function(state)
    Config.AutoWhirlSkill = state
end)

CreateToggle("🛡️ กันหลุดออกจากเซิร์ฟ 20 นาที (Anti-AFK)", Config.AntiAFK, function(state)
    Config.AntiAFK = state
end)

-- ==============================================================================
-- 5. Runtime Execution & Event Loops
-- ==============================================================================

local function ExecuteCleanJump()
    if not Config.InfiniteJump then return end

    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum and not hum.Sit then
        hum:ChangeState(Enum.HumanoidStateType.Jumping)
    end

    local _, root = GetVehicleModelAndPart()
    local phys = GetCarPhysicsTable(false)
    if root then
        root.AssemblyLinearVelocity = Vector3.new(
            root.AssemblyLinearVelocity.X,
            Config.JumpPower,
            root.AssemblyLinearVelocity.Z
        )
        if phys then
            phys.jumpPending = false
            if phys.v then
                phys.v = Vector3.new(phys.v.X, Config.JumpPower / 2, phys.v.Z)
            end
        end
    end
end

MakeTouchDraggable(QuickJumpPill, QuickJumpPill, function()
    ExecuteCleanJump()
end)

QuickJumpPill.Activated:Connect(function()
    ExecuteCleanJump()
end)

local JumpKeyConn = UserInputService.InputBegan:Connect(function(input)
    if UserInputService:GetFocusedTextBox() then return end
    if input.KeyCode == Enum.KeyCode.Space and Config.InfiniteJump then
        ExecuteCleanJump()
    end
end)

local JumpReqConn = UserInputService.JumpRequest:Connect(function()
    if Config.InfiniteJump then
        ExecuteCleanJump()
    end
end)

local AfkConn = LocalPlayer.Idled:Connect(function()
    if Config.AntiAFK then
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new(100, 100))
    end
end)

local LoopsRunning = true

task.spawn(function()
    while LoopsRunning do
        task.wait(60)
        if Config.AntiAFK then
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new(50, 50))
            end)
        end
    end
end)

task.spawn(function()
    while LoopsRunning do
        task.wait(0.35)
        if Config.AutoFarmMoney then
            pcall(function()
                local luckyFolder = Workspace:FindFirstChild("RaycityLuckySpots")
                local fieldFolder = Workspace:FindFirstChild("RBRCFieldMarkers")

                local targetList = {}
                if luckyFolder then
                    for _, item in ipairs(luckyFolder:GetChildren()) do
                        local cf = ExtractTargetCFrame(item)
                        if cf and cf.Position.Magnitude > 1 then
                            table.insert(targetList, {Instance = item, CFrame = cf})
                        end
                    end
                end

                if #targetList == 0 and fieldFolder then
                    for _, item in ipairs(fieldFolder:GetChildren()) do
                        local lower = string.lower(item.Name)
                        if not lower:find("arrow") and not lower:find("portal") then
                            local cf = ExtractTargetCFrame(item)
                            if cf and cf.Position.Magnitude > 1 then
                                table.insert(targetList, {Instance = item, CFrame = cf})
                            end
                        end
                    end
                end

                if #targetList > 0 then
                    local _, rootPart = GetVehicleModelAndPart()
                    local startPos = rootPart and rootPart.Position or Vector3.zero
                    table.sort(targetList, function(a, b)
                        return (a.CFrame.Position - startPos).Magnitude < (b.CFrame.Position - startPos).Magnitude
                    end)

                    for _, spot in ipairs(targetList) do
                        if not Config.AutoFarmMoney then break end
                        if spot.Instance and spot.Instance.Parent then
                            local freshCF = ExtractTargetCFrame(spot.Instance) or spot.CFrame
                            StatusBox.Text = "Status: กำลังลอยไปเก็บ -> " .. spot.Instance.Name
                            DriveCarToPointSafely(freshCF)
                            TriggerPickupCollection(spot.Instance)
                            task.wait(0.22)
                        end
                    end
                    CurrentGlideCFrame = nil
                else
                    CurrentGlideCFrame = nil
                    StatusBox.Text = "Status: กำลังรอเหรียญ/กล่อง LuckySpots เกิดใหม่..."
                end
            end)
        else
            CurrentGlideCFrame = nil
        end
    end
end)

task.spawn(function()
    while LoopsRunning do
        task.wait(1.2)
        if Config.AutoWhirlSkill then
            pcall(function()
                if WhirlCast then WhirlCast:FireServer() end
                if WhirlHit then WhirlHit:FireServer() end
                if WhirlClaim then WhirlClaim:FireServer() end
            end)
        end
    end
end)

local HeartbeatConn = RunService.Heartbeat:Connect(function(dt)
    if Config.GhostMode then
        ApplyGhostMode(true)
    end

    local model, root = GetVehicleModelAndPart()
    local phys = GetCarPhysicsTable(false)

    if not model or not root then
        TelemetryLabel.Text = "สถานะ: กรุณาขึ้นขับรถ"
        return
    end

    if Config.AutoFarmMoney and CurrentGlideCFrame then
        SyncCarCFrameCleanly(model, root, phys, CurrentGlideCFrame)
        TelemetryLabel.Text = "สถานะ: กำลังลอยเก็บเหรียญ/กล่องอัตโนมัติ (เสถียร 100%)"
        return
    end

    local currentKmh = 0
    if phys and phys.v then
        currentKmh = phys.v.Magnitude * 3.6
    else
        currentKmh = (root.AssemblyLinearVelocity.Magnitude / 2) * 3.6
    end

    local boostActive = Config.InstantAutoBoost or Config.ManualKeyBoost
    if boostActive then
        if phys and type(phys.p) == "table" then
            phys.p.vmax = Config.VmaxKmh / 3.6
            phys.torqueBonus = 1200
            phys.p.btPower = 10.0

            if Config.InfiniteSP then
                phys.p.btNeedSP = 1
                phys.p.btDuration = 25
            end
        end

        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local mobileMoveForward = hum and hum.MoveDirection.Magnitude > 0.1 and hum.MoveDirection:Dot(root.CFrame.LookVector) > 0.1

        local isPressingForward = (phys and phys.throttle and phys.throttle > 0.05)
            or mobileMoveForward
            or UserInputService:IsKeyDown(Enum.KeyCode.W)
            or UserInputService:IsKeyDown(Enum.KeyCode.Up)

        local isBraking = (phys and phys.brake and phys.brake > 0.05)
            or UserInputService:IsKeyDown(Enum.KeyCode.S)
            or UserInputService:IsKeyDown(Enum.KeyCode.Down)

        local shouldThrust = (Config.InstantAutoBoost or (Config.ManualKeyBoost and isPressingForward))
            and not isBraking
            and not Config.AutoFarmMoney

        if shouldThrust then
            local forward = root.CFrame.LookVector
            local flatForward = Vector3.new(forward.X, 0, forward.Z)
            flatForward = flatForward.Magnitude > 0.01 and flatForward.Unit or forward

            local maxInternalSpeed = Config.VmaxKmh / 3.6
            if phys and phys.v then
                if phys.throttle then phys.throttle = 1 end
                local curForward = phys.v:Dot(flatForward)
                local kickStart = math.min(maxInternalSpeed, 25 + (Config.AccelRate * 8))
                local nextSpeed = math.min(maxInternalSpeed, math.max(curForward, kickStart) + (Config.AccelRate * 45 * dt))

                phys.v = Vector3.new(flatForward.X * nextSpeed, phys.v.Y, flatForward.Z * nextSpeed)
                root.AssemblyLinearVelocity = Vector3.new(
                    phys.v.X * 2,
                    root.AssemblyLinearVelocity.Y,
                    phys.v.Z * 2
                )
            else
                local targetStudSpeed = math.min((Config.VmaxKmh / 3.6) * 2, root.AssemblyLinearVelocity.Magnitude + (Config.AccelRate * 90 * dt))
                root.AssemblyLinearVelocity = Vector3.new(
                    flatForward.X * targetStudSpeed,
                    root.AssemblyLinearVelocity.Y,
                    flatForward.Z * targetStudSpeed
                )
            end
        end
    elseif phys and type(phys.p) == "table" then
        if phys.p.vmax ~= StockPhysics.vmax then
            phys.p.vmax = StockPhysics.vmax
            phys.torqueBonus = 0
            phys.p.btPower = StockPhysics.btPower
            phys.p.btDuration = StockPhysics.btDuration
            phys.p.btNeedSP = StockPhysics.btNeedSP
        end
    end

    TelemetryLabel.Text = string.format(
        "ความเร็ว: %d km/h (VMAX %d) | บูส: x%.1f | มือถือ & PC พร้อมใช้งาน",
        math.floor(currentKmh),
        Config.VmaxKmh,
        Config.AccelRate
    )
end)

-- Cleanup routine
_G.RuengProDisconnect = function()
    LoopsRunning = false
    CurrentGlideCFrame = nil
    if HeartbeatConn then HeartbeatConn:Disconnect() end
    if JumpReqConn then JumpReqConn:Disconnect() end
    if JumpKeyConn then JumpKeyConn:Disconnect() end
    if AfkConn then AfkConn:Disconnect() end
    ApplyGhostMode(false)
end

print("[เรื่องโปร Hub] Loaded Successfully! Creator: เรื่องโปร | Discord: https://discord.gg/gZpkSgmR8")
return true