--[[
    ╔══════════════════════════════════════════════════╗
    ║     ULTIMATE BATTLEGROUND - LOCK ON SYSTEM       ║
    ║     by Script Generator                          ║
    ║                                                  ║
    ║  SETTINGS:                                       ║
    ║  • Lock On Key     (customizable)                ║
    ║  • Lock On Speed   (how fast camera snaps)       ║
    ║  • Sensitivity     (mouse/thumbstick feel)       ║
    ║  • DeadZone        (minimum distance to lock)    ║
    ║  • Rumble          (controller haptics toggle)   ║
    ╚══════════════════════════════════════════════════╝
]]

-- ─────────────────────────────────────────────────────────
--  SERVICES
-- ─────────────────────────────────────────────────────────
local Players            = game:GetService("Players")
local RunService         = game:GetService("RunService")
local UserInputService   = game:GetService("UserInputService")
local TweenService       = game:GetService("TweenService")
local HapticService      = game:GetService("HapticService")
local Camera             = workspace.CurrentCamera

local LocalPlayer        = Players.LocalPlayer
local Mouse              = LocalPlayer:GetMouse()

-- ─────────────────────────────────────────────────────────
--  DEFAULT SETTINGS  (all editable from the UI)
-- ─────────────────────────────────────────────────────────
local Settings = {
    LockOnKey      = Enum.KeyCode.Q,      -- Key to toggle lock-on
    LockOnSpeed    = 0.15,                -- 0.01 (instant) → 1.0 (very slow)
    Sensitivity    = 5,                   -- 1 → 10
    DeadZone       = 30,                  -- pixels; targets closer than this ignored
    Rumble         = true,                -- controller vibration on lock
    Enabled        = true,               -- master toggle
}

-- ─────────────────────────────────────────────────────────
--  STATE
-- ─────────────────────────────────────────────────────────
local LockedTarget  = nil
local IsLocked      = false
local BindingKey    = false   -- true while waiting for new keybind input

-- ─────────────────────────────────────────────────────────
--  HELPERS
-- ─────────────────────────────────────────────────────────
local function GetCharacter()
    return LocalPlayer.Character
end

local function GetHRP()
    local c = GetCharacter()
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function IsAlive(player)
    local c = player.Character
    if not c then return false end
    local h = c:FindFirstChildOfClass("Humanoid")
    return h and h.Health > 0
end

local function GetNearestTarget()
    local hrp        = GetHRP()
    if not hrp then return nil end

    local best       = nil
    local bestDist   = math.huge

    for _, p in ipairs(Players:GetPlayers()) do
        if p == LocalPlayer then continue end
        if not IsAlive(p)   then continue end

        local tc = p.Character
        if not tc then continue end
        local th = tc:FindFirstChild("HumanoidRootPart")
        if not th then continue end

        -- screen-space distance from center
        local screenPos, onScreen = Camera:WorldToScreenPoint(th.Position)
        if not onScreen then continue end

        local cx = Camera.ViewportSize.X / 2
        local cy = Camera.ViewportSize.Y / 2
        local dist = math.sqrt((screenPos.X - cx)^2 + (screenPos.Y - cy)^2)

        if dist < bestDist and dist > Settings.DeadZone then
            bestDist = dist
            best     = p
        end
    end
    return best
end

local function DoRumble()
    if not Settings.Rumble then return end
    pcall(function()
        HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Large, 0.8)
        task.delay(0.2, function()
            HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Large, 0)
        end)
    end)
end

-- ─────────────────────────────────────────────────────────
--  LOCK-ON LOGIC
-- ─────────────────────────────────────────────────────────
local function TryLockOn()
    if IsLocked then
        -- Unlock
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

-- Camera tracking each frame
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

    local hrp = GetHRP()
    if not hrp then return end

    local targetCF = CFrame.lookAt(Camera.CFrame.Position, th.Position + Vector3.new(0, 1.5, 0))
    Camera.CFrame   = Camera.CFrame:Lerp(targetCF, Settings.LockOnSpeed * (Settings.Sensitivity / 5))
end)

-- ─────────────────────────────────────────────────────────
--  INPUT
-- ─────────────────────────────────────────────────────────
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end

    -- Keybind capture mode
    if BindingKey then
        if input.UserInputType == Enum.UserInputType.Keyboard then
            Settings.LockOnKey = input.KeyCode
            BindingKey         = false
            -- UI label updated below via signal
            _G.LockOnKeyChanged = input.KeyCode.Name
        end
        return
    end

    if not Settings.Enabled then return end
    if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Settings.LockOnKey then
        TryLockOn()
    end
