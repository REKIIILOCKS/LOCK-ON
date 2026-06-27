--[[
███████╗██╗  ██╗ █████╗ ██████╗ ██████╗ ██╗     ██╗███╗   ██╗███████╗██████╗
██╔════╝██║  ██║██╔══██╗██╔══██╗██╔══██╗██║     ██║████╗  ██║██╔════╝██╔══██╗
███████╗███████║███████║██████╔╝██████╔╝██║     ██║██╔██╗ ██║█████╗  ██████╔╝
╚════██║██╔══██║██╔══██║██╔══██╗██╔═══╝ ██║     ██║██║╚██╗██║██╔══╝  ██╔══██╗
███████║██║  ██║██║  ██║██║  ██║██║     ███████╗██║██║ ╚████║███████╗██║  ██║
╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚══════╝╚═╝╚═╝  ╚═══╝╚══════╝╚═╝  ╚═╝

    VERSION : 2.0
    TOGGLE  : Right Shift  OR  Right Control
    AIMBOT  : Hold aim key (default E)
    ANTI-AC : Humanize mode, jitter, safe intervals
]]

-- ═══════════════════════════════════════════════════════════════════════════
--  SERVICES
-- ═══════════════════════════════════════════════════════════════════════════
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local HapticService    = game:GetService("HapticService")
local HttpService       = game:GetService("HttpService")
local Camera           = workspace.CurrentCamera
local LocalPlayer      = Players.LocalPlayer

-- ═══════════════════════════════════════════════════════════════════════════
--  ANTI-CHEAT PROTECTION SYSTEM
--  Techniques:
--    1. Random micro-jitter on aim (looks human)
--    2. Randomized update intervals (not perfectly every frame)
--    3. Max camera speed cap (no inhuman snapping)
--    4. Aim smoothing curve (eases in/out)
--    5. Random tiny delays between aim updates
--    6. Never aim at exact part center (slight offset randomization)
--    7. Periodic aim "wobble" to simulate real mouse movement
-- ═══════════════════════════════════════════════════════════════════════════
local AC = {
    Enabled          = true,
    JitterAmount     = 0.008,   -- random noise added to aim (radians)
    MaxCameraSpeed   = 0.45,    -- max lerp alpha per frame (prevents snap)
    HumanizeOffset   = true,    -- random small offset from part center
    OffsetRange      = 0.18,    -- studs of random offset
    SkipFrameChance  = 0.04,    -- 4% chance to skip an aim frame
    WobbleAmount     = 0.003,   -- subtle sine wobble on aim
    WobbleSpeed      = 2.1,
}

local _wobbleT   = 0
local _skipTimer = 0

local function ACJitter()
    if not AC.Enabled then return Vector3.new() end
    return Vector3.new(
        (math.random()-0.5) * AC.JitterAmount * 10,
        (math.random()-0.5) * AC.JitterAmount * 10,
        0
    )
end

local function ACOffset()
    if not AC.Enabled or not AC.HumanizeOffset then return Vector3.new() end
    return Vector3.new(
        (math.random()-0.5)*2 * AC.OffsetRange,
        (math.random()-0.5)*2 * AC.OffsetRange,
        0
    )
end

local function ACShouldSkip()
    if not AC.Enabled then return false end
    return math.random() < AC.SkipFrameChance
end

local function ACAlpha(base, dt)
    local wobble = AC.Enabled and (math.sin(_wobbleT * AC.WobbleSpeed) * AC.WobbleAmount) or 0
    return math.clamp(base + wobble, 0.001, AC.MaxCameraSpeed)
end

-- ═══════════════════════════════════════════════════════════════════════════
--  SETTINGS
-- ═══════════════════════════════════════════════════════════════════════════
local AB = {                        -- AIMBOT
    Enabled        = true,
    Key            = Enum.KeyCode.E,
    Smoothness     = 8,             -- 1 snap → 30 butter smooth
    FOVRadius      = 130,
    ShowFOV        = true,
    TargetPart     = "Head",
    PredictMovement= false,
    TeamCheck      = false,
    WallCheck      = false,
    SilentAim      = false,         -- aim without moving camera (if executor supports)
}

local ESP = {                       -- ESP
    Enabled        = true,
    Boxes          = true,
    Names          = true,
    Distance       = true,
    HealthBar      = true,
    Tracers        = true,
    Skeletons      = false,
    MaxDistance    = 1000,
    BoxColor       = Color3.fromRGB(0, 200, 255),
    NameColor      = Color3.fromRGB(255,255,255),
    TracerColor    = Color3.fromRGB(0, 200, 255),
    TracerOrigin   = "Bottom",
    RainbowMode    = false,
}

-- Toggle keybinds
local TOGGLE_KEY_1 = Enum.KeyCode.RightShift
local TOGGLE_KEY_2 = Enum.KeyCode.RightControl

-- ═══════════════════════════════════════════════════════════════════════════
--  STATE
-- ═══════════════════════════════════════════════════════════════════════════
local UIVisible    = true
local BindingKey   = false
local BindingCB    = nil
local BindingBtn   = nil
local ESPObjects   = {}
local rainbowHue   = 0

-- ═══════════════════════════════════════════════════════════════════════════
--  HELPERS
-- ═══════════════════════════════════════════════════════════════════════════
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

local function GetTargetPart(p)
    local c = p.Character
    if not c then return nil end
    return c:FindFirstChild(AB.TargetPart) or c:FindFirstChild("HumanoidRootPart")
end

local function IsTeammate(p)
    if not AB.TeamCheck then return false end
    return p.Team and p.Team == LocalPlayer.Team
end

local function HasLineOfSight(part)
    if not AB.WallCheck then return true end
    local origin = Camera.CFrame.Position
    local dir    = (part.Position - origin)
    local ray    = RaycastParams.new()
    ray.FilterDescendantsInstances = {LocalPlayer.Character}
    ray.FilterType = Enum.RaycastFilterType.Exclude
    local result = workspace:Raycast(origin, dir, ray)
    return result == nil or result.Instance:IsDescendantOf(part.Parent)
end

local function ScreenCenter()
    return Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
end

local function ToScreen(pos)
    local sp, vis = Camera:WorldToScreenPoint(pos)
    return Vector2.new(sp.X, sp.Y), sp.Z, vis
end

local function DistFromCenter(sp)
    return (sp - ScreenCenter()).Magnitude
end

local function Rainbow(speed)
    rainbowHue = (rainbowHue + speed) % 1
    return Color3.fromHSV(rainbowHue, 1, 1)
end

