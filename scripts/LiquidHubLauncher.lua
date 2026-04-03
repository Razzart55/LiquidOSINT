local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer and (LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", 10))
if not LocalPlayer or not PlayerGui then
	return
end

local GLOBAL_KEY = "__LiquidHubLauncher_Cleanup__"
local hasGetGenv, genv = pcall(function()
	return getgenv and getgenv()
end)
if hasGetGenv and genv and type(genv[GLOBAL_KEY]) == "function" then
	pcall(genv[GLOBAL_KEY])
	genv[GLOBAL_KEY] = nil
end

local oldGui = PlayerGui:FindFirstChild("LiquidHubLauncherGUI")
if oldGui then
	oldGui:Destroy()
end

local Theme = {
	Panel = Color3.fromRGB(24, 48, 88),
	Panel2 = Color3.fromRGB(36, 68, 118),
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

local REQUIRED_KEY = "lq102"
local LOGO_URL = "https://github.com/Razzart55/LiquidHub/blob/main/Liquid%20Logo.png?raw=true"
local LOGO_FILE = "LiquidHub/Liquid Logo.png"
local ENTRIES = {
	{Name = "Main GUI", Description = "Launch the local LiquidHub main GUI.", LocalFile = "LiquidHubMainGUI.lua"},
	{Name = "Script Slot 2", Description = "Add a loadstring here later.", LoadstringSource = nil},
	{Name = "Script Slot 3", Description = "Add a loadstring here later.", LoadstringSource = nil},
}

local function create(className, props)
	local obj = Instance.new(className)
	for k, v in pairs(props or {}) do obj[k] = v end
	return obj
end
local function corner(parent, px) local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, px or 12) c.Parent = parent return c end
local function stroke(parent, color, thickness, transparency) local s = Instance.new("UIStroke") s.Color = color or Theme.Stroke s.Thickness = thickness or 1 s.Transparency = transparency or 0 s.Parent = parent return s end
local function gradient(parent, a, b, r) local g = Instance.new("UIGradient") g.Color = ColorSequence.new(a, b) g.Rotation = r or 0 g.Parent = parent return g end
local function list(parent, pad) local l = Instance.new("UIListLayout") l.Padding = UDim.new(0, pad or 8) l.SortOrder = Enum.SortOrder.LayoutOrder l.Parent = parent return l end
local function tween(obj, t, props) local tw = TweenService:Create(obj, TweenInfo.new(t, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), props) tw:Play() return tw end

local function resolveRequest()
	local env = (hasGetGenv and genv) or nil
	return rawget(_G, "request") or rawget(_G, "http_request") or (rawget(_G, "syn") and rawget(_G.syn, "request")) or (env and rawget(env, "request")) or (env and rawget(env, "http_request"))
end
local function resolveAsset()
	local env = (hasGetGenv and genv) or nil
	return rawget(_G, "getcustomasset") or rawget(_G, "getsynasset") or (rawget(_G, "syn") and rawget(_G.syn, "asset")) or (env and rawget(env, "getcustomasset")) or (env and rawget(env, "getsynasset"))
end
local function ensureFolder(path) local mk = rawget(_G, "makefolder") or makefolder if type(mk) == "function" then pcall(mk, path) end end
local function prepareLogo()
	local isfileFn = rawget(_G, "isfile") or isfile
	local writefileFn = rawget(_G, "writefile") or writefile
	local req = resolveRequest()
	if type(isfileFn) == "function" then local ok, exists = pcall(isfileFn, LOGO_FILE) if ok and exists then return end end
	if type(writefileFn) == "function" and type(req) == "function" then
		ensureFolder("LiquidHub")
		local ok, response = pcall(req, {Url = LOGO_URL, Method = "GET"})
		if ok and response and (response.Success or response.StatusCode == 200) and response.Body then pcall(writefileFn, LOGO_FILE, response.Body) end
	end
end
local function createLogo(parent)
	prepareLogo()
	local isfileFn = rawget(_G, "isfile") or isfile
	local assetFn = resolveAsset()
	if type(isfileFn) ~= "function" or type(assetFn) ~= "function" then return end
	local ok, exists = pcall(isfileFn, LOGO_FILE)
	if not ok or not exists then return end
	local okAsset, asset = pcall(assetFn, LOGO_FILE)
	if not okAsset or not asset then return end
	return create("ImageLabel", {
		BackgroundTransparency = 1, Image = asset, ScaleType = Enum.ScaleType.Fit,
		Size = UDim2.new(0, 88, 0, 88), Position = UDim2.new(1, -106, 0, 10), Parent = parent
	})
end

local MouseState = {Active = false, PrevBehavior = nil, PrevIcon = nil, Conn = nil}
local function setMouseUnlocked(on)
	if on then
		if not MouseState.Active then MouseState.Active = true MouseState.PrevBehavior = UserInputService.MouseBehavior MouseState.PrevIcon = UserInputService.MouseIconEnabled end
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
		if not MouseState.Conn then
			MouseState.Conn = RunService.RenderStepped:Connect(function()
				if MouseState.Active then
					UserInputService.MouseBehavior = Enum.MouseBehavior.Default
					UserInputService.MouseIconEnabled = true
				end
			end)
		end
	else
		MouseState.Active = false
		if MouseState.Conn then MouseState.Conn:Disconnect() MouseState.Conn = nil end
		if MouseState.PrevBehavior ~= nil then UserInputService.MouseBehavior = MouseState.PrevBehavior end
		if MouseState.PrevIcon ~= nil then UserInputService.MouseIconEnabled = MouseState.PrevIcon end
	end
end

local ScreenGui = create("ScreenGui", {
	Name = "LiquidHubLauncherGUI", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 55,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = PlayerGui
})
local Root = create("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(8, 18, 36), BackgroundTransparency = 0.08, BorderSizePixel = 0, Parent = ScreenGui})
local Window = create("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0, 520, 0, 360), BackgroundColor3 = Theme.Panel, BorderSizePixel = 0, Parent = Root})
corner(Window, 20) stroke(Window, Theme.Stroke, 1, 0.1) gradient(Window, Color3.fromRGB(30, 58, 102), Color3.fromRGB(22, 42, 80), 0)
create("TextLabel", {BackgroundTransparency = 1, Position = UDim2.new(0, 20, 0, 18), Size = UDim2.new(1, -120, 0, 24), Text = "liquidlauncher", TextColor3 = Theme.Text, TextSize = 20, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, Parent = Window})
create("TextLabel", {BackgroundTransparency = 1, Position = UDim2.new(0, 20, 0, 42), Size = UDim2.new(1, -120, 0, 16), Text = "Verify your key, then choose which script to launch.", TextColor3 = Theme.Tag, TextSize = 12, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, Parent = Window})
createLogo(Window)
local Close = create("TextButton", {Size = UDim2.new(0, 32, 0, 32), Position = UDim2.new(1, -44, 0, 18), BackgroundColor3 = Theme.Panel2, Text = "X", TextColor3 = Theme.Text, TextSize = 20, Font = Enum.Font.GothamBold, AutoButtonColor = false, Parent = Window})
corner(Close, 12) stroke(Close, Theme.StrokeSoft, 1, 0.32) gradient(Close, Color3.fromRGB(44, 78, 130), Color3.fromRGB(30, 58, 102), 90)

local Content = create("Frame", {Position = UDim2.new(0, 20, 0, 86), Size = UDim2.new(1, -40, 1, -106), BackgroundTransparency = 1, Parent = Window})
local LoginPage = create("Frame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = Content})
local LoadingPage = create("Frame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = Content})
local SelectorPage = create("Frame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = Content})

local AuthBox = create("TextBox", {
	Position = UDim2.new(0, 0, 0, 16), Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = Theme.Panel4,
	BorderSizePixel = 0, Text = "", PlaceholderText = "", TextColor3 = Theme.Text, TextTransparency = 1,
	TextSize = 14, Font = Enum.Font.Code, ClearTextOnFocus = false, Parent = LoginPage
})
corner(AuthBox, 12) stroke(AuthBox, Theme.StrokeSoft, 1, 0.2) gradient(AuthBox, Color3.fromRGB(24, 44, 78), Color3.fromRGB(20, 38, 70), 0)
local Mask = create("TextLabel", {BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = "", TextColor3 = Theme.Text, TextSize = 14, Font = Enum.Font.Code, Parent = AuthBox})
local Placeholder = create("TextLabel", {BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = "Enter key...", TextColor3 = Theme.Tag, TextSize = 14, Font = Enum.Font.Code, Parent = AuthBox})
local Status = create("TextLabel", {BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 64), Size = UDim2.new(1, 0, 0, 14), Text = "", TextColor3 = Theme.Danger, TextSize = 11, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, Parent = LoginPage})
local Submit = create("TextButton", {Position = UDim2.new(0, 0, 0, 92), Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = Theme.Blue, Text = "Verify Key", TextColor3 = Theme.Text, TextSize = 14, Font = Enum.Font.GothamMedium, AutoButtonColor = false, Parent = LoginPage})
corner(Submit, 12) gradient(Submit, Theme.BlueLight, Theme.BlueDark, 0)
create("TextLabel", {BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 142), Size = UDim2.new(1, 0, 0, 36), TextWrapped = true, Text = "After verification, the launcher shows your script selector.\nEdit the ENTRIES table to add loadstrings later.", TextColor3 = Theme.Tag, TextSize = 12, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = LoginPage})

local LoadingText = create("TextLabel", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20), Text = "Initializing launcher...", TextColor3 = Theme.Text, TextSize = 14, Font = Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Left, Parent = LoadingPage})
local LoadingBarBack = create("Frame", {Position = UDim2.new(0, 0, 0, 42), Size = UDim2.new(1, 0, 0, 18), BackgroundColor3 = Theme.Panel4, BorderSizePixel = 0, Parent = LoadingPage})
corner(LoadingBarBack, 9) stroke(LoadingBarBack, Theme.StrokeSoft, 1, 0.1)
local LoadingBarFill = create("Frame", {Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = Theme.Blue, BorderSizePixel = 0, Parent = LoadingBarBack})
corner(LoadingBarFill, 9) gradient(LoadingBarFill, Theme.BlueLight, Theme.BlueDark, 0)
local LoadingPercent = create("TextLabel", {BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 68), Size = UDim2.new(1, 0, 0, 18), Text = "0%", TextColor3 = Theme.Tag, TextSize = 12, Font = Enum.Font.Code, TextXAlignment = Enum.TextXAlignment.Right, Parent = LoadingPage})

create("TextLabel", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20), Text = "Available Scripts", TextColor3 = Theme.Text, TextSize = 16, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, Parent = SelectorPage})
create("TextLabel", {BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 22), Size = UDim2.new(1, 0, 0, 18), Text = "Replace placeholder entries with loadstrings when ready.", TextColor3 = Theme.Tag, TextSize = 12, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, Parent = SelectorPage})
local EntriesHolder = create("ScrollingFrame", {Position = UDim2.new(0, 0, 0, 52), Size = UDim2.new(1, 0, 1, -52), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = SelectorPage})
list(EntriesHolder, 10)

