-- DayNightCycle.lua
-- Coloca este script en ServerScriptService

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

-- CONFIGURACIÓN DEL CICLO
-- Duración en segundos que tomará un ciclo completo (24 horas virtuales)
local cycleLengthInSeconds = 600  -- Ejemplo: 600 segundos = 10 minutos para un ciclo completo

-- Hora de inicio (en formato decimal, 0 a 24). Por ejemplo, 6 = 6:00 AM
local currentTime = 18

-- Calcula cuántas "horas virtuales" avanzamos por segundo real
local hoursPerSecond = 24 / cycleLengthInSeconds

-- Función para convertir la hora decimal a una cadena en formato "HH:MM:SS"
local function formatTime(timeDecimal)
	local hour = math.floor(timeDecimal)
	local minute = math.floor((timeDecimal - hour) * 60)
	local second = math.floor((((timeDecimal - hour) * 60) - minute) * 60)
	return string.format("%02d:%02d:%02d", hour, minute, second)
end

-- (Opcional) Función para ajustar propiedades de Lighting según la hora
local function updateLightingProperties(timeDecimal)
	-- Ejemplo: Cambiar el brillo según la hora del día.
	-- Puedes personalizar estas condiciones y valores.
	if timeDecimal >= 6 and timeDecimal < 18 then
		-- Día: más brillante
		Lighting.Brightness = 2
		Lighting.Ambient = Color3.fromRGB(180, 180, 180)
	else
		-- Noche: menos brillante
		Lighting.Brightness = 0.5
		Lighting.Ambient = Color3.fromRGB(50, 50, 100)
	end
end

-- Actualiza el ciclo en cada frame
RunService.Heartbeat:Connect(function(delta)
	-- Incrementa la hora virtual según el delta y la velocidad configurada
	currentTime = currentTime + delta * hoursPerSecond
	if currentTime >= 24 then
		currentTime = currentTime - 24  -- Reinicia el ciclo
	end

	-- Actualiza Lighting.TimeOfDay con el formato adecuado
	Lighting.TimeOfDay = formatTime(currentTime)

	-- (Opcional) Actualiza otras propiedades de Lighting según la hora
	updateLightingProperties(currentTime)
end)
