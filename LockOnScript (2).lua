--[[
    ╔══════════════════════════════════════════════════╗
    ║     ULTIMATE BATTLEGROUND - LOCK ON SYSTEM       ║
    ║                                                  ║
    ║  Rumble       : 0   → 100                        ║
    ║  Deadzone     : 0   → 100                        ║
    ║  Sensitivity  : 0   → 500                        ║
    ║  Lock On Speed: 0   → 10                         ║
    ╚══════════════════════════════════════════════════╝
]]

-- ─────────────────────────────────────────────────────────
--  SERVICES
-- ─────────────────────────────────────────────────────────
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local HapticService     = game:GetService("HapticService")
local Camera            = workspace.CurrentCamera

local LocalPlayer       = Players.LocalPlayer

-- ─────────────────────────────────────────────────────────
--  SETTINGS  (same ranges as Ultimate Battleground)
-- ─────────────────────────────────────────────────────────
local Settings = {
    LockOnKey    = Enum.KeyCode.Q,
    Rumble       = 100,   -- 0 → 100
    Deadzone     = 100,   -- 0 → 100  (screen-edge dead zone %)
    Sensitivity  = 500,   -- 0 → 500
    LockOnSpeed  = 10,    -- 0 → 10   (higher = faster snap)
    Enabled      = true,
}

-- ─────────────────────────────────────────────────────────
--  STATE
-- ─────────────────────────────────────────────────────────
local LockedTarget = nil
local IsLocked     = false
local BindingKey   = false

-- ─────────────────────────────────────────────────────────
--  HELPERS
-- ─────────────────────────────────────────────────────────
local function GetHRP()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function IsAlive(player)
    local c = player.Character
    if not c then return false end
    local h = c:FindFirstChildOfClass("Humanoid")
    return h and h.Health > 0
end

local function GetNearestTarget()
    local hrp = GetHRP()
    if not hrp then return nil end

    local best     = nil
    local bestDist = math.huge
    local vp       = Camera.ViewportSize
    local cx, cy   = vp.X / 2, vp.Y / 2

    -- Deadzone: 0=no deadzone, 100=very large deadzone
    -- Map 0-100 → 0-300 pixels
    local dzPixels = (Settings.Deadzone / 100) * 300

    for _, p in ipairs(Players:GetPlayers()) do
        if p == LocalPlayer then continue end
        if not IsAlive(p)   then continue end
        local tc = p.Character
        if not tc then continue end
        local th = tc:FindFirstChild("HumanoidRootPart")
        if not th then continue end

        local sp, onScreen = Camera:WorldToScreenPoint(th.Position)
        if not onScreen then continue end

        local dist = math.sqrt((sp.X - cx)^2 + (sp.Y - cy)^2)
        if dist < bestDist and dist > dzPixels then
            bestDist = dist
            best     = p
        end
    end
    return best
end

local function DoRumble()
    if Settings.Rumble <= 0 then return end
    pcall(function()
        local intensity = Settings.Rumble / 100
        HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Large, intensity)
        task.delay(0.25, function()
            HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Large, 0)
        end)
    end)
end

-- ─────────────────────────────────────────────────────────
--  LOCK-ON LOGIC
-- ─────────────────────────────────────────────────────────
local function TryLockOn()
    if IsLocked then
        IsLocked    = false
        LockedTarget = nil
        return
    end
    local target = GetNearestTarget()
    if target then
        LockedTarget = target
        IsLocked     = true
        DoRumble()
    end
end

RunService.RenderStepped:Connect(function()
    if not IsLocked or not LockedTarget then return end
    if not IsAlive(LockedTarget) then
        IsLocked    = false
        LockedTarget = nil
        return
    end
    local tc = LockedTarget.Character
    if not tc then return end
    local th = tc:FindFirstChild("HumanoidRootPart")
    if not th then return end

    -- LockOnSpeed 0-10 → lerp alpha 0.01-0.3
    -- Sensitivity 0-500 → multiplier 0.2-2.0
    local speedAlpha = (Settings.LockOnSpeed / 10) * 0.3
    local sensMult   = 0.2 + (Settings.Sensitivity / 500) * 1.8
    local alpha      = math.clamp(speedAlpha * sensMult, 0.01, 1)

    local targetCF = CFrame.lookAt(Camera.CFrame.Position, th.Position + Vector3.new(0, 1.5, 0))
    Camera.CFrame  = Camera.CFrame:Lerp(targetCF, alpha)
end)

