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

    -- RIGHT SHIFT → toggle UI  (always fires, even in gpe)
    if input.KeyCode == Enum.KeyCode.RightShift then
        UIVisible = not UIVisible
        if _G.ToggleUI then _G.ToggleUI(UIVisible) end
        return
    end

    -- Keybind capture — NEVER blocked by gpe so it always works
    if BindingKey then
        if input.UserInputType == Enum.UserInputType.Keyboard then
            -- Ignore shift/ctrl/alt/escape as a keybind
            local blocked = {
                [Enum.KeyCode.LeftShift]   = true,
                [Enum.KeyCode.RightShift]  = true,
                [Enum.KeyCode.LeftControl] = true,
                [Enum.KeyCode.RightControl]= true,
                [Enum.KeyCode.LeftAlt]     = true,
                [Enum.KeyCode.RightAlt]    = true,
                [Enum.KeyCode.Escape]      = true,
            }
            if not blocked[input.KeyCode] then
                Settings.LockOnKey  = input.KeyCode
                BindingKey          = false
                _G.LockOnKeyChanged = input.KeyCode.Name
            end
        end
        return
    end

    -- Normal gameplay — respect gpe so game UI still works
    if gpe then return end
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
-- ──────────────────────────────────────────────────────────
--  PS-STYLE LOCK ON INDICATOR
--  • Triangle (▼) above target head
--  • 4 corner brackets around target
--  • Name tag + HP bar
--  • Smooth fade in/out + pulse while locked
-- ──────────────────────────────────────────────────────────

local PS_COLOR_LOCK = Color3.fromRGB(255, 70, 70)
local BRACKET_SIZE  = 28
local BRACKET_THICK = 3

-- Full-screen container, we reposition each frame
local Indicator = Instance.new("Frame")
Indicator.Name                   = "PSIndicator"
Indicator.Size                   = UDim2.new(0, 140, 0, 140)
Indicator.AnchorPoint            = Vector2.new(0.5, 0.5)
Indicator.BackgroundTransparency = 1
Indicator.Visible                = false
Indicator.ZIndex                 = 10
Indicator.Parent                 = SG

-- ▼ Triangle above head
local TriFrame = Instance.new("Frame")
TriFrame.Size                   = UDim2.new(0, 22, 0, 16)
TriFrame.AnchorPoint            = Vector2.new(0.5, 1)
TriFrame.Position               = UDim2.new(0.5, 0, 0, -8)
TriFrame.BackgroundTransparency = 1
TriFrame.ZIndex                 = 11
TriFrame.Parent                 = Indicator

local function TriLine(rot, w, xo, yo)
    local f = Instance.new("Frame")
    f.Size             = UDim2.new(0, w, 0, BRACKET_THICK)
    f.AnchorPoint      = Vector2.new(0.5, 0.5)
    f.Position         = UDim2.new(0.5, xo, 0.5, yo)
    f.Rotation         = rot
    f.BackgroundColor3 = Color3.fromRGB(255,255,255)
    f.BorderSizePixel  = 0
    f.ZIndex           = 11
    f.Parent           = TriFrame
    return f
end
local triL = TriLine(-32, 14, -5, 3)
local triR = TriLine( 32, 14,  5, 3)
local triB = TriLine(  0, 18,  0, 6)

-- Name tag
local NameTag = Instance.new("TextLabel")
NameTag.Size                    = UDim2.new(0, 140, 0, 18)
NameTag.AnchorPoint             = Vector2.new(0.5, 1)
NameTag.Position                = UDim2.new(0.5, 0, 0, -26)
NameTag.BackgroundTransparency  = 1
NameTag.Text                    = ""
NameTag.TextColor3              = Color3.fromRGB(255,255,255)
NameTag.Font                    = Enum.Font.GothamBold
NameTag.TextSize                = 13
NameTag.TextStrokeTransparency  = 0.5
NameTag.TextStrokeColor3        = Color3.fromRGB(0,0,0)
NameTag.ZIndex                  = 11
NameTag.Parent                  = Indicator

-- HP bar
local HPBarBG = Instance.new("Frame")
HPBarBG.Size               = UDim2.new(0, 90, 0, 5)
HPBarBG.AnchorPoint        = Vector2.new(0.5, 1)
HPBarBG.Position           = UDim2.new(0.5, 0, 0, -10)
HPBarBG.BackgroundColor3   = Color3.fromRGB(30,30,30)
HPBarBG.BorderSizePixel    = 0
HPBarBG.ZIndex             = 11
HPBarBG.Parent             = Indicator
Instance.new("UICorner", HPBarBG).CornerRadius = UDim.new(1,0)

local HPBarFill = Instance.new("Frame")
HPBarFill.Size             = UDim2.new(1,0,1,0)
HPBarFill.BackgroundColor3 = Color3.fromRGB(80,220,80)
HPBarFill.BorderSizePixel  = 0
HPBarFill.ZIndex           = 12
HPBarFill.Parent           = HPBarBG
Instance.new("UICorner", HPBarFill).CornerRadius = UDim.new(1,0)

