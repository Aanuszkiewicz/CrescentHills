--[[
	The script that controls the Crystal Colossus boss.
--]]

local monster = script.Parent
local homePosition = script.Parent.HumanoidRootPart.Position
local aiMode = script.Parent.Config:FindFirstChild("AIMode")
local playerListMod = require(game.ReplicatedStorage.Modules.PlayerList)
local targetDist = script.Parent.Config.TargetingDistance.Value
local pursueDist = script.Parent.Config.MaxPursueDistance.Value 
local rayProjModule = require(game.ReplicatedStorage.Modules.RayProjectile)
local targeting = script.Targeting
local mhrp = monster.HumanoidRootPart
local aiV = nil
local aggroTorso = nil
local aimTarget = nil
local alive = true
local bossActive = false
local homePosition = mhrp.Position
local regenWaiting = false
local bossDying = false
local playersInZone = {}
local animations = {}

if aiMode then
	aiV = aiMode.Value
end

local monsterName = monster.Name --Consider quests
local questsInvolvingMonster = {}
for i,quest in pairs(game.ReplicatedStorage:WaitForChild("Quests"):GetChildren()) do
	local config = quest:FindFirstChild("QuestConfig")
	if config then
		local qtype = config:FindFirstChild("QuestType")
		if qtype then
			if qtype.Value == "Slay" then
				local slayMonsters = config:FindFirstChild("SlayMonsters")
				if slayMonsters then
					for i, monster in pairs(slayMonsters:GetChildren()) do
						if monster.Name == monsterName then
							table.insert(questsInvolvingMonster, quest)
						end
					end
				end
			end
		end
	end
end

function findNearestTorso(pos)
	local pList = game.Players:GetPlayers()
	local torso = nil
	local temp = nil
	local human = nil
	local char = nil
	local distance = nil
	for i,v in pList do
		char = v.Character or v.CharacterAdded:Wait()
		local rootP = char:findFirstChild("HumanoidRootPart")
		human = char:findFirstChild("Humanoid")
		if (human.Health > 0) then
			if rootP then
				local distanceVector = rootP.Position - pos
				if distanceVector.Magnitude < targetDist then
					if not torso then
						torso = rootP
						distance = distanceVector.Magnitude
					else
						if distanceVector.Magnitude < distance then
							torso = rootP
							distance = distanceVector.Magnitude
						end
					end
				end
			end
		end
	end
	return torso, distance
end

function createKnockback(VictimHRP, originPoint, applicationDuration)	 
	local kbApplicationDuration = applicationDuration
	if(kbApplicationDuration > 0) then
		local velo = Instance.new("BodyVelocity", VictimHRP)
		velo.MaxForce = Vector3.new(100000000,100000000,10000000)
		velo.P = 10000000
		local Angle = ((VictimHRP.Position - originPoint.Position) * Vector3.new(10,0,10)).Unit * 100 + Vector3.new(0,25,0)
		velo.Velocity = Angle
		wait(kbApplicationDuration)
		velo:Destroy()
	end
end

local bossParts = Instance.new("Folder", game.Workspace)

