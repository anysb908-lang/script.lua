local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local StarterGui = game:GetService("StarterGui")
local TeleportService = game:GetService("TeleportService")
local Stats = game:GetService("Stats")

local player = Players.LocalPlayer

local COLORS = {
	bg = Color3.fromRGB(30, 31, 38),
	bar = Color3.fromRGB(20, 21, 26),
	stroke = Color3.fromRGB(70, 72, 90),
	field = Color3.fromRGB(52, 54, 66),
	green = Color3.fromRGB(0, 160, 70),
	red = Color3.fromRGB(200, 55, 55),
	blue = Color3.fromRGB(60, 110, 220),
	purple = Color3.fromRGB(130, 80, 220),
	orange = Color3.fromRGB(220, 130, 40),
	teal = Color3.fromRGB(30, 170, 170),
	pink = Color3.fromRGB(220, 70, 150),
	text = Color3.fromRGB(255, 255, 255),
	muted = Color3.fromRGB(170, 172, 185),
}

-- ====== دوال مساعدة ======
local function round(instance, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = instance
end

local function stroke(instance, color, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness or 1
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = instance
end

local function makeButton(parent, text, color, size, pos, textSize)
	local b = Instance.new("TextButton")
	b.Size = size
	b.Position = pos
	b.BackgroundColor3 = color
	b.Text = text
	b.TextColor3 = COLORS.text
	b.Font = Enum.Font.SourceSansBold
	b.TextSize = textSize or 18
	b.AutoButtonColor = true
	b.Parent = parent
	round(b, 10)
	return b
end

local function makeLabel(parent, text, size, pos, textSize, color)
	local l = Instance.new("TextLabel")
	l.Size = size
	l.Position = pos
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextColor3 = color or COLORS.text
	l.Font = Enum.Font.SourceSansBold
	l.TextSize = textSize or 16
	l.TextWrapped = true
	l.Parent = parent
	return l
end

local function makeDraggable(handle, target)
	local dragging, dragStart, startPos
	handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = target.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch) then
			local d = input.Position - dragStart
			target.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + d.X,
				startPos.Y.Scale, startPos.Y.Offset + d.Y
			)
		end
	end)
end

local function getHumanoid()
	local c = player.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end

local function getRoot()
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function otherRoot(p)
	local c = p and p.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function notify(title, text)
	pcall(function()
		StarterGui:SetCore("SendNotification", { Title = title, Text = text, Duration = 3 })
	end)
end

local function aliveOthers()
	local t = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player then
			local r = otherRoot(p)
			local h = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
			if r and h and h.Health > 0 then
				t[#t + 1] = { p = p, r = r }
			end
		end
	end
	return t
end

-- ====== الشاشة الرئيسية ======
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ToolboxBot"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = player:WaitForChild("PlayerGui")

local hudFrame = Instance.new("Frame")
hudFrame.BackgroundTransparency = 1
hudFrame.Position = UDim2.new(0, 10, 0, 60)
hudFrame.Size = UDim2.new(0, 190, 0, 0)
hudFrame.AutomaticSize = Enum.AutomaticSize.Y
hudFrame.Parent = screenGui
local hudLayout = Instance.new("UIListLayout")
hudLayout.Padding = UDim.new(0, 4)
hudLayout.Parent = hudFrame

-- ====== مصانع الأدوات ======
local function humProp(prop, extra)
	local orig
	local function apply(v)
		local h = getHumanoid()
		if not h then
			return
		end
		if orig == nil then
			orig = h[prop]
		end
		if extra then
			extra(h)
		end
		h[prop] = v
	end
	local function release()
		local h = getHumanoid()
		if h and orig ~= nil then
			h[prop] = orig
		end
		orig = nil
	end
	return apply, release
end

local function worldProp(getObj, prop)
	local orig
	local function apply(v)
		local o = getObj()
		if not o then
			return
		end
		if orig == nil then
			orig = o[prop]
		end
		o[prop] = v
	end
	local function release()
		local o = getObj()
		if o and orig ~= nil then
			o[prop] = orig
		end
		orig = nil
	end
	return apply, release
end

local function fxTool(class, name, setter)
	local fx
	local function apply(v)
		if not fx or fx.Parent ~= Lighting then
			fx = Instance.new(class)
			fx.Name = name
			fx.Parent = Lighting
		end
		setter(fx, v)
	end
	local function release()
		if fx then
			fx:Destroy()
			fx = nil
		end
	end
	return apply, release
end

local function charInst(class, setup, parentChar)
	local obj
	local function apply()
		local parent = parentChar and player.Character or getRoot()
		if not parent then
			return
		end
		if obj and obj.Parent == parent then
			return
		end
		if obj then
			obj:Destroy()
		end
		obj = Instance.new(class)
		if setup then
			setup(obj)
		end
		obj.Parent = parent
	end
	local function release()
		if obj then
			obj:Destroy()
			obj = nil
		end
	end
	return apply, release
end

local function loopTool(fn, onStop)
	local conn, val
	local function apply(v)
		val = v
		if conn then
			return
		end
		conn = RunService.Heartbeat:Connect(function(dt)
			fn(dt, val)
		end)
	end
	local function release()
		if conn then
			conn:Disconnect()
			conn = nil
		end
		if onStop then
			onStop()
		end
	end
	return apply, release
end

local function hudTool(textFn)
	local label, conn
	local acc = 0
	local function apply()
		if label then
			return
		end
		label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 0, 26)
		label.BackgroundColor3 = COLORS.bar
		label.BackgroundTransparency = 0.25
		label.TextColor3 = COLORS.text
		label.Font = Enum.Font.SourceSansBold
		label.TextSize = 16
		label.Text = "..."
		label.Parent = hudFrame
		round(label, 8)
		conn = RunService.Heartbeat:Connect(function(dt)
			acc += dt
			if acc >= 0.2 then
				acc = 0
				local ok, t = pcall(textFn)
				label.Text = ok and t or "—"
			end
		end)
	end
	local function release()
		if conn then
			conn:Disconnect()
			conn = nil
		end
		if label then
			label:Destroy()
			label = nil
		end
	end
	return apply, release
end

local function espBillboard(textFn)
	local items = {}
	local running = false
	local function release()
		running = false
		for _, it in pairs(items) do
			pcall(function() it.g:Destroy() end)
		end
		items = {}
	end
	local function apply()
		if running then
			return
		end
		running = true
		task.spawn(function()
			while running do
				for p, it in pairs(items) do
					if not p.Parent then
						pcall(function() it.g:Destroy() end)
						items[p] = nil
					end
				end
				for _, other in ipairs(Players:GetPlayers()) do
					if other ~= player then
						local c = other.Character
						local head = c and c:FindFirstChild("Head")
						local hum = c and c:FindFirstChildOfClass("Humanoid")
						local it = items[other]
						if head and (not it or it.g.Parent ~= head) then
							if it then
								it.g:Destroy()
							end
							local g = Instance.new("BillboardGui")
							g.Size = UDim2.new(0, 130, 0, 40)
							g.StudsOffset = Vector3.new(0, 3, 0)
							g.AlwaysOnTop = true
							g.Adornee = head
							g.Parent = head
							local l = Instance.new("TextLabel")
							l.Size = UDim2.new(1, 0, 1, 0)
							l.BackgroundTransparency = 1
							l.TextColor3 = COLORS.text
							l.TextStrokeTransparency = 0
							l.Font = Enum.Font.SourceSansBold
							l.TextSize = 14
							l.Parent = g
							it = { g = g, l = l }
							items[other] = it
						end
						if it and it.l then
							local ok, t = pcall(textFn, other, hum)
							it.l.Text = ok and t or other.DisplayName
						end
					end
				end
				task.wait(0.2)
			end
		end)
	end
	return apply, release
