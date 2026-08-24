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

export type Plant = {
	speciesName: string,
	rarityId: number,
}

export type PlayerData = {
	coins: number,
	plants: { Plant },
	plot: { Plant | boolean },
	rebirths: number,
}

-- Rarities ordered from lowest to highest
-- income/s per plant = baseValue * species.multiplier
GameConfig.RARITIES: { Rarity } = {
	{ name = "Común",        id = 1, baseValue = 10 },
	{ name = "Poco común",   id = 2, baseValue = 18 },
	{ name = "Raro",         id = 3, baseValue = 26 },
	{ name = "Épico",        id = 4, baseValue = 34 },
	{ name = "Legendario",   id = 5, baseValue = 42 },
	{ name = "Mítico",       id = 6, baseValue = 50 },
}

-- minRarity: lowest rarity this species can roll
-- fixedRarity: if set, species is always this rarity (ignores egg roll)
GameConfig.SPECIES: { Species } = {
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
}

-- Number of pot slots per player plot
GameConfig.PLOT_SIZE = 10

-- Starting economy parameters (prevents new player deadlock)
GameConfig.STARTING_COINS = 150
GameConfig.STARTING_PLANT = { speciesName = "Manzana", rarityId = 1 }

-- Egg gacha settings
GameConfig.EGG_COST = 100
-- Weights per rarity id (1=Común → 6=Mítico). Sum = 100
GameConfig.EGG_WEIGHTS = { 50, 25, 13, 7, 4, 1 }

-- How often the server ticks passive income (seconds)
GameConfig.INCOME_TICK_RATE = 1

-- DataStore key prefix
GameConfig.DATASTORE_NAME = "FruitGardenV1"

-- Returns the income per second for a given speciesName + rarityId
function GameConfig.getIncome(speciesName: string, rarityId: number): number
	local rarity = GameConfig.RARITIES[rarityId]
	if not rarity then return 0 end

	for _, species in GameConfig.SPECIES do
		if species.name == speciesName then
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

return GameConfig
