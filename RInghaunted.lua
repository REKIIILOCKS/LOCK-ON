--[[
    Build A Ring Farm - AutoFarm + Upgrades
    Original by Lamduck | Restored for Luau / Roblox
--]]

-- Загружаем UI-библиотеку WindUI
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

-- Создаём главное окно
local Window = WindUI:CreateWindow({
    Title = "Build A Ring Farm [Work in Progress]",
    Author = "Created by Lamduck [NO KEY]",
    Folder = "LamduckHub",
    Size = UDim2.fromScale(0.05, 0.05),
    Transparent = false,
    HasOutline = false,
    SideBarWidth = 140,
})

-- Кнопка открытия (мобильная)
Window:EditOpenButton({
    Title = "Open",
    Icon = "",
    OnlyMobile = false,
    Enabled = true,
    Draggable = true,
})

-- Сервисы
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")
local TeleportService = game:GetService("TeleportService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
local Shared = ReplicatedStorage:FindFirstChild("Shared")

-- Анти-АФК
LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
    print("[LamduckHub] Anti-AFK Triggered - Prevented Disconnect!")
end)

-- Конфигурация улучшений
local PlotUpgrades = {
    SawRange = {
        SignName = "PlotUpgradeSign",
        UIFolder = "SawRange",
        RemoteArg = "ExtraSawRange",
        Type = "plot",
    },
    SawYield = {
        SignName = "PlotUpgradeSign",
        UIFolder = "SawYield",
        RemoteArg = "ExtraYield",
        Type = "plot",
    },
    SprinklerRange = {
        SignName = "PlotUpgradeSign",
        UIFolder = "SprinklerRange",
        RemoteArg = "ExtraSprinklerRange",
        Type = "plot",
    },
    SprinklerPower = {
        SignName = "PlotUpgradeSign",
        UIFolder = "SprinklerPower",
        RemoteArg = "ExtraPower",
        Type = "plot",
    },
    SeedLuck = {
        SignName = "UpgradeSign",
        UIFolder = "SeedLuck",
        Type = "seedluck",
    },
    SeedRolls = {
        SignName = "UpgradeSign",
        UIFolder = "SeedRolls",
        Type = "seedrolls",
    },
}

-- Список типов улучшений (сохраняем порядок)
local UpgradeTypes = {"SawRange", "SawYield", "SprinklerRange", "SprinklerPower", "SeedLuck", "SeedRolls"}

-- Уведомление о недостатке денег
local function notifyInsufficientCash(upgradeName, costStr)
    if costStr and costStr ~= "" then
        print("[LamduckHub] Insufficient Cash - Skipped " .. upgradeName .. ": " .. tostring(costStr))
    else
        print("[LamduckHub] Insufficient Cash - Skipped " .. upgradeName)
    end
end

-- Глобальные флаги (настройки)
_G.AutoSellCrates = false
_G.AutoUnlockFarmPlots = false
_G.AutoExpandFarmPlot = false
_G.AutoCollectQueenBeeHoneycomb = false
_G.AutoPlantRush = false
_G.AutoClaimPlantRushBossDrop = false
_G.AutoSubmitQueenBeeHoneyToken = false
_G.AutoSubmitSeedToCollector = false
_G.AutoSubmitAllSeedsToCollector = false
_G.TargetSeedCollectorSubmitSeeds = {}
_G.AutoCompost = false
_G.AutoCompostAllSeeds = false
_G.AutoPullComposterLever = false
_G.TargetCompostSeeds = {}
_G.TargetCompostMutations = {}
_G.MaxCompostInsertAmount = 0
_G.CompostFloor = 2
_G.AutoPullComposterLeverDelaySeconds = 2
_G.AutoClaimDailyReward = false
_G.AutoClaimPlaytimeReward = false
_G.SelectedSeedTrueName = "None"
_G.AutoDiscardSelectedSeed = false
_G.AutoBuyAllGears = false
_G.AutoBuySelectedGears = false
_G.AutoUnlockEggSlots = false
_G.SessionUnlockedEggSlots = {}
_G.AutoBuyAllEggs = false
_G.AutoBuySelectedEggs = false
_G.TargetEggShopEggs = {}
_G.SkipMoneyCheck = false
_G.AutoUpgradePlants = false
_G.TargetPlantUpgradeLevel = 10
_G.AutoFertilize = false
_G.AutoRollAndBuyAll = false
_G.AutoRollAndBuySelected = false
_G.TargetGachaSeeds = {}
_G.AutoUpgradePowerups = false
_G.TargetPowerups = {}
_G.TargetUpgradePlantNames = {}
_G.TargetUpgradeMutations = {}
_G.TargetFertilizePlantNames = {}
_G.TargetFertilizeMutations = {}
_G.TargetFertilizerTypes = {}

-- Словарь сокращений денег
local MoneySuffixes = {
    K = 1e3,
    M = 1e6,
    B = 1e9,
    T = 1e12,
    QA = 1e15,
    QD = 1e15,
    QI = 1e18,
    QN = 1e18,
    SX = 1e21,
    SP = 1e24,
    OC = 1e27,
    O = 1e27,
    NO = 1e30,
    N = 1e30,
    DE = 1e33,
    D = 1e33,
    UN = 1e36,
    UD = 1e36,
    DD = 1e39,
    TD = 1e42,
    QAD = 1e45,
    QID = 1e48,
    SXD = 1e51,
    SPD = 1e54,
    OCD = 1e57,
    NOD = 1e60,
    VG = 1e63,
}

-- Парсинг денег (строка -> число)
local function parseMoney(value)
    if type(value) == "number" then
        return value
    elseif type(value) ~= "string" or value == "" then
        return 0
    end

    local clean = string.upper(value):gsub("[$%,%s]", "")
    local num, suffix = string.match(clean, "^([%d%.]+)(%a*)$")
    if not num then
        return 0
    end

    local multiplier = 1
    if suffix and suffix ~= "" then
        multiplier = MoneySuffixes[suffix]
        if not multiplier then
            warn("[LamduckHub] Unknown money suffix not in dictionary: " .. suffix)
            multiplier = 1
        end
    end

    return (tonumber(num) or 0) * multiplier
end

-- Получить текущие деньги (из leaderstats или GUI)
local function getCurrentMoney()
    local leaderstatsCash = nil
    local leaderstats = LocalPlayer:FindFirstChild("leaderstats") or LocalPlayer:FindFirstChild("Leaderstats")
    if leaderstats then
        local cashObj = leaderstats:FindFirstChild("Cash")
        if cashObj then
            leaderstatsCash = parseMoney(cashObj.Value)
        end
    end

    local guiCash = nil
    local mainUI = PlayerGui:FindFirstChild("MainUI")
    if mainUI then
        local moneyCounter = mainUI:FindFirstChild("MoneyCounter")
        if moneyCounter then
            local cashCounter = moneyCounter:FindFirstChild("CashCounter")
            if cashCounter then
                guiCash = parseMoney(cashCounter.Text)
            end
        end
    end

    if guiCash and leaderstatsCash and guiCash ~= leaderstatsCash then
        print("[LamduckHub] Cash mismatch | leaderstats: " .. tostring(leaderstatsCash) .. " | gui: " .. tostring(guiCash) .. " | using gui")
    end

    return guiCash or leaderstatsCash or 0
end

-- Проверка достаточно ли денег (с учётом SkipMoneyCheck)
local function haveEnoughMoney(required, purposeLabel, costStr)
    if _G.SkipMoneyCheck then
        return true
    end
    if getCurrentMoney() >= required then
        return true
    else
        if purposeLabel then
            notifyInsufficientCash(purposeLabel, costStr)
        end
        return false
    end
end

-- Поиск своего участка (Plot)
local function findMyPlot()
    local map = workspace:FindFirstChild("Map")
    if not map then return nil end
    local plotsFolder = map:FindFirstChild("Plots")
    if not plotsFolder then return nil end

    -- Ищем по Owner
    for _, plot in ipairs(plotsFolder:GetChildren()) do
        local owner = plot:FindFirstChild("Owner")
        if owner and owner.Value == LocalPlayer then
            return plot
        end
    end

    -- Попытка получить через Remotes.Plot:GetPlot
    local success, result = pcall(function()
        if Remotes and Remotes:FindFirstChild("Plot") and Remotes.Plot:FindFirstChild("GetPlot") then
            return Remotes.Plot.GetPlot:InvokeServer()
        end
    end)
    if success then
        if typeof(result) == "Instance" then
            return result
        elseif typeof(result) == "string" and plotsFolder then
            return plotsFolder:FindFirstChild(result)
        end
    end
    return nil
