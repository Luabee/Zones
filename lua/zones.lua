local version = 1.20 -- Older versions will not run if a newer version is used in another script.
--[[
	ZONES - by Bobbleheadbob with help from Zeh Matt
		WARNING: If you edit any of these files, make them use a different namespace. Multiple scripts may depend on this library so modifying it can break other scripts.

	Purpose:
		For easy in-game designation of persistent polygonal zones which are used by any script.

	How to Use:
		All zones are saved in zones.List; see an example below.
		Zone creation is handled with weapon_zone_designator and ent_zone_point, but can be done in code as well.
		When a zone is created, changed, or removed all zones are synced to clients. When clients join they are also synced.
		Any extra details can be saved to a zone. Everything is written to a txt file and is persistent to the map.

		Since multiple scripts might use the zones system, don't assume that every zone is related to your script.
		To register a zone class, use zones.RegisterClass(class, color); use a unique string like "Scriptname Room".
		When a zone class is registered, admins can use the tool to create new ones.
		When a new zone is created, the "OnZoneCreated" hook is called serverside. See the example file for documentation.
		When a zone is loaded into the game, the "OnZoneLoaded" hook is called serverside. See the example file for documentation.
		When a player edits a zone's properties, the "ShowZoneOptions" hook is called clientside. See the example file for documentation.

		Use zones.FindByClass() to find all zones which are of a given class.
		Use ply:GetCurrentZone() to find the zone that a player is standing in.

	Installation:
		This is a shared file so include it in any shared environment. Also include ent_zone_point and weapon_zone_designator as a shared ent and weapon.
		You should not put this file directly in lua/autorun.

	License:
		YOU MAY use/edit this however you want, as long as you give proper attribution.
		YOU MAY distribute this with other scripts whether they are paid or free.
		YOU MAY NOT distribute this on its own. It must accompany another script.

	Enjoy! ~Bobbleheadbob
]]

AddCSLuaFile()

local table, math, Vector, pairs, ipairs, ents, bit = table, math, Vector, pairs, ipairs, ents, bit

if zones then
	local diff = math.abs(math.floor(version)-math.floor(zones.version)) > 0
	if diff then
		ErrorNoHalt("WARNING! Two scripts use VERY different versions of the zones API. Please tell one of them to update their script!\n")
	end
	if zones.version > version then
		if diff then
			print("The outdated version of zones is located at: "..debug.getinfo(1,"S").short_src)
		end
		print("A new version of zones exists. Using version "..zones.version.." instead of "..version)
		return
	elseif zones.version < version then
		if diff then
			print("The outdated version of zones is located at: "..debug.getinfo(zones.RegisterClass,"S").short_src)
		end
		print("A new version of zones exists. Using version "..version.." instead of "..zones.version)
	end

else
	print("Loaded zones " ..version)
end

zones = zones or {}
zones.version = version

zones.Classes = zones.Classes or {}
zones.List = zones.List or {}
zones.Map = zones.Map or {}

include("zone.lua")

//Common interface functions:

-- Registers a zone class which can then be created using weapon_zone_designator
function zones.RegisterClass(name, class)
	zones.Classes[name] = class
	print("Registered class: " .. name)
end

local plymeta = FindMetaTable("Player")
--returns one of the zones a player is found in. Also returns that zone's ID. Class is optional to filter the search.
function plymeta:GetCurrentZone(class)
	local c = zones.Cache[self][class or "___"]
	if c then return unpack(c) end
	local z,id = zones.GetZoneAt(self:GetPos(), class)
	zones.Cache[self][class or "___"] = {z,id}
	return z,id
end

--returns a table of zones the player is in. Class is optional to filter the search.
function plymeta:GetCurrentZones(class)
	return zones.GetZonesAt(self:GetPos(),class)
end

