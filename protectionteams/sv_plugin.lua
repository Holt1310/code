
local PLUGIN = PLUGIN

util.AddNetworkString("ixPTSync")
util.AddNetworkString("ixPTCreate")
util.AddNetworkString("ixPTDelete")
util.AddNetworkString("ixPTJoin")
util.AddNetworkString("ixPTLeave")
util.AddNetworkString("ixPTOwner")
util.AddNetworkString("ixPTReassign")

function PLUGIN:CreateTeam(client, squadName, bNetworked)
    if IsValid(client) and client.curTeam then
        return "@AlreadyHasTeam"
    end

    if self.teams[squadName] then
        return "@TeamAlreadyExists", squadName
    end

    self.teams[squadName] = {
        owner = client,
        members = {client},
        name = squadName
    }

    if IsValid(client) then
        client.curTeam = squadName
        client.isTeamOwner = true
    end

    if not bNetworked then
        net.Start("ixPTCreate")
        net.WriteString(squadName)
        net.WriteEntity(client)
        net.Send(self:GetReceivers())
    end

    hook.Run("OnCreateTeam", client, squadName)

    return "@TeamCreated", squadName
end

function PLUGIN:ReassignTeam(oldName, newName, bNetworked)
    if self.teams[newName] then
        return "@TeamAlreadyExists", newName
    end

    local curTeam = self.teams[oldName]

    self:DeleteTeam(oldName, true)

    self:CreateTeam(curTeam.owner, newName, true)
    self.teams[newName].members = curTeam.members

    for _, client in pairs(curTeam.members) do
        client.curTeam = newName
    end

    if not bNetworked then
        net.Start("ixPTReassign")
        net.WriteString(oldName)
        net.WriteString(newName)
        net.Send(self:GetReceivers())
    end

    hook.Run("OnReassignTeam", oldName, newName)

    return "@TeamReassigned", oldName, newName
end

function PLUGIN:SetTeamOwner(squadName, client, bNetworked)
    local curOwner = self.teams[squadName].owner

    if IsValid(curOwner) then
        curOwner.isTeamOwner = nil
    end

    self.teams[squadName].owner = client

    if IsValid(client) then
        client.isTeamOwner = true
    end

    if not bNetworked then
        net.Start("ixPTOwner")
        net.WriteString(squadName)
        net.WriteEntity(client)
        net.Send(self:GetReceivers())
    end

    hook.Run("OnSetTeamOwner", client, squadName)

    if IsValid(client) then
        return "@TeamOwnerSet", client:GetName()
    end
end

function PLUGIN:DeleteTeam(squadName, bNetworked)
    self.teams[squadName] = nil

    for _, client in pairs(self:GetReceivers()) do
        if client.curTeam == squadName then
            client.curTeam = nil

            if client.isTeamOwner then
                client.isTeamOwner = nil
            end
        end
    end

    if not bNetworked then
        net.Start("ixPTDelete")
        net.WriteString(squadName)
        net.Send(self:GetReceivers())
    end

    hook.Run("OnDeleteTeam", squadName)
end

function PLUGIN:JoinTeam(client, squadName, bNetworked)
    if client.curTeam then
        return "@TeamMustLeave"
    end

    if not self.teams[squadName] then
        return "@TeamNonExistent", squadName
    end

    table.insert(self.teams[squadName].members, client)
    client.curTeam = squadName

    if not bNetworked then
        net.Start("ixPTJoin")
        net.WriteString(squadName)
        net.WriteEntity(client)
        net.Send(self:GetReceivers())
    end

    hook.Run("OnJoinTeam", client, squadName)
    net.Start("UpdateTeamData")
    net.WriteTable(PLUGIN.teams)
    net.Broadcast()
    
    return "@JoinedTeam", squadName
end

function PLUGIN:LeaveTeam(client, bNetworked)
    if not client.curTeam then
        return "@NoCurrentTeam"
    end

    local squadName = client.curTeam
    local curTeam = self.teams[squadName]

    if curTeam then
        table.RemoveByValue(self.teams[squadName].members, client)
        client.curTeam = nil

        if not bNetworked then
            net.Start("ixPTLeave")
            net.WriteString(squadName)
            net.WriteEntity(client)
            net.Send(self:GetReceivers())
        end

        if client.isTeamOwner then
            self:SetTeamOwner(squadName, nil)
        end

        hook.Run("OnLeaveTeam", client, squadName)

        return "@LeftTeam", squadName
    end
end