end

local function othersHum(propsFn)
	local orig, running = {}, false
	local function apply()
		if running then
			return
		end
		running = true
		task.spawn(function()
			while running do
				for _, p in ipairs(Players:GetPlayers()) do
					if p ~= player then
						local h = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
						if h and not orig[h] then
							local o = {}
							for k, v in pairs(propsFn()) do
								o[k] = h[k]
								h[k] = v
							end
							orig[h] = o
						end
					end
				end
				task.wait(1)
			end
		end)
	end
	local function release()
		running = false
		for h, o in pairs(orig) do
			for k, v in pairs(o) do
				pcall(function() h[k] = v end)
			end
		end
		orig = {}
	end
	return apply, release
end

local function stateTool(states)
	local function apply()
		local h = getHumanoid()
		if h then
			for _, s in ipairs(states) do
				pcall(function() h:SetStateEnabled(s, false) end)
			end
		end
	end
	local function release()
		local h = getHumanoid()
		if h then
			for _, s in ipairs(states) do
				pcall(function() h:SetStateEnabled(s, true) end)
			end
		end
	end
	return apply, release
end

local function scaleTool(names)
	local orig = {}
	local function apply(v)
		local h = getHumanoid()
		if not h then
			return
		end
		for _, n in ipairs(names) do
			local o = h:FindFirstChild(n)
			if o then
				if orig[o] == nil then
					orig[o] = o.Value
				end
				o.Value = v / 100
			end
		end
	end
	local function release()
		for o, val in pairs(orig) do
			pcall(function() o.Value = val end)
		end
		orig = {}
	end
	return apply, release
end

-- ====== نظام الإضاءة الموحّد (يمنع تداخل الأدوات) ======
local BASE_LIGHT = {}
for _, p in ipairs({
	"Brightness", "ClockTime", "GlobalShadows", "Ambient", "OutdoorAmbient",
	"FogEnd", "FogStart", "ExposureCompensation",
	"EnvironmentDiffuseScale", "EnvironmentSpecularScale", "ShadowSoftness",
}) do
	pcall(function() BASE_LIGHT[p] = Lighting[p] end)
end
local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
local BASE_ATM = atmosphere and { Density = atmosphere.Density, Haze = atmosphere.Haze } or nil

local lightOv, lightOrder, lightTouched = {}, {}, {}

local function setLightProp(k, v)
	if k == "AtmDensity" then
		if atmosphere and atmosphere.Parent then atmosphere.Density = v end
	elseif k == "AtmHaze" then
		if atmosphere and atmosphere.Parent then atmosphere.Haze = v end
	else
		pcall(function() Lighting[k] = v end)
	end
end

local function restoreLightProp(k)
	if k == "AtmDensity" then
		if BASE_ATM then setLightProp(k, BASE_ATM.Density) end
	elseif k == "AtmHaze" then
		if BASE_ATM then setLightProp(k, BASE_ATM.Haze) end
	elseif BASE_LIGHT[k] ~= nil then
		setLightProp(k, BASE_LIGHT[k])
	end
end

local function refreshLighting()
	local now = {}
	for _, id in ipairs(lightOrder) do
		local ov = lightOv[id]
		if ov then
			for k in pairs(ov) do
				now[k] = true
			end
		end
	end
	for k in pairs(lightTouched) do
		if not now[k] then
			restoreLightProp(k)
		end
	end
	for k in pairs(now) do
		restoreLightProp(k)
	end
	for _, id in ipairs(lightOrder) do
		local ov = lightOv[id]
		if ov then
			for k, v in pairs(ov) do
				setLightProp(k, v)
			end
		end
	end
	lightTouched = now
end

local function lightTool(id, fn)
	local function apply(v)
		lightOv[id] = fn(v)
		if not table.find(lightOrder, id) then
			table.insert(lightOrder, id)
		end
		refreshLighting()
	end
	local function release()
		lightOv[id] = nil
		local i = table.find(lightOrder, id)
		if i then
			table.remove(lightOrder, i)
		end
		refreshLighting()
	end
	return apply, release
end

-- ====== أدوات الحركة ======
local speedApply, speedRelease = humProp("WalkSpeed")
local jumpApply, jumpRelease = humProp("JumpPower", function(h)
	h.UseJumpPower = true
end)
local hipApply, hipRelease = humProp("HipHeight")
local slopeApply, slopeRelease = humProp("MaxSlopeAngle")
local gravApply, gravRelease = worldProp(function() return workspace end, "Gravity")
local fovApply, fovRelease = worldProp(function() return workspace.CurrentCamera end, "FieldOfView")
local zoomApply, zoomRelease = worldProp(function() return player end, "CameraMaxZoomDistance")
local minZoomApply, minZoomRelease = worldProp(function() return player end, "CameraMinZoomDistance")

-- الطيران
local fly = { speed = 60 }
local function flyApply(v)
	fly.speed = v or fly.speed
	if fly.conn then
		return
	end
	local root, h = getRoot(), getHumanoid()
	if not root or not h then
		return
	end
	local bv = Instance.new("BodyVelocity")
	bv.MaxForce = Vector3.new(1e9, 1e9, 1e9)
	bv.Velocity = Vector3.zero
	bv.Parent = root
	local bg = Instance.new("BodyGyro")
	bg.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
	bg.P = 9e4
	bg.CFrame = root.CFrame
	bg.Parent = root
	h.PlatformStand = true
	fly.bv, fly.bg = bv, bg
	fly.conn = RunService.RenderStepped:Connect(function()
		local cam = workspace.CurrentCamera
		local hum = getHumanoid()
		if not cam or not hum or not bv.Parent then
			return
		end
		local cf = cam.CFrame
		local flatLook = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
		flatLook = flatLook.Magnitude < 0.01 and Vector3.new(0, 0, -1) or flatLook.Unit
		local flatRight = Vector3.new(cf.RightVector.X, 0, cf.RightVector.Z)
		flatRight = flatRight.Magnitude < 0.01 and Vector3.new(1, 0, 0) or flatRight.Unit
		local md = hum.MoveDirection
		local fwd = md:Dot(flatLook)
		local right = md:Dot(flatRight)
		bv.Velocity = (cf.LookVector * fwd + cf.RightVector * right) * fly.speed
		bg.CFrame = cf
	end)
end
local function flyRelease()
	if fly.conn then
		fly.conn:Disconnect()
		fly.conn = nil
	end
	if fly.bv then
		fly.bv:Destroy()
		fly.bv = nil
	end
	if fly.bg then
		fly.bg:Destroy()
		fly.bg = nil
	end
	local h = getHumanoid()
	if h then
		h.PlatformStand = false
	end
end

