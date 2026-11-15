--[[ Anime Dice — calibrated hub (PlaceId 113290951185459)
     Remote hasil dump 84 remote / 28 prompt / 113 clickdetector.
     Semua remote ada di ReplicatedStorage.Network — TIDAK perlu masuk ruangan event. ]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local Workspace         = game:GetService("Workspace")
local TweenService      = game:GetService("TweenService")
local TeleportService   = game:GetService("TeleportService")
local HttpService       = game:GetService("HttpService")

local LP = Players.LocalPlayer

local Flags, Conns = {}, {}
local function track(c) table.insert(Conns, c) return c end
local function S(...) local t={} for i=1,select("#",...) do t[i]=tostring((select(i,...))) end print("[AD]", table.concat(t," ")) end

--------------------------------------------------------------- REMOTE RESOLVER

local Net = ReplicatedStorage:WaitForChild("Network", 30)

local function remote(path)
    local cur = ReplicatedStorage
    for seg in string.gmatch(path, "[^%.]+") do
        cur = cur:FindFirstChild(seg)
        if not cur then return nil end
    end
    return cur
end

local function invoke(path, ...)
    local r = remote(path)
    if not r then return false, "missing: " .. path end
    local args = { ... }
    local ok, res = pcall(function() return r:InvokeServer(table.unpack(args)) end)
    if ok then return true, res end
    return false, tostring(res)
end

local function fire(path, ...)
    local r = remote(path)
    if not r then return false, "missing: " .. path end
    local args = { ... }
    local ok, err = pcall(function() r:FireServer(table.unpack(args)) end)
    return ok, err
end

-- coba beberapa variasi argumen sampai salah satu lolos
local function invokeAny(path, variants)
    for _, args in ipairs(variants) do
        local ok, res = invoke(path, table.unpack(args))
        if ok then return true, res, args end
    end
    return false, "semua varian gagal: " .. path
end

local function fireAny(path, variants)
    for _, args in ipairs(variants) do
        local ok = fire(path, table.unpack(args))
        if ok then return true, args end
    end
    return false, "semua varian gagal: " .. path
end

--------------------------------------------------------------- PATH TABLE

local P = {
    RollDice        = "Network.RollService.RF.RollDice",
    RollMsg         = "Network.RollService.RE.RollMessage",
    SetAutoRoll     = "Network.RollService.RE.SetAutoRoll",

    SellInv         = "Network.SellService.RF.SellInventory",
    SellEquipped    = "Network.SellService.RF.SellEquipped",
    AutoSell        = "Network.SellService.RE.UpdateAutoSell",

    LeafRoll        = "Network.LeafDiceService.RF.Roll",
    LeafAutoSell    = "Network.LeafDiceService.RF.SetAutoSell",
    LeafMsg         = "Network.LeafDiceService.RE.RollMessage",

    AutumnTravel    = "Network.AutumnService.RF.Travel",
    AutumnSync      = "Network.AutumnQuestService.RF.Sync",
    AutumnClaim     = "Network.AutumnQuestService.RF.Claim",
    AutumnBonus     = "Network.AutumnQuestService.RF.ClaimBonus",

    Travel          = "Network.TravelService.RE.Travel",

    PlotCollect     = "Network.PlotService.RE.CollectBalance",
    PlotEquipBest   = "Network.PlotService.RE.EquipBest",
    PlotLevelUp     = "Network.PlotService.RE.LevelUpSlot",
    PlotInteract    = "Network.PlotService.RE.InteractSlot",

    AppleCollect    = "Network.AppleService.RF.Collect",
    AppleSync       = "Network.AppleService.RF.Sync",
    AppleUpgrade    = "Network.AppleService.RF.BuyUpgrade",
    AppleShop       = "Network.AppleShopService.RF.Buy",
    AppleTreeUp     = "Network.AppleTreeService.RF.BuyAppleUpgrade",

    Rebirth         = "Network.RebirthService.RE.Rebirth",
    RebirthStat     = "Network.RebirthService.RE.AddStat",

    QuestBuy        = "Network.QuestService.RE.Buy",
    QuestClaim      = "Network.QuestService.RE.Claim",
    BuyUpgrade      = "Network.RE.BuyUpgrade",

    DailyClaim      = "Network.DailyRewardService.RE.Claim",
    OfflineClaim    = "Network.OfflineEarningsService.RE.Claim",
    GroupClaim      = "Network.GroupRewardService.RE.Claim",
    Redeem          = "Network.CodesService.RE.RedeemCode",

    QuirkRoll       = "Network.QuirkService.RE.Roll",
    TraitRoll       = "Network.TraitService.RE.Roll",
    GradeRoll       = "Network.GradeService.RE.Roll",
    Fuse            = "Network.FusingService.RE.Fuse",

    BuyDice         = "Network.DiceShopService.RE.BuyDice",
    EquipDice       = "Network.DiceShopService.RE.EquipDice",
    EquipUnit       = "Network.UnitService.RF.Equip",
    EquipBestTower  = "Network.Towers.RE.EquipBestTowerTeam",
    AutoTower       = "Network.Towers.RE.SetAutoTower",
}

--------------------------------------------------------------- HELPERS

local function getChar()
    local char = LP.Character or LP.CharacterAdded:Wait()
    return char, char:FindFirstChildOfClass("Humanoid"), char:FindFirstChild("HumanoidRootPart")
end

local function low(s) return string.lower(tostring(s or "")) end

local function pressBtn(pred)
    local pg = LP:FindFirstChild("PlayerGui")
    if not pg then return 0 end
    local n = 0
    for _, d in ipairs(pg:GetDescendants()) do
        if d:IsA("TextButton") and (not pred or pred(d)) then
            if firesignal then pcall(firesignal, d.MouseButton1Click) n = n + 1 end
        end
    end
    return n
end

local function findBtnByPath(segments)
    local pg = LP:FindFirstChild("PlayerGui")
    if not pg then return nil end
    for _, d in ipairs(pg:GetDescendants()) do
        if d:IsA("TextButton") then
            local full = d:GetFullName()
            local all = true
            for _, s in ipairs(segments) do
                if not string.find(full, s, 1, true) then all = false break end
            end
            if all then return d end
        end
    end
    return nil
end

--------------------------------------------------------------- ACTIONS

local function doRoll(times)
    times = times or 1
    local ok, res = invokeAny(P.RollDice, { {}, { times }, { true }, { 1 } })
    if not ok then S("RollDice gagal:", res) end
    return ok
end

local function doSellAll()
    local ok1, r1 = invokeAny(P.SellInv, { {}, { true }, { "All" } })
    local ok2, r2 = invokeAny(P.SellEquipped, { {}, { true } })
    return ok1 or ok2
end

local function doLeafRoll(times)
    times = times or 1
    return invokeAny(P.LeafRoll, { {}, { times }, { true }, { 1 } })
end

local function doCollect()
    invokeAny(P.PlotCollect, { {}, { true } })
    invokeAny(P.AppleCollect, { {}, { true } })
end

local function doQuests()
    invokeAny(P.QuestClaim, { {}, { true }, { "All" } })
    invokeAny(P.AutumnClaim, { {}, { true }, { "All" } })
    invokeAny(P.AutumnBonus, { {}, { true } })
end

local function doFreeRewards()
    invokeAny(P.DailyClaim, { {}, { true } })
    invokeAny(P.OfflineClaim, { {}, { true } })
    invokeAny(P.GroupClaim, { {}, { true } })
end

-- Autumn event: coba remote Travel dulu, lalu tombol tower Autumn Forest
local function goAutumn()
    local ok, res = invokeAny(P.AutumnTravel, { {}, { true }, { "Autumn" }, { "autumn" } })
    if ok then S("AutumnService.RF.Travel ok:", tostring(res)) return true end

    local b = findBtnByPath({ "TurkeyTower", "Autumn Forest", "Play" })
        or findBtnByPath({ "Autumn Forest" })
    if b and firesignal then
        pcall(firesignal, b.MouseButton1Click)
        S("tekan tombol Autumn Forest")
        return true
    end

    -- buka menu TurkeyTower dari HUD kalau belum kebuka
    local hubBtn = findBtnByPath({ "HUD.Top.Hub" }) or findBtnByPath({ "HUD.Left.Index" })
    if hubBtn and firesignal then
        pcall(firesignal, hubBtn.MouseButton1Click)
        task.wait(0.8)
        local b2 = findBtnByPath({ "Autumn Forest", "Play" }) or findBtnByPath({ "TurkeyTower" })
        if b2 then pcall(firesignal, b2.MouseButton1Click) return true end
    end

    S("gagal masuk autumn:", tostring(res))
    return false
end

local function doRebirth()
    return fireAny(P.Rebirth, { {}, { true } })
end

local function doBuyUpgrades()
    invokeAny(P.BuyUpgrade, { {}, { true } })
    invokeAny(P.AppleTreeUp, { {}, { true } })
end

--------------------------------------------------------------- LOOPS

local loops = {}
local function setLoop(name, interval, fn)
    if loops[name] then pcall(function() loops[name]:Disconnect() end) loops[name] = nil end
    if fn then
        loops[name] = track(task.spawn(function()
            while Flags[name] do
                local ok, err = pcall(fn)
                if not ok then S("loop err", name, err) end
                task.wait(interval)
            end
        end))
    end
end

--------------------------------------------------------------- MOVEMENT

local function applySpeed()
    local _, hum = getChar()
    if hum then hum.WalkSpeed = Flags["Walk Speed"] or 16 end
end

local flyBV, flyBG, flyConn
local function setFly(on)
    local _, hum, hrp = getChar()
    if not hrp then return end
    if on then
        flyBV = Instance.new("BodyVelocity")
        flyBV.P = 12500 flyBV.MaxForce = Vector3.new(1e5,1e5,1e5) flyBV.Velocity = Vector3.zero flyBV.Parent = hrp
        flyBG = Instance.new("BodyGyro")
        flyBG.P = 9000 flyBG.D = 700 flyBG.MaxTorque = Vector3.new(4e5,4e5,4e5) flyBG.CFrame = hrp.CFrame flyBG.Parent = hrp
        if hum then hum.PlatformStand = true end
        flyConn = track(RunService.RenderStepped:Connect(function()
            if not (flyBV and flyBV.Parent) then return end
            local cam = Workspace.CurrentCamera
            local dir = Vector3.zero
            local sp = Flags["Fly Speed"] or 60
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.yAxis end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir - Vector3.yAxis end
            if dir.Magnitude > 0 then dir = dir.Unit end
            flyBV.Velocity = dir * sp
            flyBG.CFrame = cam.CFrame
        end))
    else
        if flyConn then flyConn:Disconnect() flyConn = nil end
        if flyBV then flyBV:Destroy() flyBV = nil end
        if flyBG then flyBG:Destroy() flyBG = nil end
        if hum then hum.PlatformStand = false end
    end
end

--------------------------------------------------------------- UI

local gui = Instance.new("ScreenGui")
gui.Name = "ADHub"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.IgnoreGuiInset = true
gui.Parent = game:GetService("CoreGui")
getgenv().ADHub = gui

local win = Instance.new("Frame")
win.BackgroundColor3 = Color3.fromRGB(14, 18, 24)
win.BorderSizePixel = 0
win.ClipsDescendants = true
win.Parent = gui
Instance.new("UICorner", win).CornerRadius = UDim.new(0, 10)
local ws = Instance.new("UIStroke", win) ws.Color = Color3.fromRGB(45, 55, 70)

local top = Instance.new("Frame")
top.Size = UDim2.new(1, 0, 0, 38)
top.BackgroundColor3 = Color3.fromRGB(20, 26, 34)
top.BorderSizePixel = 0
top.Parent = win

local ttl = Instance.new("TextLabel")
ttl.Size = UDim2.new(1, -100, 1, 0)
ttl.Position = UDim2.new(0, 14, 0, 0)
ttl.BackgroundTransparency = 1
ttl.Font = Enum.Font.GothamBold
ttl.TextSize = 13
ttl.TextColor3 = Color3.fromRGB(56, 189, 248)
ttl.TextXAlignment = Enum.TextXAlignment.Left
ttl.Text = "Anime Dice  ·  4080"
ttl.Parent = top

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 30, 0, 30)
closeBtn.Position = UDim2.new(1, -38, 0, 4)
closeBtn.BackgroundTransparency = 1
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 16
closeBtn.TextColor3 = Color3.fromRGB(148, 163, 184)
closeBtn.Text = "X"
closeBtn.Parent = top

