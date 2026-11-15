--[[ AnimeDice Hub — discovery engine
     Butuh executor dengan firesignal / fireproximityprompt / fireclickdetector.
     Tekan DUMP dulu, kirim output console -> remote exact bisa dikunci. ]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst   = game:GetService("ReplicatedFirst")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local Workspace         = game:GetService("Workspace")
local Lighting          = game:GetService("Lighting")
local TweenService      = game:GetService("TweenService")
local TeleportService   = game:GetService("TeleportService")
local HttpService       = game:GetService("HttpService")

local LP = Players.LocalPlayer

local Flags, Conns = {}, {}
local function track(c) table.insert(Conns, c) return c end
local function log(...) print("[AD]", ...) end

--------------------------------------------------------------- CONFIG

local Cfg = {
    RollInterval     = 1.0,
    CollectInterval  = 0.6,
    RebirthInterval  = 2.0,
    UpgradeInterval  = 1.5,

    Roll    = { "roll", "spin", "dice", "lempar" },
    Collect = { "collect", "claim", "reward", "chest", "gift", "open",
                "autumn", "leaf", "leaves", "candy", "pumpkin", "event", "daily" },
    Rebirth = { "rebirth", "prestige", "ascend" },
    Upgrade = { "upgrade", "enhance", "buy", "purchase" },
    Sell    = { "sell", "delete" },

    PromptCollect = { "autumn", "leaf", "leaves", "candy", "pumpkin",
                      "chest", "collect", "gift", "event", "token", "coin" },
}

--------------------------------------------------------------- HELPERS

local function getChar()
    local char = LP.Character or LP.CharacterAdded:Wait()
    return char, char:FindFirstChildOfClass("Humanoid"), char:FindFirstChild("HumanoidRootPart")
end

local function low(s) return string.lower(tostring(s or "")) end

local function matchAny(text, list)
    local t = low(text)
    for _, pat in ipairs(list) do
        if string.find(t, pat, 1, true) then return pat end
    end
    return nil
end

local function press(btn)
    if not btn then return false end
    if firesignal then
        pcall(firesignal, btn.MouseButton1Click)
        return true
    end
    return false
end

--------------------------------------------------------------- DUMPER

-- Balikin dump sebagai string. Gak butuh console/F9.
local function buildDump()
    local out = {}
    local function put(s) out[#out + 1] = s end

    put("===== DUMP START =====")
    put("PlaceId: " .. tostring(game.PlaceId) .. "  JobId: " .. tostring(game.JobId))
    put("Executor: " .. tostring((identifyexecutor and identifyexecutor()) or "?"))
    put("firesignal=" .. tostring(firesignal ~= nil)
        .. " prompt=" .. tostring(fireproximityprompt ~= nil)
        .. " clickdet=" .. tostring(fireclickdetector ~= nil)
        .. " clipboard=" .. tostring(setclipboard ~= nil)
        .. " writefile=" .. tostring(writefile ~= nil))

    local remotes, prompts, clicks = {}, {}, {}

    local roots = { ReplicatedStorage, ReplicatedFirst, Workspace }
    for _, root in ipairs(roots) do
        local ok, desc = pcall(function() return root:GetDescendants() end)
        if ok then
            for _, d in ipairs(desc) do
                local cls = d.ClassName
                if cls == "RemoteEvent" or cls == "RemoteFunction"
                   or cls == "UnreliableRemoteEvent" then
                    remotes[#remotes + 1] = cls .. "  " .. d:GetFullName()
                elseif cls == "ProximityPrompt" then
                    prompts[#prompts + 1] = "ProximityPrompt  " .. d:GetFullName()
                        .. "  action=" .. tostring(d.ActionText)
                elseif cls == "ClickDetector" then
                    clicks[#clicks + 1] = "ClickDetector  " .. d:GetFullName()
                end
            end
        end
    end

    table.sort(remotes) table.sort(prompts) table.sort(clicks)

    put("--- REMOTES (" .. #remotes .. ") ---")
    for _, l in ipairs(remotes) do put(l) end
    put("--- PROMPTS (" .. #prompts .. ") ---")
    for _, l in ipairs(prompts) do put(l) end
    put("--- CLICKDETECTORS (" .. #clicks .. ") ---")
    for _, l in ipairs(clicks) do put(l) end

    local pg = LP:FindFirstChild("PlayerGui")
    if pg then
        local btns = {}
        for _, d in ipairs(pg:GetDescendants()) do
            if d:IsA("TextButton") and d.Visible and low(d.Text) ~= "" then
                btns[#btns + 1] = "BUTTON  " .. d:GetFullName() .. "  [" .. tostring(d.Text) .. "]"
            end
        end
        table.sort(btns)
        put("--- GUI BUTTONS (" .. #btns .. ") ---")
        for _, l in ipairs(btns) do put(l) end
    end

    put("===== DUMP END =====")
    return table.concat(out, "\n")
end

local lastDump = ""
local function dumpAll(showUI)
    lastDump = buildDump()
    getgenv().AD_DumpText = lastDump
    print(lastDump)
    if showUI and getgenv().AD_ShowConsole then
        getgenv().AD_ShowConsole(lastDump)
    end
    return lastDump
end
getgenv().AD_Dump = function() return dumpAll(true) end

--------------------------------------------------------------- ENGINES

local function scanButtons(patterns)
    local found = {}
    local pg = LP:FindFirstChild("PlayerGui")
    if not pg then return found end
    for _, d in ipairs(pg:GetDescendants()) do
        if d:IsA("TextButton") and d.Visible and low(d.Text) ~= "" then
            if matchAny(d.Text, patterns) then
                table.insert(found, d)
            end
        end
    end
    return found
end

local function pressPattern(patterns)
    local btns = scanButtons(patterns)
    local n = 0
    for _, b in ipairs(btns) do
        if press(b) then n = n + 1 end
    end
    return n
end

local function firePrompts(patterns)
    local n = 0
    for _, d in ipairs(Workspace:GetDescendants()) do
        if d:IsA("ProximityPrompt") and matchAny(d.ActionText .. " " .. d.ObjectText, patterns) then
            if d.Enabled then
                pcall(function()
                    d.HoldDuration = 0
                    d.MaxActivationDistance = 1e4
                end)
                if fireproximityprompt then
                    pcall(fireproximityprompt, d)
                    n = n + 1
                end
            end
        end
    end
    return n
end

local function fireClickDetectors(patterns)
    local n = 0
    for _, d in ipairs(Workspace:GetDescendants()) do
        if d:IsA("ClickDetector") then
            local parentName = d.Parent and d.Parent.Name or ""
            if matchAny(parentName .. " " .. d.Name, patterns) then
                pcall(function() d.MaxActivationDistance = 1e4 end)
                if fireclickdetector then
                    pcall(fireclickdetector, d)
                    n = n + 1
                end
            end
        end
    end
    return n
end

--------------------------------------------------------------- LOOPS

local loops = {}

local function setLoop(name, interval, fn)
    if loops[name] then
        pcall(function() loops[name]:Disconnect() end)
        loops[name] = nil
    end
    if fn then
        loops[name] = track(task.spawn(function()
            while Flags[name] do
                local ok, err = pcall(fn)
                if not ok then log("loop err " .. name .. ": " .. tostring(err)) end
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
    local char, hum, hrp = getChar()
    if not hrp then return end
    if on then
        flyBV = Instance.new("BodyVelocity")
        flyBV.P = 12500
        flyBV.MaxForce = Vector3.new(1e5, 1e5, 1e5)
        flyBV.Velocity = Vector3.zero
        flyBV.Parent = hrp

        flyBG = Instance.new("BodyGyro")
        flyBG.P = 9000
        flyBG.D = 700
        flyBG.MaxTorque = Vector3.new(4e5, 4e5, 4e5)
        flyBG.CFrame = hrp.CFrame
        flyBG.Parent = hrp

        if hum then hum.PlatformStand = true end

        flyConn = track(RunService.RenderStepped:Connect(function()
            if not (flyBV and flyBV.Parent) then return end
            local cam = Workspace.CurrentCamera
            local dir = Vector3.zero
            local speed = Flags["Fly Speed"] or 60
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.yAxis end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir - Vector3.yAxis end
            if dir.Magnitude > 0 then dir = dir.Unit end
            flyBV.Velocity = dir * speed
            flyBG.CFrame = cam.CFrame
        end))
    else
        if flyConn then flyConn:Disconnect() flyConn = nil end
        if flyBV then flyBV:Destroy() flyBV = nil end
        if flyBG then flyBG:Destroy() flyBG = nil end
        if hum then hum.PlatformStand = false end
    end
end

--------------------------------------------------------------- ESP

local highlights, espConn

local function espScan()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP then
            local char = plr.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if char and hum and hum.Health > 0 and char:FindFirstChild("HumanoidRootPart") then
                if not highlights[char] or not highlights[char].Parent then
                    local h = Instance.new("Highlight")
                    h.FillColor = Color3.fromRGB(56, 189, 248)
                    h.FillTransparency = 0.75
                    h.OutlineColor = Color3.fromRGB(56, 189, 248)
                    h.OutlineTransparency = 0
                    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    h.Adornee = char
                    h.Parent = char
                    highlights[char] = h
                end
            end
        end
    end
end

local function espClear()
    for inst, h in pairs(highlights) do
        if h and h.Parent then h:Destroy() end
        highlights[inst] = nil
    end
end

local function setESP(on)
    if on then
        espScan()
        espConn = track(RunService.Heartbeat:Connect(espScan))
    else
        if espConn then espConn:Disconnect() espConn = nil end
        espClear()
    end
end

--------------------------------------------------------------- CLICK TP

local clickTPConn
local function setClickTP(on)
    if on then
        clickTPConn = track(UserInputService.InputBegan:Connect(function(input, gpe)
            if gpe or input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
            local m = UserInputService:GetMouseLocation()
            local ray = Workspace.CurrentCamera:ViewportPointToRay(m.X, m.Y)
            local params = RaycastParams.new()
            params.FilterDescendantsInstances = { LP.Character }
            params.FilterType = Enum.RaycastFilterType.Exclude
            local hit = Workspace:Raycast(ray.Origin, ray.Direction * 2000, params)
            if hit then
                local _, _, hrp = getChar()
                if hrp then hrp.CFrame = CFrame.new(hit.Position + Vector3.new(0, 3, 0)) end
            end
        end))
    else
        if clickTPConn then clickTPConn:Disconnect() clickTPConn = nil end
    end
end

--------------------------------------------------------------- SERVER

local function serverHop()
    local ok, res = pcall(function()
        return HttpService:JSONDecode(game:HttpGet(
            "https://games.roblox.com/v1/games/" .. game.PlaceId ..
            "/servers/Public?sortOrder=Asc&limit=100&excludeFullGames=true"))
    end)
    if not ok or not res or not res.data then return end
    for _, srv in ipairs(res.data) do
        if srv.id ~= game.JobId and srv.playing < srv.maxPlayers then
            pcall(TeleportService.TeleportToPlaceInstance,
                TeleportService, game.PlaceId, srv.id, LP)
            return
        end
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
win.Size = UDim2.new(0, 470, 0, 350)
win.Position = UDim2.new(0.5, -235, 0.5, -175)
win.BackgroundColor3 = Color3.fromRGB(14, 18, 24)
win.BorderSizePixel = 0
win.ClipsDescendants = true
win.Parent = gui

local c1 = Instance.new("UICorner") c1.CornerRadius = UDim.new(0, 10) c1.Parent = win
local s1 = Instance.new("UIStroke") s1.Color = Color3.fromRGB(45, 55, 70) s1.Parent = win

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
ttl.Text = "AnimeDice Hub  ·  4080"
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

local content = Instance.new("Frame")
content.Size = UDim2.new(1, -120, 1, -38)
content.Position = UDim2.new(0, 120, 0, 38)
content.BackgroundTransparency = 1
content.Parent = win

local pages, tabs = {}, {}

local function makeTab(name)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 32)
    btn.BackgroundTransparency = 1
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 12
    btn.TextColor3 = Color3.fromRGB(148, 163, 184)
    btn.Text = name
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.Parent = tabBar

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 14)
    pad.Parent = btn

    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 3
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.Visible = false
    page.Parent = content

    local pp = Instance.new("UIPadding")
    pp.PaddingLeft = UDim.new(0, 14)
    pp.PaddingRight = UDim.new(0, 14)
    pp.PaddingTop = UDim.new(0, 10)
    pp.PaddingBottom = UDim.new(0, 14)
    pp.Parent = page

    local lay = Instance.new("UIListLayout")
    lay.SortOrder = Enum.SortOrder.LayoutOrder
    lay.Padding = UDim.new(0, 6)
    lay.Parent = page

    table.insert(tabs, { btn = btn, page = page })
    pages[name] = page
    return page
end

local function selectTab(idx)
    for i, e in ipairs(tabs) do
        local on = (i == idx)
        e.page.Visible = on
        e.btn.TextColor3 = on and Color3.fromRGB(56, 189, 248)
            or Color3.fromRGB(148, 163, 184)
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
    return l
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
    pill.BackgroundColor3 = state and Color3.fromRGB(56, 189, 248) or Color3.fromRGB(45, 55, 70)
    pill.BorderSizePixel = 0
    pill.Text = ""
    pill.AutoButtonColor = false
    pill.Parent = row
    local pc = Instance.new("UICorner") pc.CornerRadius = UDim.new(1, 0) pc.Parent = pill

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.Position = state and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)
    knob.BackgroundColor3 = Color3.fromRGB(248, 250, 252)
    knob.BorderSizePixel = 0
    knob.Parent = pill
    local kc = Instance.new("UICorner") kc.CornerRadius = UDim.new(1, 0) kc.Parent = knob

    local function render()
        TweenService:Create(pill, TweenInfo.new(0.15), {
            BackgroundColor3 = state and Color3.fromRGB(56, 189, 248) or Color3.fromRGB(45, 55, 70),
        }):Play()
        TweenService:Create(knob, TweenInfo.new(0.15), {
            Position = state and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7),
        }):Play()
        Flags[label] = state
        if cb then cb(state) end
    end

    pill.MouseButton1Click:Connect(function()
        state = not state
        render()
    end)

    Flags[label] = state
    return row
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
    local tc = Instance.new("UICorner") tc.CornerRadius = UDim.new(1, 0) tc.Parent = tr

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(56, 189, 248)
    fill.BorderSizePixel = 0
    fill.Parent = tr
    local fc = Instance.new("UICorner") fc.CornerRadius = UDim.new(1, 0) fc.Parent = fill

    local value = default
    local dragging = false

    local function commit(v)
        value = math.clamp(v, min, max)
        local alpha = (max == min) and 0 or (value - min) / (max - min)
        fill.Size = UDim2.new(alpha, 0, 1, 0)
        l.Text = label .. ": " .. tostring(math.floor(value * 100 + 0.5) / 100)
        Flags[label] = value
        if cb then cb(value) end
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
           or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end))

    commit(default)
    return row
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
    b.AutoButtonColor = true
    b.Parent = parent
    local bc = Instance.new("UICorner") bc.CornerRadius = UDim.new(0, 6) bc.Parent = b
    b.MouseButton1Click:Connect(cb)
    return b
end

local function notify(text)
    local t = Instance.new("TextLabel")
    t.Size = UDim2.new(0, 260, 0, 30)
    t.Position = UDim2.new(0.5, -130, 1, -60)
    t.BackgroundColor3 = Color3.fromRGB(20, 26, 34)
    t.BorderSizePixel = 0
    t.Font = Enum.Font.Gotham
    t.TextSize = 12
    t.TextColor3 = Color3.fromRGB(226, 232, 240)
    t.Text = text
    t.Parent = gui
    local nc = Instance.new("UICorner") nc.CornerRadius = UDim.new(0, 6) nc.Parent = t
    local ns = Instance.new("UIStroke") ns.Color = Color3.fromRGB(56, 189, 248) ns.Parent = t
    task.delay(2.5, function() t:Destroy() end)
end

-- drag
do
    local dragging, dragStart, startPos
    top.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = win.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    win.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
           or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStart
            win.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end

--------------------------------------------------------------- DUMP READER (mobile-safe, no clipboard needed)

local reader, readerBox, readerIdx, readerLines = nil, nil, 1, {}
local PER_PAGE = 6

-- semua nama fungsi clipboard yang dipakai executor berbeda-beda
local function tryClipboard(text)
    local fns = {
        rawget(getfenv(0), "setclipboard"),
        rawget(getfenv(0), "toclipboard"),
        rawget(getfenv(0), "set_clipboard"),
        rawget(getfenv(0), "writeclipboard"),
        rawget(getfenv(0), "Clipboard"),
    }
    if Clipboard and type(Clipboard) == "table" and type(Clipboard.set) == "function" then
        table.insert(fns, function(t) Clipboard.set(t) end)
    end
    if syn and type(syn) == "table" and type(syn.write_clipboard) == "function" then
        table.insert(fns, function(t) syn.write_clipboard(t) end)
    end
    for _, fn in ipairs(fns) do
        if type(fn) == "function" then
            local ok = pcall(fn, text)
            if ok then return true end
        end
    end
    return false
end

-- Upload dump ke paste service supaya bisa dibuka di HP/browser.
-- Coba beberapa endpoint, balikin URL atau nil+err.
local function uploadText(text)
    if not (syn and syn.request) and not (http and http.request) and not request then
        return nil, "executor tidak punya http.request"
    end

    local function req(opts)
        if syn and syn.request then return syn.request(opts) end
        if http and http.request then return http.request(opts) end
        return request(opts)
    end

    local body = HttpService:JSONEncode({ text = text })

    local endpoints = {
        { url = "https://api.paste.gg/v1/pastes", method = "POST",
          headers = { ["Content-Type"] = "application/json" },
          body = HttpService:JSONEncode({
              name = "ad_dump",
              visibility = "unlisted",
              files = { { name = "dump.txt", content = { format = "text", value = text } } },
          }),
          parse = function(res)
              local ok, d = pcall(HttpService.JSONDecode, HttpService, res.Body)
              if ok and d and d.id then return "https://paste.gg/" .. d.id end
          end },

        { url = "https://dpaste.com/api/v2/", method = "POST",
          headers = { ["Content-Type"] = "application/x-www-form-urlencoded" },
          body = "content=" .. (text:gsub("[^%w%-%._~]", function(c)
              return string.format("%%%02X", string.byte(c))
          end)) .. "&syntax=text&expiry=2592000",
          parse = function(res)
              local b = tostring(res.Body or ""):gsub("%s+$", "")
              if b:match("^https?://") then return b end
          end },
    }

    for _, ep in ipairs(endpoints) do
        local ok, res = pcall(req, {
            Url = ep.url,
            Method = ep.method,
            Headers = ep.headers,
            Body = ep.body,
        })
        if ok and res and (res.StatusCode == 200 or res.StatusCode == 201) then
            local url = ep.parse(res)
            if url then return url end
        end
    end

    return nil, "semua endpoint gagal"
end

local function renderPage()
    if not readerBox then return end
    local total = #readerLines
    local pages = math.max(1, math.ceil(total / PER_PAGE))
    readerIdx = math.clamp(readerIdx, 1, pages)
    local a = (readerIdx - 1) * PER_PAGE + 1
    local b = math.min(a + PER_PAGE - 1, total)

    local out = {}
    for i = a, b do
        out[#out + 1] = readerLines[i]
    end
    readerBox.Text = table.concat(out, "\n")

    if reader and reader:FindFirstChild("PageLbl") then
        reader.PageLbl.Text = readerIdx .. "/" .. pages .. "  (" .. total .. " baris)"
    end
end

local function showConsole(text)
    readerLines = {}
    for line in string.gmatch(text or "", "[^\n]*") do
        readerLines[#readerLines + 1] = line
    end
    if #readerLines == 0 then readerLines = { "(kosong)" } end

    if not reader then
        reader = Instance.new("Frame")
        reader.Size = UDim2.new(0, 470, 0, 400)
        reader.Position = UDim2.new(0.5, -235, 0.5, -200)
        reader.BackgroundColor3 = Color3.fromRGB(10, 13, 18)
        reader.BorderSizePixel = 0
        reader.Visible = false
        reader.ZIndex = 50
        reader.Parent = gui
        local cc = Instance.new("UICorner") cc.CornerRadius = UDim.new(0, 10) cc.Parent = reader
        local cs = Instance.new("UIStroke") cs.Color = Color3.fromRGB(56, 189, 248) cs.Parent = reader

        local bar = Instance.new("Frame")
        bar.Size = UDim2.new(1, 0, 0, 36)
        bar.BackgroundColor3 = Color3.fromRGB(20, 26, 34)
        bar.BorderSizePixel = 0
        bar.ZIndex = 51
        bar.Parent = reader
        local bc = Instance.new("UICorner") bc.CornerRadius = UDim.new(0, 10) bc.Parent = bar

        local hdr = Instance.new("TextLabel")
        hdr.Name = "PageLbl"
        hdr.Size = UDim2.new(1, -160, 1, 0)
        hdr.Position = UDim2.new(0, 10, 0, 0)
        hdr.BackgroundTransparency = 1
        hdr.Font = Enum.Font.GothamBold
        hdr.TextSize = 12
        hdr.TextColor3 = Color3.fromRGB(56, 189, 248)
        hdr.TextXAlignment = Enum.TextXAlignment.Left
        hdr.Text = "DUMP"
        hdr.ZIndex = 52
        hdr.Parent = bar
        reader.PageLbl = hdr

        local function mkBtn(label, xoff, w, color, cb, parent)
            local b = Instance.new("TextButton")
            b.Size = UDim2.new(0, w, 0, 26)
            b.Position = UDim2.new(1, xoff, 0.5, -13)
            b.BackgroundColor3 = color
            b.BorderSizePixel = 0
            b.Font = Enum.Font.GothamBold
            b.TextSize = 12
            b.TextColor3 = Color3.fromRGB(240, 248, 255)
            b.Text = label
            b.ZIndex = 52
            b.Parent = parent
            local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 5) c.Parent = b
            b.MouseButton1Click:Connect(cb)
            return b
        end

        mkBtn("X", -34, 28, Color3.fromRGB(120, 40, 40), function()
            reader.Visible = false
        end, bar)

        -- reader box: font besar, bisa di-select pakai jari
        readerBox = Instance.new("TextBox")
        readerBox.Name = "Box"
        readerBox.Size = UDim2.new(1, -16, 1, -100)
        readerBox.Position = UDim2.new(0, 8, 0, 42)
        readerBox.BackgroundColor3 = Color3.fromRGB(6, 9, 14)
        readerBox.BorderSizePixel = 0
        readerBox.Font = Enum.Font.Code
        readerBox.TextSize = 13
        readerBox.TextColor3 = Color3.fromRGB(168, 214, 250)
        readerBox.TextXAlignment = Enum.TextXAlignment.Left
        readerBox.TextYAlignment = Enum.TextYAlignment.Top
        readerBox.TextWrapped = true
        readerBox.MultiLine = true
        readerBox.ClearTextOnFocus = false
        readerBox.TextEditable = true
        readerBox.Text = ""
        readerBox.ZIndex = 51
        readerBox.Parent = reader
        local tc = Instance.new("UICorner") tc.CornerRadius = UDim.new(0, 6) tc.Parent = readerBox
        local tp = Instance.new("UIPadding")
        tp.PaddingLeft = UDim.new(0, 6)
        tp.PaddingTop = UDim.new(0, 6)
        tp.Parent = readerBox

        local foot = Instance.new("Frame")
        foot.Size = UDim2.new(1, -16, 0, 40)
        foot.Position = UDim2.new(0, 8, 1, -48)
        foot.BackgroundTransparency = 1
        foot.ZIndex = 51
        foot.Parent = reader

        local function footBtn(label, x, w, color, cb)
            local b = Instance.new("TextButton")
            b.Size = UDim2.new(0, w, 1, 0)
            b.Position = UDim2.new(0, x, 0, 0)
            b.BackgroundColor3 = color
            b.BorderSizePixel = 0
            b.Font = Enum.Font.GothamBold
            b.TextSize = 12
            b.TextColor3 = Color3.fromRGB(240, 248, 255)
            b.Text = label
            b.ZIndex = 52
            b.Parent = foot
            local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 6) c.Parent = b
            b.MouseButton1Click:Connect(cb)
            return b
        end

        footBtn("<<", 0, 40, Color3.fromRGB(45, 55, 70), function()
            readerIdx = readerIdx - 1
            renderPage()
        end)

        footBtn("SELANG", 46, 56, Color3.fromRGB(45, 55, 70), function()
            -- blok semua supaya bisa di-copy manual via menu sistem
            readerBox:CaptureFocus()
            readerBox.CursorPosition = 1
            readerBox.SelectionStart = 0
            notify("Tekan lama teks → Select All → Copy")
        end)

        footBtn("SAVE", 108, 56, Color3.fromRGB(22, 101, 52), function()
            local joined = table.concat(readerLines, "\n")
            if writefile then
                local ok = pcall(writefile, "ad_dump.txt", joined)
                notify(ok and "Tersimpan: ad_dump.txt" or "writefile gagal")
            else
                notify("Executor tidak punya writefile")
            end
        end)

        footBtn("COPY", 170, 56, Color3.fromRGB(37, 99, 235), function()
            local joined = table.concat(readerLines, "\n")
            if tryClipboard(joined) then
                notify("Tersalin (" .. #joined .. " char)")
            else
                notify("Clipboard tidak tersedia — pakai SAVE")
            end
        end)

        footBtn("UPLOAD", 232, 62, Color3.fromRGB(147, 51, 234), function()
            local joined = table.concat(readerLines, "\n")
            notify("Upload...")
            task.spawn(function()
                local url, err = uploadText(joined)
                if url then
                    reader.PageLbl.Text = "URL: " .. url
                    if tryClipboard(url) then
                        notify("URL tersalin: " .. url)
                    else
                        notify("URL: " .. url)
                    end
                else
                    notify("Upload gagal: " .. tostring(err))
                end
            end)
        end)

        footBtn(">>", 300, 40, Color3.fromRGB(56, 189, 248), function()
            readerIdx = readerIdx + 1
            renderPage()
        end)
    end

    readerIdx = 1
    renderPage()
    reader.Visible = true
end

getgenv().AD_ShowConsole = showConsole

--------------------------------------------------------------- RESPONSIVE (mobile)

local function fitScreen()
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local vp = cam.ViewportSize
    local w = math.min(470, vp.X - 24)
    local h = math.min(350, vp.Y - 24)
    win.Size = UDim2.new(0, w, 0, h)
    win.Position = UDim2.new(0.5, -w / 2, 0.5, -h / 2)
    tabBar.Size = UDim2.new(0, math.floor(w * 0.30), 1, -38)
    content.Size = UDim2.new(1, -math.floor(w * 0.30), 1, -38)
    content.Position = UDim2.new(0, math.floor(w * 0.30), 0, 38)
    if reader then
        local rw = math.min(470, vp.X - 16)
        local rh = math.min(400, vp.Y - 16)
        reader.Size = UDim2.new(0, rw, 0, rh)
        reader.Position = UDim2.new(0.5, -rw / 2, 0.5, -rh / 2)
    end
end

fitScreen()
do
    local cam = Workspace.CurrentCamera
    if cam then
        track(cam:GetPropertyChangedSignal("ViewportSize"):Connect(fitScreen))
    end
end

closeBtn.MouseButton1Click:Connect(function() gui.Enabled = not gui.Enabled end)

track(UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.RightShift then gui.Enabled = not gui.Enabled end
end))

--------------------------------------------------------------- BUILD

local pFarm  = makeTab("Farm")
local pEvent = makeTab("Autumn")
local pMain  = makeTab("Main")
local pVis   = makeTab("Visual")
local pMisc  = makeTab("Misc")
selectTab(1)

for i, e in ipairs(tabs) do
    e.btn.MouseButton1Click:Connect(function() selectTab(i) end)
end

-- FARM
section(pFarm, "Core")
toggle(pFarm, "Auto Roll", false, function(on)
    setLoop("Auto Roll", Cfg.RollInterval, function()
        local n = pressPattern(Cfg.Roll)
        if n == 0 then firePrompts(Cfg.Roll) end
    end)
end)
toggle(pFarm, "Auto Sell", false, function(on)
    setLoop("Auto Sell", Cfg.RollInterval, function()
        pressPattern(Cfg.Sell)
    end)
end)
toggle(pFarm, "Auto Rebirth", false, function(on)
    setLoop("Auto Rebirth", Cfg.RebirthInterval, function()
        pressPattern(Cfg.Rebirth)
    end)
end)
toggle(pFarm, "Auto Upgrade", false, function(on)
    setLoop("Auto Upgrade", Cfg.UpgradeInterval, function()
        pressPattern(Cfg.Upgrade)
    end)
end)

-- AUTUMN
section(pEvent, "Autumn Event")
toggle(pEvent, "Auto Collect Button", false, function(on)
    setLoop("Auto Collect", Cfg.CollectInterval, function()
        pressPattern(Cfg.Collect)
    end)
end)
toggle(pEvent, "Auto ProximityPrompt", false, function(on)
    setLoop("Auto Prompt", Cfg.CollectInterval, function()
        firePrompts(Cfg.PromptCollect)
    end)
end)
toggle(pEvent, "Auto ClickDetector", false, function(on)
    setLoop("Auto Click", Cfg.CollectInterval, function()
        fireClickDetectors(Cfg.PromptCollect)
    end)
end)
button(pEvent, "Scan Sekarang (isi console)", function()
    local n1 = firePrompts(Cfg.PromptCollect)
    local n2 = fireClickDetectors(Cfg.PromptCollect)
    local n3 = pressPattern(Cfg.Collect)
    log("prompt:", n1, "clickdetector:", n2, "button:", n3)
    notify("Prompt " .. n1 .. " / CD " .. n2 .. " / Btn " .. n3)
end)

toggle(pEvent, "Click Teleport", false, function(on) setClickTP(on) end)

-- MAIN
section(pMain, "Movement")
slider(pMain, "Walk Speed", 16, 300, 16, function() applySpeed() end)
slider(pMain, "Jump Power", 50, 500, 50, function(v)
    local _, hum = getChar()
    if hum then hum.UseJumpPower = true hum.JumpPower = v end
end)
toggle(pMain, "Fly", false, function(on) setFly(on) end)
slider(pMain, "Fly Speed", 10, 400, 60, function() end)
slider(pMain, "Gravity", 0, 196, 196, function(v) Workspace.Gravity = v end)

track(LP.CharacterAdded:Connect(function()
    task.wait(1)
    applySpeed()
    if Flags["Fly"] then setFly(true) end
end))

track(RunService.Heartbeat:Connect(function()
    if Flags["Walk Speed"] then
        local _, hum = getChar()
        if hum and math.abs(hum.WalkSpeed - Flags["Walk Speed"]) > 0.5 then
            hum.WalkSpeed = Flags["Walk Speed"]
        end
    end
end))

-- VISUAL
section(pVis, "Players")
toggle(pVis, "Player ESP", false, function(on) setESP(on) end)
section(pVis, "World")
toggle(pVis, "Fullbright", false, function(on)
    if on then
        Lighting.Ambient = Color3.fromRGB(180, 180, 180)
        Lighting.OutdoorAmbient = Color3.fromRGB(180, 180, 180)
        Lighting.Brightness = 3
        Lighting.GlobalShadows = false
    else
        Lighting.Ambient = Color3.fromRGB(70, 70, 70)
        Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
        Lighting.Brightness = 2
        Lighting.GlobalShadows = true
    end
end)
toggle(pVis, "No Fog", false, function(on)
    if on then
        Lighting.FogEnd = 1e5
        Lighting.FogStart = 1e5
    else
        Lighting.FogEnd = 1000
        Lighting.FogStart = 0
    end
end)

-- MISC
section(pMisc, "Diagnostics")
button(pMisc, "DUMP (panel — no F9)", function()
    dumpAll(true)
    notify("Dump dibuka")
end)
button(pMisc, "DUMP + UPLOAD (dapat URL)", function()
    dumpAll(false)
    notify("Upload...")
    task.spawn(function()
        local url, err = uploadText(getgenv().AD_DumpText or "")
        if url then
            getgenv().AD_LastDumpURL = url
            notify("URL: " .. url)
            tryClipboard(url)
        else
            notify("Upload gagal: " .. tostring(err))
        end
    end)
end)
section(pMisc, "Network")
button(pMisc, "Server Hop", function()
    serverHop()
end)
button(pMisc, "Rejoin", function()
    TeleportService:Teleport(game.PlaceId, LP)
end)
section(pMisc, "Session")
button(pMisc, "Unload Hub", function()
    setESP(false) setFly(false) setClickTP(false)
    for _, c in ipairs(Conns) do pcall(function() c:Disconnect() end) end
    gui:Destroy()
    getgenv().ADHub = nil
end)

notify("AnimeDice Hub loaded — RightShift toggle")

if not firesignal then
    notify("WARNING: firesignal tidak ada. Pakai executor lain.")
end
