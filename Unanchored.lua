---[[
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
local TAntiJitter = BTN("Anti-Jitter: ROCK-SOLID (FE)", Color3.fromRGB(30, 175, 125))
local THollowPurple = BTN("Hollow Purple (FE / Gojo)", Color3.fromRGB(150, 40, 235))
local TRainbow = BTN("Fast Rainbow: OFF", Color3.fromRGB(130, 45, 175))
local TChain = BTN("Chain Trail (Link Physics)", Color3.fromRGB(90, 140, 210))
local TSnake = BTN("Snake (Undulation Physics)", Color3.fromRGB(50, 160, 100))
local TShark = BTN("Shark Morph (Tail, Fins & Eyes)", Color3.fromRGB(45, 100, 180))
local TStickMan = BTN("Animated Stickman Morph", Color3.fromRGB(170, 60, 200))
local TBall = BTN("Ball (IRL Physics & Rolling)", Color3.fromRGB(230, 120, 30))
local TDoors = BTN("Doors: OFF", Color3.fromRGB(180, 110, 45))
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

local IsAntiJitterActive = true

R.Stepped:Connect(function()
    -- 1. Ensure all active orbit blocks never collide with the player and stay 100% still without jitter
    for _, part in ipairs(CP) do
        if part and part.Parent and not part.Anchored then
            part.CanCollide = false
            SetupBlockNoCollide(part)
            if IsAntiJitterActive then
                pcall(function()
                    part.RotVelocity = Vector3.zero
                end)
            end
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

-- Claim an unanchored part for FE: breaks welds to anchored world, wakes up physics, kills friction & snagging
local function ClaimPartFE(part)
    if not part or not part.Parent or not part:IsA("BasePart") then return end
    part.CanCollide = false
    part.Anchored = false

    -- Set physics properties: ultra-low density (0.001) and zero friction so blocks never snag or fight physics
    pcall(function()
        part.CustomPhysicalProperties = PhysicalProperties.new(0.001, 0, 0, 0, 0)
    end)

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

-- The Core FE Position & Velocity Updater (100% FE Rock-Solid, ZERO Jitter):
-- Uses high-damping BodyMovers + target distance clamping.
-- When the part is close to its target position, all residual velocity is zeroed,
-- preventing gravity fighting and micro-vibrations!
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
            part.AssemblyLinearVelocity = Vector3.zero
            pcall(function() part.Velocity = Vector3.zero end)
            return
        end
    end

    -- Ensure Anti-Jitter BodyMovers exist when Anti-Jitter is active
    local bp = part:FindFirstChild("FE_AntiJitter_BP")
    local bg = part:FindFirstChild("FE_AntiJitter_BG")

    if IsAntiJitterActive then
        if not bp then
            bp = Instance.new("BodyPosition")
            bp.Name = "FE_AntiJitter_BP"
            bp.MaxForce = Vector3.new(1e9, 1e9, 1e9)
            bp.P = 100000
            bp.D = 3000
            bp.Position = targetCF.Position
            bp.Parent = part
        end
        if not bg then
            bg = Instance.new("BodyGyro")
            bg.Name = "FE_AntiJitter_BG"
            bg.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
            bg.P = 100000
            bg.D = 3000
            bg.CFrame = targetCF
            bg.Parent = part
        end
    else
        if bp then bp:Destroy() end
        if bg then bg:Destroy() end
    end

    local currentCF = part.CFrame
    local distToTarget = (targetCF.Position - currentCF.Position).Magnitude

    if distToTarget < 0.04 then
        -- ROCK-SOLID STILLNESS: Target reached. Freeze in place with zero micro-oscillations
        part.CFrame = targetCF
        if bp then bp.Position = targetCF.Position end
        if bg then bg.CFrame = targetCF end
        part.AssemblyLinearVelocity = Vector3.zero
        part.AssemblyAngularVelocity = Vector3.zero
        pcall(function()
            part.Velocity = Vector3.zero
            part.RotVelocity = Vector3.zero
        end)
    else
        -- SMOOTH TRANSITION: Lerp cleanly toward target position without overshoot
        local alpha = math.clamp(lerpAlpha or GetBlockLerpSpeed(), 0.05, 1)
        local newCF = (alpha >= 1) and targetCF or currentCF:Lerp(targetCF, alpha)
        local delta = newCF.Position - currentCF.Position

        part.CFrame = newCF
        if bp then bp.Position = targetCF.Position end
        if bg then bg.CFrame = targetCF end

        -- Pure linear velocity proportional to movement; zero angular spin to stop rotational jitter
        local vel = delta * 45
        if vel.Magnitude > 100 then vel = vel.Unit * 100 end
        part.AssemblyLinearVelocity = vel
        part.AssemblyAngularVelocity = Vector3.zero
        pcall(function()
            part.Velocity = vel
            part.RotVelocity = Vector3.zero
        end)
    end

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

TAntiJitter.MouseButton1Click:Connect(function()
    IsAntiJitterActive = not IsAntiJitterActive
    if IsAntiJitterActive then
        TAntiJitter.Text = "Anti-Jitter: ROCK-SOLID (FE)"
        TAntiJitter.BackgroundColor3 = Color3.fromRGB(30, 175, 125)
    else
        TAntiJitter.Text = "Anti-Jitter: OFF (Raw Velocity)"
        TAntiJitter.BackgroundColor3 = Color3.fromRGB(80, 80, 95)
        for _, part in ipairs(CP) do
            if part and part.Parent then
                local bp = part:FindFirstChild("FE_AntiJitter_BP")
                local bg = part:FindFirstChild("FE_AntiJitter_BG")
                if bp then bp:Destroy() end
                if bg then bg:Destroy() end
            end
        end
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
        -- User requirement: "When orbiting, the shark is facing me and I want it to not face me but face the place it's moving forward."
        if SharkPetOrbitActive then
            SET_CHARACTER_VISIBILITY(true)
            local orbitRadius = SharkPetOrbitRadius or 16
            local orbitSpeed = 1.3
            local angle = (sharkTime * orbitSpeed)
            local orbitX = math.cos(angle) * orbitRadius
            local orbitZ = math.sin(angle) * orbitRadius

            -- Calculate current position and forward tangent direction along circular orbit
            local currentPos = rootCF * Vector3.new(orbitX, 0, orbitZ)
            local forwardTangent = rootCF:VectorToWorldSpace(Vector3.new(-math.sin(angle), 0, math.cos(angle))).Unit

            -- Shark snout is aligned at -Z; CFrame.lookAt points -Z directly along forward trajectory
            sharkBaseCF = CFrame.lookAt(currentPos, currentPos + forwardTangent)
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

        -- Ground Floor Calculation: Accurately aligns stickman with the exact surface the player's feet touch
        local groundY = GetFloorDistance(Root.Position, C)
        local floorRelY = groundY - Root.Position.Y

        -- Default standing upright reference positions
        local pelvis = Vector3.new(0, floorRelY + 11.0, 0)
        local neck = Vector3.new(0, floorRelY + 17.0, 0)
        local headCenter = Vector3.new(0, floorRelY + 21.5, 0)

        local leftHand, rightHand, leftFoot, rightFoot

        -- ANIMATION STATE DISPATCHER:
        -- Supports "wave", "sit" (auto-walks if moving!), "lay_down", and default walking/jumping
        local activeAnim = StickmanAnim

        -- User prompt rule: "don't make it sit if I walk or move"
        if activeAnim == "sit" and isMoving then
            activeAnim = "walk"
        end

        if activeAnim == "lay_down" then
            -- Stickman lies flat horizontally directly on the ground where the player's feet touch
            headCenter = Vector3.new(0, floorRelY + 0.6, -9.0)
            neck = Vector3.new(0, floorRelY + 0.5, -4.5)
            pelvis = Vector3.new(0, floorRelY + 0.4, 2.0)

            local chestBreath = math.sin(animTime * 3) * 0.2
            neck = neck + Vector3.new(0, chestBreath, 0)

            leftHand = neck + Vector3.new(-4.0, 0, 1.0)
            rightHand = neck + Vector3.new(4.0, 0, 1.0)
            leftFoot = pelvis + Vector3.new(-2.5, 0, 7.5)
            rightFoot = pelvis + Vector3.new(2.5, 0, 7.5)

        elseif activeAnim == "sit" then
            -- Seated pose: Pelvis and feet grounded directly on the floor plane
            pelvis = Vector3.new(0, floorRelY + 0.6, 0)
            neck = Vector3.new(0, floorRelY + 6.0, 0)
            headCenter = Vector3.new(0, floorRelY + 10.5, 0)

            local sitSway = math.sin(animTime * 2) * 0.15
            leftHand = pelvis + Vector3.new(-3.8, 1.8, 2.6 + sitSway)
            rightHand = pelvis + Vector3.new(3.8, 1.8, 2.6 + sitSway)
            leftFoot = pelvis + Vector3.new(-3.0, 0.1, 5.0)
            rightFoot = pelvis + Vector3.new(3.0, 0.1, 5.0)

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
            local targetCamY = (activeAnim == "lay_down") and 2.0 or ((activeAnim == "sit") and 4.5 or 14.0)
            Hum.CameraOffset = Vector3.new(0, targetCamY, 0)
        end
    end)
end)

-- ========================================================
-- 10.1. REALISTIC IRL ROLLING BALL & BOUNCE ENGINE (100% FE)
-- Player avatar stays safely inside the rolling sphere of blocks.
-- Rolling physics: Ball rolls forward as player moves forward (omega = v / R).
-- Bounce physics: Realistic squash-and-stretch bounce when jumping, falling, and landing.
-- ========================================================
local BallRotation = CFrame.new()
local WasAirborne = false
local LastFallVelocity = 0
local BounceElapsed = 10

TBall.MouseButton1Click:Connect(function()
    SWITCH_MODE("Ball")
    CC()
    if #CP == 0 then return end
    SET_CHARACTER_VISIBILITY(true) -- Player character stays inside the ball
    RESET_CAMERA()

    local ballRadius = 6.2
    BallRotation = CFrame.new()
    WasAirborne = false
    LastFallVelocity = 0
    BounceElapsed = 10

    AC = R.RenderStepped:Connect(function(dt)
        local C = L.Character
        local Root = C and C:FindFirstChild("HumanoidRootPart")
        local Hum = C and C:FindFirstChildOfClass("Humanoid")
        if not Root or not Hum then return end

        SET_CHARACTER_VISIBILITY(true)

        local totalBlocks = #CP
        if totalBlocks == 0 then return end

        local vel = Root.AssemblyLinearVelocity
        local horizVel = Vector3.new(vel.X, 0, vel.Z)
        local horizSpeed = horizVel.Magnitude
        local vertVel = vel.Y

        -- 1. ACCURATE IRL ROLLING PHYSICS:
        -- As player moves forward, the sphere rotates forward around the transverse horizontal axis
        if horizSpeed > 0.3 then
            local moveDir = horizVel.Unit
            local rollAxis = Vector3.new(moveDir.Z, 0, -moveDir.X)
            local rollAngle = (horizSpeed * dt) / ballRadius
            BallRotation = CFrame.fromAxisAngle(rollAxis, rollAngle) * BallRotation
        end

        -- 2. ACCURATE BOUNCE & SQUASH-AND-STRETCH PHYSICS:
        local floorDist = GetFloorDistance(Root.Position, C)
        local feetRelY = floorDist - Root.Position.Y
        local isGrounded = math.abs(feetRelY - (-3.1)) < 0.8 and math.abs(vertVel) < 2.0

        if vertVel < -5 then
            LastFallVelocity = math.abs(vertVel)
            WasAirborne = true
        elseif vertVel > 5 then
            WasAirborne = true
        end

        -- Trigger elastic impact bounce upon landing from fall/jump
        if isGrounded and WasAirborne then
            WasAirborne = false
            BounceElapsed = 0
        end

        BounceElapsed = BounceElapsed + dt

        -- Calculate squash & stretch factors:
        local scaleY = 1.0
        local scaleXZ = 1.0

        if BounceElapsed < 1.2 then
            -- Damped elastic rebound oscillation
            local impactEnergy = math.clamp(LastFallVelocity / 32, 0.15, 0.45)
            local decay = math.exp(-BounceElapsed * 5.5)
            local osc = math.cos(BounceElapsed * 20) * decay * impactEnergy
            scaleY = math.clamp(1.0 - osc, 0.65, 1.4)
            scaleXZ = math.clamp(1.0 + (osc * 0.5), 0.75, 1.25)
        elseif not isGrounded then
            -- Airborne aerodynamic stretch in direction of motion
            if vertVel > 3 then
                local stretch = math.clamp(vertVel / 70, 0, 0.22)
                scaleY = 1.0 + stretch
                scaleXZ = 1.0 / math.sqrt(scaleY)
            elseif vertVel < -3 then
                local stretch = math.clamp(math.abs(vertVel) / 80, 0, 0.25)
                scaleY = 1.0 + stretch
                scaleXZ = 1.0 / math.sqrt(scaleY)
            end
        end

        -- Ball center surrounds player avatar inside
        local ballCenter = Root.Position + Vector3.new(0, 0.2, 0)
        local lerpSpeed = math.clamp(BlockSpeed / 100, 0.4, 1.0)

        -- 3. FIBONACCI SPHERICAL DISTRIBUTION WITH ROTATION & SQUASH:
        for i, PRT in ipairs(CP) do
            if PRT and PRT.Parent then
                local phi = math.acos(1 - 2 * (i - 0.5) / totalBlocks)
                local theta = math.pi * (1 + math.sqrt(5)) * i

                local unscaled = Vector3.new(
                    math.sin(phi) * math.cos(theta) * ballRadius * scaleXZ,
                    math.cos(phi) * ballRadius * scaleY,
                    math.sin(phi) * math.sin(theta) * ballRadius * scaleXZ
                )

                local rotatedPoint = BallRotation:VectorToWorldSpace(unscaled)
                local targetCF = CFrame.new(ballCenter + rotatedPoint)
                UpdateFEPart(PRT, targetCF, lerpSpeed)
            end
        end
    end)
end)

-- ========================================================
-- 10.2. INTERACTIVE DOORS ENGINE (100% FE)
-- Toggle button grants "Place Door" tool in inventory.
-- Clicking places 1 block at target location acting like a swinging door.
-- Automatically opens when a player walks towards or pushes it!
-- Automatically swings closed when no player is pushing it.
-- Turning toggle off cleans up tool and returns door blocks to orbit.
-- ========================================================
local IsDoorsActive = false
local DoorTool = nil
local ActiveDoors = {} -- List of door entries: { block, closedCF, currentAngle, targetAngle, width, lastPushTime }
local DoorHeartbeat = nil

local function CleanupDoors()
    if DoorTool and DoorTool.Parent then
        pcall(function() DoorTool:Destroy() end)
    end
    DoorTool = nil

    local bp = L:FindFirstChildOfClass("Backpack")
    if bp then
        for _, t in ipairs(bp:GetChildren()) do
            if t.Name == "Place Door" then pcall(function() t:Destroy() end) end
        end
    end
    if L.Character then
        for _, t in ipairs(L.Character:GetChildren()) do
            if t.Name == "Place Door" then pcall(function() t:Destroy() end) end
        end
    end

    if DoorHeartbeat then
        DoorHeartbeat:Disconnect()
        DoorHeartbeat = nil
    end

    ActiveDoors = {}
end

local function UpdateActiveDoors(dt)
    for i = #ActiveDoors, 1, -1 do
        local door = ActiveDoors[i]
        if not door.block or not door.block.Parent then
            table.remove(ActiveDoors, i)
        else
            local isBeingPushed = false
            local pushSide = 1

            for _, p in ipairs(P:GetPlayers()) do
                local char = p.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if root then
                    local doorPos = door.closedCF.Position
                    local toDoor = doorPos - root.Position
                    local dist = toDoor.Magnitude

                    if dist < 7.5 then
                        local vel = root.AssemblyLinearVelocity
                        local horizVel = Vector3.new(vel.X, 0, vel.Z)
                        local isWalkingNear = dist < 4.8
                        local isMovingTowards = horizVel.Magnitude > 0.8 and horizVel.Unit:Dot(toDoor.Unit) > 0.35

                        if isWalkingNear or isMovingTowards then
                            isBeingPushed = true
                            door.lastPushTime = os.clock()

                            local localP = door.closedCF:PointToObjectSpace(root.Position)
                            if localP.Z < 0 then
                                pushSide = 1
                            else
                                pushSide = -1
                            end
                            break
                        end
                    end
                end
            end

            -- If player is pushing / walking towards: swing open up to ~82 degrees
            -- If not pushing: smoothly swing closed
            if isBeingPushed or (os.clock() - door.lastPushTime < 1.2) then
                door.targetAngle = math.rad(82) * pushSide
            else
                door.targetAngle = 0
            end

            -- Smooth spring damping
            local delta = door.targetAngle - door.currentAngle
            door.currentAngle = door.currentAngle + (delta * math.clamp(dt * 7.5, 0.05, 1.0))

            -- Pivot around hinge on the left edge
            local hingeCF = door.closedCF * CFrame.new(-door.width / 2, 0, 0)
            local currentDoorCF = hingeCF * CFrame.Angles(0, door.currentAngle, 0) * CFrame.new(door.width / 2, 0, 0)

            door.block.CanCollide = false
            door.block.Anchored = false
            UpdateFEPart(door.block, currentDoorCF, 0.85)
        end
    end
end

TDoors.MouseButton1Click:Connect(function()
    IsDoorsActive = not IsDoorsActive

    if IsDoorsActive then
        TDoors.Text = "Doors: ON"
        TDoors.BackgroundColor3 = Color3.fromRGB(40, 160, 90)

        local bp = L:FindFirstChildOfClass("Backpack")
        if bp then
            DoorTool = Instance.new("Tool")
            DoorTool.Name = "Place Door"
            DoorTool.RequiresHandle = false
            DoorTool.CanBeDropped = false
            DoorTool.ToolTip = "Click to place an interactive swinging door block!"

            DoorTool.Activated:Connect(function()
                if #CP == 0 then return end

                local doorBlock = nil
                local usedBlocks = {}
                for _, d in ipairs(ActiveDoors) do usedBlocks[d.block] = true end

                for i = #CP, 1, -1 do
                    if not usedBlocks[CP[i]] then
                        doorBlock = CP[i]
                        break
                    end
                end

                if not doorBlock then
                    doorBlock = CP[#CP]
                end

                local hitPos = M.Hit.Position
                local root = L.Character and L.Character:FindFirstChild("HumanoidRootPart")
                local rootPos = root and root.Position or hitPos

                local lookDir = Vector3.new(hitPos.X - rootPos.X, 0, hitPos.Z - rootPos.Z)
                if lookDir.Magnitude < 0.1 then lookDir = Vector3.new(0, 0, 1) else lookDir = lookDir.Unit end

                local doorCFrame = CFrame.lookAt(hitPos + Vector3.new(0, 3.5, 0), hitPos + Vector3.new(0, 3.5, 0) + lookDir)

                DispatchPaintToolRemote(doorBlock, Color3.fromRGB(160, 95, 45))

                table.insert(ActiveDoors, {
                    block = doorBlock,
                    closedCF = doorCFrame,
                    currentAngle = 0,
                    targetAngle = 0,
                    width = 4.2,
                    lastPushTime = 0
                })
            end)

            DoorTool.Parent = bp
        end

        if not DoorHeartbeat then
            DoorHeartbeat = R.RenderStepped:Connect(function(dt)
                if IsDoorsActive then
                    UpdateActiveDoors(dt)
                end
            end)
        end
    else
        TDoors.Text = "Doors: OFF"
        TDoors.BackgroundColor3 = Color3.fromRGB(180, 110, 45)
        CleanupDoors()
    end
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
 Active connections
local AC               = nil   -- current orbit RenderStepped
local StagingConn      = nil   -- staging hold loop
local BlasterConn      = nil
local FlyConn          = nil

-- Mode state
local CurrentMode      = "None"
local OrbitActive      = true
local Flying           = false
local CurrentWeapon    = "None"
local IsSlashing       = false
local IsHollowActive   = false
local IsRainbowActive  = false
local IsPaintActive    = false
local LastShotTime     = 0

-- Stickman / Shark animation state
local StickAnim        = "walk"  -- walk | wave | sit | lay_down
local SharkBite        = false
local SharkPetOrbit    = false
local SharkPetRadius   = 16

-- Door tool state
local DoorActive       = false
local DoorPlacedPart   = nil
local DoorAnchorPart   = nil
local DoorProxConn     = nil
local DoorPreviewConn  = nil

-- Block claiming toggles
local ClaimAllOn       = false
local TapClaimOn       = false

-- Speed / config
local FlySpeed         = 50
local BlockSpeed       = 60
local RainbowSpeed     = 2
local ToggleKey        = Enum.KeyCode.RightControl
local STAGE_ALT        = 10     -- staging orbit altitude above player

-- Color
local SelColor = Color3.fromRGB(0, 170, 255)
local R_Val, G_Val, B_Val = 0, 170, 255

-- ============================================================
-- [2] FE PHYSICS CORE (STABILIZED - NO WIGGLE, NO ROTATION)
--     All part movement uses velocity (spring-damper).
--     This replicates to the server via network ownership.
--     Tuned PD + anti-wiggle deadband & zero angular drift.
-- ============================================================
local K_SPRING     = 18     -- Responsive tracking without overshoot
local K_DAMP       = 1.5    -- Critical damping prevents oscillation
local MAX_VEL      = 80     -- Hard cap prevents teleport artifacts
local K_ROT        = 12     -- Angular alignment spring
local K_ROT_DAMP   = 1.2    -- Angular damping prevents rotational wobble

pcall(function()
    settings().Physics.AllowSleep = false
    settings().Physics.PhysicsEnvironmentalThrottle =
        Enum.EnviromentalPhysicsThrottle.Disabled
end)

local function BoostSimRadius()
    pcall(function()
        sethiddenproperty(L, "SimulationRadius",        1e6)
        sethiddenproperty(L, "MaximumSimulationRadius", 1e6)
    end)
end
BoostSimRadius()
R.Stepped:Connect(BoostSimRadius)

-- Claim network ownership of a part via the touch-interest trick
local function ClaimPart(part)
    if not part or not part:IsA("BasePart") then return end
    part.CanCollide = false
    part.Anchored   = false

    -- Keep CanQuery and CanTouch TRUE so building tools, btools, and draggers can select and build!
    pcall(function()
        part.CanQuery = true
        part.CanTouch = true
    end)

    -- Break world welds
    for _, c in ipairs(part:GetChildren()) do
        if c:IsA("Weld") or c:IsA("WeldConstraint") or c:IsA("ManualWeld")
        or c:IsA("Motor6D") or c:IsA("Snap") then
            pcall(function() c:Destroy() end)
        end
    end

    -- Touch-interest trick to claim network ownership on most executors
    local hrp = L.Character and L.Character:FindFirstChild("HumanoidRootPart")
    if hrp then
        pcall(function() firetouchinterest(part, hrp, 0) end)
        pcall(function() firetouchinterest(part, hrp, 1) end)
    end
    pcall(function() part:SetNetworkOwner(L) end)
    pcall(function()
        if sethiddenproperty then
            sethiddenproperty(part, "NetworkIsSleeping", false)
        end
    end)
end

--[[
    DrivePartFE — 100% FilteringEnabled (FE) Replicated Physics Engine
    • REPLICATED TO SERVER & ALL PLAYERS:
      Uses AssemblyLinearVelocity & AssemblyAngularVelocity with client network ownership.
      Never uses client-only CFrame so blocks are fully visible to other players and the server.
    • BUILDABLE & DRAGGABLE:
      CanQuery and CanTouch are kept TRUE so F3X, BTools, Draggers, and building tools
      can freely click, select, drag, weld, and build on the blocks while orbiting.
    • NO WIGGLING OR JITTERING:
      Uses tuned critical PD velocity with gravity-lift compensation to eliminate vertical bounce.
    • ZERO ROTATION & STILL BLOCKS:
      Actively damps all angular velocity to Vector3.zero and applies restorative upright torque
      so blocks stay completely still and face upright without tumbling or spinning.
--]]
local function DrivePartFE(part, targetCF, dt, useRot)
    if not part or not part.Parent or part.Anchored then return end

    -- Keep CanQuery and CanTouch TRUE so players and building tools can click, drag, and build!
    pcall(function()
        if not part.CanQuery then part.CanQuery = true end
        if not part.CanTouch then part.CanTouch = true end
    end)

    -- Keep CanCollide false while orbiting so blocks don't fling each other
    if part.CanCollide then part.CanCollide = false end

    pcall(function()
        if sethiddenproperty then
            sethiddenproperty(part, "NetworkIsSleeping", false)
        end
    end)

    local pos  = part.Position
    local tPos = targetCF.Position
    local vel  = part.AssemblyLinearVelocity
    local err  = tPos - pos
    local dist = err.Magnitude

    -- Safe dt clamp for stable physics integration
    local safeDt = math.clamp(dt or 0.016, 0.008, 0.033)

    -- Smooth proportional-derivative velocity: reaches target with zero overshoot/wiggle
    local K_P = 24
    local K_D = 2.0
    local desired = (err * K_P) - (vel * K_D)

    -- Gravity compensation: counteracts gravity pull so blocks never sag or bounce vertically
    local antiGravity = Vector3.new(0, workspace.Gravity * safeDt * 1.1, 0)
    local finalVel = desired + antiGravity

    -- Clamp maximum speed to avoid physics explosion
    local spd = finalVel.Magnitude
    if spd > 110 then
        finalVel = finalVel * (110 / spd)
    end

    -- Settle cleanly when within proximity
    if dist < 0.04 and vel.Magnitude < 0.3 then
        part.AssemblyLinearVelocity = antiGravity
    else
        part.AssemblyLinearVelocity = finalVel
    end

    -- ZERO ROTATION & STEADY UP-RIGHT ALIGNMENT
    if useRot then
        -- Directional orientation for snake or arrow formations
        local relRot = part.CFrame:ToObjectSpace(targetCF)
        local rx, ry, rz = relRot:ToEulerAnglesXYZ()
        local angVel = part.AssemblyAngularVelocity
        part.AssemblyAngularVelocity = (Vector3.new(rx, ry, rz) * 16) - (angVel * 1.6)
    else
        -- Blocks STAY STILL: active upright restoration eliminates any spin, tumble, or rotation!
        local rx, ry, rz = part.CFrame:ToEulerAnglesXYZ()
        local angVel = part.AssemblyAngularVelocity
        if math.abs(rx) > 0.015 or math.abs(ry) > 0.015 or math.abs(rz) > 0.015 then
            -- Gently steer the block back upright so it stays still without spinning
            part.AssemblyAngularVelocity = (Vector3.new(-rx, -ry, -rz) * 14) - (angVel * 1.4)
        else
            -- Locked still: zero angular velocity
            part.AssemblyAngularVelocity = Vector3.zero
        end
    end
end

-- ============================================================
-- [3] PART VALIDATION  (only accept real FE unanchored parts)
-- ============================================================
local function VLD(o)
    if not o or not o.Parent then return false end
    if not o:IsA("BasePart") or o:IsA("Terrain") then return false end
    if o.Anchored then return false end
    if not o:IsDescendantOf(workspace) then return false end
    if o:IsDescendantOf(Cam) then return false end
    local model = o:FindFirstAncestorOfClass("Model")
    if model and model:FindFirstChildOfClass("Humanoid") then return false end
    for _, pl in ipairs(P:GetPlayers()) do
        if pl.Character and o:IsDescendantOf(pl.Character) then return false end
    end
    if o.Name == "Handle" and o.Parent and o.Parent:IsA("Accessory") then
        return false
    end
    return true
end

-- ============================================================
-- [4] GUI — Main frame, header, scrolling buttons
-- ============================================================
local PG = L:WaitForChild("PlayerGui")
if PG:FindFirstChild("SofiScriptHub") then
    PG.SofiScriptHub:Destroy()
end

local S = Instance.new("ScreenGui")
S.Name, S.ResetOnSpawn, S.Parent = "SofiScriptHub", false, PG

-- Floating delta ball (minimize button)
local BallBtn = Instance.new("ImageButton", S)
BallBtn.Size                = UDim2.new(0, 42, 0, 42)
BallBtn.Position            = UDim2.new(0, 20, 0.4, 0)
BallBtn.BackgroundColor3    = Color3.fromRGB(30, 25, 45)
BallBtn.BorderSizePixel     = 0
BallBtn.Active              = true
BallBtn.Draggable           = true
BallBtn.Visible             = false
Instance.new("UICorner", BallBtn).CornerRadius = UDim.new(1, 0)
local bst = Instance.new("UIStroke", BallBtn)
bst.Thickness, bst.Color = 2, Color3.fromRGB(160, 80, 255)
local bic = Instance.new("TextLabel", BallBtn)
bic.Size, bic.BackgroundTransparency = UDim2.new(1,0,1,0), 1
bic.Text, bic.TextColor3 = "Δ", Color3.fromRGB(220,180,255)
bic.TextSize, bic.Font   = 20, Enum.Font.GothamBold

-- Main frame
local F = Instance.new("Frame", S)
F.Name               = "Main"
F.Size               = UDim2.new(0, 200, 0, 285)
F.Position           = UDim2.new(0, 20, 0, 40)
F.BackgroundColor3   = Color3.fromRGB(20, 20, 26)
F.BorderSizePixel    = 0
F.Active, F.Draggable, F.ClipsDescendants = true, true, true
Instance.new("UICorner", F).CornerRadius = UDim.new(0, 8)
local fst = Instance.new("UIStroke", F)
fst.Thickness, fst.Color = 1.2, Color3.fromRGB(80, 70, 120)

-- Header
local Hdr = Instance.new("Frame", F)
Hdr.Size, Hdr.BackgroundColor3, Hdr.BorderSizePixel =
    UDim2.new(1,0,0,28), Color3.fromRGB(28,28,38), 0
Instance.new("UICorner", Hdr).CornerRadius = UDim.new(0, 8)

local TitleLbl = Instance.new("TextLabel", Hdr)
TitleLbl.Size              = UDim2.new(1,-70,1,0)
TitleLbl.Position          = UDim2.new(0,8,0,0)
TitleLbl.BackgroundTransparency = 1
TitleLbl.TextColor3        = Color3.fromRGB(240,240,255)
TitleLbl.Text              = "B.R.I.C.K.S v2 (Fixed)"
TitleLbl.TextSize          = 9
TitleLbl.Font              = Enum.Font.GothamBold
TitleLbl.TextXAlignment    = Enum.TextXAlignment.Left

local function MakeHdrBtn(x, txt, col)
    local b = Instance.new("TextButton", Hdr)
    b.Size, b.Position = UDim2.new(0,22,0,22), UDim2.new(1,x,0,3)
    b.BackgroundColor3 = col
    b.TextColor3       = Color3.new(1,1,1)
    b.Text, b.TextSize, b.Font = txt, 11, Enum.Font.GothamBold
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
    return b
end
local MinBtn   = MakeHdrBtn(-50, "—", Color3.fromRGB(70,50,140))
local CloseBtn = MakeHdrBtn(-25, "X", Color3.fromRGB(200,45,45))

MinBtn.MouseButton1Click:Connect(function()
    F.Visible = false; BallBtn.Visible = true
    BallBtn.Position = UDim2.new(
        F.Position.X.Scale, F.Position.X.Offset,
        F.Position.Y.Scale, F.Position.Y.Offset)
end)
BallBtn.MouseButton1Click:Connect(function()
    BallBtn.Visible = false; F.Visible = true
end)
CloseBtn.MouseButton1Click:Connect(function()
    if S then S:Destroy() end
end)

-- Scrolling content frame
local SF = Instance.new("ScrollingFrame", F)
SF.Size              = UDim2.new(1,-4,1,-32)
SF.Position          = UDim2.new(0,2,0,30)
SF.BackgroundTransparency = 1
SF.BorderSizePixel   = 0
SF.CanvasSize        = UDim2.new(0,0,0,0)
SF.ScrollBarThickness = 3
SF.ScrollBarImageColor3 = Color3.fromRGB(140,120,210)
SF.AutomaticCanvasSize  = Enum.AutomaticSize.Y

local UIL = Instance.new("UIListLayout", SF)
UIL.SortOrder = Enum.SortOrder.LayoutOrder
UIL.Padding   = UDim.new(0, 4)

local btnOrder = 0
local function BTN(txt, col)
    btnOrder = btnOrder + 1
    local b = Instance.new("TextButton", SF)
    b.Size            = UDim2.new(1,-4,0,24)
    b.BackgroundColor3 = col
    b.TextColor3      = Color3.new(1,1,1)
    b.Text, b.TextSize, b.Font = txt, 9, Enum.Font.GothamMedium
    b.LayoutOrder     = btnOrder
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
    return b
end

-- Stats Panel
local StatsF = Instance.new("Frame", SF)
StatsF.Size             = UDim2.new(1,-4,0,80)
StatsF.BackgroundColor3 = Color3.fromRGB(28,28,36)
StatsF.BorderSizePixel  = 0
StatsF.LayoutOrder      = btnOrder
btnOrder = btnOrder + 1
Instance.new("UICorner", StatsF).CornerRadius = UDim.new(0, 5)

local function StatLbl(y, txt, col)
    local l = Instance.new("TextLabel", StatsF)
    l.Size              = UDim2.new(0.96,0,0,13)
    l.Position          = UDim2.new(0.02,0,0,y)
    l.BackgroundTransparency = 1
    l.TextColor3        = col or Color3.fromRGB(190,205,235)
    l.TextSize, l.Font  = 8.5, Enum.Font.GothamMedium
    l.TextXAlignment    = Enum.TextXAlignment.Left
    l.Text, l.TextWrapped = txt, true
    return l
end

local sLbl_Ping   = StatLbl(2,  "Ping: --")
local sLbl_Blks   = StatLbl(16, "Claimed: 0 blocks")
local sLbl_Orbit  = StatLbl(30, "Orbit: ON  |  Mode: None", Color3.fromRGB(80,255,140))
local sLbl_Sel    = StatLbl(44, "Selection: OFF", Color3.fromRGB(200,200,255))
local sLbl_Plrs   = StatLbl(62, "Players: 0")

-- Block Claiming
local BtnClaimAll  = BTN("⬜ Claim All Blocks: OFF",  Color3.fromRGB(30,110,175))
local BtnTapClaim  = BTN("👆 Tap-to-Claim: OFF",       Color3.fromRGB(55,55,90))
local BtnRelease   = BTN("🗑 Release All Claimed",      Color3.fromRGB(110,35,35))

-- Orbit Master Toggle
local BtnOrbitToggle = BTN("⏸ Orbit: ON",              Color3.fromRGB(30,155,70))

-- Settings
local SetF = Instance.new("Frame", SF)
SetF.Size             = UDim2.new(1,-4,0,110)
SetF.BackgroundColor3 = Color3.fromRGB(28,28,36)
SetF.BorderSizePixel  = 0
SetF.LayoutOrder      = btnOrder
btnOrder = btnOrder + 1
Instance.new("UICorner", SetF).CornerRadius = UDim.new(0, 5)

local function SetRow(y, lbl, defVal)
    local la = Instance.new("TextLabel", SetF)
    la.Size              = UDim2.new(0.60,0,0,18)
    la.Position          = UDim2.new(0.04,0,0,y)
    la.BackgroundTransparency = 1
    la.TextColor3        = Color3.fromRGB(180,195,225)
    la.Text, la.TextSize, la.Font = lbl, 8.5, Enum.Font.GothamMedium
    la.TextXAlignment    = Enum.TextXAlignment.Left

    local bx = Instance.new("TextBox", SetF)
    bx.Size              = UDim2.new(0.30,0,0,18)
    bx.Position          = UDim2.new(0.67,0,0,y)
    bx.BackgroundColor3  = Color3.fromRGB(38,38,50)
    bx.TextColor3        = Color3.new(1,1,1)
    bx.Text, bx.TextSize, bx.Font = tostring(defVal), 8.5, Enum.Font.GothamMedium
    Instance.new("UICorner", bx).CornerRadius = UDim.new(0, 4)
    return bx
end

local SetTitle = Instance.new("TextLabel", SetF)
SetTitle.Size, SetTitle.BackgroundTransparency = UDim2.new(1,0,0,16), 1
SetTitle.TextColor3, SetTitle.TextSize, SetTitle.Font =
    Color3.fromRGB(240,240,255), 9, Enum.Font.GothamBold
SetTitle.Text = "Settings"

local BoxFly      = SetRow(18,  "Fly Speed:",       FlySpeed)
local BoxBlock    = SetRow(38,  "Block Speed:",      BlockSpeed)
local BoxRainbow  = SetRow(58,  "Rainbow Speed:",    RainbowSpeed)
local BoxKey      = SetRow(78,  "GUI Toggle Key:",   "RCtrl")

BoxKey.Text = ToggleKey.Name
BoxFly.FocusLost:Connect(function()
    FlySpeed = tonumber(BoxFly.Text) or FlySpeed
    BoxFly.Text = tostring(FlySpeed)
end)
BoxBlock.FocusLost:Connect(function()
    BlockSpeed = tonumber(BoxBlock.Text) or BlockSpeed
    BoxBlock.Text = tostring(BlockSpeed)
end)
BoxRainbow.FocusLost:Connect(function()
    RainbowSpeed = tonumber(BoxRainbow.Text) or RainbowSpeed
    BoxRainbow.Text = tostring(RainbowSpeed)
end)

-- RGB Color Picker
local ColorF = Instance.new("Frame", SF)
ColorF.Size             = UDim2.new(1,-4,0,52)
ColorF.BackgroundColor3 = Color3.fromRGB(28,28,36)
ColorF.BorderSizePixel  = 0
ColorF.LayoutOrder      = btnOrder
btnOrder = btnOrder + 1
Instance.new("UICorner", ColorF).CornerRadius = UDim.new(0, 5)

local ColorTitle = Instance.new("TextLabel", ColorF)
ColorTitle.Size, ColorTitle.BackgroundTransparency = UDim2.new(1,0,0,14), 1
ColorTitle.TextColor3, ColorTitle.TextSize, ColorTitle.Font =
    Color3.new(1,1,1), 9, Enum.Font.GothamBold
ColorTitle.Text = "RGB Color"

local ColorPrev = Instance.new("Frame", ColorF)
ColorPrev.Size     = UDim2.new(0,26,0,22)
ColorPrev.Position = UDim2.new(1,-32,0,22)
ColorPrev.BackgroundColor3 = SelColor
Instance.new("UICorner", ColorPrev).CornerRadius = UDim.new(0, 4)

local function RGBBox(xOff, def, col)
    local b = Instance.new("TextBox", ColorF)
    b.Size     = UDim2.new(0,34,0,22)
    b.Position = UDim2.new(0,xOff,0,22)
    b.BackgroundColor3 = Color3.fromRGB(38,38,48)
    b.TextColor3 = col
    b.Text, b.TextSize, b.Font = tostring(def), 9, Enum.Font.GothamMedium
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
    return b
end
local RBox = RGBBox(6,   R_Val, Color3.fromRGB(255,110,110))
local GBox = RGBBox(46,  G_Val, Color3.fromRGB(110,255,110))
local BBox = RGBBox(86,  B_Val, Color3.fromRGB(120,170,255))

local function UpdateRGB()
    local r = math.clamp(tonumber(RBox.Text) or 0, 0, 255)
    local g = math.clamp(tonumber(GBox.Text) or 0, 0, 255)
    local b = math.clamp(tonumber(BBox.Text) or 0, 0, 255)
    SelColor = Color3.fromRGB(r, g, b)
    ColorPrev.BackgroundColor3 = SelColor
end
RBox:GetPropertyChangedSignal("Text"):Connect(UpdateRGB)
GBox:GetPropertyChangedSignal("Text"):Connect(UpdateRGB)
BBox:GetPropertyChangedSignal("Text"):Connect(UpdateRGB)

-- Target input
local TargetF = Instance.new("Frame", SF)
TargetF.Size, TargetF.BackgroundTransparency = UDim2.new(1,-4,0,24), 1
TargetF.LayoutOrder = btnOrder; btnOrder = btnOrder + 1

local WI = Instance.new("TextBox", TargetF)
WI.Size, WI.BackgroundColor3 = UDim2.new(1,0,1,0), Color3.fromRGB(36,36,46)
WI.TextColor3, WI.TextSize, WI.Font = Color3.new(1,1,1), 8.5, Enum.Font.GothamMedium
WI.Text, WI.PlaceholderText = "", "Target Player (blank = self)"
Instance.new("UICorner", WI).CornerRadius = UDim.new(0, 4)

-- Mode buttons
local BtnHollowPurple  = BTN("Hollow Purple (Gojo FE)",    Color3.fromRGB(150,40,235))
local BtnRainbow       = BTN("Fast Rainbow: OFF",           Color3.fromRGB(130,45,175))
local BtnPaint         = BTN("Paint Blocks: OFF",           Color3.fromRGB(140,50,50))
local BtnChain         = BTN("Chain Trail (Physics)",       Color3.fromRGB(90,140,210))
local BtnSnake         = BTN("Snake (Undulation)",          Color3.fromRGB(50,160,100))
local BtnShark         = BTN("Shark Morph",                 Color3.fromRGB(45,100,180))
local BtnStickman      = BTN("Animated Stickman",           Color3.fromRGB(170,60,200))
local BtnBall          = BTN("Ball Orbit (Physics)",        Color3.fromRGB(200,120,30))
local BtnDoor          = BTN("Door Tool: OFF",              Color3.fromRGB(80,80,140))
local BtnRifle         = BTN("Weapon: Rifle",               Color3.fromRGB(60,130,200))
local BtnSword         = BTN("Weapon: Sword",               Color3.fromRGB(200,110,45))
local BtnFly           = BTN("Toggle Fly",                  Color3.fromRGB(45,150,210))
local BtnFollow        = BTN("Follow Target",               Color3.fromRGB(35,170,110))
local BtnBlaster       = BTN("Brick Blaster",               Color3.fromRGB(210,45,75))
local BtnHelix         = BTN("DNA Helix",                   Color3.fromRGB(75,170,210))
local BtnTornado       = BTN("Tornado Launch",              Color3.fromRGB(190,110,35))
local BtnDraw          = BTN("Draw Mode",                   Color3.fromRGB(35,110,210))
local BtnVortex        = BTN("Server Vortex",               Color3.fromRGB(170,75,210))
local BtnRain          = BTN("Server Rain",                 Color3.fromRGB(60,120,210))
local BtnOrbit         = BTN("Sphere Orbit",                Color3.fromRGB(130,55,160))
local BtnShield        = BTN("Shield Target",               Color3.fromRGB(55,160,130))
local BtnFling         = BTN("Fling Target",                Color3.fromRGB(210,80,35))
local BtnStop          = BTN("Stop / Stage Blocks",         Color3.fromRGB(170,45,45))
local BtnReset         = BTN("Reset Character",             Color3.fromRGB(140,35,35))
local BtnRejoin        = BTN("Rejoin Server",               Color3.fromRGB(80,80,95))

-- ============================================================
-- [5] ANIMATIONS SUB-PANEL  (Stickman + Shark)
-- ============================================================
local AnimPanel = Instance.new("Frame", S)
AnimPanel.Name              = "AnimPanel"
AnimPanel.Size              = UDim2.new(0,158,0,170)
AnimPanel.Position          = UDim2.new(0,228,0,40)
AnimPanel.BackgroundColor3  = Color3.fromRGB(20,20,28)
AnimPanel.BorderSizePixel   = 0
AnimPanel.Visible           = false
AnimPanel.Active            = true
AnimPanel.Draggable         = true
Instance.new("UICorner", AnimPanel).CornerRadius = UDim.new(0, 8)
local ast = Instance.new("UIStroke", AnimPanel)
ast.Color, ast.Thickness = Color3.fromRGB(130,80,220), 1.2

local AnimHdr = Instance.new("Frame", AnimPanel)
AnimHdr.Size, AnimHdr.BackgroundColor3, AnimHdr.BorderSizePixel =
    UDim2.new(1,0,0,26), Color3.fromRGB(34,30,48), 0
Instance.new("UICorner", AnimHdr).CornerRadius = UDim.new(0, 8)

local AnimTitle = Instance.new("TextLabel", AnimHdr)
AnimTitle.Size, AnimTitle.Position, AnimTitle.BackgroundTransparency = 
    UDim2.new(1,-4,1,0), UDim2.new(0,8,0,0), 1
AnimTitle.TextColor3, AnimTitle.TextSize, AnimTitle.Font =
    Color3.fromRGB(240,225,255), 10, Enum.Font.GothamBold
AnimTitle.TextXAlignment, AnimTitle.Text = Enum.TextXAlignment.Left, "Animations"

local AnimContent = Instance.new("Frame", AnimPanel)
AnimContent.Size, AnimContent.Position, AnimContent.BackgroundTransparency =
    UDim2.new(1,-12,1,-34), UDim2.new(0,6,0,30), 1

local function ABTN(parent, txt, col)
    local b = Instance.new("TextButton", parent)
    b.Size, b.BackgroundColor3 = UDim2.new(1,0,0,26), col
    b.TextColor3, b.TextSize, b.Font = Color3.new(1,1,1), 9, Enum.Font.GothamMedium
    b.Text = txt
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
    return b
end

-- Stickman buttons
local SBFrame = Instance.new("Frame", AnimContent)
SBFrame.Size, SBFrame.BackgroundTransparency, SBFrame.Visible =
    UDim2.new(1,0,1,0), 1, false
local sbl = Instance.new("UIListLayout", SBFrame)
sbl.Padding, sbl.SortOrder = UDim.new(0, 4), Enum.SortOrder.LayoutOrder

local BtnWave    = ABTN(SBFrame, "Wave: OFF",      Color3.fromRGB(60,50,95))
local BtnSit     = ABTN(SBFrame, "Sit: OFF",       Color3.fromRGB(50,75,110))
local BtnLayDown = ABTN(SBFrame, "Lay Down: OFF",  Color3.fromRGB(90,50,100))
local BtnStand   = ABTN(SBFrame, "Stand / Reset",  Color3.fromRGB(38,38,52))
BtnStand.TextColor3 = Color3.fromRGB(200,200,225)

-- Shark buttons
local ShFrame = Instance.new("Frame", AnimContent)
ShFrame.Size, ShFrame.BackgroundTransparency, ShFrame.Visible =
    UDim2.new(1,0,1,0), 1, false
local shl = Instance.new("UIListLayout", ShFrame)
shl.Padding, shl.SortOrder = UDim.new(0, 4), Enum.SortOrder.LayoutOrder

local BtnBite     = ABTN(ShFrame, "Bite: OFF",      Color3.fromRGB(150,40,40))
local BtnPetOrbit = ABTN(ShFrame, "Pet Orbit: OFF", Color3.fromRGB(40,110,160))

-- Stickman anim handlers
local function ResetStickBtns()
    StickAnim = "walk"
    BtnWave.Text,    BtnWave.BackgroundColor3    = "Wave: OFF",     Color3.fromRGB(60,50,95)
    BtnSit.Text,     BtnSit.BackgroundColor3     = "Sit: OFF",      Color3.fromRGB(50,75,110)
    BtnLayDown.Text, BtnLayDown.BackgroundColor3 = "Lay Down: OFF", Color3.fromRGB(90,50,100)
end

BtnWave.MouseButton1Click:Connect(function()
    StickAnim = (StickAnim == "wave") and "walk" or "wave"
    ResetStickBtns()
    if StickAnim == "wave" then
        BtnWave.Text, BtnWave.BackgroundColor3 = "Wave: ON", Color3.fromRGB(40,170,80)
    end
end)
BtnSit.MouseButton1Click:Connect(function()
    StickAnim = (StickAnim == "sit") and "walk" or "sit"
    ResetStickBtns()
    if StickAnim == "sit" then
        BtnSit.Text, BtnSit.BackgroundColor3 = "Sit: ON", Color3.fromRGB(40,140,210)
    end
end)
BtnLayDown.MouseButton1Click:Connect(function()
    StickAnim = (StickAnim == "lay_down") and "walk" or "lay_down"
    ResetStickBtns()
    if StickAnim == "lay_down" then
        BtnLayDown.Text, BtnLayDown.BackgroundColor3 =
            "Lay Down: ON", Color3.fromRGB(150,50,170)
    end
end)
BtnStand.MouseButton1Click:Connect(ResetStickBtns)

BtnBite.MouseButton1Click:Connect(function()
    SharkBite = not SharkBite
    BtnBite.Text = SharkBite and "Bite: ON" or "Bite: OFF"
    BtnBite.BackgroundColor3 =
        SharkBite and Color3.fromRGB(220,40,40) or Color3.fromRGB(150,40,40)
end)
BtnPetOrbit.MouseButton1Click:Connect(function()
    SharkPetOrbit = not SharkPetOrbit
    BtnPetOrbit.Text = SharkPetOrbit and "Pet Orbit: ON" or "Pet Orbit: OFF"
    BtnPetOrbit.BackgroundColor3 =
        SharkPetOrbit and Color3.fromRGB(35,180,120) or Color3.fromRGB(40,110,160)
end)

-- ============================================================
-- [6] HELPERS
-- ============================================================
local function GetFloorY(pos, ignoreChar)
    local rp = RaycastParams.new()
    pcall(function() rp.FilterType = Enum.RaycastFilterType.Exclude end)
    local fl = {}
    if ignoreChar then table.insert(fl, ignoreChar) end
    for _, p in ipairs(CP) do table.insert(fl, p) end
    pcall(function() rp.FilterDescendantsInstances = fl end)
    local ok, res = pcall(function()
        return workspace:Raycast(pos, Vector3.new(0,-80,0), rp)
    end)
    if ok and res then return res.Position.Y end
    return pos.Y - 14
end

local function GET_TARGET()
    local q = WI.Text:lower():gsub("%s+","")
    if q ~= "" then
        for _, pl in ipairs(P:GetPlayers()) do
            if pl.Name:lower():sub(1,#q) == q
            or pl.DisplayName:lower():sub(1,#q) == q then
                return pl
            end
        end
    end
    return L
end

local function GET_TARGET_POS()
    local t   = GET_TARGET()
    local hrp = t and t.Character and t.Character:FindFirstChild("HumanoidRootPart")
    if hrp then return hrp.Position, hrp end
    local mine = L.Character and L.Character:FindFirstChild("HumanoidRootPart")
    return mine and mine.Position or Vector3.zero, mine
end

-- ============================================================
-- [7] STEALTH PAINT TOOL
-- ============================================================
local function GetPaintTool()
    local char = L.Character
    local bp   = L:FindFirstChildOfClass("Backpack")
    local containers = {}
    if char then table.insert(containers, char) end
    if bp   then table.insert(containers, bp)   end

    for _, c in ipairs(containers) do
        for _, item in ipairs(c:GetChildren()) do
            if item:IsA("Tool") then
                local n = item.Name:lower()
                if n:find("paint") or n:find("color") or n:find("f3x")
                or n:find("btool") or n:find("draw")  or n:find("brush")
                or n:find("spray") or n:find("bucket") then
                    return item
                end
            end
        end
    end
    for _, c in ipairs(containers) do
        for _, item in ipairs(c:GetChildren()) do
            if item:IsA("Tool")
            and item:FindFirstChildWhichIsA("RemoteEvent", true) then
                return item
            end
        end
    end
    return nil
end

local function HideToolGrip(tool)
    if not tool then return end
    local h = tool:FindFirstChild("Handle")
    if h then
        h.Transparency = 1
        h.LocalTransparencyModifier = 1
        h.CanCollide = false
        local rg = h:FindFirstChild("RightGrip")
        if rg then pcall(function() rg:Destroy() end) end
    end
    local char = L.Character
    if char then
        local arm = char:FindFirstChild("Right Arm") or char:FindFirstChild("RightHand")
        if arm then
            local rg = arm:FindFirstChild("RightGrip")
            if rg then pcall(function() rg:Destroy() end) end
        end
    end
end

local function StealthEquip()
    local tool = GetPaintTool()
    local char = L.Character
    if not tool or not char then return tool end
    local hum  = char:FindFirstChildOfClass("Humanoid")
    if tool.Parent ~= char and hum then
        pcall(function() hum:EquipTool(tool) end)
    end
    HideToolGrip(tool)
    return tool
end

R.Stepped:Connect(function()
    if IsPaintActive or IsRainbowActive then
        local tool = GetPaintTool()
        if tool and tool.Parent == L.Character then
            HideToolGrip(tool)
        end
    end
end)

local SidesList = {
    Enum.NormalId.Front, Enum.NormalId.Right,
    Enum.NormalId.Back,  Enum.NormalId.Left,
    Enum.NormalId.Top,   Enum.NormalId.Bottom
}

local function FirePaint(part, color)
    if not part or not part.Parent then return end
    pcall(function() part.Color = color; part.BrickColor = BrickColor.new(color) end)

    local tool     = StealthEquip()
    if not tool then return end
    local brickCol = BrickColor.new(color)
    local pos      = part.Position

    for _, child in ipairs(tool:GetDescendants()) do
        if child:IsA("RemoteEvent") then
            pcall(function()
                child:FireServer(part, Enum.NormalId.Top, pos, "both 🤝", color, "smooth","")
            end)
            pcall(function()
                child:FireServer(part, Enum.NormalId.Top, pos, "both 🤝", brickCol, "smooth","")
            end)
            pcall(function() child:FireServer(part, color)    end)
            pcall(function() child:FireServer(part, brickCol) end)
            for _, side in ipairs(SidesList) do
                pcall(function()
                    child:FireServer(part, side, pos, "both 🤝", color, "smooth","")
                end)
            end
        elseif child:IsA("RemoteFunction") then
            pcall(function() child:InvokeServer(part, color) end)
        end
    end

    local sc = tool:FindFirstChild("SyncColor", true)
    if sc and sc:IsA("RemoteEvent") then
        pcall(function()
            sc:FireServer({{Part=part, Color=color, Face=Enum.NormalId.Front}})
        end)
    end

    for _, rName in ipairs({"PaintPart","ColorPart","SetColor","Paint","SuperPaint"}) do
        local r = RS:FindFirstChild(rName, true)
        if r and r:IsA("RemoteEvent") then
            pcall(function() r:FireServer(part, color)    end)
            pcall(function() r:FireServer(part, brickCol) end)
        end
    end
end

-- ============================================================
-- [8] BLOCK CLAIMING SYSTEM
-- ============================================================
local function IsInCP(part)
    for _, p in ipairs(CP) do if p == part then return true end end
    return false
end

local function AddPart(part)
    if not VLD(part) then return end
    if IsInCP(part) then return end
    ClaimPart(part)
    table.insert(CP, part)
end

local function RefreshCP()
    local kept = {}
    for _, p in ipairs(CP) do
        if p and p.Parent and VLD(p) then
            table.insert(kept, p)
        end
    end
    CP = kept

    if not ClaimAllOn then return end

    local existSet = {}
    for _, p in ipairs(CP) do existSet[p] = true end

    for _, fname in ipairs({"Bricks","Parts","Blocks"}) do
        local folder = workspace:FindFirstChild(fname)
        if folder then
            for _, o in ipairs(folder:GetChildren()) do
                if not existSet[o] and VLD(o) then
                    ClaimPart(o)
                    table.insert(CP, o)
                    existSet[o] = true
                end
            end
        end
    end

    for _, o in ipairs(workspace:GetDescendants()) do
        if not existSet[o] and VLD(o) then
            ClaimPart(o)
            table.insert(CP, o)
            existSet[o] = true
        end
    end
end

BtnClaimAll.MouseButton1Click:Connect(function()
    ClaimAllOn = not ClaimAllOn
    BtnClaimAll.Text = ClaimAllOn
        and "✅ Claim All: ON (Scanning)"
        or  "⬜ Claim All Blocks: OFF"
    BtnClaimAll.BackgroundColor3 = ClaimAllOn
        and Color3.fromRGB(30,175,75)
        or  Color3.fromRGB(30,110,175)
    if ClaimAllOn then RefreshCP() end
end)

BtnTapClaim.MouseButton1Click:Connect(function()
    TapClaimOn = not TapClaimOn
    BtnTapClaim.Text = TapClaimOn
        and "👆 Tap-to-Claim: ON"
        or  "👆 Tap-to-Claim: OFF"
    BtnTapClaim.BackgroundColor3 = TapClaimOn
        and Color3.fromRGB(75,155,75)
        or  Color3.fromRGB(55,55,90)
end)

BtnRelease.MouseButton1Click:Connect(function()
    for _, p in ipairs(CP) do
        if p and p.Parent then
            pcall(function() p:SetNetworkOwner(nil) end)
        end
    end
    CP = {}
    ClaimAllOn = false
    BtnClaimAll.Text            = "⬜ Claim All Blocks: OFF"
    BtnClaimAll.BackgroundColor3 = Color3.fromRGB(30,110,175)
end)

UIS.InputBegan:Connect(function(input, gpe)
    if gpe or not TapClaimOn then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        local hit = M.Target
        if hit and VLD(hit) then AddPart(hit) end
    end
end)

UIS.TouchTap:Connect(function(positions, gpe)
    if gpe or not TapClaimOn then return end
    if #positions > 0 then
        local ray = Cam:ScreenPointToRay(positions[1].X, positions[1].Y)
        local rp  = RaycastParams.new()
        pcall(function() rp.FilterType = Enum.RaycastFilterType.Exclude end)
        local ch = L.Character
        pcall(function() rp.FilterDescendantsInstances = ch and {ch} or {} end)
        local res = workspace:Raycast(ray.Origin, ray.Direction*250, rp)
        if res and VLD(res.Instance) then AddPart(res.Instance) end
    end
end)

-- ============================================================
-- [9] STAGING HOLD (STEADY ORBIT AROUND PLAYER)
-- ============================================================
local function HoldInStaging()
    if StagingConn then StagingConn:Disconnect(); StagingConn = nil end
    StagingConn = R.RenderStepped:Connect(function(dt)
        if OrbitActive and CurrentMode ~= "None" then
            if StagingConn then StagingConn:Disconnect(); StagingConn = nil end
            return
        end
        local root = L.Character and L.Character:FindFirstChild("HumanoidRootPart")
        if not root then return end
        local total = math.max(1, #CP)
        for i, part in ipairs(CP) do
            if part and part.Parent then
                local ang = (i/total)*math.pi*2 + os.clock()*0.25
                local r   = 6 + math.floor(i/12)*2.5
                local tPos = root.Position + Vector3.new(
                    math.cos(ang)*r,
                    STAGE_ALT + (i%3)*1.5,
                    math.sin(ang)*r
                )
                DrivePartFE(part, CFrame.new(tPos), dt, false)
            end
        end
    end)
end

-- ============================================================
-- [10] MODE SWITCH & STOP
-- ============================================================
local function SWITCH_MODE(name)
    if AC         then AC:Disconnect();         AC = nil         end
    if BlasterConn then BlasterConn:Disconnect(); BlasterConn = nil end
    if StagingConn then StagingConn:Disconnect(); StagingConn = nil end

    BlasterConn   = nil
    IsHollowActive = false
    IsSlashing    = false
    CurrentWeapon = "None"

    ResetStickBtns()
    SharkBite     = false
    SharkPetOrbit = false
    BtnBite.Text,     BtnBite.BackgroundColor3     = "Bite: OFF",     Color3.fromRGB(150,40,40)
    BtnPetOrbit.Text, BtnPetOrbit.BackgroundColor3 = "Pet Orbit: OFF",Color3.fromRGB(40,110,160)

    if name == "Stickman" then
        AnimPanel.Visible, AnimTitle.Text = true, "Animations — Stickman"
        SBFrame.Visible, ShFrame.Visible  = true, false
    elseif name == "Shark" then
        AnimPanel.Visible, AnimTitle.Text = true, "Animations — Shark"
        SBFrame.Visible, ShFrame.Visible  = false, true
    else
        AnimPanel.Visible = false
        SBFrame.Visible, ShFrame.Visible = false, false
    end

    local Hum = L.Character and L.Character:FindFirstChildOfClass("Humanoid")
    if Hum then Hum.CameraOffset = Vector3.zero end
    Cam.CameraType = Enum.CameraType.Custom

    CurrentMode  = name
    OrbitActive  = true
    BtnOrbitToggle.Text            = "⏸ Orbit: ON"
    BtnOrbitToggle.BackgroundColor3 = Color3.fromRGB(30,155,70)
end

local function STOP()
    SWITCH_MODE("None")
    HoldInStaging()
end

BtnStop.MouseButton1Click:Connect(STOP)

BtnOrbitToggle.MouseButton1Click:Connect(function()
    OrbitActive = not OrbitActive
    BtnOrbitToggle.Text = OrbitActive and "⏸ Orbit: ON" or "▶ Orbit: OFF (Staged)"
    BtnOrbitToggle.BackgroundColor3 = OrbitActive
        and Color3.fromRGB(30,155,70) or Color3.fromRGB(120,50,50)
    if not OrbitActive then
        HoldInStaging()
    else
        if StagingConn then StagingConn:Disconnect(); StagingConn = nil end
    end
end)

-- ============================================================
-- [11] NO-COLLISION + NETWORK KEEPALIVE
-- ============================================================
R.Stepped:Connect(function()
    local char = L.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then hrp.CanCollide = false end
    end
    for _, part in ipairs(CP) do
        if part and part.Parent and not part.Anchored then
            part.CanCollide = false
            pcall(function()
                if sethiddenproperty then
                    sethiddenproperty(part, "NetworkIsSleeping", false)
                end
            end)
        end
    end
end)

-- ============================================================
-- [12] RAINBOW / PAINT LOOP
-- ============================================================
BtnRainbow.MouseButton1Click:Connect(function()
    IsRainbowActive = not IsRainbowActive
    BtnRainbow.Text = IsRainbowActive and "Rainbow: ON" or "Fast Rainbow: OFF"
    BtnRainbow.BackgroundColor3 = IsRainbowActive
        and Color3.fromRGB(40,190,80) or Color3.fromRGB(130,45,175)
    if IsRainbowActive then StealthEquip() end
end)

BtnPaint.MouseButton1Click:Connect(function()
    IsPaintActive = not IsPaintActive
    BtnPaint.Text = IsPaintActive and "Paint Blocks: ON" or "Paint Blocks: OFF"
    BtnPaint.BackgroundColor3 = IsPaintActive
        and Color3.fromRGB(50,180,50) or Color3.fromRGB(140,50,50)
    if IsPaintActive then StealthEquip() end
end)

task.spawn(function()
    while task.wait(0.1) and S.Parent do
        if IsRainbowActive and #CP > 0 then
            local tick = os.clock() * RainbowSpeed
            local total = math.max(1, #CP)
            for i, prt in ipairs(CP) do
                if prt and prt.Parent then
                    local hue = (tick + i/total) % 1
                    FirePaint(prt, Color3.fromHSV(hue, 1, 1))
                end
            end
        elseif IsPaintActive and #CP > 0 then
            for _, prt in ipairs(CP) do
                if prt and prt.Parent then
                    FirePaint(prt, SelColor)
                end
            end
        end
    end
end)

-- ============================================================
-- [13] HOLLOW PURPLE
-- ============================================================
BtnHollowPurple.MouseButton1Click:Connect(function()
    SWITCH_MODE("HollowPurple")
    RefreshCP()
    if #CP < 4 then return end

    IsHollowActive = true
    local t0         = os.clock()
    local hasFired   = false
    local blastStart = 0
    local blastPos   = Vector3.zero
    local blastDir   = Vector3.new(0,0,-1)
    local lastColor  = 0
    local half       = math.floor(#CP/2)

    AC = R.RenderStepped:Connect(function(dt)
        if not IsHollowActive or not OrbitActive then return end
        local elapsed = os.clock() - t0
        local total   = #CP
        local RootPos = GET_TARGET_POS()
        local doColor = (os.clock()-lastColor > 0.15)
        if doColor then lastColor = os.clock() end

        if elapsed < 1.4 then
            local spd  = elapsed * 15
            local conv = math.clamp(1 - elapsed/1.4, 0.1, 1)
            for i, prt in ipairs(CP) do
                if prt and prt.Parent then
                    if i <= half then
                        if doColor then FirePaint(prt, Color3.fromRGB(0,150,255)) end
                        local ang = spd + i*(math.pi*2/math.max(1,half))
                        local off = Vector3.new(
                            math.cos(ang)*6*conv + 4*conv,
                            2 + math.sin(ang*2)*(2*conv),
                            math.sin(ang)*6*conv)
                        DrivePartFE(prt, CFrame.new(RootPos+off), dt, false)
                    else
                        if doColor then FirePaint(prt, Color3.fromRGB(255,30,45)) end
                        local ang = -spd + i*(math.pi*2/math.max(1,total-half))
                        local off = Vector3.new(
                            math.cos(ang)*6*conv - 4*conv,
                            2 + math.sin(ang*2)*(2*conv),
                            math.sin(ang)*6*conv)
                        DrivePartFE(prt, CFrame.new(RootPos+off), dt, false)
                    end
                end
            end

        elseif elapsed < 2.2 then
            local pt    = elapsed - 1.4
            local cen   = RootPos + blastDir*5 + Vector3.new(0,2,0)
            blastPos    = cen
            local phi   = (1+math.sqrt(5))/2
            for i, prt in ipairs(CP) do
                if prt and prt.Parent then
                    if doColor then FirePaint(prt, Color3.fromRGB(180,20,255)) end
                    local yn = 1-(i/total)*2
                    local r2 = math.sqrt(math.max(0,1-yn*yn))*(3+math.sin(pt*10)*0.5)
                    local th = phi*i*math.pi + pt*25
                    DrivePartFE(prt,
                        CFrame.new(cen + Vector3.new(math.cos(th)*r2, yn*3, math.sin(th)*r2)),
                        dt, false)
                end
            end

        else
            if not hasFired then
                hasFired   = true
                blastStart = os.clock()
                blastDir   = (M.Hit.Position - RootPos).Unit
            end
            local bd = os.clock() - blastStart
            blastPos = blastPos + blastDir*(BlockSpeed*3)
            for i, prt in ipairs(CP) do
                if prt and prt.Parent then
                    prt.CanCollide, prt.Anchored = false, false
                    if doColor then FirePaint(prt, Color3.fromRGB(160,10,255)) end
                    prt.AssemblyLinearVelocity = blastDir*(BlockSpeed*20)
                    prt.AssemblyAngularVelocity = Vector3.zero
                    local trail = Vector3.new(
                        math.sin(i+bd*10)*2,
                        math.cos(i+bd*10)*2,
                        -((i%10)*1.5))
                    prt.CFrame = CFrame.new(blastPos+trail, blastPos+trail+blastDir)
                end
            end
            if bd > 3.5 then
                IsHollowActive = false
                STOP()
            end
        end
    end)
end)

-- ============================================================
-- [14] CHAIN TRAIL
-- ============================================================
BtnChain.MouseButton1Click:Connect(function()
    SWITCH_MODE("Chain")
    RefreshCP()
    if #CP == 0 then return end

    local linkD = 2.2
    local chain = {}
    local root0 = L.Character and L.Character:FindFirstChild("HumanoidRootPart")
    local sp    = root0 and root0.Position or Vector3.zero
    for i = 1, #CP do chain[i] = sp - Vector3.new(0,0,i*linkD) end

    AC = R.RenderStepped:Connect(function(dt)
        if not OrbitActive then return end
        local C    = L.Character
        local Root = C and C:FindFirstChild("HumanoidRootPart")
        if not Root then return end

        local lead = Root.Position - Root.CFrame.LookVector*1.5 - Vector3.new(0,1.5,0)
        chain[1] = lead

        for i = 2, #CP do
            local prev  = chain[i-1]
            local curr  = chain[i] or prev
            local delta = curr - prev
            local d     = delta.Magnitude
            if d > linkD then
                chain[i] = prev + delta.Unit * linkD
            elseif d < 0.1 then
                chain[i] = prev - Root.CFrame.LookVector * linkD
            end
            local fy = GetFloorY(chain[i], C)
            if chain[i].Y < fy + 0.8 then
                chain[i] = Vector3.new(chain[i].X, fy+0.8, chain[i].Z)
            end
        end

        for i, prt in ipairs(CP) do
            if prt and prt.Parent then
                local pos  = chain[i]
                local prev = chain[math.max(1,i-1)]
                local lCF
                if (prev-pos).Magnitude > 0.01 then
                    lCF = CFrame.lookAt(pos, prev)
                else
                    lCF = CFrame.new(pos)
                end
                local roll = (i%2==0) and math.rad(90) or 0
                DrivePartFE(prt, lCF * CFrame.Angles(0,0,roll), dt, true)
            end
        end
    end)
end)

-- ============================================================
-- [15] SNAKE
-- ============================================================
BtnSnake.MouseButton1Click:Connect(function()
    SWITCH_MODE("Snake")
    RefreshCP()
    if #CP == 0 then return end

    local segD   = 2.0
    local segs   = {}
    local snakeT = 0
    local root0  = L.Character and L.Character:FindFirstChild("HumanoidRootPart")
    local sp     = root0 and root0.Position or Vector3.zero
    for i = 1, #CP do segs[i] = sp - Vector3.new(0,1.8,i*segD) end

    AC = R.RenderStepped:Connect(function(dt)
        if not OrbitActive then return end
        local C    = L.Character
        local Root = C and C:FindFirstChild("HumanoidRootPart")
        local Hum  = C and C:FindFirstChildOfClass("Humanoid")
        if not Root or not Hum then return end
        snakeT = snakeT + dt

        local vel    = Root.AssemblyLinearVelocity
        local speed  = Vector3.new(vel.X,0,vel.Z).Magnitude
        local moving = speed > 0.5
        local rate   = moving and math.clamp(speed*1.5,4,14) or 3

        local headT  = Root.Position + Root.CFrame.LookVector*1.5 - Vector3.new(0,2.2,0)
        segs[1] = segs[1] and segs[1]:Lerp(headT, 0.4) or headT

        for i = 2, #CP do
            local prev  = segs[i-1]
            local curr  = segs[i] or prev
            local delta = curr - prev
            if delta.Magnitude > segD then
                curr = prev + delta.Unit * segD
            end
            local segDir  = (prev-curr).Magnitude > 0.01 and (prev-curr).Unit or Vector3.new(0,0,1)
            local right   = Vector3.new(-segDir.Z,0,segDir.X)
            local wave    = math.sin((snakeT*rate)-(i*0.45)) * (moving and 1.8 or 0.8)
            local fy      = GetFloorY(curr, C)
            segs[i] = Vector3.new(
                curr.X + right.X*wave*0.15,
                math.max(fy+0.8, curr.Y),
                curr.Z + right.Z*wave*0.15)
        end

        for i, prt in ipairs(CP) do
            if prt and prt.Parent then
                local pos  = segs[i]
                local nxt  = segs[math.max(1,i-1)]
                local lCF  = (nxt-pos).Magnitude > 0.05
                    and CFrame.lookAt(pos, nxt) or CFrame.new(pos)
                DrivePartFE(prt, lCF, dt, true)
            end
        end
    end)
end)

-- ============================================================
-- [16] SHARK MORPH (CENTERED ON BODY - NOT AT FEET)
-- ============================================================
BtnShark.MouseButton1Click:Connect(function()
    SWITCH_MODE("Shark")
    RefreshCP()
    if #CP == 0 then return end

    local sharkT   = 0
    local bodyCol  = Color3.fromRGB(45,65,95)
    local bellyCol = Color3.fromRGB(235,240,250)
    local eyeOpen  = Color3.fromRGB(15,15,20)
    local eyeState = false
    local lastBlink= os.clock()
    local lastClr  = 0

    task.spawn(function()
        for i, prt in ipairs(CP) do
            if prt and prt.Parent then
                local col = (i==2 or i==3) and eyeOpen
                    or ((i%2==0) and bodyCol or bellyCol)
                FirePaint(prt, col)
            end
        end
    end)

    AC = R.RenderStepped:Connect(function(dt)
        if not OrbitActive then return end
        local C    = L.Character
        local Root = C and C:FindFirstChild("HumanoidRootPart")
        local Hum  = C and C:FindFirstChildOfClass("Humanoid")
        if not Root or not Hum then return end
        sharkT = sharkT + dt

        local vel      = Root.AssemblyLinearVelocity
        local speed    = Vector3.new(vel.X,0,vel.Z).Magnitude
        local swimRate = speed>0.5 and math.clamp(speed*1.8,5,16) or 3.2
        local turnTilt = math.clamp(vel.X*0.05,-0.4,0.4)

        -- Blink logic
        local now = os.clock()
        if now-lastBlink > 3.8 then
            eyeState = true
            if now-lastBlink > 4.05 then eyeState=false; lastBlink=now end
        else eyeState=false end

        local doClr = (now-lastClr > 0.3)
        if doClr then lastClr=now end

        local biteCyc = (sharkT*14)%(math.pi*2)
        local chomp   = SharkBite and math.abs(math.sin(biteCyc)) or 0
        local jawDrop = chomp*3.5
        local jawLift = chomp*1.6
        local lungeZ  = SharkBite and math.sin(biteCyc)*3 or 0
        local thrashX = SharkBite and math.sin(sharkT*28)*1.4 or 0
        local lunge   = Vector3.new(thrashX*0.4,0,-lungeZ)

        local offsets = {}
        local colors2 = {}
        local total   = #CP

        offsets[1] = Vector3.new(thrashX*0.3,jawLift*0.4,-8) + lunge
        colors2[1] = bodyCol
        if total>=2 then
            offsets[2]=Vector3.new(-1.8,0.8+jawLift*0.2,-6.5)+lunge
            colors2[2]=eyeState and bodyCol or (SharkBite and Color3.fromRGB(255,30,30) or eyeOpen)
        end
        if total>=3 then
            offsets[3]=Vector3.new(1.8,0.8+jawLift*0.2,-6.5)+lunge
            colors2[3]=eyeState and bodyCol or (SharkBite and Color3.fromRGB(255,30,30) or eyeOpen)
        end
        if total>=4 then offsets[4]=Vector3.new(thrashX*0.3,1+jawLift,-6.8)+lunge; colors2[4]=bodyCol end
        if total>=5 then offsets[5]=Vector3.new(-1.2+thrashX*0.3,-0.9-jawDrop,-6)+lunge; colors2[5]=SharkBite and Color3.fromRGB(240,240,240) or bellyCol end
        if total>=6 then offsets[6]=Vector3.new( 1.2+thrashX*0.3,-0.9-jawDrop,-6)+lunge; colors2[6]=SharkBite and Color3.fromRGB(240,240,240) or bellyCol end

        local cur = 7
        local rem = math.max(0, total-6)
        if rem > 0 then
            local dorsC  = math.clamp(math.floor(rem*0.15),1,6)
            local pecSd  = math.clamp(math.floor(rem*0.10),1,4)
            local headC  = math.clamp(math.floor(rem*0.15),1,6)
            local tailC  = math.clamp(math.floor(rem*0.25),2,12)
            local torsoC = math.max(1, rem-(dorsC+pecSd*2+headC+tailC))
            local finSwy = math.sin(sharkT*swimRate)*0.25

            for h=1,headC do
                if cur>total then break end
                local frac=h/headC; local side=(h%2==0) and 1 or -1
                offsets[cur]=Vector3.new(side*2.2,0.2,-5+frac*3); colors2[cur]=bodyCol; cur=cur+1
            end
            for d=1,dorsC do
                if cur>total then break end
                local hf=d/dorsC
                offsets[cur]=Vector3.new(finSwy*hf,2+hf*2.8,-1.2+hf*1.5); colors2[cur]=bodyCol; cur=cur+1
            end
            for p=1,pecSd do
                if cur>total then break end
                local pf=p/pecSd
                offsets[cur]=Vector3.new(-2.5-pf*4.2,-0.6-pf*0.8+turnTilt*1.5,-2+pf*1.8); colors2[cur]=bodyCol; cur=cur+1
            end
            for p=1,pecSd do
                if cur>total then break end
                local pf=p/pecSd
                offsets[cur]=Vector3.new(2.5+pf*4.2,-0.6-pf*0.8-turnTilt*1.5,-2+pf*1.8); colors2[cur]=bodyCol; cur=cur+1
            end
            for b=1,torsoC do
                if cur>total then break end
                local bf=b/torsoC; local ang=b*2.4
                local rx2=2.2*(1-math.abs(bf-0.4)*0.4); local ry2=1.6*(1-math.abs(bf-0.4)*0.4)
                local x2=math.cos(ang)*rx2; local y2=math.sin(ang)*ry2
                offsets[cur]=Vector3.new(x2,y2,-1.5+bf*4.5)
                colors2[cur]=(y2<-0.2) and bellyCol or bodyCol; cur=cur+1
            end
            for t=1,tailC do
                if cur>total then break end
                local tf=t/tailC
                local swayX2=math.sin((sharkT*swimRate)-tf*2.8)*(tf*3.8)
                local z2=3.2+tf*9.5; local y2=0; local col2=bodyCol
                if t==tailC then y2=2.4; swayX2=swayX2*1.2
                elseif t==tailC-1 and tailC>2 then y2=-2; col2=bellyCol; swayX2=swayX2*1.2
                else y2=math.sin(t)*0.4; col2=(y2<-0.1) and bellyCol or bodyCol end
                offsets[cur]=Vector3.new(swayX2,y2,z2); colors2[cur]=col2; cur=cur+1
            end
        end
        while cur<=total do
            local ang=cur*1.5707; local y2=(cur%3==0) and 1.2 or -0.6
            offsets[cur]=Vector3.new(math.cos(ang)*1.8,y2,-2+((cur%9)*1.2))
            colors2[cur]=(y2<0) and bellyCol or bodyCol; cur=cur+1
        end

        -- FIX: Center the shark squarely at the player's torso/body center
        -- instead of dipping low near the feet.
        local bodyCenterOffset = Vector3.new(0, 0.8, 0)
        local baseCF = Root.CFrame * CFrame.new(bodyCenterOffset)

        if SharkPetOrbit then
            local ang = sharkT*1.3
            local heading = -ang + math.pi/2
            baseCF = Root.CFrame
                * CFrame.new(math.cos(ang)*SharkPetRadius, 0.8, math.sin(ang)*SharkPetRadius)
                * CFrame.Angles(0, heading, 0)
            local Hum2 = C and C:FindFirstChildOfClass("Humanoid")
            if Hum2 then Hum2.CameraOffset = Vector3.zero end
        else
            -- Framed around body center (3.5 studs) rather than 8 studs above
            Hum.CameraOffset = Vector3.new(0, 3.5, 0)
        end

        for i, prt in ipairs(CP) do
            if prt and prt.Parent then
                local off = offsets[i] or Vector3.zero
                DrivePartFE(prt, baseCF * CFrame.new(off), dt, false)
                if doClr and colors2[i] then
                    FirePaint(prt, colors2[i])
                end
            end
        end
    end)
end)

-- ============================================================
-- [17] STICKMAN MORPH (PLAYER AT FEET - NOT CENTER)
-- ============================================================
BtnStickman.MouseButton1Click:Connect(function()
    SWITCH_MODE("Stickman")
    RefreshCP()
    if #CP == 0 then return end

    local animT = 0

    local function genLine(p1, p2, count)
        local pts = {}
        for i = 1, count do
            local t = (i-1)/math.max(1,count-1)
            table.insert(pts, p1:Lerp(p2,t))
        end
        return pts
    end
    local function genCircle(center, radius, count)
        local pts = {}
        for i = 1, count do
            local ang = (i/count)*math.pi*2
            table.insert(pts, center + Vector3.new(math.cos(ang)*radius, math.sin(ang)*radius, 0))
        end
        return pts
    end

    AC = R.RenderStepped:Connect(function(dt)
        if not OrbitActive then return end
        local C    = L.Character
        local Root = C and C:FindFirstChild("HumanoidRootPart")
        local Hum  = C and C:FindFirstChildOfClass("Humanoid")
        if not Root or not Hum then return end
        animT = animT + dt

        local vel     = Root.AssemblyLinearVelocity
        local speed   = Vector3.new(vel.X,0,vel.Z).Magnitude
        local state   = Hum:GetState()
        local moving  = speed > 0.5

        local groundY    = GetFloorY(Root.Position, C)
        local localGnd   = groundY - Root.Position.Y

        local anim = StickAnim
        if anim == "sit" and moving then anim = "walk" end

        local headCenter, neck, pelvis
        local leftHand, rightHand, leftFoot, rightFoot

        -- FIX: Shift the stickman skeleton upward so that the player is positioned
        -- at the FEET of the giant stickman rather than stuck at the stickman's waist/pelvis center.
        local FOOT_ELEVATION = 11.0 -- Height offset raising pelvis so feet reach player position

        if anim == "lay_down" then
            -- Grounded lay-down with feet anchored near player
            local g = localGnd + 0.6
            headCenter = Vector3.new(0, g,     -18.0)
            neck       = Vector3.new(0, g,     -14.0)
            pelvis     = Vector3.new(0, g,      -6.0)
            local breath = math.sin(animT*3)*0.2
            neck = neck + Vector3.new(0, breath, 0)
            leftHand  = neck   + Vector3.new(-4.5, 0,  1.0)
            rightHand = neck   + Vector3.new( 4.5, 0,  1.0)
            leftFoot  = pelvis + Vector3.new(-3.0, 0,   6.0)
            rightFoot = pelvis + Vector3.new( 3.0, 0,   6.0)

        elseif anim == "sit" then
            -- Sitting stickman with feet touching right where the player stands
            local g = localGnd
            pelvis     = Vector3.new(0, g + 6.0,  -7.0)
            neck       = Vector3.new(0, g + 12.5, -7.0)
            headCenter = Vector3.new(0, g + 16.5, -7.0)
            local sway = math.sin(animT*2)*0.15
            leftHand   = pelvis + Vector3.new(-5.0, 2.0, 3.5+sway)
            rightHand  = pelvis + Vector3.new( 5.0, 2.0, 3.5+sway)
            leftFoot   = Vector3.new(-3.5, g,  0.5)
            rightFoot  = Vector3.new( 3.5, g,  0.5)

        elseif state==Enum.HumanoidStateType.Jumping or vel.Y > 2 then
            pelvis     = Vector3.new(0, 1 + FOOT_ELEVATION, 0)
            neck       = Vector3.new(0, 12 + FOOT_ELEVATION, 0)
            headCenter = Vector3.new(0, 16 + FOOT_ELEVATION, 0)
            leftHand   = neck + Vector3.new(-10, 8, 2); rightHand = neck + Vector3.new(10, 8, 2)
            leftFoot   = pelvis + Vector3.new(-6, -8, 4)
            rightFoot  = pelvis + Vector3.new( 6, -8, -2)

        elseif state==Enum.HumanoidStateType.Freefall or vel.Y < -2 then
            pelvis     = Vector3.new(0, 1 + FOOT_ELEVATION, 0)
            neck       = Vector3.new(0, 12 + FOOT_ELEVATION, 0)
            headCenter = Vector3.new(0, 16 + FOOT_ELEVATION, 0)
            leftHand   = neck + Vector3.new(-12, 12, -2); rightHand = neck + Vector3.new(12, 12, -2)
            leftFoot   = pelvis + Vector3.new(-5, -10, -2)
            rightFoot  = pelvis + Vector3.new( 5, -10,  2)

        else
            -- Standing / Walking: Pelvis elevated +11 studs so feet step right at player level
            pelvis     = Vector3.new(0, 1 + FOOT_ELEVATION, 0)
            neck       = Vector3.new(0, 12 + FOOT_ELEVATION, 0)
            headCenter = Vector3.new(0, 16 + FOOT_ELEVATION, 0)
            local cycleSpd = math.clamp(speed*0.8, 4, 12)
            local swing    = moving and math.sin(animT*cycleSpd)*0.8 or math.sin(animT*2)*0.05
            leftHand = neck + Vector3.new(
                -10*math.cos(swing), -8*math.sin(swing)-2, math.sin(swing)*6)
            if anim == "wave" then
                local wv = math.sin(animT*12)*0.6
                rightHand = neck + Vector3.new(8+wv*4.5, 11+math.abs(wv*2), -2)
            else
                rightHand = neck + Vector3.new(
                    10*math.cos(-swing), -8*math.sin(-swing)-2, math.sin(-swing)*6)
            end
            -- Left and right feet now contact ground around player level
            leftFoot  = pelvis + Vector3.new(-4, math.max(-FOOT_ELEVATION, -FOOT_ELEVATION*math.cos(swing)),  math.sin(swing)*8)
            rightFoot = pelvis + Vector3.new( 4, math.max(-FOOT_ELEVATION, -FOOT_ELEVATION*math.cos(-swing)), math.sin(-swing)*8)
        end

        local total   = #CP
        local headC   = math.clamp(math.floor(total*0.20), 8, 28)
        local spineC  = math.clamp(math.floor(total*0.15), 5, 16)
        local armC    = math.clamp(math.floor(total*0.10), 4, 12)
        local legC    = math.clamp(math.floor(total*0.12), 4, 15)

        local pts = {}
        for _, p in ipairs(genCircle(headCenter, 4.5, headC))   do table.insert(pts, p) end
        for _, p in ipairs(genLine(neck, pelvis, spineC))        do table.insert(pts, p) end
        for _, p in ipairs(genLine(neck, leftHand,  armC))       do table.insert(pts, p) end
        for _, p in ipairs(genLine(neck, rightHand, armC))       do table.insert(pts, p) end
        for _, p in ipairs(genLine(pelvis, leftFoot,  legC))     do table.insert(pts, p) end
        for _, p in ipairs(genLine(pelvis, rightFoot, legC))     do table.insert(pts, p) end

        local rootCF  = Root.CFrame
        local skelLen = #pts

        for i, prt in ipairs(CP) do
            if prt and prt.Parent then
                local pidx  = ((i-1) % skelLen) + 1
                local off   = pts[pidx]

                local repeat_n  = math.floor((i-1)/skelLen)
                local spiralAng = repeat_n * 2.1
                local spiralR   = repeat_n * 0.35
                local spreadOff = Vector3.new(
                    math.cos(spiralAng)*spiralR, 0,
                    math.sin(spiralAng)*spiralR)

                local worldPos = (rootCF * CFrame.new(off + spreadOff)).Position
                DrivePartFE(prt, CFrame.new(worldPos), dt, false)
            end
        end

        -- Camera framed comfortably so you can see your player at the feet
        Hum.CameraOffset = Vector3.new(0, 10, 0)
    end)
end)

-- ============================================================
-- [18] BALL ORBIT
-- ============================================================
BtnBall.MouseButton1Click:Connect(function()
    SWITCH_MODE("Ball")
    RefreshCP()
    if #CP == 0 then return end

    local ballT       = 0
    local bounceVel   = 0
    local bounceY     = 0
    local wasGrounded = true
    local rollAngle   = 0
    local rollAxis    = Vector3.new(1,0,0)
    local spinAngle   = 0
    local phi         = (1+math.sqrt(5))/2

    AC = R.RenderStepped:Connect(function(dt)
        if not OrbitActive then return end
        local C    = L.Character
        local Root = C and C:FindFirstChild("HumanoidRootPart")
        local Hum  = C and C:FindFirstChildOfClass("Humanoid")
        if not Root or not Hum then return end
        ballT = ballT + dt

        local vel       = Root.AssemblyLinearVelocity
        local state     = Hum:GetState()
        local grounded  = (state == Enum.HumanoidStateType.Running
            or state == Enum.HumanoidStateType.RunningNoPhysics
            or state == Enum.HumanoidStateType.Standing)
        local horizVel  = Vector3.new(vel.X,0,vel.Z)
        local speed     = horizVel.Magnitude

        if grounded and not wasGrounded then
            bounceVel = 4.5
        end
        wasGrounded = grounded

        bounceVel = bounceVel - 20*dt
        bounceY   = bounceY   + bounceVel*dt
        if bounceY <= 0 then
            bounceY   = 0
            bounceVel = math.abs(bounceVel)*0.45
            if math.abs(bounceVel) < 0.5 then bounceVel = 0 end
        end

        if speed > 0.3 then
            local ballR = 6.0
            rollAngle   = rollAngle + (speed*dt)/ballR
            if horizVel.Magnitude > 0.01 then
                local moveDir = horizVel.Unit
                rollAxis = Vector3.new(-moveDir.Z, 0, moveDir.X).Unit
            end
        end

        spinAngle = spinAngle + dt*0.35

        local total    = math.max(1, #CP)
        local ballR    = 6.0 + math.sin(ballT*1.5)*0.15
        local center   = Root.Position + Vector3.new(0, bounceY, 0)
        local spinCF   = CFrame.Angles(0, spinAngle, 0)
        local rollCF   = CFrame.fromAxisAngle(rollAxis, rollAngle)

        for i, prt in ipairs(CP) do
            if prt and prt.Parent then
                local yn  = 1 - (i/total)*2
                local r2  = math.sqrt(math.max(0, 1-yn*yn))
                local th  = phi * i * math.pi * 2
                local loc = Vector3.new(
                    math.cos(th)*r2*ballR,
                    yn*ballR,
                    math.sin(th)*r2*ballR)

                local rolled = rollCF:VectorToWorldSpace(loc)
                local spun   = spinCF:VectorToWorldSpace(rolled)
                DrivePartFE(prt, CFrame.new(center + spun), dt, false)
            end
        end
    end)
end)

-- ============================================================
-- [19] DOOR TOOL
-- ============================================================
local DoorAngle     = 0
local DoorBasePos   = Vector3.zero
local DoorBaseFwd   = Vector3.new(0,0,-1)
local DoorConn      = nil

local function CleanupDoor()
    if DoorConn     then DoorConn:Disconnect();     DoorConn = nil     end
    if DoorProxConn then DoorProxConn:Disconnect(); DoorProxConn = nil end
    if DoorPreviewConn then
        DoorPreviewConn:Disconnect(); DoorPreviewConn = nil
    end
    DoorPlacedPart = nil
    DoorAngle      = 0
end

BtnDoor.MouseButton1Click:Connect(function()
    DoorActive = not DoorActive
    BtnDoor.Text = DoorActive
        and "Door Tool: ON  (Click to Place)"
        or  "Door Tool: OFF"
    BtnDoor.BackgroundColor3 = DoorActive
        and Color3.fromRGB(80,175,80) or Color3.fromRGB(80,80,140)

    if not DoorActive then CleanupDoor(); return end

    if #CP == 0 then
        RefreshCP()
        if #CP == 0 then
            BtnDoor.Text = "Door Tool: No blocks claimed!"
            BtnDoor.BackgroundColor3 = Color3.fromRGB(180,50,50)
            DoorActive = false
            return
        end
    end

    local preview = Instance.new("Part")
    preview.Name, preview.Anchored    = "DoorPreview", true
    preview.CanCollide, preview.Transparency = false, 0.5
    preview.Size                       = Vector3.new(0.5, 8, 4)
    preview.Color                      = Color3.fromRGB(80,140,255)
    preview.Material                   = Enum.Material.Neon
    preview.Parent                     = workspace

    DoorPreviewConn = R.RenderStepped:Connect(function()
        if not DoorActive or not preview.Parent then
            DoorPreviewConn:Disconnect(); DoorPreviewConn = nil; return
        end
        local h   = M.Hit
        local snp = Vector3.new(
            math.round(h.Position.X/4)*4,
            math.round(h.Position.Y/4)*4,
            math.round(h.Position.Z/4)*4)
        preview.CFrame = CFrame.new(snp)
    end)

    local placeConn
    placeConn = M.Button1Down:Connect(function()
        if not DoorActive then placeConn:Disconnect(); return end

        local doorPart = CP[1]
        if not doorPart or not doorPart.Parent then
            placeConn:Disconnect(); CleanupDoor(); return
        end
        local newCP = {}
        for i, p in ipairs(CP) do if i ~= 1 then table.insert(newCP, p) end end
        CP = newCP

        local placeCF    = preview.CFrame
        DoorBasePos      = placeCF.Position
        DoorBaseFwd      = placeCF.LookVector
        DoorAngle        = 0
        DoorPlacedPart   = doorPart

        doorPart.Size     = Vector3.new(0.5, 8, 4)
        doorPart.CanCollide = true
        doorPart.Color    = Color3.fromRGB(140,100,60)
        doorPart.Material = Enum.Material.Wood
        doorPart.CFrame   = placeCF

        FirePaint(doorPart, Color3.fromRGB(140,100,60))

        pcall(function() preview:Destroy() end)
        if DoorPreviewConn then DoorPreviewConn:Disconnect(); DoorPreviewConn = nil end
        placeConn:Disconnect()
        DoorActive = false
        BtnDoor.Text = "Door Tool: OFF  (Door placed!)"
        BtnDoor.BackgroundColor3 = Color3.fromRGB(80,80,140)

        local hingeOffset = Vector3.new(-2, 0, 0)
        local prevAngle   = 0

        DoorConn = R.RenderStepped:Connect(function(dt)
            if not doorPart or not doorPart.Parent then
                DoorConn:Disconnect(); DoorConn = nil; return
            end

            local anyNear = false
            for _, pl in ipairs(P:GetPlayers()) do
                local plHrp = pl.Character
                    and pl.Character:FindFirstChild("HumanoidRootPart")
                if plHrp and (plHrp.Position-doorPart.Position).Magnitude < 8 then
                    anyNear = true; break
                end
            end

            local targetAngle = anyNear and (-math.pi/2) or 0
            local angleDiff = targetAngle - DoorAngle
            DoorAngle = DoorAngle + angleDiff * math.min(dt*5, 1)

            local pivotWorldCF = placeCF * CFrame.new(hingeOffset)
                                           * CFrame.Angles(0, DoorAngle, 0)
            local doorCF = pivotWorldCF * CFrame.new(-hingeOffset)

            local tPos   = doorCF.Position
            local curPos = doorPart.Position
            local posErr = tPos - curPos

            doorPart.CanCollide = true
            doorPart.Anchored   = false
            doorPart.AssemblyLinearVelocity =
                posErr * 18 - doorPart.AssemblyLinearVelocity * 0.7

            local angSpd = (DoorAngle - prevAngle) / dt
            doorPart.AssemblyAngularVelocity =
                Vector3.new(0, angSpd * 0.9, 0)

            prevAngle = DoorAngle

            pcall(function()
                if sethiddenproperty then
                    sethiddenproperty(doorPart, "NetworkIsSleeping", false)
                end
            end)
        end)
    end)
end)

-- ============================================================
-- [20] STANDARD ORBIT MODES (STABILIZED - CLEAN & STEADY)
-- ============================================================
BtnFollow.MouseButton1Click:Connect(function()
    SWITCH_MODE("Follow"); RefreshCP()
    local A = 0
    AC = R.RenderStepped:Connect(function(dt)
        if not OrbitActive then return end
        local ctr   = GET_TARGET_POS()
        A = A + 0.03
        local total = math.max(1,#CP)
        for i, prt in ipairs(CP) do
            if prt and prt.Parent then
                local ang = A + i*(math.pi*2/total)
                local off = Vector3.new(
                    math.cos(ang)*6, 2+math.sin(i+A)*2, math.sin(ang)*6)
                DrivePartFE(prt, CFrame.new(ctr+off), dt, false)
            end
        end
    end)
end)

BtnBlaster.MouseButton1Click:Connect(function()
    SWITCH_MODE("Blaster"); RefreshCP()
    if #CP < 2 then return end
    local bulletIdx = 1
    AC = R.RenderStepped:Connect(function(dt)
        if not OrbitActive then return end
        local ctr    = GET_TARGET_POS()
        local Barrel = CP[1]
        if Barrel and Barrel.Parent then
            DrivePartFE(Barrel, CFrame.new(ctr+Vector3.new(2,2,-2), M.Hit.Position), dt, true)
        end
        local root   = L.Character and L.Character:FindFirstChild("HumanoidRootPart")
        local stgPos = root and root.Position+Vector3.new(0,STAGE_ALT,0) or ctr
        for i=2,#CP do
            local b = CP[i]
            if b and b.Parent then
                DrivePartFE(b, CFrame.new(stgPos+Vector3.new((i%5)*2,0,math.floor(i/5)*2)), dt, false)
            end
        end
    end)
    BlasterConn = UIS.InputBegan:Connect(function(input, gpe)
        if gpe or not (CurrentMode=="Blaster") then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            bulletIdx = (bulletIdx % math.max(1,#CP-1)) + 2
            local Bullet = CP[bulletIdx]; local Barrel = CP[1]
            if Bullet and Bullet.Parent and Barrel and Barrel.Parent then
                Bullet.CanCollide, Bullet.Anchored = false, false
                Bullet.CFrame = Barrel.CFrame * CFrame.new(0,0,-2)
                local dir = (M.Hit.Position - Barrel.Position).Unit
                Bullet.AssemblyLinearVelocity   = dir*(BlockSpeed*8)
                Bullet.AssemblyAngularVelocity  = Vector3.zero
            end
        end
    end)
end)

BtnHelix.MouseButton1Click:Connect(function()
    SWITCH_MODE("Helix"); RefreshCP()
    local A = 0
    AC = R.RenderStepped:Connect(function(dt)
        if not OrbitActive then return end
        local ctr   = GET_TARGET_POS()
        A = A + 0.05
        local total = math.max(1,#CP)
        for i, prt in ipairs(CP) do
            if prt and prt.Parent then
                local y2   = ((i*0.8)%30)-15
                local side = (i%2==0) and 1 or -1
                local ang  = A + y2*0.3
                DrivePartFE(prt, CFrame.new(ctr + Vector3.new(
                    math.cos(ang)*6*side, y2+10, math.sin(ang)*6*side)), dt, false)
            end
        end
    end)
end)

BtnTornado.MouseButton1Click:Connect(function()
    SWITCH_MODE("Tornado"); RefreshCP()
    local A = 0
    AC = R.RenderStepped:Connect(function(dt)
        if not OrbitActive then return end
        local tgt   = M.Hit.Position
        A = A + 0.1
        local total = math.max(1,#CP)
        for i, prt in ipairs(CP) do
            if prt and prt.Parent then
                local h   = (i/total)*25
                local r2  = h*0.6+2
                local ang = A+i
                DrivePartFE(prt, CFrame.new(tgt + Vector3.new(
                    math.cos(ang)*r2, h, math.sin(ang)*r2)), dt, false)
            end
        end
    end)
end)

BtnDraw.MouseButton1Click:Connect(function()
    SWITCH_MODE("Draw"); RefreshCP()
    AC = R.RenderStepped:Connect(function(dt)
        if not OrbitActive then return end
        local tPos = M.Hit.Position
        for _, prt in ipairs(CP) do
            if prt and prt.Parent then
                DrivePartFE(prt, CFrame.new(tPos + Vector3.new(0,2,0)), dt, false)
            end
        end
    end)
end)

BtnVortex.MouseButton1Click:Connect(function()
    SWITCH_MODE("Vortex"); RefreshCP()
    local A = 0
    AC = R.RenderStepped:Connect(function(dt)
        if not OrbitActive then return end
        local ctr = GET_TARGET_POS()
        A = A + 0.05
        for i, prt in ipairs(CP) do
            if prt and prt.Parent then
                local D  = 10+i*0.2
                local CA = A+i*0.1
                DrivePartFE(prt, CFrame.new(ctr + Vector3.new(
                    math.cos(CA)*D, (i*0.1)%15, math.sin(CA)*D)), dt, false)
            end
        end
    end)
end)

BtnRain.MouseButton1Click:Connect(function()
    SWITCH_MODE("Rain"); RefreshCP()
    AC = R.RenderStepped:Connect(function(dt)
        if not OrbitActive then return end
        local ctr = GET_TARGET_POS()
        local t   = os.clock()
        for i, prt in ipairs(CP) do
            if prt and prt.Parent then
                DrivePartFE(prt, CFrame.new(ctr + Vector3.new(
                    math.sin(i+t)*30, 40+(i%20), math.cos(i+t)*30)), dt, false)
            end
        end
    end)
end)

BtnOrbit.MouseButton1Click:Connect(function()
    SWITCH_MODE("SphereOrbit"); RefreshCP()
    local A   = 0
    local phi = (1+math.sqrt(5))/2
    AC = R.RenderStepped:Connect(function(dt)
        if not OrbitActive then return end
        local ctr   = GET_TARGET_POS()
        A = A + 0.04
        local total = math.max(1,#CP)
        for i, prt in ipairs(CP) do
            if prt and prt.Parent then
                local yn   = 1-(i/total)*2
                local r2   = math.sqrt(math.max(0,1-yn*yn))*12
                local theta = phi*i*math.pi + A
                DrivePartFE(prt, CFrame.new(ctr + Vector3.new(
                    math.cos(theta)*r2, yn*12+2, math.sin(theta)*r2)), dt, false)
            end
        end
    end)
end)

BtnShield.MouseButton1Click:Connect(function()
    SWITCH_MODE("Shield"); RefreshCP()
    local A = 0
    AC = R.RenderStepped:Connect(function(dt)
        if not OrbitActive then return end
        local ctr   = GET_TARGET_POS()
        A = A + 0.03
        local total = math.max(1,#CP)
        for i, prt in ipairs(CP) do
            if prt and prt.Parent then
                local ang = A + i*(math.pi*2/total)
                DrivePartFE(prt, CFrame.new(ctr + Vector3.new(
                    math.cos(ang)*5, (i%3)*2, math.sin(ang)*5)), dt, false)
            end
        end
    end)
end)

BtnFling.MouseButton1Click:Connect(function()
    SWITCH_MODE("Fling"); RefreshCP()
    AC = R.RenderStepped:Connect(function(dt)
        if not OrbitActive then return end
        local _, tRoot = GET_TARGET_POS()
        if tRoot then
            for _, prt in ipairs(CP) do
                if prt and prt.Parent then
                    prt.CanCollide, prt.Anchored = false, false
                    prt.AssemblyLinearVelocity   = Vector3.new(10000,10000,10000)
                    prt.CFrame                   = tRoot.CFrame
                end
            end
        end
    end)
end)

-- ============================================================
-- [21] WEAPONS
-- ============================================================
BtnRifle.MouseButton1Click:Connect(function()
    CurrentWeapon = (CurrentWeapon=="Rifle") and "None" or "Rifle"
    BtnRifle.Text = (CurrentWeapon=="Rifle") and "Rifle: EQUIPPED" or "Weapon: Rifle"
    BtnRifle.BackgroundColor3 = (CurrentWeapon=="Rifle")
        and Color3.fromRGB(40,180,80) or Color3.fromRGB(60,130,200)
end)
BtnSword.MouseButton1Click:Connect(function()
    CurrentWeapon = (CurrentWeapon=="Sword") and "None" or "Sword"
    BtnSword.Text = (CurrentWeapon=="Sword") and "Sword: EQUIPPED" or "Weapon: Sword"
    BtnSword.BackgroundColor3 = (CurrentWeapon=="Sword")
        and Color3.fromRGB(220,160,40) or Color3.fromRGB(200,110,45)
end)

local function FlingTarget(targetChar, launchVec)
    if not targetChar then return end
    local root = targetChar:FindFirstChild("HumanoidRootPart")
    if not root then return end
    task.spawn(function()
        local t0 = os.clock()
        while os.clock()-t0 < 0.5 do
            for _, prt in ipairs(CP) do
                if prt and prt.Parent then
                    prt.CFrame                 = root.CFrame
                    prt.AssemblyLinearVelocity = launchVec*(BlockSpeed/60)
                end
            end
            task.wait()
        end
    end)
end

local function ShootRifle()
    if #CP<5 or os.clock()-LastShotTime<0.25 then return end
    LastShotTime = os.clock()
    local bullet = CP[#CP]
    local root   = L.Character and L.Character:FindFirstChild("HumanoidRootPart")
    if not root or not bullet then return end
    local dir = (M.Hit.Position - (root.Position+Vector3.new(0,2,0))).Unit
    bullet.CFrame                = CFrame.new(root.Position+Vector3.new(0,2,0))
    bullet.AssemblyLinearVelocity = dir*(BlockSpeed*8)
    local conn
    conn = bullet.Touched:Connect(function(hit)
        local ch  = hit.Parent
        local hum = ch and ch:FindFirstChildOfClass("Humanoid")
        if hum and ch ~= L.Character then
            conn:Disconnect()
            FlingTarget(ch, Vector3.new(
                math.random(-5000,5000), 10000, math.random(-5000,5000)))
        end
    end)
    task.delay(1.5, function() if conn then conn:Disconnect() end end)
end

local function SwordSlash()
    if IsSlashing or #CP<5 then return end
    IsSlashing = true
    task.spawn(function()
        local t0 = os.clock()
        while os.clock()-t0<0.25 do
            local root = L.Character and L.Character:FindFirstChild("HumanoidRootPart")
            if root then
                for _, pl in ipairs(P:GetPlayers()) do
                    if pl~=L and pl.Character then
                        local tr = pl.Character:FindFirstChild("HumanoidRootPart")
                        if tr and (tr.Position-root.Position).Magnitude < 18 then
                            FlingTarget(pl.Character, Vector3.new(
                                math.random(-4000,4000), 30000, math.random(-4000,4000)))
                        end
                    end
                end
            end
            task.wait()
        end
        IsSlashing = false
    end)
end

UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        if CurrentWeapon=="Rifle" then ShootRifle()
        elseif CurrentWeapon=="Sword" then SwordSlash()
        end
    end
end)

-- ============================================================
-- [22] FLYING
-- ============================================================
BtnFly.MouseButton1Click:Connect(function()
    Flying = not Flying
    BtnFly.Text = Flying and "Flying: ON" or "Toggle Fly"
    BtnFly.BackgroundColor3 = Flying
        and Color3.fromRGB(40,180,80) or Color3.fromRGB(45,150,210)

    if FlyConn then FlyConn:Disconnect(); FlyConn = nil end
    local C    = L.Character
    local Root = C and C:FindFirstChild("HumanoidRootPart")
    local Hum  = C and C:FindFirstChildOfClass("Humanoid")
    if not Flying or not Root or not Hum then
        if Hum then Hum.PlatformStand = false end; return
    end
    Hum.PlatformStand = true
    FlyConn = R.RenderStepped:Connect(function(dt)
        if not Flying then
            if Hum then Hum.PlatformStand = false end
            FlyConn:Disconnect(); FlyConn = nil; return
        end
        local camCF = workspace.CurrentCamera.CFrame
        local mv    = Vector3.zero
        if UIS:IsKeyDown(Enum.KeyCode.W) then mv = mv + camCF.LookVector  end
        if UIS:IsKeyDown(Enum.KeyCode.S) then mv = mv - camCF.LookVector  end
        if UIS:IsKeyDown(Enum.KeyCode.A) then mv = mv - camCF.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.D) then mv = mv + camCF.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.Space)     then mv = mv + Vector3.new(0,1,0) end
        if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then mv = mv - Vector3.new(0,1,0) end
        Root.AssemblyLinearVelocity = Vector3.zero
        Root.CFrame = Root.CFrame + mv*(FlySpeed*dt)
    end)
end)

-- ============================================================
-- [23] MISC BUTTONS
-- ============================================================
BtnReset.MouseButton1Click:Connect(function()
    STOP()
    local hum = L.Character and L.Character:FindFirstChildOfClass("Humanoid")
    if hum then hum.Health = 0 end
end)

BtnRejoin.MouseButton1Click:Connect(function()
    pcall(function() T:TeleportToPlaceInstance(game.PlaceId, game.JobId, L) end)
end)

UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == ToggleKey then
        F.Visible  = not F.Visible
        BallBtn.Visible = not F.Visible
    end
end)

-- ============================================================
-- [24] BACKGROUND LOOP — stats + periodic refresh
-- ============================================================
task.spawn(function()
    HoldInStaging()
    while task.wait(0.5) and S.Parent do
        pcall(function()
            RefreshCP()

            sLbl_Ping.Text   = "Ping: " .. math.round(L:GetNetworkPing()*1000) .. " ms"
            sLbl_Blks.Text   = "Claimed: " .. #CP .. " blocks"
            sLbl_Plrs.Text   = "Players: " .. #P:GetPlayers()

            local selStr = TapClaimOn and "Tap-to-Claim ON"
                or (ClaimAllOn and "Claim-All ON" or "OFF")
            sLbl_Sel.Text    = "Selection: " .. selStr

            local orbStr = OrbitActive and ("ON  |  " .. CurrentMode) or "PAUSED"
            sLbl_Orbit.Text  = "Orbit: " .. orbStr
            sLbl_Orbit.TextColor3 = OrbitActive
                and Color3.fromRGB(80,255,140) or Color3.fromRGB(255,200,80)
        end)
    end
end)

print("[B.R.I.C.K.S v2 Fixed] Loaded — Anti-Wiggle & Centering Calibrated")