local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(0, 120, 1, -38)
tabBar.Position = UDim2.new(0, 0, 0, 38)
tabBar.BackgroundColor3 = Color3.fromRGB(17, 22, 29)
tabBar.BorderSizePixel = 0
tabBar.Parent = win
local tabPad = Instance.new("UIPadding", tabBar)
tabPad.PaddingTop = UDim.new(0, 8)
local tabLay = Instance.new("UIListLayout", tabBar)
tabLay.SortOrder = Enum.SortOrder.LayoutOrder
tabLay.Padding = UDim.new(0, 2)

local content = Instance.new("Frame")
content.Position = UDim2.new(0, 120, 0, 38)
content.BackgroundTransparency = 1
content.Parent = win

local tabs = {}
local function makeTab(name)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 34)
    btn.BackgroundTransparency = 1
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 12
    btn.TextColor3 = Color3.fromRGB(148, 163, 184)
    btn.Text = name
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.LayoutOrder = #tabs + 1
    btn.Parent = tabBar
    local pad = Instance.new("UIPadding", btn)
    pad.PaddingLeft = UDim.new(0, 14)
    pad.PaddingRight = UDim.new(0, 8)

    local bar = Instance.new("Frame", btn)
    bar.Name = "ActiveBar"
    bar.Size = UDim2.new(0, 3, 0, 16)
    bar.Position = UDim2.new(0, 0, 0.5, -8)
    bar.BackgroundColor3 = Color3.fromRGB(56, 189, 248)
    bar.BorderSizePixel = 0
    bar.Visible = false
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)
    btn.ActiveBar = bar

    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 3
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.Visible = false
    page.Parent = content
    local pp = Instance.new("UIPadding", page)
    pp.PaddingLeft = UDim.new(0, 14) pp.PaddingRight = UDim.new(0, 14)
    pp.PaddingTop = UDim.new(0, 10) pp.PaddingBottom = UDim.new(0, 14)
    local lay = Instance.new("UIListLayout", page)
    lay.SortOrder = Enum.SortOrder.LayoutOrder lay.Padding = UDim.new(0, 6)

    tabs[#tabs + 1] = { btn = btn, page = page }
    return page
end

local function selectTab(idx)
    for i, e in ipairs(tabs) do
        local on = (i == idx)
        e.page.Visible = on
        e.btn.TextColor3 = on and Color3.fromRGB(56, 189, 248) or Color3.fromRGB(148, 163, 184)
        if e.btn.ActiveBar then e.btn.ActiveBar.Visible = on end
    end
end

local function section(parent, text)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, 0, 0, 22)
    l.BackgroundTransparency = 1
    l.Font = Enum.Font.GothamBold
    l.TextSize = 11
    l.TextColor3 = Color3.fromRGB(100, 116, 139)
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Text = string.upper(text)
    l.Parent = parent
