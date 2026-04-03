--// LiquidHub - CURRENT CLIENT BUILD
--// Summary:
--// 1. Provides a reusable executor-safe GUI shell for LiquidHub.
--// 2. Includes aim assist, drawing-based ESP controls, and interface utilities.
--// 3. Cleans up connections, tweens, drawing objects, and GUI on re-execution.
--// 4. Keeps all logic client-side; any real trust boundary must exist off-client.


local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
if not LocalPlayer then
	warn("[LiquidHub] LocalPlayer not available; this script must run on the client.")
	return
end

local PlayerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", 10)
if not PlayerGui then
	warn("[LiquidHub] PlayerGui not found.")
	return
end

--// =========================================================
--// SAFE RE-EXECUTION GUARD
--// =========================================================
--// Current notes:
--// - This build may be executed multiple times in the same session.
--// - Keep every long-lived connection, drawing object, tween, and GUI on the cleanup path.
--// - Any new worker, polling loop, or remote request must also register cleanup.

local GLOBAL_KEY = "__LiquidHub_Cleanup__"
local hasGetGenv, genv = pcall(function()
	return getgenv and getgenv()
end)

if hasGetGenv and genv and type(genv[GLOBAL_KEY]) == "function" then
	pcall(genv[GLOBAL_KEY])
	genv[GLOBAL_KEY] = nil
end

local oldGui = PlayerGui:FindFirstChild("ModernBlueUI_Exec")
if oldGui then
	oldGui:Destroy()
end

local Theme = {
	Main = Color3.fromRGB(28, 56, 102),
	Main2 = Color3.fromRGB(40, 76, 132),

	Panel = Color3.fromRGB(24, 48, 88),
	Panel2 = Color3.fromRGB(36, 68, 118),
	Panel3 = Color3.fromRGB(20, 40, 76),
	Panel4 = Color3.fromRGB(10, 22, 42),

	Stroke = Color3.fromRGB(110, 182, 255),
	StrokeSoft = Color3.fromRGB(88, 150, 235),

	Blue = Color3.fromRGB(92, 164, 255),
	BlueDark = Color3.fromRGB(56, 116, 228),
	BlueLight = Color3.fromRGB(172, 222, 255),

	Text = Color3.fromRGB(255, 255, 255),
	Tag = Color3.fromRGB(160, 220, 255),
	Danger = Color3.fromRGB(235, 96, 96),
}

local LOGO_URL = "https://github.com/Razzart55/LiquidHub/blob/main/Liquid%20Logo.png?raw=true"
local LOGO_FOLDER = "LiquidHub"
local LOGO_FILE = LOGO_FOLDER .. "/Liquid Logo.png"
local CachedLogoAsset = nil

local function resolveRequestFunction()
	local env = (hasGetGenv and genv) or nil
	return rawget(_G, "request")
		or rawget(_G, "http_request")
		or (rawget(_G, "syn") and rawget(_G.syn, "request"))
		or (rawget(_G, "fluxus") and rawget(_G.fluxus, "request"))
		or (env and rawget(env, "request"))
		or (env and rawget(env, "http_request"))
end

local function resolveAssetFunction()
	local env = (hasGetGenv and genv) or nil
	return rawget(_G, "getcustomasset")
		or rawget(_G, "getsynasset")
		or (rawget(_G, "syn") and rawget(_G.syn, "asset"))
		or (env and rawget(env, "getcustomasset"))
		or (env and rawget(env, "getsynasset"))
end

local function ensureFolder(path)
	local mk = rawget(_G, "makefolder") or makefolder
	local isf = rawget(_G, "isfolder") or isfolder
	if type(mk) ~= "function" then
		return false
	end

	if type(isf) == "function" then
		local ok, exists = pcall(isf, path)
		if ok and exists then
			return true
		end
	end

	pcall(mk, path)
	return true
end

local function saveLogoFileIfMissing()
	local isfileFn = rawget(_G, "isfile") or isfile
	local writefileFn = rawget(_G, "writefile") or writefile

	if type(isfileFn) == "function" then
		local ok, exists = pcall(isfileFn, LOGO_FILE)
		if ok and exists then
			return true
		end
	end

	if type(writefileFn) ~= "function" then
		return false
	end

	ensureFolder(LOGO_FOLDER)
	local requestFn = resolveRequestFunction()
	if type(requestFn) ~= "function" then
		return false
	end

	local okRequest, response = pcall(requestFn, {
		Url = LOGO_URL,
		Method = "GET",
	})
	if okRequest and response and (response.Success or response.StatusCode == 200) and response.Body then
		local okWrite = pcall(writefileFn, LOGO_FILE, response.Body)
		if okWrite then
			task.wait(0.05)
			return true
		end
	end

	return false
end

local function refreshLogoAsset()
	CachedLogoAsset = nil

	local isfileFn = rawget(_G, "isfile") or isfile
	local assetFn = resolveAssetFunction()
	if type(assetFn) ~= "function" or type(isfileFn) ~= "function" then
		return nil
	end

	local okExists, exists = pcall(isfileFn, LOGO_FILE)
	if not (okExists and exists) then
		return nil
	end

	for _ = 1, 3 do
		local okAsset, asset = pcall(assetFn, LOGO_FILE)
		if okAsset and asset and tostring(asset) ~= "" then
			CachedLogoAsset = asset
			return CachedLogoAsset
		end
		task.wait(0.05)
	end

	return nil
end

local function prepareLogoAsset()
	saveLogoFileIfMissing()
	return refreshLogoAsset()
end

prepareLogoAsset()

local function createLogo(parent, props)
	if not parent then
		return nil
	end

	local asset = CachedLogoAsset or refreshLogoAsset()
	if not asset then
		return nil
	end

	local image = Instance.new("ImageLabel")
	image.Name = props and props.Name or "LiquidHubLogo"
	image.BackgroundTransparency = 1
	image.BorderSizePixel = 0
	image.ScaleType = Enum.ScaleType.Fit
	image.Image = asset
	image.ImageTransparency = props and props.ImageTransparency or 0
	image.AnchorPoint = props and props.AnchorPoint or Vector2.new(0, 0)
	image.Position = props and props.Position or UDim2.new()
	image.Size = props and props.Size or UDim2.new(0, 48, 0, 48)
	image.ZIndex = props and props.ZIndex or 1
	image.Parent = parent
	return image
end

local function create(className, props)
	local obj = Instance.new(className)
	for key, value in pairs(props or {}) do
		obj[key] = value
	end
	return obj
end

local function corner(parent, radius)
	local instance = Instance.new("UICorner")
	instance.CornerRadius = radius or UDim.new(0, 14)
	instance.Parent = parent
	return instance
end

local function stroke(parent, color, thickness, transparency)
	local instance = Instance.new("UIStroke")
	instance.Color = color or Theme.Stroke
	instance.Thickness = thickness or 1
	instance.Transparency = transparency or 0
	instance.Parent = parent
	return instance
end

local function padding(parent, left, right, top, bottom)
	local instance = Instance.new("UIPadding")
	instance.PaddingLeft = UDim.new(0, left or 0)
	instance.PaddingRight = UDim.new(0, right or 0)
	instance.PaddingTop = UDim.new(0, top or 0)
	instance.PaddingBottom = UDim.new(0, bottom or 0)
	instance.Parent = parent
	return instance
end

local function list(parent, pad)
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, pad or 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = parent
	return layout
end

local function gradient(parent, colorA, colorB, rotation)
	local instance = Instance.new("UIGradient")
	instance.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, colorA),
		ColorSequenceKeypoint.new(1, colorB),
	})
	instance.Rotation = rotation or 0
	instance.Parent = parent
	return instance
end

local function tween(object, duration, props)
	return TweenService:Create(
		object,
		TweenInfo.new(duration, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		props
	)
end


local MouseUnlockState = {
	Active = false,
	PrevMouseBehavior = nil,
	PrevMouseIconEnabled = nil,
	PrevDevEnableMouseLock = nil,
	PrevCameraMode = nil,
	EnforcerConnection = nil,
}

local function applyGuiMouseUnlock(enabled)
	if enabled then
		if not MouseUnlockState.Active then
			MouseUnlockState.Active = true
			MouseUnlockState.PrevMouseBehavior = UserInputService.MouseBehavior
			MouseUnlockState.PrevMouseIconEnabled = UserInputService.MouseIconEnabled

			pcall(function()
				MouseUnlockState.PrevDevEnableMouseLock = LocalPlayer.DevEnableMouseLock
			end)

			pcall(function()
				MouseUnlockState.PrevCameraMode = LocalPlayer.CameraMode
			end)
		end

		pcall(function()
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end)

		pcall(function()
			UserInputService.MouseIconEnabled = true
		end)

		pcall(function()
			LocalPlayer.DevEnableMouseLock = false
		end)

		pcall(function()
			LocalPlayer.CameraMode = Enum.CameraMode.Classic
		end)

		if not MouseUnlockState.EnforcerConnection then
			MouseUnlockState.EnforcerConnection = RunService.RenderStepped:Connect(function()
				if not MouseUnlockState.Active then
					return
				end

				pcall(function()
					if UserInputService.MouseBehavior ~= Enum.MouseBehavior.Default then
						UserInputService.MouseBehavior = Enum.MouseBehavior.Default
					end
				end)

				pcall(function()
					if not UserInputService.MouseIconEnabled then
						UserInputService.MouseIconEnabled = true
					end
				end)

				pcall(function()
					if LocalPlayer.DevEnableMouseLock ~= false then
						LocalPlayer.DevEnableMouseLock = false
					end
				end)

				pcall(function()
					if LocalPlayer.CameraMode ~= Enum.CameraMode.Classic then
						LocalPlayer.CameraMode = Enum.CameraMode.Classic
					end
				end)
			end)
		end
	else
		MouseUnlockState.Active = false

		if MouseUnlockState.EnforcerConnection then
			pcall(function()
				MouseUnlockState.EnforcerConnection:Disconnect()
			end)
			MouseUnlockState.EnforcerConnection = nil
		end

		if MouseUnlockState.PrevMouseBehavior ~= nil then
			pcall(function()
				UserInputService.MouseBehavior = MouseUnlockState.PrevMouseBehavior
			end)
		end

		if MouseUnlockState.PrevMouseIconEnabled ~= nil then
			pcall(function()
				UserInputService.MouseIconEnabled = MouseUnlockState.PrevMouseIconEnabled
			end)
		end

		if MouseUnlockState.PrevDevEnableMouseLock ~= nil then
			pcall(function()
				LocalPlayer.DevEnableMouseLock = MouseUnlockState.PrevDevEnableMouseLock
			end)
		end

		if MouseUnlockState.PrevCameraMode ~= nil then
			pcall(function()
				LocalPlayer.CameraMode = MouseUnlockState.PrevCameraMode
			end)
		end
	end
end


--// =========================================================
--// AIM ASSIST CONTROLLER
--// =========================================================
--// Current notes:
--// - This is a lightweight client-side aim assist controller.
--// - It only operates on character models returned by getCandidateCharacters().
--// - If another local system also owns the camera, unify the control path to avoid camera fights.

local AimAssist = {}
AimAssist.__index = AimAssist

function AimAssist.new(config)
	config = config or {}

	local self = setmetatable({}, AimAssist)

	self.Enabled = config.Enabled ~= false
	self.FOVRadius = config.FOVRadius or 120
	self.Smoothing = config.Smoothing or 0.18
	self.Prediction = config.Prediction or 0
	self.AimPartName = config.AimPartName or "Head"
	self.RequireHold = config.RequireHold ~= false
	self.HoldInput = config.HoldInput or Enum.UserInputType.MouseButton2
	self.ActivationInput = config.ActivationInput or self.HoldInput
	self.ActivationMode = config.ActivationMode or (self.RequireHold and "Hold" or "Toggle")
	self.TeamCheck = config.TeamCheck or false
	self.VisibleCheck = config.VisibleCheck or false
	self.CompatibilityMode = config.CompatibilityMode == true

	self.IsAiming = false
	self.CurrentTarget = nil

	self.RenderConnection = nil
	self.InputBeganConnection = nil
	self.InputEndedConnection = nil

	return self
end

local function getMousePosition()
	return UserInputService:GetMouseLocation()
end

local function toScreen(point)
	local v, onScreen = Camera:WorldToViewportPoint(point)
	return Vector2.new(v.X, v.Y), onScreen
end

local Compat = { Enabled = false }

do
	local function norm(name)
		return tostring(name or ""):lower():gsub("[%s_%-_]", "")
	end

	local function baseParts(model)
		local parts = {}
		if not model then
			return parts
		end
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then
				table.insert(parts, d)
			end
		end
		return parts
	end

	local function pickNamed(model, names)
		for _, name in ipairs(names) do
			local part = model and model:FindFirstChild(name, true)
			if part and part:IsA("BasePart") then
				return part
			end
		end
		local wanted = {}
		for _, name in ipairs(names) do
			wanted[norm(name)] = true
		end
		for _, part in ipairs(baseParts(model)) do
			if wanted[norm(part.Name)] then
				return part
			end
		end
		return nil
	end

	local function pickScored(model, keywords, preferHigh)
		local best, score = nil, -1e9
		for _, part in ipairs(baseParts(model)) do
			local token = norm(part.Name)
			local s = part.Size.Magnitude
			for _, keyword in ipairs(keywords) do
				if token:find(norm(keyword), 1, true) then
					s = s + 30
				end
			end
			if preferHigh then
				s = s + part.Position.Y * 0.01
			end
			if s > score then
				score, best = s, part
			end
		end
		return best
	end

	function Compat.ResolveParts(model)
		if not model then
			return nil, nil
		end
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local root = humanoid and humanoid.RootPart or nil
		root = root or pickNamed(model, {"HumanoidRootPart","RootPart","Root","UpperTorso","Torso","LowerTorso","Pelvis","Body","Chest","Center","Main"})
		root = root or (model.PrimaryPart and model.PrimaryPart:IsA("BasePart") and model.PrimaryPart) or pickScored(model, {"root","torso","pelvis","body","chest","center","main"}, false)

		local head = pickNamed(model, {"Head","FaceCenter","Skull","Neck","UpperTorso","Torso","HumanoidRootPart"})
		head = head or pickScored(model, {"head","face","skull","neck","upper","torso","chest"}, true)
		head = head or root

		return root or head, head or root
	end

	function Compat.GetAimPart(model, preferred)
		if not model then
			return nil
		end
		local direct = preferred and model:FindFirstChild(preferred, true)
		if direct and direct:IsA("BasePart") then
			return direct
		end
		local root, head = Compat.ResolveParts(model)
		return head or root
	end
end

function AimAssist:_getCharacterPlayer(model)
	return Players:GetPlayerFromCharacter(model)
end

function AimAssist:_sameTeam(targetPlayer)
	if not self.TeamCheck or not targetPlayer or targetPlayer == LocalPlayer then
		return false
	end

	if LocalPlayer.Team ~= nil and targetPlayer.Team ~= nil then
		return LocalPlayer.Team == targetPlayer.Team
	end

	if LocalPlayer.TeamColor ~= nil and targetPlayer.TeamColor ~= nil then
		return LocalPlayer.TeamColor == targetPlayer.TeamColor
	end

	return false
end

function AimAssist:_inputMatches(input)
	local bind = self.ActivationInput or self.HoldInput
	if typeof(bind) ~= "EnumItem" then
		return false
	end

	if bind.EnumType == Enum.KeyCode then
		return input.KeyCode == bind
	end

	if bind.EnumType == Enum.UserInputType then
		return input.UserInputType == bind
	end

	return false
end

function AimAssist:_resolveAimPart(model)
	if not model then
		return nil
	end

	local direct = model:FindFirstChild(self.AimPartName, true)
	if direct and direct:IsA("BasePart") then
		return direct
	end

	if not self.CompatibilityMode then
		return nil
	end

	return Compat.GetAimPart(model, self.AimPartName)
end


function AimAssist:_isVisible(worldPosition, targetModel, ignoreList)
	if not self.VisibleCheck then
		return true
	end

	local origin = Camera.CFrame.Position
	local direction = worldPosition - origin
	if direction.Magnitude <= 0.001 then
		return true
	end

	local blacklist = {}
	if ignoreList then
		for _, item in ipairs(ignoreList) do
			table.insert(blacklist, item)
		end
	end

	table.insert(blacklist, Camera)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Blacklist
	params.FilterDescendantsInstances = blacklist
	params.IgnoreWater = true

	local result = Workspace:Raycast(origin, direction, params)
	if not result then
		return true
	end

	if targetModel and result.Instance and result.Instance:IsDescendantOf(targetModel) then
		return true
	end

	return false
end

function AimAssist:_isValidTarget(model)
	if not model or model == LocalPlayer.Character then
		return false
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local aimPart = self:_resolveAimPart(model)

	if not aimPart then
		return false
	end

	if humanoid then
		if humanoid.Health <= 0 then
			return false
		end
	elseif not self.CompatibilityMode then
		return false
	end

	if self.TeamCheck then
		local targetPlayer = self:_getCharacterPlayer(model)
		if self:_sameTeam(targetPlayer) then
			return false
		end
	end

	return true
end

function AimAssist:GetClosestTarget(candidateModels)
	if not self.Enabled then
		return nil
	end

	local mousePos = getMousePosition()
	local bestTarget = nil
	local bestDistance = self.FOVRadius

	for _, model in ipairs(candidateModels) do
		if self:_isValidTarget(model) then
			local aimPart = self:_resolveAimPart(model)
			if aimPart then
				local screenPos, onScreen = toScreen(aimPart.Position)

				if onScreen then
					local distance = (mousePos - screenPos).Magnitude
					if distance <= bestDistance then
						local ignore = {}
						if LocalPlayer.Character then
							table.insert(ignore, LocalPlayer.Character)
						end
						if self:_isVisible(aimPart.Position, model, ignore) then
							bestDistance = distance
							bestTarget = model
						end
					end
				end
			end
		end
	end

	self.CurrentTarget = bestTarget
	return bestTarget
end

function AimAssist:_getAimPosition(target)
	if not target then
		return nil
	end

	local part = self:_resolveAimPart(target)
	if not part then
		return nil
	end

	local predictedPosition = part.Position

	if self.Prediction > 0 and part:IsA("BasePart") then
		predictedPosition += part.AssemblyLinearVelocity * self.Prediction
	end

	return predictedPosition
end

function AimAssist:Update(candidateModels, deltaTime)
	if not self.Enabled then
		self.CurrentTarget = nil
		return
	end

	if self.ActivationMode == "Hold" and self.RequireHold and not self.IsAiming then
		self.CurrentTarget = nil
		return
	end

	if self.ActivationMode == "Toggle" and not self.IsAiming then
		self.CurrentTarget = nil
		return
	end

	local target = self:GetClosestTarget(candidateModels)
	if not target then
		return
	end

	local aimPosition = self:_getAimPosition(target)
	if not aimPosition then
		return
	end

	local current = Camera.CFrame
	local goal = CFrame.new(current.Position, aimPosition)
	local alpha = 1 - math.exp(-(deltaTime or 1 / 60) / math.max(self.Smoothing, 0.001))

	Camera.CFrame = current:Lerp(goal, alpha)
end

function AimAssist:Start(getCandidates)
	self:Stop()

	self.InputBeganConnection = UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end

		if self:_inputMatches(input) then
			if self.ActivationMode == "Toggle" then
				self.IsAiming = not self.IsAiming
				if not self.IsAiming then
					self.CurrentTarget = nil
				end
			else
				self.IsAiming = true
			end
		end
	end)

	self.InputEndedConnection = UserInputService.InputEnded:Connect(function(input)
		if self.ActivationMode == "Hold" and self:_inputMatches(input) then
			self.IsAiming = false
			self.CurrentTarget = nil
		end
	end)

	self.RenderConnection = RunService.RenderStepped:Connect(function(dt)
		local candidates = getCandidates()
		self:Update(candidates, dt)
	end)
