--!strict
local UITheme = {}

export type RarityVisual = {
	name: string,
	gradientTop: Color3,
	gradientBottom: Color3,
	strokeColor: Color3,
	textColor: Color3,
	badgeColor: Color3,
	glowColor: Color3,
}

-- Emojis and visual identifiers for each fruit species
local SPECIES_ICONS: { [string]: string } = {
	["Manzana"] = "🍎",
	["Banana"] = "🍌",
	["Naranja"] = "🍊",
	["Kiwi"] = "🥝",
	["Piña"] = "🍍",
	["Mango"] = "🥭",
	["Maracuyá"] = "🍈",
	["Dragon Fruit"] = "🐉",
	["Durián"] = "🦔",
	["Fruta Dorada"] = "⭐",
	["Fruta de Cristal"] = "💎",
	["Fruta Cósmica"] = "🌌",
}

-- High-quality verified Roblox asset icons
UITheme.ICONS = {
	Coin = "rbxassetid://6031075938",
	Gear = "rbxassetid://6031280882",
	Egg = "rbxassetid://6034684930",
	Plant = "rbxassetid://6034287594",
	Backpack = "rbxassetid://6034287515",
	Trophy = "rbxassetid://6031075929",
	Close = "rbxassetid://6031094678",
	Sparkle = "rbxassetid://6031094667",
	VolumeHigh = "rbxassetid://6031071057",
	Music = "rbxassetid://6034287532",
	Bolt = "rbxassetid://6034287525",
}

local RARITY_STYLES: { [number]: RarityVisual } = {
	[1] = { -- ⚪ Común
		name = "Común",
		gradientTop = Color3.fromRGB(255, 255, 255),
		gradientBottom = Color3.fromRGB(180, 190, 205),
		strokeColor = Color3.fromRGB(140, 150, 170),
		textColor = Color3.fromRGB(255, 255, 255),
		badgeColor = Color3.fromRGB(120, 130, 150),
		glowColor = Color3.fromRGB(200, 210, 230),
	},
	[2] = { -- 🟢 Poco común
		name = "Poco común",
		gradientTop = Color3.fromRGB(140, 255, 120),
		gradientBottom = Color3.fromRGB(45, 200, 70),
		strokeColor = Color3.fromRGB(25, 140, 45),
		textColor = Color3.fromRGB(255, 255, 255),
		badgeColor = Color3.fromRGB(40, 180, 60),
		glowColor = Color3.fromRGB(100, 255, 130),
	},
	[3] = { -- 🔵 Raro
		name = "Raro",
		gradientTop = Color3.fromRGB(120, 225, 255),
		gradientBottom = Color3.fromRGB(35, 135, 255),
		strokeColor = Color3.fromRGB(15, 90, 200),
		textColor = Color3.fromRGB(255, 255, 255),
		badgeColor = Color3.fromRGB(30, 130, 240),
		glowColor = Color3.fromRGB(90, 210, 255),
	},
	[4] = { -- 🟣 Épico
		name = "Épico",
		gradientTop = Color3.fromRGB(235, 130, 255),
		gradientBottom = Color3.fromRGB(150, 45, 240),
		strokeColor = Color3.fromRGB(100, 20, 175),
		textColor = Color3.fromRGB(255, 255, 255),
		badgeColor = Color3.fromRGB(155, 45, 230),
		glowColor = Color3.fromRGB(220, 110, 255),
	},
	[5] = { -- 🟡 Legendario
		name = "Legendario",
		gradientTop = Color3.fromRGB(255, 235, 90),
		gradientBottom = Color3.fromRGB(255, 150, 20),
		strokeColor = Color3.fromRGB(190, 95, 10),
		textColor = Color3.fromRGB(255, 255, 255),
		badgeColor = Color3.fromRGB(245, 150, 20),
		glowColor = Color3.fromRGB(255, 220, 60),
	},
	[6] = { -- 🔴 Mítico
		name = "Mítico",
		gradientTop = Color3.fromRGB(255, 100, 130),
		gradientBottom = Color3.fromRGB(230, 25, 65),
		strokeColor = Color3.fromRGB(150, 10, 40),
		textColor = Color3.fromRGB(255, 255, 255),
		badgeColor = Color3.fromRGB(230, 30, 75),
		glowColor = Color3.fromRGB(255, 75, 110),
	},
}

UITheme.SPECIES_ICONS = SPECIES_ICONS
UITheme.RARITY_STYLES = RARITY_STYLES

-- Vibrant UI Colors (Simulator 2026 Palette)
UITheme.Colors = {
	BackgroundDark = Color3.fromRGB(28, 34, 52),
	BackgroundMedium = Color3.fromRGB(38, 46, 70),
	BackgroundLight = Color3.fromRGB(48, 58, 88),
	BorderOutline = Color3.fromRGB(75, 90, 130),
	GoldAccent = Color3.fromRGB(255, 210, 50),
	GreenSuccess = Color3.fromRGB(50, 205, 85),
	GreenSuccessDark = Color3.fromRGB(25, 140, 50),
	BluePrimary = Color3.fromRGB(60, 160, 255),
	BluePrimaryDark = Color3.fromRGB(25, 100, 210),
	RedDanger = Color3.fromRGB(235, 60, 75),
	TextWhite = Color3.fromRGB(255, 255, 255),
	TextMuted = Color3.fromRGB(190, 205, 230),
}

-- Typography
UITheme.FontTitle = Enum.Font.GothamBlack
UITheme.FontBold = Enum.Font.GothamBold
UITheme.FontMedium = Enum.Font.GothamMedium

function UITheme.getSpeciesIcon(name: string): string
	return SPECIES_ICONS[name] or "🌱"
end

function UITheme.getRarityStyle(rarityId: number): RarityVisual
	return RARITY_STYLES[rarityId] or RARITY_STYLES[1]
end

-- Adds rounded corners
function UITheme.addCorner(instance: GuiObject, radius: number): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
	return corner
end

-- Adds a modern 3D cartoon border stroke
function UITheme.addStroke(instance: GuiObject, color: Color3, thickness: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness or 2.5
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = instance
	return stroke
end

-- Adds a vertical top-to-bottom gradient
function UITheme.addGradient(instance: GuiObject, topColor: Color3, bottomColor: Color3, rotation: number?): UIGradient
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, topColor),
		ColorSequenceKeypoint.new(1, bottomColor),
	})
	grad.Rotation = rotation or 90
	grad.Parent = instance
	return grad
end

return UITheme
