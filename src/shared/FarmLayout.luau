--!strict
-- Pure geometry for the farm grid: where every farm, pot, pedestal and upgrade
-- button sits, and how to build them.
--
-- This module deliberately has no server dependencies (only GameConfig and
-- AnimalModel), so the Studio scene draft and the live server can build the exact
-- same world from the same constants. FarmService adds behaviour on top.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local AnimalModel = require(ReplicatedStorage.Shared.AnimalModel)

local FarmLayout = {}

-- ── Layout constants ──────────────────────────────────────────────────────────

FarmLayout.FARM_COUNT = 6
FarmLayout.COLUMNS = 2
FarmLayout.ROWS = 3

FarmLayout.FARM_WIDTH = 84
FarmLayout.FARM_DEPTH = 76
FarmLayout.GAP_X = 16
FarmLayout.GAP_Z = 14
FarmLayout.FLOOR_Y = 0

FarmLayout.POT_COLUMNS = 5
FarmLayout.POT_SPACING = 11
FarmLayout.POT_AREA_CENTER_Z = 8

FarmLayout.PEDESTAL_SPACING = 15
FarmLayout.PEDESTAL_Z = -26

FarmLayout.UPGRADE_Z = -8
FarmLayout.UPGRADE_X = 36

FarmLayout.UNCLAIMED_COLOR = Color3.fromRGB(120, 132, 150)
FarmLayout.CLAIMED_COLOR = Color3.fromRGB(96, 186, 104)

-- ── Positioning ───────────────────────────────────────────────────────────────

-- World-space center of a farm in the 2x3 grid. Farms fill left-to-right,
-- back-to-front, so the arrangement stays symmetric around the origin.
function FarmLayout.getFarmOrigin(farmIndex: number): CFrame
	local zeroBased = farmIndex - 1
	local col = (zeroBased % FarmLayout.COLUMNS) + 1
	local row = math.floor(zeroBased / FarmLayout.COLUMNS) + 1

	local x = (col - (FarmLayout.COLUMNS + 1) / 2) * (FarmLayout.FARM_WIDTH + FarmLayout.GAP_X)
	local z = (row - (FarmLayout.ROWS + 1) / 2) * (FarmLayout.FARM_DEPTH + FarmLayout.GAP_Z)

	return CFrame.new(x, FarmLayout.FLOOR_Y, z)
end

-- Local offset of pot `slotIndex` (1-based) within its farm.
function FarmLayout.getPotOffset(slotIndex: number): Vector3
	local zeroBased = slotIndex - 1
	local col = zeroBased % FarmLayout.POT_COLUMNS
	local row = math.floor(zeroBased / FarmLayout.POT_COLUMNS)
	local rows = math.ceil(GameConfig.FARM_MAX_SIZE / FarmLayout.POT_COLUMNS)

	local x = (col - (FarmLayout.POT_COLUMNS - 1) / 2) * FarmLayout.POT_SPACING
	local z = FarmLayout.POT_AREA_CENTER_Z + (row - (rows - 1) / 2) * FarmLayout.POT_SPACING
	return Vector3.new(x, 0, z)
end

-- Local offset of pedestal `pedestalIndex` (1-based) within its farm.
function FarmLayout.getPedestalOffset(pedestalIndex: number): Vector3
	local x = (pedestalIndex - (GameConfig.PEDESTAL_MAX + 1) / 2) * FarmLayout.PEDESTAL_SPACING
	return Vector3.new(x, 0, FarmLayout.PEDESTAL_Z)
end

-- ── Primitives ────────────────────────────────────────────────────────────────

