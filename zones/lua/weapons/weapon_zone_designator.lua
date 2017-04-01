
if CLIENT then
	CreateClientConVar("zone_tall",200,false,true)
	CreateClientConVar("zone_class","",false,true)
	CreateClientConVar("zone_editmode",1,false,true)
	CreateClientConVar("zone_filter",0,false,true)
	
	surface.CreateFont( "zones_save", {
		font = "Roboto", -- Use the font-name which is shown to you by your operating system Font Viewer, not the file name
		size = 20,
		weight = 1000,
	} )
	surface.CreateFont( "zones_screen", {
		font = "Arial", -- Use the font-name which is shown to you by your operating system Font Viewer, not the file name
		size = 20,
		weight = 1000,
		
	} )
else
	concommand.Add("zone_swep",function(p,c,a)
		if p:IsAdmin() then
			p:Give("weapon_zone_designator")
		end
	end)
end

if engine.ActiveGamemode() == "terrortown" then
	SWEP.Base = "weapon_tttbase"
	SWEP.Kind = WEAPON_EQUIP2
end


SWEP.NoSights = true

SWEP.PrintName = "Zone Designator"
SWEP.Author = "Bobblehead"
SWEP.Purpose = "Creates zones. Reload for menu. Right click to remove a point/zone."

SWEP.Slot = 5
SWEP.SlotPos = 5

SWEP.Spawnable = true
SWEP.AdminOnly = true

SWEP.HoldType = "pistol"
SWEP.ViewModelFOV = 51
SWEP.ViewModelFlip = false
SWEP.UseHands = true
SWEP.ViewModel = "models/weapons/c_toolgun.mdl"
SWEP.WorldModel = "models/weapons/w_toolgun.mdl"
SWEP.AutoSwitchFrom = true
SWEP.AutoSwitchTo = true

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Delay = .5
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"


function SWEP:SetupDataTables()
	self:NetworkVar("Float",0,"Tall")
	self:NetworkVar("String",0,"ZoneClass")
	self:NetworkVar("Entity",0,"CurrentPoint")
	self:NetworkVar("Int",0,"Mode")
	
end

function SWEP:Initialize()

	self:SetTall(150)
	self:SetMode(1)
	
	self:SetCurrentPoint(NULL)
end

function SWEP:Deploy()
	if SERVER then
		local points = ents.FindByClass("ent_zone_point")
		local ct = 0
		for k,v in pairs(zones.List) do
			for k2,v2 in pairs(v.points)do
				for k3, v3 in pairs(v2) do
					ct = ct + 1
				end
			end
		end
		if #points != ct then
			zones.CreatePointEnts(points)
		end
	end
end

function SWEP:Holster()
	if SERVER then
		local none = true
		for k, ply in pairs(player.GetAll()) do
			if ply == self.Owner then continue end
			local wep = ply:GetActiveWeapon() 
			if IsValid(wep) and wep:GetClass() == "weapon_zone_designator" then
				none = false
				break
			end
		end
		if none then
			for k,v in pairs(ents.FindByClass("ent_zone_point"))do
				v:Remove()
			end
		end
		
		self:SetCurrentPoint(NULL)
		
		return true
	end
end

function SWEP:DrawHUD()
	local z,id = LocalPlayer():GetCurrentZone(GetConVarNumber("zone_filter") == 1 and self:GetZoneClass() or nil)
    z = z and z.class.."(# "..id..")" or "None"
    draw.SimpleText("Current Zone: "..z, "DermaLarge", 100,100)
end