end

function AimAssist:Stop()
	if self.RenderConnection then
		self.RenderConnection:Disconnect()
		self.RenderConnection = nil
	end

	if self.InputBeganConnection then
		self.InputBeganConnection:Disconnect()
		self.InputBeganConnection = nil
	end

	if self.InputEndedConnection then
		self.InputEndedConnection:Disconnect()
		self.InputEndedConnection = nil
	end

	self.IsAiming = false
	self.CurrentTarget = nil
end


local ESP = {}
ESP.__index = ESP

function ESP.new(config)
	config = config or {}

	local self = setmetatable({}, ESP)

	self.Enabled = config.Enabled or false
	self.BoxColor = config.BoxColor or Color3.fromRGB(255, 0, 0)
	self.BoxThickness = config.BoxThickness or 2
	self.TeamCheck = config.TeamCheck or false
	self.TeamColor = config.TeamColor or false
	self.AutoThickness = config.AutoThickness ~= false
	self.ShowNames = config.ShowNames ~= false
	self.TextSize = config.TextSize or 13
	self.NameAutoScale = config.NameAutoScale ~= false
	self.NameScaleMin = config.NameScaleMin or 13
	self.NameScaleMax = config.NameScaleMax or 24
	self.CompatibilityMode = config.CompatibilityMode == true

	self.Objects = {}
	self.Connection = nil
	self.PlayerAddedConnection = nil
	self.PlayerRemovingConnection = nil

	return self
end

function ESP:_isSupported()
	return Drawing and type(Drawing.new) == "function"
end

function ESP:_newLine(color, thickness)
	local line = Drawing.new("Line")
	line.Visible = false
	line.From = Vector2.new(0, 0)
	line.To = Vector2.new(0, 0)
	line.Color = color
	line.Thickness = thickness
	line.Transparency = 1
	return line
end

function ESP:_newText(color, size)
	local text = Drawing.new("Text")
	text.Visible = false
	text.Center = true
	text.Outline = true
	pcall(function()
		text.OutlineColor = Color3.fromRGB(0, 0, 0)
	end)
	text.Font = 2
	text.Size = size or 13
	text.Color = color
	text.Transparency = 1
	text.Text = ""
	return text
end

function ESP:_setVisible(library, state)
	for _, item in pairs(library) do
		item.Visible = state
	end
end

function ESP:_setColor(library, color)
	for _, item in pairs(library) do
		item.Color = color
	end
end

function ESP:_removePlayer(player)
	local entry = self.Objects[player]
	if not entry then
		return
	end

	if entry.OriginPart and entry.OriginPart.Parent then
		pcall(function()
			entry.OriginPart:Destroy()
		end)
	end

	if entry.Library then
		for _, line in pairs(entry.Library) do
			pcall(function()
				line.Visible = false
				line:Remove()
			end)
		end
	end

	self.Objects[player] = nil
end

function ESP:_ensurePlayer(player)
	if self.Objects[player] then
		return self.Objects[player]
	end

	local entry = {
		Library = {
			TL1 = self:_newLine(self.BoxColor, self.BoxThickness),
			TL2 = self:_newLine(self.BoxColor, self.BoxThickness),
			TR1 = self:_newLine(self.BoxColor, self.BoxThickness),
			TR2 = self:_newLine(self.BoxColor, self.BoxThickness),
			BL1 = self:_newLine(self.BoxColor, self.BoxThickness),
			BL2 = self:_newLine(self.BoxColor, self.BoxThickness),
			BR1 = self:_newLine(self.BoxColor, self.BoxThickness),
			BR2 = self:_newLine(self.BoxColor, self.BoxThickness),
			NameText = self:_newText(self.BoxColor, self.TextSize),
		},
		OriginPart = Instance.new("Part"),
	}

	entry.OriginPart.Name = "LiquidHub_ESP_Origin"
	entry.OriginPart.Anchored = true
	entry.OriginPart.CanCollide = false
	entry.OriginPart.CanQuery = false
	entry.OriginPart.CanTouch = false
	entry.OriginPart.Transparency = 1
	entry.OriginPart.Size = Vector3.new(1, 1, 1)
	entry.OriginPart.CFrame = CFrame.new()
	entry.OriginPart.Parent = Workspace

	self.Objects[player] = entry
	return entry
end

function ESP:_getColorForPlayer(player)
	if self.TeamColor and player and player.TeamColor then
		return player.TeamColor.Color
	end

	if self.TeamCheck and LocalPlayer and player then
		if LocalPlayer.TeamColor == player.TeamColor then
			return Color3.fromRGB(0, 255, 0)
		else
			return Color3.fromRGB(255, 0, 0)
		end
	end

	return self.BoxColor
end

function ESP:_hideAll()
	for _, entry in pairs(self.Objects) do
		self:_setVisible(entry.Library, false)
	end
end

function ESP:_resolveDisplayParts(character)
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	local head = character and character:FindFirstChild("Head")

	if rootPart and head then
		return rootPart, head
	end

	if not self.CompatibilityMode then
		return rootPart, head
	end

	return Compat.ResolveParts(character)
end

function ESP:Update()
	if not self.Enabled then
		self:_hideAll()
		return
	end

	local activeCamera = Workspace.CurrentCamera or Camera
	if not activeCamera then
		self:_hideAll()
		return
	end

	local localCharacter = LocalPlayer.Character
	local localRoot = localCharacter and localCharacter:FindFirstChild("HumanoidRootPart")

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer then
			local entry = self:_ensurePlayer(player)
			local library = entry.Library
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local rootPart, head = self:_resolveDisplayParts(character)

			if not character or (humanoid and humanoid.Health <= 0) or not rootPart or not head or (not humanoid and not self.CompatibilityMode) then
				self:_setVisible(library, false)
			else
				local rootPos, rootOnScreen = activeCamera:WorldToViewportPoint(rootPart.Position)
				local headPos, headOnScreen = activeCamera:WorldToViewportPoint(head.Position)

				if not rootOnScreen or not headOnScreen or rootPos.Z <= 0 or headPos.Z <= 0 then
					self:_setVisible(library, false)
				else
					local heightScale = 1.5
					if self.CompatibilityMode and head and rootPart then
						local gap = math.abs(head.Position.Y - rootPart.Position.Y)
						if gap > 0.25 then
							heightScale = math.clamp(gap / math.max(rootPart.Size.Y, 0.25), 1.4, 4)
						end
					end

					entry.OriginPart.Size = Vector3.new(
						math.max(rootPart.Size.X, 1),
						math.max(rootPart.Size.Y * heightScale, 2),
						math.max(rootPart.Size.Z, 1)
					)
					entry.OriginPart.CFrame = CFrame.new(rootPart.CFrame.Position, activeCamera.CFrame.Position)

					local sizeX = entry.OriginPart.Size.X
					local sizeY = entry.OriginPart.Size.Y

					local tl3d = activeCamera:WorldToViewportPoint((entry.OriginPart.CFrame * CFrame.new(sizeX, sizeY, 0)).Position)
					local tr3d = activeCamera:WorldToViewportPoint((entry.OriginPart.CFrame * CFrame.new(-sizeX, sizeY, 0)).Position)
					local bl3d = activeCamera:WorldToViewportPoint((entry.OriginPart.CFrame * CFrame.new(sizeX, -sizeY, 0)).Position)
					local br3d = activeCamera:WorldToViewportPoint((entry.OriginPart.CFrame * CFrame.new(-sizeX, -sizeY, 0)).Position)

					if tl3d.Z <= 0 or tr3d.Z <= 0 or bl3d.Z <= 0 or br3d.Z <= 0 then
						self:_setVisible(library, false)
					else
						local color = self:_getColorForPlayer(player)
						self:_setColor(library, color)

						local ratio = (activeCamera.CFrame.Position - rootPart.Position).Magnitude
						local offset = math.clamp((1 / math.max(ratio, 0.001)) * 750, 2, 300)

						library.TL1.From = Vector2.new(tl3d.X, tl3d.Y)
						library.TL1.To = Vector2.new(tl3d.X + offset, tl3d.Y)
						library.TL2.From = Vector2.new(tl3d.X, tl3d.Y)
						library.TL2.To = Vector2.new(tl3d.X, tl3d.Y + offset)

						library.TR1.From = Vector2.new(tr3d.X, tr3d.Y)
						library.TR1.To = Vector2.new(tr3d.X - offset, tr3d.Y)
						library.TR2.From = Vector2.new(tr3d.X, tr3d.Y)
						library.TR2.To = Vector2.new(tr3d.X, tr3d.Y + offset)

						library.BL1.From = Vector2.new(bl3d.X, bl3d.Y)
						library.BL1.To = Vector2.new(bl3d.X + offset, bl3d.Y)
						library.BL2.From = Vector2.new(bl3d.X, bl3d.Y)
						library.BL2.To = Vector2.new(bl3d.X, bl3d.Y - offset)

						library.BR1.From = Vector2.new(br3d.X, br3d.Y)
						library.BR1.To = Vector2.new(br3d.X - offset, br3d.Y)
						library.BR2.From = Vector2.new(br3d.X, br3d.Y)
						library.BR2.To = Vector2.new(br3d.X, br3d.Y - offset)

						local thickness = self.BoxThickness
						if self.AutoThickness and localRoot then
							local distance = (localRoot.Position - rootPart.Position).Magnitude
							thickness = math.clamp((1 / math.max(distance, 0.001)) * 100, 1, 4)
						end

						for name, item in pairs(library) do
							if name ~= "NameText" then
								item.Thickness = thickness
								item.Visible = true
							end
						end

						if library.NameText then
							library.NameText.Text = player.DisplayName or player.Name
							local nameSize = self.TextSize
							if self.NameAutoScale then
								local distanceForName = ratio
								nameSize = math.clamp((1 / math.max(distanceForName, 0.001)) * 220, self.NameScaleMin, self.NameScaleMax)
							end
							library.NameText.Size = nameSize
							pcall(function()
								library.NameText.OutlineColor = Color3.fromRGB(0, 0, 0)
							end)
							library.NameText.Position = Vector2.new(headPos.X, headPos.Y - math.max(16, offset * 0.9))
							library.NameText.Visible = self.ShowNames
						end
					end
				end
			end
		end
	end

	for player in pairs(self.Objects) do
		if not player or player.Parent ~= Players then
			self:_removePlayer(player)
		end
	end