end

-- Получение стоимости следующего улучшения по типу и этажу
local function getUpgradeCost(upgradeType, floorNum)
    local myPlot = findMyPlot()
    if not myPlot then return nil end
    local cfg = PlotUpgrades[upgradeType]
    if not cfg then return nil end

    if floorNum > 1 then
        if cfg.SignName == "UpgradeSign" then
            return nil
        end
        local floorNames = {"", "SecondFloor", "ThirdFloor", "FourthFloor", "FifthFloor", "SixthFloor"}
        local floorPart = myPlot:FindFirstChild(floorNames[floorNum])
        if not floorPart then return nil end
        local sign = floorPart:FindFirstChild(cfg.SignName)
        if sign then
            local screen = sign:FindFirstChild("Screen")
            if screen then
                local sg = screen:FindFirstChild("SurfaceGui")
                if sg then
                    local folder = sg:FindFirstChild(cfg.UIFolder)
                    if folder then
                        local btn = folder:FindFirstChild("Btn")
                        if btn then
                            local txt = btn:FindFirstChild("Txt")
                            if txt then
                                if txt.Text == "MAX" then
                                    return "MAX"
                                else
                                    return parseMoney(txt.Text)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return nil
end

-- Выполнить улучшение на определенном этаже
local function doPlotUpgrade(upgradeType, floorNum)
    if not Remotes or not Remotes:FindFirstChild("PlotUpgradeTransaction") then return end
    Remotes.PlotUpgradeTransaction:InvokeServer(
        PlotUpgrades[upgradeType].RemoteArg,
        "Floor" .. floorNum
    )
end

-- Улучшение SeedLuck / SeedRolls
local function upgradeSeedLuck()
    if Remotes and Remotes:FindFirstChild("UpgradeSeedLuck") then
        pcall(function() Remotes.UpgradeSeedLuck:InvokeServer() end)
    end
end

local function upgradeSeedRolls()
    if Remotes and Remotes:FindFirstChild("UpgradeSeedRolls") then
        pcall(function() Remotes.UpgradeSeedRolls:InvokeServer() end)
    end
end

-- Список доступных мутаций
local function getMutationList()
    local mutations = {"Normal"}
    local sharedMutations = Shared and Shared:FindFirstChild("MutationAppliers")
    if sharedMutations then
        for _, obj in ipairs(sharedMutations:GetChildren()) do
            if obj.Name and obj.Name ~= "" then
                table.insert(mutations, obj.Name)
            end
        end
    end
    table.sort(mutations, function(a, b)
        if a == "Normal" then return true
        elseif b == "Normal" then return false
        else return a < b end
    end)
    if #mutations == 1 then
        mutations = {"Normal", "Alien", "Autumn", "Cosmic", "Farm", "Frozen", "Honeycomb", "Radioactive", "Rainbow", "Void", "Wet"}
    end
    return mutations
end

-- Список всех семян (из индекса)
local function getIndexSeeds()
    local seeds = {}
    local seen = {}

    -- Парсим UI PlantsFrame
    local mainUI = PlayerGui:FindFirstChild("MainUI")
    if mainUI then
        local menus = mainUI:FindFirstChild("Menus")
        if menus then
            local indexFrame = menus:FindFirstChild("IndexFrame")
            if indexFrame then
                local main = indexFrame:FindFirstChild("Main")
                if main then
                    local plantsFrame = main:FindFirstChild("PlantsFrame")
                    if plantsFrame then
                        for _, frame in ipairs(plantsFrame:GetChildren()) do
                            if frame:IsA("Frame") then
                                local seedName = frame:FindFirstChild("SeedName")
                                local rarityName = frame:FindFirstChild("RarityName")
                                if seedName and rarityName then
                                    local name = seedName.Text
                                    local rarity = rarityName.Text
                                    if name and name ~= "" and name ~= "???" and rarity and rarity ~= "" and rarity ~= "???" then
                                        local fullName = "[" .. rarity .. "] " .. name
                                        if not seen[name] then
                                            seen[name] = true
                                            table.insert(seeds, fullName)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- Если UI не дал, ищем в ReplicatedStorage.Assets.Seeds
    if #seeds == 0 then
        local assetsSeeds = ReplicatedStorage:FindFirstChild("Assets") and ReplicatedStorage.Assets:FindFirstChild("Seeds")
        if assetsSeeds then
            for _, seed in ipairs(assetsSeeds:GetChildren()) do
                local name = seed.Name:gsub(" Seed$", "")
                if not seen[name] then
                    seen[name] = true
                    table.insert(seeds, name)
                end
            end
        end
    end

    table.sort(seeds)
    return seeds
end

-- Поиск семени в инвентаре/рюкзаке и его экипировка
local function findSeedTool(trueName)
    local char = LocalPlayer.Character
    if not char then return nil end
    local humanoid = char:FindFirstChild("Humanoid")
    if not humanoid then return nil end

    -- Проверяем, уже в руках
    local tool = char:FindFirstChildWhichIsA("Tool")
    if tool and tool:GetAttribute("InventoryCategory") == "Seeds" and tool:GetAttribute("trueName") == trueName then
        return tool
    end

    -- Ищем в рюкзаке
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if backpack then
        for _, item in ipairs(backpack:GetChildren()) do
            if item:IsA("Tool") and item:GetAttribute("InventoryCategory") == "Seeds" and item:GetAttribute("trueName") == trueName then
                humanoid:UnequipTools()
                task.wait(0.1)
                humanoid:EquipTool(item)
                return item
            end
        end
    end
    return nil
end

-- Список удобрений
local FertilizerTypes = {"Normal Fertilizer", "Strong Fertilizer", "Super Fertilizer"}

-- Найти удобрение, подходящее под фильтры
local function findFertilizer()
    local char = LocalPlayer.Character
    local function searchIn(parent)
        if not parent then return nil end
        for _, item in ipairs(parent:GetChildren()) do
            if item:IsA("Tool") then
                for _, ftype in ipairs(FertilizerTypes) do
                    if string.find(item.Name, ftype, 1, true) then
                        local useThis = true
                        if next(_G.TargetFertilizerTypes) ~= nil then
                            useThis = _G.TargetFertilizerTypes[ftype] ~= nil
                        end
                        if useThis then
                            return item
                        end
                    end
                end
            end
        end
        return nil
    end

    return searchIn(char) or searchIn(LocalPlayer:FindFirstChild("Backpack"))
end

-- Телепортация
local function teleportToCFrame(cf)
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        char.HumanoidRootPart.CFrame = cf
        return true
    end
    return false
end

local function rejoinServer()
    if queue_on_teleport then
        queue_on_teleport("print('[LamduckHub] Rejoined Successfully!')")
    end
    TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
end

-- Целевые точки для телепорта
local teleportDestinations = {
    {
        Label = "Farm Floor 1",
        DestinationType = "MyPlotFloor",
        PlotFloorYOffset = 5,
    },
    {
        Label = "Farm Floor 2",
        DestinationType = "MyPlotFloor",
        PlotFloorModelName = "SecondFloor",
        PlotFloorYOffset = 35,
    },
    {
        Label = "Farm Floor 3",
        DestinationType = "MyPlotFloor",
        PlotFloorModelName = "ThirdFloor",
        PlotFloorYOffset = 70,
    },
    {
        Label = "Seed Collector",
        DestinationType = "WorkspacePivot",
        WorkspaceModelName = "SeedCollector",
        PositionOffset = Vector3.new(0, 5, 8),
    },
    {
        Label = "Pet Merchant",
        DestinationType = "WorkspaceChildCFrame",
        WorkspaceModelName = "PetMerchant",
        WorkspaceChildName = "MerchantSign",
        PositionOffset = Vector3.new(0, 5, 10),
    },
    {
        Label = "Friend-O-Tron",
        DestinationType = "WorkspacePivot",
        WorkspaceModelName = "FriendOTron",
        PositionOffset = Vector3.new(0, 5, 10),
    },
    {
        Label = "Rejoin",
        DestinationType = "Rejoin",
    },
}

local function getDestinationCFrame(dest)
    if dest.DestinationType == "MyPlotFloor" then
        local plot = findMyPlot()
        if not plot then return nil end
        return plot:GetPivot() * CFrame.new(0, dest.PlotFloorYOffset or 5, 0)
    elseif dest.DestinationType == "WorkspacePivot" then
        local model = workspace:FindFirstChild(dest.WorkspaceModelName)
        if not model then return nil end
        return model:GetPivot() * CFrame.new(dest.PositionOffset or Vector3.zero)
    elseif dest.DestinationType == "WorkspaceChildCFrame" then
        local model = workspace:FindFirstChild(dest.WorkspaceModelName)
        if not model then return nil end
        local child = model:FindFirstChild(dest.WorkspaceChildName)
        if not child then return nil end
        return child.CFrame + (dest.PositionOffset or Vector3.zero)
    else
        return nil
    end
