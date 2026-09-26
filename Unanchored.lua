--[[
    ========================================================
    B.R.I.C.K.S v2 - created by Sofi
    Real FE Physics Engine | Block Selection | Ball | Door
    ========================================================
    CHANGES:
    * Velocity-only FE (spring-damper, no fake client CFrame)
    * Tap-to-Claim + Claim-All toggle for block selection
    * Orbit master ON/OFF toggle
    * NO character invisibility in any orbit mode
    * NO paint calls inside orbit loops (only Paint/Rainbow btns)
    * Stealth paint tool (hidden equip, still fires remotes)
    * BALL orbit: sphere shell, bounce on land, forward roll
    * DOOR tool: velocity-driven door, proximity open/close
    * Stickman sit/laydown snaps to actual ground surface
    * Fixed wiggle bug (tuned PD, unique positions per block)
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
-- Extra panels that hide when mode changes (populated by each mode's setup)
local ModePanels    = {}  -- {panelFrame, modeName}
-- Forward declarations so SWITCH_MODE can reset them before Titanic section runs
local TitanicDirOn  = false
local TitanicFwdOn  = false
local TitanicAnchored = false
local TitanicSpd    = 18

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
-- [2] FE PHYSICS CORE
--     All part movement uses velocity (spring-damper).
--     This replicates to the server via network ownership.
--     K_SPRING / K_DAMP tuned to eliminate wiggle.
-- ============================================================
local K_SPRING  = 12     -- lower = smoother, less overshoot
local K_DAMP    = 0.78   -- higher = more damped, less oscillation
local MAX_VEL   = 75     -- hard cap prevents teleport artifacts
local K_ROT     = 8      -- angular spring constant

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
    DrivePartFE - moves a part toward targetCF using velocity only.
    Spring-damper formula:
      desired_velocity = error * K_SPRING  -  current_velocity * K_DAMP
    With network ownership this velocity IS replicated to all players.
    Pass useRot=true for chain/snake modes that need directional alignment.
--]]
local function DrivePartFE(part, targetCF, dt, useRot, keepCollide)
    if not part or not part.Parent then return end
    if not keepCollide then part.CanCollide = false end
    part.Anchored   = false

    --[[
        WHY BLOCKS JITTER - and the fix:
        Setting AssemblyLinearVelocity = delta * big_number creates a large force
        that fights the CFrame every single frame. The block gets pushed by velocity,
        then snapped back by CFrame, then pushed again -> rapid oscillation = jitter.
        Setting any non-zero AssemblyAngularVelocity makes blocks spin every frame.

        Fix:
          - Angular velocity = ZERO  (eliminates all spinning/rotation)
          - Linear velocity  = tiny upward only  (anti-sleep, NOT a drive force)
          - Movement via CFrame lerp alone  (one clean force, no conflicts)
          - Alpha = 0.12  (conservative, no overshoot or snapping back)
    --]]

    part.AssemblyAngularVelocity = Vector3.zero             -- no spin at all
    part.AssemblyLinearVelocity  = Vector3.new(0, 0.04, 0) -- keep-alive only

    pcall(function()
        if sethiddenproperty then
            sethiddenproperty(part, "NetworkIsSleeping", false)
        end
    end)

    -- Smooth lerp: conservative alpha prevents overshoot and snap-back
    local alpha = math.clamp(BlockSpeed / 400, 0.05, 0.18)
    part.CFrame  = part.CFrame:Lerp(targetCF, alpha)

    -- Emergency pull-back if part has fallen or drifted out of range
    local root = L.Character and L.Character:FindFirstChild("HumanoidRootPart")
    if root and (part.Position - root.Position).Magnitude > 110 then
        part.CFrame                 = root.CFrame * CFrame.new(0, STAGE_ALT, 0)
        part.AssemblyLinearVelocity = Vector3.new(0, 0.04, 0)
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
    -- Exclude placed door so orbits do not re-claim it (prevents door jitter)
    if DoorPlacedPart and o == DoorPlacedPart then return false end
    return true
end

-- ============================================================
-- [4] GUI  - Main frame, header, scrolling buttons
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
bic.Text, bic.TextColor3 = "B", Color3.fromRGB(220,180,255)
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
TitleLbl.Text              = "B.R.I.C.K.S v2 - Sofi"
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
local MinBtn   = MakeHdrBtn(-50, "-", Color3.fromRGB(70,50,140))
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

-- -- Stats Panel ----------------------------------------------
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
local sLbl_Orbit  = StatLbl(30, "Orbit: ON  |  Mode: None",
    Color3.fromRGB(80,255,140))
local sLbl_Sel    = StatLbl(44, "Selection: OFF",
    Color3.fromRGB(200,200,255))
local sLbl_Plrs   = StatLbl(62, "Players: 0")

-- -- Block Claiming -------------------------------------------
local BtnClaimAll  = BTN("Claim All Blocks: OFF",  Color3.fromRGB(30,110,175))
local BtnTapClaim  = BTN(" Tap-to-Claim: OFF",       Color3.fromRGB(55,55,90))
local BtnRelease   = BTN(" Release All Claimed",      Color3.fromRGB(110,35,35))

-- -- Orbit Master Toggle --------------------------------------
local BtnOrbitToggle = BTN("Orbit: ON",              Color3.fromRGB(30,155,70))

-- -- Settings -------------------------------------------------
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

-- -- RGB Color Picker -----------------------------------------
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

-- -- Target input ---------------------------------------------
local TargetF = Instance.new("Frame", SF)
TargetF.Size, TargetF.BackgroundTransparency = UDim2.new(1,-4,0,24), 1
TargetF.LayoutOrder = btnOrder; btnOrder = btnOrder + 1

local WI = Instance.new("TextBox", TargetF)
WI.Size, WI.BackgroundColor3 = UDim2.new(1,0,1,0), Color3.fromRGB(36,36,46)
WI.TextColor3, WI.TextSize, WI.Font = Color3.new(1,1,1), 8.5, Enum.Font.GothamMedium
WI.Text, WI.PlaceholderText = "", "Target Player (blank = self)"
Instance.new("UICorner", WI).CornerRadius = UDim.new(0, 4)

-- -- Mode buttons ---------------------------------------------
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
    local want = (StickAnim ~= "wave") and "wave" or "walk"
    ResetStickBtns()   -- resets StickAnim to "walk" and clears all buttons
    if want == "wave" then
        StickAnim = "wave"
        BtnWave.Text = "Wave: ON"
        BtnWave.BackgroundColor3 = Color3.fromRGB(40,170,80)
    end
end)
BtnSit.MouseButton1Click:Connect(function()
    local want = (StickAnim ~= "sit") and "sit" or "walk"
    ResetStickBtns()
    if want == "sit" then
        StickAnim = "sit"
        BtnSit.Text = "Sit: ON"
        BtnSit.BackgroundColor3 = Color3.fromRGB(40,140,210)
    end
end)
BtnLayDown.MouseButton1Click:Connect(function()
    local want = (StickAnim ~= "lay_down") and "lay_down" or "walk"
    ResetStickBtns()
    if want == "lay_down" then
        StickAnim = "lay_down"
        BtnLayDown.Text = "Lay Down: ON"
        BtnLayDown.BackgroundColor3 = Color3.fromRGB(150,50,170)
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
--     Equips the paint tool once (hiding handle & grip) then
--     fires all paint remotes.  Tool is NEVER visually shown.
-- ============================================================
local function GetPaintTool()
    local char = L.Character
    local bp   = L:FindFirstChildOfClass("Backpack")
    local containers = {}
    if char then table.insert(containers, char) end
    if bp   then table.insert(containers, bp)   end

    -- Name keyword search first
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
    -- Fallback: any tool containing a RemoteEvent
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

-- Keep tool hidden every frame when paint/rainbow is on
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
    -- Apply instantly on client
    pcall(function() part.Color = color; part.BrickColor = BrickColor.new(color) end)

    local tool     = StealthEquip()
    if not tool then return end
    local brickCol = BrickColor.new(color)
    local pos      = part.Position

    for _, child in ipairs(tool:GetDescendants()) do
        if child:IsA("RemoteEvent") then
            pcall(function()
                child:FireServer(part, Enum.NormalId.Top, pos, "both |handshake|", color, "smooth","")
            end)
            pcall(function()
                child:FireServer(part, Enum.NormalId.Top, pos, "both |handshake|", brickCol, "smooth","")
            end)
            pcall(function() child:FireServer(part, color)    end)
            pcall(function() child:FireServer(part, brickCol) end)
            for _, side in ipairs(SidesList) do
                pcall(function()
                    child:FireServer(part, side, pos, "both |handshake|", color, "smooth","")
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
    -- Prune dead / anchored / invalid parts
    local kept = {}
    for _, p in ipairs(CP) do
        if p and p.Parent and VLD(p) then
            table.insert(kept, p)
        end
    end
    CP = kept

    if not ClaimAllOn then return end

    -- Scan workspace for new unclaimed unanchored parts
    local existSet = {}
    for _, p in ipairs(CP) do existSet[p] = true end

    -- Priority: dedicated folders first
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

    -- General workspace scan
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
        and "Claim All: ON (Scanning)"
        or  "Claim All Blocks: OFF"
    BtnClaimAll.BackgroundColor3 = ClaimAllOn
        and Color3.fromRGB(30,175,75)
        or  Color3.fromRGB(30,110,175)
    if ClaimAllOn then RefreshCP() end
end)

BtnTapClaim.MouseButton1Click:Connect(function()
    TapClaimOn = not TapClaimOn
    BtnTapClaim.Text = TapClaimOn
        and " Tap-to-Claim: ON"
        or  " Tap-to-Claim: OFF"
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
    BtnClaimAll.Text            = "Claim All Blocks: OFF"
    BtnClaimAll.BackgroundColor3 = Color3.fromRGB(30,110,175)
end)

-- Tap/click to claim a specific block
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
-- [9] STAGING HOLD  (blocks float safely around the player
--     when no mode is active OR orbit is paused)
-- ============================================================
local function HoldInStaging()
    if StagingConn then StagingConn:Disconnect(); StagingConn = nil end
    StagingConn = R.RenderStepped:Connect(function(dt)
        -- Only stage when orbit is off or no mode is running
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
                DrivePartFE(part, CFrame.new(tPos), dt)
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
        AnimPanel.Visible, AnimTitle.Text = true, "Animations - Stickman"
        SBFrame.Visible, ShFrame.Visible  = true, false
    elseif name == "Shark" then
        AnimPanel.Visible, AnimTitle.Text = true, "Animations - Shark"
        SBFrame.Visible, ShFrame.Visible  = false, true
    else
        AnimPanel.Visible = false
        SBFrame.Visible, ShFrame.Visible = false, false
    end
    -- Hide / show any extra registered mode panels (e.g. Titanic)
    for _, mp in ipairs(ModePanels) do
        if mp[1] and mp[1].Parent then
            mp[1].Visible = (name == mp[2])
        end
    end
    -- Reset mode-specific state when leaving that mode
    if name ~= "Titanic" then
        TitanicDirOn  = false
        TitanicFwdOn  = false
    end

    -- Reset camera POV cleanly
    local Hum = L.Character and L.Character:FindFirstChildOfClass("Humanoid")
    if Hum then Hum.CameraOffset = Vector3.zero end
    Cam.CameraType = Enum.CameraType.Custom

    CurrentMode  = name
    OrbitActive  = true
    BtnOrbitToggle.Text            = "Orbit: ON"
    BtnOrbitToggle.BackgroundColor3 = Color3.fromRGB(30,155,70)
end

local function STOP()
    SWITCH_MODE("None")
    HoldInStaging()
end

BtnStop.MouseButton1Click:Connect(STOP)

-- Orbit master toggle
BtnOrbitToggle.MouseButton1Click:Connect(function()
    OrbitActive = not OrbitActive
    BtnOrbitToggle.Text = OrbitActive and "Orbit: ON" or "Orbit: OFF (Staged)"
    BtnOrbitToggle.BackgroundColor3 = OrbitActive
        and Color3.fromRGB(30,155,70) or Color3.fromRGB(120,50,50)
    if not OrbitActive then
        HoldInStaging()
    else
        -- Resume: disconnect staging, the mode's AC loop will pick up next frame
        if StagingConn then StagingConn:Disconnect(); StagingConn = nil end
    end
end)

-- ============================================================
-- [11] NO-COLLISION + NETWORK KEEPALIVE (every Stepped frame)
-- ============================================================
R.Stepped:Connect(function()
    local char = L.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then hrp.CanCollide = false end
    end
    for _, part in ipairs(CP) do
        if part and part.Parent and not part.Anchored then
            if CurrentMode ~= "Titanic" then
                part.CanCollide = false  -- Titanic keeps CanCollide=true for riding
            end
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
-- [13] HOLLOW PURPLE  (FE, server-replicated colors & physics)
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
            -- Phase 1: Blue vortex + Red vortex orbiting each other
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
                        DrivePartFE(prt, CFrame.new(RootPos+off), dt)
                    else
                        if doColor then FirePaint(prt, Color3.fromRGB(255,30,45)) end
                        local ang = -spd + i*(math.pi*2/math.max(1,total-half))
                        local off = Vector3.new(
                            math.cos(ang)*6*conv - 4*conv,
                            2 + math.sin(ang*2)*(2*conv),
                            math.sin(ang)*6*conv)
                        DrivePartFE(prt, CFrame.new(RootPos+off), dt)
                    end
                end
            end

        elseif elapsed < 2.2 then
            -- Phase 2: Fuse into purple sphere
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
                        dt)
                end
            end

        else
            -- Phase 3: Blast
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
                    prt.AssemblyAngularVelocity = Vector3.new(0.5,0.5,0.5)
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
-- [16] SHARK MORPH  (no character hiding)
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

    -- (paint removed: shark uses block original colors)

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

        local baseCF = Root.CFrame
        if SharkPetOrbit then
            local ang = sharkT*1.3
            local heading = -ang + math.pi/2
            baseCF = Root.CFrame
                * CFrame.new(math.cos(ang)*SharkPetRadius, 0, math.sin(ang)*SharkPetRadius)
                * CFrame.Angles(0, heading, 0)
            local Hum2 = C and C:FindFirstChildOfClass("Humanoid")
            if Hum2 then Hum2.CameraOffset = Vector3.zero end
        else
            Hum.CameraOffset = Vector3.new(0,8,0)
        end

        for i, prt in ipairs(CP) do
            if prt and prt.Parent then
                local off = offsets[i] or Vector3.zero
                DrivePartFE(prt, baseCF * CFrame.new(off), dt)

            end
        end
    end)
end)

