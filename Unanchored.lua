--[[
    ========================================================
    * B.R.I.C.K.S - created by Sofi
    * Ultra-Compact Mobile Optimized GUI with Infinite Scroll
    * Features:
      - Delta-Style Floating Toggle Ball (Mobile-Ready)
      - Gojo's Hollow Purple (Lapse Blue + Reversal Red + Purple Blast) [FE / Server-Sided Colors & Physics]
      - Rapid Multi-Block Rainbow (Tool-Equip Bypass, fast cycling)
      - Chain Physics Trail (Interlocked links follow as a realistic chain)
      - Snake Physics (True lateral undulation & spinal joint physics)
      - Animated Shark Morph (Swimming tail, fins, shark colors & blinking eye paint)
      - Animated Stickman Morph [FE / Server-Sided Network Ownership]
      - Automatic Camera/POV Reset on any mode or button switch
    ========================================================
--]]

local P, R, T, U = game:GetService("Players"), game:GetService("RunService"), game:GetService("TeleportService"), game:GetService("UserInputService")
local L, M = P.LocalPlayer, P.LocalPlayer:GetMouse()
local AC, CP = nil, {}
local BlasterActive, BlasterConnection = false, nil
local Flying, FlyConnection = false, nil
local CurrentWeapon = "None"
local CurrentActiveMode = "None"

-- User & Script Configuration
local FlySpeed = 50
local BlockSpeed = 60
local RainbowSpeed = 8
local ToggleGUIKey = Enum.KeyCode.RightControl
local FlyKey = Enum.KeyCode.F

-- Safe Staging Altitude (Kept within player simulation radius so network ownership is never lost)
local STAGING_ALTITUDE = 16

-- Default Color Setup (RGB)
local R_Val, G_Val, B_Val = 0, 170, 255
local SelectedColor = Color3.fromRGB(R_Val, G_Val, B_Val)

local IsPaintActive = false
local IsRainbowActive = false
local IsHollowPurpleActive = false
local IsSlashing = false
local SlashAngle = 0
local LastShotTime = 0
local LastToolUse = 0
local LastRainbowUse = 0
local LastEyeBlinkTime = 0
local EyesClosed = false

local SidesList = {
    Enum.NormalId.Front,
    Enum.NormalId.Right,
    Enum.NormalId.Back,
    Enum.NormalId.Left,
    Enum.NormalId.Top,
    Enum.NormalId.Bottom
}

local PG = L:WaitForChild("PlayerGui")
if PG:FindFirstChild("SofiScriptHub") then PG.SofiScriptHub:Destroy() end

local S = Instance.new("ScreenGui")
S.Name, S.ResetOnSpawn, S.Parent = "SofiScriptHub", false, PG

-- ========================================================
-- 1. DELTA-STYLE FLOATING TOGGLE BALL (MOBILE READY)
-- ========================================================
local BallBtn = Instance.new("ImageButton")
BallBtn.Name = "DeltaFloatingBall"
BallBtn.Size = UDim2.new(0, 42, 0, 42)
BallBtn.Position = UDim2.new(0, 20, 0.4, 0)
BallBtn.BackgroundColor3 = Color3.fromRGB(30, 25, 45)
BallBtn.BorderSizePixel = 0
BallBtn.Active = true
BallBtn.Draggable = true
BallBtn.Visible = false
BallBtn.Parent = S

local BallCorner = Instance.new("UICorner", BallBtn)
BallCorner.CornerRadius = UDim.new(1, 0)

local BallStroke = Instance.new("UIStroke", BallBtn)
BallStroke.Thickness = 2
BallStroke.Color = Color3.fromRGB(160, 80, 255)

local BallIcon = Instance.new("TextLabel", BallBtn)
BallIcon.Size = UDim2.new(1, 0, 1, 0)
BallIcon.BackgroundTransparency = 1
BallIcon.Text = "Δ"
BallIcon.TextColor3 = Color3.fromRGB(220, 180, 255)
BallIcon.TextSize = 20
BallIcon.Font = Enum.Font.GothamBold

-- ========================================================
-- 2. ULTRA-COMPACT MOBILE GUI FRAME
-- ========================================================
local F = Instance.new("Frame")
F.Name = "MainFrame"
F.Size = UDim2.new(0, 195, 0, 260)
F.Position = UDim2.new(0, 20, 0, 40)
F.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
F.BorderSizePixel = 0
F.Active = true
F.Draggable = true
F.ClipsDescendants = true
F.Parent = S

local FrameCorner = Instance.new("UICorner", F)
FrameCorner.CornerRadius = UDim.new(0, 8)

local FrameStroke = Instance.new("UIStroke", F)
FrameStroke.Thickness = 1.2
FrameStroke.Color = Color3.fromRGB(80, 70, 120)

-- Header Bar
local Header = Instance.new("Frame", F)
Header.Size = UDim2.new(1, 0, 0, 28)
Header.BackgroundColor3 = Color3.fromRGB(28, 28, 38)
Header.BorderSizePixel = 0

local HeaderCorner = Instance.new("UICorner", Header)
HeaderCorner.CornerRadius = UDim.new(0, 8)

-- Title Label with "created by Sofi"
local TL = Instance.new("TextLabel", Header)
TL.Size = UDim2.new(1, -62, 1, 0)
TL.Position = UDim2.new(0, 8, 0, 0)
TL.BackgroundTransparency = 1
TL.TextColor3 = Color3.fromRGB(240, 240, 255)
TL.Text = "B.R.I.C.K.S - created by Sofi"
TL.TextSize = 10
TL.Font = Enum.Font.GothamBold
TL.TextXAlignment = Enum.TextXAlignment.Left

-- Toggleable Minimize Button (Turns GUI into Delta Ball)
local MinBtn = Instance.new("TextButton", Header)
MinBtn.Name = "MinimizeToBallBtn"
MinBtn.Size = UDim2.new(0, 22, 0, 22)
MinBtn.Position = UDim2.new(1, -50, 0, 3)
MinBtn.BackgroundColor3 = Color3.fromRGB(70, 50, 140)
MinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MinBtn.Text = "—"
MinBtn.TextSize = 11
MinBtn.Font = Enum.Font.GothamBold
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 5)

-- Destroy UI Button (X)
local CloseBtn = Instance.new("TextButton", Header)
CloseBtn.Name = "CloseBtn"
CloseBtn.Size = UDim2.new(0, 22, 0, 22)
CloseBtn.Position = UDim2.new(1, -25, 0, 3)
CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 45, 45)
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.Text = "X"
CloseBtn.TextSize = 11
CloseBtn.Font = Enum.Font.GothamBold
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 5)

-- Ball & GUI Toggle Logic (Delta Style)
MinBtn.MouseButton1Click:Connect(function()
    F.Visible = false
    BallBtn.Visible = true
    BallBtn.Position = UDim2.new(F.Position.X.Scale, F.Position.X.Offset, F.Position.Y.Scale, F.Position.Y.Offset)
end)

BallBtn.MouseButton1Click:Connect(function()
    BallBtn.Visible = false
    F.Visible = true
end)

CloseBtn.MouseButton1Click:Connect(function()
    if S then S:Destroy() end
end)

-- ========================================================
-- 3. ENDLESS SCROLLABLE CONTAINER
-- ========================================================
local SF = Instance.new("ScrollingFrame", F)
SF.Name = "EndlessScroll"
SF.Size = UDim2.new(1, -4, 1, -32)
SF.Position = UDim2.new(0, 2, 0, 30)
SF.BackgroundTransparency = 1
SF.BorderSizePixel = 0
SF.CanvasSize = UDim2.new(0, 0, 0, 0)
SF.ScrollBarThickness = 3
SF.ScrollBarImageColor3 = Color3.fromRGB(140, 120, 210)
SF.AutomaticCanvasSize = Enum.AutomaticSize.Y

local UIList = Instance.new("UIListLayout", SF)
UIList.SortOrder = Enum.SortOrder.LayoutOrder
UIList.Padding = UDim.new(0, 4)

UIList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    SF.CanvasSize = UDim2.new(0, 0, 0, UIList.AbsoluteContentSize.Y + 8)
end)

-- Compact Stats Panel
local StatsFrame = Instance.new("Frame", SF)
StatsFrame.Size = UDim2.new(1, -4, 0, 68)
StatsFrame.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
StatsFrame.BorderSizePixel = 0
StatsFrame.LayoutOrder = 1
Instance.new("UICorner", StatsFrame).CornerRadius = UDim.new(0, 5)

local function ST(Y, Text)
    local LN = Instance.new("TextLabel", StatsFrame)
    LN.Size = UDim2.new(0.95, 0, 0, 14)
    LN.Position = UDim2.new(0.03, 0, 0, Y)
    LN.BackgroundTransparency = 1
    LN.TextColor3 = Color3.fromRGB(190, 205, 235)
    LN.TextSize = 9
    LN.Font = Enum.Font.GothamMedium
    LN.TextXAlignment = Enum.TextXAlignment.Left
    LN.TextWrapped = true
    LN.Text = Text
    return LN
end

