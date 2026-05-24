--[[
    ╔══════════════════════════════════════════════════╗
    ║     ULTIMATE BATTLEGROUND - LOCK ON SYSTEM       ║
    ║                                                  ║
    ║  RIGHT SHIFT = Hide / Show UI                    ║
    ║  Rumble       : 0   → 100                        ║
    ║  Deadzone     : 0   → 100                        ║
    ║  Sensitivity  : 0   → 500                        ║
    ║  Lock On Speed: 0   → 10                         ║
    ╚══════════════════════════════════════════════════╝
]]

-- ──────────────────────────────────────────────────────────
--  SERVICES
-- ──────────────────────────────────────────────────────────
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local HapticService    = game:GetService("HapticService")
local Camera           = workspace.CurrentCamera
local LocalPlayer      = Players.LocalPlayer

-- ──────────────────────────────────────────────────────────
--  SETTINGS
-- ──────────────────────────────────────────────────────────
local Settings = {
    LockOnKey   = Enum.KeyCode.Q,
    Rumble      = 100,  -- 0-100
    Deadzone    = 30,   -- 0-100
    Sensitivity = 250,  -- 0-500
    LockOnSpeed = 5,    -- 0-10
    Enabled     = true,
}

-- ──────────────────────────────────────────────────────────
--  STATE
-- ──────────────────────────────────────────────────────────
local LockedTarget = nil
local IsLocked     = false
local BindingKey   = false
local UIVisible    = true

-- ──────────────────────────────────────────────────────────
--  LOCK-ON HELPERS
-- ──────────────────────────────────────────────────────────
local function GetHRP()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function IsAlive(p)
    local c = p.Character
    if not c then return false end
    local h = c:FindFirstChildOfClass("Humanoid")
    return h and h.Health > 0
end

local function GetNearestTarget()
    if not GetHRP() then return nil end
    local vp = Camera.ViewportSize
    local cx, cy = vp.X/2, vp.Y/2
    local dzPx = (Settings.Deadzone/100) * 300
    local best, bestDist = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p == LocalPlayer or not IsAlive(p) then continue end
        local tc = p.Character
        if not tc then continue end
        local th = tc:FindFirstChild("HumanoidRootPart")
        if not th then continue end
        local sp, onScreen = Camera:WorldToScreenPoint(th.Position)
        if not onScreen then continue end
        local dist = math.sqrt((sp.X-cx)^2 + (sp.Y-cy)^2)
        if dist < bestDist and dist > dzPx then
            bestDist = dist
            best     = p
        end
    end
    return best
end

local function DoRumble()
    if Settings.Rumble <= 0 then return end
    pcall(function()
        HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Large, Settings.Rumble/100)
        task.delay(0.25, function()
            HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Large, 0)
        end)
    end)
end

local function TryLockOn()
    if IsLocked then
        IsLocked = false; LockedTarget = nil; return
    end
    local t = GetNearestTarget()
    if t then LockedTarget = t; IsLocked = true; DoRumble() end
end

RunService.RenderStepped:Connect(function()
    if not IsLocked or not LockedTarget then return end
    if not IsAlive(LockedTarget) then
        IsLocked = false; LockedTarget = nil; return
    end
    local tc = LockedTarget.Character
    if not tc then return end
    local th = tc:FindFirstChild("HumanoidRootPart")
    if not th then return end
    local alpha = math.clamp((Settings.LockOnSpeed/10)*0.3 * (0.2+(Settings.Sensitivity/500)*1.8), 0.01, 1)
    Camera.CFrame = Camera.CFrame:Lerp(
        CFrame.lookAt(Camera.CFrame.Position, th.Position + Vector3.new(0,1.5,0)), alpha)
end)

-- ──────────────────────────────────────────────────────────
--  INPUT  (lock-on key + right shift)
-- ──────────────────────────────────────────────────────────
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end

    -- RIGHT SHIFT → toggle UI
    if input.KeyCode == Enum.KeyCode.RightShift then
        UIVisible = not UIVisible
        -- toggled below after Panel is built
        if _G.ToggleUI then _G.ToggleUI(UIVisible) end
        return
    end

    -- Keybind capture
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