local Notifs = create("Frame", {AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 20, 1, -20), Size = UDim2.new(0, 340, 0, 220), BackgroundTransparency = 1, ClipsDescendants = true, Parent = Root})
local notifList = list(Notifs, 10) notifList.VerticalAlignment = Enum.VerticalAlignment.Bottom
local live = {}
local function notify(text)
	while #live >= 3 do local n = table.remove(live, 1) if n and n.Parent then n:Destroy() end end
	local note = create("Frame", {Size = UDim2.new(1, 0, 0, 64), BackgroundColor3 = Theme.Panel, BackgroundTransparency = 1, BorderSizePixel = 0, Parent = Notifs})
	corner(note, 14) stroke(note, Theme.StrokeSoft, 1, 1) gradient(note, Color3.fromRGB(30, 58, 102), Color3.fromRGB(22, 42, 80), 0)
	local label = create("TextLabel", {BackgroundTransparency = 1, Position = UDim2.new(0, 14, 0, 10), Size = UDim2.new(1, -28, 1, -20), TextWrapped = true, Text = tostring(text), TextColor3 = Theme.Text, TextTransparency = 1, TextSize = 13, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = note})
	table.insert(live, note) tween(note, 0.16, {BackgroundTransparency = 0}) tween(label, 0.16, {TextTransparency = 0})
	for _, obj in ipairs(note:GetDescendants()) do if obj:IsA("UIStroke") then tween(obj, 0.16, {Transparency = 0.1}) end end
	task.delay(3.2, function() if note.Parent then tween(note, 0.16, {BackgroundTransparency = 1}) tween(label, 0.16, {TextTransparency = 1}) for _, obj in ipairs(note:GetDescendants()) do if obj:IsA("UIStroke") then tween(obj, 0.16, {Transparency = 1}) end end task.delay(0.17, function() if note.Parent then note:Destroy() end end) end end)
