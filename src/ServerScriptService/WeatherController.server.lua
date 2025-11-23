-- WeatherController.server.lua
-- Controla un ciclo de clima sencillo con estados rotativos y replicas para clientes.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local WindLines = require(ServerScriptService:WaitForChild("WindLines"))

local weatherFolder = ReplicatedStorage:FindFirstChild("Weather") or Instance.new("Folder")
weatherFolder.Name = "Weather"
weatherFolder.Parent = ReplicatedStorage

local currentWeather = weatherFolder:FindFirstChild("CurrentWeather") or Instance.new("StringValue")
currentWeather.Name = "CurrentWeather"
currentWeather.Value = "Clear"
currentWeather.Parent = weatherFolder

local weatherChanged = weatherFolder:FindFirstChild("WeatherChanged") or Instance.new("RemoteEvent")
weatherChanged.Name = "WeatherChanged"
weatherChanged.Parent = weatherFolder

local effectsFolder = Workspace:FindFirstChild("WeatherEffects") or Instance.new("Folder")
effectsFolder.Name = "WeatherEffects"
effectsFolder.Parent = Workspace

local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
if not atmosphere then
	atmosphere = Instance.new("Atmosphere")
	atmosphere.Name = "WeatherAtmosphere"
	atmosphere.Parent = Lighting
end

local function hasGlobalWind()
	return pcall(function()
		local _ = Workspace.GlobalWind
	end)
end

local supportsGlobalWind = hasGlobalWind()
local baseState = {
	FogStart = Lighting.FogStart,
	FogEnd = Lighting.FogEnd,
	Density = atmosphere.Density,
	Haze = atmosphere.Haze,
	Glare = atmosphere.Glare,
	GlobalWind = supportsGlobalWind and Workspace.GlobalWind or Vector3.new(0, 0, 0),
}

local random = Random.new()
local activeCleanup = nil
local RAIN_TEXTURE_STRAIGHT = "rbxassetid://1822883048"
local RAIN_TEXTURE_TOPDOWN = "rbxassetid://1822856633"
local RAIN_SOUND_ID = "rbxassetid://1516791621"
local SNOW_TEXTURE = "rbxassetid://11679178526" -- Snowflake 2 (nítida)
local WIND_TEXTURE = "rbxassetid://10558425570"