local function makePart(name: string, size: Vector3, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Anchored = true
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

function FarmLayout.makeBillboard(adornee: BasePart, name: string, offsetY: number, size: UDim2): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Name = name
	gui.Size = size
	gui.StudsOffsetWorldSpace = Vector3.new(0, offsetY, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 120
	gui.Adornee = adornee
	gui.Parent = adornee

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.35
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.Text = ""
	label.Parent = gui

	return label
end

-- ── Construction ──────────────────────────────────────────────────────────────

local function buildPedestal(farm: Model, pedestalIndex: number)
	local pedestal = Instance.new("Model")
	pedestal.Name = "Pedestal" .. pedestalIndex
	pedestal:SetAttribute("PedestalIndex", pedestalIndex)
	pedestal.Parent = farm

	local base = makePart("Base", Vector3.new(6, 1, 6), Color3.fromRGB(58, 66, 92), pedestal)
	local column = makePart("Column", Vector3.new(3.2, 4, 3.2), Color3.fromRGB(74, 86, 120), pedestal)
	local top = makePart("Top", Vector3.new(5, 0.8, 5), Color3.fromRGB(255, 196, 62), pedestal)
	top.Material = Enum.Material.Neon

	local offset = FarmLayout.getPedestalOffset(pedestalIndex)
	base.CFrame = CFrame.new(offset + Vector3.new(0, 0.5, 0))
	column.CFrame = CFrame.new(offset + Vector3.new(0, 3, 0))
	top.CFrame = CFrame.new(offset + Vector3.new(0, 5.4, 0))

	pedestal.PrimaryPart = base

	local label = FarmLayout.makeBillboard(top, "StatusGui", 3.2, UDim2.new(0, 220, 0, 60))
	label.Text = "ROLL"
	label.TextColor3 = Color3.fromRGB(255, 214, 90)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RollPrompt"
	prompt.ActionText = "Rollear"
	prompt.ObjectText = "Pedestal " .. pedestalIndex
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = top
end

local function buildUpgradeButton(farm: Model, upgradeId: string, title: string, offset: Vector3, color: Color3)
	local button = Instance.new("Model")
	button.Name = "Upgrade_" .. upgradeId
	button:SetAttribute("UpgradeId", upgradeId)
	button.Parent = farm

	local base = makePart("Base", Vector3.new(7, 1, 5), Color3.fromRGB(52, 60, 84), button)
	local pad = makePart("Pad", Vector3.new(6, 0.6, 4), color, button)
	pad.Material = Enum.Material.Neon

	base.CFrame = CFrame.new(offset + Vector3.new(0, 0.5, 0))
	pad.CFrame = CFrame.new(offset + Vector3.new(0, 1.2, 0))

	button.PrimaryPart = base

	local label = FarmLayout.makeBillboard(pad, "InfoGui", 4, UDim2.new(0, 260, 0, 90))
	label.Text = title

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BuyPrompt"
	prompt.ActionText = "Comprar"
	prompt.ObjectText = title
	prompt.HoldDuration = 0.35
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = pad
end

-- Builds one complete farm: floor, owner sign, every pot slot, every pedestal
-- and both upgrade buttons. Pots and pedestals the owner has not unlocked are
-- hidden at runtime rather than omitted here.
function FarmLayout.buildFarm(farmIndex: number): Model
	local farm = Instance.new("Model")
	farm.Name = "Farm" .. farmIndex
	farm:SetAttribute("FarmIndex", farmIndex)

	local floor = makePart("Floor", Vector3.new(FarmLayout.FARM_WIDTH, 1, FarmLayout.FARM_DEPTH), Color3.fromRGB(112, 168, 96), farm)
	floor.CFrame = CFrame.new(0, -0.5, 0)
	floor.Material = Enum.Material.Grass

	local border = makePart("Border", Vector3.new(FarmLayout.FARM_WIDTH + 3, 0.6, FarmLayout.FARM_DEPTH + 3), FarmLayout.UNCLAIMED_COLOR, farm)
	border.CFrame = CFrame.new(0, -0.9, 0)

	farm.PrimaryPart = floor

	local signPost = makePart("SignPost", Vector3.new(1, 8, 1), Color3.fromRGB(90, 66, 48), farm)
	signPost.CFrame = CFrame.new(0, 4, FarmLayout.PEDESTAL_Z - 12)
	local signBoard = makePart("SignBoard", Vector3.new(22, 5, 0.8), Color3.fromRGB(48, 56, 78), farm)
	signBoard.CFrame = CFrame.new(0, 9.5, FarmLayout.PEDESTAL_Z - 12)

	local signLabel = FarmLayout.makeBillboard(signBoard, "OwnerGui", 1.5, UDim2.new(0, 340, 0, 90))
	signLabel.Text = "Parcela " .. farmIndex .. "\nLibre"

	local pots = Instance.new("Folder")
	pots.Name = "Pots"
	pots.Parent = farm

	for slotIndex = 1, GameConfig.FARM_MAX_SIZE do
		local pot = AnimalModel.buildPot(slotIndex)
		pot:PivotTo(CFrame.new(FarmLayout.getPotOffset(slotIndex)))
		pot.Parent = pots
	end

	for pedestalIndex = 1, GameConfig.PEDESTAL_MAX do
		buildPedestal(farm, pedestalIndex)
	end

	buildUpgradeButton(farm, "oreLuck", "⛏️ ORE LUCK", Vector3.new(-FarmLayout.UPGRADE_X, 0, FarmLayout.UPGRADE_Z), Color3.fromRGB(90, 170, 255))
	buildUpgradeButton(farm, "pedestals", "🎰 ROLLING PEDESTALS", Vector3.new(FarmLayout.UPGRADE_X, 0, FarmLayout.UPGRADE_Z), Color3.fromRGB(255, 160, 60))

	farm:PivotTo(FarmLayout.getFarmOrigin(farmIndex))
	return farm
end

-- Builds all six farms under a `Farms` folder, replacing anything already there.
function FarmLayout.buildAll(parent: Instance): Folder
	local existing = parent:FindFirstChild("Farms")
	if existing then
		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = "Farms"

	for farmIndex = 1, FarmLayout.FARM_COUNT do
		FarmLayout.buildFarm(farmIndex).Parent = folder
	end

	folder.Parent = parent
	return folder
end

return FarmLayout