function SWEP:PrimaryAttack()
	
	
	self:SendWeaponAnim( ACT_VM_PRIMARYATTACK )
	
	if SERVER then
		self.Owner:EmitSound("buttons/button15.wav")
	end
	
	self:UpdateSettings()
	local mode = self:GetMode()
	
	if mode == 1 then //Create
		if CLIENT then return end
		self:PlacePoint()
	elseif mode == 2 then //Merge
		if CLIENT then return end
		self:MergeZones()
		
	elseif mode == 3 then //Edit
		local curr = self:GetCurrentPoint()
		
		if IsValid(curr) then
			if CLIENT then return end
			local next = curr
			repeat
				
				next.Resizing = nil
				
				next = next:GetNext()
				
			until ( next == curr )
			
			zones.List[curr:GetZoneID()].height[curr:GetAreaNumber()] = curr:GetTall()
			
			self:SetCurrentPoint(NULL)
			
		elseif CLIENT then
			local tr = self.Owner:GetEyeTrace()
			if !tr.HitWorld and IsValid(tr.Entity) and tr.Entity:GetClass() == "ent_zone_point" then
				zones.ShowOptions(tr.Entity:GetZoneID())
			end
			
		end
		
	elseif mode == 4 then
		if CLIENT then return end
		
		local curr = self:GetCurrentPoint()
		local tr = self.Owner:GetEyeTrace()
		
		if !tr.HitWorld and IsValid(tr.Entity) and tr.Entity:GetClass() == "ent_zone_point" then
			
			self:SetCurrentPoint(tr.Entity)
			
		elseif IsValid(curr) then
			
			local id,areanum = curr:GetZoneID(), curr:GetAreaNumber()
			local next = curr:GetNext()
			
			local new = ents.Create("ent_zone_point")
			local p = curr:GetPos()
			tr.HitPos.z = p.z
			new:SetPos(tr.HitPos)
			curr:SetNext(new)
			-- self:GetCurrentPoint():DeleteOnRemove(new)
			
			new.LastPoint = self:GetCurrentPoint()
			self:SetCurrentPoint(new)
			new:SetTall(curr:GetTall())
			new:SetZoneClass(curr:GetZoneClass())
			new:SetZoneID(id)
			new:SetAreaNumber(areanum)
			new:Spawn()
			new:SetNext(next)
			next.LastPoint = new
			
			
			local n = new
			local pts = {}
			repeat
				pts[#pts+1] = n:GetPos() - Vector(0,0,2)
				n = n:GetNext()
			until (n == new)
			
			zones.List[id].points[areanum] = pts
			zones.Sync()
			
		end
		
	end
	
end

function SWEP:SecondaryAttack()
	self:SendWeaponAnim( ACT_VM_PRIMARYATTACK )
	
	if CLIENT then return end
	
	self.Owner:EmitSound("buttons/button16.wav")
		
	local tr = self.Owner:GetEyeTrace()
	local mode = self:GetMode()
	
	if mode == 1 then //delete
	
		if !tr.HitWorld and IsValid(tr.Entity) and tr.Entity:GetClass() == "ent_zone_point" then
			local point = tr.Entity
			local last = point.LastPoint
			
			local id = point:GetZoneID()
			if id != -1 then
				
				if #zones.List[id].points > 1 then
					id = select(2,zones.Split(id, point:GetAreaNumber()))
				end
				
				zones.Remove(id)
				
			end
			
			point:Remove()
			
			self:SetCurrentPoint(last)
			
		elseif self:GetCurrentPoint():IsValid() then
			local point, last = self:GetCurrentPoint(), self:GetCurrentPoint().LastPoint
			point:Remove()
			self:SetCurrentPoint(last or NULL)
		end
		
	elseif mode == 2 then //split
		
		if !tr.HitWorld and IsValid(tr.Entity) and tr.Entity:GetClass() == "ent_zone_point" then
			local point = tr.Entity
			local id = point:GetZoneID()
			
			if #zones.List[id].points == 1 then
				return
			end
			
			local zone, newid = zones.Split(id, point:GetAreaNumber())
			
			local next = point
			repeat
				
				next:SetZoneID(newid)
				next:SetAreaNumber(next:GetAreaNumber() - #zones.List[id].points)
				
				next = next:GetNext()
				
			until ( next == point )
			
		end
		
	elseif mode == 3 then //resize
		local curr = self:GetCurrentPoint()
		
		if IsValid(curr) then
		
			local next = curr
			repeat
				
				next.Resizing = nil
				
				next = next:GetNext()
				
			until ( next == curr )
			
			zones.List[curr:GetZoneID()].height[curr:GetAreaNumber()] = curr:GetTall()
			
			self:SetCurrentPoint(NULL)
			
		else
			if !tr.HitWorld and IsValid(tr.Entity) and tr.Entity:GetClass() == "ent_zone_point" then
				local next = tr.Entity
				repeat
					next.Resizing = self.Owner
					
					next = next:GetNext()
					
					
				until ( next == tr.Entity )
				
				self:SetCurrentPoint(tr.Entity)
			end
		end
		
	elseif mode == 4 then //Remove a point
		
		if !tr.HitWorld and IsValid(tr.Entity) and tr.Entity:GetClass() == "ent_zone_point" or IsValid(self:GetCurrentPoint()) then
			
			local hit = tr.Entity:IsValid() and tr.Entity or self:GetCurrentPoint()
			local id,areanum = hit:GetZoneID(), hit:GetAreaNumber()
			
			if #zones.List[id].points[areanum] > 3 then
			
				local last = hit.LastPoint
				local next = hit:GetNext()
				
				next.LastPoint = last
				last:SetNext(next)
				
				hit:SetNext(NULL)
				hit.LastPoint = nil
				hit:Remove()
				
				local n = next
				local pts = {}
				repeat
					pts[#pts+1] = n:GetPos() - Vector(0,0,2)
					n = n:GetNext()
				until (n == next)
				
				zones.List[id].points[areanum] = pts
				zones.Sync()
				
				self:SetCurrentPoint(last)
				
			end
			
		end
		
	end
	
	
end

local mx,my 
if CLIENT then
	mx, my = ScrW()/2, ScrH()/2
end

function SWEP:Reload() --show menu.
	
	self:UpdateSettings()
	if SERVER then 
		if game.SinglePlayer() then
			self:CallOnClient("Reload")
		end
		return
	end
	
	if IsValid(self.frame) then return end
	
	input.SetCursorPos(mx,my)
	
	self:OpenMenu()
	
end

function SWEP:PlacePoint() --mode == 1
	local tr = self.Owner:GetEyeTrace()
	if tr.HitWorld then
		
		local next = ents.Create("ent_zone_point")
		
		if IsValid(self:GetCurrentPoint()) then
			local p = self:GetCurrentPoint():GetPos()
			tr.HitPos.z = p.z
			next:SetPos(tr.HitPos)
			self:GetCurrentPoint():SetNext(next)
			-- self:GetCurrentPoint():DeleteOnRemove(next)
		else
			next:SetPos(tr.HitPos+Vector(0,0,1))
		end
		
		next.LastPoint = self:GetCurrentPoint()
		self:SetCurrentPoint(next)
		next:SetTall(self:GetTall())
		next:SetZoneClass(self:GetZoneClass())
		next:SetZoneID(-1)
		next:SetAreaNumber(1)
		next:Spawn()
		
	elseif tr.Entity:IsValid() and tr.Entity:GetClass() == "ent_zone_point" and tr.Entity != self:GetCurrentPoint() then
		if IsValid(self:GetCurrentPoint()) then
			local next = tr.Entity
			if !IsValid(next.LastPoint) then
			
				self:GetCurrentPoint():SetNext(next)
				
				if IsValid(next:GetNext()) then //we've come full circle.
					
					next.LastPoint = self:GetCurrentPoint()
					
					local id = select(2,zones.CreateZoneFromPoint(self:GetCurrentPoint()))
					-- self:GetCurrentPoint():DeleteOnRemove(next)
					self:SetCurrentPoint(NULL)
					
					local o = self.Owner
					timer.Simple(.1,function() -- wait for it to sync.
						if IsValid(o) then
							o:SendLua("zones.ShowOptions("..id..")")
						end
					end)
					
				end
				
			end
		end
		
		
	end
end

function SWEP:MergeZones()

	local tr = self.Owner:GetEyeTrace()
	if tr.HitWorld then
		self:SetCurrentPoint(NULL)
		
	elseif IsValid(tr.Entity) and tr.Entity:GetClass() == "ent_zone_point" then
		
		local curr = self:GetCurrentPoint()
		local trent = tr.Entity
		if not IsValid(curr) then
			self:SetCurrentPoint(trent)
			
		else 
			//Merge the zones.
			if curr:GetZoneID() != trent:GetZoneID() then
				local cid = curr:GetZoneID()
			
				--Change the points.
				for k,next in pairs(ents.FindByClass("ent_zone_point")) do
					if next:GetZoneID() == cid then
						
						next:SetZoneID(trent:GetZoneID())
						next:SetAreaNumber(next:GetAreaNumber() + #zones.List[trent:GetZoneID()].points)
						next:SetZoneClass(zones.List[trent:GetZoneID()].class)
						
					end
					
				end
				
				self:SetCurrentPoint(NULL)
				
				zones.Merge(cid,trent:GetZoneID()) --from, to
				
			else
				self:SetCurrentPoint(trent)
				
			end
			
		end
		
	end
end

function SWEP:UpdateSettings()
	--load convars
	local new_tall = SERVER and self.Owner:GetInfoNum("zone_tall",200) or GetConVarNumber("zone_tall")
	local new_class = SERVER and self.Owner:GetInfo("zone_class") or GetConVarString("zone_class")
	local new_mode = SERVER and self.Owner:GetInfoNum("zone_editmode",1) or GetConVarNumber("zone_editmode")
	
	if new_class == "" then
		for k,v in pairs(zones.Classes)do
			new_class = k
			self.Owner:ConCommand('zone_class "'..k..'"')
			break
		end
	end
	
	--If changed, remove current building area
	if new_class != self:GetZoneClass() or new_tall != self:GetTall() or new_mode != self:GetMode() then
		self:ResetTool()
	end
	assert(new_class != "", "No class is set for the zone designator! Did you call zones.RegisterClass()?\n")
	
	--apply convars
	self:SetTall(new_tall)
	self:SetZoneClass(new_class)
	self:SetMode(new_mode)
end

function SWEP:ResetTool()

	if self:GetMode() == 1 and SERVER then
		local cur = self:GetCurrentPoint()
		if IsValid(cur) and cur:GetZoneID() == -1 then
			
			while IsValid(cur) do
				local last = cur.LastPoint
				cur:Remove()
				cur = last
			end
			
		end
		
	end
	self:SetCurrentPoint(NULL)
end

function SWEP:OpenMenu()
	local zc = self:GetZoneClass()
	
	local frame = vgui.Create("DFrame")
	self.frame = frame
	frame:SetSize(300,400)
	frame:Center()
	frame:MakePopup()
	frame:ShowCloseButton(false)
	frame:SetTitle("Zone Designator Options")
	function frame:Think()
		if not input.IsButtonDown(_G["KEY_"..input.LookupBinding("+reload"):upper()]) then
			mx,my = gui.MousePos()
			self:Close()
		end
	end
	
	local ztitle = vgui.Create("DLabel",frame)
	ztitle:Dock(TOP)
	ztitle:DockMargin(7,0,5,0)
	ztitle:SetText("Zone Class:")
	ztitle:SizeToContents()
	
	local zclass = vgui.Create("DComboBox",frame)
	zclass:Dock(TOP)
	zclass:DockMargin(5,0,5,0)
	for k,v in pairs(zones.Classes) do
		zclass:AddChoice(k,nil,k==zc)
	end
	function zclass:OnSelect(i,class)
		RunConsoleCommand("zone_class",class)
	end
	
	local filter = vgui.Create("DCheckBoxLabel",frame)
	filter:Dock(TOP)
	filter:DockMargin(6,5,5,5)
	filter:SetText("Filter zones of a different class.")
	filter:SizeToContents()
	filter:SetConVar("zone_filter")
	
	local height = vgui.Create( "DNumSlider", frame )
	height:Dock(TOP)
	height:DockMargin(7,0,0,0)
	height:SetText( "Zone Height:" )
	height:SetMin( 0 )
	height:SetMax( 1000 )
	height:SetDecimals( 0 )
	height:SetConVar( "zone_tall" )
	
	local modetitle = vgui.Create("DLabel",frame)
	modetitle:Dock(TOP)
	modetitle:DockMargin(7,0,5,0)
	modetitle:SetText("Tool Mode:")
	modetitle:SizeToContents()
	
	local mode = vgui.Create("DListView",frame)
	mode:Dock(TOP)
	mode:DockMargin(5,0,5,5)
	mode:AddColumn("Mode")
	mode:AddColumn("Info"):SetFixedWidth(180)
	mode:SetTall(200)
	mode:SetMultiSelect(false)
	
	mode:AddLine("Create / Delete","Create new zones")
	mode:AddLine("Merge / Split","Turn two zones into one.")
	mode:AddLine("Edit / Resize","Change zone properties.")
	mode:AddLine("Insert / Remove","Insert points into existing zones.")
	mode:SelectItem(mode:GetLine(self:GetMode()))
	function mode:OnRowSelected(id)
		RunConsoleCommand("zone_editmode",id)
	end
	
	
	local save = vgui.Create("DButton",frame)
	save:Dock(BOTTOM)
	save:DockMargin(5,0,5,5)
	save:SetText("SAVE ALL ZONES")
	save:SetFont("zones_save")
	save:SetTextColor(color_black)
	save:SetTall(50)
	function save:DoClick()
		Derma_Query("Are you sure you want to save? This can't be undone.", "Save Confirmation",
			"Yes", function() 
				RunConsoleCommand("zone_save")
			end,
			"No", function()
			end
		)
	end
	
	
	
end

local modes = {
	{ --create
		"Create",
		"Delete"
	},
	{ --merge
		"Merge",
		"Split"
	},
	{ --edit
		"Edit",
		"Resize"
	},
	{ --insert
		"Insert",
		"Remove"
	},
}
local lmb, rmb = Material("gui/lmb.png","unlitgeneric"), Material("gui/rmb.png","unlitgeneric")
function SWEP:DrawScreen(x,y,w,h)
	local mode = self:GetMode()
	local txt = modes[mode]
	
	draw.SimpleText(txt[1], "zones_screen", x+w/4, -h/5, _, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	draw.SimpleText(txt[2], "zones_screen", w+x-w/4, -h/5, _, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	
	surface.SetDrawColor(color_white)
	surface.DrawRect(x+w/2-1,y+h*.125,2,h*.75)
	
	surface.SetMaterial(lmb)
	surface.DrawTexturedRect(x+w/4-16,y+h*.55-16,32,32)
	surface.SetMaterial(rmb)
	surface.DrawTexturedRect(x+w*.75-16,y+h*.55-16,32,32)
	
end

local function GetBoneOrientation(self,ent)
	local bone, pos, ang
	bone = ent:LookupBone("Hand")
	if (!bone) then return end
	pos, ang = Vector(0,0,0), Angle(0,0,0)
	local m = ent:GetBoneMatrix(bone)
	if (m) then
		pos, ang = m:GetTranslation(), m:GetAngles()
	end
	if (IsValid(self.Owner) and self.Owner:IsPlayer() and 
		ent == self.Owner:GetViewModel() and self.ViewModelFlip) then
		ang.r = -ang.r // Fixes mirrored models
	end
	return pos, ang
end
function SWEP:ViewModelDrawn()
	local vm = self.Owner:GetViewModel()
	if !IsValid(vm) then return end

	local pos, ang = GetBoneOrientation(self, vm )
	local offset = Vector(.08, -5.16, 3.43)
	local offsetAng = Angle(180, 0, -46)
	local size = 0.0159
	local drawpos = pos + ang:Forward() * offset.x + ang:Right() * offset.y + ang:Up() * offset.z
	ang:RotateAroundAxis(ang:Up(), offsetAng.y)
	ang:RotateAroundAxis(ang:Right(), offsetAng.p)
	ang:RotateAroundAxis(ang:Forward(), offsetAng.r)
	
	cam.Start3D2D(drawpos, ang, size)
		local x,y,w,h = -72,-72
		local w,h = 2*-x, 2*-y
		//Draw Background:
		surface.SetDrawColor( 200, 200, 200, 255 )
		surface.SetDrawColor( 40,40,40,255 )
		surface.DrawRect( x, y, w, h )
		
		//Draw foreground:
		self:DrawScreen(x,y,w,h)
		
	cam.End3D2D()
end