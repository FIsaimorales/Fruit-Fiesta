--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes", 10) :: Folder

if not remotes then
	error("[Client] Remotes folder not found in ReplicatedStorage")
end

local HUD = require(script.HUD)

-- ── Remote references ──────────────────────────────────────────────────────────

local updatePlayerData = remotes:WaitForChild("UpdatePlayerData") :: RemoteEvent
local updateCoins      = remotes:WaitForChild("UpdateCoins")      :: RemoteEvent

-- ── Init HUD ──────────────────────────────────────────────────────────────────

local hud = HUD.create(player)

-- ── Receive server state ───────────────────────────────────────────────────────

-- Full player state update (on join or data changes)
updatePlayerData.OnClientEvent:Connect(function(data)
	hud.updateFull(data)
end)

-- Lightweight coin/income update (1-second tick)
updateCoins.OnClientEvent:Connect(function(coins: number, income: number)
	hud.updateCoins(coins, income)
end)

print("[Client] FruitGarden HUD initialized.")
