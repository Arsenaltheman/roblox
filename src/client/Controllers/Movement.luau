--!strict
-- Sprint input + stamina prediction, and the feel of moving around: FOV kick, a run bob, sprint
-- speed lines, footstep dust on sand, a landing dust ring with a small camera dip, and a lean/wobble
-- on anyone carrying a critter or crate.
--
-- The server owns stamina and walk speed (Steal.luau). This side only asks to start/stop and runs the
-- same Stamina math so the bar moves instantly; it adopts the server's numbers whenever they change.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Palette = require("@game/ReplicatedStorage/Shared/Config/Palette")
local Stamina = require("@game/ReplicatedStorage/Shared/Sim/Stamina")
local Net = require("@game/ReplicatedStorage/Shared/Net/Net")
local Quality = require("./Quality")
local Vfx = require("./Vfx")
local Store = require("../Store")

local Movement = {}

local BASE_FOV = 70
local SPRINT_FOV = 80
-- A quick tap (touch button / L3 click) latches sprint on, since holding a thumb on a button while
-- steering is awkward. Holding still works as a plain hold.
local TAP_SECONDS = 0.25
local LATCHABLE = { touch = true, ButtonL3 = true }
-- Desert floors that kick up dust.
local DUSTY: { [Enum.Material]: boolean } = {
	[Enum.Material.Sand] = true,
	[Enum.Material.Sandstone] = true,
	[Enum.Material.Ground] = true,
	[Enum.Material.Mud] = true,
}
local DUST_COLOR = Palette.color("sand")
local DUST_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"

local localPlayer = Players.LocalPlayer

-- Sprint state.
local predicted = Stamina.new(os.clock())
local holds: { [string]: boolean } = {}
local pressedAt: { [string]: number } = {}
local latched: { [string]: boolean } = {}
local held = false
local lastRequest = -math.huge
local stillFor = 0

local function myHumanoid(): Humanoid?
	local character = localPlayer.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function myRoot(): BasePart?
	local character = localPlayer.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function isCarrying(player: Player): boolean
	local c = player:GetAttribute("Carrying")
	return (type(c) == "string" and c ~= "") or player:GetAttribute("HeistCarry") == true
end

local function flatSpeed(root: BasePart?): number
	if not root then
		return 0
	end
	local v = root.AssemblyLinearVelocity
	return math.sqrt(v.X * v.X + v.Z * v.Z)
end

-- The server zeroes walk speed while stunned (tackle, lasso, caught by the bandit).
local function stunned(): boolean
	local h = myHumanoid()
	return h ~= nil and h.WalkSpeed <= 0.01
end

local function request(on: boolean)
	lastRequest = os.clock()
	Net.request("Sprint", on)
end

local function publish()
	Store.sprinting(predicted.active)
end

local function setHeld(sourceName: string, on: boolean)
	if on then
		holds[sourceName] = true
	else
		holds[sourceName] = nil
	end
	local want = next(holds) ~= nil
	if want == held then
		return
	end
	held = want
	local t = os.clock()
	Stamina.advance(predicted, t, predicted.active and flatSpeed(myRoot()) > 2, isCarrying(localPlayer))
	Stamina.set(predicted, t, want and not stunned())
	request(want)
	publish()
end

local function clearLatches()
	for name in latched do
		latched[name] = nil
		setHeld(name, false)
	end
end

-- Input from any source ("LeftShift", "ButtonL3", "touch").
function Movement.press(sourceName: string)
	if latched[sourceName] then
		-- Tapping again turns a latched sprint off.
		latched[sourceName] = nil
		setHeld(sourceName, false)
		return
	end
	pressedAt[sourceName] = os.clock()
	setHeld(sourceName, true)
end

function Movement.release(sourceName: string)
	local at = pressedAt[sourceName]
	pressedAt[sourceName] = nil
	if at and LATCHABLE[sourceName] and os.clock() - at < TAP_SECONDS and predicted.active then
		latched[sourceName] = true
		return
	end
	setHeld(sourceName, false)
end

-- Adopt the server's stamina when it publishes (sprint start/stop/run dry/stun/respawn).
local function adoptServer()
	local value = localPlayer:GetAttribute("Stamina")
	if type(value) == "number" then
		predicted.value = math.clamp(value, 0, 1)
		predicted.updated = os.clock()
	end
	-- Right after our own request, an older attribute update may still be in flight; the periodic
	-- reconcile catches any real disagreement.
	if os.clock() - lastRequest > 0.5 then
		local active = localPlayer:GetAttribute("Sprinting") == true
		if predicted.active and not active then
			predicted.restedAt = os.clock()
			clearLatches()
		end
		predicted.active = active
	end
	publish()
