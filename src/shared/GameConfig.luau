--!strict
local GameConfig = {}

export type Rarity = {
	name: string,
	id: number,
	baseValue: number,
}

export type Species = {
	name: string,
	minRarity: number,
	multiplier: number,
	fixedRarity: number?,
}

export type Animal = {
	animalSpecies: string,
	rarityId: number,
}

export type PlayerData = {
	money: number,
	animals: { Animal },
	farm: { Animal | boolean },
	rebirths: number,
	oreLuck: number,
	pedestals: number,
}

-- Rarities ordered from lowest to highest
-- income/s per animal = baseValue * species.multiplier
GameConfig.RARITIES = {
	{ name = "Común",        id = 1, baseValue = 10 },
	{ name = "Poco común",   id = 2, baseValue = 18 },
	{ name = "Raro",         id = 3, baseValue = 26 },
	{ name = "Épico",        id = 4, baseValue = 34 },
	{ name = "Legendario",   id = 5, baseValue = 42 },
	{ name = "Mítico",       id = 6, baseValue = 50 },
} :: { Rarity }

-- minRarity: lowest rarity this species can roll
-- fixedRarity: if set, species is always this rarity (ignores egg roll)
GameConfig.SPECIES = {
	{ name = "Manzana",          minRarity = 1, multiplier = 1.0 },
	{ name = "Banana",           minRarity = 1, multiplier = 1.0 },
	{ name = "Naranja",          minRarity = 1, multiplier = 1.0 },
	{ name = "Kiwi",             minRarity = 2, multiplier = 1.5 },
	{ name = "Piña",             minRarity = 2, multiplier = 1.5 },
	{ name = "Mango",            minRarity = 3, multiplier = 2.0 },
	{ name = "Maracuyá",         minRarity = 3, multiplier = 2.0 },
	{ name = "Dragon Fruit",     minRarity = 4, multiplier = 2.5 },
	{ name = "Durián",           minRarity = 4, multiplier = 2.5 },
	{ name = "Fruta Dorada",     minRarity = 5, multiplier = 3.0 },
	{ name = "Fruta de Cristal", minRarity = 5, multiplier = 3.0 },
	{ name = "Fruta Cósmica",    minRarity = 6, multiplier = 4.0, fixedRarity = 6 },
} :: { Species }

-- ── Farm capacity ─────────────────────────────────────────────────────────────
-- Pots start at FARM_BASE_SIZE and unlock in jumps every REBIRTHS_PER_UNLOCK
-- rebirths (rebirth 5 → 12, 10 → 14, 15 → 16, 20 → 18, 25 → 20, capped).
GameConfig.FARM_BASE_SIZE = 10
GameConfig.FARM_MAX_SIZE = 20
GameConfig.POTS_PER_UNLOCK = 2
GameConfig.REBIRTHS_PER_UNLOCK = 5

-- Absolute slot count every farm array / UI grid is allocated for.
GameConfig.FARM_SIZE = GameConfig.FARM_MAX_SIZE

-- Starting economy parameters (prevents new player deadlock)
GameConfig.STARTING_MONEY = 150
GameConfig.STARTING_ANIMAL = { animalSpecies = "Manzana", rarityId = 1 }

-- Egg gacha settings
GameConfig.EGG_COST = 100
-- Weights per rarity id (1=Común → 6=Mítico). Sum = 100 at 1x luck.
GameConfig.EGG_WEIGHTS = { 50, 25, 13, 7, 4, 1 }

-- ── Roll pedestal ─────────────────────────────────────────────────────────────
-- Rolling is free but each pedestal recharges independently, so owning more
-- pedestals is what raises your roll throughput.
GameConfig.ROLL_COOLDOWN = 8
-- Seconds the client-side slot-machine animation runs before revealing.
-- The server has already decided the result; this is presentation only.
GameConfig.ROLL_ANIM_DURATION = 2.6

-- ── Upgrades ──────────────────────────────────────────────────────────────────
GameConfig.LUCK_START = 1
GameConfig.LUCK_STEP = 1
GameConfig.LUCK_MAX = 25
GameConfig.LUCK_COST_BASE = 500
GameConfig.LUCK_COST_GROWTH = 1.6

GameConfig.PEDESTAL_START = 2
GameConfig.PEDESTAL_MAX = 5
GameConfig.PEDESTAL_COST_BASE = 2500
GameConfig.PEDESTAL_COST_GROWTH = 3

-- Controls how hard luck bends the rarity curve. Rarity i gets its weight
-- multiplied by luck^((i-1) * exponent), so common is untouched and higher
-- rarities scale progressively harder.
GameConfig.LUCK_RARITY_EXPONENT = 0.35