end

local function toggle(parent, label, default, cb)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 30)
    row.BackgroundTransparency = 1
    row.Parent = parent
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -50, 1, 0)
    l.BackgroundTransparency = 1
    l.Font = Enum.Font.Gotham
    l.TextSize = 12
    l.TextColor3 = Color3.fromRGB(203, 213, 225)
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Text = label
    l.Parent = row

    local state = default and true or false
    local pill = Instance.new("TextButton")
    pill.Size = UDim2.new(0, 40, 0, 20)
    pill.Position = UDim2.new(1, -40, 0.5, -10)
    pill.BackgroundColor3 = state and Color3.fromRGB(56,189,248) or Color3.fromRGB(45,55,70)
    pill.BorderSizePixel = 0
    pill.Text = ""
    pill.AutoButtonColor = false
    pill.Parent = row
    Instance.new("UICorner", pill).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.Position = state and UDim2.new(1,-17,0.5,-7) or UDim2.new(0,3,0.5,-7)
    knob.BackgroundColor3 = Color3.fromRGB(248, 250, 252)
    knob.BorderSizePixel = 0
    knob.Parent = pill
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local function render()
        TweenService:Create(pill, TweenInfo.new(0.15), {
            BackgroundColor3 = state and Color3.fromRGB(56,189,248) or Color3.fromRGB(45,55,70) }):Play()
        TweenService:Create(knob, TweenInfo.new(0.15), {
            Position = state and UDim2.new(1,-17,0.5,-7) or UDim2.new(0,3,0.5,-7) }):Play()
        Flags[label] = state
        if cb then cb(state) end
    end

    pill.MouseButton1Click:Connect(function() state = not state render() end)
    Flags[label] = state
