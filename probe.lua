--[[ Anime Dice — PROBE
     Tujuan: cari TAHU signature argumen remote apa adanya, bukan nebak.
     Jalankan di executor, kirim seluruh output console. ]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")
local HttpService       = game:GetService("HttpService")

local LP = Players.LocalPlayer

local out = {}
local function P(...)
    local t = {}
    for i = 1, select("#", ...) do t[i] = tostring((select(i, ...))) end
    local line = table.concat(t, " ")
    out[#out + 1] = line
    print(line)
end

local function sep(title)
    P("")
    P("==================== " .. title .. " ====================")
end

--------------------------------------------------------------- 0. ENV

sep("0. ENV")
P("PlaceId:", game.PlaceId)
P("JobId:", game.JobId)
P("Executor:", (identifyexecutor and identifyexecutor()) or "?")
P("clipboard:", tostring(setclipboard ~= nil),
  "writefile:", tostring(writefile ~= nil),
  "http:", tostring(setclipboard ~= nil and true or ((syn and syn.request) and true or (http and http.request) and true or (request and true) or false)))
P("getrawmetatable:", tostring(getrawmetatable ~= nil), "hookfunction:", tostring(hookfunction ~= nil))

--------------------------------------------------------------- 1. NETWORK TREE

sep("1. NETWORK TREE")
local Net = ReplicatedStorage:FindFirstChild("Network")
if not Net then
    P("FATAL: Network folder tidak ada")
    return
end

local services = {}
for _, svc in ipairs(Net:GetChildren()) do
    services[#services + 1] = svc.Name
end
table.sort(services)
P("Services (" .. #services .. "):", table.concat(services, ", "))

--------------------------------------------------------------- 2. AUTUMN SERVICE DETAIL

sep("2. AUTUMN SERVICE DETAIL")

local function describe(inst)
    local class = inst.ClassName
    local args = nil
    local hints = {}

    -- cari child bernama signature / args / types
    for _, ch in ipairs(inst:GetChildren()) do
        if ch:IsA("StringValue") or ch:IsA("ObjectValue") or ch:IsA("IntValue") then
            hints[#hints + 1] = ch.Name .. "=" .. tostring(ch.Value)
        end
    end

    P(class, inst:GetFullName(), (#hints > 0) and ("hints: " .. table.concat(hints, "|")) or "")
end

local function dumpService(name)
    local svc = Net:FindFirstChild(name)
    if not svc then
        P("  (tidak ada:", name .. ")")
        return
    end
    P("--", name)
    for _, ch in ipairs(svc:GetDescendants()) do
        if ch:IsA("RemoteEvent") or ch:IsA("RemoteFunction")
           or ch:IsA("UnreliableRemoteEvent") or ch:IsA("BindableEvent") then
            describe(ch)
        end
    end
end

dumpService("AutumnService")
dumpService("AutumnQuestService")
dumpService("LeafDiceService")
dumpService("AppleService")
dumpService("AppleShopService")
dumpService("AppleTreeService")

--------------------------------------------------------------- 3. SAFE INVOKE

sep("3. SAFE INVOKE TESTS")

local function tryInvoke(label, path, ...)
    local cur = ReplicatedStorage
    for seg in string.gmatch(path, "[^%.]+") do
        cur = cur:FindFirstChild(seg)
        if not cur then P(label, "-> MISSING", path) return end
    end
    local args = table.pack(...)
    local ok, res = pcall(function()
        return cur:InvokeServer(table.unpack(args, 1, args.n))
    end)
    if ok then
        P(label, "-> OK   type=" .. typeof(res) .. "  value=" .. tostring(res):sub(1, 300))
    else
        P(label, "-> ERR  " .. tostring(res):sub(1, 300))
    end
end

tryInvoke("AutumnQuest.Sync/noargs", "Network.AutumnQuestService.RF.Sync")
tryInvoke("AutumnQuest.Sync/true",   "Network.AutumnQuestService.RF.Sync", true)
tryInvoke("AutumnQuest.Claim/noargs", "Network.AutumnQuestService.RF.Claim")
tryInvoke("AutumnQuest.ClaimBonus/noargs", "Network.AutumnQuestService.RF.ClaimBonus")
tryInvoke("Autumn.Travel/noargs", "Network.AutumnService.RF.Travel")
tryInvoke("Apple.Sync/noargs", "Network.AppleService.RF.Sync")
tryInvoke("LeafDice.Roll/noargs", "Network.LeafDiceService.RF.Roll")

--------------------------------------------------------------- 4. FIRESERVER + LISTEN RETURN

sep("4. REMOTE EVENT RETURN TRACE")

local traced = {}
local function traceEvent(label, path, ...)
    local cur = ReplicatedStorage
    for seg in string.gmatch(path, "[^%.]+") do
        cur = cur:FindFirstChild(seg)
        if not cur then P(label, "-> MISSING", path) return end
    end
    if not cur:IsA("RemoteEvent") and not cur:IsA("UnreliableRemoteEvent") then
        P(label, "-> bukan RemoteEvent:", cur.ClassName)
        return
    end
    local got = {}
    local conn
    conn = cur.OnClientEvent:Connect(function(...)
        local a = table.pack(...)
        local parts = {}
        for i = 1, a.n do
            parts[#parts + 1] = typeof(a[i]) .. ":" .. tostring(a[i]):sub(1, 120)
        end
        got[#got + 1] = table.concat(parts, " | ")
    end)
    local args = table.pack(...)
    pcall(function() cur:FireServer(table.unpack(args, 1, args.n)) end)
    task.wait(1.2)
    if conn then conn:Disconnect() end
    if #got > 0 then
        for i, g in ipairs(got) do P(label, "reply[" .. i .. "]:", g) end
    else
        P(label, "-> no reply in 1.2s")
    end
end

traceEvent("AutumnQuestService.RE (cek child)", "Network.AutumnQuestService.RE")
traceEvent("LeafDice.RollMessage", "Network.LeafDiceService.RE.RollMessage")
traceEvent("Roll.RollMessage", "Network.RollService.RE.RollMessage")

--------------------------------------------------------------- 5. GUI AUTUMN (what is visible)

sep("5. GUI AUTUMN STATE")

local pg = LP:FindFirstChild("PlayerGui")
if pg then
    local function listUnder(substr)
        local found = {}
        for _, d in ipairs(pg:GetDescendants()) do
            if d:IsA("GuiObject") then
                local full = d:GetFullName()
                if string.find(full, substr, 1, true) then
                    found[#found + 1] = d.ClassName .. " visible=" .. tostring(d.Visible)
                        .. " " .. full:gsub("Players%.[^%.]+%.PlayerGui%.", "")
                end
            end
        end
        table.sort(found)
        P("--", substr, "(" .. #found .. ")")
        for _, f in ipairs(found) do P(f) end
    end
    listUnder("AutumnQuests")
    listUnder("LeafDice")
    listUnder("TurkeyTower")
    listUnder("AppleShop")
else
    P("PlayerGui tidak ada")
end

--------------------------------------------------------------- 6. PLAYER STATE / DATA

sep("6. PLAYER DATA")
for _, name in ipairs({ "Data", "PlayerData", "Save", "Stats" }) do
    local v = LP:FindFirstChild(name) or ReplicatedStorage:FindFirstChild(name)
    if v then
        P("found:", v:GetFullName(), v.ClassName)
        for _, ch in ipairs(v:GetChildren()) do
            P("  ", ch.ClassName, ch.Name, tostring(ch.Value or ""):sub(1, 80))
        end
    end
end

--------------------------------------------------------------- 7. AUTUMN MAP PRESENCE

sep("7. AUTUMN MAP PRESENCE")
P("Workspace children:", table.concat((function()
    local t = {}
    for _, c in ipairs(Workspace:GetChildren()) do t[#t + 1] = c.Name end
    table.sort(t)
    return t
end)(), ", "))

local autumnParts = 0
for _, d in ipairs(Workspace:GetDescendants()) do
    local n = string.lower(d.Name)
    if string.find(n, "autumn") or string.find(n, "leaf") or string.find(n, "harvest") then
        autumnParts = autumnParts + 1
        if autumnParts <= 25 then
            P("autumn obj:", d.ClassName, d:GetFullName())
        end
    end
end
P("total autumn/leaf/harvest objects:", autumnParts)

--------------------------------------------------------------- DONE

sep("DONE")
P("lines:", #out)

local joined = table.concat(out, "\n")
getgenv().AD_ProbeText = joined

-- upload
local function req(opts)
    if syn and syn.request then return syn.request(opts) end
    if http and http.request then return http.request(opts) end
    return request(opts)
end

local okUp, resUp = pcall(req, {
    Url = "https://paste.rs/",
    Method = "POST",
    Headers = { ["Content-Type"] = "text/plain" },
    Body = joined,
})
if okUp and resUp and (resUp.StatusCode == 200 or resUp.StatusCode == 201) then
    local url = tostring(resUp.Body):gsub("%s+$", "")
    getgenv().AD_ProbeURL = url
    print("[PROBE URL] " .. url)
else
    print("[PROBE] upload gagal: " .. tostring(okUp and resUp and resUp.StatusCode or resUp))
end