end

function ESP:Start()
	if not self:_isSupported() then
		return false
	end

	self:Stop()

	self.PlayerAddedConnection = Players.PlayerAdded:Connect(function(player)
		if player ~= LocalPlayer then
			self:_ensurePlayer(player)
		end
	end)

	self.PlayerRemovingConnection = Players.PlayerRemoving:Connect(function(player)
		self:_removePlayer(player)
	end)

	self.Connection = RunService.RenderStepped:Connect(function()
		self:Update()
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer then
			self:_ensurePlayer(player)
		end
	end

	return true
end

function ESP:Stop()
	if self.Connection then
		self.Connection:Disconnect()
		self.Connection = nil
	end

	if self.PlayerAddedConnection then
		self.PlayerAddedConnection:Disconnect()
		self.PlayerAddedConnection = nil
	end

	if self.PlayerRemovingConnection then
		self.PlayerRemovingConnection:Disconnect()
		self.PlayerRemovingConnection = nil
	end

	for player in pairs(self.Objects) do
		self:_removePlayer(player)
	end
end




local PlayerUtility = {}
PlayerUtility.__index = PlayerUtility

function PlayerUtility.new(config)
	config = config or {}

	local self = setmetatable({}, PlayerUtility)
	self.WalkSpeedEnabled = config.WalkSpeedEnabled or false
	self.WalkSpeedValue = config.WalkSpeedValue or 16
	self.WalkSpeedKeybind = config.WalkSpeedKeybind or Enum.KeyCode.V
	self.WalkSpeedMethod = config.WalkSpeedMethod or "Humanoid"
	self.FlyEnabled = config.FlyEnabled or false
	self.FlySpeed = config.FlySpeed or 60
	self.FlyKeybind = config.FlyKeybind or Enum.KeyCode.F
	self.FlyMethod = config.FlyMethod or "BodyVelocity"
	self.NoclipEnabled = config.NoclipEnabled or false
	self.NoclipKeybind = config.NoclipKeybind or Enum.KeyCode.N
	self.NoclipMethod = config.NoclipMethod or "CanCollide"

	self.Movement = {
		Forward = false,
		Backward = false,
		Left = false,
		Right = false,
		Up = false,
		Down = false,
	}
	self.InputBeganConnection = nil
	self.InputEndedConnection = nil
	self.RenderConnection = nil
	self.CharacterAddedConnection = nil
	self.BodyVelocity = nil
	self.BodyGyro = nil

	return self
end

function PlayerUtility:_getCharacter()
	return LocalPlayer and LocalPlayer.Character or nil
end

function PlayerUtility:_getHumanoid()
	local character = self:_getCharacter()
	return character and character:FindFirstChildOfClass("Humanoid") or nil
end

function PlayerUtility:_getRoot()
	local character = self:_getCharacter()
	return character and character:FindFirstChild("HumanoidRootPart") or nil
end

function PlayerUtility:_clearFlyBody()
	if self.BodyVelocity then
		pcall(function()
			self.BodyVelocity:Destroy()
		end)
		self.BodyVelocity = nil
	end
	if self.BodyGyro then
		pcall(function()
			self.BodyGyro:Destroy()
		end)
		self.BodyGyro = nil
	end
end

function PlayerUtility:_ensureFlyBody()
	local root = self:_getRoot()
	if not root then
		return nil, nil
	end

	if not self.BodyVelocity or self.BodyVelocity.Parent ~= root then
		self:_clearFlyBody()
		self.BodyVelocity = Instance.new("BodyVelocity")
		self.BodyVelocity.Name = "LiquidHub_FlyVelocity"
		self.BodyVelocity.MaxForce = Vector3.new(1e9, 1e9, 1e9)
		self.BodyVelocity.Velocity = Vector3.zero
		self.BodyVelocity.Parent = root

		self.BodyGyro = Instance.new("BodyGyro")
		self.BodyGyro.Name = "LiquidHub_FlyGyro"
		self.BodyGyro.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
		self.BodyGyro.P = 1e5
		self.BodyGyro.CFrame = Camera.CFrame
		self.BodyGyro.Parent = root
	end

	return self.BodyVelocity, self.BodyGyro
end

function PlayerUtility:SetWalkSpeedEnabled(state)
	self.WalkSpeedEnabled = state == true
	if not self.WalkSpeedEnabled then
		local humanoid = self:_getHumanoid()
		local root = self:_getRoot()
		if humanoid then
			humanoid.WalkSpeed = 16
		end
		if root and self.WalkSpeedMethod == "Velocity" then
			root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
		end
	end
end

function PlayerUtility:SetFlyEnabled(state)
	self.FlyEnabled = state == true
	if not self.FlyEnabled then
		local humanoid = self:_getHumanoid()
		if humanoid then
			humanoid.PlatformStand = false
		end
		self:_clearFlyBody()
	end
end

function PlayerUtility:SetNoclipEnabled(state)
	self.NoclipEnabled = state == true
	if not self.NoclipEnabled then
		local character = self:_getCharacter()
		if character then
			for _, item in ipairs(character:GetDescendants()) do
				if item:IsA("BasePart") then
					item.CanCollide = true
					item.CanTouch = true
					item.CanQuery = true
				end
			end
		end
	end
end

function PlayerUtility:_applyWalkSpeed()
	if not self.WalkSpeedEnabled then
		return
	end
	local humanoid = self:_getHumanoid()
	local root = self:_getRoot()
	if self.WalkSpeedMethod == "Velocity" then
		if root then
			local inputVec = Vector3.zero
			if self.Movement.Forward then inputVec += Camera.CFrame.LookVector end
			if self.Movement.Backward then inputVec -= Camera.CFrame.LookVector end
			if self.Movement.Left then inputVec -= Camera.CFrame.RightVector end
			if self.Movement.Right then inputVec += Camera.CFrame.RightVector end
			local planar = Vector3.new(inputVec.X, 0, inputVec.Z)
			if planar.Magnitude > 0 then
				local unit = planar.Unit * self.WalkSpeedValue
				root.AssemblyLinearVelocity = Vector3.new(unit.X, root.AssemblyLinearVelocity.Y, unit.Z)
			end
		end
	else
		if humanoid then
			humanoid.WalkSpeed = self.WalkSpeedValue
		end
	end
end

function PlayerUtility:_applyNoclip()
	if not self.NoclipEnabled then
		return
	end
	local character = self:_getCharacter()
	local root = self:_getRoot()
	if not character then
		return
	end

	if self.NoclipMethod == "RootOnly" then
		if root then
			root.CanCollide = false
			root.CanTouch = false
			root.CanQuery = false
		end
	else
		for _, item in ipairs(character:GetDescendants()) do
			if item:IsA("BasePart") then
				item.CanCollide = false
				if self.NoclipMethod == "FullGhost" then
					item.CanTouch = false
					item.CanQuery = false
				end
			end
		end
	end
end

function PlayerUtility:_applyFly()
	if not self.FlyEnabled then
		return
	end

	local root = self:_getRoot()
	local humanoid = self:_getHumanoid()
	if not root or not humanoid then
		return
	end

	local moveDirection = Vector3.zero
	if self.Movement.Forward then moveDirection += Camera.CFrame.LookVector end
	if self.Movement.Backward then moveDirection -= Camera.CFrame.LookVector end
	if self.Movement.Left then moveDirection -= Camera.CFrame.RightVector end
	if self.Movement.Right then moveDirection += Camera.CFrame.RightVector end
	if self.Movement.Up then moveDirection += Camera.CFrame.UpVector end
	if self.Movement.Down then moveDirection -= Camera.CFrame.UpVector end

	if self.FlyMethod == "CFrame" then
		humanoid.PlatformStand = true
		if moveDirection.Magnitude > 0 then
			root.CFrame = root.CFrame + (moveDirection.Unit * self.FlySpeed * 0.016)
		end
	else
		local bodyVelocity, bodyGyro = self:_ensureFlyBody()
		if not bodyVelocity or not bodyGyro then
			return
		end

		humanoid.PlatformStand = true
		bodyGyro.CFrame = Camera.CFrame

		if moveDirection.Magnitude > 0 then
			bodyVelocity.Velocity = moveDirection.Unit * self.FlySpeed
		else
			bodyVelocity.Velocity = Vector3.zero
		end
	end
end
function PlayerUtility:_bindMovementKey(input, state)
	local key = input.KeyCode
	if key == Enum.KeyCode.W then
		self.Movement.Forward = state
	elseif key == Enum.KeyCode.S then
		self.Movement.Backward = state
	elseif key == Enum.KeyCode.A then
		self.Movement.Left = state
	elseif key == Enum.KeyCode.D then
		self.Movement.Right = state
	elseif key == Enum.KeyCode.Space then
		self.Movement.Up = state
	elseif key == Enum.KeyCode.LeftControl or key == Enum.KeyCode.LeftShift then
		self.Movement.Down = state
	end
end

function PlayerUtility:Start(onWalkSpeedToggle, onFlyToggle, onNoclipToggle)
	self:Stop()

	self.CharacterAddedConnection = LocalPlayer.CharacterAdded:Connect(function()
		task.wait(0.2)
		self:_clearFlyBody()
		self:_applyWalkSpeed()
	end)

	self.InputBeganConnection = UserInputService.InputBegan:Connect(function(input, processed)
		if processed or UserInputService:GetFocusedTextBox() then
			return
		end

		self:_bindMovementKey(input, true)
	end)

	self.InputEndedConnection = UserInputService.InputEnded:Connect(function(input)
		self:_bindMovementKey(input, false)
	end)

	self.RenderConnection = RunService.RenderStepped:Connect(function(dt)
		self:_applyWalkSpeed()
		self:_applyNoclip()
		if self.FlyMethod == "CFrame" and self.FlyEnabled then
			local root = self:_getRoot()
			local humanoid = self:_getHumanoid()
			if root and humanoid then
				local moveDirection = Vector3.zero
				if self.Movement.Forward then moveDirection += Camera.CFrame.LookVector end
				if self.Movement.Backward then moveDirection -= Camera.CFrame.LookVector end
				if self.Movement.Left then moveDirection -= Camera.CFrame.RightVector end
				if self.Movement.Right then moveDirection += Camera.CFrame.RightVector end
				if self.Movement.Up then moveDirection += Camera.CFrame.UpVector end
				if self.Movement.Down then moveDirection -= Camera.CFrame.UpVector end
				humanoid.PlatformStand = true
				if moveDirection.Magnitude > 0 then
					root.CFrame = root.CFrame + (moveDirection.Unit * self.FlySpeed * dt)
				end
			end
		else
			self:_applyFly()
		end
	end)
end

function PlayerUtility:Stop()
	if self.InputBeganConnection then
		self.InputBeganConnection:Disconnect()
		self.InputBeganConnection = nil
	end
	if self.InputEndedConnection then
		self.InputEndedConnection:Disconnect()
		self.InputEndedConnection = nil
	end
	if self.RenderConnection then
		self.RenderConnection:Disconnect()
		self.RenderConnection = nil
	end
	if self.CharacterAddedConnection then
		self.CharacterAddedConnection:Disconnect()
		self.CharacterAddedConnection = nil
	end

	self.Movement.Forward = false
	self.Movement.Backward = false
	self.Movement.Left = false
	self.Movement.Right = false
	self.Movement.Up = false
	self.Movement.Down = false

	self:SetFlyEnabled(false)
	self:SetNoclipEnabled(false)
	self:SetWalkSpeedEnabled(false)
end

--// =========================================================
--// CONNECTION + TWEEN REGISTRY
--// =========================================================
--// Current notes:
--// - Register every long-lived RBXScriptConnection through trackConnection.
--// - Route replacement tweens through playTween so stale tweens do not stack.
--// - Gui:Destroy() remains the single full shutdown path for the file.

local Connections = {}
local ActiveTweens = {}
local Destroyed = false

local function trackConnection(conn)
	table.insert(Connections, conn)
	return conn
end

local function playTween(object, duration, props)
	if not object or Destroyed then
		return nil
	end

	local existing = ActiveTweens[object]
	if existing then
		existing:Cancel()
	end

	local tw = tween(object, duration, props)
	ActiveTweens[object] = tw

	trackConnection(tw.Completed:Connect(function()
		if ActiveTweens[object] == tw then
			ActiveTweens[object] = nil
		end
	end))

	tw:Play()
	return tw
end

local function fadeWindowDescendants(root, duration, show)
	for _, obj in ipairs(root:GetDescendants()) do
		if obj:IsA("TextLabel") or obj:IsA("TextButton") then
			playTween(obj, duration, {TextTransparency = show and 0 or 1})
		elseif obj:IsA("TextBox") then
			playTween(obj, duration, {
				BackgroundTransparency = show and 0 or 1,
				TextTransparency = show and 0 or 1,
			})
		elseif obj:IsA("Frame") and obj ~= root then
			playTween(obj, duration, {BackgroundTransparency = show and 0 or 1})
		elseif obj:IsA("UIStroke") then
			playTween(obj, duration, {Transparency = show and 0.1 or 1})
		end
	end
end

--// =========================================================
--// ROOT GUI
--// =========================================================
--// Current notes:
--// - Main is the primary content window.
--// - Backdrop spans the full screen while the GUI is visible.
--// - This build opens directly into the main window without extra startup overlays.

local ScreenGui = create("ScreenGui", {
	Name = "ModernBlueUI_Exec",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 50,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = PlayerGui,
})

local FOVPreview = create("Frame", {
	Name = "FOVPreview",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.5, 0),
	Size = UDim2.new(0, 160, 0, 160),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = 8,
	Parent = ScreenGui,
})

local FOVPreviewStroke = stroke(FOVPreview, Theme.BlueLight, 2, 0.2)
corner(FOVPreview, UDim.new(1, 0))

local FOVPreviewDot = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.5, 0),
	Size = UDim2.new(0, 4, 0, 4),
	BackgroundColor3 = Theme.BlueLight,
	BorderSizePixel = 0,
	ZIndex = 9,
	Parent = FOVPreview,
})
corner(FOVPreviewDot, UDim.new(1, 0))