end

local function slider(parent, label, min, max, default, cb)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 42)
    row.BackgroundTransparency = 1
    row.Parent = parent
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, 0, 0, 18)
    l.BackgroundTransparency = 1
    l.Font = Enum.Font.Gotham
    l.TextSize = 11
    l.TextColor3 = Color3.fromRGB(203, 213, 225)
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Text = label .. ": " .. tostring(default)
    l.Parent = row

    local tr = Instance.new("Frame")
    tr.Size = UDim2.new(1, 0, 0, 6)
    tr.Position = UDim2.new(0, 0, 0, 26)
    tr.BackgroundColor3 = Color3.fromRGB(35, 43, 55)
    tr.BorderSizePixel = 0
    tr.Parent = row
    Instance.new("UICorner", tr).CornerRadius = UDim.new(1, 0)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(56, 189, 248)
    fill.BorderSizePixel = 0
    fill.Parent = tr
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    local dragging = false
    local function commit(v)
        v = math.clamp(v, min, max)
        local alpha = (max == min) and 0 or (v - min) / (max - min)
        fill.Size = UDim2.new(alpha, 0, 1, 0)
        l.Text = label .. ": " .. tostring(math.floor(v * 100 + 0.5) / 100)
        Flags[label] = v
        if cb then cb(v) end
    end

    tr.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            local rel = (input.Position.X - tr.AbsolutePosition.X) / tr.AbsoluteSize.X
            commit(min + (max - min) * math.clamp(rel, 0, 1))
        end
    end)
    track(UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
           or input.UserInputType == Enum.UserInputType.Touch) then
            local rel = (input.Position.X - tr.AbsolutePosition.X) / tr.AbsoluteSize.X
            commit(min + (max - min) * math.clamp(rel, 0, 1))
        end
    end))
    track(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end))
    commit(default)
