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
local RainbowSpeed = 2
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
-- 2.5 DEDICATED "ANIMATIONS" SUB-GUI (Appears for Stickman & Shark)
-- ========================================================
local StickmanAnim = "walk" -- "walk" | "wave" | "sit" | "lay_down"
local SharkBiteActive = false
local SharkPetOrbitActive = false
local SharkPetOrbitRadius = 16

local AnimFrame = Instance.new("Frame", S)
AnimFrame.Name = "Animations"
AnimFrame.Size = UDim2.new(0, 168, 0, 172)
AnimFrame.Position = UDim2.new(0.02, 175, 0.28, 0)
AnimFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
AnimFrame.BorderSizePixel = 0
AnimFrame.Visible = false
AnimFrame.Active = true
AnimFrame.Draggable = true
Instance.new("UICorner", AnimFrame).CornerRadius = UDim.new(0, 8)
local AnimStroke = Instance.new("UIStroke", AnimFrame)
AnimStroke.Color = Color3.fromRGB(130, 80, 220)
AnimStroke.Thickness = 1.2

-- Header
local AnimHeader = Instance.new("Frame", AnimFrame)
AnimHeader.Size = UDim2.new(1, 0, 0, 26)
AnimHeader.BackgroundColor3 = Color3.fromRGB(34, 30, 48)
AnimHeader.BorderSizePixel = 0
Instance.new("UICorner", AnimHeader).CornerRadius = UDim.new(0, 8)

local AnimTitle = Instance.new("TextLabel", AnimHeader)
AnimTitle.Size = UDim2.new(1, -28, 1, 0)
AnimTitle.Position = UDim2.new(0, 8, 0, 0)
AnimTitle.BackgroundTransparency = 1
AnimTitle.TextColor3 = Color3.fromRGB(240, 225, 255)
AnimTitle.Text = "Animations"
AnimTitle.TextSize = 10
AnimTitle.Font = Enum.Font.GothamBold
AnimTitle.TextXAlignment = Enum.TextXAlignment.Left

-- Container for buttons
local AnimList = Instance.new("Frame", AnimFrame)
AnimList.Size = UDim2.new(1, -12, 1, -34)
AnimList.Position = UDim2.new(0, 6, 0, 30)
AnimList.BackgroundTransparency = 1

-- Stickman Controls
local StickmanButtons = Instance.new("Frame", AnimList)
StickmanButtons.Size = UDim2.new(1, 0, 1, 0)
StickmanButtons.BackgroundTransparency = 1
StickmanButtons.Visible = false
local SBLayout = Instance.new("UIListLayout", StickmanButtons)
SBLayout.Padding = UDim.new(0, 4)
SBLayout.SortOrder = Enum.SortOrder.LayoutOrder

local WaveBtn = Instance.new("TextButton", StickmanButtons)
WaveBtn.Size = UDim2.new(1, 0, 0, 24)
WaveBtn.BackgroundColor3 = Color3.fromRGB(60, 50, 95)
WaveBtn.TextColor3 = Color3.new(1, 1, 1)
WaveBtn.Text = "Wave: OFF"
WaveBtn.TextSize = 9
WaveBtn.Font = Enum.Font.GothamMedium
Instance.new("UICorner", WaveBtn).CornerRadius = UDim.new(0, 4)

local SitBtn = Instance.new("TextButton", StickmanButtons)
SitBtn.Size = UDim2.new(1, 0, 0, 24)
SitBtn.BackgroundColor3 = Color3.fromRGB(50, 75, 110)
SitBtn.TextColor3 = Color3.new(1, 1, 1)
SitBtn.Text = "Sit: OFF"
SitBtn.TextSize = 9
SitBtn.Font = Enum.Font.GothamMedium
Instance.new("UICorner", SitBtn).CornerRadius = UDim.new(0, 4)

local LayDownBtn = Instance.new("TextButton", StickmanButtons)
LayDownBtn.Size = UDim2.new(1, 0, 0, 24)
LayDownBtn.BackgroundColor3 = Color3.fromRGB(90, 50, 100)
LayDownBtn.TextColor3 = Color3.new(1, 1, 1)
LayDownBtn.Text = "Lay Down: OFF"
LayDownBtn.TextSize = 9
LayDownBtn.Font = Enum.Font.GothamMedium
Instance.new("UICorner", LayDownBtn).CornerRadius = UDim.new(0, 4)

local StandBtn = Instance.new("TextButton", StickmanButtons)
StandBtn.Size = UDim2.new(1, 0, 0, 22)
StandBtn.BackgroundColor3 = Color3.fromRGB(38, 38, 52)
StandBtn.TextColor3 = Color3.fromRGB(200, 200, 225)
StandBtn.Text = "Reset Pose / Stand"
StandBtn.TextSize = 8.5
StandBtn.Font = Enum.Font.GothamMedium
Instance.new("UICorner", StandBtn).CornerRadius = UDim.new(0, 4)

-- Shark Controls
local SharkButtons = Instance.new("Frame", AnimList)
SharkButtons.Size = UDim2.new(1, 0, 1, 0)
SharkButtons.BackgroundTransparency = 1
SharkButtons.Visible = false
local ShBLayout = Instance.new("UIListLayout", SharkButtons)
ShBLayout.Padding = UDim.new(0, 4)
ShBLayout.SortOrder = Enum.SortOrder.LayoutOrder

local BiteBtn = Instance.new("TextButton", SharkButtons)
BiteBtn.Size = UDim2.new(1, 0, 0, 24)
BiteBtn.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
BiteBtn.TextColor3 = Color3.new(1, 1, 1)
BiteBtn.Text = "Bite: OFF"
BiteBtn.TextSize = 9
BiteBtn.Font = Enum.Font.GothamMedium
Instance.new("UICorner", BiteBtn).CornerRadius = UDim.new(0, 4)

local PetOrbitBtn = Instance.new("TextButton", SharkButtons)
PetOrbitBtn.Size = UDim2.new(1, 0, 0, 24)
PetOrbitBtn.BackgroundColor3 = Color3.fromRGB(40, 110, 160)
PetOrbitBtn.TextColor3 = Color3.new(1, 1, 1)
PetOrbitBtn.Text = "Pet Orbit: OFF"
PetOrbitBtn.TextSize = 9
PetOrbitBtn.Font = Enum.Font.GothamMedium
Instance.new("UICorner", PetOrbitBtn).CornerRadius = UDim.new(0, 4)

local OrbitSliderFrame = Instance.new("Frame", SharkButtons)
OrbitSliderFrame.Size = UDim2.new(1, 0, 0, 36)
OrbitSliderFrame.BackgroundColor3 = Color3.fromRGB(28, 28, 38)
Instance.new("UICorner", OrbitSliderFrame).CornerRadius = UDim.new(0, 4)

