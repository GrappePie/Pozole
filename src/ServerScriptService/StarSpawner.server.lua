-- StarSpawner.lua
-- Coloca este Script en ServerScriptService

local Lighting     = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Debris       = game:GetService("Debris")

-- CONFIGURACIÓN
local STAR_DURATION    = 15    -- segundos antes de que desaparezca la estrella
local SPAWN_INTERVAL   = 0.2   -- segundos entre cada creación de estrella
local FALL_SPEED       = 30    -- studs/seg que “caen” las estrellas
local NIGHT_START_HOUR = 18
local NIGHT_END_HOUR   = 6

-- Determina si es de noche (entre NIGHT_START_HOUR y NIGHT_END_HOUR)
local function isNightTime()
	local hour = tonumber(string.sub(Lighting.TimeOfDay, 1, 2))
	return (hour >= NIGHT_START_HOUR or hour < NIGHT_END_HOUR)
end

-- Crea y configura una estrella con glow, trail y chispas
local function createStar()
	-- Parte base
	local star = Instance.new("Part")
	star.Name       = "Star"
	star.Size       = Vector3.new(1, 1, 1)
	star.Shape      = Enum.PartType.Ball
	star.Material   = Enum.Material.Neon
	star.BrickColor = BrickColor.new("Bright yellow")
	star.Anchored   = false
	star.CanCollide = true
	star.CastShadow = false
	star.Position   = Vector3.new(
		math.random(-500, 500),
		100,
		math.random(-500, 500)
	)
	star.Parent = workspace

	-- Glow con PointLight
	local light = Instance.new("PointLight", star)
	light.Color      = star.Color
	light.Brightness = 2
	light.Range      = 10

	-- Trail para estela
	local att0 = Instance.new("Attachment", star)
	att0.Position = Vector3.new(0, 0.5, 0)
	local att1 = Instance.new("Attachment", star)
	att1.Position = Vector3.new(0, -0.5, 0)

	local trail = Instance.new("Trail", star)
	trail.Attachment0   = att0
	trail.Attachment1   = att1
	trail.Lifetime      = 0.5
	trail.WidthScale    = NumberSequence.new(1, 0)
	trail.Transparency  = NumberSequence.new(0, 1)
	trail.FaceCamera    = true

	-- ParticleEmitter para chispas
	local spark = Instance.new("ParticleEmitter", star)
	spark.Texture        = "rbxassetid://7924475318"
	spark.LightEmission  = 1
	spark.Rate           = 20
	spark.Lifetime       = NumberRange.new(0.3, 0.6)
	spark.Speed          = NumberRange.new(0)
	spark.Size           = NumberSequence.new(0.3)
	spark.Transparency   = NumberSequence.new(0, 1)
	spark.Rotation       = NumberRange.new(0, 360)
	spark.RotSpeed       = NumberRange.new(-180, 180)

	-- BodyVelocity para caída constante
	local bv = Instance.new("BodyVelocity", star)
	bv.Velocity   = Vector3.new(0, -FALL_SPEED, 0)
	bv.MaxForce   = Vector3.new(0, 1e5, 0)

	-- Fade-out al final del tiempo de vida
	delay(STAR_DURATION - 1, function()
		-- Tween solamente la Lifetime del Trail
		TweenService:Create(trail, TweenInfo.new(1), {
			Lifetime = 0.1,
		}):Play()
		-- Tween de la transparencia de la estrella
		TweenService:Create(star, TweenInfo.new(1), {
			Transparency = 1,
		}):Play()
	end)

	-- Limpieza automática
	Debris:AddItem(star, STAR_DURATION)
end

-- Bucle principal: generar estrellas sólo de noche
while true do
	if isNightTime() then
		createStar()
		task.wait(SPAWN_INTERVAL)
	else
		task.wait(1)
	end
end