end

local function button(parent, label, cb)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 0, 30)
    b.BackgroundColor3 = Color3.fromRGB(25, 32, 42)
    b.BorderSizePixel = 0
    b.Font = Enum.Font.Gotham
    b.TextSize = 12
    b.TextColor3 = Color3.fromRGB(226, 232, 240)
    b.Text = label
    b.Parent = parent
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    b.MouseButton1Click:Connect(cb)
end

local function notify(text)
    local t = Instance.new("TextLabel")
    t.Size = UDim2.new(0, 300, 0, 30)
    t.Position = UDim2.new(0.5, -150, 1, -70)
    t.BackgroundColor3 = Color3.fromRGB(20, 26, 34)
    t.BorderSizePixel = 0
    t.Font = Enum.Font.Gotham
    t.TextSize = 12
    t.TextColor3 = Color3.fromRGB(226, 232, 240)
    t.Text = text
    t.Parent = gui
    Instance.new("UICorner", t).CornerRadius = UDim.new(0, 6)
    local s = Instance.new("UIStroke", t) s.Color = Color3.fromRGB(56, 189, 248)
    task.delay(3, function() t:Destroy() end)
end

-- drag (mouse + touch)
do
    local dragging, dragStart, startPos
    top.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true dragStart = input.Position startPos = win.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    win.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
           or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStart
            win.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                                     startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end