function zones.GetZoneAt(pos,class) --works like above, except uses any point.

	local nearby = zones.GetNearbyZones(pos)

	for k,zone in pairs(nearby) do
		local data = zone.data
		if class and class != data.class then continue end
		if not pos:WithinAABox(data.bounds.mins, data.bounds.maxs) then
			continue
		end

		for k1, points in pairs(data.points) do
			if zones.PointInPoly(pos,points) then
				local z = points[1].z
				if pos.z >= z and pos.z < z + data.height[k1] then
					return zone,k
				end
			end
		end
	end

	return nil, -1

end

function zones.GetZonesAt(pos,class) --works like above, except uses any point.
	local tbl = {}
	local nearby = zones.GetNearbyZones(pos)
	for k,zone in pairs(nearby) do
		local data = zone.data
		if class and class != data.class then continue end
		if not pos:WithinAABox(data.bounds.mins,data.bounds.maxs) then continue end
		for k1, points in pairs(data.points) do
			if zones.PointInPoly(pos,points) then
				local z = points[1].z
				if pos.z >= z and pos.z < z + data.height[k1] then
					tbl[k] = zone
				end
			end
		end
	end
	return tbl
end

--Gets a list of all zones which are of the specified class.
function zones.FindByClass(class)
	local tbl = {}

	for k,v in pairs(zones.List) do
		if v.class == class then
			tbl[k] = v
		end
	end

	return tbl
end

--Returns the numerical ID of a zone.
function zones.GetID(zone)
	return table.KeyFromValue(zones.List,zone)
end




//Getting into the meat of the API:
local mapMins = -16000
local mapMaxs = 16000
local mapSize = 32000
local chunkSize = 128

local function GetZoneIndex(pos)

	local x = pos.x + mapMaxs
	local y = pos.y + mapMaxs
	local z = pos.z + mapMaxs

	local idxX = math.floor(x / chunkSize)
	local idxY = math.floor(y / chunkSize)
	local idxZ = math.floor(z / chunkSize)
	local idx = bit.bor(bit.lshift(idxX, 24), bit.lshift(idxY, 14), idxZ)

	return idx

end

local function Floor(x,to)
    return math.floor(x / to) * to
end
local function Ceil(x,to)
    return math.ceil(x / to) * to
end

function zones.CreateZoneMapping()
    zones.Map = {}
    for _, zone in pairs(zones.List) do
		local data = zone.data
        local mins = data.bounds.mins
        local maxs = data.bounds.maxs
        for x = Floor(mins.x,chunkSize), Ceil(maxs.x + 1,chunkSize), chunkSize do
            for y = Floor(mins.y,chunkSize), Ceil(maxs.y + 1,chunkSize), chunkSize do
                for z = Floor(mins.z,chunkSize), Ceil(maxs.z + 1,chunkSize), chunkSize do
                    local idx = GetZoneIndex(Vector(x, y, z))
                    zones.Map[idx] = zones.Map[idx] or {}
                    table.insert(zones.Map[idx], zone)
                end
            end
        end
    end
end

function zones.GetNearbyZones(pos)
	local idx = GetZoneIndex(pos)
	return zones.Map[idx] or {}
end

zones.Cache = {}
local function ClearCache()
	for k,v in pairs(player.GetAll()) do
		zones.Cache[v] = {}
	end
end
ClearCache()
hook.Add("Tick","zones_cache",ClearCache)