-- ──────────────────────────────────────────────────────────
--  GUI
-- ──────────────────────────────────────────────────────────
local SG = Instance.new("ScreenGui")
SG.Name           = "LockOnUI"
SG.ResetOnSpawn   = false
SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
SG.Parent         = LocalPlayer.PlayerGui

-- ── DRAG LOGIC (header only, no Draggable=true so sliders work) ──
local function MakeDraggable(panel, handle)
    local dragging, dragStart, startPos = false, nil, nil
    handle.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging  = true
            dragStart = inp.Position
            startPos  = panel.Position
        end
    end)
    handle.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = inp.Position - dragStart
            panel.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

-- ── Panel ────────────────────────────────────────────────
local Panel = Instance.new("Frame")
Panel.Name             = "Panel"
Panel.Size             = UDim2.new(0, 320, 0, 0)  -- height set by AutomaticSize
Panel.AutomaticSize    = Enum.AutomaticSize.Y
Panel.Position         = UDim2.new(0, 24, 0.5, -200)
Panel.BackgroundColor3 = Color3.fromRGB(8, 8, 16)
Panel.BorderSizePixel  = 0
Panel.Active           = true
Panel.Parent           = SG
Instance.new("UICorner", Panel).CornerRadius = UDim.new(0,14)

local Stroke = Instance.new("UIStroke")
Stroke.Color       = Color3.fromRGB(220, 45, 45)
Stroke.Thickness   = 1.5
Stroke.Transparency= 0.25
Stroke.Parent      = Panel

-- ── Header (drag zone) ───────────────────────────────────
local Header = Instance.new("Frame")
Header.Name            = "Header"
Header.Size            = UDim2.new(1,0,0,48)
Header.BackgroundColor3= Color3.fromRGB(185,28,28)
Header.BorderSizePixel = 0
Header.ZIndex          = 2
Header.Parent          = Panel
Instance.new("UICorner", Header).CornerRadius = UDim.new(0,14)

-- Fix bottom corners of header
local HFix = Instance.new("Frame")
HFix.Size             = UDim2.new(1,0,0.5,0)
HFix.Position         = UDim2.new(0,0,0.5,0)
HFix.BackgroundColor3 = Color3.fromRGB(185,28,28)
HFix.BorderSizePixel  = 0
HFix.ZIndex           = 2
HFix.Parent           = Header

local TitleLbl = Instance.new("TextLabel")
TitleLbl.Size              = UDim2.new(1,-50,1,0)
TitleLbl.Position          = UDim2.new(0,14,0,0)
TitleLbl.BackgroundTransparency = 1
TitleLbl.Text              = "🎯  LOCK-ON SYSTEM"
TitleLbl.TextColor3        = Color3.fromRGB(255,255,255)
TitleLbl.Font              = Enum.Font.GothamBold
TitleLbl.TextSize          = 16
TitleLbl.TextXAlignment    = Enum.TextXAlignment.Left
TitleLbl.ZIndex            = 3
TitleLbl.Parent            = Header

-- Hint label
local HintLbl = Instance.new("TextLabel")
HintLbl.Size              = UDim2.new(1,-50,0,14)
HintLbl.Position          = UDim2.new(0,14,1,-16)
HintLbl.BackgroundTransparency = 1
HintLbl.Text              = "RShift = hide/show  •  drag header to move"
HintLbl.TextColor3        = Color3.fromRGB(255,180,180)
HintLbl.Font              = Enum.Font.Gotham
HintLbl.TextSize          = 9
HintLbl.TextXAlignment    = Enum.TextXAlignment.Left
HintLbl.ZIndex            = 3
HintLbl.Parent            = Header

MakeDraggable(Panel, Header)

-- ── Content ───────────────────────────────────────────────
local Content = Instance.new("Frame")
Content.Name           = "Content"
Content.Size           = UDim2.new(1,0,0,0)
Content.AutomaticSize  = Enum.AutomaticSize.Y
Content.BackgroundTransparency = 1
Content.Parent         = Panel

