
AddCSLuaFile()

DEFINE_BASECLASS( "base_anim" )

ENT.PrintName = "Zone Point"
ENT.Author = "Bobblehead"
ENT.Information = "A point in the zone designator."
ENT.Category = "Other"

ENT.Editable = false
ENT.Spawnable = false
ENT.AdminOnly = false
ENT.RenderGroup = RENDERGROUP_TRANSLUCENT


function ENT:Initialize()
	self:SetModel("models/hunter/blocks/cube025x025x025.mdl")
	self:SetCollisionGroup(COLLISION_GROUP_WORLD)
	self:DrawShadow(false)
	
	if SERVER then
		self:SetUseType(SIMPLE_USE)
		self:PhysicsInit(SOLID_BBOX)
		self:GetPhysicsObject():EnableMotion(false)
		
		self:GetPhysicsObject():SetMass(1)
		
	else
		self:SetRenderBoundsWS(self:GetPos(),self:GetPos()+Vector(0,0,self:GetTall()))
	end
end

function ENT:SetupDataTables()
	self:NetworkVar("Entity",0,"Next")
	self:NetworkVar("Float",0,"Tall")
	self:NetworkVar("Int",0,"ZoneID")
	self:NetworkVar("String",0,"ZoneClass")
	self:NetworkVar("Int",1,"AreaNumber")
end

function ENT:DrawTranslucent()
	local wep = LocalPlayer():GetActiveWeapon()
	if wep:IsValid() and wep:GetClass() == "weapon_zone_designator" then
	
		if wep:GetZoneClass() == self:GetZoneClass() or GetConVarNumber("zone_filter") == 0 then
			self:DrawModel()
			
			local p = self:GetPos()
			p.z = p.z + self:GetTall()
			render.Model({model=self:GetModel(),pos=p,ang=angle_zero})
			
			render.SetMaterial(Material("cable/cable2"))
			render.DrawBeam( self:GetPos(), p, 1, 1, 0, color_white )
			
			local next = self:GetNext()
			if IsValid(next) then
				local class = self:GetZoneClass()
				
				render.DrawBeam( self:GetPos(), next:GetPos(), 1, 1, 0, color_white )
				
				local n = next:GetPos()
				n.z = n.z + next:GetTall()
				render.DrawBeam( p, n, 1, 1, 0, color_white )
				
				render.SetColorMaterial()
				local col1 = table.Copy(zones.Classes[class])
				col1.a = 80
				local col2 = {a=80}
				col2.r = col1.r * .5
				col2.g = col1.g * .5
				col2.b = col1.b * .5
				
				render.DrawQuad(p,self:GetPos(),next:GetPos(),n,col1)
				render.DrawQuad(n,next:GetPos(),self:GetPos(),p,col2)
				
				local id = self:GetZoneID()
				local classtxt = id != -1 and class .. " (# "..id..")" or class
				
				local ang = (p-self:GetPos()):Cross(n-self:GetPos()):Angle()
				ang:RotateAroundAxis(ang:Right(), 90)
				ang:RotateAroundAxis(ang:Up(),-90)
				cam.Start3D2D((n+self:GetPos())/2,ang,.2)
					draw.SimpleText(classtxt,"DermaLarge",0,0,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
				cam.End3D2D()
				
				ang:RotateAroundAxis(Vector(0,0,1), 180)
				cam.Start3D2D((n+self:GetPos())/2,ang,.2)
					draw.SimpleText(classtxt,"DermaLarge",0,0,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
				cam.End3D2D()
				
			end
		end
	end
end

function ENT:Think()
	if CLIENT then
		local next = self:GetNext()
		if IsValid(next) and next != self.resizedto then
			self:SetRenderBoundsWS(self:GetPos(),next:GetPos()+Vector(0,0,next:GetTall()))
			self.resizedto = next
		end
		
		local wep = LocalPlayer():GetActiveWeapon()
		if wep:IsValid() and wep:GetClass() == "weapon_zone_designator" then
			if LocalPlayer():GetEyeTrace().Entity == self then
				self:SetColor(Color(255,0,0))
			elseif wep:GetCurrentPoint() == self then
				self:SetColor(Color(0,0,255))
			else
				self:SetColor(color_white)
			end
		end
	else
		
		if IsValid(self.Resizing) then
		
			self:SetTall((self.Resizing:GetEyeTrace().HitPos - self:GetPos()).z)
			
		end
		
	end
end

function ENT:OnRemove()
	if SERVER then
		if IsValid(self:GetNext()) then
			self:GetNext():Remove()
		end
	end
end
