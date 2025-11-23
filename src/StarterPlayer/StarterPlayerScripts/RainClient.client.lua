-- RainClient: lluvia pegada a cámara con splashes locales.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local weatherFolder = ReplicatedStorage:WaitForChild("Weather", 10)
local currentWeather = weatherFolder and weatherFolder:WaitForChild("CurrentWeather", 5)

local emitterPart = Instance.new("Part")
emitterPart.Name = "RainCameraEmitter"
emitterPart.Size = Vector3.new(1, 1, 1)
emitterPart.Transparency = 1
emitterPart.Anchored = true
emitterPart.CanCollide = false
emitterPart.CanQuery = false
emitterPart.CanTouch = false
emitterPart.Parent = Workspace

local rainStraight = Instance.new("ParticleEmitter")
rainStraight.Name = "RainStraight"
rainStraight.Texture = "rbxassetid://1822883048"
rainStraight.Color = ColorSequence.new(Color3.fromRGB(190, 220, 255))
rainStraight.LightInfluence = 0.9
rainStraight.LightEmission = 0.05
rainStraight.Rate = 80
-- RainClient: advanced rain controller with occlusion-aware emitters.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local SoundService = game:GetService("SoundService")

local Rain = (function()
	local MIN_SIZE = Vector3.new(0.05,0.05,0.05)			-- Size of main emitter part when rain inactive

	local RAIN_DEFAULT_COLOR = Color3.new(1,1,1)			-- Default color3 of all rain elements
	local RAIN_DEFAULT_TRANSPARENCY = 0				-- Default transparency scale ratio of all rain elements
	local RAIN_DEFAULT_SPEEDRATIO = 1				-- Default speed scale ratio of falling rain effects
	local RAIN_DEFAULT_INTENSITYRATIO = 1				-- Default intensity ratio of all rain elements
	local RAIN_DEFAULT_LIGHTEMISSION = 0.05			-- Default LightEmission of all rain elements
	local RAIN_DEFAULT_LIGHTINFLUENCE = 0.9			-- Default LightInfluence of all rain elements
	local RAIN_DEFAULT_DIRECTION = Vector3.new(0,-1,0)		-- Default direction for rain to fall into

	local RAIN_TRANSPARENCY_T1 = .25				-- Define the shape (time-wise) of the transparency curves for emitters
	local RAIN_TRANSPARENCY_T2 = .75

	local RAIN_SCANHEIGHT = 1000				-- How many studs to scan up from camera position to determine whether occluded

	local RAIN_EMITTER_DIM_DEFAULT = 40			-- Size of emitter block to the side/up
	local RAIN_EMITTER_DIM_MAXFORWARD = 100			-- Size of emitter block forwards when looking at the horizon
	local RAIN_EMITTER_UP_MODIFIER = 20			-- Maximum vertical displacement of emitter (when looking fully up/down)

	local RAIN_SOUND_ASSET = "rbxassetid://1516791621"
	local RAIN_SOUND_BASEVOLUME = 0.2			-- Starting volume of rain sound effect when not occluded
	local RAIN_SOUND_FADEIN_TIME = 1			-- Tween in/out times for sound volume
	local RAIN_SOUND_FADEOUT_TIME = 1

	local RAIN_STRAIGHT_ASSET = "rbxassetid://1822883048"		-- Some properties of the straight rain particle effect
	local RAIN_STRAIGHT_ALPHA_LOW = 0.7			-- Minimum particle transparency for the straight rain emitter
	local RAIN_STRAIGHT_SIZE = NumberSequence.new(10)
	local RAIN_STRAIGHT_LIFETIME = NumberRange.new(0.8)
	local RAIN_STRAIGHT_MAX_RATE = 600			-- Maximum rate for the straight rain emitter
	local RAIN_STRAIGHT_MAX_SPEED = 60			-- Maximum speed for the straight rain emitter

	local RAIN_TOPDOWN_ASSET = "rbxassetid://1822856633"		-- Some properties of the top-down rain particle effect
	local RAIN_TOPDOWN_ALPHA_LOW = 0.85			-- Minimum particle transparency for the top-down rain emitter
	local RAIN_TOPDOWN_SIZE = NumberSequence.new {
		NumberSequenceKeypoint.new(0, 5.33, 2.75);
		NumberSequenceKeypoint.new(1, 5.33, 2.75);
	}
	local RAIN_TOPDOWN_LIFETIME = NumberRange.new(0.8)
	local RAIN_TOPDOWN_ROTATION = NumberRange.new(0,360)
	local RAIN_TOPDOWN_MAX_RATE = 600			-- Maximum rate for the top-down rain emitter
	local RAIN_TOPDOWN_MAX_SPEED = 60			-- Maximum speed for the top-down rain emitter

	local RAIN_SPLASH_ASSET = "rbxassetid://1822856633"			-- Some properties of the splash particle effect
	local RAIN_SPLASH_ALPHA_LOW = 0.6			-- Minimum particle transparency for the splash emitters
	local RAIN_SPLASH_SIZE = NumberSequence.new {
		NumberSequenceKeypoint.new(0, 0);
		NumberSequenceKeypoint.new(.4, 3);
		NumberSequenceKeypoint.new(1, 0);
	}
	local RAIN_SPLASH_LIFETIME = NumberRange.new(0.1, 0.15)
	local RAIN_SPLASH_ROTATION = NumberRange.new(0,360)
	local RAIN_SPLASH_NUM = 20				-- Amount of splashes per frame
	local RAIN_SPLASH_CORRECTION_Y = .5			-- Offset from impact position for visual reasons
	local RAIN_SPLASH_STRAIGHT_OFFSET_Y = 50			-- Offset against rain direction for straight rain particles from splash position
	local RAIN_NOSPLASH_STRAIGHT_OFFSET_Y_MIN = 20			-- Min/max vertical offset from camera height for straight rain particles
	local RAIN_NOSPLASH_STRAIGHT_OFFSET_Y_MAX = 100			-- when no splash position could be found (i.e. no floor at that XZ-column)

	local RAIN_OCCLUDED_MINSPEED = 70			-- Minimum speed for the occluded straight rain emitters
	local RAIN_OCCLUDED_MAXSPEED = 100			-- Maximum speed for the occluded straight rain emitters
	local RAIN_OCCLUDED_SPREAD = Vector2.new(10,10)			-- Spread angle for the occluded straight rain emitters
	local RAIN_OCCLUDED_MAXINTENSITY = 2			-- How many occluded straight rain particles are emitted for every splash for max intensity

	local RAIN_OCCLUDECHECK_OFFSET_Y = 500			-- Vertical offset from camera height to start scanning downward from for splashes
	local RAIN_OCCLUDECHECK_OFFSET_XZ_MIN = -100			-- Range of possible XZ offset values from camera XZ position for the splashes
	local RAIN_OCCLUDECHECK_OFFSET_XZ_MAX = 100
	local RAIN_OCCLUDECHECK_SCAN_Y = 550			-- Scan magnitude along rain path

	local RAIN_UPDATE_PERIOD = 6			-- Update the transparency of the main emitters + volume of rain inside every X frames

	local RAIN_VOLUME_SCAN_RADIUS = 35			-- Defining grid for checking how far the camera is away from a spot exposed to rain
	local RAIN_VOLUME_SCAN_GRID = {			-- Unit range grid for scanning how far away user is from rain space
		-- range 0.2, 4 pts
		Vector3.new(0.141421363, 0, 0.141421363);
		Vector3.new(-0.141421363, 0, 0.141421363);
		Vector3.new(-0.141421363, 0, -0.141421363);
		Vector3.new(0.141421363, 0, -0.141421363);
		-- range 0.4, 8 pts
		Vector3.new(0.400000006, 0, 0);
		Vector3.new(0.282842726, 0, 0.282842726);
		Vector3.new(2.44929371e-17, 0, 0.400000006);
		Vector3.new(-0.282842726, 0, 0.282842726);
		Vector3.new(-0.400000006, 0, 4.89858741e-17);
		Vector3.new(-0.282842726, 0, -0.282842726);
		Vector3.new(-7.34788045e-17, 0, -0.400000006);
		Vector3.new(0.282842726, 0, -0.282842726);
		-- range 0.6, 10 pts
		Vector3.new(0.600000024, 0, 0);
		Vector3.new(0.485410213, 0, 0.352671146);
		Vector3.new(0.185410202, 0, 0.570633948);
		Vector3.new(-0.185410202, 0, 0.570633948);
		Vector3.new(-0.485410213, 0, 0.352671146);
		Vector3.new(-0.600000024, 0, 7.34788112e-17);
		Vector3.new(-0.485410213, 0, -0.352671146);
		Vector3.new(-0.185410202, 0, -0.570633948);
		Vector3.new(0.185410202, 0, -0.570633948);
		Vector3.new(0.485410213, 0, -0.352671146);
		-- range 0.8, 12 pts
		Vector3.new(0.772740662, 0, 0.207055241);
		Vector3.new(0.565685451, 0, 0.565685451);
		Vector3.new(0.207055241, 0, 0.772740662);
		Vector3.new(-0.207055241, 0, 0.772740662);
		Vector3.new(-0.565685451, 0, 0.565685451);
		Vector3.new(-0.772740662, 0, 0.207055241);
		Vector3.new(-0.772740662, 0, -0.207055241);
		Vector3.new(-0.565685451, 0, -0.565685451);
		Vector3.new(-0.207055241, 0, -0.772740662);
		Vector3.new(0.207055241, 0, -0.772740662);
		Vector3.new(0.565685451, 0, -0.565685451);
		Vector3.new(0.772740662, 0, -0.207055241);
	}

	local CollisionMode = {
		None = 0;
		Whitelist = 1;
		Blacklist = 2;
		Function = 3;
	}

	local PlayersService = Players
	local TweenServiceLocal = TweenService
	local RunServiceLocal = RunService

	local GlobalModifier = Instance.new("NumberValue")		-- modifier for rain visibility for disabling/enabling over time span
	GlobalModifier.Value = 1				-- 0 = fully visible, 1 = invisible

	local connections = {}				-- Stores connections to RunService signals when enabled

	local disabled = true				-- Value to figure out whether we are moving towards a disabled state (useful during tweens)

	local rainDirection = RAIN_DEFAULT_DIRECTION			-- Direction that rain falls into

	local currentCeiling = nil			-- Y coordinate of ceiling (if present)

	local collisionMode = CollisionMode.None			-- Collision mode (from Rain.CollisionMode) for raycasting
	local collisionList = nil			-- Blacklist/whitelist for raycasting
	local collisionFunc = nil			-- Raycasting test function for when collisionMode == Rain.CollisionMode.Function

	local straightLowAlpha = 1			-- Current transparency for straight rain particles
	local topdownLowAlpha = 1			-- Current transparency for top-down rain particles
	local intensityOccludedRain = 0			-- Current intensity of occluded rain particles
	local numSplashes = 0			-- Current number of generated splashes per frame
	local volumeTarget = 0			-- Current (target of tween for) sound volume

	local v3 = Vector3.new
	local NSK010 = NumberSequenceKeypoint.new(0, 1, 0)
	local NSK110 = NumberSequenceKeypoint.new(1, 1, 0)

	local volumeScanGrid = {}			-- Pre-generate grid used for raining area distance scanning
	for _,v in pairs(RAIN_VOLUME_SCAN_GRID) do
		table.insert(volumeScanGrid, v * RAIN_VOLUME_SCAN_RADIUS)
	end
	table.sort(volumeScanGrid, function(a,b)			-- Optimization: sort from close to far away for fast evaluation if closeby
		return a.magnitude < b.magnitude
	end)

	local SoundGroup = Instance.new("SoundGroup")
	SoundGroup.Name = "__RainSoundGroup"
	SoundGroup.Volume = RAIN_SOUND_BASEVOLUME
	SoundGroup.Archivable = false

	local Sound = Instance.new("Sound")
	Sound.Name = "RainSound"
	Sound.Volume = volumeTarget
	Sound.SoundId = RAIN_SOUND_ASSET
	Sound.Looped = true
	Sound.SoundGroup = SoundGroup
	Sound.Parent = SoundGroup
	Sound.Archivable = false

	local Emitter do

		Emitter = Instance.new("Part")
		Emitter.Transparency = 1
		Emitter.Anchored = true
		Emitter.CanCollide = false
		Emitter.Locked = false
		Emitter.Archivable = false
		Emitter.TopSurface = Enum.SurfaceType.Smooth
		Emitter.BottomSurface = Enum.SurfaceType.Smooth
		Emitter.Name = "__RainEmitter"
		Emitter.Size = MIN_SIZE
		Emitter.Archivable = false

		local straight = Instance.new("ParticleEmitter")
		straight.Name = "RainStraight"
		straight.LightEmission = RAIN_DEFAULT_LIGHTEMISSION
		straight.LightInfluence = RAIN_DEFAULT_LIGHTINFLUENCE
		straight.Size = RAIN_STRAIGHT_SIZE
		straight.Texture = RAIN_STRAIGHT_ASSET
		straight.LockedToPart = true
		straight.Enabled = false
		straight.Lifetime = RAIN_STRAIGHT_LIFETIME
		straight.Rate = RAIN_STRAIGHT_MAX_RATE
		straight.Speed = NumberRange.new(RAIN_STRAIGHT_MAX_SPEED)
		straight.EmissionDirection = Enum.NormalId.Bottom
		straight.Parent = Emitter
		straight.Orientation = Enum.ParticleOrientation.FacingCameraWorldUp

		local topdown = Instance.new("ParticleEmitter")
		topdown.Name = "RainTopDown"
		topdown.LightEmission = RAIN_DEFAULT_LIGHTEMISSION
		topdown.LightInfluence = RAIN_DEFAULT_LIGHTINFLUENCE
		topdown.Size = RAIN_TOPDOWN_SIZE
		topdown.Texture = RAIN_TOPDOWN_ASSET
		topdown.LockedToPart = true
		topdown.Enabled = false
		topdown.Rotation = RAIN_TOPDOWN_ROTATION
		topdown.Lifetime = RAIN_TOPDOWN_LIFETIME
		topdown.Rate = RAIN_TOPDOWN_MAX_RATE
		topdown.Speed = NumberRange.new(RAIN_TOPDOWN_MAX_SPEED)
		topdown.EmissionDirection = Enum.NormalId.Bottom
		topdown.Parent = Emitter

	end

	local splashAttachments, rainAttachments do

		splashAttachments = {}
		rainAttachments = {}

		for i = 1, RAIN_SPLASH_NUM do

			local splashAttachment = Instance.new("Attachment")
			splashAttachment.Name = "__RainSplashAttachment"
			local splash = Instance.new("ParticleEmitter")
			splash.LightEmission = RAIN_DEFAULT_LIGHTEMISSION
			splash.LightInfluence = RAIN_DEFAULT_LIGHTINFLUENCE
			splash.Size = RAIN_SPLASH_SIZE
			splash.Texture = RAIN_SPLASH_ASSET
			splash.Rotation = RAIN_SPLASH_ROTATION
			splash.Lifetime = RAIN_SPLASH_LIFETIME
			splash.Transparency = NumberSequence.new {
				NSK010;
				NumberSequenceKeypoint.new(RAIN_TRANSPARENCY_T1, RAIN_SPLASH_ALPHA_LOW, 0);
				NumberSequenceKeypoint.new(RAIN_TRANSPARENCY_T2, RAIN_SPLASH_ALPHA_LOW, 0);
				NSK110;
			}
			splash.Enabled = false
			splash.Rate = 0
			splash.Speed = NumberRange.new(0)
			splash.Name = "RainSplash"
			splash.Parent = splashAttachment
			splashAttachment.Archivable = false
			table.insert(splashAttachments, splashAttachment)

			local rainAttachment = Instance.new("Attachment")
			rainAttachment.Name = "__RainOccludedAttachment"
			local straightOccluded = Emitter.RainStraight:Clone()
			straightOccluded.Speed = NumberRange.new(RAIN_OCCLUDED_MINSPEED, RAIN_OCCLUDED_MAXSPEED)
			straightOccluded.SpreadAngle = RAIN_OCCLUDED_SPREAD
			straightOccluded.LockedToPart = false
			straightOccluded.Enabled = false
			straightOccluded.Parent = rainAttachment
			local topdownOccluded = Emitter.RainTopDown:Clone()
			topdownOccluded.Speed = NumberRange.new(RAIN_OCCLUDED_MINSPEED, RAIN_OCCLUDED_MAXSPEED)
			topdownOccluded.SpreadAngle = RAIN_OCCLUDED_SPREAD
			topdownOccluded.LockedToPart = false
			topdownOccluded.Enabled = false
			topdownOccluded.Parent = rainAttachment
			rainAttachment.Archivable = false
			table.insert(rainAttachments, rainAttachment)

		end

	end

	local ignoreEmitterList = { Emitter }

	local raycastFunctions = {
		[CollisionMode.None] = function(ray, ignoreCharacter)
			return workspace:FindPartOnRayWithIgnoreList(ray, ignoreCharacter and {Emitter, PlayersService.LocalPlayer and PlayersService.LocalPlayer.Character} or ignoreEmitterList)
		end;
		[CollisionMode.Blacklist] = function(ray)
			return workspace:FindPartOnRayWithIgnoreList(ray, collisionList)
		end;
		[CollisionMode.Whitelist] = function(ray)
			return workspace:FindPartOnRayWithWhitelist(ray, collisionList)
		end;
		[CollisionMode.Function] = function(ray)
			local destination = ray.Origin + ray.Direction
			while ray.Direction.magnitude > 0.001 do
				local part, pos, norm, mat = workspace:FindPartOnRayWithIgnoreList(ray, ignoreEmitterList)
				if not part or collisionFunc(part) then
					return part, pos, norm, mat
				end
				local start = pos + ray.Direction.Unit * 0.001
				ray = Ray.new(start, destination - start)
			end
		end;
	}
	local raycast = raycastFunctions[collisionMode]

	local function connectLoop()

		local rand = Random.new()

		local inside = true
		local frame = RAIN_UPDATE_PERIOD

		table.insert(connections, RunServiceLocal.RenderStepped:connect(function()

			local currentCamera = workspace.CurrentCamera
			if not currentCamera then
				return
			end
			local part, position = raycast(Ray.new(currentCamera.CFrame.p, -rainDirection * RAIN_SCANHEIGHT), true)

			if (not currentCeiling or currentCamera.CFrame.p.y <= currentCeiling) and not part then

				if volumeTarget < 1 and not disabled then
					volumeTarget = 1
					TweenServiceLocal:Create(Sound, TweenInfo.new(.5), {Volume = 1}):Play()
				end

				frame = RAIN_UPDATE_PERIOD

				local t = math.abs(currentCamera.CFrame.lookVector:Dot(rainDirection))

				local center = currentCamera.CFrame.p
				local right = currentCamera.CFrame.lookVector:Cross(-rainDirection)
				right = right.magnitude > 0.001 and right.unit or -rainDirection
				local forward = rainDirection:Cross(right).unit

				Emitter.Size = v3(
					RAIN_EMITTER_DIM_DEFAULT,
					RAIN_EMITTER_DIM_DEFAULT,
					RAIN_EMITTER_DIM_DEFAULT + (1 - t)*(RAIN_EMITTER_DIM_MAXFORWARD - RAIN_EMITTER_DIM_DEFAULT)
				)

				Emitter.CFrame =
					CFrame.new(
						center.x, center.y, center.z,
						right.x, -rainDirection.x, forward.x,
						right.y, -rainDirection.y, forward.y,
						right.z, -rainDirection.z, forward.z
					)
					+ (1 - t) * currentCamera.CFrame.lookVector * Emitter.Size.Z/3
					- t * rainDirection * RAIN_EMITTER_UP_MODIFIER

				Emitter.RainStraight.Enabled = true
				Emitter.RainTopDown.Enabled = true

				inside = false

			else

				Emitter.RainStraight.Enabled = false
				Emitter.RainTopDown.Enabled = false

				inside = true

			end

		end))

		local signal = RunServiceLocal:IsRunning() and RunServiceLocal.Stepped or RunServiceLocal.RenderStepped
		table.insert(connections, signal:connect(function()

			frame = frame + 1

			if frame >= RAIN_UPDATE_PERIOD then

				local currentCamera = workspace.CurrentCamera
				if not currentCamera then
					return
				end
				local t = math.abs(currentCamera.CFrame.lookVector:Dot(rainDirection))

				local straightSequence = NumberSequence.new {
					NSK010;
					NumberSequenceKeypoint.new(RAIN_TRANSPARENCY_T1, (1 - t)*straightLowAlpha + t, 0);
					NumberSequenceKeypoint.new(RAIN_TRANSPARENCY_T2, (1 - t)*straightLowAlpha + t, 0);
					NSK110;
				}
				local topdownSequence = NumberSequence.new {
					NSK010;
					NumberSequenceKeypoint.new(RAIN_TRANSPARENCY_T1, t*topdownLowAlpha + (1 - t), 0);
					NumberSequenceKeypoint.new(RAIN_TRANSPARENCY_T2, t*topdownLowAlpha + (1 - t), 0);
					NSK110;
				}

				local mapped = currentCamera.CFrame:inverse() * (currentCamera.CFrame.p - rainDirection)
				local straightRotation = NumberRange.new(math.deg(math.atan2(-mapped.x, mapped.y)))

				if inside then

					for _,v in pairs(rainAttachments) do
						v.RainStraight.Transparency = straightSequence
						v.RainStraight.Rotation = straightRotation
						v.RainTopDown.Transparency = topdownSequence
					end

					if not disabled then

						local volume = 0

						if (not currentCeiling or currentCamera.CFrame.p.y <= currentCeiling) then

							local minDistance = RAIN_VOLUME_SCAN_RADIUS
							local rayDirection = -rainDirection * RAIN_SCANHEIGHT

							for i = 1, #volumeScanGrid do
								if not raycast(Ray.new(currentCamera.CFrame * volumeScanGrid[i], rayDirection), true) then
									minDistance = volumeScanGrid[i].magnitude
									break
								end
							end

							volume = 1 - minDistance / RAIN_VOLUME_SCAN_RADIUS

						end

						if math.abs(volume - volumeTarget) > .01 then
							volumeTarget = volume
							TweenServiceLocal:Create(Sound, TweenInfo.new(1), {Volume = volumeTarget}):Play()
						end

					end

				else

					Emitter.RainStraight.Transparency = straightSequence
					Emitter.RainStraight.Rotation = straightRotation
					Emitter.RainTopDown.Transparency = topdownSequence

				end

				frame = 0

			end

			local currentCamera = workspace.CurrentCamera
			if not currentCamera then
				return
			end
			local center = currentCamera.CFrame.p
			local right = currentCamera.CFrame.lookVector:Cross(-rainDirection)
			right = right.magnitude > 0.001 and right.unit or -rainDirection
			local forward = rainDirection:Cross(right).unit
			local transform = CFrame.new(
				center.x, center.y, center.z,
				right.x, -rainDirection.x, forward.x,
				right.y, -rainDirection.y, forward.y,
				right.z, -rainDirection.z, forward.z
			)
			local rayDirection = rainDirection * RAIN_OCCLUDECHECK_SCAN_Y

			for i = 1, numSplashes do

				local splashAttachment = splashAttachments[i]
				local rainAttachment = rainAttachments[i]

				local x = rand:NextNumber(RAIN_OCCLUDECHECK_OFFSET_XZ_MIN, RAIN_OCCLUDECHECK_OFFSET_XZ_MAX)
				local z = rand:NextNumber(RAIN_OCCLUDECHECK_OFFSET_XZ_MIN, RAIN_OCCLUDECHECK_OFFSET_XZ_MAX)
				local part, position, normal = raycast(Ray.new(transform * v3(x, RAIN_OCCLUDECHECK_OFFSET_Y, z), rayDirection))

				if part then

					splashAttachment.Position = position + normal * RAIN_SPLASH_CORRECTION_Y
					splashAttachment.RainSplash:Emit(1)

					if inside then

						local corrected = position - rainDirection * RAIN_SPLASH_STRAIGHT_OFFSET_Y
						if currentCeiling and corrected.Y > currentCeiling and rainDirection.Y < 0 then
							corrected = corrected + rainDirection * (currentCeiling - corrected.Y) / rainDirection.Y
						end
						rainAttachment.CFrame = transform - transform.p + corrected
						rainAttachment.RainStraight:Emit(intensityOccludedRain)
						rainAttachment.RainTopDown:Emit(intensityOccludedRain)

					end

				elseif inside then

					local corrected = transform * v3(x, rand:NextNumber(RAIN_NOSPLASH_STRAIGHT_OFFSET_Y_MIN, RAIN_NOSPLASH_STRAIGHT_OFFSET_Y_MAX), z)
					if currentCeiling and corrected.Y > currentCeiling and rainDirection.Y < 0 then
						corrected = corrected + rainDirection * (currentCeiling - corrected.Y) / rainDirection.Y
					end
					rainAttachment.CFrame = transform - transform.p + corrected
					rainAttachment.RainStraight:Emit(intensityOccludedRain)
					rainAttachment.RainTopDown:Emit(intensityOccludedRain)

				end

			end

		end))

	end

	local function disconnectLoop()
		if #connections > 0 then
			for _,v in pairs(connections) do
				v:disconnect()
			end
			connections = {}
		end
	end

	local function disableSound(tweenInfo)

		volumeTarget = 0
		local tween = TweenServiceLocal:Create(Sound, tweenInfo, {Volume = 0})
		tween.Completed:connect(function(state)
			if state == Enum.PlaybackState.Completed then
				Sound:Stop()
			end
			tween:Destroy()
		end)
		tween:Play()

	end

	local function disable()

		disconnectLoop()

		Emitter.RainStraight.Enabled = false
		Emitter.RainTopDown.Enabled = false
		Emitter.Size = MIN_SIZE

		if not disabled then
			disableSound(TweenInfo.new(RAIN_SOUND_FADEOUT_TIME))
		end

	end

	local function makeProperty(valueObjectClass, defaultValue, setter)
		local valueObject = Instance.new(valueObjectClass)
		if defaultValue then
			valueObject.Value = defaultValue
		end
		valueObject.Changed:connect(setter)
		setter(valueObject.Value)
		return valueObject
	end

	local Color = makeProperty("Color3Value", RAIN_DEFAULT_COLOR, function(value)

		local sequence = ColorSequence.new(value)

		Emitter.RainStraight.Color = sequence
		Emitter.RainTopDown.Color = sequence

		for _,v in pairs(splashAttachments) do
			v.RainSplash.Color = sequence
		end
		for _,v in pairs(rainAttachments) do
			v.RainStraight.Color = sequence
			v.RainTopDown.Color = sequence
		end

	end)

	local function updateTransparency(value)

		local opacity = (1 - value) * (1 - GlobalModifier.Value)
		local transparency = 1 - opacity

		straightLowAlpha = RAIN_STRAIGHT_ALPHA_LOW * opacity + transparency
		topdownLowAlpha = RAIN_TOPDOWN_ALPHA_LOW * opacity + transparency

		local splashSequence = NumberSequence.new {
			NSK010;
			NumberSequenceKeypoint.new(RAIN_TRANSPARENCY_T1, opacity*RAIN_SPLASH_ALPHA_LOW + transparency, 0);
			NumberSequenceKeypoint.new(RAIN_TRANSPARENCY_T2, opacity*RAIN_SPLASH_ALPHA_LOW + transparency, 0);
			NSK110;
		}

		for _,v in pairs(splashAttachments) do
			v.RainSplash.Transparency = splashSequence
		end

	end
	local Transparency = makeProperty("NumberValue", RAIN_DEFAULT_TRANSPARENCY, updateTransparency)
	GlobalModifier.Changed:connect(updateTransparency)

	local SpeedRatio = makeProperty("NumberValue", RAIN_DEFAULT_SPEEDRATIO, function(value)

		Emitter.RainStraight.Speed = NumberRange.new(value * RAIN_STRAIGHT_MAX_SPEED)
		Emitter.RainTopDown.Speed = NumberRange.new(value * RAIN_TOPDOWN_MAX_SPEED)

	end)

	local IntensityRatio = makeProperty("NumberValue", RAIN_DEFAULT_INTENSITYRATIO, function(value)

		Emitter.RainStraight.Rate = RAIN_STRAIGHT_MAX_RATE * value
		Emitter.RainTopDown.Rate = RAIN_TOPDOWN_MAX_RATE * value

		intensityOccludedRain = math.ceil(RAIN_OCCLUDED_MAXINTENSITY * value)
		numSplashes = RAIN_SPLASH_NUM * value

	end)

	local LightEmission = makeProperty("NumberValue", RAIN_DEFAULT_LIGHTEMISSION, function(value)

		Emitter.RainStraight.LightEmission = value
		Emitter.RainTopDown.LightEmission = value

		for _,v in pairs(rainAttachments) do
			v.RainStraight.LightEmission = value
			v.RainTopDown.LightEmission = value
		end
		for _,v in pairs(splashAttachments) do
			v.RainSplash.LightEmission = value
		end

	end)

	local LightInfluence = makeProperty("NumberValue", RAIN_DEFAULT_LIGHTINFLUENCE, function(value)

		Emitter.RainStraight.LightInfluence = value
		Emitter.RainTopDown.LightInfluence = value

		for _,v in pairs(rainAttachments) do
			v.RainStraight.LightInfluence = value
			v.RainTopDown.LightInfluence = value
		end
		for _,v in pairs(splashAttachments) do
			v.RainSplash.LightInfluence = value
		end

	end)

	local RainDirection = makeProperty("Vector3Value", RAIN_DEFAULT_DIRECTION, function(value)
		if value.magnitude > 0.001 then
			rainDirection = value.unit
		end
	end)

	local Rain = {}

	Rain.CollisionMode = CollisionMode

	function Rain:Enable(tweenInfo)

		if tweenInfo ~= nil and typeof(tweenInfo) ~= "TweenInfo" then
			error("bad argument #1 to 'Enable' (TweenInfo expected, got " .. typeof(tweenInfo) .. ")", 2)
		end

		disconnectLoop()

		Emitter.RainStraight.Enabled = true
		Emitter.RainTopDown.Enabled = true
		Emitter.Parent = workspace.CurrentCamera

		for i = 1, RAIN_SPLASH_NUM do
			splashAttachments[i].Parent = workspace.Terrain
			rainAttachments[i].Parent = workspace.Terrain
		end

		if RunServiceLocal:IsRunning() then
			SoundGroup.Parent = SoundService
		end

		connectLoop()

		if tweenInfo then
			TweenServiceLocal:Create(GlobalModifier, tweenInfo, {Value = 0}):Play()
		else
			GlobalModifier.Value = 0
		end

		if not Sound.Playing then
			Sound:Play()
			if Sound.TimeLength > 0 then
				Sound.TimePosition = math.random()*Sound.TimeLength
			end
		end

		disabled = false

	end

	function Rain:Disable(tweenInfo)

		if tweenInfo ~= nil and typeof(tweenInfo) ~= "TweenInfo" then
			error("bad argument #1 to 'Disable' (TweenInfo expected, got " .. typeof(tweenInfo) .. ")", 2)
		end

		if tweenInfo then
			local tween = TweenServiceLocal:Create(GlobalModifier, tweenInfo, {Value = 1})
			tween.Completed:connect(function(state)
				if state == Enum.PlaybackState.Completed then
					disable()
				end
				tween:Destroy()
			end)
			tween:Play()
			disableSound(tweenInfo)
		else
			GlobalModifier.Value = 1
			disable()
		end

		disabled = true

	end

	function Rain:SetColor(value, tweenInfo)

		if typeof(value) ~= "Color3" then
			error("bad argument #1 to 'SetColor' (Color3 expected, got " .. typeof(value) .. ")", 2)
		elseif tweenInfo ~= nil and typeof(tweenInfo) ~= "TweenInfo" then
			error("bad argument #2 to 'SetColor' (TweenInfo expected, got " .. typeof(tweenInfo) .. ")", 2)
		end

		if tweenInfo then
			TweenServiceLocal:Create(Color, tweenInfo, {Value = value}):Play()
		else
			Color.Value = value
		end

	end

	local function makeRatioSetter(methodName, valueObject)
		return function(_, value, tweenInfo)

			if typeof(value) ~= "number" then
				error("bad argument #1 to '" .. methodName .. "' (number expected, got " .. typeof(value) .. ")", 2)
			elseif tweenInfo ~= nil and typeof(tweenInfo) ~= "TweenInfo" then
				error("bad argument #2 to '" .. methodName .. "' (TweenInfo expected, got " .. typeof(tweenInfo) .. ")", 2)
			end

			value = math.clamp(value, 0, 1)

			if tweenInfo then
				TweenServiceLocal:Create(valueObject, tweenInfo, {Value = value}):Play()
			else
				valueObject.Value = value
			end

		end
	end

	Rain.SetTransparency = makeRatioSetter("SetTransparency", Transparency)
	Rain.SetSpeedRatio = makeRatioSetter("SetSpeedRatio", SpeedRatio)
	Rain.SetIntensityRatio = makeRatioSetter("SetIntensityRatio", IntensityRatio)
	Rain.SetLightEmission = makeRatioSetter("SetLightEmission", LightEmission)
	Rain.SetLightInfluence = makeRatioSetter("SetLightInfluence", LightInfluence)

	function Rain:SetVolume(volume, tweenInfo)

		if typeof(volume) ~= "number" then
			error("bad argument #1 to 'SetVolume' (number expected, got " .. typeof(volume) .. ")", 2)
		elseif tweenInfo ~= nil and typeof(tweenInfo) ~= "TweenInfo" then
			error("bad argument #2 to 'SetVolume' (TweenInfo expected, got " .. typeof(tweenInfo) .. ")", 2)
		end

		if tweenInfo then
			TweenServiceLocal:Create(SoundGroup, tweenInfo, {Volume = volume}):Play()
		else
			SoundGroup.Volume = volume
		end

	end

	function Rain:SetDirection(direction, tweenInfo)

		if typeof(direction) ~= "Vector3" then
			error("bad argument #1 to 'SetDirection' (Vector3 expected, got " .. typeof(direction) .. ")", 2)
		elseif tweenInfo ~= nil and typeof(tweenInfo) ~= "TweenInfo" then
			error("bad argument #2 to 'SetDirection' (TweenInfo expected, got " .. typeof(tweenInfo) .. ")", 2)
		end

		if not (direction.unit.magnitude > 0) then
			warn("Attempt to set rain direction to a zero-length vector, falling back on default direction = (" .. tostring(RAIN_DEFAULT_DIRECTION) .. ")")
			direction = RAIN_DEFAULT_DIRECTION
		end

		if tweenInfo then
			TweenServiceLocal:Create(RainDirection, tweenInfo, {Value = direction}):Play()
		else
			RainDirection.Value = direction
		end

	end

	function Rain:SetCeiling(ceiling)

		if ceiling ~= nil and typeof(ceiling) ~= "number" then
			error("bad argument #1 to 'SetCeiling' (number expected, got " .. typeof(ceiling) .. ")", 2)
		end

		currentCeiling = ceiling

	end

	function Rain:SetStraightTexture(asset)

		if typeof(asset) ~= "string" then
			error("bad argument #1 to 'SetStraightTexture' (string expected, got " .. typeof(asset) .. ")", 2)
		end

		Emitter.RainStraight.Texture = asset

		for _,v in pairs(rainAttachments) do
			v.RainStraight.Texture = asset
		end

	end

	function Rain:SetTopDownTexture(asset)

		if typeof(asset) ~= "string" then
			error("bad argument #1 to 'SetStraightTexture' (string expected, got " .. typeof(asset) .. ")", 2)
		end

		Emitter.RainTopDown.Texture = asset

		for _,v in pairs(rainAttachments) do
			v.RainTopDown.Texture = asset
		end

	end

	function Rain:SetSplashTexture(asset)

		if typeof(asset) ~= "string" then
			error("bad argument #1 to 'SetStraightTexture' (string expected, got " .. typeof(asset) .. ")", 2)
		end

		for _,v in pairs(splashAttachments) do
			v.RainSplash.Texture = asset
		end

	end

	function Rain:SetSoundId(asset)

		if typeof(asset) ~= "string" then
			error("bad argument #1 to 'SetSoundId' (string expected, got " .. typeof(asset) .. ")", 2)
		end

		Sound.SoundId = asset

	end

	function Rain:SetCollisionMode(mode, param)

		if mode == CollisionMode.None then

			collisionList = nil
			collisionFunc = nil

		elseif mode == CollisionMode.Blacklist then

			if typeof(param) == "Instance" then
				collisionList = {param, Emitter}
			elseif typeof(param) == "table" then
				for i = 1, #param do
					if typeof(param[i]) ~= "Instance" then
						error("bad argument #2 to 'SetCollisionMode' (blacklist contained a " .. typeof(param[i]) .. " on index " .. tostring(i) .. " which is not an Instance)", 2)
					end
				end
				collisionList = {Emitter}
				for i = 1, #param do
					table.insert(collisionList, param[i])
				end
			else
				error("bad argument #2 to 'SetCollisionMode (Instance or array of Instance expected, got " .. typeof(param) .. ")'", 2)
			end

			collisionFunc = nil

		elseif mode == CollisionMode.Whitelist then

			if typeof(param) == "Instance" then
				collisionList = {param}
			elseif typeof(param) == "table" then
				for i = 1, #param do
					if typeof(param[i]) ~= "Instance" then
						error("bad argument #2 to 'SetCollisionMode' (whitelist contained a " .. typeof(param[i]) .. " on index " .. tostring(i) .. " which is not an Instance)", 2)
					end
				end
				collisionList = {}
				for i = 1, #param do
					table.insert(collisionList, param[i])
				end
			else
				error("bad argument #2 to 'SetCollisionMode (Instance or array of Instance expected, got " .. typeof(param) .. ")'", 2)
			end

			collisionFunc = nil

		elseif mode == CollisionMode.Function then

			if typeof(param) ~= "function" then
				error("bad argument #2 to 'SetCollisionMode' (function expected, got " .. typeof(param) .. ")", 2)
			end

			collisionList = nil

			collisionFunc = param

		else
			error("bad argument #1 to 'SetCollisionMode (Rain.CollisionMode expected, got " .. typeof(param) .. ")'", 2)
		end

		collisionMode = mode
		raycast = raycastFunctions[mode]

	end

	return Rain

end)()