end)

-- ─────────────────────────────────────────────────────────
--  GUI
-- ─────────────────────────────────────────────────────────
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name            = "LockOnUI"
ScreenGui.ResetOnSpawn    = false
ScreenGui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent          = LocalPlayer.PlayerGui

-- ── Main Panel ──────────────────────────────────────────
local Panel = Instance.new("Frame")
Panel.Name              = "Panel"
Panel.Size              = UDim2.new(0, 300, 0, 390)
Panel.Position          = UDim2.new(0, 20, 0.5, -195)
Panel.BackgroundColor3  = Color3.fromRGB(10, 10, 18)
Panel.BorderSizePixel   = 0
Panel.Active            = true
Panel.Draggable         = true
Panel.Parent            = ScreenGui

-- Rounded corners
local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 14)
UICorner.Parent       = Panel

-- Gradient border glow
local UIStroke = Instance.new("UIStroke")
UIStroke.Color        = Color3.fromRGB(255, 80, 80)
UIStroke.Thickness    = 1.5
UIStroke.Transparency = 0.3
UIStroke.Parent       = Panel

-- ── Header ──────────────────────────────────────────────
local Header = Instance.new("Frame")
Header.Size             = UDim2.new(1, 0, 0, 50)
Header.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
Header.BorderSizePixel  = 0
Header.Parent           = Panel

local HCorner = Instance.new("UICorner")
HCorner.CornerRadius = UDim.new(0, 14)
HCorner.Parent       = Header

-- Fix bottom corners of header
local HFix = Instance.new("Frame")
HFix.Size             = UDim2.new(1, 0, 0.5, 0)
HFix.Position         = UDim2.new(0, 0, 0.5, 0)
HFix.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
HFix.BorderSizePixel  = 0
HFix.Parent           = Header

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size              = UDim2.new(1, -10, 1, 0)
TitleLabel.Position          = UDim2.new(0, 10, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text              = "🎯  LOCK-ON  SYSTEM"
TitleLabel.TextColor3        = Color3.fromRGB(255, 255, 255)
TitleLabel.Font              = Enum.Font.GothamBold
TitleLabel.TextSize          = 17
TitleLabel.TextXAlignment    = Enum.TextXAlignment.Left
TitleLabel.Parent            = Header

-- Minimise button
local MinBtn = Instance.new("TextButton")
MinBtn.Size             = UDim2.new(0, 30, 0, 30)
MinBtn.Position         = UDim2.new(1, -38, 0, 10)
MinBtn.BackgroundColor3 = Color3.fromRGB(255,255,255)
MinBtn.BackgroundTransparency = 0.8
MinBtn.Text             = "—"
MinBtn.TextColor3       = Color3.fromRGB(255,255,255)
MinBtn.Font             = Enum.Font.GothamBold
MinBtn.TextSize         = 16
MinBtn.BorderSizePixel  = 0
MinBtn.Parent           = Header
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 6)

local PanelOpen = true
MinBtn.MouseButton1Click:Connect(function()
    PanelOpen = not PanelOpen
    TweenService:Create(Panel, TweenInfo.new(0.3, Enum.EasingStyle.Quart), {
        Size = PanelOpen and UDim2.new(0, 300, 0, 390) or UDim2.new(0, 300, 0, 50)
    }):Play()
end)

-- ── Content container ────────────────────────────────────
local Content = Instance.new("Frame")
Content.Name            = "Content"
Content.Position        = UDim2.new(0, 0, 0, 54)
Content.Size            = UDim2.new(1, 0, 1, -54)
Content.BackgroundTransparency = 1
Content.Parent          = Panel

local UIPad = Instance.new("UIPadding")
UIPad.PaddingLeft   = UDim.new(0, 14)
UIPad.PaddingRight  = UDim.new(0, 14)
UIPad.PaddingTop    = UDim.new(0, 8)
UIPad.Parent        = Content

local UIList = Instance.new("UIListLayout")
UIList.SortOrder  = Enum.SortOrder.LayoutOrder
UIList.Padding    = UDim.new(0, 10)
UIList.Parent     = Content