end

-- Twice a second: if the server disagrees (a request was dropped, or it ran dry first), fix it.
local function reconcile()
	if os.clock() - lastRequest < 0.6 then
		return
	end
	local server = localPlayer:GetAttribute("Sprinting") == true
	if server == predicted.active then
		return
	end
	if server and not held then
		request(false) -- our release never arrived
	else
		if predicted.active and not server then
			predicted.restedAt = os.clock()
		end
		predicted.active = server
		publish()
	end
end

-- ------------------------------------------------------------------ dust

local fxPart: Part
local stepEmitter: ParticleEmitter
local ringEmitter: ParticleEmitter

local function makeFx()
	fxPart = Instance.new("Part")
	fxPart.Name = "MovementFx"
	fxPart.Size = Vector3.new(0.2, 0.2, 0.2)
	fxPart.Transparency = 1
	fxPart.Anchored = true
	fxPart.CanCollide = false
	fxPart.CanQuery = false
	fxPart.CanTouch = false
	fxPart.Parent = Workspace

	stepEmitter = Instance.new("ParticleEmitter")
	stepEmitter.Texture = DUST_TEXTURE
	stepEmitter.Color = ColorSequence.new(DUST_COLOR)
	stepEmitter.Size =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1.6) })
	stepEmitter.Transparency =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) })
	stepEmitter.Lifetime = NumberRange.new(0.35, 0.65)
	stepEmitter.Speed = NumberRange.new(1, 3)
	stepEmitter.SpreadAngle = Vector2.new(60, 60)
	stepEmitter.Acceleration = Vector3.new(0, 1.5, 0)
	stepEmitter.Drag = 3
	stepEmitter.RotSpeed = NumberRange.new(-60, 60)
	stepEmitter.Rotation = NumberRange.new(0, 360)
	stepEmitter.Rate = 0
	stepEmitter.Parent = fxPart

	-- Ring: aimed out the front and fired once per compass direction, so it spreads flat.
	ringEmitter = Instance.new("ParticleEmitter")
	ringEmitter.Texture = DUST_TEXTURE
	ringEmitter.Color = ColorSequence.new(DUST_COLOR)
	ringEmitter.EmissionDirection = Enum.NormalId.Front
	ringEmitter.Size =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 2.6) })
	ringEmitter.Transparency =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	ringEmitter.Lifetime = NumberRange.new(0.45, 0.75)
	ringEmitter.Speed = NumberRange.new(10, 15)
	ringEmitter.SpreadAngle = Vector2.new(6, 6)
	ringEmitter.Drag = 5
	ringEmitter.RotSpeed = NumberRange.new(-90, 90)
	ringEmitter.Rotation = NumberRange.new(0, 360)
	ringEmitter.Rate = 0
	ringEmitter.Parent = fxPart
end

local function footPosition(root: BasePart, humanoid: Humanoid): Vector3
	return root.Position - Vector3.new(0, root.Size.Y / 2 + humanoid.HipHeight - 0.2, 0)
end

local function stepPuff(position: Vector3, count: number)
	fxPart.CFrame = CFrame.new(position)
	stepEmitter:Emit(count)
end

local function landingRing(position: Vector3, strength: number)
	local q = Store.quality()
	local directions = if q >= 3 then 14 elseif q == 2 then 10 else 6
	for i = 1, directions do
		fxPart.CFrame = CFrame.new(position) * CFrame.Angles(0, (i / directions) * math.pi * 2, 0)
		ringEmitter:Emit(if strength > 0.6 and q >= 2 then 2 else 1)
	end
end

-- ------------------------------------------------------------------ carry lean

-- Original Waist C0 per motor we've bent, so it goes back exactly (client-side only: never replicates).
local bent: { [Motor6D]: { base: CFrame, amount: number } } = {}

local function waist(player: Player): Motor6D?
	local character = player.Character
	local upper = character and character:FindFirstChild("UpperTorso")
	local motor = upper and upper:FindFirstChild("Waist")
	return if motor and motor:IsA("Motor6D") then motor else nil
end