end

local function destroy()
	setMouseUnlocked(false)
	if hasGetGenv and genv then genv[GLOBAL_KEY] = nil end
	if ScreenGui and ScreenGui.Parent then ScreenGui:Destroy() end
end

local function launchEntry(entry)
	local loader = rawget(_G, "loadstring") or (hasGetGenv and genv and rawget(genv, "loadstring")) or loadstring
	if entry.LocalFile then
		local readFile = rawget(_G, "readfile") or readfile
		if type(readFile) ~= "function" or type(loader) ~= "function" then notify("Local file loading unavailable") return end
		local ok, source = pcall(readFile, entry.LocalFile)
		if not ok or type(source) ~= "string" or source == "" then notify("Could not read " .. tostring(entry.LocalFile)) return end
		local chunk = loader(source)
		if not chunk then notify("Could not compile " .. tostring(entry.LocalFile)) return end
		destroy()
		task.delay(0.05, function() pcall(chunk) end)
		return
	end
	if type(entry.LoadstringSource) == "string" and entry.LoadstringSource ~= "" then
		if type(loader) ~= "function" then notify("loadstring unavailable") return end
		local chunk = loader(entry.LoadstringSource)
		if not chunk then notify("Could not compile loadstring for " .. tostring(entry.Name)) return end
		destroy()
		task.delay(0.05, function() pcall(chunk) end)
		return
	end
	notify("No loadstring configured for " .. tostring(entry.Name))