-- ═══════════════════════════════════════════════════════════════════════════
--  AIMBOT CORE
-- ═══════════════════════════════════════════════════════════════════════════
local function GetBestTarget()
    local best, bestDist = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p == LocalPlayer or not IsAlive(p) or IsTeammate(p) then continue end
        local part = GetTargetPart(p)
        if not part then continue end
        local sp, depth, vis = ToScreen(part.Position)
        if not vis or depth < 0 then continue end
        if not HasLineOfSight(part) then continue end
        local d = DistFromCenter(sp)
        if d < AB.FOVRadius and d < bestDist then
            bestDist = d; best = p
        end
    end
    return best
end

RunService.RenderStepped:Connect(function(dt)
    _wobbleT = _wobbleT + dt

    if not AB.Enabled then return end
    if not UserInputService:IsKeyDown(AB.Key) then return end
    if ACShouldSkip() then return end

    local target = GetBestTarget()
    if not target then return end
    local part = GetTargetPart(target)
    if not part then return end

    local aimPos = part.Position + ACOffset()

    if AB.PredictMovement then
        local hrp = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            local d = (Camera.CFrame.Position - aimPos).Magnitude
            aimPos = aimPos + hrp.AssemblyLinearVelocity * (d / 600)
        end
    end

    aimPos = aimPos + ACJitter()

    local smooth   = math.clamp(AB.Smoothness, 1, 50)
    local baseAlpha= 1 / smooth
    local alpha    = ACAlpha(baseAlpha, dt)

    local targetCF = CFrame.lookAt(Camera.CFrame.Position, aimPos)
    Camera.CFrame  = Camera.CFrame:Lerp(targetCF, alpha)
end)

-- ═══════════════════════════════════════════════════════════════════════════
--  SCREEN GUI
-- ═══════════════════════════════════════════════════════════════════════════
local SG = Instance.new("ScreenGui")
SG.Name           = "SharpLiner"
SG.ResetOnSpawn   = false
SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
SG.IgnoreGuiInset = true
SG.Parent         = LocalPlayer.PlayerGui

-- ═══════════════════════════════════════════════════════════════════════════
--  FOV CIRCLE
-- ═══════════════════════════════════════════════════════════════════════════
local FOVHolder = Instance.new("Frame")
FOVHolder.Name             = "FOV"
FOVHolder.Size             = UDim2.new(0, AB.FOVRadius*2, 0, AB.FOVRadius*2)
FOVHolder.AnchorPoint      = Vector2.new(0.5,0.5)
FOVHolder.Position         = UDim2.new(0.5,0,0.5,0)
FOVHolder.BackgroundTransparency = 1
FOVHolder.BorderSizePixel  = 0
FOVHolder.ZIndex           = 5
FOVHolder.Parent           = SG
Instance.new("UICorner", FOVHolder).CornerRadius = UDim.new(1,0)

local FOVStroke = Instance.new("UIStroke")
FOVStroke.Color       = Color3.fromRGB(0,200,255)
FOVStroke.Thickness   = 1.2
FOVStroke.Transparency= 0.15
FOVStroke.Parent      = FOVHolder

-- FOV dot segments (dashed look)
local NUM_DOTS = 36
local dotFrames = {}
for i = 1, NUM_DOTS do
    local dot = Instance.new("Frame")
    dot.Size             = UDim2.new(0, 4, 0, 4)
    dot.AnchorPoint      = Vector2.new(0.5,0.5)
    dot.BackgroundColor3 = Color3.fromRGB(0,200,255)
    dot.BorderSizePixel  = 0
    dot.ZIndex           = 6
    dot.Parent           = FOVHolder
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1,0)
    table.insert(dotFrames, dot)
end

