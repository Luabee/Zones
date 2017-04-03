-- This is an example usage of the zones system.
-- Lots of formal documentation is at the bottom of this file.

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



--[[ 
	--Example structure of a zone.
	zones.List[1] = { -- 1 is the zone ID. Automatically assigned.
		
		-- points, height, bounds, and class are reserved.
		points = { 	--List of areas in 3D space which define the zone.
			{		--each area is a list of points. Areas should intersect with one another but they don't have to.
				Vector(),
				Vector(),
				Vector(),
			},
			{ 
				Vector(),
				Vector(),
				Vector(),
			},
		},
		height = {200,100},	 -- How tall each area of the zone is. Each entry corresponds to an area listed above.
		bounds = { 			 --List of the min/max points in each area. Used to speed up point-in-zone testing. These are calculated when the zone is created/changed.
			{
				mins=Vector(),
				maxs=Vector(),
			},
			{
				mins=Vector(),
				maxs=Vector(),
			},
		},
		class = "GMaps Area", -- Zones with different classes are created and treated separately. Use zones.RegisterClass to create a new one.
		
		-- Zones can have any other values saved to them. If you save a player, make sure to save it as a steamid.
		
	}
	
	-- Example of the ShowZoneOptions hook.
	-- This hook lets you build your custom VGUI for your zone class which will pop up when players make a new zone or edit an existing one. Clientside.
	-- Arguments are:
	--	zone	- The full zone table of the zone we are editing.
	--	class	- The class of the zone.
	--	DPanel	- The DPanel which your VGUI elements should be parented to.
	--	zoneID	- The ID of the zone.
	--	DFrame	- The DFrame which holds it all. Not likely you will need this but it's here anyway.
	-- You must return:
	--	width, height; How large you want the DPanel to be. It will automatically resize.
	hook.Add("ShowZoneOptions","hookname_unique",function(zone,class,DPanel,zoneID,DFrame)
		if class == "Baby Got Back" then --always check class.
			local w,h = 80, 100
			
			local mul = vgui.Create("DNumberWang",DPanel) --parent to the panel.
			mul:SetPos(5,10)
			mul:SetValue(zone.onlyIfShes) --The default value should be set in the OnZoneCreated hook.
			mul:SetDecimals(1)
			mul:SetMinMax(0,10)
			function mul:OnValueChanged(new)
				-- Do your stuff here.
			end
			
			return w, h 
		end
	end)
	
	-- Example of the OnZoneCreated hook.
	-- This hook lets you set up your newly created zones with default values. Only called serverside.
	-- Arguments are:
	--	zone	- The full zone table of the zone we are editing.
	--	class	- The class of the zone.
	--	zoneID	- The ID of the zone.
	hook.Add("OnZoneCreated","hookname_unique",function(zone,class,zoneID)	
		if class == "Baby Got Back" then --always check class.
			zone.waistSize = Vector(36,24,36)
			zone.onlyIfShes = "5'3\""
		end
	end)
]]