local function setFOVPreviewSize(value)
	local sizeValue = math.max(20, math.floor((tonumber(value) or 80) * 2 + 0.5))
	FOVPreview.Size = UDim2.new(0, sizeValue, 0, sizeValue)
end

local function refreshFOVPreviewVisibility()
	if not FOVPreview then
		return
	end

	local guiTable = rawget(_G, "__LiquidHub_GuiRef__")
	local mainFrame = rawget(_G, "__LiquidHub_MainRef__")
	local aimEnabled = rawget(_G, "__LiquidHub_AimEnabled__") == true

	if not guiTable or not mainFrame then
		FOVPreview.Visible = false
		return
	end

	FOVPreview.Visible = aimEnabled and guiTable.Locked ~= true and mainFrame.Visible == true
end

setFOVPreviewSize(80)

local Backdrop = create("Frame", {
	Name = "Backdrop",
	Size = UDim2.fromScale(1, 1),
	Position = UDim2.fromScale(0, 0),
	BackgroundColor3 = Color3.fromRGB(16, 34, 64),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 0,
	Parent = ScreenGui,
})

local Main = create("Frame", {
	Name = "Main",
	Size = UDim2.new(0, 760, 0, 500),
	Position = UDim2.new(0.5, -380, 0.5, -250),
	BackgroundColor3 = Theme.Main,
	BorderSizePixel = 0,
	ClipsDescendants = true,
	ZIndex = 2,
	Parent = ScreenGui,
})
corner(Main, UDim.new(0, 22))
local MainStroke = stroke(Main, Theme.Stroke, 1.2, 0.12)
gradient(Main, Theme.Main, Theme.Main2, 90)

local Topbar = create("Frame", {
	Name = "Topbar",
	Size = UDim2.new(1, 0, 0, 62),
	BackgroundColor3 = Theme.Panel,
	BorderSizePixel = 0,
	Parent = Main,
})
corner(Topbar, UDim.new(0, 22))
gradient(Topbar, Color3.fromRGB(28, 56, 100), Color3.fromRGB(42, 78, 132), 0)

local TopbarFill = create("Frame", {
	Size = UDim2.new(1, 0, 0, 24),
	Position = UDim2.new(0, 0, 1, -24),
	BackgroundColor3 = Theme.Panel,
	BorderSizePixel = 0,
	Parent = Topbar,
})
gradient(TopbarFill, Color3.fromRGB(28, 56, 100), Color3.fromRGB(42, 78, 132), 0)

create("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.new(0, 18, 0, 10),
	Size = UDim2.new(1, -150, 0, 22),
	Text = "LiquidHub",
	TextColor3 = Theme.Text,
	TextSize = 20,
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = Topbar,
})

create("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.new(0, 18, 0, 32),
	Size = UDim2.new(1, -150, 0, 16),
	Text = "Unified Intelligence & Utility Platform",
	TextColor3 = Theme.Text,
	TextSize = 12,
	Font = Enum.Font.Gotham,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = Topbar,
})


local AccentBar = create("Frame", {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -84, 0.5, 0),
	Size = UDim2.new(0, 70, 0, 10),
	BackgroundColor3 = Theme.Blue,
	BorderSizePixel = 0,
	Parent = Topbar,
})
corner(AccentBar, UDim.new(1, 0))
gradient(AccentBar, Theme.BlueLight, Theme.BlueDark, 0)

local Close = create("TextButton", {
	Size = UDim2.new(0, 32, 0, 32),
	Position = UDim2.new(1, -42, 0, 15),
	BackgroundColor3 = Theme.Panel2,
	Text = "×",
	TextColor3 = Theme.Text,
	TextSize = 20,
	Font = Enum.Font.GothamBold,
	AutoButtonColor = false,
	Parent = Topbar,
})
corner(Close, UDim.new(0, 12))
stroke(Close, Theme.StrokeSoft, 1, 0.32)
gradient(Close, Color3.fromRGB(44, 78, 130), Color3.fromRGB(30, 58, 102), 90)

local Body = create("Frame", {
	Name = "Body",
	Position = UDim2.new(0, 0, 0, 62),
	Size = UDim2.new(1, 0, 1, -62),
	BackgroundTransparency = 1,
	Parent = Main,
})

local Sidebar = create("Frame", {
	Name = "Sidebar",
	Position = UDim2.new(0, 0, 0, 0),
	Size = UDim2.new(0, 180, 1, 0),
	BackgroundColor3 = Theme.Panel3,
	BorderSizePixel = 0,
	Parent = Body,
})
corner(Sidebar, UDim.new(0, 22))
gradient(Sidebar, Color3.fromRGB(24, 48, 86), Color3.fromRGB(18, 36, 70), 90)

local SidebarTopFill = create("Frame", {
	Position = UDim2.new(0, 0, 0, 0),
	Size = UDim2.new(1, 0, 0, 20),
	BackgroundColor3 = Theme.Panel3,
	BorderSizePixel = 0,
	Parent = Sidebar,
})
gradient(SidebarTopFill, Color3.fromRGB(24, 48, 86), Color3.fromRGB(18, 36, 70), 90)

local Pages = create("Frame", {
	Name = "Pages",
	Position = UDim2.new(0, 180, 0, 0),
	Size = UDim2.new(1, -180, 1, 0),
	BackgroundTransparency = 1,
	Parent = Body,
})

local TabsScroll = create("ScrollingFrame", {
	Name = "TabsScroll",
	Position = UDim2.new(0, 10, 0, 10),
	Size = UDim2.new(1, -20, 1, -20),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 0,
	Parent = Sidebar,
})
list(TabsScroll, 10)

createLogo(Sidebar, {
	Name = "SidebarLogo",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -18),
	Size = UDim2.new(0, 118, 0, 118),
	ZIndex = 2,
})

local Gui = {
	Ready = false,
	Locked = true,
	Tabs = {},
	CurrentTab = nil,
	Open = false,
	Busy = false,
	StatusMessage = "Hello from LiquidHub",
	Destroyed = false,
}

_G.__LiquidHub_GuiRef__ = Gui
_G.__LiquidHub_MainRef__ = Main
_G.__LiquidHub_AimEnabled__ = false

--// =========================================================
--// LIGHTWEIGHT VISIBILITY CONTROL
--// =========================================================
--// Current notes:
--// - Visibility animation is limited to the backdrop and main window roots.
--// - Avoid descendant-wide tween storms when adding more windows.
--// - Route any additional floating panels through this same visibility model.

local shownPos = UDim2.new(0.5, -380, 0.5, -250)

local function animateVisibility(show)
	if Gui.Busy or Gui.Destroyed then
		return
	end

	Gui.Busy = true

	if show then
		ScreenGui.Enabled = true
		Main.Visible = true
		Main.Position = UDim2.new(0.5, -380, 0.5, -228)
		Main.Size = UDim2.new(0, 748, 0, 490)
		Main.BackgroundTransparency = 0.12
		MainStroke.Transparency = 0.9
		Backdrop.BackgroundTransparency = 1

		playTween(Backdrop, 0.24, {BackgroundTransparency = 0.5})
		playTween(Main, 0.28, {
			Position = shownPos,
			Size = UDim2.new(0, 760, 0, 500),
			BackgroundTransparency = 0,
		})
		playTween(MainStroke, 0.28, {Transparency = 0.12})

		task.delay(0.29, function()
			if Destroyed or Gui.Destroyed then
				return
			end
			Gui.Open = true
			Gui.Busy = false
			applyGuiMouseUnlock(true)
		end)
	else
		playTween(Backdrop, 0.18, {BackgroundTransparency = 1})
		playTween(Main, 0.18, {
			Position = UDim2.new(0.5, -380, 0.5, -214),
			Size = UDim2.new(0, 748, 0, 490),
			BackgroundTransparency = 0.12,
		})
		playTween(MainStroke, 0.18, {Transparency = 0.9})

		task.delay(0.19, function()
			if Destroyed or Gui.Destroyed then
				return
			end
			Main.Visible = false
			ScreenGui.Enabled = true
			Gui.Open = false
			Gui.Busy = false
			applyGuiMouseUnlock(false)
		end)
	end
end

function Gui:SetVisible(state)
	if state == Gui.Open and ((state and Main.Visible and ScreenGui.Enabled) or (not state and (not Main.Visible or not ScreenGui.Enabled))) then
		applyGuiMouseUnlock(state and Main.Visible)
		return
	end
	if state then
		applyGuiMouseUnlock(true)
	end
	animateVisibility(state)

	task.delay(0.3, function()
		if Gui.Destroyed then
			return
		end
		refreshFOVPreviewVisibility()
	end)
end

function Gui:Toggle()
	if Gui.Locked or Gui.Destroyed then
		return
	end
	animateVisibility(not Gui.Open)
end

--// =========================================================
--// NOTIFICATIONS
--// =========================================================
--// Current notes:
--// - Keep notifications lightweight.
--// - For high-volume status logs, build a dedicated log panel instead of spamming toasts.
--// - This system is only for short user-facing events.

local NotificationsHolder = create("Frame", {
	Name = "Notifications",
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 20, 1, -250),
	Size = UDim2.new(0, 360, 0, 230),
	BackgroundTransparency = 1,
	ClipsDescendants = true,
	Parent = ScreenGui,
})
local NotificationsLayout = list(NotificationsHolder, 10)
NotificationsLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom

local LiveNotifications = {}
local MAX_NOTIFICATIONS = 3

local function cleanupDeadNotifications()
	local fresh = {}
	for _, obj in ipairs(LiveNotifications) do
		if obj and obj.Parent then
			table.insert(fresh, obj)
		end
	end
	LiveNotifications = fresh
end

function Gui:Notify(text)
	if Gui.Destroyed then
		return
	end

	cleanupDeadNotifications()

	while #LiveNotifications >= MAX_NOTIFICATIONS do
		local oldest = table.remove(LiveNotifications, 1)
		if oldest and oldest.Parent then
			oldest:Destroy()
		end
	end

	local note = create("Frame", {
		Size = UDim2.new(1, 0, 0, 68),
		BackgroundColor3 = Theme.Panel,
		BorderSizePixel = 0,
		Parent = NotificationsHolder,
	})
	table.insert(LiveNotifications, note)

	corner(note, UDim.new(0, 14))
	local noteStroke = stroke(note, Theme.Stroke, 1, 0.18)
	gradient(note, Color3.fromRGB(34, 64, 112), Color3.fromRGB(46, 86, 144), 0)

	local bar = create("Frame", {
		Size = UDim2.new(0, 5, 1, 0),
		BackgroundColor3 = Theme.Blue,
		BorderSizePixel = 0,
		Parent = note,
	})
	corner(bar, UDim.new(1, 0))
	gradient(bar, Theme.BlueLight, Theme.BlueDark, 90)

	create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 16, 0, 8),
		Size = UDim2.new(1, -24, 0, 16),
		Text = "[LiquidHub]",
		TextColor3 = Theme.Tag,
		TextSize = 12,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = note,
	})

	create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 16, 0, 26),
		Size = UDim2.new(1, -24, 0, 28),
		Text = tostring(text),
		TextWrapped = true,
		TextColor3 = Theme.Text,
		TextSize = 13,
		Font = Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = note,
	})

	note.Position = UDim2.new(0, -26, 0, 0)
	note.BackgroundTransparency = 1

	playTween(note, 0.22, {
		Position = UDim2.new(0, 0, 0, 0),
		BackgroundTransparency = 0,
	})
	playTween(noteStroke, 0.22, {Transparency = 0.18})

	task.spawn(function()
		task.wait(3)
		if Destroyed or Gui.Destroyed or not note.Parent then
			return
		end

		playTween(note, 0.35, {
			Position = UDim2.new(0, -120, 0, 0),
			BackgroundTransparency = 1,
		})
		playTween(noteStroke, 0.35, {Transparency = 1})

		for _, child in ipairs(note:GetDescendants()) do
			if child:IsA("TextLabel") then
				playTween(child, 0.35, {TextTransparency = 1})
			elseif child:IsA("Frame") then
				playTween(child, 0.35, {BackgroundTransparency = 1})
			end
		end

		task.wait(0.36)
		if note.Parent then
			note:Destroy()
		end
		cleanupDeadNotifications()
	end)
end

--// =========================================================
--// TAB / PAGE SYSTEM
--// =========================================================
--// Current notes:
--// - New hub features should usually become tabs or sections.
--// - Keep the section APIs simple so feature modules can plug into them.
--// - If the file grows much further, move CreateTab/CreateSection into a separate module.