local PadTop = Instance.new("UIPadding")
PadTop.PaddingLeft   = UDim.new(0,12)
PadTop.PaddingRight  = UDim.new(0,12)
PadTop.PaddingTop    = UDim.new(0,54)  -- below header
PadTop.PaddingBottom = UDim.new(0,10)
PadTop.Parent        = Content

local ListLayout = Instance.new("UIListLayout")
ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
ListLayout.Padding   = UDim.new(0,8)
ListLayout.Parent    = Content

-- ──────────────────────────────────────────────────────────
--  WIDGET: Number row  (label | − | value box | + )
--  No tiny draggable knob — just big clean buttons!
-- ──────────────────────────────────────────────────────────
local function MakeNumberRow(icon, label, minV, maxV, step, defaultV, order, onChange)
    local row = Instance.new("Frame")
    row.Name             = label
    row.Size             = UDim2.new(1,0,0,52)
    row.BackgroundColor3 = Color3.fromRGB(16,16,28)
    row.BorderSizePixel  = 0
    row.LayoutOrder      = order
    row.Parent           = Content
    Instance.new("UICorner", row).CornerRadius = UDim.new(0,10)

    -- icon + label on the left
    local icoLbl = Instance.new("TextLabel")
    icoLbl.Size             = UDim2.new(0,22,1,0)
    icoLbl.Position         = UDim2.new(0,10,0,0)
    icoLbl.BackgroundTransparency = 1
    icoLbl.Text             = icon
    icoLbl.TextSize         = 17
    icoLbl.Font             = Enum.Font.GothamBold
    icoLbl.TextColor3       = Color3.fromRGB(255,255,255)
    icoLbl.Parent           = row

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size             = UDim2.new(0,100,0,20)
    nameLbl.Position         = UDim2.new(0,36,0,8)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text             = label
    nameLbl.TextColor3       = Color3.fromRGB(220,220,220)
    nameLbl.Font             = Enum.Font.GothamBold
    nameLbl.TextSize         = 13
    nameLbl.TextXAlignment   = Enum.TextXAlignment.Left
    nameLbl.Parent           = row

    local rangeLbl = Instance.new("TextLabel")
    rangeLbl.Size             = UDim2.new(0,100,0,14)
    rangeLbl.Position         = UDim2.new(0,36,0,30)
    rangeLbl.BackgroundTransparency = 1
    rangeLbl.Text             = minV .. " → " .. maxV
    rangeLbl.TextColor3       = Color3.fromRGB(120,120,150)
    rangeLbl.Font             = Enum.Font.Gotham
    rangeLbl.TextSize         = 10
    rangeLbl.TextXAlignment   = Enum.TextXAlignment.Left
    rangeLbl.Parent           = row

    -- RIGHT side: [−]  [value]  [+]
    local currentVal = defaultV

    -- Minus button
    local minusBtn = Instance.new("TextButton")
    minusBtn.Size             = UDim2.new(0,34,0,34)
    minusBtn.AnchorPoint      = Vector2.new(1,0.5)
    minusBtn.Position         = UDim2.new(1,-118,0.5,0)
    minusBtn.BackgroundColor3 = Color3.fromRGB(35,35,55)
    minusBtn.Text             = "−"
    minusBtn.TextColor3       = Color3.fromRGB(220,220,220)
    minusBtn.Font             = Enum.Font.GothamBold
    minusBtn.TextSize         = 20
    minusBtn.BorderSizePixel  = 0
    minusBtn.AutoButtonColor  = false
    minusBtn.Parent           = row
    Instance.new("UICorner", minusBtn).CornerRadius = UDim.new(0,8)

    -- Value display / input box
    local valBox = Instance.new("TextBox")
    valBox.Size             = UDim2.new(0,62,0,34)
    valBox.AnchorPoint      = Vector2.new(1,0.5)
    valBox.Position         = UDim2.new(1,-50,0.5,0)
    valBox.BackgroundColor3 = Color3.fromRGB(28,28,46)
    valBox.Text             = tostring(defaultV)
    valBox.TextColor3       = Color3.fromRGB(255,255,255)
    valBox.Font             = Enum.Font.GothamBold
    valBox.TextSize         = 14
    valBox.BorderSizePixel  = 0
    valBox.ClearTextOnFocus = false
    valBox.Parent           = row
    Instance.new("UICorner", valBox).CornerRadius = UDim.new(0,8)

    -- red accent on valBox
    local vStroke = Instance.new("UIStroke")
    vStroke.Color       = Color3.fromRGB(190,30,30)
    vStroke.Thickness   = 1
    vStroke.Transparency= 0.5
    vStroke.Parent      = valBox

    -- Plus button
    local plusBtn = Instance.new("TextButton")
    plusBtn.Size             = UDim2.new(0,34,0,34)
    plusBtn.AnchorPoint      = Vector2.new(1,0.5)
    plusBtn.Position         = UDim2.new(1,-10,0.5,0)
    plusBtn.BackgroundColor3 = Color3.fromRGB(185,28,28)
    plusBtn.Text             = "+"
    plusBtn.TextColor3       = Color3.fromRGB(255,255,255)
    plusBtn.Font             = Enum.Font.GothamBold
    plusBtn.TextSize         = 20
    plusBtn.BorderSizePixel  = 0
    plusBtn.AutoButtonColor  = false
    plusBtn.Parent           = row
    Instance.new("UICorner", plusBtn).CornerRadius = UDim.new(0,8)

    -- thin progress bar at bottom of row
    local bar = Instance.new("Frame")
    bar.Size             = UDim2.new(1,-24,0,3)
    bar.Position         = UDim2.new(0,12,1,-5)
    bar.BackgroundColor3 = Color3.fromRGB(30,30,50)
    bar.BorderSizePixel  = 0
    bar.Parent           = row
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1,0)

    local barFill = Instance.new("Frame")
    barFill.Size             = UDim2.new((defaultV-minV)/(maxV-minV),0,1,0)
    barFill.BackgroundColor3 = Color3.fromRGB(210,40,40)
    barFill.BorderSizePixel  = 0
    barFill.Parent           = bar
    Instance.new("UICorner", barFill).CornerRadius = UDim.new(1,0)

    local function SetVal(v)
        v = math.clamp(v, minV, maxV)
        -- round to step
        v = math.floor(v/step + 0.5) * step
        v = math.clamp(v, minV, maxV)
        currentVal = v
        valBox.Text = tostring(v)
        local rel = maxV ~= minV and (v-minV)/(maxV-minV) or 0
        TweenService:Create(barFill, TweenInfo.new(0.1), {Size=UDim2.new(rel,0,1,0)}):Play()
        if onChange then onChange(v) end
    end

    -- Button hold support (hold for fast change)
    local function HoldButton(btn, delta)
        local held = false
        btn.MouseButton1Down:Connect(function()
            held = true
            SetVal(currentVal + delta)
            task.delay(0.4, function()
                while held do
                    SetVal(currentVal + delta)
                    task.wait(0.07)
                end
            end)
        end)
        btn.MouseButton1Up:Connect(function() held = false end)
        btn.MouseLeave:Connect(function() held = false end)
        -- hover effect
        btn.MouseEnter:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.1), {
                BackgroundColor3 = delta > 0 and Color3.fromRGB(220,50,50) or Color3.fromRGB(50,50,75)
            }):Play()
        end)
        btn.MouseLeave:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.1), {
                BackgroundColor3 = delta > 0 and Color3.fromRGB(185,28,28) or Color3.fromRGB(35,35,55)
            }):Play()
        end)
    end

    HoldButton(minusBtn, -step)
    HoldButton(plusBtn,   step)

    -- Type directly into box
    valBox.FocusLost:Connect(function()
        local num = tonumber(valBox.Text)
        if num then SetVal(num) else valBox.Text = tostring(currentVal) end
    end)

    return row
