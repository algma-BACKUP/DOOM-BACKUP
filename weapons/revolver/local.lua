--[[
    Name: RevolverLocalScript.
    Description: This script contains the client logic for the "Revolver" in the game "DO:OM," created by @sworsch.
    Author: @sworsch
    Copyright: (c) 2023 sworsch
    Version: 1.0.0
]]

repeat wait() until not script:IsDescendantOf(game:GetService("ServerStorage"))

local player = game:GetService("Players").LocalPlayer
local character = player.Character
local humanoid = character:WaitForChild("Humanoid")

local animator = humanoid:WaitForChild("Animator")
local animid_Idle  = Instance.new("Animation") animid_Idle.AnimationId  = "rbxassetid://12991939961"
local animid_Shoot = Instance.new("Animation") animid_Shoot.AnimationId = "rbxassetid://12991953080"

local idleAnimation  = animator:LoadAnimation(animid_Idle)
local shootAnimation = animator:LoadAnimation(animid_Shoot)

-- Sound variables
local soundEvent            = game:GetService("ReplicatedStorage").Events.Misc.createSound
local bodyManipulationEvent = game:GetService("ReplicatedStorage").Events.Player.bodyManipulationEvent

local excludeFolders = {workspace.World_Ignore.Barriers, player.Character}
local includeFolders = {workspace.Map, workspace.World_Ignore.Ragdolls}

local M1_DOWN = false
local WEAPON_UI = nil

-- Returns the aiming position of the local player.
getAimingPosition = function()
	local exclude = {}
	for _, folder in pairs(excludeFolders) do
		for _, part in pairs(folder:GetDescendants()) do
			if part:IsA("BasePart") then
				table.insert(exclude, part)
			end
		end
	end

	for _, s_player in pairs(game.Players:GetChildren()) do
		if s_player ~= player then
			local character = s_player.Character

			if character then
				for _, part in pairs(character:GetDescendants()) do
					if part:IsA("BasePart") then  
						if part.Parent.Name ~= 'CollisionParts' then
							table.insert(exclude, part)
						end
					end
				end	
			end	
		else
			local character = player.Character

			if character then
				for _, part in pairs(character:GetDescendants()) do
					if part:IsA("BasePart") then
						table.insert(exclude, part)
					end
				end	
			end
		end
	end 	

	local mouse = player:GetMouse()
	local mouseRay = workspace.CurrentCamera:ScreenPointToRay(mouse.X, mouse.Y, 0)
	mouseRay = Ray.new(mouseRay.Origin, mouseRay.Unit.Direction * 999)

	local hit, hitPos, normal = game.Workspace:FindPartOnRayWithIgnoreList(mouseRay, exclude or {}, true, false)
	local aimCFrame = CFrame.new(hitPos, (hitPos + mouseRay.Unit.Direction))
	local aimPosition: Vector3 = aimCFrame.Position

	return aimPosition
end

local Revolver = {
	tool = script.Parent,
	shooting = false,
	bullets = 6,
	
	reloading = false,
	
	-- Shoots a bullet.
	-- @param self (table): The weapon table.
	--     - shooting (BoolValue): If the weapon is currently shooting.
	--	   - bullets (number): How many bullets the weapon has.
	action = function(
		self: { 
			tool: Tool,
			shooting: BoolValue,
			bullets: number,
			reloading: BoolValue
		})
		
		if humanoid.Health > 0 and not self.shooting and self.bullets > 0 then
			self.shooting = true
			self.bullets -= 1

			-- Fire sound event
			soundEvent:FireServer("revolver_fire", player.Character.Head.Position, 0.5, 325)

			-- Require module script
			local module = require(self.tool:FindFirstChildOfClass("ModuleScript"))

			-- Get positions and direction
			local originPosition = character:FindFirstChild("Head").Position
			local aimPosition = getAimingPosition()
			local aimDirection = (aimPosition - originPosition).Unit

			-- Create hitscan
			local hitscan = module.hitscanCompiler.createHitscan(player, originPosition, aimDirection)

			-- Check hitscan result
			if hitscan.Part then
				if hitscan.Part.Parent.Name == "CollisionParts" then
					local s_player = game:GetService("Players"):GetPlayerFromCharacter(hitscan.Part--[[CollisionParts]].Parent--[[player.Character]].Parent)

					if s_player then
						local humanoid = s_player.Character:FindFirstChildOfClass('Humanoid')

						-- Play sound effect
						local sound = Instance.new("Sound", player.Character.Humanoid)
						sound.SoundId = "rbxassetid://13009407685"
						game.Debris:AddItem(sound, 5)
						sound:Play()

						if hitscan.Part.Name == "Head" then
							local headshot_sound = Instance.new("Sound", player.Character.Humanoid)
							headshot_sound.SoundId = "rbxassetid://13318047576"
							game.Debris:AddItem(headshot_sound, 5)
							headshot_sound:Play()
						end
					end
				end
			end

			-- Create trail
			if hitscan.Position then
				module.trailFactory.create(originPosition, hitscan.Position)
			else
				module.trailFactory.create(originPosition, aimPosition)
			end

			-- Fire remote event
			self.tool:FindFirstChildOfClass("RemoteEvent"):FireServer(hitscan.Position, hitscan.Part)
			
			if self.reloading then
				wait(2.5)	
				self.reloading = false
			else
				wait(1.5)
			end
			
			self.shooting = false
		end
	end,
	
	reload = function(
		self: { 
			tool: Tool,
			shooting: BoolValue,
			bullets: number,
			reloading: BoolValue
		})
		
		if self.reloading == false then
			self.reloading = true
			repeat
				if self.bullets + 1 > 6 then
					break
				end
				
				soundEvent:FireServer("revolver_reloadBullet", player.Character.Head.Position, 0.5, 325)

				if self.reloading then
					self.bullets += 1
				end

				wait(.75)
			until self.reloading == false
		end
	end,
}