function Gui:CreateTab(name)
	local TabButton = create("TextButton", {
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundColor3 = Theme.Panel2,
		Text = "",
		AutoButtonColor = false,
		Parent = TabsScroll,
	})
	corner(TabButton, UDim.new(0, 13))
	local TabStroke = stroke(TabButton, Theme.StrokeSoft, 1, 0.34)
	gradient(TabButton, Color3.fromRGB(42, 76, 126), Color3.fromRGB(32, 60, 104), 0)

	create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 14, 0, 0),
		Size = UDim2.new(1, -30, 1, 0),
		Text = name,
		TextColor3 = Theme.Text,
		TextSize = 14,
		Font = Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = TabButton,
	})

	local Indicator = create("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.new(0, 5, 0, 24),
		BackgroundColor3 = Theme.Blue,
		BorderSizePixel = 0,
		BackgroundTransparency = 1,
		Parent = TabButton,
	})
	corner(Indicator, UDim.new(1, 0))
	gradient(Indicator, Theme.BlueLight, Theme.BlueDark, 90)

	local Page = create("ScrollingFrame", {
		Visible = false,
		Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = Theme.Blue,
		Parent = Pages,
	})
	padding(Page, 10, 14, 10, 14)
	list(Page, 12)

	local tab = {
		Page = Page,
		Button = TabButton,
		Indicator = Indicator,
		Stroke = TabStroke,
	}

	function tab:Select()
		for _, other in ipairs(Gui.Tabs) do
			other.Page.Visible = false
			playTween(other.Button, 0.18, {BackgroundColor3 = Theme.Panel2})
			playTween(other.Indicator, 0.18, {BackgroundTransparency = 1})
			playTween(other.Stroke, 0.18, {Transparency = 0.34})
		end

		Page.Visible = true
		Gui.CurrentTab = tab

		playTween(TabButton, 0.18, {BackgroundColor3 = Theme.Panel})
		playTween(Indicator, 0.18, {BackgroundTransparency = 0})
		playTween(TabStroke, 0.18, {Transparency = 0.12})
	end

	function tab:CreateSection(sectionTitle)
		local Section = create("Frame", {
			Size = UDim2.new(1, -2, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Theme.Panel,
			BorderSizePixel = 0,
			Parent = Page,
		})
		corner(Section, UDim.new(0, 16))
		stroke(Section, Theme.Stroke, 1, 0.14)
		padding(Section, 12, 12, 12, 12)
		gradient(Section, Color3.fromRGB(34, 64, 112), Color3.fromRGB(28, 52, 96), 0)

		create("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 20),
			Text = sectionTitle,
			TextColor3 = Theme.Text,
			TextSize = 15,
			Font = Enum.Font.GothamBold,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = Section,
		})

		local Divider = create("Frame", {
			Position = UDim2.new(0, 0, 0, 26),
			Size = UDim2.new(1, 0, 0, 1),
			BackgroundColor3 = Theme.Stroke,
			BackgroundTransparency = 0.2,
			BorderSizePixel = 0,
			Parent = Section,
		})
		corner(Divider, UDim.new(1, 0))

		local Content = create("Frame", {
			Position = UDim2.new(0, 0, 0, 34),
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Parent = Section,
		})
		list(Content, 8)

		local elements = {}

		function elements:AddLabel(text)
			local label = create("TextLabel", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 18),
				AutomaticSize = Enum.AutomaticSize.Y,
				Text = text,
				TextWrapped = true,
				TextColor3 = Theme.Text,
				TextSize = 13,
				Font = Enum.Font.Gotham,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = Content,
			})

			local api = {}

			function api:Set(newText)
				label.Text = newText
			end

			return api
		end

		function elements:AddButton(text, callback)
			local button = create("TextButton", {
				Size = UDim2.new(1, 0, 0, 38),
				BackgroundColor3 = Theme.Blue,
				Text = text,
				TextColor3 = Theme.Text,
				TextSize = 14,
				Font = Enum.Font.GothamMedium,
				AutoButtonColor = false,
				Parent = Content,
			})
			corner(button, UDim.new(0, 12))
			gradient(button, Theme.BlueLight, Theme.BlueDark, 0)

			trackConnection(button.MouseEnter:Connect(function()
				playTween(button, 0.12, {BackgroundColor3 = Theme.BlueLight})
			end))

			trackConnection(button.MouseLeave:Connect(function()
				playTween(button, 0.12, {BackgroundColor3 = Theme.Blue})
			end))

			trackConnection(button.MouseButton1Click:Connect(function()
				playTween(button, 0.08, {Size = UDim2.new(1, 0, 0, 35)})
				task.wait(0.08)

				if button.Parent then
					playTween(button, 0.1, {Size = UDim2.new(1, 0, 0, 38)})
				end

				if callback then
					local ok, err = pcall(callback)
					if not ok then
						warn("[LiquidHub] Button callback error:", err)
					end
				end
			end))

			return button
		end

		function elements:AddToggle(text, defaultValue, callback)
			local state = defaultValue == true
			local activeColor = Theme.Blue
			local hoverActiveColor = Theme.BlueLight
			local inactiveColor = Theme.Panel4
			local hoverInactiveColor = Color3.fromRGB(24, 44, 78)
			local bindValue = nil
			local binding = false
			local bindChangedCallback = nil
			local triggerEnabled = true

			local button = create("TextButton", {
				Size = UDim2.new(1, 0, 0, 38),
				BackgroundColor3 = state and activeColor or inactiveColor,
				Text = text,
				TextColor3 = Theme.Text,
				TextSize = 14,
				Font = Enum.Font.GothamMedium,
				AutoButtonColor = false,
				Parent = Content,
			})
			corner(button, UDim.new(0, 12))
			stroke(button, Theme.StrokeSoft, 1, 0.22)

			local bindLabel = create("TextLabel", {
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -12, 0.5, 0),
				Size = UDim2.new(0, 44, 1, 0),
				Text = "",
				TextColor3 = Theme.Tag,
				TextSize = 12,
				Font = Enum.Font.Code,
				TextXAlignment = Enum.TextXAlignment.Right,
				Parent = button,
			})

			local hovering = false
			local function refreshBindLabel()
				if binding then
					bindLabel.Text = "..."
				elseif bindValue and bindValue.EnumType == Enum.KeyCode then
					local shown = tostring(bindValue.Name or "")
					if #shown > 6 then
						shown = shown:sub(1, 6)
					end
					bindLabel.Text = shown
				else
					bindLabel.Text = ""
				end
			end

			local function applyVisual()
				local target
				if state then
					target = hovering and hoverActiveColor or activeColor
				else
					target = hovering and hoverInactiveColor or inactiveColor
				end
				playTween(button, 0.12, {BackgroundColor3 = target})
			end

			trackConnection(button.MouseEnter:Connect(function()
				hovering = true
				applyVisual()
			end))

			trackConnection(button.MouseLeave:Connect(function()
				hovering = false
				applyVisual()
			end))

			local api = {}

			function api:Set(value, silent)
				state = value == true
				applyVisual()
				if not silent and callback then
					local ok, err = pcall(callback, state)
					if not ok then
						warn("[LiquidHub] Toggle callback error:", err)
					end
				end
			end

			function api:Get()
				return state
			end

			function api:SetBind(value, silent)
				bindValue = value
				binding = false
				refreshBindLabel()
				if not silent and bindChangedCallback then
					local ok, err = pcall(bindChangedCallback, bindValue)
					if not ok then
						warn("[LiquidHub] Toggle bind callback error:", err)
					end
				end
			end

			function api:GetBind()
				return bindValue
			end

			function api:OnBindChanged(cb)
				bindChangedCallback = cb
			end

			function api:SetTriggerEnabled(value)
				triggerEnabled = value ~= false
			end

			trackConnection(button.MouseButton1Click:Connect(function()
				if binding then
					return
				end
				playTween(button, 0.08, {Size = UDim2.new(1, 0, 0, 35)})
				task.wait(0.08)
				if button.Parent then
					playTween(button, 0.1, {Size = UDim2.new(1, 0, 0, 38)})
				end
				api:Set(not state)
			end))

			trackConnection(button.MouseButton2Click:Connect(function()
				binding = true
				refreshBindLabel()
			end))

			trackConnection(UserInputService.InputBegan:Connect(function(input, processed)
				if Gui.Destroyed or UserInputService:GetFocusedTextBox() then
					return
				end

				if binding then
					if input.UserInputType == Enum.UserInputType.Keyboard then
						if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.Backspace then
							api:SetBind(nil)
						elseif input.KeyCode ~= Enum.KeyCode.Unknown then
							api:SetBind(input.KeyCode)
						end
					end
					return
				end

				if processed or not triggerEnabled then
					return
				end

				if bindValue and bindValue.EnumType == Enum.KeyCode and input.KeyCode == bindValue then
					api:Set(not state)
				end
			end))

			refreshBindLabel()
			applyVisual()
			return api
		end

		function elements:AddTextbox(text, placeholder, callback)
			local holder = create("Frame", {
				Size = UDim2.new(1, 0, 0, 58),
				BackgroundColor3 = Theme.Panel2,
				BorderSizePixel = 0,
				ClipsDescendants = true,
				Parent = Content,
			})
			corner(holder, UDim.new(0, 14))
			stroke(holder, Theme.StrokeSoft, 1, 0.2)
			gradient(holder, Color3.fromRGB(46, 82, 136), Color3.fromRGB(34, 62, 110), 0)

			create("TextLabel", {
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 12, 0, 6),
				Size = UDim2.new(1, -24, 0, 16),
				Text = text,
				TextColor3 = Theme.Text,
				TextSize = 13,
				Font = Enum.Font.GothamMedium,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = holder,
			})

			local box = create("TextBox", {
				Position = UDim2.new(0, 12, 0, 28),
				Size = UDim2.new(1, -24, 0, 22),
				BackgroundColor3 = Theme.Panel4,
				BorderSizePixel = 0,
				Text = "",
				PlaceholderText = placeholder or "",
				TextColor3 = Theme.Text,
				PlaceholderColor3 = Theme.Text,
				TextSize = 13,
				Font = Enum.Font.Code,
				ClearTextOnFocus = false,
				MultiLine = false,
				RichText = false,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
				Parent = holder,
			})
			corner(box, UDim.new(0, 10))
			gradient(box, Color3.fromRGB(24, 44, 78), Color3.fromRGB(20, 38, 70), 0)

			trackConnection(box.FocusLost:Connect(function(enterPressed)
				if callback then
					local ok, err = pcall(callback, box.Text, enterPressed)
					if not ok then
						warn("[LiquidHub] Textbox callback error:", err)
					end
				end
			end))

			local api = {}

			function api:Set(value)
				box.Text = tostring(value or "")
			end

			function api:Get()
				return box.Text
			end

			return api
		end

		function elements:AddDropdown(text, options, defaultValue, callback)
			local holder = create("Frame", {
				Size = UDim2.new(1, 0, 0, 58),
				BackgroundColor3 = Theme.Panel2,
				BorderSizePixel = 0,
				ClipsDescendants = false,
				Parent = Content,
			})
			corner(holder, UDim.new(0, 14))
			stroke(holder, Theme.StrokeSoft, 1, 0.2)
			gradient(holder, Color3.fromRGB(46, 82, 136), Color3.fromRGB(34, 62, 110), 0)

			create("TextLabel", {
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 12, 0, 6),
				Size = UDim2.new(1, -24, 0, 16),
				Text = text,
				TextColor3 = Theme.Text,
				TextSize = 13,
				Font = Enum.Font.GothamMedium,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = holder,
			})

			local values = options or {}
			local current = defaultValue or values[1] or "Default"
			local isOpen = false
			local baseHeight = 58
			local menuHeight = math.max(#values * 24 + 8, 32)

			local button = create("TextButton", {
				Position = UDim2.new(0, 12, 0, 28),
				Size = UDim2.new(1, -24, 0, 22),
				BackgroundColor3 = Theme.Panel4,
				BorderSizePixel = 0,
				Text = tostring(current) .. "  ▼",
				TextColor3 = Theme.Text,
				TextSize = 13,
				Font = Enum.Font.Code,
				AutoButtonColor = false,
				Parent = holder,
			})
			corner(button, UDim.new(0, 10))
			gradient(button, Color3.fromRGB(24, 44, 78), Color3.fromRGB(20, 38, 70), 0)

			local menu = create("Frame", {
				Visible = false,
				Position = UDim2.new(0, 12, 0, baseHeight + 4),
				Size = UDim2.new(1, -24, 0, menuHeight),
				BackgroundColor3 = Theme.Panel,
				BorderSizePixel = 0,
				ZIndex = 40,
				Parent = holder,
			})
			corner(menu, UDim.new(0, 10))
			stroke(menu, Theme.StrokeSoft, 1, 0.15)
			gradient(menu, Color3.fromRGB(34, 64, 112), Color3.fromRGB(28, 52, 96), 0)
			padding(menu, 4, 4, 4, 4)
			list(menu, 4)

			local optionButtons = {}

			local function closeMenu()
				isOpen = false
				menu.Visible = false
				holder.Size = UDim2.new(1, 0, 0, baseHeight)
				button.Text = tostring(current) .. "  ▼"
			end

			local function openMenu()
				isOpen = true
				menu.Visible = true
				holder.Size = UDim2.new(1, 0, 0, baseHeight + 4 + menuHeight)
				button.Text = tostring(current) .. "  ▲"
			end

			for i, value in ipairs(values) do
				local option = create("TextButton", {
					Size = UDim2.new(1, 0, 0, 20),
					BackgroundColor3 = Theme.Panel4,
					BorderSizePixel = 0,
					Text = tostring(value),
					TextColor3 = Theme.Text,
					TextSize = 12,
					Font = Enum.Font.GothamMedium,
					AutoButtonColor = false,
					ZIndex = 41,
					Parent = menu,
				})
				corner(option, UDim.new(0, 8))

				trackConnection(option.MouseButton1Click:Connect(function()
					current = tostring(value)
					button.Text = current .. "  ▼"
					closeMenu()

					if callback then
						local ok, err = pcall(callback, current, i)
						if not ok then
							warn("[LiquidHub] Dropdown callback error:", err)
						end
					end
				end))

				table.insert(optionButtons, option)
			end

			trackConnection(button.MouseButton1Click:Connect(function()
				if isOpen then
					closeMenu()
				else
					openMenu()
				end
			end))

			local api = {}

			function api:Set(value)
				current = tostring(value or current)
				button.Text = current .. (isOpen and "  ▲" or "  ▼")
			end

			function api:Get()
				return current
			end

			return api
		end

		function elements:AddSlider(text, minValue, maxValue, defaultValue, callback)
			local holder = create("Frame", {
				Size = UDim2.new(1, 0, 0, 70),
				BackgroundColor3 = Theme.Panel2,
				BorderSizePixel = 0,
				ClipsDescendants = true,
				Parent = Content,
			})
			corner(holder, UDim.new(0, 14))
			stroke(holder, Theme.StrokeSoft, 1, 0.2)
			gradient(holder, Color3.fromRGB(46, 82, 136), Color3.fromRGB(34, 62, 110), 0)

			local title = create("TextLabel", {
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 12, 0, 6),
				Size = UDim2.new(1, -24, 0, 16),
				Text = text,
				TextColor3 = Theme.Text,
				TextSize = 13,
				Font = Enum.Font.GothamMedium,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = holder,
			})

			local valueLabel = create("TextLabel", {
				BackgroundTransparency = 1,
				Position = UDim2.new(1, -72, 0, 6),
				Size = UDim2.new(0, 60, 0, 16),
				Text = tostring(defaultValue or minValue or 0),
				TextColor3 = Theme.Tag,
				TextSize = 12,
				Font = Enum.Font.Code,
				TextXAlignment = Enum.TextXAlignment.Right,
				Parent = holder,
			})

			local track = create("Frame", {
				Position = UDim2.new(0, 12, 0, 38),
				Size = UDim2.new(1, -24, 0, 14),
				BackgroundColor3 = Theme.Panel4,
				BorderSizePixel = 0,
				Parent = holder,
			})
			corner(track, UDim.new(1, 0))

			local fill = create("Frame", {
				Size = UDim2.new(0, 0, 1, 0),
				BackgroundColor3 = Theme.Blue,
				BorderSizePixel = 0,
				Parent = track,
			})
			corner(fill, UDim.new(1, 0))
			gradient(fill, Theme.BlueLight, Theme.BlueDark, 0)

			local button = create("TextButton", {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Text = "",
				AutoButtonColor = false,
				Parent = track,
			})

			local minNum = tonumber(minValue) or 0
			local maxNum = tonumber(maxValue) or 100
			local current = tonumber(defaultValue)
			if not current then current = minNum end
			current = math.clamp(current, minNum, maxNum)

			local dragging = false

			local function formatValue(value)
				if math.abs(value - math.floor(value)) < 0.001 then
					return tostring(math.floor(value + 0.5))
				end
				return string.format("%.2f", value)
			end

			local function setFromAlpha(alpha)
				alpha = math.clamp(alpha, 0, 1)
				current = minNum + (maxNum - minNum) * alpha
				fill.Size = UDim2.new(alpha, 0, 1, 0)
				valueLabel.Text = formatValue(current)
				if callback then
					local ok, err = pcall(callback, current, alpha)
					if not ok then
						warn("[LiquidHub] Slider callback error:", err)
					end
				end
			end

			local function setValue(value)
				local n = tonumber(value) or minNum
				n = math.clamp(n, minNum, maxNum)
				local alpha = (n - minNum) / math.max(maxNum - minNum, 0.0001)
				setFromAlpha(alpha)
			end

			local function updateFromInput(input)
				local posX = input.Position.X - track.AbsolutePosition.X
				local alpha = posX / math.max(track.AbsoluteSize.X, 1)
				setFromAlpha(alpha)
			end

			setValue(current)

			trackConnection(button.MouseButton1Down:Connect(function()
				dragging = true
			end))

			trackConnection(UserInputService.InputChanged:Connect(function(input)
				if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
					updateFromInput(input)
				end
			end))

			trackConnection(UserInputService.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					dragging = false
				end
			end))

			local api = {}

			function api:Set(value)
				setValue(value)
			end

			function api:Get()
				return current
			end

			return api
		end

		return elements
	end

	table.insert(Gui.Tabs, tab)

	trackConnection(TabButton.MouseButton1Click:Connect(function()
		tab:Select()
	end))

	if not Gui.CurrentTab then
		tab:Select()
	end

	return tab
