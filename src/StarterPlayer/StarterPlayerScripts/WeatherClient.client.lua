-- WeatherClient.client.lua
-- Muestra el clima actual y notifica cambios al jugador.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local weatherFolder = ReplicatedStorage:WaitForChild("Weather")
local currentWeather = weatherFolder:WaitForChild("CurrentWeather")
local weatherChanged = weatherFolder:WaitForChild("WeatherChanged")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "WeatherHud"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local label = Instance.new("TextLabel")
label.Name = "WeatherLabel"
label.AnchorPoint = Vector2.new(0, 0)
label.BackgroundColor3 = Color3.fromRGB(15, 18, 25)
label.BackgroundTransparency = 0.2
label.BorderSizePixel = 0
label.Position = UDim2.new(0, 20, 0, 20)
label.Size = UDim2.new(0, 220, 0, 30)
label.Font = Enum.Font.GothamBold
label.TextScaled = true
label.TextColor3 = Color3.fromRGB(235, 235, 235)
label.TextStrokeTransparency = 0.6
label.Text = ""
label.Parent = screenGui

local function colorForWeather(weather)
	local colors = {
		Clear = Color3.fromRGB(235, 235, 235),
		Rain = Color3.fromRGB(120, 175, 255),
		Snow = Color3.fromRGB(210, 230, 255),
		Windy = Color3.fromRGB(180, 220, 200),
		MeteorShower = Color3.fromRGB(255, 190, 100),
	}
	return colors[weather] or colors.Clear
end

local function updateLabel(weather)
	label.Text = "Clima: " .. weather
	label.TextColor3 = colorForWeather(weather)
end

local function notify(weather)
	pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = "Clima actualizado",
			Text = weather,
			Duration = 3,
		})
	end)
end

updateLabel(currentWeather.Value)

currentWeather:GetPropertyChangedSignal("Value"):Connect(function()
	updateLabel(currentWeather.Value)
end)

weatherChanged.OnClientEvent:Connect(function(weather)
	updateLabel(weather)
	notify(weather)
end)