Revolver.tool:FindFirstChildOfClass("RemoteEvent").OnClientEvent:Connect(function(trail: BasePart)
	if trail then
		trail:Destroy()
	end
end)

function onEquipped()
	soundEvent:FireServer("revolver_equip", player.Character.Head.Position, .5, 325)
end
Revolver.tool.Equipped:Connect(onEquipped)


local UserInputService = game:GetService("UserInputService")
function onRender()
	if script:IsDescendantOf(workspace) then
		idleAnimation:Play()
		
		if M1_DOWN then
			if Revolver.bullets > 0 then
				Revolver:action()
			else
				Revolver:reload()
			end
		end
		
		-- BodyManipulation
		local Rshoulder = character:FindFirstChild("Right Shoulder", true)
		local Lshoulder = character:FindFirstChild("Left Shoulder", true)
		local playerMouse = game.Players.LocalPlayer:GetMouse()
		local CFNew, CFAng = CFrame.new, CFrame.Angles
		local asin, pi = math.asin, math.pi

		if Rshoulder and Lshoulder then
			local rightX, rightY, rightZ = Rshoulder.C0:ToEulerAnglesYXZ()
			local leftX, leftY, leftZ = Lshoulder.C0:ToEulerAnglesYXZ()

			local rightAngle = asin((playerMouse.Hit.p - playerMouse.Origin.p).unit.y)
			local leftAngle = asin((-playerMouse.Hit.p + playerMouse.Origin.p).unit.y)

			rightAngle = math.clamp(rightAngle, -.8, .8)
			leftAngle = math.clamp(leftAngle, -.8, .8)

			--bodyManipulationEvent:FireServer(Rshoulder, (Rshoulder.C0 * CFAng(0, 0, -rightZ)) * CFAng(0, 0, rightAngle))
			Rshoulder.C0 = (Rshoulder.C0 * CFAng(0, 0, -rightZ)) * CFAng(0, 0, rightAngle)

			--bodyManipulationEvent:FireServer(Lshoulder, (Lshoulder.C0 * CFAng(0, 0, -leftZ)) * CFAng(0, 0, leftAngle))
			Lshoulder.C0 = (Lshoulder.C0 * CFAng(0, 0, -leftZ)) * CFAng(0, 0, leftAngle)
		end	

		-- UI
		UserInputService.MouseIcon = "http://www.roblox.com/asset/?id=13373452773"
		if not WEAPON_UI then
			WEAPON_UI = Instance.new("ScreenGui", player.PlayerGui)
			WEAPON_UI.Name = "REVOLVER_GUI"

			local bulletsFrame = Instance.new("Frame", WEAPON_UI)
			bulletsFrame.BackgroundTransparency = 1
			bulletsFrame.BorderSizePixel = 0
			bulletsFrame.Size = UDim2.new(0.1, 0, 0.084, 0)
			bulletsFrame.Position = UDim2.new(0.9, 0,0.9, 0)

			local bulletIndicator = Instance.new("TextLabel", bulletsFrame)
			bulletIndicator.Size = UDim2.new(1, 0, 1, 0)
			bulletIndicator.Position = UDim2.new(0, 0, 0, 0)
			bulletIndicator.BackgroundTransparency = 1
			bulletIndicator.BorderSizePixel = 0
			bulletIndicator.TextScaled = true
			bulletIndicator.TextColor3 = Color3.fromRGB(255, 255, 255)
			bulletIndicator.RichText = true
		end

		if WEAPON_UI then
			WEAPON_UI.Frame.TextLabel.Text = "<b>" .. Revolver.bullets .. "/6</b>"
		end
	else
		M1_DOWN = false
		idleAnimation:Stop()
		shootAnimation:Stop()
		
		-- BodyManipulation
		local Rshoulder = character:FindFirstChild("Right Shoulder", true)
		local Lshoulder = character:FindFirstChild("Left Shoulder", true)

		if Rshoulder and Lshoulder then
			Rshoulder.C0 = CFrame.new(Rshoulder.C0.Position) * CFrame.Angles(math.rad(0), math.rad(90), math.rad(0))
			Lshoulder.C0 = CFrame.new(Lshoulder.C0.Position) * CFrame.Angles(math.rad(0), math.rad(-90), math.rad(0))
		end	
		
		-- UI
		UserInputService.MouseIcon = ""
		if WEAPON_UI then
			WEAPON_UI:Destroy()
			WEAPON_UI = nil
		end
	end
end

function onInputBegan(input, typing)
	if not typing then
		if input.KeyCode == Enum.KeyCode.R or input.KeyCode == Enum.KeyCode.ButtonX then
			Revolver:reload()
		elseif (input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR1) then
			M1_DOWN = true
		end
	end
end

function onInputEnded(input, typing)
	if not typing and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR1) then
		M1_DOWN = false
	end
end

game:GetService("RunService").RenderStepped:Connect(onRender)
game:GetService("UserInputService").InputBegan:Connect(onInputBegan)
game:GetService("UserInputService").InputEnded:Connect(onInputEnded)
