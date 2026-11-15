--[[ Anime Dice — LOADER dengan error surfacing.
     Kenapa: executor mobile (LDP) tidak punya F9. Kalau hub error, layar cuma
     "blank hitam" dan tidak ada cara tahu baris mana yang mati.

     Loader ini:
       1. ambil source hub via game:HttpGet
       2. jalankan di dalam xpcall + traceback
       3. error -> render panel merah berisi pesan + traceback di layar
       4. sukses -> hub jalan normal

     Loader sendiri: Instance.new satu argumen, nol remote, nol firesignal. ]]

local URLS = {
    "https://raw.githubusercontent.com/und1ne/anime-dice-hub/main/anime-dice.lua",
    "https://cdn.jsdelivr.net/gh/und1ne/anime-dice-hub@main/anime-dice.lua",
}

local function S(...)
    local t = {}
    for i = 1, select("#", ...) do t[i] = tostring((select(i, ...))) end
    print("[AD-LOADER]", table.concat(t, " "))
end

local function parentFor()
    if gethui then
        local ok, h = pcall(gethui)
        if ok and h then return h end
    end
    local ok, cg = pcall(function() return game:GetService("CoreGui") end)
    if ok and cg then return cg end
    return game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
end

local function errorPanel(msg)
    local gui = Instance.new("ScreenGui")
    gui.Name = "ADLoaderError"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 1000
    gui.Parent = parentFor()

    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, -20, 0, 0)
    f.AutomaticSize = Enum.AutomaticSize.Y
    f.Position = UDim2.new(0, 10, 0, 60)
    f.BackgroundColor3 = Color3.fromRGB(40, 12, 14)
    f.BorderSizePixel = 0
    f.Parent = gui

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 8)
    c.Parent = f

    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 10)
    pad.PaddingBottom = UDim.new(0, 10)
    pad.PaddingLeft = UDim.new(0, 12)
    pad.PaddingRight = UDim.new(0, 12)
    pad.Parent = f

    local lay = Instance.new("UIListLayout")
    lay.Padding = UDim.new(0, 8)
    lay.SortOrder = Enum.SortOrder.LayoutOrder
    lay.Parent = f

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 20)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.TextColor3 = Color3.fromRGB(248, 113, 113)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text = "AD HUB - ERROR (kirim teks ini ke 4080)"
    title.LayoutOrder = 1
    title.Parent = f

    local body = Instance.new("TextLabel")
    body.Size = UDim2.new(1, 0, 0, 0)
    body.AutomaticSize = Enum.AutomaticSize.Y
    body.BackgroundTransparency = 1
    body.Font = Enum.Font.Code
    body.TextSize = 11
    body.TextWrapped = true
    body.TextColor3 = Color3.fromRGB(254, 226, 226)
    body.TextXAlignment = Enum.TextXAlignment.Left
    body.TextYAlignment = Enum.TextYAlignment.Top
    body.Text = msg
    body.LayoutOrder = 2
    body.Parent = f

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 28)
    btn.BackgroundColor3 = Color3.fromRGB(70, 20, 22)
    btn.BorderSizePixel = 0
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 12
    btn.TextColor3 = Color3.fromRGB(254, 226, 226)
    btn.Text = "TUTUP PANEL"
    btn.LayoutOrder = 3
    btn.Parent = f

    local bc = Instance.new("UICorner")
    bc.CornerRadius = UDim.new(0, 6)
    bc.Parent = btn

    btn.MouseButton1Click:Connect(function()
        gui.Enabled = false
    end)

    if setclipboard then
        pcall(setclipboard, msg)
    elseif writefile then
        pcall(writefile, "ad_error.txt", msg)
    end

    getgenv().AD_LastError = msg
    S("ERROR:", msg)
end

local function fetch(u)
    if game.HttpGet then
        local ok, r = pcall(game.HttpGet, game, u)
        if ok and type(r) == "string" and #r > 0 then return r end
    end
    if syn and syn.request then
        local ok, r = pcall(syn.request, { Url = u, Method = "GET" })
        if ok and r and r.Body then return r.Body end
    end
    if http and http.request then
        local ok, r = pcall(http.request, { Url = u, Method = "GET" })
        if ok and r and r.Body then return r.Body end
    end
    if type(request) == "function" then
        local ok, r = pcall(request, { Url = u, Method = "GET" })
        if ok and r and r.Body then return r.Body end
    end
    return nil
end

S("fetch hub...")
local src
for _, u in ipairs(URLS) do
    src = fetch(u)
    if src and #src > 1000 then
        S("source:", u, #src, "bytes")
        break
    end
    src = nil
end

if not src then
    errorPanel("gagal ambil hub dari GitHub.\n\n" .. URLS[1] .. "\n\nCek koneksi / URL.")
    return
end

local chunk, compileErr = loadstring(src, "anime-dice.lua")
if not chunk then
    errorPanel("gagal compile hub.\n\n" .. tostring(compileErr))
    return
end

local traceback = function(e)
    local tb = (debug and debug.traceback) and debug.traceback("", 2) or ""
    return tostring(e) .. "\n\n" .. tostring(tb)
end

local ok, runErr = xpcall(chunk, traceback)
if not ok then
    errorPanel(tostring(runErr))
    return
end

S("hub loaded OK")
