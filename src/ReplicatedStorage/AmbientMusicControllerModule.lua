local AmbientMusicControllerModule = {}

function AmbientMusicControllerModule:PlayRandomAmbience(folder)
	-- Recoge los sonidos en la carpeta
	local sounds = {}
	for _, obj in ipairs(folder:GetChildren()) do
		if obj:IsA("Sound") then
			table.insert(sounds, obj)
		end
	end

	if #sounds == 0 then
		warn("No se encontraron sonidos en la carpeta de ambientación")
		return
	end

	while true do
		local chosenSound = sounds[math.random(1, #sounds)]
		chosenSound:Play()
		chosenSound.Ended:Wait()  -- Espera a que termine para reproducir otro
	end
end

return AmbientMusicControllerModule
