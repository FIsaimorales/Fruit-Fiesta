--!strict
-- Coin-purchased upgrades. Every price and cap is validated here; the client
-- only ever sends "I want to buy X".
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local DataManager = require(script.Parent.DataManager)

export type PlayerData = GameConfig.PlayerData

local UpgradeService = {}

-- Fired as (player, upgradeId, newValue) for world-side signage to refresh.
UpgradeService.Purchased = Instance.new("BindableEvent")

export type PurchaseResult = {
	ok: boolean,
	reason: string?,
	newValue: number?,
	nextCost: number?,
}

-- Ore Luck: +1x per purchase, cost grows geometrically. Higher luck bends the
-- rarity curve in GameConfig.getRarityWeights toward rarer plants.
function UpgradeService.buyLuck(player: Player): PurchaseResult
	local data = DataManager.get(player)
	if not data then
		return { ok = false, reason = "no_data" }
	end

	local current = data.oreLuck or GameConfig.LUCK_START
	if current >= GameConfig.LUCK_MAX then
		return { ok = false, reason = "maxed", newValue = current }
	end

	local cost = GameConfig.getLuckCost(current)
	if data.coins < cost then
		return { ok = false, reason = "insufficient_coins", newValue = current, nextCost = cost }
	end

	data.coins -= cost
	data.oreLuck = current + GameConfig.LUCK_STEP

	UpgradeService.Purchased:Fire(player, "oreLuck", data.oreLuck)
	return {
		ok = true,
		newValue = data.oreLuck,
		nextCost = GameConfig.getLuckCost(data.oreLuck),
	}
end

-- Rolling Pedestals: each purchase adds one independently-recharging pedestal
-- to the player's plot, up to GameConfig.PEDESTAL_MAX.
function UpgradeService.buyPedestal(player: Player): PurchaseResult
	local data = DataManager.get(player)
	if not data then
		return { ok = false, reason = "no_data" }
	end

	local current = data.pedestals or GameConfig.PEDESTAL_START
	if current >= GameConfig.PEDESTAL_MAX then
		return { ok = false, reason = "maxed", newValue = current }
	end

	local cost = GameConfig.getPedestalCost(current)
	if data.coins < cost then
		return { ok = false, reason = "insufficient_coins", newValue = current, nextCost = cost }
	end

	data.coins -= cost
	data.pedestals = current + 1

	UpgradeService.Purchased:Fire(player, "pedestals", data.pedestals)
	return {
		ok = true,
		newValue = data.pedestals,
		nextCost = GameConfig.getPedestalCost(data.pedestals),
	}
end

-- Dispatch used by the BuyUpgrade remote.
function UpgradeService.buy(player: Player, upgradeId: any): PurchaseResult
	if upgradeId == "oreLuck" then
		return UpgradeService.buyLuck(player)
	elseif upgradeId == "pedestals" then
		return UpgradeService.buyPedestal(player)
	end
	return { ok = false, reason = "unknown_upgrade" }
end

return UpgradeService