-- اختراق الجدران
local noclipConn
local function noclipApply()
	if noclipConn then
		return
	end
	noclipConn = RunService.Stepped:Connect(function()
		local c = player.Character
		if c then
			for _, p in ipairs(c:GetDescendants()) do
				if p:IsA("BasePart") and p.CanCollide then
					p.CanCollide = false
				end
			end
		end
	end)
end
local function noclipRelease()
	if noclipConn then
		noclipConn:Disconnect()
		noclipConn = nil
	end
	local c = player.Character
	if c then
		for _, n in ipairs({ "Head", "Torso", "UpperTorso", "LowerTorso", "HumanoidRootPart" }) do
			local p = c:FindFirstChild(n)
			if p and p:IsA("BasePart") then
				p.CanCollide = true
			end
		end
	end
end

-- قفز لا نهائي
local infConn
local function infApply()
	if infConn then
		return
	end
	infConn = UserInputService.JumpRequest:Connect(function()
		local h = getHumanoid()
		if h then
			h:ChangeState(Enum.HumanoidStateType.Jumping)
		end
	end)
end
local function infRelease()
	if infConn then
		infConn:Disconnect()
		infConn = nil
	end
end

local ajApply, ajRelease = loopTool(function()
	local h = getHumanoid()
	if h then
		h.Jump = true
	end
end)

-- جري سريع بزر Shift
local sp = {}
local function sprintApply(v)
	sp.speed = v or 60
	if sp.c1 then
		return
	end
	sp.c1 = UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.LeftShift then
			local h = getHumanoid()
			if h and not sp.orig then
				sp.orig = h.WalkSpeed
				h.WalkSpeed = sp.speed
			end
		end
	end)
	sp.c2 = UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.LeftShift then
			local h = getHumanoid()
			if h and sp.orig then
				h.WalkSpeed = sp.orig
				sp.orig = nil
			end
		end
	end)
end
local function sprintRelease()
	if sp.c1 then
		sp.c1:Disconnect()
		sp.c1 = nil
	end
	if sp.c2 then
		sp.c2:Disconnect()
		sp.c2 = nil
	end
	local h = getHumanoid()
	if h and sp.orig then
		h.WalkSpeed = sp.orig
	end
	sp.orig = nil
end

-- هبوط بطيء
local slowApply, slowRelease = loopTool(function(_, v)
	local r = getRoot()
	if r and v then
		local vel = r.AssemblyLinearVelocity
		if vel.Y < -v then
			r.AssemblyLinearVelocity = Vector3.new(vel.X, -v, vel.Z)
		end
	end
end)

-- منع السقوط في الفراغ
local av = {}
local avApply, avRelease = loopTool(function()
	local r, h = getRoot(), getHumanoid()
	if not r or not h then
		return
	end
	local floor = workspace.FallenPartsDestroyHeight
	if h.FloorMaterial ~= Enum.Material.Air and r.Position.Y > floor + 100 then
		av.safe = r.CFrame
	elseif av.safe and r.Position.Y < floor + 80 then
		r.AssemblyLinearVelocity = Vector3.zero
		r.CFrame = av.safe + Vector3.new(0, 4, 0)
	end
end, function()
	av.safe = nil
end)

local stumbleApply, stumbleRelease = stateTool({
	Enum.HumanoidStateType.FallingDown,
	Enum.HumanoidStateType.Ragdoll,
})
local nositApply, nositRelease = stateTool({ Enum.HumanoidStateType.Seated })

-- عدم التصادم مع اللاعبين
local ncp = { orig = {} }
local function ncpApply()
	if ncp.conn then
		return
	end
	ncp.conn = RunService.Stepped:Connect(function()
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= player and p.Character then
				for _, d in ipairs(p.Character:GetDescendants()) do
					if d:IsA("BasePart") and d.CanCollide then
						ncp.orig[d] = true
						d.CanCollide = false
					end
				end
			end
		end
	end)
end
local function ncpRelease()
	if ncp.conn then
		ncp.conn:Disconnect()
		ncp.conn = nil
	end
	for d in pairs(ncp.orig) do
		pcall(function() d.CanCollide = true end)
	end
	ncp.orig = {}
end

-- انتقال بالنقر
local ctp = {}
local function ctpGo(pos2)
	local cam = workspace.CurrentCamera
	local root = getRoot()
	if not cam or not root then
		return
	end
	local ray = cam:ScreenPointToRay(pos2.X, pos2.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character }
	local res = workspace:Raycast(ray.Origin, ray.Direction * 3000, params)
	if res then
		root.CFrame = CFrame.new(res.Position + Vector3.new(0, 4, 0))
	end
end
local function ctpApply()
	if ctp.c1 then
		return
	end
	ctp.c1 = UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			ctpGo(Vector2.new(input.Position.X, input.Position.Y))
		end
	end)
	ctp.c2 = UserInputService.TouchTapInWorld:Connect(function(position, processed)
		if not processed then
			ctpGo(position)
		end
	end)
end
local function ctpRelease()
	if ctp.c1 then
		ctp.c1:Disconnect()
		ctp.c1 = nil
	end
	if ctp.c2 then
		ctp.c2:Disconnect()
		ctp.c2 = nil
	end
end

-- دوران
local spin = { speed = 10 }
local function spinApply(v)
	spin.speed = v or spin.speed
	if spin.conn then
		return
	end
	local h = getHumanoid()
	if h then
		spin.auto = h.AutoRotate
		h.AutoRotate = false
	end
	spin.conn = RunService.Heartbeat:Connect(function(dt)
		local r = getRoot()
		if r then
			r.CFrame = r.CFrame * CFrame.Angles(0, math.rad(spin.speed * 36 * dt), 0)
		end
	end)
end
local function spinRelease()
	if spin.conn then
		spin.conn:Disconnect()
		spin.conn = nil
	end
	local h = getHumanoid()
	if h and spin.auto ~= nil then
		h.AutoRotate = spin.auto
	end
	spin.auto = nil
end

local function freezeApply()
	local r = getRoot()
	if r then
		r.Anchored = true
	end
end
local function freezeRelease()
	local r = getRoot()
	if r then
		r.Anchored = false
	end
end

local function sitApply()
	local h = getHumanoid()
	if h then
		h.Sit = true
	end
end
local function sitRelease()
	local h = getHumanoid()
	if h then
		h.Sit = false
	end
end

local coOrig
local function coApply(v)
	local h = getHumanoid()
	if h then
		if coOrig == nil then
			coOrig = h.CameraOffset
		end
		h.CameraOffset = Vector3.new(0, (v or 0) / 2, 0)
	end
end
local function coRelease()
	local h = getHumanoid()
	if h and coOrig ~= nil then
		h.CameraOffset = coOrig
	end
	coOrig = nil
end

local function fpApply()
	player.CameraMode = Enum.CameraMode.LockFirstPerson
end
local function fpRelease()
	player.CameraMode = Enum.CameraMode.Classic
end

-- ====== الإضاءة والجودة ======
local timeApply, timeRelease = lightTool("time", function(v) return { ClockTime = v } end)
local brightApply, brightRelease = lightTool("bright", function(v) return { Brightness = v } end)
local expoApply, expoRelease = lightTool("expo", function(v) return { ExposureCompensation = v } end)
local fbApply, fbRelease = lightTool("fullbright", function()
	return {
		Brightness = 2, ClockTime = 14, GlobalShadows = false,
		Ambient = Color3.fromRGB(200, 200, 200), OutdoorAmbient = Color3.fromRGB(200, 200, 200),
	}
end)
local nfApply, nfRelease = lightTool("nofog", function()
	return { FogStart = 0, FogEnd = 1e6, AtmDensity = 0, AtmHaze = 0 }
end)
local nsApply, nsRelease = lightTool("noshadows", function() return { GlobalShadows = false } end)