-- ============================================================
-- [17] STICKMAN MORPH  (fixed ground-snap for sit / lay_down)
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

        -- Ground-relative Y for sit/lay_down
        -- localGround = 0 means ground surface (offset from Root.Position)
        local groundY    = GetFloorY(Root.Position, C)
        local localGnd   = groundY - Root.Position.Y  -- typically ~-2.5

        local anim = StickAnim
        if anim == "sit" and moving then anim = "walk" end

        local headCenter, neck, pelvis
        local leftHand, rightHand, leftFoot, rightFoot

        if anim == "lay_down" then
            -- Lie flat at ground level, body along facing direction
            local g = localGnd + 0.6   -- just above ground
            headCenter = Vector3.new(0, g,     -9.0)
            neck       = Vector3.new(0, g,     -5.0)
            pelvis     = Vector3.new(0, g,      3.0)
            local breath = math.sin(animT*3)*0.2
            neck = neck + Vector3.new(0, breath, 0)
            leftHand  = neck   + Vector3.new(-4.5, 0,  1.0)
            rightHand = neck   + Vector3.new( 4.5, 0,  1.0)
            leftFoot  = pelvis + Vector3.new(-3.0, 0,  9.0)
            rightFoot = pelvis + Vector3.new( 3.0, 0,  9.0)

        elseif anim == "sit" then
            -- Sitting at ground level, legs folded forward
            local g = localGnd
            pelvis     = Vector3.new(0, g,        0)
            neck       = Vector3.new(0, g + 6.5,  0)
            headCenter = Vector3.new(0, g + 10.5, 0)
            local sway = math.sin(animT*2)*0.15
            leftHand   = pelvis + Vector3.new(-5.0, 2.0, 3.5+sway)
            rightHand  = pelvis + Vector3.new( 5.0, 2.0, 3.5+sway)
            leftFoot   = pelvis + Vector3.new(-3.5, 0,   8.0)
            rightFoot  = pelvis + Vector3.new( 3.5, 0,   8.0)

        elseif state==Enum.HumanoidStateType.Jumping or vel.Y > 2 then
            local pY = localGnd + 11
            headCenter=Vector3.new(0,pY+15,0); neck=Vector3.new(0,pY+11,0); pelvis=Vector3.new(0,pY,0)
            leftHand  = neck + Vector3.new(-10, 8, 2); rightHand = neck + Vector3.new(10, 8, 2)
            leftFoot  = pelvis + Vector3.new(-6,-3, 4); rightFoot = pelvis + Vector3.new(6,-3,-2)

        elseif state==Enum.HumanoidStateType.Freefall or vel.Y < -2 then
            local pY = localGnd + 11
            headCenter=Vector3.new(0,pY+15,0); neck=Vector3.new(0,pY+11,0); pelvis=Vector3.new(0,pY,0)
            leftHand  = neck + Vector3.new(-12,12,-2); rightHand = neck + Vector3.new(12,12,-2)
            leftFoot  = pelvis + Vector3.new(-5,-8,-2); rightFoot = pelvis + Vector3.new(5,-8,2)

        else
            local pY = localGnd + 11   -- pelvis is legLength above ground
            headCenter=Vector3.new(0,pY+15,0); neck=Vector3.new(0,pY+11,0); pelvis=Vector3.new(0,pY,0)
            local cycleSpd = math.clamp(speed*0.8,4,12)
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
            leftFoot  = pelvis + Vector3.new(-4, math.max(-11,-11*math.cos(swing)),  math.sin(swing)*8)
            rightFoot = pelvis + Vector3.new( 4, math.max(-11,-11*math.cos(-swing)), math.sin(-swing)*8)
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

                -- When many blocks map to the same skeleton point,
                -- spread them in a tiny spiral so they don't stack and fight
                local repeat_n  = math.floor((i-1)/skelLen)
                local spiralAng = repeat_n * 2.1
                local spiralR   = repeat_n * 0.35
                local spreadOff = Vector3.new(
                    math.cos(spiralAng)*spiralR, 0,
                    math.sin(spiralAng)*spiralR)

                local worldPos = (rootCF * CFrame.new(off + spreadOff)).Position
                DrivePartFE(prt, CFrame.new(worldPos), dt)
            end
        end

        Hum.CameraOffset = Vector3.new(0, localGnd + 22, 0)
    end)