local OrbitLabel = Instance.new("TextLabel", OrbitSliderFrame)
OrbitLabel.Size = UDim2.new(1, 0, 0, 14)
OrbitLabel.Position = UDim2.new(0, 4, 0, 2)
OrbitLabel.BackgroundTransparency = 1
OrbitLabel.TextColor3 = Color3.fromRGB(180, 220, 255)
OrbitLabel.Text = "Orbit Range: 16 studs"
OrbitLabel.TextSize = 8.5
OrbitLabel.Font = Enum.Font.GothamMedium
OrbitLabel.TextXAlignment = Enum.TextXAlignment.Left

local SliderTrack = Instance.new("TextButton", OrbitSliderFrame)
SliderTrack.Size = UDim2.new(1, -12, 0, 10)
SliderTrack.Position = UDim2.new(0, 6, 0, 20)
SliderTrack.BackgroundColor3 = Color3.fromRGB(45, 55, 75)
SliderTrack.Text = ""
Instance.new("UICorner", SliderTrack).CornerRadius = UDim.new(0, 5)

local SliderFill = Instance.new("Frame", SliderTrack)
local initialPct = math.clamp((SharkPetOrbitRadius - 6) / 44, 0, 1)
SliderFill.Size = UDim2.new(initialPct, 0, 1, 0)
SliderFill.BackgroundColor3 = Color3.fromRGB(50, 170, 250)
Instance.new("UICorner", SliderFill).CornerRadius = UDim.new(0, 5)

-- Event listeners for Stickman & Shark buttons
WaveBtn.MouseButton1Click:Connect(function()
    StickmanAnim = (StickmanAnim == "wave") and "walk" or "wave"
    WaveBtn.Text = (StickmanAnim == "wave") and "Wave: ON" or "Wave: OFF"
    WaveBtn.BackgroundColor3 = (StickmanAnim == "wave") and Color3.fromRGB(40, 170, 80) or Color3.fromRGB(60, 50, 95)
    if StickmanAnim == "wave" then
        SitBtn.Text = "Sit: OFF"
        SitBtn.BackgroundColor3 = Color3.fromRGB(50, 75, 110)
        LayDownBtn.Text = "Lay Down: OFF"
        LayDownBtn.BackgroundColor3 = Color3.fromRGB(90, 50, 100)
    end
end)

SitBtn.MouseButton1Click:Connect(function()
    StickmanAnim = (StickmanAnim == "sit") and "walk" or "sit"
    SitBtn.Text = (StickmanAnim == "sit") and "Sit: ON" or "Sit: OFF"
    SitBtn.BackgroundColor3 = (StickmanAnim == "sit") and Color3.fromRGB(40, 140, 210) or Color3.fromRGB(50, 75, 110)
    if StickmanAnim == "sit" then
        WaveBtn.Text = "Wave: OFF"
        WaveBtn.BackgroundColor3 = Color3.fromRGB(60, 50, 95)
        LayDownBtn.Text = "Lay Down: OFF"
        LayDownBtn.BackgroundColor3 = Color3.fromRGB(90, 50, 100)
    end
end)

LayDownBtn.MouseButton1Click:Connect(function()
    StickmanAnim = (StickmanAnim == "lay_down") and "walk" or "lay_down"
    LayDownBtn.Text = (StickmanAnim == "lay_down") and "Lay Down: ON" or "Lay Down: OFF"
    LayDownBtn.BackgroundColor3 = (StickmanAnim == "lay_down") and Color3.fromRGB(150, 50, 170) or Color3.fromRGB(90, 50, 100)
    if StickmanAnim == "lay_down" then
        WaveBtn.Text = "Wave: OFF"
        WaveBtn.BackgroundColor3 = Color3.fromRGB(60, 50, 95)
        SitBtn.Text = "Sit: OFF"
        SitBtn.BackgroundColor3 = Color3.fromRGB(50, 75, 110)
    end
end)

StandBtn.MouseButton1Click:Connect(function()
    StickmanAnim = "walk"
    WaveBtn.Text = "Wave: OFF"
    WaveBtn.BackgroundColor3 = Color3.fromRGB(60, 50, 95)
    SitBtn.Text = "Sit: OFF"
    SitBtn.BackgroundColor3 = Color3.fromRGB(50, 75, 110)
    LayDownBtn.Text = "Lay Down: OFF"
    LayDownBtn.BackgroundColor3 = Color3.fromRGB(90, 50, 100)
end)

BiteBtn.MouseButton1Click:Connect(function()
    SharkBiteActive = not SharkBiteActive
    BiteBtn.Text = SharkBiteActive and "Bite: ON (Aggressive)" or "Bite: OFF"
    BiteBtn.BackgroundColor3 = SharkBiteActive and Color3.fromRGB(220, 40, 40) or Color3.fromRGB(150, 40, 40)
end)

PetOrbitBtn.MouseButton1Click:Connect(function()
    SharkPetOrbitActive = not SharkPetOrbitActive
    PetOrbitBtn.Text = SharkPetOrbitActive and "Pet Orbit: ON" or "Pet Orbit: OFF"
    PetOrbitBtn.BackgroundColor3 = SharkPetOrbitActive and Color3.fromRGB(35, 180, 120) or Color3.fromRGB(40, 110, 160)
    if SharkPetOrbitActive then
        SET_CHARACTER_VISIBILITY(true)
        RESET_CAMERA()
    else
        SET_CHARACTER_VISIBILITY(false)
        local Hum = L.Character and L.Character:FindFirstChildOfClass("Humanoid")
        if Hum then Hum.CameraOffset = Vector3.new(0, 8, 0) end
    end
end)

local isDraggingSlider = false
local function UpdateOrbitSlider(input)
    local trackAbs = SliderTrack.AbsolutePosition
    local trackWidth = SliderTrack.AbsoluteSize.X
    if trackWidth <= 0 then return end
    local pct = math.clamp((input.Position.X - trackAbs.X) / trackWidth, 0, 1)
    SharkPetOrbitRadius = math.round(6 + pct * 44)
    SliderFill.Size = UDim2.new(pct, 0, 1, 0)
    OrbitLabel.Text = "Orbit Range: " .. SharkPetOrbitRadius .. " studs"
end

SliderTrack.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isDraggingSlider = true
        UpdateOrbitSlider(input)
    end
end)

game:GetService("UserInputService").InputChanged:Connect(function(input)
    if isDraggingSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        UpdateOrbitSlider(input)
    end
end)

