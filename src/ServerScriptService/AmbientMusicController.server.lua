local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Requiere el módulo (ajusta la ruta según donde lo hayas colocado)
local AmbientMusicControllerModule = require(ReplicatedStorage:WaitForChild("AmbientMusicControllerModule"))

-- Asumimos que tus sonidos están en SoundService -> Audio -> Players -> Ambience
local ambienceFolder = SoundService:WaitForChild("Audio"):WaitForChild("Players"):WaitForChild("Ambience")

-- Inicia la reproducción de ambientación
spawn(function()
	AmbientMusicControllerModule:PlayRandomAmbience(ambienceFolder)
end)