-- ─────────────────────────────────────────────────────────
--  INPUT
-- ─────────────────────────────────────────────────────────
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if BindingKey then
        if input.UserInputType == Enum.UserInputType.Keyboard then
            Settings.LockOnKey  = input.KeyCode
            BindingKey          = false
            _G.LockOnKeyChanged = input.KeyCode.Name
        end
        return
    end
    if not Settings.Enabled then return end
    if input.UserInputType == Enum.UserInputType.Keyboard
       and input.KeyCode == Settings.LockOnKey then
        TryLockOn()
    end
end)

-- ─────────────────────────────────────────────────────────
--  GUI
-- ─────────────────────────────────────────────────────────
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name           = "LockOnUI"
ScreenGui.ResetOnSpawn   = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent         = LocalPlayer.PlayerGui

-- ── Panel ────────────────────────────────────────────────
local Panel = Instance.new("Frame")
Panel.Name              = "Panel"
Panel.Size              = UDim2.new(0, 310, 0, 420)
Panel.Position          = UDim2.new(0, 20, 0.5, -210)
Panel.BackgroundColor3  = Color3.fromRGB(10, 10, 18)
Panel.BorderSizePixel   = 0
Panel.Active            = true
Panel.Draggable         = true
Panel.Parent            = ScreenGui
Instance.new("UICorner", Panel).CornerRadius = UDim.new(0, 14)

local UIStroke = Instance.new("UIStroke")
UIStroke.Color       = Color3.fromRGB(255, 80, 80)
UIStroke.Thickness   = 1.5
UIStroke.Transparency= 0.3
UIStroke.Parent      = Panel

-- ── Header ───────────────────────────────────────────────
local Header = Instance.new("Frame")
Header.Size            = UDim2.new(1, 0, 0, 50)
Header.BackgroundColor3= Color3.fromRGB(190, 30, 30)
Header.BorderSizePixel = 0
Header.Parent          = Panel
Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 14)

local HFix = Instance.new("Frame")
HFix.Size             = UDim2.new(1,0,0.5,0)
HFix.Position         = UDim2.new(0,0,0.5,0)
HFix.BackgroundColor3 = Color3.fromRGB(190,30,30)
HFix.BorderSizePixel  = 0
HFix.Parent           = Header

local TitleLbl = Instance.new("TextLabel")
TitleLbl.Size              = UDim2.new(1,-10,1,0)
TitleLbl.Position          = UDim2.new(0,12,0,0)
TitleLbl.BackgroundTransparency = 1
TitleLbl.Text              = "🎯  LOCK-ON  SYSTEM"
TitleLbl.TextColor3        = Color3.fromRGB(255,255,255)
TitleLbl.Font              = Enum.Font.GothamBold
TitleLbl.TextSize          = 17
TitleLbl.TextXAlignment    = Enum.TextXAlignment.Left
TitleLbl.Parent            = Header

local MinBtn = Instance.new("TextButton")
MinBtn.Size             = UDim2.new(0,28,0,28)
MinBtn.Position         = UDim2.new(1,-36,0,11)
MinBtn.BackgroundColor3 = Color3.fromRGB(255,255,255)
MinBtn.BackgroundTransparency = 0.8
MinBtn.Text             = "—"
MinBtn.TextColor3       = Color3.fromRGB(255,255,255)
MinBtn.Font             = Enum.Font.GothamBold
MinBtn.TextSize         = 14
MinBtn.BorderSizePixel  = 0
MinBtn.Parent           = Header
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0,6)

local PanelOpen = true
MinBtn.MouseButton1Click:Connect(function()
    PanelOpen = not PanelOpen
    TweenService:Create(Panel, TweenInfo.new(0.3, Enum.EasingStyle.Quart), {
        Size = PanelOpen and UDim2.new(0,310,0,420) or UDim2.new(0,310,0,50)
    }):Play()
end)

-- ── Content ───────────────────────────────────────────────
local Content = Instance.new("Frame")
Content.Name           = "Content"
Content.Position       = UDim2.new(0,0,0,54)
Content.Size           = UDim2.new(1,0,1,-54)
Content.BackgroundTransparency = 1
Content.ClipsDescendants = true
Content.Parent         = Panel

local UIPad = Instance.new("UIPadding")
UIPad.PaddingLeft  = UDim.new(0,14)
UIPad.PaddingRight = UDim.new(0,14)
UIPad.PaddingTop   = UDim.new(0,8)
UIPad.Parent       = Content

