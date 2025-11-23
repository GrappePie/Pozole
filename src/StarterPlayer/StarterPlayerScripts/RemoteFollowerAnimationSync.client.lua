-- RemoteFollowerAnimationSync.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer

local syncEvent = ReplicatedStorage:WaitForChild("SyncFollowerAnimationEvent")

-- Tabla para guardar las animaciones cargadas para cada rig (clave: rig, valor: animTracks)
local remoteAnimTracks = {}

-- Función para cargar las animaciones en un rig remoto
local function loadRemoteAnimations(rig)
	local humanoid = rig:FindFirstChildWhichIsA("Humanoid")
	if humanoid then
		local animTracks = {}
		local defaultAnimations = {
			idle = "rbxassetid://507766666",
			walk = "rbxassetid://507777826",
			run  = "rbxassetid://507767714",
		}
		for name, assetId in pairs(defaultAnimations) do
			local animation = Instance.new("Animation")
			animation.AnimationId = assetId
			animTracks[name] = humanoid:LoadAnimation(animation)
		end
		remoteAnimTracks[rig] = animTracks
		return animTracks
	end
	return nil
end

syncEvent.OnClientEvent:Connect(function(ownerUserId, animState)
	-- Ignorar si es el follower local
	if ownerUserId == localPlayer.UserId then
		return
	end

	-- Buscar el follower correspondiente en la carpeta "Followers"
	local followersFolder = workspace:WaitForChild("Followers")
	for _, rig in ipairs(followersFolder:GetDescendants()) do
		if rig:IsA("Model") and rig:GetAttribute("OwnerUserId") == ownerUserId then
			local humanoid = rig:FindFirstChildWhichIsA("Humanoid")
			if humanoid then
				local tracks = remoteAnimTracks[rig] or loadRemoteAnimations(rig)
				if tracks then
					if animState == "idle" then
						if tracks.idle and not tracks.idle.IsPlaying then
							tracks.idle:Play()
						end
						if tracks.walk then tracks.walk:Stop() end
						if tracks.run then tracks.run:Stop() end
					elseif animState == "walk" then
						if tracks.walk and not tracks.walk.IsPlaying then
							tracks.walk:Play()
						end
						if tracks.idle then tracks.idle:Stop() end
						if tracks.run then tracks.run:Stop() end
					elseif animState == "run" then
						if tracks.run and not tracks.run.IsPlaying then
							tracks.run:Play()
						end
						if tracks.idle then tracks.idle:Stop() end
						if tracks.walk then tracks.walk:Stop() end
					end
				end
			end
		end
	end
end)