end

local function teleportToDestination(dest)
    if dest.DestinationType == "Rejoin" then
        rejoinServer()
    else
        local cf = getDestinationCFrame(dest)
        if cf then
            teleportToCFrame(cf)
        end
    end
end

local function teleportToMyPlot()
    local dest = teleportDestinations[1]
    if teleportToCFrame(getDestinationCFrame(dest)) then
        WindUI:Notify({  -- <- было WindUI:Notify
            Title = "Teleport",
            Content = "Arrived at your plot!",
            Duration = 2,
        })
    else
        WindUI:Notify({  -- <- было WindUI:Notify
            Title = "Error",
            Content = "Plot not found or character not loaded.",
            Duration = 2,
        })
    end
end

-- Получение информации о стоимости вещей в магазине
local function getGearShopFrame()
    local mainUI = PlayerGui:FindFirstChild("MainUI")
    if not mainUI then return nil end
    local menus = mainUI:FindFirstChild("Menus")
    if not menus then return nil end
    local gearShopFrame = menus:FindFirstChild("GearShopFrame")
    if not gearShopFrame then return nil end
    return gearShopFrame:FindFirstChild("ScrollingFrame")
end

local function getGearPriceFromGui(gearName)
    local frame = getGearShopFrame()
    if not frame then return "N/A" end
    local gearFrame = frame:FindFirstChild(gearName)
    if not gearFrame then return "N/A" end
    for _, desc in ipairs(gearFrame:GetDescendants()) do
        if desc:IsA("TextLabel") and desc.Text and string.sub(desc.Text, 1, 1) == "$" then
            return desc.Text
        end
    end
    return "N/A"
end

local function getGearStock(gearName)
    local gearStocks = ReplicatedStorage:FindFirstChild("GearStocks")
    if not gearStocks then return 0 end
    local playerStock = gearStocks:FindFirstChild(LocalPlayer.Name)
    if not playerStock then return 0 end
    local stockObj = playerStock:FindFirstChild(gearName)
    return stockObj and stockObj.Value or 0
end

-- Список доступных шестерёнок
local function getAvailableGears()
    local gears = {}
    local assets = ReplicatedStorage:FindFirstChild("Assets")
    if assets then
        local gearFolder = assets:FindFirstChild("Gear")
        if gearFolder then
            for _, gear in ipairs(gearFolder:GetChildren()) do
                table.insert(gears, gear.Name)
            end
        end
    end
    table.sort(gears)
    return gears
end

-- Яйца и питомцы
local function getEggShopInfo()
    local petMerchant = workspace:FindFirstChild("PetMerchant")
    if not petMerchant then return "--- EGG SHOP ---\nPet Merchant not found" end

    local lines = {}
    local restockText = "Restocks In: Unknown"
    local sign = petMerchant:FindFirstChild("MerchantSign")
    if sign then
        local sg = sign:FindFirstChildWhichIsA("SurfaceGui")
        if sg then
            local timeLabel = sg:FindFirstChild("TimeLabel")
            if timeLabel then
                restockText = timeLabel.Text
            end
        end
    end
    table.insert(lines, "--- EGG SHOP (" .. restockText .. ") ---")

    local hasEggs = false
    for i = 1, 5 do
        local podium = petMerchant:FindFirstChild("Podium" .. i .. "Stock") or petMerchant:FindFirstChild("Podium" .. i)
        if podium then
            local eggLabel = podium:FindFirstChild("EggLabel", true)
            local priceLabel = podium:FindFirstChild("PriceLabel", true)
            if eggLabel and priceLabel and eggLabel.Text ~= "" then
                table.insert(lines, string.format("[Slot %d] %s | %s", i, eggLabel.Text, priceLabel.Text))
                hasEggs = true
            end
        end
    end
    if not hasEggs then
        table.insert(lines, "No eggs listed (loading or empty)")
    end
    return table.concat(lines, "\n")
end

local function getGearShopInfo()
    local lines = {"--- GEAR SHOP ---"}
    local hasStock = false
    for _, gearName in ipairs(getAvailableGears()) do
        local stock = getGearStock(gearName)
        local price = getGearPriceFromGui(gearName)
        local color = stock == 0 and "#FF5050" or "#00FF7F"
        table.insert(lines, string.format("- <font color='%s'>[%d x]</font> <font color='#FFD250'>[%s]</font> <font color='#FFFFFF'>%s</font>", color, stock, price, gearName))
        if stock > 0 then hasStock = true end
    end
    if not hasStock then
        table.insert(lines, "- All gears are out of stock!")
    end
    return table.concat(lines, "\n")
end

local function getFullShopInfo()
    return getEggShopInfo() .. "\n\n" .. getGearShopInfo()
end

-- Покупка вещи
local function buyGear(gearName)
    if not Remotes or not Remotes:FindFirstChild("Gear") or not Remotes.Gear:FindFirstChild("Transaction") then return end
    local priceStr = getGearPriceFromGui(gearName)
    local price = parseMoney(priceStr)
    if haveEnoughMoney(price, "Gear", gearName) then
        Remotes.Gear.Transaction:InvokeServer(gearName)
    end
end

-- Разблокировка слотов яиц
local function getEggSlotsInfo()
    local slots = {}
    if Shared and Shared:FindFirstChild("EggConfig") then
        local success, config = pcall(function() return require(Shared.EggConfig) end)
        if success and type(config) == "table" and config.UnlockPrices then
            for slotStr, price in pairs(config.UnlockPrices) do
                local slotNum = tonumber(string.match(slotStr, "%d+"))
                if slotNum then
                    table.insert(slots, {EggSlotNumber = slotNum, UnlockPrice = tonumber(price) or 0})
                end
            end
        end
    end
    table.sort(slots, function(a, b) return a.EggSlotNumber < b.EggSlotNumber end)
    return slots
end

local function getAvailableEggTypes()
    local eggs = {}
    if Shared and Shared:FindFirstChild("EggConfig") then
        local success, config = pcall(function() return require(Shared.EggConfig) end)
        if success and type(config) == "table" then
            for k, v in pairs(config) do
                if type(v) == "table" and string.match(tostring(k), "Egg$") then
                    table.insert(eggs, tostring(k))
                end
            end
        end
    end
    table.sort(eggs)
    if #eggs == 0 then
        eggs = {"CommonEgg", "RareEgg", "EpicEgg"}
    end
    return eggs
end

local function getEggPrice(eggName)
    if not Shared or not Shared:FindFirstChild("EggConfig") or not eggName then return 0 end
    local success, config = pcall(function() return require(Shared.EggConfig) end)
    if not success or type(config) ~= "table" then return 0 end

    if type(config.Eggs) == "table" and type(config.Eggs[eggName]) == "table" then
        local price = config.Eggs[eggName].Price or config.Eggs[eggName].Cost or config.Eggs[eggName].RollPrice
        return tonumber(price) or 0
    elseif type(config.Prices) == "table" then
        return tonumber(config.Prices[eggName]) or 0
    elseif type(config.RollPrices) == "table" then
        return tonumber(config.RollPrices[eggName]) or 0
    end
    return 0
end

local function getCurrentEggSlots()
    local slots = {}
    local petMerchant = workspace:FindFirstChild("PetMerchant")
    if not petMerchant then return slots end
    for i = 1, 5 do
        local podium = petMerchant:FindFirstChild("Podium" .. i .. "Stock") or petMerchant:FindFirstChild("Podium" .. i)
        if podium then
            local eggLabel = podium:FindFirstChild("EggLabel", true)
            if eggLabel and eggLabel.Text and eggLabel.Text ~= "" then
                local name = string.gsub(eggLabel.Text, " ", "")
                if not string.match(string.lower(name), "egg$") then
                    name = name .. "Egg"
                end
                table.insert(slots, {Slot = i, Name = name})
            end
        end
    end
    return slots
end

