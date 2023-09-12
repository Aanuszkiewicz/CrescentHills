--[[
	A module script that controls the dialogue and other popup bubble interactions.
--]]

local module = {}
local rs = game:GetService("ReplicatedStorage")
local hashLib = require(rs.Modules.HashLib)
local secretKey = "" --Omitted for privacy.
local clientHash = hashLib.sha256(secretKey)
local remEv = rs.RemoteEvents

function module.npcSystem(scriptObject)
	local center = scriptObject.Parent
	local config = scriptObject.Parent.Config
	local dialogueTable = {}
	for i,v in pairs(config.DialogueOptions:GetChildren()) do
		table.insert(dialogueTable, v)
	end
	local buttonFunctionTable = {}
	for i,v in pairs(config.Buttons:GetChildren()) do
		table.insert(buttonFunctionTable, v)
	end	
	table.sort(buttonFunctionTable, function(a, b)
		return (tonumber(a.Name) < tonumber(b.Name))
	end)
	local portrait = config.Portrait.Value
	local npcName = config.NPCName.Value
	local magnitudePart = scriptObject.Parent
	local isDialogue = config.Functionality.isDialogue.Value
	local specificFunction = config.Functionality.SpecificFunction.Value
	local interactButton = magnitudePart:WaitForChild("BillboardGui"):WaitForChild("Frame"):WaitForChild("ImageButton")
	local hoverTextLabel = interactButton.Parent.HoverText
	local player = game.Players.LocalPlayer
	local pUI = game.Players.LocalPlayer.PlayerGui
	local datastore = game.Players.LocalPlayer:WaitForChild("Datastore")
	local textScrollSounds = {}
	local scrollSoundP = config:WaitForChild("TextScrollSoundPitch").Value
	local tutProg = datastore:WaitForChild("TutorialProgress")
	
	if scrollSoundP == "Normal" then
		textScrollSounds = {pUI:WaitForChild("SFX"):WaitForChild("Text")}
	elseif scrollSoundP == "Low" then
		textScrollSounds = {pUI:WaitForChild("SFX"):WaitForChild("TextLow")}
	elseif scrollSoundP == "High" then
		textScrollSounds = {pUI:WaitForChild("SFX"):WaitForChild("TextHigh")}
	elseif scrollSoundP == "Mixed" then
		textScrollSounds = {pUI:WaitForChild("SFX"):WaitForChild("Text"), pUI:WaitForChild("SFX"):WaitForChild("TextLow"), pUI:WaitForChild("SFX"):WaitForChild("TextHigh")}
	end
	game:GetService("ContentProvider"):PreloadAsync(textScrollSounds)
	
	local function toggleEssentialVisibility(bool)
		magnitudePart.BillboardGui.Enabled = bool
		hoverTextLabel.Visible = bool
		pUI.Backpack.Enabled = bool
		pUI.Backpack:FindFirstChild("DisabledValue").Value = (not bool)
		pUI.HUD.XP.Visible = bool
		pUI.HUD.Frame.HotbarFrame.Visible = bool
		pUI.Help.Enabled = bool
		--pUI.Quests.Enabled = bool
	end
	
	local dialogueUI = pUI:WaitForChild("DialogueV2")
	local dFrame = dialogueUI.Frame
	local speechFrame = dFrame.SpeechFrame
	local speechFrameBorder = dFrame.SpeechFrameBorder
	local moreTextIndicator = speechFrame.DialogueLabel.MoreTextIndicator
	local openFramePos = dFrame.SpeechFrame.Position
	local openBorderBos = dFrame.SpeechFrameBorder.Position
	local prepFramePos = UDim2.new(openFramePos.X.Scale, openFramePos.X.Offset, openFramePos.Y.Scale + 0.1, openFramePos.Y.Offset)
	local prepBorderPos = UDim2.new(openBorderBos.X.Scale, openBorderBos.X.Offset, openBorderBos.Y.Scale + 0.1, openBorderBos.Y.Offset)
	local closedFramePos = UDim2.new(openFramePos.X.Scale, openFramePos.X.Offset, openFramePos.Y.Scale - 1, openFramePos.Y.Offset)
	local closedBorderPos = UDim2.new(openBorderBos.X.Scale, openBorderBos.X.Offset, openBorderBos.Y.Scale - 1, openBorderBos.Y.Offset)
	local defaultNPCNameSize = speechFrame.Portrait.NPCName.Size
	interactButton.MouseButton1Click:Connect(function()	
		local char = player.Character or player.CharacterAdded:Wait()
		local hum = nil
		if char then
			hum = char:WaitForChild("Humanoid")
		end
		if hum and hum.Health > 0 then
			if isDialogue == true then
				toggleEssentialVisibility(false)
				local blipMTI = false
				moreTextIndicator.ImageTransparency = 1
				moreTextIndicator.Visible = false
				local buttonsFrame = dFrame.ButtonsFrame
				local npcNameLabel = speechFrame.Portrait.NPCName
				dialogueUI.Enabled = true
				speechFrame.DialogueLabel.Text = ""
				for i,v in pairs(buttonsFrame:GetChildren()) do
					if v.ClassName == "ImageButton" then
						v:Destroy()
					end
				end
				local createdButtons = {}
				for i,v in pairs(buttonFunctionTable) do
					local bClone = dFrame.OptionClone:Clone()
					bClone.Name = "Option" .. v.Name
					bClone.Option.Text = v.Value
					bClone.Parent = buttonsFrame
					bClone.Action.Value = v.Value
					for n,b in pairs(v:GetChildren()) do
						local cVal = b:Clone()
						cVal.Parent = bClone
					end
					bClone.Visible = false
					table.insert(createdButtons, bClone)
				end
				speechFrame.Position = closedFramePos
				speechFrameBorder.Position = closedBorderPos
				speechFrame:TweenPosition(prepFramePos, "Out", "Bounce", .5)
				speechFrameBorder:TweenPosition(prepBorderPos, "Out", "Bounce", .5)
				speechFrame.Portrait.Image = portrait
				if portrait ~= "" then
					speechFrame.Portrait.BackgroundTransparency = 0.5
					npcNameLabel.AnchorPoint = Vector2.new(0, 1)
					npcNameLabel.Size = defaultNPCNameSize
					npcNameLabel.Position = UDim2.new(0, 0, 1, 0)
				else
					speechFrame.Portrait.BackgroundTransparency = 1		
					npcNameLabel.AnchorPoint = Vector2.new(0, 0.5)
					npcNameLabel.Size = UDim2.new(defaultNPCNameSize.X.Scale, defaultNPCNameSize.X.Offset, defaultNPCNameSize.Y.Scale * 2, defaultNPCNameSize.Y.Offset)
					npcNameLabel.Position = UDim2.new(0, 0, 0.5, 0)
				end
				npcNameLabel.Text = npcName
				dFrame.MagnitudeWatcher.Value = scriptObject.Parent
				wait(.5)
				local function scrollText(message)
					if dialogueUI.AbsoluteSize.X < 1900 or dialogueUI.AbsoluteSize.Y < 1040 then
						speechFrame.DialogueLabel.TextScaled = true
					else
						speechFrame.DialogueLabel.TextScaled = false
					end
					message = string.gsub(message, "{PLAYERNAME}", player.Datastore:FindFirstChild("RPName").Value)
					speechFrame.DialogueLabel.Text = ""
					local sLength = #message
					local clicked = false
					local connection = nil
					connection = game.Players.LocalPlayer:GetMouse().Button1Down:Connect(function()
						clicked = true
						connection:Disconnect()
						connection = nil
					end)
					local function playRandomTextSound()
						local choice = math.random(1, #textScrollSounds)
						textScrollSounds[choice]:Play()
					end
					for i = 1, math.ceil(sLength/2) do
						if clicked == false then
							speechFrame.DialogueLabel.Text = string.sub(message, 1, i*2)
							playRandomTextSound()
							wait()
						else
							speechFrame.DialogueLabel.Text = message
							playRandomTextSound()
							wait()
							break
						end
					end
					if connection ~= nil then
						connection:Disconnect()
						connection = nil
					end
				end
				local lastDialogueChosen = nil
				local function pickDialogue()
					local pickedDialogue = nil
					local potentialOptions = {}
					for i,v in pairs(dialogueTable) do
						if v.Name == "GreetingDialogue" then
							local greeted = datastore:FindFirstChild(npcName .. "NPCGreeted")
							if greeted then
								if greeted.Value == false then
									remEv.GreetNPC:FireServer(hashLib.base64_encode(npcName))
									pickedDialogue = v
									return pickedDialogue
								end
							else
								warn(npcName .. "NPCGreeted not in Datastore.")
							end
						elseif v.Name == "ForcedDialogue" then
							local reqVar = v:FindFirstChild("Requirements"):FindFirstChild("DatastoreVariable").Value
							if reqVar ~= "" then
								if datastore:FindFirstChild(reqVar) then
									if datastore:FindFirstChild(reqVar).Value == v:FindFirstChild("Requirements"):FindFirstChild("DatastoreValue").Value then
										pickedDialogue = v
										remEv.QuestProg:FireServer(hashLib.base64_encode(reqVar), hashLib.base64_encode(tostring(v:FindFirstChild("Requirements"):FindFirstChild("NewDatastoreValue").Value)), clientHash)
										return pickedDialogue
									end
								end
							end
						elseif v.Name == "UnlockableDialogue" then
							local reqVar = v:FindFirstChild("Requirements"):FindFirstChild("DatastoreVariable").Value
							if reqVar ~= "" then
								if datastore:FindFirstChild(reqVar) then
									if datastore:FindFirstChild(reqVar).Value >= v:FindFirstChild("Requirements"):FindFirstChild("DatastoreValue").Value then
										local maxVal = v:FindFirstChild("Requirements"):FindFirstChild("DatastoreValueMax")
										if maxVal then
											local max = maxVal.Value
											if datastore:FindFirstChild(reqVar).Value <= max then
												table.insert(potentialOptions, v)
											end
										else
											table.insert(potentialOptions, v)
										end
									end
								elseif player.Donationstore:FindFirstChild(reqVar) then
									if player.Donationstore:FindFirstChild(reqVar).Value >= v:FindFirstChild("Requirements"):FindFirstChild("DatastoreValue").Value then
										table.insert(potentialOptions, v)
									end
								else
									warn(reqVar .. " not found in datastore!")
								end
							end
						elseif v.Name == "Dialogue" then
							table.insert(potentialOptions, v)
						end
					end
					if lastDialogueChosen ~= nil and #potentialOptions > 1 then
						for i,v in pairs(potentialOptions) do
							if v == lastDialogueChosen then
								table.remove(potentialOptions, i)
								break
							end
						end
					end
					local count = 0
					for i,v in pairs(potentialOptions) do
						count = count + v:FindFirstChild("Chance").Value
					end
					count = count * 10000
					local choice = (math.random(1, count)) / 10000
					count = 0
					for i,v in pairs(potentialOptions) do
						count = count + v:FindFirstChild("Chance").Value
						if choice <= count then
							pickedDialogue = v
							lastDialogueChosen = pickedDialogue
							return pickedDialogue
						end
					end
				end
				local function blipMTIToggle() --Blip MoreTextIndicator
					moreTextIndicator.Visible = true
					while blipMTI == true do
						if moreTextIndicator.ImageTransparency == 1 then
							moreTextIndicator.ImageTransparency = 0.5
						else
							moreTextIndicator.ImageTransparency = 1
						end
						local waitTimer = 0
						repeat wait(.05) 
							waitTimer = waitTimer + .05
						until waitTimer >= .5 or blipMTI == false
					end
				end
				local function playDialogue(dialogue, firstMessage)
					if firstMessage == nil then
						firstMessage = false
					end
					local linesTable = dialogue:FindFirstChild("Lines"):GetChildren()
					table.sort(linesTable, function(a, b)
						return tonumber(a.Name) < tonumber(b.Name)
					end) -- Sort linesTable
					for i,v in pairs(createdButtons) do
						v.Visible = false
					end
					for i = 1, #linesTable do
						local v = linesTable[i]
						scrollText(v.Value)
						-- Check for special functions at the end of dialogue line --
						for j,b in pairs(v:GetChildren()) do
							if b.Name == "GiveItem" then
								game.ReplicatedStorage.DialogueItServer:FireServer(b)
							elseif b.Name == "TakeItem" then
								for n,m in pairs(b:GetChildren()) do
									game.ReplicatedStorage.ItemTakeLocalSide:FireServer((-1 * m.Value), m.Name, 0)
								end							
							elseif b.Name == "EnchPlayer" then
								local ench = require(game.ReplicatedStorage:WaitForChild("Modules"):WaitForChild("WeaponEnchantments"))
								local enchName = b:FindFirstChild("EnchName").Value
								if enchName == "Explode" then
									ench.explodeHumanoid(hum, nil, b.Dmg.Value, b.Radius.Value, game.ReplicatedStorage.Sounds:FindFirstChild("SurtrBladeExplosion"))
									dialogueUI.Enabled = false
									return true
								end
							elseif b.Name == "TeleportPlace" then
								local id = b.PlaceID.Value
								b.TeleportSound:Play()
								dialogueUI.Enabled = false
								local whiteout = b.WhiteoutUI
								whiteout.Enabled = true
								local whiteFrame = whiteout.Frame
								local tweenWhite = game:GetService("TweenService"):Create(whiteFrame, TweenInfo.new(10, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {BackgroundTransparency = 0})
								tweenWhite:Play()
								local teleportService = game:GetService("TeleportService")
								teleportService:Teleport(id, player)
							end
						end
						----
						if i < #linesTable then
							local clicked = false
							local clickConnection = nil
							clickConnection = player:GetMouse().Button1Down:Connect(function()
								clicked = true
							end)
							local blipMTICR = coroutine.wrap(blipMTIToggle)
							blipMTI = true
							blipMTICR()
							repeat wait() until clicked == true or dialogueUI.Enabled == false
							blipMTI = false
							moreTextIndicator.Visible = false
							if clickConnection ~= nil then
								clickConnection:Disconnect()
								clickConnection = nil
							end
						end
					end
					if firstMessage == false then
						for i,v in pairs(createdButtons) do
							v.Visible = true
						end
					end
					if dialogueUI.Enabled == true then --Check to see if the dialogue has successfully been completed
						return true
					else
						return false
					end
				end
				playDialogue(pickDialogue(), true)
				-- Tutorial check
				if tutProg.Value == 7 and npcName == "Anthony" then
					game.ReplicatedStorage.RemoteEvents.ProgressTutorial:FireServer(8)
				end
				-- Tween UI up, prepare buttons for functionality
				speechFrame:TweenPosition(openFramePos, "Out", "Bounce", .5)
				speechFrameBorder:TweenPosition(openBorderBos, "Out", "Bounce", .5)
				wait(.5)
				local pickDebounce = false
				local connectionArray = {}
				local function retrieveCurrentQuest()
					local currentQuest = nil
					local qFolder = config:FindFirstChild("Quests")
					local sortedQuests = {}
					if qFolder then
						for y,x in pairs(qFolder:GetChildren()) do
							table.insert(sortedQuests, x)
						end
						table.sort(sortedQuests, function(a, b)
							return (a:FindFirstChild("QuestOrder").Value < b:FindFirstChild("QuestOrder").Value)
						end)
						--print(sortedQuests)
						for y,z in pairs(sortedQuests) do
							if player.Datastore:FindFirstChild(z.Name).Value < 100 then
								return z
							end
						end
					end
					return nil
				end
				local function checkRequirements(rsQuestFolder)
					local meets = true
					local qConfig = rsQuestFolder:FindFirstChild("QuestConfig")
					if rsQuestFolder:FindFirstChild("QuestConfig"):FindFirstChild("QuestType").Value == "Fetch" then
						local fetchItems = rsQuestFolder:FindFirstChild("QuestConfig"):FindFirstChild("FetchItems")
						for i,v in pairs(fetchItems:GetChildren()) do
							if player.Datastore:FindFirstChild(v.Name).Value < v.Value then
								return false
							end
						end
					end
					if rsQuestFolder:FindFirstChild("QuestConfig"):FindFirstChild("QuestType").Value == "Talk" then
						local talkNPCS = rsQuestFolder:FindFirstChild("QuestConfig"):FindFirstChild("TalkNPCValue")
						for i,v in pairs(talkNPCS:GetChildren()) do
							if player.Datastore:FindFirstChild(v.Name).Value ~= v.Value then
								return false
							end
						end
					end
					if rsQuestFolder:FindFirstChild("QuestConfig"):FindFirstChild("QuestType").Value == "Collect" then
						local count = qConfig:FindFirstChild("CollectAmount").Value
						local tag = qConfig:FindFirstChild("CollectValueTag").Value
						for i = 1, count do
							local relTag = tag .. i
							if player.Datastore:FindFirstChild(relTag).Value == false then
								return false
							end
						end
					end
					if rsQuestFolder:FindFirstChild("QuestConfig"):FindFirstChild("QuestType").Value == "Slay" then
						for i, monsterVal in pairs(qConfig:FindFirstChild("SlayMonsters"):GetChildren()) do
							local monsterName = monsterVal.Name
							local monsterAmount = monsterVal.Value
							local slayedAmount = player.Datastore:FindFirstChild(rsQuestFolder.Name .. monsterName).Value
							if slayedAmount < monsterAmount then
								return false
							end
						end
					end
					if rsQuestFolder:FindFirstChild("QuestConfig"):FindFirstChild("QuestType").Value == "Puzzle" then
						local puzzleVal = qConfig:FindFirstChild("PuzzleValues"):FindFirstChildWhichIsA("BoolValue")
						local puzzleDSVal = player.Datastore:FindFirstChild(puzzleVal.Name).Value
						if puzzleDSVal ~= puzzleVal.Value then
							return false
						end
					end
					return meets
				end
				--print(createdButtons)
				for i,v in pairs(createdButtons) do
					v.Visible = true
					local action = v.Action.Value
					if action == "Quest" then
						if retrieveCurrentQuest() == nil then
							v.CanChoose.Value = false
						end
					end
					v.MouseButton1Down:Connect(function()
						if pickDebounce == false then
							pickDebounce = true
							if action == "" then
								v.CanChoose.Value = false
							elseif action == "Quest" then
								local currentQuest = retrieveCurrentQuest()
								if currentQuest ~= nil then
									local currentTier = player.Datastore:FindFirstChild(currentQuest.Name).Value
									if currentTier == 0 then
										for n,b in pairs(currentQuest:GetChildren()) do
											if b.ClassName == "Folder" and b.Name == "Dialogue" then
												if b:FindFirstChild("TriggerValue") then
													if b:FindFirstChild("TriggerValue").Value == currentTier then
														if playDialogue(b) == true then
															remEv.QuestProg:FireServer(hashLib.base64_encode(currentQuest.Name), hashLib.base64_encode(tostring(currentTier + 1)), clientHash)
														end
													end
												end
											end
										end
									elseif currentTier >= 1 then
										local meetsRequirements = checkRequirements(game.ReplicatedStorage.Quests:FindFirstChild(currentQuest.Name))
										if meetsRequirements then
											for n,b in pairs(currentQuest:GetChildren()) do
												if b.ClassName == "Folder" and b.Name == "Dialogue" then
													if b:FindFirstChild("TriggerValue") then
														if b:FindFirstChild("TriggerValue").Value == 100 then
															if playDialogue(b) == true then
																remEv.QuestProg:FireServer(hashLib.base64_encode(currentQuest.Name), hashLib.base64_encode(tostring(100)), clientHash)
															end
														end
													end
												end
											end		
										else
											for n,b in pairs(currentQuest:GetChildren()) do
												if b.ClassName == "Folder" and b.Name == "Dialogue" then
													if b:FindFirstChild("TriggerValue") then
														if b:FindFirstChild("TriggerValue").Value == currentTier then
															playDialogue(b)
														end
													end
												end
											end										
										end
									end
								end
							elseif action == "Exit" then
								dialogueUI.Enabled = false
								toggleEssentialVisibility(true)
							elseif action == "Sell" then
								dialogueUI.Enabled = false
								local sRestr = v:FindFirstChild("SellRestriction")
								if sRestr then
									pUI:FindFirstChild("ShopMenu"):FindFirstChild("SellRestriction"):FindFirstChild("BoostClass").Value = sRestr:FindFirstChildWhichIsA("NumberValue").Name
									pUI:FindFirstChild("ShopMenu"):FindFirstChild("SellRestriction"):FindFirstChild("Multiplier").Value = sRestr:FindFirstChildWhichIsA("NumberValue").Value
								end
								pUI:FindFirstChild("ShopMenu"):FindFirstChild("Enabler").Value = true
							elseif action == "Shop" then
								dialogueUI.Enabled = false
								local shopName = v:FindFirstChild("ShopName")
								if shopName then
									pUI.BuyMenu.StoreName.Value = ""
									pUI.BuyMenu.StoreName.Value = shopName.Value
								else
									warn("Shop name not found.")
								end
								if tutProg.Value == 8 and npcName == "Anthony" then
									game.ReplicatedStorage.RemoteEvents.ProgressTutorial:FireServer(9)
								end
							elseif action == "Upgrade Tools" then
								dialogueUI.Enabled = false
								game.Players.LocalPlayer.PlayerGui.SpecialUIs.Blacksmith.Enabled = true
								game.Players.LocalPlayer.PlayerGui.SpecialUIs.Blacksmith.Open.Value = true								
							elseif action == "Chat" then		
								playDialogue(pickDialogue())
							else
								if pUI.SpecialUIs:FindFirstChild(action) then
									local sUI = pUI.SpecialUIs:FindFirstChild(action)
									sUI.Enabled = true
									sUI.Open.Value = true	
									dialogueUI.Enabled = false
								else
									warn("Function not found.")
								end
							end
							pickDebounce = false
						end
					end)
				end
				-- Specific cases
				if specificFunction == "MinerCherryBombs" then
					game.ReplicatedStorage.MinerCherryBombs:FireServer()
				end
			else
				local dialogueUI = pUI:WaitForChild("DialogueV2")
				local dFrame = dialogueUI.Frame
				local dMagnitudeWatcher = dFrame.MagnitudeWatcher
				local function essentials()
					toggleEssentialVisibility(false)
					dMagnitudeWatcher.Value = scriptObject.Parent
				end
				if specificFunction ~= "Minecart" then
					essentials()
				end
				if specificFunction == "Jukebox" then
					game.Players.LocalPlayer.PlayerGui.SpecialUIs.Jukebox.Enabled = true
					game.Players.LocalPlayer.PlayerGui.SpecialUIs.Jukebox.Open.Value = true
				end	
				if specificFunction == "Workbench" then
					game.Players.LocalPlayer.PlayerGui.SpecialUIs.Workbench.Enabled = true
					game.Players.LocalPlayer.PlayerGui.SpecialUIs.Workbench.Open.Value = true			
				end
				if specificFunction == "Kitchen" then
					game.Players.LocalPlayer.PlayerGui.SpecialUIs.Kitchen.Enabled = true
					game.Players.LocalPlayer.PlayerGui.SpecialUIs.Kitchen.Open.Value = true			
				end
				if specificFunction == "Mill" then
					game.Players.LocalPlayer.PlayerGui.SpecialUIs.Mill.Enabled = true
					game.Players.LocalPlayer.PlayerGui.SpecialUIs.Mill.Open.Value = true			
				end
				if specificFunction == "Upgrade Tools" then
					game.Players.LocalPlayer.PlayerGui.SpecialUIs.Blacksmith.Enabled = true
					game.Players.LocalPlayer.PlayerGui.SpecialUIs.Blacksmith.Open.Value = true			
				end
				if specificFunction == "CoopCollection" then
					game.Players.LocalPlayer.PlayerGui.SpecialUIs.CoopCollection.Enabled = true
					game.Players.LocalPlayer.PlayerGui.SpecialUIs.CoopCollection.Open.Value = true			
				end
				if specificFunction == "ShedCarpentersTable" then
					game.Players.LocalPlayer.PlayerGui.SpecialUIs.ShedCarpentersTable.Enabled = true
					game.Players.LocalPlayer.PlayerGui.SpecialUIs.ShedCarpentersTable.Open.Value = true			
				end
				if specificFunction == "ShedGenerator" then
					game.Players.LocalPlayer.PlayerGui.ShedUIs.ShedGenerator.Enabled = true
					game.Players.LocalPlayer.PlayerGui.ShedUIs.ShedGenerator.Open.Value = true			
				end
				if specificFunction == "BarnCollection" then
					game.Players.LocalPlayer.PlayerGui.SpecialUIs.BarnCollection.Enabled = true
					game.Players.LocalPlayer.PlayerGui.SpecialUIs.BarnCollection.Open.Value = true	
				end
				if specificFunction == "MoonAltar"then
					local moonAltar = game.Players.LocalPlayer.PlayerScripts.Puzzles.MoonAltar.OfferShard:Fire()
					player.PlayerGui.RestoreEssentials.Toggle.Value = true
				end
				if specificFunction == "Sleep" then
					local playerGui = scriptObject.Parent.Parent.Parent.Parent.Parent
					local function sleep()
						local blackout = playerGui.Blackout
						local tweenInfo = TweenInfo.new(1)
						blackout.Enabled = true
						blackout.Frame.BackgroundTransparency = 1
						scriptObject.Parent.Parent.Parent.Parent.Parent.Frozen.Value = true
						game:GetService("TweenService"):Create(blackout.Frame, tweenInfo, {BackgroundTransparency=0}):Play()
						wait(1)
						blackout.Snore:Play()
						local centerPos = center.Position
						local centerPos64 = {hashLib.base64_encode(tostring(centerPos.X)), hashLib.base64_encode(tostring(centerPos.Y)), hashLib.base64_encode(tostring(centerPos.Z))}
						game.ReplicatedStorage.RemoteEvents.Sleep:FireServer(centerPos64, clientHash)
						wait(3)
						game:GetService("TweenService"):Create(blackout.Frame, tweenInfo, {BackgroundTransparency=1}):Play()
						wait(1)
						blackout.Enabled = false
						playerGui.Frozen.Value = false
						if tutProg.Value == 15 then
							game.ReplicatedStorage.RemoteEvents.ProgressTutorial:FireServer(16)
						end
					end
					sleep()
					scriptObject.Parent.Parent.Parent.Parent.Parent.RestoreEssentials.Toggle.Value = true
				end		
				if specificFunction == "Minecart" then
					if game.Players.LocalPlayer.Datastore:FindFirstChild("MinesTier").Value > 0 then
						essentials()
						game.Players.LocalPlayer.PlayerGui.SpecialUIs.Minecart.Enabled = true
						game.Players.LocalPlayer.PlayerGui.SpecialUIs.Minecart.Open.Value = true		
					else
						game.Players.LocalPlayer.PlayerGui.HUD.NewMessage.Toggle.Value = "You need to build the mines to unlock the minecart!"		
						scriptObject.Parent.Parent.Parent.Parent.Parent.RestoreEssentials.Toggle.Value = true
					end		
				end
				if specificFunction == "Sewer" then
					if game.Players.LocalPlayer.Datastore:FindFirstChild("Sewer Key").Value > 0 then
						-- Teleport player
						game.Players.LocalPlayer.PlayerGui.Teleporter.Toggle.Value = "SewerEntrance"
					else
						game.Players.LocalPlayer.PlayerGui.HUD.NewMessage.Toggle.Value = "The sewer grate is locked!"		
						scriptObject.Parent.Parent.Parent.Parent.Parent.RestoreEssentials.Toggle.Value = true
					end		
				end
				if specificFunction == "Wheel" then
					local camera = workspace.CurrentCamera
					camera.CameraType = Enum.CameraType.Scriptable
					local cameras = game.Workspace.StaticStreaming.Cameras
					camera.CFrame =  CFrame.new(cameras.WheelStart.Position, cameras.WheelDirection.Position)
					wait()
					camera:Interpolate(
						cameras.WheelEnd.CFrame,
						cameras.WheelDirection.CFrame,
						1.5
					)
					local wheelUI = game.Players.LocalPlayer.PlayerGui.Wheel
					wheelUI.SFX.WheelStartSFX:Play()
					wait(1.5)
					wheelUI.Enabled = true
				end
				if specificFunction == "ATM" then
					local ui = game.Players.LocalPlayer.PlayerGui.GoldShop
					ui.Enabled = true
				end
				if specificFunction == "TipJar" then
					local ui = game.Players.LocalPlayer.PlayerGui.DonateShop
					ui.Enabled = true
				end
				if specificFunction == "CarpentersTable" then
					game.Players.LocalPlayer.PlayerGui.SpecialUIs.CarpentersTable.Enabled = true
					game.Players.LocalPlayer.PlayerGui.SpecialUIs.CarpentersTable.Open.Value = true			
				end
				if game.Players.LocalPlayer.PlayerGui.SpecialUIs:FindFirstChild(specificFunction) ~= nil then
					game.Players.LocalPlayer.PlayerGui.SpecialUIs:FindFirstChild(specificFunction).Enabled = true
					if game.Players.LocalPlayer.PlayerGui.SpecialUIs:FindFirstChild(specificFunction):FindFirstChild("Open") then
						game.Players.LocalPlayer.PlayerGui.SpecialUIs:FindFirstChild(specificFunction):FindFirstChild("Open").Value = true
					end
				end
			end		
		end
	end)

	interactButton.MouseEnter:Connect(function()
		hoverTextLabel.Visible = true
		game.Players.LocalPlayer.PlayerGui.Hover:Play()
	end)

	interactButton.MouseLeave:Connect(function()
		hoverTextLabel.Visible = false
	end)	
end

return module