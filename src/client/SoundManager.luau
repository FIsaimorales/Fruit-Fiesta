--!strict
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local SoundManager = {}

-- Volumes (0.0 to 1.0)
local masterVolume = 1.0
local musicVolume = 1.0
local effectsVolume = 1.0

-- Baseline volume storage so changing sliders scales appropriately
local baseVolumes: { [Sound]: number } = {}

-- 100% clean, built-in Roblox engine sounds (no network lag, no wrong assets)
local BUILTIN_SOUNDS = {
	Click = "rbxasset://sounds/uiclick.wav",               -- Clic clásico suave
	Pop = "rbxasset://sounds/drop.wav",                    -- Pop suave para hover/plantar
	Chime = "rbxasset://sounds/electronicpingshort.wav",   -- Ping melódico
	Coin = "rbxasset://sounds/bell.wav",                   -- Campanita dorada para monedas
	EggCrack = "rbxasset://sounds/drop.wav",               -- Sonido suave de eclosión
	Fanfare = "rbxasset://sounds/victory.wav",             -- Fanfarria triunfal para frutas raras
	Error = "rbxasset://sounds/uiclick.wav",               -- Error suave
}

local uiSoundsFolder: Folder? = nil

local function getUISound(name: string): Sound?
	if not uiSoundsFolder then
		local found = SoundService:FindFirstChild("FruitCleanUISounds")
		if found and found:IsA("Folder") then
			uiSoundsFolder = found
		else
			uiSoundsFolder = Instance.new("Folder")
			uiSoundsFolder.Name = "FruitCleanUISounds"
			uiSoundsFolder.Parent = SoundService
		end
	end

	local soundAsset = BUILTIN_SOUNDS[name] or BUILTIN_SOUNDS.Click
	local s = uiSoundsFolder:FindFirstChild(name) :: Sound?
	if not s then
		s = Instance.new("Sound")
		s.Name = name
		s.SoundId = soundAsset
		s.Volume = 0.5
		s.Parent = uiSoundsFolder
		baseVolumes[s] = 0.5
	end
	return s
end

-- Determina si un sonido es música de fondo o efecto de sonido
local function isMusicSound(sound: Sound): boolean
	local nameLower = sound.Name:lower()
	local parentNameLower = sound.Parent and sound.Parent.Name:lower() or ""
	if sound.Looped then
		return true
	end
	if nameLower:find("music") or nameLower:find("bgm") or nameLower:find("ost") or nameLower:find("ambient") then
		return true
	end
	if parentNameLower:find("music") or parentNameLower:find("bgm") then
		return true
	end
	return false
end

-- Aplica los volúmenes a un sonido específico
local function applyVolumeToSound(sound: Sound)
	local base = baseVolumes[sound]
	if not base then
		base = sound.Volume > 0 and sound.Volume or 0.5
		baseVolumes[sound] = base
	end

	if isMusicSound(sound) then
		sound.Volume = base * musicVolume * masterVolume
	else
		sound.Volume = base * effectsVolume * masterVolume
	end
end

-- Actualiza todos los sonidos en Workspace y SoundService
local function updateAllSounds()
	for _, desc in Workspace:GetDescendants() do
		if desc:IsA("Sound") then
			applyVolumeToSound(desc)
		end
	end
	for _, desc in SoundService:GetDescendants() do
		if desc:IsA("Sound") then
			applyVolumeToSound(desc)
		end
	end
end

function SoundManager.setMasterVolume(vol: number)
	masterVolume = math.clamp(vol, 0, 1)
	updateAllSounds()
end

function SoundManager.setMusicVolume(vol: number)
	musicVolume = math.clamp(vol, 0, 1)
	updateAllSounds()
end

function SoundManager.setEffectsVolume(vol: number)
	effectsVolume = math.clamp(vol, 0, 1)
	updateAllSounds()
end

function SoundManager.getMasterVolume(): number
	return masterVolume
end

function SoundManager.getMusicVolume(): number
	return musicVolume
end

function SoundManager.getEffectsVolume(): number
	return effectsVolume
end

function SoundManager.playSound(name: string, pitch: number?, volumeScale: number?)
	task.spawn(function()
		local snd = getUISound(name)
		if snd then
			local finalVol = (baseVolumes[snd] or 0.5) * (volumeScale or 1.0) * effectsVolume * masterVolume
			snd.Volume = finalVol
			snd.PlaybackSpeed = pitch or 1.0
			snd:Play()
		end
	end)
end

function SoundManager.init()
	-- Escanear sonidos iniciales
	updateAllSounds()

	-- Escuchar nuevos sonidos que se agreguen dinámicamente
	Workspace.DescendantAdded:Connect(function(desc)
		if desc:IsA("Sound") then
			task.wait(0.1)
			applyVolumeToSound(desc)
		end
	end)

	SoundService.DescendantAdded:Connect(function(desc)
		if desc:IsA("Sound") then
			task.wait(0.1)
			applyVolumeToSound(desc)
		end
	end)
end

return SoundManager
