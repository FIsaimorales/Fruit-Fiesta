local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes", 10)

if not remotes then
	error("[Client] Remotes folder not found in ReplicatedStorage")
end

local HUD = require(script.HUD)

-- Current player state (updated by server push)
local playerData = {
	coins = 0,
	plants = {},
	plot = {},
	rebirths = 0,
	incomePerSecond = 0,
}

-- ── Remote references ─────────────────────────────────────────────────────────

local updatePlayerData: RemoteEvent = remotes:WaitForChild("UpdatePlayerData")
local openEgg: RemoteEvent = remotes:WaitForChild("OpenEgg")
local placePlant: RemoteEvent = remotes:WaitForChild("PlacePlant")
local removePlant: RemoteEvent = remotes:WaitForChild("RemovePlant")

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

updatePlayerData.OnClientEvent:Connect(function(data)
	playerData = data
	hud.update(data)
end)

print("[Client] FruitGarden initialized")
