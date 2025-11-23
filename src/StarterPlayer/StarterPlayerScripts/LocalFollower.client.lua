-- LocalFollower.lua

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
local player = Players.LocalPlayer

local Constants = require(ReplicatedStorage:WaitForChild("Constants"))

local AssignFollowerEvent = ReplicatedStorage:WaitForChild("AssignFollowerEvent")
local SyncFollowerAnimationEvent = ReplicatedStorage:WaitForChild("SyncFollowerAnimationEvent")
local StarEvents = ReplicatedStorage:WaitForChild("StarEvents")
local UpgradeFollowerEvent = ReplicatedStorage:WaitForChild("UpgradeFollowerEvent")

-- Variables del follower
local rig : Model? = nil
local humanoid : Humanoid? = nil
local hrp : BasePart? = nil

-- Parámetros de movimiento
local STOP_DISTANCE = 5
local WALK_DISTANCE_THRESHOLD = 7
local JOG_DISTANCE_THRESHOLD = 20
local WALK_SPEED = 8
local RANGE_SIZE = 40
local JOG_SPEED  = 12
local RUN_SPEED  = 16

local followerUpgrades = {
	Range = RANGE_SIZE,
	Speed = WALK_SPEED,
	Health = 100,
	RespawnTime = 10,
	HealthRegen = 1,
	Luck = 0
}

-- Animaciones
local animTracks = {
	idle = nil,
	walk = nil,
	run  = nil
}
local currentAnimState = nil

local function loadAnimations(humanoid: Humanoid)
	local defaultAnimations = {
		idle = "rbxassetid://18747067405",
		idle2 = "rbxassetid://18747063918",
		walk = "rbxassetid://16738340646",
		run  = "rbxassetid://72301599441680",
	}
	for name, assetId in pairs(defaultAnimations) do
		local animation = Instance.new("Animation")
		animation.AnimationId = assetId
		animTracks[name] = humanoid:LoadAnimation(animation)
	end
	animTracks.idle:Play()
	currentAnimState = "idle"
end

local function syncAnimState(newState: string)
	if currentAnimState ~= newState then
		currentAnimState = newState
		SyncFollowerAnimationEvent:FireServer(newState)
	end
end

local function updateAnimation(speed: number)
	local newState: string = ""
	if speed > 0 then
		if speed > 12 then
			newState = "run"
			if animTracks.run and not animTracks.run.IsPlaying then
				animTracks.idle:Stop()
				animTracks.walk:Stop()
				animTracks.run:Play()
			end
		else
			newState = "walk"
			if animTracks.walk and not animTracks.walk.IsPlaying then
				animTracks.idle:Stop()
				animTracks.run:Stop()
				animTracks.walk:Play()
			end
		end
	else
		newState = "idle"
		if animTracks.idle and not animTracks.idle.IsPlaying then
			animTracks.walk:Stop()
			animTracks.run:Stop()
			animTracks.idle:Play()
		end
	end
	syncAnimState(newState)
end

----------------------------------------------------
-- Lógica para recoger y entregar estrellas
----------------------------------------------------
local currentTarget : BasePart? = nil
local carryingStar : Part? = nil
local isDelivering = false

local function findNearestStar(maxDistance)
	local nearest, dist = nil, math.huge
	if not hrp then return nil end
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("Part") and obj.Name == "Star" then
			local d = (hrp.Position - obj.Position).Magnitude
			if d < maxDistance and d < dist then
				dist, nearest = d, obj
			end
		end
	end
	return nearest
end