if SERVER then
	util.AddNetworkString("zones_sync")
	util.AddNetworkString("zones_class")

	function zones.SaveZones()
		if not file.Exists("zones","DATA") then
			file.CreateDir("zones")
		end

		local data = {}
		for k,v in pairs(zones.List) do
			data[k] = v.data
		end

		file.Write("zones/"..game.GetMap():gsub("_","-"):lower()..".txt", util.TableToJSON(data))
	end

	concommand.Add("zone_save",function(ply,c,a)
		if not ply:IsAdmin() then return end
		zones.SaveZones()
	end)

	function zones.LoadZones()

		local tbl = file.Read("zones/"..game.GetMap():gsub("_","-"):lower()..".txt", "DATA")
		local list = {}
		local data = tbl and util.JSONToTable(tbl) or {}

		for k,v in pairs(data) do
			local class = zones.Classes[v.class]
			local zone = table.Copy(class)
			zone.data = v
			setmetatable(zone, zones.ZONE_META)
			list[k] = zone
		end

		zones.List = list

		//Update legacy files:
		for id,zone in pairs(zones.List) do
			if not zone.data.bounds then
				zones.CalcBounds(zone)
			end
			zone:Initialize()
			hook.Run("OnZoneLoaded",zone,zone.data.class,id)
		end
	end

	local sync = false
	local syncply

	function zones.Sync(ply)
		sync = true
		syncply = ply
	end

	hook.Add("Tick","zones_sync",function()
		if sync then
			print("Syncing")
			local list = {}
			for k,v in pairs(zones.List) do
				list[k] = v.data
			end
			net.Start("zones_sync")
			net.WriteTable(list)
			if syncply then
				net.Send(syncply)
				syncply = nil
			else
				net.Broadcast()
				zones.CreateZoneMapping()
			end
			sync = false
		end
	end)

	function zones.CreateZoneFromPoint(ent)

		local className = ent:GetZoneClass()
		local class = zones.Classes[className]

		if class == nil then
			error("Class not registered")
			return
		end

		local id = table.maxn(zones.List) + 1

		local zone = table.Copy(class)
		local data = {
			points = {{}},
			height = { ent:GetTall() },
			class = ent:GetZoneClass(),
			bounds = {},
			color = zone.Color,
			id = id,
		}
		zone.data = data
		setmetatable(zone, zones.ZONE_META)

		local cur = ent
		repeat
			local pos = cur:GetPos() - Vector(0,0,2)
			data.points[1][#data.points[1]+1] = pos

			cur:SetZoneID(id)
			cur = cur:GetNext()

		until (cur == ent)

		zones.CalcBounds(zone,true)

		zones.List[id] = zone
		hook.Run("OnZoneCreated",zone, zone.data.class,id)

		zone:Initialize()

		zones.Sync()

		return zone, id

	end

	function zones.CalcBounds(zone,newZone)
        local mins,maxs = Vector(10000000,10000000,10000000), Vector(-10000000,-10000000,-10000000)
		local data = zone.data
        for areanum,area in pairs(data.points)do
            for k,pos in pairs(area) do
                maxs.x = math.max(pos.x, maxs.x)
                maxs.y = math.max(pos.y, maxs.y)
                maxs.z = math.max(pos.z+data.height[areanum], maxs.z)
                mins.x = math.min(pos.x, mins.x)
                mins.y = math.min(pos.y, mins.y)
                mins.z = math.min(pos.z, mins.z)
            end
        end
        data.bounds = {["mins"]=mins,["maxs"]=maxs}
        if not newZone then
            hook.Run("OnZoneChanged",zone,data.class,zones.GetID(zone))
        end
    end

	function zones.Remove(id)
		local zone = zones.List[id]
		if zone == nil then
			error("Trying to remove non-existing zone")
			return
		end
		if zone.OnRemove ~= nil then
			zone:OnRemove()
		end
		hook.Run("OnZoneRemoved",zones.List[id],zones.List[id].class,id)
		zones.List[id] = nil
		zones.Sync()
	end

	function zones.CreatePointEnts(removeThese) --removeThese is optional.
		for k,v in pairs(removeThese or ents.FindByClass("ent_zone_point")) do --remove old
			v:Remove()
		end

		--create new
		for id,zone in pairs(zones.List)do
			local data = zone.data
			for k, area in pairs(data.points) do

				local first
				local curr
				for k2,point in ipairs(area)do

					local next = ents.Create("ent_zone_point")

					if IsValid(curr) then
						next:SetPos(point+Vector(0,0,1))
						curr:SetNext(next)
						-- curr:DeleteOnRemove(next)
					else
						first = next
						next:SetPos(point+Vector(0,0,1))
					end

					next.LastPoint = curr
					curr = next
					next:SetTall(data.height[k])
					next:SetZoneClass(data.class)
					next:Spawn()
					next:SetZoneID(id)
					next:SetAreaNumber(k)

				end

				curr:SetNext(first)
				-- curr:DeleteOnRemove(first)
				first.LastPoint = curr

			end
		end

	end

	function zones.Merge(from,to)

		local zfrom, zto = zones.List[from], zones.List[to]

		table.Add(zto.data.points, zfrom.data.points)
		table.Add(zto.data.height, zfrom.data.height)

		zones.Remove(from)
		zones.CalcBounds(to)

		hook.Run("OnZoneMerged",zto,zto.data.class,to,zfrom,zfrom.data.class,from)

		zones.Sync()

	end

	function zones.Split(id,areanum)
		local zone = zones.List[id]
		local data = zone.data
		local pts, h, bound = data.points[areanum], data.height[areanum]

		table.remove(data.points,areanum)
		table.remove(data.height,areanum)

		if #data.points == 0 then
			zones.Remove(id)
		end

		local new = table.Copy(zone)
		local newData = table.Copy(data)
		newData.points = {pts}
		newData.height = {h}
		new.data = newData
		setmetatable(new, zones.ZONE_META)

		local id = table.maxn(zones.List)+1
		zones.List[id] = new

		zones.CalcBounds(zone)
		zones.CalcBounds(new)

		hook.Run("OnZoneSplit",new,new.class,id,zone,id)

		zones.Sync()

		return new,id

	end

	function zones.ChangeClass(id, className)
		local zone = zones.List[id]
		local class = zones.Classes[className]

		if class == nil then
			error("Class not registered")
			return
		end

		local newZone = table.Copy(class)
		newZone.data = zone.data
		newZone.data.class = className
		setmetatable(newZone, zones.ZONE_META)

		zones.List[id] = newZone

		hook.Run("OnZoneCreated",newZone,className,id)

		zones.Sync()
	end


	local mapMins = -16000
	local mapMaxs = 16000
	local mapSize = 32000
	local chunkSize = 128

	function zones.GetZoneIndex(pos)

		local x = math.Remap(pos.x, mapMins, mapMaxs, 0, mapSize)
		local y = math.Remap(pos.y, mapMins, mapMaxs, 0, mapSize)
		local z = math.Remap(pos.z, mapMins, mapMaxs, 0, mapSize)

		local idxX = math.floor(x / chunkSize)
		local idxY = math.floor(y / chunkSize)
		local idxZ = math.floor(z / chunkSize)
		local idx = bit.bor(bit.lshift(idxX, 24), bit.lshift(idxY, 14), idxZ)

		return idx

	end

	hook.Add("InitPostEntity","zones_load",function()
		zones.LoadZones()
	end)
	hook.Add("PlayerInitialSpawn","zones_sync",function(ply)
		zones.Sync(ply)
	end)

	net.Receive("zones_class",function(len,ply)
		if not ply:IsAdmin() then return end
		local id = net.ReadFloat()
		local class = net.ReadString()

		for k,v in pairs(ents.FindByClass("ent_zone_point"))do
			if v:GetZoneID() == id then
				v:SetZoneClass(class)
			end
		end

		zones.ChangeClass(id,class)

	end)

else

	net.Receive("zones_sync",function(len)

		local list = net.ReadTable()
		local newList = {}

		for k,v in pairs(list) do
			local zoneData = v
			local class = zones.Classes[zoneData.class]
			local zone = table.Copy(class)
			zone.data = zoneData
			setmetatable(zone, zones.ZONE_META)
			if zones.List[k] == nil and zone.Initialize ~= nil then
				zone:Initialize()
			end
			newList[k] = zone
		end

		for k,zone in pairs(zones.List) do
			if newList[k] == nil and zone.OnRemove ~= nil then
				zone:OnRemove()
			end
		end

		zones.List = newList
		zones.CreateZoneMapping()

	end)

	function zones.ShowOptions(id)

		local zone = zones.List[id]
		local class = zone.data.class

		local frame = vgui.Create("DFrame")
		zones.optionsFrame = frame
		frame:MakePopup()
		frame:SetTitle("Zone Settings")

		local ztitle = vgui.Create("DLabel",frame)
		ztitle:Dock(TOP)
		ztitle:DockMargin(2,0,5,5)
		ztitle:SetText("Zone Class:")
		ztitle:SizeToContents()

		local zclass = vgui.Create("DComboBox",frame)
		zclass:Dock(TOP)
		zclass:DockMargin(0,0,0,5)
		for k,v in pairs(zones.Classes) do
			zclass:AddChoice(k,nil,k == class)
		end
		function zclass:OnSelect(i,class)
			net.Start("zones_class")
				net.WriteFloat(id)
				net.WriteString(class)
			net.SendToServer()

			frame.content:Remove()

			frame.content = vgui.Create("DPanel",frame)
			frame.content:Dock(FILL)
			frame.content:DockPadding(5,5,5,5)

			local w,h = hook.Run("ShowZoneOptions",zone,class,frame.content,id,frame)
			frame:SizeTo((w or 100)+8,(h or 2)+78, .2)
			frame:MoveTo(ScrW()/2-((w or 292)+8)/2,ScrH()/2-((h or 422)+78)/2, .2)
		end

		frame.content = vgui.Create("DPanel",frame)
		frame.content:Dock(FILL)
		frame.content:DockPadding(5,5,5,5)

		local w,h = hook.Run("ShowZoneOptions",zone,class,frame.content,id,frame)
		frame:SetSize((w or 100)+8,(h or 2)+78)
		frame:Center()

	end

end



//returns the point of intersection between two infinite lines.
local function IntersectPoint(line1, line2)

	local x1,y1,x2,y2,x3,y3,x4,y4 = line1.x1,line1.y1,line1.x2,line1.y2,line2.x1,line2.y1,line2.x2,line2.y2

	local m1,m2 = (y1-y2)/((x1-x2)+.001),(y3-y4)/((x3-x4)+.001) --get the slopes
	local yint1,yint2 = (-m1*x1)+y1,(-m2*x3)+y3 --get the y-intercepts
	local x = (yint1-yint2)/(m2-m1) --calculate x pos
	local y = m1*x+yint1 --plug in x pos to get y pos

	return x,y

end
//Returns a bool if two SEGEMENTS intersect or not.
local function Intersect(line1, line2)

	local x,y = IntersectPoint(line1, line2)

	local sx,sy = tostring(x), tostring(y)
	if (sx == "-inf" or sx == "inf" or sx == "nan") then
		return false
	end

	local minx1, maxx1 = math.min(line1.x1,line1.x2)-.1, math.max(line1.x1,line1.x2)+.1
	local minx2, maxx2 = math.min(line2.x1,line2.x2)-.1, math.max(line2.x1,line2.x2)+.1
	local miny1, maxy1 = math.min(line1.y1,line1.y2)-.1, math.max(line1.y1,line1.y2)+.1
	local miny2, maxy2 = math.min(line2.y1,line2.y2)-.1, math.max(line2.y1,line2.y2)+.1

	if (x >= minx1) and (x <= maxx1) and (x >= minx2) and (x <= maxx2) then

		if (y >= miny1) and (y <= maxy1) and (y >= miny2) and (y <= maxy2) then

			--debugoverlay.Sphere( Vector(x,y,LocalPlayer():GetPos().z), 3, FrameTime()+.01, Color(255,0,0), true)

			return true

		end

	end

	return false

end
function zones.PointInPoly(point,poly) //True if point is within a polygon.

	local ray = {
		x1 = point.x,
		y1 = point.y,
		x2 = 100000,
		y2 = 100000
	}

	local inside = false

	local line = {
		x1 = 0,
		y1 = 0,
		x2 = 0,
		y2 = 0
	}

	//Perform ray test
	for k1, v in pairs(poly) do

		local v2 = poly[k1+1]
		if not v2 then
			v2 = poly[1]
		end

		line["x1"] = v.x
		line["y1"] = v.y
		line["x2"] = v2.x
		line["y2"] = v2.y

		if Intersect(ray,line) then
			inside = !inside
		end

	end

	return inside
end