-- Lighting baseline and snow override (inspirado en Sol's RNG)
local baseLighting = {
	ColorShift_Bottom = Lighting.ColorShift_Bottom,
	FogColor = Lighting.FogColor,
	FogEnd = Lighting.FogEnd,
	EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale,
	Brightness = Lighting.Brightness,
	ColorShift_Top = Lighting.ColorShift_Top,
	ExposureCompensation = Lighting.ExposureCompensation,
	GlobalShadows = Lighting.GlobalShadows,
	EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale,
	GeographicLatitude = Lighting.GeographicLatitude,
	Ambient = Lighting.Ambient,
	OutdoorAmbient = Lighting.OutdoorAmbient,
	ShadowSoftness = Lighting.ShadowSoftness,
	FogStart = Lighting.FogStart,
}

local snowLighting = {
	ColorShift_Bottom = Color3.fromRGB(0, 0, 0),
	FogColor = Color3.fromRGB(192, 192, 192),
	FogEnd = 100000,
	EnvironmentDiffuseScale = 1,
	Brightness = 2,
	ColorShift_Top = Color3.fromRGB(0, 0, 0),
	ExposureCompensation = 0,
	GlobalShadows = true,
	EnvironmentSpecularScale = 1,
	GeographicLatitude = 0,
	Ambient = Color3.fromRGB(52, 52, 52),
	OutdoorAmbient = Color3.fromRGB(70, 70, 70),
	ShadowSoftness = 0.2,
	FogStart = 0,
	Atmosphere = {
		Haze = 0,
		Glare = 0,
		Offset = 0,
		Density = 0.4,
	},
}

local rainLighting = {
	ColorShift_Bottom = Color3.fromRGB(0, 0, 0),
	FogColor = Color3.fromRGB(192, 192, 192),
	FogEnd = 100000,
	EnvironmentDiffuseScale = 1,
	Brightness = 0,
	ColorShift_Top = Color3.fromRGB(0, 0, 0),
	ExposureCompensation = 0,
	GlobalShadows = true,
	EnvironmentSpecularScale = 1,
	GeographicLatitude = 0,
	Ambient = Color3.fromRGB(52, 52, 52),
	OutdoorAmbient = Color3.fromRGB(70, 70, 70),
	ShadowSoftness = 0.2,
	FogStart = 0,
	Atmosphere = {
		Haze = 10,
		Glare = 0,
		Offset = 0.2,
		Density = 0.6,
	},
}

local function applySnowLighting()
	Lighting.ColorShift_Bottom = snowLighting.ColorShift_Bottom
	Lighting.FogColor = snowLighting.FogColor
	Lighting.FogEnd = snowLighting.FogEnd
	Lighting.EnvironmentDiffuseScale = snowLighting.EnvironmentDiffuseScale
	Lighting.Brightness = snowLighting.Brightness
	Lighting.ColorShift_Top = snowLighting.ColorShift_Top
	Lighting.ExposureCompensation = snowLighting.ExposureCompensation
	Lighting.GlobalShadows = snowLighting.GlobalShadows
	Lighting.EnvironmentSpecularScale = snowLighting.EnvironmentSpecularScale
	Lighting.GeographicLatitude = snowLighting.GeographicLatitude
	Lighting.Ambient = snowLighting.Ambient
	Lighting.OutdoorAmbient = snowLighting.OutdoorAmbient
	Lighting.ShadowSoftness = snowLighting.ShadowSoftness
	Lighting.FogStart = snowLighting.FogStart
	atmosphere.Haze = snowLighting.Atmosphere.Haze
	atmosphere.Glare = snowLighting.Atmosphere.Glare
	atmosphere.Offset = snowLighting.Atmosphere.Offset
	atmosphere.Density = snowLighting.Atmosphere.Density
end

local function applyRainLighting()
	Lighting.ColorShift_Bottom = rainLighting.ColorShift_Bottom
	Lighting.FogColor = rainLighting.FogColor
	Lighting.FogEnd = rainLighting.FogEnd
	Lighting.EnvironmentDiffuseScale = rainLighting.EnvironmentDiffuseScale
	Lighting.Brightness = rainLighting.Brightness
	Lighting.ColorShift_Top = rainLighting.ColorShift_Top
	Lighting.ExposureCompensation = rainLighting.ExposureCompensation
	Lighting.GlobalShadows = rainLighting.GlobalShadows
	Lighting.EnvironmentSpecularScale = rainLighting.EnvironmentSpecularScale
	Lighting.GeographicLatitude = rainLighting.GeographicLatitude
	Lighting.Ambient = rainLighting.Ambient
	Lighting.OutdoorAmbient = rainLighting.OutdoorAmbient
	Lighting.ShadowSoftness = rainLighting.ShadowSoftness
	Lighting.FogStart = rainLighting.FogStart
	atmosphere.Haze = rainLighting.Atmosphere.Haze
	atmosphere.Glare = rainLighting.Atmosphere.Glare
	atmosphere.Offset = rainLighting.Atmosphere.Offset
	atmosphere.Density = rainLighting.Atmosphere.Density
end

local function restoreLighting()
	Lighting.ColorShift_Bottom = baseLighting.ColorShift_Bottom
	Lighting.FogColor = baseLighting.FogColor
	Lighting.FogEnd = baseLighting.FogEnd
	Lighting.EnvironmentDiffuseScale = baseLighting.EnvironmentDiffuseScale
	Lighting.Brightness = baseLighting.Brightness
	Lighting.ColorShift_Top = baseLighting.ColorShift_Top
	Lighting.ExposureCompensation = baseLighting.ExposureCompensation
	Lighting.GlobalShadows = baseLighting.GlobalShadows
	Lighting.EnvironmentSpecularScale = baseLighting.EnvironmentSpecularScale
	Lighting.GeographicLatitude = baseLighting.GeographicLatitude
	Lighting.Ambient = baseLighting.Ambient
	Lighting.OutdoorAmbient = baseLighting.OutdoorAmbient
	Lighting.ShadowSoftness = baseLighting.ShadowSoftness
	Lighting.FogStart = baseLighting.FogStart
	atmosphere.Haze = baseState.Haze
	atmosphere.Glare = baseState.Glare
	atmosphere.Offset = 0
	atmosphere.Density = baseState.Density
end

local function applySnowWaters()
	local watersFolder = Workspace:FindFirstChild("Waters")
	if not watersFolder then
		return function() end
	end
	local originals = {}
	for _, child in ipairs(watersFolder:GetChildren()) do
		if child:IsA("BasePart") then
			originals[child] = {
				Material = child.Material,
				Color = child.Color,
			}
			child.Material = Enum.Material.Ice
			child.Color = Color3.fromRGB(157, 194, 243)
		end
	end
	return function()
		for inst, props in pairs(originals) do
			if inst and inst.Parent then
				inst.Material = props.Material
				inst.Color = props.Color
			end
		end
	end
end

local function getSkyParticle(name)
	local map = Workspace:FindFirstChild("Map")
	if not map then
		return nil
	end
	local miscs = map:FindFirstChild("Miscs")
	if not miscs then
		return nil
	end
	local effectModel = miscs:FindFirstChild("EffectModel")
	local sky = (effectModel and effectModel:FindFirstChild("SkyParticles")) or miscs:FindFirstChild("SkyParticles")
	if not sky then
		return nil
	end
	return sky:FindFirstChild(name), sky
end

local function resetSky()
	Lighting.FogStart = baseState.FogStart
	Lighting.FogEnd = baseState.FogEnd
	atmosphere.Density = baseState.Density
	atmosphere.Haze = baseState.Haze
	atmosphere.Glare = baseState.Glare
	if supportsGlobalWind then
		Workspace.GlobalWind = baseState.GlobalWind
	end
	effectsFolder:ClearAllChildren()
end

local function getPlayersCenter()
	local sum = Vector3.new(0, 0, 0)
	local count = 0
	for _, plr in ipairs(Players:GetPlayers()) do
		local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
		if hrp then
			sum += hrp.Position
			count += 1
		end
	end
	if count == 0 then
		return Vector3.new(0, 0, 0)
	end
	return sum / count
end

local function attachFollowPlayers(plate, height)
	local function update()
		local center = getPlayersCenter()
		plate.Position = Vector3.new(center.X, height, center.Z)
	end
	update()
	local conn = RunService.Heartbeat:Connect(update)
	return function()
		if conn then
			conn:Disconnect()
		end
	end
end

local function createPrecipitationEmitter(name, texture, color, rate, speed, lifetime, size, drag, acceleration, spread, height)
	local plate = Instance.new("Part")
	plate.Name = name .. "Emitter"
	plate.Size = Vector3.new(2048, 1, 2048)
	plate.Anchored = true
	plate.CanCollide = false
	plate.Transparency = 1
	plate.Position = Vector3.new(0, height or 120, 0)
	plate.Parent = effectsFolder

	local stopFollow = attachFollowPlayers(plate, height or 120)

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = name
	if texture then
		emitter.Texture = texture
	end
	if color then
		emitter.Color = color
	end
	emitter.Rate = rate
	emitter.Speed = speed
	emitter.Lifetime = lifetime
	emitter.Size = size
	emitter.Drag = drag or 0
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.SpreadAngle = spread or Vector2.new(12, 12)
	emitter.Acceleration = acceleration or Vector3.new(0, -Workspace.Gravity * 0.25, 0)
	emitter.LightInfluence = 0
	emitter.Parent = plate

	return function()
		stopFollow()
		if plate then
			plate:Destroy()
		end
	end
end

local function createWindEmitter()
	WindLines:Init({
		Lifetime = 1.0,
		Direction = Vector3.new(1, 0, 0),
		Speed = 35,
		SpawnRate = 28,
		SpawnRadius = 320,
	})

	return function()
		WindLines:Cleanup()
	end
end

local weatherDefs = {
	{
		name = "Clear",
		weight = 4,
		duration = NumberRange.new(80, 120),
		start = function()
			resetSky()
			return resetSky
		end,
	},
	{
		name = "Rain",
		weight = 3,
		duration = NumberRange.new(50, 85),
		start = function()
			resetSky()
			applyRainLighting()
			Lighting.FogStart = 10
			Lighting.FogEnd = math.max(200, baseState.FogEnd * 0.4)
			atmosphere.Density = baseState.Density + 0.15
			atmosphere.Haze = baseState.Haze + 1
			if supportsGlobalWind then
				Workspace.GlobalWind = baseState.GlobalWind + Vector3.new(0, 0, -6)
			end

			local plate = Instance.new("Part")
			plate.Name = "RainEmitterPlate"
			plate.Size = Vector3.new(80, 80, 80)
			plate.Anchored = true
			plate.CanCollide = false
			plate.Transparency = 1
			plate.Position = Vector3.new(0, 110, 0)
			plate.Parent = effectsFolder
			local camConn
			camConn = RunService.RenderStepped:Connect(function()
				local cam = workspace.CurrentCamera
				if cam then
					plate.CFrame = cam.CFrame * CFrame.new(0, -5, -20)
				end
			end)

			local straight = Instance.new("ParticleEmitter")
			straight.Name = "RainStraight"
			straight.Texture = RAIN_TEXTURE_STRAIGHT
			straight.Color = ColorSequence.new(Color3.fromRGB(190, 220, 255))
			straight.Rate = 600
			straight.Speed = NumberRange.new(60, 70)
			straight.Lifetime = NumberRange.new(0.8, 1)
			straight.Size = NumberSequence.new(10)
			straight.EmissionDirection = Enum.NormalId.Bottom
			straight.SpreadAngle = Vector2.new(12, 12)
			straight.Acceleration = Vector3.new(0, -Workspace.Gravity * 0.2, 0)
			straight.LightInfluence = 0.9
			straight.LightEmission = 0.05
			straight.Orientation = Enum.ParticleOrientation.FacingCameraWorldUp
			straight.LockedToPart = true
			straight.Parent = plate

			local topdown = Instance.new("ParticleEmitter")
			topdown.Name = "RainTopDown"
			topdown.Texture = RAIN_TEXTURE_TOPDOWN
			topdown.Color = ColorSequence.new(Color3.fromRGB(190, 220, 255))
			topdown.Rate = 600
			topdown.Speed = NumberRange.new(60, 70)
			topdown.Lifetime = NumberRange.new(0.8, 1)
			topdown.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 5.33, 2.75),
				NumberSequenceKeypoint.new(1, 5.33, 2.75),
			})
			topdown.EmissionDirection = Enum.NormalId.Bottom
			topdown.SpreadAngle = Vector2.new(18, 18)
			topdown.Acceleration = Vector3.new(0, -Workspace.Gravity * 0.2, 0)
			topdown.LightInfluence = 0.9
			topdown.LightEmission = 0.05
			topdown.Orientation = Enum.ParticleOrientation.FacingCameraWorldUp
			topdown.LockedToPart = true
			topdown.Rotation = NumberRange.new(0, 360)
			topdown.Parent = plate

			local rainSound = Instance.new("Sound")
			rainSound.Name = "RainSound"
			rainSound.SoundId = RAIN_SOUND_ID
			rainSound.Looped = true
			rainSound.Volume = 0.35
			rainSound.RollOffMaxDistance = 250
			rainSound.Parent = plate
			rainSound:Play()

			return function()
				if rainSound.IsPlaying then
					rainSound:Stop()
				end
				if camConn then
					camConn:Disconnect()
				end
				restoreLighting()
				plate:Destroy()
				resetSky()
			end
		end,
	},
	{
		name = "Snow",
		weight = 2,
		duration = NumberRange.new(60, 90),
		start = function()
			resetSky()
			if supportsGlobalWind then
				Workspace.GlobalWind = baseState.GlobalWind + Vector3.new(0, 0, -3)
			end
			applySnowLighting()

			local skySnow, skyFolder = getSkyParticle("IsSnowy")
			local disabled = {}
			if skyFolder then
				for _, child in ipairs(skyFolder:GetChildren()) do
					if child:IsA("ParticleEmitter") then
						if child.Enabled then
							table.insert(disabled, child)
						end
						child.Enabled = false
					end
				end
			end
			if skySnow then
				skySnow.Enabled = true
			end
			-- Si no existe el particle del mapa, usa nuestro emisor de respaldo.
			local cleanupEmitter
			if not skySnow then
				cleanupEmitter = createPrecipitationEmitter(
					"Snow",
					SNOW_TEXTURE,
					ColorSequence.new(Color3.fromRGB(255, 255, 255)),
					260,
					NumberRange.new(22, 32),
					NumberRange.new(3.5, 4.5),
					NumberSequence.new(0.4, 0.55),
					4,
					Vector3.new(0, -12, 0),
					Vector2.new(10, 10),
					95
				)
			end
			local revertWaters = applySnowWaters()

			return function()
				if cleanupEmitter then
					cleanupEmitter()
				end
				if skySnow then
					skySnow.Enabled = false
				end
				for _, child in ipairs(disabled) do
					if child and child.Parent then
						child.Enabled = true
					end
				end
				revertWaters()
				restoreLighting()
				resetSky()
			end
		end,
	},
	{
		name = "Windy",
		weight = 2,
		duration = NumberRange.new(45, 70),
		start = function()
			resetSky()
			Lighting.FogStart = 0
			Lighting.FogEnd = math.max(400, baseState.FogEnd * 0.7)
			atmosphere.Density = baseState.Density + 0.05
			atmosphere.Haze = baseState.Haze + 0.5
			if supportsGlobalWind then
				Workspace.GlobalWind = Vector3.new(0, 0, -18)
			end

			local cleanupEmitter = createWindEmitter()

			return function()
				cleanupEmitter()
				resetSky()
			end
		end,
	},
	{
		name = "MeteorShower",
		weight = 1,
		duration = NumberRange.new(30, 45),
		start = function()
			resetSky()
			Lighting.FogStart = 0
			Lighting.FogEnd = math.max(700, baseState.FogEnd * 0.8)
			atmosphere.Density = baseState.Density + 0.05
			atmosphere.Haze = baseState.Haze + 0.25
			return function()
				resetSky()
			end
		end,
	},
}

local function chooseWeather()
	local totalWeight = 0
	for _, def in ipairs(weatherDefs) do
		totalWeight += def.weight
	end

	local roll = random:NextNumber(0, totalWeight)
	for _, def in ipairs(weatherDefs) do
		if roll <= def.weight then
			return def
		end
		roll -= def.weight
	end

	return weatherDefs[1]
end

local function setWeather(def)
	if activeCleanup then
		activeCleanup()
	end

	activeCleanup = nil
	currentWeather.Value = def.name
	weatherChanged:FireAllClients(def.name)

	if def.start then
		activeCleanup = def.start()
	end
end

while true do
	local def = chooseWeather()
	setWeather(def)

	local waitSeconds = def.duration.Min
	if def.duration.Max then
		waitSeconds = random:NextNumber(def.duration.Min, def.duration.Max)
	end

	task.wait(waitSeconds)
end