-- جودة رهيبة
local ultraLApply, ultraLRelease = lightTool("ultra", function()
	return {
		GlobalShadows = true, Brightness = 3, ExposureCompensation = 0.3,
		EnvironmentDiffuseScale = 1, EnvironmentSpecularScale = 1, ShadowSoftness = 0.3,
	}
end)
local ultra = {}
local function ultraApply()
	ultraLApply()
	if ultra.fx then
		return
	end
	local fx = {}
	local function add(class, props)
		local o = Instance.new(class)
		o.Name = "BotUltra"
		for k, v in pairs(props) do
			pcall(function() o[k] = v end)
		end
		o.Parent = Lighting
		fx[#fx + 1] = o
	end
	add("BloomEffect", { Intensity = 0.4, Size = 24, Threshold = 0.9 })
	add("SunRaysEffect", { Intensity = 0.25, Spread = 0.8 })
	add("ColorCorrectionEffect", { Contrast = 0.1, Saturation = 0.2, TintColor = Color3.fromRGB(255, 248, 240) })
	ultra.fx = fx
	pcall(function()
		if ultra.quality == nil then
			ultra.quality = settings().Rendering.QualityLevel
		end
		settings().Rendering.QualityLevel = Enum.QualityLevel.Level21
	end)
end
local function ultraRelease()
	ultraLRelease()
	if ultra.fx then
		for _, o in ipairs(ultra.fx) do
			pcall(function() o:Destroy() end)
		end
		ultra.fx = nil
	end
	if ultra.quality then
		pcall(function() settings().Rendering.QualityLevel = ultra.quality end)
		ultra.quality = nil
	end
end

-- رفع الأداء
local boostLApply, boostLRelease = lightTool("boost", function() return { GlobalShadows = false } end)
local boost = {}
local function boostApply()
	boostLApply()
	if boost.saved then
		return
	end
	local s = { effects = {}, emitters = {} }
	for _, d in ipairs(Lighting:GetChildren()) do
		if d:IsA("PostEffect") then
			s.effects[d] = d.Enabled
			d.Enabled = false
		end
	end
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("ParticleEmitter") or d:IsA("Smoke") or d:IsA("Fire") or d:IsA("Sparkles") then
			s.emitters[d] = d.Enabled
			d.Enabled = false
		end
	end
	pcall(function()
		s.quality = settings().Rendering.QualityLevel
		settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
	end)
	boost.saved = s
end
local function boostRelease()
	boostLRelease()
	local s = boost.saved
	if not s then
		return
	end
	for d, v in pairs(s.effects) do
		pcall(function() d.Enabled = v end)
	end
	for d, v in pairs(s.emitters) do
		pcall(function() d.Enabled = v end)
	end
	if s.quality then
		pcall(function() settings().Rendering.QualityLevel = s.quality end)
	end
	boost.saved = nil
end

-- وضع البطاطس
local potato = { mats = {}, trans = {} }
local function potatoStrip(d)
	if d:IsA("BasePart") and d ~= workspace.Terrain then
		if potato.mats[d] == nil then
			potato.mats[d] = d.Material
		end
		d.Material = Enum.Material.SmoothPlastic
	elseif d:IsA("Decal") or d:IsA("Texture") then
		if potato.trans[d] == nil then
			potato.trans[d] = d.Transparency
		end
		d.Transparency = 1
	end
end
local function potatoApply()
	if potato.conn then
		return
	end
	potato.conn = workspace.DescendantAdded:Connect(potatoStrip)
	task.spawn(function()
		local n = 0
		for _, d in ipairs(workspace:GetDescendants()) do
			if not potato.conn then
				break
			end
			pcall(potatoStrip, d)
			n += 1
			if n % 300 == 0 then
				task.wait()
			end
		end
	end)
end
local function potatoRelease()
	if potato.conn then
		potato.conn:Disconnect()
		potato.conn = nil
	end
	for d, m in pairs(potato.mats) do
		pcall(function() d.Material = m end)
	end
	for d, t in pairs(potato.trans) do
		pcall(function() d.Transparency = t end)
	end
	potato.mats = {}
	potato.trans = {}
end

-- تأثيرات الشاشة
local dofApply, dofRelease = fxTool("DepthOfFieldEffect", "BotDof", function(f, v)
	f.FarIntensity = 0.6
	f.NearIntensity = 0
	f.InFocusRadius = 20
	f.FocusDistance = v or 50
end)
local cineApply, cineRelease = fxTool("ColorCorrectionEffect", "BotCine", function(f)
	f.Contrast = 0.2
	f.Saturation = 0.15
	f.Brightness = -0.02
	f.TintColor = Color3.fromRGB(255, 240, 225)
end)
local nvApply, nvRelease = fxTool("ColorCorrectionEffect", "BotNight", function(f)
	f.TintColor = Color3.fromRGB(130, 255, 150)
	f.Brightness = 0.25
	f.Contrast = 0.3
	f.Saturation = -0.2
end)
local bwApply, bwRelease = fxTool("ColorCorrectionEffect", "BotBW", function(f)
	f.Saturation = -1
end)
local satApply, satRelease = fxTool("ColorCorrectionEffect", "BotSat", function(f, v)
	f.Saturation = (v or 0) / 100
end)
local bloomApply, bloomRelease = fxTool("BloomEffect", "BotBloom", function(f, v)
	f.Intensity = (v or 10) / 10
	f.Size = 24
	f.Threshold = 0.8
end)
local raysApply, raysRelease = fxTool("SunRaysEffect", "BotRays", function(f, v)
	f.Intensity = (v or 30) / 100
	f.Spread = 0.8
end)
local blurApply, blurRelease = fxTool("BlurEffect", "BotBlur", function(f, v)
	f.Size = v or 12
end)

-- ثلج
local snow = {}
local function snowApply()
	if snow.part then
		return
	end
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(80, 1, 80)
	local e = Instance.new("ParticleEmitter")
	e.Rate = 200
	e.Lifetime = NumberRange.new(5, 7)
	e.Speed = NumberRange.new(10, 18)
	e.EmissionDirection = Enum.NormalId.Bottom
	e.Size = NumberSequence.new(0.35)
	e.Color = ColorSequence.new(Color3.new(1, 1, 1))
	e.Transparency = NumberSequence.new(0.1)
	e.Parent = p
	p.Parent = workspace
	snow.part = p
	snow.conn = RunService.RenderStepped:Connect(function()
		local cam = workspace.CurrentCamera
		if cam then
			p.CFrame = CFrame.new(cam.CFrame.Position + Vector3.new(0, 35, 0))
		end
	end)
end
local function snowRelease()
	if snow.conn then
		snow.conn:Disconnect()
		snow.conn = nil
	end
	if snow.part then
		snow.part:Destroy()
		snow.part = nil
	end
end

-- إضاءة حولك + لمبة ملونة
local lt = {}
local function ltApply(v)
	local r = getRoot()
	if not r then
		return
	end
	if not lt.light or lt.light.Parent ~= r then
		if lt.light then
			lt.light:Destroy()
		end
		local l = Instance.new("PointLight")
		l.Brightness = 3
		l.Color = Color3.fromRGB(255, 244, 214)
		l.Parent = r
		lt.light = l
	end
	lt.light.Range = v or 40
end
local function ltRelease()
	if lt.light then
		lt.light:Destroy()
		lt.light = nil
	end
end

local cl = {}
local function clApply()
	local r = getRoot()
	if not r then
		return
	end
	if not cl.light or cl.light.Parent ~= r then
		if cl.light then
			cl.light:Destroy()
		end
		local l = Instance.new("PointLight")
		l.Range = 22
		l.Brightness = 3
		l.Parent = r
		cl.light = l
	end
	if not cl.conn then
		local t = 0
		cl.conn = RunService.Heartbeat:Connect(function(dt)
			t += dt * 0.4
			if cl.light then
				cl.light.Color = Color3.fromHSV(t % 1, 1, 1)
			end
		end)
	end
end
local function clRelease()
	if cl.conn then
		cl.conn:Disconnect()
		cl.conn = nil
	end
	if cl.light then
		cl.light:Destroy()
		cl.light = nil
	end
end

-- ====== مظهر الشخصية ======
local rb = { orig = {} }
local function rbApply()
	if rb.conn then
		return
	end
	local c = player.Character
	if not c then
		return
	end
	local parts = {}
	for _, d in ipairs(c:GetDescendants()) do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
			parts[#parts + 1] = d
			if rb.orig[d] == nil then
				rb.orig[d] = d.Color
			end
		end
	end
	local t = 0
	rb.conn = RunService.Heartbeat:Connect(function(dt)
		t += dt * 0.5
		local col = Color3.fromHSV(t % 1, 1, 1)
		for _, p in ipairs(parts) do
			p.Color = col
		end
	end)
end
local function rbRelease()
	if rb.conn then
		rb.conn:Disconnect()
		rb.conn = nil
	end
	for p, col in pairs(rb.orig) do
		pcall(function() p.Color = col end)
	end
	rb.orig = {}
end

local neon = { orig = {} }
local function neonApply()
	local c = player.Character
	if not c then
		return
	end
	for _, d in ipairs(c:GetDescendants()) do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
			if neon.orig[d] == nil then
				neon.orig[d] = d.Material
			end
			d.Material = Enum.Material.Neon
		end
	end
end
local function neonRelease()
	for p, m in pairs(neon.orig) do
		pcall(function() p.Material = m end)
	end
	neon.orig = {}
end

local tl = {}
local function tlApply()
	local r = getRoot()
	if not r or (tl.objs and tl.objs[1].Parent == r) then
		return
	end
	if tl.objs then
		for _, o in ipairs(tl.objs) do
			pcall(function() o:Destroy() end)
		end
	end
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 1, 0)
	a0.Parent = r
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -1, 0)
	a1.Parent = r
	local t = Instance.new("Trail")
	t.Attachment0 = a0
	t.Attachment1 = a1
	t.Lifetime = 1.2
	t.LightEmission = 1
	t.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 128)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 0)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 200, 255)),
	})
	t.Transparency = NumberSequence.new(0, 1)
	t.Parent = r
	tl.objs = { a0, a1, t }
