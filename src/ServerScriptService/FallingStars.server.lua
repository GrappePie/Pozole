local starDuration = 15  -- Duración en segundos que las estrellas estarán en el mapa antes de desaparecer
local starSpawnInterval = 0.1  -- Intervalo en segundos entre la aparición de nuevas estrellas

-- Modelo base de la estrella
local starModel = Instance.new("Part")
starModel.Size = Vector3.new(1, 1, 1)
starModel.Shape = Enum.PartType.Ball
starModel.Material = Enum.Material.Neon
starModel.BrickColor = BrickColor.new("Bright yellow")
starModel.Anchored = false  -- Permitir que la física de Roblox actúe sobre la estrella
starModel.CanCollide = true  -- Permitir colisiones
starModel.Parent = game.ServerStorage  -- Guardar el modelo base en ServerStorage

local function createStar()
    local star = starModel:Clone()
    star.Position = Vector3.new(
        math.random(-500, 500),  -- Posición X aleatoria
        100,                     -- Altura desde la que caerá la estrella
        math.random(-500, 500)   -- Posición Z aleatoria
    )
    star.Parent = workspace

    -- Crear dos attachments en la estrella para definir la posición de la estela.
    local attachment0 = Instance.new("Attachment")
    attachment0.Name = "Attachment0"
    attachment0.Position = Vector3.new(0, 0.5, 0)  -- Por ejemplo, en la parte superior de la estrella
    attachment0.Parent = star

    local attachment1 = Instance.new("Attachment")
    attachment1.Name = "Attachment1"
    attachment1.Position = Vector3.new(0, -0.5, 0)  -- Por ejemplo, en la parte inferior de la estrella
    attachment1.Parent = star

    -- Crear el objeto Trail y asignarle los attachments
    local trail = Instance.new("Trail")
    trail.Attachment0 = attachment0
    trail.Attachment1 = attachment1

    -- Configurar propiedades del Trail para personalizar el efecto
    trail.Lifetime = 1                   -- Duración en segundos de cada segmento de la estela
    trail.WidthScale = NumberSequence.new(1)  -- Escala de la anchura (puedes usar NumberSequence para que varíe en el tiempo)
    trail.Color = ColorSequence.new(Color3.new(1, 1, 0))  -- Color amarillo (puedes ajustar la secuencia de colores)
    trail.Transparency = NumberSequence.new(0, 1)         -- Inicia opaco y se vuelve transparente
    trail.FaceCamera = true              -- Hace que la estela siempre mire a la cámara (opcional)
    trail.Parent = star                  -- Añadir el trail a la estrella para que se mueva con ella

    -- Programar la destrucción de la estrella (y, por ende, del trail) después de 'starDuration' segundos
    task.delay(starDuration, function()
        if star then
            star:Destroy()
        end
    end)
end

-- Generar estrellas en intervalos regulares
while true do
    createStar()
    task.wait(starSpawnInterval)
end