end

-- ──────────────────────────────────────────────────────────
--  WIDGET: Toggle row
-- ──────────────────────────────────────────────────────────
local function MakeToggleRow(icon, label, defaultVal, order, onChange)
    local row = Instance.new("Frame")
    row.Size             = UDim2.new(1,0,0,46)
    row.BackgroundColor3 = Color3.fromRGB(16,16,28)
    row.BorderSizePixel  = 0
    row.LayoutOrder      = order
    row.Parent           = Content
    Instance.new("UICorner", row).CornerRadius = UDim.new(0,10)

    local icoLbl = Instance.new("TextLabel")
    icoLbl.Size             = UDim2.new(0,22,1,0)
    icoLbl.Position         = UDim2.new(0,10,0,0)
    icoLbl.BackgroundTransparency = 1
    icoLbl.Text             = icon
    icoLbl.TextSize         = 17
    icoLbl.Font             = Enum.Font.GothamBold
    icoLbl.TextColor3       = Color3.fromRGB(255,255,255)
    icoLbl.Parent           = row

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size             = UDim2.new(0.6,0,1,0)
    nameLbl.Position         = UDim2.new(0,36,0,0)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text             = label
    nameLbl.TextColor3       = Color3.fromRGB(220,220,220)
    nameLbl.Font             = Enum.Font.GothamBold
    nameLbl.TextSize         = 13
    nameLbl.TextXAlignment   = Enum.TextXAlignment.Left
    nameLbl.Parent           = row

    local togBG = Instance.new("Frame")
    togBG.Size             = UDim2.new(0,50,0,26)
    togBG.AnchorPoint      = Vector2.new(1,0.5)
    togBG.Position         = UDim2.new(1,-10,0.5,0)
    togBG.BackgroundColor3 = defaultVal and Color3.fromRGB(185,28,28) or Color3.fromRGB(38,38,58)
    togBG.BorderSizePixel  = 0
    togBG.Parent           = row
    Instance.new("UICorner", togBG).CornerRadius = UDim.new(1,0)

    local togKnob = Instance.new("Frame")
    togKnob.Size             = UDim2.new(0,20,0,20)
    togKnob.AnchorPoint      = Vector2.new(0.5,0.5)
    togKnob.Position         = defaultVal and UDim2.new(1,-14,0.5,0) or UDim2.new(0,14,0.5,0)
    togKnob.BackgroundColor3 = Color3.fromRGB(255,255,255)
    togKnob.BorderSizePixel  = 0
    togKnob.Parent           = togBG
    Instance.new("UICorner", togKnob).CornerRadius = UDim.new(1,0)

    local state = defaultVal
    local btn = Instance.new("TextButton")
    btn.Size             = UDim2.new(1,0,1,0)
    btn.BackgroundTransparency = 1
    btn.Text             = ""
    btn.Parent           = row
    btn.MouseButton1Click:Connect(function()
        state = not state
        TweenService:Create(togBG, TweenInfo.new(0.15), {
            BackgroundColor3 = state and Color3.fromRGB(185,28,28) or Color3.fromRGB(38,38,58)
        }):Play()
        TweenService:Create(togKnob, TweenInfo.new(0.15), {
            Position = state and UDim2.new(1,-14,0.5,0) or UDim2.new(0,14,0.5,0)
        }):Play()
        if onChange then onChange(state) end
    end)