end
local function tlRelease()
	if tl.objs then
		for _, o in ipairs(tl.objs) do
			pcall(function() o:Destroy() end)
		end
		tl.objs = nil
	end
end

local auraApply, auraRelease = charInst("ParticleEmitter", function(o)
	o.Rate = 40
	o.Lifetime = NumberRange.new(1, 1.5)
	o.Speed = NumberRange.new(2, 4)
	o.LightEmission = 1
	o.Size = NumberSequence.new(0.6)
	o.Color = ColorSequence.new(Color3.fromRGB(120, 200, 255))
	o.SpreadAngle = Vector2.new(180, 180)
end)
local fireApply, fireRelease = charInst("Fire", function(o)
	o.Size = 7
	o.Heat = 10
end)
local sparkApply, sparkRelease = charInst("Sparkles")
local smokeApply, smokeRelease = charInst("Smoke", function(o)
	o.Size = 6
	o.Opacity = 0.4
end)
local shieldApply, shieldRelease = charInst("ForceField", nil, true)

local tr = { orig = {} }
local function trApply(v)
	local c = player.Character
	if not c then
		return
	end
	for _, d in ipairs(c:GetDescendants()) do
		if (d:IsA("BasePart") and d.Name ~= "HumanoidRootPart") or d:IsA("Decal") then
			if tr.orig[d] == nil then
				tr.orig[d] = d.Transparency
			end
			d.Transparency = (v or 50) / 100
		end
	end
end
local function trRelease()
	for d, t in pairs(tr.orig) do
		pcall(function() d.Transparency = t end)
	end
	tr.orig = {}
end

local sizeApply, sizeRelease = scaleTool({ "BodyHeightScale", "BodyWidthScale", "BodyDepthScale", "HeadScale" })
local headApply, headRelease = scaleTool({ "HeadScale" })

local ha = { orig = {} }
local function haApply()
	local c = player.Character
	if not c then
		return
	end
	for _, d in ipairs(c:GetDescendants()) do
		if d:IsA("Accessory") then
			local hd = d:FindFirstChild("Handle")
			if hd and hd:IsA("BasePart") then
				if ha.orig[hd] == nil then
					ha.orig[hd] = hd.Transparency
				end
				hd.Transparency = 1
			end
		end
	end
end
local function haRelease()
	for hd, t in pairs(ha.orig) do
		pcall(function() hd.Transparency = t end)
	end
	ha.orig = {}
end

-- ====== اللاعبين ======
local esp = { hl = {}, running = false }
local function espRelease()
	esp.running = false
	for _, h in pairs(esp.hl) do
		pcall(function() h:Destroy() end)
	end
	esp.hl = {}
end
local function espApply()
	if esp.running then
		return
	end
	esp.running = true
	task.spawn(function()
		while esp.running do
			for p, h in pairs(esp.hl) do
				if not p.Parent then
					pcall(function() h:Destroy() end)
					esp.hl[p] = nil
				end
			end
			for _, other in ipairs(Players:GetPlayers()) do
				if other ~= player then
					local ch = other.Character
					local h = esp.hl[other]
					if ch and (not h or h.Parent ~= ch) then
						if h then
							h:Destroy()
						end
						h = Instance.new("Highlight")
						h.FillColor = Color3.fromRGB(255, 60, 60)
						h.OutlineColor = Color3.new(1, 1, 1)
						h.FillTransparency = 0.5
						h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
						h.Parent = ch
						esp.hl[other] = h
					end
				end
			end
			task.wait(1)
		end
	end)
end

local nameEspApply, nameEspRelease = espBillboard(function(other, hum)
	local hpv = hum and math.floor(hum.Health) or 0
	return other.DisplayName .. "\n❤ " .. hpv
end)

local distEspApply, distEspRelease = espBillboard(function(other)
	local r, my = otherRoot(other), getRoot()
	if r and my then
		return other.DisplayName .. "\n📏 " .. math.floor((r.Position - my.Position).Magnitude) .. " م"
	end
	return other.DisplayName
end)