local UIList = Instance.new("UIListLayout")
UIList.SortOrder = Enum.SortOrder.LayoutOrder
UIList.Padding   = UDim.new(0,10)
UIList.Parent    = Content

-- ── Slider factory ────────────────────────────────────────
local function MakeSlider(icon, labelText, minVal, maxVal, defaultVal, order, onChange)
    local holder = Instance.new("Frame")
    holder.Size             = UDim2.new(1,0,0,58)
    holder.BackgroundColor3 = Color3.fromRGB(18,18,30)
    holder.BorderSizePixel  = 0
    holder.LayoutOrder      = order
    holder.Parent           = Content
    Instance.new("UICorner", holder).CornerRadius = UDim.new(0,10)

    -- icon
    local ico = Instance.new("TextLabel")
    ico.Size             = UDim2.new(0,24,0,24)
    ico.Position         = UDim2.new(0,10,0,8)
    ico.BackgroundTransparency = 1
    ico.Text             = icon
    ico.TextSize         = 18
    ico.Font             = Enum.Font.GothamBold
    ico.TextColor3       = Color3.fromRGB(255,255,255)
    ico.Parent           = holder

    -- label
    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size             = UDim2.new(0.55,0,0,20)
    nameLbl.Position         = UDim2.new(0,38,0,6)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text             = labelText
    nameLbl.TextColor3       = Color3.fromRGB(220,220,220)
    nameLbl.Font             = Enum.Font.GothamBold
    nameLbl.TextSize         = 13
    nameLbl.TextXAlignment   = Enum.TextXAlignment.Left
    nameLbl.Parent           = holder

    -- value box
    local valBox = Instance.new("Frame")
    valBox.Size             = UDim2.new(0,60,0,24)
    valBox.AnchorPoint      = Vector2.new(1,0)
    valBox.Position         = UDim2.new(1,-8,0,5)
    valBox.BackgroundColor3 = Color3.fromRGB(190,30,30)
    valBox.BorderSizePixel  = 0
    valBox.Parent           = holder
    Instance.new("UICorner", valBox).CornerRadius = UDim.new(0,6)

    local valLbl = Instance.new("TextLabel")
    valLbl.Size             = UDim2.new(1,0,1,0)
    valLbl.BackgroundTransparency = 1
    valLbl.Text             = tostring(defaultVal)
    valLbl.TextColor3       = Color3.fromRGB(255,255,255)
    valLbl.Font             = Enum.Font.GothamBold
    valLbl.TextSize         = 13
    valLbl.Parent           = valBox

    -- down/up arrow buttons
    local downBtn = Instance.new("TextButton")
    downBtn.Size             = UDim2.new(0,22,0,22)
    downBtn.AnchorPoint      = Vector2.new(1,0)
    downBtn.Position         = UDim2.new(1,-72,0,6)
    downBtn.BackgroundColor3 = Color3.fromRGB(40,40,60)
    downBtn.Text             = "v"
    downBtn.TextColor3       = Color3.fromRGB(200,200,200)
    downBtn.Font             = Enum.Font.GothamBold
    downBtn.TextSize         = 11
    downBtn.BorderSizePixel  = 0
    downBtn.Parent           = holder
    Instance.new("UICorner", downBtn).CornerRadius = UDim.new(0,5)

    local upBtn = Instance.new("TextButton")
    upBtn.Size             = UDim2.new(0,22,0,22)
    upBtn.AnchorPoint      = Vector2.new(1,0)
    upBtn.Position         = UDim2.new(1,-6,0,6) -- right of valBox... actually place after
    -- re-position relative
    upBtn.Position         = UDim2.new(1,-8,0,5)
    upBtn.AnchorPoint      = Vector2.new(1,0)
    -- place to right of val, use absolute trick via separate parent
    upBtn.Parent           = holder

    -- Simpler: just put arrows inside valBox sides
    downBtn:Destroy() upBtn:Destroy()

    local leftArrow = Instance.new("TextButton")
    leftArrow.Size             = UDim2.new(0,22,0,24)
    leftArrow.AnchorPoint      = Vector2.new(1,0)
    leftArrow.Position         = UDim2.new(1,-70,0,5)
    leftArrow.BackgroundColor3 = Color3.fromRGB(35,35,55)
    leftArrow.Text             = "<"
    leftArrow.TextColor3       = Color3.fromRGB(200,200,200)
    leftArrow.Font             = Enum.Font.GothamBold
    leftArrow.TextSize         = 12
    leftArrow.BorderSizePixel  = 0
    leftArrow.Parent           = holder
    Instance.new("UICorner", leftArrow).CornerRadius = UDim.new(0,5)

    local rightArrow = Instance.new("TextButton")
    rightArrow.Size             = UDim2.new(0,22,0,24)
    rightArrow.AnchorPoint      = Vector2.new(1,0)
    rightArrow.Position         = UDim2.new(1,-6,0,5)
    rightArrow.BackgroundColor3 = Color3.fromRGB(35,35,55)
    rightArrow.Text             = ">"
    rightArrow.TextColor3       = Color3.fromRGB(200,200,200)
    rightArrow.Font             = Enum.Font.GothamBold
    rightArrow.TextSize         = 12
    rightArrow.BorderSizePixel  = 0
    rightArrow.Parent           = holder
    Instance.new("UICorner", rightArrow).CornerRadius = UDim.new(0,5)

    -- re-position valBox between arrows
    valBox.Position    = UDim2.new(1,-70+24,0,5)
    valBox.AnchorPoint = Vector2.new(0,0)
    valBox.Size        = UDim2.new(0,38,0,24)

    -- Track
    local track = Instance.new("Frame")
    track.Size             = UDim2.new(1,-20,0,5)
    track.Position         = UDim2.new(0,10,1,-12)
    track.BackgroundColor3 = Color3.fromRGB(35,35,55)
    track.BorderSizePixel  = 0
    track.Parent           = holder
    Instance.new("UICorner", track).CornerRadius = UDim.new(1,0)

    local fill = Instance.new("Frame")
    fill.Size             = UDim2.new((defaultVal-minVal)/(maxVal-minVal),0,1,0)
    fill.BackgroundColor3 = Color3.fromRGB(210,40,40)
    fill.BorderSizePixel  = 0
    fill.Parent           = track
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1,0)

    local knob = Instance.new("Frame")
    knob.Size             = UDim2.new(0,13,0,13)
    knob.AnchorPoint      = Vector2.new(0.5,0.5)
    knob.Position         = UDim2.new((defaultVal-minVal)/(maxVal-minVal),0,0.5,0)
    knob.BackgroundColor3 = Color3.fromRGB(255,255,255)
    knob.BorderSizePixel  = 0
    knob.ZIndex           = 3
    knob.Parent           = track
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1,0)

    local currentVal = defaultVal

    local function SetValue(v)
        v = math.clamp(math.floor(v+0.5), minVal, maxVal)
        currentVal = v
        local rel  = (v-minVal)/(maxVal-minVal)
        fill.Size     = UDim2.new(rel,0,1,0)
        knob.Position = UDim2.new(rel,0,0.5,0)
        valLbl.Text   = tostring(v)
        if onChange then onChange(v) end
    end

    -- Arrow buttons step by 1
    local step = math.max(1, math.floor((maxVal-minVal)/100))
    leftArrow.MouseButton1Click:Connect(function()  SetValue(currentVal - step) end)
    rightArrow.MouseButton1Click:Connect(function() SetValue(currentVal + step) end)

    -- Drag
    local dragging = false
    knob.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true end
    end)
    track.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true end
    end)
    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if not dragging then return end
        if inp.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        local abs  = track.AbsolutePosition
        local sz   = track.AbsoluteSize
        local rel  = math.clamp((inp.Position.X - abs.X) / sz.X, 0, 1)
        SetValue(minVal + rel*(maxVal-minVal))
    end)

    return holder