local function createLocalStar()
	-- Si ya había una estrella anterior, la borramos
	if carryingStar then
		carryingStar:Destroy()
		carryingStar = nil
	end

	-- Crear la parte
	local star = Instance.new("Part")
	star.Name       = "LocalCarriedStar"
	star.Shape      = Enum.PartType.Ball
	star.Material   = Enum.Material.Neon
	star.Size       = Vector3.new(1, 1, 1)
	star.BrickColor = BrickColor.new("Bright yellow")
	star.Anchored   = true
	star.CanCollide = false
	star.Parent     = workspace

	-- Luz
	local light = Instance.new("PointLight", star)
	light.Color      = star.Color
	light.Brightness = 2
	light.Range      = 8

	-- Offset relativo a la mano derecha
	local rightHand = rig and rig:FindFirstChild("RightHand")
	if not rightHand then
		warn("No encontré RightHand para colocar la estrella.")
		return star
	end
	local offsetCFrame = CFrame.new(0, -0.5, 0)

	-- Seguir la mano
	local conn
	conn = RunService.Heartbeat:Connect(function()
		if not star.Parent or not rightHand.Parent then
			conn:Disconnect()
			return
		end
		star.CFrame = rightHand.CFrame * offsetCFrame
	end)

	carryingStar = star
	return star
end

local function pickupStar(star: Part)
	StarEvents:FireServer("PickupStar", star)
	carryingStar = createLocalStar()
	isDelivering = true
	if rig then
		rig:SetAttribute(Constants.Attributes.CarryingStar, true)
	end
end

local function deliverStar()
	StarEvents:FireServer("DeliverStar", nil)
	if carryingStar then
		carryingStar:Destroy()
		carryingStar = nil
	end
	isDelivering = false
	if rig then
		rig:SetAttribute(Constants.Attributes.CarryingStar, false)
	end
end

----------------------------------------------------
-- Pathfinding y movimiento
----------------------------------------------------
local function isWaypointSeguro(waypointPos: Vector3, tolerance: number, sphereRadius: number): boolean
	local origin = waypointPos + Vector3.new(0, 5, 0)
	local direction = Vector3.new(0, -10, 0)
	local raycastParams = RaycastParams.new()
	raycastParams.IgnoreWater = true
	local result = workspace:Spherecast(origin, sphereRadius, direction, raycastParams)
	if result then
		return (result.Distance <= (5 + tolerance))
	else
		return false
	end
end

local function moveToPosition(destination: Vector3): boolean
	if not (hrp and humanoid) then
		warn("No se puede mover el follower: componentes faltantes.")
		return false
	end

	local pathParams = {
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = true,
		AgentJumpHeight = 10,
		AgentMaxSlope = 45,
	}

	local maxRetries = 3
	local retryCount = 0
	local pathFound = false

	while retryCount < maxRetries and not pathFound do
		local path = PathfindingService:CreatePath(pathParams)
		path.Blocked:Connect(function(blockedWaypointIndex)
			warn("Ruta bloqueada en waypoint:", blockedWaypointIndex, ". Recalculando...")
		end)
		path:ComputeAsync(hrp.Position, destination)

		if path.Status == Enum.PathStatus.Success then
			local waypoints = path:GetWaypoints()
			pathFound = true
			for i = 2, #waypoints do
				local wp = waypoints[i]
				if not isWaypointSeguro(wp.Position, 2, 2) then
					warn("Waypoint peligroso detectado. Recalculando ruta...")
					pathFound = false
					break
				end

				humanoid:MoveTo(wp.Position)
				local reached = humanoid.MoveToFinished:Wait()
				if not reached then
					warn("No se alcanzó el waypoint, recalculando ruta...")
					pathFound = false
					break
				end
			end

			if pathFound then
				return true
			end
		else
			warn("No se pudo calcular una ruta exitosa. Reintentando...")
		end

		retryCount += 1
		task.wait(0.5)
	end

	warn("Se alcanzó el número máximo de reintentos para mover al follower.")
	return false
end

