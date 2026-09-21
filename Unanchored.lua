--[[
    ========================================================
    B.R.I.C.K.S v2 — Fixed & Optimized (Anti-Wiggle Edition)
    Real FE Physics Engine | Block Selection | Ball | Door
    ========================================================
    FIXES APPLIED:
    • ELIMINATED BLOCK WIGGLING & ROTATING:
      - Removed forced tumble rotation Vector3.new(0.04, 0.04, 0.04)
      - Active angular damping stops all random spinning
      - Tuned linear PD controller with smooth proximity damping
      - Clean, rock-steady orbit and staging physics
    • SHARK MORPH CENTERED ON BODY:
      - Anchored to player's torso center (not down at feet)
      - Balanced vertical offsets and natural camera framing
    • STICKMAN MORPH FOOT-ANCHORED:
      - Entire stickman elevated by FOOT_OFFSET so player stands
        directly at the stickman's feet rather than inside pelvis
    ========================================================
--]]

-- ============================================================
-- [1] SERVICES & STATE
-- ============================================================
local P   = game:GetService("Players")
local R   = game:GetService("RunService")
local T   = game:GetService("TeleportService")
local UIS = game:GetService("UserInputService")
local RS  = game:GetService("ReplicatedStorage")

local L   = P.LocalPlayer
local M   = L:GetMouse()
local Cam = workspace.CurrentCamera

-- Claimed parts pool
local CP = {}

-- Active connections
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
    DrivePartFE — moves a part toward targetCF using velocity only.
    Spring-damper formula:
      desired_velocity = error * K_SPRING - current_velocity * K_DAMP
    With network ownership this velocity IS replicated to all players.
--]]
local function DrivePartFE(part, targetCF, dt, useRot)
    if not part or not part.Parent or part.Anchored then return end
    part.CanCollide = false

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

    -- Smooth critical damping near target to eliminate micro-jitter and wobble
    local desired = (err * K_SPRING) - (vel * K_DAMP)
    local spd     = desired.Magnitude
    if spd > MAX_VEL then desired = desired * (MAX_VEL / spd) end

    -- Keep linear velocity rock-steady without arbitrary vertical bias
    if dist < 0.05 and vel.Magnitude < 0.25 then
        part.AssemblyLinearVelocity = Vector3.zero
    else
        part.AssemblyLinearVelocity = desired
    end

    if useRot then
        -- Drive rotation cleanly toward target orientation using damped angular spring
        local relRot      = part.CFrame:ToObjectSpace(targetCF)
        local rx, ry, rz  = relRot:ToEulerAnglesXYZ()
        local angVel      = part.AssemblyAngularVelocity
        part.AssemblyAngularVelocity = (Vector3.new(rx, ry, rz) * K_ROT) - (angVel * K_ROT_DAMP)
    else
        -- FIX: Actively damp all angular velocity to ZERO.
        -- Previously this forced Vector3.new(0.04, 0.04, 0.04) every frame,
        -- which caused all blocks to constantly spin, tumble, and wiggle!
        local angVel = part.AssemblyAngularVelocity
        if angVel.Magnitude > 0.001 then
            part.AssemblyAngularVelocity = -angVel * 0.85
        else
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