end

-- ──────────────────────────────────────────────────────────
--  WIDGET: Keybind row
-- ──────────────────────────────────────────────────────────
local function MakeKeybindRow(order)
    local row = Instance.new("Frame")
    row.Size             = UDim2.new(1,0,0,52)
    row.BackgroundColor3 = Color3.fromRGB(16,16,28)
    row.BorderSizePixel  = 0
    row.LayoutOrder      = order
    row.Parent           = Content
    Instance.new("UICorner", row).CornerRadius = UDim.new(0,10)

    local icoLbl = Instance.new("TextLabel")
    icoLbl.Size             = UDim2.new(0,22,0,26)
    icoLbl.Position         = UDim2.new(0,10,0,12)
    icoLbl.BackgroundTransparency = 1
    icoLbl.Text             = "⌨️"
    icoLbl.TextSize         = 16
    icoLbl.Font             = Enum.Font.GothamBold
    icoLbl.TextColor3       = Color3.fromRGB(255,255,255)
    icoLbl.Parent           = row

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size             = UDim2.new(0.5,0,0,18)
    nameLbl.Position         = UDim2.new(0,36,0,9)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text             = "Lock-On Key"
    nameLbl.TextColor3       = Color3.fromRGB(220,220,220)
    nameLbl.Font             = Enum.Font.GothamBold
    nameLbl.TextSize         = 13
    nameLbl.TextXAlignment   = Enum.TextXAlignment.Left
    nameLbl.Parent           = row

    local subLbl = Instance.new("TextLabel")
    subLbl.Size             = UDim2.new(0.5,0,0,14)
    subLbl.Position         = UDim2.new(0,36,0,28)
    subLbl.BackgroundTransparency = 1
    subLbl.Text             = "click button to rebind"
    subLbl.TextColor3       = Color3.fromRGB(120,120,150)
    subLbl.Font             = Enum.Font.Gotham
    subLbl.TextSize         = 10
    subLbl.TextXAlignment   = Enum.TextXAlignment.Left
    subLbl.Parent           = row

    local keyBtn = Instance.new("TextButton")
    keyBtn.Size             = UDim2.new(0,110,0,34)
    keyBtn.AnchorPoint      = Vector2.new(1,0.5)
    keyBtn.Position         = UDim2.new(1,-10,0.5,0)
    keyBtn.BackgroundColor3 = Color3.fromRGB(185,28,28)
    keyBtn.Text             = "[ " .. Settings.LockOnKey.Name .. " ]"
    keyBtn.TextColor3       = Color3.fromRGB(255,255,255)
    keyBtn.Font             = Enum.Font.GothamBold
    keyBtn.TextSize         = 13
    keyBtn.BorderSizePixel  = 0
    keyBtn.AutoButtonColor  = false
    keyBtn.Parent           = row
    Instance.new("UICorner", keyBtn).CornerRadius = UDim.new(0,8)

    keyBtn.MouseButton1Click:Connect(function()
        BindingKey = true
        keyBtn.Text             = "Press any key..."
        keyBtn.BackgroundColor3 = Color3.fromRGB(120,100,20)
    end)
    keyBtn.MouseEnter:Connect(function()
        if not BindingKey then
            TweenService:Create(keyBtn,TweenInfo.new(0.1),{BackgroundColor3=Color3.fromRGB(220,45,45)}):Play()
        end
    end)
    keyBtn.MouseLeave:Connect(function()
        if not BindingKey then
            TweenService:Create(keyBtn,TweenInfo.new(0.1),{BackgroundColor3=Color3.fromRGB(185,28,28)}):Play()
        end
    end)

    RunService.Heartbeat:Connect(function()
        if _G.LockOnKeyChanged then
            keyBtn.Text             = "[ " .. _G.LockOnKeyChanged .. " ]"
            keyBtn.BackgroundColor3 = Color3.fromRGB(185,28,28)
            _G.LockOnKeyChanged     = nil
        end
    end)