local function ensureCamera()
	local cam = Workspace.CurrentCamera
	if cam then
		return cam
	end
	repeat
		RunService.RenderStepped:Wait()
		cam = Workspace.CurrentCamera
	until cam
	return cam
end

local function findSkyRain()
	local map = Workspace:FindFirstChild("Map")
	if not map then
		return nil
	end
	local miscs = map:FindFirstChild("Miscs")
	if not miscs then
		return nil
	end
	local effectModel = miscs:FindFirstChild("EffectModel")
	local sky = (effectModel and effectModel:FindFirstChild("SkyParticles")) or miscs:FindFirstChild("SkyParticles")
	if not sky then
		return nil
	end
	return sky:FindFirstChild("IsRainy")
end

local function getSkyRainEmitter(previous)
	if previous and previous.Parent then
		return previous
	end
	return findSkyRain()
end

local skyRainEmitter = getSkyRainEmitter()

local function setSkyEmitter(state)
	skyRainEmitter = getSkyRainEmitter(skyRainEmitter)
	if skyRainEmitter then
		skyRainEmitter.Enabled = state
	end
end

local weatherFolder = ReplicatedStorage:WaitForChild("Weather", 10)
local currentWeather = weatherFolder and weatherFolder:WaitForChild("CurrentWeather", 5)

local function setRainEnabled(state)
	ensureCamera()
	if state then
		Rain:Enable(TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.Out))
	else
		Rain:Disable(TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.Out))
	end
	setSkyEmitter(state)
end

if currentWeather then
	currentWeather:GetPropertyChangedSignal("Value"):Connect(function()
		setRainEnabled(currentWeather.Value == "Rain")
	end)
	setRainEnabled(currentWeather.Value == "Rain")
else
	Rain:Disable()
end
