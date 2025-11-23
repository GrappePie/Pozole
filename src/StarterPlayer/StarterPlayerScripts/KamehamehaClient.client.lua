-- KamehamehaClient.lua

local Players           = game:GetService("Players")
local UIS               = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local player  = Players.LocalPlayer
local remote  = ReplicatedStorage:WaitForChild("KamehamehaRemote")
local mouse   = player:GetMouse()

-- Animaciones (Animation en ReplicatedStorage)
local animCharge = ReplicatedStorage:WaitForChild("PowerBlast_Charge")
local animShoot  = ReplicatedStorage:WaitForChild("PowerBlast_Shoot")

local char, humanoid
local chargeTrack, shootTrack

local charging          = false
local chargeStart       = 0
local originalWalkSpeed  = 16
local originalJumpPower  = 50
local originalJumpHeight = 7.2
local jumpingDisabled    = false

-- TIEMPO QUE DURA EL KAMEHAMEHA EN EL SERVER (debe coincidir con el server)
local KAME_LIFETIME = 1.8

----------------------------------------------------
-- helper: reproducir y congelar últimos frames
-- onFreeze (opcional) se llama justo al llegar al final
----------------------------------------------------
local function holdLastFrame(track, onFreeze)
	if not track then return end

	track.Looped = false
	track.TimePosition = 0
	track:Play()
	track:AdjustSpeed(1)

	local firedCallback = false
	local conn
	conn = RunService.Heartbeat:Connect(function()
		if not track or not track.IsPlaying then
			conn:Disconnect()
			return
		end

		local len = track.Length
		local t   = track.TimePosition

		-- Consideramos "últimos frames"
		if t >= len - 0.03 then
			if onFreeze and not firedCallback then
				firedCallback = true
				onFreeze()
			end

			track.TimePosition = len - 0.001
			track:AdjustSpeed(0) -- se queda en esa pose
			conn:Disconnect()
		end
	end)
end

----------------------------------------------------
-- helper: dirección hacia donde apunta el mouse
----------------------------------------------------
local function getAimDirection()
	if not char then return nil end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil end

	local hitCF = mouse.Hit
	if not hitCF then return nil end

	local hitPos = hitCF.Position
	local dir = hitPos - hrp.Position
	if dir.Magnitude < 0.001 then
		return nil
	end
	return dir.Unit, hitPos
end

----------------------------------------------------
-- helper: ¿puedo iniciar el Kamehameha ahora?
-- no en el aire, no mientras camina/corre
----------------------------------------------------
local function canStartKamehameha()
	if not humanoid or humanoid.Health <= 0 then
		return false
	end

	local state = humanoid:GetState()

	-- estados donde NO queremos permitir castear
	if state == Enum.HumanoidStateType.Jumping
		or state == Enum.HumanoidStateType.Freefall
		or state == Enum.HumanoidStateType.FallingDown
		or state == Enum.HumanoidStateType.Climbing
	then
		return false
	end

	-- si se está moviendo (caminando/corriendo), tampoco
	if humanoid.MoveDirection.Magnitude > 0.1 then
		return false
	end

	return true
end

----------------------------------------------------
-- Preparar character
----------------------------------------------------
local function setupCharacter()
	char     = player.Character or player.CharacterAdded:Wait()
	humanoid = char:WaitForChild("Humanoid")

	chargeTrack = humanoid:LoadAnimation(animCharge)
	shootTrack  = humanoid:LoadAnimation(animShoot)

	originalWalkSpeed  = humanoid.WalkSpeed
	originalJumpPower  = humanoid.JumpPower
	originalJumpHeight = humanoid.JumpHeight
end

setupCharacter()
player.CharacterAdded:Connect(setupCharacter)

----------------------------------------------------
-- Iniciar carga (F down)
----------------------------------------------------
local function startCharge()
	if charging then return end
	if not humanoid then return end

	-- 🔹 si está en el aire o caminando/corriendo, NO castear
	if not canStartKamehameha() then
		return
	end

	charging    = true
	chargeStart = tick()

	-- bloquear movimiento y salto durante la carga
	humanoid.WalkSpeed  = 0
	humanoid.JumpPower  = 0
	humanoid.JumpHeight = 0
	humanoid.Jump       = false
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	jumpingDisabled = true

	-- parar otras anims (idle, walk, etc.)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
			if track ~= chargeTrack and track ~= shootTrack then
				track:Stop(0.2)
			end
		end
	end

	-- Reproducimos PowerBlast_Charge y SOLO cuando llega a los últimos frames
	-- mandamos StartCharge para que aparezca la esfera
	holdLastFrame(chargeTrack, function()
		if charging then
			remote:FireServer("StartCharge")
		end
	end)
end

----------------------------------------------------
-- Terminar carga / disparar (F up)
----------------------------------------------------
local function stopCharge()
	if not charging then return end
	charging = false

	local chargeTime = tick() - chargeStart
	local power = math.clamp(chargeTime / 3, 0, 1)

	-- por si la de carga seguía a medias
	if chargeTrack and chargeTrack.IsPlaying then
		chargeTrack:Stop(0.1)
	end

	-- calculamos la dirección de disparo hacia el mouse
	local aimDir, _ = getAimDirection()

	-- girar al personaje hacia esa dirección (horizontalmente)
	if aimDir and char then
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if hrp then
			local flatLook = Vector3.new(aimDir.X, 0, aimDir.Z)
			if flatLook.Magnitude > 0.001 then
				flatLook = flatLook.Unit
				local lookTarget = hrp.Position + flatLook
				hrp.CFrame = CFrame.new(hrp.Position, lookTarget)
			end
		end
	end

	-- PowerBlast_Shoot: al llegar a sus últimos frames disparamos el rayo
	holdLastFrame(shootTrack, function()
		-- mandamos potencia y dirección (puede ser nil → server usa LookVector)
		remote:FireServer("StopCharge", power, aimDir)

		-- cuando el rayo ya se apagó, soltamos la pose y el movimiento/salto
		task.delay(KAME_LIFETIME, function()
			if shootTrack then
				shootTrack:AdjustSpeed(1)
				shootTrack:Stop(0.2)
			end

			if humanoid then
				humanoid.WalkSpeed  = originalWalkSpeed
				humanoid.JumpPower  = originalJumpPower
				humanoid.JumpHeight = originalJumpHeight

				if jumpingDisabled then
					humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
					jumpingDisabled = false
				end
			end
		end)
	end)
end

----------------------------------------------------
-- Input
----------------------------------------------------
UIS.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.KeyCode == Enum.KeyCode.F then
		startCharge()
	end
end)

UIS.InputEnded:Connect(function(input, gpe)
	if input.KeyCode == Enum.KeyCode.F then
		stopCharge()
	end
end)