end

-- ──────────────────────────────────────────────────────────
--  WIDGET: Status bar
-- ──────────────────────────────────────────────────────────
local function MakeStatusRow(order)
    local row = Instance.new("Frame")
    row.Size             = UDim2.new(1,0,0,34)
    row.BackgroundColor3 = Color3.fromRGB(16,16,28)
    row.BorderSizePixel  = 0
    row.LayoutOrder      = order
    row.Parent           = Content
    Instance.new("UICorner", row).CornerRadius = UDim.new(0,8)

    local dot = Instance.new("Frame")
    dot.Size             = UDim2.new(0,10,0,10)
    dot.Position         = UDim2.new(0,12,0.5,-5)
    dot.BackgroundColor3 = Color3.fromRGB(60,60,85)
    dot.BorderSizePixel  = 0
    dot.Parent           = row
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1,0)

    local lbl = Instance.new("TextLabel")
    lbl.Size             = UDim2.new(1,-32,1,0)
    lbl.Position         = UDim2.new(0,28,0,0)
    lbl.BackgroundTransparency = 1
    lbl.Text             = "No Target"
    lbl.TextColor3       = Color3.fromRGB(130,130,155)
    lbl.Font             = Enum.Font.Gotham
    lbl.TextSize         = 11
    lbl.TextXAlignment   = Enum.TextXAlignment.Left
    lbl.Parent           = row

    RunService.RenderStepped:Connect(function()
        if IsLocked and LockedTarget then
            dot.BackgroundColor3 = Color3.fromRGB(255,45,45)
            lbl.Text             = "🔒 Locked → " .. LockedTarget.DisplayName
            lbl.TextColor3       = Color3.fromRGB(255,100,100)
        else
            dot.BackgroundColor3 = Color3.fromRGB(60,60,85)
            lbl.Text             = "No Target"
            lbl.TextColor3       = Color3.fromRGB(130,130,155)
        end
    end)