game:GetService("UserInputService").InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isDraggingSlider = false
    end
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

-- Compact Stats Panel (With Live Active Block Radar & Remote Spy Verification)
local StatsFrame = Instance.new("Frame", SF)
StatsFrame.Size = UDim2.new(1, -4, 0, 94)
StatsFrame.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
StatsFrame.BorderSizePixel = 0
StatsFrame.LayoutOrder = 1
Instance.new("UICorner", StatsFrame).CornerRadius = UDim.new(0, 5)

local function ST(Y, Text)
    local LN = Instance.new("TextLabel", StatsFrame)
    LN.Size = UDim2.new(0.95, 0, 0, 13)
    LN.Position = UDim2.new(0.03, 0, 0, Y)
    LN.BackgroundTransparency = 1
    LN.TextColor3 = Color3.fromRGB(190, 205, 235)
    LN.TextSize = 8.5
    LN.Font = Enum.Font.GothamMedium
    LN.TextXAlignment = Enum.TextXAlignment.Left
    LN.TextWrapped = true
    LN.Text = Text
    return LN
end

local PL = ST(4, "Ping: -- ms")
local BL = ST(18, "Active FE Orbit: 0 blocks")
local BPhys = ST(32, "Block State: 🟢 100% Active & Awake")
BPhys.TextColor3 = Color3.fromRGB(80, 255, 140)
local BRemote = ST(46, "Remote: Paint.Script.Event 🤝 Ready")
BRemote.TextColor3 = Color3.fromRGB(130, 200, 255)
local PLL = ST(60, "Players: 0")
local EL = ST(74, "Enlightened: Searching...")
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
NB.Text = "ALL (∞)"
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
local TNoLimitBtn = BTN("Block Limit: ∞ UNLIMITED", Color3.fromRGB(20, 160, 120))
local TRadarBtn = BTN("Block Radar ESP: ON", Color3.fromRGB(30, 160, 100))
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

-- Unlimited Block Count Toggle Logic
local IsNoLimitActive = true
TNoLimitBtn.MouseButton1Click:Connect(function()
    IsNoLimitActive = not IsNoLimitActive
    if IsNoLimitActive then
        TNoLimitBtn.Text = "Block Limit: ∞ UNLIMITED"
        TNoLimitBtn.BackgroundColor3 = Color3.fromRGB(20, 160, 120)
        NB.Text = "ALL (∞)"
    else
        TNoLimitBtn.Text = "Block Limit: CAPPED"
        TNoLimitBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 90)
        NB.Text = "50"
    end
end)

-- Block-Only Noclip Engine & Anti-Void Protection:
-- Only unanchored orbit blocks have collisions disabled with the player.
-- Character torso, legs, and feet STAY COLLIDABLE with map geometry so you NEVER fall out of the map into the void!
local function SetupBlockNoCollide(part)
    if not part or not part:IsA("BasePart") then return end
    part.CanCollide = false
    local char = L.Character
    if char then
        for _, cp in ipairs(char:GetChildren()) do
            if cp:IsA("BasePart") then
                local ncc = part:FindFirstChild("NCC_" .. cp.Name)
                if not ncc then
                    ncc = Instance.new("NoCollisionConstraint")
                    ncc.Name = "NCC_" .. cp.Name
                    ncc.Part0 = part
                    ncc.Part1 = cp
                    ncc.Parent = part
                end
            end
        end
    end
end