local tc = { items = {}, running = false }
local function tcMake(other, r)
	local old = tc.items[other]
	if old then
		pcall(function()
			old.beam:Destroy()
			old.att:Destroy()
		end)
	end
	local att = Instance.new("Attachment")
	att.Parent = r
	local beam = Instance.new("Beam")
	beam.Attachment0 = tc.a0
	beam.Attachment1 = att
	beam.FaceCamera = true
	beam.Width0 = 0.15
	beam.Width1 = 0.15
	beam.LightEmission = 1
	beam.Color = ColorSequence.new(Color3.fromRGB(255, 60, 60))
	beam.Parent = r
	tc.items[other] = { beam = beam, att = att }
end
local function tcRelease()
	tc.running = false
	for _, it in pairs(tc.items) do
		pcall(function()
			it.beam:Destroy()
			it.att:Destroy()
		end)
	end
	tc.items = {}
	if tc.a0 then
		tc.a0:Destroy()
		tc.a0 = nil
	end
end
local function tcApply()
	if tc.running then
		return
	end
	tc.running = true
	task.spawn(function()
		while tc.running do
			local my = getRoot()
			if my then
				if not tc.a0 or tc.a0.Parent ~= my then
					if tc.a0 then
						tc.a0:Destroy()
					end
					tc.a0 = Instance.new("Attachment")
					tc.a0.Parent = my
					for k in pairs(tc.items) do
						tc.items[k] = nil
					end
				end
				for _, other in ipairs(Players:GetPlayers()) do
					local r = otherRoot(other)
					local it = tc.items[other]
					if other ~= player and r and (not it or it.att.Parent ~= r) then
						tcMake(other, r)
					end
				end
			end
			task.wait(0.5)
		end
	end)
end

local farApply, farRelease = othersHum(function()
	return {
		DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer,
		NameDisplayDistance = 1000,
		HealthDisplayDistance = 1000,
	}
end)
local hideNamesApply, hideNamesRelease = othersHum(function()
	return { DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None }
end)

local hp = { dec = {}, parts = {} }
local function hpApply()
	if hp.running then
		return
	end
	hp.running = true
	task.spawn(function()
		while hp.running do
			for _, p in ipairs(Players:GetPlayers()) do
				if p ~= player and p.Character then
					for _, d in ipairs(p.Character:GetDescendants()) do
						if d:IsA("BasePart") then
							d.LocalTransparencyModifier = 1
							hp.parts[d] = true
						elseif d:IsA("Decal") then
							if hp.dec[d] == nil then
								hp.dec[d] = d.Transparency
							end
							d.Transparency = 1
						end
					end
				end
			end
			task.wait(0.5)
		end
	end)
end
local function hpRelease()
	hp.running = false
	for d in pairs(hp.parts) do
		pcall(function() d.LocalTransparencyModifier = 0 end)
	end
	for d, t in pairs(hp.dec) do
		pcall(function() d.Transparency = t end)
	end
	hp.parts = {}
	hp.dec = {}
end

local jl = {}
local function jlApply()
	if jl.c1 then
		return
	end
	jl.c1 = Players.PlayerAdded:Connect(function(p)
		notify("دخل لاعب", p.DisplayName)
	end)
	jl.c2 = Players.PlayerRemoving:Connect(function(p)
		notify("خرج لاعب", p.DisplayName)
	end)
end
local function jlRelease()
	if jl.c1 then
		jl.c1:Disconnect()
		jl.c1 = nil
	end
	if jl.c2 then
		jl.c2:Disconnect()
		jl.c2 = nil
	end
end

-- ====== العدادات ======
local fpsVal = 60
RunService.Heartbeat:Connect(function(dt)
	if dt > 0 then
		fpsVal = fpsVal * 0.9 + (1 / dt) * 0.1
	end
end)
local fcApply, fcRelease = hudTool(function()
	return "📊 FPS: " .. math.floor(fpsVal + 0.5)
end)
local pingApply, pingRelease = hudTool(function()
	local item = Stats.Network.ServerStatsItem["Data Ping"]
	return "📶 Ping: " .. math.floor(item:GetValue()) .. " ms"
end)
local coordsApply, coordsRelease = hudTool(function()
	local r = getRoot()
	if not r then
		return "📍 --"
	end
	local p = r.Position
	return "📍 " .. math.floor(p.X) .. ", " .. math.floor(p.Y) .. ", " .. math.floor(p.Z)
end)
local clockApply, clockRelease = hudTool(function()
	return "🕒 " .. os.date("%H:%M:%S")
end)
local meterApply, meterRelease = hudTool(function()
	local r = getRoot()
	if not r then
		return "🏃 --"
	end
	local v = r.AssemblyLinearVelocity
	return "🏃 سرعتك: " .. math.floor(Vector3.new(v.X, 0, v.Z).Magnitude)
end)
local pcountApply, pcountRelease = hudTool(function()
	return "👥 اللاعبين: " .. #Players:GetPlayers() .. "/" .. Players.MaxPlayers
end)
local swStart = os.clock()
local swBaseApply, swRelease = hudTool(function()
	local t = os.clock() - swStart
	return string.format("⏱ %02d:%05.2f", math.floor(t / 60), t % 60)
end)
local function swApply()
	swStart = os.clock()
	swBaseApply()
end
local bigHpApply, bigHpRelease = hudTool(function()
	local h = getHumanoid()
	if not h then
		return "❤ --"
	end
	return "❤ " .. math.floor(h.Health) .. " / " .. math.floor(h.MaxHealth)
end)

local lowFrame
local lowApply, lowRelease = loopTool(function()
	if not lowFrame then
		lowFrame = Instance.new("Frame")
		lowFrame.Size = UDim2.new(1, 0, 1, 0)
		lowFrame.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
		lowFrame.BackgroundTransparency = 1
		lowFrame.BorderSizePixel = 0
		lowFrame.Active = false
		lowFrame.Parent = screenGui
	end
	local h = getHumanoid()
	if h and h.MaxHealth > 0 and h.Health > 0 and h.Health / h.MaxHealth < 0.3 then
		lowFrame.BackgroundTransparency = 0.75 + 0.15 * math.sin(os.clock() * 6)
	else
		lowFrame.BackgroundTransparency = 1
	end
end, function()
	if lowFrame then
		lowFrame:Destroy()
		lowFrame = nil
	end
end)

-- ====== أخرى ======
local afk = {}
local function afkApply()
	if afk.conn then
		return
	end
	local VU = game:GetService("VirtualUser")
	afk.conn = player.Idled:Connect(function()
		VU:CaptureController()
		VU:ClickButton2(Vector2.new())
	end)
end
local function afkRelease()
	if afk.conn then
		afk.conn:Disconnect()
		afk.conn = nil
	end
end

local mt = { orig = {} }
local function muteOne(s)
	if s:IsA("Sound") then
		if mt.orig[s] == nil then
			mt.orig[s] = s.Volume
		end
		s.Volume = 0
	end
end
local function muteApply()
	if mt.conn then
		return
	end
	for _, d in ipairs(game:GetDescendants()) do
		muteOne(d)
	end
	mt.conn = game.DescendantAdded:Connect(muteOne)