end

-- ── Toggle factory ────────────────────────────────────────
local function MakeToggle(icon, labelText, defaultVal, order, onChange)
    local holder = Instance.new("Frame")
    holder.Size             = UDim2.new(1,0,0,42)
    holder.BackgroundColor3 = Color3.fromRGB(18,18,30)
    holder.BorderSizePixel  = 0
    holder.LayoutOrder      = order
    holder.Parent           = Content
    Instance.new("UICorner", holder).CornerRadius = UDim.new(0,10)

    local ico = Instance.new("TextLabel")
    ico.Size             = UDim2.new(0,24,1,0)
    ico.Position         = UDim2.new(0,10,0,0)
    ico.BackgroundTransparency = 1
    ico.Text             = icon
    ico.TextSize         = 18
    ico.Font             = Enum.Font.GothamBold
    ico.TextColor3       = Color3.fromRGB(255,255,255)
    ico.Parent           = holder

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size             = UDim2.new(0.6,0,1,0)
    nameLbl.Position         = UDim2.new(0,38,0,0)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text             = labelText
    nameLbl.TextColor3       = Color3.fromRGB(220,220,220)
    nameLbl.Font             = Enum.Font.GothamBold
    nameLbl.TextSize         = 13
    nameLbl.TextXAlignment   = Enum.TextXAlignment.Left
    nameLbl.Parent           = holder

    local togBG = Instance.new("Frame")
    togBG.Size             = UDim2.new(0,46,0,24)
    togBG.AnchorPoint      = Vector2.new(1,0.5)
    togBG.Position         = UDim2.new(1,-10,0.5,0)
    togBG.BackgroundColor3 = defaultVal and Color3.fromRGB(190,30,30) or Color3.fromRGB(40,40,60)
    togBG.BorderSizePixel  = 0
    togBG.Parent           = holder
    Instance.new("UICorner", togBG).CornerRadius = UDim.new(1,0)

    local togKnob = Instance.new("Frame")
    togKnob.Size             = UDim2.new(0,18,0,18)
    togKnob.AnchorPoint      = Vector2.new(0.5,0.5)
    togKnob.Position         = defaultVal and UDim2.new(1,-13,0.5,0) or UDim2.new(0,13,0.5,0)
    togKnob.BackgroundColor3 = Color3.fromRGB(255,255,255)
    togKnob.BorderSizePixel  = 0
    togKnob.Parent           = togBG
    Instance.new("UICorner", togKnob).CornerRadius = UDim.new(1,0)

    local state = defaultVal
    local btn   = Instance.new("TextButton")
    btn.Size             = UDim2.new(1,0,1,0)
    btn.BackgroundTransparency = 1
    btn.Text             = ""
    btn.Parent           = holder
    btn.MouseButton1Click:Connect(function()
        state = not state
        TweenService:Create(togBG, TweenInfo.new(0.2), {
            BackgroundColor3 = state and Color3.fromRGB(190,30,30) or Color3.fromRGB(40,40,60)
        }):Play()
        TweenService:Create(togKnob, TweenInfo.new(0.2), {
            Position = state and UDim2.new(1,-13,0.5,0) or UDim2.new(0,13,0.5,0)
        }):Play()
        if onChange then onChange(state) end
    end)
