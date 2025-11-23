-- ServerUpgrades.lua
-- Este script gestiona los upgrades del seguidor en el servidor,
-- integrando la persistencia mediante PlayerDataManager.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerDataManager = require(game:GetService("ServerScriptService"):WaitForChild("PlayerDataManager"))

-------------------------------------------------
-- RemoteEvent y RemoteFunction para los upgrades
-------------------------------------------------
local UpgradeFollowerEvent = Instance.new("RemoteEvent")
UpgradeFollowerEvent.Name = "UpgradeFollowerEvent"
UpgradeFollowerEvent.Parent = ReplicatedStorage

local GetInitialUpgrades = Instance.new("RemoteFunction")
GetInitialUpgrades.Name = "GetInitialUpgrades"
GetInitialUpgrades.Parent = ReplicatedStorage

-------------------------------------------------
-- Configuración de los upgrades
-------------------------------------------------
-- Definición de incrementos y aumentos de costo
local UpgradeConfig = {
	Range = { increment = 5, costIncrement = 1 },
	Speed = { increment = 2, costIncrement = 1 },
	Health = { increment = 20, costIncrement = 1 },
	RespawnTime = { decrement = 2, costIncrement = 1 },  -- Se reduce el tiempo de respawn.
	HealthRegen = { increment = 0.5, costIncrement = 1 },  -- Aumenta la regeneración de salud (ej. 0.5 puntos extra por upgrade)
	Luck = { increment = 1, costIncrement = 1 }          -- Aumenta el valor o probabilidad de bonus al recoger estrellas.
}

----------------------------------------------------------------
-- CARGA DE DATOS AL UNIRSE EL JUGADOR
----------------------------------------------------------------
Players.PlayerAdded:Connect(function(player)
	-- Se asume que ya existe un leaderstats con un IntValue "Stars"
	local leaderstats = player:WaitForChild("leaderstats")

	-- Cargar (o asignar valores por defecto) los datos persistentes usando PlayerDataManager.
	local pdata = PlayerDataManager:LoadPlayerData(player)
	-- Guarda los datos en el módulo para acceso rápido durante la sesión.
	PlayerDataManager[player] = pdata

	-- Actualizar el valor de "Stars" en leaderstats según lo guardado.
	local starsValue = leaderstats:FindFirstChild("Stars")
	if starsValue then
		starsValue.Value = pdata.stars or 0
	end

	print("[" .. player.Name .. "] se ha unido. Datos cargados:", pdata)

	-- Enviar los valores iniciales de los upgrades del seguidor a la GUI del jugador.
	-- Se asume que los datos de upgrades para el seguidor están en: pdata.upgrades.Follower
	local followerData = pdata.upgrades.Follower
	for upgradeType, _ in pairs(UpgradeConfig) do
		local value = followerData[upgradeType]
		local cost = followerData.Costs[upgradeType]
		UpgradeFollowerEvent:FireClient(player, upgradeType, value, cost)
	end
end)

----------------------------------------------------------------
-- GUARDADO DE DATOS AL SALIR
----------------------------------------------------------------
Players.PlayerRemoving:Connect(function(player)
	-- Antes de guardar, actualizamos la cantidad de estrellas desde leaderstats.
	local pdata = PlayerDataManager:GetPlayerData(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local starsValue = leaderstats:FindFirstChild("Stars")
		if starsValue then
			pdata.stars = starsValue.Value
		end
	end
	-- Guardar los datos persistentes.
	PlayerDataManager:SavePlayerData(player, pdata)
	-- Elimina la referencia en el módulo para liberar memoria.
	PlayerDataManager[player] = nil
end)

----------------------------------------------------------------
-- GESTIÓN DE LA COMPRA DE UPGRADES
----------------------------------------------------------------
UpgradeFollowerEvent.OnServerEvent:Connect(function(player, upgradeType)
	local pdata = PlayerDataManager:GetPlayerData(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then return end
	local starsValue = leaderstats:FindFirstChild("Stars")
	if not starsValue then return end

	local config = UpgradeConfig[upgradeType]
	if not config then
		warn("Tipo de upgrade inválido:", upgradeType)
		return
	end

	-- Trabajamos con los datos del seguidor en: pdata.upgrades.Follower
	local followerData = pdata.upgrades.Follower
	local currentCost = followerData.Costs[upgradeType]
	print("[" .. player.Name .. "] intenta mejorar " .. upgradeType .. " (Costo actual: " .. currentCost .. ") con " .. starsValue.Value .. " estrellas.")

	-- Verificar si el jugador tiene suficientes estrellas.
	if starsValue.Value >= currentCost then
		-- Descontar el costo.
		starsValue.Value = starsValue.Value - currentCost

		-- Actualizar el valor del upgrade.
		-- Para RespawnTime se reduce; para los demás se incrementa.
		if upgradeType == "RespawnTime" then
			followerData[upgradeType] = math.max(1, followerData[upgradeType] - config.decrement)
		else
			followerData[upgradeType] = followerData[upgradeType] + config.increment
		end

		-- Aumentar el costo para el siguiente upgrade.
		followerData.Costs[upgradeType] = currentCost + config.costIncrement

		print("[" .. player.Name .. "] mejoró " .. upgradeType .. ". Nuevo valor: " .. followerData[upgradeType] .. ". Nuevo costo: " .. followerData.Costs[upgradeType])

		-- Enviar la actualización al cliente.
		UpgradeFollowerEvent:FireClient(player, upgradeType, followerData[upgradeType], followerData.Costs[upgradeType])

		-- Actualizar y guardar los datos persistentes.
		PlayerDataManager:UpdatePlayerData(player, pdata)
	else
		print("[" .. player.Name .. "] no tiene suficientes estrellas para " .. upgradeType)
	end
end)

----------------------------------------------------------------
-- REMOTE FUNCTION PARA SOLICITAR DATOS INICIALES
----------------------------------------------------------------
GetInitialUpgrades.OnServerInvoke = function(player)
	local pdata = PlayerDataManager:GetPlayerData(player)
	local followerData = pdata.upgrades.Follower
	local data = {}
	for upgradeType, _ in pairs(UpgradeConfig) do
		data[upgradeType] = {
			value = followerData[upgradeType],
			cost = followerData.Costs[upgradeType]
		}
	end
	return data
end