end

for _, entry in ipairs(ENTRIES) do
	local card = create("Frame", {Size = UDim2.new(1, 0, 0, 84), BackgroundColor3 = Theme.Panel2, BorderSizePixel = 0, Parent = EntriesHolder})
	corner(card, 14) stroke(card, Theme.StrokeSoft, 1, 0.2) gradient(card, Color3.fromRGB(46, 82, 136), Color3.fromRGB(34, 62, 110), 0)
	create("TextLabel", {BackgroundTransparency = 1, Position = UDim2.new(0, 14, 0, 12), Size = UDim2.new(1, -132, 0, 18), Text = tostring(entry.Name), TextColor3 = Theme.Text, TextSize = 14, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, Parent = card})
	create("TextLabel", {BackgroundTransparency = 1, Position = UDim2.new(0, 14, 0, 34), Size = UDim2.new(1, -132, 0, 36), TextWrapped = true, Text = tostring(entry.Description or ""), TextColor3 = Theme.Tag, TextSize = 12, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = card})
	local b = create("TextButton", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.new(0, 104, 0, 34), BackgroundColor3 = Theme.Blue, Text = "Launch", TextColor3 = Theme.Text, TextSize = 13, Font = Enum.Font.GothamMedium, AutoButtonColor = false, Parent = card})
	corner(b, 12) gradient(b, Theme.BlueLight, Theme.BlueDark, 0)
	b.MouseButton1Click:Connect(function() launchEntry(entry) end)
end

local function syncMask()
	local raw = tostring(AuthBox.Text or "")
	Mask.Text = raw == "" and "" or string.rep("*", #raw)
	Placeholder.Visible = raw == ""
end

local function showSelector()
	LoadingPage.Visible = false
	SelectorPage.Visible = true
notify("liquidlauncher ready")
end

local function startLoading()
	LoginPage.Visible = false
	LoadingPage.Visible = true
	LoadingBarFill.Size = UDim2.new(0, 0, 1, 0)
	LoadingPercent.Text = "0%"
	local started = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		if not ScreenGui.Parent then conn:Disconnect() return end
		local alpha = math.clamp((os.clock() - started) / 2.2, 0, 1)
		LoadingBarFill.Size = UDim2.new(alpha, 0, 1, 0)
		LoadingPercent.Text = tostring(math.floor(alpha * 100 + 0.5)) .. "%"
		if alpha >= 1 then conn:Disconnect() task.delay(0.1, showSelector) end
	end)
end

local function tryVerify()
	Status.Text = ""
	local key = tostring(AuthBox.Text or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if key ~= "" and key == REQUIRED_KEY then
		startLoading()
	else
		Status.Text = "Invalid key."
		AuthBox.Text = ""
		syncMask()
		notify("Verification failed")
	end
end

AuthBox:GetPropertyChangedSignal("Text"):Connect(syncMask)
AuthBox.Focused:Connect(syncMask)
AuthBox.FocusLost:Connect(function(enterPressed) syncMask() if enterPressed then tryVerify() end end)
Submit.MouseButton1Click:Connect(tryVerify)
Close.MouseButton1Click:Connect(destroy)
Close.MouseEnter:Connect(function() tween(Close, 0.12, {BackgroundColor3 = Theme.Danger}) end)
Close.MouseLeave:Connect(function() tween(Close, 0.12, {BackgroundColor3 = Theme.Panel2}) end)
ScreenGui.AncestryChanged:Connect(function(_, parent) if not parent then destroy() end end)

if hasGetGenv and genv then genv[GLOBAL_KEY] = destroy end
setMouseUnlocked(true)
syncMask()
notify("liquidlauncher loaded")