RunService.RenderStepped:Connect(function(dt)
    local show = AB.ShowFOV and AB.Enabled and UIVisible
    FOVHolder.Visible = show
    if not show then return end

    local r = AB.FOVRadius
    FOVHolder.Size = UDim2.new(0, r*2, 0, r*2)

    local col = ESP.RainbowMode and Rainbow(dt*0.3) or Color3.fromRGB(0,200,255)
    FOVStroke.Color = col

    -- update dots position around circle
    for i, dot in ipairs(dotFrames) do
        local angle = (i-1) / NUM_DOTS * math.pi * 2
        local nx = 0.5 + 0.5 * math.cos(angle)
        local ny = 0.5 + 0.5 * math.sin(angle)
        -- show every other dot for dashed look
        dot.Visible          = (i % 2 == 0)
        dot.Position         = UDim2.new(nx, 0, ny, 0)
        dot.BackgroundColor3 = col
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
--  ESP SYSTEM
-- ═══════════════════════════════════════════════════════════════════════════
local function NewLine(parent, zindex)
    local f = Instance.new("Frame")
    f.BackgroundColor3 = ESP.BoxColor
    f.BorderSizePixel  = 0
    f.ZIndex           = zindex or 3
    f.Parent           = parent
    return f
end

local function CreateESP(p)
    if ESPObjects[p] then return end
    local o = {}

    -- box holder
    local bh = Instance.new("Frame")
    bh.BackgroundTransparency=1; bh.BorderSizePixel=0; bh.ZIndex=3; bh.Parent=SG
    o.bh = bh

    -- corner brackets (8 lines = 4 corners × 2 arms)
    o.corners = {}
    for i = 1, 8 do
        local f = NewLine(SG, 4)
        table.insert(o.corners, f)
    end

    -- name
    local nl = Instance.new("TextLabel")
    nl.BackgroundTransparency=1; nl.Font=Enum.Font.GothamBold
    nl.TextSize=13; nl.TextStrokeTransparency=0.3
    nl.TextStrokeColor3=Color3.new(0,0,0)
    nl.TextColor3=ESP.NameColor; nl.ZIndex=5
    nl.Size=UDim2.new(0,200,0,16); nl.AnchorPoint=Vector2.new(0.5,1)
    nl.Parent=SG; o.nl=nl

    -- dist
    local dl = Instance.new("TextLabel")
    dl.BackgroundTransparency=1; dl.Font=Enum.Font.Gotham
    dl.TextSize=11; dl.TextStrokeTransparency=0.4
    dl.TextStrokeColor3=Color3.new(0,0,0)
    dl.TextColor3=Color3.fromRGB(180,180,180); dl.ZIndex=5
    dl.Size=UDim2.new(0,200,0,14); dl.AnchorPoint=Vector2.new(0.5,0)
    dl.Parent=SG; o.dl=dl

    -- hp bar bg
    local hbg = Instance.new("Frame")
    hbg.BackgroundColor3=Color3.fromRGB(15,15,15); hbg.BorderSizePixel=0; hbg.ZIndex=3
    hbg.Parent=SG; o.hbg=hbg
    Instance.new("UICorner",hbg).CornerRadius=UDim.new(1,0)

    local hfill = Instance.new("Frame")
    hfill.BackgroundColor3=Color3.fromRGB(80,220,80); hfill.BorderSizePixel=0; hfill.ZIndex=4
    hfill.Parent=hbg; o.hfill=hfill
    Instance.new("UICorner",hfill).CornerRadius=UDim.new(1,0)

    -- tracer
    local tr = Instance.new("Frame")
    tr.BackgroundColor3=ESP.TracerColor; tr.BorderSizePixel=0
    tr.AnchorPoint=Vector2.new(0,0.5); tr.ZIndex=2; tr.Parent=SG; o.tr=tr

    ESPObjects[p] = o
end

local function RemoveESP(p)
    local o = ESPObjects[p]
    if not o then return end
    o.bh:Destroy(); o.nl:Destroy(); o.dl:Destroy(); o.hbg:Destroy(); o.tr:Destroy()
    for _, c in ipairs(o.corners) do c:Destroy() end
    ESPObjects[p] = nil
end

local function HideESP(o)
    o.bh.Visible=false; o.nl.Visible=false; o.dl.Visible=false
    o.hbg.Visible=false; o.tr.Visible=false
    for _, c in ipairs(o.corners) do c.Visible=false end
end

local THICK = 1.5
local CORNER_LEN = 10  -- length of each bracket arm in px

local function DrawCornerBox(o, x1, y1, x2, y2, col)
    local w, h = x2-x1, y2-y1
    local cl   = math.min(CORNER_LEN, w*0.3, h*0.3)
    -- corners: TL, TR, BL, BR — each has H and V arm
    -- index:   1,2  3,4  5,6  7,8
    local corners = {
        -- TL H, TL V
        {x1,    y1,    cl,    THICK},
        {x1,    y1,    THICK, cl},
        -- TR H, TR V
        {x2-cl, y1,    cl,    THICK},
        {x2-THICK,y1,  THICK, cl},
        -- BL H, BL V
        {x1,    y2-THICK, cl, THICK},
        {x1,    y2-cl, THICK, cl},
        -- BR H, BR V
        {x2-cl, y2-THICK, cl, THICK},
        {x2-THICK,y2-cl, THICK, cl},
    }
    for i, c in ipairs(o.corners) do
        local d = corners[i]
        c.Visible          = true
        c.Position         = UDim2.new(0,d[1],0,d[2])
        c.Size             = UDim2.new(0,d[3],0,d[4])
        c.BackgroundColor3 = col
    end
end

local function GetBBox(char)
    local mn = Vector2.new(math.huge, math.huge)
    local mx = Vector2.new(-math.huge,-math.huge)
    local hit= false
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            local sp, depth, vis = ToScreen(part.Position)
            if vis and depth > 0 then
                hit = true
                mn = Vector2.new(math.min(mn.X, sp.X), math.min(mn.Y, sp.Y))
                mx = Vector2.new(math.max(mx.X, sp.X), math.max(mx.Y, sp.Y))
            end
        end
    end
    if not hit then return nil end
    return mn.X-4, mn.Y-6, mx.X+4, mx.Y+4
end

RunService.RenderStepped:Connect(function(dt)
    if not ESP.Enabled or not UIVisible then
        for _, o in pairs(ESPObjects) do HideESP(o) end
        return
    end

    local myHRP = GetHRP()
    local rcol  = ESP.RainbowMode and Rainbow(dt*0.2) or ESP.BoxColor

    for p, o in pairs(ESPObjects) do
        if not IsAlive(p) then HideESP(o); continue end
        local char = p.Character
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp or not myHRP then HideESP(o); continue end

        local d3 = (myHRP.Position - hrp.Position).Magnitude
        if d3 > ESP.MaxDistance then HideESP(o); continue end

        local headSP, _, hVis = ToScreen(hrp.Position + Vector3.new(0,3.5,0))
        if not hVis then HideESP(o); continue end

        -- bbox
        local x1, y1, x2, y2 = GetBBox(char)
        local hum = char:FindFirstChildOfClass("Humanoid")
        local hp  = hum and math.clamp(hum.Health/math.max(hum.MaxHealth,1),0,1) or 1
        local hpCol = hp>0.6 and Color3.fromRGB(80,220,80) or hp>0.3 and Color3.fromRGB(255,200,0) or Color3.fromRGB(255,55,55)

        if x1 and ESP.Boxes then
            DrawCornerBox(o, x1, y1, x2, y2, rcol)
        else
            for _, c in ipairs(o.corners) do c.Visible=false end
        end

        -- HP bar left of box
        if x1 and ESP.HealthBar and hum then
            o.hbg.Visible   = true
            o.hbg.Position  = UDim2.new(0,x1-7,0,y1)
            o.hbg.Size      = UDim2.new(0,4,0,y2-y1)
            o.hfill.Size    = UDim2.new(1,0,hp,0)
            o.hfill.Position= UDim2.new(0,0,1-hp,0)
            o.hfill.BackgroundColor3=hpCol
        else
            o.hbg.Visible=false
        end

        -- Name
        if ESP.Names then
            o.nl.Visible  = true
            o.nl.Text     = p.DisplayName
            o.nl.TextColor3 = rcol
            o.nl.Position = UDim2.new(0, x1 and (x1+x2)/2 or headSP.X, 0, (y1 or headSP.Y)-2)
        else
            o.nl.Visible=false
        end

        -- Distance
        if ESP.Distance then
            o.dl.Visible  = true
            o.dl.Text     = math.floor(d3).."m"
            o.dl.Position = UDim2.new(0, x1 and (x1+x2)/2 or headSP.X, 0, (y2 or headSP.Y)+2)
        else
            o.dl.Visible=false
        end

        -- Tracer
        if ESP.Tracers then
            local vp = Camera.ViewportSize
            local oy = ESP.TracerOrigin=="Bottom" and vp.Y or ESP.TracerOrigin=="Top" and 0 or vp.Y/2
            local ox = vp.X/2
            local tx, ty = headSP.X, headSP.Y
            local dx,dy  = tx-ox, ty-oy
            local len    = math.sqrt(dx*dx+dy*dy)
            o.tr.Visible   = true
            o.tr.Position  = UDim2.new(0,ox,0,oy)
            o.tr.Size      = UDim2.new(0,len,0,THICK)
            o.tr.Rotation  = math.deg(math.atan2(dy,dx))
            o.tr.BackgroundColor3 = rcol
        else
            o.tr.Visible=false
        end
    end
end)

for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then CreateESP(p) end
end
Players.PlayerAdded:Connect(function(p) if p~=LocalPlayer then CreateESP(p) end end)
Players.PlayerRemoving:Connect(RemoveESP)

-- ═══════════════════════════════════════════════════════════════════════════
--  PANEL GUI — SHARPLINER THEME
--  Dark obsidian bg · cyan/white accent · sharp corners · glass effect
-- ═══════════════════════════════════════════════════════════════════════════
local CYAN   = Color3.fromRGB(0,200,255)
local DARK   = Color3.fromRGB(6,8,14)
local CARD   = Color3.fromRGB(12,14,24)
local CARD2  = Color3.fromRGB(18,20,34)
local WHITE  = Color3.fromRGB(255,255,255)
local GREY   = Color3.fromRGB(140,145,165)
local RED    = Color3.fromRGB(255,60,60)

local function MakeDraggable(panel, handle)
    local drag,ds,sp2=false,nil,nil
    handle.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then
            drag=true;ds=i.Position;sp2=panel.Position end
    end)
    handle.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=false end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if drag and i.UserInputType==Enum.UserInputType.MouseMovement then
            local d=i.Position-ds
            panel.Position=UDim2.new(sp2.X.Scale,sp2.X.Offset+d.X,sp2.Y.Scale,sp2.Y.Offset+d.Y)
        end
    end)
