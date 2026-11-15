# AnimeDice Hub

Single-file Roblox hub with a discovery engine. Tidak butuh remote path hardcode —
engine memindai `PlayerGui` button, `ProximityPrompt`, dan `ClickDetector` secara live.

## Load

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/und1ne/anime-dice-hub/main/loader.lua"))()
```

Atau langsung:

```lua
loadstring(game:HttpGet("https://cdn.jsdelivr.net/gh/und1ne/anime-dice-hub@main/hub.lua"))()
```

## Fitur

- Farm: Auto Roll, Auto Sell, Auto Rebirth, Auto Upgrade
- Autumn Event: Auto Collect Button, Auto ProximityPrompt, Auto ClickDetector
- Main: Walk Speed, Jump Power, Fly, Fly Speed, Gravity
- Visual: Player ESP, Fullbright, No Fog
- Misc: DUMP remote/button, Server Hop, Rejoin, Unload

`RightShift` — toggle GUI.

## Kalibrasi

Tekan `Misc -> DUMP REMOTE / BUTTON`, buka console (F9), copy blok
`===== DUMP START =====` sampai `===== DUMP END =====`. Dari situ nama remote exact
bisa dikunci supaya engine jadi direct-fire, bukan GUI-click.

## Butuh executor dengan

`firesignal`, `fireproximityprompt`, `fireclickdetector`.
