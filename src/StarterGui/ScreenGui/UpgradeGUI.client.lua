local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UpgradeFollowerEvent = ReplicatedStorage:WaitForChild("UpgradeFollowerEvent")
local GetInitialUpgrades = ReplicatedStorage:WaitForChild("GetInitialUpgrades")

-- Referencia al contenedor principal de la GUI de upgrades
local parentGui = script.Parent
local frame = parentGui:WaitForChild("Frame")
frame.Visible = false

local btnShowUpgrades = parentGui:WaitForChild("btnShowUpgrades")

-- Botones y labels existentes...
local btnSpeed = frame:WaitForChild("btnSpeed")
local btnRange = frame:WaitForChild("btnRange")
local btnHealth = frame:WaitForChild("btnHealth")
local btnRespawn = frame:WaitForChild("btnRespawn")

local labelSpeed = frame:WaitForChild("labelSpeed")
local labelRange = frame:WaitForChild("labelRange")
local labelHealth = frame:WaitForChild("labelHealth")
local labelRespawn = frame:WaitForChild("labelRespawn")

-- Nuevos botones y labels para HealthRegen y Luck:
local btnHealthRegen = frame:WaitForChild("btnHealthRegen")
local btnLuck = frame:WaitForChild("btnLuck")

local labelHealthRegen = frame:WaitForChild("labelHealthRegen")
local labelLuck = frame:WaitForChild("labelLuck")

-- Función para actualizar la GUI con los datos recibidos.
local function updateGUI(data)
	if data then
		if data.Speed then
			labelSpeed.Text = "Current Speed: " .. data.Speed.value
			btnSpeed.Text = "Upgrade Speed: " .. data.Speed.cost
		end
		if data.Range then
			labelRange.Text = "Current Range: " .. data.Range.value
			btnRange.Text = "Upgrade Range: " .. data.Range.cost
		end
		if data.Health then
			labelHealth.Text = "Current Health: " .. data.Health.value
			btnHealth.Text = "Upgrade Health: " .. data.Health.cost
		end
		if data.RespawnTime then
			labelRespawn.Text = "Current Respawn: " .. data.RespawnTime.value
			btnRespawn.Text = "Upgrade Respawn: " .. data.RespawnTime.cost
		end
		-- Actualizar los nuevos upgrades:
		if data.HealthRegen then
			labelHealthRegen.Text = "Current Health Regen: " .. data.HealthRegen.value
			btnHealthRegen.Text = "Upgrade Health Regen: " .. data.HealthRegen.cost
		end
		if data.Luck then
			labelLuck.Text = "Current Luck: " .. data.Luck.value
			btnLuck.Text = "Upgrade Luck: " .. data.Luck.cost
		end
	end
end

-- Alternar visibilidad del frame y actualizar la GUI.
btnShowUpgrades.MouseButton1Click:Connect(function()
	if frame.Visible then
		frame.Visible = false
	else
		local initialData = GetInitialUpgrades:InvokeServer()
		updateGUI(initialData)
		frame.Visible = true
	end
end)

-- Conexiones para los botones de upgrade existentes:
btnSpeed.MouseButton1Click:Connect(function()
	print("Upgrade Speed button pressed")
	UpgradeFollowerEvent:FireServer("Speed")
end)
btnRange.MouseButton1Click:Connect(function()
	print("Upgrade Range button pressed")
	UpgradeFollowerEvent:FireServer("Range")
end)
btnHealth.MouseButton1Click:Connect(function()
	print("Upgrade Health button pressed")
	UpgradeFollowerEvent:FireServer("Health")
end)
btnRespawn.MouseButton1Click:Connect(function()
	print("Upgrade Respawn button pressed")
	UpgradeFollowerEvent:FireServer("RespawnTime")
end)

-- Conexiones para los nuevos botones:
btnHealthRegen.MouseButton1Click:Connect(function()
	print("Upgrade HealthRegen button pressed")
	UpgradeFollowerEvent:FireServer("HealthRegen")
end)
btnLuck.MouseButton1Click:Connect(function()
	print("Upgrade Luck button pressed")
	UpgradeFollowerEvent:FireServer("Luck")
end)

-- Actualización de la GUI cuando se recibe una actualización del servidor.
UpgradeFollowerEvent.OnClientEvent:Connect(function(upgradeType, newValue, newCost)
	print("Recibí actualización para", upgradeType, newValue, newCost)
	if upgradeType == "Speed" then
		labelSpeed.Text = "Current Speed: " .. newValue
		btnSpeed.Text = "Upgrade Speed: " .. newCost
	elseif upgradeType == "Range" then
		labelRange.Text = "Current Range: " .. newValue
		btnRange.Text = "Upgrade Range: " .. newCost
	elseif upgradeType == "Health" then
		labelHealth.Text = "Current Health: " .. newValue
		btnHealth.Text = "Upgrade Health: " .. newCost
	elseif upgradeType == "RespawnTime" then
		labelRespawn.Text = "Current Respawn: " .. newValue
		btnRespawn.Text = "Upgrade Respawn: " .. newCost
	elseif upgradeType == "HealthRegen" then
		labelHealthRegen.Text = "Current Health Regen: " .. newValue
		btnHealthRegen.Text = "Upgrade Health Regen: " .. newCost
	elseif upgradeType == "Luck" then
		labelLuck.Text = "Current Luck: " .. newValue
		btnLuck.Text = "Upgrade Luck: " .. newCost
	end
end)
