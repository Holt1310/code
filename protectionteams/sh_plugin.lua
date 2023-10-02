
local PLUGIN = PLUGIN

PLUGIN.name = "Protection Teams"
PLUGIN.author = "wowm0d"
PLUGIN.description = "Adds joinable squads to the tab menu."
PLUGIN.schema = "HL2 RP"


PLUGIN.teams = {}

PLUGIN.spawns = PLUGIN.spawns or {}

PLUGIN.invites = PLUGIN.invites or {}

spawnedTexts = spawnedTexts or {}

-----------------------------------------------------------------------
-----------------------------------------------------------------------
----------------------------------------------------------------------- SAVING, UPDATING, AND GETTING TEAMS
-----------------------------------------------------------------------
-----------------------------------------------------------------------

if SERVER then
util.AddNetworkString("RequestTeamData")
util.AddNetworkString("UpdateTeamData")

net.Receive("RequestTeamData", function(len, ply)
    net.Start("UpdateTeamData")
    net.WriteTable(PLUGIN.teams)
    net.Send(ply)
    end)
end

if CLIENT then
    net.Receive("UpdateTeamData", function()
        PLUGIN.teams = net.ReadTable()
    end)
end
local function saveTeamsToFile()
    timer.Simple(5, function() 
        local teamsDataToSave = {}

        for squadName, team in pairs(PLUGIN.teams) do
            local savedTeam = {
                members = {},
                owner = IsValid(team.owner) and team.owner:SteamID() or nil,
                spawnPos = team.spawnPos,
                model = team.model 
            }

            for _, member in pairs(team.members) do
                if IsValid(member) then
                    table.insert(savedTeam.members, member:SteamID())
                end
            end

            teamsDataToSave[squadName] = savedTeam -- The key change is here, using the squad name as the index
        end

        local teamsData = util.TableToJSON(teamsDataToSave)  
        file.Write("teams.txt", teamsData)  
        print("Teams data has been saved to teams.txt")  
    end)
end
local function loadTeamsFromFile()
    if file.Exists("teams.txt", "DATA") then
        local teamsData = file.Read("teams.txt", "DATA")
        local tempTeams = util.JSONToTable(teamsData) or {}

        PLUGIN.teams = {}

        for squadName, savedTeam in pairs(tempTeams) do 
            local loadedTeam = {
                members = {},
                ownerSteamID = savedTeam.owner, -- Save owner's SteamID instead of the player object
                spawnPos = savedTeam.spawnPos,
                model = savedTeam.model
            }

            for _, steamID in pairs(savedTeam.members) do
                local ply = player.GetBySteamID(steamID)
                if IsValid(ply) then
                    table.insert(loadedTeam.members, ply)
                end
            end

            PLUGIN.teams[squadName] = loadedTeam
        end

        net.Start("UpdateTeamData")
        net.WriteTable(PLUGIN.teams)
        net.Broadcast()
        print("Teams data has been loaded from teams.txt")
    else
        print("No teams data file found!")
    end
end

function PLUGIN:PlayerLoadout(client)
    local character = client:GetCharacter()

    if (self.spawns and !table.IsEmpty(self.spawns) and character) then
        local squad = client.curTeam

        -- Check for squad spawn first
        if squad and PLUGIN.teams[squad] and PLUGIN.teams[squad].spawnPos then
			client:SetPos(PLUGIN.teams[squad].spawnPos)
            
			return
		end
		
        local class = character:GetClass()
        local points
        local className = "default"

        for k, v in ipairs(ix.faction.indices) do
            if (k == client:Team()) then
                points = self.spawns[v.uniqueID] or {}

                break
            end
        end

        if (points) then
            for _, v in ipairs(ix.class.list) do
                if (class == v.squadName) then
                    className = v.uniqueID

                    break
                end
            end

            points = points[className] or points["default"]

            if (points and !table.IsEmpty(points)) then
                local position = table.Random(points)

                client:SetPos(position)
            end
        end
    end
end

function PLUGIN:LoadData()
	self.spawns = self:GetData() or {}
end

function PLUGIN:SaveSpawns()
	self:SetData(self.spawns)
end