end)

-- ============================================================
-- [18] BALL ORBIT  (sphere shell, bounce on land, forward roll)
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
    local spinAngle   = 0      -- slow yaw spin
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

        -- Bounce impulse when landing
        if grounded and not wasGrounded then
            bounceVel = 4.5
        end
        wasGrounded = grounded

        -- Simulate vertical bounce (simple damped spring)
        bounceVel = bounceVel - 20*dt          -- gravity pull
        bounceY   = bounceY   + bounceVel*dt
        if bounceY <= 0 then
            bounceY   = 0
            bounceVel = math.abs(bounceVel)*0.45  -- bounce damping
            if math.abs(bounceVel) < 0.5 then bounceVel = 0 end
        end

        -- Roll: sphere rolls in the direction of horizontal movement
        if speed > 0.3 then
            local ballR = 6.0
            rollAngle   = rollAngle - (speed*dt)/ballR   -- negated = rolls toward facing direction
            if horizVel.Magnitude > 0.01 then
                -- Perpendicular axis to movement direction = roll axis
                local moveDir = horizVel.Unit
                rollAxis = Vector3.new(-moveDir.Z, 0, moveDir.X).Unit
            end
        end

        spinAngle = spinAngle + dt*0.35   -- slow ambient yaw

        local total    = math.max(1, #CP)
        local ballR    = 6.0 + math.sin(ballT*1.5)*0.15  -- tiny pulse
        local center   = Root.Position + Vector3.new(0, bounceY, 0)
        local spinCF   = CFrame.Angles(0, spinAngle, 0)
        local rollCF   = CFrame.fromAxisAngle(rollAxis, rollAngle)

        for i, prt in ipairs(CP) do
            if prt and prt.Parent then
                -- Fibonacci sphere distribution for even coverage
                local yn  = 1 - (i/total)*2
                local r2  = math.sqrt(math.max(0, 1-yn*yn))
                local th  = phi * i * math.pi * 2
                local loc = Vector3.new(
                    math.cos(th)*r2*ballR,
                    yn*ballR,
                    math.sin(th)*r2*ballR)

                -- Apply roll then spin
                local rolled = rollCF:VectorToWorldSpace(loc)
                local spun   = spinCF:VectorToWorldSpace(rolled)
                DrivePartFE(prt, CFrame.new(center + spun), dt)
            end
        end
    end)
end)