end

-- ── Root panel ──────────────────────────────────────────
local Panel = Instance.new("Frame")
Panel.Name             = "SharpLinerPanel"
Panel.Size             = UDim2.new(0,340,0,0)
Panel.AutomaticSize    = Enum.AutomaticSize.Y
Panel.Position         = UDim2.new(1,-364,0.5,-260)
Panel.BackgroundColor3 = DARK
Panel.BorderSizePixel  = 0
Panel.Active           = true
Panel.ClipsDescendants = false
Panel.Parent           = SG
Instance.new("UICorner",Panel).CornerRadius=UDim.new(0,16)

-- outer glow via UIStroke animation
local PanelStroke = Instance.new("UIStroke")
PanelStroke.Color       = CYAN
PanelStroke.Thickness   = 1.5
PanelStroke.Transparency= 0.4
PanelStroke.Parent      = Panel

-- Animate stroke glow
local strokeDir = 1
RunService.Heartbeat:Connect(function(dt)
    if not UIVisible then return end
    PanelStroke.Transparency = PanelStroke.Transparency + strokeDir * dt * 0.6
    if PanelStroke.Transparency >= 0.8 then strokeDir=-1
    elseif PanelStroke.Transparency <= 0.15 then strokeDir=1 end
end)

-- ── Top gradient bar (2px) ───────────────────────────────
local TopBar = Instance.new("Frame")
TopBar.Size             = UDim2.new(1,0,0,2)
TopBar.BackgroundColor3 = CYAN
TopBar.BorderSizePixel  = 0
TopBar.ZIndex           = 3
TopBar.Parent           = Panel
Instance.new("UIGradient",TopBar).Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(0,100,200)),
    ColorSequenceKeypoint.new(0.5, CYAN),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(120,0,255)),
}

-- ── Header ───────────────────────────────────────────────
local Header = Instance.new("Frame")
Header.Name            = "Header"
Header.Size            = UDim2.new(1,0,0,64)
Header.BackgroundTransparency=1
Header.BorderSizePixel = 0
Header.ZIndex          = 2
Header.Parent          = Panel

MakeDraggable(Panel, Header)

-- Logo mark
local LogoMark = Instance.new("Frame")
LogoMark.Size             = UDim2.new(0,36,0,36)
LogoMark.Position         = UDim2.new(0,14,0,14)
LogoMark.BackgroundColor3 = CYAN
LogoMark.BorderSizePixel  = 0
LogoMark.ZIndex           = 3
LogoMark.Parent           = Header
Instance.new("UICorner",LogoMark).CornerRadius=UDim.new(0,8)

local LogoTxt = Instance.new("TextLabel")
LogoTxt.Size=UDim2.new(1,0,1,0); LogoTxt.BackgroundTransparency=1
LogoTxt.Text="S"; LogoTxt.Font=Enum.Font.GothamBold; LogoTxt.TextSize=22
LogoTxt.TextColor3=DARK; LogoTxt.ZIndex=4; LogoTxt.Parent=LogoMark

-- Title
local TitleLbl = Instance.new("TextLabel")
TitleLbl.Size=UDim2.new(0,180,0,22); TitleLbl.Position=UDim2.new(0,58,0,12)
TitleLbl.BackgroundTransparency=1; TitleLbl.Text="SharpLiner"
TitleLbl.Font=Enum.Font.GothamBold; TitleLbl.TextSize=18
TitleLbl.TextColor3=WHITE; TitleLbl.TextXAlignment=Enum.TextXAlignment.Left
TitleLbl.ZIndex=3; TitleLbl.Parent=Header

-- Subtitle
local SubLbl = Instance.new("TextLabel")
SubLbl.Size=UDim2.new(0,200,0,14); SubLbl.Position=UDim2.new(0,58,0,34)
SubLbl.BackgroundTransparency=1; SubLbl.Text="v2.0  ·  RShift / RCtrl = toggle"
SubLbl.Font=Enum.Font.Gotham; SubLbl.TextSize=10
SubLbl.TextColor3=GREY; SubLbl.TextXAlignment=Enum.TextXAlignment.Left
SubLbl.ZIndex=3; SubLbl.Parent=Header

-- Status pill top-right
local StatusPill = Instance.new("Frame")
StatusPill.Size=UDim2.new(0,70,0,22); StatusPill.AnchorPoint=Vector2.new(1,0.5)
StatusPill.Position=UDim2.new(1,-12,0,32); StatusPill.BackgroundColor3=Color3.fromRGB(0,40,20)
StatusPill.BorderSizePixel=0; StatusPill.ZIndex=3; StatusPill.Parent=Header
Instance.new("UICorner",StatusPill).CornerRadius=UDim.new(1,0)

local StatusDot = Instance.new("Frame")
StatusDot.Size=UDim2.new(0,8,0,8); StatusDot.AnchorPoint=Vector2.new(0,0.5)
StatusDot.Position=UDim2.new(0,8,0.5,0); StatusDot.BackgroundColor3=Color3.fromRGB(0,220,80)
StatusDot.BorderSizePixel=0; StatusDot.ZIndex=4; StatusDot.Parent=StatusPill
Instance.new("UICorner",StatusDot).CornerRadius=UDim.new(1,0)

local StatusLbl = Instance.new("TextLabel")
StatusLbl.Size=UDim2.new(1,-20,1,0); StatusLbl.Position=UDim2.new(0,20,0,0)
StatusLbl.BackgroundTransparency=1; StatusLbl.Text="ON"
StatusLbl.Font=Enum.Font.GothamBold; StatusLbl.TextSize=11
StatusLbl.TextColor3=Color3.fromRGB(0,220,80); StatusLbl.ZIndex=4
StatusLbl.TextXAlignment=Enum.TextXAlignment.Left; StatusLbl.Parent=StatusPill