closeBtn.MouseButton1Click:Connect(function() gui.Enabled = not gui.Enabled end)
track(UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.RightShift then gui.Enabled = not gui.Enabled end
end))

local function fitScreen()
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local vp = cam.ViewportSize
    local w = math.min(470, vp.X - 24)
    local h = math.min(360, vp.Y - 24)
    win.Size = UDim2.new(0, w, 0, h)
    win.Position = UDim2.new(0.5, -w/2, 0.5, -h/2)
    local tw = math.floor(w * 0.30)
    tabBar.Size = UDim2.new(0, tw, 1, -38)
    content.Size = UDim2.new(1, -tw, 1, -38)
    content.Position = UDim2.new(0, tw, 0, 38)
end
fitScreen()
do
    local cam = Workspace.CurrentCamera
    if cam then track(cam:GetPropertyChangedSignal("ViewportSize"):Connect(fitScreen)) end
end

--------------------------------------------------------------- BUILD

local pRoll = makeTab("Roll")
local pAutumn = makeTab("Autumn")
local pMoney = makeTab("Money")
local pMain = makeTab("Main")
local pMisc = makeTab("Misc")
selectTab(1)
for i, e in ipairs(tabs) do e.btn.MouseButton1Click:Connect(function() selectTab(i) end) end

-- ROLL
section(pRoll, "Dice")
toggle(pRoll, "Auto Roll (server)", false, function(on)
    fireAny(P.SetAutoRoll, { { on }, { on, true } })
    if on then
        setLoop("Auto Roll (server)", 1.2, function() doRoll() end)
    end
end)
toggle(pRoll, "Auto Sell", false, function(on)
    fireAny(P.AutoSell, { { on }, { on, true } })
    if on then setLoop("Auto Sell", 3, function() doSellAll() end) end
end)
button(pRoll, "Roll x1", function() if doRoll(1) then notify("Roll sent") end end)
button(pRoll, "Roll x10", function() if doRoll(10) then notify("Roll x10 sent") end end)
button(pRoll, "Sell Inventory", function()
    if doSellAll() then notify("Sell sent") else notify("Sell gagal") end
end)

section(pRoll, "Other Rolls")
button(pRoll, "Quirk Roll", function()
    fireAny(P.QuirkRoll, { {}, { true } }) notify("Quirk roll")
end)
button(pRoll, "Trait Roll", function()
    fireAny(P.TraitRoll, { {}, { true } }) notify("Trait roll")
end)
button(pRoll, "Grade Roll", function()
    fireAny(P.GradeRoll, { {}, { true } }) notify("Grade roll")
end)

-- AUTUMN
section(pAutumn, "Event")
button(pAutumn, "MASUK AREA AUTUMN", function()
    if goAutumn() then notify("Travel Autumn dikirim") else notify("Gagal masuk autumn") end
end)
button(pAutumn, "Sync Autumn Quest", function()
    local ok, res = invokeAny(P.AutumnSync, { {}, { true } })
    S("AutumnSync:", tostring(res))
    notify(ok and ("Sync ok: " .. tostring(res):sub(1, 60)) or "Sync gagal")
end)
button(pAutumn, "Claim Semua Autumn Quest", function()
    invokeAny(P.AutumnClaim, { {}, { true }, { "All" } })
    invokeAny(P.AutumnBonus, { {}, { true } })
    notify("Claim autumn dikirim")
end)
button(pAutumn, "Claim via GUI (firesignal)", function()
    local n = pressBtn(function(b) return b:GetFullName():find("AutumnQuests", 1, true) ~= nil end)
    notify("Tombol autumn ditekan: " .. n)
end)

