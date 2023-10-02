local PLUGIN = PLUGIN

-- Update the Team Menu when a team is created, reassigned, deleted, or when a player leaves or joins a team, or a new team owner is set.
function PLUGIN:OnCreateTeam(client, squadName)
    self:UpdateTeamMenu()
end

function PLUGIN:OnReassignTeam(oldName, newName)
    self:UpdateTeamMenu()
end

function PLUGIN:OnDeleteTeam(squadName)
    self:UpdateTeamMenu()
end

function PLUGIN:OnLeaveTeam(client, squadName)
    self:UpdateTeamMenu()
end

function PLUGIN:OnJoinTeam(client, squadName)
    self:UpdateTeamMenu()
end

function PLUGIN:OnSetTeamOwner(client, squadName)
    self:UpdateTeamMenu()
end

-- Populate character info with team status.
function PLUGIN:PopulateCharacterInfo(client, character, container)
    if LocalPlayer():IsCombine() and client.curTeam then
        local curTeam = container:AddRowAfter("name", "curTeam")
        curTeam:SetText(L("TeamStatus", client.curTeam, client.isTeamOwner and L("TeamOwnerStatus") or L("TeamMemberStatus")))
        curTeam:SetBackgroundColor(client.isTeamOwner and Color(50,150,100) or Color(50,100,150))
    end
end

-- Synchronize teams data between server and clients.
net.Receive("ixPTSync", function()
    local bTeams = net.ReadBool()

    if not bTeams then
        PLUGIN.teams = {}

        for _, client in pairs(player.GetAll()) do
            client.curTeam = nil
            client.isTeamOwner = nil
        end

        return
    end

    local teams = net.ReadTable()
    PLUGIN.teams = teams

    for squadName, teamTbl in pairs(teams) do
        for _, client in pairs(teamTbl["members"]) do
            client.curTeam = squadName
        end

        local owner = teamTbl["owner"]

        if IsValid(owner) then
            owner.isTeamOwner = true
        end
    end
end)

-- Handle network messages for creating, deleting, leaving, joining, changing owner, and reassigning teams.
net.Receive("ixPTCreate", function()
    local squadName = net.ReadString()
    local client = net.ReadEntity()

    PLUGIN:CreateTeam(client, squadName)
end)

net.Receive("ixPTDelete", function()
    local squadName = net.ReadString()

    PLUGIN:DeleteTeam(squadName)
end)

net.Receive("ixPTLeave", function()
    local squadName = net.ReadString()
    local client = net.ReadEntity()

    PLUGIN:LeaveTeam(client, squadName)
end)

net.Receive("ixPTJoin", function()
    local squadName = net.ReadString()
    local client = net.ReadEntity()

    PLUGIN:JoinTeam(client, squadName)
end)

net.Receive("ixPTOwner", function()
    local squadName = net.ReadString()
    local client = net.ReadEntity()

    PLUGIN:SetTeamOwner(squadName, client)
end)

net.Receive("ixPTReassign", function()
    local oldName = net.ReadString()
    local newName = net.ReadString()

    PLUGIN:ReassignTeam(oldName, newName)
end)