end

-- ── Keybind ───────────────────────────────────────────────
local function MakeKeybind(order)
    local holder = Instance.new("Frame")
    holder.Size             = UDim2.new(1,0,0,52)
    holder.BackgroundColor3 = Color3.fromRGB(18,18,30)
    holder.BorderSizePixel  = 0
    holder.LayoutOrder      = order
    holder.Parent           = Content
    Instance.new("UICorner", holder).CornerRadius = UDim.new(0,10)

    local ico = Instance.new("TextLabel")
    ico.Size             = UDim2.new(0,24,0,24)
    ico.Position         = UDim2.new(0,10,0,6)
    ico.BackgroundTransparency = 1
    ico.Text             = "⌨️"
    ico.TextSize         = 16
    ico.Font             = Enum.Font.GothamBold
    ico.TextColor3       = Color3.fromRGB(255,255,255)
    ico.Parent           = holder

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size             = UDim2.new(1,0,0,18)
    nameLbl.Position         = UDim2.new(0,38,0,5)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text             = "Lock-On Keybind"
    nameLbl.TextColor3       = Color3.fromRGB(220,220,220)
    nameLbl.Font             = Enum.Font.GothamBold
    nameLbl.TextSize         = 13
    nameLbl.TextXAlignment   = Enum.TextXAlignment.Left
    nameLbl.Parent           = holder

    local keyBtn = Instance.new("TextButton")
    keyBtn.Size             = UDim2.new(1,-20,0,22)
    keyBtn.Position         = UDim2.new(0,10,0,26)
    keyBtn.BackgroundColor3 = Color3.fromRGB(190,30,30)
    keyBtn.Text             = "[ " .. Settings.LockOnKey.Name .. " ]   click to change"
    keyBtn.TextColor3       = Color3.fromRGB(255,255,255)
    keyBtn.Font             = Enum.Font.Gotham
    keyBtn.TextSize         = 11
    keyBtn.BorderSizePixel  = 0
    keyBtn.Parent           = holder
    Instance.new("UICorner", keyBtn).CornerRadius = UDim.new(0,6)

    keyBtn.MouseButton1Click:Connect(function()
        BindingKey  = true
        keyBtn.Text = "  Press any key..."
        keyBtn.BackgroundColor3 = Color3.fromRGB(100,100,20)
    end)

    RunService.Heartbeat:Connect(function()
        if _G.LockOnKeyChanged then
            keyBtn.Text = "[ " .. _G.LockOnKeyChanged .. " ]   click to change"
            keyBtn.BackgroundColor3 = Color3.fromRGB(190,30,30)
            _G.LockOnKeyChanged = nil
        end
    end)