-- ============================================================
-- [19] DOOR TOOL
--     Claims one block, places it as a velocity-driven door.
--     Door swings open when any player is within 8 studs,
--     closes smoothly when everyone moves away.
-- ============================================================
local DoorAngle     = 0      -- current open angle (radians)
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

    -- Need at least one claimed block
    if #CP == 0 then
        RefreshCP()
        if #CP == 0 then
            BtnDoor.Text = "Door Tool: No blocks claimed!"
            BtnDoor.BackgroundColor3 = Color3.fromRGB(180,50,50)
            DoorActive = false
            return
        end
    end

    -- Holographic preview block follows cursor
    local preview = Instance.new("Part")
    -- Door: 4 wide, 8 tall, thin (faces toward player)
    preview.Name, preview.Anchored    = "DoorPreview", true
    preview.CanCollide, preview.Transparency = false, 0.45
    preview.Size                       = Vector3.new(4, 8, 0.3)  -- width, height, thickness
    preview.Color                      = Color3.fromRGB(80,140,255)
    preview.Material                   = Enum.Material.Neon
    preview.Parent                     = workspace

    -- Preview follows cursor, bottom on ground, faces player direction
    DoorPreviewConn = R.RenderStepped:Connect(function()
        if not DoorActive or not preview.Parent then
            DoorPreviewConn:Disconnect(); DoorPreviewConn = nil; return
        end
        local h   = M.Hit
        -- Snap XZ position, use actual Y + lift so bottom of door is at ground
        local snp = Vector3.new(
            math.round(h.Position.X),
            h.Position.Y + 4,   -- lift by half height (8/2=4) so bottom = cursor
            math.round(h.Position.Z))
        -- Door faces perpendicular to player's look direction
        local hrp = L.Character and L.Character:FindFirstChild("HumanoidRootPart")
        local fwd = hrp and Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z).Unit
                         or Vector3.new(0,0,-1)
        preview.CFrame = CFrame.lookAt(snp, snp + fwd)
    end)

    -- Place door only on genuine TAP (TouchTap on mobile avoids false swipe triggers)
    local placeConn
    local doorPlaceFn  -- forward decl
    doorPlaceFn = function()
        if not DoorActive then
            if placeConn then placeConn:Disconnect(); placeConn = nil end
            return
        end

        -- Pop the first claimed block as the door
        local doorPart = CP[1]
        if not doorPart or not doorPart.Parent then
            if placeConn then placeConn:Disconnect(); placeConn = nil end
            CleanupDoor(); return
        end
        -- Remove from pool
        local newCP = {}
        for i, p in ipairs(CP) do if i ~= 1 then table.insert(newCP, p) end end
        CP = newCP

        -- Place door
        local placeCF    = preview.CFrame
        DoorBasePos      = placeCF.Position
        DoorBaseFwd      = placeCF.LookVector
        DoorAngle        = 0
        DoorPlacedPart   = doorPart

        -- Door stands upright: 4 wide, 8 tall, thin
        doorPart.Size       = Vector3.new(4, 8, 0.3)
        doorPart.CanCollide = true
        doorPart.Color      = Color3.fromRGB(140, 100, 60)
        doorPart.Material   = Enum.Material.Wood
        doorPart.CFrame     = placeCF  -- placeCF already has correct Y and orientation

        FirePaint(doorPart, Color3.fromRGB(140, 100, 60))

        pcall(function() preview:Destroy() end)
        if DoorPreviewConn then DoorPreviewConn:Disconnect(); DoorPreviewConn = nil end
        if placeConn then placeConn:Disconnect(); placeConn = nil end
        DoorActive = false
        BtnDoor.Text = "Door Tool: OFF  (Door placed!)"
        BtnDoor.BackgroundColor3 = Color3.fromRGB(80,80,140)

        -- Hinge = left vertical edge of door in LOCAL door space
        -- Door width is 4 in X, so left edge = X = -2
        local hingeLocalOffset = Vector3.new(-2, 0, 0)

        DoorAngle = 0
        local prevAngle = 0

        DoorConn = R.RenderStepped:Connect(function(dt)
            if not doorPart or not doorPart.Parent then
                DoorConn:Disconnect(); DoorConn = nil; return
            end

            -- Open when any player is within 8 studs
            local anyNear = false
            for _, pl in ipairs(P:GetPlayers()) do
                local plHrp = pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
                if plHrp and (plHrp.Position - doorPart.Position).Magnitude < 8 then
                    anyNear = true; break
                end
            end
            local targetAngle = anyNear and (-math.pi/2) or 0

            -- Smooth swing
            DoorAngle = DoorAngle + (targetAngle - DoorAngle) * math.min(dt * 5, 1)

            --[[
                Hinge pivot math (correct door rotation):
                  1. Transform hinge point to world space using ORIGINAL placeCF
                  2. Rotate around the world Y-axis at that pivot by DoorAngle
                  3. The door center = pivot + door's local (+X * 2) in the rotated frame
                This keeps the hinge edge fixed and swings the door correctly.
            --]]
            local pivotWorld = placeCF * CFrame.new(hingeLocalOffset)
            local swingCF    = pivotWorld * CFrame.Angles(0, DoorAngle, 0)
            local doorCF     = swingCF   * CFrame.new(-hingeLocalOffset)

            doorPart.CanCollide = true
            doorPart.Anchored   = false

            -- Move to doorCF using lerp (smooth, no snapping)
            local alpha = math.min(dt * 12, 1)
            doorPart.CFrame = doorPart.CFrame:Lerp(doorCF, alpha)

            local angSpd = (DoorAngle - prevAngle) / math.max(dt, 0.001)
            doorPart.AssemblyAngularVelocity = Vector3.new(0, angSpd * 0.8, 0)
            doorPart.AssemblyLinearVelocity  = Vector3.new(0, 0.02, 0)
            prevAngle = DoorAngle

            pcall(function()
                if sethiddenproperty then
                    sethiddenproperty(doorPart, "NetworkIsSleeping", false)
                end
            end)
        end)
    end  -- doorPlaceFn
    -- Wire to TouchTap on mobile (no swipe false-positives) or Mouse on desktop
    if UIS.TouchEnabled then
        placeConn = UIS.TouchTap:Connect(function(positions, gpe)
            if gpe or not DoorActive then return end
            doorPlaceFn()
        end)
    else
        placeConn = M.Button1Down:Connect(function()
            doorPlaceFn()
        end)
    end
end)

-- ============================================================
-- [20] STANDARD ORBIT MODES  (no paint calls in loops)
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
                DrivePartFE(prt, CFrame.new(ctr+off), dt)
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
            DrivePartFE(Barrel, CFrame.new(ctr+Vector3.new(2,2,-2), M.Hit.Position), dt)
        end
        local root   = L.Character and L.Character:FindFirstChild("HumanoidRootPart")
        local stgPos = root and root.Position+Vector3.new(0,STAGE_ALT,0) or ctr
        for i=2,#CP do
            local b = CP[i]
            if b and b.Parent then
                DrivePartFE(b, CFrame.new(stgPos+Vector3.new((i%5)*2,0,math.floor(i/5)*2)), dt)
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
                Bullet.AssemblyAngularVelocity  = Vector3.new(0.5,0.5,0.5)
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
                    math.cos(ang)*6*side, y2+10, math.sin(ang)*6*side)), dt)
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
                    math.cos(ang)*r2, h, math.sin(ang)*r2)), dt)
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
                DrivePartFE(prt, CFrame.new(tPos + Vector3.new(0,2,0)), dt)
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
                    math.cos(CA)*D, (i*0.1)%15, math.sin(CA)*D)), dt)
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
                    math.sin(i+t)*30, 40+(i%20), math.cos(i+t)*30)), dt)
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
                    math.cos(theta)*r2, yn*12+2, math.sin(theta)*r2)), dt)
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
                    math.cos(ang)*5, (i%3)*2, math.sin(ang)*5)), dt)
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

-- Keyboard GUI toggle
UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == ToggleKey then
        F.Visible  = not F.Visible
        BallBtn.Visible = not F.Visible
    end
end)

-- ============================================================
-- [24] BACKGROUND LOOP  - stats + periodic refresh
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


-- ============================================================
-- [T] TITANIC ORBIT
--     Blocks form a Titanic ship shape in FRONT of the player.
--     CanCollide = true so players can walk/sit on it.
--     Mini GUI: Direction track + Forward movement.
-- ============================================================

