local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local Debris            = game:GetService("Debris")

local remote              = ReplicatedStorage:WaitForChild("KamehamehaRemote")
local chargeTemplate      = ReplicatedStorage:WaitForChild("KamehamehaCharge")
local chargeSoundTemplate = ReplicatedStorage:WaitForChild("Charge")      -- sonido inicial
local chargeLoopTemplate  = ReplicatedStorage:WaitForChild("ChargeLoop")  -- sonido en loop
local kameTemplate        = ReplicatedStorage:WaitForChild("Kamehameha")
local shootSoundTemplate  = ReplicatedStorage:FindFirstChild("Shoot") -- opcional
local Constants           = require(ReplicatedStorage:WaitForChild("Constants"))

local BASE_KAME_DAMAGE = 25
local HIT_COOLDOWN     = 0.25

local activeCharges = {}

----------------------------------------------------
-- Helpers combate
----------------------------------------------------
local function findHumanoidFromPart(part)
	local model = part:FindFirstAncestorOfClass("Model")
	if not model then return nil end
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum then
		return hum, model
	end
	return nil
end

local function classifyTarget(shooter, model)
	local zombieFolder    = workspace:FindFirstChild("Zombies")
	local followersFolder = workspace:FindFirstChild("Followers")

	if zombieFolder and model:IsDescendantOf(zombieFolder) then
		return "enemy"
	end

	if followersFolder and model:IsDescendantOf(followersFolder) then
		local ownerAttr = Constants.Attributes and Constants.Attributes.OwnerUserId
		if ownerAttr then
			local ownerId = model:GetAttribute(ownerAttr)
			if ownerId == shooter.UserId then
				return "ally"
			else
				return "enemy"
			end
		else
			return "ally"
		end
	end

	local pl = Players:GetPlayerFromCharacter(model)
	if pl then
		if pl == shooter then
			return "self"
		else
			return "ally"
		end
	end

	return "neutral"
end

----------------------------------------------------
--  Kamehameha principal
----------------------------------------------------
local function spawnKamehameha(player, power, shootDir)
	local character = player.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local kame = kameTemplate:Clone()
	kame.Name = "KamehamehaActive"
	kame.Parent = workspace

	local startFolder = kame:WaitForChild("Start")
	local endFolder   = kame:WaitForChild("End")

	local startPart = startFolder:FindFirstChild("Start")
		or startFolder:FindFirstChildWhichIsA("BasePart")

	local endMain = endFolder:FindFirstChild("End")
		or endFolder:FindFirstChildWhichIsA("BasePart")

	if not startPart or not endMain then
		warn("Kamehameha: falta Start o End")
		kame:Destroy()
		return
	end

	-- dirección final: la que manda el cliente, o LookVector si no viene
	local lookDir
	if shootDir and typeof(shootDir) == "Vector3" and shootDir.Magnitude > 0.001 then
		lookDir = shootDir.Unit
	else
		lookDir = hrp.CFrame.LookVector
	end

	-- origen usando manos
	local rightHand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	local leftHand  = character:FindFirstChild("LeftHand")  or character:FindFirstChild("Left Arm")

	local startPos
	if rightHand and leftHand then
		local midPos = (rightHand.Position + leftHand.Position) / 2
		startPos = midPos
			+ lookDir * 2.3
			+ hrp.CFrame.UpVector * 0.1
	else
		startPos = hrp.Position
			+ lookDir * 4
			+ hrp.CFrame.UpVector * 1.5
	end

	local startCF = CFrame.new(startPos, startPos + lookDir)

	if kame:IsA("Model") then
		kame.PrimaryPart = startPart
		kame:SetPrimaryPartCFrame(startCF)
	else
		kame.CFrame = startCF
	end

	-- escala según potencia
	local power01 = math.clamp(power or 0, 0, 1)
	local scale   = 0.7 + power01 * 1.3

	for _, d in ipairs(kame:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Size = d.Size * scale
		elseif d:IsA("ParticleEmitter") then
			d.Rate = d.Rate * (0.5 + power01 * 1.5)
		end
	end

	-- Partes del END
	local endParts   = {}
	local endOffsets = {}

	for _, part in ipairs(endFolder:GetDescendants()) do
		if part:IsA("BasePart") then
			table.insert(endParts, part)
			endOffsets[part] = endMain.CFrame:ToObjectSpace(part.CFrame)
		end
	end

	-- hitbox
	local hitbox = Instance.new("Part")
	hitbox.Name = "KameHitbox"
	hitbox.Anchored = true
	hitbox.CanCollide = false
	hitbox.Transparency = 1
	hitbox.Parent = kame

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = {kame, character}

	local lastHitTimes = {}

	local function setEndLength(length)
		local newEndPos = startPos + lookDir * length
		local newEndCF  = CFrame.new(newEndPos, newEndPos + lookDir)
		for _, part in ipairs(endParts) do
			part.CFrame = newEndCF * endOffsets[part]
		end

		local centerPos = (startPos + newEndPos) / 2
		local hbCF = CFrame.new(centerPos, centerPos + lookDir)

		local thickness = 4 * scale
		hitbox.Size   = Vector3.new(thickness, thickness, math.max(4 * scale, length))
		hitbox.CFrame = hbCF
	end

	local currentLength = 0
	setEndLength(currentLength)

	-- sonido disparo
	if shootSoundTemplate then
		local s = shootSoundTemplate:Clone()
		s.Parent = hrp
		s:Play()
		Debris:AddItem(s, s.TimeLength + 0.5)
	end

	local speed   = 120
	local life    = 1.8
	local elapsed = 0

	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		if not kame.Parent then
			conn:Disconnect()
			return
		end

		elapsed += dt
		if elapsed >= life then
			conn:Disconnect()
			kame:Destroy()
			return
		end

		currentLength += speed * dt
		setEndLength(currentLength)

		-- daño
		local now = tick()
		local parts = workspace:GetPartBoundsInBox(hitbox.CFrame, hitbox.Size / 2, overlapParams)

		for _, part in ipairs(parts) do
			if part:IsA("BasePart") then
				local hum, model = findHumanoidFromPart(part)
				if hum and model and hum.Health > 0 then
					local rel = classifyTarget(player, model)
					if rel == "enemy" then
						local last = lastHitTimes[hum] or 0
						if now - last >= HIT_COOLDOWN then
							lastHitTimes[hum] = now
							local dmg = BASE_KAME_DAMAGE * (0.5 + power01 * 1.5)
							hum:TakeDamage(dmg)
						end
					end
				end
			end
		end
	end)
