local PLUGIN = PLUGIN

function PLUGIN:UpdateTeamMenu()
    if IsValid(ix.gui.teams) and IsValid(ix.gui.menu) then
        local subpanel = nil
        local tabs = {}
        hook.Run("CreateMenuButtons", tabs)

        for k, v in pairs(ix.gui.menu.subpanels) do
            if v.subpanelName == "tabProtectionTeam" then
                subpanel = v
                break
            end
        end

        if ix.gui.teams:IsVisible() and ix.gui.menu:GetActiveTab() == "tabProtectionTeam" then
            ix.gui.teams:Remove()
            tabs["tabProtectionTeam"](ix.gui.menu:GetActiveSubpanel())
        elseif subpanel then
            ix.gui.teams:Remove()
            tabs["tabProtectionTeam"](subpanel)
        end
    end
end

function PLUGIN:CreateTeam(client, squadName)
    self.teams[squadName] = {
        owner = client,
        members = {client},
        name = squadName  -- Storing the squad name
    }

    client.curTeam = squadName
    client.isTeamOwner = true

    hook.Run("OnCreateTeam", client, squadName)
end

function PLUGIN:ReassignTeam(oldName, newName)
    local curTeam = self.teams[oldName]

    self:DeleteTeam(oldName)

    self:CreateTeam(curTeam["owner"], newName)
    self.teams[newName]["members"] = curTeam["members"]

    for _, client in pairs(curTeam["members"]) do
        client.curTeam = newName
    end

    hook.Run("OnReassignTeam", oldName, newName)
end

function PLUGIN:DeleteTeam(squadName)
    self.teams[squadName] = nil

    for _, client in pairs(self:GetReceivers()) do
        if client.curTeam == squadName then
            client.curTeam = nil

            if client.isTeamOwner then
                client.isTeamOwner = nil
            end
        end
    end

    hook.Run("OnDeleteTeam", squadName)
end

function PLUGIN:LeaveTeam(client, squadName)
    if not self.teams or not self.teams[squadName] then
        print("self.teams or self.teams[squadName] is nil")
        return
    end
    
    table.RemoveByValue(self.teams[squadName]["members"], client)
    
    if not client then
        print("client is nil")
        return
    end
    
    client.curTeam = nil

    -- If you need to update the player model when they leave the team, add here
    -- e.g. client:SetModel(defaultModel)

    hook.Run("OnLeaveTeam", client, squadName)
end

function PLUGIN:JoinTeam(client, squadName)
    if not self.teams then
        print("self.teams is nil")
        return
    end

    if not self.teams[squadName] then
        print("self.teams[squadName] is nil")
        return
    end

    table.insert(self.teams[squadName]["members"], client)

    if not client then
        print("client is nil")
        return
    end
    
    client.curTeam = squadName

    -- The existing UpdatePlayerModel function can be used as-is

    hook.Run("OnJoinTeam", client, squadName)
end

function PLUGIN:SetTeamOwner(squadName, client)
    local curOwner = self.teams[squadName]["owner"]

    if IsValid(curOwner) then
        curOwner.isTeamOwner = nil
    end

    self.teams[squadName]["owner"] = client

    if IsValid(client) then
        client.isTeamOwner = true
    end

    hook.Run("OnSetTeamOwner", client, squadName)
end