RunService.Heartbeat:Connect(function()
    local on = AB.Enabled or ESP.Enabled
    StatusDot.BackgroundColor3    = on and Color3.fromRGB(0,220,80) or RED
    StatusLbl.TextColor3          = on and Color3.fromRGB(0,220,80) or RED
    StatusPill.BackgroundColor3   = on and Color3.fromRGB(0,40,20)  or Color3.fromRGB(40,0,0)
    StatusLbl.Text                = on and "ON" or "OFF"
end)

-- Divider under header
local Divider = Instance.new("Frame")
Divider.Size=UDim2.new(1,-28,0,1); Divider.Position=UDim2.new(0,14,0,64)
Divider.BackgroundColor3=Color3.fromRGB(30,33,55); Divider.BorderSizePixel=0
Divider.ZIndex=2; Divider.Parent=Panel

-- ── Tab bar ──────────────────────────────────────────────
local TabBar = Instance.new("Frame")
TabBar.Size=UDim2.new(1,-28,0,34); TabBar.Position=UDim2.new(0,14,0,72)
TabBar.BackgroundColor3=CARD2; TabBar.BorderSizePixel=0; TabBar.ZIndex=2; TabBar.Parent=Panel
Instance.new("UICorner",TabBar).CornerRadius=UDim.new(0,10)

local TabLayout=Instance.new("UIListLayout"); TabLayout.FillDirection=Enum.FillDirection.Horizontal
TabLayout.Padding=UDim.new(0,4); TabLayout.VerticalAlignment=Enum.VerticalAlignment.Center
local TabPad=Instance.new("UIPadding"); TabPad.PaddingLeft=UDim.new(0,4); TabPad.PaddingRight=UDim.new(0,4)
TabLayout.Parent=TabBar; TabPad.Parent=TabBar

-- ── Content area ─────────────────────────────────────────
local function MakeContent()
    local f=Instance.new("Frame")
    f.Size=UDim2.new(1,-28,0,0); f.AutomaticSize=Enum.AutomaticSize.Y
    f.Position=UDim2.new(0,14,0,114); f.BackgroundTransparency=1
    f.BorderSizePixel=0; f.Visible=false; f.Parent=Panel
    local p=Instance.new("UIPadding"); p.PaddingBottom=UDim.new(0,14); p.Parent=f
    local l=Instance.new("UIListLayout"); l.SortOrder=Enum.SortOrder.LayoutOrder
    l.Padding=UDim.new(0,6); l.Parent=f
    return f
end

local AimbotContent = MakeContent(); AimbotContent.Visible=true
local ESPContent    = MakeContent()
local ACContent     = MakeContent()

-- ── Tab builder ──────────────────────────────────────────
local tabs = {}
local currentTab = "aimbot"

local function SwitchTab(name)
    currentTab = name
    AimbotContent.Visible = name=="aimbot"
    ESPContent.Visible    = name=="esp"
    ACContent.Visible     = name=="ac"
    for tname, tdata in pairs(tabs) do
        local active = tname==name
        TweenService:Create(tdata.btn, TweenInfo.new(0.15), {
            BackgroundColor3 = active and CYAN or Color3.fromRGB(0,0,0),
            BackgroundTransparency = active and 0 or 1,
        }):Play()
        tdata.lbl.TextColor3 = active and DARK or GREY
    end
end

local function MakeTab(label, name)
    local btn=Instance.new("TextButton")
    btn.Size=UDim2.new(0,92,0,26); btn.BackgroundColor3=name==currentTab and CYAN or Color3.new()
    btn.BackgroundTransparency=name==currentTab and 0 or 1
    btn.Text=""; btn.BorderSizePixel=0; btn.AutoButtonColor=false; btn.Parent=TabBar
    Instance.new("UICorner",btn).CornerRadius=UDim.new(0,7)

    local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(1,0,1,0)
    lbl.BackgroundTransparency=1; lbl.Text=label; lbl.Font=Enum.Font.GothamBold
    lbl.TextSize=11; lbl.TextColor3=name==currentTab and DARK or GREY
    lbl.ZIndex=3; lbl.Parent=btn

    btn.MouseButton1Click:Connect(function() SwitchTab(name) end)
    tabs[name]={btn=btn,lbl=lbl}
end

MakeTab("🎯  Aimbot","aimbot")
MakeTab("👁  ESP","esp")
MakeTab("🛡  Anti-AC","ac")

-- ═══════════════════════════════════════════════════════════════════════════
--  WIDGET FACTORIES
-- ═══════════════════════════════════════════════════════════════════════════

-- Section header
local function MakeSection(parent, label, order)
    local f=Instance.new("Frame"); f.Size=UDim2.new(1,0,0,24)
    f.BackgroundTransparency=1; f.LayoutOrder=order; f.Parent=parent
    local l=Instance.new("TextLabel"); l.Size=UDim2.new(1,0,1,0)
    l.BackgroundTransparency=1; l.Text=label:upper()
    l.Font=Enum.Font.GothamBold; l.TextSize=9; l.TextColor3=CYAN
    l.TextXAlignment=Enum.TextXAlignment.Left; l.Parent=f
    local line=Instance.new("Frame"); line.Size=UDim2.new(1,0,0,1)
    line.Position=UDim2.new(0,0,1,-1); line.BackgroundColor3=Color3.fromRGB(25,28,50)
    line.BorderSizePixel=0; line.Parent=f
end