end

----------------------------------------------------
--  Carga (Charge) compartida
----------------------------------------------------
local function startChargeServer(player)
	if activeCharges[player] then return end

	local character = player.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local rightHand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	local leftHand  = character:FindFirstChild("LeftHand")  or character:FindFirstChild("Left Arm")
	if not rightHand or not leftHand then return end

	local chargeModel = chargeTemplate:Clone()
	chargeModel.Parent = workspace

	local corePart    = chargeModel:WaitForChild("In")
	local waveEmitter = corePart:WaitForChild("Wave")

	if not chargeModel.PrimaryPart then
		chargeModel.PrimaryPart = corePart
	end

	for _, p in ipairs(chargeModel:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
		end
	end

	corePart.Size = Vector3.new(0.3, 0.3, 0.3)

	local sizeTween = TweenService:Create(
		corePart,
		TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{ Size = Vector3.new(1.5, 1.5, 1.5) }
	)
	sizeTween:Play()

	waveEmitter.Rate = 25
	waveEmitter.Enabled = true

	-- 🔊 Sonido inicial (Charge)
	local chargeSound = chargeSoundTemplate:Clone()
	chargeSound.Parent = hrp
	chargeSound.Looped = false
	chargeSound.Volume = 0
	chargeSound:Play()
	TweenService:Create(
		chargeSound,
		TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{ Volume = 1 }
	):Play()

	-- 🔊 Sonido de loop (ChargeLoop)
	local chargeLoopSound = chargeLoopTemplate:Clone()
	chargeLoopSound.Parent = hrp
	chargeLoopSound.Looped = true
	chargeLoopSound.Volume = 0
	chargeLoopSound.PlaybackSpeed = 1 -- ✅ velocidad normal

	local function startLoopIfStillCharging()
		local data = activeCharges[player]
		if not data or data.model ~= chargeModel then
			return -- ya dejó de cargar o se limpió
		end

		chargeLoopSound:Play()
		TweenService:Create(
			chargeLoopSound,
			TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
			{ Volume = 1 }
		):Play()
	end

	if chargeSound.TimeLength > 0 then
		local delayTime = math.max(chargeSound.TimeLength - 0.8, 0.1)
		task.delay(delayTime, startLoopIfStillCharging)
	else
		chargeSound.Ended:Connect(startLoopIfStillCharging)
	end

	local data = {
		model      = chargeModel,
		core       = corePart,
		emitter    = waveEmitter,
		tween      = sizeTween,
		sound      = chargeSound,
		loopSound  = chargeLoopSound,
		spin       = 0,
		startTime  = tick()
	}

	data.conn = RunService.Heartbeat:Connect(function(dt)
		if not chargeModel.Parent then
			data.conn:Disconnect()
			return
		end

		local c = player.Character
		if not c then return end
		local hrp2 = c:FindFirstChild("HumanoidRootPart")
		local rh   = c:FindFirstChild("RightHand") or c:FindFirstChild("Right Arm")
		local lh   = c:FindFirstChild("LeftHand")  or c:FindFirstChild("Left Arm")
		if not hrp2 or not rh or not lh then return end

		data.spin += dt * 3

		local midPos = (rh.Position + lh.Position) / 2
		local targetCF = CFrame.new(midPos, midPos + hrp2.CFrame.LookVector)
		targetCF = targetCF * CFrame.Angles(0, data.spin, 0)

		chargeModel:PivotTo(targetCF)
	end)

	activeCharges[player] = data
end

local function stopChargeServer(player, power, shootDir)
	local data = activeCharges[player]
	if not data then return end
	activeCharges[player] = nil

	local chargeTime = tick() - data.startTime
	local finalPower = power or math.clamp(chargeTime / 3, 0, 1)

	if data.tween then
		data.tween:Cancel()
	end

	if data.emitter then
		data.emitter:Emit(40)
		data.emitter.Enabled = false
	end

	if data.conn then
		data.conn:Disconnect()
	end

	if data.sound then
		local s = data.sound
		TweenService:Create(
			s,
			TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.In),
			{ Volume = 0 }
		):Play()
		Debris:AddItem(s, 0.3)
	end

	if data.loopSound then
		local ls = data.loopSound
		TweenService:Create(
			ls,
			TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.In),
			{ Volume = 0 }
		):Play()
		Debris:AddItem(ls, 0.3)
	end

	if data.model then
		Debris:AddItem(data.model, 0.5)
	end

	spawnKamehameha(player, finalPower, shootDir)
end

----------------------------------------------------
--  RemoteEvent handler
----------------------------------------------------
remote.OnServerEvent:Connect(function(player, action, arg1, arg2)
	if action == "StartCharge" then
		startChargeServer(player)
	elseif action == "StopCharge" then
		-- arg1 = power, arg2 = shootDir (Vector3 o nil)
		stopChargeServer(player, arg1, arg2)
	end
end)