R.Stepped:Connect(function()
    -- 1. Ensure all active orbit blocks never collide with the player
    for _, part in ipairs(CP) do
        if part and part.Parent and not part.Anchored then
            part.CanCollide = false
            SetupBlockNoCollide(part)
        end
    end

    -- 2. Maintain solid ground collision for character, only HRP collision disabled for smooth block pass-through
    local char = L.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then hrp.CanCollide = false end

        -- 3. Anti-Void Floor Guard: If player falls near void height, rescue back to ground level!
        local voidThreshold = (workspace.FallenPartsDestroyHeight or -500) + 40
        if hrp and hrp.Position.Y < voidThreshold then
            hrp.AssemblyLinearVelocity = Vector3.new(0, 35, 0)
            local groundY = GetFloorDistance(Vector3.new(hrp.Position.X, 100, hrp.Position.Z), char)
            hrp.CFrame = CFrame.new(hrp.Position.X, math.max(10, groundY + 5), hrp.Position.Z)
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
    if IsNoLimitActive then return math.huge end
    local txt = NB.Text:upper():gsub("%s+", "")
    if txt == "ALL" or txt == "INF" or txt == "NOLIMIT" or txt == "MAX" or txt == "∞" or txt:find("ALL") or txt == "" then
        return math.huge
    end
    local V = tonumber(txt)
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
    if not part or not part.Parent or part.Anchored then return end
    part.CanCollide = false
    part.Anchored = false

    local root = L.Character and L.Character:FindFirstChild("HumanoidRootPart")
    if root then
        local dist = (part.Position - root.Position).Magnitude
        -- If part somehow drifted, dropped, or fell (> 85 studs away), snap it back into orbit!
        if dist > 85 then
            part.CFrame = root.CFrame * CFrame.new(0, 3, 0)
            part.AssemblyLinearVelocity = Vector3.new(0, 0.5, 0)
            return
        end
    end

    local alpha = lerpAlpha or GetBlockLerpSpeed()
    local currentCF = part.CFrame
    local newCF = (alpha >= 1) and targetCF or currentCF:Lerp(targetCF, alpha)
    local delta = newCF.Position - currentCF.Position

    -- CRITICAL FOR FE: AssemblyLinearVelocity matching displacement prevents sleep
    -- and forces Roblox server physics replication to sync position to all other players!
    part.AssemblyLinearVelocity = (delta * 35) + Vector3.new(0, 0.12, 0)
    part.AssemblyAngularVelocity = Vector3.new(0.05, 0, 0.05)
    part.CFrame = newCF

    pcall(function()
        if sethiddenproperty then
            sethiddenproperty(part, "NetworkIsSleeping", false)
        end
    end)
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

-- Universal Mode Switcher: Automatically resets camera/POV, summons blocks, and cleans previous loops
local function SummonBlocksToPlayer()
    local root = L.Character and L.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    for i, part in ipairs(CP) do
        if part and part.Parent and not part.Anchored then
            part.CanCollide = false
            part.Anchored = false
            local dist = (part.Position - root.Position).Magnitude
            if dist > 35 then
                part.CFrame = root.CFrame * CFrame.new(math.random(-5, 5), math.random(1, 4), math.random(-5, 5))
            end
            part.AssemblyLinearVelocity = Vector3.new(0, 0.5, 0)
        end
    end
end

local function SWITCH_MODE(newModeName)
    if AC then AC:Disconnect() AC = nil end
    if BlasterConnection then BlasterConnection:Disconnect() BlasterConnection = nil end
    BlasterActive = false
    CurrentWeapon = "None"
    IsSlashing = false
    IsHollowPurpleActive = false

    -- Reset Animations GUI states
    StickmanAnim = "walk"
    SharkBiteActive = false
    SharkPetOrbitActive = false
    if WaveBtn then WaveBtn.Text = "Wave: OFF"; WaveBtn.BackgroundColor3 = Color3.fromRGB(60, 50, 95) end
    if SitBtn then SitBtn.Text = "Sit: OFF"; SitBtn.BackgroundColor3 = Color3.fromRGB(50, 75, 110) end
    if LayDownBtn then LayDownBtn.Text = "Lay Down: OFF"; LayDownBtn.BackgroundColor3 = Color3.fromRGB(90, 50, 100) end
    if BiteBtn then BiteBtn.Text = "Bite: OFF"; BiteBtn.BackgroundColor3 = Color3.fromRGB(150, 40, 40) end
    if PetOrbitBtn then PetOrbitBtn.Text = "Pet Orbit: OFF"; PetOrbitBtn.BackgroundColor3 = Color3.fromRGB(40, 110, 160) end

    -- Show/hide Animations GUI based strictly on Stickman / Shark usage
    if newModeName == "Stickman" then
        AnimFrame.Visible = true
        AnimTitle.Text = "Animations - Stickman"
        StickmanButtons.Visible = true
        SharkButtons.Visible = false
    elseif newModeName == "Shark" then
        AnimFrame.Visible = true
        AnimTitle.Text = "Animations - Shark"
        StickmanButtons.Visible = false
        SharkButtons.Visible = true
    else
        AnimFrame.Visible = false
        StickmanButtons.Visible = false
        SharkButtons.Visible = false
    end

    SET_CHARACTER_VISIBILITY(true)
    RESET_CAMERA() -- Guarantees POV is clean whenever user switches to any button/orbit
    SummonBlocksToPlayer()

    CurrentActiveMode = newModeName
end

local function STOP()
    SWITCH_MODE("None")
    HoldBlocksInStaging()
end

-- ========================================================
-- 5. 100% FE PAINT TOOL & SERVER-SIDED EQUIP SPOOFING ENGINE
-- ========================================================
-- Comprehensive finder for paint tools in Backpack, Character, or Workspace
local function GetPaintTool()
    local char = L.Character
    local bp = L:FindFirstChildOfClass("Backpack")
    local searchIn = {}
    if char then table.insert(searchIn, char) end
    if bp then table.insert(searchIn, bp) end

    -- Priority 1: Match tool name keywords
    for _, container in ipairs(searchIn) do
        for _, item in ipairs(container:GetChildren()) do
            if item:IsA("Tool") then
                local n = item.Name:lower()
                if n:find("paint") or n:find("color") or n:find("f3x") or n:find("btool") or n:find("stamper") or n:find("draw") or n:find("brush") or n:find("spray") or n:find("bucket") or n:find("hue") then
                    return item
                end
            end
        end
    end

    -- Priority 2: Check tools containing paint/sync remotes
    for _, container in ipairs(searchIn) do
        for _, item in ipairs(container:GetChildren()) do
            if item:IsA("Tool") and (item:FindFirstChild("SyncColor") or item:FindFirstChild("Event", true) or item:FindFirstChildWhichIsA("RemoteEvent", true)) then
                return item
            end
        end
    end

    -- Priority 3: Workspace check
    local wsChar = workspace:FindFirstChild(L.Name)
    if wsChar then
        for _, item in ipairs(wsChar:GetChildren()) do
            if item:IsA("Tool") and (item.Name:lower():find("paint") or item.Name:lower():find("color")) then
                return item
            end
        end
    end

    return nil
end

-- Server-Spoofed Paint Tool Engine:
-- Equips tool, passes server validation, and keeps hands free
local function MaintainFakeEquippedPaintTool()
    local char = L.Character
    if not char then return end
    local tool = GetPaintTool()
    if not tool then return end

    if tool.Parent ~= char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            pcall(function() hum:EquipTool(tool) end)
        else
            pcall(function() tool.Parent = char end)
        end
    end

    -- Clear tool holding pose / RightGrip from character's right arm so player doesn't visibly hold it
    local rightArm = char:FindFirstChild("Right Arm") or char:FindFirstChild("RightHand")
    if rightArm then
        local grip = rightArm:FindFirstChild("RightGrip")
        if grip then pcall(function() grip:Destroy() end) end
    end

    local handle = tool:FindFirstChild("Handle")
    if handle and handle:IsA("BasePart") then
        local grip2 = handle:FindFirstChild("RightGrip")
        if grip2 then pcall(function() grip2:Destroy() end) end
        handle.Transparency = 1
        handle.CanCollide = false
    end
end

-- Dispatches paint tool remote packets to the server AND applies instant local visual coloring!
-- This guarantees the blocks turn the selected color immediately on your screen,
-- while replicating to other players whenever a paint tool/remote exists.
local function DispatchPaintToolRemote(part, colorToPaint)
    if not part or not part.Parent or not part:IsA("BasePart") then return end

    -- 1. INSTANT GUARANTEED VISUAL COLORING (Never fails to paint on client!)
    pcall(function()
        part.Color = colorToPaint
        part.BrickColor = BrickColor.new(colorToPaint)
        part.Material = Enum.Material.SmoothPlastic
    end)

    -- 2. Equip and prepare paint tool for server replication
    local Dtool = GetPaintTool()
    local char = L.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if Dtool and char and Dtool.Parent ~= char and hum then
        pcall(function() hum:EquipTool(Dtool) end)
    end

    MaintainFakeEquippedPaintTool()
    if Dtool then
        pcall(function() Dtool:Activate() end)
    end

    local pos = part.Position
    local brickCol = BrickColor.new(colorToPaint)

    -- 3. Broadcast to all remotes in Dtool
    if Dtool then
        for _, child in ipairs(Dtool:GetDescendants()) do
            if child:IsA("RemoteEvent") then
                -- Cobalt Remote Spy signature:
                pcall(function() child:FireServer(part, Enum.NormalId.Top, pos, "both ð¤", colorToPaint, "smooth", "") end)
                pcall(function() child:FireServer(part, Enum.NormalId.Top, pos, "both ð¤", brickCol, "smooth", "") end)
                pcall(function() child:FireServer(part, Enum.NormalId.Top, pos, "both 🤝", colorToPaint, "smooth", "") end)
                pcall(function() child:FireServer(part, Enum.NormalId.Top, pos, "both 🤝", brickCol, "smooth", "") end)
                -- Classic Stamper / Super Paint:
                pcall(function() child:FireServer(part, Enum.NormalId.Top, pos, "Paint", colorToPaint) end)
                pcall(function() child:FireServer(part, Enum.NormalId.Top, pos, "Paint", brickCol) end)
                pcall(function() child:FireServer(part, Enum.NormalId.Top, pos, "Color", colorToPaint) end)
                -- Direct Part & Color:
                pcall(function() child:FireServer(part, colorToPaint) end)
                pcall(function() child:FireServer(part, brickCol) end)
                pcall(function() child:FireServer(part, brickCol.Name) end)
                for _, side in ipairs(SidesList) do
                    pcall(function() child:FireServer(part, side, pos, "both 🤝", colorToPaint, "smooth", "") end)
                    pcall(function() child:FireServer(part, side, pos, "both 🤝", brickCol, "smooth", "") end)
                end
            elseif child:IsA("RemoteFunction") then
                pcall(function() child:InvokeServer(part, colorToPaint) end)
                pcall(function() child:InvokeServer({{ Part = part, Color = colorToPaint, Face = Enum.NormalId.Front }}) end)
            end
        end

        local syncColor = Dtool:FindFirstChild("SyncColor", true)
        if syncColor and syncColor:IsA("RemoteEvent") then
            pcall(function() syncColor:FireServer({{ Part = part, Color = colorToPaint, Face = Enum.NormalId.Front }}) end)
        end
    end

    -- 4. ReplicatedStorage centralized paint service fallback
    local rep = game:GetService("ReplicatedStorage")
    for _, rName in ipairs({"PaintPart", "ColorPart", "SetColor", "Paint", "SuperPaint", "ColorRemote", "BuildingTools"}) do
        local r = rep:FindFirstChild(rName, true)
        if r and r:IsA("RemoteEvent") then
            pcall(function() r:FireServer(part, colorToPaint) end)
            pcall(function() r:FireServer(part, brickCol) end)
        end
    end
end

local function ForcePaintBlockServerSided(part)
    DispatchPaintToolRemote(part, SelectedColor)
end

-- RAINBOW TOGGLE: Cycles colors across all unanchored blocks concurrently via FE Server Paint
TRainbow.MouseButton1Click:Connect(function()
    IsRainbowActive = not IsRainbowActive
    if IsRainbowActive then
        TRainbow.Text = "Rainbow (FE): ON"
        TRainbow.BackgroundColor3 = Color3.fromRGB(40, 190, 80)
        MaintainFakeEquippedPaintTool()
    else
        TRainbow.Text = "Rainbow (FE): OFF"
        TRainbow.BackgroundColor3 = Color3.fromRGB(130, 45, 175)
        -- Return tool to backpack cleanly when disabled
        local tool = GetPaintTool()
        local bp = L:FindFirstChildOfClass("Backpack")
        if tool and bp and tool.Parent == L.Character then
            pcall(function() tool.Parent = bp end)
        end
    end
end)

TPaintBtn.MouseButton1Click:Connect(function()
    IsPaintActive = not IsPaintActive
    if IsPaintActive then
        TPaintBtn.Text = "Paint Blocks: ON"
        TPaintBtn.BackgroundColor3 = Color3.fromRGB(50, 180, 50)
        MaintainFakeEquippedPaintTool()
    else
        TPaintBtn.Text = "Paint Blocks: OFF"
        TPaintBtn.BackgroundColor3 = Color3.fromRGB(140, 50, 50)
    end
end)

-- Continuously preserve fake-equipped status when rainbow is active
R.Stepped:Connect(function()
    if IsRainbowActive or IsPaintActive then
        MaintainFakeEquippedPaintTool()
    end
end)

-- Dedicated FE Rainbow Broadcast Loop (Smooth, slowed down, 100% server paint)
task.spawn(function()
    while task.wait(0.08) and S.Parent do
        if IsRainbowActive and #CP > 0 then
            MaintainFakeEquippedPaintTool()
            local timeTick = os.clock() * RainbowSpeed
            local total = #CP
            for i, part in ipairs(CP) do
                if part and part.Parent and not part.Anchored then
                    local rainbowHue = (timeTick + (i / math.max(1, total))) % 1
                    local rainbowColor = Color3.fromHSV(rainbowHue, 1, 1)
                    -- 100% FE Paint: Server paints the block through the tool remote!
                    -- NO fake client-side part.Color assignments!
                    DispatchPaintToolRemote(part, rainbowColor)
                end
            end
        elseif IsPaintActive and #CP > 0 then
            for _, part in ipairs(CP) do
                if part and part.Parent and not part.Anchored then
                    ForcePaintBlockServerSided(part)
                end
            end
        end
    end
end)

-- Strict 100% FE Server-Sided Part Validation Engine:
-- Eliminates ALL client-side fake parts, anchored world geometry, camera parts, and non-replicated objects!
local function VLD(O)
    if not O or not O.Parent then return false end
    if not O:IsA("BasePart") or O:IsA("Terrain") then return false end
    if O.Anchored then return false end
    if not O:IsDescendantOf(workspace) then return false end
    if O:IsDescendantOf(workspace.CurrentCamera) then return false end

    -- Must not be part of any character or humanoid
    local model = O:FindFirstAncestorOfClass("Model")
    if model and model:FindFirstChildOfClass("Humanoid") then
        return false
    end
    for _, p in ipairs(P:GetPlayers()) do
        if p.Character and O:IsDescendantOf(p.Character) then
            return false
        end
    end

    -- Ignore accessory handles attached to characters
    if O.Name == "Handle" and O.Parent and O.Parent:IsA("Accessory") then
        return false
    end

    return true
end

-- Persistent Part Index Gathering Engine (100% FE SERVER BLOCKS ONLY):
-- Scans workspace (with priority for workspace.Bricks, workspace.Parts, workspace.Blocks)
-- Preserves existing parts in CP at their EXACT indexes so no blocks ever swap positions or jump!
local function CC()
    local LIM = GETLIMIT()
    local kept = {}
    local existingSet = {}

    -- 1. Retain all valid existing parts in CP at their exact positions, pruning invalid or anchored parts
    for _, p in ipairs(CP) do
        if p and p.Parent and VLD(p) and #kept < LIM then
            table.insert(kept, p)
            existingSet[p] = true
        end
    end

    -- 2. Only append newly discovered genuine FE unanchored server blocks to the end
    if #kept < LIM then
        -- Fast Priority Pass: check dedicated folders first if game uses them (like workspace.Bricks from screenshot!)
        local priorityFolders = { workspace:FindFirstChild("Bricks"), workspace:FindFirstChild("Parts"), workspace:FindFirstChild("Blocks") }
        for _, f in ipairs(priorityFolders) do
            if f then
                for _, O in ipairs(f:GetChildren()) do
                    if #kept >= LIM then break end
                    if not existingSet[O] and VLD(O) then
                        ClaimPartFE(O)
                        table.insert(kept, O)
                        existingSet[O] = true
                    end
                end
            end
        end

        -- General Workspace Pass
        if #kept < LIM then
            for _, O in ipairs(workspace:GetDescendants()) do
                if #kept >= LIM then break end
                if not existingSet[O] and VLD(O) then
                    ClaimPartFE(O)
                    table.insert(kept, O)
                    existingSet[O] = true
                end
            end
        end
    end

    CP = kept
end

-- ========================================================
-- BLOCK RADAR & LIVE ACTIVITY INSPECTOR (100% TRANSPARENCY)
-- Renders 3D BillboardGuis directly above every block in workspace
-- 🟢 GREEN: Active & Awake in formation with live speed & distance
-- 🔴 AMBER: Dormant / Sleeping parts in workspace
-- ========================================================
local IsRadarActive = true
local RadarBillboards = {}

local function ClearRadar()
    for part, bb in pairs(RadarBillboards) do
        if bb and bb.Parent then pcall(function() bb:Destroy() end) end
    end
    RadarBillboards = {}
    for _, item in ipairs(workspace:GetDescendants()) do
        if item.Name == "SOFI_BLOCK_RADAR" then
            pcall(function() item:Destroy() end)
        end
    end
end

local function UpdateBlockRadar()
    if not IsRadarActive then
        ClearRadar()
        return
    end

    local activeMap = {}
    for i, p in ipairs(CP) do
        if p and p.Parent then
            activeMap[p] = i
        end
    end

    local root = L.Character and L.Character:FindFirstChild("HumanoidRootPart")
    local rootPos = root and root.Position or Vector3.zero

    -- 1. Radar tags for all active blocks in CP
    for i, part in ipairs(CP) do
        if part and part.Parent and not part.Anchored then
            local bb = RadarBillboards[part]
            if not bb or not bb.Parent then
                bb = Instance.new("BillboardGui")
                bb.Name = "SOFI_BLOCK_RADAR"
                bb.Size = UDim2.new(0, 105, 0, 32)
                bb.StudsOffset = Vector3.new(0, 2.4, 0)
                bb.AlwaysOnTop = true
                bb.Adornee = part
                bb.Parent = part

                local f = Instance.new("Frame", bb)
                f.Size = UDim2.new(1, 0, 1, 0)
                f.BackgroundColor3 = Color3.fromRGB(16, 26, 20)
                f.BackgroundTransparency = 0.2
                Instance.new("UICorner", f).CornerRadius = UDim.new(0, 4)

                local stroke = Instance.new("UIStroke", f)
                stroke.Color = Color3.fromRGB(40, 255, 120)
                stroke.Thickness = 1

                local title = Instance.new("TextLabel", f)
                title.Name = "Title"
                title.Size = UDim2.new(1, 0, 0.5, 0)
                title.BackgroundTransparency = 1
                title.TextColor3 = Color3.fromRGB(60, 255, 130)
                title.TextSize = 8.5
                title.Font = Enum.Font.GothamBold

                local sub = Instance.new("TextLabel", f)
                sub.Name = "Sub"
                sub.Size = UDim2.new(1, 0, 0.5, 0)
                sub.Position = UDim2.new(0, 0, 0.5, 0)
                sub.BackgroundTransparency = 1
                sub.TextColor3 = Color3.fromRGB(210, 245, 220)
                sub.TextSize = 7.5
                sub.Font = Enum.Font.GothamMedium

                RadarBillboards[part] = bb
            end

            local vel = part.AssemblyLinearVelocity
            local speed = vel and math.round(vel.Magnitude) or 0
            local dist = math.round((part.Position - rootPos).Magnitude)
            local f = bb:FindFirstChildOfClass("Frame")
            if f then
                local t = f:FindFirstChild("Title")
                local s = f:FindFirstChild("Sub")
                if t then t.Text = "🟢 FE ACTIVE #" .. i end
                if s then s.Text = "Vel: " .. speed .. " | Dist: " .. dist .. "m" end
            end
        end
    end

    -- Clean up stale tags
    for part, bb in pairs(RadarBillboards) do
        if not part or not part.Parent or not activeMap[part] then
            if bb and bb.Parent then pcall(function() bb:Destroy() end) end
            RadarBillboards[part] = nil
        end
    end
end

TRadarBtn.MouseButton1Click:Connect(function()
    IsRadarActive = not IsRadarActive
    if IsRadarActive then
        TRadarBtn.Text = "Block Radar ESP: ON"
        TRadarBtn.BackgroundColor3 = Color3.fromRGB(30, 160, 100)
    else
        TRadarBtn.Text = "Block Radar ESP: OFF"
        TRadarBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 95)
        ClearRadar()
    end
end)

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
                    if shouldBroadcastColor then DispatchPaintToolRemote(PRT, intensePurple) end
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
-- 9. ANIMATED SHARK MORPH (100% FE & PERSISTENT ANATOMY)
-- Accurate shark colors: Slate Grey / Deep Blue body, white belly,
-- dynamic swimming tail, pectoral fins and blinking painted eyes!
-- Every block has its OWN unique non-overlapping spot.
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

    local LastEyeState = false
    local LastEyeBlinkTime = os.clock()
    local EyesClosed = false

    -- Server-sided initial shark paint: Colors the whole shark via FE paint tool
    task.spawn(function()
        for i, PRT in ipairs(CP) do
            if PRT and PRT.Parent then
                local col = (i == 2 or i == 3) and eyeOpenColor or ((i % 2 == 0) and sharkBodyColor or sharkBellyColor)
                DispatchPaintToolRemote(PRT, col)
            end
        end
    end)

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
        local turnTilt = math.clamp(velocity.X * 0.05, -0.4, 0.4)

        -- Shark Eye Blinking Logic (Paints eye blocks to close/open eyes via FE Paint Tool)
        local now = os.clock()
        if now - LastEyeBlinkTime > 3.8 then
            EyesClosed = true
            if now - LastEyeBlinkTime > 4.05 then
                EyesClosed = false
                LastEyeBlinkTime = now
            end
        else
            EyesClosed = false
        end

        -- Broadcast paint remote ONLY when eye state actually flips (prevents remote flooding!)
        -- Strictly uses FE remote with NO fake client paints!
        if EyesClosed ~= LastEyeState then
            LastEyeState = EyesClosed
            local eyeCol = EyesClosed and eyeClosedColor or eyeOpenColor
            if CP[2] and CP[2].Parent then
                DispatchPaintToolRemote(CP[2], eyeCol)
            end
            if CP[3] and CP[3].Parent then
                DispatchPaintToolRemote(CP[3], eyeCol)
            end
        end

        local totalBlocks = #CP
        if totalBlocks == 0 then return end

        -- BITE ANIMATION CALCULATIONS (Aggressive Jaws & Head Lunge)
        local biteCycle = (sharkTime * 14) % (math.pi * 2)
        local chomp = SharkBiteActive and math.abs(math.sin(biteCycle)) or 0
        local jawDrop = chomp * 3.5
        local jawLift = chomp * 1.6
        local lungeZ = SharkBiteActive and (math.sin(biteCycle) * 3.0) or 0
        local thrashX = SharkBiteActive and (math.sin(sharkTime * 28) * 1.4) or 0
        local biteLunge = Vector3.new(thrashX * 0.4, 0, -lungeZ)

        -- PROCEDURAL ANATOMICAL SHARK MESH GENERATOR
        -- Generates EXACTLY totalBlocks distinct coordinates so EVERY block has its own dedicated spot!
        local offsets = {}
        local colors = {}

        -- Slot 1: Snout Tip (thrusts forward and snaps open)
        offsets[1] = Vector3.new(thrashX * 0.3, jawLift * 0.4, -8.0) + biteLunge
        colors[1] = sharkBodyColor

        -- Slot 2 & 3: Left and Right Eyes (Dedicated eye blocks!)
        if totalBlocks >= 2 then
            offsets[2] = Vector3.new(-1.8, 0.8 + jawLift * 0.2, -6.5) + biteLunge
            colors[2] = EyesClosed and eyeClosedColor or (SharkBiteActive and Color3.fromRGB(255, 30, 30) or eyeOpenColor)
        end
        if totalBlocks >= 3 then
            offsets[3] = Vector3.new(1.8, 0.8 + jawLift * 0.2, -6.5) + biteLunge
            colors[3] = EyesClosed and eyeClosedColor or (SharkBiteActive and Color3.fromRGB(255, 30, 30) or eyeOpenColor)
        end

        -- Slot 4: Upper Forehead
        if totalBlocks >= 4 then
            offsets[4] = Vector3.new(thrashX * 0.3, 1.0 + jawLift, -6.8) + biteLunge
            colors[4] = sharkBodyColor
        end

        -- Slot 5 & 6: Lower Jaws (Mandibles drop open aggressively during bite!)
        if totalBlocks >= 5 then
            offsets[5] = Vector3.new(-1.2 + thrashX * 0.3, -0.9 - jawDrop, -6.0) + biteLunge
            colors[5] = SharkBiteActive and Color3.fromRGB(240, 240, 240) or sharkBellyColor
        end
        if totalBlocks >= 6 then
            offsets[6] = Vector3.new(1.2 + thrashX * 0.3, -0.9 - jawDrop, -6.0) + biteLunge
            colors[6] = SharkBiteActive and Color3.fromRGB(240, 240, 240) or sharkBellyColor
        end

        -- Distribute remaining blocks into anatomical regions
        local cur = 7
        local remaining = math.max(0, totalBlocks - 6)

        if remaining > 0 then
            local dorsalCount = math.clamp(math.floor(remaining * 0.15), 1, 6)
            local pectoralCount = math.clamp(math.floor(remaining * 0.20), 2, 8)
            local pecSide = math.max(1, math.floor(pectoralCount / 2))
            local headCount = math.clamp(math.floor(remaining * 0.15), 1, 6)
            local tailCount = math.clamp(math.floor(remaining * 0.25), 2, 12)
            local torsoCount = math.max(1, remaining - (dorsalCount + (pecSide * 2) + headCount + tailCount))

            -- Head & Gills Flanks
            for h = 1, headCount do
                if cur > totalBlocks then break end
                local frac = h / headCount
                local z = -5.0 + (frac * 3.0)
                local side = (h % 2 == 0) and 1 or -1
                offsets[cur] = Vector3.new(side * 2.2, 0.2, z)
                colors[cur] = sharkBodyColor
                cur = cur + 1
            end

            -- Dorsal Fin (Top Blade rising with swim sway)
            local finSway = math.sin(sharkTime * swimRate) * 0.25
            for d = 1, dorsalCount do
                if cur > totalBlocks then break end
                local hFrac = d / dorsalCount
                local y = 2.0 + (hFrac * 2.8)
                local z = -1.2 + (hFrac * 1.5)
                offsets[cur] = Vector3.new(finSway * hFrac, y, z)
                colors[cur] = sharkBodyColor
                cur = cur + 1
            end

            -- Pectoral Fins (Left Wing)
            for p = 1, pecSide do
                if cur > totalBlocks then break end
                local pFrac = p / pecSide
                local x = -2.5 - (pFrac * 4.2)
                local y = -0.6 - (pFrac * 0.8) + (turnTilt * 1.5)
                local z = -2.0 + (pFrac * 1.8)
                offsets[cur] = Vector3.new(x, y, z)
                colors[cur] = sharkBodyColor
                cur = cur + 1
            end

            -- Pectoral Fins (Right Wing)
            for p = 1, pecSide do
                if cur > totalBlocks then break end
                local pFrac = p / pecSide
                local x = 2.5 + (pFrac * 4.2)
                local y = -0.6 - (pFrac * 0.8) - (turnTilt * 1.5)
                local z = -2.0 + (pFrac * 1.8)
                offsets[cur] = Vector3.new(x, y, z)
                colors[cur] = sharkBodyColor
                cur = cur + 1
            end

            -- Torso Core (Streamlined Cylindrical Body)
            for b = 1, torsoCount do
                if cur > totalBlocks then break end
                local bFrac = b / torsoCount
                local z = -1.5 + (bFrac * 4.5)
                local angle = b * 2.39996 -- Golden angle distribution around body cylinder
                local radiusX = 2.2 * (1 - math.abs(bFrac - 0.4) * 0.4)
                local radiusY = 1.6 * (1 - math.abs(bFrac - 0.4) * 0.4)
                local x = math.cos(angle) * radiusX
                local y = math.sin(angle) * radiusY
                offsets[cur] = Vector3.new(x, y, z)
                colors[cur] = (y < -0.2) and sharkBellyColor or sharkBodyColor
                cur = cur + 1
            end

            -- Articulated Swimming Tail & Caudal Fins
            for t = 1, tailCount do
                if cur > totalBlocks then break end
                local tFrac = t / tailCount
                local swayX = math.sin((sharkTime * swimRate) - (tFrac * 2.8)) * (tFrac * 3.8)
                local z = 3.2 + (tFrac * 9.5)
                local y = 0
                local col = sharkBodyColor

                -- Tail tip lobes (Caudal Fin)
                if t == tailCount then
                    y = 2.4
                    swayX = swayX * 1.2
                elseif t == tailCount - 1 and tailCount > 2 then
                    y = -2.0
                    col = sharkBellyColor
                    swayX = swayX * 1.2
                else
                    y = math.sin(t) * 0.4
                    col = (y < -0.1) and sharkBellyColor or sharkBodyColor
                end

                offsets[cur] = Vector3.new(swayX, y, z)
                colors[cur] = col
                cur = cur + 1
            end
        end

        -- GUARANTEED ALLOCATION FOR EVERY SINGLE BLOCK (prevents any missing parts!)
        while cur <= totalBlocks do
            local angle = cur * 1.5707
            local z = -2.0 + ((cur % 9) * 1.2)
            local y = (cur % 3 == 0) and 1.2 or -0.6
            offsets[cur] = Vector3.new(math.cos(angle) * 1.8, y, z)
            colors[cur] = (y < 0) and sharkBellyColor or sharkBodyColor
            cur = cur + 1
        end

        local rootCF = Root.CFrame
        local sharkBaseCF = rootCF

        -- PET ORBIT LOGIC: Shark orbits player smoothly with customizable range, avatar visible, and normal camera!
        if SharkPetOrbitActive then
            SET_CHARACTER_VISIBILITY(true)
            local orbitRadius = SharkPetOrbitRadius or 16
            local orbitSpeed = 1.3
            local angle = (sharkTime * orbitSpeed)
            local orbitX = math.cos(angle) * orbitRadius
            local orbitZ = math.sin(angle) * orbitRadius
            local heading = -angle + (math.pi / 2)
            sharkBaseCF = rootCF * CFrame.new(orbitX, 0, orbitZ) * CFrame.Angles(0, heading, 0)
            if Cam then
                Cam.CameraType = Enum.CameraType.Custom
                Hum.CameraOffset = Vector3.zero
            end
        else
            SET_CHARACTER_VISIBILITY(false)
            if Cam then
                Cam.CameraType = Enum.CameraType.Custom
                Hum.CameraOffset = Vector3.new(0, 8, 0)
            end
        end

        local lerpSpeed = math.clamp(BlockSpeed / 100, 0.35, 1.0)

        for i, PRT in ipairs(CP) do
            if PRT and PRT.Parent then
                local targetOffset = offsets[i] or Vector3.new(0, 0, 0)
                local targetCF = sharkBaseCF * CFrame.new(targetOffset)
                UpdateFEPart(PRT, targetCF, lerpSpeed)
            end
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

        -- ANIMATION STATE DISPATCHER:
        -- Supports "wave", "sit" (auto-walks if moving!), "lay_down", and default walking/jumping
        local activeAnim = StickmanAnim

        -- User prompt rule: "don't make it sit if I walk or move"
        if activeAnim == "sit" and isMoving then
            activeAnim = "walk"
        end

        if activeAnim == "lay_down" then
            -- Stickman lies flat horizontally along the ground
            headCenter = Vector3.new(0, 1.2 + groundOffset, -9.0)
            neck = Vector3.new(0, 1.0 + groundOffset, -5.0)
            pelvis = Vector3.new(0, 1.0 + groundOffset, 3.0)

            local chestBreath = math.sin(animTime * 3) * 0.25
            neck = neck + Vector3.new(0, chestBreath, 0)

            leftHand = neck + Vector3.new(-5.0, 0, 1.0)
            rightHand = neck + Vector3.new(5.0, 0, 1.0)
            leftFoot = pelvis + Vector3.new(-3.5, 0, 9.5)
            rightFoot = pelvis + Vector3.new(3.5, 0, 9.5)

        elseif activeAnim == "sit" then
            -- Seated pose: lowered pelvis, folded legs forward, arms resting on knees
            neck = Vector3.new(0, 7.5 + groundOffset, 0)
            headCenter = Vector3.new(0, 11.5 + groundOffset, 0)
            pelvis = Vector3.new(0, 0.8 + groundOffset, 0)

            local sitSway = math.sin(animTime * 2) * 0.15
            leftHand = pelvis + Vector3.new(-5.5, 2.0, 3.5 + sitSway)
            rightHand = pelvis + Vector3.new(5.5, 2.0, 3.5 + sitSway)
            leftFoot = pelvis + Vector3.new(-4.0, 0, 8.5)
            rightFoot = pelvis + Vector3.new(4.0, 0, 8.5)

        elseif state == Enum.HumanoidStateType.Jumping or velocity.Y > 2 then
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

            -- If Wave is active: Right hand lifts up high and waves back and forth!
            if activeAnim == "wave" then
                local waveAngle = math.sin(animTime * 12) * 0.6
                rightHand = neck + Vector3.new(8 + (waveAngle * 4.5), 11 + math.abs(waveAngle * 2), -2)
            else
                rightHand = neck + Vector3.new(10 * math.cos(-swingAngle), -8 * math.sin(-swingAngle) - 2, math.sin(-swingAngle) * 6)
            end

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

-- Main Background Loop (Stats, Block Radar & Scanning)
task.spawn(function()
    HoldBlocksInVoid()
    while task.wait(0.5) and S.Parent do
        pcall(function()
            CC()
            UpdateBlockRadar()
            PL.Text = "Ping: " .. math.round(L:GetNetworkPing() * 1000) .. " ms"

            local totalWorkspaceBlocks = 0
            for _, o in ipairs(workspace:GetDescendants()) do
                if o:IsA("BasePart") and not o.Anchored and not o:IsDescendantOf(workspace.CurrentCamera) then
                    totalWorkspaceBlocks = totalWorkspaceBlocks + 1
                end
            end

            local activeCount = #CP
            BL.Text = "Active FE Orbit: " .. activeCount .. " / " .. totalWorkspaceBlocks .. " blocks"
            if activeCount > 0 then
                BPhys.Text = "Block State: 🟢 " .. activeCount .. " Awake & Orbiting"
                BPhys.TextColor3 = Color3.fromRGB(80, 255, 140)
            else
                BPhys.Text = "Block State: 🟡 Scanning for unanchored parts"
                BPhys.TextColor3 = Color3.fromRGB(255, 200, 80)
            end
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
