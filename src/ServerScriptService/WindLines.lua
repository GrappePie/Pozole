-- WindLines.lua
-- Genera líneas de viento con Trail similares a Sol's RNG.

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Terrain = workspace:FindFirstChildOfClass("Terrain") or workspace

local OFFSET = Vector3.new(0, 0.1, 0)
local module = {}

module.UpdateConnection = nil
module.UpdateQueue = table.create(32)
module.LastSpawned = 0
module.Lifetime = 0.7
module.Direction = Vector3.new(1, 0, 0)
module.Speed = 30
module.SpawnRate = 18 -- líneas por segundo
module.SpawnRadius = 250

local function clearQueue()
	for _, windLine in module.UpdateQueue do
		if windLine.Attachment0 then
			windLine.Attachment0:Destroy()
		end
		if windLine.Attachment1 then
			windLine.Attachment1:Destroy()
		end
		if windLine.Trail then
			windLine.Trail:Destroy()
		end
	end
	table.clear(module.UpdateQueue)
end

function module:Cleanup()
	if module.UpdateConnection then
		module.UpdateConnection:Disconnect()
		module.UpdateConnection = nil
		module.LastSpawned = 0
	end
	clearQueue()
end

function module:Init(settings)
	settings = settings or {}
	module.Lifetime = settings.Lifetime or module.Lifetime
	module.Direction = settings.Direction or module.Direction
	module.Speed = settings.Speed or module.Speed
	module.SpawnRate = settings.SpawnRate or module.SpawnRate
	module.SpawnRadius = settings.SpawnRadius or module.SpawnRadius

	if module.UpdateConnection then
		module.UpdateConnection:Disconnect()
		module.UpdateConnection = nil
	end
	clearQueue()

	local spawnInterval = 1 / module.SpawnRate
	module.LastSpawned = os.clock()

	module.UpdateConnection = RunService.Heartbeat:Connect(function(dt)
		local clock = os.clock()

		-- spawn
		if clock - module.LastSpawned >= spawnInterval then
			module:Create()
			module.LastSpawned = clock
		end

		-- update
		for i = #module.UpdateQueue, 1, -1 do
			local windLine = module.UpdateQueue[i]
			local alive = clock - windLine.StartClock
			if alive >= windLine.Lifetime then
				windLine.Attachment0:Destroy()
				windLine.Attachment1:Destroy()
				windLine.Trail:Destroy()
				module.UpdateQueue[i] = module.UpdateQueue[#module.UpdateQueue]
				module.UpdateQueue[#module.UpdateQueue] = nil
			else
				windLine.Trail.MaxLength = math.max(6, 14 - (14 * (alive / windLine.Lifetime)))
				local seededClock = (clock + windLine.Seed) * (windLine.Speed * 0.08)
				local startPos = windLine.Position
				windLine.Attachment0.WorldPosition = (CFrame.new(startPos, startPos + windLine.Direction) * CFrame.new(
					0,
					0,
					windLine.Speed * -alive
				)).Position + Vector3.new(
					math.sin(seededClock) * 0.4,
					math.sin(seededClock * 1.3) * 0.3,
					math.sin(seededClock * 1.1) * 0.4
				)
				windLine.Attachment1.WorldPosition = windLine.Attachment0.WorldPosition + OFFSET
			end
		end
	end)
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

function module:Create(settings)
	settings = settings or {}
	local lifetime = settings.Lifetime or module.Lifetime
	local dir = (settings.Direction or module.Direction).Unit
	local speed = settings.Speed or module.Speed
	if speed <= 0 then
		return
	end

	local center = getPlayersCenter()
	local radius = settings.SpawnRadius or module.SpawnRadius
	local theta = math.rad(math.random(0, 360))
	local dist = math.random(0, radius)
	local pos = center + Vector3.new(math.cos(theta) * dist, math.random(6, 18), math.sin(theta) * dist)

	local a0 = Instance.new("Attachment")
	local a1 = Instance.new("Attachment")
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(0.1, 0.16),
		NumberSequenceKeypoint.new(0.4, 0.16),
		NumberSequenceKeypoint.new(1, 0.05),
	})
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 0.9),
	})
	trail.FaceCamera = true
	trail.Lifetime = lifetime
	trail.LightInfluence = 0
	trail.Parent = a0

	a0.WorldPosition = pos
	a1.WorldPosition = pos + OFFSET

	module.UpdateQueue[#module.UpdateQueue + 1] = {
		Attachment0 = a0,
		Attachment1 = a1,
		Trail = trail,
		Lifetime = lifetime + (math.random(-8, 8) * 0.02),
		Position = pos,
		Direction = dir,
		Speed = speed + (math.random(-4, 4) * 0.05),
		StartClock = os.clock(),
		Seed = math.random(1, 500) * 0.1,
	}

	a0.Parent = Terrain
	a1.Parent = Terrain
end

return module
