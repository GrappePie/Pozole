-- ZombieAnimator.lua
-- StarterPlayerScripts

local ANIM_IDS = {
	idle   = 10921344533,
	walk   = 10921355261,
	run    = 616163682,
	attack = 18524313628,
}

local zombieFolder = workspace:WaitForChild("Zombies")

-- Altera la animación según el atributo State
local function setupZombieAnimations(rig)
	if not rig:IsA("Model") then return end
	local humanoid = rig:FindFirstChildWhichIsA("Humanoid")
	if not humanoid then return end

	-- Crear Animator y cargar AnimationTracks
	local animator = Instance.new("Animator")
	animator.Parent = humanoid

	local tracks = {}
	for state, id in pairs(ANIM_IDS) do
		local anim = Instance.new("Animation")
		anim.Name        = state .. "Anim"
		anim.AnimationId = "rbxassetid://" .. id
		anim.Parent      = rig
		tracks[state]    = animator:LoadAnimation(anim)
	end

	-- Función interna para reproducir la pista
	local function applyState(state)
		-- detener todo primero
		for _, t in pairs(tracks) do
			t:Stop()
		end
		-- luego reproducir la deseada
		if tracks[state] then
			tracks[state]:Play()
		end
	end

	-- Escuchar cambios de atributo State
	rig:GetAttributeChangedSignal("State"):Connect(function()
		applyState(rig:GetAttribute("State"))
	end)

	-- Estado inicial
	local init = rig:GetAttribute("State")
	if init then
		applyState(init)
	end
end

-- Conectar a todos los zombies existentes
for _, rig in ipairs(zombieFolder:GetChildren()) do
	setupZombieAnimations(rig)
end
-- Y a los que lleguen después
zombieFolder.ChildAdded:Connect(setupZombieAnimations)