end

-- ── Status Bar ────────────────────────────────────────────
local function MakeStatus(order)
    local holder = Instance.new("Frame")
    holder.Size             = UDim2.new(1,0,0,32)
    holder.BackgroundColor3 = Color3.fromRGB(18,18,30)
    holder.BorderSizePixel  = 0
    holder.LayoutOrder      = order
    holder.Parent           = Content
    Instance.new("UICorner", holder).CornerRadius = UDim.new(0,8)

    local dot = Instance.new("Frame")
    dot.Size             = UDim2.new(0,10,0,10)
    dot.Position         = UDim2.new(0,10,0.5,-5)
    dot.BackgroundColor3 = Color3.fromRGB(70,70,90)
    dot.BorderSizePixel  = 0
    dot.Parent           = holder
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1,0)

    local lbl = Instance.new("TextLabel")
    lbl.Size             = UDim2.new(1,-30,1,0)
    lbl.Position         = UDim2.new(0,26,0,0)
    lbl.BackgroundTransparency = 1
    lbl.Text             = "No Target"
    lbl.TextColor3       = Color3.fromRGB(140,140,160)
    lbl.Font             = Enum.Font.Gotham
    lbl.TextSize         = 11
    lbl.TextXAlignment   = Enum.TextXAlignment.Left
    lbl.Parent           = holder

    RunService.RenderStepped:Connect(function()
        if IsLocked and LockedTarget then
            dot.BackgroundColor3 = Color3.fromRGB(255,50,50)
            lbl.Text             = "🔒 Locked → " .. LockedTarget.DisplayName
            lbl.TextColor3       = Color3.fromRGB(255,110,110)
        else
            dot.BackgroundColor3 = Color3.fromRGB(70,70,90)
            lbl.Text             = "No Target"
            lbl.TextColor3       = Color3.fromRGB(140,140,160)
        end
    end)
end

-- ── Build UI ──────────────────────────────────────────────
MakeKeybind(1)

MakeSlider("🎮", "Rumble", 0, 100, Settings.Rumble, 2, function(v)
    Settings.Rumble = v
end)

MakeSlider("🎯", "Deadzone", 0, 100, Settings.Deadzone, 3, function(v)
    Settings.Deadzone = v
end)

MakeSlider("🖱️", "Sensitivity", 0, 500, Settings.Sensitivity, 4, function(v)
    Settings.Sensitivity = v
end)

MakeSlider("⚡", "Lock On Speed", 0, 10, Settings.LockOnSpeed, 5, function(v)
    Settings.LockOnSpeed = v
end)

MakeToggle("✅", "Lock-On Enabled", Settings.Enabled, 6, function(v)
    Settings.Enabled = v
    if not v then IsLocked = false LockedTarget = nil end
end)

MakeStatus(7)

-- ── Crosshair ─────────────────────────────────────────────
local CF = Instance.new("Frame")
CF.Size             = UDim2.new(0,18,0,18)
CF.AnchorPoint      = Vector2.new(0.5,0.5)
CF.Position         = UDim2.new(0.5,0,0.5,0)
CF.BackgroundTransparency = 1
CF.Parent           = ScreenGui

local function Line(x,y,w,h)
    local f = Instance.new("Frame")
    f.Size             = UDim2.new(0,w,0,h)
    f.Position         = UDim2.new(0,x,0,y)
    f.BackgroundColor3 = Color3.fromRGB(255,55,55)
    f.BorderSizePixel  = 0
    f.Parent           = CF
end
Line(8,0,2,18)
Line(0,8,18,2)

local prevLocked = false
RunService.Heartbeat:Connect(function()
    if IsLocked and not prevLocked then
        for i=1,3 do
            task.wait(0.08)
            for _,c in ipairs(CF:GetChildren()) do c.BackgroundColor3=Color3.fromRGB(255,255,255) end
            task.wait(0.08)
            for _,c in ipairs(CF:GetChildren()) do c.BackgroundColor3=Color3.fromRGB(255,55,55) end
        end
    end
    prevLocked = IsLocked
end)

print("[LockOn] Loaded! Key: " .. Settings.LockOnKey.Name)