-- Titanic block offset table (ship faces -Z = forward, bow = -Z)
local function BuildTitanicOffsets(total)
    local o = {}
    local n = 1
    local function add(v) if n <= total then o[n]=v; n=n+1 end end

    -- KEEL (spine along bottom)
    for i=0,9 do add(Vector3.new(0,-5,-24+i*5)) end
    -- HULL PORT (left side)
    for i=0,7 do add(Vector3.new(-5,-2,-20+i*5)) end
    -- HULL STARBOARD (right side)
    for i=0,7 do add(Vector3.new( 5,-2,-20+i*5)) end
    -- MAIN DECK top
    for i=0,7 do add(Vector3.new(0, 0,-18+i*4)) end
    -- BOW
    add(Vector3.new(0,-1,-25)); add(Vector3.new(0,-3,-27)); add(Vector3.new(0,-4,-28))
    add(Vector3.new(-2,-2,-26)); add(Vector3.new(2,-2,-26))
    -- STERN
    add(Vector3.new(0,-1,27)); add(Vector3.new(0,-3,28))
    add(Vector3.new(-2,-3,27)); add(Vector3.new(2,-3,27))
    -- SUPERSTRUCTURE center rows
    for i=0,7 do add(Vector3.new(0,4,-10+i*3)) end
    add(Vector3.new(-3,3,-5)); add(Vector3.new(3,3,-5))
    add(Vector3.new(-3,3, 5)); add(Vector3.new(3,3, 5))
    add(Vector3.new(-3,3,15)); add(Vector3.new(3,3,15))
    -- Upper promenade
    for i=0,4 do add(Vector3.new(0,7,-6+i*4)) end
    -- 4 FUNNELS (3 blocks each, z: -8, 0, 8, 16)
    for _,fz in ipairs({-8,0,8,16}) do
        add(Vector3.new(0, 9,fz))
        add(Vector3.new(0,14,fz))
        add(Vector3.new(0,19,fz))
    end
    -- BRIDGE
    add(Vector3.new( 0,7,-15)); add(Vector3.new(-2,8,-15))
    add(Vector3.new( 2,8,-15)); add(Vector3.new( 0,10,-15))
    -- FORWARD MAST
    add(Vector3.new(0, 7,-23)); add(Vector3.new(0,13,-23))
    add(Vector3.new(0,19,-23)); add(Vector3.new(0,25,-23))
    -- AFT MAST
    add(Vector3.new(0, 7,20)); add(Vector3.new(0,13,20)); add(Vector3.new(0,18,20))
    -- LIFEBOATS (both sides)
    for i=0,3 do
        add(Vector3.new(-5,3,-5+i*4))
        add(Vector3.new( 5,3,-5+i*4))
    end
    -- PROPELLERS
    add(Vector3.new(0,-6,25)); add(Vector3.new(-3,-5,25)); add(Vector3.new(3,-5,25))
    -- Hull fill for remaining blocks
    while n<=total do
        local t=((n-1)%30)/30; local z=-22+t*44
        local row=math.floor((n-1)/30)
        local x=((row%3)-1)*3; local y=(row%3)-3
        o[n]=Vector3.new(x,y,z); n=n+1
    end
    return o
end

-- Titanic GUI
local TitanicPanel = Instance.new("Frame", S)
TitanicPanel.Name             = "TitanicPanel"
TitanicPanel.Size             = UDim2.new(0,155,0,110)
TitanicPanel.Position         = UDim2.new(0,228,0,220)
TitanicPanel.BackgroundColor3 = Color3.fromRGB(18,22,34)
TitanicPanel.BorderSizePixel  = 0
TitanicPanel.Visible          = false
TitanicPanel.Active           = true
TitanicPanel.Draggable        = true
table.insert(ModePanels, {TitanicPanel, "Titanic"})  -- auto-shown by SWITCH_MODE
Instance.new("UICorner", TitanicPanel).CornerRadius = UDim.new(0,8)
local tpStroke = Instance.new("UIStroke", TitanicPanel)
tpStroke.Color, tpStroke.Thickness = Color3.fromRGB(60,100,180), 1.3

local TPTitle = Instance.new("TextLabel", TitanicPanel)
TPTitle.Size               = UDim2.new(1,0,0,24)
TPTitle.BackgroundColor3   = Color3.fromRGB(28,38,60)
TPTitle.BorderSizePixel    = 0
TPTitle.TextColor3         = Color3.fromRGB(180,210,255)
TPTitle.TextSize, TPTitle.Font = 9, Enum.Font.GothamBold
TPTitle.Text               = "TITANIC"
Instance.new("UICorner", TPTitle).CornerRadius = UDim.new(0,8)

local TPList = Instance.new("Frame", TitanicPanel)
TPList.Size, TPList.Position, TPList.BackgroundTransparency =
    UDim2.new(1,-10,1,-32), UDim2.new(0,5,0,28), 1
local tpLayout = Instance.new("UIListLayout", TPList)
tpLayout.Padding, tpLayout.SortOrder = UDim.new(0,5), Enum.SortOrder.LayoutOrder

local function TBTN(txt, col)
    local b = Instance.new("TextButton", TPList)
    b.Size, b.BackgroundColor3 = UDim2.new(1,0,0,24), col
    b.TextColor3, b.TextSize, b.Font = Color3.new(1,1,1), 9, Enum.Font.GothamMedium
    b.Text = txt
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,4)
    return b
end

local BtnTitanicDir = TBTN("Direction Track: OFF", Color3.fromRGB(50,70,130))
local BtnTitanicFwd = TBTN(">> Forward (Hold)",    Color3.fromRGB(35,120,60))
local BtnTitanicStop= TBTN("Anchor Ship",          Color3.fromRGB(110,40,40))

-- Titanic state (flags declared at top for SWITCH_MODE access)
local titanicCF       = CFrame.new(0,0,0)
local titanicOffsets  = {}

BtnTitanicDir.MouseButton1Click:Connect(function()
    TitanicDirOn = not TitanicDirOn
    BtnTitanicDir.Text = TitanicDirOn and "Direction Track: ON" or "Direction Track: OFF"
    BtnTitanicDir.BackgroundColor3 = TitanicDirOn
        and Color3.fromRGB(40,160,80) or Color3.fromRGB(50,70,130)
end)

BtnTitanicFwd.MouseButton1Click:Connect(function()
    TitanicFwdOn    = not TitanicFwdOn
    TitanicAnchored = false
    BtnTitanicFwd.Text = TitanicFwdOn and "|| Pause Forward" or ">> Forward (Hold)"
    BtnTitanicFwd.BackgroundColor3 = TitanicFwdOn
        and Color3.fromRGB(200,130,30) or Color3.fromRGB(35,120,60)
end)

BtnTitanicStop.MouseButton1Click:Connect(function()
    TitanicAnchored = true
    TitanicFwdOn    = false
    BtnTitanicFwd.Text = ">> Forward (Hold)"
    BtnTitanicFwd.BackgroundColor3 = Color3.fromRGB(35,120,60)
    BtnTitanicStop.Text = "Anchored"
    BtnTitanicStop.BackgroundColor3 = Color3.fromRGB(160,50,50)
    task.delay(0.8, function()
        BtnTitanicStop.Text = "Anchor Ship"
        BtnTitanicStop.BackgroundColor3 = Color3.fromRGB(110,40,40)
        TitanicAnchored = false
    end)
end)

-- Button in main scrolling frame
local BtnTitanic = BTN("Titanic Ship Orbit", Color3.fromRGB(25,60,130))

