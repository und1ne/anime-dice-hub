-- AnimeDice Hub loader
-- Pakai jsDelivr dulu (cache instan), fallback ke raw GitHub.

local urls = {
    "https://cdn.jsdelivr.net/gh/und1ne/anime-dice-hub@main/hub.lua",
    "https://raw.githubusercontent.com/und1ne/anime-dice-hub/main/hub.lua",
}

local lastErr
for _, url in ipairs(urls) do
    local ok, src = pcall(function()
        return game:HttpGet(url, true)
    end)
    if ok and type(src) == "string" and #src > 200 and not string.find(src, "^404") then
        local fn, err = loadstring(src)
        if fn then
            return fn()
        end
        lastErr = err
    else
        lastErr = tostring(src)
    end
end

warn("[AnimeDice Hub] load gagal: " .. tostring(lastErr))