-- Toggle row
local function MakeToggle(parent, icon, label, val, order, cb)
    local row=Instance.new("Frame"); row.Size=UDim2.new(1,0,0,42)
    row.BackgroundColor3=CARD; row.BorderSizePixel=0; row.LayoutOrder=order; row.Parent=parent
    Instance.new("UICorner",row).CornerRadius=UDim.new(0,10)

    local ico=Instance.new("TextLabel"); ico.Size=UDim2.new(0,20,1,0); ico.Position=UDim2.new(0,10,0,0)
    ico.BackgroundTransparency=1; ico.Text=icon; ico.TextSize=15; ico.Font=Enum.Font.GothamBold
    ico.TextColor3=WHITE; ico.Parent=row

    local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(0.58,0,1,0); lbl.Position=UDim2.new(0,34,0,0)
    lbl.BackgroundTransparency=1; lbl.Text=label; lbl.TextColor3=Color3.fromRGB(210,215,230)
    lbl.Font=Enum.Font.Gotham; lbl.TextSize=12; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Parent=row

    local tbg=Instance.new("Frame"); tbg.Size=UDim2.new(0,44,0,22); tbg.AnchorPoint=Vector2.new(1,0.5)
    tbg.Position=UDim2.new(1,-10,0.5,0)
    tbg.BackgroundColor3=val and CYAN or Color3.fromRGB(35,38,60)
    tbg.BorderSizePixel=0; tbg.Parent=row
    Instance.new("UICorner",tbg).CornerRadius=UDim.new(1,0)

    local knob=Instance.new("Frame"); knob.Size=UDim2.new(0,18,0,18); knob.AnchorPoint=Vector2.new(0.5,0.5)
    knob.Position=val and UDim2.new(1,-12,0.5,0) or UDim2.new(0,12,0.5,0)
    knob.BackgroundColor3=val and DARK or WHITE; knob.BorderSizePixel=0; knob.Parent=tbg
    Instance.new("UICorner",knob).CornerRadius=UDim.new(1,0)

    local s=val
    local btn=Instance.new("TextButton"); btn.Size=UDim2.new(1,0,1,0)
    btn.BackgroundTransparency=1; btn.Text=""; btn.Parent=row
    btn.MouseButton1Click:Connect(function()
        s=not s
        TweenService:Create(tbg,TweenInfo.new(0.15),{BackgroundColor3=s and CYAN or Color3.fromRGB(35,38,60)}):Play()
        TweenService:Create(knob,TweenInfo.new(0.15),{
            Position=s and UDim2.new(1,-12,0.5,0) or UDim2.new(0,12,0.5,0),
            BackgroundColor3=s and DARK or WHITE,
        }):Play()
        if cb then cb(s) end
    end)

    -- hover
    row.MouseEnter:Connect(function()
        TweenService:Create(row,TweenInfo.new(0.1),{BackgroundColor3=CARD2}):Play()
    end)
    row.MouseLeave:Connect(function()
        TweenService:Create(row,TweenInfo.new(0.1),{BackgroundColor3=CARD}):Play()
    end)
end

-- Slider row
local function MakeSlider(parent, icon, label, minV, maxV, step, defV, order, cb)
    local row=Instance.new("Frame"); row.Size=UDim2.new(1,0,0,54)
    row.BackgroundColor3=CARD; row.BorderSizePixel=0; row.LayoutOrder=order; row.Parent=parent
    Instance.new("UICorner",row).CornerRadius=UDim.new(0,10)

    local ico=Instance.new("TextLabel"); ico.Size=UDim2.new(0,20,0,26); ico.Position=UDim2.new(0,10,0,6)
    ico.BackgroundTransparency=1; ico.Text=icon; ico.TextSize=14; ico.Font=Enum.Font.GothamBold
    ico.TextColor3=WHITE; ico.Parent=row

    local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(0.52,0,0,22); lbl.Position=UDim2.new(0,34,0,5)
    lbl.BackgroundTransparency=1; lbl.Text=label; lbl.TextColor3=Color3.fromRGB(210,215,230)
    lbl.Font=Enum.Font.Gotham; lbl.TextSize=12; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Parent=row

    -- value badge
    local vbg=Instance.new("Frame"); vbg.Size=UDim2.new(0,48,0,22); vbg.AnchorPoint=Vector2.new(1,0)
    vbg.Position=UDim2.new(1,-8,0,5); vbg.BackgroundColor3=CARD2; vbg.BorderSizePixel=0; vbg.Parent=row
    Instance.new("UICorner",vbg).CornerRadius=UDim.new(0,6)
    local vs=Instance.new("UIStroke"); vs.Color=CYAN; vs.Thickness=1; vs.Transparency=0.6; vs.Parent=vbg

    local vlbl=Instance.new("TextLabel"); vlbl.Size=UDim2.new(1,0,1,0); vlbl.BackgroundTransparency=1
    vlbl.Text=tostring(defV); vlbl.Font=Enum.Font.GothamBold; vlbl.TextSize=12
    vlbl.TextColor3=CYAN; vlbl.Parent=vbg

    -- track
    local track=Instance.new("Frame"); track.Size=UDim2.new(1,-20,0,4); track.Position=UDim2.new(0,10,1,-12)
    track.BackgroundColor3=Color3.fromRGB(25,28,50); track.BorderSizePixel=0; track.Parent=row
    Instance.new("UICorner",track).CornerRadius=UDim.new(1,0)

    local fill=Instance.new("Frame"); fill.Size=UDim2.new((defV-minV)/(maxV-minV),0,1,0)
    fill.BackgroundColor3=CYAN; fill.BorderSizePixel=0; fill.Parent=track
    Instance.new("UICorner",fill).CornerRadius=UDim.new(1,0)

    local knob=Instance.new("Frame"); knob.Size=UDim2.new(0,12,0,12); knob.AnchorPoint=Vector2.new(0.5,0.5)
    knob.Position=UDim2.new((defV-minV)/(maxV-minV),0,0.5,0); knob.BackgroundColor3=WHITE
    knob.BorderSizePixel=0; knob.ZIndex=4; knob.Parent=track
    Instance.new("UICorner",knob).CornerRadius=UDim.new(1,0)

    local cur=defV
    local function Set(v)
        v=math.clamp(math.floor(v/step+0.5)*step,minV,maxV)
        cur=v; vlbl.Text=tostring(v)
        local rel=(v-minV)/(maxV-minV)
        TweenService:Create(fill,TweenInfo.new(0.08),{Size=UDim2.new(rel,0,1,0)}):Play()
        TweenService:Create(knob,TweenInfo.new(0.08),{Position=UDim2.new(rel,0,0.5,0)}):Play()
        if cb then cb(v) end
    end

    local dragging=false
    track.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then
            dragging=true
            local rel=math.clamp((i.Position.X-track.AbsolutePosition.X)/track.AbsoluteSize.X,0,1)
            Set(minV+rel*(maxV-minV))
        end
    end)
    track.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and i.UserInputType==Enum.UserInputType.MouseMovement then
            local rel=math.clamp((i.Position.X-track.AbsolutePosition.X)/track.AbsoluteSize.X,0,1)
            Set(minV+rel*(maxV-minV))
        end
    end)
    knob.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=true end
    end)
    knob.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end
    end)

    row.MouseEnter:Connect(function()
        TweenService:Create(row,TweenInfo.new(0.1),{BackgroundColor3=CARD2}):Play()
    end)
    row.MouseLeave:Connect(function()
        TweenService:Create(row,TweenInfo.new(0.1),{BackgroundColor3=CARD}):Play()
    end)
end