ix.command.Add("SpawnAdd", {
	description = "@cmdSpawnAdd",
	privilege = "Manage Spawn Points",
	adminOnly = true,
	arguments = {
		ix.type.string,
		bit.bor(ix.type.text, ix.type.optional)
	},
	OnRun = function(self, client, name, class)
		local info = ix.faction.indices[name:lower()]
		local info2
		local faction

		if (!info) then
			for _, v in ipairs(ix.faction.indices) do
				if (ix.util.StringMatches(v.uniqueID, name) or ix.util.StringMatches(L(v.name, client), name)) then
					faction = v.uniqueID
					info = v

					break
				end
			end
		end

		if (info) then
			if (class and class != "") then
				local found = false

				for _, v in ipairs(ix.class.list) do
					if (v.faction == info.squadName and
						(v.uniqueID:lower() == class:lower() or ix.util.StringMatches(L(v.name, client), class))) then
						class = v.uniqueID
						info2 = v
						found = true

						break
					end
				end

				if (!found) then
					return "@invalidClass"
				end
			else
				class = "default"
			end

			PLUGIN.spawns[faction] = PLUGIN.spawns[faction] or {}
			PLUGIN.spawns[faction][class] = PLUGIN.spawns[faction][class] or {}

			table.insert(PLUGIN.spawns[faction][class], client:GetPos())

			PLUGIN:SaveSpawns()

			name = L(info.name, client)

			if (info2) then
				name = name .. " (" .. L(info2.name, client) .. ")"
			end

			return "@spawnAdded", name
		else
			return "@invalidFaction"
		end
	end
})

ix.command.Add("SpawnRemove", {
	description = "@cmdSpawnRemove",
	privilege = "Manage Spawn Points",
	adminOnly = true,
	arguments = bit.bor(ix.type.number, ix.type.optional),
	OnRun = function(self, client, radius)
		radius = radius or 120

		local position = client:GetPos()
		local i = 0

		for _, v in pairs(PLUGIN.spawns) do
			for _, v2 in pairs(v) do
				for k3, v3 in pairs(v2) do
					if (v3:Distance(position) <= radius) then
						v2[k3] = nil
						i = i + 1
					end
				end
			end
		end

		if (i > 0) then
			PLUGIN:SaveSpawns()
		end

		return "@spawnDeleted", i
	end
})

ix.command.Add("PTList", {
    adminOnly = true, -- Only allow admins to use this command
    description = "Lists the contents of the PLUGIN.teams table.",
    OnRun = function(self, client)
        print("---- PLUGIN.teams Contents ----")
        for squadName, teamData in pairs(PLUGIN.teams) do
            print("Squad squadName:", squadName)
            print("Owner:", IsValid(teamData.owner) and teamData.owner:Name() or "None")
            print("Members:")
            for _, member in ipairs(teamData.members) do
                if IsValid(member) then
                    print("-", member:Name())
                end
            end
            print("-----------------------------")
        end
        return "@PTListPrinted" -- This message will be shown to the admin in-game
    end
})

function PLUGIN:GetReceivers()
    local recievers = {}

    for _, client in pairs(player.GetAll()) do
        if (client:IsCombine()) then
            table.insert(recievers, client)
        end
    end

    return recievers
end

ix.util.Include("cl_plugin.lua")
ix.util.Include("cl_hooks.lua")
ix.util.Include("sv_plugin.lua")
ix.util.Include("sv_hooks.lua")


if SERVER then
    util.AddNetworkString("SpawnTextRequest")
    net.Receive("SpawnTextRequest", function(len, ply)
        -- Check if the player is a team leader before proceeding
        if ply.isTeamOwner then
            local text = net.ReadString()
            local ent = ents.Create("squad_objectivemark")
            ent:SetPos(ply:GetEyeTrace().HitPos + Vector(0,0,10))
            ent:SetNWString("Text", text)
            ent:SetNWString("Squad", ply.curTeam) -- Set the squad to the player's current team
            ent:Spawn()
            table.insert(spawnedTexts, ent)
        end
    end)
end

