-- ZombieInvasion.lua
-- ServerScriptService

local Lighting = game:GetService("Lighting")
local Players  = game:GetService("Players")

-- CONFIGURACIÓN
local ZOMBIE_FOLDER_NAME = "Zombies"
local NIGHT_START_HOUR   = 18
local NIGHT_END_HOUR     = 6
local SPAWN_INTERVAL     = 10    -- segundos entre zombies
local BASE_DAMAGE        = 10
local DAMAGE_COOLDOWN    = 2     -- segundos entre ataques al mismo jugador

-- IA
local IDLE_DISTANCE = 3
local WALK_DISTANCE = 20
local WALK_SPEED    = 8
local RUN_SPEED     = 16

-- Carpeta donde aparecen los zombies
local zombieFolder = workspace:FindFirstChild(ZOMBIE_FOLDER_NAME)
if not zombieFolder then
	zombieFolder = Instance.new("Folder", workspace)
	zombieFolder.Name = ZOMBIE_FOLDER_NAME
end

--------------------------------------------------------------------
-- Funciones Auxiliares
--------------------------------------------------------------------
local function isNightTime()
	local h = tonumber(string.sub(Lighting.TimeOfDay, 1, 2))
	return (h >= NIGHT_START_HOUR or h < NIGHT_END_HOUR)
end

local function getRandomFriendUserIdForPlayer(player)
	if not player then return nil end
	local ok, pages = pcall(function()
		return Players:GetFriendsAsync(player.UserId)
	end)
	if not ok or not pages then
		warn("Error al obtener amigos de "..player.Name)
		return nil
	end
	local friends = pages:GetCurrentPage()
	if #friends == 0 then return nil end
	return friends[math.random(1, #friends)].Id
end

local function createZombieRigFromUserId(userId)
	local ok, desc = pcall(function()
		return Players:GetHumanoidDescriptionFromUserId(userId)
	end)
	if not ok or not desc then
		return nil
	end

	local rig = Players:CreateHumanoidModelFromDescription(
		desc,
		Enum.HumanoidRigType.R15,
		Enum.AssetTypeVerification.Always
	)
	if not rig then return nil end
	
	local okName, username = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local baseName = okName and username or tostring(userId)
	
	rig.Name = "Zombie " .. baseName

	-- Pintar verde todas las partes
	for _, part in ipairs(rig:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Color = Color3.new(0, 1, 0)
		end
	end

	return rig
end

--------------------------------------------------------------------
-- Spawneo y Lógica Principal
--------------------------------------------------------------------
local function spawnZombie()
	local allPlayers = Players:GetPlayers()
	if #allPlayers == 0 then return end

	-- Elegir un jugador y obtener un friendId (o fallback al mismo jugador)
	local chosen   = allPlayers[1]
	local friendId = getRandomFriendUserIdForPlayer(chosen)
	local zombie   = createZombieRigFromUserId(friendId)
		or createZombieRigFromUserId(chosen.UserId)
	if not zombie then return end

	zombie.Parent = zombieFolder
	zombie:SetAttribute("State", "idle")

	-- Posición inicial
	local hrp = zombie:FindFirstChild("HumanoidRootPart")
	if hrp then
		hrp.CFrame = CFrame.new(
			math.random(-500, 500),
			10,
			math.random(-500, 500)
		)
	end

	local humanoid   = zombie:FindFirstChildWhichIsA("Humanoid")
	local lastDamage = {}

	if humanoid and hrp then
		-- IA / movimiento / cambios de State
		task.spawn(function()
			while zombie.Parent and isNightTime() do
				-- buscar jugador más cercano
				local nearest, dist = nil, math.huge
				for _, pl in ipairs(Players:GetPlayers()) do
					local root = pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
					if root then
						local d = (root.Position - hrp.Position).Magnitude
						if d < dist then
							dist, nearest = d, pl
						end
					end
				end

				-- decidir estado
				local state
				if dist < IDLE_DISTANCE then
					state = "idle"
				elseif dist <= WALK_DISTANCE then
					state = "walk"
				else
					state = "run"
				end

				-- aplicar estado y velocidad
				zombie:SetAttribute("State", state)
				if state == "idle" then
					humanoid.WalkSpeed = 0
				elseif state == "walk" then
					humanoid.WalkSpeed = WALK_SPEED
				else
					humanoid.WalkSpeed = RUN_SPEED
				end

				-- moverse si no está idle
				if humanoid.WalkSpeed > 0 and nearest and nearest.Character then
					local target = nearest.Character:FindFirstChild("HumanoidRootPart")
					if target then
						humanoid:MoveTo(target.Position)
					end
				end

				task.wait(2)
			end

			-- amaneció: destruye el zombie
			if zombie.Parent then
				zombie:Destroy()
			end
		end)

		-- Manejo de daño y animación de ataque
		for _, part in ipairs(zombie:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Touched:Connect(function(hit)
					if not hit or not hit.Parent then
						return
					end

					local character = hit.Parent
					local pl        = Players:GetPlayerFromCharacter(character)
					local charH     = character:FindFirstChildWhichIsA("Humanoid")

					if pl and charH then
						local now = tick()
						if not lastDamage[pl.UserId]
							or now - lastDamage[pl.UserId] >= DAMAGE_COOLDOWN then

							lastDamage[pl.UserId] = now
							zombie:SetAttribute("State", "attack")

							-- aplicar daño
							local buff = pl:GetAttribute("DefenseBuff") or 0
							local dmg  = BASE_DAMAGE * (1 - buff)
							charH:TakeDamage(dmg)
						end
					end
				end)
			end
		end

	end
end

-- Bucle infinito de día/noche
task.spawn(function()
	while true do
		if isNightTime() then
			spawnZombie()
			task.wait(SPAWN_INTERVAL)
		else
			-- de día, destruir todos los zombies
			for _, z in ipairs(zombieFolder:GetChildren()) do
				z:Destroy()
			end
			task.wait(5)
		end
	end
end)
