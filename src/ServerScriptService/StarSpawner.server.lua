-- StarSpawner.lua
-- Genera estrellas fugaces cuando hay lluvia de estrellas y es de noche.

local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local STAR_DURATION = 15
local SPAWN_INTERVAL = 0.2
local FALL_SPEED = 30
local NIGHT_START_HOUR = 18
local NIGHT_END_HOUR = 6

local weatherFolder = ReplicatedStorage:FindFirstChild("Weather") or ReplicatedStorage:WaitForChild("Weather")
local currentWeather = weatherFolder:WaitForChild("CurrentWeather")

local function isMeteorWeather()
	return currentWeather.Value == "MeteorShower"
end

local function isNightTime()
	local hour = tonumber(string.sub(Lighting.TimeOfDay, 1, 2))
	return (hour >= NIGHT_START_HOUR or hour < NIGHT_END_HOUR)
end

local function createStar()
	local star = Instance.new("Part")
	star.Name = "Star"
	star.Size = Vector3.new(1, 1, 1)
	star.Shape = Enum.PartType.Ball
	star.Material = Enum.Material.Neon
	star.BrickColor = BrickColor.new("Bright yellow")
	star.Anchored = false
	star.CanCollide = true
	star.CastShadow = false
	star.Position = Vector3.new(
		math.random(-500, 500),
		100,
		math.random(-500, 500)
	)
	star.Parent = workspace

	local light = Instance.new("PointLight")
	light.Color = star.Color
	light.Brightness = 2
	light.Range = 10
	light.Parent = star

	local att0 = Instance.new("Attachment")
	att0.Position = Vector3.new(0, 0.5, 0)
	att0.Parent = star

	local att1 = Instance.new("Attachment")
	att1.Position = Vector3.new(0, -0.5, 0)
	att1.Parent = star

	local trail = Instance.new("Trail")
	trail.Attachment0 = att0
	trail.Attachment1 = att1
	trail.Lifetime = 0.5
	trail.WidthScale = NumberSequence.new(1, 0)
	trail.Transparency = NumberSequence.new(0, 1)
	trail.FaceCamera = true
	trail.Parent = star

	local spark = Instance.new("ParticleEmitter")
	spark.Texture = "rbxassetid://7924475318"
	spark.LightEmission = 1
	spark.Rate = 20
	spark.Lifetime = NumberRange.new(0.3, 0.6)
	spark.Speed = NumberRange.new(0)
	spark.Size = NumberSequence.new(0.3)
	spark.Transparency = NumberSequence.new(0, 1)
	spark.Rotation = NumberRange.new(0, 360)
	spark.RotSpeed = NumberRange.new(-180, 180)
	spark.Parent = star

	local bv = Instance.new("BodyVelocity")
	bv.Velocity = Vector3.new(0, -FALL_SPEED, 0)
	bv.MaxForce = Vector3.new(0, 1e5, 0)
	bv.Parent = star

	task.delay(STAR_DURATION - 1, function()
		TweenService:Create(trail, TweenInfo.new(1), { Lifetime = 0.1 }):Play()
		TweenService:Create(star, TweenInfo.new(1), { Transparency = 1 }):Play()
	end)

	Debris:AddItem(star, STAR_DURATION)
end

while true do
	if isMeteorWeather() and isNightTime() then
		createStar()
		task.wait(SPAWN_INTERVAL)
	else
		task.wait(1)
	end
end