-- ── Widget factory functions ─────────────────────────────
local function MakeLabel(text, order)
    local lbl = Instance.new("TextLabel")
    lbl.Size             = UDim2.new(1, 0, 0, 14)
    lbl.BackgroundTransparency = 1
    lbl.Text             = text
    lbl.TextColor3       = Color3.fromRGB(180, 100, 100)
    lbl.Font             = Enum.Font.GothamBold
    lbl.TextSize         = 11
    lbl.TextXAlignment   = Enum.TextXAlignment.Left
    lbl.LayoutOrder      = order
    lbl.Parent           = Content
    return lbl
end

local function MakeSlider(labelText, minVal, maxVal, defaultVal, order, onChange)
    local holder = Instance.new("Frame")
    holder.Size             = UDim2.new(1, 0, 0, 46)
    holder.BackgroundColor3 = Color3.fromRGB(20, 20, 32)
    holder.BorderSizePixel  = 0
    holder.LayoutOrder      = order
    holder.Parent           = Content
    Instance.new("UICorner", holder).CornerRadius = UDim.new(0, 8)

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size             = UDim2.new(0.6, 0, 0, 18)
    nameLbl.Position         = UDim2.new(0, 10, 0, 4)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text             = labelText
    nameLbl.TextColor3       = Color3.fromRGB(230, 230, 230)
    nameLbl.Font             = Enum.Font.Gotham
    nameLbl.TextSize         = 12
    nameLbl.TextXAlignment   = Enum.TextXAlignment.Left
    nameLbl.Parent           = holder

    local valLbl = Instance.new("TextLabel")
    valLbl.Size             = UDim2.new(0.3, 0, 0, 18)
    valLbl.Position         = UDim2.new(0.7, -10, 0, 4)
    valLbl.BackgroundTransparency = 1
    valLbl.Text             = tostring(defaultVal)
    valLbl.TextColor3       = Color3.fromRGB(255, 100, 100)
    valLbl.Font             = Enum.Font.GothamBold
    valLbl.TextSize         = 12
    valLbl.TextXAlignment   = Enum.TextXAlignment.Right
    valLbl.Parent           = holder

    -- Track BG
    local track = Instance.new("Frame")
    track.Size             = UDim2.new(1, -20, 0, 6)
    track.Position         = UDim2.new(0, 10, 1, -14)
    track.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
    track.BorderSizePixel  = 0
    track.Parent           = holder
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    -- Fill
    local fill = Instance.new("Frame")
    fill.Size             = UDim2.new((defaultVal - minVal) / (maxVal - minVal), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
    fill.BorderSizePixel  = 0
    fill.Parent           = track
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    -- Knob
    local knob = Instance.new("Frame")
    knob.Size             = UDim2.new(0, 14, 0, 14)
    knob.AnchorPoint      = Vector2.new(0.5, 0.5)
    knob.Position         = UDim2.new((defaultVal - minVal) / (maxVal - minVal), 0, 0.5, 0)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel  = 0
    knob.ZIndex           = 3
    knob.Parent           = track
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    -- Drag logic
    local dragging = false
    knob.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true end
    end)
    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if not dragging then return end
        if inp.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        local trackAbsPos  = track.AbsolutePosition
        local trackAbsSize = track.AbsoluteSize
        local rel = math.clamp((inp.Position.X - trackAbsPos.X) / trackAbsSize.X, 0, 1)
        local val = math.floor(minVal + rel * (maxVal - minVal) + 0.5)
        if maxVal - minVal < 10 then
            -- float range (LockOnSpeed)
            val = math.floor((minVal + rel * (maxVal - minVal)) * 100 + 0.5) / 100
        end
        fill.Size     = UDim2.new(rel, 0, 1, 0)
        knob.Position = UDim2.new(rel, 0, 0.5, 0)
        valLbl.Text   = tostring(val)
        if onChange then onChange(val) end
    end)

    return holder
end