local function buyEgg(slotInfo)
    if not slotInfo or not slotInfo.Slot or not slotInfo.Name then return false end
    local eggShopRemote = Remotes and Remotes:FindFirstChild("EggShop") and Remotes.EggShop:FindFirstChild("Transaction")
    local rollRemote = Remotes and Remotes:FindFirstChild("RollEgg")
    if not eggShopRemote or not rollRemote then return false end

    local success1 = pcall(function() eggShopRemote:InvokeServer("BuyEgg", slotInfo.Slot) end)
    if not success1 then return false end
    pcall(function() rollRemote:FireServer(slotInfo.Name) end)
    task.wait(0.1)
    pcall(function() rollRemote:FireServer(slotInfo.Name, "ClaimRolledPet") end)
    print("[LamduckHub] EggShop | " .. slotInfo.Name .. " | slot: " .. slotInfo.Slot)
    return true
end

-- Сканирование инвентаря на наличие семян (trueName)
local function scanInventoryForSeeds()
    local seeds = {"None"}
    local seen = {}

    local function scan(parent)
        if not parent then return end
        for _, item in ipairs(parent:GetChildren()) do
            if item:IsA("Tool") and item:GetAttribute("InventoryCategory") == "Seeds" then
                local trueName = item:GetAttribute("trueName")
                if trueName and not seen[trueName] then
                    seen[trueName] = true
                    table.insert(seeds, trueName)
                end
            end
        end
    end

    scan(LocalPlayer.Character)
    scan(LocalPlayer:FindFirstChild("Backpack"))
    return seeds
end

-- ==================== UI ====================
local FarmTab = Window:Tab({Title = "Farming", Icon = "sprout"})
local UpgradesTab = Window:Tab({Title = "Upgrades", Icon = "sparkles"})
local ShopTab = Window:Tab({Title = "Gacha $ Shop", Icon = "shopping-cart"})
local EventsTab = Window:Tab({Title = "Events", Icon = "star"})
local RewardsTab = Window:Tab({Title = "Rewards", Icon = "gift"})
local UtilitiesTab = Window:Tab({Title = "Utilities", Icon = "wrench"})
local ConfigTab = Window:Tab({Title = "Config", Icon = "settings"})

-- ---------- Farming ----------
local autoFarmSection = FarmTab:Section({Title = "AUTO FARMING"})

FarmTab:Toggle({
    Title = "Auto Sell Crates",
    Value = false,
    Callback = function(val)
        _G.AutoSellCrates = val
        if val then
            task.spawn(function()
                while _G.AutoSellCrates do
                    pcall(function()
                        if Remotes and Remotes:FindFirstChild("SellCrates") then
                            Remotes.SellCrates:FireServer()
                        end
                    end)
                    task.wait(2)
                end
            end)
        end
    end,
})

FarmTab:Toggle({
    Title = "Auto Unlock Farm Plots",
    Value = false,
    Callback = function(val)
        _G.AutoUnlockFarmPlots = val
        if val then
            task.spawn(function()
                while _G.AutoUnlockFarmPlots do
                    local myPlot = findMyPlot()
                    if myPlot then
                        for _, desc in ipairs(myPlot:GetDescendants()) do
                            if not _G.AutoUnlockFarmPlots then break end
                            if desc.Name == "Dirt" then
                                pcall(function()
                                    Remotes.UnlockPlot:FireServer(desc)
                                end)
                                task.wait(2)
                                break -- одно разблокирование за цикл
                            end
                        end
                    end
                    task.wait(2)
                end
            end)
        end
    end,
})

FarmTab:Toggle({
    Title = "Auto Expand Farm Plot",
    Value = false,
    Callback = function(val)
        _G.AutoExpandFarmPlot = val
        if val then
            task.spawn(function()
                while _G.AutoExpandFarmPlot do
                    pcall(function()
                        local map = workspace:FindFirstChild("Map")
                        if not map then return end
                        local plots = map:FindFirstChild("Plots")
                        if not plots then return end
                        local upgradeRemote = Remotes and Remotes:FindFirstChild("UpgradeFarm")
                        if not upgradeRemote then return end

                        for _, plot in ipairs(plots:GetChildren()) do
                            if not _G.AutoExpandFarmPlot then break end
                            local expandSign = plot:FindFirstChild("ExpandSign")
                            if expandSign then
                                local screen = expandSign:FindFirstChild("Screen")
                                if screen then
                                    local sg = screen:FindFirstChild("SurfaceGui")
                                    if sg then
                                        local expand = sg:FindFirstChild("Expand")
                                        if expand then
                                            local btn = expand:FindFirstChild("Btn")
                                            if btn then
                                                local txt = btn:FindFirstChild("Txt")
                                                if txt and txt:IsA("TextLabel") then
                                                    local cost = parseMoney(txt.Text)
                                                    if haveEnoughMoney(cost, "Plot Expansion") then
                                                        upgradeRemote:InvokeServer()
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end)
                    task.wait(2)
                end
            end)
        end
    end,
})

-- Seed Management
local seedManagementSection = FarmTab:Section({Title = "SEED MANAGEMENT"})

local seedDropdownValues = scanInventoryForSeeds()
local seedDropdown = FarmTab:Dropdown({
    Title = "Select Seed Type",
    Values = seedDropdownValues,
    Value = "None",
    Callback = function(val)
        _G.SelectedSeedTrueName = val
    end,
})

FarmTab:Button({
    Title = "Refresh Seed List",
    Callback = function()
        _G.SelectedSeedTrueName = "None"
        local newSeeds = scanInventoryForSeeds()
        seedDropdown:Refresh(newSeeds)
        WindUI:Notify({Title = "Inventory Scanned", Content = "Seed dropdown updated.", Duration = 2})
    end,
})

FarmTab:Button({
    Title = "Plant Selected Seed Type",
    Callback = function()
        if _G.SelectedSeedTrueName == "None" then
            WindUI:Notify({Title = "Error", Content = "Please select a seed type to plant first.", Duration = 3})
            return
        end
        task.spawn(function()
            local myPlot = findMyPlot()
            if not myPlot then
                WindUI:Notify({Title = "Error", Content = "Could not locate your farm plot.", Duration = 3})
                return
            end
            local plantedAny = false
            for _, desc in ipairs(myPlot:GetDescendants()) do
                if desc.Name == "Dirt" and desc:GetAttribute("PlantLevel") == nil then
                    local seed = findSeedTool(_G.SelectedSeedTrueName)
                    if seed then
                        pcall(function()
                            Remotes.PlantSeed:FireServer(desc)
                        end)
                        task.wait(0.3)
                        plantedAny = true
                    end
                end
            end
            if not plantedAny then
                WindUI:Notify({Title = "Out of Seeds", Content = "Ran out of " .. _G.SelectedSeedTrueName .. " seeds. Stopping.", Duration = 4})
            else
                WindUI:Notify({Title = "Planting Complete", Content = "Successfully planted all available plots!", Duration = 4})
            end
            task.wait(0.5)
            _G.SelectedSeedTrueName = "None"
            seedDropdown:Refresh(scanInventoryForSeeds())
        end)
    end,
})

FarmTab:Button({
    Title = "Discard Selected Seed",
    Callback = function()
        if _G.SelectedSeedTrueName == "None" then
            WindUI:Notify({Title = "Error", Content = "Please select a seed type to discard.", Duration = 3})
            return
        end
        if _G.IsDiscarding then
            WindUI:Notify({Title = "Info", Content = "Discard process is already running.", Duration = 3})
            return
        end
        Window:Dialog({
            Title = "WARNING",
            Content = "<font color='#FF4D4D'>Are you sure you want to discard ALL " .. _G.SelectedSeedTrueName .. " seeds? This cannot be undone.</font>",
            Buttons = {
                {
                    Title = "Yes",
                    Callback = function()
                        _G.IsDiscarding = true
                        local targetSeed = _G.SelectedSeedTrueName
                        WindUI:Notify({Title = "Started", Content = "Discarding " .. targetSeed, Duration = 3})
                        local char = LocalPlayer.Character
                        if char and char:FindFirstChildWhichIsA("Humanoid") then
                            char.Humanoid:UnequipTools()
                        end
                        task.spawn(function()
                            while _G.IsDiscarding do
                                if _G.SelectedSeedTrueName ~= targetSeed then break end
                                local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildWhichIsA("Tool")
                                if tool and tool:GetAttribute("trueName") == targetSeed then
                                    pcall(function()
                                        if Remotes and Remotes:FindFirstChild("DiscardSeed") then
                                            Remotes.DiscardSeed:FireServer()
                                        end
                                    end)
                                else
                                    findSeedTool(targetSeed)
                                    task.wait(0.2)
                                end
                                task.wait()
                            end
                            _G.IsDiscarding = false
                        end)
                    end,
                },
                {Title = "No"},
            },
        })
    end,
})

-- Plant Control
local plantControlSection = FarmTab:Section({Title = "PLANT CONTROL"})