end
local function muteRelease()
	if mt.conn then
		mt.conn:Disconnect()
		mt.conn = nil
	end
	for s, v in pairs(mt.orig) do
		pcall(function() s.Volume = v end)
	end
	mt.orig = {}
end

local function guiApply()
	pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false) end)
end
local function guiRelease()
	pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true) end)
end

-- ====== أزرار الأوامر ======
local savedCF
local checkpointActions = {
	{ label = "💾 حفظ موقعي", fn = function()
		local r = getRoot()
		if not r then
			return "ما لقيت شخصيتك"
		end
		savedCF = r.CFrame
		return "تم حفظ الموقع ✅"
	end },
	{ label = "↩ العودة للموقع", fn = function()
		local r = getRoot()
		if not r or not savedCF then
			return "ما فيه موقع محفوظ"
		end
		r.CFrame = savedCF
		return "رجعت للموقع ✅"
	end },
}

local function pickPlayer(mode)
	local my = getRoot()
	local list = aliveOthers()
	if #list == 0 or not my then
		return nil
	end
	if mode == "random" then
		return list[math.random(#list)]
	end
	local best, bd
	for _, e in ipairs(list) do
		local d = (e.r.Position - my.Position).Magnitude
		if not bd or (mode == "nearest" and d < bd) or (mode == "farthest" and d > bd) then
			best, bd = e, d
		end
	end
	return best
end
local function tpTo(entry)
	local my = getRoot()
	if my and entry then
		my.CFrame = entry.r.CFrame * CFrame.new(0, 0, 4)
		return "انتقلت إلى " .. entry.p.DisplayName .. " ✅"
	end
	return "ما لقيت لاعب"
end
local tpActions = {
	{ label = "📍 أقرب لاعب", fn = function() return tpTo(pickPlayer("nearest")) end },
	{ label = "🎲 لاعب عشوائي", fn = function() return tpTo(pickPlayer("random")) end },
	{ label = "🛰 أبعد لاعب", fn = function() return tpTo(pickPlayer("farthest")) end },
}

local spawnActions = {
	{ label = "🏁 انتقال لنقطة الظهور", fn = function()
		local r = getRoot()
		local found
		for _, d in ipairs(workspace:GetDescendants()) do
			if d:IsA("SpawnLocation") then
				found = d
				break
			end
		end
		if r and found then
			r.CFrame = found.CFrame + Vector3.new(0, 5, 0)
			return "تم ✅"
		end
		return "ما لقيت نقطة ظهور"
	end },
}

local dashActions = {
	{ label = "➡ اندفاع للأمام", fn = function()
		local r = getRoot()
		if r then
			r.AssemblyLinearVelocity = r.CFrame.LookVector * 120 + Vector3.new(0, 20, 0)
		end
		return "اندفاع ✅"
	end },
	{ label = "⬆ اندفاع للأعلى", fn = function()
		local r = getRoot()
		if r then
			r.AssemblyLinearVelocity = Vector3.new(0, 110, 0)
		end
		return "اندفاع ✅"
	end },
}

local resetActions = {
	{ label = "💀 إعادة الشخصية", fn = function()
		local h = getHumanoid()
		if h then
			h.Health = 0
		end
		return "تمت الإعادة ✅"
	end },
	{ label = "🔄 إعادة الدخول للعبة", fn = function()
		pcall(function() TeleportService:Teleport(game.PlaceId, player) end)
		return "جاري الدخول..."
	end },
}

-- ====== سجل الأدوات ======
local TOOLS = {}
local function sl(min, max, default, ...)
	return { min = min, max = max, default = default, presets = { ... } }
end
local function add(id, title, color, keywords, apply, release, opts)
	opts = opts or {}
	TOOLS[#TOOLS + 1] = {
		id = id, title = title, color = color, keywords = keywords,
		apply = apply, release = release, world = opts.world, slider = opts.slider, on = false,
	}
end

-- حركة
add("speed", "🏃 سرعة الجري", COLORS.green, { "سرعة الجري", "سرعة", "جري", "اسرع", "speed", "walkspeed" },
	speedApply, speedRelease, { slider = sl(16, 500, 50, 30, 50, 100, 250) })
add("jump", "🦘 قوة القفز", COLORS.green, { "قوة القفز", "قفز عالي", "نط عالي", "jump" },
	jumpApply, jumpRelease, { slider = sl(50, 500, 100, 75, 100, 200, 400) })
add("fly", "🕊 طيران", COLORS.blue, { "طيران", "طير", "fly" },
	flyApply, flyRelease, { slider = sl(10, 300, 60, 30, 60, 120, 250) })
add("noclip", "👻 اختراق الجدران", COLORS.purple, { "اختراق الجدران", "اختراق", "جدران", "noclip" },
	noclipApply, noclipRelease, { world = true })
add("infjump", "♾ قفز لا نهائي", COLORS.teal, { "قفز لا نهائي", "قفز لانهائي", "لا نهائي", "لانهائي", "infinite", "infjump" },
	infApply, infRelease, { world = true })
add("autojump", "🐸 قفز تلقائي", COLORS.green, { "قفز تلقائي", "نط تلقائي", "قفز مستمر", "autojump" },
	ajApply, ajRelease, { world = true })
add("sprint", "💨 جري بزر Shift", COLORS.green, { "جري سريع", "شفت", "sprint", "shift" },
	sprintApply, sprintRelease, { world = true, slider = sl(20, 300, 60, 30, 60, 100, 200) })
add("gravity", "🪐 الجاذبية", COLORS.blue, { "جاذبية", "طفو", "gravity" },
	gravApply, gravRelease, { world = true, slider = sl(0, 400, 60, 20, 60, 120, 196) })
add("slowfall", "🪂 هبوط بطيء", COLORS.teal, { "هبوط بطيء", "مظلة", "سقوط بطيء", "slowfall" },
	slowApply, slowRelease, { world = true, slider = sl(5, 100, 15, 5, 15, 30, 60) })
add("antivoid", "🛟 منع السقوط في الفراغ", COLORS.green, { "منع السقوط", "فراغ", "antivoid", "void" },
	avApply, avRelease, { world = true })
add("antistumble", "🧍 منع التعثر", COLORS.green, { "منع التعثر", "تعثر", "سقوط", "رقدوول", "ragdoll" },
	stumbleApply, stumbleRelease)
add("nosit", "🪑 منع الجلوس", COLORS.muted, { "منع الجلوس", "جلوس", "كرسي" },
	nositApply, nositRelease)
add("nocollide", "🫥 عدم التصادم مع اللاعبين", COLORS.purple, { "عدم التصادم", "تصادم", "ما يصطدم" },
	ncpApply, ncpRelease, { world = true })
add("clicktp", "🖱 انتقال بالنقر", COLORS.blue, { "انتقال بالنقر", "تيليبورت", "انتقال", "teleport", "tp" },
	ctpApply, ctpRelease, { world = true })
add("hipheight", "📏 ارتفاع الشخصية", COLORS.blue, { "ارتفاع الشخصية", "ارتفاع", "hipheight" },
	hipApply, hipRelease, { slider = sl(0, 30, 5, 0, 3, 8, 20) })
add("slope", "⛰ زاوية الصعود", COLORS.blue, { "زاوية الصعود", "تسلق", "منحدر", "slope" },
	slopeApply, slopeRelease, { slider = sl(0, 89, 89, 45, 60, 80, 89) })
add("spin", "🌀 دوران", COLORS.pink, { "دوران", "لف", "spin" },
	spinApply, spinRelease, { slider = sl(1, 100, 10, 5, 10, 30, 80) })
add("freeze", "🧊 تجميد", COLORS.teal, { "تجميد", "ثبات", "freeze" },
	freezeApply, freezeRelease)
add("sit", "💺 جلوس", COLORS.muted, { "اجلس", "قعود", "sit" },
	sitApply, sitRelease)

-- كاميرا
add("camoffset", "🎬 إزاحة الكاميرا", COLORS.blue, { "ازاحة الكاميرا", "رفع الكاميرا", "camera offset" },
	coApply, coRelease, { slider = sl(0, 20, 4, 0, 2, 4, 10) })
add("minzoom", "🔍 تقريب الكاميرا", COLORS.teal, { "تقريب الكاميرا", "اقل مسافة", "min zoom" },
	minZoomApply, minZoomRelease, { world = true, slider = sl(1, 100, 30, 1, 10, 30, 100) })
add("zoomdist", "🔭 مسافة الكاميرا", COLORS.teal, { "مسافة الكاميرا", "زوم لا نهائي", "تبعيد", "zoom out" },
	zoomApply, zoomRelease, { world = true, slider = sl(10, 1000, 300, 40, 100, 300, 1000) })
add("fov", "🎯 مجال الرؤية (زوم)", COLORS.teal, { "زوم", "fov", "مجال الرؤية", "الرؤية" },
	fovApply, fovRelease, { world = true, slider = sl(30, 120, 100, 40, 70, 100, 120) })
add("firstperson", "🎥 منظور الشخص الأول", COLORS.blue, { "منظور اول", "شخص اول", "اول شخص", "first person" },
	fpApply, fpRelease, { world = true })

-- إضاءة وجودة
add("ultra", "💎 جودة رهيبة", COLORS.purple, { "جودة رهيبة", "جودة عالية", "جودة خرافية", "ultra", "رسومات", "جرافيك", "graphics" },
	ultraApply, ultraRelease, { world = true })
add("fullbright", "☀ إضاءة كاملة", COLORS.orange, { "اضاءة كاملة", "فل برايت", "fullbright" },
	fbApply, fbRelease, { world = true })
add("time", "🕐 وقت اليوم", COLORS.orange, { "وقت اليوم", "الوقت", "ليل", "نهار", "clocktime" },
	timeApply, timeRelease, { world = true, slider = sl(0, 24, 12, 0, 6, 12, 18) })
add("brightness", "🔅 سطوع الإضاءة", COLORS.orange, { "سطوع", "ساطع", "brightness", "شدة الاضاءة" },
	brightApply, brightRelease, { world = true, slider = sl(0, 10, 3, 1, 3, 5, 10) })
add("exposure", "📸 تعريض الضوء", COLORS.blue, { "تعريض", "exposure" },
	expoApply, expoRelease, { world = true, slider = sl(-3, 3, 1, -2, 0, 1, 3) })
add("nofog", "🌫 إزالة الضباب", COLORS.teal, { "ضباب", "fog" },
	nfApply, nfRelease, { world = true })
add("noshadows", "🌑 إزالة الظلال", COLORS.muted, { "ظلال", "ظل", "shadows" },
	nsApply, nsRelease, { world = true })
add("potato", "🥔 وضع البطاطس", COLORS.orange, { "بطاطس", "potato", "اضعف جودة", "اقل جودة" },
	potatoApply, potatoRelease, { world = true })
add("fpsboost", "🚀 رفع الأداء", COLORS.green, { "رفع الاداء", "تحسين الاداء", "تقليل الجودة", "تخفيف", "لاق", "lag", "boost", "اداء" },
	boostApply, boostRelease, { world = true })
add("dof", "🌁 ضبابية الخلفية", COLORS.teal, { "ضبابية الخلفية", "عمق الميدان", "dof" },
	dofApply, dofRelease, { world = true, slider = sl(5, 200, 50, 10, 30, 80, 200) })
add("cinematic", "🎞 ألوان سينمائية", COLORS.orange, { "سينمائي", "سينما", "cinematic" },
	cineApply, cineRelease, { world = true })
add("nightvision", "🌙 رؤية ليلية", COLORS.green, { "رؤية ليلية", "night vision", "nightvision" },
	nvApply, nvRelease, { world = true })
add("bw", "⚫ أبيض وأسود", COLORS.muted, { "ابيض واسود", "اسود وابيض", "رمادي", "grayscale" },
	bwApply, bwRelease, { world = true })
add("bloom", "🌟 توهج الضوء", COLORS.orange, { "توهج الضوء", "بلوم", "bloom" },
	bloomApply, bloomRelease, { world = true, slider = sl(0, 50, 10, 5, 10, 25, 50) })
add("sunrays", "🌅 أشعة الشمس", COLORS.orange, { "اشعة الشمس", "اشعه", "sunrays" },
	raysApply, raysRelease, { world = true, slider = sl(0, 100, 30, 10, 30, 60, 100) })
add("saturation", "🎨 تشبع الألوان", COLORS.pink, { "تشبع", "ساتوريشن", "saturation", "الوان" },
	satApply, satRelease, { world = true, slider = sl(-100, 300, 150, -100, 0, 150, 300) })
add("blur", "💨 تغبيش الشاشة", COLORS.muted, { "تغبيش", "بلور", "blur" },
	blurApply, blurRelease, { world = true, slider = sl(0, 56, 12, 5, 12, 30, 56) })
add("snow", "❄ ثلج", COLORS.teal, { "ثلج", "تلج", "snow" },
	snowApply, snowRelease, { world = true })
add("light", "💡 إضاءة حولك", COLORS.orange, { "ضوء", "نور", "لمبة", "light" },
	ltApply, ltRelease, { slider = sl(10, 100, 40, 15, 30, 60, 100) })
add("colorlight", "🔆 لمبة ملونة", COLORS.pink, { "لمبة ملونة", "ضوء ملون", "نور ملون" },
	clApply, clRelease)

-- مظهر الشخصية
add("rainbow", "🌈 ألوان قوس قزح", COLORS.pink, { "قوس قزح", "رينبو", "rainbow", "ملون" },
	rbApply, rbRelease)
add("neon", "✨ نيون", COLORS.pink, { "نيون", "neon", "لمعان" },
	neonApply, neonRelease)
add("trail", "☄ ذيل ملون", COLORS.pink, { "ذيل", "اثر", "trail" },
	tlApply, tlRelease)
add("aura", "🔮 هالة", COLORS.purple, { "هالة", "اورا", "aura" },
	auraApply, auraRelease)
add("fire", "🔥 نار", COLORS.red, { "نار", "حريق", "fire" },
	fireApply, fireRelease)
add("sparkles", "🎇 بريق", COLORS.orange, { "بريق", "لمعان", "sparkles" },
	sparkApply, sparkRelease)
add("smoke", "💭 دخان", COLORS.muted, { "دخان", "smoke" },
	smokeApply, smokeRelease)
add("shield", "🛡 درع بصري", COLORS.blue, { "درع", "حماية", "forcefield" },
	shieldApply, shieldRelease)
add("transparency", "🫧 شفافية الشخصي
