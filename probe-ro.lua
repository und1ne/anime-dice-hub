--[[ Anime Dice — PROBE READ-ONLY
     TIDAK mengirim apa pun ke server. Nol InvokeServer, nol FireServer, nol firesignal.
     Cuma baca pohon ReplicatedStorage.Network, GUI, dan Workspace.
     Aman: tidak ada paket keluar, anti-cheat tidak punya apa pun untuk dideteksi. ]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")

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
    P("======== " .. title .. " ========")
end

--------------------------------------------------------------- 0

sep("0. ENV")
P("PlaceId:", game.PlaceId)
P("Executor:", (identifyexecutor and identifyexecutor()) or "?")
P("clipboard:", tostring(setclipboard ~= nil), "writefile:", tostring(writefile ~= nil))

--------------------------------------------------------------- 1

sep("1. NETWORK TREE (read only)")

local Net = ReplicatedStorage:FindFirstChild("Network")
if not Net then
    P("FATAL: Network folder tidak ada")
    print(table.concat(out, "\n"))
    return
end

local function describe(inst, depth)
    local pad = string.rep("  ", depth)
    local hints = {}
    for _, ch in ipairs(inst:GetChildren()) do
        if ch:IsA("StringValue") or ch:IsA("IntValue")
           or ch:IsA("NumberValue") or ch:IsA("BoolValue") then
            hints[#hints + 1] = ch.Name .. "=" .. tostring(ch.Value)
        end
    end
    P(pad .. inst.ClassName .. "  " .. inst.Name
        .. ((#hints > 0) and ("   {" .. table.concat(hints, ", ") .. "}") or ""))
end

local services = {}
for _, c in ipairs(Net:GetChildren()) do services[#services + 1] = c.Name end
table.sort(services)
P("Services (" .. #services .. "): " .. table.concat(services, ", "))

--------------------------------------------------------------- 2

sep("2. AUTUMN / LEAF / APPLE / QUEST DETAIL")

local interesting = {
    "AutumnService", "AutumnQuestService", "LeafDiceService",
    "AppleService", "AppleShopService", "AppleTreeService", "QuestService",
}

for _, name in ipairs(interesting) do
    local svc = Net:FindFirstChild(name)
    if not svc then
        P("--", name, "(TIDAK ADA)")
    else
        P("--", name .. "  [" .. svc.ClassName .. "]")
        for _, ch in ipairs(svc:GetDescendants()) do
            if ch ~= svc then describe(ch, 1) end
        end
        -- attributes kadang nyimpen schema
        local attrs = svc:GetAttributes()
        if next(attrs) then
            for k, v in pairs(attrs) do P("   attr:", k, "=", tostring(v)) end
        end
    end
end

--------------------------------------------------------------- 3

sep("3. ALL REMOTES BY SERVICE (nama saja)")

for _, svcName in ipairs(services) do
    local svc = Net:FindFirstChild(svcName)
    local remotes = {}
    for _, ch in ipairs(svc:GetDescendants()) do
        if ch:IsA("RemoteEvent") or ch:IsA("RemoteFunction") then
            remotes[#remotes + 1] = ch.ClassName:gsub("Remote", "R") .. ":" .. ch.Name
        end
    end
    if #remotes > 0 then
        table.sort(remotes)
        P(svcName .. " -> " .. table.concat(remotes, ", "))
    end
end

--------------------------------------------------------------- 4

sep("4. GUI AUTUMN STATE (no firesignal)")

local pg = LP:FindFirstChild("PlayerGui")
if pg then
    local keys = { "AutumnQuests", "LeafDice", "TurkeyTower", "AppleShop", "Quests", "AppleBoard" }
    for _, key in ipairs(keys) do
        local found = {}
        for _, d in ipairs(pg:GetDescendants()) do
            if d:IsA("GuiObject") and string.find(d:GetFullName(), key, 1, true) then
                found[#found + 1] = d.ClassName
                    .. " vis=" .. tostring(d.Visible)
                    .. " " .. d:GetFullName():gsub("Players%.[^%.]+%.PlayerGui%.", "")
            end
        end
        table.sort(found)
        P("--", key, "(" .. #found .. ")")
        for i = 1, math.min(#found, 20) do P("  " .. found[i]) end
    end
else
    P("PlayerGui tidak ada")
end

--------------------------------------------------------------- 5

sep("5. MAP PRESENCE")

local tops = {}
for _, c in ipairs(Workspace:GetChildren()) do tops[#tops + 1] = c.Name end
table.sort(tops)
P("Workspace: " .. table.concat(tops, ", "))

local hits = 0
local samples = {}
for _, d in ipairs(Workspace:GetDescendants()) do
    local n = string.lower(d.Name)
    if string.find(n, "autumn") or string.find(n, "leaf")
       or string.find(n, "harvest") or string.find(n, "apple") then
        hits = hits + 1
        if #samples < 30 then
            samples[#samples + 1] = d.ClassName .. " " .. d:GetFullName()
        end
    end
end
P("objek autumn/leaf/harvest/apple: " .. hits)
for _, s in ipairs(samples) do P("  " .. s) end

--------------------------------------------------------------- 6

sep("6. PLAYER DATA SHAPE (baca saja)")

for _, name in ipairs({ "Data", "PlayerData", "Save", "Stats", "Profile" }) do
    local v = LP:FindFirstChild(name) or ReplicatedStorage:FindFirstChild(name)
    if v then
        P("found:", v:GetFullName(), v.ClassName)
        for _, ch in ipairs(v:GetChildren()) do
            P("  ", ch.ClassName, ch.Name, tostring(ch.Value or ""):sub(1, 80))
        end
    end
end

--------------------------------------------------------------- DONE

sep("DONE — " .. #out .. " baris. TIDAK ADA paket dikirim ke server.")

local joined = table.concat(out, "\n")
getgenv().AD_ProbeRO = joined

local function req(opts)
    if syn and syn.request then return syn.request(opts) end
    if http and http.request then return http.request(opts) end
    if type(request) == "function" then return request(opts) end
    return nil
end

local r = req
if r then
    local ok, res = pcall(r, {
        Url = "https://paste.rs/",
        Method = "POST",
        Headers = { ["Content-Type"] = "text/plain" },
        Body = joined,
    })
    if ok and res and (res.StatusCode == 200 or res.StatusCode == 201) then
        local url = tostring(res.Body):gsub("%s+$", "")
        getgenv().AD_ProbeROURL = url
        print("[PROBE-RO URL] " .. url)
    else
        print("[PROBE-RO] upload gagal")
    end
else
    print("[PROBE-RO] tidak ada http client. copy dari console atau print(getgenv().AD_ProbeRO)")
end