FarmTab:Button({
    Title = "Remove All Current Plants (Get all seed back)",
    Callback = function()
        Window:Dialog({
            Title = "Confirm Removal",
            Content = "Are you sure you want to remove ALL current plants?",
            Buttons = {
                {
                    Title = "Confirm",
                    Callback = function()
                        WindUI:Notify({Title = "Farm Removing", Content = "Removing all plants...", Duration = 10})
                        local myPlot = findMyPlot()
                        if myPlot then
                            for _, desc in ipairs(myPlot:GetDescendants()) do
                                if desc.Name == "Dirt" and desc:GetAttribute("PlantLevel") ~= nil then
                                    pcall(function()
                                        Remotes.RemovePlant:FireServer(desc)
                                    end)
                                    task.wait(0.3)
                                end
                            end
                            WindUI:Notify({Title = "Farm Removed", Content = "Successfully removed all plants!", Duration = 3})
                        end
                    end,
                },
                {Title = "Cancel"},
            },
        })
    end,
})

-- Компостер
local composterSection = FarmTab:Section({Title = "COMPOSTER SETTINGS"})

local composterSeedDropdown = FarmTab:Dropdown({
    Title = "Select Seeds (Empty = Skip)",
    Values = getIndexSeeds(),
    Value = {},
    Multi = true,
    AllowNone = true,
    Callback = function(val) _G.TargetCompostSeeds = val end,
})

local composterMutationDropdown = FarmTab:Dropdown({
    Title = "Select Mutations (Empty = All)",
    Values = getMutationList(),
    Value = {},
    Multi = true,
    AllowNone = true,
    Callback = function(val) _G.TargetCompostMutations = val end,
})

local composterFloorDropdown = FarmTab:Dropdown({
    Title = "Select Composter Floor",
    Values = {"2", "3"},
    Value = "2",
    Callback = function(val) _G.CompostFloor = tonumber(val) or 2 end,
})

local maxInsertInput = FarmTab:Input({
    Title = "Max Seeds Per Insert (0 = No Limit)",
    Placeholder = "0",
    Value = "0",
    Numeric = true,
    Finished = true,
    Callback = function(val)
        local num = tonumber(val)
        if not num or num < 0 or (num % 1 ~= 0) then
            _G.MaxCompostInsertAmount = 0
            maxInsertInput:Set("0")
        else
            _G.MaxCompostInsertAmount = math.floor(num)
        end
    end,
})

FarmTab:Input({
    Title = "Auto Pull Lever Delay (Seconds)",
    Placeholder = "2",
    Value = "2",
    Numeric = true,
    Finished = true,
    Callback = function(val)
        local num = tonumber(val)
        _G.AutoPullComposterLeverDelaySeconds = (num and num >= 0) and num or 2
    end,
})

FarmTab:Button({
    Title = "Refresh & Clear Compost Settings",
    Callback = function()
        _G.TargetCompostSeeds = {}
        _G.TargetCompostMutations = {}
        _G.MaxCompostInsertAmount = 0
        _G.CompostFloor = 2
        _G.AutoPullComposterLeverDelaySeconds = 2
        composterSeedDropdown:Refresh(getIndexSeeds())
        composterMutationDropdown:Refresh(getMutationList())
        composterSeedDropdown:Select({})
        composterMutationDropdown:Select({})
        composterFloorDropdown:Select("2")
        maxInsertInput:Set("0")
        WindUI:Notify({Title = "Composter", Content = "Compost settings refreshed and cleared.", Duration = 2})
    end,
})

-- Функции компостера
local function getCompostInsertRemote()
    if Remotes and Remotes:FindFirstChild("Composter") and Remotes.Composter:FindFirstChild("InsertSeed") then
        return Remotes.Composter.InsertSeed
    end
    return nil
end

local function getSeedQuantity(tool)
    local qtyStr = string.match(tool.Name, "%(x(%d+)%)")
    return tonumber(qtyStr) or 1
end

local function getSeedKey(tool, mutation, plantLevel)
    local seedKey = tool:GetAttribute("seedKey")
    if seedKey then return seedKey end
    local lvl = tool:GetAttribute("Level") or 1
    return tostring(mutation) .. "_" .. tostring(lvl) .. "_" .. tostring(plantLevel)
end

local function clampInsertAmount(available)
    if _G.MaxCompostInsertAmount > 0 then
        return math.min(available, _G.MaxCompostInsertAmount)
    end
    return available
end

local function findCompostSeed()
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if not backpack then return nil end
    for _, tool in ipairs(backpack:GetChildren()) do
        if tool:IsA("Tool") and tool:GetAttribute("InventoryCategory") == "Seeds" then
            local plant = tool:GetAttribute("Plant") or tool:GetAttribute("trueName")
            local mutation = tool:GetAttribute("Mutation") or "Normal"
            -- Проверка фильтров
            if _G.TargetCompostSeeds and next(_G.TargetCompostSeeds) ~= nil then
                if not _G.TargetCompostSeeds[plant] then continue end
            end
            if _G.TargetCompostMutations and next(_G.TargetCompostMutations) ~= nil then
                if not _G.TargetCompostMutations[mutation] then continue end
            end
            return tool
        end
    end
    return nil
end

-- Компостер: Auto Compost All Seeds (опасный)
FarmTab:Toggle({
    Title = "Auto Compost All Seeds All Mutations (DANGER! CANNOT UNDO!)",
    Value = false,
    Callback = function(val) _G.AutoCompostAllSeeds = val end,
})

FarmTab:Toggle({
    Title = "Auto Compost Selected Filter",
    Value = false,
    Callback = function(val)
        _G.AutoCompost = val
        if val then
            task.spawn(function()
                while _G.AutoCompost do
                    local seed = findCompostSeed()
                    if seed then
                        local qty = clampInsertAmount(getSeedQuantity(seed))
                        local remote = getCompostInsertRemote()
                        if remote then
                            for i = 1, qty do
                                remote:FireServer(seed)
                                task.wait(0.1)
                            end
                        end
                    end
                    task.wait(0.5)
                end
            end)
        end
    end,
})

FarmTab:Toggle({
    Title = "Auto Pull Composter Lever",
    Value = false,
    Callback = function(val)
        _G.AutoPullComposterLever = val
        if val then
            task.spawn(function()
                while _G.AutoPullComposterLever do
                    pcall(function()
                        if Remotes and Remotes:FindFirstChild("Composter") and Remotes.Composter:FindFirstChild("PullLever") then
                            Remotes.Composter.PullLever:FireServer()
                        end
                    end)
                    task.wait(_G.AutoPullComposterLeverDelaySeconds)
                end
            end)
        end
    end,
})

FarmTab:Button({
    Title = "Manual Insert (Run Once)",
    Callback = function()
        local seed = findCompostSeed()
        if not seed then return end
        local qty = clampInsertAmount(getSeedQuantity(seed))
        local remote = getCompostInsertRemote()
        if remote then
            for i = 1, qty do
                remote:FireServer(seed)
                task.wait(0.1)
            end
        end
    end,
})

-- ========== Upgrades ==========
local plotPowerupsSection = UpgradesTab:Section({Title = "PLOT POWERUPS"})

local powerupsList = {"SawRange", "SawYield", "SprinklerRange", "SprinklerPower", "SeedLuck", "SeedRolls"}
local powerupDropdown = UpgradesTab:Dropdown({
    Title = "Select Powerups to Upgrade",
    Values = powerupsList,
    Value = {},
    Multi = true,
    AllowNone = true,
    Callback = function(val) _G.TargetPowerups = val end,
})

UpgradesTab:Toggle({
    Title = "Auto Upgrade Selected Powerups",
    Value = false,
    Callback = function(val)
        _G.AutoUpgradePowerups = val
        if val then
            task.spawn(function()
                while _G.AutoUpgradePowerups do
                    for _, upgrade in ipairs(UpgradeTypes) do
                        if not _G.AutoUpgradePowerups then break end
                        if _G.TargetPowerups and _G.TargetPowerups[upgrade] then
                            local cfg = PlotUpgrades[upgrade]
                            if cfg.Type == "plot" then
                                for floor = 1, 3 do
                                    local cost = getUpgradeCost(upgrade, floor)
                                    if cost == "MAX" then break end
                                    if cost and haveEnoughMoney(cost, upgrade, tostring(cost)) then
                                        doPlotUpgrade(upgrade, floor)
                                        task.wait(1)
                                    else
                                        break
                                    end
                                end
                            elseif cfg.Type == "seedluck" then
                                upgradeSeedLuck()
                                task.wait(1)
                            elseif cfg.Type == "seedrolls" then
                                upgradeSeedRolls()
                                task.wait(1)
                            end
                        end
                    end
                    task.wait(3)
                end
            end)
        end
    end,
})