-- Keybind row
local function MakeKeybind(parent, label, curKey, order, cb)
    local row=Instance.new("Frame"); row.Size=UDim2.new(1,0,0,42)
    row.BackgroundColor3=CARD; row.BorderSizePixel=0; row.LayoutOrder=order; row.Parent=parent
    Instance.new("UICorner",row).CornerRadius=UDim.new(0,10)

    local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(0.55,0,1,0); lbl.Position=UDim2.new(0,12,0,0)
    lbl.BackgroundTransparency=1; lbl.Text="⌨  "..label; lbl.TextColor3=Color3.fromRGB(210,215,230)
    lbl.Font=Enum.Font.Gotham; lbl.TextSize=12; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Parent=row

    local kbtn=Instance.new("TextButton"); kbtn.Size=UDim2.new(0,118,0,28); kbtn.AnchorPoint=Vector2.new(1,0.5)
    kbtn.Position=UDim2.new(1,-8,0.5,0); kbtn.BackgroundColor3=CARD2; kbtn.BorderSizePixel=0
    kbtn.Text="[ "..curKey.Name.." ]"; kbtn.TextColor3=CYAN; kbtn.Font=Enum.Font.GothamBold
    kbtn.TextSize=11; kbtn.AutoButtonColor=false; kbtn.Parent=row
    Instance.new("UICorner",kbtn).CornerRadius=UDim.new(0,7)
    local ks=Instance.new("UIStroke"); ks.Color=CYAN; ks.Thickness=1; ks.Transparency=0.5; ks.Parent=kbtn

    kbtn.MouseButton1Click:Connect(function()
        BindingKey=true; BindingCB=cb; BindingBtn=kbtn
        kbtn.Text="  listening..."; kbtn.TextColor3=Color3.fromRGB(255,200,0)
        ks.Color=Color3.fromRGB(255,200,0)
    end)
    kbtn.MouseEnter:Connect(function()
        if not BindingKey then
            TweenService:Create(kbtn,TweenInfo.new(0.1),{BackgroundColor3=Color3.fromRGB(0,30,45)}):Play()
        end
    end)
    kbtn.MouseLeave:Connect(function()
        if not BindingKey then
            TweenService:Create(kbtn,TweenInfo.new(0.1),{BackgroundColor3=CARD2}):Play()
        end
    end)
    return kbtn
end

-- Dropdown row
local function MakeDropdown(parent, icon, label, opts, defVal, order, cb)
    local row=Instance.new("Frame"); row.Size=UDim2.new(1,0,0,42)
    row.BackgroundColor3=CARD; row.BorderSizePixel=0; row.LayoutOrder=order; row.Parent=parent
    Instance.new("UICorner",row).CornerRadius=UDim.new(0,10)

    local ico=Instance.new("TextLabel"); ico.Size=UDim2.new(0,20,1,0); ico.Position=UDim2.new(0,10,0,0)
    ico.BackgroundTransparency=1; ico.Text=icon; ico.TextSize=14; ico.Font=Enum.Font.GothamBold
    ico.TextColor3=WHITE; ico.Parent=row

    local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(0.48,0,1,0); lbl.Position=UDim2.new(0,34,0,0)
    lbl.BackgroundTransparency=1; lbl.Text=label; lbl.TextColor3=Color3.fromRGB(210,215,230)
    lbl.Font=Enum.Font.Gotham; lbl.TextSize=12; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Parent=row

    local idx=1; for i,v in ipairs(opts) do if v==defVal then idx=i end end

    local dbtn=Instance.new("TextButton"); dbtn.Size=UDim2.new(0,118,0,28); dbtn.AnchorPoint=Vector2.new(1,0.5)
    dbtn.Position=UDim2.new(1,-8,0.5,0); dbtn.BackgroundColor3=CARD2; dbtn.BorderSizePixel=0
    dbtn.Text="◀  "..opts[idx].."  ▶"; dbtn.TextColor3=CYAN; dbtn.Font=Enum.Font.GothamBold
    dbtn.TextSize=10; dbtn.AutoButtonColor=false; dbtn.Parent=row
    Instance.new("UICorner",dbtn).CornerRadius=UDim.new(0,7)
    local ds=Instance.new("UIStroke"); ds.Color=CYAN; ds.Thickness=1; ds.Transparency=0.5; ds.Parent=dbtn

    dbtn.MouseButton1Click:Connect(function()
        idx=idx%#opts+1; dbtn.Text="◀  "..opts[idx].."  ▶"
        if cb then cb(opts[idx]) end
    end)
    dbtn.MouseEnter:Connect(function()
        TweenService:Create(dbtn,TweenInfo.new(0.1),{BackgroundColor3=Color3.fromRGB(0,30,45)}):Play()
    end)
    dbtn.MouseLeave:Connect(function()
        TweenService:Create(dbtn,TweenInfo.new(0.1),{BackgroundColor3=CARD2}):Play()
    end)
end

-- Info row (read-only text)
local function MakeInfoRow(parent, label, val, order)
    local row=Instance.new("Frame"); row.Size=UDim2.new(1,0,0,34)
    row.BackgroundColor3=CARD; row.BorderSizePixel=0; row.LayoutOrder=order; row.Parent=parent
    Instance.new("UICorner",row).CornerRadius=UDim.new(0,8)

    local ll=Instance.new("TextLabel"); ll.Size=UDim2.new(0.6,0,1,0); ll.Position=UDim2.new(0,12,0,0)
    ll.BackgroundTransparency=1; ll.Text=label; ll.TextColor3=GREY
    ll.Font=Enum.Font.Gotham; ll.TextSize=11; ll.TextXAlignment=Enum.TextXAlignment.Left; ll.Parent=row

    local vl=Instance.new("TextLabel"); vl.Size=UDim2.new(0.38,0,1,0); vl.Position=UDim2.new(0.62,0,0,0)
    vl.BackgroundTransparency=1; vl.Text=val; vl.TextColor3=CYAN
    vl.Font=Enum.Font.GothamBold; vl.TextSize=11; vl.TextXAlignment=Enum.TextXAlignment.Right; vl.Parent=row
end

-- ═══════════════════════════════════════════════════════════════════════════
--  BUILD AIMBOT TAB
-- ═══════════════════════════════════════════════════════════════════════════
MakeSection(AimbotContent,"  General",1)
MakeToggle(AimbotContent,"🎯","Aimbot Enabled",AB.Enabled,2,function(v) AB.Enabled=v end)
MakeKeybind(AimbotContent,"Aim Hold Key",AB.Key,3,function(k) AB.Key=k end)

MakeSection(AimbotContent,"  Targeting",10)
MakeDropdown(AimbotContent,"💀","Target Part",{"Head","HumanoidRootPart","Torso"},AB.TargetPart,11,function(v) AB.TargetPart=v end)
MakeToggle(AimbotContent,"🏃","Predict Movement",AB.PredictMovement,12,function(v) AB.PredictMovement=v end)
MakeToggle(AimbotContent,"👥","Team Check",AB.TeamCheck,13,function(v) AB.TeamCheck=v end)
MakeToggle(AimbotContent,"🧱","Wall Check",AB.WallCheck,14,function(v) AB.WallCheck=v end)

