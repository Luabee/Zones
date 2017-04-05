AddCSLuaFile()

local ZONE = {}
ZONE.__index = ZONE

function ZONE:GetId()
	return self.data.id
end

function ZONE:GetPlayers()
	return {} -- TODO: Implement me.
end

function ZONE:GetClass()
	return self.data.class
end

function ZONE:GetName()
	return self.Name or self.data.class
end

zones.ZONE_META = ZONE
