-- FallingStars.server.lua
-- Pequeno generador de estrellas fugaces ligado al clima.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local starDuration = 15
local starSpawnInterval = 0.1

local weatherFolder = ReplicatedStorage:FindFirstChild("Weather") or ReplicatedStorage:WaitForChild("Weather")
local currentWeather = weatherFolder:WaitForChild("CurrentWeather")

local function isMeteorWeather()
	return currentWeather.Value == "MeteorShower"
end

local function isNightTime()
	local hour = tonumber(string.sub(Lighting.TimeOfDay, 1, 2))
	return (hour >= 18 or hour < 6)
end

local starModel = Instance.new("Part")
starModel.Size = Vector3.new(1, 1, 1)
starModel.Shape = Enum.PartType.Ball
starModel.Material = Enum.Material.Neon
starModel.BrickColor = BrickColor.new("Bright yellow")
starModel.Anchored = false
starModel.CanCollide = true
starModel.Parent = game.ServerStorage

local function createStar()
	local star = starModel:Clone()
	star.Position = Vector3.new(
		math.random(-500, 500),
		100,
		math.random(-500, 500)
	)
	star.Parent = workspace

	local attachment0 = Instance.new("Attachment")
	attachment0.Name = "Attachment0"
	attachment0.Position = Vector3.new(0, 0.5, 0)
	attachment0.Parent = star

	local attachment1 = Instance.new("Attachment")
	attachment1.Name = "Attachment1"
	attachment1.Position = Vector3.new(0, -0.5, 0)
	attachment1.Parent = star

	local trail = Instance.new("Trail")
	trail.Attachment0 = attachment0
	trail.Attachment1 = attachment1
	trail.Lifetime = 1
	trail.WidthScale = NumberSequence.new(1)
	trail.Color = ColorSequence.new(Color3.new(1, 1, 0))
	trail.Transparency = NumberSequence.new(0, 1)
	trail.FaceCamera = true
	trail.Parent = star

	task.delay(starDuration, function()
		if star then
			star:Destroy()
		end
	end)
end

while true do
	if isMeteorWeather() and isNightTime() then
		createStar()
		task.wait(starSpawnInterval)
	else
		task.wait(1)
	end
end