local function followLogic()
	if not (rig and humanoid and hrp) then return end
	if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then return end

	local playerRoot = player.Character:FindFirstChild("HumanoidRootPart")

	-- Si está entregando estrella, prioridad al jugador
	if isDelivering then
		local distanceToPlayer = (hrp.Position - playerRoot.Position).Magnitude
		if distanceToPlayer <= STOP_DISTANCE then
			humanoid:MoveTo(hrp.Position)
			humanoid.WalkSpeed = 0
			deliverStar()
			return
		else
			if distanceToPlayer <= WALK_DISTANCE_THRESHOLD then
				humanoid.WalkSpeed = WALK_SPEED
			elseif distanceToPlayer <= JOG_DISTANCE_THRESHOLD then
				humanoid.WalkSpeed = JOG_SPEED
			else
				humanoid.WalkSpeed = RUN_SPEED
			end
			moveToPosition(playerRoot.Position)
			return
		end
	end

	-- Buscar estrella cercana
	local star = findNearestStar(followerUpgrades.Range)
	if star then
		local distToStar = (hrp.Position - star.Position).Magnitude
		if distToStar <= STOP_DISTANCE then
			humanoid:MoveTo(hrp.Position)
			humanoid.WalkSpeed = 0
			pickupStar(star)
			return
		else
			if distToStar <= WALK_DISTANCE_THRESHOLD then
				humanoid.WalkSpeed = WALK_SPEED
			elseif distToStar <= JOG_DISTANCE_THRESHOLD then
				humanoid.WalkSpeed = JOG_SPEED
			else
				humanoid.WalkSpeed = RUN_SPEED
			end
			moveToPosition(star.Position)
			return
		end
	else
		-- Seguir al jugador
		local distanceToPlayer = (hrp.Position - playerRoot.Position).Magnitude
		if distanceToPlayer <= STOP_DISTANCE then
			humanoid:MoveTo(hrp.Position)
			humanoid.WalkSpeed = 0
		else
			if distanceToPlayer <= WALK_DISTANCE_THRESHOLD then
				humanoid.WalkSpeed = WALK_SPEED
			elseif distanceToPlayer <= JOG_DISTANCE_THRESHOLD then
				humanoid.WalkSpeed = JOG_SPEED
			else
				humanoid.WalkSpeed = RUN_SPEED
			end
			moveToPosition(playerRoot.Position)
		end
	end
end

----------------------------------------------------
-- Regeneración de salud
----------------------------------------------------
task.spawn(function()
	while true do
		task.wait(1)
		if rig and humanoid and humanoid.Health > 0 then
			local regen = followerUpgrades.HealthRegen or 0
			humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + regen)
		end
	end
end)

----------------------------------------------------
-- Gestión de conexiones
----------------------------------------------------
local followerConnections = {}

local function cleanupFollowerConnections()
	for _, conn in ipairs(followerConnections) do
		if conn.Connected then
			conn:Disconnect()
		end
	end
	followerConnections = {}
end

----------------------------------------------------
-- Asignación del follower (evento del server)
----------------------------------------------------
AssignFollowerEvent.OnClientEvent:Connect(function(receivedRig)
	-- Si ya había un follower asignado, limpiar sus conexiones
	if rig and rig.Parent then
		cleanupFollowerConnections()
	end

	if not receivedRig then
		warn("[LocalFollower] Recibí un rig nil en AssignFollowerEvent.")
		return
	end

	-- 🔹 Esperar a que el atributo OwnerUserId exista/replice
	local ownerAttrName = Constants.Attributes.OwnerUserId
	local ownerId = receivedRig:GetAttribute(ownerAttrName)

	if not ownerId then
		receivedRig:GetAttributeChangedSignal(ownerAttrName):Wait()
		ownerId = receivedRig:GetAttribute(ownerAttrName)
	end

	if ownerId ~= player.UserId then
		warn("[LocalFollower] Follower recibido no es para este jugador. ownerId=",
			ownerId, " playerId=", player.UserId)
		return
	end

	-- A partir de aquí, sí es nuestro follower
	rig = receivedRig
	humanoid = rig:FindFirstChildWhichIsA("Humanoid")
	hrp = rig:WaitForChild("HumanoidRootPart")

	print("[LocalFollower] Follower asignado correctamente.")

	if humanoid then
		loadAnimations(humanoid)
		humanoid.WalkSpeed = followerUpgrades.Speed

		local runningConn = humanoid.Running:Connect(function(speed)
			updateAnimation(speed)
		end)
		table.insert(followerConnections, runningConn)
	end

	local heartbeatConn
	heartbeatConn = RunService.Heartbeat:Connect(function()
		if not (rig and rig.Parent) then
			heartbeatConn:Disconnect()
		else
			followLogic()
		end
	end)
	table.insert(followerConnections, heartbeatConn)
end)