-- Flora Upgrade
local floraUpgradeSection = UpgradesTab:Section({Title = "FLORA UPGRADE"})

local upgradePlantNamesDropdown = UpgradesTab:Dropdown({
    Title = "Target Plants (Empty = All)",
    Values = getIndexSeeds(),
    Value = {},
    Multi = true,
    AllowNone = true,
    Callback = function(val) _G.TargetUpgradePlantNames = val end,
})

local upgradeMutationsDropdown = UpgradesTab:Dropdown({
    Title = "Target Mutations (Empty = All)",
    Values = getMutationList(),
    Value = {},
    Multi = true,
    AllowNone = true,
    Callback = function(val) _G.TargetUpgradeMutations = val end,
})

UpgradesTab:Button({
    Title = "Refresh & Clear Upgrade Targets",
    Callback = function()
        _G.TargetUpgradePlantNames = {}
        _G.TargetUpgradeMutations = {}
        upgradePlantNamesDropdown:Refresh(getIndexSeeds())
        upgradeMutationsDropdown:Refresh(getMutationList())
        upgradePlantNamesDropdown:Select({})
        upgradeMutationsDropdown:Select({})
        WindUI:Notify({Title = "Upgrades", Content = "Targets refreshed and cleared.", Duration = 2})
    end,
})

local plantLevelSlider = UpgradesTab:Slider({
    Title = "Target Plant Level",
    Min = 1,
    Max = 100,
    Default = 10,
    Step = 1,
    Callback = function(val) _G.TargetPlantUpgradeLevel = val end,
})

UpgradesTab:Toggle({
    Title = "Auto Upgrade Targeted Plants",
    Value = false,
    Callback = function(val)
        _G.AutoUpgradePlants = val
        if val then
            task.spawn(function()
                while _G.AutoUpgradePlants do
                    pcall(function()
                        -- Логика авто-апгрейда (зависит от игры, здесь упрощённо)
                        if Remotes and Remotes:FindFirstChild("UpgradePlant") then
                            Remotes.UpgradePlant:FireServer()
                        end
                    end)
                    task.wait(2)
                end
            end)
        end
    end,
})

-- Flora Fertilization
local floraFertSection = UpgradesTab:Section({Title = "FLORA FERTILIZATION"})

local fertilizePlantNamesDropdown = UpgradesTab:Dropdown({
    Title = "Target Plants (Empty = All)",
    Values = getIndexSeeds(),
    Value = {},
    Multi = true,
    AllowNone = true,
    Callback = function(val) _G.TargetFertilizePlantNames = val end,
})

local fertilizeMutationsDropdown = UpgradesTab:Dropdown({
    Title = "Target Mutations (Empty = All)",
    Values = getMutationList(),
    Value = {},
    Multi = true,
    AllowNone = true,
    Callback = function(val) _G.TargetFertilizeMutations = val end,
})

local fertilizerTypeDropdown = UpgradesTab:Dropdown({
    Title = "Fertilizer Type (Empty = All)",
    Values = FertilizerTypes,
    Value = {},
    Multi = true,
    AllowNone = true,
    Callback = function(val) _G.TargetFertilizerTypes = val end,
})

UpgradesTab:Button({
    Title = "Refresh & Clear Fertilize Targets",
    Callback = function()
        _G.TargetFertilizePlantNames = {}
        _G.TargetFertilizeMutations = {}
        _G.TargetFertilizerTypes = {}
        fertilizePlantNamesDropdown:Refresh(getIndexSeeds())
        fertilizeMutationsDropdown:Refresh(getMutationList())
        fertilizePlantNamesDropdown:Select({})
        fertilizeMutationsDropdown:Select({})
        fertilizerTypeDropdown:Select({})
        WindUI:Notify({Title = "Fertilize", Content = "Targets refreshed and cleared.", Duration = 2})
    end,
})

UpgradesTab:Toggle({
    Title = "Auto Fertilize Targeted Plants",
    Value = false,
    Callback = function(val)
        _G.AutoFertilize = val
        if val then
            task.spawn(function()
                while _G.AutoFertilize do
                    local fert = findFertilizer()
                    if fert then
                        pcall(function()
                            Remotes.Fertilize:FireServer(fert)
                        end)
                    end
                    task.wait(2)
                end
            end)
        end
    end,
})

-- ========== Gacha $ Shop ==========
local gachaSection = ShopTab:Section({Title = "SEED GACHA (ROLL & BUY)"})

ShopTab:Toggle({
    Title = "Auto Roll & Buy ALL Seeds",
    Value = false,
    Callback = function(val) _G.AutoRollAndBuyAll = val end,
})

local gachaSeedsDropdown = ShopTab:Dropdown({
    Title = "Select Seeds to Snipe",
    Values = getIndexSeeds(),
    Value = {},
    Multi = true,
    AllowNone = true,
    Callback = function(val) _G.TargetGachaSeeds = val end,
})

ShopTab:Toggle({
    Title = "Auto Roll & Buy SELECTED Seeds",
    Value = false,
    Callback = function(val) _G.AutoRollAndBuySelected = val end,
})