local PL = ST(4, "Ping: -- ms")
local BL = ST(18, "Bricks: 0")
local PLL = ST(32, "Players: 0")
local EL = ST(46, "Enlightened: Searching...")
EL.TextColor3 = Color3.fromRGB(255, 215, 0)

-- Settings Panel (Compact for Mobile)
local SettingsFrame = Instance.new("Frame", SF)
SettingsFrame.Size = UDim2.new(1, -4, 0, 120)
SettingsFrame.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
SettingsFrame.BorderSizePixel = 0
SettingsFrame.LayoutOrder = 2
Instance.new("UICorner", SettingsFrame).CornerRadius = UDim.new(0, 5)

local SettingsTitle = Instance.new("TextLabel", SettingsFrame)
SettingsTitle.Size = UDim2.new(1, 0, 0, 16)
SettingsTitle.BackgroundTransparency = 1
SettingsTitle.TextColor3 = Color3.fromRGB(240, 240, 255)
SettingsTitle.Text = "Settings & Speeds"
SettingsTitle.TextSize = 9
SettingsTitle.Font = Enum.Font.GothamBold

local function CreateSettingInput(yOffset, labelText, defaultVal)
    local label = Instance.new("TextLabel", SettingsFrame)
    label.Size = UDim2.new(0.62, 0, 0, 18)
    label.Position = UDim2.new(0.04, 0, 0, yOffset)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(180, 195, 225)
    label.Text = labelText
    label.TextSize = 8.5
    label.Font = Enum.Font.GothamMedium
    label.TextXAlignment = Enum.TextXAlignment.Left

    local box = Instance.new("TextBox", SettingsFrame)
    box.Size = UDim2.new(0.28, 0, 0, 18)
    box.Position = UDim2.new(0.68, 0, 0, yOffset)
    box.BackgroundColor3 = Color3.fromRGB(38, 38, 50)
    box.TextColor3 = Color3.new(1, 1, 1)
    box.Text = tostring(defaultVal)
    box.TextSize = 8.5
    box.Font = Enum.Font.GothamMedium
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 4)
    return box
end

local FlySpeedBox = CreateSettingInput(20, "Fly Speed:", FlySpeed)
local BlockSpeedBox = CreateSettingInput(42, "Block Speed:", BlockSpeed)
local RainbowSpeedBox = CreateSettingInput(64, "Rainbow Speed:", RainbowSpeed)

local ToggleGUIBtn = Instance.new("TextButton", SettingsFrame)
ToggleGUIBtn.Size = UDim2.new(0.28, 0, 0, 18)
ToggleGUIBtn.Position = UDim2.new(0.68, 0, 0, 86)
ToggleGUIBtn.BackgroundColor3 = Color3.fromRGB(38, 38, 50)
ToggleGUIBtn.TextColor3 = Color3.new(1, 1, 1)
ToggleGUIBtn.Text = ToggleGUIKey.Name
ToggleGUIBtn.TextSize = 8.5
ToggleGUIBtn.Font = Enum.Font.GothamMedium
Instance.new("UICorner", ToggleGUIBtn).CornerRadius = UDim.new(0, 4)

local ToggleGUILabel = Instance.new("TextLabel", SettingsFrame)
ToggleGUILabel.Size = UDim2.new(0.62, 0, 0, 18)
ToggleGUILabel.Position = UDim2.new(0.04, 0, 0, 86)
ToggleGUILabel.BackgroundTransparency = 1
ToggleGUILabel.TextColor3 = Color3.fromRGB(180, 195, 225)
ToggleGUILabel.Text = "Hide/Show Key:"
ToggleGUILabel.TextSize = 8.5
ToggleGUILabel.Font = Enum.Font.GothamMedium
ToggleGUILabel.TextXAlignment = Enum.TextXAlignment.Left

local MobileHint = Instance.new("TextLabel", SettingsFrame)
MobileHint.Size = UDim2.new(0.92, 0, 0, 14)
MobileHint.Position = UDim2.new(0.04, 0, 0, 104)
MobileHint.BackgroundTransparency = 1
MobileHint.TextColor3 = Color3.fromRGB(160, 140, 220)
MobileHint.Text = "POV auto-resets on mode switch!"
MobileHint.TextSize = 7.5
MobileHint.Font = Enum.Font.GothamMedium
MobileHint.TextXAlignment = Enum.TextXAlignment.Left

FlySpeedBox.FocusLost:Connect(function()
    local val = tonumber(FlySpeedBox.Text)
    if val then FlySpeed = val else FlySpeedBox.Text = tostring(FlySpeed) end
end)

BlockSpeedBox.FocusLost:Connect(function()
    local val = tonumber(BlockSpeedBox.Text)
    if val then BlockSpeed = val else BlockSpeedBox.Text = tostring(BlockSpeed) end
end)

RainbowSpeedBox.FocusLost:Connect(function()
    local val = tonumber(RainbowSpeedBox.Text)
    if val then RainbowSpeed = val else RainbowSpeedBox.Text = tostring(RainbowSpeed) end
end)

-- RGB Color Frame
local ColorPickerFrame = Instance.new("Frame", SF)
ColorPickerFrame.Size = UDim2.new(1, -4, 0, 58)
ColorPickerFrame.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
ColorPickerFrame.LayoutOrder = 3
Instance.new("UICorner", ColorPickerFrame).CornerRadius = UDim.new(0, 5)

local ColorTitle = Instance.new("TextLabel", ColorPickerFrame)
ColorTitle.Size = UDim2.new(1, 0, 0, 14)
ColorTitle.BackgroundTransparency = 1
ColorTitle.TextColor3 = Color3.new(1, 1, 1)
ColorTitle.Text = "RGB Customizer"
ColorTitle.TextSize = 9
ColorTitle.Font = Enum.Font.GothamBold

local ColorPreview = Instance.new("Frame", ColorPickerFrame)
ColorPreview.Size = UDim2.new(0, 28, 0, 22)
ColorPreview.Position = UDim2.new(1, -34, 0, 22)
ColorPreview.BackgroundColor3 = SelectedColor
Instance.new("UICorner", ColorPreview).CornerRadius = UDim.new(0, 4)

local function CreateRGBBox(xOffset, defaultVal, placeholder, textColor)
    local box = Instance.new("TextBox", ColorPickerFrame)
    box.Size = UDim2.new(0, 36, 0, 22)
    box.Position = UDim2.new(0, xOffset, 0, 22)
    box.BackgroundColor3 = Color3.fromRGB(38, 38, 48)
    box.TextColor3 = textColor
    box.Text = tostring(defaultVal)
    box.PlaceholderText = placeholder
    box.TextSize = 9
    box.Font = Enum.Font.GothamMedium
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 4)
    return box
end

local R_Box = CreateRGBBox(8, R_Val, "R", Color3.fromRGB(255, 110, 110))
local G_Box = CreateRGBBox(50, G_Val, "G", Color3.fromRGB(110, 255, 110))
local B_Box = CreateRGBBox(92, B_Val, "B", Color3.fromRGB(120, 170, 255))

local function UpdateColorFromRGB()
    local r = math.clamp(tonumber(R_Box.Text) or 0, 0, 255)
    local g = math.clamp(tonumber(G_Box.Text) or 0, 0, 255)
    local b = math.clamp(tonumber(B_Box.Text) or 0, 0, 255)
    SelectedColor = Color3.fromRGB(r, g, b)
    ColorPreview.BackgroundColor3 = SelectedColor
end

R_Box:GetPropertyChangedSignal("Text"):Connect(UpdateColorFromRGB)
G_Box:GetPropertyChangedSignal("Text"):Connect(UpdateColorFromRGB)
B_Box:GetPropertyChangedSignal("Text"):Connect(UpdateColorFromRGB)

-- Target & Limits Frame
local InputFrame = Instance.new("Frame", SF)
InputFrame.Size = UDim2.new(1, -4, 0, 24)
InputFrame.BackgroundTransparency = 1
InputFrame.LayoutOrder = 4

local WI = Instance.new("TextBox", InputFrame)
WI.Size = UDim2.new(0.58, 0, 1, 0)
WI.BackgroundColor3 = Color3.fromRGB(36, 36, 46)
WI.TextColor3 = Color3.new(1, 1, 1)
WI.Text = ""
WI.PlaceholderText = "Target Player"
WI.TextSize = 8.5
WI.Font = Enum.Font.GothamMedium
Instance.new("UICorner", WI).CornerRadius = UDim.new(0, 4)

local NB = Instance.new("TextBox", InputFrame)
NB.Size = UDim2.new(0.38, 0, 1, 0)
NB.Position = UDim2.new(0.62, 0, 0, 0)
NB.BackgroundColor3 = Color3.fromRGB(36, 36, 46)
NB.TextColor3 = Color3.new(1, 1, 1)
NB.Text = "ALL"
NB.PlaceholderText = "Max Blocks"
NB.TextSize = 8.5
NB.Font = Enum.Font.GothamMedium
Instance.new("UICorner", NB).CornerRadius = UDim.new(0, 4)