MakeSection(AimbotContent,"  FOV & Aim",20)
MakeSlider(AimbotContent,"🌀","FOV Radius",10,500,5,AB.FOVRadius,21,function(v) AB.FOVRadius=v end)
MakeToggle(AimbotContent,"⭕","Show FOV Circle",AB.ShowFOV,22,function(v) AB.ShowFOV=v end)
MakeSlider(AimbotContent,"🌊","Smoothness",1,30,1,AB.Smoothness,23,function(v) AB.Smoothness=v end)

-- ═══════════════════════════════════════════════════════════════════════════
--  BUILD ESP TAB
-- ═══════════════════════════════════════════════════════════════════════════
MakeSection(ESPContent,"  General",1)
MakeToggle(ESPContent,"👁","ESP Enabled",ESP.Enabled,2,function(v) ESP.Enabled=v end)
MakeToggle(ESPContent,"🌈","Rainbow Mode",ESP.RainbowMode,3,function(v) ESP.RainbowMode=v end)

MakeSection(ESPContent,"  Overlays",10)
MakeToggle(ESPContent,"⬜","Corner Boxes",ESP.Boxes,11,function(v) ESP.Boxes=v end)
MakeToggle(ESPContent,"🏷","Names",ESP.Names,12,function(v) ESP.Names=v end)
MakeToggle(ESPContent,"📏","Distance",ESP.Distance,13,function(v) ESP.Distance=v end)
MakeToggle(ESPContent,"❤","Health Bar",ESP.HealthBar,14,function(v) ESP.HealthBar=v end)
MakeToggle(ESPContent,"📡","Tracers",ESP.Tracers,15,function(v) ESP.Tracers=v end)

MakeSection(ESPContent,"  Range",20)
MakeSlider(ESPContent,"🔭","Max Distance",50,2000,50,ESP.MaxDistance,21,function(v) ESP.MaxDistance=v end)
MakeDropdown(ESPContent,"📍","Tracer Origin",{"Bottom","Center","Top"},ESP.TracerOrigin,22,function(v) ESP.TracerOrigin=v end)

-- ═══════════════════════════════════════════════════════════════════════════
--  BUILD ANTI-AC TAB
-- ═══════════════════════════════════════════════════════════════════════════
MakeSection(ACContent,"  Anti-Cheat Shield",1)
MakeToggle(ACContent,"🛡","Protection Enabled",AC.Enabled,2,function(v) AC.Enabled=v end)
MakeToggle(ACContent,"👆","Humanize Offset",AC.HumanizeOffset,3,function(v) AC.HumanizeOffset=v end)

MakeSection(ACContent,"  Humanizer",10)
MakeSlider(ACContent,"💨","Aim Jitter",0,20,1,math.floor(AC.JitterAmount*1000),11,function(v)
    AC.JitterAmount=v/1000
end)
MakeSlider(ACContent,"⚡","Max Cam Speed",5,100,5,math.floor(AC.MaxCameraSpeed*100),12,function(v)
    AC.MaxCameraSpeed=v/100
end)
MakeSlider(ACContent,"🎲","Skip Frame %",0,20,1,math.floor(AC.SkipFrameChance*100),13,function(v)
    AC.SkipFrameChance=v/100
end)
MakeSlider(ACContent,"〰","Wobble Amount",0,15,1,math.floor(AC.WobbleAmount*1000),14,function(v)
    AC.WobbleAmount=v/1000
end)

MakeSection(ACContent,"  Info",20)
MakeInfoRow(ACContent,"Jitter mode","randomized",21)
MakeInfoRow(ACContent,"Interval","frame-varied",22)
MakeInfoRow(ACContent,"Offset","humanized",23)
MakeInfoRow(ACContent,"Speed cap","enforced",24)

-- ═══════════════════════════════════════════════════════════════════════════
--  INPUT HANDLER
-- ═══════════════════════════════════════════════════════════════════════════
local BLOCKED_KEYS = {
    [Enum.KeyCode.LeftShift]=true,[Enum.KeyCode.RightShift]=true,
    [Enum.KeyCode.LeftControl]=true,[Enum.KeyCode.RightControl]=true,
    [Enum.KeyCode.LeftAlt]=true,[Enum.KeyCode.RightAlt]=true,
    [Enum.KeyCode.Escape]=true,[Enum.KeyCode.Insert]=true,
}

UserInputService.InputBegan:Connect(function(input, gpe)
    -- Toggle UI (always fires)
    if input.KeyCode==TOGGLE_KEY_1 or input.KeyCode==TOGGLE_KEY_2 then
        UIVisible = not UIVisible
        Panel.Visible = UIVisible
        FOVHolder.Visible = UIVisible and AB.ShowFOV and AB.Enabled
        return
    end

    -- Keybind capture (never blocked by gpe)
    if BindingKey then
        if input.UserInputType==Enum.UserInputType.Keyboard then
            if not BLOCKED_KEYS[input.KeyCode] then
                if BindingCB then BindingCB(input.KeyCode) end
                if BindingBtn then
                    BindingBtn.Text="[ "..input.KeyCode.Name.." ]"
                    BindingBtn.TextColor3=CYAN
                    local ks=BindingBtn:FindFirstChildOfClass("UIStroke")
                    if ks then ks.Color=CYAN end
                end
                BindingKey=false; BindingCB=nil; BindingBtn=nil
            end
        end
        return
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
--  BOOT ANIMATION
-- ═══════════════════════════════════════════════════════════════════════════
Panel.BackgroundTransparency = 1
for _, d in ipairs(Panel:GetDescendants()) do
    if d:IsA("TextLabel") or d:IsA("TextButton") then
        d.TextTransparency = 1
    end
end

task.spawn(function()
    task.wait(0.1)
    TweenService:Create(Panel,TweenInfo.new(0.4,Enum.EasingStyle.Quart),{BackgroundTransparency=0}):Play()
    task.wait(0.15)
    for _, d in ipairs(Panel:GetDescendants()) do
        if d:IsA("TextLabel") or d:IsA("TextButton") then
            TweenService:Create(d,TweenInfo.new(0.3),{TextTransparency=0}):Play()
        end
    end
end)

print("┌─────────────────────────────────────┐")
print("│  SharpLiner v2.0  loaded            │")
print("│  RShift / RCtrl  = toggle UI        │")
print("│  Hold "..AB.Key.Name.."            = aimbot          │")
print("└─────────────────────────────────────┘")