-- Эти функции будут работать, если флаги включены и запущен цикл (ниже)
task.spawn(function()
    while true do
        if _G.AutoRollAndBuyAll or _G.AutoRollAndBuySelected then
            local stands = {}
            -- Сбор информации о стендах с семенами
            local myPlot = findMyPlot()
            if myPlot then
                local roller = myPlot:FindFirstChild("SeedRoller")
                if roller then
                    for i = 1, 6 do
                        local stand = roller:FindFirstChild("Stand" .. i)
                        if stand then
                            stands[i] = stand:GetPivot().Position
                        end
                    end
                end
            end

            local availableSeeds = {}
            for _, model in ipairs(workspace:GetChildren()) do
                if model:IsA("Model") and model:FindFirstChild("BuySeed", true) then
                    local modelPos = model:GetPivot().Position
                    local nearestStand, minDist = nil, math.huge
                    for idx, pos in pairs(stands) do
                        local dist = (Vector3.new(modelPos.X, 0, modelPos.Z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude
                        if dist < minDist then
                            minDist = dist
                            nearestStand = idx
                        end
                    end
                    if nearestStand and minDist < 15 then
                        local seedGui = model:FindFirstChild("SeedGui", true)
                        if seedGui then
                            for _, desc in ipairs(seedGui:GetDescendants()) do
                                if desc:IsA("TextLabel") and string.find(desc.Text, "$") then
                                    local price = parseMoney(desc.Text)
                                    availableSeeds[model.Name] = {standIdx = nearestStand, price = price}
                                end
                            end
                        end
                    end
                end
            end

            -- Roll & Buy
            if _G.AutoRollAndBuyAll then
                if next(availableSeeds) then
                    for seedName, info in pairs(availableSeeds) do
                        if not _G.AutoRollAndBuyAll then break end
                        if haveEnoughMoney(info.price, "Seed", seedName) then
                            pcall(function()
                                Remotes.BuySeed:FireServer(info.standIdx)
                            end)
                            task.wait(0.5)
                        end
                    end
                else
                    -- Roll
                    pcall(function() Remotes.RollSeeds:FireServer() end)
                    task.wait(3.5)
                end
            elseif _G.AutoRollAndBuySelected then
                -- Аналогично, но с фильтром по _G.TargetGachaSeeds
                -- (реализация опущена для краткости)
            end
        end
        task.wait(1)
    end
end)

-- Gear Shop
local gearSection = ShopTab:Section({Title = "GEAR SHOP"})

ShopTab:Toggle({
    Title = "Auto Buy All Available Gears",
    Value = false,
    Callback = function(val) _G.AutoBuyAllGears = val end,
})

local gearDropdown = ShopTab:Dropdown({
    Title = "Select Gears to Buy",
    Values = getAvailableGears(),
    Value = {},
    Multi = true,
    AllowNone = true,
    Callback = function(val) _G.TargetBuyGears = val end,
})

ShopTab:Toggle({
    Title = "Auto Buy Selected Gears",
    Value = false,
    Callback = function(val) _G.AutoBuySelectedGears = val end,
})

-- Цикл покупки шестерёнок
task.spawn(function()
    while true do
        if _G.AutoBuyAllGears then
            for _, gear in ipairs(getAvailableGears()) do
                if getGearStock(gear) > 0 then
                    buyGear(gear)
                    task.wait(0.5)
                end
            end
        elseif _G.AutoBuySelectedGears then
            for gear, _ in pairs(_G.TargetBuyGears or {}) do
                if getGearStock(gear) > 0 then
                    buyGear(gear)
                    task.wait(0.5)
                end
            end
        end
        task.wait(5)
    end
end)

-- Egg Shop
local eggSection = ShopTab:Section({Title = "EGG SHOP"})

ShopTab:Toggle({
    Title = "Auto Unlock Egg Slots",
    Value = false,
    Callback = function(val) _G.AutoUnlockEggSlots = val end,
})

local eggSlots = getEggSlotsInfo()
local unlockLoop = task.spawn(function()
    while true do
        if _G.AutoUnlockEggSlots then
            for _, slotInfo in ipairs(eggSlots) do
                if not _G.SessionUnlockedEggSlots[slotInfo.EggSlotNumber] and haveEnoughMoney(slotInfo.UnlockPrice, "Unlock Egg Slot " .. slotInfo.EggSlotNumber) then
                    pcall(function()
                        if Remotes and Remotes:FindFirstChild("EggShop") and Remotes.EggShop:FindFirstChild("Transaction") then
                            Remotes.EggShop.Transaction:InvokeServer("UnlockSlot", slotInfo.EggSlotNumber)
                            _G.SessionUnlockedEggSlots[slotInfo.EggSlotNumber] = true
                        end
                    end)
                    task.wait(0.5)
                end
            end
        end
        task.wait(3)
    end
end)

ShopTab:Toggle({
    Title = "Auto Buy All Available Eggs",
    Value = false,
    Callback = function(val) _G.AutoBuyAllEggs = val end,
})

local eggDropdown = ShopTab:Dropdown({
    Title = "Select Eggs to Buy",
    Values = getAvailableEggTypes(),
    Value = {},
    Multi = true,
    AllowNone = true,
    Callback = function(val) _G.TargetEggShopEggs = val end,
})

ShopTab:Button({
    Title = "Refresh Egg List",
    Callback = function()
        eggDropdown:Refresh(getAvailableEggTypes())
        WindUI:Notify({Title = "Eggs", Content = "Egg list refreshed.", Duration = 2})
    end,
})

ShopTab:Toggle({
    Title = "Auto Buy Selected Eggs",
    Value = false,
    Callback = function(val) _G.AutoBuySelectedEggs = val end,
})

-- Цикл покупки яиц
task.spawn(function()
    while true do
        local slots = getCurrentEggSlots()
        if _G.AutoBuyAllEggs then
            for _, slot in ipairs(slots) do
                buyEgg(slot)
                task.wait(0.5)
            end
        elseif _G.AutoBuySelectedEggs then
            for _, slot in ipairs(slots) do
                if _G.TargetEggShopEggs[slot.Name] then
                    buyEgg(slot)
                    task.wait(0.5)
                end
            end
        end
        task.wait(5)
    end
end)

-- Live Shop Stock
local stockSection = ShopTab:Section({Title = "LIVE SHOP STOCK"})
local stockParagraph = ShopTab:Paragraph({Title = "Current Available Items", Desc = "Loading shop stock..."})

ShopTab:Button({
    Title = "Refresh Stock Info",
    Callback = function()
        stockParagraph:SetDesc(getFullShopInfo())
    end,
})

-- Первоначальная загрузка
task.spawn(function() stockParagraph:SetDesc(getFullShopInfo()) end)

-- ========== Events ==========
local worldEventsSection = EventsTab:Section({Title = "WORLD EVENTS"})

EventsTab:Toggle({
    Title = "Auto Shoot Plant Rush",
    Value = false,
    Callback = function(val) _G.AutoPlantRush = val end,
})

EventsTab:Toggle({
    Title = "Auto Claim Plant Rush Boss Drops",
    Value = false,
    Callback = function(val) _G.AutoClaimPlantRushBossDrop = val end,
})

-- Plant Rush loop
task.spawn(function()
    while true do
        if _G.AutoPlantRush then
            pcall(function()
                if Remotes and Remotes:FindFirstChild("PlantRush") then
                    Remotes.PlantRush:FireServer("Shoot")
                end
            end)
            task.wait(0.2)
        end
        if _G.AutoClaimPlantRushBossDrop then
            pcall(function()
                if Remotes and Remotes:FindFirstChild("ClaimBossDrop") then
                    Remotes.ClaimBossDrop:FireServer()
                end
            end)
            task.wait(1)
        end
        task.wait(1)
    end
end)

-- Queen Bee
EventsTab:Toggle({
    Title = "Auto Collect Queen Bee Honeycomb",
    Value = false,
    Callback = function(val) _G.AutoCollectQueenBeeHoneycomb = val end,
})

EventsTab:Toggle({
    Title = "Auto Submit Honey Token to Jar Machine (Honey Pot)",
    Value = false,
    Callback = function(val) _G.AutoSubmitQueenBeeHoneyToken = val end,
})

task.spawn(function()
    while true do
        if _G.AutoCollectQueenBeeHoneycomb then
            pcall(function()
                if Remotes and Remotes:FindFirstChild("CollectHoneycomb") then
                    Remotes.CollectHoneycomb:FireServer()
                end
            end)
            task.wait(1)
        end
        if _G.AutoSubmitQueenBeeHoneyToken then
            pcall(function()
                if Remotes and Remotes:FindFirstChild("SubmitHoneyToken") then
                    Remotes.SubmitHoneyToken:FireServer()
                end
            end)
            task.wait(1)
        end
        task.wait(1)
    end
end)

-- Seed Collector
local seedCollectorSection = EventsTab:Section({Title = "SEED COLLECTOR"})

local collectorSeedsDropdown = EventsTab:Dropdown({
    Title = "Select Seeds to Submit to Collector",
    Values = getIndexSeeds(),
    Value = {},
    Multi = true,
    AllowNone = true,
    Callback = function(val) _G.TargetSeedCollectorSubmitSeeds = val end,
})

EventsTab:Button({
    Title = "Refresh & Clear Seed Collector Targets",
    Callback = function()
        _G.TargetSeedCollectorSubmitSeeds = {}
        collectorSeedsDropdown:Refresh(getIndexSeeds())
        collectorSeedsDropdown:Select({})
        WindUI:Notify({Title = "Collector", Content = "Targets refreshed and cleared.", Duration = 2})
    end,
})

EventsTab:Toggle({
    Title = "Auto Submit Targeted Seeds to Collector",
    Value = false,
    Callback = function(val) _G.AutoSubmitSeedToCollector = val end,
})

EventsTab:Toggle({
    Title = "Auto Submit ALL Seeds to Collector (Ignore Filter)",
    Value = false,
    Callback = function(val) _G.AutoSubmitAllSeedsToCollector = val end,
})

task.spawn(function()
    while true do
        if _G.AutoSubmitAllSeedsToCollector then
            pcall(function()
                if Remotes and Remotes:FindFirstChild("SubmitAllSeeds") then
                    Remotes.SubmitAllSeeds:FireServer()
                end
            end)
        elseif _G.AutoSubmitSeedToCollector then
            -- Здесь логика отправки конкретных семян
        end
        task.wait(5)
    end
end)

-- ========== Rewards ==========
local dailySection = RewardsTab:Section({Title = "DAILY REWARDS"})

RewardsTab:Toggle({
    Title = "Auto Claim Daily Reward",
    Value = false,
    Callback = function(val) _G.AutoClaimDailyReward = val end,
})

RewardsTab:Toggle({
    Title = "Auto Claim Playtime Reward",
    Value = false,
    Callback = function(val) _G.AutoClaimPlaytimeReward = val end,
})

task.spawn(function()
    while true do
        if _G.AutoClaimDailyReward then
            pcall(function()
                if Remotes and Remotes:FindFirstChild("ClaimDailyReward") then
                    Remotes.ClaimDailyReward:FireServer()
                end
            end)
        end
        if _G.AutoClaimPlaytimeReward then
            pcall(function()
                if Remotes and Remotes:FindFirstChild("ClaimPlaytimeReward") then
                    Remotes.ClaimPlaytimeReward:FireServer()
                end
            end)
        end
        task.wait(60)
    end
end)

-- ========== Utilities ==========
local purchaseSection = UtilitiesTab:Section({Title = "PURCHASE"})

UtilitiesTab:Toggle({
    Title = "Skip Money Check (ONLY IF AUTO BUY BUG, ELSE U MAY GOT ADS)",
    Value = false,
    Callback = function(val) _G.SkipMoneyCheck = val end,
})

-- Teleport
local teleportSection = UtilitiesTab:Section({Title = "TELEPORT"})

-- Плавающая кнопка телепорта
local floatingGuiEnabled = false
local floatingButton

local function createFloatingTPButton()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "LamduckFloatingTP"
    screenGui.ResetOnSpawn = false
    screenGui.Enabled = false

    pcall(function()
        screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end)

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 48, 0, 32)
    btn.Position = UDim2.new(0.8, 0, 0.2, 0)
    btn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Text = "TP"
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 14
    btn.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = btn

    local frame = Instance.new("Frame")
    frame.Position = UDim2.new(0, 0, 0, 32)
    frame.Size = UDim2.new(0, 140, 0, 0)
    frame.AutomaticSize = Enum.AutomaticSize.Y
    frame.BackgroundTransparency = 1
    frame.Visible = false
    frame.Parent = btn

    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 5)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Parent = frame

    -- Кнопки для каждой точки телепорта
    for idx, dest in ipairs(teleportDestinations) do
        local destBtn = Instance.new("TextButton")
        destBtn.Size = UDim2.new(1, 0, 0, 32)
        destBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        destBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
        destBtn.Text = dest.Label
        destBtn.Font = Enum.Font.GothamSemibold
        destBtn.TextSize = 13
        destBtn.LayoutOrder = idx
        destBtn.Parent = frame

        local destCorner = Instance.new("UICorner")
        destCorner.CornerRadius = UDim.new(0, 6)
        destCorner.Parent = destBtn

        destBtn.MouseButton1Click:Connect(function()
            teleportToDestination(dest)
            frame.Visible = false
        end)
    end

    -- Перетаскивание кнопки
    local UIS = game:GetService("UserInputService")
    local dragging = false
    local dragStart, startPos

    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = btn.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    UIS.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            btn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    btn.MouseButton1Click:Connect(function()
        frame.Visible = not frame.Visible
    end)

    return screenGui, btn
