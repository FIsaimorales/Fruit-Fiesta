--!strict
local UITheme = {}

-- Emojis and visual identifiers for each fruit species
UITheme.SPECIES_ICONS: { [string]: string } = {
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

export type RarityVisual = {
	name: string,
	gradientTop: Color3,
	gradientBottom: Color3,
	strokeColor: Color3,
	textColor: Color3,
	badgeColor: Color3,
	particleColor: ColorSequence,
}

UITheme.RARITY_STYLES: { [number]: RarityVisual } = {
	[1] = { -- Común (Slate / Crisp White-Gray)
		name = "Común",
		gradientTop = Color3.fromRGB(240, 240, 245),
		gradientBottom = Color3.fromRGB(170, 175, 185),
		strokeColor = Color3.fromRGB(120, 125, 140),
		textColor = Color3.fromRGB(40, 45, 55),
		badgeColor = Color3.fromRGB(150, 155, 165),
		particleColor = ColorSequence.new(Color3.fromRGB(220, 220, 220)),
	},
	[2] = { -- Poco común (Vibrant Emerald Lime)
		name = "Poco común",
		gradientTop = Color3.fromRGB(130, 255, 130),
		gradientBottom = Color3.fromRGB(40, 190, 60),
		strokeColor = Color3.fromRGB(25, 130, 40),
		textColor = Color3.fromRGB(255, 255, 255),
		badgeColor = Color3.fromRGB(45, 180, 65),
		particleColor = ColorSequence.new(Color3.fromRGB(100, 255, 120)),
	},
	[3] = { -- Raro (Sapphire Cyan Blue)
		name = "Raro",
		gradientTop = Color3.fromRGB(100, 220, 255),
		gradientBottom = Color3.fromRGB(30, 120, 245),
		strokeColor = Color3.fromRGB(15, 80, 180),
		textColor = Color3.fromRGB(255, 255, 255),
		badgeColor = Color3.fromRGB(35, 130, 240),
		particleColor = ColorSequence.new(Color3.fromRGB(80, 200, 255)),
	},
	[4] = { -- Épico (Royal Violet Purple)
		name = "Épico",
		gradientTop = Color3.fromRGB(225, 120, 255),
		gradientBottom = Color3.fromRGB(140, 40, 230),
		strokeColor = Color3.fromRGB(90, 20, 160),
		textColor = Color3.fromRGB(255, 255, 255),
		badgeColor = Color3.fromRGB(150, 45, 235),
		particleColor = ColorSequence.new(Color3.fromRGB(210, 100, 255)),
	},
	[5] = { -- Legendario (Radiant Sun Gold)
		name = "Legendario",
		gradientTop = Color3.fromRGB(255, 230, 90),
		gradientBottom = Color3.fromRGB(255, 140, 20),
		strokeColor = Color3.fromRGB(180, 90, 10),
		textColor = Color3.fromRGB(255, 255, 255),
		badgeColor = Color3.fromRGB(245, 150, 25),
		particleColor = ColorSequence.new(Color3.fromRGB(255, 215, 50)),
	},
	[6] = { -- Mítico (Cosmic Crimson Star)
		name = "Mítico",
		gradientTop = Color3.fromRGB(255, 90, 120),
		gradientBottom = Color3.fromRGB(220, 20, 60),
		strokeColor = Color3.fromRGB(140, 10, 35),
		textColor = Color3.fromRGB(255, 255, 255),
		badgeColor = Color3.fromRGB(230, 30, 70),
		particleColor = ColorSequence.new(Color3.fromRGB(255, 70, 100)),
	},
}

-- Modern clean fonts
UITheme.FontTitle = Enum.Font.GothamBlack
UITheme.FontBold = Enum.Font.GothamBold
UITheme.FontMedium = Enum.Font.GothamMedium
UITheme.FontRegular = Enum.Font.Gotham

-- UI Helpers
function UITheme.getSpeciesIcon(name: string): string
	return UITheme.SPECIES_ICONS[name] or "🌱"
end

function UITheme.getRarityStyle(rarityId: number): RarityVisual
	return UITheme.RARITY_STYLES[rarityId] or UITheme.RARITY_STYLES[1]
end

-- Adds rounded corners to an instance
function UITheme.addCorner(instance: GuiObject, radius: number): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
	return corner
end

-- Adds a modern cartoon 3D border stroke
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