end

-- ──────────────────────────────────────────────────────────
--  BUILD  UI
-- ──────────────────────────────────────────────────────────
MakeKeybindRow(1)

MakeNumberRow("🎮", "Rumble",       0, 100, 1,  Settings.Rumble,      2, function(v) Settings.Rumble      = v end)
MakeNumberRow("🎯", "Deadzone",     0, 100, 1,  Settings.Deadzone,    3, function(v) Settings.Deadzone    = v end)
MakeNumberRow("🖱️", "Sensitivity", 0, 500, 5,  Settings.Sensitivity, 4, function(v) Settings.Sensitivity = v end)
MakeNumberRow("⚡", "Lock On Speed",0, 10,  1,  Settings.LockOnSpeed, 5, function(v) Settings.LockOnSpeed = v end)

MakeToggleRow("✅", "Lock-On Enabled", Settings.Enabled, 6, function(v)
    Settings.Enabled = v
    if not v then IsLocked = false; LockedTarget = nil end
end)

MakeStatusRow(7)

-- ──────────────────────────────────────────────────────────
--  Right Shift toggle
-- ──────────────────────────────────────────────────────────
_G.ToggleUI = function(visible)
    TweenService:Create(Panel, TweenInfo.new(0.25, Enum.EasingStyle.Quart), {
        BackgroundTransparency = visible and 0 or 1
    }):Play()
    for _, d in ipairs(Panel:GetDescendants()) do
        if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") or d:IsA("Frame") then
            TweenService:Create(d, TweenInfo.new(0.2), {
                BackgroundTransparency = visible and (d.BackgroundTransparency < 0.9 and d.BackgroundTransparency or d.BackgroundTransparency) or 1
            }):Play()
        end
    end
    Panel.Visible = visible
end

-- ──────────────────────────────────────────────────────────
--  Crosshair
-- ──────────────────────────────────────────────────────────
local CHFrame = Instance.new("Frame")
CHFrame.Size             = UDim2.new(0,20,0,20)
CHFrame.AnchorPoint      = Vector2.new(0.5,0.5)
CHFrame.Position         = UDim2.new(0.5,0,0.5,0)
CHFrame.BackgroundTransparency = 1
CHFrame.Parent           = SG

local function CHLine(x,y,w,h)
    local f = Instance.new("Frame")
    f.Size             = UDim2.new(0,w,0,h)
    f.Position         = UDim2.new(0,x,0,y)
    f.BackgroundColor3 = Color3.fromRGB(255,55,55)
    f.BorderSizePixel  = 0
    f.Parent           = CHFrame
end
CHLine(9,0,2,20)
CHLine(0,9,20,2)

local prevLocked = false
RunService.Heartbeat:Connect(function()
    if IsLocked and not prevLocked then
        task.spawn(function()
            for i=1,3 do
                task.wait(0.07)
                for _,c in ipairs(CHFrame:GetChildren()) do c.BackgroundColor3=Color3.fromRGB(255,255,255) end
                task.wait(0.07)
                for _,c in ipairs(CHFrame:GetChildren()) do c.BackgroundColor3=Color3.fromRGB(255,55,55) end
            end
        end)
    end
    prevLocked = IsLocked
end)

print("[LockOn] ✅ Loaded!  Key=" .. Settings.LockOnKey.Name .. "  |  RightShift = hide/show UI")
