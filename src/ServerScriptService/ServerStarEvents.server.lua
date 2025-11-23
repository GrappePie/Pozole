-- ServerStarEvents (Server Script)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerDataManager = require(game:GetService("ServerScriptService"):WaitForChild("PlayerDataManager"))

local StarEvents = Instance.new("RemoteEvent")
StarEvents.Name = "StarEvents"
StarEvents.Parent = ReplicatedStorage

-- Configuración rápida de Leaderstats para cada jugador (opcional)
Players.PlayerAdded:Connect(function(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local starsValue = Instance.new("IntValue")
	starsValue.Name = "Stars"
	starsValue.Value = 0
	starsValue.Parent = leaderstats
end)

StarEvents.OnServerEvent:Connect(function(player, action, star, _)
	if action == "PickupStar" then
		if star and star.Parent == workspace then
			star:Destroy()
			print("["..player.Name.."] Follower recogió la estrella en el servidor.")
		end

	elseif action == "DeliverStar" then
		local leaderstats = player:FindFirstChild("leaderstats")
		if leaderstats then
			local starsVal = leaderstats:FindFirstChild("Stars")
			if starsVal then
				-- Obtiene el valor de Luck directamente desde los datos persistentes.
				local pdata = PlayerDataManager:GetPlayerData(player)
				local luckValue = pdata.upgrades.Follower.Luck or 0

				-- Por defecto se suma 1 estrella.
				local totalValue = 1

				-- Genera un número aleatorio entre 0 y 100.
				local chance = math.random(0, 100)
				-- Si el valor aleatorio es menor o igual al Luck (porcentaje), se otorga 1 estrella extra.
				if chance <= luckValue then
					totalValue = totalValue + 1
				end

				starsVal.Value = starsVal.Value + totalValue
				print("["..player.Name.."] Follower entregó la estrella. Se suman " .. tostring(totalValue) .. " al contador. (Chance: " .. chance .. " | Luck: " .. luckValue .. ")")
			end
		end
	end
end)
