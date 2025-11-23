-- PlayerDataManager.lua (ModuleScript en ServerScriptService)
local DataStoreService = game:GetService("DataStoreService")
local playerDataStore = DataStoreService:GetDataStore("PlayerDataStore")

local PlayerDataManager = {}

-- Tabla de valores por defecto para los datos del jugador
local defaultData = {
	stars = 0,
	upgrades = {
		Follower = {
			Range = 40,
			Speed = 8,
			Health = 100,
			RespawnTime = 10,
			-- Nuevos upgrades:
			HealthRegen = 1,  -- 1 punto de regeneración por segundo
			Luck = 0,         -- 0% de bonus inicialmente
			Costs = {
				Range = 1,
				Speed = 1,
				Health = 1,
				RespawnTime = 1,
				HealthRegen = 1,
				Luck = 1
			}
		},
		-- Más secciones para otros upgrades del jugador, si existen.
	}
}

-- Función recursiva para rellenar los campos faltantes en la tabla "data" con los de "defaults"
local function fillDefaults(defaults, data)
	for key, value in pairs(defaults) do
		if type(value) == "table" then
			if type(data[key]) ~= "table" then
				data[key] = value
			else
				fillDefaults(value, data[key])
			end
		else
			if data[key] == nil then
				data[key] = value
			end
		end
	end
	return data
end

-- Carga los datos del jugador, o retorna valores por defecto si no existen.
function PlayerDataManager:LoadPlayerData(player)
	local key = "Player_" .. player.UserId
	local data
	local success, err = pcall(function()
		data = playerDataStore:GetAsync(key)
	end)
	if success and data then
		-- Rellenar los campos faltantes usando la tabla de defaults.
		data = fillDefaults(defaultData, data)
		return data
	else
		-- Si no se obtuvieron datos, se retornan los valores por defecto.
		return defaultData
	end
end

-- Guarda los datos del jugador
function PlayerDataManager:SavePlayerData(player, data)
	local key = "Player_" .. player.UserId
	local success, err = pcall(function()
		playerDataStore:SetAsync(key, data)
	end)
	if not success then
		warn("Error al guardar datos de " .. player.Name .. ": " .. err)
	end
end

-- Función para obtener los datos en sesión o cargarlos si aún no existen
function PlayerDataManager:GetPlayerData(player)
	if not self[player] then
		self[player] = self:LoadPlayerData(player)
	end
	return self[player]
end

-- Función para actualizar datos y guardarlos
function PlayerDataManager:UpdatePlayerData(player, newData)
	self[player] = newData
	self:SavePlayerData(player, newData)
end

return PlayerDataManager