end

--// =========================================================
--// UI CONTENT
--// =========================================================
--// Current notes:
--// - This section now contains the live Aimlock and Settings pages.
--// - Add future features here or move each feature area into its own module.
--// - Keep page controls aligned with the features that are actually implemented.


local ConfigStorage = {
	Folder = "LiquidHub",
	File = "LiquidHub/config.json",
}

local function ensureConfigFolder()
	local mk = rawget(_G, "makefolder") or makefolder
	local isf = rawget(_G, "isfolder") or isfolder
	if type(mk) == "function" then
		if type(isf) == "function" then
			local ok, exists = pcall(isf, ConfigStorage.Folder)
			if ok and exists then
				return true
			end
		end
		pcall(mk, ConfigStorage.Folder)
		return true
	end
	return false
end

local function writeConfigString(content)
	local wf = rawget(_G, "writefile") or writefile
	if type(wf) == "function" then
		ensureConfigFolder()
		local ok = pcall(wf, ConfigStorage.File, content)
		if ok then
			return true
		end
	end

	if hasGetGenv and genv then
		genv.__LiquidHub_ConfigCache__ = content
		return true
	end

	return false
end

local function readConfigString()
	local rf = rawget(_G, "readfile") or readfile
	local isf = rawget(_G, "isfile") or isfile
	if type(rf) == "function" then
		if type(isf) == "function" then
			local ok, exists = pcall(isf, ConfigStorage.File)
			if ok and not exists then
				if hasGetGenv and genv and type(genv.__LiquidHub_ConfigCache__) == "string" then
					return genv.__LiquidHub_ConfigCache__
				end
				return nil
			end
		end

		local ok, content = pcall(rf, ConfigStorage.File)
		if ok and type(content) == "string" and content ~= "" then
			return content
		end
	end

	if hasGetGenv and genv and type(genv.__LiquidHub_ConfigCache__) == "string" then
		return genv.__LiquidHub_ConfigCache__
	end

	return nil
end

local function saveConfigTable(tbl)
	local ok, encoded = pcall(function()
		return HttpService:JSONEncode(tbl)
	end)
	if not ok or type(encoded) ~= "string" then
		return false, "Encode failed"
	end
	if writeConfigString(encoded) then
		return true
	end
	return false, "writefile unavailable"
end

local function loadConfigTable()
	local raw = readConfigString()
	if not raw then
		return nil, "No saved config found"
	end
	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	if not ok or type(decoded) ~= "table" then
		return nil, "Config decode failed"
	end
	return decoded
end

local MainTab = Gui:CreateTab("Aimlock")
local ESPTab = Gui:CreateTab("ESP")
local PlayerTab = Gui:CreateTab("Player")
local SettingsTab = Gui:CreateTab("Settings")

local MainSection = MainTab:CreateSection("Aimlock Settings")

local AimStatus = MainSection:AddLabel("Status: Disabled")
local AimFOV = MainSection:AddLabel("FOV Preview: 80")
local AimSmooth = MainSection:AddLabel("Smoothness: 0.18")
local AimPrediction = MainSection:AddLabel("Prediction: 0.12")
local AimActivationModeLabel = MainSection:AddLabel("Activation Mode: Hold")
local AimActivationKeyLabel = MainSection:AddLabel("Activation Key: MouseButton2")
local AimWallCheckLabel = MainSection:AddLabel("Wall Check: Enabled")
local AimTeamCheckLabel = MainSection:AddLabel("Team Check: Enabled")

local AimAssistEnabled = false
local AimFOVValue = 80
local AimSmoothValue = 0.18
local AimPredictionValue = 0.12
local AimActivationModeValue = "Hold"
local AimActivationInputValue = Enum.UserInputType.MouseButton2
local AimWallCheckValue = true
local AimTeamCheckValue = true
local CompatibilityModeValue = false
local AimSettingsChangeToken = 0
local AimBindCaptureConnection = nil
_G.__LiquidHub_AimEnabled__ = AimAssistEnabled

local function getCandidateCharacters()
	local candidates = {}

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and player.Character then
			table.insert(candidates, player.Character)
		end
	end

	return candidates
end

local function formatActivationInput(input)
	if typeof(input) ~= "EnumItem" then
		return "Unknown"
	end

	if input.EnumType == Enum.KeyCode then
		return input.Name
	end

	return input.Name
end


local function enumToStoredValue(input)
	if typeof(input) ~= "EnumItem" then
		return nil
	end
	return {
		EnumType = tostring(input.EnumType),
		Name = input.Name,
	}
end

local function storedValueToEnum(data)
	if type(data) ~= "table" or type(data.Name) ~= "string" or type(data.EnumType) ~= "string" then
		return nil
	end

	if data.EnumType == "Enum.KeyCode" then
		return Enum.KeyCode[data.Name]
	elseif data.EnumType == "Enum.UserInputType" then
		return Enum.UserInputType[data.Name]
	end

	return nil
end

local function isBindableInput(input)
	if input.UserInputType == Enum.UserInputType.Keyboard then
		return input.KeyCode ~= Enum.KeyCode.Unknown
	end

	return input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.MouseButton2
		or input.UserInputType == Enum.UserInputType.MouseButton3
end

local AimController = AimAssist.new({
	Enabled = AimAssistEnabled,
	FOVRadius = AimFOVValue,
	Smoothing = AimSmoothValue,
	Prediction = AimPredictionValue,
	AimPartName = "Head",
	RequireHold = true,
	HoldInput = AimActivationInputValue,
	ActivationInput = AimActivationInputValue,
	ActivationMode = AimActivationModeValue,
	TeamCheck = AimTeamCheckValue,
	VisibleCheck = AimWallCheckValue,
	CompatibilityMode = CompatibilityModeValue,
})

AimController:Start(getCandidateCharacters)

local function queueAimSettingsApply()
	AimSettingsChangeToken += 1
	local token = AimSettingsChangeToken

	task.delay(0.15, function()
		if Gui.Destroyed or token ~= AimSettingsChangeToken then
			return
		end

		Gui:Notify("Aim settings applied")
	end)
end

local AimAssistToggle = MainSection:AddToggle("AimAssist", AimAssistEnabled, function(state)
	AimAssistEnabled = state
	_G.__LiquidHub_AimEnabled__ = AimAssistEnabled
	AimController.Enabled = AimAssistEnabled
	AimStatus:Set("Status: " .. (AimAssistEnabled and "Enabled" or "Disabled"))
	refreshFOVPreviewVisibility()
	Gui:Notify("AimAssist " .. (AimAssistEnabled and "enabled" or "disabled"))
end)

local AimWallToggle = MainSection:AddToggle("Wall Check", AimWallCheckValue, function(state)
	AimWallCheckValue = state
	AimController.VisibleCheck = AimWallCheckValue
	AimController.CurrentTarget = nil
	AimWallCheckLabel:Set("Wall Check: " .. (AimWallCheckValue and "Enabled" or "Disabled"))
	Gui:Notify("Wall check " .. (AimWallCheckValue and "enabled" or "disabled"))
	queueAimSettingsApply()
end)

local AimTeamToggle = MainSection:AddToggle("Team Check", AimTeamCheckValue, function(state)
	AimTeamCheckValue = state
	AimController.TeamCheck = AimTeamCheckValue
	AimController.CurrentTarget = nil
	AimTeamCheckLabel:Set("Team Check: " .. (AimTeamCheckValue and "Enabled" or "Disabled"))
	Gui:Notify("Team check " .. (AimTeamCheckValue and "enabled" or "disabled"))
	queueAimSettingsApply()
end)

local AimActivationModeDropdown = MainSection:AddDropdown("Activation Mode", {"Hold", "Toggle"}, AimActivationModeValue, function(value)
	AimActivationModeValue = value
	AimController.ActivationMode = AimActivationModeValue
	AimController.RequireHold = AimActivationModeValue == "Hold"
	AimController.IsAiming = false
	AimController.CurrentTarget = nil
	AimActivationModeLabel:Set("Activation Mode: " .. AimActivationModeValue)
	queueAimSettingsApply()
end)

MainSection:AddButton("Change Activation Key", function()
	if AimBindCaptureConnection then
		pcall(function()
			AimBindCaptureConnection:Disconnect()
		end)
		AimBindCaptureConnection = nil
	end


	AimActivationKeyLabel:Set("Activation Key: Listening...")
	Gui:Notify("Press any keyboard key or mouse button")

	task.defer(function()
		AimBindCaptureConnection = UserInputService.InputBegan:Connect(function(input)
			if Gui.Destroyed then
				return
			end

			if not isBindableInput(input) then
				return
			end

			AimActivationInputValue = input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode or input.UserInputType
			AimController.ActivationInput = AimActivationInputValue
			AimController.HoldInput = AimActivationInputValue
			AimController.IsAiming = false
			AimController.CurrentTarget = nil
			AimActivationKeyLabel:Set("Activation Key: " .. formatActivationInput(AimActivationInputValue))
			Gui:Notify("Activation key set to " .. formatActivationInput(AimActivationInputValue))
			queueAimSettingsApply()

			if AimBindCaptureConnection then
				pcall(function()
					AimBindCaptureConnection:Disconnect()
				end)
				AimBindCaptureConnection = nil
			end
		end)
	end)
end)

local AimFOVSlider = MainSection:AddSlider("FOV", 20, 200, 80, function(value)
	AimFOVValue = math.floor(value + 0.5)
	AimController.FOVRadius = AimFOVValue
	AimFOV:Set("FOV Preview: " .. tostring(AimFOVValue))
	setFOVPreviewSize(AimFOVValue)
	queueAimSettingsApply()
end)

local AimSmoothSlider = MainSection:AddSlider("Smoothness", 0.01, 1.00, 0.18, function(value)
	AimSmoothValue = math.floor(value * 100 + 0.5) / 100
	AimController.Smoothing = AimSmoothValue
	AimSmooth:Set("Smoothness: " .. string.format("%.2f", AimSmoothValue))
	queueAimSettingsApply()
end)

local AimPredictionSlider = MainSection:AddSlider("Prediction", 0.00, 1.00, 0.12, function(value)
	AimPredictionValue = math.floor(value * 100 + 0.5) / 100
	AimController.Prediction = AimPredictionValue
	AimPrediction:Set("Prediction: " .. string.format("%.2f", AimPredictionValue))
	queueAimSettingsApply()
end)



local ESPSection = ESPTab:CreateSection("ESP Settings")

local ESPStatus = ESPSection:AddLabel("Status: Disabled")
local ESPTeamCheckStatus = ESPSection:AddLabel("Team Check: Disabled")
local ESPTeamColorStatus = ESPSection:AddLabel("Team Color: Disabled")
local ESPThicknessStatus = ESPSection:AddLabel("Line Thickness: 2")
local ESPAutoThicknessStatus = ESPSection:AddLabel("Auto Thickness: Enabled")
local ESPColorStatus = ESPSection:AddLabel("Box Color: Red")
local ESPNameStatus = ESPSection:AddLabel("Name ESP: Enabled")
local ESPNameAutoScaleStatus = ESPSection:AddLabel("Name Auto Scale: Enabled")
local ESPNameScaleStatus = ESPSection:AddLabel("Name Scale: 13")

local ESPEnabled = false
local ESPTeamCheckValue = false
local ESPTeamColorValue = false
local ESPThicknessValue = 2
local ESPAutoThicknessValue = true
local ESPColorValue = Color3.fromRGB(255, 0, 0)
local ESPNameValue = true
local ESPNameAutoScaleValue = true
local ESPNameScaleValue = 13

local ESPController = ESP.new({
	Enabled = ESPEnabled,
	BoxColor = ESPColorValue,
	BoxThickness = ESPThicknessValue,
	TeamCheck = ESPTeamCheckValue,
	TeamColor = ESPTeamColorValue,
	AutoThickness = ESPAutoThicknessValue,
	ShowNames = ESPNameValue,
	NameAutoScale = ESPNameAutoScaleValue,
	TextSize = ESPNameScaleValue,
	NameScaleMin = 10,
	NameScaleMax = 28,
	CompatibilityMode = CompatibilityModeValue,
})

local ESPAvailable = ESPController:Start()
if not ESPAvailable then
	ESPStatus:Set("Status: Unsupported")
end

local ESPEnabledToggle = ESPSection:AddToggle("ESP", ESPEnabled, function(state)
	if not ESPAvailable then
		Gui:Notify("Drawing API not available")
		return
	end

	ESPEnabled = state
	ESPController.Enabled = ESPEnabled
	ESPStatus:Set("Status: " .. (ESPEnabled and "Enabled" or "Disabled"))
	Gui:Notify("ESP " .. (ESPEnabled and "enabled" or "disabled"))
end)

local ESPTeamCheckToggle = ESPSection:AddToggle("Team Check", ESPTeamCheckValue, function(state)
	if not ESPAvailable then
		Gui:Notify("Drawing API not available")
		return
	end

	ESPTeamCheckValue = state
	ESPController.TeamCheck = ESPTeamCheckValue
	ESPTeamCheckStatus:Set("Team Check: " .. (ESPTeamCheckValue and "Enabled" or "Disabled"))
	Gui:Notify("ESP team check " .. (ESPTeamCheckValue and "enabled" or "disabled"))
end)