local function updateLean(dt: number, t: number)
	local camera = Workspace.CurrentCamera
	local q = Store.quality()
	for _, player in Players:GetPlayers() do
		local motor = waist(player)
		if not motor then
			continue
		end
		local entry = bent[motor]
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local want = isCarrying(player) and root ~= nil
		-- Other players' wobble is skipped on low quality and when far away.
		if want and player ~= localPlayer and camera and root then
			want = q >= 2 and (root.Position - camera.CFrame.Position).Magnitude < 150
		end
		if not want and not entry then
			continue
		end
		if not entry then
			entry = { base = motor.C0, amount = 0 }
			bent[motor] = entry
		end
		entry.amount += ((if want then 1 else 0) - entry.amount) * math.min(1, dt * 6)
		if not want and entry.amount < 0.01 then
			motor.C0 = entry.base
			bent[motor] = nil
			continue
		end
		local run = math.clamp(flatSpeed(root) / 20, 0, 1)
		local seed = player.UserId % 7
		-- Lean into the run under the load, and sway side to side with the stride.
		local pitch = -math.rad(3 + 5 * run)
		local roll = math.sin(t * (4 + 5 * run) + seed) * math.rad(2 + 3 * run)
		motor.C0 = entry.base * CFrame.Angles(pitch * entry.amount, 0, roll * entry.amount)
	end
	-- Forget motors whose character is gone.
	for motor in bent do
		if not motor.Parent then
			bent[motor] = nil
		end
	end
end

-- ------------------------------------------------------------------ per frame

local sprintBlend = 0
local bobPhase = 0
local stride = 0
local fovOwned = false
local lastStaminaShown = 1
local dipStarted = -math.huge
local dipStrength = 0
local fallStarted: number? = nil
local fallPeak = 0

local function onLanded(root: BasePart, humanoid: Humanoid)
	local started = fallStarted
	fallStarted = nil
	if not started then
		return
	end
	local airtime = os.clock() - started
	local impact = math.clamp((-fallPeak - 20) / 50, 0, 1)
	fallPeak = 0
	if airtime < 0.35 and impact <= 0 then
		return
	end
	local strength = math.max(impact, math.clamp((airtime - 0.35) / 1, 0, 1))
	local position = footPosition(root, humanoid)
	if DUSTY[humanoid.FloorMaterial] or humanoid.FloorMaterial == Enum.Material.Air then
		landingRing(position, strength)
	else
		stepPuff(position, 3)
	end
	if not Quality.reducedMotion() then
		dipStarted = os.clock()
		dipStrength = 0.15 + 0.35 * strength
	end
end

local function frame(dt: number)
	local t = os.clock()
	local humanoid = myHumanoid()
	local root = myRoot()
	local speed = flatSpeed(root)
	local moving = speed > 2

	-- Stamina prediction.
	if Stamina.advance(predicted, t, predicted.active and moving, isCarrying(localPlayer)) then
		clearLatches()
		publish()
	end
	if predicted.active and stunned() then
		Stamina.set(predicted, t, false)
		clearLatches()
		publish()
	end
	-- A latched sprint ends once you stop running.
	stillFor = if moving then 0 else stillFor + dt
	if stillFor > 0.6 and next(latched) then
		clearLatches()
	end
	if
		math.abs(predicted.value - lastStaminaShown) > 0.004
		or (predicted.value >= 1 and lastStaminaShown < 1)
	then
		lastStaminaShown = predicted.value
		Store.stamina(predicted.value)
	end

	local reduced = Quality.reducedMotion()
	local target = if predicted.active and moving then 1 else 0
	sprintBlend += (target - sprintBlend) * math.min(1, dt * 7)
	local eased = sprintBlend * sprintBlend * (3 - 2 * sprintBlend)

	-- FOV kick (only while the normal follow camera is in charge, so cutscenes keep their FOV).
	local camera = Workspace.CurrentCamera
	if camera and camera.CameraType == Enum.CameraType.Custom then
		local kick = if reduced then 0 else (SPRINT_FOV - BASE_FOV)
		local fov = BASE_FOV + kick * eased
		if fovOwned or eased > 0.001 then
			camera.FieldOfView = fov
			fovOwned = eased > 0.001
		end
	end

	-- Camera: run bob (sprinting only) + landing dip.
	local offset = Vector3.zero
	if not reduced and eased > 0.01 then
		bobPhase += dt * math.max(speed, 8) * 0.5
		offset += Vector3.new(math.cos(bobPhase) * 0.07, (math.abs(math.sin(bobPhase)) - 0.5) * 0.16, 0) * eased
	end
	local dipT = (t - dipStarted) / 0.3
	if dipT >= 0 and dipT < 1 then
		offset += Vector3.new(0, -dipStrength * math.sin(dipT * math.pi), 0)
	end
	Vfx.cameraOffset("movement", offset)

	-- Speed lines (Vfx draws them; base-speed sprinting is below its own threshold).
	Vfx.speedLines(if Store.quality() >= 2 then eased * 0.5 else 0)

	if not humanoid or not root then
		return
	end

	-- Falling: remember the hardest downward speed for the landing.
	if fallStarted then
		fallPeak = math.min(fallPeak, root.AssemblyLinearVelocity.Y)
	end

	-- Footstep dust: a puff every stride on dusty ground.
	local q = Store.quality()
	if moving and DUSTY[humanoid.FloorMaterial] and (q >= 2 or predicted.active) then
		stride += speed * dt
		local strideLength = if predicted.active then 5 else 6.5
		if stride >= strideLength then
			stride = 0
			local back = root.CFrame.LookVector * -0.6
			stepPuff(
				footPosition(root, humanoid) + back,
				if predicted.active then 3 elseif q >= 3 then 2 else 1
			)
		end
	else
		stride = 0
	end