-- Corner brackets
local function MakeBracket(ancX, ancY, posX, posY)
    local b = Instance.new("Frame")
    b.Size              = UDim2.new(0, BRACKET_SIZE, 0, BRACKET_SIZE)
    b.AnchorPoint       = Vector2.new(ancX, ancY)
    b.Position          = UDim2.new(posX, 0, posY, 0)
    b.BackgroundTransparency = 1
    b.ZIndex            = 11
    b.Parent            = Indicator

    local h = Instance.new("Frame")
    h.Size              = UDim2.new(0, BRACKET_SIZE, 0, BRACKET_THICK)
    h.Position          = UDim2.new(0, 0, ancY == 0 and 0 or 1, ancY == 0 and 0 or -BRACKET_THICK)
    h.BackgroundColor3  = Color3.fromRGB(255,255,255)
    h.BorderSizePixel   = 0
    h.ZIndex            = 12
    h.Parent            = b

    local v = Instance.new("Frame")
    v.Size              = UDim2.new(0, BRACKET_THICK, 0, BRACKET_SIZE)
    v.Position          = UDim2.new(ancX == 0 and 0 or 1, ancX == 0 and 0 or -BRACKET_THICK, 0, 0)
    v.BackgroundColor3  = Color3.fromRGB(255,255,255)
    v.BorderSizePixel   = 0
    v.ZIndex            = 12
    v.Parent            = b

    return b, h, v
end

local bTL,bTLh,bTLv = MakeBracket(0,0,0,0)
local bTR,bTRh,bTRv = MakeBracket(1,0,1,0)
local bBL,bBLh,bBLv = MakeBracket(0,1,0,1)
local bBR,bBRh,bBRv = MakeBracket(1,1,1,1)

local bracketParts = {bTLh,bTLv,bTRh,bTRv,bBLh,bBLv,bBRh,bBRv,triL,triR,triB}

local function SetColor(col)
    for _, p in ipairs(bracketParts) do p.BackgroundColor3 = col end
end

local function SetAlpha(a)
    NameTag.TextTransparency       = 1 - a
    NameTag.TextStrokeTransparency = 1 - (a * 0.5)
    HPBarBG.BackgroundTransparency = 1 - a
    HPBarFill.BackgroundTransparency = 1 - a
    for _, p in ipairs(bracketParts) do
        p.BackgroundTransparency = 1 - a
    end
end

SetAlpha(0)

local indAlpha = 0
local pulseT   = 0

RunService.RenderStepped:Connect(function(dt)
    if not IsLocked or not LockedTarget then
        if indAlpha > 0 then
            indAlpha = math.max(0, indAlpha - dt * 7)
            SetAlpha(indAlpha)
        end
        if indAlpha <= 0 then Indicator.Visible = false end
        return
    end

    local tc = LockedTarget.Character
    if not tc then return end
    local th  = tc:FindFirstChild("HumanoidRootPart")
    local hum = tc:FindFirstChildOfClass("Humanoid")
    if not th then return end

    local headPos = th.Position + Vector3.new(0, 3.6, 0)
    local sp, onScreen = Camera:WorldToScreenPoint(headPos)
    if not onScreen then Indicator.Visible = false; return end

    Indicator.Visible  = true
    Indicator.Position = UDim2.new(0, sp.X, 0, sp.Y)

    -- Fade in
    indAlpha = math.min(1, indAlpha + dt * 9)
    SetAlpha(indAlpha)

    -- Scale with distance
    local dist  = (Camera.CFrame.Position - th.Position).Magnitude
    local scale = math.clamp(18 / math.max(dist, 1), 0.35, 1.5)
    local bSz   = math.floor(BRACKET_SIZE * scale)
    for _, b in ipairs({bTL,bTR,bBL,bBR}) do
        b.Size = UDim2.new(0, bSz, 0, bSz)
    end

    -- Pulse red
    pulseT = pulseT + dt * 4
    local p = 0.75 + 0.25 * math.sin(pulseT)
    SetColor(Color3.fromRGB(math.floor(255*p), math.floor(65*p), math.floor(65*p)))

    -- Name
    NameTag.Text = LockedTarget.DisplayName

    -- HP
    if hum then
        local r = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
        HPBarFill.Size = UDim2.new(r, 0, 1, 0)
        HPBarFill.BackgroundColor3 =
            r > 0.5  and Color3.fromRGB(80,220,80)  or
            r > 0.25 and Color3.fromRGB(255,200,0)  or
            Color3.fromRGB(255,55,55)
    end
end)

-- Flash white on initial lock
local prevLocked = false
RunService.Heartbeat:Connect(function()
    if IsLocked and not prevLocked then
        task.spawn(function()
            for i = 1, 3 do
                SetColor(Color3.fromRGB(255,255,255))
                task.wait(0.05)
                SetColor(PS_COLOR_LOCK)
                task.wait(0.05)
            end
        end)
    end
    prevLocked = IsLocked
end)

print("[LockOn] ✅ Loaded!  Key=" .. Settings.LockOnKey.Name .. "  |  RightShift = hide/show UI")