local ESPTeamColorToggle = ESPSection:AddToggle("Team Color", ESPTeamColorValue, function(state)
	if not ESPAvailable then
		Gui:Notify("Drawing API not available")
		return
	end

	ESPTeamColorValue = state
	ESPController.TeamColor = ESPTeamColorValue
	ESPTeamColorStatus:Set("Team Color: " .. (ESPTeamColorValue and "Enabled" or "Disabled"))
	Gui:Notify("ESP team color " .. (ESPTeamColorValue and "enabled" or "disabled"))
end)

local ESPColorDropdown = ESPSection:AddDropdown("Box Color", {"Red", "Green", "Blue", "White", "Yellow"}, "Red", function(value)
	if value == "Red" then
		ESPColorValue = Color3.fromRGB(255, 0, 0)
	elseif value == "Green" then
		ESPColorValue = Color3.fromRGB(0, 255, 0)
	elseif value == "Blue" then
		ESPColorValue = Color3.fromRGB(0, 170, 255)
	elseif value == "White" then
		ESPColorValue = Color3.fromRGB(255, 255, 255)
	else
		ESPColorValue = Color3.fromRGB(255, 255, 0)
	end

	ESPTeamCheckValue = false
	ESPTeamColorValue = false
	ESPController.TeamCheck = false
	ESPController.TeamColor = false
	ESPController.BoxColor = ESPColorValue
	ESPTeamCheckStatus:Set("Team Check: Disabled")
	ESPTeamColorStatus:Set("Team Color: Disabled")
	if ESPTeamCheckToggle then ESPTeamCheckToggle:Set(false, true) end
	if ESPTeamColorToggle then ESPTeamColorToggle:Set(false, true) end
	ESPColorStatus:Set("Box Color: " .. value)
	Gui:Notify("ESP color set to " .. value)
end)

local ESPThicknessSlider = ESPSection:AddSlider("Line Thickness", 1, 4, 2, function(value)
	ESPThicknessValue = math.floor(value + 0.5)
	ESPController.BoxThickness = ESPThicknessValue
	ESPAutoThicknessValue = false
	ESPController.AutoThickness = false
	ESPThicknessStatus:Set("Line Thickness: " .. tostring(ESPThicknessValue))
	ESPAutoThicknessStatus:Set("Auto Thickness: Disabled")
	if ESPAutoThicknessToggle then ESPAutoThicknessToggle:Set(false, true) end
end)

local ESPAutoThicknessToggle = ESPSection:AddToggle("Auto Thickness", ESPAutoThicknessValue, function(state)
	if not ESPAvailable then
		Gui:Notify("Drawing API not available")
		return
	end

	ESPAutoThicknessValue = state
	ESPController.AutoThickness = ESPAutoThicknessValue
	ESPAutoThicknessStatus:Set("Auto Thickness: " .. (ESPAutoThicknessValue and "Enabled" or "Disabled"))
	Gui:Notify("ESP auto thickness " .. (ESPAutoThicknessValue and "enabled" or "disabled"))
end)


local ESPNameToggle = ESPSection:AddToggle("Name ESP", ESPNameValue, function(state)
	if not ESPAvailable then
		Gui:Notify("Drawing API not available")
		return
	end

	ESPNameValue = state
	ESPController.ShowNames = ESPNameValue
	ESPNameStatus:Set("Name ESP: " .. (ESPNameValue and "Enabled" or "Disabled"))
	Gui:Notify("ESP names " .. (ESPNameValue and "enabled" or "disabled"))
end)


local ESPNameAutoScaleToggle = ESPSection:AddToggle("Name Auto Scale", ESPNameAutoScaleValue, function(state)
	if not ESPAvailable then
		Gui:Notify("Drawing API not available")
		return
	end

	ESPNameAutoScaleValue = state
	ESPController.NameAutoScale = ESPNameAutoScaleValue
	ESPNameAutoScaleStatus:Set("Name Auto Scale: " .. (ESPNameAutoScaleValue and "Enabled" or "Disabled"))
	Gui:Notify("Name auto scale " .. (ESPNameAutoScaleValue and "enabled" or "disabled"))
end)

local ESPNameScaleSlider = ESPSection:AddSlider("Name Scale", 10, 28, 13, function(value)
	ESPNameScaleValue = math.floor(value + 0.5)
	ESPController.TextSize = ESPNameScaleValue
	ESPController.NameScaleMin = ESPNameScaleValue
	ESPNameScaleStatus:Set("Name Scale: " .. tostring(ESPNameScaleValue))
	ESPNameAutoScaleValue = false
	ESPController.NameAutoScale = false
	ESPNameAutoScaleStatus:Set("Name Auto Scale: Disabled")
	if ESPNameAutoScaleToggle then
		ESPNameAutoScaleToggle:Set(false, true)
	end
end)



local PlayerSection = PlayerTab:CreateSection("Player Utilities")

local WalkSpeedStatus = PlayerSection:AddLabel("WalkSpeed: 16")
local WalkSpeedMethodStatus = PlayerSection:AddLabel("WalkSpeed Method: Humanoid")
local FlyStatus = PlayerSection:AddLabel("Fly: Disabled")
local FlyMethodStatus = PlayerSection:AddLabel("Fly Method: BodyVelocity")
local NoclipStatus = PlayerSection:AddLabel("Noclip: Disabled")
local NoclipMethodStatus = PlayerSection:AddLabel("Noclip Method: CanCollide")

local WalkSpeedEnabled = false
local WalkSpeedValue = 16
local WalkSpeedMethodValue = "Humanoid"
local FlyEnabled = false
local FlySpeedValue = 60
local FlyMethodValue = "BodyVelocity"
local NoclipEnabled = false
local NoclipMethodValue = "CanCollide"
local WalkSpeedBindValue = Enum.KeyCode.V
local FlyBindValue = Enum.KeyCode.F
local NoclipBindValue = Enum.KeyCode.N

local PlayerController = PlayerUtility.new({
	WalkSpeedEnabled = WalkSpeedEnabled,
	WalkSpeedValue = WalkSpeedValue,
	WalkSpeedKeybind = WalkSpeedBindValue,
	WalkSpeedMethod = WalkSpeedMethodValue,
	FlyEnabled = FlyEnabled,
	FlySpeed = FlySpeedValue,
	FlyKeybind = FlyBindValue,
	FlyMethod = FlyMethodValue,
	NoclipEnabled = NoclipEnabled,
	NoclipKeybind = NoclipBindValue,
	NoclipMethod = NoclipMethodValue,
})

local WalkSpeedToggle
local FlyToggle
local NoclipToggle

local function onWalkSpeedToggle(state, fromKeybind)
	WalkSpeedEnabled = state == true
	PlayerController:SetWalkSpeedEnabled(WalkSpeedEnabled)
	WalkSpeedStatus:Set("WalkSpeed: " .. tostring(WalkSpeedEnabled and WalkSpeedValue or 16))
	if WalkSpeedToggle and WalkSpeedToggle:Get() ~= WalkSpeedEnabled then
		WalkSpeedToggle:Set(WalkSpeedEnabled, true)
	end
	if fromKeybind then
		Gui:Notify("WalkSpeed " .. (WalkSpeedEnabled and "enabled" or "disabled"))
	end
end

local function onFlyToggle(state, fromKeybind)
	FlyEnabled = state == true
	PlayerController:SetFlyEnabled(FlyEnabled)
	FlyStatus:Set("Fly: " .. (FlyEnabled and "Enabled" or "Disabled"))
	if FlyToggle and FlyToggle:Get() ~= FlyEnabled then
		FlyToggle:Set(FlyEnabled, true)
	end
	if fromKeybind then
		Gui:Notify("Fly " .. (FlyEnabled and "enabled" or "disabled"))
	end
end

local function onNoclipToggle(state, fromKeybind)
	NoclipEnabled = state == true
	PlayerController:SetNoclipEnabled(NoclipEnabled)
	NoclipStatus:Set("Noclip: " .. (NoclipEnabled and "Enabled" or "Disabled"))
	if NoclipToggle and NoclipToggle:Get() ~= NoclipEnabled then
		NoclipToggle:Set(NoclipEnabled, true)
	end
	if fromKeybind then
		Gui:Notify("Noclip " .. (NoclipEnabled and "enabled" or "disabled"))
	end
end

PlayerController:Start(onWalkSpeedToggle, onFlyToggle, onNoclipToggle)

WalkSpeedToggle = PlayerSection:AddToggle("WalkSpeed", WalkSpeedEnabled, function(state)
	onWalkSpeedToggle(state, false)
	Gui:Notify("WalkSpeed " .. (state and "enabled" or "disabled"))
end)
WalkSpeedToggle:SetBind(WalkSpeedBindValue, true)
WalkSpeedToggle:OnBindChanged(function(bind)
	WalkSpeedBindValue = bind or Enum.KeyCode.V
	PlayerController.WalkSpeedKeybind = WalkSpeedBindValue
end)

local WalkSpeedSlider = PlayerSection:AddSlider("WalkSpeed Value", 16, 100, 16, function(value)
	WalkSpeedValue = math.floor(value + 0.5)
	PlayerController.WalkSpeedValue = WalkSpeedValue
	WalkSpeedStatus:Set("WalkSpeed: " .. tostring(WalkSpeedEnabled and WalkSpeedValue or 16))
end)

local WalkSpeedMethodDropdown = PlayerSection:AddDropdown("WalkSpeed Method", {"Humanoid", "Velocity"}, WalkSpeedMethodValue, function(value)
	WalkSpeedMethodValue = value
	PlayerController.WalkSpeedMethod = value
	WalkSpeedMethodStatus:Set("WalkSpeed Method: " .. value)
	Gui:Notify("WalkSpeed method: " .. value)
end)

FlyToggle = PlayerSection:AddToggle("Fly", FlyEnabled, function(state)
	onFlyToggle(state, false)
	Gui:Notify("Fly " .. (state and "enabled" or "disabled"))
end)
FlyToggle:SetBind(FlyBindValue, true)
FlyToggle:OnBindChanged(function(bind)
	FlyBindValue = bind or Enum.KeyCode.F
	PlayerController.FlyKeybind = FlyBindValue
end)

local FlySpeedSlider = PlayerSection:AddSlider("Fly Speed", 20, 150, 60, function(value)
	FlySpeedValue = math.floor(value + 0.5)
	PlayerController.FlySpeed = FlySpeedValue
end)

local FlyMethodDropdown = PlayerSection:AddDropdown("Fly Method", {"BodyVelocity", "CFrame"}, FlyMethodValue, function(value)
	FlyMethodValue = value
	PlayerController.FlyMethod = value
	FlyMethodStatus:Set("Fly Method: " .. value)
	Gui:Notify("Fly method: " .. value)
end)

NoclipToggle = PlayerSection:AddToggle("Noclip", NoclipEnabled, function(state)
	onNoclipToggle(state, false)
	Gui:Notify("Noclip " .. (state and "enabled" or "disabled"))
end)
NoclipToggle:SetBind(NoclipBindValue, true)
NoclipToggle:OnBindChanged(function(bind)
	NoclipBindValue = bind or Enum.KeyCode.N
	PlayerController.NoclipKeybind = NoclipBindValue
end)

local NoclipMethodDropdown = PlayerSection:AddDropdown("Noclip Method", {"CanCollide", "FullGhost", "RootOnly"}, NoclipMethodValue, function(value)
	NoclipMethodValue = value
	PlayerController.NoclipMethod = value
	NoclipMethodStatus:Set("Noclip Method: " .. value)
	Gui:Notify("Noclip method: " .. value)
end)

local function collectConfig()
	return {
		Version = 1,
		Aim = {
			Enabled = AimAssistEnabled,
			CompatibilityMode = CompatibilityModeValue,
			FOV = AimFOVValue,
			Smoothness = AimSmoothValue,
			Prediction = AimPredictionValue,
			ActivationMode = AimActivationModeValue,
			ActivationInput = enumToStoredValue(AimActivationInputValue),
			WallCheck = AimWallCheckValue,
			TeamCheck = AimTeamCheckValue,
		},
		ESP = {
			Enabled = ESPEnabled,
			TeamCheck = ESPTeamCheckValue,
			TeamColor = ESPTeamColorValue,
			Thickness = ESPThicknessValue,
			AutoThickness = ESPAutoThicknessValue,
			Color = {R = ESPColorValue.R, G = ESPColorValue.G, B = ESPColorValue.B},
			ShowNames = ESPNameValue,
			NameAutoScale = ESPNameAutoScaleValue,
			NameScale = ESPNameScaleValue,
		},
		Player = {
			WalkSpeedEnabled = WalkSpeedEnabled,
			WalkSpeedValue = WalkSpeedValue,
			WalkSpeedMethod = WalkSpeedMethodValue,
			WalkSpeedKeybind = enumToStoredValue(WalkSpeedToggle and WalkSpeedToggle:GetBind() or WalkSpeedBindValue),
			FlyEnabled = FlyEnabled,
			FlySpeed = FlySpeedValue,
			FlyMethod = FlyMethodValue,
			FlyKeybind = enumToStoredValue(FlyToggle and FlyToggle:GetBind() or FlyBindValue),
			NoclipEnabled = NoclipEnabled,
			NoclipMethod = NoclipMethodValue,
			NoclipKeybind = enumToStoredValue(NoclipToggle and NoclipToggle:GetBind() or NoclipBindValue),
		},
	}
end

