--This is an example usage of the zones system.
AddCSLuaFile("zones.lua")
include("zones.lua")

zones.RegisterClass("Arena Zone",Color(255,0,0))

--Use this to set default properties. Only called on server.
hook.Add("OnZoneCreated","Arena Zone",function(zone,class,zoneID)
	if class == "Arena Zone" then
		
		zone.DmgMul = 1
		
	end
end)

-- Use this hook to let a player change a zone after making it or with the edit tool.
-- class is zone.class, zone is the zone's full table, DPanel is a panel to parent your things to, zoneID is the zone's ID, DFrame is the whole frame.
-- Return your preferred width and height for the panel and the frame will size to it.
hook.Add("ShowZoneOptions","Arena Zone",function(zone,class,DPanel,zoneID,DFrame) 
	if class == "Arena Zone" then
		local w,h = 500, 400
		
		local mulbl = Label("Damage Multiplier:")
		mulbl:SetParent(DPanel)
		mulbl:SetPos(5,5)
		mulbl:SetTextColor(color_black)
		mulbl:SizeToContents()
		
		local mul = vgui.Create("DNumberWang",DPanel) --parent to the panel.
		mul:SetPos(5,mulbl:GetTall()+10)
		mul:SetValue(zone.DmgMul)
		mul:SetDecimals(1)
		mul:SetMinMax(0,10)
		function mul:OnValueChanged(new)
			net.Start("arena_zone")
				net.WriteFloat(zoneID)
				net.WriteFloat(new)
			net.SendToServer()
		end
		
		
		
		return w, h -- Specify the width and height for the DPanel container. The frame will resize accordingly.
		
	end
end)

if SERVER then
	util.AddNetworkString("arena_zone")
	net.Receive("arena_zone",function(len,ply)
		local id, new = net.ReadFloat(), net.ReadFloat()
		if not ply:IsAdmin() then return end
		
		zones.List[id].DmgMul = new
		zones.Sync()
		
	end)
end

hook.Add("ScalePlayerDamage","Arena Zone",function(ply, hitgroup, dmginfo)
	local zone = ply:GetCurrentZone() 
	if zone then
		if zone.class == "Arena Zone" then
			dmginfo:ScaleDamage(zone.DmgMul)
			
		end
	end
end)
