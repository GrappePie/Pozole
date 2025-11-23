-- ServerFollower.lua
--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local ServerScriptService = game:GetService("ServerScriptService")

local Constants = require(ReplicatedStorage:WaitForChild("Constants"))
local PlayerDataManager = require(ServerScriptService:WaitForChild("PlayerDataManager"))

-- Configuración de RemoteEvents
local AssignFollowerEvent = Instance.new("RemoteEvent")
AssignFollowerEvent.Name = "AssignFollowerEvent"
AssignFollowerEvent.Parent = ReplicatedStorage

local SyncFollowerAnimationEvent = Instance.new("RemoteEvent")
SyncFollowerAnimationEvent.Name = "SyncFollowerAnimationEvent"
SyncFollowerAnimationEvent.Parent = ReplicatedStorage

-- Función para obtener el UserId de YukiManju
local function getUserIdFromUsername(username: string): number?
	local success, userIdOrError = pcall(function()
		return Players:GetUserIdFromNameAsync(username)
	end)
	if success then
		return userIdOrError
	else
		warn("No se pudo obtener el UserId para el nombre de usuario:", username, userIdOrError)
		return nil
	end
end

local USERNAME = "YukiManju"
local USER_ID = getUserIdFromUsername(USERNAME)

if not USER_ID then
	warn("Script abortado: No se pudo determinar el UserId para el usuario:", USERNAME)
	return
end

-- Función para crear el rig del follower
local function spawnRigFromUserId(userId: number): Model?
	local success, descriptionOrError = pcall(function()
		return Players:GetHumanoidDescriptionFromUserId(userId)
	end)
	if not success or not descriptionOrError then
		warn("No se pudo obtener la HumanoidDescription para el userId:", userId, descriptionOrError)
		return nil
	end

	local description = descriptionOrError
	local newRig = Players:CreateHumanoidModelFromDescription(
		description,
		Enum.HumanoidRigType.R15,
		Enum.AssetTypeVerification.Always
	)
	newRig.Name = "YukiManjuFollower"

	-- Verificar/crear carpeta Followers
	local followersFolder = workspace:FindFirstChild("Followers")
	if not followersFolder then
		followersFolder = Instance.new("Folder")
		followersFolder.Name = "Followers"
		followersFolder.Parent = workspace
	end
	newRig.Parent = followersFolder

	-- Posicionar el rig
	local root = newRig:WaitForChild("HumanoidRootPart")
	root.CFrame = CFrame.new(0, 10, 0)
	root.Anchored = false

	local rigHumanoid = newRig:FindFirstChildWhichIsA("Humanoid")
	if rigHumanoid then
		rigHumanoid.DisplayName = " "
		rigHumanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.DisplayWhenDamaged
		rigHumanoid.NameDisplayDistance = 0
	end

	return newRig
end

-- Función para asignar el follower a un jugador
local function spawnFollowerForPlayer(player: Player)
	local rig = spawnRigFromUserId(USER_ID)
	if not rig then return end

	-- Asignar el network owner
	local hrp = rig:FindFirstChild("HumanoidRootPart")
	if hrp then
		hrp:SetNetworkOwner(player)
	end

	-- Usar la constante para marcar el rig
	rig:SetAttribute(Constants.Attributes.OwnerUserId, player.UserId)

	-- Obtener datos del jugador
	local pdata = PlayerDataManager:GetPlayerData(player)
	local respawnTime = 10
	if pdata and pdata.upgrades and pdata.upgrades.Follower and pdata.upgrades.Follower.RespawnTime then
		respawnTime = pdata.upgrades.Follower.RespawnTime
	end
	rig:SetAttribute(Constants.Attributes.RespawnTime, respawnTime)

	AssignFollowerEvent:FireClient(player, rig)

	-- Conectar el evento Died del humanoide
	local humanoid = rig:FindFirstChildWhichIsA("Humanoid")
	if humanoid then
		humanoid.Died:Connect(function()
			print("Follower de " .. player.Name .. " ha muerto.")
			local rt = rig:GetAttribute(Constants.Attributes.RespawnTime) or 10
			print("Reapareciendo en " .. rt .. " segundos...")
			wait(rt)
			if player.Parent then
				if rig and rig.Parent then
					rig:Destroy()
				end
				spawnFollowerForPlayer(player)
			else
				print("El jugador " .. player.Name .. " ya no está conectado; no se reaparece el follower.")
			end
		end)
	end
end

Players.PlayerAdded:Connect(function(player)
	spawnFollowerForPlayer(player)
end)

for _, player in ipairs(Players:GetPlayers()) do
	spawnFollowerForPlayer(player)
end

SyncFollowerAnimationEvent.OnServerEvent:Connect(function(player, animState)
	local ownerUserId = player.UserId
	SyncFollowerAnimationEvent:FireAllClients(ownerUserId, animState)
end)

local function onPlayerRemoving(player: Player)
	for _, model in ipairs(workspace:GetDescendants()) do
		if model:IsA("Model") and model:GetAttribute(Constants.Attributes.OwnerUserId) == player.UserId then
			local primaryPart = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
			if primaryPart then
				local explosion = Instance.new("Explosion")
				explosion.Position = primaryPart.Position
				explosion.BlastRadius = 10
				explosion.BlastPressure = 50000
				explosion.Parent = workspace
			end
			for _, part in ipairs(model:GetDescendants()) do
				if part:IsA("BasePart") then
					part:BreakJoints()
					part.Anchored = false
				end
			end
			Debris:AddItem(model, 5)
		end
	end
end

Players.PlayerRemoving:Connect(onPlayerRemoving)