end

-- ------------------------------------------------------------------ boot

local function hookCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	fallStarted = nil
	fallPeak = 0
	humanoid.StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Freefall then
			fallStarted = os.clock()
			fallPeak = 0
		elseif new == Enum.HumanoidStateType.Landed then
			local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				onLanded(root, humanoid)
			end
		end
	end)
	-- The FOV may have been mid-kick when we died.
	fovOwned = true
end

-- Shift-lock defaults to Shift. Move it to Ctrl so Shift is free for sprint (best effort: these are
-- Roblox's own PlayerModule children and may change).
local function moveShiftLockToCtrl()
	task.spawn(function()
		local ok = pcall(function()
			local scripts = localPlayer:WaitForChild("PlayerScripts", 10)
			local module = scripts and scripts:WaitForChild("PlayerModule", 10)
			local camera = module and module:WaitForChild("CameraModule", 10)
			local controller = camera and camera:WaitForChild("MouseLockController", 10)
			local keys = controller and controller:WaitForChild("BoundKeys", 10)
			if keys and keys:IsA("StringValue") then
				keys.Value = "LeftControl,RightControl"
			end
		end :: any)
		if not ok then
			warn("[Movement] couldn't move shift-lock to Ctrl")
		end
	end)
end

function Movement.init()
	makeFx()
end

function Movement.start()
	-- No touch button from ContextActionService: it would sit on top of (and hide) the jump button.
	-- Touch players get our own SPRINT button (UI/SprintButton).
	ContextActionService:BindActionAtPriority("Sprint", function(_, inputState, input)
		local name = input.KeyCode.Name
		if inputState == Enum.UserInputState.Begin then
			Movement.press(name)
		elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
			Movement.release(name)
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
	moveShiftLockToCtrl()

	-- Alt-tabbing away while holding Shift never sends the key-up.
	UserInputService.WindowFocusReleased:Connect(function()
		for name in table.clone(holds) do
			latched[name] = nil
			setHeld(name, false)
		end
	end)

	localPlayer:GetAttributeChangedSignal("Stamina"):Connect(adoptServer)
	localPlayer:GetAttributeChangedSignal("Sprinting"):Connect(adoptServer)
	if localPlayer.Character then
		task.spawn(hookCharacter, localPlayer.Character)
	end
	localPlayer.CharacterAdded:Connect(function(character)
		-- Respawn: fresh full bar and nothing held over from the old body.
		clearLatches()
		predicted = Stamina.new(os.clock())
		publish()
		hookCharacter(character)
	end)

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator >= 0.5 then
			accumulator = 0
			reconcile()
		end
	end)
	-- Before the camera reads CameraOffset / FieldOfView this frame.
	RunService:BindToRenderStep("Movement", Enum.RenderPriority.Camera.Value - 2, frame)
	RunService.Heartbeat:Connect(function(dt)
		updateLean(dt, os.clock())
	end)
end

return Movement