local function MakeToggle(labelText, defaultVal, order, onChange)
    local holder = Instance.new("Frame")
    holder.Size             = UDim2.new(1, 0, 0, 40)
    holder.BackgroundColor3 = Color3.fromRGB(20, 20, 32)
    holder.BorderSizePixel  = 0
    holder.LayoutOrder      = order
    holder.Parent           = Content
    Instance.new("UICorner", holder).CornerRadius = UDim.new(0, 8)

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size             = UDim2.new(0.65, 0, 1, 0)
    nameLbl.Position         = UDim2.new(0, 10, 0, 0)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text             = labelText
    nameLbl.TextColor3       = Color3.fromRGB(230, 230, 230)
    nameLbl.Font             = Enum.Font.Gotham
    nameLbl.TextSize         = 12
    nameLbl.TextXAlignment   = Enum.TextXAlignment.Left
    nameLbl.Parent           = holder

    local togBG = Instance.new("Frame")
    togBG.Size             = UDim2.new(0, 44, 0, 22)
    togBG.AnchorPoint      = Vector2.new(1, 0.5)
    togBG.Position         = UDim2.new(1, -10, 0.5, 0)
    togBG.BackgroundColor3 = defaultVal and Color3.fromRGB(200, 40, 40) or Color3.fromRGB(50, 50, 70)
    togBG.BorderSizePixel  = 0
    togBG.Parent           = holder
    Instance.new("UICorner", togBG).CornerRadius = UDim.new(1, 0)

    local togKnob = Instance.new("Frame")
    togKnob.Size             = UDim2.new(0, 18, 0, 18)
    togKnob.AnchorPoint      = Vector2.new(0.5, 0.5)
    togKnob.Position         = defaultVal and UDim2.new(1, -11, 0.5, 0) or UDim2.new(0, 11, 0.5, 0)
    togKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    togKnob.BorderSizePixel  = 0
    togKnob.Parent           = togBG
    Instance.new("UICorner", togKnob).CornerRadius = UDim.new(1, 0)

    local state = defaultVal
    local btn   = Instance.new("TextButton")
    btn.Size             = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text             = ""
    btn.Parent           = holder

    btn.MouseButton1Click:Connect(function()
        state = not state
        local onColor  = Color3.fromRGB(200, 40, 40)
        local offColor = Color3.fromRGB(50, 50, 70)
        TweenService:Create(togBG, TweenInfo.new(0.2), {BackgroundColor3 = state and onColor or offColor}):Play()
        TweenService:Create(togKnob, TweenInfo.new(0.2), {
            Position = state and UDim2.new(1, -11, 0.5, 0) or UDim2.new(0, 11, 0.5, 0)
        }):Play()
        if onChange then onChange(state) end
    end)
    return holder
end

local function MakeKeybindBtn(order)
    local holder = Instance.new("Frame")
    holder.Size             = UDim2.new(1, 0, 0, 50)
    holder.BackgroundColor3 = Color3.fromRGB(20, 20, 32)
    holder.BorderSizePixel  = 0
    holder.LayoutOrder      = order
    holder.Parent           = Content
    Instance.new("UICorner", holder).CornerRadius = UDim.new(0, 8)

    local lbl = Instance.new("TextLabel")
    lbl.Size             = UDim2.new(1, 0, 0, 18)
    lbl.Position         = UDim2.new(0, 10, 0, 5)
    lbl.BackgroundTransparency = 1
    lbl.Text             = "LOCK-ON KEYBIND"
    lbl.TextColor3       = Color3.fromRGB(230, 230, 230)
    lbl.Font             = Enum.Font.Gotham
    lbl.TextSize         = 12
    lbl.TextXAlignment   = Enum.TextXAlignment.Left
    lbl.Parent           = holder

    local keyBtn = Instance.new("TextButton")
    keyBtn.Size             = UDim2.new(1, -20, 0, 22)
    keyBtn.Position         = UDim2.new(0, 10, 0, 24)
    keyBtn.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
    keyBtn.Text             = "[ " .. Settings.LockOnKey.Name .. " ]"
    keyBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
    keyBtn.Font             = Enum.Font.GothamBold
    keyBtn.TextSize         = 12
    keyBtn.BorderSizePixel  = 0
    keyBtn.Parent           = holder
    Instance.new("UICorner", keyBtn).CornerRadius = UDim.new(0, 6)

    keyBtn.MouseButton1Click:Connect(function()
        BindingKey  = true
        keyBtn.Text = "[ Press ANY Key... ]"
        keyBtn.BackgroundColor3 = Color3.fromRGB(120, 120, 30)
    end)

    -- Watch for key change
    RunService.Heartbeat:Connect(function()
        if _G.LockOnKeyChanged then
            keyBtn.Text = "[ " .. _G.LockOnKeyChanged .. " ]"
            keyBtn.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
            _G.LockOnKeyChanged = nil
        end
    end)

    return holder
end

-- ── Status bar ───────────────────────────────────────────
local StatusBar = Instance.new("Frame")
StatusBar.Size             = UDim2.new(1, -28, 0, 24)
StatusBar.BackgroundColor3 = Color3.fromRGB(20, 20, 32)
StatusBar.BorderSizePixel  = 0
StatusBar.LayoutOrder      = 99
StatusBar.Parent           = Content
Instance.new("UICorner", StatusBar).CornerRadius = UDim.new(0, 6)