-- How often the server ticks passive income (seconds)
GameConfig.INCOME_TICK_RATE = 1

-- DataStore key prefix
GameConfig.DATASTORE_NAME = "GranjaFantasticaV1"

-- Returns the income per second for a given animalSpecies + rarityId
function GameConfig.getIncome(animalSpecies: string, rarityId: number): number
	local rarity = GameConfig.RARITIES[rarityId]
	if not rarity then return 0 end

	for _, species in GameConfig.SPECIES do
		if species.name == animalSpecies then
			return math.round(rarity.baseValue * species.multiplier)
		end
	end
	return 0
end

-- Returns species data by name, or nil
function GameConfig.getSpecies(name: string): Species?
	for _, s in GameConfig.SPECIES do
		if s.name == name then return s end
	end
	return nil
end

-- Returns rarity data by id, or nil
function GameConfig.getRarity(id: number): Rarity?
	return GameConfig.RARITIES[id]
end

-- Returns all species compatible with a given rarity roll
function GameConfig.getSpeciesForRarity(rarityId: number): { Species }
	local valid: { Species } = {}
	for _, s in GameConfig.SPECIES do
		if s.fixedRarity then
			if s.fixedRarity == rarityId then
				table.insert(valid, s)
			end
		elseif s.minRarity <= rarityId then
			table.insert(valid, s)
		end
	end
	-- Fallback if empty
	if #valid == 0 then
		for _, s in GameConfig.SPECIES do
			if s.minRarity <= rarityId then
				table.insert(valid, s)
			end
		end
	end
	return valid
end

-- ── Farm capacity ─────────────────────────────────────────────────────────────

-- How many pots this player has unlocked at their current rebirth count.
function GameConfig.getMaxPots(rebirths: number): number
	local unlocks = math.floor(math.max(rebirths, 0) / GameConfig.REBIRTHS_PER_UNLOCK)
	local pots = GameConfig.FARM_BASE_SIZE + unlocks * GameConfig.POTS_PER_UNLOCK
	return math.min(pots, GameConfig.FARM_MAX_SIZE)
end

-- Rebirth count at which the next pot unlock lands, or nil once capped.
function GameConfig.getNextPotUnlock(rebirths: number): number?
	if GameConfig.getMaxPots(rebirths) >= GameConfig.FARM_MAX_SIZE then
		return nil
	end
	local unlocks = math.floor(math.max(rebirths, 0) / GameConfig.REBIRTHS_PER_UNLOCK)
	return (unlocks + 1) * GameConfig.REBIRTHS_PER_UNLOCK
end

-- ── Luck & rarity odds ────────────────────────────────────────────────────────

-- Rarity weights bent by the player's Ore Luck multiplier. At 1x luck these are
-- exactly EGG_WEIGHTS; higher luck scales rarer entries progressively harder.
function GameConfig.getRarityWeights(luck: number): { number }
	local l = math.max(luck or 1, 1)
	local weights: { number } = {}
	for i, base in GameConfig.EGG_WEIGHTS do
		weights[i] = base * (l ^ ((i - 1) * GameConfig.LUCK_RARITY_EXPONENT))
	end
	return weights
end

-- Same curve expressed as percentages (sums to 100) for display in the UI.
function GameConfig.getRarityOdds(luck: number): { number }
	local weights = GameConfig.getRarityWeights(luck)
	local total = 0
	for _, w in weights do
		total += w
	end
	local odds: { number } = {}
	for i, w in weights do
		odds[i] = (w / total) * 100
	end
	return odds
end

-- ── Upgrade costs ─────────────────────────────────────────────────────────────

-- Cost of the next Ore Luck level given the player's current multiplier.
function GameConfig.getLuckCost(currentLuck: number): number
	local purchases = math.max((currentLuck or GameConfig.LUCK_START) - GameConfig.LUCK_START, 0)
	purchases = math.floor(purchases / GameConfig.LUCK_STEP)
	return math.floor(GameConfig.LUCK_COST_BASE * (GameConfig.LUCK_COST_GROWTH ^ purchases))
end

-- Cost of the next Rolling Pedestal given how many the player already owns.
function GameConfig.getPedestalCost(currentPedestals: number): number
	local purchases = math.max((currentPedestals or GameConfig.PEDESTAL_START) - GameConfig.PEDESTAL_START, 0)
	return math.floor(GameConfig.PEDESTAL_COST_BASE * (GameConfig.PEDESTAL_COST_GROWTH ^ purchases))
end

return GameConfig