section(pAutumn, "Leaf Dice")
toggle(pAutumn, "Auto Leaf Roll", false, function(on)
    fireAny(P.LeafAutoSell, { { on }, { on, true } })
    if on then
        setLoop("Auto Leaf Roll", 1.5, function() doLeafRoll() end)
    end
end)
button(pAutumn, "Leaf Roll x1", function()
    if doLeafRoll(1) then notify("Leaf roll") end
end)
button(pAutumn, "Leaf Roll x10", function()
    if doLeafRoll(10) then notify("Leaf roll x10") end
end)
button(pAutumn, "Buka Menu LeafDice", function()
    local b = findBtnByPath({ "HUD", "Hub" }) or findBtnByPath({ "HUD.Left.Index" })
    if b and firesignal then pcall(firesignal, b.MouseButton1Click) end
    notify("Cari menu LeafDice manual kalau gak kebuka")
end)

section(pAutumn, "Apple / Harvest")
toggle(pAutumn, "Auto Collect Apples", false, function(on)
    if on then setLoop("Auto Collect", 2, doCollect) end
end)
toggle(pAutumn, "Auto Buy Apple Upgrade", false, function(on)
    if on then setLoop("Auto Apple Up", 5, doBuyUpgrades) end
end)

-- MONEY
section(pMoney, "Passive")
button(pMoney, "Collect Balance (plot)", function()
    invokeAny(P.PlotCollect, { {}, { true } }) notify("Collect dikirim")
end)
button(pMoney, "Equip Best Unit", function()
    invokeAny(P.PlotEquipBest, { {}, { true } }) notify("Equip best")
end)
button(pMoney, "Equip Best Tower", function()
    fireAny(P.EquipBestTower, { {}, { true } }) notify("Tower best")
end)
toggle(pMoney, "Auto Rebirth", false, function(on)
    if on then setLoop("Auto Rebirth", 4, doRebirth) end
end)
toggle(pMoney, "Auto Quests (claim)", false, function(on)
    if on then setLoop("Auto Quests", 6, doQuests) end
end)
toggle(pMoney, "Auto Free Rewards", false, function(on)
    if on then setLoop("Auto Rewards", 10, doFreeRewards) end
end)

-- MAIN
section(pMain, "Movement")
slider(pMain, "Walk Speed", 16, 300, 16, applySpeed)
slider(pMain, "Jump Power", 50, 500, 50, function(v)
    local _, hum = getChar()
    if hum then hum.UseJumpPower = true hum.JumpPower = v end
end)
toggle(pMain, "Fly", false, setFly)
slider(pMain, "Fly Speed", 10, 400, 60, function() end)
slider(pMain, "Gravity", 0, 196, 196, function(v) Workspace.Gravity = v end)

track(LP.CharacterAdded:Connect(function()
    task.wait(1)
    applySpeed()
end))

-- MISC
section(pMisc, "Diagnostics")
button(pMisc, "Tes Remote (cek 84 remote)", function()
    local list = {}
    for k, v in pairs(P) do
        if remote(v) then list[#list + 1] = k else S("MISSING:", k, v) end
    end
    table.sort(list)
    S("remote ada:", #list)
    notify("Remote terpasang: " .. #list .. "/" .. (function() local n=0 for _ in pairs(P) do n=n+1 end return n end)())
end)
section(pMisc, "Network")
button(pMisc, "Rejoin", function() TeleportService:Teleport(game.PlaceId, LP) end)
button(pMisc, "Unload", function()
    setFly(false)
    for _, c in ipairs(Conns) do pcall(function() c:Disconnect() end) end
    gui:Destroy()
    getgenv().ADHub = nil
end)

S("Anime Dice hub loaded. Remote resolved.")
notify("Anime Dice hub loaded")
