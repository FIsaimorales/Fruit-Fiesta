--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes", 10) :: Folder

if not remotes then
	error("[Client] Remotes folder not found in ReplicatedStorage")
end

local HUD = require(script.HUD)

-- ── Remote references ─────────────────────────────────────────────────────────

local updatePlayerData = remotes:WaitForChild("UpdatePlayerData") :: RemoteEvent
local updateCoins = remotes:WaitForChild("UpdateCoins") :: RemoteEvent
local openEgg = remotes:WaitForChild("OpenEgg") :: RemoteEvent
local placePlant = remotes:WaitForChild("PlacePlant") :: RemoteEvent
local removePlant = remotes:WaitForChild("RemovePlant") :: RemoteEvent

-- ── Init HUD ──────────────────────────────────────────────────────────────────

local hud = HUD.create(player)

-- Callbacks HUD fires when player takes actions
hud.onOpenEgg = function()
	openEgg:FireServer()
end

hud.onPlacePlant = function(inventoryIndex: number, slotIndex: number)
	placePlant:FireServer(inventoryIndex, slotIndex)
end

hud.onRemovePlant = function(slotIndex: number)
	removePlant:FireServer(slotIndex)
end

-- ── Receive server state ──────────────────────────────────────────────────────

-- Full player state update (on join, inventory changes, egg open, plot change)
updatePlayerData.OnClientEvent:Connect(function(data)
	hud.updateFull(data)
end)

-- Lightweight coin/income update (1-second tick)
updateCoins.OnClientEvent:Connect(function(coins: number, income: number)
	hud.updateCoins(coins, income)
end)

print("[Client] FruitGarden initialized with network optimizations.")
