--!strict
-- Low-poly animal builder: a simple stem with a geometric fruit on top.
--
-- Everything here is generated from primitives (Part shapes + solid colors, no
-- textures, no meshes, no external assets), which keeps the generic Roblox
-- low-poly look and means the game ships with zero asset dependencies.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

export type Animal = GameConfig.Animal

local AnimalModel = {}

export type FruitVisual = {
	color: Color3,
	shape: Enum.PartType,
	size: Vector3,
	-- Tilts the fruit for silhouettes that read better off-axis (banana, cósmica).
	tilt: number?,
	neon: boolean?,
}

-- Per-species fruit look. Ball parts with a non-uniform Size render as
-- ellipsoids, which is enough to distinguish every fruit at a glance.
local FRUIT_VISUALS: { [string]: FruitVisual } = {
	["Manzana"] = { color = Color3.fromRGB(214, 48, 49), shape = Enum.PartType.Ball, size = Vector3.new(1.5, 1.4, 1.5) },
	["Banana"] = { color = Color3.fromRGB(253, 203, 60), shape = Enum.PartType.Ball, size = Vector3.new(0.7, 1.9, 0.7), tilt = 28 },
	["Naranja"] = { color = Color3.fromRGB(240, 138, 26), shape = Enum.PartType.Ball, size = Vector3.new(1.5, 1.5, 1.5) },
	["Kiwi"] = { color = Color3.fromRGB(122, 85, 46), shape = Enum.PartType.Ball, size = Vector3.new(1.2, 1.5, 1.2) },
	["Piña"] = { color = Color3.fromRGB(226, 178, 42), shape = Enum.PartType.Ball, size = Vector3.new(1.2, 2.1, 1.2) },
	["Mango"] = { color = Color3.fromRGB(232, 126, 40), shape = Enum.PartType.Ball, size = Vector3.new(1.3, 1.7, 1.3), tilt = 15 },
	["Maracuyá"] = { color = Color3.fromRGB(140, 92, 60), shape = Enum.PartType.Ball, size = Vector3.new(1.4, 1.4, 1.4) },
	["Dragon Fruit"] = { color = Color3.fromRGB(226, 61, 122), shape = Enum.PartType.Block, size = Vector3.new(1.3, 1.8, 1.3), tilt = 45 },
	["Durián"] = { color = Color3.fromRGB(150, 158, 61), shape = Enum.PartType.Block, size = Vector3.new(1.5, 1.6, 1.5), tilt = 30 },
	["Fruta Dorada"] = { color = Color3.fromRGB(255, 210, 50), shape = Enum.PartType.Ball, size = Vector3.new(1.6, 1.6, 1.6), neon = true },
	["Fruta de Cristal"] = { color = Color3.fromRGB(140, 230, 255), shape = Enum.PartType.Block, size = Vector3.new(1.3, 1.9, 1.3), tilt = 45, neon = true },
	["Fruta Cósmica"] = { color = Color3.fromRGB(158, 80, 255), shape = Enum.PartType.Block, size = Vector3.new(1.5, 1.5, 1.5), tilt = 45, neon = true },
}

local DEFAULT_VISUAL: FruitVisual = {
	color = Color3.fromRGB(120, 200, 110),
	shape = Enum.PartType.Ball,
	size = Vector3.new(1.4, 1.4, 1.4),
}

local STEM_COLOR = Color3.fromRGB(74, 130, 62)
local LEAF_COLOR = Color3.fromRGB(96, 170, 78)
local SOIL_COLOR = Color3.fromRGB(74, 54, 40)
local POT_COLOR = Color3.fromRGB(168, 96, 62)

function AnimalModel.getVisual(animalSpecies: string): FruitVisual
	return FRUIT_VISUALS[animalSpecies] or DEFAULT_VISUAL
end

local function makePart(name: string, size: Vector3, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Builds the empty pot that sits in a farm slot. `slotIndex` is stamped on the
-- model so the farm can find and refill it later.
function AnimalModel.buildPot(slotIndex: number): Model
	local pot = Instance.new("Model")
	pot.Name = "Pot" .. slotIndex
	pot:SetAttribute("SlotIndex", slotIndex)

	local body = makePart("PotBody", Vector3.new(3, 1.8, 3), POT_COLOR, pot)
	body.Shape = Enum.PartType.Cylinder
	-- Cylinder parts extend along X, so stand it upright.
	body.CFrame = CFrame.new(0, 0.9, 0) * CFrame.Angles(0, 0, math.rad(90))
	body.CanCollide = true
	body.CanQuery = true

	local rim = makePart("PotRim", Vector3.new(0.5, 3.4, 3.4), Color3.fromRGB(190, 112, 74), pot)
	rim.Shape = Enum.PartType.Cylinder
	rim.CFrame = CFrame.new(0, 1.75, 0) * CFrame.Angles(0, 0, math.rad(90))

	local soil = makePart("Soil", Vector3.new(0.35, 2.9, 2.9), SOIL_COLOR, pot)
	soil.Shape = Enum.PartType.Cylinder
	soil.CFrame = CFrame.new(0, 1.85, 0) * CFrame.Angles(0, 0, math.rad(90))

	pot.PrimaryPart = body
	return pot
end

-- Builds the animal itself: stem, two leaves, and the fruit on top.
-- The model's PrimaryPart sits at the base, so pivoting it to a pot's soil
-- surface places it correctly.
function AnimalModel.build(animal: Animal): Model
	local visual = AnimalModel.getVisual(animal.animalSpecies)

	local model = Instance.new("Model")
	model.Name = animal.animalSpecies
	model:SetAttribute("AnimalSpecies", animal.animalSpecies)
	model:SetAttribute("RarityId", animal.rarityId)

	-- Invisible anchor at ground level: everything is positioned relative to it.
	local root = makePart("Root", Vector3.new(0.2, 0.2, 0.2), STEM_COLOR, model)
	root.Transparency = 1

	local stemHeight = 2.4
	local stem = makePart("Stem", Vector3.new(0.32, stemHeight, 0.32), STEM_COLOR, model)
	stem.CFrame = CFrame.new(0, stemHeight / 2, 0)

	-- Two angled leaves, mirrored around the stem.
	for i, side in { -1, 1 } do
		local leaf = makePart("Leaf" .. i, Vector3.new(1.1, 0.16, 0.6), LEAF_COLOR, model)
		leaf.CFrame = CFrame.new(side * 0.62, stemHeight * 0.45, 0)
			* CFrame.Angles(0, 0, math.rad(side * -22))
	end

	local fruit = makePart("Fruit", visual.size, visual.color, model)
	fruit.Shape = visual.shape
	if visual.neon then
		fruit.Material = Enum.Material.Neon
	end
	fruit.CFrame = CFrame.new(0, stemHeight + visual.size.Y * 0.42, 0)
		* CFrame.Angles(0, math.rad(visual.tilt or 0), math.rad(visual.tilt or 0))

	-- Rare animals get a coloured glow so a good farm reads at a distance.
	if animal.rarityId >= 4 then
		local light = Instance.new("PointLight")
		light.Color = visual.color
		light.Brightness = animal.rarityId >= 6 and 2.5 or 1.4
		light.Range = animal.rarityId >= 6 and 12 or 8
		light.Parent = fruit
	end

	model.PrimaryPart = root
	return model
end

return AnimalModel