function colossus()
	local attacks = monster:WaitForChild("Attacks")
	local mHumanoid = monster.Humanoid
	local chasingPlayer = false
	local waitTime = 0.1
	local tickAttackChance = 0.075 --.05 
	local meleeRange = 40
	local defaultWalkSpeed = mHumanoid.WalkSpeed
	local attacksDict = {}
	local cooldowns = {}
	local cinematicAnimation = mHumanoid:LoadAnimation(monster.Misc.Cinematic)
	cinematicAnimation:GetMarkerReachedSignal("Roar"):Connect(function()
		monster.Head.CinematicRoar:Play()
	end)
	cinematicAnimation:GetMarkerReachedSignal("Stomp"):Connect(function()
		monster.RightFoot.StompLoud:Play()
	end)
	local function facePlayer(tweenTime, phrp)
		spawn(function()
			wait()
			mhrp.AlignOrientation.Enabled = true
			mhrp.AlignOrientation.CFrame = CFrame.new(mhrp.Position, phrp.Position)
			wait(tweenTime)
			mhrp.AlignOrientation.Enabled = false
		end)
	end
	for i,v in pairs(attacks:GetChildren()) do
		local aType = v.AttackType.Value
		if attacksDict[aType] == nil then
			attacksDict[aType] = {v}
		else
			table.insert(attacksDict[aType], v)
		end
		cooldowns[v.Name] = false
		local animInstance = v:FindFirstChild("Animation")
		if animInstance then
			local anim = mHumanoid:LoadAnimation(animInstance)
			animations[v] = anim
			-- animation specific events
			if v.Name == "Slam" then
				--print("create slam markerreachedsignal")
				animations[v]:GetMarkerReachedSignal("Slam"):Connect(function()
					local rHand = monster.RightHand
					local lHand = monster.LeftHand
					local midpoint = (rHand.Position + lHand.Position) / 2
					local radius = v.Radius.Value
					rHand.Slam:Play()
					local hitbox = Instance.new("Part", bossParts)
					hitbox.Anchored = true
					hitbox.CanCollide = false
					hitbox.Transparency = 1
					hitbox.Shape = Enum.PartType.Ball
					hitbox.Size = Vector3.new(radius, radius, radius)
					local crater = game.ReplicatedStorage.BossAssets:FindFirstChild("Crystal Colossus"):FindFirstChild("Crater"):Clone()
					crater.Parent = game.Workspace
					local pPart = crater.PrimaryPart
					crater:SetPrimaryPartCFrame(CFrame.new(midpoint) * CFrame.new(0, -2, 0) * CFrame.Angles(0, math.rad(math.random(-180, 180)), 0))
					game:GetService("Debris"):AddItem(crater, 5)
					local hitPlayers = {}
					hitbox.Touched:Connect(function(hit)
						if hit.Parent then
							local potChar = hit.Parent
							local player = game.Players:GetPlayerFromCharacter(potChar)
							if player then
								if table.find(hitPlayers, player) == nil then
									table.insert(hitPlayers, player)
									player.Character.Humanoid:TakeDamage(v.Damage.Value)
								end
							end
						end
					end)
					hitbox.Position = midpoint
					pPart.Debris.Enabled = true
					wait(.2)
					pPart.Debris.Enabled = false
					wait(.4)
					hitbox:Destroy()
				end)
			elseif v.Name == "Roar" then
				animations[v]:GetMarkerReachedSignal("Stomp"):Connect(function()
					monster.RightFoot.StompLoud:Play()
					local stompHitPlayers = {}
					local stompDamage = monster.RightFoot.Touched:Connect(function(hit)
						if hit.Parent then
							local potChar = hit.Parent
							local player = game.Players:GetPlayerFromCharacter(potChar)
							if player then
								if table.find(stompHitPlayers, player) == nil then
									table.insert(stompHitPlayers, player)
									player.Character.Humanoid:TakeDamage(v.StompDamage.Value)
								end
							end
						end
					end)
					wait(.2)
					stompDamage:Disconnect()
				end)
				animations[v]:GetMarkerReachedSignal("Roar"):Connect(function()
					monster.Head.Roar:Play()
					local roarEntity = game.ReplicatedStorage.BossAssets:FindFirstChild("Crystal Colossus"):FindFirstChild("Roar"):Clone()
					roarEntity.Parent = game.Workspace
					roarEntity:SetPrimaryPartCFrame(CFrame.new(monster.Head.Position))
					roarEntity.Active.Value = true
					local roarTime = 1.25
					local fadeTime = 1.5
					local range = v.Radius.Value
					
					local ts = game:GetService("TweenService")
					local aoe = roarEntity.AOE
					local outerRing = roarEntity.OuterRing
					local innerRing = roarEntity.Ring
					local info = TweenInfo.new(roarTime, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
					local infoRot = TweenInfo.new(roarTime/3, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
					local aoeproperties = {Size = Vector3.new(range, range, range)}
					local outerRingSizeProperties = {Size = Vector3.new(range, range, roarEntity.OuterRing.Size.Z)}
					local innerRingSizeProperties = {Size = Vector3.new(range - 10, innerRing.Size.Y, range - 10)}
					local innerRingRot1Properties = {CFrame = innerRing.CFrame * CFrame.Angles(0, math.rad(120), 0)}
					local innerRingRot2Properties = {CFrame = innerRing.CFrame * CFrame.Angles(0, math.rad(240), 0)}
					local innerRingRot3Properties = {CFrame = innerRing.CFrame * CFrame.Angles(0, math.rad(360), 0)}
					
					local tweenaoe = ts:Create(aoe, info, aoeproperties)
					local tweenOuter = ts:Create(outerRing, info, outerRingSizeProperties)
					local tweenInnerSize = ts:Create(innerRing, info, innerRingSizeProperties)
					local tweenRot1 = ts:Create(innerRing, infoRot, innerRingRot1Properties)
					local tweenRot2 = ts:Create(innerRing, infoRot, innerRingRot2Properties)
					local tweenRot3 = ts:Create(innerRing, infoRot, innerRingRot3Properties)
					tweenaoe:Play()
					tweenOuter:Play()
					tweenInnerSize:Play()
					tweenRot1:Play()
					tweenRot1.Completed:Connect(function() tweenRot2:Play() end)
					tweenRot2.Completed:Connect(function() tweenRot3:Play() end)
					aoe.AirPressure:Play()
					local hitPlayers = {}
					aoe.Touched:Connect(function(hit)
						if hit.Parent then
							local potChar = hit.Parent
							local player = game.Players:GetPlayerFromCharacter(potChar)
							if player then
								if table.find(hitPlayers, player) == nil then
									table.insert(hitPlayers, player)
									player.Character.Humanoid:TakeDamage(v.Damage.Value)
									aoe.Hit:Play()
									local kb = coroutine.wrap(createKnockback)
									kb(player.Character.HumanoidRootPart, aoe, v.KnockbackTime.Value)
								end
							end
						end					
					end)
					tweenaoe.Completed:Wait()
					
					local fadeInfo = TweenInfo.new(fadeTime, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
					local fadeProperties1 = {Transparency = 1, Size = aoe.Size + Vector3.new(50, 50, 50)}
					local fadeProperties2 = {Transparency = 1, Size = outerRing.Size + Vector3.new(50, 50, 0)}
					local fadeProperties3 = {Transparency = 1, Size = innerRing.Size + Vector3.new(50, 0, 50)}
					local tweenFade1 = ts:Create(aoe, fadeInfo, fadeProperties1)
					local tweenFade2 = ts:Create(outerRing, fadeInfo, fadeProperties2)
					local tweenFade3 = ts:Create(innerRing, fadeInfo, fadeProperties3)
					tweenFade1:Play()
					tweenFade2:Play()
					tweenFade3:Play()
					wait(fadeTime)
					roarEntity:Destroy()
				end)
				animations[v]:GetMarkerReachedSignal("StepLeft"):Connect(function()
					monster.LeftFoot.StompSound:Play()
				end)		
				animations[v]:GetMarkerReachedSignal("StepRight"):Connect(function()
					monster.RightFoot.StompSound:Play()
				end)		
			elseif v.Name == "Throw" then
				local boulder = nil
				animations[v]:GetMarkerReachedSignal("StompSound"):Connect(function()
					monster.RightFoot.StompLoud:Play()
					local stompHitPlayers = {}
					local stompDamage = monster.RightFoot.Touched:Connect(function(hit)
						if hit.Parent then
							local potChar = hit.Parent
							local player = game.Players:GetPlayerFromCharacter(potChar)
							if player then
								if table.find(stompHitPlayers, player) == nil then
									table.insert(stompHitPlayers, player)
									player.Character.Humanoid:TakeDamage(v.StompDamage.Value)
								end
							end
						end
					end)
					wait(.2)
					stompDamage:Disconnect()
					monster.RightHand.CanCollide = false
					monster.RightHandCrystals.CanCollide = false
				end)
				animations[v]:GetMarkerReachedSignal("PenetrateGround"):Connect(function()
					monster.RightHand.Dig:Play()
					monster.RightHand.DigDebris.Enabled = true
				end)
				animations[v]:GetMarkerReachedSignal("SpawnStone"):Connect(function()
					facePlayer(1, aggroTorso)
					boulder = game.ReplicatedStorage.BossAssets:FindFirstChild("Crystal Colossus"):FindFirstChild("Crystal Boulder"):Clone()
					local main = boulder.Main
					local hitbox = boulder.Hitbox
					hitbox.Transparency = 1
					for i,v in pairs(boulder:GetChildren()) do
						if v:IsA("BasePart") and v.Name ~= "Main" then
							local weld = Instance.new("WeldConstraint", v)
							weld.Part0 = v
							weld.Part1 = main
						end
					end
					for i,v in pairs(boulder.TrailsBox:GetChildren()) do
						if v.ClassName == "Trail" then
							v.Enabled = false
						end
					end
					main.Middle.Arcs.Enabled = false
					boulder.Parent = game.Workspace
					boulder:SetPrimaryPartCFrame(monster.RightHand.CFrame * CFrame.new(0, 3, 0))
					local weld = Instance.new("WeldConstraint", main)
					weld.Part0 = main
					weld.Part1 = monster.RightHand
					wait(.5)
					monster.RightHand.DigDebris.Enabled = false
				end)
				--animations[v]:GetMarkerReachedSignal("LockOn"):Connect(function()
				--	if aggroTorso ~= nil then
				--		aimTarget = aggroTorso.Position
				--	end
				--end)
				animations[v]:GetMarkerReachedSignal("ThrowStone"):Connect(function()
					if boulder ~= nil then
						monster.RightHand.Throw:Play()
						local main = boulder.Main
						local hitbox = boulder.Hitbox
						for i,v in pairs(boulder.TrailsBox:GetChildren()) do
							if v.ClassName == "Trail" then
								v.Enabled = true
							end
						end
						main.Middle.Arcs.Enabled = true
						if aggroTorso ~= nil then
							aimTarget = aggroTorso
							main:FindFirstChildWhichIsA("WeldConstraint"):Destroy()
							main.Anchored = true
							game:GetService("Debris"):AddItem(boulder, 5)
							local rayOrigin = main.Position
							--print(aimTarget.Name, aimTarget.Parent.Name)
							local rayGoal = aimTarget.CFrame.Position
							local rayDirection = (rayGoal - rayOrigin).Unit * 500
							local targetPosition = rayDirection
							local filters = {boulder, aimTarget.Parent, monster}
							local raycastParams = RaycastParams.new()
							raycastParams.FilterDescendantsInstances = filters
							raycastParams.FilterType = Enum.RaycastFilterType.Exclude
							raycastParams.IgnoreWater = true
							raycastParams.RespectCanCollide = true
							local raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
							local function RayToPart(ray)
								local MidPoint = ray.Origin + ray.Direction/2
								local Part = Instance.new("Part")
								Part.CanCollide = false
								Part.CanQuery = false
								Part.Anchored = true
								Part.CFrame = CFrame.lookAt(MidPoint, ray.Origin)
								Part.Size = Vector3.new(1, 1, ray.Direction.Magnitude)
								Part.Parent = workspace
								return Part
							end
							if raycastResult then
								targetPosition = raycastResult.Position
							end
							local ts = game:GetService("TweenService")
							local oppositeLookVect = main.CFrame.LookVector * -1
							local distance = (targetPosition - rayOrigin).Magnitude
							--print(targetPosition, distance)
							local boulderSpeed = 250 -- in studs per sec
							local travelTime = distance / boulderSpeed
							--print(travelTime)
							local tInfo = TweenInfo.new(travelTime, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
							local boulderTween = ts:Create(main, tInfo, {CFrame = CFrame.new(targetPosition, oppositeLookVect)})
							local boulderHitPlayers = {}
							local boulderExploded = false
							local function explodeBoulder()
								--print("EXPLODE")
								if boulderExploded == false then
									boulderExploded = true
									main.Anchored = true
									main.Transparency = 1
									hitbox.Anchored = true
									for i,v in pairs(boulder:GetChildren()) do
										local tCons = v:FindFirstChildWhichIsA("WeldConstraint")
										if tCons then
											tCons:Destroy()
										end
										if v.Name == "Crystals" then
											v.CanCollide = true
										end
									end
									main.HitSFX:Play()
									spawn(function()
										main.Debris.Enabled = true
										main.CrystalDebris.Enabled = true
										main.Middle.Arcs.Enabled = false
										wait(0.5)
										main.Debris.Enabled = false
										main.CrystalDebris.Enabled = false
									end)	
									local explosion = Instance.new("Explosion", boulder)
									explosion.Visible = false
									explosion.DestroyJointRadiusPercent = 0
									explosion.BlastRadius = math.floor(hitbox.Size.X / 2)
									explosion.ExplosionType = Enum.ExplosionType.NoCraters
									explosion.BlastPressure = 150000
									explosion.Position = main.Position
									explosion.Hit:Connect(function(hit)
										local potChar = hit.Parent
										local player = game.Players:GetPlayerFromCharacter(potChar)
										if player then
											if table.find(boulderHitPlayers, player) == nil then
												table.insert(boulderHitPlayers, player)
												player.Character.Humanoid:TakeDamage(v.Damage.Value)
											end
										end												
									end)
								end
							end
							local boulderHit = nil
							boulderHit = boulder.TrailsBox.Touched:Connect(function(hit)
								if hit.Parent ~= monster then
									boulderHit:Disconnect()
									boulderTween:Pause()
									explodeBoulder()
								end
							end)
							boulderTween:Play()
							boulderTween.Completed:Wait()
							explodeBoulder()
							aimTarget = nil
						end
					end
				end)
			end
		end
	end
	--print(attacksDict)
	local function chooseAttack(attackType)
		local chosenAttack = attacksDict[attackType][math.random(1, #attacksDict[attackType])]
		--print(chosenAttack)
		return chosenAttack
	end
	local function freeze()
		monster.Humanoid.WalkSpeed = 0
	end
	local function unfreeze()
		if bossDying == false then
			monster.Humanoid.WalkSpeed = defaultWalkSpeed
		end
	end
	local function putOnCooldown(attack)
		cooldowns[attack] = true
		spawn(function()
			wait(attacks:FindFirstChild(attack):FindFirstChild("Cooldown").Value)
			cooldowns[attack] = false
		end)
	end
	while mHumanoid.Health > 1 do
		local nTorso, dist = findNearestTorso(mhrp.Position)
		local targetDist = nil
		if nTorso then
			if aggroTorso == nil then -- First time finding a player 
				cinematicAnimation:AdjustSpeed(0.75)
				cinematicAnimation:Play()
				cinematicAnimation.Stopped:Wait()
				-- Check if the music zone contains boss track, check for all people in zone to toggle health bar
				bossActive = true
			end
			if nTorso ~= aggroTorso or aggroTorso.Parent.Humanoid.Health <= 0 then -- Old aggro target dead, or new closer enemy to take aggro on
				aggroTorso = nTorso
				targetDist = dist
			end
		end
		if aggroTorso ~= nil then
			local dCheck = (aggroTorso.Position - mhrp.Position).Magnitude
			--print(dCheck, "DCHECK")
			if dCheck > pursueDist then -- Not in range of enemy (or dead already)
				aggroTorso = nil
				-- Reset boss
				mHumanoid:MoveTo(homePosition)
				if not regenWaiting then
					regenWaiting = true
					spawn(function()
						wait(30)
						if aggroTorso == nil then -- Still nobody in sight? Reset health, destroy minions (if any)
							mHumanoid.Health = monster.Config.MaxHealth.Value
							game.ServerStorage.BossBindableEvents.DespawnBoss:Fire(monster.Name, 0)
						end
						regenWaiting = false
					end)
				end
			else -- In range of enemy
				targetDist = dCheck
				mHumanoid.AutoRotate = true
				chasingPlayer = true
				mHumanoid:MoveTo(aggroTorso.Position)
			end
		else
			mHumanoid.AutoRotate = false
			mHumanoid:MoveTo(mhrp.Position)
			chasingPlayer = false			
		end
		local attack = nil
		--print(targetDist)
		if targetDist then
			if targetDist <= meleeRange then
				attack = chooseAttack("Melee")
			else
				if math.random() <= tickAttackChance then
					attack = chooseAttack("Ranged")
				end			
			end
		end
		if attack and cooldowns[attack.Name] == false then
			local attackName = attack.Name
			if attackName == "Slam" then
				facePlayer(.6, nTorso)
				animations[attack]:Play()
				animations[attack].Stopped:Wait()
				animations[attack]:Stop()
				putOnCooldown(attackName)
				wait(.5)
			elseif attackName == "Roar" then
				freeze()
				animations[attack]:Play()
				animations[attack].Stopped:Wait()
				animations[attack]:Stop()
				putOnCooldown(attackName)
				wait(.5)			
				unfreeze()
			elseif attackName == "Throw" then
				freeze()
				animations[attack]:Play()
				animations[attack].Stopped:Wait()
				animations[attack]:Stop()
				putOnCooldown(attackName)
				wait(.25)			
				unfreeze()				
			end
		end
		wait(waitTime)
	end
end

local dropsFolder = monster.Config:WaitForChild("Drops")
local xpGainModule = require(game.ReplicatedStorage.Modules:WaitForChild("ServerSideGain"))
function giveDrops(player)
	local playerLuckMult = game.ReplicatedStorage.RemoteFunctions.GetLuckMultiplier:InvokeClient(player)
	wait()
	for i,v in pairs(dropsFolder:GetChildren()) do
		local roll = (math.random(1, 10000) / 100)
		local rawChance = v.DropChance.Value
		local refinedChance = v.DropChance.Value * playerLuckMult
		--print(drops.Parent.XPGained.Value)
		local amount = 1
		if(v:FindFirstChild("Amount")) then
			amount = v:FindFirstChild("Amount").Value
		end
		if roll <= refinedChance then
			player.Datastore:FindFirstChild(v.Name).Value = player.Datastore:FindFirstChild(v.Name).Value + amount
			game.ReplicatedStorage.ItemPickup:FireClient(player, amount, v.Name, 0, "None")
		end
	end
	xpGainModule.xpGain(player, dropsFolder.Parent.XPGained.Value, "Slayer")	
	for i, quest in pairs(questsInvolvingMonster) do
		if player.Datastore:FindFirstChild(quest.Name).Value >= 1 then
			local qVal = player.Datastore:FindFirstChild(quest.Name .. monsterName)
			if qVal then
				qVal.Value += 1
			end
		end
	end
	player.Datastore:FindFirstChild("Kills").Value += 1	
	local badge = monster.Config:FindFirstChild("Badge") 
	if badge then
		local badgeId = badge.Value
		game.Workspace.BadgeGiver.GiveBadge:Fire(player, badgeId, Color3.fromRGB(137, 34, 255))
	end
	return true
end

function killBoss()
	if bossDying == false then
		bossDying = true
		-- death animation, despawn boss, get everyone in arena, disable healthbar
		for i,v in pairs(monster.Humanoid:GetPlayingAnimationTracks()) do
			v:Stop()
		end
		monster.Humanoid.WalkSpeed = 0
		local deathAnim = monster.Humanoid:LoadAnimation(monster.Misc.Death)
		deathAnim:Play()
		deathAnim:GetMarkerReachedSignal("Crash"):Connect(function()
			monster.HumanoidRootPart.Death:Play()
			spawn(function()
				monster.UpperTorso.Debris.Enabled = true
				monster:BreakJoints()
				wait(0.5)
				alive = false
				monster.Humanoid.Health = 0
				monster.UpperTorso.Debris.Enabled = false
			end)
			wait(1)
			--print("DROPS")
			local dropped = {}
			for i,v in pairs(monster.Tags:GetChildren()) do --Distribute drops
				local player = v.Value
				if player and table.find(dropped, player) == nil then
					spawn(function()
						local success = giveDrops(player)
						if success then
							table.insert(dropped, player)
						end
					end)
				end
			end
		end)
		--deathAnim.Stopped:Wait()
		wait(5)
		game.ServerStorage.BossBindableEvents.DespawnBoss:Fire(monster.Name, monster.Config.RespawnTime.Value)
	end
end

monster.Humanoid.HealthChanged:Connect(function()
	local health = monster.Humanoid.Health
	if health <= 1 and alive then
		monster.Humanoid.Health = 1
		killBoss()
	end
end)

function setup() --Preparation
	monster.Humanoid.MaxHealth = monster.Config.MaxHealth.Value
	monster.Humanoid.Health = monster.Config.MaxHealth.Value
	monster.Humanoid.WalkSpeed = monster.Config.WalkSpeed.Value
end

function zoneControl() -- Set up and manage boss zone
	local zoneContainer = game.Workspace:FindFirstChild("BossZones"):FindFirstChild(monster.Name)
	if zoneContainer then
		local Zone = require(game:GetService("ReplicatedStorage").Zone)
		local zone = Zone.new(zoneContainer)
		zone:setAccuracy("Medium")
		local playersArray = zone:getPlayers()
		print(playersArray)
		zone.playerEntered:Connect(function(player)
			print(("%s entered the zone!"):format(player.Name))
		end)
		zone.playerExited:Connect(function(player)
			print(("%s exited the zone!"):format(player.Name))
		end)
	else
		warn("NO BOSS ZONE FOUND! " .. monster.Name)
	end
end

if aiV then
	if aiV == "Colossus" then
		setup()
		colossus()
	end
end