local function applyConfig(cfg)
	if type(cfg) ~= "table" then
		return false, "Invalid config"
	end

	local aim = cfg.Aim or {}
	if type(aim.CompatibilityMode) == "boolean" then
		CompatibilityModeValue = aim.CompatibilityMode
		Compat.Enabled = CompatibilityModeValue
		AimController.CompatibilityMode = CompatibilityModeValue
		ESPController.CompatibilityMode = CompatibilityModeValue
		CompatibilityStatus:Set("Compatibility Mode: " .. (CompatibilityModeValue and "Enabled" or "Disabled"))
		if CompatibilityToggle then
			CompatibilityToggle:Set(CompatibilityModeValue, true)
		end
	end
	if type(aim.Enabled) == "boolean" then
		AimAssistToggle:Set(aim.Enabled, true)
		AimAssistEnabled = aim.Enabled
		_G.__LiquidHub_AimEnabled__ = AimAssistEnabled
		AimController.Enabled = aim.Enabled
		AimStatus:Set("Status: " .. (aim.Enabled and "Enabled" or "Disabled"))
		refreshFOVPreviewVisibility()
	end
	if type(aim.WallCheck) == "boolean" then
		AimWallToggle:Set(aim.WallCheck, true)
		AimWallCheckValue = aim.WallCheck
		AimController.VisibleCheck = aim.WallCheck
		AimWallCheckLabel:Set("Wall Check: " .. (aim.WallCheck and "Enabled" or "Disabled"))
	end
	if type(aim.TeamCheck) == "boolean" then
		AimTeamToggle:Set(aim.TeamCheck, true)
		AimTeamCheckValue = aim.TeamCheck
		AimController.TeamCheck = aim.TeamCheck
		AimTeamCheckLabel:Set("Team Check: " .. (aim.TeamCheck and "Enabled" or "Disabled"))
	end
	if type(aim.FOV) == "number" and AimFOVSlider then
		AimFOVSlider:Set(aim.FOV)
	end
	if type(aim.Smoothness) == "number" and AimSmoothSlider then
		AimSmoothSlider:Set(aim.Smoothness)
	end
	if type(aim.Prediction) == "number" and AimPredictionSlider then
		AimPredictionSlider:Set(aim.Prediction)
	end
	if type(aim.ActivationMode) == "string" and AimActivationModeDropdown then
		AimActivationModeDropdown:Set(aim.ActivationMode)
		AimActivationModeValue = aim.ActivationMode
		AimController.ActivationMode = aim.ActivationMode
		AimController.RequireHold = aim.ActivationMode == "Hold"
		AimActivationModeLabel:Set("Activation Mode: " .. aim.ActivationMode)
	end
	local savedAimInput = storedValueToEnum(aim.ActivationInput)
	if savedAimInput then
		AimActivationInputValue = savedAimInput
		AimController.ActivationInput = savedAimInput
		AimController.HoldInput = savedAimInput
		AimActivationKeyLabel:Set("Activation Key: " .. formatActivationInput(savedAimInput))
	end

	local esp = cfg.ESP or {}
	if type(esp.Enabled) == "boolean" then
		ESPEnabledToggle:Set(esp.Enabled, true)
		ESPEnabled = esp.Enabled
		ESPController.Enabled = esp.Enabled
		ESPStatus:Set("Status: " .. (esp.Enabled and "Enabled" or "Disabled"))
	end
	if type(esp.TeamCheck) == "boolean" then
		ESPTeamCheckToggle:Set(esp.TeamCheck, true)
		ESPTeamCheckValue = esp.TeamCheck
		ESPController.TeamCheck = esp.TeamCheck
		ESPTeamCheckStatus:Set("Team Check: " .. (esp.TeamCheck and "Enabled" or "Disabled"))
	end
	if type(esp.TeamColor) == "boolean" then
		ESPTeamColorToggle:Set(esp.TeamColor, true)
		ESPTeamColorValue = esp.TeamColor
		ESPController.TeamColor = esp.TeamColor
		ESPTeamColorStatus:Set("Team Color: " .. (esp.TeamColor and "Enabled" or "Disabled"))
	end
	if type(esp.AutoThickness) == "boolean" then
		ESPAutoThicknessToggle:Set(esp.AutoThickness, true)
		ESPAutoThicknessValue = esp.AutoThickness
		ESPController.AutoThickness = esp.AutoThickness
		ESPAutoThicknessStatus:Set("Auto Thickness: " .. (esp.AutoThickness and "Enabled" or "Disabled"))
	end
	if type(esp.ShowNames) == "boolean" then
		ESPNameToggle:Set(esp.ShowNames, true)
		ESPNameValue = esp.ShowNames
		ESPController.ShowNames = esp.ShowNames
		ESPNameStatus:Set("Name ESP: " .. (esp.ShowNames and "Enabled" or "Disabled"))
	end
	if type(esp.NameAutoScale) == "boolean" then
		ESPNameAutoScaleToggle:Set(esp.NameAutoScale, true)
		ESPNameAutoScaleValue = esp.NameAutoScale
		ESPController.NameAutoScale = esp.NameAutoScale
		ESPNameAutoScaleStatus:Set("Name Auto Scale: " .. (esp.NameAutoScale and "Enabled" or "Disabled"))
	end
	if type(esp.Thickness) == "number" and ESPThicknessSlider then
		ESPThicknessSlider:Set(esp.Thickness)
	end
	if type(esp.NameScale) == "number" and ESPNameScaleSlider then
		ESPNameScaleSlider:Set(esp.NameScale)
	end
	if type(esp.Color) == "table" and type(esp.Color.R) == "number" and type(esp.Color.G) == "number" and type(esp.Color.B) == "number" then
		ESPColorValue = Color3.new(esp.Color.R, esp.Color.G, esp.Color.B)
		ESPController.BoxColor = ESPColorValue
		local colorName = "Custom"
		local presets = {
			Red = Color3.fromRGB(255, 0, 0),
			Green = Color3.fromRGB(0, 255, 0),
			Blue = Color3.fromRGB(0, 170, 255),
			White = Color3.fromRGB(255, 255, 255),
			Yellow = Color3.fromRGB(255, 255, 0),
		}
		for name, value in pairs(presets) do
			if math.abs(value.R - ESPColorValue.R) < 0.001 and math.abs(value.G - ESPColorValue.G) < 0.001 and math.abs(value.B - ESPColorValue.B) < 0.001 then
				colorName = name
				if ESPColorDropdown then
					ESPColorDropdown:Set(name)
				end
				break
			end
		end
		ESPColorStatus:Set("Box Color: " .. colorName)
	end

	local playerCfg = cfg.Player or {}
	if type(playerCfg.WalkSpeedEnabled) == "boolean" then
		WalkSpeedToggle:Set(playerCfg.WalkSpeedEnabled, true)
		onWalkSpeedToggle(playerCfg.WalkSpeedEnabled, false)
	end
	if type(playerCfg.WalkSpeedValue) == "number" and WalkSpeedSlider then
		WalkSpeedSlider:Set(playerCfg.WalkSpeedValue)
	end
	if type(playerCfg.WalkSpeedMethod) == "string" and WalkSpeedMethodDropdown then
		WalkSpeedMethodDropdown:Set(playerCfg.WalkSpeedMethod)
		WalkSpeedMethodValue = playerCfg.WalkSpeedMethod
		PlayerController.WalkSpeedMethod = playerCfg.WalkSpeedMethod
		WalkSpeedMethodStatus:Set("WalkSpeed Method: " .. playerCfg.WalkSpeedMethod)
	end
	local savedWalkBind = storedValueToEnum(playerCfg.WalkSpeedKeybind)
	if savedWalkBind then
		WalkSpeedBindValue = savedWalkBind
		PlayerController.WalkSpeedKeybind = savedWalkBind
		if WalkSpeedToggle then WalkSpeedToggle:SetBind(savedWalkBind, true) end
	end
	if type(playerCfg.FlyEnabled) == "boolean" then
		FlyToggle:Set(playerCfg.FlyEnabled, true)
		onFlyToggle(playerCfg.FlyEnabled, false)
	end
	if type(playerCfg.FlySpeed) == "number" and FlySpeedSlider then
		FlySpeedSlider:Set(playerCfg.FlySpeed)
	end
	if type(playerCfg.FlyMethod) == "string" and FlyMethodDropdown then
		FlyMethodDropdown:Set(playerCfg.FlyMethod)
		FlyMethodValue = playerCfg.FlyMethod
		PlayerController.FlyMethod = playerCfg.FlyMethod
		FlyMethodStatus:Set("Fly Method: " .. playerCfg.FlyMethod)
	end
	local savedFlyBind = storedValueToEnum(playerCfg.FlyKeybind)
	if savedFlyBind then
		FlyBindValue = savedFlyBind
		PlayerController.FlyKeybind = savedFlyBind
		if FlyToggle then FlyToggle:SetBind(savedFlyBind, true) end
	end
	if type(playerCfg.NoclipEnabled) == "boolean" then
		NoclipToggle:Set(playerCfg.NoclipEnabled, true)
		onNoclipToggle(playerCfg.NoclipEnabled, false)
	end
	if type(playerCfg.NoclipMethod) == "string" and NoclipMethodDropdown then
		NoclipMethodDropdown:Set(playerCfg.NoclipMethod)
		NoclipMethodValue = playerCfg.NoclipMethod
		PlayerController.NoclipMethod = playerCfg.NoclipMethod
		NoclipMethodStatus:Set("Noclip Method: " .. playerCfg.NoclipMethod)
	end
	local savedNoclipBind = storedValueToEnum(playerCfg.NoclipKeybind)
	if savedNoclipBind then
		NoclipBindValue = savedNoclipBind
		PlayerController.NoclipKeybind = savedNoclipBind
		if NoclipToggle then NoclipToggle:SetBind(savedNoclipBind, true) end
	end

	return true
end

local ConfigSection = SettingsTab:CreateSection("Config")
ConfigSection:AddLabel("Saves aim, ESP, and player settings to LiquidHub/config.json.")
ConfigSection:AddButton("Save Config", function()
	local ok, err = saveConfigTable(collectConfig())
	if ok then
		Gui:Notify("Config saved")
	else
		Gui:Notify("Config save failed: " .. tostring(err))
	end
end)

ConfigSection:AddButton("Load Config", function()
	local cfg, err = loadConfigTable()
	if not cfg then
		Gui:Notify("Config load failed: " .. tostring(err))
		return
	end
	local ok, applyErr = applyConfig(cfg)
	if ok then
		Gui:Notify("Config loaded")
	else
		Gui:Notify("Config apply failed: " .. tostring(applyErr))
	end
end)

ConfigSection:AddButton("Auto Load Config", function()
	local cfg = loadConfigTable()
	if cfg then
		applyConfig(cfg)
		Gui:Notify("Config auto-loaded")
	else
		Gui:Notify("No saved config found")
	end
end)

local SettingsSection = SettingsTab:CreateSection("Interface")
SettingsSection:AddLabel("Press K to fade the UI in and out.")
SettingsSection:AddLabel("This LiquidHub build is optimized to reduce crash/stutter risk.")
local CompatibilityStatus = SettingsSection:AddLabel("Compatibility Mode: Disabled")
local CompatibilityToggle = SettingsSection:AddToggle("Compatibility Mode", CompatibilityModeValue, function(state)
	CompatibilityModeValue = state
	Compat.Enabled = state
	AimController.CompatibilityMode = state
	ESPController.CompatibilityMode = state
	CompatibilityStatus:Set("Compatibility Mode: " .. (state and "Enabled" or "Disabled"))
	Gui:Notify("Compatibility mode " .. (state and "enabled" or "disabled"))
end)

SettingsSection:AddButton("Unload", function()
	Gui:Destroy()
end)

SettingsSection:AddButton("Reload", function()
	local reload
	if hasGetGenv and genv and type(genv.__LiquidHub_Reload__) == "function" then
		reload = genv.__LiquidHub_Reload__
	end

	Gui:Destroy()

	if reload then
		task.delay(0.05, function()
			pcall(reload)
		end)
	end
end)

--// =========================================================
--// CLEANUP / DESTROY
--// =========================================================
--// Current notes:
--// - Add new cleanup responsibilities here whenever new background work is introduced.
--// - Avoid destroying GUI or drawing objects manually from scattered code paths.
--// - Prefer Gui:Destroy() as the only full unload entry point.

function Gui:Destroy()
	if Gui.Destroyed then
		return
	end

	Gui.Ready = false
	Gui.Destroyed = true
	Destroyed = true

	for _, conn in ipairs(Connections) do
		pcall(function()
			conn:Disconnect()
		end)
	end
	table.clear(Connections)

	for object, tw in pairs(ActiveTweens) do
		pcall(function()
			tw:Cancel()
		end)
		ActiveTweens[object] = nil
	end

	if AimBindCaptureConnection then
		pcall(function()
			AimBindCaptureConnection:Disconnect()
		end)
		AimBindCaptureConnection = nil
	end


	if AimController then
		AimController:Stop()
	end

	if ESPController then
		ESPController:Stop()
	end

	if PlayerController then
		PlayerController:Stop()
	end

	if FOVPreview then
		FOVPreview.Visible = false
	end

	applyGuiMouseUnlock(false)

	if ScreenGui and ScreenGui.Parent then
		ScreenGui:Destroy()
	end
end

if hasGetGenv and genv then
	genv[GLOBAL_KEY] = function()
		Gui:Destroy()
	end

	--// NOTE:
	--// Reload depends on executor-provided request/loadstring support.
	--// Replace this with a controlled update system if LiquidHub becomes production-facing.
	genv.__LiquidHub_Reload__ = function()
		local loader = rawget(genv, "loadstring") or loadstring
		local req = getRequestFunction and getRequestFunction()
		if loader and req then
			local response = req({
				Url = "https://raw.githubusercontent.com/Razzart55/LiquidHub/main/LiquidHub.lua",
				Method = "GET",
			})
			if response and (response.StatusCode == 200 or response.Success) and response.Body then
				local chunk = loader(response.Body)
				if chunk then
					return chunk()
				end
			end
		end

		warn("[LiquidHub] Reload failed: request/loadstring unavailable or remote fetch failed.")
	end
end

--// =========================================================
--// INPUT / INTERACTION
--// =========================================================
--// Current notes:
--// - Hotkeys should always respect focused textboxes.
--// - If more shortcuts are added, keep them centralized here.
--// - Avoid binding the same key in multiple places.

trackConnection(Close.MouseButton1Click:Connect(function()
	Gui:SetVisible(false)
end))

--// Login and loading flow removed.

trackConnection(Close.MouseEnter:Connect(function()
	playTween(Close, 0.12, {BackgroundColor3 = Theme.Danger})
end))

trackConnection(Close.MouseLeave:Connect(function()
	playTween(Close, 0.12, {BackgroundColor3 = Theme.Panel2})
end))

trackConnection(UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if Gui.Destroyed or gameProcessed then
		return
	end

	if UserInputService:GetFocusedTextBox() then
		return
	end

	if input.KeyCode == Enum.KeyCode.K then
		if Gui.Locked or not Gui.Ready then
			return
		end

		if not Main.Visible then
			ScreenGui.Enabled = true
			Main.Visible = true
			Gui.Busy = false
			Gui.Open = false
		end

		Gui:Toggle()
	end
end))

trackConnection(ScreenGui.AncestryChanged:Connect(function(_, parent)
	if not parent then
		Gui:Destroy()
	end
end))

--// =========================================================
--// INITIALIZE
--// =========================================================
--// Current notes:
--// - Gui.Ready only becomes true after required objects and bindings exist.
--// - The UI opens directly in this build.
--// - Keep startup side effects small.

Main.Visible = true
Gui.Open = false
Gui.Ready = true
ScreenGui.Enabled = true

do
	local startupCfg = loadConfigTable()
	if startupCfg then
		pcall(function()
			applyConfig(startupCfg)
		end)
	end
	refreshFOVPreviewVisibility()
end

Gui:Notify("LiquidHub ready")
Gui:SetVisible(true)

--// =========================================================
--// FUTURE FEATURE MAP
--// =========================================================
--// Current roadmap:
--// 1. Add any new utility pages as separate tabs.
--// 2. Move large feature areas into separate modules once the file grows again.
--// 3. Route long-running work through a single state manager.
--// 4. Keep any trust-sensitive logic off the client whenever possible.