BtnTitanic.MouseButton1Click:Connect(function()
    SWITCH_MODE("Titanic")
    RefreshCP()
    if #CP == 0 then return end

    -- Compute ship offsets scaled to block count
    titanicOffsets = BuildTitanicOffsets(#CP)
    TitanicDirOn, TitanicFwdOn, TitanicAnchored = false, false, false

    -- Spawn Titanic in front of the player (not on them)
    local Root = L.Character and L.Character:FindFirstChild("HumanoidRootPart")
    if not Root then return end
    local lv    = Vector3.new(Root.CFrame.LookVector.X, 0, Root.CFrame.LookVector.Z)
    if lv.Magnitude < 0.01 then lv = Vector3.new(0,0,1) else lv = lv.Unit end
    -- Place ship 45 studs ahead so player stands at the stern, not inside
    local spawn = Root.Position + lv * 45 + Vector3.new(0,-3,0)
    -- CFrame.lookAt makes LookVector = lv (ship faces exact same direction as player)
    titanicCF   = CFrame.lookAt(spawn, spawn + lv)

    TitanicPanel.Visible = true

    AC = R.RenderStepped:Connect(function(dt)
        if not OrbitActive then return end
        local C     = L.Character
        local Root2 = C and C:FindFirstChild("HumanoidRootPart")
        if not Root2 then return end

        -- Direction tracking: rotate ship to face player's look direction
        if TitanicDirOn then
            local lv2    = Root2.CFrame.LookVector
            local flatLv = Vector3.new(lv2.X, 0, lv2.Z)
            if flatLv.Magnitude > 0.01 then
                titanicCF = CFrame.lookAt(titanicCF.Position,
                    titanicCF.Position + flatLv.Unit)
            end
        end

        -- Forward movement: CFrame + Vector3 preserves rotation perfectly
        if TitanicFwdOn and not TitanicAnchored then
            titanicCF = titanicCF + titanicCF.LookVector * TitanicSpd * dt
        end

        -- Ground collision: keep keel above terrain / anchored surfaces
        do
            local grp = RaycastParams.new()
            pcall(function() grp.FilterType = Enum.RaycastFilterType.Exclude end)
            local gfl = {}
            for _, gp in ipairs(CP) do table.insert(gfl, gp) end
            local gc = L.Character
            if gc then table.insert(gfl, gc) end
            pcall(function() grp.FilterDescendantsInstances = gfl end)
            local gRes = workspace:Raycast(
                titanicCF.Position + Vector3.new(0,25,0),
                Vector3.new(0,-80,0), grp)
            if gRes then
                local gY    = gRes.Position.Y
                -- Keel (bottom of hull) is at local Y = -5
                local keelY = (titanicCF * CFrame.new(0,-5,0)).Position.Y
                local lift  = (gY + 2) - keelY
                if lift > 0 then
                    titanicCF = titanicCF + Vector3.new(0, lift, 0)
                end
            end
        end

        local total = #CP
        if total == 0 then return end
        if #titanicOffsets ~= total then
            titanicOffsets = BuildTitanicOffsets(total)
        end

        -- Drive each block toward its Titanic position
        -- CanCollide = true so players can walk/sit on the ship
        for i, prt in ipairs(CP) do
            if prt and prt.Parent then
                prt.CanCollide = true   -- rideable: players can stand on deck
                prt.Anchored   = false
                prt.AssemblyAngularVelocity = Vector3.zero
                prt.AssemblyLinearVelocity  = Vector3.new(0, 0.04, 0)
                pcall(function()
                    if sethiddenproperty then
                        sethiddenproperty(prt, "NetworkIsSleeping", false)
                    end
                end)
                local off    = titanicOffsets[i] or Vector3.zero
                local tCF    = titanicCF * CFrame.new(off)
                local alpha  = math.clamp(BlockSpeed / 400, 0.05, 0.18)
                prt.CFrame   = prt.CFrame:Lerp(tCF, alpha)
                -- Pull back if fallen
                local r2 = L.Character and L.Character:FindFirstChild("HumanoidRootPart")
                if r2 and (prt.Position - titanicCF.Position).Magnitude > 180 then
                    prt.CFrame = titanicCF * CFrame.new(off)
                end
            end
        end
    end)
end)

print("[B.R.I.C.K.S v2] Loaded - created by Sofi")

-- ============================================================
-- [SB] SAVE BUILD + WALK MODE
-- ============================================================

-- ?? Serialization helpers (Agarware-compatible format) ?????
local SB_MatSym = {
    [Enum.Material.SmoothPlastic]="!", [Enum.Material.Plastic]="@",
    [Enum.Material.Brick]="$",         [Enum.Material.WoodPlanks]="%",
    [Enum.Material.Ice]="^",           [Enum.Material.Grass]="&",
    [Enum.Material.Sand]="*",          [Enum.Material.Snow]="(",
    [Enum.Material.Glass]=")",         [Enum.Material.Wood]="-",
    [Enum.Material.Slate]="_",         [Enum.Material.Neon]="?",
    [Enum.Material.Metal]="{",         [Enum.Material.Concrete]="~",
    [Enum.Material.DiamondPlate]="]",  [Enum.Material.Granite]="[",
    [Enum.Material.Marble]="+",        [Enum.Material.Pebble]="=",
}
local SB_SymMat = {}
for m,s in pairs(SB_MatSym) do SB_SymMat[s]=m end

local function SB_ColorHex(c)
    return string.format("%02X%02X%02X",
        math.floor(c.R*255), math.floor(c.G*255), math.floor(c.B*255))
end
local function SB_HexColor(h)
    return Color3.fromRGB(
        tonumber(h:sub(1,2),16) or 0,
        tonumber(h:sub(3,4),16) or 0,
        tonumber(h:sub(5,6),16) or 0)
end

local function SB_Serialize(parts)
    local s = ""
    for _, p in ipairs(parts) do
        if p and p.Parent then
            local mat = SB_MatSym[p.Material] or "!"
            local col = SB_ColorHex(p.Color)
            local sz  = p.Size
            local cf  = p.CFrame
            s = s .. string.format("|%s%s%.0f,%.0f,%.0f.%.3f,%.3f,%.3f|",
                col, mat, sz.X, sz.Y, sz.Z, cf.X, cf.Y, cf.Z)
        end
    end
    return s
end

local function SB_Parse(str)
    local blocks = {}
    for entry in str:gmatch("|([^|]+)|") do
        local col6 = entry:match("^(%x%x%x%x%x%x)")
        if col6 then
            local rest = entry:sub(7)
            local mat  = rest:sub(1,1)
            local nums = rest:sub(2)
            local sx,sy,sz,px,py,pz = nums:match(
                "^([%d%.]+),([%d%.]+),([%d%.]+)%.([%-%.%d]+),([%-%.%d]+),([%-%.%d]+)")
            if sx then
                table.insert(blocks,{
                    color    = SB_HexColor(col6),
                    material = SB_SymMat[mat] or Enum.Material.SmoothPlastic,
                    size     = Vector3.new(tonumber(sx),tonumber(sy),tonumber(sz)),
                    position = Vector3.new(tonumber(px),tonumber(py),tonumber(pz)),
                })
            end
        end
    end
    return blocks
end

-- ?? State ??????????????????????????????????????????????????
local SB_SelectOn  = false
local SB_Selected  = {}           -- part -> true
local SB_Highlights= {}           -- part -> SelectionBox
local SB_Data      = {}           -- saved block data {cf,size,color,material,relCF,part}
local SB_Center    = Vector3.zero
local SB_Ghosts    = {}           -- holographic preview parts
local SB_BuildStr  = ""           -- last serialized string

local WalkOn       = false
local WalkParts    = {}           -- {part, relCF}
local WalkConn     = nil

-- ?? Ghost helpers ???????????????????????????????????????????
local function SB_ClearGhosts()
    for _, g in ipairs(SB_Ghosts) do
        if g and g.Parent then pcall(function() g:Destroy() end) end
    end
    SB_Ghosts = {}
end

local function SB_ShowGhosts()
    SB_ClearGhosts()
    for _, bd in ipairs(SB_Data) do
        local g = Instance.new("Part")
        g.Anchored, g.CanCollide = true, false
        g.Size, g.CFrame         = bd.size, bd.cf
        g.Color, g.Material      = bd.color, Enum.Material.Neon
        g.Transparency           = 0.52
        g.Parent                 = workspace
        local sb = Instance.new("SelectionBox", g)
        sb.Adornee, sb.Color3    = g, Color3.fromRGB(0,190,255)
        sb.LineThickness, sb.SurfaceTransparency = 0.04, 1
        table.insert(SB_Ghosts, g)
    end
end

-- ?? Save Build GUI ??????????????????????????????????????????
local SBPanel = Instance.new("Frame", S)
SBPanel.Name             = "SaveBuildPanel"
SBPanel.Size             = UDim2.new(0,215,0,210)
SBPanel.Position         = UDim2.new(0,230,0,40)
SBPanel.BackgroundColor3 = Color3.fromRGB(14,18,26)
SBPanel.BorderSizePixel  = 0
SBPanel.Active           = true
SBPanel.Draggable        = true
SBPanel.Visible          = false
-- NOTE: SBPanel is user-toggled, not mode-dependent; do NOT add to ModePanels
Instance.new("UICorner", SBPanel).CornerRadius = UDim.new(0,8)
local sbSt = Instance.new("UIStroke", SBPanel)
sbSt.Color, sbSt.Thickness = Color3.fromRGB(0,175,220), 1.3

local SBHdr = Instance.new("Frame", SBPanel)
SBHdr.Size, SBHdr.BackgroundColor3, SBHdr.BorderSizePixel =
    UDim2.new(1,0,0,26), Color3.fromRGB(12,32,52), 0
Instance.new("UICorner", SBHdr).CornerRadius = UDim.new(0,8)
local SBTitle = Instance.new("TextLabel", SBHdr)
SBTitle.Size, SBTitle.Position, SBTitle.BackgroundTransparency =
    UDim2.new(1,-30,1,0), UDim2.new(0,8,0,0), 1
SBTitle.TextColor3, SBTitle.TextSize, SBTitle.Font, SBTitle.TextXAlignment =
    Color3.fromRGB(90,215,255), 10, Enum.Font.GothamBold, Enum.TextXAlignment.Left
SBTitle.Text = "Save Build"
local SBX = Instance.new("TextButton", SBHdr)
SBX.Size, SBX.Position = UDim2.new(0,22,0,22), UDim2.new(1,-25,0,2)
SBX.BackgroundColor3, SBX.TextColor3, SBX.Text = Color3.fromRGB(200,45,45), Color3.new(1,1,1), "X"
SBX.TextSize, SBX.Font, SBX.BorderSizePixel = 10, Enum.Font.GothamBold, 0
Instance.new("UICorner", SBX).CornerRadius = UDim.new(0,4)
SBX.MouseButton1Click:Connect(function() SBPanel.Visible = false end)

local SBList = Instance.new("Frame", SBPanel)
SBList.Size, SBList.Position, SBList.BackgroundTransparency =
    UDim2.new(1,-10,1,-34), UDim2.new(0,5,0,30), 1
local sbLayout = Instance.new("UIListLayout", SBList)
sbLayout.Padding, sbLayout.SortOrder = UDim.new(0,4), Enum.SortOrder.LayoutOrder

local function SBBTN(txt, col)
    local b = Instance.new("TextButton", SBList)
    b.Size, b.BackgroundColor3, b.BorderSizePixel = UDim2.new(1,0,0,25), col, 0
    b.TextColor3, b.TextSize, b.Font = Color3.new(1,1,1), 9, Enum.Font.GothamMedium
    b.Text = txt
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,4)
    return b