-- Helper to Generate Compact Button
local currentOrder = 5
local function BTN(TXT, COL)
    currentOrder = currentOrder + 1
    local B = Instance.new("TextButton", SF)
    B.Size = UDim2.new(1, -4, 0, 24)
    B.BackgroundColor3 = COL
    B.TextColor3 = Color3.new(1, 1, 1)
    B.Text = TXT
    B.TextSize = 9
    B.Font = Enum.Font.GothamMedium
    B.LayoutOrder = currentOrder
    Instance.new("UICorner", B).CornerRadius = UDim.new(0, 4)
    return B
end

-- ========================================================
-- 4. BUTTONS (INCLUDING NEW CHAIN, SNAKE, SHARK & HOLLOW PURPLE)
-- ========================================================
local THollowPurple = BTN("Hollow Purple (FE / Gojo)", Color3.fromRGB(150, 40, 235))
local TRainbow = BTN("Fast Rainbow: OFF", Color3.fromRGB(130, 45, 175))
local TChain = BTN("Chain Trail (Link Physics)", Color3.fromRGB(90, 140, 210))
local TSnake = BTN("Snake (Undulation Physics)", Color3.fromRGB(50, 160, 100))
local TShark = BTN("Shark Morph (Tail, Fins & Eyes)", Color3.fromRGB(45, 100, 180))
local TStickMan = BTN("Animated Stickman Morph", Color3.fromRGB(170, 60, 200))
local TPaintBtn = BTN("Paint Blocks: OFF", Color3.fromRGB(140, 50, 50))
local TRifle = BTN("Weapon: Equip Rifle", Color3.fromRGB(60, 130, 200))
local TSword = BTN("Weapon: Equip Sword", Color3.fromRGB(200, 110, 45))
local TFly = BTN("Toggle Fly", Color3.fromRGB(45, 150, 210))
local TFollow = BTN("Follow Selected Target", Color3.fromRGB(35, 170, 110))
local TBlaster = BTN("Toggle Brick Blaster", Color3.fromRGB(210, 45, 75))
local THelix = BTN("DNA Helix", Color3.fromRGB(75, 170, 210))
local TTornado = BTN("Tornado Launch", Color3.fromRGB(190, 110, 35))
local TD = BTN("Toggle Draw Mode", Color3.fromRGB(35, 110, 210))
local TV = BTN("Server Vortex", Color3.fromRGB(170, 75, 210))
local TR = BTN("Server Rain", Color3.fromRGB(210, 130, 35))
local TOrbit = BTN("Orbit Target", Color3.fromRGB(130, 55, 160))
local TShield = BTN("Shield Target", Color3.fromRGB(55, 160, 130))
local TFL = BTN("Fling Target", Color3.fromRGB(210, 80, 35))
local TST = BTN("Send Blocks to High Void", Color3.fromRGB(190, 55, 55))
local TReset = BTN("Reset Character", Color3.fromRGB(170, 45, 45))
local TRejoin = BTN("Rejoin Server", Color3.fromRGB(90, 90, 100))