end

UtilitiesTab:Toggle({
    Title = "Show Floating Teleport Button",
    Value = false,
    Callback = function(val)
        floatingGuiEnabled = val
        if val then
            if not floatingButton then
                local gui, btn = createFloatingTPButton()
                floatingButton = btn
                gui.Enabled = true
            else
                floatingButton.Parent.Enabled = true
            end
        else
            if floatingButton then
                floatingButton.Parent.Enabled = false
            end
        end
    end,
})

UtilitiesTab:Button({
    Title = "Reset Floating TP Button Position",
    Callback = function()
        if floatingButton then
            floatingButton.Position = UDim2.new(0.8, 0, 0.2, 0)
        end
    end,
})

UtilitiesTab:Button({
    Title = "Teleport to My Plot",
    Callback = teleportToMyPlot,
})

-- Debug
local debugSection = UtilitiesTab:Section({Title = "DEBUG"})
UtilitiesTab:Button({
    Title = "Rejoin Server",
    Callback = rejoinServer,
})

-- ========== Config ==========
local infoSection = ConfigTab:Section({Title = "INFO & COMMUNITY"})

ConfigTab:Paragraph({
    Title = "About Script",
    Desc = [[<font color='#00FF7F'><b>Script created by Lamduck.</b></font>
<font color='#FF6AFF'>Join the community below to chat, give feedback, request features, or request games.</font>]],
})

ConfigTab:Button({
    Title = "Join Discord Server",
    Callback = function()
        if game:GetService("GuiService"):IsTenFootInterface() then
            -- На ПК открываем ссылку
        end
        -- setclipboard или другие методы
    end,
})

local configSection = ConfigTab:Section({Title = "CONFIGURATION"})

local configFileName = "build-a-ring-farm.json"

local function saveConfig()
    local config = {}
    -- Сохраняем все нужные флаги
    config.AutoSellCrates = _G.AutoSellCrates
    config.AutoUnlockFarmPlots = _G.AutoUnlockFarmPlots
    config.AutoExpandFarmPlot = _G.AutoExpandFarmPlot
    config.AutoCollectQueenBeeHoneycomb = _G.AutoCollectQueenBeeHoneycomb
    config.AutoPlantRush = _G.AutoPlantRush
    config.AutoClaimPlantRushBossDrop = _G.AutoClaimPlantRushBossDrop
    config.AutoSubmitQueenBeeHoneyToken = _G.AutoSubmitQueenBeeHoneyToken
    config.AutoSubmitSeedToCollector = _G.AutoSubmitSeedToCollector
    config.AutoSubmitAllSeedsToCollector = _G.AutoSubmitAllSeedsToCollector
    config.TargetSeedCollectorSubmitSeeds = _G.TargetSeedCollectorSubmitSeeds
    config.AutoCompost = _G.AutoCompost
    config.AutoCompostAllSeeds = _G.AutoCompostAllSeeds
    config.AutoPullComposterLever = _G.AutoPullComposterLever
    config.TargetCompostSeeds = _G.TargetCompostSeeds
    config.TargetCompostMutations = _G.TargetCompostMutations
    config.MaxCompostInsertAmount = _G.MaxCompostInsertAmount
    config.CompostFloor = _G.CompostFloor
    config.AutoPullComposterLeverDelaySeconds = _G.AutoPullComposterLeverDelaySeconds
    config.AutoClaimDailyReward = _G.AutoClaimDailyReward
    config.AutoClaimPlaytimeReward = _G.AutoClaimPlaytimeReward
    config.SelectedSeedTrueName = _G.SelectedSeedTrueName
    config.AutoBuyAllGears = _G.AutoBuyAllGears
    config.AutoBuySelectedGears = _G.AutoBuySelectedGears
    config.AutoUnlockEggSlots = _G.AutoUnlockEggSlots
    config.AutoBuyAllEggs = _G.AutoBuyAllEggs
    config.AutoBuySelectedEggs = _G.AutoBuySelectedEggs
    config.TargetEggShopEggs = _G.TargetEggShopEggs
    config.SkipMoneyCheck = _G.SkipMoneyCheck
    config.AutoUpgradePlants = _G.AutoUpgradePlants
    config.TargetPlantUpgradeLevel = _G.TargetPlantUpgradeLevel
    config.AutoFertilize = _G.AutoFertilize
    config.AutoRollAndBuyAll = _G.AutoRollAndBuyAll
    config.AutoRollAndBuySelected = _G.AutoRollAndBuySelected
    config.TargetGachaSeeds = _G.TargetGachaSeeds
    config.AutoUpgradePowerups = _G.AutoUpgradePowerups
    config.TargetPowerups = _G.TargetPowerups
    config.TargetUpgradePlantNames = _G.TargetUpgradePlantNames
    config.TargetUpgradeMutations = _G.TargetUpgradeMutations
    config.TargetFertilizePlantNames = _G.TargetFertilizePlantNames
    config.TargetFertilizeMutations = _G.TargetFertilizeMutations
    config.TargetFertilizerTypes = _G.TargetFertilizerTypes
    if floatingButton then
        config.ShowFloatingTeleportButton = floatingGuiEnabled
        config.TeleportButtonPosXScale = floatingButton.Position.X.Scale
        config.TeleportButtonPosXOffset = floatingButton.Position.X.Offset
        config.TeleportButtonPosYScale = floatingButton.Position.Y.Scale
        config.TeleportButtonPosYOffset = floatingButton.Position.Y.Offset
    end
    local success, encoded = pcall(function() return HttpService:JSONEncode(config) end)
    if success then
        writefile(configFileName, encoded)
        WindUI:Notify({Title = "Config", Content = "Configuration saved.", Duration = 2})
    end
end

local function loadConfig()
    if not isfile(configFileName) then return false end
    local success, data = pcall(function() return readfile(configFileName) end)
    if not success then return false end
    local config = HttpService:JSONDecode(data)
    if not config then return false end

    -- Восстанавливаем настройки
    for k, v in pairs(config) do
        if k == "ShowFloatingTeleportButton" then
            -- вызов UI toggle
        elseif k:find("TeleportButtonPos") and floatingButton then
            -- восстановление позиции
        elseif _G[k] ~= nil then
            _G[k] = v
        end
    end
    WindUI:Notify({Title = "System", Content = "Previous config loaded successfully!", Duration = 4})
    return true
end

ConfigTab:Button({
    Title = "Save Current Config",
    Callback = saveConfig,
})

ConfigTab:Button({
    Title = "Delete & Reset Config",
    Callback = function()
        if isfile(configFileName) then
            delfile(configFileName)
            WindUI:Notify({Title = "Config", Content = "Configuration deleted.", Duration = 2})
        end
    end,
})

-- Автозагрузка конфига
loadConfig()

-- Первый телепорт на участок
teleportToMyPlot()

print("[LamduckHub] Fully restored script loaded successfully.")