end
local function SBLbl(txt, col)
    local l = Instance.new("TextLabel", SBList)
    l.Size, l.BackgroundTransparency, l.BorderSizePixel = UDim2.new(1,0,0,17), 1, 0
    l.TextColor3, l.TextSize, l.Font = col or Color3.fromRGB(150,195,235), 8.5, Enum.Font.GothamMedium
    l.TextXAlignment, l.TextWrapped, l.Text = Enum.TextXAlignment.Left, true, txt
    return l
end

local BtnSBSelect = SBBTN("Select Blocks: OFF",       Color3.fromRGB(35,55,95))
local SBCountLbl  = SBLbl("Selected: 0 blocks",       Color3.fromRGB(120,185,255))
local BtnSBSave   = SBBTN("Save Selected",             Color3.fromRGB(28,120,72))
local BtnSBImport = SBBTN("Show Hologram",             Color3.fromRGB(130,85,18))
local BtnSBWalk   = SBBTN("Walk Mode: OFF",            Color3.fromRGB(75,25,110))
local BtnSBClear  = SBBTN("Clear All",                 Color3.fromRGB(95,25,25))
local SBStatusLbl = SBLbl("No build saved",            Color3.fromRGB(100,150,200))

-- Button in main panel to open/close this GUI
local BtnSaveBuild = BTN("Save Build",  Color3.fromRGB(14,72,108))
BtnSaveBuild.MouseButton1Click:Connect(function()
    SBPanel.Visible = not SBPanel.Visible
end)

-- ?? Selection system ????????????????????????????????????????
local function SB_UpdateCount()
    local n = 0
    for _ in pairs(SB_Selected) do n = n + 1 end
    SBCountLbl.Text = "Selected: " .. n .. " blocks"
end

local function SB_Toggle(part)
    if not part or not part:IsA("BasePart") then return end
    if SB_Selected[part] then
        SB_Selected[part] = nil
        local hl = SB_Highlights[part]
        if hl then pcall(function() hl:Destroy() end) end
        SB_Highlights[part] = nil
    else
        SB_Selected[part] = true
        local sb = Instance.new("SelectionBox", workspace)
        sb.Adornee, sb.Color3 = part, Color3.fromRGB(0,255,110)
        sb.LineThickness, sb.SurfaceTransparency = 0.05, 0.8
        SB_Highlights[part] = sb
    end
    SB_UpdateCount()
end

BtnSBSelect.MouseButton1Click:Connect(function()
    SB_SelectOn = not SB_SelectOn
    BtnSBSelect.Text = SB_SelectOn and "Select Blocks: ON (tap any block)" or "Select Blocks: OFF"
    BtnSBSelect.BackgroundColor3 = SB_SelectOn
        and Color3.fromRGB(35,155,70) or Color3.fromRGB(35,55,95)
end)