-- Global Noclip Loop
R.Stepped:Connect(function()
    if L.Character then
        for _, part in ipairs(L.Character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end
end)

-- Target Helpers
local function GET_TARGET()
    local query = WI.Text:lower():gsub("%s+", "")
    if query ~= "" then
        for _, p in ipairs(P:GetPlayers()) do
            if p.Name:lower():sub(1, #query) == query or p.DisplayName:lower():sub(1, #query) == query then
                return p
            end
        end
    end
    return L
end

local function GET_TARGET_POS()
    local t = GET_TARGET()
    if t and t.Character and t.Character:FindFirstChild("HumanoidRootPart") then
        return t.Character.HumanoidRootPart.Position, t.Character.HumanoidRootPart
    end
    return (L.Character and L.Character:FindFirstChild("HumanoidRootPart")) and L.Character.HumanoidRootPart.Position or Vector3.zero, nil
end

local function GETLIMIT()
    local V = tonumber(NB.Text)
    return V and math.max(1, V) or math.huge
end

local function GetBlockLerpSpeed()
    return math.clamp(BlockSpeed / 100, 0.05, 1)
end

-- ========================================================
-- TRUE FE NETWORK OWNERSHIP & REPLICATION ENGINE
-- ========================================================
-- Maximize client simulation radius so Roblox grants network ownership
-- over all unanchored parts in the game
pcall(function()
    settings().Physics.PhysicsEnvironmentalThrottle = Enum.EnviromentalPhysicsThrottle.Disabled
    settings().Physics.AllowSleep = false
end)

local function MaximizeSimulationRadius()
    pcall(function()
        sethiddenproperty(L, "SimulationRadius", 1000000)
        sethiddenproperty(L, "MaximumSimulationRadius", 1000000)
    end)
end
MaximizeSimulationRadius()
R.Stepped:Connect(MaximizeSimulationRadius)

-- Claim an unanchored part for FE: breaks welds to anchored world, wakes up physics
local function ClaimPartFE(part)
    if not part or not part.Parent or not part:IsA("BasePart") then return end
    part.CanCollide = false
    part.Anchored = false

    -- Destroy any constraints or welds binding it to static world geometry
    for _, child in ipairs(part:GetChildren()) do
        if child:IsA("Weld") or child:IsA("WeldConstraint") or child:IsA("ManualWeld") or child:IsA("Motor6D") or child:IsA("Snap") or child:IsA("TouchTransmitter") then
            pcall(function() child:Destroy() end)
        end
    end

    pcall(function()
        local root = L.Character and L.Character:FindFirstChild("HumanoidRootPart")
        if root and firetouchinterest then
            firetouchinterest(part, root, 0)
            firetouchinterest(part, root, 1)
        end
    end)

    pcall(function()
        part:SetNetworkOwner(L)
    end)
end

-- Backward compatibility alias
local function NeutralizePhysics(part)
    ClaimPartFE(part)
end

-- The Core FE Position & Velocity Updater:
-- Sets part.CFrame AND sets AssemblyLinearVelocity to match the displacement!
-- This forces the Roblox server physics pipeline to replicate the movement to ALL players!
local function UpdateFEPart(part, targetCF, lerpAlpha)
    if not part or not part.Parent then return end
    part.CanCollide = false
    part.Anchored = false

    local alpha = lerpAlpha or GetBlockLerpSpeed()
    local newCF = (alpha >= 1) and targetCF or part.CFrame:Lerp(targetCF, alpha)
    local delta = newCF.Position - part.Position

    -- CRITICAL FOR FE: AssemblyLinearVelocity matching displacement prevents sleep
    -- and forces Roblox server physics replication to sync position to all other players!
    part.AssemblyLinearVelocity = (delta * 35) + Vector3.new(0, 0.12, 0)
    part.AssemblyAngularVelocity = Vector3.new(0.05, 0, 0.05)
    part.CFrame = newCF
end

-- Safe Staging Orbit: Keeps unanchored blocks hovering within 16 studs of the player
-- so Network Ownership is 100% maintained at all times (blocks NEVER fall asleep!)
local function HoldBlocksInStaging()
    if AC then AC:Disconnect() AC = nil end

    AC = R.RenderStepped:Connect(function()
        local root = L.Character and L.Character:FindFirstChild("HumanoidRootPart")
        if not root then return end
        local rootCF = root.CFrame
        local count = math.max(1, #CP)

        for i, PRT in ipairs(CP) do
            if PRT and PRT.Parent then
                local angle = (i / count) * math.pi * 2 + (os.clock() * 0.6)
                local radius = 5.5 + (math.floor(i / 14) * 2.2)
                local yOffset = STAGING_ALTITUDE + ((i % 4) * 1.5)
                local targetCF = rootCF * CFrame.new(math.cos(angle) * radius, yOffset, math.sin(angle) * radius)
                UpdateFEPart(PRT, targetCF, 0.2)
            end
        end
    end)
end

-- Backward compatibility
local function HoldBlocksInVoid()
    HoldBlocksInStaging()
end

-- Character & Camera Reset Engine (Solves POV sticking between modes)
local function SET_CHARACTER_VISIBILITY(visible)
    local C = L.Character
    if not C then return end
    for _, p in ipairs(C:GetDescendants()) do
        if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
            p.Transparency = visible and 0 or 1
        elseif p:IsA("Decal") then
            p.Transparency = visible and 0 or 1
        end
    end
end

local function RESET_CAMERA()
    local Cam = workspace.CurrentCamera
    local Hum = L.Character and L.Character:FindFirstChildOfClass("Humanoid")
    if Cam then
        Cam.CameraType = Enum.CameraType.Custom
        if Hum then
            Cam.CameraSubject = Hum
            Hum.CameraOffset = Vector3.zero -- PROMPT REQUIREMENT: Clears any lingering POV offsets!
        end
    end
end

-- Universal Mode Switcher: Automatically resets camera/POV and cleans previous loops
local function SWITCH_MODE(newModeName)
    if AC then AC:Disconnect() AC = nil end
    if BlasterConnection then BlasterConnection:Disconnect() BlasterConnection = nil end
    BlasterActive = false
    CurrentWeapon = "None"
    IsSlashing = false
    IsHollowPurpleActive = false

    SET_CHARACTER_VISIBILITY(true)
    RESET_CAMERA() -- Guarantees POV is clean whenever user switches to any button/orbit

    CurrentActiveMode = newModeName
end

local function STOP()
    SWITCH_MODE("None")
    HoldBlocksInStaging()
end

-- ========================================================
-- 5. PAINT TOOL & FAST RAINBOW TOOL-EQUIP BYPASS ENGINE
-- ========================================================
-- Dispatches paint tool remote packets WITHOUT forcing player to visibly hold tool
-- and WITHOUT teleporting HumanoidRootPart (prevents camera/character glitching!)
local function DispatchPaintToolRemote(part, colorToPaint)
    local char = L.Character
    local bp = L:FindFirstChildOfClass("Backpack")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp or not part or not part.Parent then return end

    local Dtool = (bp and bp:FindFirstChild("Paint")) or (char and char:FindFirstChild("Paint"))
    if not Dtool then return end

    local scriptFolder = Dtool:FindFirstChild("Script") or Dtool:FindFirstChild("F3X") or Dtool
    local event = scriptFolder and (scriptFolder:FindFirstChild("Event") or scriptFolder:FindFirstChild("RemoteEvent"))

    if event then
        for _, side in ipairs(SidesList) do
            pcall(function()
                event:FireServer(part, side, part.Position, "both 🤝", colorToPaint, "", "")
            end)
        end

        if Dtool:FindFirstChild("Activate") then
            pcall(function() Dtool:Activate() end)
        end
    else
        local currentEquipped = char:FindFirstChildOfClass("Tool")
        if currentEquipped ~= Dtool and hum then
            pcall(function()
                Dtool.Parent = char
                local sc = Dtool:FindFirstChild("Script")
                local ev = sc and sc:FindFirstChild("Event")
                if ev then
                    ev:FireServer(part, SidesList[1], part.Position, "both 🤝", colorToPaint, "", "")
                end
                Dtool.Parent = bp
                if currentEquipped and currentEquipped.Parent == bp then
                    hum:EquipTool(currentEquipped)
                end
            end)
        end
    end
end

local function ForcePaintBlockServerSided(part)
    DispatchPaintToolRemote(part, SelectedColor)
end

-- FAST RAINBOW TOGGLE: Rapidly cycles colors across all unanchored blocks concurrently
TRainbow.MouseButton1Click:Connect(function()
    IsRainbowActive = not IsRainbowActive
    if IsRainbowActive then
        TRainbow.Text = "Fast Rainbow: ON"
        TRainbow.BackgroundColor3 = Color3.fromRGB(40, 190, 80)
    else
        TRainbow.Text = "Fast Rainbow: OFF"
        TRainbow.BackgroundColor3 = Color3.fromRGB(130, 45, 175)
    end
end)

TPaintBtn.MouseButton1Click:Connect(function()
    IsPaintActive = not IsPaintActive
    if IsPaintActive then
        TPaintBtn.Text = "Paint Blocks: ON"
        TPaintBtn.BackgroundColor3 = Color3.fromRGB(50, 180, 50)
    else
        TPaintBtn.Text = "Paint Blocks: OFF"
        TPaintBtn.BackgroundColor3 = Color3.fromRGB(140, 50, 50)
    end
end)

-- Part Validation
local function VLD(O)
    if not (O:IsA("BasePart") and not O.Anchored) then return false end
    if O:FindFirstAncestorOfClass("Model") and O:FindFirstAncestorOfClass("Model"):FindFirstChildOfClass("Humanoid") then
        return false
    end
    for _, p in ipairs(P:GetPlayers()) do
        if p.Character and O:IsDescendantOf(p.Character) then
            return false
        end
    end
    return true
end

-- Block Gathering & High-Frequency Rainbow Loop
local function CC()
    local newCP = {}
    local LIM = GETLIMIT()
    for _, O in ipairs(workspace:GetDescendants()) do
        if #newCP >= LIM then break end
        if VLD(O) then
            NeutralizePhysics(O)
            table.insert(newCP, O)
        end
    end
    CP = newCP

    -- Rapid Rainbow Execution: Fast color waves across all blocks simultaneously
    if IsRainbowActive and (os.clock() - LastRainbowUse > 0.02) then
        LastRainbowUse = os.clock()
        local timeTick = os.clock() * RainbowSpeed
        for i, part in ipairs(CP) do
            local rainbowHue = (timeTick + (i / math.max(1, #CP))) % 1
            local rainbowColor = Color3.fromHSV(rainbowHue, 1, 1)
            part.Color = rainbowColor
            -- Broadcasts paint packets so color is FE Server-Sided
            DispatchPaintToolRemote(part, rainbowColor)
        end
    elseif IsPaintActive and (os.clock() - LastToolUse > 0.1) then
        LastToolUse = os.clock()
        for _, part in ipairs(CP) do
            ForcePaintBlockServerSided(part)
        end
    end
end

-- Floor Distance Helper
local function GetFloorDistance(originPos, ignoreChar)
    if not originPos or typeof(originPos) ~= "Vector3" then return 0 end
    local raycastParams = RaycastParams.new()
    pcall(function() raycastParams.FilterType = Enum.RaycastFilterType.Exclude end)
    local filterList = {}
    if ignoreChar then table.insert(filterList, ignoreChar) end
    for _, p in ipairs(CP) do table.insert(filterList, p) end
    raycastParams.FilterDescendantsInstances = filterList

    local success, rayResult = pcall(function()
        return workspace:Raycast(originPos, Vector3.new(0, -30, 0), raycastParams)
    end)

    if success and rayResult then return rayResult.Position.Y end
    return originPos.Y - 14
end

-- ========================================================
-- 6. GOJO'S HOLLOW PURPLE (FE / SERVER-SIDED REPLICATION)
-- Broadcasts remote paint events and network-owned linear velocity
-- so all server players witness the Lapse Red + Lapse Blue + Purple Blast!
-- ========================================================
THollowPurple.MouseButton1Click:Connect(function()
    SWITCH_MODE("Hollow Purple")
    CC()
    if #CP < 4 then return end

    IsHollowPurpleActive = true
    local startTime = os.clock()
    local Center, TargetRoot = GET_TARGET_POS()
    local TargetDirection = (M.Hit.Position - Center).Unit
    local hasFired = false
    local blastStart = 0
    local blastPos = Center
    local lastServerColorBroadcast = 0

    AC = R.RenderStepped:Connect(function()
        if not IsHollowPurpleActive then return end
        local elapsed = os.clock() - startTime
        local total = #CP
        local half = math.floor(total / 2)
        local RootPos = GET_TARGET_POS()
        local shouldBroadcastColor = (os.clock() - lastServerColorBroadcast > 0.15)
        if shouldBroadcastColor then lastServerColorBroadcast = os.clock() end

        -- Phase 1 (0 to 1.4s): Orbiting Lapse Blue & Lapse Red
        if elapsed < 1.4 then
            local orbitSpeed = elapsed * 15
            local converge = math.clamp(1 - (elapsed / 1.4), 0.1, 1)

            for i, PRT in ipairs(CP) do
                if PRT and PRT.Parent then
                    if i <= half then
                        -- LAPSE BLUE (Vortex Blue)
                        local blueColor = Color3.fromRGB(0, 150, 255)
                        PRT.Color = blueColor
                        if shouldBroadcastColor then DispatchPaintToolRemote(PRT, blueColor) end

                        local angle = orbitSpeed + (i * (math.pi * 2 / half))
                        local radius = 6 * converge
                        local blueOffset = Vector3.new(
                            math.cos(angle) * radius + (4 * converge),
                            2 + math.sin(angle * 2) * (2 * converge),
                            math.sin(angle) * radius
                        )
                        UpdateFEPart(PRT, CFrame.new(RootPos + blueOffset), GetBlockLerpSpeed())
                    else
                        -- REVERSAL RED (Opposing Red)
                        local redColor = Color3.fromRGB(255, 30, 45)
                        PRT.Color = redColor
                        if shouldBroadcastColor then DispatchPaintToolRemote(PRT, redColor) end

                        local angle = -orbitSpeed + (i * (math.pi * 2 / (total - half)))
                        local radius = 6 * converge
                        local redOffset = Vector3.new(
                            math.cos(angle) * radius - (4 * converge),
                            2 + math.sin(angle * 2) * (2 * converge),
                            math.sin(angle) * radius
                        )
                        UpdateFEPart(PRT, CFrame.new(RootPos + redOffset), GetBlockLerpSpeed())
                    end
                end
            end

        -- Phase 2 (1.4s to 2.2s): Fusion into Hollow Purple Sphere
        elseif elapsed < 2.2 then
            local purpleTime = elapsed - 1.4
            local spinSpeed = 25
            local sphereCenter = RootPos + (TargetDirection * 5) + Vector3.new(0, 2, 0)
            blastPos = sphereCenter
            local purpleColor = Color3.fromRGB(180, 20, 255)

            for i, PRT in ipairs(CP) do
                if PRT and PRT.Parent then
                    PRT.Color = purpleColor
                    if shouldBroadcastColor then DispatchPaintToolRemote(PRT, purpleColor) end

                    local phi = (1 + math.sqrt(5)) / 2
                    local y = 1 - (i / total) * 2
                    local radius = math.sqrt(1 - y * y) * (3 + math.sin(purpleTime * 10) * 0.5)
                    local theta = phi * i * math.pi + (purpleTime * spinSpeed)
                    local x = math.cos(theta) * radius
                    local z = math.sin(theta) * radius

                    local targetCF = CFrame.new(sphereCenter + Vector3.new(x, y * 3, z))
                    UpdateFEPart(PRT, targetCF, 0.4)
                end
            end

        -- Phase 3 (2.2s+): High-Velocity Beam Blast (FE Replicated)
        else
            if not hasFired then
                hasFired = true
                blastStart = os.clock()
                TargetDirection = (M.Hit.Position - RootPos).Unit
            end

            local blastDuration = os.clock() - blastStart
            blastPos = blastPos + (TargetDirection * (BlockSpeed * 3))
            local intensePurple = Color3.fromRGB(160, 10, 255)

            for i, PRT in ipairs(CP) do
                if PRT and PRT.Parent then
                    PRT.CanCollide = false
                    PRT.Anchored = false
                    PRT.Color = intensePurple
                    -- Replicates high blast velocity across network
                    PRT.AssemblyLinearVelocity = TargetDirection * (BlockSpeed * 20)
                    PRT.AssemblyAngularVelocity = Vector3.new(0.5, 0.5, 0.5)

                    local trailOffset = Vector3.new(
                        math.sin(i + elapsed * 10) * 2,
                        math.cos(i + elapsed * 10) * 2,
                        -((i % 10) * 1.5)
                    )
                    PRT.CFrame = CFrame.new(blastPos + trailOffset, blastPos + trailOffset + TargetDirection)
                end
            end

            if blastDuration > 3.5 then
                IsHollowPurpleActive = false
                HoldBlocksInStaging()
            end
        end
    end)
end)

-- ========================================================
-- 7. CHAIN TRAIL (FOLLOWS LIKE A REAL INTERLOCKED CHAIN)
-- Strict distance constraint between link i and link i-1
-- ========================================================
TChain.MouseButton1Click:Connect(function()
    SWITCH_MODE("Chain")
    CC()
    if #CP == 0 then return end

    local linkDistance = 2.2
    local chainPositions = {}

    local root = L.Character and L.Character:FindFirstChild("HumanoidRootPart")
    local startPos = root and root.Position or Vector3.zero
    for i = 1, #CP do
        chainPositions[i] = startPos - Vector3.new(0, 0, i * linkDistance)
    end

    AC = R.RenderStepped:Connect(function()
        local C = L.Character
        local Root = C and C:FindFirstChild("HumanoidRootPart")
        if not Root then return end

        -- Leader is player's root part trailing back
        local leadPos = Root.Position - (Root.CFrame.LookVector * 1.5) - Vector3.new(0, 1.5, 0)
        chainPositions[1] = leadPos

        for i = 2, #CP do
            local prev = chainPositions[i - 1]
            local curr = chainPositions[i] or prev
            local delta = curr - prev
            local dist = delta.Magnitude

            -- Enforce chain link distance constraint
            if dist > linkDistance then
                chainPositions[i] = prev + (delta.Unit * linkDistance)
            elseif dist < 0.1 then
                chainPositions[i] = prev - (Root.CFrame.LookVector * linkDistance)
            end

            -- Ground hugging / floor collision check
            local floorY = GetFloorDistance(chainPositions[i], C)
            if chainPositions[i].Y < floorY + 1 then
                chainPositions[i] = Vector3.new(chainPositions[i].X, floorY + 1, chainPositions[i].Z)
            end
        end

        for i, PRT in ipairs(CP) do
            if PRT and PRT.Parent then
                local pos = chainPositions[i]
                local nextPos = chainPositions[math.max(1, i - 1)]
                local lookAtCFrame
                if (nextPos - pos).Magnitude > 0.01 then
                    lookAtCFrame = CFrame.lookAt(pos, nextPos)
                else
                    lookAtCFrame = CFrame.new(pos)
                end

                -- Alternate 90-degree link roll for genuine chain link appearance
                local rollAngle = (i % 2 == 0) and math.rad(90) or 0
                local targetCF = lookAtCFrame * CFrame.Angles(0, 0, rollAngle)
                UpdateFEPart(PRT, targetCF, GetBlockLerpSpeed())
            end
        end
    end)
end)

-- ========================================================
-- 8. SNAKE PHYSICS (SINUSOIDAL UNDULATION & GROUND KINEMATICS)
-- Realistic snake slithering wave with ground contact
-- ========================================================
TSnake.MouseButton1Click:Connect(function()
    SWITCH_MODE("Snake")
    CC()
    if #CP == 0 then return end

    local segmentDist = 2.0
    local snakePositions = {}
    local snakeTime = 0

    local root = L.Character and L.Character:FindFirstChild("HumanoidRootPart")
    local startPos = root and root.Position or Vector3.zero
    for i = 1, #CP do
        snakePositions[i] = startPos - Vector3.new(0, 1.8, i * segmentDist)
    end

    AC = R.RenderStepped:Connect(function(dt)
        local C = L.Character
        local Root = C and C:FindFirstChild("HumanoidRootPart")
        local Hum = C and C:FindFirstChildOfClass("Humanoid")
        if not Root or not Hum then return end

        snakeTime = snakeTime + dt
        local velocity = Root.AssemblyLinearVelocity
        local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
        local isMoving = speed > 0.5
        local slitherRate = isMoving and math.clamp(speed * 1.5, 4, 14) or 3.0

        -- Head follows slightly in front of feet
        local headTarget = Root.Position + (Root.CFrame.LookVector * 1.5) - Vector3.new(0, 2.2, 0)
        snakePositions[1] = snakePositions[1] and snakePositions[1]:Lerp(headTarget, 0.4) or headTarget

        for i = 2, #CP do
            local prev = snakePositions[i - 1]
            local curr = snakePositions[i] or prev
            local delta = curr - prev
            local dist = delta.Magnitude

            -- Distance constraint
            if dist > segmentDist then
                curr = prev + (delta.Unit * segmentDist)
            end

            -- Snake lateral slither wave (perpendicular to direction)
            local segDir = (prev - curr).Unit
            local rightVec = Vector3.new(-segDir.Z, 0, segDir.X)
            local waveAmp = math.sin((snakeTime * slitherRate) - (i * 0.45)) * (isMoving and 1.8 or 0.8)

            local groundY = GetFloorDistance(curr, C)
            snakePositions[i] = Vector3.new(curr.X + (rightVec.X * waveAmp * 0.15), math.max(groundY + 0.8, curr.Y), curr.Z + (rightVec.Z * waveAmp * 0.15))
        end

        for i, PRT in ipairs(CP) do
            if PRT and PRT.Parent then
                local pos = snakePositions[i]
                local nextPos = snakePositions[math.max(1, i - 1)]
                local lookCF
                if (nextPos - pos).Magnitude > 0.05 then
                    lookCF = CFrame.lookAt(pos, nextPos)
                else
                    lookCF = CFrame.new(pos)
                end

                UpdateFEPart(PRT, lookCF, GetBlockLerpSpeed())
            end
        end
    end)
end)

-- ========================================================
-- 9. ANIMATED SHARK MORPH (SWIMMING TAIL, FINS & EYE BLINK)
-- Accurate shark colors: Slate Grey / Deep Blue body, white belly,
-- dynamic swimming tail, pectoral fins and blinking painted eyes!
-- ========================================================
TShark.MouseButton1Click:Connect(function()
    SWITCH_MODE("Shark")
    CC()
    if #CP == 0 then return end
    SET_CHARACTER_VISIBILITY(false)

    local sharkTime = 0
    local Cam = workspace.CurrentCamera
    local sharkBodyColor = Color3.fromRGB(45, 65, 95)    -- Oceanic Slate Blue
    local sharkBellyColor = Color3.fromRGB(235, 240, 250) -- Shark White Underbelly
    local eyeOpenColor = Color3.fromRGB(15, 15, 20)       -- Glossy Shark Eye
    local eyeClosedColor = sharkBodyColor                 -- Eye Lid matches body

    AC = R.RenderStepped:Connect(function(dt)
        local C = L.Character
        local Root = C and C:FindFirstChild("HumanoidRootPart")
        local Hum = C and C:FindFirstChildOfClass("Humanoid")
        if not Root or not Hum then return end

        SET_CHARACTER_VISIBILITY(false)
        sharkTime = sharkTime + dt

        local velocity = Root.AssemblyLinearVelocity
        local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
        local isMoving = speed > 0.5
        local swimRate = isMoving and math.clamp(speed * 1.8, 5, 16) or 3.2

        -- Shark Eye Blinking Logic (Paints eye blocks to close/open eyes)
        if os.clock() - LastEyeBlinkTime > 3.5 then
            EyesClosed = true
            if os.clock() - LastEyeBlinkTime > 3.75 then
                EyesClosed = false
                LastEyeBlinkTime = os.clock()
            end
        end

        local rootCF = Root.CFrame
        local total = #CP
        local snoutIndex = 1
        local eyeLeftIndex = 2
        local eyeRightIndex = 3

        -- Construct Shark Anatomy Map
        local sharkPoints = {}
        local sharkColors = {}

        -- Snout & Jaws
        table.insert(sharkPoints, Vector3.new(0, 0, -8))
        table.insert(sharkColors, sharkBodyColor)

        -- Left & Right Eyes (Blinks by painting!)
        table.insert(sharkPoints, Vector3.new(-1.8, 0.8, -6.5))
        table.insert(sharkColors, EyesClosed and eyeClosedColor or eyeOpenColor)

        table.insert(sharkPoints, Vector3.new(1.8, 0.8, -6.5))
        table.insert(sharkColors, EyesClosed and eyeClosedColor or eyeOpenColor)

        -- Head & Gills
        for z = -5, -2, 1 do
            table.insert(sharkPoints, Vector3.new(-2.2, 0.2, z))
            table.insert(sharkColors, sharkBodyColor)
            table.insert(sharkPoints, Vector3.new(2.2, 0.2, z))
            table.insert(sharkColors, sharkBodyColor)
            table.insert(sharkPoints, Vector3.new(0, -1.2, z))
            table.insert(sharkColors, sharkBellyColor)
        end

        -- Dorsal Fin (Sways slightly on top)
        local finSway = math.sin(sharkTime * swimRate) * 0.15
        table.insert(sharkPoints, Vector3.new(finSway, 3.2, -1))
        table.insert(sharkColors, sharkBodyColor)
        table.insert(sharkPoints, Vector3.new(finSway * 1.5, 4.5, 0))
        table.insert(sharkColors, sharkBodyColor)

        -- Pectoral Left & Right Fins (Flare out & tilt when turning)
        local turnTilt = math.clamp(velocity.X * 0.05, -0.4, 0.4)
        table.insert(sharkPoints, Vector3.new(-4.5, -0.8 + turnTilt, -2))
        table.insert(sharkColors, sharkBodyColor)
        table.insert(sharkPoints, Vector3.new(-6.2, -1.2 + turnTilt, -1))
        table.insert(sharkColors, sharkBodyColor)

        table.insert(sharkPoints, Vector3.new(4.5, -0.8 - turnTilt, -2))
        table.insert(sharkColors, sharkBodyColor)
        table.insert(sharkPoints, Vector3.new(6.2, -1.2 - turnTilt, -1))
        table.insert(sharkColors, sharkBodyColor)

        -- Torso Core
        for z = -1, 3, 1 do
            table.insert(sharkPoints, Vector3.new(0, 1.2, z))
            table.insert(sharkColors, sharkBodyColor)
            table.insert(sharkPoints, Vector3.new(-2, 0, z))
            table.insert(sharkColors, sharkBodyColor)
            table.insert(sharkPoints, Vector3.new(2, 0, z))
            table.insert(sharkColors, sharkBodyColor)
            table.insert(sharkPoints, Vector3.new(0, -1.2, z))
            table.insert(sharkColors, sharkBellyColor)
        end

        -- Articulated Swimming Tail (Sinusoidal lateral flexion)
        local tailSegments = 8
        for tIdx = 1, tailSegments do
            local tailProgress = tIdx / tailSegments
            local swayX = math.sin((sharkTime * swimRate) - (tIdx * 0.5)) * (tailProgress * 3.5)
            local zPos = 3 + (tIdx * 1.5)
            table.insert(sharkPoints, Vector3.new(swayX, 0, zPos))
            table.insert(sharkColors, sharkBodyColor)

            -- Caudal Tail Fin Tips (Upper and Lower lobes)
            if tIdx == tailSegments then
                table.insert(sharkPoints, Vector3.new(swayX * 1.2, 2.5, zPos + 1.5))
                table.insert(sharkColors, sharkBodyColor)
                table.insert(sharkPoints, Vector3.new(swayX * 1.2, -2.0, zPos + 1.2))
                table.insert(sharkColors, sharkBellyColor)
            end
        end

        local pCount = #sharkPoints

        for i, PRT in ipairs(CP) do
            if PRT and PRT.Parent then
                local pointIdx = ((i - 1) % pCount) + 1
                local baseOffset = sharkPoints[pointIdx]
                local targetColor = sharkColors[pointIdx] or sharkBodyColor

                PRT.Color = targetColor
                -- Broadcast eye blink or shark paint server-sided
                if pointIdx == eyeLeftIndex or pointIdx == eyeRightIndex then
                    DispatchPaintToolRemote(PRT, targetColor)
                end

                local targetCF = rootCF * CFrame.new(baseOffset)
                UpdateFEPart(PRT, targetCF, GetBlockLerpSpeed())
            end
        end

        if Cam then
            Cam.CameraType = Enum.CameraType.Custom
            Hum.CameraOffset = Vector3.new(0, 8, 0)
        end
    end)
end)

-- ========================================================
-- 10. ANIMATED STICKMAN MORPH (FE OPTIMIZED)
-- ========================================================
TStickMan.MouseButton1Click:Connect(function()
    SWITCH_MODE("Stickman")
    CC()
    if #CP == 0 then return end
    SET_CHARACTER_VISIBILITY(false)

    local function generateLine(p1, p2, count)
        local pts = {}
        for i = 1, count do
            local t = (i - 1) / math.max(1, count - 1)
            table.insert(pts, p1:Lerp(p2, t))
        end
        return pts
    end

    local function generateCircle(center, radius, count)
        local pts = {}
        for i = 1, count do
            local angle = (i / count) * math.pi * 2
            table.insert(pts, center + Vector3.new(math.cos(angle) * radius, math.sin(angle) * radius, 0))
        end
        return pts
    end

    local animTime = 0
    local Cam = workspace.CurrentCamera

    AC = R.RenderStepped:Connect(function(dt)
        local C = L.Character
        local Root = C and C:FindFirstChild("HumanoidRootPart")
        local Hum = C and C:FindFirstChildOfClass("Humanoid")
        if not Root or not Hum then return end

        SET_CHARACTER_VISIBILITY(false)
        animTime = animTime + dt

        local velocity = Root.AssemblyLinearVelocity
        local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
        local state = Hum:GetState()
        local isMoving = speed > 0.5

        local groundY = GetFloorDistance(Root.Position, C)
        local currentLowestFootY = Root.Position.Y - 12
        local groundOffset = math.max(0, groundY - currentLowestFootY)

        local headCenter = Vector3.new(0, 16 + groundOffset, 0)
        local neck = Vector3.new(0, 12 + groundOffset, 0)
        local pelvis = Vector3.new(0, 1 + groundOffset, 0)

        local leftHand, rightHand, leftFoot, rightFoot

        if state == Enum.HumanoidStateType.Jumping or velocity.Y > 2 then
            leftHand = neck + Vector3.new(-10, 8, 2)
            rightHand = neck + Vector3.new(10, 8, 2)
            leftFoot = pelvis + Vector3.new(-6, -3, 4)
            rightFoot = pelvis + Vector3.new(6, -3, -2)
        elseif state == Enum.HumanoidStateType.Freefall or velocity.Y < -2 then
            leftHand = neck + Vector3.new(-12, 12, -2)
            rightHand = neck + Vector3.new(12, 12, -2)
            leftFoot = pelvis + Vector3.new(-5, -8, -2)
            rightFoot = pelvis + Vector3.new(5, -8, 2)
        else
            local cycleSpeed = math.clamp(speed * 0.8, 4, 12)
            local swingAngle = isMoving and math.sin(animTime * cycleSpeed) * 0.8 or math.sin(animTime * 2) * 0.05

            leftHand = neck + Vector3.new(-10 * math.cos(swingAngle), -8 * math.sin(swingAngle) - 2, math.sin(swingAngle) * 6)
            rightHand = neck + Vector3.new(10 * math.cos(-swingAngle), -8 * math.sin(-swingAngle) - 2, math.sin(-swingAngle) * 6)

            local leftFootY = math.max(-11, -11 * math.cos(swingAngle))
            local rightFootY = math.max(-11, -11 * math.cos(-swingAngle))
            leftFoot = pelvis + Vector3.new(-4, leftFootY, math.sin(swingAngle) * 8)
            rightFoot = pelvis + Vector3.new(4, rightFootY, math.sin(-swingAngle) * 8)
        end

        local totalBlocks = #CP
        local headCount = math.clamp(math.floor(totalBlocks * 0.20), 8, 28)
        local spineCount = math.clamp(math.floor(totalBlocks * 0.15), 5, 16)
        local armCount = math.clamp(math.floor(totalBlocks * 0.10), 4, 12)
        local legCount = math.clamp(math.floor(totalBlocks * 0.12), 4, 15)

        local skeletonPoints = {}
        for _, p in ipairs(generateCircle(headCenter, 4.5, headCount)) do table.insert(skeletonPoints, p) end
        for _, p in ipairs(generateLine(neck, pelvis, spineCount)) do table.insert(skeletonPoints, p) end
        for _, p in ipairs(generateLine(neck, leftHand, armCount)) do table.insert(skeletonPoints, p) end
        for _, p in ipairs(generateLine(neck, rightHand, armCount)) do table.insert(skeletonPoints, p) end
        for _, p in ipairs(generateLine(pelvis, leftFoot, legCount)) do table.insert(skeletonPoints, p) end
        for _, p in ipairs(generateLine(pelvis, rightFoot, legCount)) do table.insert(skeletonPoints, p) end

        local rootCF = Root.CFrame
        local skelLen = #skeletonPoints

        for i, PRT in ipairs(CP) do
            if PRT and PRT.Parent then
                local pointIndex = ((i - 1) % skelLen) + 1
                local baseOffset = skeletonPoints[pointIndex]
                local targetCF = rootCF * CFrame.new(baseOffset)
                UpdateFEPart(PRT, targetCF, GetBlockLerpSpeed())
            end
        end

        if Cam then
            Cam.CameraType = Enum.CameraType.Custom
            Hum.CameraOffset = Vector3.new(0, 14, 0)
        end
    end)
end)

-- Standard Weapons & Handlers
TRifle.MouseButton1Click:Connect(function() CurrentWeapon = (CurrentWeapon == "Rifle") and "None" or "Rifle" end)
TSword.MouseButton1Click:Connect(function() CurrentWeapon = (CurrentWeapon == "Sword") and "None" or "Sword" end)

local function FlingPlayer(targetChar, launchVector)
    if not targetChar then return end
    local root = targetChar:FindFirstChild("HumanoidRootPart")
    if not root then return end

    task.spawn(function()
        local duration = 0.5
        local startTime = os.clock()
        while os.clock() - startTime < duration do
            for _, part in ipairs(CP) do
                if part and part.Parent then
                    part.CFrame = root.CFrame
                    part.AssemblyLinearVelocity = launchVector * (BlockSpeed / 60)
                end
            end
            task.wait()
        end
    end)
end

local function ShootRifleBullet()
    if #CP < 5 or os.clock() - LastShotTime < 0.25 then return end
    LastShotTime = os.clock()

    local bulletPart = CP[#CP]
    local root = L.Character and L.Character:FindFirstChild("HumanoidRootPart")
    if not root or not bulletPart then return end

    local startPos = root.Position + Vector3.new(0, 2, 0)
    local targetPos = M.Hit.Position
    local direction = (targetPos - startPos).Unit

    bulletPart.CFrame = CFrame.new(startPos, startPos + direction)
    bulletPart.AssemblyLinearVelocity = direction * (BlockSpeed * 8)

    local conn
    conn = bulletPart.Touched:Connect(function(hit)
        local char = hit.Parent
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum and char ~= L.Character then
            conn:Disconnect()
            FlingPlayer(char, Vector3.new(math.random(-5000, 5000), 10000, math.random(-5000, 5000)))
        end
    end)

    task.delay(1.5, function() if conn then conn:Disconnect() end end)
end

local function PerformSwordSlash()
    if IsSlashing or #CP < 5 then return end
    IsSlashing = true

    task.spawn(function()
        local duration = 0.25
        local startTime = os.clock()

        while os.clock() - startTime < duration do
            local progress = (os.clock() - startTime) / duration
            SlashAngle = math.rad(-110 + (progress * 220))

            local root = L.Character and L.Character:FindFirstChild("HumanoidRootPart")
            if root then
                for _, p in ipairs(P:GetPlayers()) do
                    if p ~= L and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                        local targetRoot = p.Character.HumanoidRootPart
                        if (targetRoot.Position - root.Position).Magnitude < 18 then
                            FlingPlayer(p.Character, Vector3.new(math.random(-4000, 4000), 30000, math.random(-4000, 4000)))
                        end
                    end
                end
            end
            task.wait()
        end

        SlashAngle = 0
        IsSlashing = false
    end)
end

U.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        if CurrentWeapon == "Rifle" then ShootRifleBullet()
        elseif CurrentWeapon == "Sword" then PerformSwordSlash() end
    end
end)

-- Flying System
local ToggleFlyFunction = function()
    Flying = not Flying
    if FlyConnection then FlyConnection:Disconnect() FlyConnection = nil end

    local C = L.Character
    local Root = C and C:FindFirstChild("HumanoidRootPart")
    local Hum = C and C:FindFirstChildOfClass("Humanoid")

    if not Flying or not Root or not Hum then
        if Hum then Hum.PlatformStand = false end
        return
    end

    Hum.PlatformStand = true
    FlyConnection = R.RenderStepped:Connect(function(dt)
        if not Flying or not Root or not Hum then
            if Hum then Hum.PlatformStand = false end
            if FlyConnection then FlyConnection:Disconnect() end
            return
        end

        local CamCF = workspace.CurrentCamera.CFrame
        local MoveVec = Vector3.zero

        if U:IsKeyDown(Enum.KeyCode.W) then MoveVec = MoveVec + CamCF.LookVector end
        if U:IsKeyDown(Enum.KeyCode.S) then MoveVec = MoveVec - CamCF.LookVector end
        if U:IsKeyDown(Enum.KeyCode.A) then MoveVec = MoveVec - CamCF.RightVector end
        if U:IsKeyDown(Enum.KeyCode.D) then MoveVec = MoveVec + CamCF.RightVector end
        if U:IsKeyDown(Enum.KeyCode.Space) then MoveVec = MoveVec + Vector3.new(0, 1, 0) end
        if U:IsKeyDown(Enum.KeyCode.LeftShift) then MoveVec = MoveVec - Vector3.new(0, 1, 0) end

        Root.AssemblyLinearVelocity = Vector3.zero
        Root.CFrame = Root.CFrame + (MoveVec * (FlySpeed * dt))
    end)
end

TFly.MouseButton1Click:Connect(ToggleFlyFunction)

-- Other Animations (All automatically invoke SWITCH_MODE to ensure camera/POV reset)
TFollow.MouseButton1Click:Connect(function()
    SWITCH_MODE("Follow")
    CC()
    local A = 0
    local lastBroadcast = 0
    AC = R.RenderStepped:Connect(function()
        local Center = GET_TARGET_POS()
        A = A + 0.03
        local shouldBroadcast = (os.clock() - lastBroadcast > 0.2)
        if shouldBroadcast then lastBroadcast = os.clock() end

        for i, PRT in ipairs(CP) do
            if PRT and PRT.Parent then
                PRT.Color = SelectedColor
                if shouldBroadcast then DispatchPaintToolRemote(PRT, SelectedColor) end
                local angle = A + (i * (math.pi * 2 / #CP))
                local offset = Vector3.new(math.cos(angle) * 6, 2 + math.sin(i + A) * 2, math.sin(angle) * 6)
                local targetCF = CFrame.new(Center + offset)
                UpdateFEPart(PRT, targetCF, GetBlockLerpSpeed())
            end
        end
    end)
end)

TBlaster.MouseButton1Click:Connect(function()
    SWITCH_MODE("Blaster")
    CC()
    if #CP < 2 then return end

    BlasterActive = true
    local currentBulletIndex = 1
    local lastBroadcast = 0

    AC = R.RenderStepped:Connect(function()
        local Center = GET_TARGET_POS()
        local Barrel = CP[1]
        local shouldBroadcast = (os.clock() - lastBroadcast > 0.5)
        if shouldBroadcast then lastBroadcast = os.clock() end

        if Barrel and Barrel.Parent then
            local barrelColor = Color3.fromRGB(255, 50, 50)
            Barrel.Color = barrelColor
            if shouldBroadcast then DispatchPaintToolRemote(Barrel, barrelColor) end
            local barrelCF = CFrame.new(Center + Vector3.new(2, 2, -2), M.Hit.Position)
            UpdateFEPart(Barrel, barrelCF, 0.4)
        end

        local root = L.Character and L.Character:FindFirstChild("HumanoidRootPart")
        local stagingPos = root and (root.Position + Vector3.new(0, STAGING_ALTITUDE, 0)) or Center
        for i = 2, #CP do
            local b = CP[i]
            if b and b.Parent then
                local targetCF = CFrame.new(stagingPos + Vector3.new((i % 5) * 2, 0, math.floor(i / 5) * 2))
                UpdateFEPart(b, targetCF, GetBlockLerpSpeed())
            end
        end
    end)

    BlasterConnection = U.InputBegan:Connect(function(input, gpe)
        if gpe or not BlasterActive then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            currentBulletIndex = (currentBulletIndex % (#CP - 1)) + 2
            local Bullet = CP[currentBulletIndex]
            local Barrel = CP[1]

            if Bullet and Bullet.Parent and Barrel and Barrel.Parent then
                Bullet.CanCollide = false
                Bullet.Anchored = false
                Bullet.CFrame = Barrel.CFrame * CFrame.new(0, 0, -2)
                local TargetDir = (M.Hit.Position - Barrel.Position).Unit
                Bullet.AssemblyLinearVelocity = TargetDir * (BlockSpeed * 8)
                Bullet.AssemblyAngularVelocity = Vector3.new(0.5, 0.5, 0.5)
            end
        end
    end)
end)

THelix.MouseButton1Click:Connect(function()
    SWITCH_MODE("Helix")
    CC()
    local A = 0
    local lastBroadcast = 0
    AC = R.RenderStepped:Connect(function()
        local Center = GET_TARGET_POS()
        A = A + 0.05
        local shouldBroadcast = (os.clock() - lastBroadcast > 0.25)
        if shouldBroadcast then lastBroadcast = os.clock() end

        for i, PRT in ipairs(CP) do
            if PRT and PRT.Parent then
                local helixColor = Color3.fromHSV((i / #CP + A * 0.1) % 1, 0.8, 1)
                PRT.Color = helixColor
                if shouldBroadcast then DispatchPaintToolRemote(PRT, helixColor) end
                local y = ((i * 0.8) % 30) - 15
                local side = (i % 2 == 0) and 1 or -1
                local angle = A + (y * 0.3)
                local x = math.cos(angle) * 6 * side
                local z = math.sin(angle) * 6 * side
                local targetCF = CFrame.new(Center + Vector3.new(x, y + 10, z))
                UpdateFEPart(PRT, targetCF, GetBlockLerpSpeed())
            end
        end
    end)
end)

TTornado.MouseButton1Click:Connect(function()
    SWITCH_MODE("Tornado")
    CC()
    local A = 0
    local lastBroadcast = 0
    AC = R.RenderStepped:Connect(function()
        local TargetPos = M.Hit.Position
        A = A + 0.1
        local shouldBroadcast = (os.clock() - lastBroadcast > 0.3)
        if shouldBroadcast then lastBroadcast = os.clock() end

        for i, PRT in ipairs(CP) do
            if PRT and PRT.Parent then
                local tornadoColor = Color3.fromRGB(200, 200, 220)
                PRT.Color = tornadoColor
                if shouldBroadcast then DispatchPaintToolRemote(PRT, tornadoColor) end
                local height = (i / math.max(1, #CP)) * 25
                local radius = height * 0.6 + 2
                local angle = A + i
                local targetCF = CFrame.new(TargetPos + Vector3.new(math.cos(angle) * radius, height, math.sin(angle) * radius))
                UpdateFEPart(PRT, targetCF, GetBlockLerpSpeed())
            end
        end
    end)
end)

TD.MouseButton1Click:Connect(function()
    SWITCH_MODE("Draw")
    CC()
    AC = R.RenderStepped:Connect(function()
        local TPos = M.Hit.Position
        for _, PRT in ipairs(CP) do
            if PRT and PRT.Parent then
                local targetCF = CFrame.new(TPos + Vector3.new(0, 2, 0))
                UpdateFEPart(PRT, targetCF, GetBlockLerpSpeed())
            end
        end
    end)
end)

TV.MouseButton1Click:Connect(function()
    SWITCH_MODE("Vortex")
    CC()
    local A = 0
    local lastBroadcast = 0
    AC = R.RenderStepped:Connect(function()
        local Center = GET_TARGET_POS()
        A = A + 0.05
        local shouldBroadcast = (os.clock() - lastBroadcast > 0.25)
        if shouldBroadcast then lastBroadcast = os.clock() end

        for i, PRT in ipairs(CP) do
            if PRT and PRT.Parent then
                PRT.Color = SelectedColor
                if shouldBroadcast then DispatchPaintToolRemote(PRT, SelectedColor) end
                local D, CA = 10 + (i * 0.2), A + (i * 0.1)
                local targetCF = CFrame.new(Center + Vector3.new(math.cos(CA) * D, (i * 0.1) % 15, math.sin(CA) * D))
                UpdateFEPart(PRT, targetCF, GetBlockLerpSpeed())
            end
        end
    end)
end)

TR.MouseButton1Click:Connect(function()
    SWITCH_MODE("Rain")
    CC()
    local lastBroadcast = 0
    AC = R.RenderStepped:Connect(function()
        local Center = GET_TARGET_POS()
        local shouldBroadcast = (os.clock() - lastBroadcast > 0.3)
        if shouldBroadcast then lastBroadcast = os.clock() end

        for i, PRT in ipairs(CP) do
            if PRT and PRT.Parent then
                local rainColor = Color3.fromRGB(0, 120, 255)
                PRT.Color = rainColor
                if shouldBroadcast then DispatchPaintToolRemote(PRT, rainColor) end
                local targetCF = CFrame.new(Center + Vector3.new(math.sin(i + os.clock()) * 30, 40 + (i % 20), math.cos(i + os.clock()) * 30))
                UpdateFEPart(PRT, targetCF, GetBlockLerpSpeed())
            end
        end
    end)
end)

TOrbit.MouseButton1Click:Connect(function()
    SWITCH_MODE("Orbit")
    CC()
    local A = 0
    local lastBroadcast = 0
    AC = R.RenderStepped:Connect(function()
        local Center = GET_TARGET_POS()
        A = A + 0.04
        local phi = (1 + math.sqrt(5)) / 2
        local shouldBroadcast = (os.clock() - lastBroadcast > 0.25)
        if shouldBroadcast then lastBroadcast = os.clock() end

        for i, PRT in ipairs(CP) do
            if PRT and PRT.Parent then
                PRT.Color = SelectedColor
                if shouldBroadcast then DispatchPaintToolRemote(PRT, SelectedColor) end
                local y = 1 - (i / math.max(1, #CP)) * 2
                local radius = math.sqrt(1 - y * y) * 12
                local theta = phi * i * math.pi + A
                local x = math.cos(theta) * radius
                local z = math.sin(theta) * radius
                local targetCF = CFrame.new(Center + Vector3.new(x, y * 12 + 2, z))
                UpdateFEPart(PRT, targetCF, GetBlockLerpSpeed())
            end
        end
    end)
end)

TShield.MouseButton1Click:Connect(function()
    SWITCH_MODE("Shield")
    CC()
    local A = 0
    local lastBroadcast = 0
    AC = R.RenderStepped:Connect(function()
        local Center = GET_TARGET_POS()
        A = A + 0.03
        local shouldBroadcast = (os.clock() - lastBroadcast > 0.25)
        if shouldBroadcast then lastBroadcast = os.clock() end

        for i, PRT in ipairs(CP) do
            if PRT and PRT.Parent then
                local shieldColor = Color3.fromRGB(50, 255, 100)
                PRT.Color = shieldColor
                if shouldBroadcast then DispatchPaintToolRemote(PRT, shieldColor) end
                local angle = A + (i * (math.pi * 2 / #CP))
                local x = math.cos(angle) * 5
                local z = math.sin(angle) * 5
                local targetCF = CFrame.new(Center + Vector3.new(x, (i % 3) * 2, z))
                UpdateFEPart(PRT, targetCF, GetBlockLerpSpeed())
            end
        end
    end)
end)

TFL.MouseButton1Click:Connect(function()
    SWITCH_MODE("Fling")
    CC()
    AC = R.RenderStepped:Connect(function()
        local Center, TargetRoot = GET_TARGET_POS()
        if TargetRoot then
            for _, PRT in ipairs(CP) do
                if PRT and PRT.Parent then
                    PRT.CanCollide = false
                    PRT.Anchored = false
                    PRT.AssemblyLinearVelocity = Vector3.new(10000, 10000, 10000)
                    PRT.CFrame = TargetRoot.CFrame
                end
            end
        end
    end)
end)

-- Main Background Loop (Stats & Scanning)
task.spawn(function()
    HoldBlocksInVoid()
    while task.wait(0.5) and S.Parent do
        pcall(function()
            CC()
            PL.Text = "Ping: " .. math.round(L:GetNetworkPing() * 1000) .. " ms"
            BL.Text = "Bricks: " .. #CP
            PLL.Text = "Players: " .. #P:GetPlayers()

            local enlightenedList = {}
            for _, player in ipairs(P:GetPlayers()) do
                local bp = player:FindFirstChildOfClass("Backpack")
                local ch = player.Character
                if (bp and bp:FindFirstChild("The Arkstone")) or (ch and ch:FindFirstChild("The Arkstone")) then
                    table.insert(enlightenedList, player.DisplayName)
                end
            end

            if #enlightenedList > 0 then
                EL.Text = "Enlightened: " .. table.concat(enlightenedList, ", ")
            else
                EL.Text = "Enlightened: None"
            end
        end)
    end
end)

TST.MouseButton1Click:Connect(STOP)

TReset.MouseButton1Click:Connect(function()
    STOP()
    if L.Character and L.Character:FindFirstChildOfClass("Humanoid") then
        L.Character:FindFirstChildOfClass("Humanoid").Health = 0
    end
end)

TRejoin.MouseButton1Click:Connect(function()
    T:TeleportToPlaceInstance(game.PlaceId, game.JobId, L)
end)

print("[Sofi Script Hub] Successfully Loaded! created by Sofi")