local StatusDot = Instance.new("Frame")
StatusDot.Size             = UDim2.new(0, 10, 0, 10)
StatusDot.Position         = UDim2.new(0, 8, 0.5, -5)
StatusDot.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
StatusDot.BorderSizePixel  = 0
StatusDot.Parent           = StatusBar
Instance.new("UICorner", StatusDot).CornerRadius = UDim.new(1, 0)

local StatusLbl = Instance.new("TextLabel")
StatusLbl.Size             = UDim2.new(1, -30, 1, 0)
StatusLbl.Position         = UDim2.new(0, 25, 0, 0)
StatusLbl.BackgroundTransparency = 1
StatusLbl.Text             = "No Target"
StatusLbl.TextColor3       = Color3.fromRGB(160, 160, 160)
StatusLbl.Font             = Enum.Font.Gotham
StatusLbl.TextSize         = 11
StatusLbl.TextXAlignment   = Enum.TextXAlignment.Left
StatusLbl.Parent           = StatusBar

-- Update status every frame
RunService.RenderStepped:Connect(function()
    if IsLocked and LockedTarget then
        StatusDot.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
        StatusLbl.Text  = "🔒 Locked → " .. LockedTarget.DisplayName
        StatusLbl.TextColor3 = Color3.fromRGB(255, 120, 120)
    else
        StatusDot.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
        StatusLbl.Text  = "No Target"
        StatusLbl.TextColor3 = Color3.fromRGB(160, 160, 160)
    end
end)

-- ── Build all widgets ─────────────────────────────────────
MakeKeybindBtn(1)

MakeSlider("Lock-On Speed", 1, 100, math.floor(Settings.LockOnSpeed * 100), 3, function(v)
    Settings.LockOnSpeed = v / 100
end)

MakeSlider("Sensitivity", 1, 10, Settings.Sensitivity, 4, function(v)
    Settings.Sensitivity = v
end)

MakeSlider("DeadZone  (px)", 0, 200, Settings.DeadZone, 5, function(v)
    Settings.DeadZone = v
end)

MakeToggle("Rumble  (Controller)", Settings.Rumble, 6, function(v)
    Settings.Rumble = v
end)

MakeToggle("Lock-On Enabled", Settings.Enabled, 7, function(v)
    Settings.Enabled = v
    if not v then
        IsLocked    = false
        LockedTarget = nil
    end
end)

-- ── Separator + status ───────────────────────────────────
local sep = Instance.new("Frame")
sep.Size             = UDim2.new(1, -28, 0, 1)
sep.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
sep.BorderSizePixel  = 0
sep.LayoutOrder      = 8
sep.Parent           = Content

-- status already added above at order 99
-- re-parent to ensure ordering
StatusBar.LayoutOrder = 9

-- ── Crosshair indicator (center screen) ─────────────────
local CrosshairFrame = Instance.new("Frame")
CrosshairFrame.Size             = UDim2.new(0, 16, 0, 16)
CrosshairFrame.AnchorPoint      = Vector2.new(0.5, 0.5)
CrosshairFrame.Position         = UDim2.new(0.5, 0, 0.5, 0)
CrosshairFrame.BackgroundTransparency = 1
CrosshairFrame.Parent           = ScreenGui

local function MakeLine(x, y, w, h)
    local f = Instance.new("Frame")
    f.Size             = UDim2.new(0, w, 0, h)
    f.Position         = UDim2.new(0, x, 0, y)
    f.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
    f.BorderSizePixel  = 0
    f.Parent           = CrosshairFrame
end
MakeLine(7, 0, 2, 16)   -- vertical
MakeLine(0, 7, 16, 2)   -- horizontal

-- Flash crosshair on lock
local function FlashCrosshair()
    for i = 1, 3 do
        task.wait(0.1)
        for _, c in ipairs(CrosshairFrame:GetChildren()) do c.BackgroundColor3 = Color3.fromRGB(255,255,255) end
        task.wait(0.1)
        for _, c in ipairs(CrosshairFrame:GetChildren()) do c.BackgroundColor3 = Color3.fromRGB(255, 60, 60) end
    end
end

-- Hook flash to lock event
local prevLocked = false
RunService.Heartbeat:Connect(function()
    if IsLocked and not prevLocked then
        task.spawn(FlashCrosshair)
    end
    prevLocked = IsLocked
end)

print("[LockOn] Script loaded! Press " .. Settings.LockOnKey.Name .. " to lock on.")