UIS.InputBegan:Connect(function(input, gpe)
    if gpe or not SB_SelectOn then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        if M.Target then SB_Toggle(M.Target) end
    end
end)
UIS.TouchTap:Connect(function(positions, gpe)
    if gpe or not SB_SelectOn then return end
    if #positions > 0 then
        local ray = Cam:ScreenPointToRay(positions[1].X, positions[1].Y)
        local rp  = RaycastParams.new()
        local ch  = L.Character
        pcall(function() rp.FilterType = Enum.RaycastFilterType.Exclude end)
        pcall(function() rp.FilterDescendantsInstances = ch and {ch} or {} end)
        local res = workspace:Raycast(ray.Origin, ray.Direction*300, rp)
        if res and res.Instance then SB_Toggle(res.Instance) end
    end
end)

-- ?? Save ????????????????????????????????????????????????????
BtnSBSave.MouseButton1Click:Connect(function()
    local parts = {}
    for part in pairs(SB_Selected) do
        if part and part.Parent then table.insert(parts, part) end
    end
    if #parts == 0 then SBStatusLbl.Text = "Nothing selected!"; return end

    -- Compute center
    local sum = Vector3.zero
    for _, p in ipairs(parts) do sum = sum + p.Position end
    SB_Center = sum / #parts

    -- Store block data
    SB_Data = {}
    local centerCF = CFrame.new(SB_Center)
    for _, p in ipairs(parts) do
        table.insert(SB_Data, {
            cf       = p.CFrame,
            size     = p.Size,
            color    = p.Color,
            material = p.Material,
            canColl  = p.CanCollide,
            -- relative CFrame from group center (preserves shape when following player)
            relCF    = centerCF:ToObjectSpace(p.CFrame),
            part     = p,
        })
    end

    -- Also serialize for reference
    SB_BuildStr = SB_Serialize(parts)

    SBStatusLbl.Text, SBStatusLbl.TextColor3 =
        "Saved " .. #SB_Data .. " blocks", Color3.fromRGB(70,240,110)
end)

-- ?? Import hologram ?????????????????????????????????????????
BtnSBImport.MouseButton1Click:Connect(function()
    if #SB_Ghosts > 0 then
        SB_ClearGhosts()
        BtnSBImport.Text = "Show Hologram"
        SBStatusLbl.Text, SBStatusLbl.TextColor3 =
            "Ghosts cleared", Color3.fromRGB(150,195,235)
        return
    end
    if #SB_Data == 0 then SBStatusLbl.Text = "Save a build first!"; return end
    SB_ShowGhosts()
    BtnSBImport.Text = "Hide Hologram"
    SBStatusLbl.Text, SBStatusLbl.TextColor3 =
        "Showing " .. #SB_Ghosts .. " ghost blocks", Color3.fromRGB(90,205,255)
end)

-- ?? Walk Mode ????????????????????????????????????????????????
-- Unanchors saved blocks via stealth paint tool, then drives them
-- to follow the player in the exact same relative formation.
-- Toggling off re-anchors them at their new positions.

local function SB_StealthSetAnchor(part, shouldAnchor)
    pcall(function() part.Anchored = shouldAnchor end)
    if not shouldAnchor then ClaimPart(part) end
    -- Fire anchor-change remotes through the stealth paint tool
    local tool = GetPaintTool()
    if not tool then return end
    for _, child in ipairs(tool:GetDescendants()) do
        if child:IsA("RemoteEvent") then
            pcall(function() child:FireServer(part, "Anchor", shouldAnchor) end)
            pcall(function() child:FireServer(part, shouldAnchor) end)
            pcall(function() child:FireServer(part, "anchored", shouldAnchor) end)
            pcall(function() child:FireServer(part, "setanchor", shouldAnchor) end)
        end
    end
end

-- Locate the actual workspace part nearest a saved position
local function SB_FindPartNear(savedCF, radius)
    radius = radius or 1.5
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart")
        and not obj:IsDescendantOf(L.Character or game)
        and (obj.Position - savedCF.Position).Magnitude < radius then
            return obj
        end
    end
    return nil
end

BtnSBWalk.MouseButton1Click:Connect(function()
    WalkOn = not WalkOn

    if WalkOn then
        if #SB_Data == 0 then
            WalkOn = false
            SBStatusLbl.Text = "Save a build first!"
            return
        end

        BtnSBWalk.Text = "Walk Mode: ON  (tap to stop)"
        BtnSBWalk.BackgroundColor3 = Color3.fromRGB(155,45,200)

        local root = L.Character and L.Character:FindFirstChild("HumanoidRootPart")
        local playerCF = root and root.CFrame or CFrame.new()

        WalkParts = {}
        local found = 0
        for _, bd in ipairs(SB_Data) do
            -- Resolve the actual part: use saved reference or find nearby
            local part = (bd.part and bd.part.Parent) and bd.part
                      or SB_FindPartNear(bd.cf)
            if part and part.Parent then
                -- Silently unanchor via paint tool
                StealthEquip()           -- equip without showing
                SB_StealthSetAnchor(part, false)
                -- Compute offset relative to the player's current CFrame
                table.insert(WalkParts, {
                    part  = part,
                    -- relCF from playerCF so the build follows the player
                    relCF = playerCF:ToObjectSpace(part.CFrame),
                })
                found = found + 1
            end
        end

        if found == 0 then
            WalkOn = false
            BtnSBWalk.Text = "Walk Mode: OFF"
            BtnSBWalk.BackgroundColor3 = Color3.fromRGB(75,25,110)
            SBStatusLbl.Text = "No blocks found at saved positions"
            return
        end
        SBStatusLbl.Text, SBStatusLbl.TextColor3 =
            "Walking " .. found .. " blocks", Color3.fromRGB(190,100,255)

        if WalkConn then WalkConn:Disconnect() end
        WalkConn = R.RenderStepped:Connect(function(dt)
            if not WalkOn then
                if WalkConn then WalkConn:Disconnect(); WalkConn = nil end
                return
            end
            local C3   = L.Character
            local Root3 = C3 and C3:FindFirstChild("HumanoidRootPart")
            if not Root3 then return end
            local baseCF = Root3.CFrame
            for _, wp in ipairs(WalkParts) do
                local prt = wp.part
                if prt and prt.Parent then
                    -- Apply the stored relative CFrame to the player's current CFrame
                    -- This keeps the entire build formation rigid around the player
                    local targetCF = baseCF * wp.relCF
                    DrivePartFE(prt, targetCF, dt)
                end
            end
        end)

    else
        -- Turn off: re-anchor blocks at their current positions
        BtnSBWalk.Text = "Walk Mode: OFF"
        BtnSBWalk.BackgroundColor3 = Color3.fromRGB(75,25,110)
        if WalkConn then WalkConn:Disconnect(); WalkConn = nil end
        for _, wp in ipairs(WalkParts) do
            local prt = wp.part
            if prt and prt.Parent then
                task.delay(0.15, function()
                    SB_StealthSetAnchor(prt, true)
                end)
            end
        end
        WalkParts = {}
        SBStatusLbl.Text, SBStatusLbl.TextColor3 =
            "Anchored at new positions", Color3.fromRGB(70,240,110)
    end
end)

-- ?? Clear all ???????????????????????????????????????????????
BtnSBClear.MouseButton1Click:Connect(function()
    -- Remove selection highlights
    for _, hl in pairs(SB_Highlights) do
        if hl then pcall(function() hl:Destroy() end) end
    end
    SB_Selected, SB_Highlights = {}, {}
    SB_ClearGhosts()
    SB_Data = {}
    SB_BuildStr = ""
    SBCountLbl.Text  = "Selected: 0 blocks"
    SBStatusLbl.Text, SBStatusLbl.TextColor3 = "Cleared",  Color3.fromRGB(150,195,235)
    BtnSBImport.Text = "Show Hologram"
end)
