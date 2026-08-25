--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes", 10) :: Folder

if not remotes then
	error("[Client] Remotes folder not found in ReplicatedStorage")
end

local HUD = require(script.HUD)
local SoundManager = require(script.SoundManager)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

export type Plant = GameConfig.Plant

-- Inicializar gestor de sonido global (conecta la música y efectos de Workspace/SoundService a los sliders)
SoundManager.init()

-- ── Remote references ─────────────────────────────────────────────────────────

local updatePlayerData = remotes:WaitForChild("UpdatePlayerData") :: RemoteEvent
local updateCoins = remotes:WaitForChild("UpdateCoins") :: RemoteEvent
local eggOpened = remotes:WaitForChild("EggOpened") :: RemoteEvent
local openEgg = remotes:WaitForChild("OpenEgg") :: RemoteEvent
local placePlant = remotes:WaitForChild("PlacePlant") :: RemoteEvent
local removePlant = remotes:WaitForChild("RemovePlant") :: RemoteEvent
local autoEquipBest = remotes:WaitForChild("AutoEquipBest") :: RemoteEvent
local rollResult = remotes:WaitForChild("RollResult") :: RemoteEvent
local requestRoll = remotes:WaitForChild("RequestRoll") :: RemoteEvent
local buyUpgrade = remotes:WaitForChild("BuyUpgrade") :: RemoteEvent

-- ── Init Modern HUD ───────────────────────────────────────────────────────────

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

hud.onAutoEquip = function()
	autoEquipBest:FireServer()
end

hud.onRoll = function(pedestalIndex: number)
	requestRoll:FireServer(pedestalIndex)
end

hud.onBuyUpgrade = function(upgradeId: string)
	buyUpgrade:FireServer(upgradeId)
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

-- Egg reveal cinematic trigger
eggOpened.OnClientEvent:Connect(function(plant: Plant)
	hud.showGachaReveal(plant)
end)

-- Roll pedestal: the server already decided the outcome, the payload just tells
-- us what it is and how long to spin the slot machine before showing it.
rollResult.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" or typeof(payload.plant) ~= "table" then
		return
	end
	hud.showRollResult(payload.plant, payload.duration or 2.5)
end)

print("[Client] Fruit Fiesta HUD, roll pedestals & upgrades initialized.")