if CLIENT then
    local dimDistance = 1024

    hook.Add("HUDPaint", "DrawFloatingTexts", function()
        local client = LocalPlayer()
        for _, ent in ipairs(ents.FindByClass("squad_objectivemark")) do
            if IsValid(ent) then
                local screenPosition = ent:GetPos():ToScreen()
                local entSquad = ent:GetNWString("Squad", "")

                if screenPosition.visible and client.curTeam == entSquad then
                    local text = ent:GetNWString("Text", "")
                    local distance = client:GetPos():Distance(ent:GetPos())
                    local factor = 1 - math.Clamp(distance / dimDistance, 0, 1)
                    local size = math.max(10, 32 * factor)
                    local alpha = math.max(255 * factor, 80)
                    
                    surface.SetFont("ixGenericFont")
                    surface.SetDrawColor(255, 255, 255, alpha)
                    surface.DrawRect(screenPosition.x - size / 2, screenPosition.y - size / 2, size, size)
                    ix.util.DrawText(text, screenPosition.x, screenPosition.y - size, ColorAlpha(color_white, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, nil, alpha)
                end
            end
        end
    end)
end

-- MENU FOR SQUAD WAYPOINTS
local function GetEntityTextOptions()
    local trace = LocalPlayer():GetEyeTrace()
    local ent = trace.Entity
    local textOptions = {}

    if IsValid(ent) then
        local className = ent:GetClass()

        if className then  -- Ensure className is not nil
            if className == "func_door" then
                textOptions = {"Stack Up", "Check Ammo and Weapons!", "Open and Flash", "Lockpick/Hack", "Blow the Door", "Open and Grenade"}
            elseif className == "some_entity_class_2" then
                textOptions = {"Option A", "Option B"}
            elseif string.find(className, "npc_vjks_reb_", 1, true) == 1 then
                textOptions = {"Focus Fire Here", "Enemy Positions!"}
            end
            -- Add more conditions as needed
        end
    else
        -- Default options if the player isn't looking at anything specific
        textOptions = {"Move Position", "Hold Position", "Attack", "Defend"}
    end

    return textOptions
end

local keyIsDown = false
local keyToBind = KEY_F5
local activeMenu = nil

local function OpenRadialMenu(squadNames)
    -- Check if the menu is already open.
    if IsValid(activeMenu) then
        activeMenu:Close()
        return
    end

    local frame = vgui.Create("DFrame")
    frame:SetSize(800, 800)
    frame:Center()
    frame:MakePopup()
    frame:SetTitle(" ")
    frame:SetDraggable(false)  -- Make the frame non-movable
    frame:ShowCloseButton(false) 
    frame.Paint = function(self, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(50, 50, 50, 0))
    end

    -- Determine angle increment based on the number of squad names
    local angleIncrement = 360 / #squadNames
    local frameRadius = frame:GetWide() / 2 -- Assuming the frame is a square, so Width and Height should be the same.

    -- Create buttons around the circle
    for i, name in ipairs(squadNames) do
        local angle = math.rad(i * angleIncrement - 90) -- Subtract 90 degrees (or pi/2 in radians) to start from the top
        local buttonRadius = 60 -- Half of the button's size (120 / 2)

        local x = frameRadius + math.cos(angle) * (frameRadius - buttonRadius) - buttonRadius
        local y = frameRadius + math.sin(angle) * (frameRadius - buttonRadius) - buttonRadius

        local button = vgui.Create("DButton", frame)
        button:SetSize(120, 120)
        button:SetPos(x, y)
        button:SetText(name)
        button.Paint = function(self, w, h)
            local borderRadius = math.min(w, h) / 2  -- Ensure that it remains a circle even if the width and height change
            local borderColor = Color(255, 255, 255, 0)  -- White border, you can adjust the color
            local buttonColor = Color(50, 50, 50, 150)  -- Your button's main color
        
            -- Draw the button's main circle (filled)
            draw.RoundedBox(borderRadius, 0, 0, w, h, buttonColor)
        
            -- Draw the button's border (you can adjust the border thickness)
            surface.SetDrawColor(borderColor)
            surface.DrawOutlinedRect(0, 0, w, h, 2)  -- The last parameter (2) is the border thickness
        end
        
        button.DoClick = function()
            frame:Close()
            if CLIENT and LocalPlayer().isTeamOwner then -- Only allow team leaders to set waypoints
                net.Start("SpawnTextRequest")
                net.WriteString(name)
                net.SendToServer()
            end
        end
    end

    frame.OnClose = function()
        activeMenu = nil
    end

    activeMenu = frame -- Set the newly created frame as our active menu.
end

if CLIENT then
    hook.Add("Think", "CheckRadialMenuKey", function()
        if input.IsKeyDown(keyToBind) then
            if not keyIsDown and not IsValid(activeMenu) then
                keyIsDown = true
                local textOptions = GetEntityTextOptions()
                OpenRadialMenu(textOptions)
            end
        else
            if IsValid(activeMenu) then
                activeMenu:Close()
            end
        end
    end)
end

concommand.Add("squadradial", function()
    local textOptions = GetEntityTextOptions()
    OpenRadialMenu(textOptions)
end)

ix.command.Add("PTCreate", {
    description = "@cmdPTCreate",
    arguments = bit.bor(ix.type.string, ix.type.optional),  -- Changed from ix.type.number to ix.type.string
    OnRun = function(self, client, squadName)  -- Changed 'index' to 'squadName'
        
        local class = client:GetCharacter():GetClass()
        local allowedClasses = {CLASS_LEADRECON, CLASS_LEADASLT, CLASS_LEADLOG}  -- Replace with actual allowed class IDs

        if not table.HasValue(allowedClasses, class) then
            return "@classNotAllowed"  -- Replace with actual error message or localization key
        end

        if not client:IsCombine() then
            return "@CannotUseTeamCommands"
        end

        if not squadName then
            return client:RequestString("@cmdPTCreate", "@cmdCreatePTDesc", function(text)
                ix.command.Run(client, "PTCreate", {text})
            end, "")
        end

        -- Ensure that the squad name is unique
        for _, team in pairs(PLUGIN.teams) do
            if team.name == squadName then
                return "@squadNameTaken"  -- Replace with actual error message or localization key
            end
        end

        saveTeamsToFile()

        return PLUGIN:CreateTeam(client, squadName)  -- Changed 'index' to 'squadName'
    end
})

if SERVER then
    -- Table to store the invitations
    PLUGIN.invites = PLUGIN.invites or {}

    -- Function to send an invite
    function PLUGIN:InviteToSquad(sender, target)
        if IsValid(sender) and sender.isTeamOwner and IsValid(target) and target:IsPlayer() then
            PLUGIN.invites[target] = sender.curTeam  -- Store the team ID the player is invited to

            -- Optionally send a chat message to both players
            sender:ChatPrint(target:GetName() .. " has been invited to your squad.")
            target:ChatPrint("You have been invited to join " .. sender:GetName() .. "'s squad. Use /ptjoin to accept.")
        end
    end
end

ix.command.Add("PTInvite", {
    description = "Invite a player to your squad",
    arguments = ix.type.player,
    OnRun = function(self, client, target)
        if SERVER then  -- Ensure this is being executed server-side
            PLUGIN:InviteToSquad(client, target)
        end
    end
})

ix.command.Add("PTJoin", {
    description = "@cmdPTJoin",
    arguments = ix.type.string,
    OnRun = function(self, client, squadName)
        if not client:IsCombine() then
            return "@CannotUsePTCommands"
        end

        local isInvited = PLUGIN.invites[client] == squadName
        local isAdmin = client:IsAdmin() -- Or another check depending on how your admin system is set up

        if not isInvited and not isAdmin then
            return "@NotInvitedToSquad"
        end

        -- Remove the player from the invitations list after joining if they were invited
        if isInvited then
            PLUGIN.invites[client] = nil
        end

        saveTeamsToFile()

        return PLUGIN:JoinTeam(client, squadName)
    end
})


ix.command.Add("PTLeave", {
    description = "@cmdPTLeave",
    OnRun = function(self, client)
        if (!client:IsCombine()) then
            return "@CannotUsePTCommands"
        end
        saveTeamsToFile()

        return PLUGIN:LeaveTeam(client)

    end
})

hook.Add("PlayerDisconnected", "ClearPlayerInvites", function(ply)
    if PLUGIN.invites[ply] then
        PLUGIN.invites[ply] = nil
    end
end)


ix.command.Add("PTLead", {
    description = "@cmdPTLead",
    arguments = bit.bor(ix.type.player, ix.type.optional),
    OnRun = function(self, client, target)
        
        local class = client:GetCharacter():GetClass()
        local allowedClasses = {CLASS_LEADRECON, CLASS_LEADASLT, CLASS_LEADLOG}  -- Replace with actual allowed class IDs

        if not table.HasValue(allowedClasses, class) then
            return "@classNotAllowed"  -- Replace with actual error message or localization key
        end

        if not client:IsCombine() then
            return "@CannotUseTeamCommands"
        end

        -- The rest of the existing code
        local squadName = target and target.curTeam or client.curTeam

        if not PLUGIN.teams[squadName] then 
            return "@TargetNoCurrentTeam"
        end

        if not client:IsDispatch() then
            if client.curTeam ~= target.curTeam then 
                return "@TargetNotSameTeam"
            end

            if PLUGIN.teams[squadName]["owner"] then
                if target == client then 
                    return "@TeamAlreadyHasOwner"
                end
                
                if not client.isTeamOwner then 
                    return "@CannotPromoteTeamMembers"
                end
            end
        end

        if target == client or not target then
            if PLUGIN:SetTeamOwner(squadName, target) then
                return "@TeamOwnerAssume"
            end
        end

        if PLUGIN:SetTeamOwner(squadName, target) then
            target.isTeamOwner = true
        end

        saveTeamsToFile()

        return PLUGIN:SetTeamOwner(squadName, target)
    end
})

ix.command.Add("PTKick", {
    description = "@cmdPTKick",
    arguments = ix.type.player,
    OnRun = function(self, client, target)
        if (!client:IsCombine()) then
            return "@CannotUseTeamCommands"
        end

        local squadName = target.curTeam

        if (!PLUGIN.teams[squadName]) then return "@TargetNoCurrentTeam" end

        if (client.curTeam != target.curTeam and !client:IsDispatch()) then return "@TargetNotSameTeam" end

        if (!client.isTeamOwner and !client:IsDispatch()) then return "@CannotKickTeamMembers" end

        PLUGIN:LeaveTeam(target)
        saveTeamsToFile()

        return "@KickedFromTeam", target:GetName()

    end
})

ix.command.Add("PTSetModel", {
    description = "Open a menu to set the player model for the protection team.",
    adminOnly = false,
    OnRun = function(self, client)
        
        if client.isTeamOwner then
            local faction = client:Team()  -- Get the faction of the team owner
            net.Start("OpenModelMenu")
            net.WriteUInt(faction, 32)  -- Send the faction to the client
            net.Send(client)
        else
            return "@notTeamOwner"
        end
    end
})

if SERVER then
    util.AddNetworkString("OpenModelMenu")
    util.AddNetworkString("SetPTModel")

    net.Receive("SetPTModel", function(len, ply)
        if ply.isTeamOwner then
            local model = net.ReadString()
            local teamsquadName = ply.curTeam
            
            if PLUGIN.teams and PLUGIN.teams[teamsquadName] then
                PLUGIN.teams[teamsquadName].model = model
                
                for _, member in pairs(PLUGIN.teams[teamsquadName].members) do
                    if IsValid(member) then
                        local character = member:GetCharacter()

                        if character then
                            character:SetModel(model)
                        end
                    end
                end
            end

            saveTeamsToFile()
        end
    end)
end


if CLIENT then
    net.Receive("OpenModelMenu", function()
        local faction = net.ReadUInt(32)  -- Receive the faction from the server

        local frame = vgui.Create("DFrame")
        frame:SetSize(300, 400)
        frame:Center()
        frame:MakePopup()
        frame:SetTitle("Select Player Model")

        local modelList = vgui.Create("DListView", frame)
        modelList:Dock(FILL)
        modelList:AddColumn("Model")

        -- Different factions can have different available models
        local models = {
            [FACTION_ASLT] = {
                "models/jajoff/sps/jlmbase/empire/shock/recruit.mdl",
                "models/jajoff/sps/jlmbase/empire/501st/recruit.mdl",
                "models/jajoff/sps/jlmbase/empire/shock/driver.mdl",
                "models/jajoff/sps/jlmbase/empire/shock/officer.mdl",
                "models/jajoff/sps/jlmbase/empire/shock/patrol.mdl",
                "models/jajoff/sps/jlmbase/empire/shock/trooper.mdl",
                "models/jajoff/sps/jlmbase/empire/shock/waylandtrooper.mdl",
                "models/jajoff/sps/jlmbase/empire/shock/arc.mdl",
                "models/jajoff/sps/jlmbase/empire/shock/commando.mdl",
                "models/jajoff/sps/jlmbase/empire/501st/arc.mdl",
                "models/jajoff/sps/jlmbase/empire/501st/commando.mdl",
                "models/jajoff/sps/jlmbase/empire/501st/jet.mdl",
                "models/jajoff/sps/jlmbase/empire/501st/officer.mdl",
                "models/jajoff/sps/jlmbase/empire/501st/scorch.mdl",
                "models/jajoff/sps/jlmbase/empire/501st/trooper.mdl",
                "models/jajoff/sps/jlmbase/empire/501st/waylandtrooper.mdl",
                "models/jajoff/sps/jlmbase/empire/characters/tybalt.mdl",
                "models/jajoff/sps/jlmbase/empire/isb/dt02.mdl",
                "models/jajoff/sps/jlmbase/empire/isb/dt01.mdl",
                "models/jajoff/sps/jlmbase/empire/501st/officer_uniform.mdl",
                "models/jajoff/sps/jlmbase/empire/shock/officer_uniform.mdl",
                "models/jajoff/sps/jlmbase/empire/stormtrooper/veteran.mdl",
                "models/jajoff/sps/jlmbase/empire/characters/clone_axel.mdl",
                "models/jajoff/sps/jlmbase/empire/characters/fyodor.mdl",
                "models/jajoff/sps/jlmbase/empire/characters/kas.mdl",
                "models/jajoff/sps/jlmbase/empire/characters/lang.mdl",
                "models/jajoff/sps/jlmbase/empire/characters/swt.mdl",
                "models/jajoff/sps/jlmbase/empire/characters/mexar.mdl"
            },
            [FACTION_LOG] = {
                "models/jajoff/sps/jlmbase/empire/nova/commando.mdl",
                "models/jajoff/sps/jlmbase/empire/nova/officer.mdl",
                "models/jajoff/sps/jlmbase/empire/nova/officer_uniform.mdl",
                "models/jajoff/sps/jlmbase/empire/nova/patrol.mdl",
                "models/jajoff/sps/jlmbase/empire/nova/pilot.mdl",
                "models/jajoff/sps/jlmbase/empire/nova/recruit.mdl",
                "models/jajoff/sps/jlmbase/empire/nova/trooper.mdl",
                "models/jajoff/sps/jlmbase/empire/nova/waylandtrooper.mdl",
                "models/jajoff/sps/jlmbase/empire/logistics/engineer.mdl",
                "models/jajoff/sps/jlmbase/empire/logistics/med/arc.mdl",
                "models/jajoff/sps/jlmbase/empire/logistics/med/commando.mdl",
                "models/jajoff/sps/jlmbase/empire/logistics/med/medic.mdl",
                "models/jajoff/sps/jlmbase/empire/logistics/med/recruit.mdl",
                "models/jajoff/sps/jlmbase/empire/logistics/med/trooper.mdl",
                "models/jajoff/sps/jlmbase/empire/logistics/med/waylandtrooper.mdl",
                "models/jajoff/sps/jlmbase/empire/logistics/med/officer.mdl",
                "models/jajoff/sps/jlmbase/empire/logistics/med/pilot.mdl",
                "models/jajoff/sps/jlmbase/empire/logistics/med/pilot_elite.mdl",
                "models/jajoff/sps/jlmbase/empire/royal/pilot.mdl",
                "models/jajoff/sps/jlmbase/empire/shock/pilot.mdl",
                "models/jajoff/sps/jlmbase/empire/501st/pilot_elite.mdl",
                "models/jajoff/sps/jlmbase/empire/501st/pilot.mdl",
                "models/jajoff/sps/jlmbase/empire/shock/pilot_elite.mdl",
                "models/jajoff/sps/jlmbase/empire/characters/clone_fay.mdl",
                "models/jajoff/sps/jlmbase/empire/characters/kep.mdl",
                "models/jajoff/sps/jlmbase/empire/inquisition/commando.mdl"
            },
            [FACTION_RECON] = {
                "models/jajoff/sps/jlmbase/empire/501st/elite.mdl",
                "models/jajoff/sps/jlmbase/empire/inquisition/trooper.mdl",
                "models/jajoff/sps/jlmbase/empire/characters/bonnie.mdl",
                "models/jajoff/sps/jlmbase/empire/logistics/arc.mdl",
                "models/jajoff/sps/jlmbase/empire/logistics/commando.mdl",
                "models/jajoff/sps/jlmbase/empire/logistics/officer.mdl",
                "models/jajoff/sps/jlmbase/empire/logistics/driver.mdl",
                "models/jajoff/sps/jlmbase/empire/logistics/recruit.mdl",
                "models/jajoff/sps/jlmbase/empire/logistics/pilot_elite.mdl",
                "models/jajoff/sps/jlmbase/empire/logistics/pilot.mdl",
                "models/jajoff/sps/jlmbase/empire/logistics/trooper.mdl",
                "models/jajoff/sps/jlmbase/empire/logistics/waylandtrooper.mdl",
                "models/jajoff/sps/jlmbase/empire/scout/recruit.mdl",
                "models/jajoff/sps/jlmbase/empire/scout/shadow.mdl",
                "models/jajoff/sps/jlmbase/empire/scout/shadowarc.mdl",
                "models/jajoff/sps/jlmbase/empire/scout/trooper.mdl",
                "models/jajoff/sps/jlmbase/empire/stormtrooper/shadowtrooper.mdl",
                "models/jajoff/sps/jlmbase/empire/scout/commando.mdl",
                "models/jajoff/sps/jlmbase/empire/scout/elite.mdl",
                "models/jajoff/sps/jlmbase/empire/scout/officer.mdl",
                "models/jajoff/sps/jlmbase/empire/scout/officer_uniform.mdl",
                "models/jajoff/sps/jlmbase/empire/penal/trooper.mdl",
                "models/jajoff/sps/jlmbase/empire/characters/ejp.mdl",
                "models/jajoff/sps/jlmbase/empire/characters/ghostnaah.mdl", 
                "models/jajoff/sps/jlmbase/empire/characters/kris.mdl",
                "models/jajoff/sps/jlmbase/empire/characters/ryn.mdl"
            },
            -- Add more factions and their respective models here
        }

        -- Populate the list with models based on the leader’s faction
        for _, model in pairs(models[faction] or {}) do
            modelList:AddLine(model)
        end

        modelList.OnRowSelected = function(lst, squadName, pnl)
            local selectedModel = pnl:GetColumnText(1)

            net.Start("SetPTModel")
            net.WriteString(selectedModel)
            net.SendToServer()

            frame:Close()
        end
    end)
end

ix.command.Add("PTMemberModel", {
    description = "Open a menu to set a player model for a specific team member.",
    adminOnly = false,
    arguments = ix.type.player, 
    OnRun = function(self, client, target)
        if client.isTeamOwner then
            local faction = client:Team()
            net.Start("OpenMemberModelMenu")
            net.WriteUInt(faction, 32)
            net.WriteEntity(target)
            net.Send(client)
        else
            return "@notTeamOwner"
        end
    end
})


if SERVER then
    util.AddNetworkString("OpenMemberModelMenu")
    util.AddNetworkString("SetMemberModel")

    net.Receive("SetMemberModel", function(len, client)
        if client.isTeamOwner then
            local member = net.ReadEntity()
            local model = net.ReadString()
            
            if IsValid(member) and member:GetCharacter() then
                member:GetCharacter():SetModel(model)
            end
        end
    end)
end


if CLIENT then
    net.Receive("OpenMemberModelMenu", function()
        local faction = net.ReadUInt(32)
        local member = net.ReadEntity()

        local frame = vgui.Create("DFrame")
        frame:SetSize(300, 400)
        frame:Center()
        frame:MakePopup()
        frame:SetTitle("Select Player Model for " .. member:Name())

        local modelList = vgui.Create("DListView", frame)
        modelList:Dock(FILL)
        modelList:AddColumn("Model")

        local models = {
            [FACTION_ASLT] = {
                "models/player/police.mdl",
                "models/player/police_fem.mdl"
                -- Add more metrocop models here
            },
            [FACTION_ADMIN] = {
                "models/player/combine_super_soldier.mdl",
                "models/player/combine_soldier.mdl"
                -- Add more overwatch models here
            },
        }

        for _, model in pairs(models[faction] or {}) do
            modelList:AddLine(model)
        end

        modelList.OnRowSelected = function(lst, index, pnl)
            local selectedModel = pnl:GetColumnText(1)

            net.Start("SetMemberModel")
            net.WriteEntity(member)
            net.WriteString(selectedModel)
            net.SendToServer()

            frame:Close()
        end
    end)
end

ix.command.Add("PTSetSpawn", {
    description = "Set the spawn point for your squad.",
    adminOnly = false,
    OnRun = function(self, client)
        if client.isTeamOwner then
            local squadName = client.curTeam

            if PLUGIN.teams and PLUGIN.teams[squadName] then
                local spawnPos = client:GetPos()  -- Get the player’s current position
                PLUGIN.teams[squadName].spawnPos = spawnPos  -- Set the spawn position in the team’s data
                
                net.Start("UpdateTeamSpawn")
                net.WriteString(squadName)
                net.WriteVector(spawnPos)
                net.Broadcast()  -- Send to all clients to update their local data

                client:Notify("Spawn point set for squad " .. squadName .. ".")
            else
                return "@noSquadFound"
            end
        else
            return "@notTeamOwner"
        end
    end
})

if SERVER then
    util.AddNetworkString("UpdateTeamSpawn")
end

if CLIENT then
    net.Receive("UpdateTeamSpawn", function()
        local squadName = net.ReadString()
        local spawnPos = net.ReadVector()

        if PLUGIN.teams and PLUGIN.teams[squadName] then
            PLUGIN.teams[squadName].spawnPos = spawnPos  -- Update the spawn position in the local team’s data
            LocalPlayer():Notify("New spawn point set for squad " .. squadName .. ".")
        end
    end)
end

ix.command.Add("PTClearSpawn", {
    description = "Clear the spawn point for your squad.",
    adminOnly = false,
    OnRun = function(self, client)
        if client.isTeamOwner then
            local squadName = client.curTeam

            if PLUGIN.teams and PLUGIN.teams[squadName] then
                PLUGIN.teams[squadName].spawnPos = nil  -- Clear the spawn position in the team’s data
                
                net.Start("ClearTeamSpawn")
                net.WriteString(squadName)
                net.Broadcast()  -- Send to all clients to update their local data

                client:Notify("Spawn point cleared for squad " .. squadName .. ".")
            else
                return "@noSquadFound"
            end
        else
            return "@notTeamOwner"
        end
    end
})

if SERVER then
    util.AddNetworkString("ClearTeamSpawn")
end

if CLIENT then
    net.Receive("ClearTeamSpawn", function()
        local squadName = net.ReadString()

        if PLUGIN.teams and PLUGIN.teams[squadName] then
            PLUGIN.teams[squadName].spawnPos = nil  -- Clear the spawn position in the local team’s data
            LocalPlayer():Notify("Spawn point cleared for squad " .. squadName .. ".")
        end
    end)
end

ix.command.Add("PTForceAssign", {
    description = "Force assigns a player to a specific squad.",
    arguments = {ix.type.string, ix.type.string},
    adminOnly = true,
    OnRun = function(self, client, playerName, squadName)
        local target = ix.util.FindPlayer(playerName)

        if IsValid(target) then
            if PLUGIN.teams and PLUGIN.teams[squadName] then
                
                net.Start("ForceAssignSquad")
                net.WriteEntity(target)
                net.WriteString(squadName)
                net.Broadcast()
                
                -- Using the PLUGIN:JoinTeam function to assign the player to the squad
                return PLUGIN:JoinTeam(target, squadName)  
            else
                return "@squadNotFound", squadName
            end
        else
            return "@playerNotFound", playerName
        end
    end
})

if SERVER then
    util.AddNetworkString("ForceAssignSquad")
end

if CLIENT then
    net.Receive("ForceAssignSquad", function()
        local player = net.ReadEntity()
        local squad = net.ReadString()

        if IsValid(player) and PLUGIN.teams and PLUGIN.teams[squad] then
            player.curTeam = squad  -- Update the player's current team in local data
            print(player:GetName() .. " has been force assigned to squad " .. squad)  -- For debugging, replace with an actual notification or UI update
        end
    end)
end

ix.command.Add("PTForceDelete", {
    description = "Force deletes a specific squad.",
    arguments = ix.type.string,
    adminOnly = true,
    OnRun = function(self, client, squadName)
        if PLUGIN.teams and PLUGIN.teams[squadName] then
            PLUGIN.teams[squadName] = nil  -- Remove the squad from the teams list
            
            saveTeamsToFile()  -- You may need to implement this function to save changes to a file if necessary
            
            net.Start("ForceDeleteSquad")
            net.WriteString(squadName)
            net.Broadcast()
            
            return "@squadForceDeleted", squadName
        else
            return "@squadNotFound", squadName
        end
    end
})

if SERVER then
    util.AddNetworkString("ForceDeleteSquad")
end

if CLIENT then
    net.Receive("ForceDeleteSquad", function()
        local squad = net.ReadString()

        if PLUGIN.teams and PLUGIN.teams[squad] then
            PLUGIN.teams[squad] = nil  -- Update the local data
            print("Squad " .. squad .. " has been force deleted")  -- For debugging, replace with an actual notification or UI update
        end
    end)
end

-- Creating a console command to trigger the saving function
concommand.Add("save_teams", function(ply, cmd, args)
    if IsValid(ply) and not ply:IsAdmin() then
        print("You do not have permission to use this command!")
        return
    end

    saveTeamsToFile()
end)

-- Creating a console command to trigger the loading function
concommand.Add("load_teams", function(ply, cmd, args)
    if IsValid(ply) and not ply:IsAdmin() then
        print("You do not have permission to use this command!")
        return
    end

    loadTeamsFromFile()
end)
    -- Function to check squad membership
local function checkSquadMembership(ply)
    if IsValid(ply) and not ply.curTeam then
        for squadName, squad in pairs(PLUGIN.teams) do
            local belongsToSquad = false
            
            for _, member in pairs(squad.members) do
                if IsValid(member) and member == ply then
                    belongsToSquad = true
                    break
                end
            end

            if belongsToSquad then
                ply.curTeam = squadName
                print(ply:GetName() .. " has been assigned to squad " .. squadName)
                break
            end
        end
    end
end

ix.command.Add("CheckSquad", {
    description = "Use to fix your squad not loading",
    adminOnly = false,
    OnRun = function(self, client)
        checkSquadMembership(client)

    end
})

hook.Add("PlayerInitialSpawn", "LoadTeamsOnJoin", function(ply)
        timer.Simple(5, function()
        loadTeamsFromFile(ply)
        end)
end)

hook.Add("PlayerInitialSpawn", "SendTeamDataToClient", function(ply)
    net.Start("UpdateTeamData")
    net.WriteTable(PLUGIN.teams)
    net.Send(ply)
end)


hook.Add("PlayerCanHearPlayersVoice", "SquadVoiceCommunication", function(listener, talker)
    if not IsValid(talker) or not IsValid(listener) then
        return false
    end

    -- Parameters
    local maxHearingDistance = 500  -- Maximum distance to hear players outside of the squad

    if talker.curTeam and listener.curTeam and PLUGIN.teams[talker.curTeam] and PLUGIN.teams[listener.curTeam] then
        if talker.curTeam == listener.curTeam then
            return true  -- Always hear members of the same squad
        else
            -- Check if the distance between talker and listener is within the limit for different squads
            local distance = talker:GetPos():Distance(listener:GetPos())
            return distance <= maxHearingDistance
        end
    else
        -- If either the talker or listener (or both) is not in a squad, check the distance between them
        local distance = talker:GetPos():Distance(listener:GetPos())
        return distance <= maxHearingDistance
    end
end)


